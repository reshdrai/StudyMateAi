import io

try:
    from PIL import Image
    import pytesseract
    TESSERACT_AVAILABLE = True
except ImportError:
    TESSERACT_AVAILABLE = False

# Try common tesseract paths
import shutil
import platform

if TESSERACT_AVAILABLE:
    if platform.system() == "Windows":
        common_paths = [
            r"C:\Program Files\Tesseract-OCR\tesseract.exe",
            r"D:\Program Files\Tesseract-OCR\tesseract.exe",
            r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
        ]
        for p in common_paths:
            if shutil.which("tesseract") or __import__("os").path.exists(p):
                pytesseract.pytesseract.tesseract_cmd = p
                break
    # On Linux/Mac, tesseract is usually in PATH


def extract_text_from_image_bytes(image_bytes: bytes) -> str:
    if not TESSERACT_AVAILABLE:
        return "[OCR unavailable - install pytesseract and Tesseract-OCR]"

    try:
        image = Image.open(io.BytesIO(image_bytes))
        text = pytesseract.image_to_string(image)
        return text.strip()
    except Exception as e:
        print(f"[WARNING] OCR failed: {e}")
        return "[OCR failed to extract text from image]"
