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
    jinja2 Pillow
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
# WeasyPrint discovers them automatically via fontconfig -- this covers
# Arabic, Thai, emoji, and every other script the host has installed.
# ReportLab needs none of that: it only ever uses the baked-in
# fonts-wqy-zenhei, registered explicitly in reportlab_fonts.py.
COPY entrypoint.sh /app/entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["run"]
