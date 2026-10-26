import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt

from .config import settings

ALGORITHM = "HS256"
# Foydalanuvchi topilmaganda ham bcrypt vaqtini sarflash (login vaqti orqali email aniqlashga qarshi)
_DUMMY_HASH = bcrypt.hashpw(b"dummy-password-1", bcrypt.gensalt(rounds=10)).decode()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode()


def verify_password(password: str, password_hash: Optional[str]) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), (password_hash or _DUMMY_HASH).encode()) and bool(password_hash)
    except ValueError:
        return False


def create_token(sub: int, token_type: str, expires: timedelta, extra: Optional[dict] = None) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": str(sub), "type": token_type, "iat": now, "exp": now + expires, "jti": uuid.uuid4().hex}
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: str) -> Optional[dict]:
    try:
        data = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    if data.get("type") != expected_type:
        return None
    return data


def access_token(user_id: int) -> str:
    return create_token(user_id, "access", timedelta(minutes=settings.access_minutes))


def refresh_token(user_id: int) -> str:
    return create_token(user_id, "refresh", timedelta(days=settings.refresh_days))
