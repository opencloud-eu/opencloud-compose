# AGENTS.md

Compose files for running OpenCloud. Each module is one compose file, modules are combined through `COMPOSE_FILE` (see `README.md`).

## Adding a Docker image

Every new image follows one schema. Renovate detects it from the schema alone, there is no annotation and no file list to maintain.

1. Write the image line with an image and a tag variable, both with a default:

   ```yaml
   image: ${<NAME>_DOCKER_IMAGE:-<registry/image>}:${<NAME>_DOCKER_TAG:-<version>}
   ```

   `<version>` is an exact released version, usually the one `latest` points to today. An image without version tags is pinned by the digest of its multi-arch index (`docker buildx imagetools inspect <image>:latest`):

   ```yaml
   image: ${<NAME>_DOCKER_IMAGE:-<registry/image>}:${<NAME>_DOCKER_TAG:-latest@sha256:<digest>}
   ```

2. Document both variables in `.env.example`, uncommented and empty, in this wording:

   ```sh
   # Docker image to use for the <name> container. Defaults to "<registry/image>".
   <NAME>_DOCKER_IMAGE=
   # Docker tag to pull for the <name> container.
   # Defaults to the pinned version. Use git pull to update.
   <NAME>_DOCKER_TAG=
   ```

   The version number lives only in the compose file. `.env.example` and `README.md` say "pinned version", because renovate bumps the compose file and a copied number goes stale.

   `.env.example` is the reference for variables. The table in `README.md` is a selection: add a row there only when asked.

3. Check compose. Done when the pinned image is printed and there is no warning:

   ```sh
   docker compose --env-file .env.example -f docker-compose.yml -f <module>.yml config | grep image:
   ```

4. Check renovate. Done when the output shows the image with its `depName` and `currentValue`:

   ```sh
   docker run --rm -v "$PWD:/usr/src/app" -e LOG_LEVEL=debug renovate/renovate --platform=local 2>&1 \
     | grep -A3 '"depName": "<registry/image>"'
   ```

   Renovate finds files through `git ls-files`: `git add` a new compose file before the run. To see an update proposal, pin an older version for the run and widen the grep to `-A12`.

## How renovate treats images

- **Detection:** one pattern in `renovate.json` (`customManagers`) matches the schema above in every yaml file and reads name, tag and digest from the `image:` line. Images written as a fixed string (`traefik:v3.7.18`) are older and handled by renovate's `docker-compose` manager.
- **Automerge:** patch updates are merged automatically for every image. An image that needs a manual merge gets its own rule by package name, placed after the automerge rule:

  ```json
  { "matchPackageNames": ["<registry/image>"], "automerge": false }
  ```

- **Version limits:** an image that must stay on one major gets an `allowedVersions` rule by package name, like `postgres`.
- **Tag suffix variants:** a variant published as a tag suffix is a third variable appended to the tag, like `TIKA_DOCKER_VARIANT` in `search/tika.yml`. A variant published as a separate image needs nothing, the image variable selects it.
- **Stable branches:** `renovate.json` on `main` also governs `stable-*`. Check a pattern change against the `image:` lines on those branches.

## Removing or renaming a variable

Compose ignores a variable it no longer reads, so an old `.env` fails silently. Make it fail loudly: add the old name to `x-removed-variables` in the module's compose file, like `TIKA_IMAGE` in `search/tika.yml`. Compose then aborts with the message when the old variable is still set.
