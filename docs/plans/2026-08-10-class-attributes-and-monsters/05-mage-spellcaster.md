# Step 5 — Mage and Spellcaster

## Milestone

A Mage has a limited MP resource and one readable damaging/control spell with counterplay; it meaningfully differs from a ranged Scout.

## Setup and red/green tasks

Branch from updated `main` as `feat/mage-spellcaster` and run `make check`. Write failing tests for MP persistence/restore, cast legality/cost, area targeting, effect expiry, and no-resource rejection. Add MP only as a Mage-owned resource, then one spell and one counterable control effect before the Mage template and Spellcaster branch. Verify focused tests, `make check`, editor scan, scenarios against swarms and resistant/control enemies, and `git diff --check`. In `make play`, confirm the Mage is powerful but fragile and resource-limited. After user signoff, commit and merge locally to `main`; delete the branch and do not push.
