# Step 3 — Blacksmith

## Milestone

The Blacksmith crafts a normal item and upgrades one owned weapon with Sharpened, adding exactly +1 raw damage before Might and Resistance.

## Red/green delivery

Branch as `feat/blacksmith`. Add failing tests for building gate, recipe/resource validation, item conversion, same-category replacement, and deterministic Sharpened combat damage. Implement recipe data, Blacksmith state/UI, and one normal craft plus Sharpened. Verify focused tests, `make check`, editor scan, simulation comparison, and `git diff --check`; use `make play` to craft, equip, and battle-test the result. After user signoff, commit, merge locally, delete the branch, and do not push.
