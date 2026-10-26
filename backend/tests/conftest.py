import os

# Import qilishdan oldin sozlanadi. Standart: xotiradagi SQLite; PostgreSQL uchun TEST_DATABASE_URL bering
os.environ["DATABASE_URL"] = os.getenv("TEST_DATABASE_URL", "sqlite://")
os.environ["JWT_SECRET"] = "test-secret"
os.environ["AUTO_CREATE_TABLES"] = "false"
os.environ["SEED_ON_START"] = "false"
os.environ["EXPOSE_RESET_TOKEN"] = "true"
os.environ["APP_TZ_OFFSET_MINUTES"] = "0"

import itertools  # noqa: E402

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import seed  # noqa: E402
from app.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402
from app.security import hash_password  # noqa: E402

_counter = itertools.count(1)


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed.seed_reference_data(db)
    yield


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def _register(client, email=None, password="Parol12345"):
    email = email or f"user{next(_counter)}@example.com"
    r = client.post("/auth/register", json={"email": email, "password": password, "is_adult_confirmed": True, "accept_terms": True})
    assert r.status_code == 201, r.text
    return email, {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def user(client):
    return _register(client)[1]


@pytest.fixture()
def other_user(client):
    return _register(client)[1]


@pytest.fixture()
def register():
    return _register


@pytest.fixture()
def admin(client):
    with SessionLocal() as db:
        from app.models import FitnessProfile, UserSettings
        u = User(email="admin@example.com", password_hash=hash_password("Admin12345"), role="content_admin", is_adult_confirmed=True)
        u.profile, u.settings = FitnessProfile(), UserSettings()
        db.add(u)
        db.commit()
    r = client.post("/auth/login", json={"email": "admin@example.com", "password": "Admin12345"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def ex_ids(client, user):
    """{'home': id, 'gym': id} — birinchi mos mashqlar."""
    out = {}
    for mode in ("home", "gym"):
        out[mode] = client.get("/exercises", params={"mode": mode}, headers=user).json()[0]["id"]
    return out
