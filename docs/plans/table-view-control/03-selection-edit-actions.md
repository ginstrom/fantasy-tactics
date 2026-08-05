# Step 3: Emit selection, edit, and action intents

## Milestone

Consumers can receive stable row IDs for selection, activation, edits, and button presses, while supplied rows remain unchanged.

## Files

- Modify: `scripts/ui/table_view.gd`
- Modify: `tests/unit/test_table_view.gd`

## Red

1. Add tests connecting to `row_selected`, `selection_changed`, `cell_edited`, and `action_pressed` on a test table.
2. Select a rendered item and assert selection returns its ID and the matching source dictionary through `get_selected_rows`.
3. Make an integer column editable, change its rendered cell, invoke the Tree edit signal path, and assert `cell_edited` carries an integer while the original input dictionary still holds its old value.
4. Trigger a button column and assert `action_pressed` contains the stable ID and descriptor key.
5. Run the focused GUT test. Expect failures for missing signals and methods.

## Green

1. Add `row_selected`, `row_activated`, `selection_changed`, `cell_edited`, `action_pressed`, and `sort_changed` signals to `TableView`.
2. Connect the Tree selection, activation, edit, and button signals in `_ready`.
3. Implement `get_selected_row_ids` and `get_selected_rows` via item metadata and `_source_rows`.
4. Parse editable integer, float, boolean, and text cells before emitting an edit signal. Ignore invalid column indices and non-editable columns.
5. Emit action intent using the button's stored column identity. Do not write back into `_source_rows` or any supplied row dictionary.
6. Re-run focused tests, then `make test` and `git diff --check`.

## Commit

```bash
git add scripts/ui/table_view.gd tests/unit/test_table_view.gd
git commit -m "feat: add TableView interaction signals"
```
