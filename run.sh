#!/bin/bash

# Exit on error
set -e

echo "Creating folder structure..."
# Centralized data folders and config directory
sudo mkdir -p /data/{books,audiobooks,music,movies,series,photos,documents,obsidian}
sudo mkdir -p /opt/homeserver/config/{jellyfin,navidrome,audiobookshelf,postgres,calibre-web,immich}

# Set ownership to the current user
sudo chown -R $USER:$USER /data
sudo chown -R $USER:$USER /opt/homeserver

echo "Setting up official Docker repository..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker, Compose Plugin, and Samba..."
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin samba

# Ensure Docker starts on boot
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER

echo "Creating docker-compose stack..."

cat <<EOF > /opt/homeserver/docker-compose.yml
version: "3.8"

services:
  # Media Server (Movies/TV)
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    network_mode: "host"
    volumes:
      - /data/movies:/media/movies
      - /data/series:/media/series
      - /opt/homeserver/config/jellyfin:/config
    restart: unless-stopped

  # Music Streaming
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    ports:
      - "4533:4533"
    environment:
      ND_SCANSCHEDULE: 1h
      ND_LOGLEVEL: info
    volumes:
      - /data/music:/music
      - /opt/homeserver/config/navidrome:/data
    restart: unless-stopped

  # Audiobooks and E-books
  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    ports:
      - "13378:80"
    volumes:
      - /data/audiobooks:/audiobooks
      - /data/books:/books
      - /opt/homeserver/config/audiobookshelf:/config
      - /opt/homeserver/metadata:/metadata
    restart: unless-stopped

  # General E-book Management (PDFs/Epubs)
  calibre-web:
    image: lscr.io/linuxserver/calibre-web:latest
    container_name: calibre-web
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Africa/Casablanca
    volumes:
      - /opt/homeserver/config/calibre-web:/config
      - /data/books:/books
    ports:
      - "8083:8083"
    restart: unless-stopped

  # Photo Gallery
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    volumes:
      - /data/photos:/usr/src/app/upload
    environment:
      - DB_HOSTNAME=immich-db
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=immich-redis
    ports:
      - "2283:2283"
    depends_on:
      - immich-db
      - immich-redis
    restart: unless-stopped

  immich-db:
    image: tensorchord/pgvecto_rs:pg14-v0.2.0
    container_name: immich-db
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_DB=immich
    volumes:
      - /opt/homeserver/config/postgres:/var/lib/postgresql/data
    restart: unless-stopped

  immich-redis:
    image: redis:6.2-alpine
    container_name: immich-redis
    restart: unless-stopped

EOF

echo "Starting services..."
cd /opt/homeserver
# Use sudo to avoid permission issues immediately after usermod
sudo docker compose up -d

echo "Configuring Samba for LAN access..."

# Append Samba configuration
sudo bash -c 'cat >> /etc/samba/smb.conf <<EOL

[HomeData]
   path = /data
   browseable = yes
   read only = no
   guest ok = yes
   force user = '$USER'
EOL'

sudo systemctl restart smbd

echo "-------------------------------------------------------"
echo "Setup complete! Access your services via your local IP:"
echo "Jellyfin:             http://SERVER_IP:8096"
echo "Navidrome:            http://SERVER_IP:4533"
echo "Audiobookshelf:       http://SERVER_IP:13378"
echo "Calibre-Web:          http://SERVER_IP:8083"
echo "Immich:               http://SERVER_IP:2283"
echo "Samba Share:          \\\\SERVER_IP\\HomeData"
echo "-------------------------------------------------------"