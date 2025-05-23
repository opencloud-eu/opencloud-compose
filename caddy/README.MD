Here you find two files:
# docker-compose.caddy.yml 
# Caddyfile
After you copied .env.example to .env please add :caddy/docker-compose.caddy.yml as last entry.
This will install a caddy reverse proxy server along with your OpenCloud deployment.
As Caddy needs a config file copy the one from /caddy/Caddyfile to your directory.
Fill your API-Key and ACME Email adress.
