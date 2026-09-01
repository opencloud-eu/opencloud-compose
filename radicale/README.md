# Radicale — CalDAV / CardDAV

This module adds [Radicale](https://radicale.org/) as a CalDAV (calendars,
to-do lists) and CardDAV (contacts) server behind the OpenCloud proxy. Every
user gets a personal calendar and address book on first access.

## Enabling

Add `radicale/radicale.yml` to your `COMPOSE_FILE`:

```
COMPOSE_FILE=docker-compose.yml:radicale/radicale.yml:traefik/opencloud.yml
```

The routes are defined in [`config/opencloud/proxy.yaml`](../config/opencloud/proxy.yaml),
which `radicale.yml` mounts into the opencloud container.

## Connecting clients

### URLs

| Service | URL |
|---|---|
| CalDAV (calendar) | `https://<your-domain>/caldav/` |
| CardDAV (contacts) | `https://<your-domain>/carddav/` |

**The trailing slash is required.** `https://<your-domain>/caldav` (without
the slash) is not routed to Radicale and returns the OpenCloud web UI instead.

Clients that implement DAV service discovery (RFC 6764) can also be pointed
at the bare domain `https://<your-domain>/` — the `/.well-known/caldav` and
`/.well-known/carddav` endpoints redirect them to the URLs above. Clients
that don't (or that get confused by the web UI at the base URL) need the full
URL including the suffix.

### Authentication: use an App Token

DAV clients authenticate with **username + App Token** — not your account
password. With the default configuration (`PROXY_ENABLE_BASIC_AUTH=false`)
the account password is rejected with `401 Unauthorized`; App Tokens work out
of the box.

Create a token either

- in the web UI under **Settings → App Tokens**, or
- on the CLI:

  ```bash
  docker compose exec opencloud opencloud auth-app create --user-name=<user> --expiration=72h
  ```

### GNOME Online Accounts

GNOME expects a directly answering DAV endpoint per account, so calendars and
contacts are added as two separate accounts:

1. **Settings → Online Accounts → Add Account → Calendar (CalDAV)**
   — URL `https://<your-domain>/caldav/`, your username, an App Token as
   password.
2. **Settings → Online Accounts → Add Account → Contacts (CardDAV)**
   — URL `https://<your-domain>/carddav/`, same credentials.

### Thunderbird

- Calendar: *New Calendar → On the Network*, URL `https://<your-domain>/caldav/`
- Address book: *New Address Book → Add CardDAV Address Book*, URL
  `https://<your-domain>/carddav/`

Use an App Token as the password in both dialogs.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `401 Unauthorized` | Account password used instead of an App Token (or the token expired). |
| `405 Method Not Allowed` / HTML response | Trailing slash missing — the request landed on the web UI, not Radicale. |
| Client says "not a (Cal)DAV server" at the base URL | The client doesn't do RFC 6764 discovery. Use the full `/caldav/` / `/carddav/` URL. |
