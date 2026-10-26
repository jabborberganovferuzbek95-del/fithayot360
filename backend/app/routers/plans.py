from datetime import date
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, owned_or_404
from ..models import Exercise, ExerciseLog, PlanItem, User, WorkoutPlan, WorkoutSession
from ..schemas import (PlanBrief, PlanCreate, PlanItemIn, PlanItemOut, PlanItemUpdate, PlanOut, PlanUpdate)

router = APIRouter(prefix="/plans", tags=["plans"])


def completed_item_ids(db: Session, item_ids: List[int]) -> set:
    if not item_ids:
        return set()
    rows = db.scalars(
        select(ExerciseLog.plan_item_id)
        .join(WorkoutSession, WorkoutSession.id == ExerciseLog.session_id)
        .where(ExerciseLog.plan_item_id.in_(item_ids), WorkoutSession.status == "completed")
        .distinct()
    ).all()
    return set(rows)


def serialize(db: Session, plan: WorkoutPlan) -> PlanOut:
    done = completed_item_ids(db, [i.id for i in plan.items])
    out = PlanOut.model_validate(plan)
    for item_out in out.items:
        item_out.is_completed = item_out.id in done
    return out


def _check_item(db: Session, plan: WorkoutPlan, exercise_id: int, planned_date: date):
    ex = db.get(Exercise, exercise_id)
    if not ex or not ex.is_active:
        raise HTTPException(422, "Mashq topilmadi yoki faol emas")
    if not (plan.starts_on <= planned_date <= plan.ends_on):
        raise HTTPException(422, "Mashq sanasi reja davridan tashqarida")


@router.get("", response_model=List[PlanBrief])
def list_plans(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.scalars(
        select(WorkoutPlan).where(WorkoutPlan.user_id == user.id).order_by(WorkoutPlan.starts_on.desc(), WorkoutPlan.id.desc())
    ).all()


@router.post("", response_model=PlanOut, status_code=201)
def create_plan(body: PlanCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    plan = WorkoutPlan(user_id=user.id, title=body.title.strip(), starts_on=body.starts_on, ends_on=body.ends_on)
    db.add(plan)
    for it in body.items:
        _check_item(db, plan, it.exercise_id, it.planned_date)
        plan.items.append(PlanItem(**it.model_dump()))
    db.commit()
    db.refresh(plan)
    return serialize(db, plan)


@router.get("/{plan_id}", response_model=PlanOut)
def get_plan(plan_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return serialize(db, owned_or_404(db, WorkoutPlan, plan_id, user, "Reja"))


@router.patch("/{plan_id}", response_model=PlanOut)
def update_plan(plan_id: int, body: PlanUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    plan = owned_or_404(db, WorkoutPlan, plan_id, user, "Reja")
    data = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    starts, ends = data.get("starts_on", plan.starts_on), data.get("ends_on", plan.ends_on)
    if ends < starts:
        raise HTTPException(422, "Tugash sanasi boshlanish sanasidan oldin bo'lishi mumkin emas")
    if any(not (starts <= i.planned_date <= ends) for i in plan.items):
        raise HTTPException(422, "Rejadagi ba'zi mashqlar yangi davrdan tashqarida qoladi")
    for k, v in data.items():
        setattr(plan, k, v)
    db.commit()
    db.refresh(plan)
    return serialize(db, plan)


@router.delete("/{plan_id}", status_code=204)
def delete_plan(plan_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    plan = owned_or_404(db, WorkoutPlan, plan_id, user, "Reja")
    item_ids = [i.id for i in plan.items]
    if item_ids:  # tarixdagi qaydlar saqlanadi, faqat reja bilan bog'lanish uziladi
        db.execute(update(ExerciseLog).where(ExerciseLog.plan_item_id.in_(item_ids)).values(plan_item_id=None))
    db.execute(update(WorkoutSession).where(WorkoutSession.plan_id == plan.id).values(plan_id=None))
    db.delete(plan)
    db.commit()


@router.post("/{plan_id}/items", response_model=PlanItemOut, status_code=201)
def add_item(plan_id: int, body: PlanItemIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    plan = owned_or_404(db, WorkoutPlan, plan_id, user, "Reja")
    _check_item(db, plan, body.exercise_id, body.planned_date)
    item = PlanItem(plan_id=plan.id, **body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return PlanItemOut.model_validate(item)


def _own_item(db: Session, plan_id: int, item_id: int, user: User):
    plan = owned_or_404(db, WorkoutPlan, plan_id, user, "Reja")
    item = db.get(PlanItem, item_id)
    if not item or item.plan_id != plan.id:
        raise HTTPException(404, "Reja bandi topilmadi")
    return plan, item


@router.patch("/{plan_id}/items/{item_id}", response_model=PlanItemOut)
def update_item(
    plan_id: int, item_id: int, body: PlanItemUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    plan, item = _own_item(db, plan_id, item_id, user)
    data = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    _check_item(db, plan, data.get("exercise_id", item.exercise_id), data.get("planned_date", item.planned_date))
    for k, v in data.items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    out = PlanItemOut.model_validate(item)
    out.is_completed = item.id in completed_item_ids(db, [item.id])
    return out


@router.delete("/{plan_id}/items/{item_id}", status_code=204)
def delete_item(plan_id: int, item_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _, item = _own_item(db, plan_id, item_id, user)
    db.execute(update(ExerciseLog).where(ExerciseLog.plan_item_id == item.id).values(plan_item_id=None))
    db.delete(item)
    db.commit()
