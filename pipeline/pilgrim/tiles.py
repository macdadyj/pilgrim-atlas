"""Write a PMTiles archive of vector tiles for the northern pack."""

import gzip
import math
from collections import defaultdict

import mapbox_vector_tile
from pmtiles.tile import Compression, TileType, zxy_to_tileid
from pmtiles.writer import write
from shapely.geometry import box, shape
from shapely.validation import make_valid

from .bbox import NORTHERN_NM


def _tile_xy(lon: float, lat: float, zoom: int) -> tuple[int, int]:
    limited = max(min(lat, 85.05112878), -85.05112878)
    n = 2**zoom
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(limited)
    y = int((1.0 - math.log(math.tan(lat_rad) + 1 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
    limit = n - 1
    return max(0, min(limit, x)), max(0, min(limit, y))


def _tile_bounds(zoom: int, x: int, y: int) -> tuple[float, float, float, float]:
    n = 2**zoom

    def lat_of(row: int) -> float:
        merc = math.pi * (1 - 2 * row / n)
        return math.degrees(math.atan(math.sinh(merc)))

    west = x / n * 360.0 - 180.0
    east = (x + 1) / n * 360.0 - 180.0
    return west, lat_of(y + 1), east, lat_of(y)


def _bbox(geometry: dict) -> tuple[float, float, float, float]:
    geom = shape(geometry)
    return geom.bounds


def _add(buckets, layer: str, geometry: dict, props: dict, zooms: range) -> None:
    min_lon, min_lat, max_lon, max_lat = _bbox(geometry)
    for zoom in zooms:
        x0, y0 = _tile_xy(min_lon, max_lat, zoom)
        x1, y1 = _tile_xy(max_lon, min_lat, zoom)
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                buckets[(zoom, x, y)][layer].append((geometry, props))


_LAYER_TYPES = {
    "land": {"Polygon", "MultiPolygon"},
    "parcels": {"Polygon", "MultiPolygon"},
    "trails": {"LineString", "MultiLineString"},
    "places": {"Point", "MultiPoint"},
}


def _pieces(geom):
    if geom is None or geom.is_empty:
        return
    kind = geom.geom_type
    if kind == "GeometryCollection":
        for part in geom.geoms:
            yield from _pieces(part)
        return
    if kind in {"Polygon", "MultiPolygon", "LineString", "MultiLineString", "Point", "MultiPoint"}:
        yield geom


def _clip_parts(geometry, bounds, allowed: set[str]) -> list:
    try:
        geom = shape(geometry) if isinstance(geometry, dict) else geometry
        geom = make_valid(geom)
        tile = box(*bounds)
        if not geom.intersects(tile):
            return []
        inside = (
            geom.bounds[0] >= bounds[0]
            and geom.bounds[1] >= bounds[1]
            and geom.bounds[2] <= bounds[2]
            and geom.bounds[3] <= bounds[3]
        )
        clipped = geom if inside else make_valid(geom.intersection(tile))
    except Exception:
        return []
    parts = []
    for part in _pieces(clipped):
        if part.geom_type not in allowed or part.is_empty:
            continue
        if part.geom_type in {"Polygon", "MultiPolygon"} and part.area == 0:
            continue
        parts.append(part)
    return parts


def _encodable(layer_name: str, features: list, bounds) -> tuple[list, int]:
    options = {"quantize_bounds": bounds, "extents": 4096}
    try:
        mapbox_vector_tile.encode([{"name": layer_name, "features": features}], default_options=options)
        return features, 0
    except ValueError:
        kept = []
        for feature in features:
            try:
                mapbox_vector_tile.encode(
                    [{"name": layer_name, "features": [feature]}],
                    default_options=options,
                )
            except ValueError:
                continue
            kept.append(feature)
        return kept, len(features) - len(kept)


def write_pmtiles(path, lands, trails, places, parcels) -> None:
    buckets = defaultdict(lambda: {"land": [], "trails": [], "places": [], "parcels": []})
    for land in lands:
        _add(
            buckets,
            "land",
            land["geometry"],
            {"kind": land["kind"], "name": land.get("name") or ""},
            range(6, 12),
        )
    for trail in trails:
        _add(
            buckets,
            "trails",
            trail["geometry"],
            {"name": trail.get("name") or "", "access": trail.get("access") or ""},
            range(9, 14),
        )
    for place in places:
        _add(
            buckets,
            "places",
            {"type": "Point", "coordinates": [place["lon"], place["lat"]]},
            {
                "name": place["name"],
                "catholic": 1 if place["catholic"] else 0,
                "category": place["category"],
            },
            range(8, 15),
        )
    for geometry, address in parcels:
        props = {"address": address} if address else {}
        _add(buckets, "parcels", geometry, props, range(14, 15))

    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    header = {
        "min_zoom": 6,
        "max_zoom": 14,
        "min_lon_e7": int(NORTHERN_NM.west * 1e7),
        "min_lat_e7": int(NORTHERN_NM.south * 1e7),
        "max_lon_e7": int(NORTHERN_NM.east * 1e7),
        "max_lat_e7": int(NORTHERN_NM.north * 1e7),
        "center_lon_e7": int(-106.0 * 1e7),
        "center_lat_e7": int(35.7 * 1e7),
        "center_zoom": 8,
        "tile_compression": Compression.GZIP,
        "tile_type": TileType.MVT,
        "clustered": True,
    }
    metadata = {
        "name": "Pilgrim Atlas northern New Mexico",
        "format": "pbf",
        "attribution": "© OpenStreetMap contributors",
        "vector_layers": [
            {"id": "land", "fields": {"kind": "String", "name": "String"}},
            {"id": "trails", "fields": {"name": "String", "access": "String"}},
            {"id": "places", "fields": {"name": "String", "catholic": "Number", "category": "String"}},
            {"id": "parcels", "fields": {"address": "String"}},
        ],
    }
    ordered = sorted(buckets, key=lambda zxy: zxy_to_tileid(*zxy))
    print(f"tiles to write: {len(ordered)}")
    if not ordered:
        return
    skipped = 0
    with write(str(path)) as writer:
        for index, zxy in enumerate(ordered):
            bounds = _tile_bounds(*zxy)
            layers = []
            for layer_name, features in buckets[zxy].items():
                encoded = []
                allowed = _LAYER_TYPES[layer_name]
                for geometry, props in features:
                    for part in _clip_parts(geometry, bounds, allowed):
                        encoded.append({"geometry": part, "properties": props})
                if not encoded:
                    continue
                layers.append({"name": layer_name, "features": encoded})
            if not layers:
                continue
            options = {"quantize_bounds": bounds, "extents": 4096}
            try:
                tile = mapbox_vector_tile.encode(layers, default_options=options)
            except ValueError:
                cleaned = []
                for layer in layers:
                    kept, dropped = _encodable(layer["name"], layer["features"], bounds)
                    skipped += dropped
                    if kept:
                        cleaned.append({"name": layer["name"], "features": kept})
                if not cleaned:
                    continue
                tile = mapbox_vector_tile.encode(cleaned, default_options=options)
            writer.write_tile(zxy_to_tileid(*zxy), gzip.compress(tile, mtime=0))
            if index and index % 400 == 0:
                print(f"  tiles {index}/{len(ordered)}")
        writer.finalize(header, metadata)
    if skipped:
        print(f"skipped {skipped} tile features that could not be encoded")
