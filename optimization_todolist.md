# SkillHub Optimization TodoList

## Phase 1: Stability & Compilation (Immediate)
- [ ] **Fix Sendable Conformance**: Update `SkillManifest` and `InstalledSkillRecord` in `SkillHubCore` to conform to `Sendable` to fix App build errors.
- [ ] **Command Alignment**: Update `SkillHubViewModel` to call CLI `add` instead of `register`.
- [ ] **Atomic Storage**: Refactor `SkillStore.save()` to use atomic file replacement and basic file locking.

## Phase 2: Refactoring & Cleanup (Architecture)
- [x] **Consolidate Models**: Remove duplicate `HealthStatus` and `DiagnosticIssue` from `SkillHubApp`, use the ones from `SkillHubCore`.
- [x] **Decouple ViewModel**: Extract `SkillService` and `ScanService` from `SkillHubViewModel`.
- [x] **Remove Stub Logic**: Replace `fatalError` in Adapters with proper error throwing.

## Phase 3: Robustness & DX
- [x] **Path Centralization**: Ensure all product paths are resolved only via Adapters.
- [x] **CLI Modularization**: Split `main.swift` in `SkillHubCLI` into separate command handlers.
- [x] **Schema Validation**: Add formal schema validation for `configPatch` operations.
