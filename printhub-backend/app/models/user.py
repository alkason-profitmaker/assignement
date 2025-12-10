"""
User model for PrintHub
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base


class User(Base):
    """User model representing a resident"""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=True)
    flat_number = Column(String(20), nullable=True)
    tower = Column(String(50), nullable=True)
    society_id = Column(String(50), nullable=False, default="SOCIETY_001")

    # Authentication
    otp_hash = Column(String(255), nullable=True)
    otp_expiry = Column(DateTime, nullable=True)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)

    # Relationships
    orders = relationship("Order", back_populates="user")

    def __repr__(self):
        return f"<User {self.phone_number}>"
