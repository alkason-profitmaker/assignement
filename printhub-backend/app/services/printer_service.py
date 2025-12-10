"""
Printer service for managing print jobs and printer communication
"""
import uuid
import asyncio
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session
import logging

from app.models.order import Order, OrderItem, OrderStatus
from app.models.printer import PrinterStation, PrinterStatus
from app.services.payment_service import PaymentService
from app.core.config import settings

logger = logging.getLogger(__name__)


class PrinterService:
    """Service for printer operations"""

    def __init__(self, db: Session):
        self.db = db
        self.payment_service = PaymentService(db)

    def get_station_by_id(self, station_id: str) -> Optional[PrinterStation]:
        """Get printer station by ID"""
        return self.db.query(PrinterStation).filter(
            PrinterStation.station_id == station_id
        ).first()

    def get_station_by_qr_token(self, qr_token: str) -> Optional[PrinterStation]:
        """Get printer station by QR token"""
        return self.db.query(PrinterStation).filter(
            PrinterStation.qr_code_token == qr_token
        ).first()

    def create_station(
        self,
        station_id: str,
        name: str,
        location: str,
        society_id: str = None
    ) -> PrinterStation:
        """Create a new printer station"""
        qr_token = str(uuid.uuid4())

        station = PrinterStation(
            station_id=station_id,
            society_id=society_id or settings.SOCIETY_ID,
            name=name,
            location=location,
            qr_code_token=qr_token,
            status=PrinterStatus.OFFLINE
        )

        self.db.add(station)
        self.db.commit()
        self.db.refresh(station)

        logger.info(f"Created printer station: {station_id}")
        return station

    def update_station_status(
        self,
        station: PrinterStation,
        status: str,
        paper_level: int = None,
        bw_ink_level: int = None,
        color_ink_level: int = None
    ) -> PrinterStation:
        """Update printer station status (heartbeat)"""
        station.status = status
        station.last_heartbeat = datetime.utcnow()

        if paper_level is not None:
            station.paper_level = paper_level
        if bw_ink_level is not None:
            station.bw_ink_level = bw_ink_level
        if color_ink_level is not None:
            station.color_ink_level = color_ink_level

        # Auto-update status based on supplies
        if station.paper_level < 10:
            station.status = PrinterStatus.PAPER_LOW
        elif station.bw_ink_level < 10 or station.color_ink_level < 10:
            station.status = PrinterStatus.INK_LOW

        self.db.commit()
        self.db.refresh(station)
        return station

    def validate_print_request(self, order: Order, station_qr_token: str) -> dict:
        """
        Validate print request.
        Checks order status, expiry, and station availability.
        """
        # Check order status
        if order.status != OrderStatus.READY_TO_PRINT:
            if order.status == OrderStatus.COMPLETED:
                return {"valid": False, "error": "Order already printed"}
            elif order.status == OrderStatus.EXPIRED:
                return {"valid": False, "error": "Order has expired"}
            elif order.status == OrderStatus.REFUNDED:
                return {"valid": False, "error": "Order was refunded"}
            else:
                return {"valid": False, "error": f"Order not ready. Status: {order.status}"}

        # Check expiry
        if datetime.utcnow() > order.expires_at:
            order.status = OrderStatus.EXPIRED
            order.status_message = "Order expired"
            self.db.commit()
            # Trigger auto-refund
            self.payment_service.process_refund(order, "Order expired before printing")
            return {"valid": False, "error": "Order has expired. Refund initiated."}

        # Validate station
        station = self.get_station_by_qr_token(station_qr_token)
        if not station:
            return {"valid": False, "error": "Invalid printer station QR code"}

        if station.station_id != order.station_id:
            return {"valid": False, "error": "Please go to the correct printer station"}

        if station.status == PrinterStatus.OFFLINE:
            return {"valid": False, "error": "Printer is offline. Please try again later."}

        if station.status == PrinterStatus.BUSY:
            return {"valid": False, "error": "Printer is busy. Please wait."}

        if station.status == PrinterStatus.ERROR:
            return {"valid": False, "error": "Printer has an error. Please contact support."}

        if station.paper_level < 5:
            return {"valid": False, "error": "Printer is low on paper. Please contact support."}

        return {"valid": True, "station": station}

    async def trigger_print(self, order: Order, station: PrinterStation) -> dict:
        """
        Trigger print job on the printer.
        In production, this would communicate with the actual printer.
        For MVP, we simulate the print process.
        """
        try:
            # Update order status
            order.status = OrderStatus.PRINTING
            order.status_message = "Printing in progress..."
            station.status = PrinterStatus.BUSY
            self.db.commit()

            logger.info(f"Starting print for order {order.order_number}")

            # Get order items
            items = order.items
            total_pages = order.total_pages
            pages_printed = 0

            for item in items:
                item.print_status = "printing"
                self.db.commit()

                # Simulate printing each page
                for page in range(item.total_pages):
                    # In production: send actual print command
                    # For MVP: simulate with delay
                    await asyncio.sleep(0.5)  # 500ms per page simulation
                    pages_printed += 1

                    # Log progress
                    progress = int((pages_printed / total_pages) * 100)
                    logger.debug(f"Order {order.order_number}: {progress}% ({pages_printed}/{total_pages})")

                item.print_status = "done"
                self.db.commit()

            # Update order as completed
            order.status = OrderStatus.COMPLETED
            order.status_message = "Print completed successfully"
            order.printed_at = datetime.utcnow()

            # Update station statistics
            station.status = PrinterStatus.ONLINE
            station.total_pages_printed += total_pages
            station.total_orders_processed += 1
            station.paper_level = max(0, station.paper_level - (total_pages // 10))

            self.db.commit()

            logger.info(f"Print completed for order {order.order_number}")

            return {
                "success": True,
                "order_number": order.order_number,
                "pages_printed": total_pages,
                "message": "Print completed! Please collect your documents."
            }

        except Exception as e:
            logger.error(f"Print failed for order {order.order_number}: {e}")

            # Handle failure
            order.status = OrderStatus.FAILED
            order.status_message = f"Print failed: {str(e)}"
            station.status = PrinterStatus.ONLINE

            for item in order.items:
                if item.print_status == "printing":
                    item.print_status = "failed"

            self.db.commit()

            # Trigger auto-refund
            self.payment_service.process_refund(order, f"Print failed: {str(e)}")

            return {
                "success": False,
                "order_number": order.order_number,
                "error": str(e),
                "message": "Print failed. Refund will be processed automatically."
            }

    def get_print_status(self, order: Order) -> dict:
        """Get current print status for an order"""
        items = order.items
        total_pages = order.total_pages
        pages_done = sum(
            item.total_pages for item in items
            if item.print_status == "done"
        )

        progress = int((pages_done / total_pages) * 100) if total_pages > 0 else 0

        status_messages = {
            OrderStatus.READY_TO_PRINT: "Ready to print. Scan QR at station.",
            OrderStatus.PRINTING: f"Printing... {progress}%",
            OrderStatus.COMPLETED: "Print completed!",
            OrderStatus.FAILED: "Print failed. Refund processing.",
            OrderStatus.EXPIRED: "Order expired.",
            OrderStatus.REFUNDED: "Refunded."
        }

        return {
            "order_number": order.order_number,
            "status": order.status.value,
            "current_page": pages_done,
            "total_pages": total_pages,
            "progress_percentage": progress,
            "message": status_messages.get(order.status, "Unknown status")
        }

    def cleanup_print_files(self, order: Order) -> None:
        """Clean up temporary files after printing"""
        from app.services.file_service import FileService
        file_service = FileService()

        for item in order.items:
            if item.file_path:
                file_service.cleanup_file(item.file_path)

        logger.info(f"Cleaned up files for order {order.order_number}")

    def initialize_default_station(self) -> PrinterStation:
        """Initialize default printer station for MVP"""
        existing = self.get_station_by_id(settings.PRINTER_STATION_ID)
        if existing:
            return existing

        return self.create_station(
            station_id=settings.PRINTER_STATION_ID,
            name="PrintHub Station 1",
            location="Near Main Gate",
            society_id=settings.SOCIETY_ID
        )
