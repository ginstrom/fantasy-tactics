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

**Status: Blocked** — required before `feat/stage-5-tactical-depth` (Step 3) starts.

- **Player decision:** TBD at Step 3 kickoff — how terrain/cover choice
  and avoidance/reaction (e.g. opportunity-attack) resolution order affect
  play.
- **Counterplay:** TBD.
- **Encounter use:** TBD — must name at least one authored or repeatable
  encounter that demonstrates it.
- **Durable-state/snapshot change:** TBD — grid/terrain data does not exist
  yet (`battle_state_factory.gd:35` confirms tile-occupancy-only today).
- **Deterministic scenario assertion:** TBD.
- **Manual acceptance check:** TBD.

No balance value (terrain distribution weights, reaction ordering rule) is
invented here; Step 3 cannot start until this row is filled in and approved.

### D3 — Mage: first spell/counter encounter

**Status: Blocked** — required before `feat/stage-5-mage-counterplay` (Step 4) starts.

- **Player decision:** TBD — which offensive/control spell ships first and
  what player choice it creates.
- **Counterplay:** TBD — the resistant/control-counter monster trait that
  makes the spell non-dominant.
- **Encounter use:** TBD.
- **Durable-state/snapshot change:** TBD — likely a `"mage"` `CLASS_DEFINITIONS`
  entry plus enemy-side spell/resistance fields.
- **Deterministic scenario assertion:** TBD — must guarantee spellcasting is
  actually exercised (see D3's supporting evidence above: the existing
  Cleric spell system is *not* exercised by representative-seed play alone).
- **Manual acceptance check:** TBD.

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
