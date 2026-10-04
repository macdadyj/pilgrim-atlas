"""Bundle offline hillshade and contours for Northern New Mexico.

Source tiles are Mapzen Terrain Tiles on AWS Open Data (Terrarium RGB),
licensed CC BY 4.0 and ODbL. This script derives a hillshade JPEG archive and
100-meter contour vectors so the phone does not call that server.
"""

import gzip
import math
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO
from pathlib import Path

import mapbox_vector_tile
import numpy as np
from PIL import Image
from pmtiles.tile import Compression, TileType, zxy_to_tileid
from pmtiles.writer import write
from shapely.geometry import LineString, box

from .bbox import NORTHERN_NM

TERRARIUM = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
HILL_ZOOMS = range(7, 12)
CONTOUR_ZOOMS = range(10, 12)
CONTOUR_INTERVAL_M = 100
USER_AGENT = "PilgrimAtlas/terrain (offline pack; contact team@lojo.engineering)"


def _xyz_range(zoom: int) -> tuple[range, range]:
    def xy(lon: float, lat: float) -> tuple[int, int]:
        n = 2**zoom
        x = int((lon + 180.0) / 360.0 * n)
        limited = max(min(lat, 85.05112878), -85.05112878)
        lat_rad = math.radians(limited)
        y = int((1.0 - math.log(math.tan(lat_rad) + 1 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
        return x, y

    x0, y0 = xy(NORTHERN_NM.west, NORTHERN_NM.north)
    x1, y1 = xy(NORTHERN_NM.east, NORTHERN_NM.south)
    return range(min(x0, x1), max(x0, x1) + 1), range(min(y0, y1), max(y0, y1) + 1)


def _tile_bounds(zoom: int, x: int, y: int) -> tuple[float, float, float, float]:
    n = 2**zoom

    def lat_of(row: int) -> float:
        merc = math.pi * (1 - 2 * row / n)
        return math.degrees(math.atan(math.sinh(merc)))

    west = x / n * 360.0 - 180.0
    east = (x + 1) / n * 360.0 - 180.0
    return west, lat_of(y + 1), east, lat_of(y)


def _download(zoom: int, x: int, y: int, cache: Path) -> Path:
    dest = cache / f"{zoom}/{x}/{y}.png"
    if dest.exists() and dest.stat().st_size > 100:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    url = TERRARIUM.format(z=zoom, x=x, y=y)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=40) as response:
        dest.write_bytes(response.read())
    return dest


def _elevation(image: Image.Image, step: int = 1) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float64)
    grid = rgb[:, :, 0] * 256.0 + rgb[:, :, 1] + rgb[:, :, 2] / 256.0 - 32768.0
    if step > 1:
        grid = grid[::step, ::step]
    return grid


def _hillshade_jpeg(image: Image.Image, zoom: int, lat: float) -> bytes:
    grid = _elevation(image)
    cell = 156543.03392 * math.cos(math.radians(lat)) / (2**zoom)
    padded = np.pad(grid, 1, mode="edge")
    a = padded[:-2, :-2]
    b = padded[:-2, 1:-1]
    c = padded[:-2, 2:]
    d = padded[1:-1, :-2]
    f = padded[1:-1, 2:]
    g = padded[2:, :-2]
    h = padded[2:, 1:-1]
    i = padded[2:, 2:]
    dzdx = ((c + 2 * f + i) - (a + 2 * d + g)) / (8 * cell)
    dzdy = ((g + 2 * h + i) - (a + 2 * b + c)) / (8 * cell)
    slope = np.arctan(np.hypot(dzdx, dzdy))
    aspect = np.arctan2(dzdy, -dzdx)
    azimuth = math.radians(315)
    altitude = math.radians(45)
    shade = np.cos(altitude) * np.cos(slope) + np.sin(altitude) * np.sin(slope) * np.cos(azimuth - aspect)
    shade = np.clip(shade, 0.0, 1.0)
    value = (70 + 175 * shade).astype(np.uint8)
    rgb = np.stack(
        [value, (value.astype(np.float64) * 0.97).astype(np.uint8), (value.astype(np.float64) * 0.90).astype(np.uint8)],
        axis=-1,
    )
    buffer = BytesIO()
    Image.fromarray(rgb, "RGB").save(buffer, format="JPEG", quality=72, optimize=True)
    return buffer.getvalue()


def _project(px: float, py: float, width: int, height: int, bounds) -> tuple[float, float]:
    west, south, east, north = bounds
    lon = west + (px / max(width - 1, 1)) * (east - west)
    lat = north - (py / max(height - 1, 1)) * (north - south)
    return lon, lat


def _stitch(pairs: list[tuple[tuple[float, float], tuple[float, float]]]) -> list[LineString]:
    def key(point: tuple[float, float]) -> tuple[float, float]:
        return (round(point[0], 5), round(point[1], 5))

    neighbors: dict[tuple[float, float], list[int]] = defaultdict(list)
    edges: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for start, end in pairs:
        left, right = key(start), key(end)
        if left == right:
            continue
        index = len(edges)
        edges.append((left, right))
        neighbors[left].append(index)
        neighbors[right].append(index)
    used: set[int] = set()
    lines: list[LineString] = []
    for index in range(len(edges)):
        if index in used:
            continue
        used.add(index)
        left, right = edges[index]
        chain = [left, right]

        def walk(end: tuple[float, float], reverse: bool) -> None:
            current = end
            while True:
                nxt = None
                for edge_id in neighbors[current]:
                    if edge_id in used:
                        continue
                    a, b = edges[edge_id]
                    used.add(edge_id)
                    nxt = b if a == current else a
                    break
                if nxt is None or nxt == current:
                    break
                if reverse:
                    chain.insert(0, nxt)
                else:
                    chain.append(nxt)
                current = nxt

        walk(right, False)
        walk(chain[0], True)
        if len(chain) >= 2:
            lines.append(LineString(chain))
    return lines


def _contours(image: Image.Image, bounds: tuple[float, float, float, float]) -> list:
    grid = _elevation(image, step=2)
    height, width = grid.shape
    if height < 2 or width < 2:
        return []
    low = float(np.min(grid))
    high = float(np.max(grid))
    level = int(math.floor(low / CONTOUR_INTERVAL_M) * CONTOUR_INTERVAL_M)
    stop = int(math.ceil(high / CONTOUR_INTERVAL_M) * CONTOUR_INTERVAL_M)
    tile = box(*bounds)
    lines = []
    while level <= stop:
        segments: list[tuple[tuple[float, float], tuple[float, float]]] = []
        top = grid[:-1, :-1]
        right = grid[:-1, 1:]
        bottom = grid[1:, 1:]
        left = grid[1:, :-1]
        edges = (
            (top, right, 0, 0, 1, 0),
            (right, bottom, 1, 0, 1, 1),
            (bottom, left, 1, 1, 0, 1),
            (left, top, 0, 1, 0, 0),
        )
        hits: dict[tuple[int, int], list[tuple[float, float]]] = defaultdict(list)
        for first, second, ax, ay, bx, by in edges:
            cross = (first < level) != (second < level)
            if not np.any(cross):
                continue
            denom = second - first
            safe = np.where(np.abs(denom) < 1e-6, 1.0, denom)
            t = np.clip((level - first) / safe, 0.0, 1.0)
            ys, xs = np.nonzero(cross)
            for y, x in zip(ys.tolist(), xs.tolist(), strict=False):
                px = x + ax + (bx - ax) * float(t[y, x])
                py = y + ay + (by - ay) * float(t[y, x])
                hits[(int(y), int(x))].append(_project(px, py, width, height, bounds))
        for points in hits.values():
            if len(points) >= 2 and points[0] != points[1]:
                segments.append((points[0], points[1]))
        for line in _stitch(segments):
            if line.is_empty or not line.intersects(tile):
                continue
            lines.append((line, level))
        level += CONTOUR_INTERVAL_M
    return lines


def _encode_contours(features: list, bounds) -> bytes | None:
    if not features:
        return None
    encoded = [{"geometry": geom, "properties": {"elev": elev}} for geom, elev in features]
    tile = mapbox_vector_tile.encode(
        [{"name": "contours", "features": encoded}],
        default_options={"quantize_bounds": bounds, "extents": 4096},
    )
    return gzip.compress(tile, mtime=0)


def _header(min_zoom: int, max_zoom: int, compression, tile_type) -> dict:
    return {
        "min_zoom": min_zoom,
        "max_zoom": max_zoom,
        "min_lon_e7": int(NORTHERN_NM.west * 1e7),
        "min_lat_e7": int(NORTHERN_NM.south * 1e7),
        "max_lon_e7": int(NORTHERN_NM.east * 1e7),
        "max_lat_e7": int(NORTHERN_NM.north * 1e7),
        "center_lon_e7": int(-106.0 * 1e7),
        "center_lat_e7": int(35.7 * 1e7),
        "center_zoom": 8,
        "tile_compression": compression,
        "tile_type": tile_type,
        "clustered": True,
    }


def build(hillshade_path: Path, contour_path: Path, cache: Path) -> None:
    jobs = []
    for zoom in HILL_ZOOMS:
        xs, ys = _xyz_range(zoom)
        for x in xs:
            for y in ys:
                jobs.append((zoom, x, y))
    print(f"terrain tiles {len(jobs)}", flush=True)
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = [pool.submit(_download, zoom, x, y, cache) for zoom, x, y in jobs]
        done = 0
        for future in as_completed(futures):
            future.result()
            done += 1
            if done % 40 == 0 or done == len(jobs):
                print(f"  downloaded {done}/{len(jobs)}", flush=True)
    hillshade_path.parent.mkdir(parents=True, exist_ok=True)
    if hillshade_path.exists():
        hillshade_path.unlink()
    if contour_path.exists():
        contour_path.unlink()
    hill_meta = {
        "name": "Pilgrim Atlas hillshade",
        "format": "jpeg",
        "attribution": "Hillshade derived from Mapzen Terrain Tiles, CC BY 4.0 and ODbL",
    }
    contour_meta = {
        "name": "Pilgrim Atlas contours",
        "format": "pbf",
        "attribution": "100 m contours derived from Mapzen Terrain Tiles, CC BY 4.0 and ODbL",
        "vector_layers": [{"id": "contours", "fields": {"elev": "Number"}}],
    }
    with write(str(hillshade_path)) as hill_writer, write(str(contour_path)) as contour_writer:
        for index, (zoom, x, y) in enumerate(jobs):
            image = Image.open(_download(zoom, x, y, cache))
            bounds = _tile_bounds(zoom, x, y)
            mid_lat = (bounds[1] + bounds[3]) / 2
            hill_writer.write_tile(zxy_to_tileid(zoom, x, y), _hillshade_jpeg(image, zoom, mid_lat))
            if zoom in CONTOUR_ZOOMS:
                encoded = _encode_contours(_contours(image, bounds), bounds)
                if encoded:
                    contour_writer.write_tile(zxy_to_tileid(zoom, x, y), encoded)
            if index and index % 20 == 0:
                print(f"  shaded {index}/{len(jobs)}", flush=True)
        hill_writer.finalize(_header(7, 11, Compression.NONE, TileType.JPEG), hill_meta)
        contour_writer.finalize(_header(10, 11, Compression.GZIP, TileType.MVT), contour_meta)
    print(f"hillshade {hillshade_path.stat().st_size} contours {contour_path.stat().st_size}", flush=True)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    resources = root / "Sources" / "PilgrimAtlas" / "Resources"
    cache = Path.home() / ".cache" / "pilgrim-atlas" / "terrarium"
    build(
        resources / "northern-new-mexico-hillshade.pmtiles",
        resources / "northern-new-mexico-contours.pmtiles",
        cache,
    )
