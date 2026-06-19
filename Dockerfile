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
    # WeasyPrint's rendering engine (Cairo/Pango text shaping + gdk-pixbuf
    # image decoding) and fontconfig's matching engine. No CJK/emoji font
    # files are installed here on purpose: they're supplied at runtime via
    # a read-only bind mount of the host's /usr/share/fonts. entrypoint.sh
    # must run fc-cache -f on startup, since the mount doesn't exist at
    # build time and fontconfig needs to index it fresh.
    fontconfig \
    libcairo2 libpango-1.0-0 libpangoft2-1.0-0 libgdk-pixbuf-2.0-0 \
    shared-mime-info \
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

# Uncomment to apply security patches beyond what the base image provides.
# Not recommended for reproducible builds; prefer bumping the base image tag.
# RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*


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
    python-docx python-pptx pypdf csvkit \
    jinja2 Pillow reportlab

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
# fonts read-only, e.g. docker run -v /usr/share/fonts:/usr/share/fonts:ro.
# WeasyPrint discovers them automatically via fontconfig. ReportLab does not
# auto-discover anything -- only register fonts it can actually parse:
#   pdfmetrics.registerFont(TTFont('Droid', '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf'))
# Do not register any Noto Sans/Serif CJK file with ReportLab -- they're CFF
# (PostScript) outline fonts, and ReportLab's TTFont parser only supports
# TrueType glyf outlines. It will raise TTFError regardless of subfontIndex.
COPY --chmod=0755 entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["run"]
