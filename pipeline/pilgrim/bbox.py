"""Northern New Mexico box from the feasibility coverage check."""

from dataclasses import dataclass


@dataclass(frozen=True)
class BBox:
    south: float = 34.80
    west: float = -107.30
    north: float = 37.05
    east: float = -104.70

    def contains(self, lon: float, lat: float) -> bool:
        return self.west <= lon <= self.east and self.south <= lat <= self.north

    def as_esri_envelope(self) -> str:
        return f"{self.west},{self.south},{self.east},{self.north}"


NORTHERN_NM = BBox()
