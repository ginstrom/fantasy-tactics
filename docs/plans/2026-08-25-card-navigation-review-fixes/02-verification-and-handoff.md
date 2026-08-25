# Step 2 — Correct verification formatting and run the regression gate

**Milestone:** The verification report’s formatting claim is true for the feature range, and the repair has fresh automated evidence.

**Files:**

- Modify: `docs/plans/2026-08-25-card-navigation/verification.md`
- Modify: `docs/plans/2026-08-25-card-navigation-review-fixes/index.md`

## Red/green tasks

1. Run `git diff --check d4a177a..HEAD`; it must report the two Markdown trailing-whitespace lines in the original verification report.
2. Remove the hard-break spaces after the Date and Plan metadata lines without changing their content.
3. Re-run `git diff --check d4a177a..HEAD`; it must exit 0.
4. Run `make check`, `godot --headless --path . --editor --quit`, and `git diff --check` from the branch tip. Record the exact commands/results in the final handoff; do not claim manual verification without user confirmation.

## Handoff

Review the final diff for only the two interaction fixes, their focused regression tests, the whitespace correction, and this repair plan. Ask the user to run the Step 1 manual check. Only user signoff authorizes the local commit and merge to `main`.
