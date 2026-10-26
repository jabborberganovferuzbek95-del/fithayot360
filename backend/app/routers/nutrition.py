"""Ovqatlanish (retseptlar, ovqat qaydi), meditatsiya va premium 'xabar bering' ro'yxati."""
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404, require_content_admin
from ..models import MealLog, MeditationItem, MeditationLog, PremiumInterest, Recipe, User, utcnow
from ..schemas import (MealIn, MealOut, MeditationLogIn, MeditationLogOut, MeditationOut, RecipeCreate, RecipeOut,
                       RecipeUpdate)
from .progress import local_date, local_range_utc

router = APIRouter(tags=["nutrition"])
FUTURE = timedelta(minutes=5)


def _utc(dt: datetime) -> datetime:
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)


# ---------- Retseptlar ----------
@router.get("/recipes", response_model=List[RecipeOut])
def list_recipes(
    meal_type: Optional[str] = Query(None, pattern="^(breakfast|lunch|dinner|snack|detox)$"),
    q: Optional[str] = Query(None, max_length=100),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Recipe).where(Recipe.is_active.is_(True))
    if meal_type:
        stmt = stmt.where(Recipe.meal_type == meal_type)
    if q:
        stmt = stmt.where(Recipe.title.ilike(f"%{q.strip()}%"))
    return db.scalars(stmt.order_by(Recipe.title).limit(limit).offset(offset)).all()


@router.get("/recipes/{recipe_id}", response_model=RecipeOut)
def get_recipe(recipe_id: int, _: User = Depends(get_current_user), db: Session = Depends(get_db)):
    r = db.get(Recipe, recipe_id)
    if not r or not r.is_active:
        raise HTTPException(404, "Retsept topilmadi")
    return r


@router.post("/admin/recipes", response_model=RecipeOut, status_code=201, tags=["admin"])
def create_recipe(body: RecipeCreate, _: User = Depends(require_content_admin), db: Session = Depends(get_db)):
    r = Recipe(**body.model_dump())
    db.add(r)
    db.commit()
    db.refresh(r)
    return r


@router.patch("/admin/recipes/{recipe_id}", response_model=RecipeOut, tags=["admin"])
def update_recipe(recipe_id: int, body: RecipeUpdate, _: User = Depends(require_content_admin), db: Session = Depends(get_db)):
    r = db.get(Recipe, recipe_id)
    if not r:
        raise HTTPException(404, "Retsept topilmadi")
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(r, k, v)
    db.commit()
    db.refresh(r)
    return r


# ---------- Ovqat qaydi ----------
@router.post("/meals", response_model=MealOut, status_code=201)
def add_meal(body: MealIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    title, kcal = body.title, body.kcal
    if body.recipe_id is not None:
        r = db.get(Recipe, body.recipe_id)
        if not r or not r.is_active:
            raise HTTPException(422, "Retsept topilmadi")
        title, kcal = title or r.title, kcal if kcal is not None else r.kcal
    when = _utc(body.eaten_at) if body.eaten_at else utcnow()
    if when > utcnow() + FUTURE:
        raise HTTPException(422, "Vaqt kelajakda bo'lishi mumkin emas")
    m = MealLog(user_id=user.id, recipe_id=body.recipe_id, title=title, meal_type=body.meal_type, kcal=kcal, eaten_at=when)
    db.add(m)
    db.commit()
    db.refresh(m)
    return m


@router.get("/meals", response_model=List[MealOut])
def list_meals(day: Optional[date] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    d = day or local_date(utcnow())
    lo, hi = local_range_utc(d, d)
    return db.scalars(
        select(MealLog).where(MealLog.user_id == user.id, MealLog.eaten_at >= lo, MealLog.eaten_at < hi).order_by(MealLog.eaten_at)
    ).all()


@router.delete("/meals/{meal_id}", status_code=204)
def delete_meal(meal_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.delete(owned_or_404(db, MealLog, meal_id, user, "Ovqat qaydi"))
    db.commit()


# ---------- Meditatsiya ----------
@router.get("/meditations", response_model=List[MeditationOut])
def list_meditations(
    category: Optional[str] = Query(None, pattern="^(stress|focus|sleep|motivation)$"),
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(MeditationItem).where(MeditationItem.is_active.is_(True))
    if category:
        stmt = stmt.where(MeditationItem.category == category)
    return db.scalars(stmt.order_by(MeditationItem.id)).all()


@router.post("/meditation-logs", response_model=MeditationLogOut, status_code=201)
def add_meditation_log(body: MeditationLogIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.item_id is not None and not db.get(MeditationItem, body.item_id):
        raise HTTPException(422, "Meditatsiya topilmadi")
    log = MeditationLog(user_id=user.id, item_id=body.item_id, duration_min=body.duration_min)
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.get("/meditation-logs", response_model=List[MeditationLogOut])
def list_meditation_logs(
    limit: int = Query(30, ge=1, le=200), user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    return db.scalars(
        select(MeditationLog).where(MeditationLog.user_id == user.id).order_by(MeditationLog.completed_at.desc()).limit(limit)
    ).all()


# ---------- Premium: to'lov yo'q, faqat qiziqish bildirish ----------
@router.get("/premium/interest")
def premium_status(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"interested": db.scalar(select(PremiumInterest.id).where(PremiumInterest.user_id == user.id)) is not None}


@router.post("/premium/interest", status_code=201)
def premium_join(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not db.scalar(select(PremiumInterest.id).where(PremiumInterest.user_id == user.id)):
        db.add(PremiumInterest(user_id=user.id))
        db.commit()
    return {"interested": True}
