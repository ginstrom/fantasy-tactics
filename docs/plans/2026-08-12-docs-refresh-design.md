# Documentation Refresh Design

## Goal

Make the developer documentation and durable first-campaign design reference
accurately describe the systems shipped through the Runic Workshop slice.

## Decision

Use the current source, tests, Make targets, and recently delivered
implementation plans as the authority. Keep `game-design.md` a readable
player-facing systems reference: mark implemented loops as shipped and state
the next bounded work explicitly. Keep `docs/dev/` operational: it should
map ownership, supported commands, and reliable verification paths without
duplicating campaign design.

## Scope

- Refresh `docs/dev/README.md`, `code-map.md`, `running-the-game.md`, and
  `testing.md` where their claims no longer match the checkout.
- Refresh `docs/plans/first-playable-campaign/game-design.md` for item
  instances, carried inventory, tactical potion use, Blacksmith, Alchemy
  Workshop, and Runic Workshop behavior.
- Preserve all existing design boundaries that remain unimplemented; do not
  change game code, balance, or player-facing behavior.

## Verification

Cross-check every changed factual claim against source or tests, run the
documentation's headless validation path, and run `git diff --check`.
