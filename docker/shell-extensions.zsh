pve-help() {
    cat <<'USAGE'
Proxmox admin commands:
  pve-help                    Show this help
  pve-doctor                  Validate local configuration (no cluster changes)
  pve-nodes                   List cluster nodes (API)
  pve-guests                  List VMs and LXC containers (API)
  pve-status                  Display cluster membership/status (API)
  pve-inventory               Display inventory hosts/groups (local)
  pve-ping [group]            Verify Ansible SSH connectivity
  pve-shell GROUP 'COMMAND'   Run command on hosts via Ansible/SSH
  pve-play NAME [args...]     Run ansible/playbooks/NAME.yml
  pve-tofu [args...]          Run OpenTofu in /workspace/tofu
  pve-agent [KEY]             Start ssh-agent and add mounted private key

Native commands also work: px, ansible, ansible-playbook, tofu, ssh, jq.
AI assistants (see AGENTS.md for their rules here): claude, codex.
USAGE
}

pve-doctor() { px doctor "$@"; }
pve-nodes() { px nodes "$@"; }
pve-guests() { px guests "$@"; }
pve-status() { px status "$@"; }
pve-inventory() { ansible-inventory --graph "$@"; }
pve-ping() { ansible "${1:-proxmox_nodes}" -m ansible.builtin.ping; }
pve-shell() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: pve-shell GROUP 'COMMAND'" >&2
        return 2
    fi
    local target=$1
    shift
    ansible "$target" -m ansible.builtin.shell -a "$*"
}
pve-play() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: pve-play NAME [args...]" >&2
        return 2
    fi
    local playbook=$1
    shift
    ansible-playbook "/workspace/ansible/playbooks/${playbook}.yml" "$@"
}
pve-tofu() { tofu -chdir=/workspace/tofu "$@"; }
pve-agent() {
    local key=${1:-$HOME/.ssh/id_ed25519}
    if [[ ! -r "$key" ]]; then
        echo "SSH private key not readable: $key" >&2
        return 2
    fi
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$key" || return $?
    export PROXMOX_VE_SSH_AGENT=true
    export PROXMOX_VE_SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
    echo 'SSH agent ready for SSH, Ansible, and OpenTofu.'
}
