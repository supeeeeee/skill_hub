# SkillHub Technical Design (MVP)

## Architecture

SkillHub is split into two Swift packages:

1. `SkillHubCore` (library)
   - Domain models (`SkillManifest`, `SkillHubState`, install modes)
   - JSON state store (`JSONSkillStore`)
   - Adapter protocol and registry
   - Filesystem utility helpers

2. `SkillHubCLI` (executable)
   - Command parser and command handlers
   - Uses `SkillHubCore` for all business logic

Design principle: keep adapter and state management reusable so a future macOS GUI app can reuse `SkillHubCore` directly.

## Data Model

### Skill Manifest (`skill.json`)

Top-level fields:
- `id` (string, required)
- `name` (string, required)
- `version` (string, required)
- `summary` (string, required)
- `entrypoint` (string, optional)
- `tags` ([string], optional)
- `adapters` ([AdapterConfig], optional)

`AdapterConfig` fields:
- `productID` (string)
- `installMode` (`auto` | `symlink` | `copy` | `configPatch`)
- `targetPath` (string, optional)
- `configPatch` (map string->string, optional; MVP placeholder)

### Runtime State (MVP JSON)

File schema:
- `schemaVersion` (int)
- `skills` ([InstalledSkillRecord])
- `updatedAt` (ISO8601 string)

`InstalledSkillRecord` fields:
- `manifest` (`SkillManifest` snapshot)
- `manifestPath` (string)
- `installedProducts` ([string])
- `enabledProducts` ([string])
- `lastInstallModeByProduct` (map productID->installMode)

## Storage Paths

Default roots:
- SkillHub state directory: `~/.skillhub/`
- State file (MVP): `~/.skillhub/state.json`
- Skill staging store: `~/.skillhub/skills/`
- Backups: `~/.skillhub/backups/`

Future path extensions:
- SQLite DB: `~/.skillhub/state.sqlite`
- Operation log: `~/.skillhub/operations.log`

## Adapter Interface

`ProductAdapter` responsibilities:
- Expose stable `id` and display `name`.
- Expose `supportedInstallModes` capabilities.
- Detect product availability with `detect()` and explain why detection failed.
- Install skill payload via `install(skill:mode:)`, including mode override if needed.
- Apply product-level enable/disable side effects.
- Report `status()` for a skill per product.

MVP adapters:
- `OpenClawAdapter` (real implementation)
- `OpenCodeAdapter` (stub)
- `ClaudeCodeAdapter` (stub)
- `CodexAdapter` (stub)
- `CursorAdapter` (stub)

Stub adapters include plausible TODO path constants and `configPatch` placeholders, and intentionally return `notImplemented` for product mutations.

## Install Modes

1. `auto`
   - Resolve mode in adapter with `symlink` preference, then fallback to `copy`.
   - Adapter can override auto resolution based on product constraints.

2. `symlink`
   - Create link from product skill location to source skill directory.
   - Pros: instant updates, low disk usage.
   - Cons: products that forbid symlinks may fail.

3. `copy`
   - Copy files into product-managed location.
   - Pros: broad compatibility.
   - Cons: drift unless reinstall/update is repeated.

4. `configPatch`
   - Edit product config to reference/enable skill.
   - Pros: supports products driven by JSON/YAML settings.
   - Cons: highest corruption risk without strict patch model.

CLI behavior:
- Default install mode is `auto` when `--mode` is omitted.
- `install` output shows both requested mode and chosen mode.
- `stage <manifest-path>` copies the containing skill directory to `~/.skillhub/skills/<id>`.
- `unstage <skill-id>` deletes only the staged store copy.
- `uninstall <skill-id> <product-id>` removes product activation/install state but leaves staged store files.
- `remove <skill-id> [--purge]` deletes SkillHub state record, with optional staged store purge.

OpenClaw behavior:
- Skill store root: `~/.skillhub/skills`
- OpenClaw skills root: `~/.openclaw/skills`
- `install` validates staged skill presence and resolves mode (`auto` => `symlink` then `copy`).
- `enable` applies the mode recorded during `install` (`symlink` or `copy`) from staged store to OpenClaw.
- If `~/.openclaw/skills/<skillId>` already exists, it is moved to
  `~/.skillhub/backups/<timestamp>/openclaw/<skillId>/` before writing the new artifact.
- `disable` removes `~/.openclaw/skills/<skillId>` if present.

Codex behavior:
- Skill store root: `~/.skillhub/skills`
- Codex skills root: `~/.codex/skills`
- `install` validates staged skill presence and resolves mode (`auto` => `symlink` then `copy`).
- `enable` applies the mode recorded during `install` (`symlink` or `copy`) from staged store to Codex.
- If `~/.codex/skills/<skillId>` already exists, it is moved to
  `~/.skillhub/backups/<timestamp>/codex/<skillId>/` before writing the new artifact.
- `disable` removes `~/.codex/skills/<skillId>` if present.

Per-product install capabilities:
- `openclaw`: `auto`, `symlink`, `copy`
- `opencode`: `auto`, `symlink`, `copy`, `configPatch` (stub)
- `claude-code`: `auto`, `copy`, `configPatch` (stub)
- `codex`: `auto`, `symlink`, `copy`
- `cursor`: `auto`, `symlink`, `copy`, `configPatch` (stub)

MVP implementation status:
- Filesystem primitives for symlink/copy are provided.
- Config patch function is placeholder until per-product patchers are defined.

## Security and Permissions

1. Local-only by default, no outbound network actions required.
2. Use user-owned paths under home directory; avoid privileged paths.
3. Before writes, verify parent exists or create it in user scope.
4. For config edits (future), create backup before mutation.
5. Avoid storing secrets in state; manifests are metadata only.

## Update and Rollback Strategy

MVP strategy:
1. Read and validate existing state.
2. Write to `state.json.tmp`.
3. Atomically replace `state.json`.

Adapter operation strategy (MVP):
1. Validate source paths and requested/resolved mode.
2. If destination exists, move it into `~/.skillhub/backups/<timestamp>/<product>/<skillId>/`.
3. Apply filesystem changes (symlink/copy/disable).
4. Persist state updates after adapter mutation succeeds.

Planned full implementation:
1. Build operation plan.
2. Snapshot affected files to backup location.
3. Apply filesystem/config changes.
4. On failure, execute reverse operations from plan.
5. Persist operation outcome and diagnostics.

## Error Handling

Error categories:
- Validation errors (invalid manifest, unknown product, unsupported mode)
- Filesystem errors (path missing, permissions, copy/link failures)
- Adapter errors (environment invalid, not implemented, product mutation failed)
- State errors (decode/encode failure, atomic write failure)

CLI behavior:
- Return non-zero exit code on failure.
- Print concise cause and likely fix.
- Never swallow errors silently.

## JSON to SQLite Migration Plan

1. Introduce `SkillStore` protocol (already in place).
2. Add `SQLiteSkillStore` with same interface.
3. Add one-time migration command:
   - read `state.json`
   - write `state.sqlite`
   - verify row counts/checksums
   - mark migration complete in metadata.
4. Keep JSON export command for debugging and backup.
