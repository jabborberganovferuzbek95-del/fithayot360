from datetime import date, datetime, timedelta, timezone

TODAY = date.today()
MONDAY = TODAY - timedelta(days=TODAY.weekday())


def make_plan(client, h, ex_home, ex_gym):
    r = client.post("/plans", headers=h, json={
        "title": "Test", "starts_on": str(MONDAY), "ends_on": str(MONDAY + timedelta(days=6)),
        "items": [{"exercise_id": ex_home, "planned_date": str(MONDAY), "planned_minutes": 10},
                  {"exercise_id": ex_gym, "planned_date": str(MONDAY + timedelta(days=1)), "planned_minutes": 20}]})
    assert r.status_code == 201, r.text
    return r.json()


def test_plan_completion_rate(client, user, ex_ids):
    plan = make_plan(client, user, ex_ids["home"], ex_ids["gym"])
    item = plan["items"][0]
    s = client.post("/sessions", headers=user, json={"mode": "home", "plan_id": plan["id"]}).json()
    assert client.post(f"/sessions/{s['id']}/logs", headers=user,
                       json={"exercise_id": item["exercise_id"], "reps": 10, "plan_item_id": item["id"]}).status_code == 201
    # yakunlanmaguncha bajarilgan hisoblanmaydi
    assert client.get("/progress/weekly", headers=user).json()["completed_items"] == 0
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    p = client.get("/progress/weekly", params={"week_start": str(MONDAY)}, headers=user).json()
    assert (p["planned_items"], p["completed_items"], p["planned_completion_rate"]) == (2, 1, 50.0)
    assert client.get(f"/plans/{plan['id']}", headers=user).json()["items"][0]["is_completed"] is True


def test_interrupted_session_not_in_progress(client, user, ex_ids):
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["home"], "reps": 5})
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "interrupted"})
    assert client.get("/progress/weekly", headers=user).json()["total_sessions"] == 0
    assert client.get("/history", headers=user).json() == []
    # yakunlangan seansga qayd qo'shib bo'lmaydi
    assert client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["home"], "reps": 5}).status_code == 409


def test_session_time_rules_and_duration(client, user):
    from app.database import SessionLocal
    from app.models import WorkoutSession

    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    with SessionLocal() as db:  # seansni 60 daqiqa oldin boshlangan qilib qo'yamiz
        row = db.get(WorkoutSession, s["id"])
        row.started_at = datetime.now(timezone.utc) - timedelta(minutes=60)
        db.commit()
        started = row.started_at
    assert client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"}).status_code == 422  # qaydsiz yakunlanmaydi
    ex = client.get("/exercises", params={"mode": "home"}, headers=user).json()[0]["id"]
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex, "reps": 5})
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    ok = client.patch(f"/sessions/{s['id']}", headers=user, json={"finished_at": (started + timedelta(minutes=45)).isoformat()})
    assert ok.status_code == 200 and ok.json()["duration_minutes"] == 45
    assert client.patch(f"/sessions/{s['id']}", headers=user, json={"finished_at": (started - timedelta(minutes=1)).isoformat()}).status_code == 422
    future = (datetime.now(timezone.utc) + timedelta(hours=2)).isoformat()
    assert client.patch(f"/sessions/{s['id']}", headers=user, json={"finished_at": future}).status_code == 422
    assert client.get("/progress/weekly", headers=user).json()["total_active_minutes"] == 45


def test_mode_mismatch_and_foreign_plan_item(client, user, other_user, ex_ids):
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    assert client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["gym"], "reps": 5}).status_code == 422
    other_plan = make_plan(client, other_user, ex_ids["home"], ex_ids["gym"])
    r = client.post(f"/sessions/{s['id']}/logs", headers=user,
                    json={"exercise_id": ex_ids["home"], "reps": 5, "plan_item_id": other_plan["items"][0]["id"]})
    assert r.status_code == 404
    assert client.post("/sessions", headers=user, json={"mode": "home", "plan_id": other_plan["id"]}).status_code == 404


def test_plans_ownership_and_validation(client, user, other_user, ex_ids):
    plan = make_plan(client, user, ex_ids["home"], ex_ids["gym"])
    pid, iid = plan["id"], plan["items"][0]["id"]
    assert client.get(f"/plans/{pid}", headers=other_user).status_code == 404
    assert client.patch(f"/plans/{pid}", headers=other_user, json={"title": "x"}).status_code == 404
    assert client.delete(f"/plans/{pid}", headers=other_user).status_code == 404
    assert client.patch(f"/plans/{pid}/items/{iid}", headers=other_user, json={"planned_minutes": 5}).status_code == 404
    assert client.get("/plans", headers=other_user).json() == []
    # validatsiya
    bad_dates = {"title": "x", "starts_on": str(MONDAY), "ends_on": str(MONDAY - timedelta(days=1))}
    assert client.post("/plans", headers=user, json=bad_dates).status_code == 422
    out_of_range = {"exercise_id": ex_ids["home"], "planned_date": str(MONDAY + timedelta(days=30)), "planned_minutes": 10}
    assert client.post(f"/plans/{pid}/items", headers=user, json=out_of_range).status_code == 422
    # tahrirlash va o'chirish (FR-08)
    assert client.patch(f"/plans/{pid}/items/{iid}", headers=user, json={"planned_minutes": 25}).json()["planned_minutes"] == 25
    assert client.delete(f"/plans/{pid}/items/{iid}", headers=user).status_code == 204
    assert len(client.get(f"/plans/{pid}", headers=user).json()["items"]) == 1


def test_delete_plan_keeps_history(client, user, ex_ids):
    plan = make_plan(client, user, ex_ids["home"], ex_ids["gym"])
    item = plan["items"][0]
    s = client.post("/sessions", headers=user, json={"mode": "home", "plan_id": plan["id"]}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": item["exercise_id"], "reps": 8, "plan_item_id": item["id"]})
    client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    assert client.delete(f"/plans/{plan['id']}", headers=user).status_code == 204
    got = client.get(f"/sessions/{s['id']}", headers=user).json()
    assert got["plan_id"] is None and len(got["logs"]) == 1


def test_catalog_filters(client, user):
    home = client.get("/exercises", params={"mode": "home"}, headers=user).json()
    gym = client.get("/exercises", params={"mode": "gym"}, headers=user).json()
    assert home and gym and all(e["category"]["mode"] == "home" for e in home)
    assert all(e["safety_note"] for e in home + gym)  # FR-06
    q = client.get("/exercises", params={"q": "cho'kkalash"}, headers=user).json()
    assert q and all("cho'kkalash" in e["title"].lower() for e in q)
    assert all(e["equipment"] == "dumbbell" for e in client.get("/exercises", params={"equipment": "dumbbell"}, headers=user).json())
    assert all(e["difficulty"] == "beginner" for e in client.get("/exercises", params={"difficulty": "beginner"}, headers=user).json())


def test_profile_flow(client, register):
    _, h = register(client)
    me = client.get("/me", headers=h).json()
    assert me["profile_completed"] is False and me["settings"]["language_code"] == "uz"
    r = client.patch("/me", headers=h, json={"goal": "strength", "experience_level": "beginner", "preferred_location": "mixed", "daily_minutes": 30})
    assert r.json()["profile_completed"] is True
    assert client.patch("/me", headers=h, json={"daily_minutes": 2}).status_code == 422
    assert client.patch("/me", headers=h, json={"goal": "lose_10kg_fast"}).status_code == 422
    assert client.get("/me", headers=h).json()["profile"]["goal"] == "strength"  # saqlanadi


def test_auth_edge_cases(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer bad.token"}).status_code == 401
    base = {"email": "z@example.com", "is_adult_confirmed": True, "accept_terms": True}
    assert client.post("/auth/register", json={**base, "password": "short1"}).status_code == 422
    assert client.post("/auth/register", json={**base, "password": "onlyletters"}).status_code == 422
    assert client.post("/auth/register", json={**base, "password": "Parol12345", "accept_terms": False}).status_code == 422
    assert client.post("/auth/register", json={**base, "email": "not-an-email", "password": "Parol12345"}).status_code == 422
    tokens = client.post("/auth/register", json={**base, "password": "Parol12345"}).json()
    assert client.post("/auth/register", json={**base, "password": "Parol12345"}).status_code == 409
    # access token refresh sifatida ishlamaydi, aksincha ham
    assert client.post("/auth/refresh", json={"refresh_token": tokens["access_token"]}).status_code == 401
    assert client.get("/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"}).status_code == 401
    new = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert new.status_code == 200 and client.get("/me", headers={"Authorization": f"Bearer {new.json()['access_token']}"}).status_code == 200


def test_password_reset_flow(client, register):
    email, _ = register(client, password="Eski12345")
    assert client.post("/auth/forgot-password", json={"email": "yoq@example.com"}).json().get("reset_token") is None
    token = client.post("/auth/forgot-password", json={"email": email}).json()["reset_token"]
    assert client.post("/auth/reset-password", json={"token": token, "new_password": "Yangi12345"}).status_code == 200
    assert client.post("/auth/login", json={"email": email, "password": "Eski12345"}).status_code == 401
    assert client.post("/auth/login", json={"email": email, "password": "Yangi12345"}).status_code == 200
    # token bir martalik (parol o'zgargach yaroqsiz)
    assert client.post("/auth/reset-password", json={"token": token, "new_password": "Boshqa12345"}).status_code == 400
    assert client.post("/auth/reset-password", json={"token": "garbage", "new_password": "Boshqa12345"}).status_code == 400


def test_export_and_delete_account(client, register, ex_ids):
    email, h = register(client)
    client.post("/activities", headers=h, json={"activity_type_code": "walking", "duration_minutes": 10})
    s = client.post("/sessions", headers=h, json={"mode": "home"}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=h, json={"exercise_id": ex_ids["home"], "reps": 5})
    plan = make_plan(client, h, ex_ids["home"], ex_ids["gym"])
    client.patch(f"/sessions/{s['id']}", headers=h, json={"status": "completed"})
    exp = client.get("/me/export", headers=h).json()
    assert exp["account"]["email"] == email and len(exp["activities"]) == 1 and len(exp["sessions"]) == 1 and len(exp["plans"]) == 1
    assert "password" not in str(exp).lower()
    assert client.request("DELETE", "/me", headers=h, json={"password": "Notogri1"}).status_code == 403
    assert client.request("DELETE", "/me", headers=h, json={"password": "Parol12345"}).status_code == 204
    assert client.get("/me", headers=h).status_code == 401
    assert client.post("/auth/login", json={"email": email, "password": "Parol12345"}).status_code == 401


def test_weekly_days_breakdown_and_activity_future(client, user):
    client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 30, "distance_km": 2.5})
    future = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    assert client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 5, "occurred_at": future}).status_code == 422
    p = client.get("/progress/weekly", headers=user).json()
    assert len(p["days"]) == 7 and sum(d["minutes"] for d in p["days"]) == p["total_active_minutes"] == 30
    assert client.post("/activities", headers=user, json={"duration_minutes": 5}).status_code == 422  # tur ko'rsatilmagan
    assert client.post("/activities", headers=user, json={"activity_type_code": "yoq", "duration_minutes": 5}).status_code == 422


def test_activity_ownership_and_edit(client, user, other_user):
    a = client.post("/activities", headers=user, json={"activity_type_code": "cycling", "duration_minutes": 40}).json()
    assert client.patch(f"/activities/{a['id']}", headers=other_user, json={"duration_minutes": 1}).status_code == 404
    assert client.delete(f"/activities/{a['id']}", headers=other_user).status_code == 404
    assert client.patch(f"/activities/{a['id']}", headers=user, json={"duration_minutes": 50}).json()["duration_minutes"] == 50
    assert client.get("/activities", headers=other_user).json() == []
    assert client.delete(f"/activities/{a['id']}", headers=user).status_code == 204


def test_validation_message_is_readable_and_health(client):
    r = client.post("/auth/register", json={"email": "q@example.com", "password": "short", "is_adult_confirmed": True, "accept_terms": True})
    assert r.status_code == 422 and "8 belgi" in r.json()["detail"]
    assert client.get("/health").json()["status"] == "ok"
