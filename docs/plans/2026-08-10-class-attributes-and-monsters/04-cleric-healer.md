# Step 4 — Cleric and Healer

## Milestone

A Cleric provides limited targeted healing/protection to a mixed party, and the system expresses duration, target legality, and stacking limits clearly.

## Setup and red/green tasks

Branch from updated `main` as `feat/cleric-healer` and run `make check`. Begin with failing tests for healing target/range, defeated-unit exclusion, duration expiry, resistance caps, recruitment gating, and attrition scenarios. Add the smallest reusable effect-duration model before the Cleric template, ability UI, and one Healer branch. Verify focused tests, `make check`, editor scan, mixed-party simulator baselines, and `git diff --check`. In `make play`, verify healing improves a difficult encounter without allowing infinite stall. After user signoff, commit and merge locally to `main`; delete the branch and do not push.
