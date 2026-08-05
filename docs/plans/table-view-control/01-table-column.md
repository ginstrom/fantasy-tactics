# Step 1: Define `TableColumn`

## Milestone

Callers can declare typed table columns with presentation defaults and optional
formatter, comparator, and button-label callables.

## Setup

Work in the `feat/table-view-control` worktree. Use the project test command:
`godot --headless -s addons/gut/gut_cmdln.gd -gexit`.

## Files

- Create: `scripts/ui/table_column.gd`
- Create: `tests/unit/test_table_column.gd`

## Red

1. Create `tests/unit/test_table_column.gd`, extending `GutTest`.
2. Add a test that preloads `res://scripts/ui/table_column.gd`, constructs
   `TableColumn.new(&"level", "Level", TableColumn.Type.INTEGER)`, and asserts its key, title, type, and defaults: non-editable, sortable, visible, non-expanding, ratio `1`, width `0`, and left alignment.
3. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_table_column -gexit`. Expect a load failure because the script does not exist.

## Green

1. Implement `TableColumn` as `class_name TableColumn` extending `RefCounted`.
2. Declare `Type` with `TEXT`, `INTEGER`, `FLOAT`, `BOOLEAN`, `ICON`, and `BUTTON` members.
3. Add the typed properties agreed in the design: key, title, type, layout and edit/sort flags, alignment, plus `formatter`, `comparator`, and `button_text` callables.
4. Add the three-argument constructor with `TEXT` as its default type.
5. Re-run the focused test and expect it to pass.

## Refactor and commit

Run `make test`, then `git diff --check`. Commit only these files:

```bash
git add scripts/ui/table_column.gd tests/unit/test_table_column.gd
git commit -m "feat: add TableColumn descriptor"
```
