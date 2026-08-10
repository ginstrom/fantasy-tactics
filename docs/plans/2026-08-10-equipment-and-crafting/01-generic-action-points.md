# Step 1 — Generic Action Points

## Milestone

Every unit receives 6 AP each Round; movement costs 1 AP per tile, basic attacks cost 3 AP, and repeated legal attacks are possible while AP remains.

## Red/green delivery

Branch from updated `main` as `feat/generic-action-points`. Add failing GUT tests for initial/reset AP, three moves plus attack, two stationary attacks, insufficient-AP rejection, enemy AP behavior, and existing input paths. Implement AP on runtime `Unit`, legal-action validation in `BattleController`, and AP HUD feedback without moving durable campaign ownership. Run focused tests, `make check`, editor scan, seeded simulations against every current monster composition, and `git diff --check`. Use `make play` to verify movement, repeated attacks, and End Turn. After user signoff, commit, merge locally to `main`, delete the branch, and do not push.
