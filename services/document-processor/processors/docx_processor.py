
try:
    import docx  # python-docx
except Exception:  # pragma: no cover
    docx = None  # type: ignore


def extract_text_from_docx(file_path: str) -> str:
    """Extract plain text from a DOCX file using python-docx.

    Returns empty string if library is unavailable or parsing fails.
    """
    if docx is None:
        return ""
    try:
        document = docx.Document(file_path)
        return "\n".join(p.text for p in document.paragraphs).strip()
    except Exception:
        return ""


