"""Clip, simplify, and reproject geometries into GeoJSON."""

import shapely
from shapely.geometry import mapping, shape
from shapely.ops import transform as shp_transform

from .bbox import BBox


def _round_coords(node, digits: int):
    if isinstance(node, (list, tuple)):
        if len(node) >= 2 and isinstance(node[0], (int, float)) and not isinstance(node[0], bool):
            return [round(float(node[0]), digits), round(float(node[1]), digits)]
        return [_round_coords(item, digits) for item in node]
    return node


def to_features(geom, bbox: BBox, tolerance: float) -> list[dict]:
    if geom is None:
        return []
    try:
        if geom.is_empty:
            return []
        geom = shapely.make_valid(geom)
    except Exception:
        return []
    clipped = shapely.clip_by_rect(geom, bbox.west, bbox.south, bbox.east, bbox.north)
    if clipped.is_empty:
        return []
    simplified = clipped.simplify(tolerance, preserve_topology=True)
    if simplified.is_empty:
        return []
    parts = []
    if simplified.geom_type == "GeometryCollection":
        geoms = list(simplified.geoms)
    elif simplified.geom_type.startswith("Multi"):
        geoms = list(simplified.geoms)
    else:
        geoms = [simplified]
    for part in geoms:
        if part.is_empty or part.geom_type not in {"Polygon", "MultiPolygon", "LineString", "MultiLineString"}:
            continue
        if part.geom_type == "Polygon" and part.area < 1e-8:
            continue
        geo = mapping(part)
        geo["coordinates"] = _round_coords(geo["coordinates"], 5)
        parts.append(geo)
    return parts


def reproject_shape(shp_geom, transformer) -> object:
    geom = shape(shp_geom.__geo_interface__)
    return shp_transform(transformer.transform, geom)


def shape_from_geojson(geometry: dict):
    return shape(geometry)
