# Step 3: Integration and manual campaign route

## Objective

Verify the two-site choice survives a real clear/refill cycle and record the
result before merging.

## Files

- Modify: `docs/plans/first-playable-campaign/game-design.md` only if manual
  verification exposes a design-record correction
- Generated and reviewed: `screenshots/` (do not commit)

## Steps

1. Run the complete automated and static checks:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: all tests pass, Godot reports no script errors, and whitespace is
   clean.
2. Optionally capture screenshots:

   ```bash
   make screenshots
   ```

   Inspect the World Map for one and two stars. Do not commit generated PNGs.
3. Ask the user to run `make play` and verify: create/deploy a party; observe
   Goblin Camp with `★` and Orc Outpost with `★★`; select/enter/clear one;
   confirm the other remains enterable; advance 15 World Map turns; confirm
   exactly one replacement appears and no site label contains text or gold.
4. After explicit user signoff, commit any final design-record adjustment,
   merge locally into `main`, and remove the branch:

   ```bash
   git add docs/plans/first-playable-campaign/game-design.md
   git commit -m "docs: record two starting encounter choices"
   git checkout main
   git merge <feature-branch>
   git branch -d <feature-branch>
   ```

   Do not push or open a PR unless the user asks.

## Milestone

The two-site strategic choice is manually confirmed and accurately documented
before local integration.
