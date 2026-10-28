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
    from sqlalchemy import text

    tables_to_clear = [
        "exercise_logs",
        "workout_sessions",
        "plan_items",
        "workout_plans",
        "activity_logs",
        "step_logs",
        "water_logs",
        "sleep_logs",
        "meditation_logs",
        "meal_logs",
        "habit_checks",
        "habits",
        "user_goals",
        "consent_events",
    ]

    deleted_counts = {}
    for tbl in tables_to_clear:
        try:
            res = db.execute(text(f"DELETE FROM {tbl}"))
            deleted_counts[tbl] = res.rowcount if hasattr(res, "rowcount") else 0
        except Exception:
            db.rollback()

    db.commit()
    return {
        "status": "ok",
        "message": "Foydalanuvchilarning barcha faollik va mashg'ulotlar tarixi muvaffaqiyatli tozalandi.",
        "deleted": deleted_counts,
    }

