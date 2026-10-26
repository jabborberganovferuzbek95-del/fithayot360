from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import ActivityType, Exercise, ExerciseCategory, User
from ..schemas import ActivityTypeOut, CategoryOut, ExerciseOut

router = APIRouter(tags=["catalog"])


@router.get("/exercise-categories", response_model=List[CategoryOut])
def categories(_: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.scalars(select(ExerciseCategory).order_by(ExerciseCategory.mode, ExerciseCategory.id)).all()


@router.get("/activity-types", response_model=List[ActivityTypeOut])
def activity_types(_: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.scalars(select(ActivityType).order_by(ActivityType.id)).all()


@router.get("/exercises", response_model=List[ExerciseOut])
def list_exercises(
    q: Optional[str] = Query(None, max_length=100, description="Nom bo'yicha qidiruv"),
    mode: Optional[str] = Query(None, pattern="^(home|gym)$"),
    category: Optional[str] = Query(None, description="Kategoriya kodi"),
    equipment: Optional[str] = Query(None, max_length=100),
    difficulty: Optional[str] = Query(None, pattern="^(beginner|intermediate|advanced)$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Exercise).join(ExerciseCategory).where(Exercise.is_active.is_(True))
    if q:
        stmt = stmt.where(Exercise.title.ilike(f"%{q.strip()}%"))
    if mode:
        stmt = stmt.where(ExerciseCategory.mode == mode)
    if category:
        stmt = stmt.where(ExerciseCategory.code == category)
    if equipment:
        stmt = stmt.where(Exercise.equipment.ilike(equipment.strip()))
    if difficulty:
        stmt = stmt.where(Exercise.difficulty == difficulty)
    stmt = stmt.order_by(ExerciseCategory.mode, Exercise.title).limit(limit).offset(offset)
    return db.scalars(stmt).unique().all()


@router.get("/exercises/{exercise_id}", response_model=ExerciseOut)
def get_exercise(exercise_id: int, _: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ex = db.get(Exercise, exercise_id)
    if not ex or not ex.is_active:
        raise HTTPException(404, "Mashq topilmadi")
    return ex
