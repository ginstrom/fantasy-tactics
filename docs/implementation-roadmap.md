# Design Implementation Roadmap

## Purpose and status

This is the dependency-ordered implementation roadmap for the remaining major
game designs. Its first priority is a **completable Borderlands campaign** that
can be played repeatedly to assess playability, appeal, and engagement. It is
not an implementation plan or a claim that a design is already shipped.

The durable mechanics remain owned by their canonical documents. This roadmap
only says when to implement them and what must be true before moving on:

- [Borderlands Campaign Loop](campaign-loop.md) owns the campaign contract.
- [Classes](class-system.md), [Combat System](combat-system.md), and the
  [Monster Manual](monster-manual.md) own tactical roles and rules.
- [Equipment Handbook](equipment-handbook.md) owns gear, consumables, and
  crafting.
- [Intelligence System](intelligence.md) and [World Map and
  Encounters](world-map-and-encounters.md) own strategic discovery and travel.

Before each stage, compare its stated contracts with the live implementation
and tests. A design document can describe an approved future contract even
when a similarly named prototype already exists; do not call a contract done
until its persistence, UI, automated coverage, and manual play checks agree.

## Ordering principles

1. Complete one small campaign before expanding its strategic breadth. A
   player must be able to start, prepare, fight, recover from setbacks, win,
   and enter labelled free play.
2. Implement each party role only when an authored encounter makes its
   decision valuable. Do not add a class, monster, perk, or building merely
   because it has a design entry.
3. Prefer the minimum vertical slice that can be played and measured. Optional
   scouting, multiple simultaneous parties, and advanced class branches must
   not delay proof of the first campaign.
4. Preserve deterministic scenarios and campaign simulation whenever durable
   campaign or combat rules change. Balance claims need reproducible evidence,
   followed by manual `make play` sessions.

## Stage 1 — Campaign spine and safe failure states

**Goal:** a new game has a clear current objective and can progress through a
sequence of authored encounters without a broken save, lost objective, or
unrecoverable party state.

Implement the campaign state owned by `GameSession`: current objective,
completed objective ids, unlocked authored encounters, final victory, and
free-play state. Create the twelve required authored encounter definitions
(three tier 1, three tier 2, three tier 3, two pre-boss, and final boss) with
stable ids, prerequisites, exact compositions, rewards, intended counterplay,
and loss consequences. Required objectives must be discovered and displayed
when unlocked; probability must never block campaign continuation.

Make the Encampment and World Map communicate the current objective, next
unlock, danger signal, and final-victory condition. Complete the loss loop:
Battle Retreat, pre-battle Withdraw, party wipe, permanent death, atomic item
transfer, reward banking/loss, return routing, and a legal zero-gold/no-party
recovery route. Save/import validation must preserve every new campaign and
aftermath field.

**Exit gate:** starting a fresh save, completing the first required objective,
retreating, wiping, re-forming a party, saving/loading, and unlocking the next
objective all work deterministically. No outcome may remove the player's only
legal way to form a party or advance recovery.

## Stage 2 — Party readiness for the full campaign

**Goal:** tier gates test understandable preparation choices instead of hidden
numbers or a single dominant class.

Finish the first three-role party as a coherent vertical slice:

- Replace manual generic Attack-point spending with automatic, class-owned
  skills and data-backed every-third-level perk choices. Recalibrate the
  Warrior and monster baselines from that new progression.
- Complete the Ranger/Scout's ranged pressure and useful reconnaissance
  contribution. The campaign needs only the information required for its
  authored encounters; the full optional Intelligence System remains later.
- Complete Cleric/Healer recruitment, Temple recovery support, MP-backed
  battle support, and the details-view **Heal party member** action. Apply the
  locked natural-recovery rates and cap recovery at maximum HP/MP.
- Migrate combatants and the initial roster to the shared tactical profile
  without silently rebalancing them. Ensure action points, wounds, armour,
  resistance, equipment, potions, and battle UI communicate their effects.

Build an authored encounter pattern for each role: formation and banking loot
for tier 1; scouting, ranged pressure, resistance/armour, and potions for tier
2; mixed-force target priority for tier 3. Include the smallest required
monster variants and AI behaviours with each pattern rather than adding whole
families upfront.

**Exit gate:** a party of up to five can make meaningful Warrior, Ranger, and
Cleric trade-offs across the tier-1-to-tier-3 encounter patterns. Deterministic
scenarios cover class resources, equipment hydration, retreat aftermath, and
the new progression values; manual play confirms the roles read clearly.

## Stage 3 — Complete campaign assembly and proof

**Goal:** the full 60–90 minute Borderlands arc is playable from New Game to
final victory, then continues only as explicitly labelled optional free play.

Tune and connect the authored encounter sequence, rewards, Encampment upgrade
costs, recruitment, Shop income, workshops, and recovery so the intended party
can reach roughly level 6 and make several meaningful upgrades before the
boss. Implement final-boss composition, victory presentation, and post-victory
free-play boundaries. Required encounters never respawn or reopen when a
repeatable vacancy is filled.

Extend deterministic campaign scenarios to use the documented representative
seed set and all three initial roles. Record objective progression, party
losses, recovery, resources, and victory/failure outcomes so a balance change
can be compared rather than guessed at.

**Exit gate:** representative deterministic runs and a scripted save/load path
reach victory with valid state transitions. Manual sessions can complete the
arc, explain why a setback occurred, and distinguish victory from repeatable
free play.

## Stage 4 — Engagement, pacing, and presentation iteration

**Goal:** use the now-complete loop to improve whether the game is enjoyable,
legible, and worth replaying before increasing systemic scope.

Run structured play sessions through the whole arc. Iterate on encounter
composition, rewards, recovery pressure, retreat risk, upgrade timing,
recruitment availability, and class counterplay using recorded outcomes and
player observations. Fix onboarding, objective messaging, feedback, and
accessibility issues exposed by real runs.

Raise the presentation proof standard alongside those changes: readable 3/4
top-down combat and World Map assets, clear targeting/mode feedback, combat
hit/heal/retreat feedback, wound readability, and purposeful music/SFX routing.
Presentation work is evaluated against player comprehension and atmosphere,
not merely asset replacement count.

**Exit gate:** multiple complete manual campaigns produce actionable pacing
evidence; no repeated confusion or dominant strategy remains unaddressed. The
team can state the intended first-campaign experience and demonstrate it in a
fresh playthrough.

## Stage 5 — Strategic and roster expansion

**Goal:** add breadth only after the first campaign's loop has stable appeal.

Implement these as separate, independently balanced slices in this order:

1. **Optional intelligence and quests:** Watchtowers, distance-retention
   detection/scouting, accumulating encounter details, and Guild Hall quests.
   Keep authored-objective discovery guaranteed.
2. **Additional combat depth:** battlefield line of sight/fog, cover, dodge,
   parry, opportunity attacks, and only then the perks, weapons, monsters, and
   AI behaviours that require them.
3. **Mage and counterplay:** MP-backed offensive/control spells with resistant
   and control-counter monsters, then deterministic scenario coverage.
4. **Specializations:** Knight, Archer, Battle Mage, Paladin, and eventually
   the luck-based critical-dealer Rogue with weaker Scouting. Each must change
   choices rather than add a stat bonus.
5. **Multi-party strategy:** independent deployment/travel, simultaneous
   scouting chances, party-selection UI, and time escalation. It requires a
   campaign state and UI audit; it is not compatible with the first campaign's
   one-active-party constraint by default.

Each slice must name its new decision, counterplay, authored or repeatable
encounter use, persistence changes, scenario evidence, and manual acceptance
check before implementation begins.

## Explicitly deferred until after the first campaign

- Guild Hall tier 4, multi-party dispatch, and time-based quest escalation.
- Rogue and the non-root specialization roster.
- Mage spell branches and advanced perk trees.
- New monster families that need unimplemented primitives, including pack AI,
  control/cleansing, penetration, broad status effects, or magical counters.
- Broad free-play expansion beyond the clearly labelled post-victory loop.

## Decision checkpoints

At the end of Stages 1–3, stop and review actual play evidence before taking
on the next stage. If the campaign cannot be completed, return to the earliest
stage whose exit gate failed; do not compensate by adding optional systems or
more content. At the end of Stage 4, decide whether the first campaign has
enough appeal to expand, or whether it needs another focused iteration.

## Implementation discipline

Translate each approved stage into a separate folderized implementation plan
under `docs/plans/`, with an `index.md` and independently verifiable steps.
Each step should use a branch from `main`, red/green tests, focused automated
checks, `make check`, `godot --headless --path . --editor --quit`, `git diff
--check`, and the stage's manual `make play` acceptance check. Do not merge or
call a design shipped until those checks and the requested manual signoff are
recorded.
