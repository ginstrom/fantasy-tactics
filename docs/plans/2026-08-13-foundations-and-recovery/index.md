# Foundations and Recovery — Implementation Plan (Gap-Analysis Roadmap Part 1)

**Date:** 2026-08-13
**Status:** proposed
**Implements:** [`docs/gap-analysis.md`](../../gap-analysis.md) §4, roadmap step 1 —
*"Resolve foundations and recovery."*

## Scope

Roadmap part 1 requires, in the gap analysis's own words:

> Decide the initial party/onboarding target, define automatic class-owned
> skill tracks and their migration from manual Attack points, and add the
> baseline healing lifecycle. Keep perks at the existing every-third-level
> cadence; do not silently convert deferred attributes into mechanics.

That decomposes into three steps, executed in order:

| # | Step file | Summary | Depends on |
|---|---|---|---|
| 1 | [01-onboarding-decision.md](01-onboarding-decision.md) | Make the initial-party/onboarding difference an explicit, recorded product decision | — |
| 2 | [02-class-owned-skill-tracks.md](02-class-owned-skill-tracks.md) | Replace manual Attack-point allocation with automatic class-owned skill progression, including save migration | — (no code dependency on step 1; the roadmap orders the decision first) |
| 3 | [03-baseline-healing-lifecycle.md](03-baseline-healing-lifecycle.md) | Persist battle damage and add natural/rest/encampment recovery across world turns | step 2 merged (step 3's save migration extends step 2's nested snapshot-normalization pass; both also touch leveling UI, `game_config`, and the same test files) |

Each step file is self-contained: setup, red/green TDD task list,
verification, manual `make play` sign-off, commit, and merge-back to `main`.

## Grounding — current state of `main` (verified at c37990d)

These facts drove the step designs; re-verify before starting each step:

- **Onboarding.** `start_new_game()` → `reset()` gives one Warrior
  (`warrior_001`), no party, 200 gold. The player creates the first party
  (`create_party()`) and staffs it; `CAMPAIGN_GUIDE_SEQUENCE` guides the
  first loop. The vision (`docs/designs/vision.md` §Party management) says
  the player starts with a party of four.
- **Progression.** `_award_adventurer_xp()` grants `+LEVEL_UP_MAX_HEALTH_BONUS`
  (10) max health and `+LEVEL_UP_SKILL_POINTS` (10) skill points per level.
  `spend_attack_points()` converts skill points 1:1 into raw `stats.attack`
  (player-initiated, from the level-up overlay). Hit chance is
  `min(attack / 100, 0.95)` via `get_effective_hit_chance()`. Perks: one
  pending choice every `PERK_LEVEL_INTERVAL` (3) levels; only `bonus_move`
  exists. Balance constants load from `config/game_config.json`
  (`progression.*`) via `GameConfig`, locked key-by-key by
  `tests/unit/test_game_config.gd`.
- **Classes.** `CLASS_DEFINITIONS` (warrior, scout) holds
  `allowed_weapon_categories` and `base_stats` only. Recruits are seeded from
  class baselines via `_seed_adventurer_baseline_stats()`.
- **Healing.** There is no persistent current health: `battle_controller.gd`
  creates player units at `get_effective_max_health()` and `unit.gd` starts
  `health = max_health`; nothing writes post-battle health back, and
  `end_world_turn()` performs no recovery. Potions heal only during battle
  (`try_use_potion()` path, 2 AP). `availability_status` is always
  `"available"`.
- **Saves.** `CampaignSnapshot.FORMAT_VERSION = 1` with all-or-nothing
  validation in `from_dictionary()`. Post-v1 fields were added *without*
  bumping the version by normalizing absent keys to defaults (workshop
  jobs, `shop_level` inference, owned instances) — steps 2 and 3 reuse this
  pattern. Adventurer lists are currently validated at id level only
  (`_normalize_id_list()`), so nested-record defaults need a small new
  normalization pass.
- **Balance tooling.** `make simulate` (scene-driven battles, JSONL outcomes)
  and `make scenario` (deterministic, seed-pinned scenario runner over
  `scenarios/battle/*.json`; schema covered by `test_scenario_contract.gd`,
  leveled units by `battle_state_factory.gd`). Generated reports are local
  evidence, never committed.

## Constraints carried into every step

From the gap analysis and `docs/designs/class-system.md`:

1. **Perk cadence is invariant.** One perk choice every third level;
   `bonus_move` stays the only shipped perk in this plan. Each step that
   touches leveling keeps (and regression-tests) this cadence.
2. **No deferred attributes become mechanics.** No dodge, critical hits,
   magic points, carrying capacity, luck rolls, or Strength/Agility/etc.
   attributes. New skills may only map to effect systems that already exist
   in `main` (today: raw Attack → hit chance). Skills needing a new effect
   system (scouting, spellcasting) belong to roadmap part 2.
3. **No tactical-stat rename.** The live model keeps its stored `attack` /
   `defense` names (gap analysis: a migration to `accuracy`/`guard` "is not
   required merely to add a new feature").
4. **Live combat enemy data is unchanged.** No new enemies, encounters, or
   composition tables in this plan.
5. **Repo workflow** (`AGENTS.md`): plain branch off `main` (no worktrees),
   red/green TDD, `make check`, manual `make play` sign-off where the step
   calls for it, commit, local merge back to `main`, delete the branch.
   Never push.

## Shared setup for every step

```bash
git checkout main && git pull
git checkout -b <branch-name-from-step-file>
make check   # confirm a green baseline before touching anything
```

## Shared definition of done for every step

- `make check` passes (full GUT suite).
- The step's scenario/balance evidence was generated and matches its gate
  (reports stay local; summarize numbers in the commit body or PR notes).
- Manual verification performed and signed off by the user where the step
  requires it.
- One commit on the branch, merged locally back to `main` after sign-off;
  branch deleted. Do not push.
- Developer docs updated where the step changes documented behavior
  (`docs/dev/code-map.md` domain-model and progression sections, plus the
  gap-analysis status notes in this index).

## Out of scope (belong to later roadmap parts)

- Scout reconnaissance loop, Cleric, Mage, ability primitive,
  specializations (part 2).
- Battlefield fog of war, perception, auto-combat, auto-resolve (part 3).
- Multiple parties, formations, town buildings, trade routes, map fog
  (part 4) — including any *implementation* of a different starting party
  size; step 1 only records the decision.
- Dungeon exploration, narrative arc, endgame (part 5).
- Permadeath/injury states, out-of-battle potion healing as a required
  feature, Temple/Cleric healing modifiers (gap analysis §2.3 items 2–3).

## Plan lifecycle

Per `docs/dev/README.md`, dated plan directories are deleted once fully
merged. After step 3 merges, remove this directory in a small docs commit
(the recorded onboarding decision itself persists in `docs/gap-analysis.md`,
where step 1 writes it). Update the **Status** line above and the table in
each step file as steps complete.
