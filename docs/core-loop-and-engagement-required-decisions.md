# Required Decisions: Core Loop Completion and Engagement

> **Status:** Open decision register for
> [the core-loop roadmap](core-loop-and-engagement-roadmap.md). The
> recommendations preserve its compact, loop-first campaign while making its
> promises testable against the current game.

Resolve the **blocking** decisions before marking the roadmap implementation
ready. The later decisions can be resolved during the relevant feature-design
slice, but must be settled before that slice begins.

## Blocking decisions

### D1 — Campaign arc and authored battle count

**Decision:** What is the fixed objective graph that creates a 10–15 battle,
60–90 minute campaign?

Use three tiers of three authored encounters (nine total),
a two-battle pre-boss sequence, and one final boss: twelve required battles.
Unlock the next node only from completed campaign objectives; free-play
vacancies appear only after victory.

This should yield enough gold and experience that we can take a party of 5 units to level 6 (two perks).

**Required contract:** Every authored node declares an objective id, exact
enemy composition, prerequisite, reward, intended counterplay, and loss
consequence. `GameSession` persists campaign progression independently of
active and completed encounter-instance ids.

### D2 — Party-size sequence and initial formation

**Decision:** Does Campaign 1 start with three or four party slots?

Start at **three**, then upgrade to four and five. It makes
the first Guild Hall upgrade a visible strategic choice and naturally stages
the Warrior/Scout/Cleric triad. The initial roster may offer more than three
adventurers, but only three deploy.

Roster size is fixed at 10 for Guild Hall tier 1, and 15 for tier 2.
The number of recruitable units is capped at 4 for tier 1, and 6 for tier 2.
If a new recruitable unit appears when the recruit pool is at the max, the oldest recruitable unit is removed.

### D3 — Permadeath, retreat, and equipment recovery

**Decision:** Which battle outcomes kill units, can the player retreat, and
what happens to each dead unit's equipment?

A unit that reaches 0 HP is slain at battle resolution;
remove it from the party and roster. All equipped, carried, and unique modified
items go to the party loot pool and return to the Encampment bank on a successful retreat.

If there is a party wipe, all gold and loot are lost.

A party can retreat, but faces consequences based on the nearest enemy.

```
            loss of remaining HP chance
distance  |  0% | 10% | 50% | death
----------+-----+-----+-----+-------
1-3       | 10% | 30% | 30% | 30%
4-6       | 20% | 50% | 10% | 10%
7+        | 50% | 30% | 10% | 10%
```

Add a Retreat button to the lower left of the bottom panel (with move/action/end turn buttons)

**Required contract:** Validate all state before mutation, then transfer items
and remove the adventurer atomically. A dead id may not remain in party members,
item ownership, save data, or battle aftermath input.

### D4 — Recovery time, income, and recruitment guarantee

**Decision:** How does a player recover from a wipe or zero gold, and what
numbers make that guarantee true?

**Recommendation:** After a wipe, return to the Encampment, discard
unbanked/pending rewards. 

After a retreat, party appears over the encounter location with the retreat penalties applied.

Party earns passive income based on shop tier as a minimal supply to re-equip a new party.

Shop tier 1: 2 gold/turn, iron arms
Shop tier 2: 5 gold/turn, steel arms
Shop tier 3: 10 gold/turn, healing potions (2-8 hp, 20 gold)

**Required contract:** Every turn must advance healing, jobs, recruitment
vacancies, and income without requiring a deployable party. Test zero-gold,
no-party, and repeated/wipe states through to a legal replacement party.

### D5 — Tier gates and tactical answers

**Decision:** What concrete preparation gates each tier, and which gameplay
primitive answers its main threat?

Monster threat level increases over time (turns). The timing should be enough so that the party can advance to level 6 or thereabouts, with several encampment upgrades, by the final boss battle.

**Required contract:** Each threat level must be shown on the UI with star icons (1-5)

## Decisions due before their feature slice

### D6 — Scout reconnaissance information policy

**Recommendation:** Recon reveals exact enemy types and counts, danger tier,
and reward categories (gold band, crystal tier, possible gear); it does not
reveal random-roll outcomes, enemy positions, or every future ability. This
creates a meaningful choice without removing tactical discovery.

### D7 — Cleric and Temple scope

**Recommendation:** Temple unlocks Cleric recruitment and one encampment
blessing. The first Cleric slice contains one targeted in-battle heal and one
temporary protection effect, both with explicit AP, range, duration, and
stacking rules. It should not add a broad spell tree or Mage prerequisites.

### D8 — Final encounter and free play

**Recommendation:** Make the final boss a unique authored encounter whose
completion atomically records campaign victory, shows a dedicated victory
screen, and unlocks clearly labelled free play. Free-play encounters never
modify completed campaign objectives or replay the victory screen.

### D9 — Presentation proof standard

**Recommendation:** Keep 3/4 top-down perspective as the visual direction,
but defer production asset commitments until campaign playthrough evidence is
complete. The presentation milestone needs screenshots, an audio checklist,
and a manual clarity test covering tactical selection, facing, hit results,
wounds, objectives, gates, and mute parity.

## Completion evidence

The roadmap is ready to become an implementation contract when D1–D5 are
resolved and recorded in the roadmap, and D6–D9 have explicit owners and
decision dates. Campaign completion is proven only when all of the following
exist:

- a save-compatible campaign-state model and objective UI;
- deterministic tactical scenarios for every authored battle and gate;
- a deterministic campaign run covering victory and a zero-gold wipe recovery;
- a manual clean-save playthrough to victory and a manual setback/rebuild
  playthrough; and
- `make check` plus `git diff --check` passing.
