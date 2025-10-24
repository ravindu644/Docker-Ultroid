# Edit the paths in the file first

# Copy the service file
sudo cp /home/ravindu644/Desktop/Ultroid/ultroid_guide/ultroid-docker.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable ultroid-docker.service
sudo systemctl start ultroid-docker.service

# Check status
sudo systemctl status ultroid-docker.service

