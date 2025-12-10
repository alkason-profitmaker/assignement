"""
Authentication API routes
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.user_service import UserService
from app.schemas.user import (
    UserCreate, UserLogin, OTPVerify, UserUpdate, UserResponse, TokenResponse
)
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=dict)
async def register(
    user_data: UserCreate,
    db: Session = Depends(get_db)
):
    """
    Register a new user and send OTP for verification.
    For MVP, auto-registers and sends OTP.
    """
    service = UserService(db)

    # Check if user exists
    existing = service.get_user_by_phone(user_data.phone_number)
    if existing and existing.is_verified:
        # User exists, just send OTP for login
        result = service.send_otp(user_data.phone_number)
        return {
            "message": "User already registered. OTP sent for login.",
            **result
        }

    # Create user and send OTP
    if not existing:
        service.create_user(user_data)

    result = service.send_otp(user_data.phone_number)
    return {
        "message": "Registration successful. OTP sent for verification.",
        **result
    }


@router.post("/login", response_model=dict)
async def login(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Request OTP for login.
    Auto-registers new users.
    """
    service = UserService(db)
    result = service.send_otp(login_data.phone_number)
    return result


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(
    otp_data: OTPVerify,
    db: Session = Depends(get_db)
):
    """
    Verify OTP and get access token.
    """
    service = UserService(db)
    result = service.verify_otp(otp_data.phone_number, otp_data.otp)

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=result.get("message", "OTP verification failed")
        )

    return TokenResponse(
        access_token=result["access_token"],
        token_type=result["token_type"],
        user=UserResponse.model_validate(result["user"])
    )


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user)
):
    """
    Get current user's profile.
    """
    return UserResponse.model_validate(current_user)


@router.put("/me", response_model=UserResponse)
async def update_profile(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update current user's profile.
    """
    service = UserService(db)
    updated_user = service.update_user(current_user.id, user_data)

    if not updated_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return UserResponse.model_validate(updated_user)


@router.post("/resend-otp", response_model=dict)
async def resend_otp(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Resend OTP to user's phone number.
    """
    service = UserService(db)
    result = service.send_otp(login_data.phone_number)
    return result
