"""Nearby summary: explore, trails, manager, closures."""

from dataclasses import dataclass

from .geometry import distance_to_line_m, haversine_m, line_vertices
from .land import LandHit, land_status
from .textutil import fold, sentences


@dataclass(frozen=True)
class Place:
    name: str
    category: str
    catholic: bool
    lat: float
    lon: float
    summary: str = ""


@dataclass(frozen=True)
class Trail:
    name: str
    access: str
    geometry: dict


def _access_line(access: str) -> str:
    text = sentences()
    cleaned = access.strip()
    if not cleaned:
        return text["trail_untagged"]
    return f"Tagged access={cleaned}. That tag is not permission to enter or to leave the trail."


def nearby_summary(
    lat: float,
    lon: float,
    places: list[Place],
    trails: list[Trail],
    lands: list[LandHit],
    explore_km: float = 8.0,
    trail_km: float = 3.0,
) -> dict:
    hit, land_text = land_status(lon, lat, lands)
    explore = []
    for place in places:
        meters = haversine_m(lat, lon, place.lat, place.lon)
        if meters <= explore_km * 1000:
            explore.append((meters, place))
    explore.sort(key=lambda item: item[0])
    explore_rows = []
    for meters, place in explore[:8]:
        kind = "Catholic landmark" if place.catholic else place.category.replace("_", " ")
        explore_rows.append(
            {
                "name": place.name,
                "category": kind,
                "meters": round(meters),
                "catholic": place.catholic,
            }
        )

    trail_rows = []
    for trail in trails:
        distance = distance_to_line_m(lat, lon, line_vertices(trail.geometry))
        if distance is None or distance > trail_km * 1000:
            continue
        trail_rows.append(
            {
                "name": trail.name or "Unnamed hiking route",
                "meters": round(distance),
                "access": _access_line(trail.access),
            }
        )
    trail_rows.sort(key=lambda row: row["meters"])

    closure_notes = [sentences()["closures"]]
    if hit is not None and (hit.pub_access or "").upper() == "XA":
        closure_notes.append(
            "The land record under this point maps public access as closed. That is not a live alert."
        )
    if hit is not None and hit.kind == "abq_closed":
        label = hit.name or "An Open Space unit"
        closure_notes.append(f"{label} is mapped closed to the public.")

    return {
        "land": land_text,
        "land_kind": None if hit is None else hit.kind,
        "land_source": "" if hit is None else hit.source,
        "land_source_date": "" if hit is None else hit.source_date,
        "explore": explore_rows,
        "trails": trail_rows[:6],
        "closures": closure_notes,
        "not_a_survey": sentences()["not_a_survey"],
    }


def search_names(query: str, places: list[Place], trails: list[Trail], limit: int = 30) -> list[dict]:
    needle = fold(query)
    if not needle:
        return []
    rows = []
    for place in places:
        if needle in fold(place.name):
            rows.append(
                {
                    "kind": "place",
                    "name": place.name,
                    "catholic": place.catholic,
                    "lat": place.lat,
                    "lon": place.lon,
                }
            )
    for trail in trails:
        if needle in fold(trail.name):
            rows.append({"kind": "trail", "name": trail.name, "catholic": False})
    return rows[:limit]
