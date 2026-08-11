# Runic Workshop Design

## Goal

Add the first socketed passive: armor's Thorn Rune. A melee hit on its wearer
has a 25% chance to Paralyze the attacker for one Round.

## Workshop and recipe

- Build the Runic Workshop for 50 gold; upgrade level 1 to level 2 for 50
  gold. Thorn Rune is available at level 1.
- A single socketing job takes seven World Map Turns and consumes 20 gold plus
  one mana crystal of tier 1 or higher when it starts.
- Each armor instance has one rune socket. Thorn is armor-only. Socketing a
  new rune replaces and consumes any displaced rune.
- Every eligibility check completes before mutating gold, crystals, jobs, or
  item ownership. Completed jobs update the target owned instance and persist
  through campaign snapshots.

## Shared combat contract

`BattleController` publishes a completed-hit event after a successful attack.
Effect definitions consume that event rather than adding rune-specific attack
callbacks. A Thorn-equipped defender reacts only to a hit tagged `melee`.

The chance roll goes through an injectable seam, so tests can cover its 0% and
100% boundaries. On a successful roll, Thorn adds the reusable `paralyze`
status to the attacker for one Round. While Paralyzed, a unit cannot move,
attack, consume an item, or transfer one. The status expires at the next Round
boundary. A unit cannot receive a second Paralyze while already Paralyzed;
there is no duration refresh or stack.

## UI and AI

The Runic Workshop screen follows the Blacksmith and Alchemy Workshop pattern:
build and upgrade controls, compatible owned-armor selection, a job countdown,
and clear replacement wording. Battlefield feedback records Thorn triggers and
shows a Paralyzed unit's state. AI treats a Paralyzed unit as unable to act and
ends its turn safely.

## Verification

Tests cover atomic recipe failure, armor compatibility, replacement and
snapshot persistence, melee-only trigger tags, deterministic chance seams,
duration/immunity, UI feedback, and AI behavior. Finish with focused GUT,
`make check`, editor scan, seeded trigger scenarios, `git diff --check`, and a
manual `make play` check of a trigger and replacement before local merge.
