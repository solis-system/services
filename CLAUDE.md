# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker service configuration generator for the Solis infrastructure. The project reads a service manifest (`manifest.yml`) and generates:
- Docker Compose files (production and development)
- Caddyfile for reverse proxy configuration
- Homepage dashboard service configuration

The generator supports automatic subdomain routing, volume management, basic authentication, and Cloudflare DNS integration.

## Core Architecture

### Configuration Flow
1. **manifest.yml** - Single source of truth defining all services with metadata (title, description, icon, group, subdomain, ports, volumes, environment, storage type, auth)
2. **main.js** - Orchestrates the generation process via ConfigGenerator class
3. **config.js** - Reads environment variables from `.env` and defines service schema validation rules
4. **functions/** - Utility modules for file I/O, YAML operations, and Caddy template generation
5. **dist/** - Generated output directory containing all runtime configuration files

### Service Definition Schema
Services in `manifest.yml` support:
- **Required**: `image` - Docker image to use
- **Optional**: `title`, `description`, `icon`, `subdomain`, `internal_port`, `ports`, `volumes`, `environment`, `labels`, `command`, `depends_on`, `storage` (internal/external), `dev_path`, `group` (for homepage grouping), `auth` (basic)

### Key Components
- **ConfigGenerator (main.js)**: Generates docker-compose.yml, docker-compose.dev.yml, Caddyfile, homepage_services.yaml, and proxy.docker-compose.yml
- **Storage Management**: Services with `storage: internal` get auto-created Docker volumes; `storage: external` expects pre-existing volumes
- **Reverse Proxy**: Caddy automatically routes `subdomain.DOMAIN` to `servicename:internal_port`; services without subdomain are skipped
- **Homepage Groups**: Services are organized into dashboard groups (1=Lolapp, 2=Outils, 3=Data) defined in config.js

## Common Commands

### Build and Start Services
```bash
# Generate config and start all services (production)
make up

# Generate config and start all services (development with live reload)
ENV=development make up

# Start all services with build flag in development
ENV=development make up

# Stop all services
make down

# Restart all services
make restart
```

### Single Service Operations
```bash
# Start specific service
make start SERVICE=servicename

# Stop specific service
make stop SERVICE=servicename

# Restart specific service
make restart_one SERVICE=servicename
```

### Configuration Generation
```bash
# Generate configuration files only (without starting containers)
make generate

# Generate for development environment
ENV=development make generate

# Or directly with bun/node
bun start
# or
node main.js
```

### Docker Operations
```bash
# List running containers
make ps

# View logs for specific service
docker compose -f dist/proxy.docker-compose.yml -f dist/docker-compose.yml logs servicename

# View logs for all services
docker compose -f dist/proxy.docker-compose.yml -f dist/docker-compose.yml logs
```

## Environment Configuration

The `.env` file must contain:
- **DOMAIN** - Base domain for all services (required)
- **ENV** - production or development (defaults to production)
- **CLOUDFLARE_API_TOKEN** - For Caddy DNS challenge
- **EMAIL** - Admin email for Let's Encrypt
- **BASIC_AUTH** - Base64 encoded credentials (admin:password format)
- **REGISTRY_URL** - Docker registry URL for custom images
- Plus service-specific environment variables referenced in manifest.yml

## Development Workflow

When adding or modifying services:
1. Update `manifest.yml` with service definition
2. Add any required environment variables to `.env`
3. Run `make generate` to validate configuration generation
4. Review generated files in `dist/` directory
5. Run `make up` or `ENV=development make up` to start services
6. For development mode, ensure service has `dev_path` pointing to local source code and a `Dockerfile-dev` in that directory

## Network Architecture

All services connect to the `proxy-network` (external Docker network that must be created manually before first run). The Caddy reverse proxy handles:
- Automatic HTTPS via Cloudflare DNS challenge
- Subdomain routing to internal services
- Optional basic authentication per service
- Gzip compression