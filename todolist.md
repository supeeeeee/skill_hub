# SkillHub Lifecycle & UI Clarity Refactor - TODO

## 1. UI/UX Clarity & Naming Standardization
- [ ] **Standardize Terminology:** Unified naming across UI and logs:
    - `Register`: Adding a skill to the library (currently `Add`).
    - `Install`: Staging files + Adapter binding (currently `Setup` / `Apply`).
    - `Enable/Disable`: Activating/Deactivating an installed skill.
- [ ] **Improve Status Indicators:** Use more distinct icons/colors for the 4 lifecycle stages (Registered, Staged, Installed, Enabled).

## 2. Skills View (Asset Management Center)
- [ ] **Installation Badges:** Add badges or icons to skill cards in the main Skills list to show which products the skill is currently installed in.
- [ ] **Consumption Summary:** In `SkillDetailView`, list all products and the specific status of the skill for each.

## 3. Product Detail View (Product Configuration Center)
- [ ] **Two-Section Layout:** Separate the skills list into:
    - **Active Skills:** Skills already installed/enabled for this product.
    - **From Library:** Skills registered in SkillHub but not yet installed for this product.
- [ ] **Contextual Actions:** 
    - In "Active Skills": Only show Enable/Disable/Uninstall.
    - In "From Library": Show "Install to Product".

## 4. Backend & Model Refinement (SkillHubViewModel)
- [ ] **Enhanced Result Handling:** Refine `installSkill` and `setSkillEnabled` to return rich state objects.
- [ ] **Product-Specific Skill Filtering:** Add computed properties to easily fetch "unbound" skills for a specific product.

## 5. Implementation Notes
- Use `opencode` with `gemini-3-flash-preview` (Gemini 3) for all code changes.
- Ensure `ProductDetailView` and `SkillsView` logic are strictly separated.
