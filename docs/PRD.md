# SkillHub PRD (MVP)

## Problem

People using multiple AI agent products repeatedly re-create and re-install the same "skills" (prompts, tools, configs, scripts) per product. Each product has different folder conventions and configuration formats, which leads to drift, setup friction, and fragile manual processes.

## Goals

1. Provide a central place to register and manage reusable agent skills.
2. Install the same skill into multiple products through adapter-specific logic.
3. Support one-command install flows with three install modes: symlink, copy, config patch.
4. Offer clear visibility into per-skill and per-product status.
5. Keep MVP local-first and macOS-focused with low operational complexity.

## Non-Goals (MVP)

- Cloud sync, multi-device replication, or team collaboration.
- UI-heavy desktop app in MVP (CLI-first scaffold is acceptable foundation).
- Full production-grade adapters for all products.
- Encrypted secret management system.
- Marketplace/discovery for third-party skills.

## Personas

1. **Power Builder**
   - Uses multiple agent products (OpenCode/OpenClaw, Claude Desktop, Cursor).
   - Wants one source of truth for reusable workflows.

2. **Prompt Engineer**
   - Frequently iterates on prompts/skill manifests.
   - Wants quick rollout and rollback across products.

3. **Ops-minded Solo Developer**
   - Values predictable, inspectable local state.
   - Wants safe install modes and clear failure signals.

## User Stories

1. As a user, I can list supported products and check whether each adapter is available.
2. As a user, I can add a skill by pointing to a `skill.json` manifest.
3. As a user, I can install a skill into a product with `symlink`, `copy`, or `config-patch`.
4. As a user, I can enable or disable a skill for a specific product.
5. As a user, I can query status to understand what is installed and enabled.
6. As a user, I can recover from failed installs with clear rollback guidance.

## UX / IA (MVP)

### Product Areas

- **Onboarding / Doctor**
  - First-run setup checks and environment diagnosis.
  - Ensures adapters and filesystem paths are valid before any install.

- **Products**
  - Lists supported products and adapter readiness.
  - Shows capabilities by install mode (`symlink`, `copy`, `config-patch`).

- **Skills**
  - Main catalog of registered skills with status snapshot.
  - Entry point to add new skills and drill into details.

- **Skill Detail**
  - Per-skill operations: install, enable, disable, remove, inspect history.
  - Product-level status, mode, and last operation result.

- **Apply Modal**
  - Confirmation step before mutating actions (install/enable/disable/remove).
  - Displays impact, selected targets, and rollback note.

- **Settings**
  - Local state path, default behavior, and safety toggles.
  - MVP scope limited to local-only configuration.

- **Activity**
  - Reverse-chronological operation log for audit and troubleshooting.
  - Shows command, target, result, and timestamp.

### Text Wireframes

#### 1) Onboarding / Doctor

- **Primary purpose:** confirm environment is ready.
- **Fields:**
  - Workspace path
  - Detected products (OpenCode/OpenClaw, Claude Desktop, Cursor)
  - Adapter health checks
  - Permissions check (read/write)
- **CTAs:**
  - `Run checks`
  - `Fix with guidance`
  - `Continue to Products`
- **Empty states:**
  - No products detected: "No supported products found yet. Install a product or set a custom path in Settings."
  - Checks not run: "Run doctor checks before first install."

#### 2) Products

- **Primary purpose:** inspect product compatibility and readiness.
- **Fields:**
  - Product name and adapter ID
  - Detection status (available/unavailable)
  - Supported modes
  - Last validated timestamp
- **CTAs:**
  - `Validate all`
  - `Recheck product`
  - `View details`
- **Empty states:**
  - No adapters available: "No adapters are ready. Start with Onboarding/Doctor to diagnose setup issues."

#### 3) Skills

- **Primary purpose:** browse and manage registered skills.
- **Fields:**
  - Skill name, ID, version
  - Source manifest path
  - Installed product count
  - Enabled product count
  - Last updated timestamp
- **CTAs:**
  - `Add skill`
  - `Refresh catalog`
  - `Open skill`
- **Empty states:**
  - No skills registered: "No skills yet. Add one by pointing to a valid `skill.json` manifest."

#### 4) Skill Detail

- **Primary purpose:** execute per-skill lifecycle actions.
- **Fields:**
  - Skill metadata (name, ID, version, description)
  - Target product rows with status (not installed/installed/enabled)
  - Install mode per product
  - Last operation result and timestamp
- **CTAs:**
  - `Install`
  - `Enable`
  - `Disable`
  - `Remove`
  - `Open activity`
- **Empty states:**
  - Not installed anywhere: "This skill is registered but not installed to any product yet."

#### 5) Apply Modal

- **Primary purpose:** confirm action and reduce accidental mutations.
- **Fields:**
  - Action summary (e.g., Install `skill-id` to 2 products)
  - Selected products
  - Mode selection (if install)
  - Backup/rollback note
- **CTAs:**
  - `Apply`
  - `Cancel`
  - `View rollback details`
- **Empty states:**
  - No targets selected: "Select at least one product to continue."

#### 6) Settings

- **Primary purpose:** configure local defaults and paths.
- **Fields:**
  - State file location
  - Default install mode (optional)
  - Safety toggle: require confirmation for destructive operations
  - Adapter path overrides (advanced, optional)
- **CTAs:**
  - `Save settings`
  - `Reset defaults`
  - `Open state file location`
- **Empty states:**
  - No overrides set: "Using auto-detected defaults. Add overrides only if detection fails."

#### 7) Activity

- **Primary purpose:** provide operational traceability.
- **Fields:**
  - Timestamp
  - Command/action
  - Skill and product targets
  - Result (success/error)
  - Short detail message
- **CTAs:**
  - `Filter`
  - `Retry failed action`
  - `Export log`
- **Empty states:**
  - No history yet: "No activity yet. Actions appear here after your first operation."

### Primary User Journey (MVP)

#### First-Run Journey

1. Open **Onboarding / Doctor** and run checks.
2. Resolve blockers using guided fixes until at least one product is available.
3. Open **Skills** and add a skill from `skill.json`.
4. Enter **Skill Detail**, choose product(s), and start `Install`.
5. Confirm action in **Apply Modal** and complete install.
6. Enable skill where applicable and verify outcome in **Activity**.

#### Daily Use Journey

1. Open **Skills** to review current status and identify updates.
2. Open a **Skill Detail** page for the target skill.
3. Apply install/enable/disable changes to one or more products.
4. Use **Apply Modal** to confirm impact before execution.
5. Check **Activity** for success/errors and perform retries if needed.
6. Use **Products** and **Settings** only when environment or defaults change.

### Copywriting Guidelines (Errors and Success)

- Match CLI guidance: concise, deterministic, actionable, and free of fluff.
- Use this structure for errors: `What failed` + `Why` + `Next step`.
- Prefer specific nouns and paths over generic wording (name product, skill ID, file path).
- Keep one clear recovery action per message where possible.
- Avoid blame language; focus on system state and user action.
- Success messages should confirm completed action and resulting state.

Examples:

- **Error:** "Install failed for `cursor` because adapter path is missing. Set adapter override in Settings, then run install again."
- **Error:** "Could not parse `skill.json` at `/path/to/skill.json`. Fix JSON syntax and retry `Add skill`."
- **Success:** "Installed `daily-standup` to `opencode` using `symlink`. Skill is now available to enable."
- **Success:** "Enabled `release-checklist` for `claude-desktop`. Last updated just now."

### UI Spec: Style B (Card-Heavy, Linear/Notion-like)

#### Visual Style

- **Layout model:** Card-first interface on a soft neutral canvas. Each page is composed of stacked sections where major actions and data live inside cards rather than full-width tables.
- **Card system:**
  - Default card radius: 10px
  - Border: 1px subtle neutral stroke
  - Elevation: low shadow at rest, medium shadow on hover/focus-within
  - Internal padding: 16px (mobile), 20px (desktop)
- **Spacing scale:** 4/8/12/16/24/32. Primary page rhythm uses 24px between major sections and 12-16px within card internals.
- **Typography:**
  - Primary UI font: modern sans for clarity and density
  - Headings: semibold with tight line-height
  - Body text: regular weight, high contrast
  - Meta/status text: smaller size and lower contrast
- **Density target:** Compact-professional; optimized for scanning many skills/products without visual clutter.

#### Component Specs

- **ProductCard**
  - Shows product name, adapter ID, detection status, supported modes, and last validated time.
  - Primary action: `Recheck`.
  - Secondary actions: `View details`, `Run doctor` when unavailable.
- **SkillCard**
  - Shows skill name, ID, version, installed count, enabled count, and latest activity snippet.
  - Primary action: `Open skill`.
  - Secondary actions: quick `Install` and overflow menu (`Disable`, `Remove`, `Open activity`).
- **BindingMatrixRow**
  - Represents one skill-product binding.
  - Columns: Product, State, Mode, Last result, Last updated, CTA area.
  - CTA area changes by binding state machine (defined below).
- **PrimaryCTAButton**
  - Used for the highest-priority mutation per surface (`Install`, `Enable`, `Apply`, `Run checks`).
  - Solid fill, high contrast text, min height 36px, disabled state clearly visible.
- **ModePill**
  - Displays install mode (`symlink`, `copy`, `config-patch`).
  - Neutral by default, highlighted when selected in Apply flow.
- **StatusBadge**
  - Compact semantic badge for state/result (`Not detected`, `Detected`, `Staged`, `Installed`, `Enabled`, `Error`).
  - Color must always pair with text label (never color-only meaning).
- **InlineLog**
  - Single-line operation result under cards/rows with timestamp and truncation.
  - Expands inline for full message and recovery hint.
- **EmptyState**
  - Includes short explanation, one primary CTA, optional helper link.
  - Must be card-contained and visually consistent with populated states.

#### Page Layouts

- **Products**
  - Header card: environment summary + `Validate all`.
  - Grid/list of `ProductCard` components.
  - Inline warnings for unavailable adapters.
- **Skills**
  - Header card: catalog totals, `Add skill`, `Refresh catalog`.
  - Search/filter bar card.
  - Responsive list/grid of `SkillCard` components.
- **Skill Detail**
  - Top metadata card for skill identity and source path.
  - Binding matrix card containing `BindingMatrixRow` entries.
  - Recent activity card using `InlineLog` items.
- **Doctor**
  - Check runner card with `Run checks` as primary.
  - Results card stack grouped by category (paths, permissions, adapters).
  - Recovery card with guided next steps.
- **Settings**
  - Sectioned cards for paths, defaults, and safety toggles.
  - Save/reset actions persist at page top and bottom for long forms.
- **Activity**
  - Filter/scope control card.
  - Chronological log cards with status badges and expandable details.

#### Interaction Rules

- **Default focus**
  - On page load, focus lands on the primary page-level action (or first filter/search control if no immediate safe action).
  - In modals, focus lands on the first actionable field; focus trap remains until close.
- **Keyboard**
  - Global: `Cmd+K` opens command/search palette (optional but preferred).
  - `Enter` triggers focused primary action when valid.
  - `Esc` closes modal/palette/drawer and returns focus to trigger element.
  - Tab order follows visual order, including card actions and overflow menus.
- **Confirmation rules**
  - Required for all mutating actions: install, enable, disable, remove, apply.
  - Confirmation copy must include target skill, target products, and expected state transition.
  - High-risk actions (remove/disable across multiple products) require explicit typed confirm or second-click confirm.

#### Binding State Machine and CTA Mapping

Binding states for each skill-product pair:

1. `notDetected`
2. `detected`
3. `staged`
4. `installed`
5. `enabled`

State behavior and visible CTA:

| State | Meaning | Primary CTA | Secondary CTA |
| --- | --- | --- | --- |
| `notDetected` | Product or adapter not available | `Run doctor` | `Open settings` |
| `detected` | Product is available, no staged change | `Install` | `Choose mode` |
| `staged` | Pending mutation awaiting confirmation/apply | `Apply` | `Cancel staged` |
| `installed` | Installed but not active/enabled | `Enable` | `Reinstall` |
| `enabled` | Installed and active | `Disable` | `Reinstall` |

Transition expectations:

- `notDetected -> detected` via successful doctor/recheck.
- `detected -> staged` after selecting mode/targets and preparing apply action.
- `staged -> installed` after successful apply/install.
- `installed -> enabled` after successful enable.
- `enabled -> installed` after disable.
- Any failure keeps current stable state and surfaces error in `InlineLog` + `StatusBadge(Error)`.

#### Error-to-UI Mapping

| Error Source | Typical Failure | UI Surface | User-facing Pattern |
| --- | --- | --- | --- |
| `doctor` | Path, permission, adapter validation failure | Doctor results cards + ProductCard badge | Show failing check, reason, and one guided fix action |
| `apply` | Confirmation mismatch or transaction validation failure | Apply modal inline error + blocked submit | Keep modal open, preserve inputs, highlight invalid target/mode |
| `install` | File operation/patch/symlink failure | BindingMatrixRow + Skill Detail activity card | Row-level error badge, `Retry install`, rollback guidance link |
| `enable` | Product config activation failed | BindingMatrixRow + InlineLog | Keep at `installed`, show actionable next step (`Open settings` or `Retry`) |

Global error behavior:

- Errors are anchored near the failed card/row first, with optional page toast as secondary signal.
- Every error message follows: `What failed` + `Why` + `Next step`.
- Retry CTA appears when operation is safe to re-run idempotently.

## Functional Requirements

1. Parse and validate `skill.json` manifest.
2. Persist skill catalog and enablement state locally.
3. Expose adapter protocol to install/enable/disable in product-specific way.
4. Provide product enumeration with environment validation status.
5. Support idempotent skill registration (`add` updates existing skill by ID).
6. Record install mode used for each skill-product pairing.

## Non-Functional Requirements

1. Local-first operation with no network dependency for core workflow.
2. JSON state should remain human-inspectable.
3. Commands should complete within sub-second for small catalogs.
4. Preserve forward compatibility to migrate JSON -> SQLite.

## Success Metrics

1. Time to register + install a new skill to one product < 60 seconds (local).
2. Time to replicate a skill to second product < 30 seconds.
3. Install command failure recovery without manual file surgery in >90% of expected adapter cases (post-stub phase).
4. Zero silent failures: all failed operations return explicit error.

## Risks and Mitigations

1. **Risk:** Product path/config drift across versions.
   - **Mitigation:** Adapter validation and versioned adapter capability checks.

2. **Risk:** Config patch mode may corrupt product config.
   - **Mitigation:** Pre-change backup, structured patching, rollback metadata.

3. **Risk:** Permission denials in user directories.
   - **Mitigation:** Up-front checks and actionable permission guidance.

4. **Risk:** Symlink mode incompatible with some products.
   - **Mitigation:** Adapter-declared supported modes and fallback to copy.

5. **Risk:** State inconsistency after interrupted operations.
   - **Mitigation:** Write-ahead temp files and atomic rename.
