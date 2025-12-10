"""
Printer station model for PrintHub
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float
from datetime import datetime
from app.core.database import Base


class PrinterStatus(str):
    """Printer status constants"""
    ONLINE = "online"
    OFFLINE = "offline"
    BUSY = "busy"
    ERROR = "error"
    PAPER_LOW = "paper_low"
    INK_LOW = "ink_low"


class PrinterStation(Base):
    """Printer station model representing a physical printing station"""

    __tablename__ = "printer_stations"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(String(50), unique=True, index=True, nullable=False)
    society_id = Column(String(50), nullable=False)

    # Station details
    name = Column(String(100), nullable=False)
    location = Column(String(255), nullable=False)  # e.g., "Near Main Gate"
    ip_address = Column(String(50), nullable=True)

    # Status
    status = Column(String(20), default=PrinterStatus.OFFLINE)
    is_active = Column(Boolean, default=True)

    # Capabilities
    supports_color = Column(Boolean, default=True)
    supports_bw = Column(Boolean, default=True)
    max_pages = Column(Integer, default=100)

    # Supplies tracking
    paper_level = Column(Integer, default=100)  # percentage
    bw_ink_level = Column(Integer, default=100)  # percentage
    color_ink_level = Column(Integer, default=100)  # percentage

    # Statistics
    total_pages_printed = Column(Integer, default=0)
    total_orders_processed = Column(Integer, default=0)

    # QR Code for the station
    qr_code_token = Column(String(100), unique=True, nullable=False)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_heartbeat = Column(DateTime, nullable=True)

    def __repr__(self):
        return f"<PrinterStation {self.station_id}>"
