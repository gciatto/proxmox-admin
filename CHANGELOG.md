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
