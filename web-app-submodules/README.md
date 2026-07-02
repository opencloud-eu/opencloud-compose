# Web App Submodules

Build OpenCloud Web extensions from the submodules in this directory and deploy them for OpenCloud.

## How it works

```
web-extensions/packages/web-app-*/dist   →   OC_APPS_DIR/<app>/
web-app-comments/dist                    →   OC_APPS_DIR/comments/
opencloud-3dviewer/dist                  →   OC_APPS_DIR/3dviewer/
opencloud-web-calendar/dist              →   OC_APPS_DIR/web-calendar/
web-app-presentation-viewer/dist/mdpresentation-viewer/   →   OC_APPS_DIR/mdpresentation-viewer/
                                                              ↓
                                                   OpenCloud container
                                        (/var/lib/opencloud/web/assets/apps)
```

- **`OC_WEB_APPS`** selects apps from `web-extensions` when building without app arguments
- **Standalone submodules** are built on every default run; pass app names to build only selected extensions
- **Build output** stays in each submodule's `dist/` directory
- **`OC_APPS_DIR`** is the directory OpenCloud reads extensions from (default: `./config/opencloud/apps`)
- The build script **cleans** `OC_APPS_DIR` (except `.gitkeep`) and **copies** each built app into it (no symlinks)
- `docker-compose.yml` bind-mounts `OC_APPS_DIR` into the container

`OC_APPS_DIR` should **not** point into a submodule. Keep it under the repo root (e.g. `config/opencloud/apps`) or any other host path you mount into OpenCloud.

## Setup

From the repository root:

```bash
git submodule update --init --recursive
```

Docker is required on the host. The build script runs `pnpm install` and `pnpm build` inside temporary containers and removes them when finished. Most apps use [pnpm](https://pnpm.io/docker) (`ghcr.io/pnpm/pnpm:11.9.0` by default, override with `PNPM_IMAGE`); the presentation viewer uses `node:20-bookworm` by default (`PRESENTATION_IMAGE`). Node.js is installed via `pnpm runtime set` where needed (default: Node 24, override with `NODE_VERSION`).

Configure web-extensions apps in `.env` at the repository root:

```
OC_WEB_APPS=calculator,draw-io,json-viewer,notes,unzip
```

Optional apps directory (default: `./config/opencloud/apps`):

```
OC_APPS_DIR=/your/local/opencloud/apps
```

## Build

From the repository root:

```bash
./web-app-submodules/build-web-extensions.sh
```

The script reads `OC_WEB_APPS` from `.env` for the web-extensions monorepo and builds all standalone submodules when no app names are passed.

Build only selected extensions (monorepo apps or standalone repos):

```bash
./web-app-submodules/build-web-extensions.sh comments
./web-app-submodules/build-web-extensions.sh calculator draw-io
./web-app-submodules/build-web-extensions.sh --all
./web-app-submodules/build-web-extensions.sh --list
```

App names from web-extensions can use the short name (`calculator`) or `web-app-calculator`. Standalone repos accept deploy names or directory names (`comments`, `web-app-comments`, `calendar` for web-calendar).

After building, restart the OpenCloud container to load new extensions.

## Module Federation compatibility (OpenCloud 7.2.x)

External apps built with `@opencloud-eu/extension-sdk` 7.0.x can pull in Module Federation runtime **2.4.x**, which breaks other apps on OpenCloud **7.2.0** (host runtime **2.3.1**) with errors like:

`Shared module '@opencloud-eu/web-client' must be provided by host`

Pin standalone submodules to **extension-sdk 7.1.2** (same as the `web-extensions` lockfile). The build script rejects `remoteEntry*.mjs` files that use the 2.4.x `__mf_module_cache__` pattern.

## web-extensions apps

`arcade`, `calculator`, `cast`, `draw-io`, `external-sites`, `importer`, `json-viewer`, `maps`, `notes`, `pastebin`, `progress-bars`, `unzip`

## Default build (no arguments)

`comments`, `3dviewer`, `web-calendar`, `mdpresentation-viewer`, plus apps listed in `OC_WEB_APPS`

Use `--all` to build every web-extensions app as well.

For `external-sites` and `importer`, copy and customize the configuration first:

```bash
cp config/opencloud/apps.yaml.dist config/opencloud/apps.yaml
```
