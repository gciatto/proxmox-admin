# syntax=docker/dockerfile:1
# Official OpenTofu minimal image is intended for multi-stage copying.
FROM ghcr.io/opentofu/opentofu:1-minimal AS opentofu
# Node runtime for the AI coding CLIs (Claude Code requires Node >= 22).
FROM node:24-bookworm-slim AS node

FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ANSIBLE_COLLECTIONS_PATH=/opt/ansible/collections \
    ZDOTDIR=/opt/proxmox-admin \
    HOME=/home/operator \
    TF_PLUGIN_CACHE_DIR=/home/operator/.cache/tofu/plugins \
    CLAUDE_CONFIG_DIR=/home/operator/.claude \
    CODEX_HOME=/home/operator/.codex \
    DISABLE_AUTOUPDATER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates openssh-client zsh zsh-autosuggestions zsh-syntax-highlighting git curl jq ripgrep tini gosu passwd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm

# Versions are kept up to date by Renovate (customManagers:dockerfileVersions).
# renovate: datasource=galaxy-collection depName=community.proxmox
ARG COMMUNITY_PROXMOX_VERSION=2.1.0
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.310
# renovate: datasource=npm depName=@openai/codex
ARG CODEX_VERSION=0.163.0

RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && npm install -g --no-fund --no-audit \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force

WORKDIR /build
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-cache-dir 'ansible-core>=2.18,<2.21' 'passlib>=1.7,<2' . \
    && ansible-galaxy collection install "community.proxmox:==${COMMUNITY_PROXMOX_VERSION}" -p /opt/ansible/collections

COPY docker/entrypoint.sh /usr/local/bin/proxmox-entrypoint
COPY docker/pve-validate /usr/local/bin/pve-validate
COPY docker/zshrc /opt/proxmox-admin/.zshrc
COPY docker/shell-extensions.zsh /opt/proxmox-admin/shell-extensions.zsh
# Launcher, extracted and run on the host by cluster repositories' admin.sh stub.
COPY admin.sh compose.yaml /opt/proxmox-admin/launcher/
# Defaults for cluster repositories mounted at /workspace, which may override them.
COPY ansible/ansible.cfg /opt/proxmox-admin/ansible/ansible.cfg
COPY ansible/playbooks /opt/proxmox-admin/ansible/playbooks
# Build-time leftovers in HOME are root-owned and would not be writable by the operator UID.
RUN chmod 0755 /usr/local/bin/proxmox-entrypoint /usr/local/bin/pve-validate \
    && rm -rf /home/operator/.ansible /home/operator/.npm \
    && mkdir -p /home/operator/.cache/tofu/plugins /workspace \
    && chmod 0755 /home/operator

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/proxmox-entrypoint"]
CMD ["zsh", "-i"]
