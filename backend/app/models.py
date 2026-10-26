"""FitHayot 360 ma'lumotlar modeli (texnik topshiriq 7-bo'lim).

TT'dagi jadvallarga qo'shimcha ustunlar (README'da izohlangan):
  * workout_sessions.notes            - S15 "qaydlar"
  * exercise_logs.plan_item_id        - reja bandining bajarilganini aniq aniqlash (FR-15)
  * exercise_logs.idempotency_key,
    activity_logs.idempotency_key     - takror yuborishdan himoya (AT-10)
"""
from datetime import date, datetime, timezone
from typing import List, Optional

from sqlalchemy import (
    Boolean, CheckConstraint, Date, DateTime, Float, ForeignKey, Index, Integer,
    String, Text, TypeDecorator, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class UTCDateTime(TypeDecorator):
    """Har doim UTC (tz-aware) saqlaydi va qaytaradi (SQLite ham, PostgreSQL ham)."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('user','content_admin','system_admin')", name="ck_users_role"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="user")
    is_adult_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    full_name: Mapped[Optional[str]] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)

    profile: Mapped["FitnessProfile"] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")
    settings: Mapped["UserSettings"] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")
    plans: Mapped[List["WorkoutPlan"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    sessions: Mapped[List["WorkoutSession"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    activities: Mapped[List["ActivityLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    consents: Mapped[List["ConsentEvent"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class FitnessProfile(Base):
    __tablename__ = "fitness_profiles"
    __table_args__ = (
        CheckConstraint("daily_minutes IS NULL OR (daily_minutes BETWEEN 5 AND 300)", name="ck_profile_minutes"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    goal: Mapped[Optional[str]] = mapped_column(String(30))
    experience_level: Mapped[Optional[str]] = mapped_column(String(20))
    preferred_location: Mapped[Optional[str]] = mapped_column(String(20))
    daily_minutes: Mapped[Optional[int]] = mapped_column(Integer)
    activity_level: Mapped[Optional[str]] = mapped_column(String(20))
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, onupdate=utcnow)

    user: Mapped[User] = relationship(back_populates="profile")

    @property
    def is_complete(self) -> bool:
        return all([self.goal, self.experience_level, self.preferred_location, self.daily_minutes])


class UserSettings(Base):
    __tablename__ = "user_settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    language_code: Mapped[str] = mapped_column(String(5), default="uz")
    reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    privacy_version: Mapped[Optional[str]] = mapped_column(String(20))

    user: Mapped[User] = relationship(back_populates="settings")


class ConsentEvent(Base):
    __tablename__ = "consent_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    policy_version: Mapped[str] = mapped_column(String(20))
    purpose: Mapped[str] = mapped_column(String(60))
    accepted_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(UTCDateTime)

    user: Mapped[User] = relationship(back_populates="consents")


class ExerciseCategory(Base):
    __tablename__ = "exercise_categories"
    __table_args__ = (CheckConstraint("mode IN ('home','gym')", name="ck_category_mode"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(40), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    mode: Mapped[str] = mapped_column(String(10))


class Exercise(Base):
    __tablename__ = "exercises"
    __table_args__ = (
        CheckConstraint("difficulty IN ('beginner','intermediate','advanced')", name="ck_exercise_difficulty"),
        Index("ix_exercises_category_active", "category_id", "is_active"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("exercise_categories.id"))
    title: Mapped[str] = mapped_column(String(150), index=True)
    description: Mapped[str] = mapped_column(Text)
    equipment: Mapped[str] = mapped_column(String(100), default="none")
    difficulty: Mapped[str] = mapped_column(String(20), default="beginner")
    duration_hint: Mapped[Optional[str]] = mapped_column(String(50))
    safety_note: Mapped[str] = mapped_column(Text)
    image_url: Mapped[Optional[str]] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    category: Mapped[ExerciseCategory] = relationship(lazy="joined")

    @property
    def mode(self) -> str:
        return self.category.mode


class ContentAudit(Base):
    __tablename__ = "content_audit"

    id: Mapped[int] = mapped_column(primary_key=True)
    admin_user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    exercise_id: Mapped[int] = mapped_column(ForeignKey("exercises.id"))
    action: Mapped[str] = mapped_column(String(20))
    occurred_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


class WorkoutPlan(Base):
    __tablename__ = "workout_plans"
    __table_args__ = (
        CheckConstraint("ends_on >= starts_on", name="ck_plan_dates"),
        CheckConstraint("status IN ('active','archived')", name="ck_plan_status"),
        Index("ix_plans_user", "user_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(150))
    starts_on: Mapped[date] = mapped_column(Date)
    ends_on: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(15), default="active")

    user: Mapped[User] = relationship(back_populates="plans")
    items: Mapped[List["PlanItem"]] = relationship(
        back_populates="plan", cascade="all, delete-orphan", order_by="PlanItem.planned_date, PlanItem.sort_order"
    )


class PlanItem(Base):
    __tablename__ = "plan_items"
    __table_args__ = (
        CheckConstraint("planned_minutes > 0", name="ck_item_minutes"),
        Index("ix_plan_items_plan_date", "plan_id", "planned_date"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    plan_id: Mapped[int] = mapped_column(ForeignKey("workout_plans.id", ondelete="CASCADE"))
    exercise_id: Mapped[int] = mapped_column(ForeignKey("exercises.id"))
    planned_date: Mapped[date] = mapped_column(Date)
    planned_minutes: Mapped[int] = mapped_column(Integer, default=10)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    plan: Mapped[WorkoutPlan] = relationship(back_populates="items")
    exercise: Mapped[Exercise] = relationship(lazy="joined")


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"
    __table_args__ = (
        CheckConstraint("finished_at IS NULL OR finished_at >= started_at", name="ck_session_times"),
        CheckConstraint("status IN ('in_progress','completed','interrupted')", name="ck_session_status"),
        CheckConstraint("mode IN ('home','gym')", name="ck_session_mode"),
        Index("ix_sessions_user_started", "user_id", "started_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    plan_id: Mapped[Optional[int]] = mapped_column(ForeignKey("workout_plans.id", ondelete="SET NULL"))
    started_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    finished_at: Mapped[Optional[datetime]] = mapped_column(UTCDateTime)
    status: Mapped[str] = mapped_column(String(15), default="in_progress")
    mode: Mapped[str] = mapped_column(String(10))
    notes: Mapped[Optional[str]] = mapped_column(Text)

    user: Mapped[User] = relationship(back_populates="sessions")
    logs: Mapped[List["ExerciseLog"]] = relationship(
        back_populates="session", cascade="all, delete-orphan", order_by="ExerciseLog.id"
    )

    @property
    def duration_minutes(self) -> Optional[int]:
        if self.finished_at is None:
            return None
        return max(0, round((self.finished_at - self.started_at).total_seconds() / 60))


class ExerciseLog(Base):
    __tablename__ = "exercise_logs"
    __table_args__ = (
        CheckConstraint("set_no > 0", name="ck_log_set"),
        CheckConstraint("reps IS NULL OR reps > 0", name="ck_log_reps"),
        CheckConstraint("weight_kg IS NULL OR weight_kg >= 0", name="ck_log_weight"),
        CheckConstraint("duration_seconds IS NULL OR duration_seconds > 0", name="ck_log_duration"),
        CheckConstraint("reps IS NOT NULL OR duration_seconds IS NOT NULL", name="ck_log_has_value"),
        UniqueConstraint("session_id", "idempotency_key", name="uq_log_idem"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("workout_sessions.id", ondelete="CASCADE"), index=True)
    exercise_id: Mapped[int] = mapped_column(ForeignKey("exercises.id"))
    plan_item_id: Mapped[Optional[int]] = mapped_column(ForeignKey("plan_items.id", ondelete="SET NULL"), index=True)
    set_no: Mapped[int] = mapped_column(Integer, default=1)
    reps: Mapped[Optional[int]] = mapped_column(Integer)
    weight_kg: Mapped[Optional[float]] = mapped_column(Float)
    duration_seconds: Mapped[Optional[int]] = mapped_column(Integer)
    completed_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(64))

    session: Mapped[WorkoutSession] = relationship(back_populates="logs")
    exercise: Mapped[Exercise] = relationship(lazy="joined")


class ActivityType(Base):
    __tablename__ = "activity_types"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(30), unique=True)
    title: Mapped[str] = mapped_column(String(80))


class ActivityLog(Base):
    __tablename__ = "activity_logs"
    __table_args__ = (
        CheckConstraint("duration_minutes > 0", name="ck_activity_duration"),
        CheckConstraint("distance_km IS NULL OR distance_km >= 0", name="ck_activity_distance"),
        UniqueConstraint("user_id", "idempotency_key", name="uq_activity_idem"),
        Index("ix_activity_user_time", "user_id", "occurred_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    activity_type_id: Mapped[int] = mapped_column(ForeignKey("activity_types.id"))
    occurred_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    duration_minutes: Mapped[int] = mapped_column(Integer)
    distance_km: Mapped[Optional[float]] = mapped_column(Float)
    note: Mapped[Optional[str]] = mapped_column(String(500))
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(64))

    user: Mapped[User] = relationship(back_populates="activities")
    activity_type: Mapped[ActivityType] = relationship(lazy="joined")


# ======================= Wellness kengaytmasi (v2) =======================
class UserGoals(Base):
    """Foydalanuvchi o'zi belgilaydigan kundalik maqsadlar (tibbiy tavsiya emas)."""
    __tablename__ = "user_goals"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    steps_goal: Mapped[int] = mapped_column(Integer, default=10000)
    water_goal_ml: Mapped[int] = mapped_column(Integer, default=2500)
    sleep_goal_min: Mapped[int] = mapped_column(Integer, default=450)
    workout_goal_min: Mapped[int] = mapped_column(Integer, default=30)
    calorie_goal: Mapped[int] = mapped_column(Integer, default=2000)


class WaterLog(Base):
    __tablename__ = "water_logs"
    __table_args__ = (
        CheckConstraint("amount_ml > 0", name="ck_water_amount"),
        UniqueConstraint("user_id", "idempotency_key", name="uq_water_idem"),
        Index("ix_water_user_time", "user_id", "logged_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    amount_ml: Mapped[int] = mapped_column(Integer)
    logged_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(64))


class SleepLog(Base):
    __tablename__ = "sleep_logs"
    __table_args__ = (
        CheckConstraint("duration_min > 0", name="ck_sleep_duration"),
        CheckConstraint("quality IS NULL OR (quality BETWEEN 1 AND 5)", name="ck_sleep_quality"),
        UniqueConstraint("user_id", "sleep_date", name="uq_sleep_day"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    sleep_date: Mapped[date] = mapped_column(Date)  # uyg'ongan kun
    duration_min: Mapped[int] = mapped_column(Integer)
    quality: Mapped[Optional[int]] = mapped_column(Integer)


class StepLog(Base):
    """Qadamlar qo'lda kiritiladi (TT: avtomatik sensor/GPS yo'q)."""
    __tablename__ = "step_logs"
    __table_args__ = (
        CheckConstraint("steps >= 0", name="ck_steps_nonneg"),
        UniqueConstraint("user_id", "day", name="uq_steps_day"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    day: Mapped[date] = mapped_column(Date)
    steps: Mapped[int] = mapped_column(Integer)


class Recipe(Base):
    __tablename__ = "recipes"
    __table_args__ = (
        CheckConstraint("meal_type IN ('breakfast','lunch','dinner','snack','detox')", name="ck_recipe_type"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(150), index=True)
    meal_type: Mapped[str] = mapped_column(String(15))
    kcal: Mapped[int] = mapped_column(Integer)
    prep_minutes: Mapped[int] = mapped_column(Integer, default=15)
    ingredients: Mapped[str] = mapped_column(Text)
    instructions: Mapped[str] = mapped_column(Text)
    image_url: Mapped[Optional[str]] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class MealLog(Base):
    __tablename__ = "meal_logs"
    __table_args__ = (
        CheckConstraint("kcal >= 0", name="ck_meal_kcal"),
        CheckConstraint("meal_type IN ('breakfast','lunch','dinner','snack')", name="ck_meal_type"),
        Index("ix_meal_user_time", "user_id", "eaten_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    recipe_id: Mapped[Optional[int]] = mapped_column(ForeignKey("recipes.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(150))
    meal_type: Mapped[str] = mapped_column(String(15))
    kcal: Mapped[int] = mapped_column(Integer)
    eaten_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


class MeditationItem(Base):
    __tablename__ = "meditation_items"
    __table_args__ = (
        CheckConstraint("category IN ('stress','focus','sleep','motivation')", name="ck_med_category"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(150))
    category: Mapped[str] = mapped_column(String(15))
    duration_min: Mapped[int] = mapped_column(Integer)
    description: Mapped[str] = mapped_column(Text)
    guide: Mapped[str] = mapped_column(Text)  # matnli yo'riqnoma (audio yo'q)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class MeditationLog(Base):
    __tablename__ = "meditation_logs"
    __table_args__ = (CheckConstraint("duration_min > 0", name="ck_medlog_duration"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    item_id: Mapped[Optional[int]] = mapped_column(ForeignKey("meditation_items.id", ondelete="SET NULL"))
    duration_min: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


class PremiumInterest(Base):
    """To'lov tizimi yo'q: foydalanuvchi faqat 'xabar bering' ro'yxatiga yoziladi."""
    __tablename__ = "premium_interest"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


# ======================= v3: dasturlar va odatlar =======================
class Program(Base):
    __tablename__ = "programs"
    __table_args__ = (
        CheckConstraint("mode IN ('home','gym')", name="ck_program_mode"),
        CheckConstraint("kind IN ('full_body','strength','stretch','cardio')", name="ck_program_kind"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(150), index=True)
    description: Mapped[str] = mapped_column(Text)
    mode: Mapped[str] = mapped_column(String(10))
    kind: Mapped[str] = mapped_column(String(15))
    difficulty: Mapped[str] = mapped_column(String(20), default="beginner")
    duration_min: Mapped[int] = mapped_column(Integer, default=20)
    image_url: Mapped[Optional[str]] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    items: Mapped[List["ProgramItem"]] = relationship(
        back_populates="program", cascade="all, delete-orphan", order_by="ProgramItem.sort_order"
    )

    @property
    def exercise_count(self) -> int:
        return len(self.items)


class ProgramItem(Base):
    __tablename__ = "program_items"
    __table_args__ = (CheckConstraint("seconds IS NOT NULL OR reps IS NOT NULL", name="ck_pitem_target"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    program_id: Mapped[int] = mapped_column(ForeignKey("programs.id", ondelete="CASCADE"), index=True)
    exercise_id: Mapped[int] = mapped_column(ForeignKey("exercises.id"))
    seconds: Mapped[Optional[int]] = mapped_column(Integer)
    reps: Mapped[Optional[int]] = mapped_column(Integer)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    program: Mapped[Program] = relationship(back_populates="items")
    exercise: Mapped[Exercise] = relationship(lazy="joined")


class Habit(Base):
    """Foydalanuvchining shaxsiy odati (avtomatik odatlardan tashqari)."""
    __tablename__ = "habits"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


class HabitCheck(Base):
    __tablename__ = "habit_checks"
    __table_args__ = (UniqueConstraint("habit_id", "day", name="uq_habit_day"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    habit_id: Mapped[int] = mapped_column(ForeignKey("habits.id", ondelete="CASCADE"), index=True)
    day: Mapped[date] = mapped_column(Date)
