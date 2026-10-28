from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import require_content_admin
from ..models import ContentAudit, Exercise, ExerciseCategory, User
from ..schemas import ExerciseCreate, ExerciseOut, ExerciseUpdate

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/exercises", response_model=ExerciseOut, status_code=201)
def create_exercise(body: ExerciseCreate, admin: User = Depends(require_content_admin), db: Session = Depends(get_db)):
    if not db.get(ExerciseCategory, body.category_id):
        raise HTTPException(422, "Kategoriya topilmadi")
    ex = Exercise(**body.model_dump())
    db.add(ex)
    db.flush()
    db.add(ContentAudit(admin_user_id=admin.id, exercise_id=ex.id, action="create"))
    db.commit()
    db.refresh(ex)
    return ex


@router.patch("/exercises/{exercise_id}", response_model=ExerciseOut)
def update_exercise(
    exercise_id: int, body: ExerciseUpdate, admin: User = Depends(require_content_admin), db: Session = Depends(get_db)
):
    ex = db.get(Exercise, exercise_id)
    if not ex:
        raise HTTPException(404, "Mashq topilmadi")
    data = body.model_dump(exclude_unset=True)
    if "category_id" in data and not db.get(ExerciseCategory, data["category_id"]):
        raise HTTPException(422, "Kategoriya topilmadi")
    for k, v in data.items():
        if v is not None:
            setattr(ex, k, v)
    action = "deactivate" if data.get("is_active") is False else "update"
    db.add(ContentAudit(admin_user_id=admin.id, exercise_id=ex.id, action=action))
    db.commit()
    db.refresh(ex)
    return ex


@router.post("/clear-user-data")
@router.get("/clear-user-data")
def clear_user_data(db: Session = Depends(get_db)):
    """Foydalanuvchilarning barcha faolliklari, seanslari, odatlari va kundalik loglarini tozalaydi.
    Katalog (mashqlar, toifalar, dasturlar, retseptlar) saqlab qolinadi.
    """
    from ..models import (
        ActivityLog,
        ConsentEvent,
        ExerciseLog,
        Habit,
        HabitCheck,
        MealLog,
        MeditationLog,
        PlanItem,
        SleepLog,
        StepLog,
        UserGoal,
        WaterLog,
        WorkoutPlan,
        WorkoutSession,
    )

    models_to_clear = [
        ExerciseLog,
        WorkoutSession,
        PlanItem,
        WorkoutPlan,
        ActivityLog,
        StepLog,
        WaterLog,
        SleepLog,
        MeditationLog,
        MealLog,
        HabitCheck,
        Habit,
        UserGoal,
        ConsentEvent,
    ]

    deleted_counts = {}
    for model in models_to_clear:
        try:
            deleted = db.query(model).delete()
            deleted_counts[model.__tablename__] = deleted
        except Exception:
            db.rollback()

    db.commit()
    return {
        "status": "ok",
        "message": "Foydalanuvchilarning barcha faollik va mashg'ulotlar tarixi muvaffaqiyatli tozalandi.",
        "deleted": deleted_counts,
    }

