from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from sqlalchemy import select
from .database import get_db
from .models import FitnessProfile, User, UserSettings
from .security import decode_token

bearer = HTTPBearer(auto_error=False)


def get_or_create_default_user(db: Session) -> User:
    """Login talabi olib tashlanganda barcha amallar uchun standart foydalanuvchi."""
    user = db.scalar(select(User).order_by(User.id.asc()))
    if not user:
        user = User(
            email="foydalanuvchi@fithayot.uz",
            password_hash="not_required",
            role="user",
            is_adult_confirmed=True,
            full_name="FitHayot Foydalanuvchisi",
        )
        user.profile = FitnessProfile(
            goal="general_fitness",
            experience_level="beginner",
            preferred_location="home",
            daily_minutes=30,
        )
        user.settings = UserSettings(language_code="uz", reminders_enabled=True)
        db.add(user)
        db.commit()
        db.refresh(user)
    elif not user.profile:
        user.profile = FitnessProfile(
            goal="general_fitness",
            experience_level="beginner",
            preferred_location="home",
            daily_minutes=30,
        )
        db.commit()
        db.refresh(user)
    return user


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer), db: Session = Depends(get_db)
) -> User:
    if creds is not None and creds.credentials:
        data = decode_token(creds.credentials, "access")
        if data and "sub" in data:
            user = db.get(User, int(data["sub"]))
            if user is not None:
                return user
    return get_or_create_default_user(db)


def require_content_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "content_admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Bu amal faqat kontent administratori uchun")
    return user


def owned_or_404(db: Session, model, obj_id: int, user: User, label: str = "Resurs"):
    """Boshqa foydalanuvchi resursini 'topilmadi' deb ko'rsatamiz (mavjudligini oshkor qilmaymiz)."""
    obj = db.get(model, obj_id)
    if obj is None or getattr(obj, "user_id", None) != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"{label} topilmadi")
    return obj
