#!/bin/sh
set -eu

# Root-owned image + arbitrary host UID is intentional. Home and mounts are
# writable by the invoking UID; no private keys or tokens are copied into image.
# Add a passwd/group entry for the invoking host UID so OpenSSH and tools work
# on both Linux and macOS; then drop root privileges before starting anything.
if [ "$(id -u)" -eq 0 ]; then
    operator_uid=${ADMIN_UID:-1000}
    operator_gid=${ADMIN_GID:-1000}
    if ! getent group "$operator_gid" >/dev/null; then
        groupadd -g "$operator_gid" operator-group
    fi
    if ! getent passwd "$operator_uid" >/dev/null; then
        useradd -M -u "$operator_uid" -g "$operator_gid" -d /home/operator -s /bin/zsh operator
    fi
    chown "$operator_uid:$operator_gid" /home/operator
    exec gosu "$operator_uid:$operator_gid" "$0" "$@"
fi

TOKEN_FILE=${PROXMOX_TOKEN_SECRET_FILE:-/run/secrets/proxmox-token}
if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    PROXMOX_TOKEN_SECRET=$(cat "$TOKEN_FILE")
    export PROXMOX_TOKEN_SECRET
fi

if [ -n "${PROXMOX_TOKEN_ID:-}" ]; then
    if [ -z "${PROXMOX_USER:-}" ]; then
        PROXMOX_USER=${PROXMOX_TOKEN_ID%%!*}
        export PROXMOX_USER
    fi
    if [ -n "${PROXMOX_TOKEN_SECRET:-}" ]; then
        PROXMOX_VE_API_TOKEN="${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}"
        export PROXMOX_VE_API_TOKEN
    fi
fi

if [ -n "${PROXMOX_HOST:-}" ]; then
    PROXMOX_VE_ENDPOINT="https://${PROXMOX_HOST}:${PROXMOX_PORT:-8006}/"
    export PROXMOX_VE_ENDPOINT
fi

if [ -n "${PROXMOX_SSH_USER:-}" ]; then
    PROXMOX_VE_SSH_USERNAME="$PROXMOX_SSH_USER"
    export PROXMOX_VE_SSH_USERNAME
fi

case "${PROXMOX_VALIDATE_CERTS:-true}" in
    0|false|FALSE|no|NO)
        export PROXMOX_VALIDATE_CERTS=false
        export PROXMOX_VE_INSECURE=true
        ;;
    *)
        export PROXMOX_VALIDATE_CERTS=true
        export PROXMOX_VE_INSECURE=false
        ;;
esac

# An optional trusted *CA bundle* works for Python requests and Go/OpenTofu.
if [ -n "${PROXMOX_CA_BUNDLE:-}" ]; then
    if [ ! -r "$PROXMOX_CA_BUNDLE" ]; then
        echo "Proxmox CA bundle not readable: $PROXMOX_CA_BUNDLE" >&2
        exit 2
    fi
    export REQUESTS_CA_BUNDLE="$PROXMOX_CA_BUNDLE"
    export SSL_CERT_FILE="$PROXMOX_CA_BUNDLE"
fi

# The cluster repository mounted at /workspace may override the image's Ansible defaults.
if [ -z "${ANSIBLE_CONFIG:-}" ]; then
    ANSIBLE_CONFIG=/opt/proxmox-admin/ansible/ansible.cfg
    [ -f /workspace/ansible/ansible.cfg ] && ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg
    export ANSIBLE_CONFIG
fi

# Ansible modules and the CLI run from the container's Python installation.
export ANSIBLE_PYTHON_INTERPRETER=/usr/local/bin/python3

exec "$@"
