"""Maqsadlar, suv, uyqu va qadam (kundalik kuzatuv)."""
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404
from ..models import SleepLog, StepLog, User, UserGoals, WaterLog, utcnow
from ..schemas import (GoalsOut, GoalsUpdate, SleepIn, SleepOut, StepsIn, StepsOut, WaterDay, WaterIn, WaterOut)
from .progress import local_date, local_range_utc

router = APIRouter(tags=["wellness"])


def goals_of(db: Session, user: User) -> UserGoals:
    g = db.scalar(select(UserGoals).where(UserGoals.user_id == user.id))
    if g is None:
        g = UserGoals(user_id=user.id)
        db.add(g)
        db.commit()
        db.refresh(g)
    return g


def today() -> date:
    return local_date(utcnow())


def _not_future(d: date):
    if d > today() + timedelta(days=1):
        raise HTTPException(422, "Sana kelajakda bo'lishi mumkin emas")


@router.get("/goals", response_model=GoalsOut)
def get_goals(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return goals_of(db, user)


@router.patch("/goals", response_model=GoalsOut)
def update_goals(body: GoalsUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    g = goals_of(db, user)
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(g, k, v)
    db.commit()
    db.refresh(g)
    return g


# ---------- Suv ----------
@router.post("/water", response_model=WaterOut)
def add_water(
    body: WaterIn,
    response: Response,
    idempotency_key: Optional[str] = Header(None, max_length=64),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if idempotency_key:
        ex = db.scalar(select(WaterLog).where(WaterLog.user_id == user.id, WaterLog.idempotency_key == idempotency_key))
        if ex:
            response.status_code = 200
            return ex
    w = WaterLog(user_id=user.id, amount_ml=body.amount_ml, idempotency_key=idempotency_key)
    db.add(w)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        ex = db.scalar(select(WaterLog).where(WaterLog.user_id == user.id, WaterLog.idempotency_key == idempotency_key))
        if ex:
            response.status_code = 200
            return ex
        raise HTTPException(422, "Suv qaydini saqlab bo'lmadi")
    db.refresh(w)
    response.status_code = 201
    return w


@router.get("/water", response_model=WaterDay)
def water_day(day: Optional[date] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    d = day or today()
    lo, hi = local_range_utc(d, d)
    rows = db.scalars(
        select(WaterLog).where(WaterLog.user_id == user.id, WaterLog.logged_at >= lo, WaterLog.logged_at < hi)
        .order_by(WaterLog.logged_at)
    ).all()
    return WaterDay(day=d, total_ml=sum(r.amount_ml for r in rows), goal_ml=goals_of(db, user).water_goal_ml, entries=rows)


@router.delete("/water/{water_id}", status_code=204)
def delete_water(water_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.delete(owned_or_404(db, WaterLog, water_id, user, "Suv qaydi"))
    db.commit()


# ---------- Uyqu ----------
@router.put("/sleep/{day}", response_model=SleepOut)
def put_sleep(day: date, body: SleepIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _not_future(day)
    row = db.scalar(select(SleepLog).where(SleepLog.user_id == user.id, SleepLog.sleep_date == day))
    if row is None:
        row = SleepLog(user_id=user.id, sleep_date=day, duration_min=body.duration_min, quality=body.quality)
        db.add(row)
    else:
        row.duration_min, row.quality = body.duration_min, body.quality
    db.commit()
    db.refresh(row)
    return row


@router.get("/sleep", response_model=List[SleepOut])
def list_sleep(
    date_from: Optional[date] = None, date_to: Optional[date] = None,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    end = date_to or today()
    start = date_from or end - timedelta(days=6)
    return db.scalars(
        select(SleepLog).where(SleepLog.user_id == user.id, SleepLog.sleep_date >= start, SleepLog.sleep_date <= end)
        .order_by(SleepLog.sleep_date)
    ).all()


@router.delete("/sleep/{day}", status_code=204)
def delete_sleep(day: date, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(SleepLog).where(SleepLog.user_id == user.id, SleepLog.sleep_date == day))
    if not row:
        raise HTTPException(404, "Uyqu qaydi topilmadi")
    db.delete(row)
    db.commit()


# ---------- Qadamlar (qo'lda) ----------
@router.put("/steps/{day}", response_model=StepsOut)
def put_steps(day: date, body: StepsIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _not_future(day)
    row = db.scalar(select(StepLog).where(StepLog.user_id == user.id, StepLog.day == day))
    if row is None:
        row = StepLog(user_id=user.id, day=day, steps=body.steps)
        db.add(row)
    else:
        row.steps = body.steps
    db.commit()
    db.refresh(row)
    return row


@router.get("/steps", response_model=List[StepsOut])
def list_steps(
    date_from: Optional[date] = None, date_to: Optional[date] = None,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    end = date_to or today()
    start = date_from or end - timedelta(days=6)
    return db.scalars(
        select(StepLog).where(StepLog.user_id == user.id, StepLog.day >= start, StepLog.day <= end).order_by(StepLog.day)
    ).all()
