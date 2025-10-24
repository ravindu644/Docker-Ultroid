# Use Ubuntu 22.04 LTS as the base image
FROM ubuntu:22.04

# Set a non-interactive frontend for package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install system-level dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    wget \
    redis-server \
    python3 \
    nano \
    python3-pip \
    sudo \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    curl \
    ffmpeg \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

# Install all required Python packages
RUN pip3 install --no-cache-dir \
    telethon \
    gitpython \
    python-decouple \
    python-dotenv \
    telegraph \
    enhancer \
    requests \
    psutil \
    aiohttp \
    redis \
    pyrogram \
    catbox-uploader \
    cloudscraper \
    pillow \
    google-api-python-client \
    opencv-python \
    numpy \
    beautifulsoup4 \
    apscheduler \
    qrcode \
    pytz \
    yt-dlp \
    selenium \
    webdriver-manager \
    lxml \
    html5lib \
    oauth2client \
    profanitydetector \
    PyPDF2 \
    twikit \
    htmlwebshot \
    akinator.py \
    youtube-search-python \
    https://github.com/New-dev0/Telethon-Patch/archive/main.zip \
    git+https://github.com/pytgcalls/pytgcalls

WORKDIR /ultroid

# Create ultroid user and configure sudo without password
RUN useradd -m -s /bin/bash ultroid && \
    usermod -aG sudo ultroid && \
    echo 'ultroid ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /ultroid /data && \
    chown -R ultroid:ultroid /ultroid && \
    chown -R ultroid:ultroid /data && \
    chmod -R 755 /data

# Clone the Ultroid repository
RUN su - ultroid -c "cd /ultroid && git clone https://github.com/TeamUltroid/Ultroid.git bot" && \
    chmod -R 755 /ultroid/bot/

# Configure Redis for persistence
RUN sed -i 's|^dir .*|dir /data/|' /etc/redis/redis.conf && \
    sed -i 's|^appendonly no|appendonly yes|' /etc/redis/redis.conf && \
    sed -i 's|^# appendonly no|appendonly yes|' /etc/redis/redis.conf && \
    sed -i 's|^# save|save|' /etc/redis/redis.conf

# Copy the initialization script and make it executable
COPY init_vars.sh /usr/local/bin/init_vars.sh
RUN chmod +x /usr/local/bin/init_vars.sh

# Switch to ultroid user
USER ultroid

# Add /home/ultroid/.local/bin to PATH
ENV PATH="/home/ultroid/.local/bin:${PATH}"

# Set the entrypoint to our custom script
CMD ["/usr/local/bin/init_vars.sh"]
