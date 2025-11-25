# CLAUDE.md - AI Assistant Guide for OpenCloud Compose

## Project Overview

OpenCloud Compose is a Docker Compose-based deployment toolkit for [OpenCloud](https://opencloud.eu), an open-source file sync and share platform. This repository provides modular, composable configurations for deploying OpenCloud in various environments with optional integrations.

**Repository**: https://github.com/opencloud-eu/opencloud-compose
**Documentation**: https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/docker-compose-base

## Repository Structure

```
opencloud-eu-compose/
├── docker-compose.yml          # Core OpenCloud service definition
├── .env.example                # Environment variables template (copy to .env)
├── .gitignore                  # Git ignore patterns
├── README.md                   # User documentation
├── LICENSE                     # GPLv3 license
│
├── antivirus/                  # ClamAV antivirus integration
│   └── clamav.yml
│
├── certs/                      # SSL certificates directory (contents gitignored)
│   └── .gitkeep
│
├── config/                     # Configuration files
│   ├── keycloak/               # Keycloak IdP configuration
│   │   ├── clients/            # OIDC client definitions (web, desktop, mobile)
│   │   ├── themes/opencloud/   # Custom Keycloak login theme
│   │   ├── opencloud-realm.dist.json
│   │   ├── opencloud-realm-autoprovisioning.dist.json
│   │   └── docker-entrypoint-override.sh
│   ├── ldap/                   # OpenLDAP configuration
│   │   ├── ldif/               # LDAP initialization files
│   │   ├── schemas/            # Custom LDAP schemas
│   │   └── *.sh                # Entrypoint scripts
│   ├── opencloud/              # OpenCloud-specific configs
│   │   ├── apps/               # Web extension apps (mostly gitignored)
│   │   ├── banned-password-list.txt
│   │   ├── csp.yaml            # Content Security Policy
│   │   └── proxy.yaml          # Proxy routes (for Radicale)
│   ├── radicale/               # Radicale CalDAV/CardDAV config
│   └── traefik/                # Traefik dynamic configuration
│       ├── dynamic/            # Dynamic config files (gitignored)
│       └── docker-entrypoint-override.sh
│
├── external-proxy/             # Configs for use behind external reverse proxy
│   ├── collabora.yml
│   ├── collabora-exposed.yml
│   ├── keycloak.yml
│   ├── keycloak-exposed.yml
│   ├── opencloud.yml
│   └── opencloud-exposed.yml
│
├── idm/                        # Identity Management configurations
│   ├── ldap-keycloak.yml       # Keycloak + LDAP shared directory mode
│   ├── external-idp.yml        # External IdP autoprovisioning mode
│   └── external-authelia.yml   # Authelia integration
│
├── monitoring/                 # Metrics and monitoring
│   ├── monitoring.yml          # Prometheus metrics endpoints
│   └── monitoring-collaboration.yml
│
├── radicale/                   # CalDAV/CardDAV integration
│   └── radicale.yml
│
├── search/                     # Full-text search
│   └── tika.yml                # Apache Tika integration
│
├── storage/                    # Storage backends
│   └── decomposeds3.yml        # S3-compatible storage driver
│
├── testing/                    # Testing configurations
│   ├── external-keycloak.yml   # Local Keycloak for testing
│   └── ldap-manager.yml        # LDAP management tools
│
├── traefik/                    # Traefik reverse proxy configurations
│   ├── opencloud.yml           # Core Traefik + OpenCloud routing
│   ├── collabora.yml           # Collabora routing
│   └── ldap-keycloak.yml       # Keycloak routing
│
└── weboffice/                  # Office document editing
    └── collabora.yml           # Collabora Online integration
```

## Modular Docker Compose Architecture

This project uses Docker Compose's multi-file capability. Files are combined using colon-separated paths in `COMPOSE_FILE` or via `-f` flags.

### Core Compose Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | **Required**. Core OpenCloud service |
| `traefik/opencloud.yml` | Traefik reverse proxy with Let's Encrypt |
| `weboffice/collabora.yml` | Collabora Online document editing |
| `idm/ldap-keycloak.yml` | Keycloak + LDAP identity management |
| `search/tika.yml` | Apache Tika full-text search |
| `antivirus/clamav.yml` | ClamAV virus scanning |
| `radicale/radicale.yml` | CalDAV/CardDAV server |
| `monitoring/monitoring.yml` | Prometheus metrics |
| `storage/decomposeds3.yml` | S3 storage backend |

### File Naming Conventions

- `traefik/*.yml` - Traefik routing rules for services
- `external-proxy/*.yml` - Port exposure for external proxies
- `*-exposed.yml` - Variants that expose additional ports

### Common Deployment Combinations

```bash
# Minimal with Traefik
docker-compose.yml:traefik/opencloud.yml

# With Collabora
docker-compose.yml:weboffice/collabora.yml:traefik/opencloud.yml:traefik/collabora.yml

# With Keycloak/LDAP
docker-compose.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/ldap-keycloak.yml

# Full stack
docker-compose.yml:weboffice/collabora.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/collabora.yml:traefik/ldap-keycloak.yml

# Behind external proxy
docker-compose.yml:weboffice/collabora.yml:external-proxy/opencloud.yml:external-proxy/collabora.yml
```

## Environment Configuration

### Key Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_FILE` | - | Colon-separated compose files |
| `OC_DOMAIN` | `cloud.opencloud.test` | Primary OpenCloud domain |
| `INITIAL_ADMIN_PASSWORD` | **Required** | Admin password (set before first start) |
| `OC_DOCKER_IMAGE` | `opencloudeu/opencloud-rolling` | Docker image |
| `OC_DOCKER_TAG` | `latest` | Image tag |
| `INSECURE` | `true` | Skip SSL verification (for self-signed certs) |
| `TRAEFIK_SERVICES_TLS_CONFIG` | `tls.certresolver=letsencrypt` | TLS configuration |
| `KEYCLOAK_DOMAIN` | `keycloak.opencloud.test` | Keycloak domain |
| `COLLABORA_DOMAIN` | `collabora.opencloud.test` | Collabora domain |
| `WOPISERVER_DOMAIN` | `wopiserver.opencloud.test` | WOPI server domain |

### Files to Never Commit

These are gitignored for security:
- `.env` (actual environment file)
- `certs/*` (SSL certificates)
- `config/traefik/dynamic/*` (certificate configs)
- `custom/` (local overrides)

## Development Workflow

### Initial Setup

```bash
# Clone repository
git clone https://github.com/opencloud-eu/opencloud-compose.git
cd opencloud-compose

# Create environment file
cp .env.example .env

# Edit .env - set at minimum:
# - INITIAL_ADMIN_PASSWORD=your_secure_password
# - COMPOSE_FILE=docker-compose.yml:traefik/opencloud.yml

# For local development, add to /etc/hosts:
# 127.0.0.1 cloud.opencloud.test traefik.opencloud.test
```

### Running Services

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f
docker compose logs -f opencloud

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v
```

### Local SSL with mkcert

```bash
mkcert -install
mkcert -cert-file certs/opencloud.test.crt -key-file certs/opencloud.test.key "*.opencloud.test" opencloud.test
# Then set TRAEFIK_SERVICES_TLS_CONFIG="tls=true" in .env
```

## Key Conventions

### Container User/Group

Default UID:GID is `1000:1000`. Configure with:
- `OC_CONTAINER_UID_GID` for OpenCloud and data containers
- `TRAEFIK_CONTAINER_UID_GID` for Traefik

### Network

All services connect to `opencloud-net` network defined in `docker-compose.yml`.

### Volume Naming

- `opencloud-config` - OpenCloud configuration
- `opencloud-data` - OpenCloud data
- `keycloak_postgres_data` - Keycloak database
- `ldap-data`, `ldap-certs` - LDAP data and certificates
- Service-specific volumes follow `{service}-{type}` pattern

### Port Mappings (External Proxy Mode)

| Service | Port |
|---------|------|
| OpenCloud | 9200 |
| Collabora | 9980 |
| WOPI Server | 9300 |
| Keycloak | 8080 |

### Logging

Set `LOG_DRIVER` env var (default: `local`). Use `LOG_PRETTY=true` for human-readable logs.

## Common Tasks for AI Assistants

### Adding a New Service Integration

1. Create compose file in appropriate directory
2. Define service with `opencloud-net` network
3. Add environment overrides to `opencloud` service if needed
4. Create corresponding `traefik/*.yml` for routing rules
5. Create `external-proxy/*.yml` if external proxy support needed
6. Document in README.md under "Deployment Options"
7. Add relevant env vars to `.env.example` with documentation

### Modifying Environment Variables

1. Add new variables to `.env.example` with descriptive comments
2. Update compose files to reference with `${VAR_NAME:-default}`
3. Document in README.md "Configuration" section

### Updating Container Images

Image versions are controlled by env vars:
- `OC_DOCKER_TAG` - OpenCloud version
- `CLAMAV_DOCKER_TAG` - ClamAV version
- `TIKA_IMAGE` - Apache Tika image

Collabora and Keycloak versions are pinned in compose files.

### Testing Changes

1. Use local development setup with self-signed certs
2. Test compose file combinations for syntax: `docker compose config`
3. Verify service startup: `docker compose up -d && docker compose ps`
4. Check logs for errors: `docker compose logs -f`

## Important Notes

- **Admin Password**: `INITIAL_ADMIN_PASSWORD` must be set before first startup; cannot be changed via env after initialization
- **DNS**: Production deployments require proper DNS entries for all domains
- **Keycloak Modes**: Two mutually exclusive modes - autoprovisioning vs shared user directory
- **Collabora SSL**: Set `COLLABORA_SSL_ENABLE=false` when behind reverse proxy
- **Monitoring Network**: `monitoring/monitoring.yml` requires external `opencloud-net` network (create with `docker network create opencloud-net`)

## File Modification Guidelines

When modifying this repository:

1. **YAML formatting**: Use 2-space indentation, follow existing patterns
2. **Environment variables**: Always provide sensible defaults with `${VAR:-default}` syntax
3. **Documentation**: Update README.md for user-facing changes
4. **Secrets**: Never commit actual passwords, tokens, or certificates
5. **Compose syntax**: Target Docker Compose v2 format
