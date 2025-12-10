"""
Payment schemas for API requests/responses
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from app.models.payment import PaymentStatus


class PaymentCreate(BaseModel):
    """Schema for initiating payment"""
    order_id: int = Field(..., description="Order ID to pay for")


class PaymentResponse(BaseModel):
    """Schema for payment response"""
    id: int
    order_id: int
    amount: float
    currency: str
    status: PaymentStatus
    razorpay_order_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class RazorpayOrderResponse(BaseModel):
    """Schema for Razorpay order creation response"""
    razorpay_order_id: str
    amount: int  # Amount in paise
    currency: str
    key_id: str
    order_number: str
    user_phone: str


class PaymentVerify(BaseModel):
    """Schema for verifying payment from Razorpay"""
    razorpay_order_id: str = Field(..., description="Razorpay order ID")
    razorpay_payment_id: str = Field(..., description="Razorpay payment ID")
    razorpay_signature: str = Field(..., description="Razorpay signature for verification")


class PaymentVerifyResponse(BaseModel):
    """Schema for payment verification response"""
    success: bool
    order_number: str
    message: str
    qr_token: Optional[str] = None  # Token for print release
    station_location: str
    validity_hours: int


class RefundResponse(BaseModel):
    """Schema for refund response"""
    success: bool
    refund_id: Optional[str] = None
    amount: float
    reason: str
    message: str
