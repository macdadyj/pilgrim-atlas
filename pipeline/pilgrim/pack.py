"""SQLite pack. Code stays MIT; this database is not MIT."""

import json
import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE places (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    catholic INTEGER NOT NULL,
    denomination TEXT NOT NULL DEFAULT '',
    lat REAL NOT NULL,
    lon REAL NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    opening_hours TEXT NOT NULL DEFAULT '',
    service_times TEXT NOT NULL DEFAULT '',
    mass_times TEXT NOT NULL DEFAULT '',
    confession_times TEXT NOT NULL DEFAULT '',
    access TEXT NOT NULL DEFAULT '',
    parking TEXT NOT NULL DEFAULT '',
    wheelchair TEXT NOT NULL DEFAULT '',
    website TEXT NOT NULL DEFAULT '',
    wikipedia TEXT NOT NULL DEFAULT '',
    wikidata TEXT NOT NULL DEFAULT '',
    image TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL,
    source_date TEXT NOT NULL
);
CREATE TABLE trails (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    access TEXT NOT NULL DEFAULT '',
    geojson TEXT NOT NULL,
    source TEXT NOT NULL,
    source_date TEXT NOT NULL
);
CREATE TABLE land (
    id INTEGER PRIMARY KEY,
    kind TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    manager TEXT NOT NULL DEFAULT '',
    pub_access TEXT NOT NULL DEFAULT '',
    geojson TEXT NOT NULL,
    source TEXT NOT NULL,
    source_date TEXT NOT NULL
);
CREATE TABLE links (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    note TEXT NOT NULL
);
CREATE INDEX places_name ON places(name);
"""

def _place_value(place: dict, field: str):
    value = place.get(field, "")
    if field == "catholic":
        return 1 if value else 0
    if isinstance(value, float):
        return value
    return "" if value is None else value


PLACE_FIELDS = (
    "name",
    "category",
    "catholic",
    "denomination",
    "lat",
    "lon",
    "description",
    "address",
    "opening_hours",
    "service_times",
    "mass_times",
    "confession_times",
    "access",
    "parking",
    "wheelchair",
    "website",
    "wikipedia",
    "wikidata",
    "image",
    "source",
    "source_date",
)


def write_sqlite(path: Path, meta: dict, places: list[dict], trails: list[dict], lands: list[dict], links: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    connection = sqlite3.connect(path)
    try:
        connection.executescript(SCHEMA)
        connection.executemany(
            "INSERT INTO meta (key, value) VALUES (?, ?)",
            [(key, str(value)) for key, value in sorted(meta.items())],
        )
        connection.executemany(
            f"INSERT INTO places ({', '.join(PLACE_FIELDS)}) VALUES ({', '.join('?' for _ in PLACE_FIELDS)})",
            [[_place_value(place, field) for field in PLACE_FIELDS] for place in places],
        )
        connection.executemany(
            "INSERT INTO trails (name, access, geojson, source, source_date) VALUES (?, ?, ?, ?, ?)",
            [
                (
                    trail["name"],
                    trail.get("access") or "",
                    json.dumps(trail["geometry"], separators=(",", ":")),
                    trail["source"],
                    trail["source_date"],
                )
                for trail in trails
            ],
        )
        connection.executemany(
            "INSERT INTO land (kind, name, manager, pub_access, geojson, source, source_date) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    land["kind"],
                    land.get("name") or "",
                    land.get("manager") or "",
                    land.get("pub_access") or "",
                    json.dumps(land["geometry"], separators=(",", ":")),
                    land["source"],
                    land["source_date"],
                )
                for land in lands
            ],
        )
        connection.executemany(
            "INSERT INTO links (title, url, note) VALUES (?, ?, ?)",
            [(link["title"], link["url"], link["note"]) for link in links],
        )
        connection.commit()
    finally:
        connection.close()


def column_names(path: Path) -> set[str]:
    connection = sqlite3.connect(path)
    try:
        names = set()
        for table in ("meta", "places", "trails", "land", "links"):
            for row in connection.execute(f"PRAGMA table_info({table})"):
                names.add(row[1].lower())
        return names
    finally:
        connection.close()
