"""
Order service for managing print orders
"""
import uuid
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
import logging

from app.models.order import Order, OrderItem, OrderStatus
from app.models.user import User
from app.schemas.order import OrderCreate, OrderItemCreate
from app.services.file_service import FileService
from app.core.config import settings

logger = logging.getLogger(__name__)


class OrderService:
    """Service for order-related operations"""

    def __init__(self, db: Session):
        self.db = db
        self.file_service = FileService()

    def generate_order_number(self) -> str:
        """Generate a unique order number"""
        timestamp = datetime.utcnow().strftime("%y%m%d")
        unique_id = str(uuid.uuid4().int)[:4]
        return f"PH{timestamp}{unique_id}"

    def generate_qr_token(self) -> str:
        """Generate a unique QR token for print release"""
        return str(uuid.uuid4())

    def create_order(self, user_id: int, items_data: List[dict]) -> Order:
        """
        Create a new print order.
        items_data should contain file info with bw_pages, color_pages, etc.
        """
        order_number = self.generate_order_number()
        expires_at = datetime.utcnow() + timedelta(hours=settings.ORDER_VALIDITY_HOURS)

        # Calculate totals
        total_bw = sum(item.get("bw_pages", 0) for item in items_data)
        total_color = sum(item.get("color_pages", 0) for item in items_data)
        total_pages = total_bw + total_color

        # Calculate price
        price_info = self.file_service.calculate_price(total_bw, total_color)
        total_amount = price_info["total_amount"]

        # Create order
        order = Order(
            order_number=order_number,
            user_id=user_id,
            station_id=settings.PRINTER_STATION_ID,
            total_pages=total_pages,
            bw_pages=total_bw,
            color_pages=total_color,
            total_amount=total_amount,
            status=OrderStatus.CREATED,
            expires_at=expires_at,
            qr_token=self.generate_qr_token()
        )

        self.db.add(order)
        self.db.flush()  # Get the order ID

        # Create order items
        for item_data in items_data:
            item_amount = self.file_service.calculate_price(
                item_data.get("bw_pages", 0),
                item_data.get("color_pages", 0)
            )["total_amount"]

            order_item = OrderItem(
                order_id=order.id,
                file_name=item_data["file_name"],
                file_type=item_data["file_type"],
                file_size=item_data.get("file_size", 0),
                file_path=item_data.get("file_path"),
                total_pages=item_data.get("total_pages", 1),
                bw_pages=item_data.get("bw_pages", 0),
                color_pages=item_data.get("color_pages", 0),
                is_collage=1 if item_data.get("is_collage") else 0,
                collage_layout=item_data.get("collage_layout"),
                collage_images=item_data.get("collage_images"),
                item_amount=item_amount
            )
            self.db.add(order_item)

        self.db.commit()
        self.db.refresh(order)

        logger.info(f"Created order {order_number} for user {user_id}")
        return order

    def get_order_by_number(self, order_number: str) -> Optional[Order]:
        """Get order by order number"""
        return self.db.query(Order).filter(Order.order_number == order_number).first()

    def get_order_by_id(self, order_id: int) -> Optional[Order]:
        """Get order by ID"""
        return self.db.query(Order).filter(Order.id == order_id).first()

    def get_order_by_qr_token(self, qr_token: str) -> Optional[Order]:
        """Get order by QR token"""
        return self.db.query(Order).filter(Order.qr_token == qr_token).first()

    def get_user_orders(
        self,
        user_id: int,
        page: int = 1,
        page_size: int = 10,
        status: Optional[OrderStatus] = None
    ) -> tuple[List[Order], int]:
        """Get paginated orders for a user"""
        query = self.db.query(Order).filter(Order.user_id == user_id)

        if status:
            query = query.filter(Order.status == status)

        total = query.count()
        orders = query.order_by(desc(Order.created_at)).offset((page - 1) * page_size).limit(page_size).all()

        return orders, total

    def update_order_status(
        self,
        order: Order,
        status: OrderStatus,
        message: Optional[str] = None
    ) -> Order:
        """Update order status"""
        order.status = status
        if message:
            order.status_message = message
        order.updated_at = datetime.utcnow()

        if status == OrderStatus.COMPLETED:
            order.printed_at = datetime.utcnow()

        self.db.commit()
        self.db.refresh(order)

        logger.info(f"Order {order.order_number} status updated to {status}")
        return order

    def mark_order_paid(self, order: Order) -> Order:
        """Mark order as paid and ready for printing"""
        return self.update_order_status(
            order,
            OrderStatus.READY_TO_PRINT,
            "Payment completed. Ready to print."
        )

    def validate_print_request(self, order: Order, station_qr_token: str) -> dict:
        """
        Validate if an order can be printed.
        Checks: status, expiry, station match.
        """
        # Check if order is ready to print
        if order.status != OrderStatus.READY_TO_PRINT:
            return {
                "valid": False,
                "error": f"Order not ready for printing. Status: {order.status}"
            }

        # Check if order has expired
        if datetime.utcnow() > order.expires_at:
            self.update_order_status(order, OrderStatus.EXPIRED, "Order expired")
            return {"valid": False, "error": "Order has expired. Refund will be processed."}

        # Validate station QR token
        from app.models.printer import PrinterStation
        station = self.db.query(PrinterStation).filter(
            PrinterStation.qr_code_token == station_qr_token
        ).first()

        if not station:
            return {"valid": False, "error": "Invalid printer station"}

        if station.station_id != order.station_id:
            return {"valid": False, "error": "Wrong printer station"}

        if station.status != "online":
            return {"valid": False, "error": f"Printer is {station.status}"}

        return {"valid": True, "station": station}

    def rate_order(self, order: Order, rating: int, feedback: Optional[str] = None) -> Order:
        """Add rating and feedback to completed order"""
        if order.status != OrderStatus.COMPLETED:
            raise ValueError("Can only rate completed orders")

        order.rating = rating
        order.feedback = feedback
        order.updated_at = datetime.utcnow()

        self.db.commit()
        self.db.refresh(order)

        logger.info(f"Order {order.order_number} rated: {rating}/5")
        return order

    def get_order_price_breakdown(self, order: Order) -> dict:
        """Get detailed price breakdown for an order"""
        return self.file_service.calculate_price(order.bw_pages, order.color_pages)

    def check_expired_orders(self) -> int:
        """
        Check for expired orders and mark them.
        Returns count of newly expired orders.
        """
        now = datetime.utcnow()
        expired_orders = self.db.query(Order).filter(
            Order.status == OrderStatus.READY_TO_PRINT,
            Order.expires_at < now
        ).all()

        count = 0
        for order in expired_orders:
            self.update_order_status(order, OrderStatus.EXPIRED, "Order expired - auto-refund initiated")
            count += 1

        logger.info(f"Marked {count} orders as expired")
        return count
