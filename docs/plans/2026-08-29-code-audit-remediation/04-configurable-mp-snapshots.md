# Step 04 — Configurable MP snapshot validation

**Objective:** Validate saved MP against the same `GameConfig` class cap that
runtime uses, while preserving strict atomic rejection of malformed snapshots.

**Dependency:** Step 03 merged. **Branch:** `fix/configurable-mp-snapshots`.

## Files

- Modify: `scripts/save/campaign_snapshot.gd:735-748`
- Modify: `tests/unit/test_campaign_snapshot.gd` beside MP validation tests
- Inspect: `scripts/autoload/game_config.gd`, `scripts/autoload/game_session.gd:1790-1820`, and `config/game_config.json`

## Red/green TDD

1. In a test that safely overrides/reset-restores `GameConfig`, set Cleric or
   Mage `mp_max` above the compiled catalog value. Export/import a snapshot
   with that valid higher `mp_current` and assert success. Add a paired value
   one above the overridden cap and assert atomic rejection with unchanged live
   state. Keep static default-cap coverage intact.
2. Run red:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_snapshot.gd -gexit
   ```
3. Replace the static cap lookup in `_validate_mp_field()` with the existing
   fallback-safe `GameConfig` source used by runtime. `CampaignSnapshot` stays
   scene-tree-free and must not invent a second configuration cache.
4. Run focused green, `make check`, editor parse, and `git diff --check`.

## Review and merge

Reviewer verifies configuration reset even on test failure, default behavior,
upper-bound rejection, and snapshot atomicity. No manual game check is needed
for a pure persistence validation change. After user accepts the evidence,
commit `fix(save): validate MP against configured class caps`, merge locally,
delete the branch, and record the configuration seam used.
