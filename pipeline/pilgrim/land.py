"""Land-status wording. A polygon is not permission to enter."""

from dataclasses import dataclass

from .geometry import bbox_of_geometry, point_in_geometry
from .textutil import sentences

RANK = {
    "tribal": 0,
    "nps": 1,
    "usfs": 2,
    "usfs_inholding": 3,
    "usfs_other": 3,
    "blm": 4,
    "dod": 5,
    "federal_other": 5,
    "state_trust": 6,
    "state_other": 7,
    "abq_closed": 8,
    "abq_open": 9,
    "local_protected": 10,
    "private_mapped": 11,
    "sma_undefined": 12,
}

PUB_KEYS = {"OA": "pub_oa", "RA": "pub_ra", "XA": "pub_xa", "UK": "pub_uk"}


@dataclass(frozen=True)
class LandHit:
    kind: str
    name: str
    manager: str
    pub_access: str
    source: str
    source_date: str
    geometry: dict

    @property
    def bbox(self) -> tuple[float, float, float, float] | None:
        return bbox_of_geometry(self.geometry)

    @property
    def rank(self) -> int:
        return RANK.get(self.kind, 50)


def land_sentence(hit: LandHit | None) -> str:
    text = sentences()
    if hit is None:
        return text["unknown"]
    base = text.get(hit.kind, text["unknown"])
    label = hit.name.strip() or hit.manager.strip()
    sentence = f"{label}. {base}" if label else base
    pub = PUB_KEYS.get((hit.pub_access or "").upper())
    if pub:
        sentence = f"{sentence} {text[pub]}"
    return sentence


def land_status(lon: float, lat: float, hits: list[LandHit]) -> tuple[LandHit | None, str]:
    containing: list[LandHit] = []
    for hit in hits:
        box = hit.bbox
        if box is None:
            continue
        min_lon, min_lat, max_lon, max_lat = box
        if lon < min_lon or lon > max_lon or lat < min_lat or lat > max_lat:
            continue
        if point_in_geometry(lon, lat, hit.geometry):
            containing.append(hit)
    if not containing:
        return None, land_sentence(None)
    containing.sort(key=lambda hit: (hit.rank, _area(hit)))
    winner = containing[0]
    return winner, land_sentence(winner)


def _area(hit: LandHit) -> float:
    box = hit.bbox
    if box is None:
        return 1e9
    min_lon, min_lat, max_lon, max_lat = box
    return max(0.0, (max_lon - min_lon) * (max_lat - min_lat))


def grants_entry(sentence: str) -> bool:
    """True when wording would tell someone they may go in. Used by tests."""
    lowered = sentence.lower()
    banned = (
        "you can enter",
        "you can go here",
        "entry is allowed",
        "permission to enter is granted",
        "public land you can",
    )
    return any(phrase in lowered for phrase in banned)
