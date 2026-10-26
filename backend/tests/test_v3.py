"""v3: dasturlar, odatlar, profil xulosasi, bildirishnomalar, maslahatchi, mini-migratsiya."""
from datetime import date, timedelta

import pytest
from sqlalchemy import create_engine, inspect, text

TODAY = date.today()


def test_programs(client, user):
    ps = client.get("/programs", headers=user).json()
    assert len(ps) >= 6 and all(p["exercise_count"] >= 3 for p in ps)
    home = client.get("/programs", params={"mode": "home"}, headers=user).json()
    assert home and all(p["mode"] == "home" for p in home)
    assert all(p["kind"] == "cardio" for p in client.get("/programs", params={"kind": "cardio"}, headers=user).json())
    full = client.get(f"/programs/{ps[0]['id']}", headers=user).json()
    assert len(full["items"]) == ps[0]["exercise_count"]
    assert all(i["seconds"] or i["reps"] for i in full["items"])
    # dastur mashqlari rejimiga mos (seansga log yozish mumkin)
    s = client.post("/sessions", headers=user, json={"mode": full["mode"]}).json()
    it = full["items"][0]
    kw = {"duration_seconds": it["seconds"]} if it["seconds"] else {"reps": it["reps"]}
    assert client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": it["exercise"]["id"], **kw}).status_code == 201
    assert client.get("/programs/99999", headers=user).status_code == 404
    assert client.get("/programs").status_code == 401


def test_custom_habits(client, user, other_user):
    h = client.post("/habits", headers=user, json={"title": "Ertalab cho'zilish"})
    assert h.status_code == 201
    hid = h.json()["id"]
    assert client.post("/habits", headers=user, json={"title": ""}).status_code == 422
    assert len(client.get("/habits", headers=user).json()) == 1 and client.get("/habits", headers=other_user).json() == []
    assert client.put(f"/habits/{hid}/checks/{TODAY}", headers=other_user, json={"done": True}).status_code == 404
    assert client.put(f"/habits/{hid}/checks/{TODAY}", headers=user, json={"done": True}).status_code == 200
    client.put(f"/habits/{hid}/checks/{TODAY}", headers=user, json={"done": True})  # takror xavfsiz
    checks = client.get("/habit-checks", headers=user).json()
    assert len(checks) == 1 and checks[0]["habit_id"] == hid
    assert client.put(f"/habits/{hid}/checks/{TODAY + timedelta(days=10)}", headers=user, json={"done": True}).status_code == 422
    client.put(f"/habits/{hid}/checks/{TODAY}", headers=user, json={"done": False})
    assert client.get("/habit-checks", headers=user).json() == []
    assert client.delete(f"/habits/{hid}", headers=other_user).status_code == 404
    assert client.delete(f"/habits/{hid}", headers=user).status_code == 204


def test_habit_limit(client, user):
    for i in range(20):
        assert client.post("/habits", headers=user, json={"title": f"odat {i}"}).status_code == 201
    assert client.post("/habits", headers=user, json={"title": "ortiqcha"}).status_code == 422


def test_summary_and_achievements(client, user, ex_ids):
    s0 = client.get("/me/summary", headers=user).json()
    assert s0["sessions_total"] == 0 and s0["streak"] == 0 and not any(a["earned"] for a in s0["achievements"])
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["home"], "reps": 5})
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    client.put(f"/steps/{TODAY}", headers=user, json={"steps": 12000})
    client.post("/water", headers=user, json={"amount_ml": 2000})
    client.post("/water", headers=user, json={"amount_ml": 500})
    s1 = client.get("/me/summary", headers=user).json()
    earned = {a["key"] for a in s1["achievements"] if a["earned"]}
    assert s1["sessions_total"] == 1 and s1["streak"] >= 1 and s1["active_days_30"] >= 1
    assert {"first_workout", "steps_goal", "water_goal"} <= earned and "ten_workouts" not in earned


def test_insights_rules(client, user):
    ins = client.get("/insights", headers=user).json()
    assert any(i["kind"] == "system" and i["icon"] == "profile" for i in ins)       # profil to'ldirilmagan
    client.patch("/me", headers=user, json={"goal": "stay_fit", "experience_level": "beginner", "preferred_location": "home", "daily_minutes": 20})
    client.post("/premium/interest", headers=user)
    ins2 = client.get("/insights", headers=user).json()
    assert not any(i["icon"] in ("profile", "premium") for i in ins2)
    client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 20})
    assert any(i["icon"] == "stats" for i in client.get("/insights", headers=user).json())
    assert all({"id", "kind", "icon", "title", "body"} <= set(i) for i in ins2)


def test_coach(client, user):
    for topic in ("today", "workout", "meal", "status"):
        r = client.get("/coach/ask", params={"topic": topic}, headers=user).json()
        assert r["text"] and "sun'iy intellekt" in r["note"]
    assert client.get("/coach/ask", params={"topic": "hack"}, headers=user).status_code == 422
    w = client.get("/coach/ask", params={"topic": "workout"}, headers=user).json()
    assert w["action"]["type"] == "program" and client.get(f"/programs/{w['action']['id']}", headers=user).status_code == 200
    m = client.get("/coach/ask", params={"topic": "meal"}, headers=user).json()
    assert m["action"]["type"] == "recipe" and client.get(f"/recipes/{m['action']['id']}", headers=user).status_code == 200
    # kaloriya maqsadi to'lganda ovqat tavsiya qilinmaydi
    client.patch("/goals", headers=user, json={"calorie_goal": 800})
    client.post("/meals", headers=user, json={"title": "Katta ovqat", "kcal": 1000, "meal_type": "dinner"})
    full = client.get("/coach/ask", params={"topic": "meal"}, headers=user).json()
    assert full["action"] is None and "to'ldi" in full["text"]


def test_profile_v3_fields(client, register):
    body = {"email": "ism@example.com", "password": "Parol12345", "is_adult_confirmed": True, "accept_terms": True, "full_name": "  Aziza Karimova "}
    r = client.post("/auth/register", json=body)
    assert r.status_code == 201
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    me = client.get("/me", headers=h).json()
    assert me["full_name"] == "Aziza Karimova"
    upd = client.patch("/me", headers=h, json={"goal": "weight_loss", "activity_level": "moderate", "full_name": "Aziza K."}).json()
    assert upd["profile"]["goal"] == "weight_loss" and upd["profile"]["activity_level"] == "moderate" and upd["full_name"] == "Aziza K."
    assert client.patch("/me", headers=h, json={"activity_level": "extreme"}).status_code == 422
    # vazn/bo'y/yosh kabi maydonlar qabul qilinmaydi (e'tiborsiz qoldiriladi, saqlanmaydi)
    client.patch("/me", headers=h, json={"weight_kg": 70, "height_cm": 175})
    assert "weight_kg" not in str(client.get("/me/export", headers=h).json())


def test_stats_year(client, user):
    assert len(client.get("/stats", params={"days": 365}, headers=user).json()["days"]) == 365
    assert client.get("/stats", params={"days": 400}, headers=user).status_code == 422


def test_ensure_columns_adds_missing_without_data_loss():
    from app.migrate import ensure_columns
    eng = create_engine("sqlite://")
    with eng.begin() as c:
        c.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY, email VARCHAR(255))"))
        c.execute(text("INSERT INTO users (id, email) VALUES (1, 'a@b.c')"))
    added = ensure_columns(eng)
    assert "users.full_name" in added
    assert "full_name" in {c["name"] for c in inspect(eng).get_columns("users")}
    with eng.connect() as c:
        assert c.execute(text("SELECT email FROM users")).scalar() == "a@b.c"
    assert ensure_columns(eng) == []  # ikkinchi marta hech narsa qo'shmaydi
