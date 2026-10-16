"""Higher-zoom land tiles with rounded corners.

The main pack stops land at zoom 11. Overzooming those tiles to the plaza
makes the fills look like cut polygons. This archive carries the same land
through zoom 14, with a short round buffer so corners are not sharp spikes.
"""

import json
import sqlite3
from collections import defaultdict
from pathlib import Path

import mapbox_vector_tile
from pmtiles.tile import Compression, TileType, zxy_to_tileid
from pmtiles.writer import write
from shapely.geometry import box, shape
from shapely.validation import make_valid

from .bbox import NORTHERN_NM
from .tiles import _clip_parts, _tile_bounds, _tile_xy

ROOT = Path(__file__).resolve().parents[2]
SQLITE = ROOT / "Sources" / "PilgrimAtlas" / "Resources" / "northern-new-mexico.sqlite"
ZOOMS = range(8, 15)


def _smooth(geom):
    try:
        geom = make_valid(geom)
        rounded = geom.buffer(0.00022, resolution=2, join_style=1).buffer(-0.00022, resolution=2, join_style=1)
        if rounded.is_empty:
            return geom
        return make_valid(rounded)
    except Exception:
        return geom


def build(path: Path, sqlite_path: Path = SQLITE) -> None:
    connection = sqlite3.connect(sqlite_path)
    rows = connection.execute("SELECT kind, name, geojson FROM land").fetchall()
    connection.close()
    features = []
    for kind, name, blob in rows:
        geom = _smooth(shape(json.loads(blob)))
        if geom.is_empty:
            continue
        features.append((geom, {"kind": kind, "name": name or ""}))
    print(f"land features {len(features)}", flush=True)
    buckets: dict[tuple[int, int, int], list] = defaultdict(list)
    for geom, props in features:
        min_lon, min_lat, max_lon, max_lat = geom.bounds
        for zoom in ZOOMS:
            x0, y0 = _tile_xy(min_lon, max_lat, zoom)
            x1, y1 = _tile_xy(max_lon, min_lat, zoom)
            for x in range(min(x0, x1), max(x0, x1) + 1):
                for y in range(min(y0, y1), max(y0, y1) + 1):
                    bounds = _tile_bounds(zoom, x, y)
                    for part in _clip_parts(geom, bounds, {"Polygon", "MultiPolygon"}):
                        buckets[(zoom, x, y)].append({"geometry": part, "properties": props})
    print(f"land tiles {len(buckets)}", flush=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    header = {
        "min_zoom": 8,
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
        "name": "Pilgrim Atlas land detail",
        "format": "pbf",
        "vector_layers": [{"id": "land", "fields": {"kind": "String", "name": "String"}}],
    }
    import gzip

    with write(str(path)) as writer:
        for index, zxy in enumerate(sorted(buckets, key=lambda item: zxy_to_tileid(*item))):
            bounds = _tile_bounds(*zxy)
            tile = mapbox_vector_tile.encode(
                [{"name": "land", "features": buckets[zxy]}],
                default_options={"quantize_bounds": bounds, "extents": 4096},
            )
            writer.write_tile(zxy_to_tileid(*zxy), gzip.compress(tile, mtime=0))
            if index and index % 2000 == 0:
                print(f"  land {index}/{len(buckets)}", flush=True)
        writer.finalize(header, metadata)
    print(f"land detail {path.stat().st_size}", flush=True)


if __name__ == "__main__":
    resources = ROOT / "Sources" / "PilgrimAtlas" / "Resources"
    build(resources / "northern-new-mexico-land.pmtiles")
