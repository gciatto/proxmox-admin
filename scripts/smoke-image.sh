#!/usr/bin/env bash
set -euo pipefail

# Run against the locally built image. No Proxmox access or operator secrets.
image=${1:?Usage: scripts/smoke-image.sh IMAGE[:TAG]}
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# The UID/GID is intentionally absent from the image: exercise privilege drop.
docker run --rm \
  --env ADMIN_UID=23456 \
  --env ADMIN_GID=23456 \
  --volume "$repo_dir:/workspace:ro" \
  "$image" \
  bash -euc '
    test "$(id -u)" -eq 23456
    test "$(id -g)" -eq 23456
    test "$HOME" = /home/operator

    px --help >/dev/null
    python -m unittest discover -s /workspace/tests -v

    ansible --version
    ansible-galaxy collection list community.proxmox
    ansible-inventory -i /workspace/ansible/inventory/hosts.yml.example --list >/dev/null
    for playbook in /workspace/ansible/playbooks/*.yml; do
      ansible-playbook -i /workspace/ansible/inventory/hosts.yml.example \
        --syntax-check "$playbook"
    done

    tofu version
    claude --version
    codex --version
    tofu -chdir=/workspace/tofu fmt -check -recursive

    zsh -fc "source /opt/proxmox-admin/.zshrc && pve-help" >/dev/null
    pve-validate
  '

# A cluster repository without its own Ansible config or playbooks uses the image's defaults.
empty=$(mktemp -d)
docker run --rm \
  --env ADMIN_UID=23456 \
  --env ADMIN_GID=23456 \
  --volume "$empty:/workspace:ro" \
  "$image" \
  zsh -fc '
    test "$ANSIBLE_CONFIG" = /opt/proxmox-admin/ansible/ansible.cfg
    source /opt/proxmox-admin/.zshrc >/dev/null
    pve-play ping -i localhost, --syntax-check >/dev/null
  '
rmdir "$empty"

# Test the exact operator entrypoint too: Compose and the wrapper must work
# with an empty token file and an isolated (non-sensitive) SSH mount.
if [[ "$(id -u)" -ne 0 ]]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/ssh" "$tmp/claude" "$tmp/codex"
  : > "$tmp/token"
  (
    cd "$repo_dir"
    HOST_SSH_DIR="$tmp/ssh" \
    HOST_PROXMOX_TOKEN_FILE="$tmp/token" \
    HOST_CLAUDE_DIR="$tmp/claude" \
    HOST_CODEX_DIR="$tmp/codex" \
    PVE_ADMIN_IMAGE="$image" \
      ./admin.sh px --help >/dev/null
  )
fi
