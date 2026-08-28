# Step 03 — Guild Hall recruitment capacity

**Objective:** Populate every newly unlocked recruitment-offer slot when the
Guild Hall advances from 4 to 8, then 8 to 10 offers.

**Dependency:** Step 02 merged. **Branch:** `fix/guild-hall-recruitment-capacity`.

## Required policy confirmation

Before coding, ask the user to confirm the approved recommendation: upgrades
immediately fill newly unlocked vacancies with ordinary recruitment offers;
no simulated time passes, current offers remain, and the normal template and
overflow rules select new offers. If declined, revise this step and obtain a
new review before implementation.

## Files

- Modify: `scripts/autoload/game_session.gd:2430-2436`
- Modify: `tests/unit/test_game_session.gd` beside Guild Hall cap/upgrade tests
- Inspect: `scripts/autoload/game_session.gd:3730-3795` vacancy/offer helpers
- Inspect: `scripts/ui/guild_hall.gd` only to confirm the existing refresh path

## Red/green TDD

1. Add regressions on a fresh `GameSession` proving a successful level 1→2
   upgrade leaves eight valid offers and level 2→3 leaves ten; assert existing
   offers are preserved, each new ID is unique, and failed/max upgrades do not
   mint candidates. Do not call a private helper in the expectation unless the
   test first proves the public `upgrade_guild_hall()` behavior.
2. Run the focused file red:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```
3. In `upgrade_guild_hall()`, after the level changes, fill only the difference
   between candidate count and `get_recruitment_offer_cap()` through the
   established offer-generation boundary. Retain gold checks and all
   candidate-template/overflow invariants.
4. Run focused green, then full/static/diff checks.

## Review, manual confirmation, merge

Reviewer checks both upgrade levels, no duplicate IDs, and no accidental
gold/time/vacancy behavior. Manual check through `make play`: fund and upgrade
the Guild Hall in a debug state, then verify the recruitment view shows the
new simultaneous capacity. After user signoff, commit
`fix(recruitment): fill guild hall offer capacity on upgrade`, merge locally,
delete the branch, and record the policy decision.
