"""
Printer schemas for API requests/responses
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class PrinterStationResponse(BaseModel):
    """Schema for printer station response"""
    station_id: str
    name: str
    location: str
    status: str
    is_active: bool
    supports_color: bool
    supports_bw: bool
    paper_level: int
    bw_ink_level: int
    color_ink_level: int

    class Config:
        from_attributes = True


class PrintTriggerRequest(BaseModel):
    """Schema for triggering print job"""
    order_number: str = Field(..., description="Order number to print")
    station_qr_token: str = Field(..., description="QR token scanned from printer station")


class PrintTriggerResponse(BaseModel):
    """Schema for print trigger response"""
    success: bool
    order_number: str
    message: str
    estimated_time_seconds: Optional[int] = None
    total_pages: int


class PrintStatusResponse(BaseModel):
    """Schema for print status response"""
    order_number: str
    status: str
    current_page: int
    total_pages: int
    progress_percentage: int
    message: str


class PrintCompleteResponse(BaseModel):
    """Schema for print completion response"""
    success: bool
    order_number: str
    pages_printed: int
    message: str


class PrinterHeartbeat(BaseModel):
    """Schema for printer heartbeat update"""
    station_id: str
    status: str
    paper_level: int
    bw_ink_level: int
    color_ink_level: int


class StationQRResponse(BaseModel):
    """Schema for station QR code info"""
    station_id: str
    qr_token: str
    location: str
    status: str
