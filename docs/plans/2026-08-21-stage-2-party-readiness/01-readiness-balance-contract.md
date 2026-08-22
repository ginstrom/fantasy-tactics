# Step 1 — Readiness Balance Contract

**Branch:** `docs/stage-2-readiness-contract`
**Depends on:** clean `main`
**Milestone:** Canonical design and shipped balance configuration name every number and effect required for Stage 2, with explicit user approval before runtime code changes.

## Files

- Modify: `docs/designs/class-system.md`
- Modify: `docs/designs/campaign-loop.md`
- Modify: `docs/designs/monster-manual.md`
- Modify: `config/game_config.json`
- Modify: `tests/unit/test_game_config.gd`
- Modify: `tests/unit/test_localization.gd` only if approved player-visible names/descriptions are added now

## Setup

```bash
git checkout main && git pull
git checkout -b docs/stage-2-readiness-contract
make check
```

## Decision record

Before editing runtime code, present the following one-page decision table to the user and record the approved values in the canonical documents and `GameConfig`:

| Required decision | Record exactly |
|---|---|
| Warrior/Scout/Cleric perk trees | IDs, display names, class ownership, level/prerequisite rules, one concrete shipped effect, and any excluded future primitives. |
| Perk selection behavior | Eligible options, duplicate policy, whether an unchosen option remains available at a later slot, and the UI rule when no legal option exists. |
| Automatic progression/baseline | Starting values and deterministic/injected gain ranges for owned skills; the updated Warrior comparison rows and monster targets. |
| Durable Cleric MP | base/max MP, battle-start and battle-aftermath semantics, per-mode recovery rates, and save migration default. |
| Natural recovery | exact moving/resting/Encampment HP and MP rates; Temple HP bonus; cap behavior. These must supersede the inconsistent current `HEAL_RATE_*` values. |
| Details-view heal | MP cost, HP restored, legal targets, failure/no-op semantics, and player-visible feedback. |

Keep the first shipped perk set deliberately small: each effect must be expressible through an already-supported primitive (AP, max HP, raw might, guard, resistance, spell range/cost, or Scout intel range). Mark perks requiring dodge, penetration, reactions, control, or a new combat action as deferred, rather than naming an effect no code can safely deliver.

## Red/green tasks

1. Update the three canonical design documents with a single Stage 2 “locked values” table. Replace phrases such as “exact values are deferred” only for decisions actually approved; retain all out-of-scope future systems as deferred.
2. Add the approved tunables beneath the appropriate `progression`, `healing`, and new `cleric` sections of `config/game_config.json`. Do not put mutable adventurer state in `GameConfig`.
3. Add failing `test_game_config.gd` assertions for every new required key and fallback lookup. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_config.gd -gexit
   ```

   Expected: fail until the JSON keys and defaults are synchronized.
4. Add only the matching `GameConfig.DEFAULTS` values required to make the configuration test green. Do not add progression, recovery, or UI behavior in this documentation step.
5. Run:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

## Manual signoff

Review the table with the user. Confirm each perk uses an available primitive, the MP/recovery math is capped and explainable, and the Tier 1–3 role patterns have a named preparation decision. Record the approved values in the commit message/body or implementation handoff.

## Commit and local merge

After user signoff, stage only the edited canonical docs, config, and tests; commit `docs(readiness): lock stage two balance contract`, merge locally to `main`, and delete `docs/stage-2-readiness-contract`. Do not push or open a PR.
