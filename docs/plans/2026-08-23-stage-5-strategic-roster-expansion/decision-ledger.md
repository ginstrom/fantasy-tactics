# Stage 5 Decision & Evidence Ledger

Dated 2026-08-23. Created by Step 1
([01-stage-5-readiness-and-decision-contract.md](01-stage-5-readiness-and-decision-contract.md)).
This is the durable record of what already exists in the shipped codebase,
and the gate that every later Stage 5 step's product decisions must clear
before its branch starts. Update this file in place as each step's decisions
are approved; do not delete earlier rows.

## Protected baseline evidence (2026-08-23, before any doc change this step)

Run from a clean `main` at commit `590da0b` (Stage 4 exit-gate signoff).
Full logs kept locally outside Git at
`/tmp/claude-1000/-home-ryan-play-fantasy-tactics/e2323559-6e0b-4d2f-8996-ef7f01069b5f/scratchpad/stage5-step1/`
(`campaign-sim.log`, `check.log`, `editor.log`) — not committed.

| Command | Result |
|---|---|
| `make campaign-sim` | 5/5 representative-seed victories (seeds 4, 9, 10, 12, 14); 0 wipes, 0 stalemates, 12/12 battles won per run |
| `make check` | 78 scripts, 1833/1833 tests passing, 0 orphans beyond the 1 pre-existing known orphan, exit 0 |
| `godot --headless --path . --editor --quit` | exit 0, no import/scan errors |
| `git diff --check` | clean (no changes yet) |

These match the numbers recorded in the Stage 4 exit-gate signoff
(`docs/plans/2026-08-23-stage-4-engagement-presentation/index.md`), confirming
the checkout is the same baseline Stage 4 signed off on.

## Seam / absence evidence by feature area

File:line citations below are current as of commit `590da0b`. Re-verify
before relying on a citation in a later step — code moves.

### Intelligence, Watchtowers, Guild Hall quests

**Exists:** `GameSession.get_party_scouting_intel()` (`scripts/autoload/game_session.gd:2634`)
is a binary in-range/out-of-range Scout reveal gated by
`get_effective_scout_intel_range()` (`game_session.gd:4062`) —
not the design's per-World-Map-Turn probabilistic accumulation.
`get_threat_stars()` (`game_session.gd:2607-2611`, `THREAT_TURN_INTERVAL := 15`)
is a working precedent for bounded world-turn-based escalation. Guild Hall
levels 1-3 exist (`game_session.gd:888-898`); `GUILD_HALL_MAX_LEVEL = 3`
(no tier 4). `CampaignSnapshot` (`scripts/save/campaign_snapshot.gd`,
`FORMAT_VERSION := 2`) has an established incremental-field migration
pattern for durable per-encounter state.

**Absent:** No `watchtower`, `distance_retention`, or `quest` term anywhere
in `scripts/` (grep-verified zero hits). No per-World-Map-Turn detection
loop; no ordered tier reveal; no quest posting/timer/reward logic; no
`tests/unit/*watchtower*` or `*quest*` files. Stage 4's own index.md
invariants reconfirm this absence as of the most recent exit gate.

### Tactical depth primitives (visibility, terrain, avoidance, reactions)

**Exists:** `Grid.has_line_of_sight()` (`scripts/battle/grid.gd:39`) is real
occupied-tile LOS used for ranged attacks and spell targeting. Facing/flanking
is fully shipped (`BattleController.get_flank_type()`,
`battle_controller.gd:635`, with config-driven Guard-penalty/crit-bonus
application at lines 780-794). AP costs match the design doc 1:1
(`battle_controller.gd:110-119`). `withdraw_from_encounter()`
(`game_session.gd:2022`) already implements world-map-and-encounters.md's
Withdraw mechanic exactly.

**Absent:** No Cover, Dodge, Parry, or Attacks of Opportunity anywhere in
`scripts/` (grep-verified). No terrain data on the grid at all —
`battle_state_factory.gd:35` states units "only know about tile occupancy,
not terrain." No mechanical wound-band stat reduction (only a cosmetic HP
label exists). No test coverage for any of these.

### Mage and magical counterplay

**Exists:** `BattleController.try_cast_spell()` (`battle_controller.gd:1035`)
is a working MP/AP-gated, LOS/range-checked spell-cast pipeline dispatching
on `spell_id`. Class-owned MP (`mp_current`/`mp_max`,
`CLERIC_MP_MAX`, `game_session.gd:1064,1372`) matches the design's "MP is a
separate, class-owned resource" intent. `spellcasting`/`magic_resistance`
are real end-to-end unit attributes. Two spells ship today (`"heal"`,
`"bless"`, both Cleric-only, both **ally-targeted only** —
`battle_controller.gd:1037` structurally requires `target.side ==
selected_unit.side`, so enemy-targeted spells need that gate changed, not
just a new `match` arm).

**Absent:** No `"mage"` entry in `CLASS_DEFINITIONS` (only `warrior`,
`scout`, `cleric` exist). No offensive/control spells, no monster
resistant/control-counter fields beyond the universal unused
`magic_resistance: 0`. **Load-bearing finding:** `CampaignSim`'s own
telemetry shows the *existing* Cleric spell system goes unexercised across
the 5 representative seeds — `campaign_sim.gd:454` (`_record_full_triad()`)
and `campaign_sim_metrics.gd:47-78` report **"Full triad fielded: 0/5 runs"**
and **"Total spell casts: 0"** in the current baseline run (confirmed live
in this step's `make campaign-sim` log). A Mage slice cannot rely on
representative-seed campaign play to prove spellcasting counterplay; it
needs its own deterministic scenario fixtures that guarantee composition.

### Specializations (including Rogue)

**Exists:** Perk-tree infrastructure (`CLASS_PERKS`, `perk_tree_size`,
`is_perk_choice_pending()`/`choose_perk()`) is real and data-driven.
`CLASS_DEFINITIONS`' dict shape already supports everything a specialization
entry would need (`base_stats`, `skills`, `mp_max`, `spells`, `equipment`,
`progression`) — only 3 root entries are populated.

**Absent:** Zero specialization classes exist in code (grep-verified for
Knight/Archer/Paladin/BattleMage/Rogue/Ranger — only unrelated comment
hits). No luck-based crit mechanic, no non-root specialization data, no
test coverage.

### Multi-party strategy and time escalation

**Exists:** `parties: Array[Dictionary]` is already an array, not a scalar,
with per-entry `id`/`member_ids`/`location_id`/`world_position`/`deployed`/
`travel_route`/`movement_spent` — structurally ready for more than one
entry. `get_threat_stars()` is a working escalation precedent (see above).

**Absent:** `GameSession.get_max_party_count()` (`game_session.gd:1443`)
hardcodes `return 1` with a doc comment explicitly deferring the raise to
"roadmap part 4 (multi-party play)." `FIRST_PARTY_ID`/`selected_party_id`
are singular throughout; no Send-Party UI, no simultaneous multi-party
scouting, no per-party selection. Stage 4's index.md invariants reconfirm
this absence as of the most recent exit gate.

## Decision rows

Each row records: **Player decision** (what the player chooses), **Counterplay**
(the cost/risk that makes the choice meaningful), **Encounter use** (where it's
exercised — authored and/or repeatable), **Durable-state/snapshot change**,
**Deterministic scenario assertion**, and **Manual acceptance check**. A row
without an explicit approval record stays `Blocked`; no balance value is
invented for a blocked row.

### D1 — Intelligence: Guild Hall quest duration, reward basis, posting cadence

**Status: Approved 2026-08-23 (user, this step).**

- **Player decision:** Whether to accept a Guild Hall quest on a discovered
  optional encounter, trading a bounded time window for the encounter's
  reward plus early Tier-level/Main-monster reveal, versus leaving it
  unquested.
- **Counterplay:** Accepting starts a real timer
  (`encounter_tier * 10` World Map Turns); missing it forfeits the reward and
  blocks new quest postings for `encounter_tier * 5` turns (existing design
  value, unchanged). Investing in Watchtower/Scout coverage raises the
  detection/intel rate that produces quest-eligible discoveries sooner.
- **Encounter use:** Optional (non-authored) live encounter instances only.
  Authored `obj_*` objectives are never gated by quest state — they stay
  permanently discovered on unlock per the design doc's own invariant.
- **Durable-state/snapshot change:** `GameSession` gains a per-encounter
  intelligence/quest record (discovered flag, known-tier progress, optional
  quest id/timer/reward) keyed by live encounter instance id;
  `CampaignSnapshot` `FORMAT_VERSION` bump with a transactional migration
  test (old saves import with no quest state, not a partial/corrupt one).
- **Deterministic scenario assertion:** Seeded-RNG test proving (a) a quest
  timer of `encounter_tier * 10` turns expires and blocks new postings for
  exactly `encounter_tier * 5` turns afterward, and (b) an authored
  objective's discovery/route never depends on quest/intel state.
- **Manual acceptance check:** In `make play`, accept a quest, let it expire
  without clearing the target, confirm the posting block and that the next
  authored objective is still immediately visible without developer help.

**Approved values:**

| Parameter | Value | Basis |
|---|---|---|
| Quest duration | `encounter_tier * 10` World Map Turns | Doubles the existing post-expiry block formula (`encounter_tier * 5`) so completing is meaningfully easier than the miss penalty |
| Reward basis | 50% of the encounter's expected gold/loot value (design-specified), where "expected value" is derived from `CampaignSim`'s existing per-tier average gold telemetry rather than a newly authored table | Reuses already-observed play data instead of inventing new balance numbers |
| Posting cadence | One-time 50% roll at live-encounter-instance creation only; no periodic re-roll | Matches the design doc's literal wording and its explicit note that time-based escalation of un-quested encounters is deferred |

**Watchtower balance table:** design-specified in `docs/designs/intelligence.md`
(tier 1/2/3 cost 50/100/200, encampment detection 50/65/75 vs. 25 base).
**Approved as-is, no changes** — confirmed with the user 2026-08-23 alongside
the quest parameters above; Step 2 implements this table verbatim rather
than re-deciding it.

### D2 — Tactical depth: terrain representation/distribution and reaction ordering

**Status: Approved 2026-08-23 (user).**

- **Player decision:** Whether to fight from Cover, whether to flank a
  Cover/Parry-capable defender instead of attacking head-on, whether to
  press a melee attack against a unit that might Dodge/Parry, and whether
  to reposition near an enemy and accept the opportunity-attack risk versus
  retreating safely.
- **Counterplay:** Already fully specified in `docs/designs/combat-system.md`
  and not re-decided here: flanking (Side/Rear) reduces defender Guard
  20%/50% and raises crit chance, which bypasses Cover's Guard bonus; a
  successful Dodge/Parry off-balances the attacker (-10% Guard on their next
  round) and a successful Parry also grants the defender a +10% melee
  counter-bonus against that attacker; an opportunity attack only lands at
  -10% melee to-hit, so it punishes but doesn't guarantee-stop repositioning.
- **Encounter use:** Step 3 adds one authored/repeatable encounter/terrain
  layout demonstrating each of Cover, Dodge, Parry, and Opportunity Attack
  (task 6 of the step file), now unblocked because each primitive's
  counterplay is already approved above rather than needing individual
  per-primitive sign-off.
- **Durable-state/snapshot change:** New per-tile Cover data on the battle
  grid (authored per encounter, not persisted to `CampaignSnapshot` — battle
  state is not currently save/loadable mid-fight, consistent with existing
  architecture); `Unit` gains Dodge/Parry/off-balance/counter-bonus/stale-LOS
  state, scoped to `BattleController`/`Unit`, not `GameSession`.
- **Deterministic scenario assertion:** `ScenarioContract`/`BattleStateFactory`
  fixtures proving Cover/Dodge/Parry/Opportunity-Attack outcomes replay
  byte-identically for a fixed seed, and that an unrelated seed run
  before/after doesn't change the outcome (no hidden global RNG coupling).
- **Manual acceptance check:** In `make play`, identify visible vs. stale
  space, Cover, the valid reaction trigger, and the resulting log/feedback
  without consulting test data; confirm Move/Attack stay button-only,
  right-click facing costs no AP, and a reaction neither duplicates nor
  bypasses normal battle aftermath.

**Approved values:**

| Parameter | Value | Basis |
|---|---|---|
| Terrain representation/distribution | Cover tiles are hand-authored per encounter (same pattern as `EXPEDITIONS`' existing hand-placed positions/compositions) — no procedural distribution algorithm | Avoids inventing distribution weights; only the demonstration encounter(s) this step adds need Cover tiles placed |
| Battlefield visibility ("stale" areas) | Last-known-position memory: tiles outside current LOS render dimmed; an enemy last seen in a now-stale tile keeps showing at its last-known position (visually marked as possibly outdated) until re-observed | Matches the design doc's literal "grows stale" wording with a readable player signal, rather than simple hide/reveal |
| Dodge chance | Flat 10% for all units | Matches the design doc's "small chance" wording without inventing a new per-unit stat; consistent order of magnitude with the existing 5% crit chance and -10% off-balance/opportunity penalties already in the design |
| Parry chance | Flat 10% for all units (melee-eligible attacks only) | Same basis as Dodge |
| Opportunity-attack trigger scope | One opportunity attack per adjacent enemy per move action, however many times the mover departs/re-enters that enemy's adjacency within one move; the move completes regardless of whether the attack hits | Matches the design doc's per-departure wording read at the move-action grain, avoids stacking multiple free attacks from a single repositioning decision |
| Opportunity-attack reactor eligibility (clarified 2026-08-23) | Melee-capable enemies only (`attack_max_range == 1`); ranged enemies never trigger an opportunity attack | Step 3 implementation review found legacy ranged enemy templates carry one flat `hit_chance` stat with no melee/missile split — applying the documented -10% *melee* to-hit penalty to it would mislabel their ranged accuracy as melee. User confirmed melee-only scope rather than extending the mechanic to cover this gap. |

### D3 — Mage: first spell/counter encounter

**Status: Approved 2026-08-23 (user).**

- **Player decision:** Whether to spend 3 AP/1 MP putting a dangerous enemy
  to Sleep (skipping its next turn) instead of attacking it directly, weighing
  that landing any hit on a sleeping target wakes it early (so the rest of
  the party must choose to leave it alone to bank the full incapacitation),
  and that a magic-resistant target may simply shrug the cast off outright.
- **Counterplay:** Player-facing — attacking a sleeping enemy wakes it
  immediately, so Sleep only pays off if the party holds fire on that target;
  it can't be combined with focusing it down the same turn. Enemy-facing — a
  target's `magic_resistance` roll (`(magic_resistance - spellcasting)/100`)
  can fully negate the cast outright (binary, matching combat-system.md's
  "negates ... the effect" wording read for a non-numeric status), so Sleep
  is not a universal free skip against every enemy.
- **Encounter use:** Step 4 adds one authored/repeatable encounter fielding
  the new magic-resistant enemy variant, so both the successful-Sleep and
  resisted-Sleep outcomes are exercised.
- **Durable-state/snapshot change:** New `"mage"` `CLASS_DEFINITIONS` entry
  (Intelligence 6-8, class_multiplier 0.5, `spells: ["sleep"]`, skills per
  class-system.md's shipped table: melee n/a, missile low, spellcasting med)
  plus a durable `mp_current` field mirrored from Cleric's existing pattern;
  Sleep's own `SLEEPING_STATUS_ID` battle-local status, scoped to
  `BattleController`/`Unit`, not `GameSession`. The counter enemy's
  `magic_resistance` value lives in that one encounter's factory data, not a
  new monster family.
- **Deterministic scenario assertion:** Must guarantee spellcasting is
  actually exercised (see D3's supporting evidence above: the existing
  Cleric spell system is *not* exercised by representative-seed play alone)
  — a dedicated fixture proving a successful Sleep, a resisted Sleep, and an
  early wake-on-hit, all replaying byte-identically for a fixed seed.
- **Manual acceptance check:** In `make play`, recruit a Mage, read its AP/MP
  and Sleep's cost before casting, cast it in the approved encounter,
  observe both a successful Sleep (enemy skips its turn) and, if the
  magic-resistant enemy is targeted, a resisted cast; attack a sleeping
  enemy and confirm it wakes immediately; finish the encounter and verify
  MP recovery/save/load preserves Mage state without granting Sleep to
  another class.

**Approved values:**

| Parameter | Value | Basis |
|---|---|---|
| First spell | Sleep (control): applies a new `SLEEPING_STATUS_ID` to one living enemy target, blocking its move/attack/cast exactly like the existing `PARALYZED_STATUS_ID` used by the Thorn rune, until it wakes | User's explicit choice of a control spell over Fire Bolt; a distinct status id (not literally reusing Paralyzed) keeps Thorn's and Sleep's sources conceptually separate while reusing the same `statuses` dict/`has_status()`/`apply_status()` framework and the existing move/attack/cast blocking gates (generalized to check either status) |
| Cast AP/MP cost, range | 3 AP / 1 MP, 0-3 tile line-of-sight range (4 with the Meditation perk) | Reuses Cleric's exact established `try_cast_spell()`/`spells`/`mp_remaining` economy; no new action economy invented |
| Mage `mp_max` | 3, same default magnitude as Cleric's config-driven `cleric.mp_max`, via its own `mage.mp_max` GameConfig key | Extends the same "reuse Cleric's exact costs" principle to the resource pool size, not just the per-cast cost — flagged here explicitly since it wasn't its own separate question |
| Sleep duration/expiry | Blocks the target's next turn's actions; clears automatically at the start of the next player round (same round-boundary timing `_clear_expired_statuses()` already uses for Paralyzed), unless broken early | Reuses the existing round-boundary clear pattern rather than inventing a new duration/counter mechanic |
| Sleep interruption | Any landed attack against a sleeping unit, from any source, immediately clears `SLEEPING_STATUS_ID` (wakes the target) before its natural expiry | User's explicit requirement |
| Resistance check | Defender's `magic_resistance` roll (`(magic_resistance - caster's spellcasting)/100`) chance to fully negate the cast — Sleep either applies in full or not at all, no partial/reduced effect | Matches combat-system.md's literal "negates ... the effect" wording, read as the binary case for a status (vs. a damage spell's numeric halving) |
| Counter enemy | Reuse an existing monster type; author one new/existing encounter where that enemy has `magic_resistance > 0` as immutable per-encounter factory data — no new monster family, art, or lore | Matches Step 3's "hand-authored per encounter" precedent for Cover; avoids monster-manual.md's full new-monster addition checklist for a decision-gate step |

### D4 — Specializations: delivery order and promotion eligibility

**Status: Approved 2026-08-23 (user).**

- **Player decision:** Whether to promote an eligible root adventurer
  (Warrior→Knight, Warrior→Archer, Mage→Battle Mage, Cleric→Paladin) once
  both its root perks are chosen, trading its root's two-perk tree for the
  specialization's own perk(s)/spell and (for Paladin only) a built Temple
  requirement, versus keeping it in its root class.
- **Counterplay:** Every new ability reuses an already-shipped magnitude
  rather than adding a strictly-dominant option: Shield Bash/Lock On/Called
  Shot/Temporary Guard/Fire Bolt/the boon all cost the same AP (and, for
  spells, MP) as their existing analogs and share the same -10%/+10%/2-8/
  double-Bless order of magnitude already present elsewhere in combat, so a
  promoted adventurer gains a new tactical choice, not a flat power bump.
  Called Shot's Guard-bypass costs a flat -10% to-hit, matching the existing
  opportunity-attack accuracy/power trade-off. Fire Bolt is still subject to
  the existing `magic_resistance` halving roll like any other spell.
- **Encounter use:** Each branch's task 5 (per the step file) adds one
  encounter/monster counter and two fixed-seed scenarios per shipped
  ability, demonstrating both a favorable and an unfavorable use, before
  that branch merges.
- **Durable-state/snapshot change:** `GameSession` gains a `specialization`
  (or equivalent) field per adventurer, set only once both root perks are
  chosen (and, for Paladin, only once the Temple Encampment upgrade is
  built); existing root `CLASS_DEFINITIONS` entries and perk ids are
  unchanged, migration-safe for adventurers who never promote. Knight/Archer
  gain their two named perks on the existing perk-tree/`perk_tree_size`
  mechanism (no re-implementation of Step 3's universal Parry primitive).
  Battle Mage gains a `temporary_guard` perk plus a granted `"fire_bolt"`
  spell entry (mirroring how Sleep was granted to base Mage). Paladin gains
  a granted stronger self-castable Bless variant, not a new perk-tree entry.
- **Deterministic scenario assertion:** One `ScenarioContract`/
  `BattleStateFactory` fixture per shipped ability proving its outcome (the
  off-balance application, the second-target strike, the to-hit bonus, the
  Guard-bypass, the Guard buff, Fire Bolt's damage/resist halving, the
  doubled Bless bonus) replays byte-identically for a fixed seed, plus a
  promotion-eligibility test proving the ability is unavailable before
  promotion and persists through a snapshot round trip after.
- **Manual acceptance check:** Per the step file's documented manual check,
  repeated once per branch as it merges: promote one eligible root
  character, compare it with the unpromoted alternative, use its defining
  ability in its authored/repeatable encounter, observe its counter,
  save/load, and confirm the decision remains clear without developer help.

**Approved values:**

| Parameter | Value | Basis |
|---|---|---|
| Delivery order | Knight → Archer → Battle Mage → Paladin | Matches class-system.md's own roadmap table order (line 196) |
| Promotion eligibility (Knight/Archer/Battle Mage) | Available once both of the root class's two Stage 2 perks are chosen | Specialization perks/spells become additional entries on the same perk-tree mechanism once the root tree is exhausted; no new eligibility gate invented |
| Promotion eligibility (Paladin only) | Same perk-exhaustion rule, plus the Encampment's Temple upgrade must already be built | Reuses campaign-loop.md's existing built Temple upgrade to satisfy class-system.md's "Temple-gated recruitment" note for Paladin specifically, without inventing new gating |
| Knight's two perks | Shield Bash, Chain Blow (not Parry) | Step 3 already shipped a universal flat-10% Parry primitive for every unit; re-implementing it as a Knight-only perk would require inventing a new numeric upgrade. Shield Bash + Chain Blow are Knight's remaining two design-doc perks, keeping the existing "exactly two perks per class" pattern |
| Shield Bash effect | Melee attack that, on a hit, also applies the existing off-balance status (-10% Guard next round, the same status Dodge/Parry already apply) to the target; normal attack AP cost | Reuses Step 3's off-balance status/magnitude exactly |
| Chain Blow effect | Once per round, a landed melee attack also strikes one additional adjacent enemy using the same to-hit roll and damage formula; no extra AP cost | New multi-target resolution, but reuses the existing single-attack roll/formula twice rather than inventing a new damage model |
| Archer's perks | Lock On, Called Shot (not Piercing Arrow) | User's explicit selection from the three design-doc-named Archer perks |
| Lock On effect | +10% to-hit against a target the Archer also attacked last round | Same order of magnitude as the existing off-balance/opportunity-attack penalties |
| Called Shot effect | Normal attack AP cost; ignores the defender's Guard entirely for that one attack, at a flat -10% to-hit penalty | Mirrors the opportunity-attack's existing accuracy-for-power trade-off exactly |
| Battle Mage's ability set | Temporary Guard perk + a granted `"fire_bolt"` spell (not enchanted weapon penetration) | The roadmap table places "penetration" in Step 6 (advanced perk branches), not Step 5; Fire Bolt's resisted-damage formula is already specified in combat-system.md |
| Temporary Guard effect | Self-cast, +10 Guard (same magnitude as the existing Bulwark perk) until the start of next round (same round-boundary Sleep/Paralyzed already clear on); costs Sleep's 3 AP/1 MP economy | Reuses Bulwark's existing Guard magnitude and Sleep's existing cast economy/round-boundary clear |
| Fire Bolt cost/range/damage | 3 AP / 1 MP, 0-3 tile LOS range (reusing Sleep's exact cast economy); deals 2-8 damage (same magnitude as Heal's roll), halved on a successful `magic_resistance` roll | No new action economy invented; damage magnitude reuses Heal's existing roll range; resistance handling matches combat-system.md's literal "Fire Bolt damage reduced by half" wording |
| Paladin's ability | Grants the existing Bless spell (already self-castable today — its ally-only gate includes the caster) at double its current bonus: 20% hit chance / 1.20x damage, vs. Bless's existing 10%/1.10x | "Self-castable" was already true of shipped Bless; "stronger" is the only new magnitude, set as a direct doubling of the existing bonus rather than an arbitrarily chosen new value |

Rogue is explicitly deferred within this row until its own counterplay is
separately accepted, per the plan index.

### D5 — Multi-party: cap, battle-party selection, time-escalation rule

**Status: Approved 2026-08-24 (user, this step).**

- **Player decision:** Whether to field and independently dispatch a second
  party — once the Guild Hall reaches its top tier — to a different
  encounter/location than the first, splitting scouting and battle coverage
  across two fronts at once, versus keeping the whole roster in one party;
  and, when both parties are simultaneously staged at an encounter ready to
  fight, which one to send into battle first.
- **Counterplay:** Guild Hall level 3 is the existing top-tier upgrade cost
  (unchanged, no new price invented); splitting the roster across two
  parties means neither party can draw on the full roster's strongest
  configuration at once. The shared `world_turn` clock and its bounded
  threat-star escalation advance once per End Turn regardless of party
  count, so fielding a second party doesn't buy free strategic time — it
  only lets that time be spent on two fronts instead of one. Only one
  battle can be active at a time (single `BattleController` instance), so a
  party staged at an encounter while the other is mid-battle must wait.
- **Encounter use:** No new authored/repeatable encounter is added by this
  step; the existing authored and optional encounter roster becomes
  reachable by two independently routed parties instead of one.
- **Durable-state/snapshot change:** `GameSession.get_max_party_count()`
  becomes Guild-Hall-level-gated instead of hardcoded `1`
  (`game_session.gd:1443`); `parties: Array[Dictionary]` (already
  multi-entry-shaped), `FIRST_PARTY_ID`/`selected_party_id`, and every
  one-party-assumption call site the step file's task 2 requires auditing
  first, are replaced with explicit party-id APIs. `THREAT_TURN_INTERVAL`
  moves from a hardcoded constant into `GameConfig`
  (`world_map.threat_turn_interval`, default unchanged). No new per-party
  "in battle" lock field is added — battle exclusivity continues to rely on
  the existing single-`BattleController`-instance invariant.
- **Deterministic scenario assertion:** Seeded fixtures proving (a)
  `get_max_party_count()` returns `1` below Guild Hall level 3 and `2` at
  level 3, (b) two parties hold independent routes/destinations/
  `movement_spent` without cross-contaminating each other's state, (c) the
  threat-star and quest-expiry counters read correctly off the
  config-backed interval and each quest's own timer, and (d) a party cannot
  claim a battle already owned by another party's encounter, and quest/
  reward progress never attributes to the wrong party.
- **Manual acceptance check:** Per the step file's documented manual check:
  in `make play`, form two parties, send them to different destinations,
  switch selection, advance turns, inspect independent routes/scouting,
  resolve an encounter with one while the other remains valid, save/load
  mid-travel, and confirm the threat/quest counters are visible and that
  time/quest feedback never hides the authored objective.

**Approved values:**

| Parameter | Value | Basis |
|---|---|---|
| Party cap | 2, unlocked once the Guild Hall reaches level 3 (`GUILD_HALL_MAX_LEVEL`); 1 below that (today's behavior, unchanged) | Matches `game_session.gd`'s own pre-existing forward-looking comment on `get_max_party_count()`, which already ties the 1->2 raise to the Guild Hall level 2->3 upgrade — reuses an already-planted precedent and the existing top-tier gate rather than inventing a new threshold |
| Time-escalation source | The existing `get_threat_stars()`/`THREAT_TURN_INTERVAL` mechanic, moved into `GameConfig` (`world_map.threat_turn_interval`, default `15` unchanged) plus a new World Map/info-panel "turns until next threat star" counter shown alongside the existing Step 2 quest-expiry counter | Finishes wiring a mechanism the codebase already planted and pointed at this exact step (`THREAT_TURN_INTERVAL`'s own comment: "Step 6's simulation/balance harness is the step that revisits its exact value") — no new escalation curve or number invented |
| Battle-party tie-break | Whichever party's Enter the player clicks first claims the active battle; the other party's Enter stays visible but disabled/queued until that battle resolves | Reuses the existing single-`BattleController`-instance constraint rather than adding new concurrency/lock state or a new modal; identical in spirit to today's single-party Enter/Withdraw flow |

## Manual check record

Reviewed with the user 2026-08-23. Confirmed: the first approved runtime
slice is optional intelligence/quests (Step 2); D2-D5 stay `Blocked` and no
later step may start until its own row is filled in and approved by the
user; D1's quest duration/reward-basis/posting-cadence and the Watchtower
balance table are approved as recorded above.

Step 2 merged 2026-08-23 after manual `make play` signoff (commit `7a9ae58`).

D2 (tactical depth: terrain source, visibility staleness, Dodge/Parry
chance, opportunity-attack trigger scope) approved with the user 2026-08-23
ahead of Step 3 — recorded above.

D4 (specializations: delivery order Knight → Archer → Battle Mage →
Paladin, promotion eligibility) approved with the user 2026-08-23 ahead of
Step 5 — recorded above. All four branches merged 2026-08-23/24 after their
own independent review and manual `make play` signoff: Knight (commit
`44841db`), Archer (`7bf9b91`), Battle Mage (`4968ae0`, which also fixed a
prerequisite gap — Mage had no root perk-tree entry, which would have made
Battle Mage promotion permanently unreachable under the existing
eligibility gate), Paladin (`0c52a6d`, gated additionally on a built
Temple, granting a doubled Bless rather than a new perk). Rogue remains
deferred per the plan; Step 5 is complete.

D5 (multi-party: cap of 2 gated on Guild Hall level 3, the existing
threat-star mechanic made config-backed with a new turns-until-escalation
counter, and a click-order battle tie-break) approved with the user
2026-08-24 ahead of Step 6 — recorded above.

**Known limitation, accepted 2026-08-24 (user):** `pending_reward`/
`pending_gear`/`pending_mana_crystals` (`game_session.gd`) remain single
campaign-wide "loot in transit" buckets, not attributes of each party.
A single battle's own reward is never misattributed — only one party can
hold the active battle claim at a time (`active_battle_party_id`) — but if
two parties are simultaneously carrying unbanked loot toward the Encampment
after separate encounters, it pools into one shared bucket rather than
staying separate per party. **The correct fix is to make these three fields
attributes of each entry in `parties` — the same way `member_ids`/
`travel_route` already are — rather than campaign-wide globals**, not to
add ad hoc cross-party guards. That touches roughly ten files outside Step
6's declared list (`party_details.gd`, `victory_screen.gd`,
`battle_result.gd`, `campaign_sim.gd`, and others that read the shared
fields), which is why it was scoped out of Step 6 rather than fixed inline.
A matching doc comment is planted directly above `pending_reward`'s
declaration in `game_session.gd` so the fix direction is visible at the
point a future step would actually touch. The user explicitly chose to
leave this as scoped rather than expand Step 6 to cover it; revisit if it
proves to matter in play, and before Step 7's exit gate treats "no
battle/quest/objective state is attributed to the wrong party" as fully
proven for the loot-in-transit case specifically.

**Arrival-visibility clarification, approved 2026-08-24 (user).** Independent
review found `world_map.gd`'s `_check_for_arrival()` only checks the
currently-selected party's tile on End Turn, so a non-selected party arriving
at a live encounter the same turn never auto-opens its arrival panel — the
player would have to manually click that party's marker to notice, risking a
missed quest/threat window. Approved resolution: on End Turn, if a
non-selected deployed party has arrived at a live encounter, selection
auto-switches to it and its arrival panel opens immediately — the same
behavior single-party play already has, extended to whichever party actually
arrived. Given the party cap is 2 (see above), if both parties arrive
simultaneously the already-selected party's own arrival panel takes priority
(existing behavior unchanged); the other party's arrival is picked up on the
player's next click, same as today for any change made to a non-selected
party.
