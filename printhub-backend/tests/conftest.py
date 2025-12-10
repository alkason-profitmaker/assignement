"""
Pytest configuration and fixtures
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app

# Test database
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    """Override database dependency for testing"""
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def db():
    """Create test database for each test"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db):
    """Create test client"""
    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=engine)

    with TestClient(app) as test_client:
        yield test_client

    Base.metadata.drop_all(bind=engine)
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db):
    """Create a test user"""
    from app.models.user import User
    from app.core.config import settings

    user = User(
        phone_number="9876543210",
        name="Test User",
        flat_number="A-101",
        tower="Tower A",
        society_id=settings.SOCIETY_ID,
        is_verified=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_token(test_user):
    """Generate auth token for test user"""
    from app.core.security import create_access_token

    return create_access_token(
        data={"sub": str(test_user.id), "phone": test_user.phone_number}
    )


@pytest.fixture
def auth_headers(auth_token):
    """Get authorization headers"""
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def test_station(db):
    """Create a test printer station"""
    from app.models.printer import PrinterStation
    from app.core.config import settings

    station = PrinterStation(
        station_id=settings.PRINTER_STATION_ID,
        society_id=settings.SOCIETY_ID,
        name="Test Station",
        location="Near Main Gate",
        qr_code_token="test-qr-token-12345",
        status="online"
    )
    db.add(station)
    db.commit()
    db.refresh(station)
    return station
