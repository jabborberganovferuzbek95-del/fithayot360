from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404
from ..models import ActivityLog, ActivityType, User, utcnow
from ..schemas import ActivityCreate, ActivityOut, ActivityUpdate

router = APIRouter(prefix="/activities", tags=["active"])
FUTURE_TOLERANCE = timedelta(minutes=5)


def _as_utc(dt: datetime) -> datetime:
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)


def _check_time(dt: datetime) -> datetime:
    dt = _as_utc(dt)
    if dt > utcnow() + FUTURE_TOLERANCE:
        raise HTTPException(422, "Faollik vaqti kelajakda bo'lishi mumkin emas")
    return dt


@router.post("", response_model=ActivityOut)
def create_activity(
    body: ActivityCreate,
    response: Response,
    idempotency_key: Optional[str] = Header(None, max_length=64),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if idempotency_key:  # AT-10
        existing = db.scalar(
            select(ActivityLog).where(ActivityLog.user_id == user.id, ActivityLog.idempotency_key == idempotency_key)
        )
        if existing:
            response.status_code = 200
            return existing
    atype = (
        db.get(ActivityType, body.activity_type_id)
        if body.activity_type_id is not None
        else db.scalar(select(ActivityType).where(ActivityType.code == body.activity_type_code))
    )
    if not atype:
        raise HTTPException(422, "Faollik turi topilmadi")
    log = ActivityLog(
        user_id=user.id, activity_type_id=atype.id, occurred_at=_check_time(body.occurred_at or utcnow()),
        duration_minutes=body.duration_minutes, distance_km=body.distance_km, note=body.note,
        idempotency_key=idempotency_key,
    )
    db.add(log)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(ActivityLog).where(ActivityLog.user_id == user.id, ActivityLog.idempotency_key == idempotency_key)
        )
        if existing:
            response.status_code = 200
            return existing
        raise HTTPException(422, "Faollikni saqlab bo'lmadi")
    db.refresh(log)
    response.status_code = 201
    return log


@router.get("", response_model=List[ActivityOut])
def list_activities(
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(ActivityLog).where(ActivityLog.user_id == user.id)
    if date_from:
        stmt = stmt.where(ActivityLog.occurred_at >= _as_utc(date_from))
    if date_to:
        stmt = stmt.where(ActivityLog.occurred_at < _as_utc(date_to))
    return db.scalars(stmt.order_by(ActivityLog.occurred_at.desc()).limit(limit).offset(offset)).all()


@router.patch("/{activity_id}", response_model=ActivityOut)
def update_activity(
    activity_id: int, body: ActivityUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    a = owned_or_404(db, ActivityLog, activity_id, user, "Faollik")
    data = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if "activity_type_id" in data and not db.get(ActivityType, data["activity_type_id"]):
        raise HTTPException(422, "Faollik turi topilmadi")
    if "occurred_at" in data:
        data["occurred_at"] = _check_time(data["occurred_at"])
    for k, v in data.items():
        setattr(a, k, v)
    db.commit()
    db.refresh(a)
    return a


@router.delete("/{activity_id}", status_code=204)
def delete_activity(activity_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    a = owned_or_404(db, ActivityLog, activity_id, user, "Faollik")
    db.delete(a)
    db.commit()
