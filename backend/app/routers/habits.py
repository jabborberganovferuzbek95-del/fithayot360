"""Shaxsiy odatlar (avtomatik odatlar /dashboard/today da)."""
from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404
from ..models import Habit, HabitCheck, User, utcnow
from ..schemas import HabitCheckIn, HabitIn, HabitOut
from .progress import local_date

router = APIRouter(tags=["habits"])
MAX_HABITS = 20


@router.get("/habits")
def list_habits(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Habit).where(Habit.user_id == user.id).order_by(Habit.id)).all()
    return [HabitOut.model_validate(h) for h in rows]


@router.post("/habits", response_model=HabitOut, status_code=201)
def create_habit(body: HabitIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = len(db.scalars(select(Habit.id).where(Habit.user_id == user.id)).all())
    if count >= MAX_HABITS:
        raise HTTPException(422, f"Odatlar soni {MAX_HABITS} tadan oshmasligi kerak")
    h = Habit(user_id=user.id, title=body.title.strip())
    db.add(h)
    db.commit()
    db.refresh(h)
    return h


@router.delete("/habits/{habit_id}", status_code=204)
def delete_habit(habit_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.delete(owned_or_404(db, Habit, habit_id, user, "Odat"))
    db.commit()


@router.put("/habits/{habit_id}/checks/{day}")
def set_check(habit_id: int, day: date, body: HabitCheckIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    owned_or_404(db, Habit, habit_id, user, "Odat")
    if day > local_date(utcnow()) + timedelta(days=1):
        raise HTTPException(422, "Kelajak sanasini belgilab bo'lmaydi")
    row = db.scalar(select(HabitCheck).where(HabitCheck.habit_id == habit_id, HabitCheck.day == day))
    if body.done and not row:
        db.add(HabitCheck(habit_id=habit_id, day=day))
    elif not body.done and row:
        db.delete(row)
    db.commit()
    return {"habit_id": habit_id, "day": day, "done": body.done}


@router.get("/habit-checks")
def list_checks(
    date_from: Optional[date] = None, date_to: Optional[date] = None,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    end = date_to or local_date(utcnow())
    start = date_from or end - timedelta(days=6)
    rows = db.execute(
        select(HabitCheck.habit_id, HabitCheck.day).join(Habit, Habit.id == HabitCheck.habit_id)
        .where(Habit.user_id == user.id, HabitCheck.day >= start, HabitCheck.day <= end)
    ).all()
    return [{"habit_id": r[0], "day": r[1]} for r in rows]
