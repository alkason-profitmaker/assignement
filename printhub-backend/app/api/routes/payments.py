"""
Payment API routes
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.payment_service import PaymentService
from app.services.order_service import OrderService
from app.schemas.payment import (
    PaymentCreate, PaymentResponse, PaymentVerify,
    RazorpayOrderResponse, PaymentVerifyResponse, RefundResponse
)
from app.api.deps import get_current_user
from app.models.user import User
from app.models.order import OrderStatus

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/initiate", response_model=RazorpayOrderResponse)
async def initiate_payment(
    payment_data: PaymentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Initiate payment for an order.
    Creates a Razorpay order and returns details for mobile app.
    """
    order_service = OrderService(db)
    payment_service = PaymentService(db)

    # Get order
    order = order_service.get_order_by_id(payment_data.order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    # Verify ownership
    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to pay for this order"
        )

    # Check order status
    if order.status not in [OrderStatus.CREATED, OrderStatus.PAYMENT_PENDING]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot pay for order with status: {order.status}"
        )

    try:
        razorpay_order = payment_service.create_razorpay_order(order)
        return RazorpayOrderResponse(**razorpay_order)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/verify", response_model=PaymentVerifyResponse)
async def verify_payment(
    verify_data: PaymentVerify,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Verify payment after Razorpay callback.
    Validates signature and updates order status.
    """
    payment_service = PaymentService(db)

    result = payment_service.verify_payment(
        verify_data.razorpay_order_id,
        verify_data.razorpay_payment_id,
        verify_data.razorpay_signature
    )

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.get("error", "Payment verification failed")
        )

    return PaymentVerifyResponse(
        success=True,
        order_number=result["order_number"],
        message=result["message"],
        qr_token=result.get("qr_token"),
        station_location=result["station_location"],
        validity_hours=result["validity_hours"]
    )


@router.get("/status/{order_number}", response_model=PaymentResponse)
async def get_payment_status(
    order_number: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get payment status for an order.
    """
    order_service = OrderService(db)
    payment_service = PaymentService(db)

    order = order_service.get_order_by_number(order_number)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this payment"
        )

    payment = payment_service.get_payment_by_order(order.id)
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment not found"
        )

    return PaymentResponse.model_validate(payment)


@router.post("/refund/{order_number}", response_model=RefundResponse)
async def request_refund(
    order_number: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Request refund for an order (manual trigger).
    Auto-refunds are handled by the system automatically.
    """
    order_service = OrderService(db)
    payment_service = PaymentService(db)

    order = order_service.get_order_by_number(order_number)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to refund this order"
        )

    # Only allow refund for certain statuses
    allowed_statuses = [
        OrderStatus.READY_TO_PRINT,
        OrderStatus.EXPIRED,
        OrderStatus.FAILED
    ]
    if order.status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot refund order with status: {order.status}"
        )

    result = payment_service.process_refund(order, "User requested refund")

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.get("error", "Refund failed")
        )

    return RefundResponse(**result)


@router.post("/webhook/razorpay")
async def razorpay_webhook(
    db: Session = Depends(get_db)
):
    """
    Razorpay webhook for payment events.
    In production, verify webhook signature.
    """
    # Webhook handling for:
    # - payment.captured
    # - payment.failed
    # - refund.created
    # - refund.processed
    # - refund.failed

    # For MVP, we rely on client-side verification
    # Production implementation would process webhooks here
    return {"status": "ok"}
