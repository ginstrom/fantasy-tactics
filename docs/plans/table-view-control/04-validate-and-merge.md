# Step 4: Validate, verify manually, and merge

## Milestone

The component is headlessly valid, regression-tested, manually reviewed in the
running game, committed, and ready for a local merge after user signoff.

## Automated verification

Run from the worktree:

1. `make check`
2. `godot --headless --path . --editor --quit`
3. `git diff --check`
4. `git status --short --branch`

Expected result: all GUT tests pass, Godot reports no script parse errors,
diff whitespace is clean, and only intended TableView files are staged or
committed. Inspect generated `.uid` files and keep only ones Godot requires.

## Manual verification

Ask the user to run `make play` from this worktree. They should confirm the
game reaches the existing start flow without errors; this foundation is not yet
wired into a screen, so no new in-game table is expected.

Do not claim completion or commit the final validation state until the user has
provided this signoff.

## Commit and local merge after signoff

1. `git add scripts/ui/table_column.gd scripts/ui/table_view.gd tests/unit/test_table_column.gd tests/unit/test_table_view.gd`
2. `git commit -m "feat: add reusable TableView control"`
3. `git -C /home/ryan/play/fantasy-tactics checkout main`
4. `git -C /home/ryan/play/fantasy-tactics merge feat/table-view-control`
5. `git -C /home/ryan/play/fantasy-tactics branch -d feat/table-view-control`

Leave the worktree in place until the merge succeeds. Do not push or open a
pull request.
