# Step 2 - Campaign design reference refresh

## Milestone

`game-design.md` separates the shipped first-campaign loops from future
expansion without contradicting current source or tests.

## Setup

1. Read the current design reference and the current implementation slices:
   equipment instances, Blacksmith, Alchemy Workshop, tactical item actions,
   and Runic Workshop.
2. Treat `GameSession`, `BattleController`, the matching UI scripts, and
   their unit tests as implementation authority.

## Red/green documentation workflow

1. Identify claims that describe now-shipped systems as future work or omit
   their rules.
2. Update the completed-route, equipment/loot, building, and next-work
   sections to describe immutable base items plus unique upgraded instances,
   carried inventory, potion use, timed workshop jobs, and the Thorn rune.
3. Retain clearly marked deferred work for broader crafting/content scope.

## Verification

```bash
rg -n 'blacksmith|alchemy|runic|potion|instance|inventory' \
  docs/plans/first-playable-campaign/game-design.md
make check
git diff --check
```

## Manual verification

Run `make play`; use the Stocked Trading Post + Stores debug scenario to
visit Buildings, Trade, Stores, and the equipment-assignment flow. Confirm
the document's stated player loop is legible in the UI.

## Commit and merge

After user signoff, include this step with the documentation-refresh commit,
merge locally to `main`, delete the branch, and do not push.
