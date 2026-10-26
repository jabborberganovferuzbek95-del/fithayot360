from datetime import date, datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

Goal = Literal["general_fitness", "strength", "endurance", "flexibility", "active_lifestyle", "weight_loss", "muscle_gain",
               "stay_fit", "healthy_lifestyle", "reduce_stress", "more_energy"]
ActivityLevel = Literal["sedentary", "moderate", "active"]
Level = Literal["beginner", "intermediate", "advanced"]
Location = Literal["home", "gym", "outdoor", "mixed"]
Mode = Literal["home", "gym"]
Module = Literal["home", "gym", "active"]


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Auth ----------
def validate_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Parol kamida 8 belgidan iborat bo'lishi kerak")
    if len(v.encode("utf-8")) > 72:
        raise ValueError("Parol juda uzun (ko'pi bilan 72 bayt)")
    if not any(c.isalpha() for c in v) or not any(c.isdigit() for c in v):
        raise ValueError("Parolda kamida bitta harf va bitta raqam bo'lishi kerak")
    return v


class RegisterIn(BaseModel):
    full_name: Optional[str] = Field(None, max_length=100)
    email: EmailStr
    password: str
    is_adult_confirmed: bool
    accept_terms: bool

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.strip().lower()

    _pw = field_validator("password")(validate_password)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=200)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.strip().lower()


class RefreshIn(BaseModel):
    refresh_token: str


class ForgotIn(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.strip().lower()


class ResetIn(BaseModel):
    token: str
    new_password: str
    _pw = field_validator("new_password")(validate_password)


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class MessageOut(BaseModel):
    message: str
    reset_token: Optional[str] = None  # faqat development rejimida


# ---------- Me ----------
class ProfileOut(ORM):
    goal: Optional[Goal] = None
    experience_level: Optional[Level] = None
    preferred_location: Optional[Location] = None
    daily_minutes: Optional[int] = None
    activity_level: Optional[ActivityLevel] = None


class SettingsOut(ORM):
    language_code: str
    reminders_enabled: bool
    privacy_version: Optional[str] = None


class MeOut(BaseModel):
    id: int
    email: str
    full_name: Optional[str] = None
    role: str
    is_adult_confirmed: bool
    created_at: datetime
    profile: ProfileOut
    settings: SettingsOut
    profile_completed: bool


class MeUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    activity_level: Optional[ActivityLevel] = None
    goal: Optional[Goal] = None
    experience_level: Optional[Level] = None
    preferred_location: Optional[Location] = None
    daily_minutes: Optional[int] = Field(None, ge=5, le=300)
    language_code: Optional[Literal["uz", "ru", "en"]] = None
    reminders_enabled: Optional[bool] = None


class DeleteAccountIn(BaseModel):
    password: str


# ---------- Catalog ----------
class CategoryOut(ORM):
    id: int
    code: str
    name: str
    mode: Mode


class ExerciseBrief(ORM):
    id: int
    title: str
    mode: Mode
    equipment: str


class ExerciseOut(ORM):
    id: int
    title: str
    description: str
    equipment: str
    difficulty: Level
    duration_hint: Optional[str] = None
    safety_note: str
    image_url: Optional[str] = None
    is_active: bool
    category: CategoryOut


class ExerciseCreate(BaseModel):
    category_id: int
    title: str = Field(min_length=2, max_length=150)
    description: str = Field(min_length=10, max_length=4000)
    equipment: str = Field("none", max_length=100)
    difficulty: Level = "beginner"
    duration_hint: Optional[str] = Field(None, max_length=50)
    safety_note: str = Field(min_length=5, max_length=2000)
    image_url: Optional[str] = Field(None, max_length=500)
    is_active: bool = True


class ExerciseUpdate(BaseModel):
    category_id: Optional[int] = None
    title: Optional[str] = Field(None, min_length=2, max_length=150)
    description: Optional[str] = Field(None, min_length=10, max_length=4000)
    equipment: Optional[str] = Field(None, max_length=100)
    difficulty: Optional[Level] = None
    duration_hint: Optional[str] = Field(None, max_length=50)
    safety_note: Optional[str] = Field(None, min_length=5, max_length=2000)
    image_url: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = None


# ---------- Plans ----------
class PlanItemIn(BaseModel):
    exercise_id: int
    planned_date: date
    planned_minutes: int = Field(10, ge=1, le=300)
    sort_order: int = Field(0, ge=0, le=1000)


class PlanItemUpdate(BaseModel):
    exercise_id: Optional[int] = None
    planned_date: Optional[date] = None
    planned_minutes: Optional[int] = Field(None, ge=1, le=300)
    sort_order: Optional[int] = Field(None, ge=0, le=1000)


class PlanItemOut(ORM):
    id: int
    exercise_id: int
    planned_date: date
    planned_minutes: int
    sort_order: int
    exercise: ExerciseBrief
    is_completed: bool = False


class PlanCreate(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    starts_on: date
    ends_on: date
    items: List[PlanItemIn] = []

    @model_validator(mode="after")
    def _dates(self):
        if self.ends_on < self.starts_on:
            raise ValueError("Tugash sanasi boshlanish sanasidan oldin bo'lishi mumkin emas")
        return self


class PlanUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    starts_on: Optional[date] = None
    ends_on: Optional[date] = None
    status: Optional[Literal["active", "archived"]] = None


class PlanOut(ORM):
    id: int
    title: str
    starts_on: date
    ends_on: date
    status: str
    items: List[PlanItemOut] = []


class PlanBrief(ORM):
    id: int
    title: str
    starts_on: date
    ends_on: date
    status: str


# ---------- Sessions ----------
class SessionCreate(BaseModel):
    mode: Mode
    plan_id: Optional[int] = None


class SessionUpdate(BaseModel):
    status: Optional[Literal["completed", "interrupted"]] = None
    finished_at: Optional[datetime] = None
    notes: Optional[str] = Field(None, max_length=1000)


class LogCreate(BaseModel):
    exercise_id: int
    set_no: int = Field(1, ge=1, le=100)
    reps: Optional[int] = Field(None, ge=1, le=1000)
    weight_kg: Optional[float] = Field(None, ge=0, le=1000)
    duration_seconds: Optional[int] = Field(None, ge=1, le=86400)
    plan_item_id: Optional[int] = None

    @model_validator(mode="after")
    def _has_value(self):
        if self.reps is None and self.duration_seconds is None:
            raise ValueError("Takror yoki davomiylik (soniya) kiritilishi shart")
        return self


class LogUpdate(BaseModel):
    set_no: Optional[int] = Field(None, ge=1, le=100)
    reps: Optional[int] = Field(None, ge=1, le=1000)
    weight_kg: Optional[float] = Field(None, ge=0, le=1000)
    duration_seconds: Optional[int] = Field(None, ge=1, le=86400)


class LogOut(ORM):
    id: int
    session_id: int
    exercise_id: int
    exercise: ExerciseBrief
    plan_item_id: Optional[int] = None
    set_no: int
    reps: Optional[int] = None
    weight_kg: Optional[float] = None
    duration_seconds: Optional[int] = None
    completed_at: datetime


class SessionBrief(ORM):
    id: int
    mode: Mode
    status: str
    plan_id: Optional[int] = None
    started_at: datetime
    finished_at: Optional[datetime] = None
    duration_minutes: Optional[int] = None
    notes: Optional[str] = None


class SessionOut(SessionBrief):
    logs: List[LogOut] = []


# ---------- Activities ----------
class ActivityTypeOut(ORM):
    id: int
    code: str
    title: str


class ActivityCreate(BaseModel):
    activity_type_id: Optional[int] = None
    activity_type_code: Optional[str] = None
    occurred_at: Optional[datetime] = None
    duration_minutes: int = Field(ge=1, le=1440)
    distance_km: Optional[float] = Field(None, ge=0, le=1000)
    note: Optional[str] = Field(None, max_length=500)

    @model_validator(mode="after")
    def _type(self):
        if self.activity_type_id is None and not self.activity_type_code:
            raise ValueError("Faollik turini tanlang")
        return self


class ActivityUpdate(BaseModel):
    activity_type_id: Optional[int] = None
    occurred_at: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(None, ge=1, le=1440)
    distance_km: Optional[float] = Field(None, ge=0, le=1000)
    note: Optional[str] = Field(None, max_length=500)


class ActivityOut(ORM):
    id: int
    activity_type: ActivityTypeOut
    occurred_at: datetime
    duration_minutes: int
    distance_km: Optional[float] = None
    note: Optional[str] = None


# ---------- Progress / History ----------
class DayStat(BaseModel):
    date: date
    minutes: int
    sessions: int
    activities: int


class WeeklyProgress(BaseModel):
    week_start: date
    week_end: date
    total_sessions: int
    total_activity_entries: int
    total_active_minutes: int
    minutes_by_module: dict
    planned_items: int
    completed_items: int
    planned_completion_rate: Optional[float] = None  # None => "N/A" (reja yo'q)
    days: List[DayStat]


class HistoryItem(BaseModel):
    kind: Literal["session", "activity"]
    id: int
    module: Module
    title: str
    occurred_at: datetime
    duration_minutes: Optional[int] = None
    distance_km: Optional[float] = None
    detail: Optional[str] = None


# ======================= Wellness kengaytmasi (v2) =======================
MealType = Literal["breakfast", "lunch", "dinner", "snack"]
RecipeType = Literal["breakfast", "lunch", "dinner", "snack", "detox"]
MedCategory = Literal["stress", "focus", "sleep", "motivation"]


class GoalsOut(ORM):
    steps_goal: int
    water_goal_ml: int
    sleep_goal_min: int
    workout_goal_min: int
    calorie_goal: int


class GoalsUpdate(BaseModel):
    steps_goal: Optional[int] = Field(None, ge=1000, le=100000)
    water_goal_ml: Optional[int] = Field(None, ge=500, le=10000)
    sleep_goal_min: Optional[int] = Field(None, ge=240, le=720)
    workout_goal_min: Optional[int] = Field(None, ge=5, le=300)
    calorie_goal: Optional[int] = Field(None, ge=800, le=6000)


class WaterIn(BaseModel):
    amount_ml: int = Field(ge=50, le=2000)


class WaterOut(ORM):
    id: int
    amount_ml: int
    logged_at: datetime


class WaterDay(BaseModel):
    day: date
    total_ml: int
    goal_ml: int
    entries: List[WaterOut]


class SleepIn(BaseModel):
    duration_min: int = Field(ge=1, le=1440)
    quality: Optional[int] = Field(None, ge=1, le=5)


class SleepOut(ORM):
    sleep_date: date
    duration_min: int
    quality: Optional[int] = None


class StepsIn(BaseModel):
    steps: int = Field(ge=0, le=200000)


class StepsOut(ORM):
    day: date
    steps: int


class RecipeOut(ORM):
    id: int
    title: str
    meal_type: RecipeType
    kcal: int
    prep_minutes: int
    ingredients: str
    instructions: str
    image_url: Optional[str] = None
    is_active: bool


class RecipeCreate(BaseModel):
    title: str = Field(min_length=2, max_length=150)
    meal_type: RecipeType
    kcal: int = Field(ge=0, le=5000)
    prep_minutes: int = Field(15, ge=1, le=600)
    ingredients: str = Field(min_length=3, max_length=4000)
    instructions: str = Field(min_length=3, max_length=6000)
    image_url: Optional[str] = Field(None, max_length=500)
    is_active: bool = True


class RecipeUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=2, max_length=150)
    meal_type: Optional[RecipeType] = None
    kcal: Optional[int] = Field(None, ge=0, le=5000)
    prep_minutes: Optional[int] = Field(None, ge=1, le=600)
    ingredients: Optional[str] = Field(None, min_length=3, max_length=4000)
    instructions: Optional[str] = Field(None, min_length=3, max_length=6000)
    image_url: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = None


class MealIn(BaseModel):
    recipe_id: Optional[int] = None
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    meal_type: MealType
    kcal: Optional[int] = Field(None, ge=0, le=5000)
    eaten_at: Optional[datetime] = None

    @model_validator(mode="after")
    def _need(self):
        if self.recipe_id is None and (not self.title or self.kcal is None):
            raise ValueError("Retseptni tanlang yoki ovqat nomi va kkal ni kiriting")
        return self


class MealOut(ORM):
    id: int
    recipe_id: Optional[int] = None
    title: str
    meal_type: MealType
    kcal: int
    eaten_at: datetime


class MeditationOut(ORM):
    id: int
    title: str
    category: MedCategory
    duration_min: int
    description: str
    guide: str


class MeditationLogIn(BaseModel):
    item_id: Optional[int] = None
    duration_min: int = Field(ge=1, le=240)


class MeditationLogOut(ORM):
    id: int
    item_id: Optional[int] = None
    duration_min: int
    completed_at: datetime


# ======================= v3 =======================
class ProgramItemOut(ORM):
    id: int
    exercise: ExerciseBrief
    seconds: Optional[int] = None
    reps: Optional[int] = None
    sort_order: int


class ProgramBrief(ORM):
    id: int
    title: str
    description: str
    mode: Mode
    kind: Literal["full_body", "strength", "stretch", "cardio"]
    difficulty: Level
    duration_min: int
    image_url: Optional[str] = None
    exercise_count: int


class ProgramOut(ProgramBrief):
    items: List[ProgramItemOut] = []


class HabitIn(BaseModel):
    title: str = Field(min_length=1, max_length=100)


class HabitOut(ORM):
    id: int
    title: str


class HabitCheckIn(BaseModel):
    done: bool
