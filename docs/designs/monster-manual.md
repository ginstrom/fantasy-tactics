# Monster Manual

## Purpose and status

This is the long-term monster roster and a balance contract for adding it in slices. It describes monsters in the same shared tactical vocabulary as adventurers, but does not make every entry live. The current initial roster is Kobold, Goblin, Orc, and Hobgoblin; future families are added only alongside an encounter, AI behaviour, rewards, and automated balance evidence.

The canonical monster data is eventually a template table owned by `GameSession`, copied into a runtime `Unit` at battle start. A monster has no adventurer progression, equipment inventory, or mutable template state.

## Calibration baseline

The current shipped values below are calibrated against a fresh Warrior with the
starter gear, before perks or upgraded equipment. They are a compatibility
baseline for the still-live manual skill-point system, not the target
automatic-skill progression model:

| Baseline | max_health | accuracy | guard | resistance | mobility | attack |
|---|---:|---:|---:|---:|---:|---|
| Level 1 Warrior | 10 | 60 | 10 | 10% | 3 | Iron Longsword, 1–8 (mean 4.5) |
| Level 2 Warrior, unspent points | 20 | 60 | 10 | 10% | 3 | Iron Longsword, 1–8 (mean 4.5) |
| Level 2 Warrior, all 10 points in Accuracy | 20 | 70 | 10 | 10% | 3 | Iron Longsword, 1–8 (mean 4.5) |

The current campaign awards level 2 at 20 XP and grants 10 skill points; it does
not force a player to spend them. Both level-2 rows are therefore valid current
test baselines. When automatic class-owned skills replace manual spending, this
table must be recalibrated from the Warrior's declared automatic progression;
the manual-Accuracy row must be removed rather than retained as a player
choice. These tables assume flat, open terrain and no healing, perks, party
allies, or upgraded equipment.

For rough review, use expected damage per attack (hit chance multiplied by post-Resistance damage) and expected player attacks to defeat. These are comparison tools, not an auto-balance rule: movement, terrain, enemy count, and player choices can deliberately change an encounter's difficulty.

## Shared monster profile

| Field | Meaning |
|---|---|
| `id`, `name_key` | Stable data and localization identity. |
| `tier` | Encounter danger grouping; it is not a level. |
| `max_health`, `might`, `accuracy`, `guard`, `resistance`, `mobility` | Shared tactical attributes. |
| `attacks` | One or more natural/weapon attacks with name, range/tags, and damage range. |
| `abilities` | Explicit, data-defined behaviours; empty until a slice implements them. |
| `kill_xp`, `loot_id` | Campaign reward contract. |
| `role` | Human-readable encounter purpose, such as swarm, skirmisher, bruiser, or elite. |

## Initial roster — preserve shipped values

The initial migration gives every monster `might: 0`, `guard: 0`, `resistance: 0`, and `mobility: 3`. Its attack damage stays exactly as the current game: the new model documents it as a fixed natural/weapon range. This prevents a schema migration from being a stealth rebalance.

| Monster | Tier / role | HP | Accuracy | Might | Guard | Resistance | Mobility | Attack | Kill XP |
|---|---|---:|---:|---:|---:|---:|---:|---|---:|
| Kobold | 3 / swarm | 6 | 25 | 0 | 0 | 0% | 3 | Rusty Dagger, 1–1 | 3 |
| Goblin | 1 / skirmisher | 13 | 30 | 0 | 0 | 0% | 3 | Short Sword, 2–2 | 5 |
| Orc | 2 / bruiser | 22 | 50 | 0 | 0 | 0% | 3 | War Axe, 3–3 | 10 |
| Hobgoblin | 3 / elite | 30 | 60 | 0 | 0 | 0% | 3 | Two-Handed Sword, 4–4 | 20 |

### What the numbers mean against the baseline

| Monster | Level-1 Warrior expected attacks to defeat | Expected damage to L1 Warrior per monster attack | Interpretation | Level-2 expectation |
|---|---:|---:|---|---|
| Kobold | 2.2 | 0.15 | Individually weak; threatening as a 4–8-unit swarm. | A swarm remains a positioning test, not a solo duel. |
| Goblin | 4.8 | 0.40 | Introductory solo enemy; player-favoured but not free. | Reliably cleared alone. |
| Orc | 8.1 | 1.20 | Near-even solo bruiser for a fresh Warrior. | Current manual-Accuracy investment makes this more favourable; recalibrate for automatic skills. |
| Hobgoblin | 11.1 | 2.00 | Elite; defeats an unprepared level-1 Warrior in a straight duel. | Dangerous solo target; intended for a formed party or better gear. |

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
| Wolf | fast flanker | Mobility/pack AI |
| Giant Spider | control skirmisher | status effects and cleansing |
| Ogre | high-health bruiser | multi-party encounter pacing |
| Wraith | magical elite | spells, magical damage, or resistance rules |

## Addition checklist

Before adding a monster to live data, specify: its role; exact shared attributes and attack ranges; spawn count/encounter tier; rewards; its level-1 and level-2 Warrior matchup; the counterplay it expects; unit and encounter tests; headless simulation scenarios; and one manual `make play` verification.

Do not add a monster only because its name is present in this manual.
