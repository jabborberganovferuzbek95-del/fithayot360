"""Mini-migratsiya: mavjud jadvalga yangi (nullable) ustunlarni qo'shadi. Ma'lumotlar saqlanadi.
Katta o'zgarishlar uchun baribir Alembic tavsiya etiladi."""
from sqlalchemy import inspect, text

ADDITIONS = {
    "users": [("full_name", "VARCHAR(100)")],
    "fitness_profiles": [("activity_level", "VARCHAR(20)")],
    "recipes": [("image_url", "VARCHAR(500)")],
    "exercises": [("image_url", "VARCHAR(500)")],
}


def ensure_columns(engine) -> list:
    added = []
    insp = inspect(engine)
    with engine.begin() as conn:
        for table, cols in ADDITIONS.items():
            if not insp.has_table(table):
                continue
            have = {c["name"] for c in insp.get_columns(table)}
            for name, ddl in cols:
                if name not in have:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
                    added.append(f"{table}.{name}")
    return added
