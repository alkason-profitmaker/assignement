"""
Order API routes
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
import json

from app.core.database import get_db
from app.services.order_service import OrderService
from app.services.file_service import FileService
from app.schemas.order import (
    OrderResponse, OrderListResponse, OrderRatingRequest,
    OrderPreviewResponse, PriceBreakdown, OrderItemResponse
)
from app.api.deps import get_current_user
from app.models.user import User
from app.models.order import OrderStatus
from app.core.config import settings

router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("/upload", response_model=OrderPreviewResponse)
async def upload_files_for_preview(
    files: List[UploadFile] = File(...),
    collage_config: Optional[str] = Form(None),  # JSON string
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload files and get preview with pricing.
    Does NOT create order yet - just calculates price.

    For collage: pass collage_config as JSON:
    {"layout": "2x2", "create_collage": true}
    """
    file_service = FileService()
    items_info = []

    # Parse collage config if provided
    collage = None
    if collage_config:
        try:
            collage = json.loads(collage_config)
        except json.JSONDecodeError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid collage configuration"
            )

    total_bw = 0
    total_color = 0

    # Process files
    if collage and collage.get("create_collage"):
        # Collage mode - combine images into single PDF
        image_paths = []
        for file in files:
            content = await file.read()
            file_path = file_service.save_uploaded_file(content, file.filename)
            image_paths.append(file_path)

        layout = collage.get("layout", "2x2")
        collage_path, collage_info = file_service.create_collage(image_paths, layout)

        items_info.append({
            "file_name": f"collage_{layout}.pdf",
            "file_type": "collage",
            "file_path": collage_path,
            "total_pages": collage_info["total_pages"],
            "bw_pages": collage_info["bw_pages"],
            "color_pages": collage_info["color_pages"],
            "file_size": collage_info["file_size"],
            "is_collage": True,
            "collage_layout": layout,
            "collage_images": image_paths
        })

        total_bw += collage_info["bw_pages"]
        total_color += collage_info["color_pages"]

    else:
        # Regular file upload
        for file in files:
            content = await file.read()
            file_path = file_service.save_uploaded_file(content, file.filename)

            # Validate and analyze file
            file_type = "pdf" if file.filename.lower().endswith(".pdf") else "image"
            validation = file_service.validate_file(file_path, file_type)

            if not validation.get("valid"):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid file {file.filename}: {validation.get('error')}"
                )

            info = validation["info"]
            items_info.append({
                "file_name": file.filename,
                "file_type": file_type,
                "file_path": file_path,
                "total_pages": info["total_pages"],
                "bw_pages": info["bw_pages"],
                "color_pages": info["color_pages"],
                "file_size": info["file_size"],
                "is_collage": False
            })

            total_bw += info["bw_pages"]
            total_color += info["color_pages"]

    # Check page limit
    total_pages = total_bw + total_color
    if total_pages > settings.MAX_PAGES_PER_ORDER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Too many pages. Maximum: {settings.MAX_PAGES_PER_ORDER}"
        )

    # Calculate pricing
    price_info = file_service.calculate_price(total_bw, total_color)

    # Build preview response
    items_response = []
    for item in items_info:
        item_price = file_service.calculate_price(
            item["bw_pages"], item["color_pages"]
        )["total_amount"]

        items_response.append(OrderItemResponse(
            id=0,  # Not created yet
            file_name=item["file_name"],
            file_type=item["file_type"],
            total_pages=item["total_pages"],
            bw_pages=item["bw_pages"],
            color_pages=item["color_pages"],
            is_collage=item.get("is_collage", False),
            collage_layout=item.get("collage_layout"),
            item_amount=item_price,
            print_status="pending"
        ))

    # Store items info in session/cache for order creation
    # For MVP, we'll pass file paths directly

    return OrderPreviewResponse(
        items=items_response,
        price_breakdown=PriceBreakdown(**price_info),
        station_location="Near Main Gate",
        validity_hours=settings.ORDER_VALIDITY_HOURS
    )


@router.post("/create", response_model=OrderResponse)
async def create_order(
    files: List[UploadFile] = File(...),
    collage_config: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new print order after file upload.
    This creates the order and prepares it for payment.
    """
    file_service = FileService()
    order_service = OrderService(db)
    items_data = []

    # Parse collage config
    collage = None
    if collage_config:
        try:
            collage = json.loads(collage_config)
        except json.JSONDecodeError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid collage configuration"
            )

    # Process files (same logic as preview)
    if collage and collage.get("create_collage"):
        image_paths = []
        for file in files:
            content = await file.read()
            file_path = file_service.save_uploaded_file(content, file.filename)
            image_paths.append(file_path)

        layout = collage.get("layout", "2x2")
        collage_path, collage_info = file_service.create_collage(image_paths, layout)

        items_data.append({
            "file_name": f"collage_{layout}.pdf",
            "file_type": "collage",
            "file_path": collage_path,
            "total_pages": collage_info["total_pages"],
            "bw_pages": collage_info["bw_pages"],
            "color_pages": collage_info["color_pages"],
            "file_size": collage_info["file_size"],
            "is_collage": True,
            "collage_layout": layout,
            "collage_images": image_paths
        })
    else:
        for file in files:
            content = await file.read()
            file_path = file_service.save_uploaded_file(content, file.filename)

            file_type = "pdf" if file.filename.lower().endswith(".pdf") else "image"
            validation = file_service.validate_file(file_path, file_type)

            if not validation.get("valid"):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid file {file.filename}: {validation.get('error')}"
                )

            info = validation["info"]
            items_data.append({
                "file_name": file.filename,
                "file_type": file_type,
                "file_path": file_path,
                "total_pages": info["total_pages"],
                "bw_pages": info["bw_pages"],
                "color_pages": info["color_pages"],
                "file_size": info["file_size"],
                "is_collage": False
            })

    # Create order
    order = order_service.create_order(current_user.id, items_data)

    # Get price breakdown
    price_breakdown = order_service.get_order_price_breakdown(order)

    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        status=order.status,
        status_message=order.status_message,
        total_pages=order.total_pages,
        bw_pages=order.bw_pages,
        color_pages=order.color_pages,
        total_amount=order.total_amount,
        expires_at=order.expires_at,
        created_at=order.created_at,
        items=[OrderItemResponse.model_validate(item) for item in order.items],
        price_breakdown=PriceBreakdown(**price_breakdown)
    )


@router.get("/", response_model=OrderListResponse)
async def get_user_orders(
    page: int = 1,
    page_size: int = 10,
    status_filter: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get paginated list of user's orders.
    """
    order_service = OrderService(db)

    # Parse status filter
    status_enum = None
    if status_filter:
        try:
            status_enum = OrderStatus(status_filter)
        except ValueError:
            pass

    orders, total = order_service.get_user_orders(
        current_user.id, page, page_size, status_enum
    )

    order_responses = []
    for order in orders:
        price_breakdown = order_service.get_order_price_breakdown(order)
        order_responses.append(OrderResponse(
            id=order.id,
            order_number=order.order_number,
            status=order.status,
            status_message=order.status_message,
            total_pages=order.total_pages,
            bw_pages=order.bw_pages,
            color_pages=order.color_pages,
            total_amount=order.total_amount,
            expires_at=order.expires_at,
            created_at=order.created_at,
            printed_at=order.printed_at,
            rating=order.rating,
            items=[OrderItemResponse.model_validate(item) for item in order.items],
            price_breakdown=PriceBreakdown(**price_breakdown)
        ))

    return OrderListResponse(
        orders=order_responses,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get("/{order_number}", response_model=OrderResponse)
async def get_order(
    order_number: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get order details by order number.
    """
    order_service = OrderService(db)
    order = order_service.get_order_by_number(order_number)

    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this order"
        )

    price_breakdown = order_service.get_order_price_breakdown(order)

    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        status=order.status,
        status_message=order.status_message,
        total_pages=order.total_pages,
        bw_pages=order.bw_pages,
        color_pages=order.color_pages,
        total_amount=order.total_amount,
        expires_at=order.expires_at,
        created_at=order.created_at,
        printed_at=order.printed_at,
        rating=order.rating,
        items=[OrderItemResponse.model_validate(item) for item in order.items],
        price_breakdown=PriceBreakdown(**price_breakdown)
    )


@router.post("/{order_number}/rate", response_model=OrderResponse)
async def rate_order(
    order_number: str,
    rating_data: OrderRatingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Rate a completed order.
    """
    order_service = OrderService(db)
    order = order_service.get_order_by_number(order_number)

    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found"
        )

    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to rate this order"
        )

    if order.status != OrderStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Can only rate completed orders"
        )

    order = order_service.rate_order(order, rating_data.rating, rating_data.feedback)

    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        status=order.status,
        status_message=order.status_message,
        total_pages=order.total_pages,
        bw_pages=order.bw_pages,
        color_pages=order.color_pages,
        total_amount=order.total_amount,
        expires_at=order.expires_at,
        created_at=order.created_at,
        printed_at=order.printed_at,
        rating=order.rating,
        items=[OrderItemResponse.model_validate(item) for item in order.items]
    )
