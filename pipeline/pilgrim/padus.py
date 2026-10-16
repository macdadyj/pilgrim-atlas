"""Read PAD-US fee and proclamation KMZ files shipped inside the state zip."""

import io
import re
import zipfile
import xml.etree.ElementTree as ET

from .names import public_label

NS = "{http://www.opengis.net/kml/2.2}"
_PAIR = re.compile(r"<td>([^<]*)</td>\s*<td>([^<]*)</td>", re.IGNORECASE)


def _fields(description: str) -> dict[str, str]:
    return {key.strip(): value.strip() for key, value in _PAIR.findall(description or "")}


def _coords(text: str) -> list[list[float]]:
    ring = []
    for raw in text.split():
        parts = raw.split(",")
        if len(parts) < 2:
            continue
        ring.append([float(parts[0]), float(parts[1])])
    return ring


def _polygons(placemark) -> list[dict]:
    geometries = []
    for poly in placemark.findall(f".//{NS}Polygon"):
        outer_el = poly.find(f"{NS}outerBoundaryIs/{NS}LinearRing/{NS}coordinates")
        if outer_el is None or not (outer_el.text or "").strip():
            continue
        rings = [_coords(outer_el.text)]
        for inner in poly.findall(f"{NS}innerBoundaryIs/{NS}LinearRing/{NS}coordinates"):
            if inner.text:
                rings.append(_coords(inner.text))
        if len(rings[0]) >= 4:
            geometries.append({"type": "Polygon", "coordinates": rings})
    return geometries


def _kind(fields: dict[str, str]) -> str:
    own = (fields.get("Own_Type") or "").upper()
    mang = (fields.get("Mang_Type") or "").upper()
    # Unit names are not used here. "Salinas Pueblo Missions" is a National
    # Park Service unit, and the word Pueblo in a unit name is not ownership.
    blob = " ".join(fields.get(key, "") for key in ("Loc_Mang", "Mang_Name", "d_Mang_Nam")).lower()
    if own == "TRIB" or mang == "TRIB" or re.search(r"\b(tribe|tribal|pueblo|indian affairs)\b", blob):
        return "tribal"
    if "national park service" in blob or fields.get("Mang_Name") == "NPS":
        return "nps"
    if "forest service" in blob or fields.get("Mang_Name") in {"USFS", "FS"}:
        return "usfs"
    if "land management" in blob or fields.get("Mang_Name") == "BLM":
        return "blm"
    if "fish and wildlife" in blob or fields.get("Mang_Name") == "FWS":
        return "federal_other"
    if "defense" in blob or fields.get("Mang_Name") in {"DOD", "USDOD"}:
        return "dod"
    if own == "PVT" or mang == "PVT":
        return "private_mapped"
    if own == "STAT" or mang == "STAT":
        return "state_other"
    if own == "FED" or mang == "FED":
        return "federal_other"
    if own in {"UNK", ""} and mang in {"UNK", ""}:
        return "sma_undefined"
    return "local_protected"


def iter_kmz_records(kmz_bytes: bytes, source: str):
    archive = zipfile.ZipFile(io.BytesIO(kmz_bytes))
    root = ET.fromstring(archive.read("doc.kml"))
    for placemark in root.iter(f"{NS}Placemark"):
        desc_el = placemark.find(f"{NS}description")
        fields = _fields("" if desc_el is None else "".join(desc_el.itertext()))
        kind = _kind(fields)
        own_type = fields.get("Own_Type")
        name = public_label(fields.get("Unit_Nm") or fields.get("Loc_Nm"), own_type=own_type)
        manager = public_label(fields.get("Loc_Mang") or fields.get("d_Mang_Nam"), own_type=own_type)
        if kind == "private_mapped":
            name = ""
            manager = ""
        for geometry in _polygons(placemark):
            yield {
                "kind": kind,
                "name": name,
                "manager": manager,
                "pub_access": (fields.get("Pub_Access") or "").upper(),
                "source": source,
                "source_date": "PAD-US 4.1 file dated 2025-03-26",
                "geometry": geometry,
            }


def records_from_state_zip(zip_path) -> list[dict]:
    archive = zipfile.ZipFile(zip_path)
    layers = [
        ("PADUS4_1Fee_StateNM.kmz", "USGS PAD-US 4.1 fee"),
        ("PADUS4_1Proclamation_StateNM.kmz", "USGS PAD-US 4.1 proclamation"),
    ]
    rows = []
    for member, source in layers:
        rows.extend(iter_kmz_records(archive.read(member), source))
    return rows
