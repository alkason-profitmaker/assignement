"""
User schemas for API requests/responses
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class UserCreate(BaseModel):
    """Schema for user registration"""
    phone_number: str = Field(..., min_length=10, max_length=15, description="User phone number")
    name: Optional[str] = Field(None, max_length=100, description="User name")
    flat_number: Optional[str] = Field(None, max_length=20, description="Flat/apartment number")
    tower: Optional[str] = Field(None, max_length=50, description="Tower/building name")


class UserLogin(BaseModel):
    """Schema for user login request"""
    phone_number: str = Field(..., min_length=10, max_length=15)


class OTPVerify(BaseModel):
    """Schema for OTP verification"""
    phone_number: str = Field(..., min_length=10, max_length=15)
    otp: str = Field(..., min_length=4, max_length=6)


class UserUpdate(BaseModel):
    """Schema for user profile update"""
    name: Optional[str] = Field(None, max_length=100)
    flat_number: Optional[str] = Field(None, max_length=20)
    tower: Optional[str] = Field(None, max_length=50)


class UserResponse(BaseModel):
    """Schema for user response"""
    id: int
    phone_number: str
    name: Optional[str] = None
    flat_number: Optional[str] = None
    tower: Optional[str] = None
    society_id: str
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Schema for authentication token response"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
