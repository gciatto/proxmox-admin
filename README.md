# Proxmox Admin

A self-contained Docker/Compose administration workstation for a **remote Proxmox VE cluster**. Inspired by [almaai-unibo/image-huawei-admin](https://github.com/almaai-unibo/image-huawei-admin): start an interactive Zsh container, mount your own SSH credentials, and run convenient administration functions.

The image includes:

- **Ansible** with `community.proxmox` for API administration and SSH-based host operations;
- **OpenTofu** with the `bpg/proxmox` provider scaffold for declarative resources;
- **Python** + Proxmoxer, exposing the `px` read-only cluster inspection CLI;
- `ssh`, `ssh-agent`, `git`, `jq`, Zsh helper functions.

## Requirements

- Docker + Docker Compose v2 on each administrator's workstation (Linux/macOS);
- network reachability to the Proxmox API (usually TCP `8006`) and to each Proxmox node over SSH (TCP `22`);
- authorized SSH keys and trusted host entries in the administrator's `~/.ssh` directory;
- an individual Proxmox API token for API-based commands; **SSH-only operation does not need the token**.

Use scoped personal accounts/tokens with permissions appropriate to each operator. SSH keys and token secrets are **never copied into the image**.

## 1. One-time workstation configuration

```bash
cp .env.example .env
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
```

Edit `.env` to set your `PROXMOX_HOST`, `PROXMOX_TOKEN_ID`, and optional TLS settings. `PROXMOX_HOST` is a hostname or IP **without** scheme/port. Edit `ansible/inventory/hosts.yml` with your real cluster nodes and SSH username.

Store your *personal API token secret* in a separate file:

```bash
mkdir -p "$HOME/.config/proxmox-admin"
chmod 700 "$HOME/.config/proxmox-admin"
printf '%s' 'YOUR-PERSONAL-API-TOKEN-SECRET' > "$HOME/.config/proxmox-admin/token"
chmod 600 "$HOME/.config/proxmox-admin/token"
```

The token ID is `user@realm!tokenname` and belongs in `.env`; the token *secret* belongs in `~/.config/proxmox-admin/token`. No token is required for SSH-only commands: leave the token file empty. Do not put secrets into tracked files.

Ensure the trusted SSH host keys are recorded in `~/.ssh/known_hosts` on the **client**. Verify each fingerprint with your cluster administrator before adding it. SSH host-key checking is enabled, including in Ansible.

For a cluster using a private CA, put the full trusted CA bundle at `config/certs/ca-bundle.pem` and set:

```dotenv
PROXMOX_CA_BUNDLE=/workspace/config/certs/ca-bundle.pem
```

The CA bundle is mounted from the local checkout into the container, not baked into the image. TLS verification remains enabled by default.

## 2. Run

If your team publishes a prebuilt image to GHCR, set `PVE_ADMIN_IMAGE` in `.env` to that image (for example, `ghcr.io/YOUR-ORG/proxmox-admin:latest`) and simply run `./admin.sh`. You can refresh the image with `./admin.sh --pull`. GitHub Actions can build and publish that image automatically (see [CI and releases](#ci-and-releases-with-github-actions)).

Alternatively, build the image locally and enter the shell:

```bash
./admin.sh --build
```

Subsequent invocations:

```bash
./admin.sh
```

Each invocation creates an ephemeral container running tools as your workstation UID/GID (the entrypoint drops root privileges). Your SSH keys are mounted read-only from `${HOME}/.ssh` at `/home/operator/.ssh`, the checkout is mounted at `/workspace`, and the token secret is mounted read-only from `~/.config/proxmox-admin/token` at `/run/secrets/proxmox-token` (outside the writable workspace).

To mount another SSH directory instead:

```bash
HOST_SSH_DIR="$HOME/.ssh-cluster" ./admin.sh
```

To use a different token-secret file, set `HOST_PROXMOX_TOKEN_FILE` to its absolute path. The launcher creates an empty token file automatically for SSH-only users.

Run commands directly without opening a shell:

```bash
./admin.sh px nodes
./admin.sh px --json guests
./admin.sh ansible-playbook ansible/playbooks/ping.yml
./admin.sh tofu -chdir=/workspace/tofu version
```

### Interactive shell functions

```zsh
pve-help                     # command reference
pve-doctor                   # validate local configuration
pve-nodes                    # list Proxmox cluster nodes (API)
pve-guests                   # list VMs and LXC containers (API)
pve-status                   # show cluster membership (API)
pve-inventory                # show Ansible host inventory
pve-ping                     # SSH connectivity test for proxmox_nodes
pve-shell pve1 'pveversion'  # run an SSH command on inventory target
pve-shell proxmox_nodes 'uptime'
pve-play node-facts          # execute an Ansible playbook (SSH)
pve-play cluster-status      # execute a Proxmox API playbook
pve-play guests              # query guest inventory via Ansible
pve-tofu init                # download provider into local plugin cache
pve-tofu plan                # show changes (initially empty)
```

The shell functions are thin conveniences; all native `ansible`, `ansible-playbook`, `tofu`, `ssh`, `python` and `px` commands work normally.

### Agent-based SSH authentication

The mounted SSH private key also works directly with SSH and Ansible. For passphrase-protected keys, or for OpenTofu provider operations that require SSH, load your key into an agent **inside the container**:

```zsh
pve-agent ~/.ssh/id_ed25519
```

`pve-agent` exports the `PROXMOX_VE_SSH_AGENT` environment variable for the OpenTofu provider. For API-token authentication with provider-side SSH, set `PROXMOX_SSH_USER` in `.env`; the provider receives `PROXMOX_VE_SSH_USERNAME`. SSH is only needed by the provider for certain resources/operations.

## Access model

| Tool | Authentication | Notes |
| --- | --- | --- |
| `ssh`, Ansible on hosts | Per-user SSH key (or SSH agent) | UNIX permissions/`sudo` control capabilities. |
| `px` and Ansible Proxmox API modules | Per-user Proxmox API token | Token permissions control operations. |
| OpenTofu bpg provider | Per-user Proxmox API token; optionally SSH | Uses `PROXMOX_VE_ENDPOINT`, `PROXMOX_VE_API_TOKEN`, optional `PROXMOX_VE_SSH_*`. |

Per-operator tokens should be scoped and revocable; if using privilege-separated tokens, both the user and token must possess the appropriate ACL privileges. Some Proxmox API actions require `root@pam` ticket authentication and cannot be done using tokens, regardless of permissions.

## Project structure

```text
.
├── admin.sh                        # portable launch wrapper
├── Dockerfile                     # Ansible + Python + OpenTofu image
├── compose.yaml                   # bind mounts, UID/GID, runtime vars
├── compose.build.yaml             # optional local image build
├── docker/                        # entrypoint + interactive Zsh functions
├── src/pxadmin/                   # Python read-only REST API CLI
├── tests/                         # CLI unit tests
├── scripts/                       # workflow checks and Docker smoke tests
├── .github/workflows/             # CI and GHCR publishing pipelines
├── ansible/
│   ├── inventory/hosts.yml.example
│   └── playbooks/               # SSH and API query examples
├── tofu/                          # bpg/proxmox provider scaffold
└── config/certs/                  # optional private CA bundle (ignored)
```

The `.env`, personal token file, local SSH keys, generated OpenTofu state, and the real inventory are ignored by Git and excluded from the Docker build context.

## Shared-state policy for OpenTofu

The included OpenTofu configuration has **no managed resources**. Do not let multiple operators independently apply the same infrastructure using separate local state files. Before adding production resources:

1. Agree which VM/CT/storage resources are OpenTofu-owned versus Ansible-owned.
2. Configure a team-accessible remote state backend with locking and backups.
3. Import existing resources into the shared state before making changes.
4. Run `pve-tofu plan` before `pve-tofu apply`.

The default `bpg/proxmox` provider version in `tofu/versions.tf` is pinned to the version current when this starter was prepared. Review Proxmox VE compatibility before upgrading it.

## CI and releases with GitHub Actions

The repository provides **two GitHub Actions workflows**, without requiring repository secrets or a Proxmox test cluster:

| Workflow | When | What it does |
| --- | --- | --- |
| `.github/workflows/ci.yml` | Pull requests, pushes to non-primary branches, manual runs; reusable from releases | Python unit tests, shell/YAML checks, and **build + smoke tests for both `linux/amd64` and `linux/arm64`**, with no credentials and no publication. |
| `.github/workflows/release.yml` | Pushes to `main`/`master`; pushes of `v*` tags | Runs the **same CI workflow first**, then builds and pushes a multi-platform image to GitHub Container Registry (`ghcr.io`). Publish is skipped if any test fails. |

The CI container smoke tests verify that the installed `px`, Ansible/Proxmox collection, OpenTofu and Zsh helpers are callable; that Ansible inventories and playbooks parse; that OpenTofu files are formatted; and that the container drops privileges to an arbitrary non-root UID/GID. **Tests do not contact your Proxmox cluster.**

### One-time GitHub repository setup

1. Push this project to a GitHub repository (e.g., `YOUR-ORG/proxmox-admin`). Enable GitHub Actions for the repository. If your organization restricts `GITHUB_TOKEN` or package publication, allow Actions to write GitHub Packages. The publishing job requests `packages: write`; **no PAT or additional release secret** is needed.
2. Use repository branch protection/rulesets for `main`/`master` and version tags, so unreviewed changes cannot be published. Require passing checks on pull requests.
3. After the first successful release, review the GHCR package's visibility and grant team access as appropriate. An administrator pulling a private image must first authenticate to GHCR (e.g., with a GitHub token with `read:packages` permission).

### Image tags

Assuming the repository is `YOUR-ORG/proxmox-admin` (names are normalized to lowercase):

| Git event | Published tags | Intended use |
| --- | --- | --- |
| Push to `main` or `master` | `ghcr.io/your-org/proxmox-admin:edge`, `:sha-<commit>` | Team testing / development. |
| Push tag `v1.2.3` | `:v1.2.3`, `:1.2.3`, `:1.2`, `:latest`, `:sha-<commit>` | Stable release. |
| Push tag `v1.3.0-rc.1` | `:v1.3.0-rc.1`, `:1.3.0-rc.1`, `:sha-<commit>` | Pre-release; never replaces `:latest`. |

Release tags follow `vMAJOR.MINOR.PATCH`, optionally with `-PRERELEASE`. Publish a stable version from a reviewed commit:

```bash
git switch main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

Once GitHub Actions has published the image, on each administrator's workstation put the following in `.env`:

```dotenv
PVE_ADMIN_IMAGE=ghcr.io/your-org/proxmox-admin:latest
```

Then run:

```bash
./admin.sh --pull          # pull the published image and open its shell
./admin.sh                 # reuse locally cached image on later runs
```

For reproducibility, you can pin a version (`:v0.1.0`) or an image digest instead of `:latest`. Images are published with an SBOM and BuildKit provenance attestations. Operator SSH keys, API token files, local inventories and OpenTofu state are explicitly excluded from the Docker build context; no Proxmox credentials are provided to CI.

### Running the checks yourself

```bash
python3 -m pip install 'PyYAML>=6,<7'  # for the workflow/YAML validator
python3 scripts/check-yaml.py
python3 -m unittest discover -s tests -v
bash -n admin.sh scripts/smoke-image.sh
sh -n docker/entrypoint.sh

docker build -t proxmox-admin:ci .
bash scripts/smoke-image.sh proxmox-admin:ci
```

The `scripts/smoke-image.sh` command requires Docker but not a Proxmox endpoint or secrets. In GitHub Actions the same checks execute for both supported architectures.

## Live cluster checks (administrator workstation)

After configuring your own SSH access and API token, validate connectivity:

```bash
./admin.sh px doctor                         # local checks only
./admin.sh ansible-inventory --graph         # inspect configured hosts
./admin.sh ansible-playbook ansible/playbooks/ping.yml  # SSH to nodes
./admin.sh px nodes                          # Proxmox API
```

The `px` CLI provides read-only inspection. Use Ansible or OpenTofu for intentional changes; unlike CI smoke tests, these checks require the configured cluster and credentials.
