## [1.3.0](https://github.com/gciatto/proxmox-admin/compare/1.2.1...1.3.0) (2026-10-21)

### Features

* **image:** preconfigured Zsh with safe defaults ([43aa298](https://github.com/gciatto/proxmox-admin/commit/43aa2989bf981c29aa0fb0530fc5bb10434a0c86))

### Bug Fixes

* **ansible:** discover the Python interpreter per host ([8877072](https://github.com/gciatto/proxmox-admin/commit/887707223a3d984769aa2d4fccdb57d68230ae1a)), closes [#10](https://github.com/gciatto/proxmox-admin/issues/10)

### Build and continuous integration

* **release:** also push the image to Docker Hub when DOCKERHUB_USERNAME is set ([6b5843a](https://github.com/gciatto/proxmox-admin/commit/6b5843a6ecbcb0e0d0f2b4edc0c8ada515588308))

## [1.2.1](https://github.com/gciatto/proxmox-admin/compare/1.2.0...1.2.1) (2026-10-21)

### Bug Fixes

* **ansible:** pass only the token name as api_token_id ([90f2452](https://github.com/gciatto/proxmox-admin/commit/90f2452db2e0220a92c66c05f981b069ea8d10f2))

## [1.2.0](https://github.com/gciatto/proxmox-admin/compare/1.1.0...1.2.0) (2026-10-21)

### Features

* add px get and px snapshot to inspect clusters, warmed up at shell start ([14648f5](https://github.com/gciatto/proxmox-admin/commit/14648f55ebc75393f31d524de7a76f5efe5496a6))

## [1.1.0](https://github.com/gciatto/proxmox-admin/compare/1.0.0...1.1.0) (2026-10-21)

### Features

* serve per-cluster repositories, with built-in Ansible defaults and pve-validate ([6f7f3e6](https://github.com/gciatto/proxmox-admin/commit/6f7f3e6da380a5b7860488c8bf2e078c9fbfbec9))
* ship the launcher in the image for cluster repositories ([09a2ed4](https://github.com/gciatto/proxmox-admin/commit/09a2ed4f7cd6cdc6861d3a9566c6318d27343048))

## 1.0.0 (2026-10-21)

### Features

* add Claude Code and Codex CLIs to the image, mounting the user's config ([2e5eb6f](https://github.com/gciatto/proxmox-admin/commit/2e5eb6f7764a2dc8c4d93f664c4c274d95ff76b0))
* first commit ([2399837](https://github.com/gciatto/proxmox-admin/commit/23998370850212a902603f628b191dfe913144a7))

### Documentation

* add AGENTS.md with agent guidance and link CLAUDE.md to it ([1076828](https://github.com/gciatto/proxmox-admin/commit/10768282de8a8de4ed255a5c960135e8caa291fe))

### Build and continuous integration

* manage dev dependencies with uv, run checks and hooks through it ([505e499](https://github.com/gciatto/proxmox-admin/commit/505e4994cdfbf20b2e49b0263df372a60d26bb49))
* release with semantic-release to GitHub and GHCR, add Renovate and git hooks ([d34ce2f](https://github.com/gciatto/proxmox-admin/commit/d34ce2f88721eea352194af141007d575ad9e670))
