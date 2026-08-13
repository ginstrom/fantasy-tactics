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
| 1 | [01-onboarding-decision.md](01-onboarding-decision.md) | Record the initial-party/onboarding decision and implement it: generated instance ids for units and items, 4-warrior starting roster, four starting recruitment offers, party size/count caps with a Parties-screen indicator | — |
| 2 | [02-class-owned-skill-tracks.md](02-class-owned-skill-tracks.md) | Replace manual Attack-point allocation with automatic class-owned skill progression (melee/missile/guard/might tracks, vitality-derived max health), including save migration | — (no code dependency on step 1; the roadmap orders the decision first) |
| 3 | [03-baseline-healing-lifecycle.md](03-baseline-healing-lifecycle.md) | Persist battle damage and add natural/rest/encampment recovery across world turns | step 2 merged (step 3's save migration extends the nested snapshot-normalization pass step 1 introduces and step 2 extends; both also touch leveling UI, `game_config`, and the same test files) |

Each step file is self-contained: setup, red/green TDD task list,
verification, manual `make play` sign-off, commit, and merge-back to `main`.

## Grounding — current state of `main` (verified at 37d027b)

These facts drove the step designs; re-verify before starting each step:

- **Onboarding.** `start_new_game()` → `reset()` gives one Warrior
  (`warrior_001`), no party, 200 gold, and one recruitment offer
  (`warrior_002`). The player creates the first party (`create_party()`) and
  staffs it; `CAMPAIGN_GUIDE_SEQUENCE` guides the first loop. The vision
  (`docs/designs/vision.md` §Party management) says the player starts with a
  party of four. **Decided (2026-08-13):** the starting state becomes a
  4-warrior roster plus four recruitment offers (3 warriors, 1 scout) — see
  the Decisions section below and step 1. Supporting code facts:
  `RECRUITMENT_CANDIDATE_TEMPLATES` already holds exactly that offer pool
  (warrior_002/scout_002/warrior_003/warrior_004) with
  `RECRUITMENT_OFFER_CAP = 4`; `create_party()` hardcodes a single party;
  `get_max_party_size()` (Guild Hall level caps 4 → 5) is enforced by
  assignment; `scripts/ui/parties.gd` disables Create once any party exists.
- **Progression.** `_award_adventurer_xp()` grants `+LEVEL_UP_MAX_HEALTH_BONUS`
  (10) max health and `+LEVEL_UP_SKILL_POINTS` (10) skill points per level.
  `spend_attack_points()` converts skill points 1:1 into raw `stats.attack`
  (player-initiated, from the level-up overlay). Hit chance is
  `min(attack / 100, 0.95)` via `get_effective_hit_chance()`. Perks: one
  pending choice every `PERK_LEVEL_INTERVAL` (3) levels; only `bonus_move`
  exists. Balance constants load from `config/game_config.json`
  (`progression.*`) via `GameConfig`, locked key-by-key by
  `tests/unit/test_game_config.gd`.
- **Combat channels.** Hit resolution is
  `max(attacker hit_chance − target defense / 100, 5%)` in
  `battle_controller.gd`; player `defense` comes only from armor
  (`get_effective_defense()`). Ranged attacks are already shipped (Scouts
  equip bows with range 1–3/1–4), but one stored `attack` value feeds hit
  chance for every weapon category. Damage is
  `round((roll + raw_damage_bonus) × (1 − resistance / 100))` with no
  damage floor and no Resistance cap in code (armor values sit far below the
  design's 95% temporary cap). Monster units carry their own `hit_chance` /
  `defense` from templates and keep them in every step of this plan.
- **Classes.** `CLASS_DEFINITIONS` (warrior, scout) holds
  `allowed_weapon_categories` and `base_stats` only. Recruits are seeded from
  class baselines via `_seed_adventurer_baseline_stats()`.
- **Identity.** Every record already carries an `id` distinct from its
  display `name`, but ids are minted from class-derived sequential schemes
  (`warrior_%03d`, `blacksmith_item_%03d`, `encounter_%03d`) with
  collision-scanning loops (`recruit_adventurer()`,
  `_spawn_next_recruitment_offer()`), and recruitment template ids double as
  candidate ids (template claiming is implied by id collision;
  `purchase_recruit()` needs an id-collision guard because of it). Item
  instances already have the right shape — an instance record keyed by id
  with a `base_item_id` back-reference — but `materialize_banked_item_instance()`
  takes a caller-supplied id (test-only callers today). There is no
  generated-id helper anywhere yet; index constraint 6 governs what this
  plan introduces.
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
- **Design updates (2026-08-13).** `docs/designs/class-system.md` now splits
  the old `accuracy` attribute into `melee` and `missile` skills, adds
  `spellcasting`/`magic_resistance` as future Mage-slice attributes, defines
  a per-class skill-growth table (low 1–2 / med 3–4 / hi 4–5 points per
  level for might/melee/missile/guard/spellcasting), and states max health
  is calculated as vitality × level. `docs/designs/combat-system.md` defines
  to-hit as attack skill minus defense skill clamped 5%–95%, a 95% ceiling
  on damage resistance, generic action points, and the deferred mechanics
  (dodge, parry, cover, flanking, attacks of opportunity, scouting, line of
  sight). Step 2 implements the parts of this whose effect channels already
  exist in `main` (see its "Which skills ship" table); everything else stays
  future vocabulary per constraint 2.

## Constraints carried into every step

From the gap analysis, `docs/designs/class-system.md`, and
`docs/designs/combat-system.md`:

1. **Perk cadence is invariant.** One perk choice every third level;
   `bonus_move` stays the only shipped perk in this plan. Each step that
   touches leveling keeps (and regression-tests) this cadence.
2. **No deferred attributes become mechanics.** No critical hits, magic
   points, carrying capacity, luck rolls, or Strength/Agility/Intelligence/
   Piety/Luck attributes; no dodge, parry, cover, flanking, attacks of
   opportunity, scouting, or line of sight (all combat-system.md design
   intent without owning systems). New skills may only map to effect channels
   that already exist in `main` — today: melee/missile → hit chance (ranged
   attacks are shipped), guard → the defense subtraction in hit resolution,
   might → the raw-damage bonus slot. `spellcasting`/`magic_resistance` need
   a spell system and belong to roadmap part 2. The one sanctioned exception:
   per-class **vitality** derives max health in step 2 (designer decision,
   2026-08-13; the class design marks Vitality as needing no additional
   system).
3. **Skill tracks replace stored Attack.** Step 2 splits the live `attack`
   value into `melee`/`missile` and adds `guard`/`might` per the class
   design's tactical profile. No other renames: monster template fields and
   the armor `defense`/`resistance` fields keep their names (the guard skill
   adds to `get_effective_defense()` rather than renaming it).
4. **Live combat enemy data is unchanged.** No new enemies, encounters, or
   composition tables in this plan.
5. **Repo workflow** (`AGENTS.md`): plain branch off `main` (no worktrees),
   red/green TDD, `make check`, manual `make play` sign-off where the step
   calls for it, commit, local merge back to `main`, delete the branch.
   Never push.
6. **Instance identity is generated, never derived.** Every newly minted
   unit (starting-roster seed, recruitment offer, overflow offer, debug
   recruit) and every newly minted item instance gets a generated,
   collision-free id (GUID-style string) from one shared helper. Identity
   never depends on the display name or on class-derived sequential
   numbering; names stay purely cosmetic, ids are hidden from the player,
   and the collision-scanning machinery the sequential schemes required is
   deleted with them. Records that already exist keep their ids as opaque
   strings — no save-wide re-minting. The same rule binds later roadmap
   parts (e.g. party ids when multi-party arrives in part 4).

## Decisions (recorded 2026-08-13)

1. **Onboarding / initial party.** Start with 4 warriors in the roster and 4
   recruitable units (3 warriors, 1 scout). Maximum party size is 4 and
   maximum party count is 1; the player creates and mans a party before
   deploying. Implemented by step 1; recorded in `docs/gap-analysis.md`
   there.
2. **Second-party unlock deferred.** The Guild Hall level 2 → 3 upgrade that
   raises the party-count cap from 1 to 2 is a recorded progression rule but
   is **not** built in this plan — second-party creation and multi-party
   World Map behavior stay in roadmap part 4 (§2.1).
3. **Vitality-derived max health.** Step 2 replaces the flat +10 max health
   per level with per-class vitality (`max_health = vitality × level`), per
   the updated class design.

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
  specializations (part 2) — including `spellcasting`/`magic_resistance`
  mechanics and any perk branches that need them.
- Battlefield fog of war, perception, auto-combat, auto-resolve (part 3),
  and the rest of combat-system.md's deferred mechanics: dodge, parry,
  cover, flanking, attacks of opportunity.
- Multiple parties, formations, town buildings, trade routes, map fog
  (part 4) — including the Guild Hall level 2 → 3 party-count unlock and
  second-party creation recorded in decision 2 above. Step 1 implements only
  the caps and the starting roster the decision calls for.
- Dungeon exploration, narrative arc, endgame (part 5).
- Permadeath/injury states, out-of-battle potion healing as a required
  feature, Temple/Cleric healing modifiers (gap analysis §2.3 items 2–3).
- Re-tuning early encounters for a full four-member starting party — a
  consequence of the onboarding decision; campaign balance work that must
  respect constraint 4 (no encounter/composition changes in this plan).
  Step 1's evidence captures the current numbers for that future pass.
- Making the design's 95% Resistance ceiling and `max(1, damage)` floor
  configurable combat rules — required before any effect can modify
  Resistance, which nothing in this plan does.
- Migrating encounter-instance minting (`encounter_%03d` sequential scan)
  onto the generated-id rule of constraint 6 — nothing in this plan mints or
  renames encounter instances (constraint 4); convert them when the
  world-map threat work next touches that path.

## Plan lifecycle

Per `docs/dev/README.md`, dated plan directories are deleted once fully
merged. After step 3 merges, remove this directory in a small docs commit
(the recorded onboarding decision itself persists in `docs/gap-analysis.md`,
where step 1 writes it). Update the **Status** line above and the table in
each step file as steps complete.
