# Step 4 — Alchemy Workshop

## Milestone

The Alchemy Workshop creates three assigned tactical potions and applies Basic Accuracy; each potion costs 2 AP and has a shared temporary-effect lifecycle.

## Red/green delivery

Branch as `feat/alchemy-workshop`. Add failing tests for building/material gates, assignment, 2-AP use, one-time consumption, invalid-use non-consumption, duration expiry, cap/refresh rules, and Basic-versus-Advanced replacement. Implement the generic timed-effect contract before potion UI/recipes. Verify focused tests, `make check`, editor scan, mixed combat simulations, and `git diff --check`; use `make play` to make, assign, and use each potion. After user signoff, commit, merge locally, delete the branch, and do not push.
