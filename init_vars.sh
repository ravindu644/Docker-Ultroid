#!/bin/bash

ENV_FILE="/ultroid/bot/.env"
REDIS_CONF="/etc/redis/redis.conf"

# Check if this is the first run by looking for the .env file
if [ ! -f "$ENV_FILE" ]; then
    echo "--- First time setup ---"
    
    # --- Collect User Variables ---
    read -p "Enter your API_ID: " API_ID
    read -p "Enter your API_HASH: " API_HASH
    read -p "Create a password for Redis: " REDIS_PASSWORD
    read -p "Enter LOG_CHANNEL ID (optional, press Enter to skip): " LOG_CHANNEL
    read -p "Enter BOT_TOKEN (optional, press Enter to skip): " BOT_TOKEN
    echo ""

    # --- Handle Session String ---
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

    # --- Configure Redis ---
    echo "Configuring Redis with your password..."
    sed -i "s/^# requirepass .*/requirepass $REDIS_PASSWORD/" "$REDIS_CONF"
    # Allow Redis to run correctly inside Docker
    sed -i "s/^supervised no/supervised systemd/" "$REDIS_CONF"
    sed -i "s/^dir .*/dir \/data\//" "$REDIS_CONF"

    # --- Create .env file ---
    echo "Creating .env file with your credentials..."
    cat > "$ENV_FILE" << EOL
# Your Ultroid Configuration
API_ID=${API_ID}
API_HASH=${API_HASH}
SESSION=${SESSION}
REDIS_URI=localhost:6379
REDIS_PASSWORD=${REDIS_PASSWORD}
LOG_CHANNEL=${LOG_CHANNEL}
BOT_TOKEN=${BOT_TOKEN}
EOL
    echo "Setup complete. The bot will now start."
    sleep 2
else
    echo "Existing .env file found. Starting bot..."
fi

# --- Start Services ---
echo "Starting Redis server in the background..."
redis-server "$REDIS_CONF" --daemonize yes
sleep 2

echo "--- Starting Ultroid Bot ---"
# Execute the bot's startup script, replacing this process
cd /ultroid/bot/ && exec ./startup
