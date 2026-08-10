# Step 3 — Scout and Ranger

## Milestone

A Scout can be recruited and fielded beside a Warrior, make a legal ranged attack, and provide pre-battle scouting information that affects route or encounter choices.

## Setup and red/green tasks

Branch from updated `main` as `feat/scout-ranger` and run `make check`. Add failing tests for ranged target legality, blocked/invalid lines, Scout recruitment, displayed enemy information, and an encounter where the Scout's range matters. Add only the range/line-of-sight primitive, Scout template, basic scouting UI, and one initial Ranger specialization choice. Verify focused tests, `make check`, editor scan, simulator scenarios (Warrior-only versus Warrior+Scout), and `git diff --check`. Use `make play` to confirm ranged attacks cannot replace front-line positioning. After user signoff, commit and merge locally to `main`; delete the branch and do not push.
