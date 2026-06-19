"""ReportLab font registration.

ReportLab has zero filesystem/fontconfig awareness -- a font file existing
on disk does nothing until it's explicitly registered. And only TrueType
``glyf``-outline fonts work: Noto Sans/Serif CJK ships as CFF (PostScript)
outlines, which raises TTFError regardless of how you reference it.
Droid Sans Fallback is glyf-format and is the only verified-working CJK
option available via the host's bind-mounted fonts.

Call register_cjk_font() once, before any PDF generation that might need
CJK text. Safe to call repeatedly -- it's a no-op after the first success.
"""

import os

from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

DROID_PATH = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"
FONT_NAME = "CJK-Fallback"

_registered = False


def register_cjk_font(path: str = DROID_PATH, font_name: str = FONT_NAME) -> str:
    """Register the one CJK font ReportLab can actually parse.

    Returns the registered font name on success. Raises RuntimeError if
    the file is missing -- almost always means the host font bind-mount
    (``-v /usr/share/fonts:/usr/share/fonts:ro``) isn't attached to this
    container.

    Do not point this at any Noto Sans/Serif CJK file: those are CFF
    (PostScript) outline fonts. ReportLab's TTFont parser only supports
    TrueType ``glyf`` outlines and will raise TTFError on them every time,
    regardless of subfontIndex.
    """
    global _registered
    if _registered:
        return font_name

    if not os.path.exists(path):
        raise RuntimeError(
            f"CJK font not found at {path}. "
            "Is the host font bind-mount attached? "
            "(docker run -v /usr/share/fonts:/usr/share/fonts:ro ...)"
        )

    pdfmetrics.registerFont(TTFont(font_name, path))

    # Droid Sans Fallback has no separate bold/italic face. Map all four
    # style slots to the same regular face so platypus markup like <b> or
    # <i> degrades to the regular glyphs instead of raising a KeyError.
    pdfmetrics.registerFontFamily(
        font_name,
        normal=font_name,
        bold=font_name,
        italic=font_name,
        boldItalic=font_name,
    )

    _registered = True
    return font_name
