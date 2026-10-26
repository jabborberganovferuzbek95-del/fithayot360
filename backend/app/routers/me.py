from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import (MealLog, MeditationLog, SleepLog, StepLog, User, UserGoals, WaterLog, WorkoutPlan,
                      WorkoutSession)
from ..schemas import DeleteAccountIn, MeOut, MeUpdate
from ..security import verify_password

router = APIRouter(tags=["me"])

PROFILE_FIELDS = ("goal", "experience_level", "preferred_location", "daily_minutes", "activity_level")
SETTINGS_FIELDS = ("language_code", "reminders_enabled")


def _me(user: User) -> MeOut:
    return MeOut(
        id=user.id, email=user.email, full_name=user.full_name, role=user.role, is_adult_confirmed=user.is_adult_confirmed,
        created_at=user.created_at, profile=user.profile, settings=user.settings,
        profile_completed=user.profile.is_complete,
    )


@router.get("/me", response_model=MeOut)
def get_me(user: User = Depends(get_current_user)):
    return _me(user)


@router.patch("/me", response_model=MeOut)
def update_me(body: MeUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is None:
            continue
        target = user if k == "full_name" else (user.profile if k in PROFILE_FIELDS else user.settings)
        setattr(target, k, v.strip() if k == "full_name" else v)
    db.commit()
    db.refresh(user)
    return _me(user)


@router.get("/me/export")
def export_me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """FR-22: foydalanuvchi o'z ma'lumotlarini JSON ko'rinishida oladi."""
    sessions = db.scalars(select(WorkoutSession).where(WorkoutSession.user_id == user.id)).all()
    return {
        "account": {"email": user.email, "created_at": user.created_at, "is_adult_confirmed": user.is_adult_confirmed},
        "profile": {k: getattr(user.profile, k) for k in PROFILE_FIELDS},
        "settings": {k: getattr(user.settings, k) for k in SETTINGS_FIELDS},
        "consents": [
            {"purpose": c.purpose, "policy_version": c.policy_version, "accepted_at": c.accepted_at, "revoked_at": c.revoked_at}
            for c in user.consents
        ],
        "plans": [
            {"title": p.title, "starts_on": p.starts_on, "ends_on": p.ends_on, "status": p.status,
             "items": [{"exercise": i.exercise.title, "planned_date": i.planned_date, "planned_minutes": i.planned_minutes} for i in p.items]}
            for p in db.scalars(select(WorkoutPlan).where(WorkoutPlan.user_id == user.id)).all()
        ],
        "sessions": [
            {"mode": s.mode, "status": s.status, "started_at": s.started_at, "finished_at": s.finished_at, "notes": s.notes,
             "logs": [{"exercise": l.exercise.title, "set_no": l.set_no, "reps": l.reps, "weight_kg": l.weight_kg,
                       "duration_seconds": l.duration_seconds, "completed_at": l.completed_at} for l in s.logs]}
            for s in sessions
        ],
        "wellness": {
            "goals": {k: getattr(g, k) for k in ("steps_goal", "water_goal_ml", "sleep_goal_min", "workout_goal_min", "calorie_goal")} if (g := db.scalar(select(UserGoals).where(UserGoals.user_id == user.id))) else None,
            "water": [{"amount_ml": w.amount_ml, "logged_at": w.logged_at} for w in db.scalars(select(WaterLog).where(WaterLog.user_id == user.id))],
            "sleep": [{"date": s.sleep_date, "duration_min": s.duration_min, "quality": s.quality} for s in db.scalars(select(SleepLog).where(SleepLog.user_id == user.id))],
            "steps": [{"day": s.day, "steps": s.steps} for s in db.scalars(select(StepLog).where(StepLog.user_id == user.id))],
            "meals": [{"title": m.title, "meal_type": m.meal_type, "kcal": m.kcal, "eaten_at": m.eaten_at} for m in db.scalars(select(MealLog).where(MealLog.user_id == user.id))],
            "meditation": [{"duration_min": m.duration_min, "completed_at": m.completed_at} for m in db.scalars(select(MeditationLog).where(MeditationLog.user_id == user.id))],
        },
        "activities": [
            {"type": a.activity_type.title, "occurred_at": a.occurred_at, "duration_minutes": a.duration_minutes,
             "distance_km": a.distance_km, "note": a.note}
            for a in user.activities
        ],
    }


@router.delete("/me", status_code=204)
def delete_me(body: DeleteAccountIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """FR-22: parolni tasdiqlab hisob va barcha shaxsiy ma'lumotlarni o'chirish."""
    if user.role != "user":
        raise HTTPException(403, "Administrator hisobini o'chirish alohida tartibda amalga oshiriladi")
    if not verify_password(body.password, user.password_hash):
        raise HTTPException(403, "Parol noto'g'ri")
    db.delete(user)
    db.commit()
