# Step 6 — Specializations and Additional Monsters

## Milestone

Each specialization and monster family arrives as a bounded, counterable content slice—not as raw stat inflation—and is evidenced against level-1 and level-2 Warrior baselines plus the mixed party it is intended to challenge.

## Setup and red/green tasks

For each approved slice, branch from updated `main` using a named `feat/<specialization-or-monster>` branch. Add failing tests for the exact perk/ability or monster template, composition, rewards, and counterplay before implementation. Start with Knight/Archer/Battle Mage/Paladin only once the necessary core primitive is live; introduce Bandit, Skeleton, Wolf, Giant Spider, Ogre, or Wraith only with its required primitive from the monster manual. Run focused tests, `make check`, editor scan, seeded scenarios, and `git diff --check`; then manually verify with `make play`. After user signoff, commit, merge locally to `main`, delete the branch, and do not push.
