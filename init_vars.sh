#!/bin/bash

ENV_FILE="/ultroid/bot/.env"
REDIS_CONF="/etc/redis/redis.conf"

# Trap Ctrl+C and exit gracefully
trap 'echo -e "\n\nSetup cancelled by user. Exiting..."; kill $REDIS_PID 2>/dev/null; exit 130' INT TERM

# Configure Redis password from .env or setup
configure_redis() {
    local password="$1"
    echo "Configuring Redis with password..."
    sudo sed -i "s|^requirepass .*|requirepass $password|" "$REDIS_CONF"
    sudo sed -i "s|^# requirepass .*|requirepass $password|" "$REDIS_CONF"
}

# First time setup
if [ ! -f "$ENV_FILE" ]; then
    echo "--- First time setup ---"
    echo "(Press Ctrl+C at any time to cancel)"
    echo ""
    
    # Collect User Variables
    read -p "Enter your API_ID: " API_ID
    read -p "Enter your API_HASH: " API_HASH
    read -p "Create a password for Redis: " REDIS_PASSWORD
    read -p "Enter LOG_CHANNEL ID (optional, press Enter to skip): " LOG_CHANNEL
    read -p "Enter BOT_TOKEN (optional, press Enter to skip): " BOT_TOKEN
    
    # Trim whitespace from optional fields
    LOG_CHANNEL=$(echo "$LOG_CHANNEL" | xargs)
    BOT_TOKEN=$(echo "$BOT_TOKEN" | xargs)
    
    echo ""

    # Handle Session String
    read -p "Do you already have a session string? (y/N): " has_session
    if [[ "$has_session" == [yY] ]]; then
        read -p "Please paste your existing SESSION string: " SESSION
    else
        echo ""
        echo "--- Generating a new Session String ---"
        python3 /ultroid/bot/resources/session/ssgen.py
        echo "-----------------------------------"
        echo "IMPORTANT: A session string was generated above."
        echo "Please copy it carefully and save it somewhere safe."
        echo ""
        read -p "Now, paste the SESSION string here to continue: " SESSION
    fi

    # Configure Redis
    configure_redis "$REDIS_PASSWORD"

    # Create .env file
    echo "Creating .env file with your credentials..."
    cat > "$ENV_FILE" << EOL
# Your Ultroid Configuration
API_ID=${API_ID}
API_HASH=${API_HASH}
SESSION=${SESSION}
REDIS_URI=localhost:6379
REDIS_PASSWORD=${REDIS_PASSWORD}
EOL

    # Append optional fields only if provided
    [ -n "$LOG_CHANNEL" ] && echo "LOG_CHANNEL=${LOG_CHANNEL}" >> "$ENV_FILE"
    [ -n "$BOT_TOKEN" ] && echo "BOT_TOKEN=${BOT_TOKEN}" >> "$ENV_FILE"

    echo "Setup complete. The bot will now start."
    sleep 2
else
    echo "Existing .env file found. Starting bot..."
    
    # Load Redis password from .env and configure
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        [ -n "$REDIS_PASSWORD" ] && configure_redis "$REDIS_PASSWORD"
    fi
fi

# Start Redis server
echo "Starting Redis server..."
sudo redis-server "$REDIS_CONF" --daemonize yes
sleep 2

# Store Redis PID for cleanup
REDIS_PID=$(pgrep redis-server)

# Cleanup function on exit
cleanup() {
    echo "Shutting down services..."
    sudo redis-cli -a "$REDIS_PASSWORD" shutdown save 2>/dev/null || sudo killall redis-server 2>/dev/null
    exit 0
}

trap cleanup EXIT

echo "--- Starting Ultroid Bot ---"
# Execute the bot's startup script
cd /ultroid/bot/ && exec ./startup
