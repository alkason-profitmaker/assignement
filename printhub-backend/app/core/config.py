"""
PrintHub Backend Configuration
"""
from pydantic_settings import BaseSettings
from typing import Optional
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings"""

    # App settings
    APP_NAME: str = "PrintHub"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    API_PREFIX: str = "/api/v1"

    # Database
    DATABASE_URL: str = "sqlite:///./printhub.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT Settings
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Razorpay Settings
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""

    # Pricing (in INR)
    PRICE_BW_PAGE: float = 3.0
    PRICE_COLOR_PAGE: float = 10.0

    # Order settings
    ORDER_VALIDITY_HOURS: int = 2
    MAX_FILE_SIZE_MB: int = 50
    MAX_PAGES_PER_ORDER: int = 100

    # Printer settings
    PRINTER_STATION_ID: str = "STATION_001"
    PRINTER_IP: str = "192.168.1.100"

    # Society settings (MVP - single society)
    SOCIETY_ID: str = "SOCIETY_001"
    SOCIETY_NAME: str = "Green Valley Apartments"

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


settings = get_settings()
