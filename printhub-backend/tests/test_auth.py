"""
Tests for authentication endpoints
"""
import pytest
from fastapi import status


def test_health_check(client):
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["status"] == "healthy"


def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["name"] == "PrintHub"
    assert "version" in data


def test_register_new_user(client):
    """Test user registration"""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "phone_number": "9876543211",
            "name": "New User",
            "flat_number": "B-202"
        }
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["success"] is True
    assert "OTP sent" in data["message"] or "Registration successful" in data["message"]


def test_login_request_otp(client, test_user):
    """Test OTP request for login"""
    response = client.post(
        "/api/v1/auth/login",
        json={"phone_number": test_user.phone_number}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["success"] is True


def test_get_current_user(client, auth_headers, test_user):
    """Test getting current user profile"""
    response = client.get("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["phone_number"] == test_user.phone_number
    assert data["name"] == test_user.name


def test_update_profile(client, auth_headers, test_user):
    """Test updating user profile"""
    response = client.put(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"name": "Updated Name", "flat_number": "C-303"}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["name"] == "Updated Name"
    assert data["flat_number"] == "C-303"


def test_unauthorized_access(client):
    """Test access without authentication"""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_invalid_token(client):
    """Test access with invalid token"""
    headers = {"Authorization": "Bearer invalid-token"}
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
