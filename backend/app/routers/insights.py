"""Profil xulosasi, yutuqlar, bildirishnomalar (ma'lumotlardan hisoblangan maslahatlar) va qoidaga asoslangan maslahatchi.
DIQQAT: bu sun'iy intellekt emas va tibbiy tavsiya emas."""
from datetime import timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import MeditationLog, PremiumInterest, Program, Recipe, User, WorkoutSession, utcnow
from .dashboard import collect
from .progress import local_date
from .wellness import goals_of

router = APIRouter(tags=["insights"])
NOTE = "Bu qoidalarga asoslangan maslahat: sun'iy intellekt va tibbiy tavsiya emas."


def _local_hour() -> int:
    return ((utcnow() + timedelta(minutes=settings.tz_offset_minutes)).hour)


def _is_active(m: dict) -> bool:
    return m["active_minutes"] > 0 or m["meditation_min"] > 0 or m["steps"] > 0


def _streak(days: dict, today) -> int:
    d = today if _is_active(days[today]) else today - timedelta(days=1)
    n = 0
    while d in days and _is_active(days[d]):
        n += 1
        d -= timedelta(days=1)
    return n


@router.get("/me/summary")
def my_summary(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = local_date(utcnow())
    days = collect(db, user, today - timedelta(days=89), today)
    g = goals_of(db, user)
    sessions = db.scalars(select(WorkoutSession).where(WorkoutSession.user_id == user.id, WorkoutSession.status == "completed")).all()
    med_total = sum(r.duration_min for r in db.scalars(select(MeditationLog).where(MeditationLog.user_id == user.id)))
    streak = _streak(days, today)
    last30 = [days[today - timedelta(days=i)] for i in range(30)]
    ach = [
        ("first_workout", "Birinchi mashg'ulot", "Birinchi seansni yakunladingiz", len(sessions) >= 1),
        ("ten_workouts", "10 ta mashg'ulot", "10 ta seans yakunlandi", len(sessions) >= 10),
        ("streak_3", "3 kunlik seriya", "3 kun ketma-ket faol bo'ldingiz", streak >= 3),
        ("streak_7", "Haftalik seriya", "7 kun ketma-ket faol bo'ldingiz", streak >= 7),
        ("steps_goal", "Qadam maqsadi", "Qadam maqsadini bajardingiz", any(d["steps"] >= g.steps_goal for d in days.values())),
        ("water_goal", "Suv maqsadi", "Kunlik suv maqsadiga yetdingiz", any(d["water_ml"] >= g.water_goal_ml for d in days.values())),
        ("meditation_30", "Xotirjamlik", "Jami 30 daqiqa meditatsiya qildingiz", med_total >= 30),
    ]
    return {
        "sessions_total": len(sessions),
        "minutes_total": sum(s.duration_minutes or 0 for s in sessions),
        "active_days_30": sum(1 for d in last30 if _is_active(d)),
        "streak": streak,
        "achievements": [{"key": k, "title": t, "description": d, "earned": bool(e)} for k, t, d, e in ach],
    }


@router.get("/insights")
def insights(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today = local_date(utcnow())
    days = collect(db, user, today - timedelta(days=29), today)
    m, g, h = days[today], goals_of(db, user), _local_hour()
    out = []

    def add(kind, icon, title, body):
        out.append({"id": f"{kind}-{len(out)}", "kind": kind, "icon": icon, "title": title, "body": body})

    if h >= 12 and m["water_ml"] < g.water_goal_ml * 0.5:
        add("tip", "water", "Suv ichishni unutmang", f"Bugun {m['water_ml'] / 1000:g} L ichdingiz, maqsad {g.water_goal_ml / 1000:g} L.")
    if g.steps_goal * 0.8 <= m["steps"] < g.steps_goal:
        add("tip", "steps", "Qadam maqsadiga oz qoldi", f"Yana {g.steps_goal - m['steps']} qadam qoldi.")
    if h >= 17 and m["active_minutes"] == 0:
        add("tip", "workout", "Bugun hali harakat qayd qilinmagan", "Qisqa mashq yoki yurishni qayd eting, hatto 10 daqiqa ham yaxshi.")
    if m["sleep_min"] == 0 and h >= 8:
        add("tip", "sleep", "Uyqu qaydini kiriting", "Kecha qancha uxlaganingizni yozib qo'ying: shunda statistika to'liq bo'ladi.")
    streak = _streak(days, today)
    if streak >= 3:
        add("tip", "streak", f"{streak} kunlik seriya!", "Har kuni kamida bitta faollik qayd qilyapsiz. Davom eting.")
    week = sum(days[today - timedelta(days=i)]["active_minutes"] for i in range(7))
    if week > 0:
        add("tip", "stats", "Haftalik xulosa", f"Oxirgi 7 kunda {week} daqiqa faol bo'ldingiz.")
    if not user.profile.is_complete:
        add("system", "profile", "Profilni to'ldiring", "Maqsad va tajriba darajasini kiritsangiz, tavsiyalar aniqroq bo'ladi.")
    if not db.scalar(select(PremiumInterest.id).where(PremiumInterest.user_id == user.id)):
        add("system", "premium", "Premium tez orada", "Premium hali ishga tushmagan. Qiziqsangiz, xabar berish ro'yxatiga yoziling.")
    return out


@router.get("/coach/ask")
def coach_ask(
    topic: str = Query("today", pattern="^(today|workout|meal|status)$"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = local_date(utcnow())
    m = collect(db, user, today, today)[today]
    g = goals_of(db, user)
    resp = {"topic": topic, "text": "", "action": None, "note": NOTE}

    if topic == "status":
        resp["text"] = (
            f"Bugun: {m['steps']} qadam (maqsad {g.steps_goal}), suv {m['water_ml'] / 1000:g} L (maqsad {g.water_goal_ml / 1000:g} L), "
            f"faol vaqt {m['active_minutes']} daqiqa, ovqat {m['calories_in']} kkal."
        )
    elif topic == "today":
        todo = []
        if m["water_ml"] < g.water_goal_ml:
            todo.append(f"{(g.water_goal_ml - m['water_ml']) / 1000:.1f} L suv ichish")
        if m["steps"] < g.steps_goal:
            todo.append(f"yana {g.steps_goal - m['steps']} qadam yurish")
        if m["active_minutes"] < g.workout_goal_min:
            todo.append(f"{g.workout_goal_min - m['active_minutes']} daqiqa mashq qilish")
        if m["meditation_min"] < 10:
            todo.append("10 daqiqa meditatsiya")
        resp["text"] = ("Bugun uchun maqsadlaringiz: " + "; ".join(todo) + ".") if todo else "Bugungi barcha maqsadlarni bajardingiz. Barakalla!"
    elif topic == "workout":
        loc = user.profile.preferred_location
        mode = "gym" if loc == "gym" else "home"
        level = user.profile.experience_level or "beginner"
        progs = db.scalars(select(Program).where(Program.is_active.is_(True), Program.mode == mode)).unique().all()
        pick = next((p for p in progs if p.difficulty == level), progs[0] if progs else None)
        if pick:
            resp["text"] = f"Sizga \"{pick.title}\" mos: {pick.duration_min} daqiqa, {pick.exercise_count} ta mashq."
            resp["action"] = {"type": "program", "id": pick.id}
        else:
            resp["text"] = "Hozircha mos dastur topilmadi."
    else:  # meal
        left = g.calorie_goal - m["calories_in"]
        want = "breakfast" if _local_hour() < 11 else ("lunch" if _local_hour() < 16 else "dinner")
        recs = db.scalars(select(Recipe).where(Recipe.is_active.is_(True), Recipe.kcal <= max(left, 0))).all()
        pick = next((r for r in recs if r.meal_type == want), recs[0] if recs else None)
        if left <= 0:
            resp["text"] = "Bugungi kaloriya maqsadingiz to'ldi."
        elif pick:
            resp["text"] = f"\"{pick.title}\" mos keladi: taxminan {pick.kcal} kkal, {pick.prep_minutes} daqiqa. Bugun yana ~{left} kkal qoldi."
            resp["action"] = {"type": "recipe", "id": pick.id}
        else:
            resp["text"] = "Kaloriya maqsadingizga mos retsept topilmadi."
    return resp
