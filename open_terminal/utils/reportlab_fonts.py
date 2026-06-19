"""
ReportLab font registration.

ReportLab has zero filesystem/fontconfig awareness -- a font file existing
on disk does nothing until it's explicitly registered. And only TrueType
`glyf`-outline fonts work: Noto Sans/Serif CJK ships as CFF (PostScript)
outlines, which raises TTFError regardless of how you reference it.

WenQuanYi Zen Hei is glyf-format AND has full Latin + Han coverage in one
file -- verified by rendering mixed English/Chinese text through Platypus.

Droid Sans Fallback (glyf-format, present on the host) was the original
candidate, but it has ZERO Latin glyphs -- it's designed to be used only
as a fallback *after* a primary Latin font in a font stack. ReportLab has
no such fallback-chain concept, so any English mixed into the same
Paragraph silently disappears (the layout reserves the width, but draws
nothing). WenQuanYi Zen Hei isn't on the host's bind-mounted fonts, so it
must be baked into the image specifically for this purpose (see Dockerfile).

Call register_cjk_font() once, before any PDF generation that might need
CJK text. Safe to call repeatedly -- it's a no-op after the first success.
"""

import os
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

WQY_PATH = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"
FONT_NAME = "CJK-Fallback"

_registered = False


def register_cjk_font(path: str = WQY_PATH, font_name: str = FONT_NAME) -> str:
    """
    Register the CJK + Latin font ReportLab can actually parse and that
    won't drop English text.

    Returns the registered font name on success. Raises RuntimeError if
    the file is missing -- means the `fonts-wqy-zenhei` apt package isn't
    installed in this image (it's intentionally baked in, not supplied by
    the host font bind-mount).

    Do NOT use:
    - Any Noto Sans/Serif CJK file -- CFF (PostScript) outlines, raises
      TTFError on ReportLab's TTFont parser regardless of subfontIndex.
    - Droid Sans Fallback -- glyf-format and ReportLab-parseable, but has
      NO Latin glyphs. Mixed English/Chinese text silently loses all the
      English. Verified by rendering -- it doesn't raise an error, it just
      renders blank space where the English should be.
    """
    global _registered
    if _registered:
        return font_name

    if not os.path.exists(path):
        raise RuntimeError(
            f"CJK font not found at {path}. "
            "Is `fonts-wqy-zenhei` installed in this image? "
            "It must be baked in -- it is not supplied by the host font bind-mount."
        )

    pdfmetrics.registerFont(TTFont(font_name, path, subfontIndex=0))

    # WenQuanYi Zen Hei has no separate bold/italic face either. Map all
    # four style slots to the same regular face so platypus markup like
    # <b> or <i> degrades to the regular glyphs instead of raising a
    # KeyError when it looks up a bold/italic variant that was never
    # registered.
    pdfmetrics.registerFontFamily(
        font_name,
        normal=font_name,
        bold=font_name,
        italic=font_name,
        boldItalic=font_name,
    )

    _registered = True
    return font_name
