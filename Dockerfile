# Pin to a specific patch version for reproducible builds.
# To pick up security patches, bump this version and rebuild.
FROM python:3.12.13

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    coreutils findutils grep sed gawk diffutils patch \
    less file tree bc man-db \
    # Networking
    curl wget net-tools iputils-ping dnsutils netcat-openbsd socat telnet \
    openssh-client rsync \
    # Editors
    vim nano \
    # Version control
    git \
    # Build tools
    build-essential cmake make \
    # Scripting & languages
    perl ruby-full lua5.4 \
    # Data processing
    jq xmlstarlet sqlite3 \
    # Media & documents
    ffmpeg pandoc imagemagick texlive-latex-base \
    librsvg2-bin poppler-utils \
    graphviz ghostscript \
    # ^ NEW: graphviz = diagram/graph rendering (dot); ghostscript = PDF
    #        compress/repair + backend for table extractors (camelot etc.)
    # WeasyPrint's rendering engine (Cairo/Pango text shaping + gdk-pixbuf
    # image decoding) and fontconfig's matching engine. No general CJK/emoji
    # font FILES are installed here on purpose: they're supplied at runtime
    # via a read-only bind mount of the host's /usr/share/fonts (Ubuntu VM
    # already has Noto CJK + Droid Sans Fallback). entrypoint.sh must run
    # `fc-cache -f` on startup, since the mount doesn't exist at build time.
    fontconfig \
    libcairo2 libpango-1.0-0 libpangoft2-1.0-0 libgdk-pixbuf-2.0-0 \
    shared-mime-info \
    # ReportLab CANNOT use the host's Noto CJK fonts (CFF outlines -- always
    # raises TTFError) or Droid Sans Fallback (glyf-OK, but has zero Latin
    # glyphs -- English text silently vanishes from mixed EN/CN PDFs).
    # WenQuanYi Zen Hei is the one glyf-format font with full Latin + Han
    # coverage in a single file, and it's not on the host, so it's baked
    # in here specifically for ReportLab's sake. See reportlab_fonts.py.
    fonts-wqy-zenhei \
    # Compression
    zip unzip tar gzip bzip2 xz-utils zstd p7zip-full \
    # System
    procps htop lsof strace sysstat \
    sudo tmux screen tini iptables ipset dnsmasq \
    ca-certificates gnupg apt-transport-https \
    # Capabilities (needed for setcap on Python binary)
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI + Compose + Buildx (mount socket at runtime for access)
RUN curl -fsSL https://get.docker.com | sh

WORKDIR /app

RUN pip install --no-cache-dir \
    numpy pandas scipy scikit-learn \
    matplotlib seaborn plotly \
    jupyter ipython \
    requests beautifulsoup4 lxml \
    sqlalchemy psycopg2-binary \
    pyyaml toml jsonlines \
    tqdm rich \
    openpyxl weasyprint \
    python-docx python-pptx pypdf reportlab csvkit \
    jinja2 Pillow \
    # NEW: static chart export (Plotly needs kaleido to write image files)
    kaleido \
    # NEW: PDF read/render side (pypdf only writes/merges)
    pymupdf pdf2image pdfplumber \
    # NEW: codes + richer Excel write (charts, conditional formatting)
    qrcode python-barcode xlsxwriter \
    # NEW: SVG -> PNG/PDF (cairo) and SVG -> ReportLab flowable
    cairosvg svglib \
    # NEW: HEIC/HEIF decode + headless computer vision
    pillow-heif opencv-python-headless \
    # NEW: python bindings for graphviz (needs the apt `dot` above)
    graphviz pydot

COPY . .

# Create a capability-bearing Python copy for the server process only.
# The system python3 stays clean so user-spawned Python processes remain
# dumpable (readable via /proc/[pid]/fd/ for port detection).
RUN pip install --no-cache-dir . \
    && cp "$(readlink -f "$(which python3)")" /usr/local/bin/python3-ot \
    && setcap cap_setgid+ep /usr/local/bin/python3-ot \
    && sed -i "1s|.*|#!/usr/local/bin/python3-ot|" "$(which open-terminal)"

RUN useradd -m -s /bin/bash user && echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER user
ENV SHELL=/bin/bash
ENV PATH="/home/user/.local/bin:${PATH}"
WORKDIR /home/user

EXPOSE 8000

# Runtime requirement (not enforceable at build time): bind-mount the host's
# fonts read-only, e.g. `docker run -v /usr/share/fonts:/usr/share/fonts:ro`.
COPY entrypoint.sh /app/entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["run"]
