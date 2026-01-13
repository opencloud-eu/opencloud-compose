# OpenCloud Compose

This repository provides Docker Compose configurations for deploying OpenCloud in various environments.

> [!IMPORTANT]
> Please use the [official docs](https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/docker-compose-base) for a **Production Deployment**.

## Overview

OpenCloud Compose offers a modular approach to deploying OpenCloud with several configuration options:

- **Standard deployment** with Traefik reverse proxy and Let's Encrypt certificates or certificates from files
- **External proxy** support for environments with existing reverse proxies (like Nginx, Caddy, etc.)
- **Collabora Online** integration for document editing
- **Keycloak and LDAP** integration for centralized identity management
- **Full text search** with Apache Tika for content extraction and metadata analysis
- **Monitoring** with metrics endpoints for observability and performance monitoring
- **Radicale** integration for Calendar and Contacts
- **ClamAV** antivirus scanning with ClamAV

## Quick Start Guide

### Prerequisites

- Docker and Docker Compose v2 installed.
- Domain names pointing to your server (for production deployment)
- Basic understanding of Docker Compose concepts

> [!IMPORTANT]
> Please use the docker installation guide from the [Official Documentation](https://docs.docker.com/engine/install/) to ensure using docker compose v2. Official linux distro package repositories might still contain docker compose v1, e.g. Debian 12 "Bookworm". Using docker compose v1 will lead to a broken docker deployment.

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

3. **Set admin password**:
   set `INITIAL_ADMIN_PASSWORD=your_secure_password` environment variable in your `.env` file
4. **Domain**:
   optionally, set `OC_DOMAIN=your-domain.com` to overwrite the default `cloud.opencloud.test`
5. **Configure deployment options**:

   You can deploy using explicit `-f` flags:
   ```bash
   docker compose -f docker-compose.yml -f traefik/opencloud.yml up -d
   ```

   Or by adding the `COMPOSE_FILE` variable in `.env`:
   ```
   COMPOSE_FILE=docker-compose.yml:traefik/opencloud.yml
   ```

   Then simply run:
   ```bash
   docker compose up -d
   ```

6. **Add local domains to `/etc/hosts`** (for local development only):
   ```
   127.0.0.1 cloud.opencloud.test
   127.0.0.1 traefik.opencloud.test
   127.0.0.1 keycloak.opencloud.test
   ```

7. **Access OpenCloud**:
   - URL: https://cloud.opencloud.test
   - Username: `admin`
   - Password: value of your `INITIAL_ADMIN_PASSWORD`

## Deployment Options

### With Keycloak and LDAP using a Shared User Directory

OpenCloud can be deployed with Keycloak for identity management and LDAP for the shared user directory:

> **DNS Requirements**: This setup requires DNS entries for both the main OpenCloud domain and the Keycloak subdomain. Configure DNS A/AAAA records for your domains (e.g., `cloud.example.com`, `keycloak.example.com`) or use a wildcard DNS entry (`*.example.com`).

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f idm/ldap-keycloak.yml -f traefik/opencloud.yml -f traefik/ldap-keycloak.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/ldap-keycloak.yml
```

> **For local development only**: Add to `/etc/hosts`:
> ```
> 127.0.0.1 keycloak.opencloud.test
> ```

This setup includes:
- Keycloak for authentication and identity management
- Shared LDAP server as a user directory with demo users and groups
- Integration with Keycloak using OpenCloud clients (`web`, `OpenCloudDesktop`, `OpenCloudAndroid`, `OpenCloudIOS`)

### With Collabora Online

Include Collabora for document editing using either method:

> **DNS Requirements**: This setup requires DNS entries for the main OpenCloud domain, Collabora subdomain, and WOPI server subdomain. Configure DNS A/AAAA records for your domains (e.g., `cloud.example.com`, `collabora.example.com`, `wopiserver.example.com`) or use a wildcard DNS entry (`*.example.com`).

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f weboffice/collabora.yml -f traefik/opencloud.yml -f traefik/collabora.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:weboffice/collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
```

> **For local development only**: Add to `/etc/hosts`:
> ```
> 127.0.0.1 collabora.opencloud.test
> 127.0.0.1 wopiserver.opencloud.test
> ```

### With Full Text Search

Enable full text search capabilities with Apache Tika using either method:

> **DNS Requirements**: This setup requires DNS entries for the main OpenCloud domain. Configure a DNS A/AAAA record for your domain (e.g., `cloud.example.com`) or use a wildcard DNS entry (`*.example.com`).

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f search/tika.yml -f traefik/opencloud.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:search/tika.yml:traefik/opencloud.yml
```

This setup includes:
- Apache Tika for text extraction and metadata analysis from various file formats
- Full text search functionality in the OpenCloud interface
- Support for documents, PDFs, images, and other file types

**Tika Image Variant:**
By default, OpenCloud Compose uses `apache/tika:latest` which provides:
- Smaller image size (~300MB vs ~1.2GB for the full variant)
- Faster container startup and deployment
- Core text extraction functionality for common document formats (PDF, Office docs, text files, etc.)

The base variant is recommended for most use cases. If you need advanced features like specialized OCR processing or specific image format support, you can override the image by setting `TIKA_IMAGE=apache/tika:latest-full` in your `.env` file.

### With Radicale

Enable CalDAV (calendars, to-do lists) and CardDAV (contacts) server.

> **DNS Requirements**: This setup requires DNS entries for the main OpenCloud domain. Configure a DNS A/AAAA record for your domain (e.g., `cloud.example.com`) or use a wildcard DNS entry (`*.example.com`).

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f radicale/radicale.yml -f traefik/opencloud.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:radicale/radicale.yml:traefik/opencloud.yml
```

This setup includes:
- Radicale as a CalDAV (calendars, to-do lists) and CardDAV (contacts) server
- Users access to a Personal Calendar and Addressbook

### With Monitoring

Enable monitoring capabilities with metrics endpoints using either method:

> **DNS Requirements**: This setup requires DNS entries for the main OpenCloud domain. Configure a DNS A/AAAA record for your domain (e.g., `cloud.example.com`) or use a wildcard DNS entry (`*.example.com`).

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f monitoring/monitoring.yml -f traefik/opencloud.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:monitoring/monitoring.yml:traefik/opencloud.yml
```

This setup includes:
- Metrics endpoints for OpenCloud proxy service (port 9205)
- Metrics endpoints for collaboration service (port 9304)
- Performance monitoring and observability data
- Prometheus-compatible metrics format

Access metrics endpoints:
- OpenCloud metrics: `http://localhost:9205/metrics`
- Collaboration metrics: `http://localhost:9304/metrics`

> **Note**: The monitoring configuration uses an external network `opencloud-net`. You need to create this network manually before starting the services:
> ```bash
> docker network create opencloud-net
> ```

### Behind External Proxy

If you already have a reverse proxy (Nginx, Caddy, etc.), use either method:

> **DNS Requirements**: When using an external proxy, you need to configure your external proxy to handle DNS and SSL termination. Ensure your DNS entries point to your external proxy server, and configure your proxy to forward requests to the exposed OpenCloud ports.

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f weboffice/collabora.yml -f external-proxy/opencloud.yml -f external-proxy/collabora.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:weboffice/collabora.yml:external-proxy/opencloud.yml:external-proxy/collabora.yml
```

This exposes the necessary ports:
- OpenCloud: 9200
- Collabora: 9980
- WOPI server: 9300

**Please note:**
If you're using **Nginx Proxy Manager (NPM)**, you **should NOT** activate **"Block Common Exploits"** for the Proxy Host.
Otherwise, the desktop app authentication will return **error 403 Forbidden**.

### ClamAV anti-virus

Enable anti-virus scans for uploaded files.

Using `-f` flags:
```bash
docker compose -f docker-compose.yml -f antivirus/clamav.yml -f traefik/opencloud.yml up -d
```

Or by setting in `.env`:
```
COMPOSE_FILE=docker-compose.yml:antivirus/clamav.yml:traefik/opencloud.yml
```

**Important:** adjust the variable in `.env` to start the antivirus service. Add additional services separated by comma, e.g. `notifications,antivirus`:
```
START_ADDITIONAL_SERVICES="antivirus"
```


## SSL Certificate Support

OpenCloud Compose supports adding SSL certificates for public domains and development environments. This feature enables you to use the "Let's Encrypt ACME challenge" to generate certificates for your public domains as well as using your own certificates.

### Use Let's Encrypt with ACME Challenge

1. **Enable Let's Encrypt**:
   - Set `TRAEFIK_LETSENCRYPT_EMAIL` to your email address for the ACME challenge
   - Set `TRAEFIK_SERVICES_TLS_CONFIG="tls.certresolver=letsencrypt"` to use Let's Encrypt (default value)

   ```bash
   # In your .env file
   TRAEFIK_LETSENCRYPT_EMAIL=devops@your-domain.tld
   TRAEFIK_SERVICES_TLS_CONFIG="tls.certresolver=letsencrypt"
   ```

### Use Certificates from the `certs/` directory

1. **Place your certificates**:
   - Copy your certificate files (`.crt`, `.pem`, `.key`) to the `certs/` directory
   - The directory structure is flexible - organize as needed for your setup

2. **Configure Traefik dynamic configuration**:
   - Place Traefik dynamic configuration files in `config/traefik/dynamic/`

   Example `config/traefik/dynamic/certs.yml`:
   ```yaml
   tls:
     certificates:
       - certFile: /certs/opencloud.test.crt
         keyFile: /certs/opencloud.test.key
         stores:
           - default
   ```

3. **Configure environment variables**:
   - Set `TRAEFIK_SERVICES_TLS_CONFIG="tls=true"` to use your local certificates
   
     ```bash
     # In your .env file
     TRAEFIK_SERVICES_TLS_CONFIG="tls=true"
     ```

The certificate directory and configuration directories are now available and automatically mounted in the containers:
- `certs/` → `/certs/` (inside the Traefik container)
- `config/traefik/dynamic/` → dynamic configuration loading

> [!TIP]
>
> **Local development or testing with mkcert**
> For local development, you can use `mkcert` to generate self-signed certificates for your local domains. This allows you to test SSL/TLS configurations without needing a public domain or Let's Encrypt. It also brings the advantage that you don't have to accept self-signed certificates in your browser all the time.
> ```bash
> # Install mkcert (if not already installed)
> # macOS: brew install mkcert
> # Linux: apt install mkcert or similar
> # Windows: choco install mkcert or download from GitHub
>   
> # Install the local CA
> mkcert -install
>   
> # Generate certificates for your local domains
> mkcert -cert-file certs/opencloud.test.crt -key-file certs/opencloud.test.key "*.opencloud.test" opencloud.test
> ```

> [!IMPORTANT]
> The contents of the `certs/` directory and configuration directories are ignored by git to prevent accidentally committing sensitive certificate files.

## Configuration

### Environment Variables

The configuration is managed through environment variables in the `.env` file:

- We provide `.env.example` as a template with documentation for all options
- Your personal `.env` file is ignored by git to keep sensitive information private
- This pattern allows everyone to customize their deployment without affecting the repository

Key variables:

| Variable                      | Description                                           | Default                      |
|-------------------------------|-------------------------------------------------------|------------------------------|
| `COMPOSE_FILE`                | Colon-separated list of compose files to use          | (commented out)              |
| `OC_DOMAIN`                   | OpenCloud domain                                      | cloud.opencloud.test         |
| `INITIAL_ADMIN_PASSWORD `     | OpenCloud password for the admin user                 | (no value)                   |
| `OC_DOCKER_TAG`               | OpenCloud image tag                                   | latest                       |
| `OC_CONFIG_DIR`               | Config directory path                                 | (Docker volume)              |
| `OC_DATA_DIR`                 | Data directory path                                   | (Docker volume)              |
| `INSECURE`                    | Skip certificate validation                           | true                         |
| `COLLABORA_DOMAIN`            | Collabora domain                                      | collabora.opencloud.test     |
| `WOPISERVER_DOMAIN`           | WOPI server domain                                    | wopiserver.opencloud.test    |
| `TIKA_IMAGE`                  | Apache Tika image tag                                 | apache/tika:slim             |
| `KEYCLOAK_DOMAIN`             | Keycloak domain                                       | keycloak.opencloud.test      |
| `KEYCLOAK_ADMIN`              | Keycloak admin username                               | kcadmin                      |
| `KEYCLOAK_ADMIN_PASSWORD`     | Keycloak admin password                               | admin                        |
| `LDAP_BIND_PASSWORD`          | LDAP password for the bind user                       | admin                        |
| `KC_DB_USERNAME`              | Database user for keycloak                            | keycloak                     |
| `KC_DB_PASSWORD`              | Database password for keycloak                        | keycloak                     |
| `TRAEFIK_LETSENCRYPT_EMAIL`   | Email Address for the Let's Encrypt ACME challenge    | example@example.org          |
| `TRAEFIK_SERVICES_TLS_CONFIG` | Tell traefik and the services which TLS config to use | tls.certresolver=letsencrypt |
| `TRAEFIK_CERTS_DIR`           | Directory for custom certificates.                    | ./certs                      |

See `.env.example` for all available options and their documentation.

### Admin Password Configuration

The `INITIAL_ADMIN_PASSWORD` environment variable is **required** for OpenCloud to work properly:

- **Only needed when using the built-in LDAP server (idm)**
- **Must be set before the first start of OpenCloud. Changes in the ENV variable after the first startup will be ignored.**
- If not set, OpenCloud will not work properly and the container will keep restarting
- After first initialization, the admin password can only be changed via:
  - OpenCloud User Settings UI
  - OpenCloud CLI

For external LDAP servers, the admin password is managed by the LDAP server itself.

**Important**: Set this variable in your `.env` file before starting OpenCloud for the first time:
```
INITIAL_ADMIN_PASSWORD=your-secure-password-here
```

For more details, see the [OpenCloud documentation](https://docs.opencloud.eu/docs/admin/resources/common-issues#-change-admin-password-set-in-env).

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
- `weboffice/` - Web office integrations (Collabora Online)
- `storage/` - Storage backend configurations (decomposeds3)
- `search/` - Search and content analysis services (Apache Tika)
- `monitoring/` - Monitoring and metrics configurations
- `idm/` - Identity management configurations (Keycloak & LDAP)
- `traefik/` - Traefik reverse proxy configurations
- `external-proxy/` - Configuration for external reverse proxies
- `radicale/` - Radicale configuration
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
COMPOSE_FILE=docker-compose.yml:weboffice/collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
```

Production with Keycloak and LDAP:
```
COMPOSE_FILE=docker-compose.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/ldap-keycloak.yml
```

Production with both Collabora and Keycloak/LDAP:
```
COMPOSE_FILE=docker-compose.yml:weboffice/collabora.yml:idm/ldap-keycloak.yml:traefik/opencloud.yml:traefik/collabora.yml:traefik/ldap-keycloak.yml
```

Production with monitoring:
```
COMPOSE_FILE=docker-compose.yml:monitoring/monitoring.yml:traefik/opencloud.yml
```

### Automation and GitOps

For automated deployments, using the `COMPOSE_FILE` variable in `.env` is recommended:

```
COMPOSE_FILE=docker-compose.yml:weboffice/collabora.yml:traefik/opencloud.yml:traefik/collabora.yml
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
