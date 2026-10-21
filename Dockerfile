# syntax=docker/dockerfile:1
# Official OpenTofu minimal image is intended for multi-stage copying.
FROM ghcr.io/opentofu/opentofu:1-minimal AS opentofu

FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/opt/ansible/collections \
    ZDOTDIR=/opt/proxmox-admin \
    HOME=/home/operator \
    TF_PLUGIN_CACHE_DIR=/home/operator/.cache/tofu/plugins

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates openssh-client zsh git curl jq tini gosu passwd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu

WORKDIR /build
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-cache-dir 'ansible-core>=2.18,<2.21' . \
    && ansible-galaxy collection install 'community.proxmox:==2.0.0' -p /opt/ansible/collections

COPY docker/entrypoint.sh /usr/local/bin/proxmox-entrypoint
COPY docker/zshrc /opt/proxmox-admin/.zshrc
COPY docker/shell-extensions.zsh /opt/proxmox-admin/shell-extensions.zsh
RUN chmod 0755 /usr/local/bin/proxmox-entrypoint \
    && mkdir -p /home/operator/.cache/tofu/plugins /workspace \
    && chmod 0755 /home/operator

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/proxmox-entrypoint"]
CMD ["zsh", "-i"]
