# Step 04: Battle Round Terminology

## Milestone

Battle communicates its player/enemy action cycle in Rounds; the World Map communicates travel in Turns. The battle control remains **End Turn**, because it gives the enemy its action rather than ending a full round.

## Setup

Branch: `feat/battle-round-terminology` from updated `main`. This is independent of steps 01-03.

## Files

- Modify: `translations/en.tres`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

1. Add failing tests that the battle HUD exposes a round label/value, starts at Round 1, and increments only after the enemy action cycle returns control to the player. Add a localization assertion that player-facing battle hints no longer call that cycle a turn.
2. Run `make test`; expected failure: no round state/label and old localized hints.
3. Add `round_number: int = 1` to `battlefield.gd`. Increment it immediately after the second `grid.end_turn()` in `_play_enemy_turn()`, when player control returns. Add/update a localized HUD label in `_on_board_changed()`; change `battle.hint.*` to Round wording, leaving `battle.end_turn` unchanged.
4. Run `make check` and `git diff --check`.

## Commit and merge

Commit with `feat: show battle rounds`. No manual check is required. Merge locally after review; do not push.
