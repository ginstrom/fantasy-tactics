# Step 6 — Verification and Local Merge

## Checklist

1. Confirm only the approved slice is changed with `git status --short` and `git diff --check`.
2. Run `make check` and `godot --headless --path . --editor --quit`.
3. Run the slice's seeded simulations and retain reproducible scenarios/results only.
4. Ask the user to complete the documented `make play` route and record the accepted AP/crafting/counterplay behavior.
5. Commit the focused slice, then after approval merge locally into `main` and delete its branch. Do not push or open a PR unless asked.
