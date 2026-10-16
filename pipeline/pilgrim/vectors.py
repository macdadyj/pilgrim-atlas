"""City of Albuquerque and State Land Office shapefiles."""

import re
from pathlib import Path

import shapefile
from pyproj import CRS, Transformer

from .names import is_owner_field, public_label, strip_owner_fields
from .prepare import reproject_shape

_ADDRESS_KEY = re.compile(r"addr|situs|site.?add|address", re.IGNORECASE)


def _transformer(prj_path: Path):
    source = CRS.from_wkt(prj_path.read_text(encoding="utf-8", errors="replace"))
    return Transformer.from_crs(source, CRS.from_epsg(4326), always_xy=True)


def read_shapefile(shp_path: Path):
    reader = shapefile.Reader(str(shp_path))
    transformer = _transformer(shp_path.with_suffix(".prj"))
    for shape, record in zip(reader.shapes(), reader.records()):
        props = strip_owner_fields(record.as_dict())
        yield props, reproject_shape(shape, transformer)


def open_space_records(shp_path: Path, source_date: str) -> list[dict]:
    rows = []
    for props, geom in read_shapefile(shp_path):
        status = (props.get("Status") or "").strip()
        kind = "abq_closed" if "closed" in status.lower() else "abq_open"
        rows.append(
            {
                "kind": kind,
                "name": public_label(props.get("Name")),
                "manager": "City of Albuquerque Open Space",
                "pub_access": "",
                "source": "City of Albuquerque Open Space shapefile",
                "source_date": source_date,
                "geometry": None,
                "_geom": geom,
                "status": status,
            }
        )
    return rows


def trust_records(shp_path: Path, source_date: str) -> list[dict]:
    rows = []
    for props, geom in read_shapefile(shp_path):
        description = (props.get("Descriptio") or "").strip()
        if description == "Subsurface":
            continue
        rows.append(
            {
                "kind": "state_trust",
                "name": "",
                "manager": "New Mexico State Land Office",
                "pub_access": "",
                "source": "New Mexico State Land Office slo_STLStatusCombined_Own",
                "source_date": source_date,
                "geometry": None,
                "_geom": geom,
                "estate": description,
            }
        )
    return rows


def _parcel_address(props: dict) -> str:
    number = props.get("STREETNUMB")
    number_text = ""
    if isinstance(number, (int, float)) and 0 < number < 90000:
        number_text = str(int(number))
    elif isinstance(number, str) and number.isdigit() and 0 < int(number) < 90000:
        number_text = str(int(number))
    street = " ".join(
        part.strip()
        for part in (
            str(props.get("STREETNAME") or ""),
            str(props.get("STREETDESI") or ""),
            str(props.get("STREETQUAD") or ""),
        )
        if part and str(part).strip()
    )
    if number_text or street:
        return " ".join(part for part in (number_text, street) if part)
    for key, value in props.items():
        if value and _ADDRESS_KEY.search(str(key)) and not is_owner_field(str(key)):
            return str(value).strip()
    return ""


def parcel_geometries(shp_path: Path) -> list[tuple[object, str]]:
    rows = []
    for index, (props, geom) in enumerate(read_shapefile(shp_path), start=1):
        rows.append((geom, _parcel_address(props)))
        if index % 40000 == 0:
            print(f"  parcels read {index}")
    return rows
