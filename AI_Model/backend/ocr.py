from PIL import Image
import pytesseract
import io

# change this path if your Tesseract is installed somewhere else
pytesseract.pytesseract.tesseract_cmd = r"D:\Program Files\tesseracttesseract.exe"


def extract_text_from_image_bytes(image_bytes: bytes) -> str:
    image = Image.open(io.BytesIO(image_bytes))
    text = pytesseract.image_to_string(image)
    return text.strip()