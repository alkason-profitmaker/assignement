"""
File service for handling file uploads, PDF processing, and collage creation
"""
import os
import uuid
import tempfile
from typing import List, Tuple, Optional
from PIL import Image
from PyPDF2 import PdfReader
import io
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)

# Temporary directory for file storage
TEMP_DIR = tempfile.mkdtemp(prefix="printhub_")


class FileService:
    """Service for file processing operations"""

    # Collage layout configurations (images per page)
    COLLAGE_LAYOUTS = {
        "2x1": {"rows": 2, "cols": 1, "images_per_page": 2},
        "2x2": {"rows": 2, "cols": 2, "images_per_page": 4},
        "3x2": {"rows": 3, "cols": 2, "images_per_page": 6},
        "4x2": {"rows": 4, "cols": 2, "images_per_page": 8},
    }

    # A4 dimensions at 300 DPI
    A4_WIDTH = 2480  # pixels
    A4_HEIGHT = 3508  # pixels
    MARGIN = 50  # pixels

    def __init__(self):
        os.makedirs(TEMP_DIR, exist_ok=True)

    def save_uploaded_file(self, content: bytes, filename: str) -> str:
        """Save uploaded file to temporary storage"""
        file_id = str(uuid.uuid4())
        ext = os.path.splitext(filename)[1]
        file_path = os.path.join(TEMP_DIR, f"{file_id}{ext}")

        with open(file_path, "wb") as f:
            f.write(content)

        logger.info(f"Saved file: {file_path}")
        return file_path

    def get_pdf_info(self, file_path: str) -> dict:
        """
        Analyze PDF file and return page information.
        Determines B/W vs color pages.
        """
        try:
            reader = PdfReader(file_path)
            total_pages = len(reader.pages)

            # For MVP, we'll use a simplified color detection
            # In production, use more sophisticated image analysis
            bw_pages = 0
            color_pages = 0

            for page in reader.pages:
                # Check if page has color content
                # Simplified: assume pages with images might be color
                if "/XObject" in page.get("/Resources", {}):
                    color_pages += 1
                else:
                    bw_pages += 1

            # If no detection worked, default to B/W
            if bw_pages == 0 and color_pages == 0:
                bw_pages = total_pages

            return {
                "total_pages": total_pages,
                "bw_pages": bw_pages,
                "color_pages": color_pages,
                "file_size": os.path.getsize(file_path)
            }
        except Exception as e:
            logger.error(f"Error analyzing PDF: {e}")
            raise ValueError(f"Could not process PDF file: {str(e)}")

    def analyze_image(self, file_path: str) -> dict:
        """
        Analyze image file to determine if it's color or B/W.
        """
        try:
            with Image.open(file_path) as img:
                # Check if image is grayscale
                is_bw = img.mode in ("L", "1") or self._is_grayscale(img)

                return {
                    "total_pages": 1,
                    "bw_pages": 1 if is_bw else 0,
                    "color_pages": 0 if is_bw else 1,
                    "width": img.width,
                    "height": img.height,
                    "file_size": os.path.getsize(file_path)
                }
        except Exception as e:
            logger.error(f"Error analyzing image: {e}")
            raise ValueError(f"Could not process image file: {str(e)}")

    def _is_grayscale(self, img: Image.Image, threshold: int = 10) -> bool:
        """Check if an RGB image is effectively grayscale"""
        if img.mode != "RGB":
            return True

        # Sample pixels to check for color
        pixels = list(img.getdata())
        sample_size = min(1000, len(pixels))
        sample = pixels[::max(1, len(pixels) // sample_size)]

        for r, g, b in sample:
            if abs(r - g) > threshold or abs(g - b) > threshold or abs(r - b) > threshold:
                return False
        return True

    def create_collage(
        self,
        image_paths: List[str],
        layout: str,
        output_format: str = "PDF"
    ) -> Tuple[str, dict]:
        """
        Create a photo collage from multiple images.
        Returns the path to the generated file and page info.
        """
        if layout not in self.COLLAGE_LAYOUTS:
            raise ValueError(f"Invalid layout: {layout}. Valid options: {list(self.COLLAGE_LAYOUTS.keys())}")

        layout_config = self.COLLAGE_LAYOUTS[layout]
        rows = layout_config["rows"]
        cols = layout_config["cols"]
        images_per_page = layout_config["images_per_page"]

        # Calculate cell dimensions
        cell_width = (self.A4_WIDTH - (cols + 1) * self.MARGIN) // cols
        cell_height = (self.A4_HEIGHT - (rows + 1) * self.MARGIN) // rows

        pages = []
        total_images = len(image_paths)
        num_pages = (total_images + images_per_page - 1) // images_per_page

        for page_num in range(num_pages):
            # Create A4 page
            page = Image.new("RGB", (self.A4_WIDTH, self.A4_HEIGHT), "white")

            # Place images on page
            start_idx = page_num * images_per_page
            end_idx = min(start_idx + images_per_page, total_images)

            for i, img_idx in enumerate(range(start_idx, end_idx)):
                row = i // cols
                col = i % cols

                x = self.MARGIN + col * (cell_width + self.MARGIN)
                y = self.MARGIN + row * (cell_height + self.MARGIN)

                try:
                    with Image.open(image_paths[img_idx]) as img:
                        # Resize image to fit cell while maintaining aspect ratio
                        img.thumbnail((cell_width, cell_height), Image.Resampling.LANCZOS)

                        # Center image in cell
                        paste_x = x + (cell_width - img.width) // 2
                        paste_y = y + (cell_height - img.height) // 2

                        # Convert to RGB if necessary
                        if img.mode in ("RGBA", "P"):
                            img = img.convert("RGB")

                        page.paste(img, (paste_x, paste_y))
                except Exception as e:
                    logger.error(f"Error processing image {image_paths[img_idx]}: {e}")

            pages.append(page)

        # Save as PDF
        output_id = str(uuid.uuid4())
        output_path = os.path.join(TEMP_DIR, f"collage_{output_id}.pdf")

        if pages:
            pages[0].save(
                output_path,
                "PDF",
                save_all=True,
                append_images=pages[1:] if len(pages) > 1 else []
            )

        # Analyze collage for color content
        is_color = any(not self._is_grayscale(Image.open(p)) for p in image_paths if os.path.exists(p))

        return output_path, {
            "total_pages": num_pages,
            "bw_pages": 0 if is_color else num_pages,
            "color_pages": num_pages if is_color else 0,
            "file_size": os.path.getsize(output_path),
            "layout": layout,
            "images_used": len(image_paths)
        }

    def calculate_price(self, bw_pages: int, color_pages: int) -> dict:
        """Calculate price for print job"""
        bw_total = bw_pages * settings.PRICE_BW_PAGE
        color_total = color_pages * settings.PRICE_COLOR_PAGE
        total = bw_total + color_total

        return {
            "bw_pages": bw_pages,
            "color_pages": color_pages,
            "bw_price_per_page": settings.PRICE_BW_PAGE,
            "color_price_per_page": settings.PRICE_COLOR_PAGE,
            "bw_total": bw_total,
            "color_total": color_total,
            "total_amount": total
        }

    def cleanup_file(self, file_path: str) -> bool:
        """Remove temporary file after printing"""
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.info(f"Cleaned up file: {file_path}")
                return True
        except Exception as e:
            logger.error(f"Error cleaning up file {file_path}: {e}")
        return False

    def validate_file(self, file_path: str, file_type: str) -> dict:
        """Validate file before processing"""
        if not os.path.exists(file_path):
            return {"valid": False, "error": "File not found"}

        file_size = os.path.getsize(file_path)
        max_size = settings.MAX_FILE_SIZE_MB * 1024 * 1024

        if file_size > max_size:
            return {"valid": False, "error": f"File too large. Maximum size: {settings.MAX_FILE_SIZE_MB}MB"}

        if file_type == "pdf":
            try:
                info = self.get_pdf_info(file_path)
                if info["total_pages"] > settings.MAX_PAGES_PER_ORDER:
                    return {"valid": False, "error": f"Too many pages. Maximum: {settings.MAX_PAGES_PER_ORDER}"}
                return {"valid": True, "info": info}
            except Exception as e:
                return {"valid": False, "error": str(e)}

        elif file_type in ("image", "jpg", "jpeg", "png"):
            try:
                info = self.analyze_image(file_path)
                return {"valid": True, "info": info}
            except Exception as e:
                return {"valid": False, "error": str(e)}

        return {"valid": False, "error": "Unsupported file type"}
