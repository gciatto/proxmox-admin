# Proxmox Admin

A self-contained Docker administration workstation for **remote Proxmox VE clusters**. Inspired by [almaai-unibo/image-huawei-admin](https://github.com/almaai-unibo/image-huawei-admin): start an interactive Zsh container, mount your own SSH credentials, and run convenient administration functions.

The image includes:

- **Ansible** with `community.proxmox` for API administration and SSH-based host operations;
- **OpenTofu** with the `bpg/proxmox` provider for declarative resources;
- **Python** + Proxmoxer, exposing the `px` read-only cluster inspection CLI;
- **Claude Code** (`claude`) and **Codex** (`codex`), to operate the cluster with AI assistance;
- `ssh`, `ssh-agent`, `git`, `jq`, `ripgrep`, Zsh helper functions, built-in playbooks.

## How it is used: one configuration repository per cluster

This repository is the **tool**: it builds, tests and releases the image to GHCR. Each cluster gets its own **configuration repository**, created from [template-proxmox-cluster](https://github.com/gciatto/template-proxmox-cluster) and shared by that cluster's administrators. It holds the shared settings (`cluster.env`), inventory, playbooks, OpenTofu resources, CA bundle and the rules for AI agents, and pins an image version in `cluster.env` (upgraded by Renovate). Its `admin.sh` is a stub: the launcher (`admin.sh` + `compose.yaml` of this repository) ships in the image, under `/opt/proxmox-admin/launcher/`, and the stub extracts it from the pinned image and runs it with `PVE_WORKSPACE` set to the cluster repository. One launcher, always matching the image version. Personal secrets stay on each workstation. **Start there** to administer a cluster.

### Requirements

- Docker + Docker Compose v2 on each administrator's workstation (Linux/macOS);
- network reachability to the Proxmox API (usually TCP `8006`) and to each Proxmox node over SSH (TCP `22`);
- authorized SSH keys and trusted host entries in the administrator's `~/.ssh` directory (SSH host-key checking is enabled, including in Ansible);
- an individual Proxmox API token for API-based commands; **SSH-only operation does not need the token**.

Use scoped personal accounts/tokens with permissions appropriate to each operator. SSH keys and token secrets are **never copied into the image**.

### Image contract

The launcher (`admin.sh` + `compose.yaml`) runs an ephemeral container as the workstation's UID/GID (the entrypoint drops root privileges), with:

| Mount | Container path | Notes |
| --- | --- | --- |
| `PVE_WORKSPACE`: cluster repository (default: this checkout) | `/workspace` | Read-write; `cluster.env` and `.env` there are loaded into the container. |
| `HOST_SSH_DIR` (default `~/.ssh`) | `/home/operator/.ssh` | Read-only. |
| `HOST_PROXMOX_TOKEN_FILE` | `/run/secrets/proxmox-token` | Read-only; empty for SSH-only use. |
| `HOST_CLAUDE_DIR`, `HOST_CODEX_DIR` | `/home/operator/.claude`, `/home/operator/.codex` | See [AI assistants](#ai-assistants-claude-code-codex). |

From `/workspace`, the image uses `ansible/inventory/hosts.yml`, `ansible/playbooks/*.yml` (`pve-play NAME` falls back to the built-in `ping`, `node-facts`, `cluster-status`, `guests`), `ansible/ansible.cfg` if present (otherwise the built-in one), `tofu/`, and the CA bundle named by `PROXMOX_CA_BUNDLE`. Environment: `PROXMOX_HOST` (no scheme/port), `PROXMOX_PORT`, `PROXMOX_VALIDATE_CERTS`, `PROXMOX_CA_BUNDLE`, `PROXMOX_TOKEN_ID` (`user@realm!tokenname`), `PROXMOX_USER`, `PROXMOX_SSH_USER`. `pve-validate` checks a mounted repository offline (inventory, playbook syntax, OpenTofu formatting); cluster repositories run it in CI and in a pre-commit hook.

### Trying the image from this checkout

This repository has its own launcher, for development: it mounts this checkout at `/workspace`.

```bash
cp .env.example .env                                            # endpoint, token ID, TLS
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
mkdir -p ~/.config/proxmox-admin && chmod 700 ~/.config/proxmox-admin
printf '%s' 'YOUR-PERSONAL-API-TOKEN-SECRET' > ~/.config/proxmox-admin/token
chmod 600 ~/.config/proxmox-admin/token
./admin.sh --build          # build the image locally and open its shell
./admin.sh                  # later runs; or set PVE_ADMIN_IMAGE in .env and use --pull
./admin.sh px nodes         # one-off commands
```

`HOST_SSH_DIR`, `HOST_PROXMOX_TOKEN_FILE`, `HOST_CLAUDE_DIR` and `HOST_CODEX_DIR` override the mounted paths.

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
pve-validate                 # offline checks of the mounted repository
claude                       # Claude Code, see "AI assistants" below
codex                        # Codex CLI
```

The shell functions are thin conveniences; all native `ansible`, `ansible-playbook`, `tofu`, `ssh`, `python` and `px` commands work normally.

### Agent-based SSH authentication

The mounted SSH private key also works directly with SSH and Ansible. For passphrase-protected keys, or for OpenTofu provider operations that require SSH, load your key into an agent **inside the container**:

```zsh
pve-agent ~/.ssh/id_ed25519
```

`pve-agent` exports the `PROXMOX_VE_SSH_AGENT` environment variable for the OpenTofu provider. For API-token authentication with provider-side SSH, set `PROXMOX_SSH_USER` in `.env`; the provider receives `PROXMOX_VE_SSH_USERNAME`. SSH is only needed by the provider for certain resources/operations.

### AI assistants (Claude Code, Codex)

Inside the container, `claude` and `codex` run in `/workspace` with the same tools and credentials as you. They read the cluster repository's `AGENTS.md` (Claude through the `CLAUDE.md` link), which tells them to inspect read-only first and to **ask before any change** to the cluster. They still act with *your* SSH keys and API token: review what they propose before approving it, and prefer a scoped token over an all-powerful one.

`admin.sh` bind-mounts your own configuration, read-write, so settings, logins and session history are shared with your workstation:

| Host (default) | Container | Override with |
| --- | --- | --- |
| `~/.claude` | `/home/operator/.claude` (`CLAUDE_CONFIG_DIR`) | `HOST_CLAUDE_DIR` |
| `~/.codex` (or `$CODEX_HOME`) | `/home/operator/.codex` (`CODEX_HOME`) | `HOST_CODEX_DIR` |

If a directory does not exist, a checkout-local one under `.local/` (ignored by Git) is used instead; set the variable to such a directory to keep your personal configuration out of the container (e.g. `HOST_CLAUDE_DIR="$PWD/.local/claude" ./admin.sh`).

Authentication, either:

- log in once inside the container (`claude` → `/login`, `codex login --device-auth`); the login is saved in the mounted directory. On macOS, Claude Code keeps workstation logins in the Keychain, which the container cannot read, so a first login inside the container is needed (it is stored in `~/.claude/.credentials.json`);
- or export `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `OPENAI_API_KEY` in the shell running `./admin.sh`: they are passed through only when set.

Claude Code's global settings file lives inside the mounted directory (`~/.claude/.claude.json`), not in the host's `~/.claude.json`, so first-run preferences are asked once. The CLIs are pinned in the image (auto-update is disabled) and updated through Renovate.

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
├── AGENTS.md (CLAUDE.md)          # rules for AI agents developing this repository
├── src/pxadmin/                   # Python read-only REST API CLI
├── tests/                         # CLI unit tests
├── scripts/                       # checks, Git hooks, smoke and release scripts
├── .github/workflows/             # CI and release (GitHub + GHCR) pipelines
├── uv.lock                        # locked Python (dev) dependencies, managed by uv
├── package.json                   # semantic-release (Node) dependencies
├── release.config.mjs             # semantic-release configuration
├── renovate.json                  # Renovate dependency updates
├── CHANGELOG.md                   # generated by semantic-release
├── ansible/
│   ├── ansible.cfg                # built into the image as the default configuration
│   ├── inventory/hosts.yml.example
│   └── playbooks/                 # built-in SSH and API query playbooks
├── tofu/                          # bpg/proxmox provider scaffold (smoke-test fixture)
└── config/certs/                  # optional private CA bundle for local trials (ignored)
```

The `.env`, personal token file, local SSH keys, generated OpenTofu state, and the real inventory are ignored by Git and excluded from the Docker build context.

## OpenTofu

OpenTofu resources belong to cluster repositories, which must configure a shared remote state backend before adding any: see [template-proxmox-cluster](https://github.com/gciatto/template-proxmox-cluster). The `tofu/` scaffold here only exercises the tooling.

## CI and releases with GitHub Actions

| Workflow | When | What it does |
| --- | --- | --- |
| `.github/workflows/ci.yml` | Pull requests, pushes to non-primary branches, manual runs; reused by releases | Python unit tests, shell/YAML checks, and **build + smoke tests for both `linux/amd64` and `linux/arm64`**, with no credentials and no publication. |
| `.github/workflows/release.yml` | Pushes to `main`/`master`, manual runs | Runs the **same CI workflow first**, then [semantic-release](https://semantic-release.gitbook.io/): computes the next version from the commit messages, pushes the multi-platform image to GitHub Container Registry (`ghcr.io`), then commits `CHANGELOG.md`/`pyproject.toml`/`uv.lock`, tags the release and creates a **GitHub release**. Nothing is released if a test or the image push fails. |

The CI container smoke tests verify that the installed `px`, Ansible/Proxmox collection, OpenTofu and Zsh helpers are callable; that Ansible inventories and playbooks parse; that OpenTofu files are formatted; and that the container drops privileges to an arbitrary non-root UID/GID. **Tests do not contact your Proxmox cluster.**

### Versioning

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/): they decide whether a push to `main` releases, and which version it gets. `feat` releases a minor version, `fix`, `docs`, `revert` and `chore(core-deps)` a patch, and `!` (e.g. `feat!:`) a major one; other types (`chore`, `ci`, `test`, ...) release nothing. Tags are plain versions (`1.2.3`, no `v` prefix) and are created by semantic-release only: never tag or bump the version by hand. `CHANGELOG.md` is generated.

### One-time GitHub repository setup

1. Push this project to a GitHub repository (e.g., `YOUR-ORG/proxmox-admin`) and enable GitHub Actions. If your organization restricts `GITHUB_TOKEN` or package publication, allow Actions to write GitHub Packages.
2. Use branch protection/rulesets for `main`/`master`, requiring passing checks on pull requests. semantic-release pushes a release commit to that branch: if protection forbids it for `GITHUB_TOKEN`, add a `RELEASE_TOKEN` repository secret (a token allowed to push to the branch and create releases). Without it, `GITHUB_TOKEN` is used.
3. After the first release, review the GHCR package's visibility and grant team access as appropriate. An administrator pulling a private image must first authenticate to GHCR (e.g., with a GitHub token with `read:packages` permission).

### Image tags

Assuming the repository is `YOUR-ORG/proxmox-admin` (names are normalized to lowercase), release `1.2.3` publishes `ghcr.io/your-org/proxmox-admin:1.2.3`, `:1.2`, `:1` and `:latest`. Images carry an SBOM and BuildKit provenance attestations.

Cluster repositories pin an exact version in their `compose.yaml`, and Renovate proposes upgrades there. Operator SSH keys, API token files, local inventories and OpenTofu state are explicitly excluded from the Docker build context; no Proxmox credentials are provided to CI.

### Dependency updates (Renovate)

[Renovate](https://docs.renovatebot.com/) is configured in `renovate.json` (install the Renovate GitHub app on the repository). It opens pull requests for GitHub Actions, the Dockerfile base images, Python dependencies, the `community.proxmox` collection, the OpenTofu provider and the semantic-release preset, and automerges them when CI passes. Updates of what ships in the image are committed as `chore(core-deps)`, so they trigger a patch release.

### Running the checks yourself

Local development uses [uv](https://docs.astral.sh/uv/) (Python 3.12, as in the image, from `.python-version`):

```bash
uv sync                                # .venv with the dev dependencies (PyYAML)
uv run bash scripts/check.sh --test    # shell/YAML checks + unit tests (without --test: no tests)

docker build -t proxmox-admin:ci .
bash scripts/smoke-image.sh proxmox-admin:ci
```

The `scripts/smoke-image.sh` command requires Docker but not a Proxmox endpoint or secrets. In GitHub Actions the same checks execute for both supported architectures.

### Git hooks

Optional and local: they live in `.git/hooks/`, so each clone opts in with `uv run python scripts/githooks.py install [HOOK...]` (default: all; `uninstall` removes them). `git commit/push --no-verify` skips them once. Existing hooks not installed by this script are never overwritten.

| Hook | Runs on | Blocks when |
| --- | --- | --- |
| `pre-commit` | every `git commit` | `scripts/check.sh` fails (run through `uv run`, like all hooks) |
| `conventional-commits` | every commit message | the subject is not `<type>[(scope)][!]: <description>` |
| `no-ai-signature` | every commit message | it has an AI-assistant trailer or "Generated with" footer |
| `pre-push` | every `git push` | `scripts/check.sh --test` fails |
