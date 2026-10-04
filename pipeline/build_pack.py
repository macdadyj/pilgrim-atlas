#!/usr/bin/env python3
"""Build the Northern New Mexico offline pack.

Downloads are cached under ~/.cache/pilgrim-atlas. Re-runs do not repeat them.
Public servers are called once per dataset, with a pause between ArcGIS pages.
"""

import json
import os
import pickle
import sys
import zipfile
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from shapely.geometry import shape

from pilgrim.arcgis import query_features
from pilgrim.bbox import NORTHERN_NM
from pilgrim.http_cache import fetch
from pilgrim.names import public_label
from pilgrim.osm_extract import extract_osm
from pilgrim.pack import write_sqlite
from pilgrim.padus import records_from_state_zip
from pilgrim.prepare import to_features
from pilgrim.textutil import ROOT, disclaimer
from pilgrim.tiles import write_pmtiles
from pilgrim.vectors import open_space_records, parcel_geometries, trust_records

CACHE = Path(os.environ.get("PILGRIM_CACHE", Path.home() / ".cache" / "pilgrim-atlas" / "downloads"))
RESOURCES = ROOT / "Sources" / "PilgrimAtlas" / "Resources"
PACK_DIR = ROOT / "pack"

USFS_URL = "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_BasicOwnership_01/MapServer/0/query"
BLM_URL = "https://gis.blm.gov/arcgis/rest/services/lands/BLM_Natl_SMA_Cached_without_PriUnk/MapServer/1/query"
NPS_URL = (
    "https://services1.arcgis.com/fBc8EJBxQRMcHlei/ArcGIS/rest/services/"
    "NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer/2/query"
)

BLM_KIND = {
    "BLM": "blm",
    "BIA": "tribal",
    "FWS": "federal_other",
    "DOD": "dod",
    "USBR": "federal_other",
    "DOE": "federal_other",
    "OTHFE": "federal_other",
    "ST": "state_other",
    "PVT": "private_mapped",
    "UND": "sma_undefined",
    "LOC": "local_protected",
}

SANTA_FE_LINKS = [
    {
        "title": "Santa Fe County GIS",
        "url": "https://www.santafecountynm.gov/growth-management/gis",
        "note": "Link only. Santa Fe County parcel polygons and owner names are not in this pack.",
    },
    {
        "title": "Santa Fe County GIS disclaimer",
        "url": "https://www.santafecountynm.gov/growth-management/gis/gisconfirm",
        "note": "The county says its datasets are reference only and not a substitute for a recorded plat.",
    },
    {
        "title": "City of Santa Fe map gallery",
        "url": "https://santafenm.gov/information-technology-telecommunications/gis/map-gallery",
        "note": "Link only. City parcel layers are not copied into this pack.",
    },
]


def _unzip(archive: Path, dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as handle:
        handle.extractall(dest)
    return dest


def _clip_rows(rows, tolerance: float) -> list[dict]:
    clipped = []
    for row in rows:
        try:
            geom = row.get("_geom")
            if geom is None and row.get("geometry"):
                geom = shape(row["geometry"])
        except Exception:
            continue
        for geometry in to_features(geom, NORTHERN_NM, tolerance):
            item = {
                "kind": row["kind"],
                "name": row.get("name") or "",
                "manager": row.get("manager") or "",
                "pub_access": row.get("pub_access") or "",
                "source": row["source"],
                "source_date": row["source_date"],
                "geometry": geometry,
            }
            clipped.append(item)
    return clipped


def _service_lands(features, mapper, tolerance: float) -> list[dict]:
    rows = []
    for feature in features:
        geometry = feature.get("geometry")
        if not geometry:
            continue
        props = feature.get("properties") or {}
        mapped = mapper(props)
        if mapped is None:
            continue
        mapped["geometry"] = geometry
        rows.append(mapped)
    return _clip_rows(rows, tolerance)


def _usfs(props: dict) -> dict | None:
    klass = (props.get("ownerclassification") or "").strip()
    if klass == "USDA FOREST SERVICE":
        kind = "usfs"
    elif klass == "NON-FS":
        kind = "usfs_inholding"
    elif klass:
        kind = "usfs_other"
    else:
        return None
    forest = public_label(props.get("forestname"))
    return {
        "kind": kind,
        "name": forest,
        "manager": "USDA Forest Service" if kind == "usfs" else "",
        "pub_access": "",
        "source": "USFS Basic Ownership (EDW_BasicOwnership_01)",
        "source_date": date.today().isoformat(),
    }


def _blm(props: dict) -> dict | None:
    code = (props.get("ADMIN_AGENCY_CODE") or "").strip().upper()
    if code in {"USFS", "NPS"}:
        return None
    kind = BLM_KIND.get(code)
    if kind is None:
        return None
    label = "" if kind == "private_mapped" else public_label(props.get("ADMIN_UNIT_NAME"))
    return {
        "kind": kind,
        "name": label,
        "manager": label,
        "pub_access": "",
        "source": "BLM Surface Management Agency",
        "source_date": date.today().isoformat(),
    }


def _nps(props: dict) -> dict | None:
    name = public_label(props.get("UNIT_NAME"))
    return {
        "kind": "nps",
        "name": name,
        "manager": "National Park Service",
        "pub_access": "",
        "source": "NPS Land Resources Division boundary",
        "source_date": date.today().isoformat(),
    }


def _try_service(name: str, url: str, params: dict, mapper, tolerance: float) -> list[dict]:
    try:
        features = query_features(url, params, CACHE / f"{name}.json")
        rows = _service_lands(features, mapper, tolerance)
        print(f"{name}: {len(rows)} polygons")
        return rows
    except Exception as error:
        print(f"{name} skipped: {error}")
        return []


def _dedupe_places(places: list[dict]) -> list[dict]:
    seen = set()
    unique = []
    for place in places:
        key = (place["name"].casefold(), round(place["lat"], 4), round(place["lon"], 4))
        if key in seen:
            continue
        seen.add(key)
        unique.append(place)
    return unique


def _clip_trails(trails: list[dict]) -> list[dict]:
    kept = []
    for trail in trails:
        parts = to_features(shape(trail["geometry"]), NORTHERN_NM, 0.0004)
        if not parts:
            continue
        geometry = parts[0] if len(parts) == 1 else {"type": "MultiLineString", "coordinates": []}
        if len(parts) > 1:
            coordinates = []
            for part in parts:
                if part["type"] == "LineString":
                    coordinates.append(part["coordinates"])
                else:
                    coordinates.extend(part["coordinates"])
            geometry = {"type": "MultiLineString", "coordinates": coordinates}
        kept.append({**trail, "geometry": geometry})
    return kept


def _write_outputs(places, trails, lands, parcels, meta) -> None:
    sqlite_path = RESOURCES / "northern-new-mexico.sqlite"
    pmtiles_path = RESOURCES / "northern-new-mexico.pmtiles"
    print("writing sqlite")
    write_sqlite(sqlite_path, meta, places, trails, lands, SANTA_FE_LINKS)
    print("writing pmtiles")
    write_pmtiles(pmtiles_path, lands, trails, places, parcels)
    manifest = {
        "sqlite_bytes": sqlite_path.stat().st_size,
        "pmtiles_bytes": pmtiles_path.stat().st_size if pmtiles_path.exists() else 0,
        **meta,
    }
    PACK_DIR.mkdir(parents=True, exist_ok=True)
    (PACK_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("sqlite", manifest["sqlite_bytes"], "pmtiles", manifest["pmtiles_bytes"])


def build() -> None:
    stage_path = CACHE / "stages" / "assembled-v1.pkl"
    if stage_path.exists():
        print("loading cached assemble", stage_path)
        with stage_path.open("rb") as handle:
            places, trails, lands, parcels, meta = pickle.load(handle)
        _write_outputs(places, trails, lands, parcels, meta)
        return

    today = date.today().isoformat()
    print("cache", CACHE)
    open_space_zip = fetch("https://abqgis01.cabq.gov/datadownload/OpenSpace.zip", CACHE / "OpenSpace.zip")
    parcels_zip = fetch("https://abqgis01.cabq.gov/datadownload/CityParcels.zip", CACHE / "CityParcels.zip")
    trust_zip = fetch(
        "https://mapservice.nmstatelands.org/GISDataDownloads/ZipFiles/slo_STLStatusCombined_Own.zip",
        CACHE / "slo_STLStatusCombined_Own.zip",
    )
    padus_zip = fetch(
        "https://www.sciencebase.gov/catalog/file/get/6759abcfd34edfeb8710a004?name=PADUS4_1_State_NM_GDB_KMZ.zip",
        CACHE / "PADUS4_1_State_NM_GDB_KMZ.zip",
        minimum_bytes=1_000_000,
    )
    pbf = fetch(
        "https://download.geofabrik.de/north-america/us/new-mexico-latest.osm.pbf",
        CACHE / "new-mexico-latest.osm.pbf",
        minimum_bytes=1_000_000,
    )

    extracted = CACHE / "extracted"
    _unzip(open_space_zip, extracted / "open-space")
    _unzip(parcels_zip, extracted / "parcels")
    _unzip(trust_zip, extracted / "trust")

    envelope = {
        "where": "1=1",
        "geometry": NORTHERN_NM.as_esri_envelope(),
        "geometryType": "esriGeometryEnvelope",
        "inSR": "4326",
        "spatialRel": "esriSpatialRelIntersects",
        "maxAllowableOffset": "0.002",
        "geometryPrecision": "5",
    }
    usfs = _try_service(
        "usfs",
        USFS_URL,
        {**envelope, "outFields": "ownerclassification,forestname"},
        _usfs,
        0.0015,
    )
    nps = _try_service(
        "nps",
        NPS_URL,
        {**envelope, "outFields": "UNIT_NAME,UNIT_TYPE,STATE", "maxAllowableOffset": "0.001"},
        _nps,
        0.001,
    )
    blm = _try_service(
        "blm",
        BLM_URL,
        {
            "where": "ADMIN_ST='NM'",
            "outFields": "ADMIN_AGENCY_CODE,ADMIN_UNIT_NAME,ADMIN_UNIT_TYPE",
            "maxAllowableOffset": "0.004",
            "geometryPrecision": "4",
        },
        _blm,
        0.0025,
    )

    padus_rows = []
    for record in records_from_state_zip(padus_zip):
        padus_rows.append(record)
    padus = _clip_rows(padus_rows, 0.0015)
    print(f"pad-us: {len(padus)} polygons")

    trust = _clip_rows(trust_records(extracted / "trust" / "slo_STLStatusCombined_Own.shp", "file dated 2026-07-31"), 0.0012)
    print(f"state trust: {len(trust)} polygons")
    space = _clip_rows(open_space_records(extracted / "open-space" / "OpenSpace.shp", f"downloaded {today}"), 0.0005)
    print(f"open space: {len(space)} polygons")

    print("reading parcels")
    parcel_shp = next((extracted / "parcels").rglob("*.shp"))
    parcel_shapes = parcel_geometries(parcel_shp)
    parcels = []
    for geom, address in parcel_shapes:
        for geometry in to_features(geom, NORTHERN_NM, 0.00012):
            parcels.append((geometry, address))
    print(f"parcels: {len(parcels)} lot polygons")

    print("reading OpenStreetMap extract")
    places, trails, osm_date = extract_osm(pbf)
    places = _dedupe_places(places)
    trails = _clip_trails(trails)
    print(f"places: {len(places)} trails: {len(trails)} osm date: {osm_date}")

    lands = usfs + nps + blm + padus + trust + space
    meta = {
        "name": "Northern New Mexico",
        "bbox": NORTHERN_NM.as_esri_envelope(),
        "built": today,
        "osm_date": osm_date,
        "place_count": str(len(places)),
        "trail_count": str(len(trails)),
        "land_count": str(len(lands)),
        "parcel_count": str(len(parcels)),
        "cabq_disclaimer": disclaimer("cabq_disclaimer.txt"),
        "slo_disclaimer": disclaimer("slo_disclaimer.txt"),
        "attribution": "© OpenStreetMap contributors",
        "skipped": "Santa Fe County and City of Santa Fe parcels are link-out only. PAD-US easements are not shipped. Subsurface-only trust land is not shown as walkable surface.",
    }
    stage_path.parent.mkdir(parents=True, exist_ok=True)
    with stage_path.open("wb") as handle:
        pickle.dump((places, trails, lands, parcels, meta), handle, protocol=pickle.HIGHEST_PROTOCOL)
    print("cached assemble", stage_path)
    _write_outputs(places, trails, lands, parcels, meta)


if __name__ == "__main__":
    build()
