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

**Status: Blocked** — required before `feat/stage-5-specializations` (Step 5) starts.

- **Player decision:** TBD — which root's specialization branch ships
  first, and the eligibility rule for promoting into it.
- **Counterplay:** TBD.
- **Encounter use:** TBD.
- **Durable-state/snapshot change:** TBD.
- **Deterministic scenario assertion:** TBD.
- **Manual acceptance check:** TBD.

Rogue is explicitly deferred within this row until its own counterplay is
separately accepted, per the plan index.

### D5 — Multi-party: cap, battle-party selection, time-escalation rule

**Status: Blocked** — required before `feat/stage-5-multi-party` (Step 6) starts.

- **Player decision:** TBD — how many parties, and how the player selects
  which party acts/battles.
- **Counterplay:** TBD.
- **Encounter use:** TBD.
- **Durable-state/snapshot change:** TBD — `get_max_party_count()` currently
  hardcodes `1` (`game_session.gd:1443`).
- **Deterministic scenario assertion:** TBD.
- **Manual acceptance check:** TBD.

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
