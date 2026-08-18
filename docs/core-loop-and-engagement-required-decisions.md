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

**Recommendation:** Use three tiers of three authored encounters (nine total),
a two-battle pre-boss sequence, and one final boss: twelve required battles.
Unlock the next node only from completed campaign objectives; free-play
vacancies appear only after victory.

**Alternative:** Make only five to seven authored battles and fill the arc with
repeatable vacancies. This is cheaper to build but cannot guarantee pacing,
rewards, or a meaningful ending.

**Required contract:** Every authored node declares an objective id, exact
enemy composition, prerequisite, reward, intended counterplay, and loss
consequence. `GameSession` persists campaign progression independently of
active and completed encounter-instance ids.

### D2 — Party-size sequence and initial formation

**Decision:** Does Campaign 1 start with three or four party slots?

**Recommendation:** Start at **three**, then upgrade to four and five. It makes
the first Guild Hall upgrade a visible strategic choice and naturally stages
the Warrior/Scout/Cleric triad. The initial roster may offer more than three
adventurers, but only three deploy.

**Alternative:** Retain the current four-to-five capacity. It minimizes
migration and balancing work, but the first Guild Hall upgrade no longer
creates the proposed 3→4 composition moment.

**Required contract:** State whether roster size is deliberately unlimited for
Campaign 1. Do not claim a roster cap unless its rule, UI, and recovery effect
are designed.

### D3 — Permadeath, retreat, and equipment recovery

**Decision:** Which battle outcomes kill units, can the player retreat, and
what happens to each dead unit's equipment?

**Recommendation:** A unit that reaches 0 HP is slain at battle resolution;
remove it from the party and roster. All equipped, carried, and unique modified
items return to the Encampment bank on a successful retreat/wipe. Add an
explicit retreat action that is available only before the final encounter and
costs the same campaign setback as a wipe.

**Alternative:** Lose equipment with the adventurer. This increases stakes but
turns a recovery loop into an inventory-loss spiral and needs much larger
economy margins.

**Required contract:** Validate all state before mutation, then transfer items
and remove the adventurer atomically. A dead id may not remain in party members,
item ownership, save data, or battle aftermath input.

### D4 — Recovery time, income, and recruitment guarantee

**Decision:** How does a player recover from a wipe or zero gold, and what
numbers make that guarantee true?

**Recommendation:** After a wipe or retreat, return to the Encampment, discard
unbanked/pending rewards, and advance **two Encampment recovery turns**. The
player may also advance a recovery turn from the Encampment. Grant **2 gold per
turn** at Shop level 1 and **5 gold per turn** at level 2; always display the
next affordable recruit/gear target. Ensure at least one level-1 recruit costs
no more than five base recovery turns.

**Alternative:** Preserve the current 1 gold per World Map turn and require a
deployed party to advance time. This does not meet the stated soft-lock
guarantee after a wipe.

**Required contract:** Recovery turns must advance healing, jobs, recruitment
vacancies, and income without requiring a deployable party. Test zero-gold,
no-party, and repeated-wipe states through to a legal replacement party.

### D5 — Tier gates and tactical answers

**Decision:** What concrete preparation gates each tier, and which gameplay
primitive answers its main threat?

**Recommendation:** Gate by completed objectives plus one visible preparation
requirement, never hidden power score:

- Tier 2: Scout reconnaissance completed and one ranged option equipped.
- Tier 3: Temple/Cleric unlocked and one protection or healing tool prepared.
- Final: all tier objectives complete plus the Guild Hall's selected party-size
  upgrade.

Define the tier-2 defensive counter as **Resistance penetration**, rather than
the currently vague phrase “armor-piercing gear.”

**Alternative:** Gate purely by level or gold. This is simple but weakens the
roadmap's promise that composition and tactical learning unlock the next
challenge.

**Required contract:** Each gate must be shown in the campaign UI with its
reason, current state, and next action. Every counter needs a deterministic
scenario proving the intended preparation changes the outcome.

## Decisions due before their feature slice

### D6 — Scout reconnaissance information policy

**Recommendation:** Recon reveals exact enemy types and counts, danger tier,
and reward categories (gold band, crystal tier, possible gear); it does not
reveal random-roll outcomes, enemy positions, or every future ability. This
creates a meaningful choice without removing tactical discovery.

**Alternative:** Reveal only a danger tier and vague hints. It costs less UI
work but is unlikely to justify Scout's strategic role.

### D7 — Cleric and Temple scope

**Recommendation:** Temple unlocks Cleric recruitment and one encampment
blessing. The first Cleric slice contains one targeted in-battle heal and one
temporary protection effect, both with explicit AP, range, duration, and
stacking rules. It should not add a broad spell tree or Mage prerequisites.

**Alternative:** Make Temple only a recruitment building. This reduces scope
but gives the hub little strategic identity.

### D8 — Final encounter and free play

**Recommendation:** Make the final boss a unique authored encounter whose
completion atomically records campaign victory, shows a dedicated victory
screen, and unlocks clearly labelled free play. Free-play encounters never
modify completed campaign objectives or replay the victory screen.

**Alternative:** Let the final boss use a normal repeatable vacancy. This
undermines a durable completion state and makes the ending ambiguous.

### D9 — Presentation proof standard

**Recommendation:** Keep 3/4 top-down perspective as the visual direction,
but defer production asset commitments until campaign playthrough evidence is
complete. The presentation milestone needs screenshots, an audio checklist,
and a manual clarity test covering tactical selection, facing, hit results,
wounds, objectives, gates, and mute parity.

**Alternative:** Start bespoke art and music with the class work. It can expose
usability issues earlier, but risks redoing assets when class and encounter
semantics change.

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
