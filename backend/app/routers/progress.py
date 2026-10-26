from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import ActivityLog, ExerciseLog, PlanItem, User, WorkoutPlan, WorkoutSession, utcnow
from ..schemas import DayStat, HistoryItem, Module, WeeklyProgress
from .plans import completed_item_ids

router = APIRouter(tags=["progress"])
OFFSET = timedelta(minutes=settings.tz_offset_minutes)
MODE_LABEL = {"home": "Home mashg'uloti", "gym": "Gym mashg'uloti"}


def local_date(dt: datetime) -> date:
    return (dt + OFFSET).date()


def local_range_utc(start: date, end_inclusive: date):
    """Mahalliy sanalar oralig'ini UTC [from, to) ga o'giradi."""
    lo = datetime.combine(start, time.min, tzinfo=timezone.utc) - OFFSET
    hi = datetime.combine(end_inclusive + timedelta(days=1), time.min, tzinfo=timezone.utc) - OFFSET
    return lo, hi


def compute_weekly(db: Session, user: User, week_start: date) -> WeeklyProgress:
    """TT 7.4: total_active_minutes = SUM(yakunlangan seans davomiyligi) + SUM(activity_logs.duration_minutes).
    Active qayd seans sifatida ikkinchi marta hisoblanmaydi (alohida jadval)."""
    week_end = week_start + timedelta(days=6)
    lo, hi = local_range_utc(week_start, week_end)

    sessions = db.scalars(
        select(WorkoutSession).where(
            WorkoutSession.user_id == user.id, WorkoutSession.status == "completed",
            WorkoutSession.started_at >= lo, WorkoutSession.started_at < hi,
        )
    ).all()
    activities = db.scalars(
        select(ActivityLog).where(ActivityLog.user_id == user.id, ActivityLog.occurred_at >= lo, ActivityLog.occurred_at < hi)
    ).all()

    by_module = {"home": 0, "gym": 0, "active": 0}
    day_min, day_ses, day_act = defaultdict(int), defaultdict(int), defaultdict(int)
    for s in sessions:
        m = s.duration_minutes or 0
        by_module[s.mode] += m
        d = local_date(s.started_at)
        day_min[d] += m
        day_ses[d] += 1
    for a in activities:
        by_module["active"] += a.duration_minutes
        d = local_date(a.occurred_at)
        day_min[d] += a.duration_minutes
        day_act[d] += 1

    items = db.scalars(
        select(PlanItem).join(WorkoutPlan).where(
            WorkoutPlan.user_id == user.id, PlanItem.planned_date >= week_start, PlanItem.planned_date <= week_end
        )
    ).unique().all()
    done = completed_item_ids(db, [i.id for i in items])
    planned, completed = len(items), len(done)
    rate = round(completed / planned * 100, 1) if planned else None  # bo'sh reja -> N/A (0 ga bo'lish yo'q)

    days = [
        DayStat(date=week_start + timedelta(days=i), minutes=day_min[week_start + timedelta(days=i)],
                sessions=day_ses[week_start + timedelta(days=i)], activities=day_act[week_start + timedelta(days=i)])
        for i in range(7)
    ]
    return WeeklyProgress(
        week_start=week_start, week_end=week_end, total_sessions=len(sessions), total_activity_entries=len(activities),
        total_active_minutes=sum(by_module.values()), minutes_by_module=by_module,
        planned_items=planned, completed_items=completed, planned_completion_rate=rate, days=days,
    )


@router.get("/progress/weekly", response_model=WeeklyProgress)
def weekly(
    week_start: Optional[date] = Query(None, description="Ixtiyoriy sana; shu sana kirgan haftaning dushanbasi olinadi"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    base = week_start or local_date(utcnow())
    monday = base - timedelta(days=base.weekday())
    return compute_weekly(db, user, monday)


@router.get("/history", response_model=List[HistoryItem])
def history(
    module: Optional[Module] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Yagona tarix: yakunlangan Home/Gym seanslari va Active faolliklar bitta ro'yxatda (FR-13)."""
    lo = local_range_utc(date_from, date_from)[0] if date_from else None
    hi = local_range_utc(date_to, date_to)[1] if date_to else None
    out: List[HistoryItem] = []

    if module in (None, "home", "gym"):
        stmt = select(WorkoutSession).where(WorkoutSession.user_id == user.id, WorkoutSession.status == "completed")
        if module:
            stmt = stmt.where(WorkoutSession.mode == module)
        if lo:
            stmt = stmt.where(WorkoutSession.started_at >= lo)
        if hi:
            stmt = stmt.where(WorkoutSession.started_at < hi)
        for s in db.scalars(stmt).all():
            names = list(dict.fromkeys(l.exercise.title for l in s.logs))
            out.append(HistoryItem(
                kind="session", id=s.id, module=s.mode, title=MODE_LABEL[s.mode], occurred_at=s.started_at,
                duration_minutes=s.duration_minutes,
                detail=(f"{len(names)} ta mashq: " + ", ".join(names[:3]) + ("…" if len(names) > 3 else "")) if names else None,
            ))
    if module in (None, "active"):
        stmt = select(ActivityLog).where(ActivityLog.user_id == user.id)
        if lo:
            stmt = stmt.where(ActivityLog.occurred_at >= lo)
        if hi:
            stmt = stmt.where(ActivityLog.occurred_at < hi)
        for a in db.scalars(stmt).all():
            out.append(HistoryItem(
                kind="activity", id=a.id, module="active", title=a.activity_type.title, occurred_at=a.occurred_at,
                duration_minutes=a.duration_minutes, distance_km=a.distance_km, detail=a.note,
            ))
    out.sort(key=lambda x: x.occurred_at, reverse=True)
    return out[offset: offset + limit]
