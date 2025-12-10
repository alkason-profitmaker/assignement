"""
User service for authentication and user management
"""
import random
import string
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash, verify_password, create_access_token
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)


class UserService:
    """Service for user-related operations"""

    def __init__(self, db: Session):
        self.db = db

    def get_user_by_phone(self, phone_number: str) -> Optional[User]:
        """Get user by phone number"""
        return self.db.query(User).filter(User.phone_number == phone_number).first()

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        """Get user by ID"""
        return self.db.query(User).filter(User.id == user_id).first()

    def create_user(self, user_data: UserCreate) -> User:
        """Create a new user"""
        user = User(
            phone_number=user_data.phone_number,
            name=user_data.name,
            flat_number=user_data.flat_number,
            tower=user_data.tower,
            society_id=settings.SOCIETY_ID
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        logger.info(f"Created new user: {user.phone_number}")
        return user

    def update_user(self, user_id: int, user_data: UserUpdate) -> Optional[User]:
        """Update user profile"""
        user = self.get_user_by_id(user_id)
        if not user:
            return None

        if user_data.name is not None:
            user.name = user_data.name
        if user_data.flat_number is not None:
            user.flat_number = user_data.flat_number
        if user_data.tower is not None:
            user.tower = user_data.tower

        user.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(user)
        return user

    def generate_otp(self) -> str:
        """Generate a 6-digit OTP"""
        return ''.join(random.choices(string.digits, k=6))

    def send_otp(self, phone_number: str) -> dict:
        """
        Send OTP to user's phone number.
        In production, integrate with SMS gateway (MSG91, Twilio, etc.)
        For MVP, we'll simulate OTP sending.
        """
        user = self.get_user_by_phone(phone_number)
        if not user:
            # Auto-register new users
            user = self.create_user(UserCreate(phone_number=phone_number))

        otp = self.generate_otp()
        otp_expiry = datetime.utcnow() + timedelta(minutes=10)

        # Store hashed OTP
        user.otp_hash = get_password_hash(otp)
        user.otp_expiry = otp_expiry
        self.db.commit()

        # In production, send SMS here
        # For MVP/development, log the OTP
        logger.info(f"OTP for {phone_number}: {otp}")

        return {
            "success": True,
            "message": "OTP sent successfully",
            "phone_number": phone_number,
            # Remove in production - only for testing
            "debug_otp": otp if settings.DEBUG else None
        }

    def verify_otp(self, phone_number: str, otp: str) -> dict:
        """Verify OTP and return access token"""
        user = self.get_user_by_phone(phone_number)
        if not user:
            return {"success": False, "message": "User not found"}

        if not user.otp_hash or not user.otp_expiry:
            return {"success": False, "message": "No OTP requested"}

        if datetime.utcnow() > user.otp_expiry:
            return {"success": False, "message": "OTP expired"}

        if not verify_password(otp, user.otp_hash):
            return {"success": False, "message": "Invalid OTP"}

        # Clear OTP after successful verification
        user.otp_hash = None
        user.otp_expiry = None
        user.is_verified = True
        user.last_login = datetime.utcnow()
        self.db.commit()

        # Generate access token
        access_token = create_access_token(
            data={"sub": str(user.id), "phone": user.phone_number}
        )

        logger.info(f"User {phone_number} logged in successfully")

        return {
            "success": True,
            "access_token": access_token,
            "token_type": "bearer",
            "user": user
        }
