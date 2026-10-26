import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from . import seed
from .config import settings
from .database import Base, SessionLocal, engine
from .migrate import ensure_columns
from .routers import (activities, admin, auth, dashboard, exercises, habits, insights, me, nutrition, plans, programs,
                      progress, sessions, wellness)

log = logging.getLogger("fithayot")


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.is_production and settings.jwt_secret == "dev-only-change-me":
        raise RuntimeError("Productionda JWT_SECRET ni o'zgartirish shart")
    if settings.auto_create_tables:
        Base.metadata.create_all(engine)
        ensure_columns(engine)
    if settings.seed_on_start:
        with SessionLocal() as db:
            seed.seed_reference_data(db)
            seed.seed_admin(db)
    yield


app = FastAPI(
    title="FitHayot 360 API",
    version="3.0.0",
    description="Home / Gym / Active mashg'ulotlarini yagona hisob va progress tizimida yurituvchi MVP backend. "
    "Tibbiy tashxis yoki davolash vositasi emas; sun'iy intellekt ishlatilmaydi.",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def validation_handler(_: Request, exc: RequestValidationError):
    """Foydalanuvchiga tushunarli bitta xabar + to'liq xatolar ro'yxati."""
    errors = exc.errors()
    first = errors[0] if errors else {}
    msg = str(first.get("msg", "Noto'g'ri ma'lumot")).removeprefix("Value error, ")
    field = ".".join(str(p) for p in first.get("loc", []) if p not in ("body", "query", "path", "header"))
    detail = msg if first.get("type") == "value_error" else f"Noto'g'ri qiymat{f' ({field})' if field else ''}: {msg}"
    safe = [{"loc": e.get("loc"), "msg": e.get("msg"), "type": e.get("type")} for e in errors]
    return JSONResponse(status_code=422, content={"detail": detail, "errors": safe})


@app.exception_handler(Exception)
async def unhandled(_: Request, exc: Exception):  # NFR-09: ichki detallar foydalanuvchiga berilmaydi
    log.exception("Kutilmagan xatolik", exc_info=exc)
    return JSONResponse(status_code=500, content={"detail": "Serverda kutilmagan xatolik yuz berdi. Keyinroq urinib ko'ring."})


@app.get("/health", tags=["system"])
def health():
    db_ok = True
    try:
        with engine.connect() as c:
            c.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    return {"status": "ok" if db_ok else "degraded", "database": db_ok, "version": app.version}


for r in (auth.router, me.router, exercises.router, plans.router, sessions.router, activities.router,
          progress.router, admin.router, wellness.router, nutrition.router, dashboard.router, programs.router, habits.router, insights.router):
    app.include_router(r)
