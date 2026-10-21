# AGENTS.md

Guidance for coding agents working in this repository. User-facing docs live in `README.md`; this file covers what an agent needs to change the code safely.

Operating a cluster happens in a separate cluster repository created from [template-proxmox-cluster](https://github.com/gciatto/template-proxmox-cluster), whose own `AGENTS.md` holds the operator rules. If you are in `/workspace` of a running admin container with this repository mounted, those rules apply here too: inspect read-only first and **ask before any change** to the cluster.

## What this is

A Docker/Compose "admin workstation" image for operating a **remote Proxmox VE cluster**. Operators run `./admin.sh`, which starts an ephemeral container with Ansible (`community.proxmox`), OpenTofu (`bpg/proxmox`), `px` (a small **read-only** Python CLI over the Proxmox API), and the Claude Code and Codex CLIs.

## Map

| Path | Role |
| --- | --- |
| `admin.sh` | Host-side launcher, also shipped in the image for cluster repositories (`PVE_WORKSPACE`): exports `ADMIN_UID/GID`, `HOST_SSH_DIR`, `HOST_PROXMOX_TOKEN_FILE`, `HOST_CLAUDE_DIR`, `HOST_CODEX_DIR` (user's `~/.claude`/`~/.codex`, else `.local/claude`/`.local/codex`); creates `.local/cache` and an empty token file; `--build` / `--pull`; then `docker compose run --rm admin "$@"`. |
| `compose.yaml` / `compose.build.yaml` | Runtime mounts and env; the build file only adds `build: .`. Image defaults to `proxmox-admin:local`, overridden by `PVE_ADMIN_IMAGE`. |
| `Dockerfile` | `python:3.12-slim-bookworm` + `tofu` from `ghcr.io/opentofu/opentofu:1-minimal` + Node from `node:24-bookworm-slim`; installs `ansible-core`, the `px` package, and Claude Code / Codex via npm. Versions pinned as `ARG`s with `# renovate:` comments. |
| `docker/entrypoint.sh` | Runs as root, creates passwd/group entries for the host UID/GID, drops privileges via `gosu`, then derives env vars (see below) and picks `ANSIBLE_CONFIG` (`/workspace/ansible/ansible.cfg`, else the built-in one). |
| `docker/pve-validate` | Offline checks of the repository mounted at `/workspace`; used by cluster repositories' CI and hooks. |
| `docker/shell-extensions.zsh`, `docker/zshrc` | `pve-*` Zsh helpers: thin wrappers around `px`, `ansible`, `ansible-playbook`, `tofu`. |
| `src/pxadmin/cli.py` | The `px` CLI (`doctor`, `status`, `nodes`, `guests`, `storage`, `version`, `get PATH`, `snapshot`, `--json`). Entry point declared in `pyproject.toml`. |
| `src/pxadmin/snapshot.py` | `px snapshot`: reads `CLUSTER_PATHS`/`NODE_PATHS` (errors recorded, never fatal), writes `summary.md` + `snapshot.json` to `/tmp/pve-snapshot` (`PVE_SNAPSHOT_DIR`). |
| `tests/` | stdlib `unittest` tests for `px`, the snapshot and the Git hooks. |
| `ansible/` | `ansible.cfg` and playbooks `ping`, `node-facts` (SSH), `cluster-status`, `guests` (API on `localhost`), **copied into the image** under `/opt/proxmox-admin/ansible/` as defaults for cluster repositories; example inventory (group `proxmox_nodes`). |
| `tofu/` | Provider scaffold only, with **no managed resources** on purpose; a smoke-test fixture. Real resources live in cluster repositories. |
| `scripts/check.sh` | All source checks (shell syntax, YAML); `--test` adds unit tests. Used by CI and the Git hooks, always through `uv run`. |
| `scripts/check-yaml.py` | YAML parse check plus assertions on CI/release workflow wiring (PyYAML, from the uv `dev` group). |
| `scripts/smoke-image.sh` | Runs tools inside a built image under an arbitrary UID/GID, with no cluster access. |
| `scripts/githooks.py` | Installs/removes local Git hooks (`install|uninstall [HOOK...]`); also the commit-msg checks. |
| `scripts/release-image.sh` | Builds and pushes the multi-arch image to GHCR (and Docker Hub when `DOCKERHUB_USERNAME` is set); called by semantic-release only. |
| `.github/workflows/` | `ci.yml` (tests + amd64/arm64 smoke) and `release.yml` (reuses `ci.yml`, then runs semantic-release). |
| `package.json`, `release.config.mjs` | semantic-release: DanySK's conventional-commits preset + image push, GitHub release, release commit. |
| `renovate.json` | Renovate; `customManagers:dockerfileVersions` tracks the `# renovate:` `ARG`s in the Dockerfile. |

## Checks to run before finishing

```bash
uv sync                                  # .venv with dev dependencies (PyYAML)
uv run bash scripts/check.sh --test
# When the Dockerfile, docker/, ansible/ or tofu/ changes (needs Docker):
docker build -t proxmox-admin:ci . && bash scripts/smoke-image.sh proxmox-admin:ci
```

CI never contacts a real cluster, and neither should you. **Do not run** `./admin.sh px <api-command>`, `ansible-playbook` against the real inventory, or `tofu apply` unless the user explicitly asks: they act on live infrastructure with the operator's credentials.

## Configuration flow

`.env` → `compose.yaml` → `docker/entrypoint.sh` → tools. The entrypoint derives:

- `PROXMOX_TOKEN_SECRET` from the mounted file `/run/secrets/proxmox-token`. Compose only passes `PROXMOX_TOKEN_SECRET_FILE`. The API playbooks read `PROXMOX_TOKEN_SECRET`, so they only work through the entrypoint.
- `PROXMOX_USER` from the `PROXMOX_TOKEN_ID` prefix (`user@realm!name`) when unset.
- `PROXMOX_VE_ENDPOINT`, `PROXMOX_VE_API_TOKEN`, `PROXMOX_VE_SSH_USERNAME`, `PROXMOX_VE_INSECURE` for the OpenTofu bpg provider.
- `REQUESTS_CA_BUNDLE` / `SSL_CERT_FILE` from `PROXMOX_CA_BUNDLE`. `px` relies on these and does not take a CA path itself.

When you add a new setting, wire it through all of these layers: `.env.example`, `compose.yaml` `environment:`, the entrypoint (if it needs deriving), and the README.

## Invariants (don't break)

- **AI CLI config is mounted, never baked in.** `~/.claude` and `~/.codex` are bind-mounted read-write (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`); `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_API_KEY` are passed through from the shell only when set.
- **No secrets in the image or repo.** SSH keys, the token file, `.env`, the real `ansible/inventory/hosts.yml`, `config/certs/*`, and tofu state/tfvars are git-ignored *and* docker-ignored. Keep `.gitignore` and `.dockerignore` in sync.
- **The container never runs tools as root.** The image has no baked-in user; the entrypoint creates one for `ADMIN_UID/GID`. `admin.sh` refuses to run as root. The smoke test checks UID 23456.
- **TLS verification and SSH host-key checking stay on by default** (`PROXMOX_VALIDATE_CERTS=true`, `host_key_checking = True`). Use a CA bundle; don't disable verification.
- **`px` stays read-only.** Changes go through Ansible/OpenTofu. Error messages must not print credential values. API playbook tasks use `no_log: true`.
- **`proxmoxer` is imported lazily inside `connect()`** so tests run with only the stdlib (CI doesn't install the package). Keep new imports of third-party packages lazy, or update CI.
- `PROXMOX_TOKEN_ID` must be `user@realm!tokenname`, and its prefix must equal `PROXMOX_USER` (enforced in `Config.from_env`).
- **The image contract is shared with cluster repositories** (see `README.md`, "Image contract", and `../template-proxmox-cluster`): mount points, `/workspace` layout, env vars, `pve-*` helpers, `pve-validate`. Changing it is a breaking change (`feat!:`/`fix!:`). `admin.sh` and `compose.yaml` ship in the image (`/opt/proxmox-admin/launcher/`) and run for both this checkout and cluster repositories (`PVE_WORKSPACE`), whose `admin.sh` stub extracts them: keep them working from any directory, and keep the stub contract (`PVE_WORKSPACE`, `PVE_ADMIN_IMAGE`, launcher path) stable.
- `tofu/` must pass `tofu fmt -check -recursive`. Don't add managed resources without the shared-remote-state setup described in the README.
- `release.yml` must keep `publish.needs: verify` and `verify.uses: ./.github/workflows/ci.yml`. `ci.yml` must keep `pull_request` and `workflow_call` triggers. `check-yaml.py` asserts all of these.
- Releases are made only by semantic-release on `main`/`master`: never create tags (plain `1.2.3`, no `v`) or bump the version by hand (it does `uv version`, keeping `pyproject.toml` and `uv.lock` in sync). `CHANGELOG.md` is generated.
- The image is pushed in semantic-release's `prepare` step, before the release commit and tag, so a failed push releases nothing. Keep that order in `release.config.mjs`.

## Pinned versions

When you bump a version, check Proxmox VE compatibility first.

- `ansible-core>=2.18,<2.21`, `community.proxmox`, `@anthropic-ai/claude-code`, `@openai/codex`, Node 24 (Dockerfile)
- `bpg/proxmox` `0.117.0`, OpenTofu `>= 1.9.0` (`tofu/versions.tf`); image uses `opentofu:1-minimal`
- `proxmoxer>=2.3,<3`, `requests>=2.31,<3`, Python `>=3.10` (`pyproject.toml`); image and CI use 3.12

## Git

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, e.g. `feat(px): add storage subcommand`, `fix(entrypoint): ...`, `ci: ...`, `docs: ...`. They drive releases, so pick the type carefully: `feat` = minor; `fix`, `docs`, `revert`, `chore(core-deps)` = patch; `!` = major; other types release nothing.
- Local hooks (`uv run python scripts/githooks.py install`) enforce the two rules below plus `check.sh` on commit and `check.sh --test` on push.
- No AI attribution in commits: no `Co-Authored-By:` trailers for agents, no "Generated with ..." lines.
- Agents may commit on their own initiative while working on a task, but must **always ask before pushing** (including tags, which trigger releases).

## Conventions

- Dependencies: `uv add` (image runtime) or `uv add --dev` (checks only); never hand-edit `uv.lock`. CI runs `uv sync --locked`, so commit the lock with `pyproject.toml`. The Dockerfile installs with `pip install .`, so dev dependencies never reach the image.
- Python: stdlib-first, `argparse`, type hints, `from __future__ import annotations`; tests use `unittest` (no pytest).
- Shell: `set -euo pipefail` in bash; the entrypoint is POSIX `sh` (`set -eu`). Zsh helpers are named `pve-*`.
- Adding a playbook: put it in `ansible/playbooks/NAME.yml` and it is reachable as `pve-play NAME`. The smoke test syntax-checks it automatically. API playbooks run on `localhost` with `connection: local` and read credentials from env via `lookup('env', ...)`.
- Adding a `px` subcommand: add it to the tuple in `main()` and to the dispatch branch, then mirror it in `pve-help` and the README.
