# SkillHub Product & UX Optimization Plan (Phase 4)

## 1. Terminology & Command Consolidation
- [ ] **Simplify CLI Commands**: Deprecate `stage`, `setup`, `apply` in favor of a clear 3-step model:
    - `add` (Register/Localize)
    - `deploy` (Install/Link to Product)
    - `enable` (Activate in Config)
- [ ] **UI Alignment**: Update `ContentView` and `SkillDetailView` to reflect this 3-step lifecycle.

## 2. Onboarding & Proactive Doctor
- [ ] **Automatic Health Check**: Trigger `ScanService.doctor()` on app launch.
- [ ] **Visual Doctor View**: Create a dedicated "Doctor" tab/view in the App to show issues and provide one-click "Fix All" buttons.
- [ ] **Sample Skill Auto-Suggest**: If no skills are present, show a "Welcome" view with a one-click button to install the `hello-world` sample skill.

## 3. Discovery & "Lite" Marketplace
- [x] **Discovery Tab**: Implement a "Discover" view in `ContentView`.
- [x] **Static Registry**: Seed the Discover view with a curated list of recommended skills (e.g., from a bundled `discovery.json`).
- [ ] **Remote Add**: Ensure the `Add` workflow handles HTTPS URLs smoothly with metadata preview.

## 4. Persona-Based UI (Simple/Pro)
- [x] **User Preference**: Add a `isAdvancedMode` toggle in a new Settings view.
- [x] **Conditional UI**: Hide "Install Mode", "Custom Paths", and "Config Patch" details unless `isAdvancedMode` is true.
- [ ] **Operation Plan**: Show a simple "What will happen" summary before performing destructive or config-changing actions.
