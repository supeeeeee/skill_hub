# SkillHub To-Do (2026-02-15)

## Current Snapshot
- **Product shape**: SkillHub positions itself as a local-first hub that registers `skill.json` manifests once and installs/enables them across adapters. Today the CLI (`Packages/SkillHubCLI`) is the authoritative workflow, while the SwiftUI desktop shell (`Packages/SkillHubApp`) mirrors the PRDa card-first IA but still relies on CLI side effects for most actions.
- **Technical state**: `SkillHubCore` cleanly separates models, adapters, filesystem helpers, and a JSON-backed store. Only OpenClaw and Codex implement real filesystem mutations; the OpenCode/Claude/Cursor adapters remain stubbed. Config-patch mode and SQLite store are defined in docs but not implemented.
- **Key gaps**: CLI doctor/status output is text-only and lacks structured readiness checks; manifest ingestion assumes inconsistent filenames (`skill.json` vs `manifest.json`); the desktop app does not yet render the binding matrix, Apply modal, or Activity log described in `docs/PRD.md`; there is no cross-surface activity log/telemetry.

## Guiding Principles
- Keep CLI and UI surfaces aligned with the PRD text wireframes (Doctor, Products, Skills, Skill Detail, Apply, Settings, Activity) so the same concepts are visible everywhere.
- Prefer adapter-driven behavior: every install/enable/disable path should funnel through `ProductAdapter` implementations backed by backup + rollback support.
- Maintain human-inspectable state (JSON now, SQLite later) and treat all operations as idempotent with explicit error copy following the `What failed + Why + Next step` rule.

## P0  Stabilize the MVP

### CLI + State Reliability
- [ ] Standardize the canonical manifest filename (`skill.json`) across `add`, `stage`, `apply`, URL fetch, and git clone paths in `Packages/SkillHubCLI/Sources/SkillHubCLI/main.swift`, update `docs/skill.schema.json`, and refresh `Examples/skills` to match so users don92Γt guess between `manifest.json` and `skill.json`.
- [ ] Enforce schema validation before decoding by loading `docs/skill.schema.json`, running JSONSchema validation, and surfacing targeted errors (missing `id`, duplicate adapters, unsupported mode) with actionable copy.
- [ ] Expand `doctor`/`detect` into a structured readiness report: verify state file readability/writability, ensure `~/.skillhub/{skills,backups}` exist, run adapter detection plus permissions per PRD, and add a `--json` option so the desktop app can reuse the diagnostics pane.
- [ ] Harden stage/apply pipeline: detect partial copies, checksum staged directories, and ensure `apply` re-runs enablement when the on-disk install mode drifts from `lastInstallModeByProduct`; add rollback on failure using `FileSystemUtils.backupIfExists`.

### Adapter Readiness & Coverage
- [ ] Implement OpenCode adapter install/enable/disable paths (symlink/copy/configPatch) by writing into the actual OpenCode skills/config directory, including backups and detection of incompatible config patch requests.
- [ ] Flesh out Cursor and Claude Code adapters with real filesystem/config targets and support for `configPatch`, matching the install-mode matrix defined in `docs/TECH_SPEC.md`.
- [ ] Add integration smoke tests per adapter (OpenClaw, Codex, OpenCode, Cursor, Claude) that run in a temp home directory, validating detect/install/enable/disable and verifying backups land in `~/.skillhub/backups/<timestamp>/<product>/<skill>`. Wire them into `make test-adapters` for CI.

### Desktop Experience Foundation
- [ ] Rebuild `SkillsView`, `SkillDetailView`, and `ApplySkillView` to match the PRD card-first layout (header cards, binding matrix rows with state badges, InlineLog activity card, Apply modal with rollback note) using the existing component stubs in `Packages/SkillHubApp/Sources/SkillHubApp`.
- [ ] Replace the `Process`-based CLI invocation in `SkillHubViewModel.addSkill`/`installSkill` with direct `SkillHubCore` calls so the app can stage/install/enable without shelling out, and show progress + error copy inline.
- [ ] Implement the command palette stub (Cmd+K) to search skills/products/actions, ensuring focus handling per PRD interaction rules.
- [ ] Wire toast, InlineLog, and Activity views to a shared operation log source rather than ad-hoc `@Published` arrays so CLI + UI events stay in sync.

### Observability & Status
- [ ] Introduce a lightweight append-only activity log (`~/.skillhub/operations.log`) with structured JSON rows (timestamp, command, targets, result, detail). Update CLI commands to emit entries and expose a `skillhub activity [--tail N] [--json]` command.
- [ ] Extend `skillhub status` with per-product detection + adapter status even for uninstalled skills (leveraging `adapter.status`), and optionally emit machine-readable output to drive the desktop dashboard.

## P1  Experience & Platform Lift

### Install Modes & Config Patch
- [ ] Build the config-patch engine in `FileSystemUtils.applyConfigPatch`: support JSON merge patches with backups + validation, then enable `configPatch` for adapters that declare it.
- [ ] Add per-product default install mode settings in `SkillHubState` and surface them in the Settings page + CLI flags (`--default-mode <product>=<mode>`), preserving overrides per Apply action.

### State & Storage Evolution
- [ ] Implement `SQLiteSkillStore` behind the existing `SkillStore` protocol, including migration tooling (`skillhub migrate-state sqlite`) and validation to keep JSON export parity.
- [ ] Support concurrent operations by introducing advisory locking (file lock or sqlite table) around store mutations so CLI, GUI, and background tasks cannot race.

### Skill Lifecycle Enhancements
- [ ] Add `update` and `diff` commands that restage a manifest, preview changes per adapter, and reinstall while preserving enablement when possible.
- [ ] Implement `rollback` leveraging backups: `skillhub rollback <skill-id> <product-id> [--timestamp ...]` restores the last known copy/symlink/config patch and updates state + activity log.

### Desktop UX Polish
- [ ] Build the Doctor, Products, Settings, and Activity screens in the macOS app with the card stacks and CTA rules described in `docs/PRD.md`, including inline warnings for undetected adapters and recovery cards.
- [ ] Add responsive behavior + keyboard navigation/shortcuts (focus order, Enter submits primary CTA, Esc closes modal) to satisfy the PRD interaction section.

## P2  Growth & Ecosystem
- [ ] Stand up a remote skill catalog (simple signed JSON feed or API) and surface it as a browsable gallery + search in the desktop app, with CLI commands to `skillhub search|install <remote-id>`.
- [ ] Introduce opt-in telemetry + crash reporting so we can aggregate anonymous stats on adapter readiness, install failure rates, and favored modes (respecting local-first defaults).
- [ ] Explore team/workspace support (shared state path, git-backed skills directory, or cloud sync) once single-user workflows are stable.

## Cross-Cutting Quality
- [ ] Add unit tests for `JSONSkillStore`, adapter mode resolution, and CLI argument parsing; run them in CI via `swift test` in each package.
- [ ] Ship integration smoke tests for the macOS app (XCTest UI tests) covering skill import, apply, and uninstall flows.
- [ ] Document troubleshooting guides in `docs/` (doctor failures, permissions, adapter-specific fixes) and keep README + PRD updated as new flows launch.
