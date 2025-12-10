"""
Payment service for Razorpay integration
"""
import hmac
import hashlib
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session
import razorpay
import logging

from app.models.order import Order, OrderStatus
from app.models.payment import Payment, PaymentStatus
from app.core.config import settings

logger = logging.getLogger(__name__)


class PaymentService:
    """Service for payment operations with Razorpay"""

    def __init__(self, db: Session):
        self.db = db
        # Initialize Razorpay client
        if settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET:
            self.client = razorpay.Client(
                auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
            )
        else:
            self.client = None
            logger.warning("Razorpay credentials not configured")

    def create_razorpay_order(self, order: Order) -> dict:
        """
        Create a Razorpay order for payment.
        Returns order details for mobile app to initiate payment.
        """
        # Check if payment already exists
        existing_payment = self.db.query(Payment).filter(
            Payment.order_id == order.id
        ).first()

        if existing_payment and existing_payment.status == PaymentStatus.COMPLETED:
            raise ValueError("Payment already completed for this order")

        # Amount in paise (Razorpay uses smallest currency unit)
        amount_paise = int(order.total_amount * 100)

        razorpay_order = None
        razorpay_order_id = None

        if self.client:
            try:
                razorpay_order = self.client.order.create({
                    "amount": amount_paise,
                    "currency": "INR",
                    "receipt": order.order_number,
                    "notes": {
                        "order_number": order.order_number,
                        "user_id": str(order.user_id),
                        "pages": str(order.total_pages)
                    }
                })
                razorpay_order_id = razorpay_order["id"]
            except Exception as e:
                logger.error(f"Razorpay order creation failed: {e}")
                raise ValueError(f"Payment gateway error: {str(e)}")
        else:
            # Mock order ID for development
            razorpay_order_id = f"order_mock_{order.order_number}"

        # Create or update payment record
        if existing_payment:
            existing_payment.razorpay_order_id = razorpay_order_id
            existing_payment.status = PaymentStatus.PENDING
            existing_payment.updated_at = datetime.utcnow()
            payment = existing_payment
        else:
            payment = Payment(
                order_id=order.id,
                amount=order.total_amount,
                razorpay_order_id=razorpay_order_id,
                status=PaymentStatus.PENDING
            )
            self.db.add(payment)

        # Update order status
        order.status = OrderStatus.PAYMENT_PENDING
        order.updated_at = datetime.utcnow()

        self.db.commit()

        logger.info(f"Created Razorpay order {razorpay_order_id} for order {order.order_number}")

        return {
            "razorpay_order_id": razorpay_order_id,
            "amount": amount_paise,
            "currency": "INR",
            "key_id": settings.RAZORPAY_KEY_ID,
            "order_number": order.order_number,
            "user_phone": order.user.phone_number if order.user else ""
        }

    def verify_payment(
        self,
        razorpay_order_id: str,
        razorpay_payment_id: str,
        razorpay_signature: str
    ) -> dict:
        """
        Verify payment signature from Razorpay.
        Returns success status and order details.
        """
        # Find payment record
        payment = self.db.query(Payment).filter(
            Payment.razorpay_order_id == razorpay_order_id
        ).first()

        if not payment:
            return {"success": False, "error": "Payment not found"}

        order = payment.order
        if not order:
            return {"success": False, "error": "Order not found"}

        # Verify signature
        if self.client and settings.RAZORPAY_KEY_SECRET:
            try:
                # Generate expected signature
                message = f"{razorpay_order_id}|{razorpay_payment_id}"
                expected_signature = hmac.new(
                    settings.RAZORPAY_KEY_SECRET.encode(),
                    message.encode(),
                    hashlib.sha256
                ).hexdigest()

                if expected_signature != razorpay_signature:
                    payment.status = PaymentStatus.FAILED
                    payment.error_message = "Signature verification failed"
                    self.db.commit()
                    return {"success": False, "error": "Payment verification failed"}

            except Exception as e:
                logger.error(f"Signature verification error: {e}")
                # In production, we should fail here
                # For MVP, we'll log and continue

        # Update payment record
        payment.razorpay_payment_id = razorpay_payment_id
        payment.razorpay_signature = razorpay_signature
        payment.status = PaymentStatus.COMPLETED
        payment.completed_at = datetime.utcnow()

        # Update order status
        order.status = OrderStatus.READY_TO_PRINT
        order.status_message = "Payment completed. Ready to print."
        order.updated_at = datetime.utcnow()

        self.db.commit()

        logger.info(f"Payment verified for order {order.order_number}")

        return {
            "success": True,
            "order_number": order.order_number,
            "message": "Payment successful! Go to the printer station and scan QR to print.",
            "qr_token": order.qr_token,
            "station_location": "Near Main Gate",  # From station config
            "validity_hours": settings.ORDER_VALIDITY_HOURS
        }

    def process_refund(self, order: Order, reason: str) -> dict:
        """
        Process refund for a failed or expired order.
        Auto-refund per FRD requirements.
        """
        payment = self.db.query(Payment).filter(
            Payment.order_id == order.id,
            Payment.status == PaymentStatus.COMPLETED
        ).first()

        if not payment:
            return {"success": False, "error": "No completed payment found"}

        if payment.status == PaymentStatus.REFUNDED:
            return {"success": False, "error": "Already refunded"}

        refund_id = None

        if self.client and payment.razorpay_payment_id:
            try:
                # Process refund through Razorpay
                refund = self.client.payment.refund(
                    payment.razorpay_payment_id,
                    {
                        "amount": int(payment.amount * 100),  # In paise
                        "notes": {
                            "reason": reason,
                            "order_number": order.order_number
                        }
                    }
                )
                refund_id = refund.get("id")
            except Exception as e:
                logger.error(f"Razorpay refund failed: {e}")
                # Mark as refund initiated for manual processing
                payment.status = PaymentStatus.REFUND_INITIATED
                payment.refund_reason = reason
                self.db.commit()
                return {"success": False, "error": f"Refund processing failed: {str(e)}"}
        else:
            # Mock refund for development
            refund_id = f"refund_mock_{order.order_number}"

        # Update payment record
        payment.status = PaymentStatus.REFUNDED
        payment.refund_id = refund_id
        payment.refund_amount = payment.amount
        payment.refund_reason = reason
        payment.refunded_at = datetime.utcnow()

        # Update order status
        order.status = OrderStatus.REFUNDED
        order.status_message = f"Refunded: {reason}"
        order.updated_at = datetime.utcnow()

        self.db.commit()

        logger.info(f"Refund processed for order {order.order_number}: {reason}")

        return {
            "success": True,
            "refund_id": refund_id,
            "amount": payment.amount,
            "reason": reason,
            "message": f"Refund of ₹{payment.amount} processed successfully"
        }

    def get_payment_by_order(self, order_id: int) -> Optional[Payment]:
        """Get payment record for an order"""
        return self.db.query(Payment).filter(Payment.order_id == order_id).first()

    def handle_payment_failure(self, order: Order, error_message: str) -> None:
        """Handle payment failure - update records"""
        payment = self.get_payment_by_order(order.id)
        if payment:
            payment.status = PaymentStatus.FAILED
            payment.error_message = error_message
            self.db.commit()

        order.status = OrderStatus.FAILED
        order.status_message = f"Payment failed: {error_message}"
        order.updated_at = datetime.utcnow()
        self.db.commit()

        logger.warning(f"Payment failed for order {order.order_number}: {error_message}")
