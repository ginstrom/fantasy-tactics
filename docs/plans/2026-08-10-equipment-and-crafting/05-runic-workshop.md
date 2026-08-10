# Step 5 — Runic Workshop

## Milestone

One eligible item can socket a Thorn Rune; its validated melee-hit trigger can Paralyze an attacker through the shared event/effect system.

## Red/green delivery

Branch as `feat/runic-workshop`. Add failing tests for socket compatibility, atomic replacement outcome, trigger order, chance seam, melee-only tags, duration/immunity/refresh behavior, UI feedback, and AI response. Implement shared battle events/statuses before rune crafting and one-socket UI. Verify focused tests, `make check`, editor scan, seeded trigger simulations, and `git diff --check`; use `make play` to observe a Thorn trigger and replacement. After user signoff, commit, merge locally, delete the branch, and do not push.
