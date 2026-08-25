# Card Navigation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to
> implement this plan task-by-task.

**Goal:** Provide a universal, wrapping card navigator for every current
player-facing list that opens detailed entries.

**Architecture:** A new `CardNavigator` owns only the full-screen shell and
an immutable ordered ID session. Screen-local controllers retain ownership of
their ordered rows, data lookup, mutations, and selection restoration; small
card-body controls render each entry type. `ModalDialog` remains an
acknowledgement/outcome component rather than becoming a second navigator.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, GUT 9.7.1.

## Contract and boundaries

- `<` from the first card wraps to the final card; `>` from the final card
  wraps to the first. A single entry disables both controls.
- The navigation order is exactly the list's current displayed order. It is
  captured at opening time, not recomputed from mutable domain state.
- Close or Escape restores the originating list, selects the last viewed ID
  if it remains present, and gives focus back to that list's View control.
- If the current ID is no longer valid after a mutation, close safely and
  refresh; do not silently substitute an unrelated entry.
- Cards are centered and dominate the screen. The card shell owns the only
  generic title/count/arrows/Close UI; type-specific controls stay inside the
  body.
- `GameSession` owns game state, `GameManager` owns scene routes, and scene
  controllers own transient selection. Do not add navigator IDs to saves or
  global route context.
- This plan changes player-facing detail presentation, not recruitment,
  inventory, combat, perk, or economy rules. Pending perk choice still gates
  battle completion even if the player closes its card.

## Delivery rules

Implement steps serially. For every step: begin from current local `main` on
a regular feature branch (never a worktree), read `docs/dev/README.md`, this
index, and the assigned step; preserve unrelated changes; follow red/green
TDD; obtain an independent read-only review of `git diff <base>...HEAD`; then
ask for the manual check. Only user signoff authorizes the documented commit,
local merge to `main`, and branch deletion. Do not push or open a PR.

## Ordered steps

1. [Navigator shell and test contract](01-navigator-shell.md)
2. [Adventurer and party-member cards](02-adventurer-cards.md)
3. [Recruitment and item cards](03-recruitment-and-item-cards.md)
4. [Journal and battle outcome level-up cards](04-journal-and-level-up-cards.md)
5. [Coverage audit, regression gate, and handoff](05-coverage-audit-and-handoff.md)

Steps 2–4 depend on Step 1 and can be implemented only serially under this
project's handoff policy. Step 5 depends on all preceding steps.

## Exit gate

Run focused GUT files named in each step, `make check`,
`godot --headless --path . --editor --quit`, `git diff --check`, and
`make screenshots`. Manual `make play` must verify wraparound, Close and
Escape restoration, no card behind another card, selection restoration after
an allowed mutation, shop/store actions, journal entries, and multi-unit
level-up flow. Screenshot output is visual evidence only; it does not replace
manual interaction testing.
