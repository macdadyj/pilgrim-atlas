"""Places and hiking routes from a Geofabrik PBF. Not from Overpass."""

from pathlib import Path

import osmium

from .bbox import NORTHERN_NM
from .catholic import worship_class
from .names import strip_owner_fields


def _tags(item) -> dict[str, str]:
    return strip_owner_fields({tag.k: tag.v for tag in item.tags})


def _address(tags: dict[str, str]) -> str:
    line = " ".join(part for part in (tags.get("addr:housenumber"), tags.get("addr:street")) if part)
    city = ", ".join(
        part for part in (tags.get("addr:city"), tags.get("addr:state"), tags.get("addr:postcode")) if part
    )
    return ", ".join(part for part in (line, city) if part)


def _optional(tags: dict[str, str], key: str) -> str:
    return (tags.get(key) or "").strip()


def place_from_tags(tags: dict[str, str], lat: float, lon: float, source_date: str) -> dict | None:
    if not NORTHERN_NM.contains(lon, lat):
        return None
    klass = worship_class(tags)
    if klass == "skip":
        return None
    name = (tags.get("name") or "").strip()
    if not name and klass == "landmark":
        return None
    if not name:
        name = "Unnamed place of worship"
    photo = _optional(tags, "image") or _optional(tags, "wikimedia_commons")
    return {
        "name": name,
        "category": "landmark" if klass == "landmark" else "worship",
        "catholic": klass == "catholic",
        "denomination": _optional(tags, "denomination"),
        "lat": round(lat, 6),
        "lon": round(lon, 6),
        "description": _optional(tags, "description")[:600],
        "address": _address(tags),
        "opening_hours": _optional(tags, "opening_hours"),
        "service_times": _optional(tags, "service_times"),
        "mass_times": _optional(tags, "mass_times"),
        "confession_times": _optional(tags, "confession_times"),
        "access": _optional(tags, "access"),
        "parking": _optional(tags, "parking"),
        "wheelchair": _optional(tags, "wheelchair"),
        "website": _optional(tags, "website") or _optional(tags, "contact:website"),
        "wikipedia": _optional(tags, "wikipedia"),
        "wikidata": _optional(tags, "wikidata"),
        "image": photo,
        "source": "OpenStreetMap",
        "source_date": source_date,
    }


def pbf_timestamp(path: Path) -> str:
    reader = osmium.io.Reader(str(path))
    try:
        header = reader.header()
        for key in ("timestamp", "osmosis_replication_timestamp"):
            value = header.get(key)
            if value:
                return str(value)
    finally:
        reader.close()
    return ""


class _Index(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.routes = []
        self.place_relations = []
        self.way_ids: set[int] = set()

    def relation(self, relation):
        tags = _tags(relation)
        way_ids = [member.ref for member in relation.members if member.type == "w"]
        if tags.get("route") == "hiking":
            self.routes.append(
                {
                    "name": (tags.get("name") or "").strip(),
                    "access": (tags.get("access") or tags.get("foot") or "").strip(),
                    "way_ids": way_ids,
                }
            )
            self.way_ids.update(way_ids)
        elif worship_class(tags) != "skip":
            self.place_relations.append({"tags": tags, "way_ids": way_ids})
            self.way_ids.update(way_ids)


class _Geometries(osmium.SimpleHandler):
    def __init__(self, wanted: set[int], source_date: str):
        super().__init__()
        self.wanted = wanted
        self.source_date = source_date
        self.places = []
        self.ways: dict[int, list[list[float]]] = {}

    def node(self, node):
        if not node.location.valid():
            return
        record = place_from_tags(_tags(node), node.location.lat, node.location.lon, self.source_date)
        if record:
            self.places.append(record)

    def way(self, way):
        coords = []
        for node in way.nodes:
            if node.location.valid():
                coords.append([round(node.lon, 6), round(node.lat, 6)])
        if len(coords) < 2:
            return
        if way.id in self.wanted:
            self.ways[way.id] = coords
        record = place_from_tags(
            _tags(way),
            sum(point[1] for point in coords) / len(coords),
            sum(point[0] for point in coords) / len(coords),
            self.source_date,
        )
        if record:
            self.places.append(record)


def _line(way_lists: list[list[list[float]]]) -> dict | None:
    if not way_lists:
        return None
    if len(way_lists) == 1:
        return {"type": "LineString", "coordinates": way_lists[0]}
    return {"type": "MultiLineString", "coordinates": way_lists}


def extract_osm(path: Path) -> tuple[list[dict], list[dict], str]:
    source_date = pbf_timestamp(path)
    index = _Index()
    index.apply_file(str(path), locations=False)
    geometries = _Geometries(index.way_ids, source_date)
    geometries.apply_file(str(path), locations=True)
    for relation in index.place_relations:
        points = []
        for way_id in relation["way_ids"]:
            points.extend(geometries.ways.get(way_id, []))
        if not points:
            continue
        record = place_from_tags(
            relation["tags"],
            sum(point[1] for point in points) / len(points),
            sum(point[0] for point in points) / len(points),
            source_date,
        )
        if record:
            geometries.places.append(record)
    trails = []
    for route in index.routes:
        parts = [geometries.ways[way_id] for way_id in route["way_ids"] if way_id in geometries.ways]
        geometry = _line(parts)
        if geometry is None:
            continue
        trails.append(
            {
                "name": route["name"] or "Unnamed hiking route",
                "access": route["access"],
                "geometry": geometry,
                "source": "OpenStreetMap",
                "source_date": source_date,
            }
        )
    return geometries.places, trails, source_date
