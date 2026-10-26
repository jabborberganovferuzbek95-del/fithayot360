import os
from dataclasses import dataclass


def _bool(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    env: str = os.getenv("APP_ENV", "development")
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg2://fithayot:fithayot@localhost:5432/fithayot360",
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-only-change-me")
    access_minutes: int = int(os.getenv("ACCESS_TOKEN_MINUTES", "30"))
    refresh_days: int = int(os.getenv("REFRESH_TOKEN_DAYS", "14"))
    reset_minutes: int = int(os.getenv("RESET_TOKEN_MINUTES", "30"))
    tz_offset_minutes: int = int(os.getenv("APP_TZ_OFFSET_MINUTES", "300"))
    cors_origins: str = os.getenv("CORS_ORIGINS", "*")
    expose_reset_token: bool = _bool("EXPOSE_RESET_TOKEN", "false")
    auto_create_tables: bool = _bool("AUTO_CREATE_TABLES", "true")
    seed_on_start: bool = _bool("SEED_ON_START", "true")
    policy_version: str = os.getenv("POLICY_VERSION", "2026-10")
    admin_email: str = os.getenv("ADMIN_EMAIL", "")
    admin_password: str = os.getenv("ADMIN_PASSWORD", "")

    @property
    def is_production(self) -> bool:
        return self.env.lower() == "production"


settings = Settings()
