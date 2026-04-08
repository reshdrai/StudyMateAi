from pypdf import PdfReader


def extract_text_from_pdf_file(file_path: str) -> str:
    reader = PdfReader(file_path)
    pages_text = []

    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            pages_text.append(text)

    return "\n\n".join(pages_text).strip()