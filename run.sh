version: "3"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    network_mode: "host"
    volumes:
      - /data/movies:/media/movies
      - /data/series:/media/series
      - /opt/homeserver/config/jellyfin:/config
    restart: unless-stopped

  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    ports:
      - "4533:4533"
    environment:
      ND_SCANSCHEDULE: 1h
      ND_LOGLEVEL: info
      ND_BASEURL: ""
    volumes:
      - /data/music:/music
      - /opt/homeserver/config/navidrome:/data
    restart: unless-stopped

  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    ports:
      - "13378:80"
    volumes:
      - /data/audiobooks:/audiobooks
      - /data/books:/books # You can manage e-books here too
      - /opt/homeserver/config/audiobookshelf:/config
      - /opt/homeserver/metadata:/metadata
    restart: unless-stopped

  # Better for technical PDFs and general E-pub management
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

  # If you still want a Photo Gallery for LAN use:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    volumes:
      - /data/photos:/usr/src/app/upload
    env_file: [] # Explicitly empty to avoid errors
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