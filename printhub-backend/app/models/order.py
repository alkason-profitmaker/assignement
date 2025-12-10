"""
Order models for PrintHub
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, Text, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.core.database import Base


class OrderStatus(str, enum.Enum):
    """Order status enumeration"""
    CREATED = "created"
    PAYMENT_PENDING = "payment_pending"
    PAYMENT_COMPLETED = "payment_completed"
    READY_TO_PRINT = "ready_to_print"
    PRINTING = "printing"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"
    EXPIRED = "expired"


class PageType(str, enum.Enum):
    """Page type for pricing"""
    BW = "bw"
    COLOR = "color"


class Order(Base):
    """Order model representing a print order"""

    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(20), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    station_id = Column(String(50), nullable=False)

    # Order details
    total_pages = Column(Integer, nullable=False, default=0)
    bw_pages = Column(Integer, nullable=False, default=0)
    color_pages = Column(Integer, nullable=False, default=0)
    total_amount = Column(Float, nullable=False)

    # Status tracking
    status = Column(Enum(OrderStatus), default=OrderStatus.CREATED)
    status_message = Column(String(255), nullable=True)

    # Validity
    expires_at = Column(DateTime, nullable=False)
    printed_at = Column(DateTime, nullable=True)

    # QR code for print release
    qr_token = Column(String(100), unique=True, nullable=True)

    # Rating
    rating = Column(Integer, nullable=True)
    feedback = Column(Text, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    payment = relationship("Payment", back_populates="order", uselist=False)

    def __repr__(self):
        return f"<Order {self.order_number}>"


class OrderItem(Base):
    """Order item model representing individual files/pages in an order"""

    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)

    # File details
    file_name = Column(String(255), nullable=False)
    file_type = Column(String(20), nullable=False)  # pdf, image, collage
    file_size = Column(Integer, nullable=False)  # in bytes
    file_path = Column(String(500), nullable=True)  # temporary storage path

    # Page details
    total_pages = Column(Integer, nullable=False, default=1)
    bw_pages = Column(Integer, nullable=False, default=0)
    color_pages = Column(Integer, nullable=False, default=0)

    # Collage info (if applicable)
    is_collage = Column(Integer, default=0)  # 0 = no, 1 = yes
    collage_layout = Column(String(10), nullable=True)  # 2x1, 2x2, 3x2, 4x2
    collage_images = Column(JSON, nullable=True)  # List of image paths for collage

    # Pricing
    item_amount = Column(Float, nullable=False)

    # Status
    print_status = Column(String(50), default="pending")  # pending, printing, done, failed

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    order = relationship("Order", back_populates="items")

    def __repr__(self):
        return f"<OrderItem {self.file_name}>"
