"""Paint the tiles the phone requests at camera zoom 15.

A style-id check is not enough. This pack's z14 tiles contain places, and
Albuquerque parcels, and not land or trails. If the style asks for that zoom,
the bitmap stays the cream background.
"""

import gzip
import json
import math
import sqlite3
from io import BytesIO
from pathlib import Path

import mapbox_vector_tile
import pytest
from PIL import Image, ImageDraw
from pmtiles.reader import MmapSource, Reader

ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / "Sources" / "PilgrimAtlas" / "Resources"
PACK = RESOURCES / "northern-new-mexico.pmtiles"
HILLSHADE = RESOURCES / "northern-new-mexico-hillshade.pmtiles"
CONTOURS = RESOURCES / "northern-new-mexico-contours.pmtiles"
CONTRACT = ROOT / "Sources" / "PilgrimAtlasCore" / "render-contract.json"
SQLITE = RESOURCES / "northern-new-mexico.sqlite"
BEIGE = (0xEF, 0xE6, 0xD6, 255)
EXTENT = 4096
LAND_COLORS = {
    "tribal": (0x7A, 0x3E, 0x8C),
    "nps": (0x1F, 0x6F, 0x8A),
    "usfs": (0x1F, 0x7A, 0x3A),
    "usfs_inholding": (0xA8, 0x98, 0x80),
    "usfs_other": (0x6E, 0x8F, 0x72),
    "blm": (0xC4, 0x8A, 0x12),
    "dod": (0x8C, 0x30, 0x30),
    "federal_other": (0x3D, 0x5A, 0x73),
    "state_trust": (0xE0, 0x6A, 0x1F),
    "state_other": (0xC4, 0xA0, 0x6A),
    "abq_closed": (0xA3, 0x3B, 0x3B),
    "abq_open": (0x4F, 0x8A, 0x32),
    "local_protected": (0x2F, 0x8F, 0x7A),
    "private_mapped": (0xC4, 0xB4, 0x9A),
    "sma_undefined": (0xB7, 0xA9, 0x9A),
}


def _contract() -> dict:
    return json.loads(CONTRACT.read_text())


def _xyz(lon: float, lat: float, zoom: int) -> tuple[int, int]:
    n = 2**zoom
    x = int((lon + 180.0) / 360.0 * n)
    limited = max(min(lat, 85.05112878), -85.05112878)
    lat_rad = math.radians(limited)
    y = int((1.0 - math.log(math.tan(lat_rad) + 1 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


def _reader(path: Path) -> tuple[Reader, object]:
    handle = path.open("rb")
    return Reader(MmapSource(handle)), handle


def _decode(reader: Reader, zoom: int, x: int, y: int) -> dict:
    raw = reader.get(zoom, x, y)
    assert raw, f"missing tile {zoom}/{x}/{y}"
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return mapbox_vector_tile.decode(raw)


def _scale(points) -> list[tuple[float, float]]:
    return [(point[0] / EXTENT * 256, point[1] / EXTENT * 256) for point in points]


def _paint_land(layers: dict, opacity: float) -> Image.Image:
    base = Image.new("RGBA", (256, 256), BEIGE)
    overlay = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for feature in layers.get("land", {}).get("features", []):
        kind = feature["properties"].get("kind", "")
        red, green, blue = LAND_COLORS.get(kind, (90, 90, 90))
        fill = (red, green, blue, int(255 * opacity))
        geometry = feature["geometry"]
        if geometry["type"] == "Polygon":
            polygons = [geometry["coordinates"]]
        elif geometry["type"] == "MultiPolygon":
            polygons = geometry["coordinates"]
        else:
            continue
        for rings in polygons:
            if rings and rings[0]:
                draw.polygon(_scale(rings[0]), fill=fill)
    return Image.alpha_composite(base, overlay)


def _painted_pixels(image: Image.Image) -> int:
    raw = image.tobytes()
    count = 0
    for index in range(0, len(raw), 4):
        if max(
            abs(raw[index] - BEIGE[0]),
            abs(raw[index + 1] - BEIGE[1]),
            abs(raw[index + 2] - BEIGE[2]),
        ) > 12:
            count += 1
    return count


def _assert_land(image: Image.Image) -> None:
    painted = _painted_pixels(image)
    assert painted > 256 * 256 * 0.02, f"land fill is missing or still beige ({painted} pixels)"


def _trail_pixels(layers: dict) -> int:
    image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for feature in layers.get("trails", {}).get("features", []):
        geometry = feature["geometry"]
        if geometry["type"] == "LineString":
            lines = [geometry["coordinates"]]
        elif geometry["type"] == "MultiLineString":
            lines = geometry["coordinates"]
        else:
            continue
        for line in lines:
            if len(line) >= 2:
                draw.line(_scale(line), fill=(0x6B, 0x4F, 0x3A, 255), width=3)
    raw = image.tobytes()
    return sum(1 for index in range(3, len(raw), 4) if raw[index] > 200)


def _trail_vertices() -> list[tuple[float, float]]:
    connection = sqlite3.connect(SQLITE)
    try:
        rows = connection.execute("SELECT geojson FROM trails LIMIT 80").fetchall()
    finally:
        connection.close()
    points = []
    for (blob,) in rows:
        geometry = json.loads(blob)
        if geometry["type"] == "LineString":
            line = geometry["coordinates"]
        elif geometry["type"] == "MultiLineString" and geometry["coordinates"]:
            line = max(geometry["coordinates"], key=len)
        else:
            continue
        if len(line) < 2:
            continue
        lon, lat = line[len(line) // 2]
        points.append((lon, lat))
    return points


def test_land_and_trails_paint_at_the_requested_zoom():
    if not PACK.exists():
        pytest.skip("northern-new-mexico.pmtiles is not built yet")
    contract = _contract()
    opacity = contract["minFillOpacity"]
    assert opacity >= 0.45
    land_zoom = min(contract["cameraZoom"], contract["landMaxZoom"])
    trail_zoom = min(contract["cameraZoom"], contract["trailMaxZoom"])
    assert land_zoom < 14
    assert trail_zoom < 14
    reader, handle = _reader(PACK)
    try:
        for name, lon, lat in (
            ("plaza", -105.9378, 35.6870),
            ("albuquerque", -106.6504, 35.0844),
        ):
            x, y = _xyz(lon, lat, land_zoom)
            image = _paint_land(_decode(reader, land_zoom, x, y), opacity)
            _assert_land(image)
            covered = image.copy()
            ImageDraw.Draw(covered).rectangle((0, 0, 255, 255), fill=BEIGE)
            with pytest.raises(AssertionError):
                _assert_land(covered)
        plaza_x, plaza_y = _xyz(-105.9378, 35.6870, trail_zoom)
        plaza_trails = _trail_pixels(_decode(reader, trail_zoom, plaza_x, plaza_y))
        assert plaza_trails > 8, "plaza trails did not draw"
        drew_trail = False
        for lon, lat in _trail_vertices():
            trail_x, trail_y = _xyz(lon, lat, trail_zoom)
            raw = reader.get(trail_zoom, trail_x, trail_y)
            if not raw:
                continue
            if _trail_pixels(_decode(reader, trail_zoom, trail_x, trail_y)) > 8:
                drew_trail = True
                break
        assert drew_trail, "a point on a pack trail did not draw a trail line"
        parcel_zoom = min(contract["cameraZoom"], contract["placeMaxZoom"])
        abq_x, abq_y = _xyz(-106.6504, 35.0844, parcel_zoom)
        parcels = _decode(reader, parcel_zoom, abq_x, abq_y).get("parcels", {}).get("features", [])
        assert parcels, "Albuquerque lot lines are not in the tile the place source requests"
    finally:
        handle.close()


def test_bundled_terrain_is_not_flat():
    contract = _contract()
    assert HILLSHADE.exists() and HILLSHADE.stat().st_size > 100_000
    assert CONTOURS.exists() and CONTOURS.stat().st_size > 100_000
    zoom = min(contract["cameraZoom"], contract["landMaxZoom"])
    x, y = _xyz(-105.9378, 35.6870, zoom)
    hill_reader, hill_handle = _reader(HILLSHADE)
    contour_reader, contour_handle = _reader(CONTOURS)
    try:
        hill = hill_reader.get(zoom, x, y)
        assert hill and hill[:3] == b"\xff\xd8\xff"
        image = Image.open(BytesIO(hill)).convert("L")
        pixels = image.tobytes()
        mean = sum(pixels) / len(pixels)
        variance = sum((pixel - mean) ** 2 for pixel in pixels) / len(pixels)
        assert variance > 40, "hillshade tile is flat"
        raw = contour_reader.get(zoom, x, y)
        assert raw
        if raw[:2] == b"\x1f\x8b":
            raw = gzip.decompress(raw)
        layers = mapbox_vector_tile.decode(raw)
        assert layers.get("contours", {}).get("features"), "plaza contour tile is empty"
    finally:
        hill_handle.close()
        contour_handle.close()
