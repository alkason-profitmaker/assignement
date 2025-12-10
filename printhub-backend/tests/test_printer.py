"""
Tests for printer endpoints
"""
import pytest
from fastapi import status


def test_get_station_info(client, auth_headers, test_station):
    """Test getting printer station info"""
    response = client.get("/api/v1/printer/station", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["station_id"] == test_station.station_id
    assert data["location"] == test_station.location


def test_trigger_print_order_not_found(client, auth_headers, test_station):
    """Test print trigger with invalid order"""
    response = client.post(
        "/api/v1/printer/trigger",
        headers=auth_headers,
        json={
            "order_number": "INVALID123",
            "station_qr_token": test_station.qr_code_token
        }
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_get_print_status_not_found(client, auth_headers):
    """Test getting print status for non-existent order"""
    response = client.get(
        "/api/v1/printer/status/INVALID123",
        headers=auth_headers
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_station_heartbeat(client, test_station):
    """Test station heartbeat update"""
    response = client.post(
        "/api/v1/printer/station/heartbeat",
        json={
            "station_id": test_station.station_id,
            "status": "online",
            "paper_level": 80,
            "bw_ink_level": 90,
            "color_ink_level": 85
        }
    )
    assert response.status_code == status.HTTP_200_OK


def test_station_online(client, test_station):
    """Test setting station online"""
    response = client.post(f"/api/v1/printer/station/online/{test_station.station_id}")
    assert response.status_code == status.HTTP_200_OK
    assert "online" in response.json()["message"]


def test_station_offline(client, test_station):
    """Test setting station offline"""
    response = client.post(f"/api/v1/printer/station/offline/{test_station.station_id}")
    assert response.status_code == status.HTTP_200_OK
    assert "offline" in response.json()["message"]


def test_station_not_found(client):
    """Test heartbeat for non-existent station"""
    response = client.post(
        "/api/v1/printer/station/heartbeat",
        json={
            "station_id": "INVALID_STATION",
            "status": "online",
            "paper_level": 100,
            "bw_ink_level": 100,
            "color_ink_level": 100
        }
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND
