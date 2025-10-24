#!/bin/bash

# --- Configuration ---
IMAGE_NAME="ultroid-bot"
CONTAINER_NAME="my-ultroid"
CONFIG_VOLUME="ultroid_config"
REDIS_VOLUME="redis_data"

# --- Pre-flight Checks ---
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in your PATH."
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

build_image() {
    echo "--- Building Docker image: '$IMAGE_NAME' ---"
    if [ ! -f "Dockerfile" ]; then
        echo "Error: Dockerfile not found in the current directory."
        exit 1
    fi
    docker build -t "$IMAGE_NAME" .
    if [ $? -ne 0 ]; then
        echo "Error: Docker build failed."
        exit 1
    fi
    echo "--- Build complete! ---"
}

# --- Main Logic ---
case "$1" in
    build)
        build_image
        ;;

    start)
        echo "--- Starting container: '$CONTAINER_NAME' ---"
        if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
            echo "Image '$IMAGE_NAME' not found. Building it automatically..."
            build_image
        fi
        
        if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container is already running. Attaching to view logs..."
            docker logs -f "$CONTAINER_NAME"
        elif [ "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container exists but is stopped. Starting and attaching..."
            docker start -ai "$CONTAINER_NAME"
        else
            echo "Creating a new container..."
            docker run -it --name "$CONTAINER_NAME" \
                -v "${CONFIG_VOLUME}:/ultroid/bot" \
                -v "${REDIS_VOLUME}:/data" \
                "$IMAGE_NAME"
        fi
        ;;

    stop)
        echo "--- Stopping container: '$CONTAINER_NAME' ---"
        docker stop "$CONTAINER_NAME"
        echo "--- Container stopped. ---"
        ;;

    logs)
        echo "--- Tailing logs for container: '$CONTAINER_NAME' ---"
        docker logs -f "$CONTAINER_NAME"
        ;;

    shell)
        echo "--- Opening a shell in container: '$CONTAINER_NAME' ---"
        docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;

    uninstall)
        echo "--- UNINSTALLATION ---"
        read -p "WARNING: This will permanently delete the container, image, and all data. Are you sure? (y/n): " confirm
        if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
            docker stop "$CONTAINER_NAME" &>/dev/null
            docker rm "$CONTAINER_NAME" &>/dev/null
            docker rmi "$IMAGE_NAME" &>/dev/null
            docker volume rm "$CONFIG_VOLUME" &>/dev/null
            docker volume rm "$REDIS_VOLUME" &>/dev/null
            echo "--- Uninstallation complete. ---"
        else
            echo "Uninstallation cancelled."
        fi
        ;;

    *)
        usage
        ;;
esac
