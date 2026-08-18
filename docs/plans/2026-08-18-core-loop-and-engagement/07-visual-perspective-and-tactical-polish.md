# Step 7: Presentation Pass — 3/4 Top-Down Perspective and Tactical Visual Polish

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/visual-perspective-and-polish`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Execute the visual engagement and clarity pass following the mechanical stability proven in Steps 1–6. Apply placeholder assets that clearly read as a **3/4 top-down perspective** across the tactical Battlefield and World Map, without changing the established square-grid coordinate, pathfinding, or input model. Implement high-contrast **Floating Combat Text** and visual indicators that explain existing rules.

---

## Technical Design

### 1. 3/4 Top-Down Perspective Standardization (`scripts/battle/battle_controller.gd`, `scenes/world/world_map.tscn`)
- Keep the existing angled orthogonal logical grid. Use placeholder sprites, ground shadows, baseline anchors, and depth ordering to produce the approved 3/4 top-down read; do not adopt an isometric/dimetric coordinate transform.
- Capture Battlefield, World Map, and Encampment screenshots with `make screenshots`; owner confirms the three required views read as 3/4 top-down before this step merges.

### 2. Floating Combat Text System (`scenes/battle/floating_text.tscn`, `scripts/battle/floating_text.gd`)
- Add a lightweight, pooled `FloatingText` component that spawns over target units:
  - **Damage:** Red text (e.g. `"-14"`), rises and fades over 0.6s.
  - **Critical Hit:** Enlarged golden-yellow text with punch-scale animation (e.g. `"CRIT! -28"`).
  - **Healing:** Bright green text with cross icon (e.g. `"+12 HP"`).
  - **Miss / Evade:** Gray text (`"MISS"`).
  - **Guard Absorbed:** Blue shield text (`"BLOCKED"` or `"-6 (Guard)"`).
- Injectable / unit-testable signal `combat_text_spawned(pos: Vector2, text: String, type: String)`.

### 3. Wound State & Health Degrade Visuals (`scripts/battle/unit_info_panel.gd`, `scripts/battle/portrait_panel.gd`)
- Visual wound badges on unit battlefield representations and portrait frames:
  - **Healthy (100% - 51% HP):** Standard health bar (green).
  - **Wounded (50% - 21% HP):** Amber health bar + blood drop wound badge.
  - **Critical (20% - 1% HP):** Pulsing red health bar + severe trauma badge.
  - **Slain (0 HP):** Skull icon / darkened defeated sprite before aftermath cleanup.

### 4. World Map Fog & Strategic Scouting Visuals (`scripts/world/world_map.gd`)
- Do not add fog of war in this slice.
- When a deployed Scout is within three World Map squares of an encounter, render tier and composition badges; otherwise leave its marker location-only.

### 5. Encampment Building Tier Visual States (`scenes/ui/encampment.tscn`, `scripts/ui/encampment.gd`)
- Update Encampment building cards to visually reflect upgrades:
  - Guild Hall: Wooden lodge (Tier 1) → Fortified hall (Tier 2) → Grand Guild Castle (Tier 3).
  - Temple: Consecrated shrine (Tier 1) → Cathedral (Tier 2).
  - Shop: Market stall (Tier 1) → Trade house (Tier 2) → Grand Emporium (Tier 3).

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/visual-perspective-and-polish
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **Floating Combat Text Spawner ([`tests/unit/test_floating_text.gd`](../../../tests/unit/test_floating_text.gd) & [`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test floating combat text spawns on damage, critical hit, miss, and heal.
   - Test animation lifecycle: text rises, fades, and is freed/recycled without memory leaks.
   - Test correct color coding and text strings for damage, crits, and healing.

2. **Wound State Visual Indicators ([`tests/unit/test_portrait_panel.gd`](../../../tests/unit/test_portrait_panel.gd) & [`tests/unit/test_unit_info_panel.gd`](../../../tests/unit/test_unit_info_panel.gd)):**
   - Test wound badge state switches at 50% HP (Wounded) and 20% HP (Critical).
   - Test UI updates immediately when damage or healing is applied.

3. **World Map Scouting Overlay Visuals ([`tests/unit/test_world_map.gd`](../../../tests/unit/test_world_map.gd)):**
   - Test scouting intel overlay renders only when a deployed Scout is within three squares.
   - Test threat stars render with high-contrast palette.

4. **Encampment Building Visual States ([`tests/unit/test_encampment.gd`](../../../tests/unit/test_encampment.gd)):**
   - Test building card visual assets update according to building level.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. Run `make screenshots` and inspect the **Encampment**, World Map, and Battlefield captures:
   - Upgrade Guild Hall and Shop; confirm the building card visuals update to higher-tier artwork.
3. Deploy a party to the **World Map**:
   - Confirm the owner-approved 3/4 top-down perspective is consistent while routes and click targets retain their existing positions.
   - Hover over encounter sites and confirm the scout overlay displays clear, sharp text.
4. Enter combat on the **Battlefield**:
   - Attack an enemy unit: verify red floating damage numbers appear above the target with a smooth upward float.
   - Land a critical hit: verify golden `"CRIT!"` text with punch animation.
   - Cast Heal with Cleric: verify green healing text appears.
   - Miss an attack: verify `"MISS"` indicator.
   - Take damage on a player unit until below 50% HP and 20% HP: confirm portrait wound badges update immediately.

---

## Commit and Merge

```bash
git status --short
git add scripts/battle/battle_controller.gd scripts/battle/floating_text.gd scenes/battle/floating_text.tscn scripts/battle/portrait_panel.gd scripts/battle/unit_info_panel.gd scripts/world/world_map.gd scripts/ui/encampment.gd scenes/ui/encampment.tscn scenes/battle/battlefield.tscn translations/en.tres tests/unit/test_floating_text.gd tests/unit/test_battle_controller.gd tests/unit/test_portrait_panel.gd tests/unit/test_unit_info_panel.gd tests/unit/test_world_map.gd tests/unit/test_encampment.gd
git diff --cached --check
git commit -m "feat(presentation): implement 3/4 top-down perspective polish, floating combat text, and wound indicators"

# After user sign-off:
git checkout main
git merge feat/visual-perspective-and-polish
git branch -d feat/visual-perspective-and-polish
```

---

## Milestone (Concretely Verifiable)

- 3/4 top-down visual perspective is consistent across Battlefield and World Map.
- Floating combat text provides instant feedback for hits, crits, misses, and heals.
- Wound states and building tier upgrades are visually distinct and verified.
- `make check` passes 100% green.
