"""Interfeys tili: skriptlar uchun umumiy tarjima funksiyasi."""
import json
import os
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "falcon"
_catalog = None


def language():
    chosen = None
    for name in ("settings.json", "defaults.json"):
        try:
            chosen = json.loads((CONFIG / name).read_text() or "{}").get("appearance", {}).get("language")
        except (OSError, ValueError, AttributeError):
            continue
        if chosen:
            break
    if chosen in ("en", "ru"):
        return chosen
    env = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    return "ru" if env.startswith("ru") else "en"


def tr(text, **values):
    global _catalog
    result = text
    if language() == "ru":
        if _catalog is None:
            try:
                _catalog = json.loads((CONFIG / "i18n-ru.json").read_text())
            except (OSError, ValueError):
                _catalog = {}
        result = _catalog.get(text, text)
    return result.format(**values) if values else result
