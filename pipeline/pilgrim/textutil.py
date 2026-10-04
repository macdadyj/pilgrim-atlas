import json
import unicodedata
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "Sources" / "PilgrimAtlasCore"


@lru_cache(maxsize=1)
def sentences() -> dict[str, str]:
    return json.loads((CORE / "sentences.json").read_text(encoding="utf-8"))


def disclaimer(name: str) -> str:
    return (CORE / name).read_text(encoding="utf-8").strip()


def fold(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value)
    stripped = "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn")
    return stripped.casefold().strip()
