# Step 2: Render, filter, and sort rows

## Milestone

`TableView` owns a `Tree`, renders only display rows, formats supported cell
types, and transforms its internal display list without mutating source rows.

## Files

- Create: `scripts/ui/table_view.gd`
- Create: `tests/unit/test_table_view.gd`

## Red

1. Create a scene-hosted `TableView` in `test_table_view.gd` using `add_child_autofree`, then await one process frame so `_ready` creates its Tree.
2. Add a test that sets name and integer columns plus rows with IDs, calls `set_filter("bor")`, and asserts the Tree shows only Borin while the input row array remains unchanged.
3. Add a test that clicks or simulates the public sort path for an integer column and asserts numeric ascending then descending order, including equal values retaining their relative order.
4. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_table_view -gexit`. Expect a load failure because `table_view.gd` does not exist.

## Green

1. Implement `class_name TableView` as a `VBoxContainer`; create and configure exactly one child `Tree` in `_ready`.
2. Add `set_columns`, `set_rows`, `clear_rows`, `set_filter`, `clear_filter`, and `refresh`. Duplicate input row arrays before storing them.
3. Configure Tree columns from `TableColumn` widths, titles, expansion, and visibility settings. Render text, integer, float, boolean, and button cells; format floats to two decimals unless a formatter supplies text.
4. Filter text/integer/float columns case-insensitively. Sort using a three-way comparison (including custom comparators), not a negated boolean comparator.
5. Keep an internal item-to-row map and store the configured stable ID as item metadata. Do not add an API that treats TreeItems as game data.
6. Re-run the focused test; then run `make test` and `git diff --check`.

## Commit

```bash
git add scripts/ui/table_view.gd tests/unit/test_table_view.gd
git commit -m "feat: render TableView rows"
```
