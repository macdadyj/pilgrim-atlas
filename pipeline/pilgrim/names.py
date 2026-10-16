"""Drop private owner names before they reach the pack."""

import re

_OWNER_KEY = re.compile(r"owner", re.IGNORECASE)
_PERSON_WORDS = re.compile(r"[A-Za-z][A-Za-z'.-]*")
_PLACE_OR_ORG = (
    "bureau",
    "service",
    "department",
    "county",
    "city",
    "state",
    "united",
    "national",
    "forest",
    "park",
    "district",
    "tribe",
    "tribal",
    "pueblo",
    "nation",
    "university",
    "college",
    "school",
    "office",
    "blm",
    "nps",
    "usda",
    "conservancy",
    "foundation",
    "society",
    "church",
    "diocese",
    "parish",
    "authority",
    "commission",
    "agency",
    "reservation",
    "monument",
    "refuge",
    "wilderness",
    "trust",
    "range",
    "canyon",
    "mesa",
    "trail",
    "mountain",
    "creek",
    "river",
    "lake",
    "experimental",
    "recreation",
    "preserve",
    "reserve",
    "cemetery",
    "chapel",
    "shrine",
    "plaza",
)


def is_owner_field(key: str) -> bool:
    return _OWNER_KEY.search(key.strip()) is not None


def strip_owner_fields(props: dict) -> dict:
    """Remove owner-name columns. Agency fields such as Own_Name do not match."""
    cleaned = {}
    for key, value in props.items():
        if is_owner_field(str(key)):
            continue
        cleaned[key] = value
    return cleaned


def looks_like_private_person(value: str) -> bool:
    text = value.strip()
    if not text or text.upper() in {"UNK", "UNKNOWN", "PVT", "PRIVATE", "NONE"}:
        return False
    low = text.lower()
    if any(hint in low for hint in _PLACE_OR_ORG):
        return False
    words = _PERSON_WORDS.findall(text)
    if any(ch.isdigit() for ch in text):
        return False
    return 2 <= len(words) <= 4


def public_label(value: str | None, *, own_type: str | None = None) -> str:
    """Label safe to show. Private-owner values become an empty string."""
    if value is None:
        return ""
    text = str(value).strip()
    if not text or text.upper() in {"UNK", "UNKNOWN", "NONE"}:
        return ""
    if (own_type or "").upper() == "PVT":
        return ""
    if looks_like_private_person(text):
        return ""
    return text
