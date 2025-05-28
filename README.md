# OpenCloud Compose

This repository provides Docker Compose configurations for deploying OpenCloud in various environments.

## Overview

OpenCloud Compose offers a modular approach to deploying OpenCloud with several configuration options:

- **Standard deployment** with Traefik reverse proxy and Let's Encrypt certificates
- **External proxy** support for environments with existing reverse proxies (like Nginx, Caddy, etc.)
- **Collabora Online** integration for document editing
- **Keycloak and LDAP** integration for centralized identity management

## Quick Start Guide

### Prerequisites

- Docker and Docker Compose installed
- Domain names pointing to your server (for production deployment)
- Basic understanding of Docker Compose concepts

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/opencloud-eu/opencloud-compose.git
   cd opencloud-compose
   ```

2. **Create environment file**:
   ```bash
   cp .env.example .env
   ```
   
   > **Note**: The repository includes `.env.example` as a template with default settings and documentation. Your actual `.env` file is excluded from version control (via `.gitignore`) to prevent accidentally committing sensitive information like passwords and domain-specific settings.

3. **Configure deployment options**:
   
   You can deploy using explicit `-f` flags:
   ```bash
   docker compose -f docker-compose.yml -f traefik/opencloud.yml up -d
   ```
   
   Or by uncommenting the `COMPOSE_FILE` variable in `.env`:
   ```
   COMPOSE_FILE=docker-compose.yml:traefik/opencloud.yml
   ```
   
   Then simply run:
   ```bash
   docker compose up -d
   ```

4. **Add local domains to `/etc/hosts`**:
   ```
   127.0.0.1 cloud.opencloud.test
   127.0.0.1 traefik.opencloud.test
   127.0.0.1 keycloak.opencloud.test
   ```

5. **Access OpenCloud**:
   - URL: https://cloud.opencloud.test
   - Username: `admin`
   - Password: `admin` (or as configured in `.env`)

### Production Deployment

1. **Edit the `.env` file** and configure:
   - Domain names
   - Admin password
   - SSL certificate email
   - Storage paths

2. **Configure deployment options** in `.env`:
   ```
   COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
   ```

3. **Start OpenCloud**:
   ```bash
   docker compose up -d
   ```

## Deployment Options

### With Keycloak and LDAP using a Shared User Directory

OpenCloud can be deployed with Keycloak for identity management and LDAP for the shared user directory:

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f idm/ldap-keycloak.yml -f traefik/opencloud.yml -f traefik/ldap-keycloak.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/ldap-keycloak.yml
```

Add to `/etc/hosts` for local development:
```
127.0.0.1 keycloak.opencloud.test
```

This setup includes:
- Keycloak for authentication and identity management
- Shared LDAP server as a user directory with demo users and groups
- Integration with Keycloak using OpenCloud clients (`web`, `OpenCloudDesktop`, `OpenCloudAndroid`, `OpenCloudIOS`)

### With Collabora Online

Include Collabora for document editing using either method:

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f docker-compose.collabora.yml -f traefik/opencloud.yml -f traefik/collabora.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
```

Add to `/etc/hosts` for local development:
```
127.0.0.1 collabora.opencloud.test
127.0.0.1 wopiserver.opencloud.test
```

### Behind External Proxy

If you already have a reverse proxy (Nginx, Caddy, etc.), use either method:

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f docker-compose.collabora.yml -f external-proxy/opencloud.yml -f external-proxy/collabora.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:external-proxy/opencloud.yml:external-proxy/collabora.yml
```

This exposes the necessary ports:
- OpenCloud: 9200
- Collabora: 9980
- WOPI server: 9300


**Please note:**  
If you're using **Nginx Proxy Manager (NPM)**, you **should NOT** activate **"Block Common Exploits"** for the Proxy Host.  
Otherwise, the desktop app authentication will return **error 403 Forbidden**.


## Configuration

### Environment Variables

The configuration is managed through environment variables in the `.env` file:

- We provide `.env.example` as a template with documentation for all options
- Your personal `.env` file is ignored by git to keep sensitive information private
- This pattern allows everyone to customize their deployment without affecting the repository

Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `COMPOSE_FILE` | Colon-separated list of compose files to use | (commented out) |
| `OC_DOMAIN` | OpenCloud domain | cloud.opencloud.test |
| `OC_DOCKER_TAG` | OpenCloud image tag | latest |
| `ADMIN_PASSWORD` | Admin password | admin |
| `OC_CONFIG_DIR` | Config directory path | (Docker volume) |
| `OC_DATA_DIR` | Data directory path | (Docker volume) |
| `INSECURE` | Skip certificate validation | true |
| `COLLABORA_DOMAIN` | Collabora domain | collabora.opencloud.test |
| `WOPISERVER_DOMAIN` | WOPI server domain | wopiserver.opencloud.test |
| `KEYCLOAK_DOMAIN` | Keycloak domain | keycloak.opencloud.test |
| `KEYCLOAK_ADMIN_USER` | Keycloak admin username | admin |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | admin |
| `KEYCLOAK_REALM` | Keycloak realm name | openCloud |
| `LDAP_ADMIN_PASSWORD` | LDAP admin password | admin |

See `.env.example` for all available options and their documentation.

### Persistent Storage

For production, configure persistent storage:

```
OC_CONFIG_DIR=/path/to/opencloud/config
OC_DATA_DIR=/path/to/opencloud/data
```

Ensure proper permissions:
```bash
mkdir -p /path/to/opencloud/{config,data}
chown -R 1000:1000 /path/to/opencloud
```

### Compose File Structure

This repository uses a modular approach with multiple compose files:

- `docker-compose.yml` - Core OpenCloud service
- `docker-compose.collabora.yml` - Collabora Online integration
- `idm/` - Identity management configurations (Keycloak & LDAP)
- `traefik/` - Traefik reverse proxy configurations
- `external-proxy/` - Configuration for external reverse proxies
- `config/` - Configuration files for OpenCloud, Keycloak, and LDAP

## Advanced Usage

### Understanding the COMPOSE_FILE Variable

The `COMPOSE_FILE` environment variable is a powerful way to manage complex Docker Compose deployments:

- It uses colons (`:`) as separators between files (configurable with `COMPOSE_PATH_SEPARATOR`)
- Files are processed in order, with later files overriding settings from earlier ones
- It allows you to run just `docker compose up -d` without specifying `-f` flags
- Perfect for automation, CI/CD pipelines, and consistent deployments

Example configurations:

Production with Collabora:
```
COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
```

Production with Keycloak and LDAP:
```
COMPOSE_FILE=docker-compose.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/ldap-keycloak.yml
```

Production with both Collabora and Keycloak/LDAP:
```
COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/collabora.yml:traefik/ldap-keycloak.yml
```

### Automation and GitOps

For automated deployments, using the `COMPOSE_FILE` variable in `.env` is recommended:

```
COMPOSE_FILE=docker-compose.yml:docker-compose.collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
```

This allows tools like Ansible or CI/CD pipelines to deploy the stack without modifying the compose files.

### Custom compose file overrides

You can create custom compose files to override specific settings after creating a `custom` directory:
```bash
mkdir -p custom
```

Then create a `docker-compose.override.yml` file in the `custom` directory with your overrides.

This folder is ignored by git, allowing you to customize your deployment without affecting the repository. This can be useful in scenarios like portainer where the git repository is configured as a stack.

You can for example add custom labels to the OpenCloud service:

```yaml
services:
  opencloud:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.opencloud.rule=Host(`cloud.opencloud.test`)"
      - "traefik.http.services.opencloud.loadbalancer.server.port=80"
      - "traefik.http.routers.opencloud.tls.certresolver=my-resolver"
```

## Troubleshooting

### Common Issues

- **SSL Certificate Errors**: For local development, accept self-signed certificates by visiting each domain directly in your browser.
- **Port Conflicts**: If you have services already using ports 80/443, use the external proxy configuration.
- **Permission Issues**: Ensure data and config directories have proper permissions (owned by user/group 1000).

### Logs

View logs with:
```bash
docker compose logs -f
```

For specific service logs:
```bash
docker compose logs -f opencloud
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU General Public License v3 (GPLv3).