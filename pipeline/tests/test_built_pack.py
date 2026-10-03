"""Checks against the pack produced by pipeline/build_pack.py."""

import json
import sqlite3
from pathlib import Path

import pytest
from shapely.geometry import shape

from pilgrim.catholic import is_catholic_denomination
from pilgrim.land import LandHit, grants_entry, land_status
from pilgrim.names import is_owner_field, looks_like_private_person
from pilgrim.textutil import disclaimer, sentences

ROOT = Path(__file__).resolve().parents[2]
SQLITE = ROOT / "Sources" / "PilgrimAtlas" / "Resources" / "northern-new-mexico.sqlite"
PMTILES = ROOT / "Sources" / "PilgrimAtlas" / "Resources" / "northern-new-mexico.pmtiles"


def _connect():
    if not SQLITE.exists():
        pytest.skip("northern-new-mexico.sqlite is not built yet")
    return sqlite3.connect(SQLITE)


def test_pack_has_no_owner_columns_and_keeps_the_city_disclaimer():
    connection = _connect()
    try:
        columns = set()
        for table in ("meta", "places", "trails", "land", "links"):
            for row in connection.execute(f"PRAGMA table_info({table})"):
                columns.add(row[1])
        assert not any(is_owner_field(name) for name in columns)
        meta = dict(connection.execute("SELECT key, value FROM meta"))
        assert meta["cabq_disclaimer"] == disclaimer("cabq_disclaimer.txt")
        assert "\u2019" in meta["cabq_disclaimer"]
        assert meta["slo_disclaimer"] == disclaimer("slo_disclaimer.txt")
        assert int(meta["place_count"]) > 100
        assert int(meta["land_count"]) > 100
        assert int(meta["parcel_count"]) > 1000
        blob = " ".join(meta.values()).lower()
        assert "owner name" not in blob
    finally:
        connection.close()


def test_pack_places_trails_and_link_out():
    connection = _connect()
    try:
        def names(like: str) -> list[tuple]:
            return connection.execute(
                "SELECT name, category, catholic, denomination, mass_times, confession_times FROM places WHERE name LIKE ? COLLATE NOCASE",
                (like,),
            ).fetchall()

        chimayo = names("%Chimay%")
        assert chimayo, "expected a Chimayó place from OpenStreetMap"
        loretto = names("%Loretto%")
        assert loretto, "expected Loretto Chapel to stay in the pack"
        for name, category, catholic, denomination, _mass, _confession in loretto:
            if category == "landmark" and not is_catholic_denomination(denomination):
                assert catholic == 0, name
        assert names("%San Miguel%")
        cathedral = names("%Cathedral%") + names("%St. Francis%") + names("%Saint Francis%")
        assert cathedral

        catholic_rows = connection.execute(
            "SELECT name, denomination FROM places WHERE catholic = 1"
        ).fetchall()
        assert catholic_rows, "expected some Catholic places of worship"
        for name, denomination in catholic_rows:
            assert is_catholic_denomination(denomination), name
        anglican = connection.execute(
            "SELECT catholic FROM places WHERE lower(denomination) LIKE '%anglican%'"
        ).fetchall()
        assert all(row[0] == 0 for row in anglican)

        invented = connection.execute(
            "SELECT name FROM places WHERE mass_times = 'Sunday Mass' OR confession_times = 'Saturday confession'"
        ).fetchall()
        assert invented == []

        links = connection.execute("SELECT title, url, note FROM links").fetchall()
        urls = " ".join(row[1] for row in links)
        notes = " ".join(row[2] for row in links)
        assert "santafecountynm.gov" in urls
        assert "not in this pack" in notes.lower() or "not copied" in notes.lower()
        assert connection.execute("SELECT COUNT(*) FROM trails").fetchone()[0] > 0
    finally:
        connection.close()


def test_pack_land_wording_and_blank_private_names():
    connection = _connect()
    try:
        counts = dict(connection.execute("SELECT kind, COUNT(*) FROM land GROUP BY kind"))
        for kind in ("usfs", "nps", "blm", "state_trust", "abq_open"):
            assert counts.get(kind, 0) > 0, kind
        private = connection.execute(
            "SELECT name, manager FROM land WHERE kind = 'private_mapped'"
        ).fetchall()
        assert private, "expected private surface polygons with names removed"
        assert all(name == "" and manager == "" for name, manager in private)

        labeled = connection.execute(
            "SELECT kind, name, manager FROM land WHERE name != '' OR manager != ''"
        ).fetchall()
        for kind, name, manager in labeled:
            assert not looks_like_private_person(name), (kind, name)
            assert not looks_like_private_person(manager), (kind, manager)

        row = connection.execute(
            "SELECT name, manager, pub_access, geojson, source, source_date FROM land WHERE kind = 'state_trust' LIMIT 1"
        ).fetchone()
        geometry = json.loads(row[3])
        polygon = shape(geometry)
        point = polygon.representative_point()
        hit = LandHit(
            kind="state_trust",
            name=row[0],
            manager=row[1],
            pub_access=row[2],
            source=row[4],
            source_date=row[5],
            geometry=geometry,
        )
        winner, trust_sentence = land_status(point.x, point.y, [hit])
        assert winner is not None and winner.kind == "state_trust"
        assert "Not federal public land" in trust_sentence
        assert "permit" in trust_sentence
        assert not grants_entry(trust_sentence)
        _unknown, unknown_sentence = land_status(0, 0, [hit])
        assert unknown_sentence == sentences()["unknown"]
        assert not grants_entry(unknown_sentence)
        assert "federal public land" not in unknown_sentence
    finally:
        connection.close()


def test_pmtiles_archive_exists():
    if not PMTILES.exists():
        pytest.skip("northern-new-mexico.pmtiles is not built yet")
    header = PMTILES.read_bytes()[:16]
    assert header[:7] == b"PMTiles"
    assert PMTILES.stat().st_size > 10_000
