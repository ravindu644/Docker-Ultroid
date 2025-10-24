#!/bin/bash

# --- Configuration ---
IMAGE_NAME="ultroid-bot"
CONTAINER_NAME="my-ultroid"
CONFIG_VOLUME="ultroid_config"
REDIS_VOLUME="redis_data"
COMPRESSED_IMAGE="ultroid-bot.tar.xz"
INSTALL_MARKER=".installed"

# --- Colors for output ---
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# --- Pre-flight Checks ---
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in your PATH.${RESET}"
    echo "Please install Docker to use this script: https://docs.docker.com/get-docker/"
    exit 1
fi

# --- Helper Functions ---
usage() {
    echo "Usage: $0 {build|start|stop|logs|shell|uninstall}"
    echo "Commands:"
    echo "  build      - Builds (or rebuilds) the Docker image."
    echo "  start      - Builds if needed, then starts the bot container."
    echo "  stop       - Stops the running container."
    echo "  logs       - View the live logs of the bot."
    echo "  shell      - Open an interactive shell inside the running container."
    echo "  uninstall  - DESTRUCTIVE. Removes container, image, and all data."
    exit 1
}

load_compressed_image() {
    if [ -f "$COMPRESSED_IMAGE" ]; then
        echo -e "${GREEN}Found compressed image. Loading...${RESET}"
        if xz -d -c "$COMPRESSED_IMAGE" | docker load; then
            echo -e "${GREEN}Image loaded successfully!${RESET}"
            return 0
        else
            echo -e "${RED}Failed to load compressed image.${RESET}"
            return 1
        fi
    fi
    return 1
}

build_image() {
    echo "--- Building Docker image: '$IMAGE_NAME' ---"
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found in the current directory.${RESET}"
        exit 1
    fi
    
    if docker build -t "$IMAGE_NAME" .; then
        echo -e "${GREEN}Build complete!${RESET}"
        return 0
    else
        echo -e "${RED}Error: Docker build failed.${RESET}"
        exit 1
    fi
}

ensure_image_exists() {
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        return 0
    fi
    
    echo "Image '$IMAGE_NAME' not found."
    
    if [ -f "$INSTALL_MARKER" ]; then
        echo -e "${YELLOW}Installation marker exists but image is missing. Rebuilding...${RESET}"
        rm -f "$INSTALL_MARKER"
    fi
    
    if ! load_compressed_image; then
        echo "Building from Dockerfile..."
        build_image
    fi
    
    touch "$INSTALL_MARKER"
}

# --- Main Logic ---
case "$1" in
    build)
        echo -e "${YELLOW}Removing previous installation...${RESET}"
        docker stop "$CONTAINER_NAME" &>/dev/null
        docker rm "$CONTAINER_NAME" &>/dev/null
        docker rmi "$IMAGE_NAME" &>/dev/null
        rm -f "$INSTALL_MARKER"

        # Try loading compressed image first
        if ! load_compressed_image; then
            build_image
        fi
        
        touch "$INSTALL_MARKER"
        echo -e "${GREEN}Image ready to use!${RESET}"
        ;;

    start)
        echo "--- Starting container: '$CONTAINER_NAME' ---"
        ensure_image_exists

        # Set up signal handling for Ctrl+C
        trap 'echo -e "\n${YELLOW}Stopping container...${RESET}"; docker stop "$CONTAINER_NAME" &>/dev/null; exit 0' INT TERM

        if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container is already running. Attaching to view logs..."
            echo -e "${YELLOW}Press Ctrl+C to detach from logs (container will keep running)${RESET}"
            docker logs -f "$CONTAINER_NAME"
        elif [ "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container exists but is stopped. Starting and attaching..."
            echo -e "${YELLOW}Press Ctrl+C to stop the container${RESET}"
            docker start -ai "$CONTAINER_NAME"
        else
            echo "Creating a new container..."
            echo -e "${YELLOW}Press Ctrl+C to stop the container${RESET}"
            docker run -it --name "$CONTAINER_NAME" \
                -v "${CONFIG_VOLUME}:/ultroid/bot" \
                -v "${REDIS_VOLUME}:/data" \
                "$IMAGE_NAME"
        fi
        ;;

    stop)
        echo "--- Stopping container: '$CONTAINER_NAME' ---"
        if docker stop "$CONTAINER_NAME" 2>/dev/null; then
            echo -e "${GREEN}Container stopped.${RESET}"
        else
            echo -e "${YELLOW}Container is not running.${RESET}"
        fi
        ;;

    logs)
        echo "--- Tailing logs for container: '$CONTAINER_NAME' ---"
        if docker ps -q -f name=^/${CONTAINER_NAME}$ &> /dev/null && [ -n "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            docker logs -f "$CONTAINER_NAME"
        else
            echo -e "${YELLOW}Container is not running.${RESET}"
            echo "Showing last logs from stopped container:"
            docker logs "$CONTAINER_NAME" 2>/dev/null || echo -e "${RED}No logs available.${RESET}"
        fi
        ;;

    shell)
        echo "--- Opening a shell in container: '$CONTAINER_NAME' ---"
        ensure_image_exists
        
        if docker ps -q -f name=^/${CONTAINER_NAME}$ &> /dev/null && [ -n "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            # Container is running, exec into it
            docker exec -it "$CONTAINER_NAME" /bin/bash -c "cd /ultroid/bot && exec /bin/bash --login"
        else
            echo -e "${YELLOW}Container is not running. Starting temporary shell-only container...${RESET}"
            docker rm "$CONTAINER_NAME" &>/dev/null
            docker run -it --rm --name "$CONTAINER_NAME" \
                -v "${CONFIG_VOLUME}:/ultroid/bot" \
                -v "${REDIS_VOLUME}:/data" \
                "$IMAGE_NAME" /bin/bash -c "cd /ultroid/bot && exec /bin/bash --login"
        fi
        ;;

    uninstall)
        echo "--- UNINSTALLATION ---"
        read -p "WARNING: This will permanently delete the container, image, and all data. Are you sure? (y/n): " confirm
        if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
            echo "Stopping and removing container..."
            docker stop "$CONTAINER_NAME" &>/dev/null
            docker rm -f "$CONTAINER_NAME" &>/dev/null
            echo "Removing image..."
            docker rmi -f "$IMAGE_NAME" &>/dev/null
            echo "Removing volumes..."
            docker volume rm "$CONFIG_VOLUME" "$REDIS_VOLUME" &>/dev/null
            echo "Cleaning up installation marker..."
            rm -f "$INSTALL_MARKER"
            echo -e "${GREEN}Uninstallation complete.${RESET}"
        else
            echo "Uninstallation cancelled."
        fi
        ;;

    *)
        usage
        ;;
esac
