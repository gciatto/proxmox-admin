# AGENTS.md

Guidance for coding agents working in this repository. User-facing docs live in `README.md`; this file covers what an agent needs to change the code safely.

## What this is

A Docker/Compose "admin workstation" image for operating a **remote Proxmox VE cluster**. Operators run `./admin.sh`, which starts an ephemeral container with Ansible (`community.proxmox`), OpenTofu (`bpg/proxmox`), and `px`, a small **read-only** Python CLI over the Proxmox API.

## Map

| Path | Role |
| --- | --- |
| `admin.sh` | Host-side launcher: exports `ADMIN_UID/GID`, `HOST_SSH_DIR`, `HOST_PROXMOX_TOKEN_FILE`; creates `.local/cache` and an empty token file; `--build` / `--pull`; then `docker compose run --rm admin "$@"`. |
| `compose.yaml` / `compose.build.yaml` | Runtime mounts and env; the build file only adds `build: .`. Image defaults to `proxmox-admin:local`, overridden by `PVE_ADMIN_IMAGE`. |
| `Dockerfile` | `python:3.12-slim-bookworm` + `tofu` copied from `ghcr.io/opentofu/opentofu:1-minimal`; installs `ansible-core` and the `px` package. |
| `docker/entrypoint.sh` | Runs as root, creates passwd/group entries for the host UID/GID, drops privileges via `gosu`, then derives env vars (see below). |
| `docker/shell-extensions.zsh`, `docker/zshrc` | `pve-*` Zsh helpers: thin wrappers around `px`, `ansible`, `ansible-playbook`, `tofu`. |
| `src/pxadmin/cli.py` | The whole `px` CLI (`doctor`, `status`, `nodes`, `guests`, `storage`, `version`, `--json`). Entry point declared in `pyproject.toml`. |
| `tests/test_cli.py` | stdlib `unittest` tests for `px`. |
| `ansible/` | `ansible.cfg`, example inventory (group `proxmox_nodes`), and playbooks: `ping`, `node-facts` (SSH), `cluster-status`, `guests` (API on `localhost`). |
| `tofu/` | Provider scaffold only, with **no managed resources** on purpose. |
| `scripts/check.sh` | All source checks (shell syntax, YAML); `--test` adds unit tests. Used by CI and the Git hooks. |
| `scripts/check-yaml.py` | YAML parse check plus assertions on CI/release workflow wiring. Needs PyYAML; `check.sh` skips it if missing. |
| `scripts/smoke-image.sh` | Runs tools inside a built image under an arbitrary UID/GID, with no cluster access. |
| `scripts/githooks.py` | Installs/removes local Git hooks (`install|uninstall [HOOK...]`); also the commit-msg checks. |
| `scripts/release-image.sh` | Builds and pushes the multi-arch image to GHCR; called by semantic-release only. |
| `.github/workflows/` | `ci.yml` (tests + amd64/arm64 smoke) and `release.yml` (reuses `ci.yml`, then runs semantic-release). |
| `package.json`, `release.config.mjs` | semantic-release: DanySK's conventional-commits preset + image push, GitHub release, release commit. |
| `renovate.json` | Renovate; a regex manager tracks `community.proxmox` in the Dockerfile. |

## Checks to run before finishing

```bash
bash scripts/check.sh --test             # YAML part needs PyYAML>=6,<7, otherwise skipped
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

- **No secrets in the image or repo.** SSH keys, the token file, `.env`, the real `ansible/inventory/hosts.yml`, `config/certs/*`, and tofu state/tfvars are git-ignored *and* docker-ignored. Keep `.gitignore` and `.dockerignore` in sync.
- **The container never runs tools as root.** The image has no baked-in user; the entrypoint creates one for `ADMIN_UID/GID`. `admin.sh` refuses to run as root. The smoke test checks UID 23456.
- **TLS verification and SSH host-key checking stay on by default** (`PROXMOX_VALIDATE_CERTS=true`, `host_key_checking = True`). Use a CA bundle; don't disable verification.
- **`px` stays read-only.** Changes go through Ansible/OpenTofu. Error messages must not print credential values. API playbook tasks use `no_log: true`.
- **`proxmoxer` is imported lazily inside `connect()`** so tests run with only the stdlib (CI doesn't install the package). Keep new imports of third-party packages lazy, or update CI.
- `PROXMOX_TOKEN_ID` must be `user@realm!tokenname`, and its prefix must equal `PROXMOX_USER` (enforced in `Config.from_env`).
- In-container paths are hard-coded to `/workspace` (inventory, `ansible.cfg`, playbooks, tofu dir) and `/home/operator`.
- `tofu/` must pass `tofu fmt -check -recursive`. Don't add managed resources without the shared-remote-state setup described in the README.
- `release.yml` must keep `publish.needs: verify` and `verify.uses: ./.github/workflows/ci.yml`. `ci.yml` must keep `pull_request` and `workflow_call` triggers. `check-yaml.py` asserts all of these.
- Releases are made only by semantic-release on `main`/`master`: never create tags (plain `1.2.3`, no `v`) or bump `pyproject.toml`'s version by hand. `CHANGELOG.md` is generated.
- The image is pushed in semantic-release's `prepare` step, before the release commit and tag, so a failed push releases nothing. Keep that order in `release.config.mjs`.

## Pinned versions

When you bump a version, check Proxmox VE compatibility first.

- `ansible-core>=2.18,<2.21`, `community.proxmox==2.0.0` (Dockerfile)
- `bpg/proxmox` `0.117.0`, OpenTofu `>= 1.9.0` (`tofu/versions.tf`); image uses `opentofu:1-minimal`
- `proxmoxer>=2.3,<3`, `requests>=2.31,<3`, Python `>=3.10` (`pyproject.toml`); image and CI use 3.12

## Git

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, e.g. `feat(px): add storage subcommand`, `fix(entrypoint): ...`, `ci: ...`, `docs: ...`. They drive releases, so pick the type carefully: `feat` = minor; `fix`, `docs`, `revert`, `chore(core-deps)` = patch; `!` = major; other types release nothing.
- Local hooks (`python3 scripts/githooks.py install`) enforce the two rules below plus `check.sh` on commit and `check.sh --test` on push.
- No AI attribution in commits: no `Co-Authored-By:` trailers for agents, no "Generated with ..." lines.
- Agents may commit on their own initiative while working on a task, but must **always ask before pushing** (including tags, which trigger releases).

## Conventions

- Python: stdlib-first, `argparse`, type hints, `from __future__ import annotations`; tests use `unittest` (no pytest).
- Shell: `set -euo pipefail` in bash; the entrypoint is POSIX `sh` (`set -eu`). Zsh helpers are named `pve-*`.
- Adding a playbook: put it in `ansible/playbooks/NAME.yml` and it is reachable as `pve-play NAME`. The smoke test syntax-checks it automatically. API playbooks run on `localhost` with `connection: local` and read credentials from env via `lookup('env', ...)`.
- Adding a `px` subcommand: add it to the tuple in `main()` and to the dispatch branch, then mirror it in `pve-help` and the README.
