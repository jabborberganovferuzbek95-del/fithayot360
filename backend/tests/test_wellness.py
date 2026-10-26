"""v2: suv, uyqu, qadam, ovqatlanish, meditatsiya, premium, dashboard va statistika."""
from datetime import date, datetime, timedelta, timezone

TODAY = date.today()


def test_goals_defaults_and_validation(client, user):
    g = client.get("/goals", headers=user).json()
    assert g == {"steps_goal": 10000, "water_goal_ml": 2500, "sleep_goal_min": 450, "workout_goal_min": 30, "calorie_goal": 2000}
    assert client.patch("/goals", headers=user, json={"steps_goal": 8000}).json()["steps_goal"] == 8000
    assert client.patch("/goals", headers=user, json={"water_goal_ml": 50}).status_code == 422
    assert client.patch("/goals", headers=user, json={"calorie_goal": 100}).status_code == 422
    assert client.get("/goals", headers=user).json()["steps_goal"] == 8000


def test_water_flow_idempotency_and_ownership(client, user, other_user):
    r = client.post("/water", headers=user, json={"amount_ml": 250})
    assert r.status_code == 201
    h = {**user, "Idempotency-Key": "w1"}
    a, b = client.post("/water", headers=h, json={"amount_ml": 250}), client.post("/water", headers=h, json={"amount_ml": 250})
    assert (a.status_code, b.status_code) == (201, 200) and a.json()["id"] == b.json()["id"]
    day = client.get("/water", headers=user).json()
    assert day["total_ml"] == 500 and day["goal_ml"] == 2500 and len(day["entries"]) == 2
    assert client.post("/water", headers=user, json={"amount_ml": 0}).status_code == 422
    assert client.post("/water", headers=user, json={"amount_ml": -100}).status_code == 422
    assert client.delete(f"/water/{r.json()['id']}", headers=other_user).status_code == 404
    assert client.delete(f"/water/{r.json()['id']}", headers=user).status_code == 204
    assert client.get("/water", headers=user).json()["total_ml"] == 250
    assert client.get("/water", headers=other_user).json()["total_ml"] == 0


def test_sleep_upsert_and_validation(client, user, other_user):
    d = str(TODAY)
    assert client.put(f"/sleep/{d}", headers=user, json={"duration_min": 450, "quality": 4}).status_code == 200
    assert client.put(f"/sleep/{d}", headers=user, json={"duration_min": 480}).json()["duration_min"] == 480  # yangilanadi
    rows = client.get("/sleep", headers=user).json()
    assert len(rows) == 1 and rows[0]["duration_min"] == 480
    assert client.put(f"/sleep/{d}", headers=user, json={"duration_min": 0}).status_code == 422
    assert client.put(f"/sleep/{d}", headers=user, json={"duration_min": 400, "quality": 9}).status_code == 422
    assert client.put(f"/sleep/{TODAY + timedelta(days=5)}", headers=user, json={"duration_min": 400}).status_code == 422
    assert client.get("/sleep", headers=other_user).json() == []
    assert client.delete(f"/sleep/{d}", headers=user).status_code == 204
    assert client.delete(f"/sleep/{d}", headers=user).status_code == 404


def test_steps_upsert_and_validation(client, user):
    d = str(TODAY)
    assert client.put(f"/steps/{d}", headers=user, json={"steps": 7240}).json()["steps"] == 7240
    assert client.put(f"/steps/{d}", headers=user, json={"steps": 8000}).json()["steps"] == 8000
    assert len(client.get("/steps", headers=user).json()) == 1
    assert client.put(f"/steps/{d}", headers=user, json={"steps": -1}).status_code == 422
    assert client.put(f"/steps/{d}", headers=user, json={"steps": 999999}).status_code == 422


def test_recipes_and_meals(client, user, other_user, admin):
    rec = client.get("/recipes", headers=user).json()
    assert len(rec) >= 8 and all(r["kcal"] >= 0 for r in rec)
    assert all(r["meal_type"] == "breakfast" for r in client.get("/recipes", params={"meal_type": "breakfast"}, headers=user).json())
    r0 = rec[0]
    m = client.post("/meals", headers=user, json={"recipe_id": r0["id"], "meal_type": "lunch"})
    assert m.status_code == 201 and m.json()["kcal"] == r0["kcal"] and m.json()["title"] == r0["title"]
    custom = client.post("/meals", headers=user, json={"title": "Osh", "kcal": 500, "meal_type": "dinner"})
    assert custom.status_code == 201
    assert client.post("/meals", headers=user, json={"meal_type": "snack"}).status_code == 422        # nom/kkal yo'q
    assert client.post("/meals", headers=user, json={"title": "X", "kcal": -5, "meal_type": "snack"}).status_code == 422
    assert client.post("/meals", headers=user, json={"recipe_id": 99999, "meal_type": "snack"}).status_code == 422
    assert len(client.get("/meals", headers=user).json()) == 2 and client.get("/meals", headers=other_user).json() == []
    assert client.delete(f"/meals/{m.json()['id']}", headers=other_user).status_code == 404
    assert client.delete(f"/meals/{m.json()['id']}", headers=user).status_code == 204
    # admin retsept
    body = {"title": "Yangi retsept", "meal_type": "snack", "kcal": 100, "ingredients": "bir nima", "instructions": "tayyorlash"}
    assert client.post("/admin/recipes", headers=user, json=body).status_code == 403
    new = client.post("/admin/recipes", headers=admin, json=body)
    assert new.status_code == 201
    assert client.patch(f"/admin/recipes/{new.json()['id']}", headers=admin, json={"is_active": False}).status_code == 200
    assert client.get(f"/recipes/{new.json()['id']}", headers=user).status_code == 404


def test_meditation_and_premium(client, user):
    items = client.get("/meditations", headers=user).json()
    assert len(items) >= 5 and all(i["guide"] for i in items)
    assert all(i["category"] == "sleep" for i in client.get("/meditations", params={"category": "sleep"}, headers=user).json())
    assert client.post("/meditation-logs", headers=user, json={"item_id": items[0]["id"], "duration_min": 5}).status_code == 201
    assert client.post("/meditation-logs", headers=user, json={"duration_min": 0}).status_code == 422
    assert client.post("/meditation-logs", headers=user, json={"item_id": 99999, "duration_min": 5}).status_code == 422
    assert len(client.get("/meditation-logs", headers=user).json()) == 1
    assert client.get("/premium/interest", headers=user).json() == {"interested": False}
    client.post("/premium/interest", headers=user)
    client.post("/premium/interest", headers=user)  # takror xavfsiz
    assert client.get("/premium/interest", headers=user).json() == {"interested": True}


def test_dashboard_today_and_habits(client, user, ex_ids):
    empty = client.get("/dashboard/today", headers=user).json()
    assert empty["steps"] == 0 and empty["habits_done"] == 0 and len(empty["habits"]) == 5
    client.put(f"/steps/{TODAY}", headers=user, json={"steps": 10000})
    client.post("/water", headers=user, json={"amount_ml": 2000})
    client.post("/water", headers=user, json={"amount_ml": 500})
    client.put(f"/sleep/{TODAY}", headers=user, json={"duration_min": 460})
    client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 35})
    rec = client.get("/recipes", headers=user).json()[0]
    client.post("/meals", headers=user, json={"recipe_id": rec["id"], "meal_type": "lunch"})
    client.post("/meditation-logs", headers=user, json={"duration_min": 10})
    d = client.get("/dashboard/today", headers=user).json()
    assert (d["steps"], d["water_ml"], d["sleep_min"], d["active_minutes"], d["meditation_min"]) == (10000, 2500, 460, 35, 10)
    assert d["calories_in"] == rec["kcal"]
    assert d["habits_done"] == 5 and all(h["done"] for h in d["habits"])
    # sessiya vaqti ham faol vaqtga qo'shiladi, Active ikki marta sanalmaydi
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["home"], "reps": 5})
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    assert client.get("/dashboard/today", headers=user).json()["active_minutes"] == 35


def test_stats_week_and_month(client, user, other_user):
    y = TODAY - timedelta(days=1)
    client.put(f"/steps/{TODAY}", headers=user, json={"steps": 6000})
    client.put(f"/steps/{y}", headers=user, json={"steps": 4000})
    client.put(f"/sleep/{TODAY}", headers=user, json={"duration_min": 420})
    client.post("/water", headers=user, json={"amount_ml": 1000})
    w = client.get("/stats", params={"days": 7}, headers=user).json()
    assert len(w["days"]) == 7 and w["totals"]["steps"] == 10000 and w["averages"]["steps"] == round(10000 / 7)
    assert w["totals"]["water_ml"] == 1000 and w["averages"]["sleep_min"] == 420
    m = client.get("/stats", params={"days": 30}, headers=user).json()
    assert len(m["days"]) == 30 and m["totals"]["steps"] == 10000
    # boshqa foydalanuvchi ma'lumoti ko'rinmaydi; uyqu qaydi yo'q bo'lsa N/A (None)
    o = client.get("/stats", headers=other_user).json()
    assert o["totals"]["steps"] == 0 and o["averages"]["sleep_min"] is None
    assert client.get("/stats", params={"days": 0}, headers=user).status_code == 422
    assert client.get("/stats", params={"days": 500}, headers=user).status_code == 422


def test_export_and_delete_include_wellness(client, register):
    email, h = register(client)
    client.put(f"/steps/{TODAY}", headers=h, json={"steps": 1234})
    client.post("/water", headers=h, json={"amount_ml": 300})
    client.patch("/goals", headers=h, json={"steps_goal": 5000})
    client.post("/premium/interest", headers=h)
    exp = client.get("/me/export", headers=h).json()
    assert exp["wellness"]["steps"][0]["steps"] == 1234 and exp["wellness"]["goals"]["steps_goal"] == 5000
    assert client.request("DELETE", "/me", headers=h, json={"password": "Parol12345"}).status_code == 204
    assert client.post("/auth/login", json={"email": email, "password": "Parol12345"}).status_code == 401
