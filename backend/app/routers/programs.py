from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Program, User
from ..schemas import ProgramBrief, ProgramOut

router = APIRouter(prefix="/programs", tags=["programs"])


@router.get("", response_model=List[ProgramBrief])
def list_programs(
    mode: Optional[str] = Query(None, pattern="^(home|gym)$"),
    kind: Optional[str] = Query(None, pattern="^(full_body|strength|stretch|cardio)$"),
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Program).where(Program.is_active.is_(True))
    if mode:
        stmt = stmt.where(Program.mode == mode)
    if kind:
        stmt = stmt.where(Program.kind == kind)
    return db.scalars(stmt.order_by(Program.id)).unique().all()


@router.get("/{program_id}", response_model=ProgramOut)
def get_program(program_id: int, _: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p = db.get(Program, program_id)
    if not p or not p.is_active:
        raise HTTPException(404, "Dastur topilmadi")
    return p
