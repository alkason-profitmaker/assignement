"""
Printer API routes
"""
import asyncio
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.printer_service import PrinterService
from app.services.order_service import OrderService
from app.schemas.printer import (
    PrinterStationResponse, PrintTriggerRequest, PrintTriggerResponse,
    PrintStatusResponse, PrinterHeartbeat, StationQRResponse
)
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/printer", tags=["Printer"])


@router.get("/station", response_model=PrinterStationResponse)
async def get_station_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get printer station information.
    For MVP, returns the single society printer station.
    """
    printer_service = PrinterService(db)

    # Initialize default station if not exists
    station = printer_service.initialize_default_station()

    return PrinterStationResponse.model_validate(station)


@router.post("/trigger", response_model=PrintTriggerResponse)
async def trigger_print(
    request: PrintTriggerRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Trigger print job after scanning station QR code.
    This is called when user scans QR at printer station.
    """
    order_service = OrderService(db)
    printer_service = PrinterService(db)

    # Get order
    order = order_service.get_order_by_number(request.order_number)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    # Verify ownership
    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to print this order"
        )

    # Validate print request
    validation = printer_service.validate_print_request(order, request.station_qr_token)
    if not validation.get("valid"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=validation.get("error")
        )

    station = validation["station"]

    # Trigger print in background
    # Note: In production, this would be handled by a task queue (Celery)
    async def run_print():
        await printer_service.trigger_print(order, station)
        printer_service.cleanup_print_files(order)

    background_tasks.add_task(asyncio.create_task, run_print())

    # Estimate print time (roughly 8 seconds per page for simulation)
    estimated_time = order.total_pages * 8

    return PrintTriggerResponse(
        success=True,
        order_number=order.order_number,
        message="Print job started. Please wait at the station.",
        estimated_time_seconds=estimated_time,
        total_pages=order.total_pages
    )


@router.get("/status/{order_number}", response_model=PrintStatusResponse)
async def get_print_status(
    order_number: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get print status for an order.
    Poll this endpoint for progress updates.
    """
    order_service = OrderService(db)
    printer_service = PrinterService(db)

    order = order_service.get_order_by_number(order_number)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this order"
        )

    status_info = printer_service.get_print_status(order)
    return PrintStatusResponse(**status_info)


@router.get("/station/qr", response_model=StationQRResponse)
async def get_station_qr_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get station QR code info for validation.
    The QR code on the physical station encodes this token.
    """
    printer_service = PrinterService(db)
    station = printer_service.initialize_default_station()

    return StationQRResponse(
        station_id=station.station_id,
        qr_token=station.qr_code_token,
        location=station.location,
        status=station.status
    )


# Station management endpoints (for printer daemon/admin)

@router.post("/station/heartbeat")
async def station_heartbeat(
    heartbeat: PrinterHeartbeat,
    db: Session = Depends(get_db)
):
    """
    Receive heartbeat from printer station.
    Updates station status and supply levels.
    """
    printer_service = PrinterService(db)
    station = printer_service.get_station_by_id(heartbeat.station_id)

    if not station:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Station not found"
        )

    printer_service.update_station_status(
        station,
        heartbeat.status,
        heartbeat.paper_level,
        heartbeat.bw_ink_level,
        heartbeat.color_ink_level
    )

    return {"status": "ok", "message": "Heartbeat received"}


@router.post("/station/online/{station_id}")
async def set_station_online(
    station_id: str,
    db: Session = Depends(get_db)
):
    """
    Set station to online status.
    Called when printer daemon starts.
    """
    printer_service = PrinterService(db)
    station = printer_service.get_station_by_id(station_id)

    if not station:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Station not found"
        )

    printer_service.update_station_status(station, "online")
    return {"status": "ok", "message": f"Station {station_id} is now online"}


@router.post("/station/offline/{station_id}")
async def set_station_offline(
    station_id: str,
    db: Session = Depends(get_db)
):
    """
    Set station to offline status.
    Called when printer daemon stops or encounters error.
    """
    printer_service = PrinterService(db)
    station = printer_service.get_station_by_id(station_id)

    if not station:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Station not found"
        )

    printer_service.update_station_status(station, "offline")
    return {"status": "ok", "message": f"Station {station_id} is now offline"}
