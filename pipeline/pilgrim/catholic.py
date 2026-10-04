"""Catholic highlight. Other worship stays visible."""

_CATHOLIC = {
    "roman_catholic",
    "catholic",
    "greek_catholic",
    "ruthenian_catholic",
    "byzantine_catholic",
}


def normalize_denomination(value: str | None) -> str:
    if not value:
        return ""
    return value.strip().lower().replace(" ", "_").replace("-", "_")


def is_catholic_denomination(value: str | None) -> bool:
    name = normalize_denomination(value)
    if not name or "anglican" in name:
        return False
    if name in _CATHOLIC:
        return True
    return "byzantine" in name and "catholic" in name


def worship_class(tags: dict) -> str:
    """Return catholic, other_worship, landmark, or skip."""
    amenity = (tags.get("amenity") or "").strip().lower()
    tourism = (tags.get("tourism") or "").strip().lower()
    historic = (tags.get("historic") or "").strip().lower()
    place = (tags.get("place") or "").strip().lower()
    denomination = tags.get("denomination")
    if amenity == "place_of_worship":
        if is_catholic_denomination(denomination):
            return "catholic"
        return "other_worship"
    landmark_tourism = {"attraction", "museum", "viewpoint", "gallery", "artwork"}
    landmark_historic = {
        "monument",
        "memorial",
        "church",
        "monastery",
        "wayside_shrine",
        "ruins",
        "archaeological_site",
        "shrine",
    }
    if tourism in landmark_tourism or historic in landmark_historic or place == "square":
        return "landmark"
    if amenity == "monastery":
        return "landmark"
    return "skip"
