#!/usr/bin/env bash
set -euo pipefail

SUBMODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SUBMODULES_DIR}/.." && pwd)"
WEB_EXTENSIONS_DIR="${SUBMODULES_DIR}/web-extensions"
PNPM_IMAGE="${PNPM_IMAGE:-ghcr.io/pnpm/pnpm:11.9.0}"
PRESENTATION_IMAGE="${PRESENTATION_IMAGE:-node:20-bookworm}"
NODE_VERSION="${NODE_VERSION:-24}"
PRESENTATION_VIEWER_APP="mdpresentation-viewer"

MONOREPO_APP_NAMES=(
  arcade
  calculator
  cast
  draw-io
  external-sites
  importer
  json-viewer
  maps
  notes
  pastebin
  progress-bars
  unzip
)

STANDALONE_PNPM_SUBMODULES=(
  "comments|web-app-comments"
  "3dviewer|opencloud-3dviewer"
  "web-calendar|opencloud-web-calendar"
)

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

APPS_DIR="${OC_APPS_DIR:-${ROOT_DIR}/config/opencloud/apps}"
APPS_DIR="${APPS_DIR/#\~/$HOME}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [APP ...]

Build OpenCloud web extensions and deploy them to OC_APPS_DIR (default: config/opencloud/apps).

With no APP arguments, apps from web-extensions are taken from OC_WEB_APPS in .env and all
standalone submodule extensions are built (comments, 3dviewer, web-calendar, presentation-viewer).

With APP arguments, only the listed extensions are built and deployed.

Apps from web-extensions (monorepo):
  ${MONOREPO_APP_NAMES[*]}

Standalone submodule repos (aliases in parentheses):
  comments (web-app-comments)
  3dviewer (opencloud-3dviewer)
  web-calendar (opencloud-web-calendar, calendar)
  mdpresentation-viewer (presentation-viewer, web-app-presentation-viewer)

Options:
  -a, --all       Build every web-extensions app plus all standalone extensions
  -l, --list      List available app names and exit
  -h, --help      Show this help

Examples:
  $(basename "$0")                          # OC_WEB_APPS + all standalone extensions
  $(basename "$0") comments                 # only comments
  $(basename "$0") calculator draw-io       # two monorepo apps only
  $(basename "$0") --all                    # everything
EOF
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to build web extensions in a pnpm container." >&2
  exit 1
fi

normalize_monorepo_app() {
  local app="$1"
  app="${app#web-app-}"
  echo "${app}"
}

monorepo_package_dir() {
  local app_name="$1"
  echo "${WEB_EXTENSIONS_DIR}/packages/web-app-${app_name}"
}

is_monorepo_app() {
  local app="$1"
  local candidate

  for candidate in "${MONOREPO_APP_NAMES[@]}"; do
    if [[ "${candidate}" == "${app}" ]]; then
      return 0
    fi
  done

  return 1
}

resolve_app_name() {
  local input="$1"
  local normalized alias deploy_name relative_dir

  normalized="$(normalize_monorepo_app "${input}")"
  if is_monorepo_app "${normalized}"; then
    echo "${normalized}"
    return 0
  fi

  for entry in "${STANDALONE_PNPM_SUBMODULES[@]}"; do
    deploy_name="${entry%%|*}"
    relative_dir="${entry#*|}"

    if [[ "${input}" == "${deploy_name}" || "${input}" == "${relative_dir}" ]]; then
      echo "${deploy_name}"
      return 0
    fi

    if [[ "${deploy_name}" == "web-calendar" && "${input}" == "calendar" ]]; then
      echo "${deploy_name}"
      return 0
    fi
  done

  if [[ "${input}" == "${PRESENTATION_VIEWER_APP}" \
    || "${input}" == "presentation-viewer" \
    || "${input}" == "web-app-presentation-viewer" ]]; then
    echo "${PRESENTATION_VIEWER_APP}"
    return 0
  fi

  return 1
}

list_available_apps() {
  echo "Monorepo apps (web-extensions):"
  printf '  %s\n' "${MONOREPO_APP_NAMES[@]}"
  echo
  echo "Standalone submodules:"
  for entry in "${STANDALONE_PNPM_SUBMODULES[@]}"; do
    printf '  %s (%s)\n' "${entry%%|*}" "${entry#*|}"
  done
  echo "  ${PRESENTATION_VIEWER_APP} (web-app-presentation-viewer)"
}

standalone_relative_dir() {
  local deploy_name="$1"
  local entry

  for entry in "${STANDALONE_PNPM_SUBMODULES[@]}"; do
    if [[ "${entry%%|*}" == "${deploy_name}" ]]; then
      echo "${entry#*|}"
      return 0
    fi
  done

  return 1
}

is_standalone_pnpm_app() {
  local deploy_name="$1"
  standalone_relative_dir "${deploy_name}" >/dev/null 2>&1
}

run_pnpm_build() {
  local source_dir="$1"
  local install_flags="${2:---frozen-lockfile}"

  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -e CI=true \
    -e HOME=/tmp \
    -v "${source_dir}:/work" \
    -w /work \
    "${PNPM_IMAGE}" \
    bash -c "pnpm runtime set node ${NODE_VERSION} -g && pnpm install ${install_flags} && pnpm build"
}

verify_mf_remote_entry() {
  local deploy_name="$1"
  local dist_dir="$2"
  local remote_entry

  remote_entry="$(find "${dist_dir}" -name 'remoteEntry*.mjs' -print -quit)"
  if [[ -z "${remote_entry}" ]]; then
    return 0
  fi

  if grep -q '__mf_module_cache__' "${remote_entry}"; then
    echo "Incompatible Module Federation build for ${deploy_name}: ${remote_entry} uses runtime 2.4.x." >&2
    echo "Pin @opencloud-eu/extension-sdk to 7.1.2 (same as web-extensions) and rebuild." >&2
    exit 1
  fi
}

deploy_dist() {
  local deploy_name="$1"
  local dist_dir="$2"
  local target="${APPS_DIR}/${deploy_name}"

  if [[ ! -d "${dist_dir}" ]]; then
    echo "Build output not found: ${dist_dir}" >&2
    exit 1
  fi

  echo "Deploying ${deploy_name} to ${target}..."
  mkdir -p "${target}"
  cp -a "${dist_dir}/." "${target}/"
}

clean_app_targets() {
  local deploy_name

  mkdir -p "${APPS_DIR}"
  for deploy_name in "$@"; do
    local target="${APPS_DIR}/${deploy_name}"
    if [[ -e "${target}" ]]; then
      echo "Cleaning ${target}..."
      rm -rf "${target}"
    fi
  done
}

build_monorepo_apps() {
  local app build_commands build_script

  build_commands=(
    "pnpm runtime set node ${NODE_VERSION} -g"
    "pnpm install --frozen-lockfile"
  )
  for app in "${MONOREPO_APPS[@]}"; do
    build_commands+=("pnpm --filter ./packages/web-app-${app} build")
  done

  build_script="${build_commands[0]}"
  for ((i = 1; i < ${#build_commands[@]}; i++)); do
    build_script+=" && ${build_commands[i]}"
  done

  echo "Building web-extensions apps (${#MONOREPO_APPS[@]}) in ${PNPM_IMAGE} container..."
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -e CI=true \
    -e HOME=/tmp \
    -v "${WEB_EXTENSIONS_DIR}:/work" \
    -w /work \
    "${PNPM_IMAGE}" \
    bash -c "${build_script}"
}

build_standalone_pnpm_app() {
  local deploy_name="$1"
  local relative_dir source_dir

  relative_dir="$(standalone_relative_dir "${deploy_name}")"
  source_dir="${SUBMODULES_DIR}/${relative_dir}"

  echo "Building standalone extension ${deploy_name} in ${PNPM_IMAGE} container..."
  run_pnpm_build "${source_dir}"
  verify_mf_remote_entry "${deploy_name}" "${source_dir}/dist"
}

build_presentation_viewer() {
  local presentation_build_dir

  presentation_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/presentation-viewer-build.XXXXXX")"
  trap cleanup_presentation_build_dir EXIT

  rsync -a --exclude=.git "${PRESENTATION_VIEWER_DIR}/" "${presentation_build_dir}/"

  echo "Building standalone extension ${PRESENTATION_VIEWER_APP} in ${PRESENTATION_IMAGE} container..."
  docker run --rm \
    -e CI=true \
    -e HOME=/work \
    -v "${presentation_build_dir}:/work" \
    -w /work \
    "${PRESENTATION_IMAGE}" \
    bash -c "
      set -euo pipefail
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git jq
      corepack enable
      corepack prepare pnpm@8.15.1 --activate
      jq -s '.[0] * .[1]' package-common.json package-opencloud.json \
        | jq '.devDependencies.vite = \"^8.0.0\" | .devDependencies.vitest = \"^4.0.0\" | .devDependencies[\"@opencloud-eu/extension-sdk\"] = \"7.1.2\"' \
        > package.json
      jq '.id = \"mdpresentation-viewer\"' public/manifest.json > public/manifest.json.tmp \
        && mv public/manifest.json.tmp public/manifest.json
      find . -type f \\( -name '*.ts' -o -name '*.vue' -o -name '*.prettierrc' \\) -not \\( -path './node_modules/*' -o -path './dist/*' \\) -print0 | xargs -0 sed -i 's/ownclouders/opencloud-eu/g'
      pnpm install
      pnpm build
    "

  PRESENTATION_VIEWER_DIST="${presentation_build_dir}/dist/${PRESENTATION_VIEWER_APP}"
  verify_mf_remote_entry "${PRESENTATION_VIEWER_APP}" "${PRESENTATION_VIEWER_DIST}"
}

PRESENTATION_VIEWER_DIST=""
presentation_build_dir=""

cleanup_presentation_build_dir() {
  [[ -n "${presentation_build_dir}" && -d "${presentation_build_dir}" ]] || return 0
  docker run --rm -v "${presentation_build_dir}:/work" "${PNPM_IMAGE}" rm -rf /work >/dev/null 2>&1 || true
  rmdir "${presentation_build_dir}" 2>/dev/null || true
}

SELECTED_APPS=()
BUILD_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -l | --list)
      list_available_apps
      exit 0
      ;;
    -a | --all)
      BUILD_ALL=true
      shift
      ;;
    --)
      shift
      SELECTED_APPS+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      SELECTED_APPS+=("$1")
      shift
      ;;
  esac
done

MONOREPO_APPS=()
STANDALONE_PNPM_APPS=()
BUILD_PRESENTATION=false

if [[ "${BUILD_ALL}" == true ]]; then
  MONOREPO_APPS=("${MONOREPO_APP_NAMES[@]}")
  for entry in "${STANDALONE_PNPM_SUBMODULES[@]}"; do
    STANDALONE_PNPM_APPS+=("${entry%%|*}")
  done
  BUILD_PRESENTATION=true
elif [[ ${#SELECTED_APPS[@]} -gt 0 ]]; then
  for raw_app in "${SELECTED_APPS[@]}"; do
    resolved_app=""
    if ! resolved_app="$(resolve_app_name "${raw_app}")"; then
      echo "Unknown app: ${raw_app}" >&2
      echo >&2
      list_available_apps >&2
      exit 1
    fi

    if is_monorepo_app "${resolved_app}"; then
      if [[ " ${MONOREPO_APPS[*]:-} " != *" ${resolved_app} "* ]]; then
        MONOREPO_APPS+=("${resolved_app}")
      fi
    elif is_standalone_pnpm_app "${resolved_app}"; then
      if [[ " ${STANDALONE_PNPM_APPS[*]:-} " != *" ${resolved_app} "* ]]; then
        STANDALONE_PNPM_APPS+=("${resolved_app}")
      fi
    elif [[ "${resolved_app}" == "${PRESENTATION_VIEWER_APP}" ]]; then
      BUILD_PRESENTATION=true
    fi
  done
else
  if [[ -n "${OC_WEB_APPS:-}" ]]; then
    OC_WEB_APPS="${OC_WEB_APPS//,/ }"
    for app in ${OC_WEB_APPS}; do
      [[ -n "${app}" ]] || continue
      MONOREPO_APPS+=("$(normalize_monorepo_app "${app}")")
    done
  fi

  for entry in "${STANDALONE_PNPM_SUBMODULES[@]}"; do
    STANDALONE_PNPM_APPS+=("${entry%%|*}")
  done
  BUILD_PRESENTATION=true
fi

DEPLOY_APPS=("${MONOREPO_APPS[@]}" "${STANDALONE_PNPM_APPS[@]}")
if [[ "${BUILD_PRESENTATION}" == true ]]; then
  DEPLOY_APPS+=("${PRESENTATION_VIEWER_APP}")
fi

if [[ ${#DEPLOY_APPS[@]} -eq 0 ]]; then
  echo "No apps selected to build." >&2
  echo "Set OC_WEB_APPS in .env, pass app names, or use --all." >&2
  exit 1
fi

if [[ ${#MONOREPO_APPS[@]} -gt 0 ]]; then
  if [[ ! -d "${WEB_EXTENSIONS_DIR}/packages" ]]; then
    echo "web-extensions submodule not found. Run: git submodule update --init --recursive" >&2
    exit 1
  fi

  for app in "${MONOREPO_APPS[@]}"; do
    if ! is_monorepo_app "${app}"; then
      echo "Unknown web-extensions app: ${app}" >&2
      exit 1
    fi
    if [[ ! -d "$(monorepo_package_dir "${app}")" ]]; then
      echo "Unknown web-extensions app: ${app}" >&2
      exit 1
    fi
  done
fi

for deploy_name in "${STANDALONE_PNPM_APPS[@]}"; do
  relative_dir="$(standalone_relative_dir "${deploy_name}")"
  if [[ ! -d "${SUBMODULES_DIR}/${relative_dir}" ]]; then
    echo "Standalone submodule not found: ${relative_dir}. Run: git submodule update --init --recursive" >&2
    exit 1
  fi
done

PRESENTATION_VIEWER_DIR="${SUBMODULES_DIR}/web-app-presentation-viewer"
if [[ "${BUILD_PRESENTATION}" == true && ! -d "${PRESENTATION_VIEWER_DIR}" ]]; then
  echo "Standalone submodule not found: web-app-presentation-viewer. Run: git submodule update --init --recursive" >&2
  exit 1
fi

echo "Deploy target: ${APPS_DIR} (OC_APPS_DIR)"
echo "Selected apps: ${DEPLOY_APPS[*]}"
clean_app_targets "${DEPLOY_APPS[@]}"

if [[ ${#MONOREPO_APPS[@]} -gt 0 ]]; then
  build_monorepo_apps
fi

for deploy_name in "${STANDALONE_PNPM_APPS[@]}"; do
  build_standalone_pnpm_app "${deploy_name}"
done

if [[ "${BUILD_PRESENTATION}" == true ]]; then
  build_presentation_viewer
fi

for app in "${MONOREPO_APPS[@]}"; do
  deploy_dist "${app}" "$(monorepo_package_dir "${app}")/dist"
done

for deploy_name in "${STANDALONE_PNPM_APPS[@]}"; do
  relative_dir="$(standalone_relative_dir "${deploy_name}")"
  deploy_dist "${deploy_name}" "${SUBMODULES_DIR}/${relative_dir}/dist"
done

if [[ "${BUILD_PRESENTATION}" == true ]]; then
  deploy_dist "${PRESENTATION_VIEWER_APP}" "${PRESENTATION_VIEWER_DIST}"
fi

echo "Done. Built extensions are available under ${APPS_DIR} (OC_APPS_DIR)."
