import json
from pathlib import Path

from pilgrim.catholic import is_catholic_denomination, worship_class
from pilgrim.land import LandHit, grants_entry, land_sentence, land_status
from pilgrim.names import is_owner_field, looks_like_private_person, public_label, strip_owner_fields
from pilgrim.nearby import Place, Trail, nearby_summary, search_names
from pilgrim.pack import column_names, write_sqlite
from pilgrim.textutil import sentences
from pilgrim.tiles import write_pmtiles

ROOT = Path(__file__).resolve().parents[2]


def square(lon, lat, size=0.02):
    ring = [
        [lon, lat],
        [lon + size, lat],
        [lon + size, lat + size],
        [lon, lat + size],
        [lon, lat],
    ]
    return {"type": "Polygon", "coordinates": [ring]}


def hit(kind, lon, lat, **kwargs):
    return LandHit(
        kind=kind,
        name=kwargs.get("name", ""),
        manager=kwargs.get("manager", ""),
        pub_access=kwargs.get("pub_access", ""),
        source=kwargs.get("source", "test"),
        source_date=kwargs.get("source_date", "2026-10-03"),
        geometry=square(lon, lat, kwargs.get("size", 0.02)),
    )


def test_owner_fields_are_removed_and_agency_fields_stay():
    raw = {
        "OwnerName": "Jane Q. Public",
        "OWNER1": "Jane Q. Public",
        "owner": "Jane Q. Public",
        "address": "1 Old Santa Fe Trail",
        "Own_Name": "Bureau of Land Management",
        "Mang_Name": "Bureau of Land Management",
    }
    cleaned = strip_owner_fields(raw)
    blob = json.dumps(cleaned)
    assert "Jane Q. Public" not in blob
    assert cleaned["address"] == "1 Old Santa Fe Trail"
    assert cleaned["Own_Name"] == "Bureau of Land Management"
    assert is_owner_field("OwnerName")
    assert not is_owner_field("Own_Name")
    assert looks_like_private_person("Jane Q. Public")
    assert not looks_like_private_person("Bureau of Land Management")
    assert not looks_like_private_person("Jornada Experimental Range")
    assert public_label("Jane Q. Public", own_type="PVT") == ""
    assert public_label("Bureau of Land Management", own_type="FED") == "Bureau of Land Management"


def test_catholic_classification_keeps_other_worship_visible():
    assert is_catholic_denomination("roman_catholic")
    assert is_catholic_denomination("Catholic")
    assert is_catholic_denomination("greek_catholic")
    assert is_catholic_denomination("ruthenian_catholic")
    assert is_catholic_denomination("byzantine_catholic")
    assert not is_catholic_denomination("anglican_catholic")
    assert not is_catholic_denomination("catholic1")
    assert not is_catholic_denomination("baptist")
    assert worship_class({"amenity": "place_of_worship", "denomination": "roman_catholic"}) == "catholic"
    assert worship_class({"amenity": "place_of_worship", "denomination": "baptist"}) == "other_worship"
    assert worship_class({"amenity": "place_of_worship"}) == "other_worship"
    loretto = worship_class({"tourism": "museum", "name": "Loretto Chapel", "wikidata": "Q2956557"})
    assert loretto == "landmark"


def test_land_status_wording_does_not_grant_entry():
    text = sentences()
    assert text["blm"].startswith("Bureau of Land Management surface.")
    assert text["usfs_inholding"] == (
        "Inside a national-forest administrative boundary, but mapped as non-Forest Service. "
        "Do not assume you may enter."
    )
    assert "Not federal public land" in text["state_trust"]
    assert text["unknown"].startswith("No open dataset covers this point.")
    for sentence in text.values():
        assert not grants_entry(sentence)

    inside = (-106.0, 35.5)
    _, blm = land_status(*inside, [hit("blm", -106.01, 35.49)])
    assert blm == text["blm"]
    _, trust = land_status(*inside, [hit("state_trust", -106.01, 35.49)])
    assert trust == text["state_trust"]
    _, missing = land_status(-100, 40, [hit("blm", -106.01, 35.49)])
    assert missing == text["unknown"]
    _, tribal = land_status(*inside, [hit("tribal", -106.01, 35.49), hit("blm", -106.01, 35.49)])
    assert tribal == text["tribal"]
    _, inholding = land_status(*inside, [hit("usfs_inholding", -106.01, 35.49, name="Santa Fe National Forest")])
    assert text["usfs_inholding"] in inholding
    assert "Santa Fe National Forest" in inholding
    _, closed = land_status(*inside, [hit("local_protected", -106.01, 35.49, pub_access="XA")])
    assert text["pub_xa"] in closed


def test_nearby_summary_and_search():
    places = [
        Place("El Santuario de Chimayó", "worship", True, 35.99, -106.01),
        Place("Loretto Chapel", "landmark", False, 35.2, -105.9),
    ]
    trails = [
        Trail(
            "Ridge Trail",
            "",
            {"type": "LineString", "coordinates": [[-106.02, 35.98], [-106.0, 36.0]]},
        )
    ]
    lands = [hit("usfs", -106.02, 35.98, name="Carson National Forest")]
    summary = nearby_summary(35.99, -106.01, places, trails, lands, explore_km=8, trail_km=5)
    assert "Forest Service" in summary["land"]
    assert summary["explore"][0]["name"].endswith("Chimayó")
    assert summary["explore"][0]["catholic"] is True
    assert summary["trails"][0]["name"] == "Ridge Trail"
    assert "not permission" in summary["trails"][0]["access"]
    assert "not in this pack" in summary["closures"][0]
    found = search_names("chimayo", places, trails)
    assert found[0]["name"] == "El Santuario de Chimayó"


def test_named_fee_polygon_beats_unknown_proclamation():
    fee = hit("usfs", -105.85, 35.75, name="Santa Fe National Forest", pub_access="OA", size=0.02)
    proclamation = hit("usfs", -105.85, 35.75, name="Santa Fe National Forest", pub_access="UK", size=0.01)
    _, sentence = land_status(-105.845, 35.755, [fee, proclamation])
    assert "open" in sentence
    assert "unknown" not in sentence
    assert not grants_entry(sentence)
    _, only_unknown = land_status(-105.845, 35.755, [proclamation])
    assert "unknown" in only_unknown
    assert not grants_entry(only_unknown)


def test_fixture_pack_strips_owner_and_keeps_mass_tag_raw():
    places = [
        {
            "name": "Saint Edwin",
            "category": "worship",
            "catholic": True,
            "denomination": "roman_catholic",
            "lat": 35.1,
            "lon": -106.6,
            "service_times": "Su",
            "mass_times": "",
            "confession_times": "",
            "source": "OpenStreetMap",
            "source_date": "2026-10-02",
        }
    ]
    lands = [
        {
            "kind": "state_trust",
            "name": "",
            "manager": "New Mexico State Land Office",
            "pub_access": "",
            "source": "test",
            "source_date": "2026-07-31",
            "geometry": square(-106.7, 35.05, 0.05),
        }
    ]
    dest = ROOT / "pack" / "fixture-test.sqlite"
    tiles = ROOT / "pack" / "fixture-test.pmtiles"
    write_sqlite(dest, {"cabq_disclaimer": "www.cabq.gov"}, places, [], lands, [])
    assert "owner" not in "".join(column_names(dest))
    blob = dest.read_bytes()
    assert b"Jane Q. Public" not in blob
    collection = {
        "type": "GeometryCollection",
        "geometries": [
            square(-106.7, 35.05, 0.05),
            {"type": "LineString", "coordinates": [[-106.7, 35.05], [-106.65, 35.1]]},
        ],
    }
    write_pmtiles(
        tiles,
        [{**lands[0], "geometry": collection}],
        [],
        [{"name": "Saint Edwin", "catholic": True, "category": "worship", "lat": 35.07, "lon": -106.68}],
        [(square(-106.68, 35.08, 0.01), "100 Old Santa Fe Trail")],
    )
    assert tiles.stat().st_size > 0
    dest.unlink()
    tiles.unlink()
