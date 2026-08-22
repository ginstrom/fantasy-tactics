# Step 7 — Stage 2 Exit Gate

**Branch:** `test/stage-2-party-readiness-exit-gate`
**Depends on:** Step 6 merged
**Milestone:** A reproducible integration proof and recorded manual play evidence show that the three-role party is ready for Stage 3 without overstating balance certainty.

## Files

- Create: `tests/unit/test_stage_2_party_readiness.gd`
- Modify: `tests/unit/test_campaign_sim.gd` only if it lacks an assertion for the documented representative output
- Modify: `docs/dev/testing.md` only if a new persistent command/workflow needs documentation

## Red/green tasks

1. Write `test_stage_2_party_readiness.gd` using `before_each` reset and public session APIs. It must form a legal up-to-five mixed party, equip class-compatible gear, reach a deterministic perk slot, build a Temple/recruit Cleric, execute a details heal, advance capped HP/MP recovery, enter/retreat from a scenario battle with preserved aftermath, and export/import the result.
2. Include one `ScenarioContract`/`BattleStateFactory` fixture per Tier 1–3 pattern. Assert class resources, hydrated equipment/profile values, target-priority outcome, and seeded result—not a subjective “balance passed” claim.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stage_2_party_readiness.gd -gexit
   ```

   Expected: fail until an actual cross-boundary defect is fixed. Do not broaden scope or weaken an assertion to accommodate a regression.
4. Make only demonstrated repairs, rerun focused tests, then execute:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Preserve the terminal output with the implementation handoff. `make campaign-sim-sweep` may supplement investigation but never substitutes for representative-seed evidence.

## Manual exit-gate signoff

From a fresh `make play` campaign, recruit/form a Warrior–Scout–Cleric party, make one perk selection per eligible role, build/use the Temple, use campaign healing and recovery, inspect Scout intel before a Tier 2 battle, equip armour/resistance and a potion, and play a Tier 3 mixed force. Confirm each role reads distinctly and that save/load plus retreat aftermath preserve HP, MP, items, and legal recovery. Capture screenshots only for a disputed UI/readability issue.

## Commit and local merge

After user signoff, stage the new exit-gate test and only changed optional test/doc files; commit `test(campaign): prove stage two party readiness`, merge locally to `main`, and delete `test/stage-2-party-readiness-exit-gate`. Do not push or open a PR.
