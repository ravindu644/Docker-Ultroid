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
    python3-pip && \
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
    aiohttp \
    pyrogram \
    catbox-uploader \
    cloudscraper \
    https://github.com/New-dev0/Telethon-Patch/archive/main.zip \
    git+https://github.com/pytgcalls/pytgcalls

WORKDIR /ultroid

# Clone the Ultroid repository and make startup script executable
RUN git clone https://github.com/TeamUltroid/Ultroid.git bot
RUN chmod -R 755 /ultroid/bot/

# Copy the initialization script and make it executable
COPY init_vars.sh /usr/local/bin/init_vars.sh
RUN chmod +x /usr/local/bin/init_vars.sh

# Set the entrypoint to our custom script
CMD ["/usr/local/bin/init_vars.sh"]
