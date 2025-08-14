from typing import Optional

try:
    from PyPDF2 import PdfReader
except Exception:  # pragma: no cover
    PdfReader = None  # type: ignore


def extract_text_from_pdf(file_path: str) -> str:
    """Extract plain text from a PDF file using PyPDF2.

    Returns empty string if library is unavailable or parsing fails.
    """
    if PdfReader is None:
        return ""
    try:
        reader = PdfReader(file_path)
        parts = []
        for page in reader.pages:
            try:
                parts.append(page.extract_text() or "")
            except Exception:
                continue
        return "\n".join(parts).strip()
    except Exception:
        return ""


