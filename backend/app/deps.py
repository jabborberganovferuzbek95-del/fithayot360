from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .database import get_db
from .models import User
from .security import decode_token

bearer = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer), db: Session = Depends(get_db)
) -> User:
    unauthorized = HTTPException(
        status.HTTP_401_UNAUTHORIZED, "Sessiya yaroqsiz yoki muddati tugagan", headers={"WWW-Authenticate": "Bearer"}
    )
    if creds is None:
        raise unauthorized
    data = decode_token(creds.credentials, "access")
    if not data:
        raise unauthorized
    user = db.get(User, int(data["sub"]))
    if user is None:
        raise unauthorized
    return user


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
