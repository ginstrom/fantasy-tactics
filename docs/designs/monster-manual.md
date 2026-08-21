# Monster Manual

## Purpose and status

This is the long-term monster roster and a balance contract for adding it in slices. It describes monsters in the same shared tactical vocabulary as adventurers, but does not make every entry live. The current initial roster is Kobold, Goblin, Orc, and Hobgoblin; future families are added only alongside an encounter, AI behaviour, rewards, and automated balance evidence.

The canonical monster data is eventually a template table owned by `GameSession`, copied into a runtime `Unit` at battle start. A monster has no adventurer progression, equipment inventory, or mutable template state.

## Campaign encounter contract

The first completable campaign uses twelve required authored battles: three in
each of tiers 1–3, two pre-boss battles, and a final boss. An authored
encounter declares its objective id, exact composition, prerequisite, reward,
intended counterplay, and loss consequence. Repeatable vacancies are
post-victory free-play content and cannot supply a required campaign battle or
reopen a completed objective.

Monster threat rises at a campaign pace and appears on the World Map as a
one-to-five-star risk indicator. It is separate from this manual's `tier`,
which groups encounter design purpose. See the [Borderlands Campaign Loop](campaign-loop.md#objectives-gates-and-encounter-threat) for campaign gates.

## Calibration baseline

The current shipped values below are calibrated against a fresh Warrior with the
starter gear, before perks or upgraded equipment. They are a compatibility
baseline for the still-live manual skill-point system, not the target
automatic-skill progression model:

| Baseline | max_health | melee | guard | resistance | movement range | attack |
|---|---:|---:|---:|---:|---:|---|
| Level 1 Warrior | 10 | 60 | 10 | 10% | 3 | Iron Longsword, 1–8 (mean 4.5) |
| Level 2 Warrior, automatic skills | 20 | 63–64 (mean 63.5) | 11–12 (mean 11.5) | 10% | 3 | Iron Longsword, 1–8 + might 3–4 (mean gain 3.5) |

The current campaign awards level 2 at 20 XP. Automatic class-owned skills
(`CLASS_DEFINITIONS.warrior.skills`) replace manual point spending: melee,
guard, and might each roll their tier's gain range independently
(melee/might "med" 3–4, guard "low" 1–2), and `max_health` is
`vitality × level` (10 × 2 = 20). The row above uses each roll's mean for a
single reproducible comparison baseline; guard also includes the starting
leather armor's +10. Might now adds to every raw damage roll (mean 4.5 + mean
3.5 = mean 8.0 per hit), which the retired manual-Accuracy-only row never
modeled — automatic Might is why the level-2 matchups below are
substantially stronger than the old comparison table. These tables assume
flat, open terrain and no healing, perks, party allies, or upgraded
equipment.

For rough review, use expected damage per attack (hit chance multiplied by post-Resistance damage) and expected player attacks to defeat. These are comparison tools, not an auto-balance rule: movement, terrain, enemy count, and player choices can deliberately change an encounter's difficulty.

## Shared monster profile

Monsters possess all the same tactical attributes as adventurer units, though attributes non-applicable to a specific monster type are set to `0` (e.g., `spellcasting: 0` for Goblin Warriors). The exact same battle mechanics apply to units and enemies alike, and certain enemy types (such as Brigands) use standard unit class profiles.

| Field | Meaning |
|---|---|
| `id`, `name_key` | Stable data and localization identity. |
| `tier` | Encounter danger grouping; it is not a level. |
| `max_health`, `might`, `melee`, `missile`, `guard`, `spellcasting`, `magic_resistance`, `resistance`, `action_points` | Shared tactical attributes matching adventurer unit profiles. |
| `attacks` | One or more natural/weapon attacks with name, range/tags, and damage range. |
| `abilities` | Explicit, data-defined behaviours; empty until a slice implements them. |
| `kill_xp`, `loot_id` | Campaign reward contract. |
| `role` | Human-readable encounter purpose, such as swarm, skirmisher, bruiser, or elite. |

### Stage 2 locked values (2026-08-21, recalculated for class progression and perks)

Recalibrated Level-2 Warrior matchups under automatic skills, replacing the
deprecated manual-Accuracy comparison, using the same mean-of-range baseline
as the Calibration Baseline table above (melee 63.5%, guard 11.5, raw damage
8.0 — max_health 20 is exact either way, since it is `vitality × level`
rather than a rolled skill). This mean is now backed by a real deterministic
regression rather than a hand-derived approximation:
`test_deterministic_level_two_warrior_baseline_matches_monster_manual_table()`
(tests/unit/test_game_session.gd) pins two separate sessions'
`skill_gain_roll` — one always taking each skill's minimum gain, one always
taking its maximum — and averages the two genuinely deterministic outcomes
(e.g. melee's "med" tier, min 3 / max 4, averages to the same 63.5 this
table uses), reproducing this baseline from real code instead of an
un-exercised approximation. The same test also locks in this table's own
comparison-figure convention: Guard reduces the monster's hit chance
directly, but Resistance is not applied to the "damage to Warrior" column
(verified against this doc's own pre-existing Level 1 baseline numbers,
which only match `(monster_hit_chance - guard / 100) * monster_mean_damage`,
not that formula times `(1 - resistance)` as well):

| Monster | Level-2 automatic-skill Warrior expected attacks to defeat | Expected damage to Warrior per monster attack |
|---|---:|---:|
| Kobold | 1.2 | 0.14 |
| Goblin | 2.6 | 0.37 |
| Orc | 4.3 | 1.16 |
| Hobgoblin | 5.9 | 1.94 |

## Initial roster — preserve shipped values

The initial migration gives every monster `might: 0`, `guard: 0`, `resistance: 0`, `spellcasting: 0`, `magic_resistance: 0`, and `action_points: 6`. Attack hit chances map to `melee` (or `missile` for ranged monsters). Its attack damage stays exactly as the current game: documented as a fixed natural/weapon range. This prevents a schema migration from being a stealth rebalance.

| Monster | Tier / role | HP | Melee | Missile | Might | Guard | Resistance | AP | Attack | Kill XP |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---:|
| Kobold | 3 / swarm | 6 | 25 | 0 | 0 | 0 | 0% | 6 | Rusty Dagger, 1–1 | 3 |
| Goblin | 1 / skirmisher | 13 | 30 | 0 | 0 | 0 | 0% | 6 | Short Sword, 2–2 | 5 |
| Orc | 2 / bruiser | 22 | 50 | 0 | 0 | 0 | 0% | 6 | War Axe, 3–3 | 10 |
| Hobgoblin | 3 / elite | 30 | 60 | 0 | 0 | 0 | 0% | 6 | Two-Handed Sword, 4–4 | 20 |

### What the numbers mean against the baseline

| Monster | Level-1 Warrior expected attacks to defeat | Expected damage to L1 Warrior per monster attack | Interpretation | Level-2 expectation |
|---|---:|---:|---|---|
| Kobold | 2.2 | 0.15 | Individually weak; threatening as a 4–8-unit swarm. | A swarm remains a positioning test, not a solo duel; automatic Might makes a level-2 Warrior nearly one-round it solo (1.2 attacks, see the Stage 2 locked table above). |
| Goblin | 4.8 | 0.40 | Introductory solo enemy; player-favoured but not free. | Reliably cleared alone (2.6 attacks). |
| Orc | 8.1 | 1.20 | Near-even solo bruiser for a fresh Warrior. | Automatic Might makes this clearly favourable for a level-2 Warrior (4.3 attacks vs. 8.1 at level 1). |
| Hobgoblin | 11.1 | 2.00 | Elite; defeats an unprepared level-1 Warrior in a straight duel. | Dangerous solo target; intended for a formed party or better gear (5.9 attacks at level 2, still elite-tier). |

Expected attacks to defeat use the Warrior's 60% Accuracy and 4.5 mean
Longsword damage. Expected incoming damage applies the Warrior's 10 Guard and
10% Resistance. The automatic-skill implementation must replace this
manual-investment comparison with reproducible level-2 Warrior values.

## Encounter use by slice

| Slice | Monsters enabled | Composition purpose | New design question |
|---|---|---|---|
| **Shipped** | Goblin, Orc; Kobold/Hobgoblin in tier-3 composition | Solo tutorial, bruiser, swarm, elite | Do current full-party counts feel legible? |
| Shared-attribute migration | same four | Preserve the table above | Can naming/data migration pass existing combat simulations unchanged? |
| Ranger | Kobold, Goblin, new ranged skirmisher | open lanes and protected threats | Can ranged pressure be answered by positioning? |
| Cleric | Orc, Hobgoblin, new debuffer | sustained attrition | Does support extend survival without trivializing encounters? |
| Mage | swarms plus new resistant/control enemy | area damage and spell counters | Does each spell have a readable counter? |
| Specializations | selected variants, never silent stat inflation | compositional puzzles | Do roles remain distinct across party builds? |

## Future monster families

These are a backlog, not spawnable content. Each family must enter through a separate slice with an encounter template, art/name localization, loot, AI behaviour, tests, and level-1/level-2 Warrior comparison.

| Family | Intended role | First new primitive required |
|---|---|---|
| Bandit | armed humanoid mirror | ranged attack or Guard-focused gear |
| Skeleton | resistant undead | Resistance and Cleric interaction |
| Wolf | fast flanker | movement/pack AI |
| Giant Spider | control skirmisher | status effects and cleansing |
| Ogre | high-health bruiser | multi-unit party encounter pacing |
| Wraith | magical elite | spells, magical damage, or resistance rules |

Additionally, we will add skirmisher/archer versions of kobold/goblin/orc/hobgoblin equipped with slings (kobold) or bows (short for goblin, otherwise longbows)

## Addition checklist

Before adding a monster to live data, specify: its role; exact shared attributes and attack ranges; spawn count/encounter tier; rewards; its level-1 and level-2 Warrior matchup; the counterplay it expects; unit and encounter tests; headless simulation scenarios; and one manual `make play` verification.

Do not add a monster only because its name is present in this manual.
