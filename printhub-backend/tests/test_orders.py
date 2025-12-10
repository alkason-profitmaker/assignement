"""
Tests for order endpoints
"""
import pytest
import io
from fastapi import status


def test_get_pricing(client):
    """Test pricing endpoint"""
    response = client.get("/api/v1/pricing")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["bw_price_per_page"] == 3.0
    assert data["color_price_per_page"] == 10.0
    assert data["currency"] == "INR"


def test_get_user_orders_empty(client, auth_headers):
    """Test getting orders when user has none"""
    response = client.get("/api/v1/orders/", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["orders"] == []
    assert data["total"] == 0


def test_get_order_not_found(client, auth_headers):
    """Test getting non-existent order"""
    response = client.get("/api/v1/orders/INVALID123", headers=auth_headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_upload_files_unauthorized(client):
    """Test file upload without auth"""
    # Create a simple PDF-like file
    file_content = b"%PDF-1.4 test content"
    files = {"files": ("test.pdf", io.BytesIO(file_content), "application/pdf")}

    response = client.post("/api/v1/orders/upload", files=files)
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_create_order_unauthorized(client):
    """Test order creation without auth"""
    file_content = b"%PDF-1.4 test content"
    files = {"files": ("test.pdf", io.BytesIO(file_content), "application/pdf")}

    response = client.post("/api/v1/orders/create", files=files)
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_rate_order_not_found(client, auth_headers):
    """Test rating non-existent order"""
    response = client.post(
        "/api/v1/orders/INVALID123/rate",
        headers=auth_headers,
        json={"rating": 5}
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_orders_pagination(client, auth_headers):
    """Test order list pagination parameters"""
    response = client.get(
        "/api/v1/orders/?page=1&page_size=5",
        headers=auth_headers
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["page"] == 1
    assert data["page_size"] == 5
