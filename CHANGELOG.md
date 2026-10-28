## [1.3.5](https://github.com/gciatto/proxmox-admin/compare/1.3.4...1.3.5) (2026-10-28)

### Dependency updates

* **core-deps:** update dependency @anthropic-ai/claude-code to v2.1.312 ([#15](https://github.com/gciatto/proxmox-admin/issues/15)) ([5a08093](https://github.com/gciatto/proxmox-admin/commit/5a08093dcd9c6ce6c67d53f98ac4aa47ad6affcb))

## [1.3.4](https://github.com/gciatto/proxmox-admin/compare/1.3.3...1.3.4) (2026-10-27)

### Dependency updates

* **core-deps:** update terraform proxmox to v0.118.1 ([#14](https://github.com/gciatto/proxmox-admin/issues/14)) ([c46bbfc](https://github.com/gciatto/proxmox-admin/commit/c46bbfca52a322b8ba0d3c36a6e58014c095acdd))

### Build and continuous integration

* **deps:** update actions/checkout action to v5 ([#3](https://github.com/gciatto/proxmox-admin/issues/3)) ([d2350d2](https://github.com/gciatto/proxmox-admin/commit/d2350d2475e99713f52723b30165daa55c048e71))

## [1.3.3](https://github.com/gciatto/proxmox-admin/compare/1.3.2...1.3.3) (2026-10-27)

### Dependency updates

* **core-deps:** update dependency @openai/codex to v0.164.0 ([#13](https://github.com/gciatto/proxmox-admin/issues/13)) ([5a21060](https://github.com/gciatto/proxmox-admin/commit/5a21060f8f0bff31973e8f4ffc9a8f2e2b71e55a))

### Build and continuous integration

* **deps:** update astral-sh/setup-uv action to v10.3.2 ([#12](https://github.com/gciatto/proxmox-admin/issues/12)) ([134d0d3](https://github.com/gciatto/proxmox-admin/commit/134d0d3ecd84804e6726bf49c2a3db2b9e7de479))

## [1.3.2](https://github.com/gciatto/proxmox-admin/compare/1.3.1...1.3.2) (2026-10-27)

### Dependency updates

* **core-deps:** update dependency @anthropic-ai/claude-code to v2.1.311 ([#11](https://github.com/gciatto/proxmox-admin/issues/11)) ([be4176d](https://github.com/gciatto/proxmox-admin/commit/be4176dbece126cc1edb06dedf36c5f03f876dcd))
* **core-deps:** update dependency community.proxmox to v2.1.0 ([#1](https://github.com/gciatto/proxmox-admin/issues/1)) ([a714ddf](https://github.com/gciatto/proxmox-admin/commit/a714ddfc04c5fce6204b3c737c4e898abe309aac))

## [1.3.1](https://github.com/gciatto/proxmox-admin/compare/1.3.0...1.3.1) (2026-10-21)

### Bug Fixes

* **image:** install passlib, needed by Ansible's password_hash filter ([4f712d5](https://github.com/gciatto/proxmox-admin/commit/4f712d579a635f03c899dd1973e8515e9f4b9e35))

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
