"""Statik media (fon rasmlari, mashq GIF/videolari) serverda saqlanadi — ilova hajmi kichik qoladi.

Mashq ko'rsatmasi: backend/static/exercises/<mashq_id>.gif (yoki .webp / .mp4).
Boshqa joyda (CDN) saqlansa, admin orqali mashqning image_url maydoniga to'liq URL yoziladi.
"""
from pathlib import Path
from typing import Optional

STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
EXERCISE_DIR = STATIC_DIR / "exercises"
EXTENSIONS = ("gif", "webp", "mp4")


def exercise_media_path(exercise_id: int) -> Optional[str]:
    for ext in EXTENSIONS:
        if (EXERCISE_DIR / f"{exercise_id}.{ext}").is_file():
            return f"/static/exercises/{exercise_id}.{ext}"
    return None
