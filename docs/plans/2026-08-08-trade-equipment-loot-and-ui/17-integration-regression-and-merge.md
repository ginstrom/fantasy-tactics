# Task 17: Integration, regression sweep, manual verification, and merge

## Objective

Confirm the whole plan holds together as one system — not just task by
task — then get the user's manual sign-off and merge the branch back into
`main`. This is the task `AGENTS.md`'s "each step should be self-contained,
including... verification and merging feature branch back to main (after
user signoff)" calls for at the plan level; no earlier task in this plan
does a full regression sweep, an editor sanity check, or a manual pass.

## Files

- None expected to change; this task is verification-only unless the
  regression sweep in step 2 below turns up a straggler.

## Depends on

Tasks 01-16, all committed on `feat/trade-equipment-loot-and-ui`.

## Steps

### Full regression sweep

1. Confirm every task's commit landed and the branch is clean:

   ```bash
   git log --oneline main..HEAD
   git status
   ```

   Expected: 16 commits (one per Task 01-16), no uncommitted changes.

2. Run the full suite:

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

3. Grep for anything the individual tasks may have missed — every reference
   to the removed `attack_damage` field or the removed flat `reward` key:

   ```bash
   grep -rn "attack_damage\|\.reward\b" scripts tests
   ```

   Expected: no matches other than `SUPER_POWER_ATTACK_DAMAGE`/
   `WARRIOR_ATTACK_DAMAGE`-style const *names* that happen to contain the
   substring, and `pending_reward`/`deposit_pending_reward` (still a real,
   intentional field/method). If a real straggler turns up, fix it and
   rerun `make test`.

4. Confirm the project still opens cleanly in the editor (catches scene/
   script wiring mistakes GUT alone won't, e.g. a broken `NodePath` in one
   of the four new `.tscn` files):

   ```bash
   godot --headless --path . --editor --quit
   ```

5. Run `git diff --check main` to catch stray whitespace/conflict markers
   before manual verification.

6. Regenerate the screenshot tour and skim the new frames for anything
   visually broken (missing labels, misaligned columns, an empty table that
   should have rows):

   ```bash
   make screenshots
   ```

   Check `./screenshots/trade.png`, `stores.png`, and `trading_post.png`
   specifically — these are the three steps Task 16 added.

### Manual verification

7. Run `make play`. Walk the full loop by hand:
   - Encampment → Trade: confirm the Trade button is enabled and the screen
     shows "Stores" only, with "Purchase Trading Post (50 gold)" disabled
     at 0 gold.
   - Deploy the starting party, win the Goblin Camp: confirm the party's
     `InformationPanel` shows "Carried loot: 1 mana crystals, 0-1 gear"
     (gear is a 25% roll, so 0 or 1 is both correct) alongside the pending
     gold reward, before returning to the Encampment.
   - Return to the Encampment: confirm gold, mana crystals, and any dropped
     gear are banked (carried-loot row disappears).
   - Trade → Stores: confirm the banked mana crystal and any banked gear
     appear with the correct sell price; selling requires a Trading Post
     (Sell stays disabled until one is purchased).
   - Earn or grant enough gold to purchase the Trading Post (50 gold);
     confirm Trade now also lists "Trading Post", and Stores' Sell button
     becomes enabled.
   - Trade → Trading Post: confirm every weapon and armor from the catalog
     is listed with its correct price, and buying one it deposits into
     Stores.
   - Stores → select a purchased weapon → Assign to Unit: confirm the
     Warrior's equipment updates (visible from Unit Details) and the
     previously-equipped item returns to Stores.
   - Enter a battle with the newly-equipped weapon: confirm the Warrior's
     damage this attack falls inside the new weapon's documented range
     (not the old fixed value), and that leather armor's 10%
     defense/resistance are having a visible (if small) effect over several
     attacks.
8. Report the manual pass (or any deviation) to the user and wait for
   explicit sign-off before merging.

### Merge

9. Once approved:

   ```bash
   git checkout main
   git pull
   git merge feat/trade-equipment-loot-and-ui
   git branch -d feat/trade-equipment-loot-and-ui
   ```

   Do not push to `origin` or open a PR unless the user asks.

## Milestone

The full test suite is green end to end, the editor opens the project
without errors, the screenshot tour's new frames look correct, the user has
manually confirmed the complete equipment/loot/trade loop works as
designed, and the branch is merged into `main`.
