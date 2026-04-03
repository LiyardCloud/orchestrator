# Ecosystem Repo Guide

The ecosystem repository contains no application code. Its only responsibilities are:

- Running all services together via Docker Compose
- Managing Cloudflare Tunnel routing
- Storing infrastructure configuration and deployment scripts

Service repos are linked as **git submodules** — no Docker registry needed. Images are built directly on the RPi from source.

---

## Repository Structure

```
ecosystem/
├── docker-compose.yml         # main compose file — all services
├── docker-compose.dev.yml     # local development overrides
├── .env.example               # all required variables, no values
├── .env                       # actual secrets — never commit
├── cloudflared/
│   └── config.yml             # Cloudflare Tunnel routing config
├── services/
│   ├── dataroom/              # submodule → github.com/you/dataroom
│   └── journal/               # submodule → github.com/you/journal
├── scripts/
│   └── deploy.sh              # pull latest code and rebuild services
└── docs/
    └── services.md            # port map and service registry
```

---

## Cloudflare Tunnel Setup

### 1. Install cloudflared

Skip if already installed

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### 2. Authenticate and create tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create ecosystem
```

The command outputs a tunnel ID. Save it — you will need it in the config file.

### 3. Config file

Create `cloudflared/config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/deploy/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: dataroom.yourdomain.com
    service: http://localhost:3001
  - hostname: journal.yourdomain.com
    service: http://localhost:3002
  - service: http_status:404
```

Add DNS records for each subdomain:

```bash
cloudflared tunnel route dns ecosystem dataroom.yourdomain.com
cloudflared tunnel route dns ecosystem journal.yourdomain.com
```

### 4. Run cloudflared as a system service

Skip if already added

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

---

## Submodules Setup

### Adding a service repo as a submodule

```bash
git submodule add https://github.com/liyard-tls/dataroom services/dataroom
git commit -m "add service submodules"
```

### Cloning the ecosystem repo (first time on RPi)

```bash
git clone --recurse-submodules https://github.com/you/ecosystem
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
```

### Important rule

Never edit code inside the `services/` directories. Always work in the standalone service repo. The submodule is read-only from the ecosystem repo's perspective.

---

## Docker Compose

Services are built from local submodule source — no Docker registry required.

### docker-compose.yml

Important!
Initialy find docker-compose file in service repository. Based on this file create/edit the ecosystem docker-compose file. If service docker-compose file have container with a database ignore it, because ecosystem should have only on PostrgeSQL database.

```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      retries: 5

  dataroom:
    build:
      context: ./services/dataroom
    restart: unless-stopped
    ports:
      - "3001:3001"
    environment:
      PORT: 3001
      ENV: production
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/dataroom_db
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID}
      FIREBASE_PRIVATE_KEY: ${FIREBASE_PRIVATE_KEY}
      FIREBASE_CLIENT_EMAIL: ${FIREBASE_CLIENT_EMAIL}
    depends_on:
      postgres:
        condition: service_healthy

  # journal:
  #   build:
  #     context: ./services/journal
  #   restart: unless-stopped
  #   ports:
  #     - "3002:3002"
  #   environment:
  #     PORT: 3002
  #     ENV: production
  #     DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/journal_db
  #     FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID}
  #     FIREBASE_PRIVATE_KEY: ${FIREBASE_PRIVATE_KEY}
  #     FIREBASE_CLIENT_EMAIL: ${FIREBASE_CLIENT_EMAIL}
  #   depends_on:
  #     postgres:
  #       condition: service_healthy

volumes:
  postgres_data:
```

### docker-compose.dev.yml (local development)

```yaml
services:
  dataroom:
    environment:
      ENV: development
```

Run locally with:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

---

## Environment Variables

Important!
Initialy check a service .env.example and create/edit the ecosystem .env.example based on services ones

### .env.example

```env
# PostgreSQL
POSTGRES_USER=
POSTGRES_PASSWORD=

# Firebase (shared across all services)
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
```

### .env (on RPi only — never commit)

```bash
cp .env.example .env
nano .env
```

---

## Database Setup

PostgreSQL runs as a single container with separate databases per service.
Create databases once after first launch:

```bash
docker compose exec postgres psql -U ${POSTGRES_USER} -c "CREATE DATABASE dataroom_db;"
docker compose exec postgres psql -U ${POSTGRES_USER} -c "CREATE DATABASE journal_db;"
```

Each service runs its own migrations on startup — the ecosystem repo does not manage migrations.

---

## Deployment Script

`scripts/deploy.sh` — pull latest code from all service repos and rebuild:

```bash
#!/bin/bash
set -e

echo "Pulling latest code..."
git pull
git submodule update --remote

echo "Rebuilding and restarting services..."
docker compose up -d --build

echo "Cleaning up old images..."
docker image prune -f

echo "Done."
```

Make it executable:

```bash
chmod +x scripts/deploy.sh
```

Run a deploy:

```bash
./scripts/deploy.sh
```

`git submodule update --remote` pulls the latest `main` branch of every service repo. The ecosystem repo then commits the updated submodule references.

---

## Makefile

Create a Makefile with important commands, like up, down, restart, update and so on

---

## Service Port Registry

Defined in `docs/services.md`. Every service must register its port here to avoid conflicts.

| Service  | Port | URL                     |
| -------- | ---- | ----------------------- |
| dataroom | 3001 | dataroom.yourdomain.com |
| journal  | 3002 | journal.yourdomain.com  |

When adding a new service: pick the next available port, add it to this table, and add the routing rule to `cloudflared/config.yml`.

---

## Adding a New Service

1. Add the service repo as a submodule:
   ```bash
   git submodule add https://github.com/you/newservice services/newservice
   git commit -m "add newservice submodule"
   ```
2. Add a service block to `docker-compose.yml` (use commented journal block as template)
3. Add a new ingress rule to `cloudflared/config.yml`
4. Register the DNS route:
   ```bash
   cloudflared tunnel route dns ecosystem newservice.yourdomain.com
   ```
5. Create the database:
   ```bash
   docker compose exec postgres psql -U ${POSTGRES_USER} -c "CREATE DATABASE newservice_db;"
   ```
6. Add the port to `docs/services.md`
7. Run `./scripts/deploy.sh`

---

## First-Time Setup Checklist

- [ ] cloudflared installed, tunnel created, running as system service
- [ ] Domain added to Cloudflare, DNS records created for all subdomains
- [ ] Ecosystem repo cloned on RPi with `--recurse-submodules`
- [ ] `.env` created from `.env.example` and filled in
- [ ] `docker compose up -d` — PostgreSQL starts
- [ ] Databases created (`dataroom_db`, etc.)
- [ ] `./scripts/deploy.sh` — services built and started
- [ ] Services reachable via their subdomains
