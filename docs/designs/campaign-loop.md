# Borderlands Campaign Loop

## Purpose and status

This document is the canonical design contract for the first completable
Borderlands campaign. It connects the tactical, party, Encampment, economy,
and World Map systems described elsewhere in `docs/designs/`. **Contract**
means a locked roadmap decision that a future slice must implement and test;
it is not a claim that the behaviour is already shipped. **Deferred** means
the roadmap deliberately leaves the feature-slice decision open.

## Campaign contract

The first campaign is a 60–90 minute arc of twelve required authored battles:
three tier-1 encounters, three tier-2 encounters, three tier-3 encounters, a
two-battle pre-boss sequence, and a final boss. Its loop is:

```text
Recruit and deploy -> clear the current objective -> return with loot
-> recover, equip, or upgrade the Encampment -> unlock the next objective
-> defeat the final boss -> optional free play
```

The campaign has exactly one active party, `party_001`. It begins with three
deployable slots. Guild Hall upgrades raise deployment capacity to four and
then five; they do not create additional active parties.

Each authored encounter declares a stable objective id, exact enemy
composition, prerequisite objective, reward, intended counterplay, and loss
consequence. Campaign state persists the current objective, completed
objective ids, unlocked authored encounters, final-victory state, and
post-victory free-play state. It is versioned and owned by `GameSession`.

Authored objectives never respawn or reopen when encounter vacancies refill.
After final victory, clearly labelled repeatable free play may fill vacancies,
but it never changes completed objectives or replays the victory screen.

## Objectives, gates, and encounter threat

A fresh campaign routes the player directly to party formation and states the
first objective. The campaign UI always communicates the current objective,
its next unlock, and the final victory condition.

Tier gates must be understandable preparation gates—not hidden numerical
thresholds. Tier 1 teaches formation, facing, flanking, and banking loot;
tier 2 tests scouting, ranged pressure, armour/resistance counterplay, and
potion use; tier 3 tests target priority against mixed forces. The final boss
tests the accumulated party composition, positioning, and Encampment upgrades.

Monster threat rises on a campaign pace that permits a party of five to reach
about level 6 and make several Encampment upgrades before the final boss. The
World Map displays the resulting threat as one to five stars. A star rating is
an encounter-risk signal, not an objective prerequisite and not a substitute
for the authored encounter definition.

## Stage 3 arc contract: the twelve authored nodes

Every number below is transcribed from `GameSession.CAMPAIGN_OBJECTIVES`/
`EXPEDITIONS`/`*_ENEMY_STATS`/`ENEMY_LOOT_TABLES` (see
`scripts/autoload/game_session.gd`) — none is invented here. "Threat/star" is
each node's `difficulty` field, which doubles as `get_threat_stars()`'s floor
value; the World Map may display a higher star count than this table states
once `world_turn` escalation applies (`get_threat_stars()`), but a node's
authored composition and reward never change with it.

| ID | Tier/★ | Composition | Intended counterplay | Clear XP | Kill XP (sum) | Mean loot gold* |
|---|---:|---|---|---:|---:|---:|
| `obj_tier1_1_goblin_outpost` | 1/★1 | Goblin×1, Kobold×2 | Formation vs. a mixed weak group; teaches focus-fire | 15 | 11 | 8.5 + 20 bonus |
| `obj_tier1_2_kobold_warren` | 1/★1 | Kobold×4, Kobold Slinger×1 | Swarm + one ranged threat; teaches AoE-adjacent positioning vs. numbers | 18 | 16 | 12.5 + 20 bonus |
| `obj_tier1_3_goblin_warcamp` | 1/★1 | Goblin×2, Goblin Archer×1 | Closing distance on a ranged skirmisher; teaches facing/flanking | 20 | 16 | 10.5 + 20 bonus |
| `obj_tier2_1_orc_outpost` | 2/★2 | Orc Bruiser×1, Goblin Archer×1 | Armored bruiser (10 guard/15 resist) + ranged pressure together | 30 | 18 | 9.5 + 40 bonus |
| `obj_tier2_2_orc_warband` | 2/★2 | Orc Bruiser×2 | Sustained attrition vs. two armored units; tests healing/potions | 35 | 24 | 12 + 40 bonus |
| `obj_tier2_3_brute_stronghold` | 2/★2 | Orc Bruiser×2, Goblin Archer×2 | Fortified position; terrain + potion use vs. a 4-unit mixed force | 40 | 36 | 19 + 40 bonus |
| `obj_tier3_1_hobgoblin_command` | 3/★3 | Hobgoblin Elite×1, Kobold Slinger×2 | Elite burst damage (5 guard/10 resist, 5 dmg) plus ranged escort | 55 | 32 | 12.5 + 60 bonus |
| `obj_tier3_2_mixed_forces_ambush` | 3/★3 | Hobgoblin Elite×1, Orc Bruiser×1, Goblin Shaman×1 | Target-priority puzzle: kill the ranged support (Shaman) before the two melee elites close | 60 | 44 | 17 + 60 bonus |
| `obj_tier3_3_ruined_fortress` | 3/★3 | Hobgoblin Elite×2, Orc Bruiser×2 | Full mixed force, no swarm padding; tests a formed, upgraded party | 65 | 72 | 27 + 60 bonus |
| `obj_preboss_1_borderlands_vanguard` | 4/★4 | Hobgoblin Elite×2, Goblin Archer×2, Kobold×1 | Five-unit gatehouse guard; volume-of-fire test before the honor guard | 90 | 63 | 24.5 + 80 bonus |
| `obj_preboss_2_borderlands_stronghold` | 4/★4 | Hobgoblin Champion×3, Orc Warlord×1 | Heaviest pre-boss elites (Champion: 8 guard/15 resist/6 dmg; Warlord: 12 guard/20 resist/7 dmg) | 100 | 125 | 28.5 + 80 bonus |
| `obj_boss_borderlands_ogre` | 5/★5 | Ogre×1 | Single 90-HP boss (15 guard/20 resist, 5–12 dmg); accumulated composition/positioning/upgrades test, not a swarm | 200 | 150 | 150 + 100 bonus |

\* "Mean loot gold" = per-kill `(gold_min+gold_max)/2 * gold_multiplier` summed
over the node's composition, from `ENEMY_LOOT_TABLES`, plus the mean of the
flat completion bonus `randi_range(18,22) * difficulty`. This is an
analytical expectation from shipped tables, not a measured average — Step 2
(`make campaign-sim` telemetry) is the authority on what parties actually
bank, since it also includes starting gold, Shop passive income, and gear
drops this estimate excludes.

### Arc totals

- **Total clear+kill XP across all 12 nodes**: 1335 (985 before the Ogre, 350
  from the Ogre alone).
- **Target level near 6 before the Ogre**: `award_party_xp` splits every
  award evenly across the party's *current* `member_ids` (capped by
  `get_max_party_size()`, i.e. Guild Hall tier — 3/4/5), and
  `get_level_xp_threshold(level)` is `5*level*(level+1)-10` (L6 = 200
  XP/member, from `GameSession.get_level_xp_threshold()`). Dividing the
  pre-Ogre total (985) by a constant party size across the whole arc gives:
  5 members throughout → 197 XP/member → level 5, three points under the L6
  threshold; 4 members throughout → 246 XP/member → level 6; 3 members
  throughout (never upgrading Guild Hall) → 328 XP/member → level 7. The
  locked target band is **level 5–7, centered on 6**, depending on Guild Hall
  tier reached.
- **Total expected gold before the Ogre**: starting gold (200) + mean
  kill/completion loot (≈701.5, from the table) + variable Shop passive
  income (2/5/10 gold per World Map Turn by Shop tier), which is not fixed
  here since it depends on turns taken. Treat ≈900 gold as an analytical
  floor, not a cap.
- **Encampment upgrade budget**: the full upgrade catalog totals 12 possible
  upgrade actions (`GUILD_HALL` to level 3 = 2 actions past its floor,
  `TEMPLE` = 1, `BLACKSMITH` = 3, `ALCHEMY_WORKSHOP` = 2, `RUNIC_WORKSHOP` =
  2, `SHOP` to level 3 = 2 — matching `get_campaign_victory_summary()`'s own
  `upgrades_completed` formula). How many of these 12 a winning run typically
  completes is deliberately left unspecified here; see "Stage 3 approval
  bands" below.

### Final encounter and free-play presentation (D8) — resolved

The following is **already shipped code**; this paragraph locks it into the
design contract as-is, not as a new decision:

- **Ogre formation**: a single `OGRE_ENEMY_STATS` unit (90 HP, 15 guard, 20%
  resist, 5–12 damage, 55% hit chance), fielded alone. No multi-Ogre or
  reinforcement-wave formation exists.
- **Victory screen**: headline "Campaign Victory!" / "The Borderlands Ogre
  falls."; five stats — World Turns Elapsed, Battles Won, Casualties, Gold
  Banked, Encampment Upgrades (`GameSession.get_campaign_victory_summary()`);
  Continue button reads "Continue in Free Play".
- **"Battles Won" is intentionally a total-battles-cleared count, not a
  12-battle counter**: `get_campaign_victory_summary()` reports
  `completed_encounters.size()`, which also includes the two starting sandbox
  encounters (`goblin_camp`/`orc_outpost`) and any `ruined_fortress` clears
  the player made alongside the 12-node ladder. This is approved, locked
  behavior — the victory screen deliberately credits every battle cleared on
  the way to victory, not only the required ladder.
- **Free play timing**: `is_free_play_active` flips true the instant
  `set_campaign_victory()` runs (i.e. the moment the Ogre dies), not when the
  player presses Continue — Continue only navigates to the Encampment.
- **Post-victory repeatable vacancies**: the same three sandbox templates used
  throughout the campaign (`goblin_camp`, `orc_outpost`, `ruined_fortress`) —
  there is no separate free-play-only template pool.
- **Required IDs never reappear**: enforced by `can_enter_encounter()` (an
  authored id, once in `completed_encounters`, can never be re-entered).
- **Reward summary text describes the real mechanical reward, not a
  guaranteed item**: each objective's `reward_summary_key` string
  (`translations/en.tres`) states that gold and salvage come from the
  cleared site, scaled qualitatively by difficulty, rather than promising a
  specific named item — the actual reward is always the random per-kill loot
  roll (`ENEMY_LOOT_TABLES`) plus the flat completion bonus
  (`randi_range(18,22) * difficulty`); no code path grants a fixed weapon,
  armor, or rune slot on objective completion.

## Stage 3 approval bands

`make campaign-sim` (Makefile) documents its representative seed set as "the
documented representative campaign seed set (4, 9, 10, 12, 14)" — this is
`CampaignSim.REPRESENTATIVE_VICTORY_SEEDS` (`scripts/tools/campaign_sim.gd`),
the single production-owned copy read by the CLI, the metrics/label layer,
and `test_campaign_sim.gd`'s
`test_run_campaign_reaches_victory_on_the_representative_seed_set()`.

| Band | Value | Source |
|---|---|---|
| Representative seed set | 4, 9, 10, 12, 14 | `CampaignSim.REPRESENTATIVE_VICTORY_SEEDS`, mirrored by `make campaign-sim` |
| Required victory count | 5/5 (all representative seeds) | Already the passing contract of `test_run_campaign_reaches_victory_on_the_representative_seed_set()` |
| Maximum simulated world turns (hard safety cap) | 400 | `CampaignSim.MAX_WORLD_TURNS` |
| Target party level at Ogre entry | 5–7, centered on 6 | Computed above from `get_level_xp_threshold()` against the 985 pre-Ogre XP total at 3/4/5-member party sizes |
| Allowed gold/resource range | `gold_earned` 800–1500 per representative seed; total `hp_recovered` (summed across a run's `objective_records`) 150–400 | Measured by `make campaign-sim` against the shipped state (all five representative seeds: `gold_earned` 1038–1135, `hp_recovered` total 264–293) and locked as a regression floor/ceiling with headroom by `test_campaign_sim.gd`'s `test_representative_seeds_earn_gold_and_recover_hp_within_the_measured_baseline_range()` |
| Allowed upgrade-count range | at least 6 of the 12 possible upgrade actions completed by victory, always including the Guild Hall level-1→3 cap, a built Temple, and a built Blacksmith | Measured: all five representative seeds complete exactly the same 7 (`guild_hall_level_2`, `guild_hall_level_3`, `blacksmith`, `blacksmith_level_2`, `blacksmith_level_3`, `temple`, `shop_level_2`) by victory. Locked as a regression floor (not the observed exact count, to leave headroom for legitimate small pacing shifts) by `test_campaign_sim.gd`'s `test_representative_seeds_complete_the_measured_floor_of_encampment_upgrades()` |

**Deviations requiring user approval**: a representative-seed victory count
below 5/5, **or** any change to the seed set itself (4, 9, 10, 12, 14) —
either one requires explicit user approval before proceeding, since the set
is a small, hand-verified list rather than a re-derivable sample (see
`REPRESENTATIVE_VICTORY_SEEDS`'s own doc comment). The gold/resource and
upgrade-count bands above are likewise the same kind of deviation gate: a run
that falls outside them requires the same approval, never a silent tuning
change.

Step 2 (Campaign telemetry and comparison) is the step that gathers real
`make campaign-sim` output and checks it against this contract — that step
fixed the bands that were already numerically grounded (seed set, victory
count, safety cap, target level) and deferred the gold/resource and
upgrade-count bands pending a first empirical run. Step 4 (Authored arc
economy and boss tuning) ran that empirical baseline (`make campaign-sim`
against the already-shipped state — no tuning was needed, since every
representative seed already met every band above) and filled in the two
rows this table left "not yet defined," each traceable to the measured
report and the new regression test that now locks it, per this row's
"Source" column.

## Stage 4 evidence and presentation contract

Stage 4 tunes pacing, comprehension, and presentation against the proven
Stage 3 campaign. This section is the approved measurement standard: what a
manual play session must record, how a repeated finding is decided, what
automated evidence is pinned alongside it, and what "readable 3/4
presentation and purposeful audio" (D9) means. No baseline collection or
tuning may begin until the user has explicitly accepted this section.

### Play-session protocol

| Decision | Value |
|---|---|
| Minimum complete fresh campaigns | Three, covering the whole Stage 4 arc (Step 2's baseline plus any Step 3–5 rechecks); record more whenever a finding needs a second independent confirmation before it counts as repeated |
| Who may play | The user (project owner) is the primary player. Any additional playtester requires the user's explicit approval per session and is recorded only under an anonymous session label (e.g. `S1`, `S2`) — no name, account, or other personal data is captured |
| Assistive settings permitted | The shipped in-game audio settings (Master/Music/SFX sliders and mute toggles, `scripts/ui/audio_settings.gd`) and ordinary OS-level accessibility features (e.g. display zoom, screen reader) that do not alter game state |
| Dev tools permitted | None during a counted session. The debug menu (`F9`), Super Power, and Recruit Adventurer are dev-only state shortcuts that would contaminate comprehension/pacing evidence; a session that used one is not a valid fresh-campaign record. The debug menu may only be used to abort and restart a session from New Game, never mid-session |
| Required checkpoints | New Game; each objective (entry and resolution); recovery/upgrade actions at the Encampment; Withdraw or Battle Retreat, when it occurs; defeat/wipe, when it occurs; save/load; victory; free play |
| Durable facts per checkpoint | Session label, build commit (`git rev-parse --short HEAD`), in-game World Map Turn, objective id (when applicable), the player's stated understanding of "what do I do next" and "what just happened" *before* being told, the observable outcome (win/loss/roll result/screen shown), and a screenshot or report path if one was captured |

Anonymous session labels only. No personal data (real names, accounts,
screen recordings of the player, etc.) is ever recorded in a session record
or finding.

### Automated comparison evidence

Every manual-session round is accompanied by the fixed, deterministic
`make campaign-sim` run over the representative seed set (`4, 9, 10, 12,
14`, `CampaignSim.REPRESENTATIVE_VICTORY_SEEDS`) — see [Stage 3 approval
bands](#stage-3-approval-bands). The Stage 3 5/5-victory requirement and its
gold/resource and upgrade-count bands must continue to hold; a regression is
a Stage 4 finding, not something Stage 4 is allowed to loosen. Preserve
every representative-mode report field this contract already relies on:
`gold_earned`, `hp_recovered`, `mean_party_level_curve`,
`mean_upgrade_progression_turns`, and `per_objective_summary`. A
`make campaign-sim-sweep` run is exploratory, labelled evidence only — it
never substitutes for the named representative-mode proof above.

### D9 — Presentation proof standard

D9 is an approval table, not an asset wish list. It states what a
first-time player must be able to identify at normal play scale, on the
named surface, using only what the shipped game already shows or plays —
never asset counts or art-direction preferences. Steps 3–5 may only change
implementation in service of the acceptance observation already approved
here; a new comprehension requirement is a new decision-log row, not an
inline addition during tuning.

| Player must identify | Surface | Acceptance observation |
|---|---|---|
| Party vs. enemy unit, and each unit's facing | Battlefield | Without hovering, the player can tell ally from enemy and read each unit's facing well enough to predict whether an attack would land as a flank |
| Hovered unit, selected unit, and which side is currently acting | Battlefield | The player can tell which unit the cursor is over, which unit is selected/queued to act, and — during the enemy phase — that the enemy is acting, without opening a separate panel to confirm |
| Range, target legality, and current action mode | Battlefield | Before committing, the player can tell move-and-attack range from dash-only range, which enemies are directly attackable vs. reachable only via move-and-attack, and whether Move/Attack/Contextual mode is active |
| Hit / miss / critical / heal / retreat result | Battlefield | Without reading the scrolling combat log, the player can tell an action just resolved as a hit, miss, critical, heal, or retreat, and roughly how much HP changed |
| Wound tier | Battlefield, Encampment | The player can read a unit's wound tier (Healthy/Wounded/Critical/Slain) for both allies and enemies at a glance, with the same tier meaning on both surfaces |
| Current objective, next unlock, and encounter threat | World Map, Encampment | Without opening a menu, the player can state the current objective, what unlocks next, and the relative threat of an available encounter |
| Music/SFX state | World Map, Battlefield, Encampment | By ear alone, the player notices the transition between exploration, combat, victory, and defeat music, and hears a distinct SFX for hit, miss, critical, heal, and retreat |

Settings requirement: the Master/Music/SFX sliders and mute toggles must
stay reachable from every screen a checkpoint above occurs on, and muting
audio must never remove the only signal for a gameplay-critical result.

Non-audio/non-colour-only cue requirement: every gameplay-critical result
above must pair colour with a text label, glyph, or icon — colour or audio
alone is never sufficient. This is already true of the shipped hit/miss/
critical floating text and the wound-tier glyph badges; Steps 3–5 must
preserve that pairing in any change and may not introduce a new
colour-only or audio-only signal for an item in this table.

## Encampment progression and economy floor

The Encampment is a fast, card-like strategic layer. Every building level must
show its cost, completion timing (immediate or world-turn), prerequisite, and
concrete unlock.

| Hub | Contract role |
|---|---|
| Guild Hall | General Warrior/Scout recruitment and party capacity. Tier 1 permits 10 roster members and 4 offers; tier 2 permits 15 and 6. When an arriving offer would exceed the cap, remove the oldest offer. |
| Temple | Cleric recruitment and recovery support. Each Temple tier adds 1 HP to Encampment natural recovery per World Map Turn; it does not change MP recovery. |
| Blacksmith and Workshops | Physical gear, potions, and rune upgrades; see the Equipment Handbook. |
| Shop and Stores | Sells loot and buys basic gear/provisions. It grants 2 gold per World Map Turn at tier 1, 5 at tier 2, and 10 at tier 3; the tier-3 contract includes 2–8 HP healing potions costing 20 gold. |

World Map Turns advance recovery, jobs, recruitment vacancies, and Shop income
even with no deployable party. Natural recovery is per adventurer, per World
Map Turn: a moving deployed adventurer recovers **1 HP and 2 MP**; a stationary
deployed adventurer recovers **2 HP and 4 MP**; and an adventurer at the
Encampment recovers **3 HP and 6 MP**, plus **1 HP for each Temple tier**. Thus
an Encampment with a tier-2 Temple restores 5 HP and 6 MP per turn. Recovery
cannot exceed the adventurer's maximum HP or MP. Only a class with an MP-backed
resource (Cleric) recovers MP; an adventurer with no `mp_max` always recovers
0 MP, which is a no-op, not an error. These rates live in
`config/game_config.json`'s `healing` section
(`moving_rate`/`resting_rate`/`encamped_rate` for HP,
`moving_mp_rate`/`resting_mp_rate`/`encamped_mp_rate` for MP,
`temple_hp_bonus_per_tier` for the Temple bonus) and supersede the previous
flat, Temple-blind `encamped_rate` of 4.

Cleric current MP is durable adventurer state, not a battle-local reset: a
battle start hydrates the battle unit's MP from the adventurer's durable
current/max MP (not always full), and battle aftermath writes the surviving
Cleric's remaining MP back, clamped to `cleric.mp_max` (3, `config/
game_config.json`). A dead adventurer owns no persisted MP record, the same
as HP. A save with no `mp_current` field migrates it to full (`mp_current =
mp_max`) on load.

A Healer is a deliberate recovery accelerator. The Healer's details view must
offer **Heal party member**: it targets a living member of that Healer's
deployed party, or a living adventurer at the Encampment when the Healer is
encamped, and spends the Healer's available MP to restore HP. The locked
values (`config/game_config.json`'s `cleric` section) match the existing
battle-local Heal spell exactly: **1 MP cost**, **2–8 HP restored** (random,
capped at the target's max HP). The action is a no-op — no MP spent, no HP
changed — when the Healer lacks 1 MP, the target is already at full HP, the
target is dead, or the target isn't a legal target (wrong party, or an
Encampment adventurer while the Healer is still deployed); the UI disables
the button and states the reason rather than allowing a failed attempt. A
future mana-recovery potion joins the healing potion line to speed MP
recovery.

Passing a World Map Turn is a legal, intentional recovery action, not a free
pause: it advances every stated world-turn system, including jobs, vacancies,
Shop income, and accepted Guild Hall quest timers. Future unquested-encounter
escalation will add further time pressure. The campaign must always permit an
affordable level-1 replacement and an accessible way to advance recovery after
bankruptcy or a wipe. Zero-gold, no-party, repeated-retreat, and wipe states
must lead to a legal replacement party rather than a soft lock.

## Defeat, death, and retreat

A unit at 0 HP is dead. At battle resolution, validate all aftermath state
before changing it, then remove the dead unit permanently. Its equipped,
carried, and unique modified items transfer atomically to the party loot pool;
after a successful retreat, that loot returns to the Encampment bank. A dead
id must not remain in party membership, item ownership, save data, or
battle-aftermath input.

**Battle Retreat** is an explicit player action available only after entering
the Battlefield. It ends the battle, discards all
unbanked/pending rewards, applies the nearest-enemy consequence below to each
surviving party member, and leaves the party at the encounter location.

| Nearest enemy distance | No remaining-HP loss | 10% loss | 50% loss | Death |
|---|---:|---:|---:|---:|
| 1–3 | 10% | 30% | 30% | 30% |
| 4–6 | 20% | 50% | 10% | 10% |
| 7+ | 50% | 30% | 10% | 10% |

The distance is measured when Battle Retreat resolves. Each row is a complete,
mutually exclusive per-unit outcome distribution and totals 100%.

After Battle Retreat, surviving members appear on the World Map at the
encounter location with their destination set to the Encampment. They travel
home over subsequent World Map Turns. The lower-risk pre-battle **Withdraw**
action is defined separately in [World Map and
Encounters](world-map-and-encounters.md#arrival-and-withdrawal).

A party wipe returns the party to the Encampment, permanently resolves deaths,
and loses all gold and loot. It also discards unbanked/pending rewards. It must
not erase completed campaign objectives or upgrades.

## Deferred roadmap decisions

The following are intentionally not implementation contracts yet:

- **Scout reconnaissance (D6):** discovery, scouting reveals, Watchtowers,
  and optional Guild Hall quests are defined in the [Intelligence
  System](intelligence.md). Their multi-party and time-escalation portions
  remain deferred from the first campaign implementation.
- **Cleric and Temple scope (D7):** the recovery and details-view healing
  contract above is locked, including exact MP cost, HP range, and targeting
  for the details-view heal. A targeted in-battle heal and temporary
  protection remain the proposed first slice; broader Temple effects beyond
  the HP recovery bonus above (e.g. a second Temple tier) remain to be
  decided.
- **Final encounter and free-play presentation (D8):** locked — see [Stage 3
  arc contract: the twelve authored
  nodes](#stage-3-arc-contract-the-twelve-authored-nodes)'s "Final encounter
  and free-play presentation" subsection above.
- **Presentation proof standard (D9):** resolved — see [Stage 4 evidence and
  presentation contract § D9 — Presentation proof
  standard](#d9--presentation-proof-standard). 3/4 top-down perspective and
  hybrid placeholder-to-custom assets remain roadmap goals; their concrete
  asset/audio implementation is a Step 5 decision, not this table.

## Related design documents

- [Game Vision](vision.md) gives the player-facing premise and long-term
  direction.
- [Battle Screen](battle-screen.md) places the Retreat control and tactical
  controls.
- [Combat System](combat-system.md) defines round-level combat rules.
- [Intelligence System](intelligence.md) defines discovery, scouting, and
  optional quest intelligence.
- [Classes](class-system.md), [Monster Manual](monster-manual.md), and the
  [Equipment Handbook](equipment-handbook.md) define the tactical choices that
  authored encounters and recovery use.
