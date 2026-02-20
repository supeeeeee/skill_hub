# SkillHub (MVP)

SkillHub is a Swift-based macOS-focused toolkit for managing reusable "agent skills" in one place and installing them into multiple agent products via adapters.

This repository is intentionally scoped to an MVP:
- `SkillHubCore` provides models, JSON-backed state store, adapter protocol, and filesystem helpers.
- `SkillHubCLI` provides a lightweight command-line workflow for products and skills.
- Product adapters are stubs and contain TODO paths for real product integration.

## Repository Layout

- `docs/PRD.md` - product requirements document
- `docs/TECH_SPEC.md` - technical architecture and implementation notes
- `docs/skill.schema.json` - sample skill manifest schema
- `Examples/skills/hello-world/skill.json` - sample skill manifest
- `Examples/state/state.json` - sample JSON state format (SQLite planned later)
- `Packages/SkillHubCore` - core library package
- `Packages/SkillHubCLI` - CLI package

## Quickstart

Requirements:
- macOS
- Swift (Xcode Command Line Tools)

Note: XCTest is not available in some minimal Swift toolchains/environments. This MVP focuses on buildable packages + CLI smoke runs.

Build CLI (recommended):

```bash
make build
```

Run CLI examples:

```bash
make run
# or:
cd Packages/SkillHubCLI
swift run skillhub products
swift run skillhub add ../../Examples/skills/hello-world/skill.json
swift run skillhub skills
swift run skillhub status
```

## Common workflows

One-step apply:

```bash
swift run skillhub apply ../../Examples/skills/hello-world/skill.json opencode
# alias:
swift run skillhub setup ../../Examples/skills/hello-world/skill.json opencode
```

Two-step setup (install to local store + enable on product):

```bash
swift run skillhub install ../../Examples/skills/hello-world/skill.json
swift run skillhub enable hello-world opencode
```

Uninstall and purge:

```bash
swift run skillhub uninstall hello-world opencode
swift run skillhub remove hello-world --purge
```

## Current MVP Status

- State storage is JSON at `~/.skillhub/state.json` by default.
- `install` command installs a skill into the local SkillHub store (register + stage).
- Product-side activation is handled by `enable`/`disable`.
- SQLite, richer patching, and production product integrations are planned post-MVP.
