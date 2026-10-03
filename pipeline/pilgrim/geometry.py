"""Small geometry helpers shared by the pack builder and the query tests."""

import math
from typing import Iterable

EARTH_M = 6371000.0


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_M * math.asin(min(1.0, math.sqrt(a)))


def _point_in_ring(lon: float, lat: float, ring: list[list[float]]) -> bool:
    inside = False
    count = len(ring)
    if count < 3:
        return False
    j = count - 1
    for i in range(count):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > lat) != (yj > lat):
            x_cross = (xj - xi) * (lat - yi) / ((yj - yi) or 1e-15) + xi
            if lon < x_cross:
                inside = not inside
        j = i
    return inside


def point_in_polygon(lon: float, lat: float, rings: list[list[list[float]]]) -> bool:
    """GeoJSON polygon rings: exterior first, then holes."""
    if not rings or not _point_in_ring(lon, lat, rings[0]):
        return False
    for hole in rings[1:]:
        if _point_in_ring(lon, lat, hole):
            return False
    return True


def point_in_geometry(lon: float, lat: float, geometry: dict) -> bool:
    kind = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if kind == "Polygon":
        return point_in_polygon(lon, lat, coords)
    if kind == "MultiPolygon":
        return any(point_in_polygon(lon, lat, rings) for rings in coords)
    return False


def bbox_of_geometry(geometry: dict) -> tuple[float, float, float, float] | None:
    xs: list[float] = []
    ys: list[float] = []

    def walk(node) -> None:
        if isinstance(node, (list, tuple)):
            if len(node) >= 2 and isinstance(node[0], (int, float)) and isinstance(node[1], (int, float)):
                xs.append(float(node[0]))
                ys.append(float(node[1]))
            else:
                for item in node:
                    walk(item)

    walk(geometry.get("coordinates"))
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def _to_xy(lat: float, lon: float, lat0: float) -> tuple[float, float]:
    x = math.radians(lon) * math.cos(math.radians(lat0)) * EARTH_M
    y = math.radians(lat) * EARTH_M
    return x, y


def distance_to_line_m(lat: float, lon: float, line: Iterable[list[float]]) -> float | None:
    points = [p for p in line if len(p) >= 2]
    if not points:
        return None
    if len(points) == 1:
        return haversine_m(lat, lon, points[0][1], points[0][0])
    best = None
    px, py = _to_xy(lat, lon, lat)
    for start, end in zip(points, points[1:]):
        ax, ay = _to_xy(start[1], start[0], lat)
        bx, by = _to_xy(end[1], end[0], lat)
        dx, dy = bx - ax, by - ay
        length_sq = dx * dx + dy * dy
        if length_sq == 0:
            dist = math.hypot(px - ax, py - ay)
        else:
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
            dist = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
        best = dist if best is None else min(best, dist)
    return best


def line_vertices(geometry: dict) -> list[list[float]]:
    kind = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if kind == "LineString":
        return coords
    if kind == "MultiLineString":
        merged: list[list[float]] = []
        for part in coords:
            merged.extend(part)
        return merged
    return []
