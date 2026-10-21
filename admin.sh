#!/usr/bin/env bash
set -euo pipefail

# Launcher of the admin container, also shipped in the image (/opt/proxmox-admin/launcher).
# Cluster repositories run it through their admin.sh stub, which extracts it from the pinned
# image and sets PVE_WORKSPACE (the repository) and PVE_ADMIN_IMAGE. Run from this checkout,
# the workspace is the checkout itself.
launcher_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${PVE_WORKSPACE:-$launcher_dir}"

if ! command -v docker >/dev/null 2>&1; then
    echo 'Docker and Docker Compose v2 are required.' >&2
    exit 127
fi

if [[ "$(id -u)" -eq 0 ]]; then
    echo 'Run admin.sh as an unprivileged workstation user, not root.' >&2
    exit 2
fi

# One token secret per cluster, named after CLUSTER_NAME in cluster.env.
token_dir="${HOME}/.config/proxmox-admin"
if [[ -f cluster.env ]]; then
    cluster_name=$(sed -n 's/^CLUSTER_NAME=//p' cluster.env)
    if [[ ! "$cluster_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo 'Set CLUSTER_NAME in cluster.env (letters, digits, ".", "_", "-").' >&2
        exit 2
    fi
    token_dir="${token_dir}/${cluster_name}"
fi

export ADMIN_UID="$(id -u)"
export ADMIN_GID="$(id -g)"
export HOST_SSH_DIR="${HOST_SSH_DIR:-${HOME}/.ssh}"
export HOST_PROXMOX_TOKEN_FILE="${HOST_PROXMOX_TOKEN_FILE:-${token_dir}/token}"
# AI CLI configuration (read-write: logins, settings, sessions). Defaults to the user's own,
# falling back to a workspace-local directory for users without one.
if [[ -z "${HOST_CLAUDE_DIR:-}" ]]; then
    HOST_CLAUDE_DIR="${HOME}/.claude"
    [[ -d "$HOST_CLAUDE_DIR" ]] || HOST_CLAUDE_DIR="$PWD/.local/claude"
fi
if [[ -z "${HOST_CODEX_DIR:-}" ]]; then
    HOST_CODEX_DIR="${CODEX_HOME:-${HOME}/.codex}"
    [[ -d "$HOST_CODEX_DIR" ]] || HOST_CODEX_DIR="$PWD/.local/codex"
fi
export HOST_CLAUDE_DIR HOST_CODEX_DIR

if [[ ! -d "$HOST_SSH_DIR" ]]; then
    echo "SSH directory missing: $HOST_SSH_DIR" >&2
    echo 'Set HOST_SSH_DIR to a directory containing your SSH keys and known_hosts.' >&2
    exit 2
fi

umask 077
mkdir -p .local/cache/tofu/plugins "$HOST_CLAUDE_DIR" "$HOST_CODEX_DIR"
mkdir -p "$(dirname "$HOST_PROXMOX_TOKEN_FILE")"
if [[ ! -e "$HOST_PROXMOX_TOKEN_FILE" ]]; then
    : > "$HOST_PROXMOX_TOKEN_FILE"
fi
if [[ ! -f "$HOST_PROXMOX_TOKEN_FILE" ]]; then
    echo "Token file must be an ordinary file: $HOST_PROXMOX_TOKEN_FILE" >&2
    exit 2
fi

# Relative paths in the Compose files resolve against the workspace. An explicit -f disables
# the automatic compose.override.yaml, so it is added back when present.
compose=(docker compose --project-directory "$PWD" -f "$launcher_dir/compose.yaml")
[[ -f compose.override.yaml ]] && compose+=(-f compose.override.yaml)

if [[ "${1:-}" == '--build' ]]; then
    "${compose[@]}" -f compose.build.yaml build admin
    shift
elif [[ "${1:-}" == '--pull' ]]; then
    "${compose[@]}" pull admin
    shift
fi

if [[ -t 0 && -t 1 ]]; then
    exec "${compose[@]}" run --rm admin "$@"
else
    exec "${compose[@]}" run --rm -T admin "$@"
fi
