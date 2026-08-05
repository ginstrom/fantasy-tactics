# TableView Control Implementation Plan

## Goal

Create a code-only `TableView` Godot control backed by a private `Tree`, plus
`TableColumn` descriptors and GUT coverage. The control renders external row
dictionaries and emits interactions without becoming the owner of game data.

## Scope

The first version provides text, integer, float, boolean, and button columns;
single selection; sorting; global text filtering; optional formatting; and
edit/action signals. It does not migrate any existing screen or add search UI,
pagination, multi-selection, column hiding, or persisted layout.

## Order and checkpoints

1. [Define `TableColumn`](01-table-column.md) — descriptor API and its unit contract.
2. [Render and transform rows](02-render-sort-filter.md) — Tree rendering, formatting, filtering, and sorting without changing caller-owned rows.
3. [Emit UI intents](03-selection-edit-actions.md) — selection, activation, editable cells, and button actions with no model mutation.
4. [Validate and hand off](04-validate-and-merge.md) — full checks, Godot script scan, user `make play` verification, commit, and local merge after signoff.

Every implementation step follows red/green TDD. Perform the requested manual
verification before the final commit and merge; do not push.
