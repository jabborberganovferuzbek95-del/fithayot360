"""Bosh sahifa (bugun) va statistika (7/30 kun) uchun yig'ma ma'lumotlar."""
from collections import defaultdict
from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import (ActivityLog, MealLog, MeditationLog, SleepLog, StepLog, User, WaterLog, WorkoutSession, utcnow)
from .progress import local_date, local_range_utc
from .wellness import goals_of

router = APIRouter(tags=["dashboard"])
FIELDS = ("steps", "water_ml", "sleep_min", "calories_in", "active_minutes", "workout_sessions", "meditation_min")


def collect(db: Session, user: User, start: date, end: date) -> dict:
    """Har bir mahalliy kun uchun ko'rsatkichlarni yig'adi."""
    days = {start + timedelta(i): dict.fromkeys(FIELDS, 0) for i in range((end - start).days + 1)}
    lo, hi = local_range_utc(start, end)

    for r in db.scalars(select(StepLog).where(StepLog.user_id == user.id, StepLog.day >= start, StepLog.day <= end)):
        days[r.day]["steps"] = r.steps
    for r in db.scalars(select(SleepLog).where(SleepLog.user_id == user.id, SleepLog.sleep_date >= start, SleepLog.sleep_date <= end)):
        days[r.sleep_date]["sleep_min"] = r.duration_min
    for r in db.scalars(select(WaterLog).where(WaterLog.user_id == user.id, WaterLog.logged_at >= lo, WaterLog.logged_at < hi)):
        days[local_date(r.logged_at)]["water_ml"] += r.amount_ml
    for r in db.scalars(select(MealLog).where(MealLog.user_id == user.id, MealLog.eaten_at >= lo, MealLog.eaten_at < hi)):
        days[local_date(r.eaten_at)]["calories_in"] += r.kcal
    for r in db.scalars(select(MeditationLog).where(MeditationLog.user_id == user.id, MeditationLog.completed_at >= lo, MeditationLog.completed_at < hi)):
        days[local_date(r.completed_at)]["meditation_min"] += r.duration_min
    for s in db.scalars(select(WorkoutSession).where(
            WorkoutSession.user_id == user.id, WorkoutSession.status == "completed",
            WorkoutSession.started_at >= lo, WorkoutSession.started_at < hi)):
        d = days[local_date(s.started_at)]
        d["active_minutes"] += s.duration_minutes or 0
        d["workout_sessions"] += 1
    for a in db.scalars(select(ActivityLog).where(ActivityLog.user_id == user.id, ActivityLog.occurred_at >= lo, ActivityLog.occurred_at < hi)):
        days[local_date(a.occurred_at)]["active_minutes"] += a.duration_minutes
    return days


def _fmt(n: int) -> str:
    return f"{n:,}".replace(",", " ")


@router.get("/dashboard/today")
def dashboard_today(day: Optional[date] = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    d = day or local_date(utcnow())
    g = goals_of(db, user)
    m = collect(db, user, d, d)[d]
    habits = [
        {"key": "steps", "title": f"{_fmt(g.steps_goal)} qadam yurish", "done": m["steps"] >= g.steps_goal},
        {"key": "water", "title": f"Suv ichish ({g.water_goal_ml / 1000:g} L)", "done": m["water_ml"] >= g.water_goal_ml},
        {"key": "workout", "title": f"{g.workout_goal_min} daqiqa mashq", "done": m["active_minutes"] >= g.workout_goal_min},
        {"key": "meditation", "title": "Meditatsiya (10 daq)", "done": m["meditation_min"] >= 10},
        {"key": "sleep", "title": f"Uyqu ({g.sleep_goal_min / 60:.1f} soat)", "done": m["sleep_min"] >= g.sleep_goal_min},
    ]
    return {
        "day": d, **m,
        "goals": {"steps": g.steps_goal, "water_ml": g.water_goal_ml, "sleep_min": g.sleep_goal_min,
                  "workout_min": g.workout_goal_min, "calories": g.calorie_goal},
        "habits": habits,
        "habits_done": sum(h["done"] for h in habits),
    }


@router.get("/stats")
def stats(
    days: int = Query(7, ge=1, le=366),
    end: Optional[date] = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    e = end or local_date(utcnow())
    s = e - timedelta(days=days - 1)
    data = collect(db, user, s, e)
    rows = [{"date": k, **v} for k, v in sorted(data.items())]
    totals = {f: sum(r[f] for r in rows) for f in FIELDS}
    sleep_days = [r["sleep_min"] for r in rows if r["sleep_min"] > 0]
    averages = {
        "steps": round(totals["steps"] / days),
        "water_ml": round(totals["water_ml"] / days),
        "calories_in": round(totals["calories_in"] / days),
        "active_minutes": round(totals["active_minutes"] / days),
        "sleep_min": round(sum(sleep_days) / len(sleep_days)) if sleep_days else None,  # qaydi bo'lmasa N/A
    }
    return {"start": s, "end": e, "days": rows, "totals": totals, "averages": averages}
