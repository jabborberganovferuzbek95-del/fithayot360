from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..models import ConsentEvent, FitnessProfile, User, UserSettings
from ..schemas import (ForgotIn, LoginIn, MessageOut, RefreshIn, RegisterIn, ResetIn, TokenOut)
from ..security import (access_token, create_token, decode_token, hash_password, refresh_token, verify_password)

router = APIRouter(prefix="/auth", tags=["auth"])


def _tokens(user_id: int) -> TokenOut:
    return TokenOut(
        access_token=access_token(user_id),
        refresh_token=refresh_token(user_id),
        expires_in=settings.access_minutes * 60,
    )


@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    # FR-01 / AT-01: 18+ tasdig'isiz akkaunt yaratilmaydi
    if not body.is_adult_confirmed:
        raise HTTPException(422, "Ro'yxatdan o'tish uchun 18 yosh va undan katta ekaningizni tasdiqlang")
    if not body.accept_terms:
        raise HTTPException(422, "Foydalanish shartlari va maxfiylik siyosatiga rozilik berish shart")
    if db.scalar(select(User.id).where(User.email == body.email)):
        raise HTTPException(409, "Bu email bilan hisob allaqachon mavjud")

    user = User(email=body.email, password_hash=hash_password(body.password), role="user", is_adult_confirmed=True,
                full_name=(body.full_name or "").strip() or None)
    user.profile = FitnessProfile()
    user.settings = UserSettings(language_code="uz", reminders_enabled=False, privacy_version=settings.policy_version)
    user.consents = [
        ConsentEvent(policy_version=settings.policy_version, purpose="terms_and_privacy"),
        ConsentEvent(policy_version=settings.policy_version, purpose="age_18_plus_confirmation"),
    ]
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Bu email bilan hisob allaqachon mavjud")
    return _tokens(user.id)


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email))
    ok = verify_password(body.password, user.password_hash if user else None)
    if not user or not ok:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Email yoki parol noto'g'ri")
    return _tokens(user.id)


@router.post("/refresh", response_model=TokenOut)
def refresh(body: RefreshIn, db: Session = Depends(get_db)):
    data = decode_token(body.refresh_token, "refresh")
    if not data or not db.get(User, int(data["sub"])):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sessiya yaroqsiz yoki muddati tugagan")
    return _tokens(int(data["sub"]))


@router.post("/forgot-password", response_model=MessageOut, status_code=202)
def forgot_password(body: ForgotIn, db: Session = Depends(get_db)):
    """Email mavjudligini oshkor qilmaydi. Productionda token emailga yuboriladi (TODO: SMTP)."""
    user = db.scalar(select(User).where(User.email == body.email))
    out = MessageOut(message="Agar bu email ro'yxatdan o'tgan bo'lsa, tiklash ko'rsatmasi yuboriladi")
    if user and settings.expose_reset_token and not settings.is_production:
        out.reset_token = create_token(
            user.id, "reset", timedelta(minutes=settings.reset_minutes), {"pwd": user.password_hash[-12:]}
        )
    return out


@router.post("/reset-password", response_model=MessageOut)
def reset_password(body: ResetIn, db: Session = Depends(get_db)):
    data = decode_token(body.token, "reset")
    user = db.get(User, int(data["sub"])) if data else None
    # token parol o'zgargach yaroqsiz bo'ladi (pwd barmoq izi)
    if not user or data.get("pwd") != user.password_hash[-12:]:
        raise HTTPException(400, "Tiklash havolasi yaroqsiz yoki muddati tugagan")
    user.password_hash = hash_password(body.new_password)
    db.commit()
    return MessageOut(message="Parol yangilandi. Endi yangi parol bilan kiring")
