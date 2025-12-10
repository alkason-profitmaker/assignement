"""
PrintHub Backend - Main FastAPI Application
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.core.config import settings
from app.core.database import init_db
from app.api.routes import auth, orders, payments, printer

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    init_db()
    logger.info("Database initialized")

    # Initialize default printer station
    from app.core.database import SessionLocal
    from app.services.printer_service import PrinterService
    db = SessionLocal()
    try:
        printer_service = PrinterService(db)
        station = printer_service.initialize_default_station()
        logger.info(f"Printer station initialized: {station.station_id}")
    finally:
        db.close()

    yield

    # Shutdown
    logger.info("Shutting down application")


# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
    PrintHub Community MVP API

    A hyperlocal, proximity-based self-service printing solution for residential apartment societies.

    ## Features
    - User authentication via OTP
    - File upload (PDF, images)
    - Photo collage creation
    - UPI payment via Razorpay
    - QR code based print release
    - Auto-refund on failure

    ## Pricing
    - B/W: ₹3/page
    - Color: ₹10/page
    """,
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(auth.router, prefix=settings.API_PREFIX)
app.include_router(orders.router, prefix=settings.API_PREFIX)
app.include_router(payments.router, prefix=settings.API_PREFIX)
app.include_router(printer.router, prefix=settings.API_PREFIX)


@app.get("/")
async def root():
    """Root endpoint - health check"""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "society": settings.SOCIETY_NAME
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.get(f"{settings.API_PREFIX}/pricing")
async def get_pricing():
    """Get current pricing information"""
    return {
        "bw_price_per_page": settings.PRICE_BW_PAGE,
        "color_price_per_page": settings.PRICE_COLOR_PAGE,
        "currency": "INR",
        "max_pages_per_order": settings.MAX_PAGES_PER_ORDER,
        "max_file_size_mb": settings.MAX_FILE_SIZE_MB,
        "order_validity_hours": settings.ORDER_VALIDITY_HOURS
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )
