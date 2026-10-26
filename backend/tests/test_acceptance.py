"""TT 8.2 qabul testlari AT-01 … AT-12."""
from datetime import date, timedelta

TODAY = date.today()
MONDAY = TODAY - timedelta(days=TODAY.weekday())


def reg_body(**kw):
    b = {"email": "a@example.com", "password": "Parol12345", "is_adult_confirmed": True, "accept_terms": True}
    b.update(kw)
    return b


def test_at01_adult_not_confirmed_rejected(client):
    r = client.post("/auth/register", json=reg_body(is_adult_confirmed=False))
    assert r.status_code == 422 and "18" in r.json()["detail"]
    assert client.post("/auth/login", json={"email": "a@example.com", "password": "Parol12345"}).status_code == 401  # akkaunt yaratilmadi


def test_at02_login_and_wrong_password(client):
    client.post("/auth/register", json=reg_body())
    r = client.post("/auth/login", json={"email": "A@Example.com", "password": "Parol12345"})  # email normalizatsiyasi
    assert r.status_code == 200
    me = client.get("/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert me.status_code == 200 and me.json()["email"] == "a@example.com"
    assert client.post("/auth/login", json={"email": "a@example.com", "password": "Xato12345"}).status_code == 401


def test_at03_add_home_exercise_to_plan(client, user, ex_ids):
    plan = client.post("/plans", headers=user, json={
        "title": "Hafta", "starts_on": str(MONDAY), "ends_on": str(MONDAY + timedelta(days=6)),
        "items": [{"exercise_id": ex_ids["home"], "planned_date": str(MONDAY), "planned_minutes": 15}]})
    assert plan.status_code == 201
    got = client.get(f"/plans/{plan.json()['id']}", headers=user).json()
    assert len(got["items"]) == 1 and got["items"][0]["exercise"]["mode"] == "home"


def test_at04_gym_log(client, user, ex_ids):
    s = client.post("/sessions", headers=user, json={"mode": "gym"}).json()
    r = client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["gym"], "set_no": 1, "reps": 10, "weight_kg": 40})
    assert r.status_code == 201 and r.json()["weight_kg"] == 40 and r.json()["reps"] == 10
    # vazn ixtiyoriy
    assert client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["gym"], "set_no": 2, "reps": 8}).status_code == 201


def test_at05_active_25_minutes_adds_to_progress(client, user):
    r = client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 25})
    assert r.status_code == 201
    p = client.get("/progress/weekly", headers=user).json()
    assert p["total_active_minutes"] == 25 and p["minutes_by_module"]["active"] == 25 and p["total_activity_entries"] == 1


def test_at06_negative_values_rejected(client, user, ex_ids):
    assert client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": -5}).status_code == 422
    assert client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 0}).status_code == 422
    assert client.post("/activities", headers=user, json={"activity_type_code": "walking", "duration_minutes": 10, "distance_km": -1}).status_code == 422
    s = client.post("/sessions", headers=user, json={"mode": "gym"}).json()
    for bad in ({"reps": 0}, {"reps": -3}, {"reps": 5, "weight_kg": -1}, {"set_no": 0, "reps": 5}, {}):
        r = client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["gym"], **bad})
        assert r.status_code == 422, bad


def test_at07_cannot_access_other_users_session(client, user, other_user):
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    for method, url, kw in [("get", f"/sessions/{s['id']}", {}), ("patch", f"/sessions/{s['id']}", {"json": {"status": "completed"}}),
                            ("post", f"/sessions/{s['id']}/logs", {"json": {"exercise_id": 1, "reps": 5}})]:
        r = getattr(client, method)(url, headers=other_user, **kw)
        assert r.status_code in (403, 404), url
    assert client.get("/sessions", headers=other_user).json() == []


def test_at08_finish_and_reopen_history_matches_weekly(client, user, ex_ids):
    s = client.post("/sessions", headers=user, json={"mode": "home"}).json()
    client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids["home"], "reps": 12})
    done = client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    assert done.status_code == 200 and done.json()["status"] == "completed" and done.json()["finished_at"]
    reopened = client.get(f"/sessions/{s['id']}", headers=user).json()
    assert len(reopened["logs"]) == 1
    hist = client.get("/history", headers=user).json()
    weekly = client.get("/progress/weekly", headers=user).json()
    assert len(hist) == 1 and weekly["total_sessions"] == 1
    assert weekly["total_active_minutes"] == sum(h["duration_minutes"] for h in hist)
    # qayta yakunlab bo'lmaydi
    assert client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"}).status_code == 409


def test_at09_empty_plan_rate_is_na(client, user):
    p = client.get("/progress/weekly", headers=user)
    assert p.status_code == 200
    assert p.json()["planned_items"] == 0 and p.json()["planned_completion_rate"] is None


def test_at10_idempotent_retry_no_duplicate(client, user, ex_ids):
    h = {**user, "Idempotency-Key": "abc-123"}
    body = {"activity_type_code": "walking", "duration_minutes": 20}
    r1, r2 = client.post("/activities", headers=h, json=body), client.post("/activities", headers=h, json=body)
    assert (r1.status_code, r2.status_code) == (201, 200) and r1.json()["id"] == r2.json()["id"]
    assert len(client.get("/activities", headers=user).json()) == 1
    # mashq logi uchun ham
    s = client.post("/sessions", headers=user, json={"mode": "gym"}).json()
    lh = {**user, "Idempotency-Key": "log-1"}
    lb = {"exercise_id": ex_ids["gym"], "reps": 10}
    a, b = client.post(f"/sessions/{s['id']}/logs", headers=lh, json=lb), client.post(f"/sessions/{s['id']}/logs", headers=lh, json=lb)
    assert a.json()["id"] == b.json()["id"]
    assert len(client.get(f"/sessions/{s['id']}", headers=user).json()["logs"]) == 1


def test_at11_non_admin_cannot_add_catalog(client, user, admin):
    cat = client.get("/exercise-categories", headers=user).json()[0]["id"]
    body = {"category_id": cat, "title": "Yangi mashq", "description": "Sinov uchun tavsif matni", "safety_note": "Ehtiyot bo'ling"}
    assert client.post("/admin/exercises", headers=user, json=body).status_code == 403
    assert client.post("/admin/exercises", json=body).status_code == 401
    ok = client.post("/admin/exercises", headers=admin, json=body)
    assert ok.status_code == 201
    upd = client.patch(f"/admin/exercises/{ok.json()['id']}", headers=admin, json={"is_active": False})
    assert upd.status_code == 200
    assert client.get(f"/exercises/{ok.json()['id']}", headers=user).status_code == 404  # nofaol mashq ko'rinmaydi


def test_at12_home_gym_active_in_one_account(client, user, ex_ids):
    for mode in ("home", "gym"):
        s = client.post("/sessions", headers=user, json={"mode": mode}).json()
        client.post(f"/sessions/{s['id']}/logs", headers=user, json={"exercise_id": ex_ids[mode], "reps": 10})
        client.patch(f"/sessions/{s['id']}", headers=user, json={"status": "completed"})
    client.post("/activities", headers=user, json={"activity_type_code": "running", "duration_minutes": 15})
    hist = client.get("/history", headers=user).json()
    assert {h["module"] for h in hist} == {"home", "gym", "active"}
    for m in ("home", "gym", "active"):
        assert [h["module"] for h in client.get("/history", params={"module": m}, headers=user).json()] == [m]
