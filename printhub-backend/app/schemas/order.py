"""
Order schemas for API requests/responses
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from app.models.order import OrderStatus


class CollageConfig(BaseModel):
    """Configuration for photo collage"""
    layout: str = Field(..., description="Collage layout: 2x1, 2x2, 3x2, 4x2")
    images: List[str] = Field(..., description="List of image identifiers for collage")


class OrderItemCreate(BaseModel):
    """Schema for creating an order item"""
    file_name: str = Field(..., max_length=255)
    file_type: str = Field(..., description="File type: pdf, image, collage")
    is_collage: bool = Field(default=False)
    collage_config: Optional[CollageConfig] = None


class OrderItemResponse(BaseModel):
    """Schema for order item response"""
    id: int
    file_name: str
    file_type: str
    total_pages: int
    bw_pages: int
    color_pages: int
    is_collage: bool
    collage_layout: Optional[str] = None
    item_amount: float
    print_status: str

    class Config:
        from_attributes = True


class OrderCreate(BaseModel):
    """Schema for creating an order"""
    items: List[OrderItemCreate] = Field(..., min_length=1)


class PriceBreakdown(BaseModel):
    """Price breakdown for order"""
    bw_pages: int
    color_pages: int
    bw_price_per_page: float
    color_price_per_page: float
    bw_total: float
    color_total: float
    total_amount: float


class OrderResponse(BaseModel):
    """Schema for order response"""
    id: int
    order_number: str
    status: OrderStatus
    status_message: Optional[str] = None
    total_pages: int
    bw_pages: int
    color_pages: int
    total_amount: float
    expires_at: datetime
    created_at: datetime
    printed_at: Optional[datetime] = None
    rating: Optional[int] = None
    items: List[OrderItemResponse] = []
    price_breakdown: Optional[PriceBreakdown] = None

    class Config:
        from_attributes = True


class OrderListResponse(BaseModel):
    """Schema for list of orders"""
    orders: List[OrderResponse]
    total: int
    page: int
    page_size: int


class OrderRatingRequest(BaseModel):
    """Schema for rating an order"""
    rating: int = Field(..., ge=1, le=5, description="Rating from 1 to 5")
    feedback: Optional[str] = Field(None, max_length=500, description="Optional feedback")


class OrderPreviewResponse(BaseModel):
    """Schema for order preview (before payment)"""
    items: List[OrderItemResponse]
    price_breakdown: PriceBreakdown
    station_location: str
    validity_hours: int


class QRScanRequest(BaseModel):
    """Schema for QR scan request to trigger print"""
    order_number: str = Field(..., description="Order number")
    station_qr_token: str = Field(..., description="QR token from printer station")
