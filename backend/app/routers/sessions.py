from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404
from ..models import Exercise, ExerciseLog, PlanItem, User, WorkoutPlan, WorkoutSession, utcnow
from ..schemas import (LogCreate, LogOut, LogUpdate, Mode, SessionBrief, SessionCreate, SessionOut, SessionUpdate)

router = APIRouter(prefix="/sessions", tags=["sessions"])
FUTURE_TOLERANCE = timedelta(minutes=5)


def _as_utc(dt: datetime) -> datetime:
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)


@router.post("", response_model=SessionOut, status_code=201)
def start_session(body: SessionCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.plan_id is not None:
        owned_or_404(db, WorkoutPlan, body.plan_id, user, "Reja")
    s = WorkoutSession(user_id=user.id, plan_id=body.plan_id, mode=body.mode, status="in_progress", started_at=utcnow())
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


@router.get("", response_model=List[SessionBrief])
def list_sessions(
    mode: Optional[Mode] = None,
    status: Optional[str] = Query(None, pattern="^(in_progress|completed|interrupted)$"),
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(WorkoutSession).where(WorkoutSession.user_id == user.id)
    if mode:
        stmt = stmt.where(WorkoutSession.mode == mode)
    if status:
        stmt = stmt.where(WorkoutSession.status == status)
    if date_from:
        stmt = stmt.where(WorkoutSession.started_at >= _as_utc(date_from))
    if date_to:
        stmt = stmt.where(WorkoutSession.started_at < _as_utc(date_to))
    return db.scalars(stmt.order_by(WorkoutSession.started_at.desc()).limit(limit).offset(offset)).all()


@router.get("/{session_id}", response_model=SessionOut)
def get_session(session_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return owned_or_404(db, WorkoutSession, session_id, user, "Seans")


@router.patch("/{session_id}", response_model=SessionOut)
def update_session(
    session_id: int, body: SessionUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    s = owned_or_404(db, WorkoutSession, session_id, user, "Seans")
    data = body.model_dump(exclude_unset=True)
    now = utcnow()

    if data.get("status"):
        if s.status != "in_progress":
            raise HTTPException(409, "Faqat davom etayotgan seansni yakunlash mumkin")
        if data["status"] == "completed" and not s.logs:  # TT 8.1: progress faqat haqiqiy qayd asosida
            raise HTTPException(422, "Kamida bitta mashq qaydi qo'shing yoki seansni to'xtating")
        s.status = data["status"]
        if s.finished_at is None:
            s.finished_at = now
    if data.get("finished_at") is not None:
        fin = _as_utc(data["finished_at"])
        if s.status == "in_progress":
            raise HTTPException(422, "Avval seans holatini yakunlang")
        if fin < s.started_at:
            raise HTTPException(422, "Tugash vaqti boshlanish vaqtidan oldin bo'lishi mumkin emas")
        if fin > now + FUTURE_TOLERANCE:
            raise HTTPException(422, "Tugash vaqti kelajakda bo'lishi mumkin emas")
        s.finished_at = fin
    if "notes" in data:
        s.notes = data["notes"]
    db.commit()
    db.refresh(s)
    return s


def _log_checks(db: Session, s: WorkoutSession, user: User, exercise_id: int, plan_item_id: Optional[int]):
    ex = db.get(Exercise, exercise_id)
    if not ex or not ex.is_active:
        raise HTTPException(422, "Mashq topilmadi yoki faol emas")
    if ex.mode != s.mode:
        raise HTTPException(422, f"Bu mashq {s.mode.upper()} seansiga mos kelmaydi")
    if plan_item_id is not None:
        item = db.get(PlanItem, plan_item_id)
        if not item or item.plan.user_id != user.id:
            raise HTTPException(404, "Reja bandi topilmadi")
        if item.exercise_id != exercise_id:
            raise HTTPException(422, "Reja bandi boshqa mashqqa tegishli")


@router.post("/{session_id}/logs", response_model=LogOut)
def add_log(
    session_id: int,
    body: LogCreate,
    response: Response,
    idempotency_key: Optional[str] = Header(None, max_length=64),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    s = owned_or_404(db, WorkoutSession, session_id, user, "Seans")
    if idempotency_key:  # AT-10: takror yuborilsa mavjud qayd qaytariladi
        existing = db.scalar(
            select(ExerciseLog).where(ExerciseLog.session_id == s.id, ExerciseLog.idempotency_key == idempotency_key)
        )
        if existing:
            response.status_code = 200
            return existing
    if s.status != "in_progress":
        raise HTTPException(409, "Yakunlangan seansga yangi qayd qo'shib bo'lmaydi")
    _log_checks(db, s, user, body.exercise_id, body.plan_item_id)
    log = ExerciseLog(session_id=s.id, idempotency_key=idempotency_key, **body.model_dump())
    db.add(log)
    try:
        db.commit()
    except IntegrityError:  # parallel takror so'rov
        db.rollback()
        existing = db.scalar(
            select(ExerciseLog).where(ExerciseLog.session_id == s.id, ExerciseLog.idempotency_key == idempotency_key)
        )
        if existing:
            response.status_code = 200
            return existing
        raise HTTPException(422, "Qaydni saqlab bo'lmadi")
    db.refresh(log)
    response.status_code = 201
    return log


def _own_log(db: Session, session_id: int, log_id: int, user: User):
    s = owned_or_404(db, WorkoutSession, session_id, user, "Seans")
    log = db.get(ExerciseLog, log_id)
    if not log or log.session_id != s.id:
        raise HTTPException(404, "Qayd topilmadi")
    return log


@router.patch("/{session_id}/logs/{log_id}", response_model=LogOut)
def update_log(
    session_id: int, log_id: int, body: LogUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    log = _own_log(db, session_id, log_id, user)
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(log, k, v)
    db.commit()
    db.refresh(log)
    return log


@router.delete("/{session_id}/logs/{log_id}", status_code=204)
def delete_log(session_id: int, log_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    log = _own_log(db, session_id, log_id, user)
    db.delete(log)
    db.commit()
