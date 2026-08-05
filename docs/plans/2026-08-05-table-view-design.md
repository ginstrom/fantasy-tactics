# TableView Design

## Goal

Provide one reusable Godot control for displaying tabular UI data without
turning `TreeItem` instances into game state. This change creates the control
only; existing Parties and Party Details screens will adopt it in later work.

## Chosen shape

`TableView` is a code-only `VBoxContainer` that creates and owns one child
`Tree` named `Tree`. A companion `TableColumn` `RefCounted` describes each
column. Screens configure the view with column descriptors and dictionaries,
then handle emitted interaction signals.

The initial version supports text, integer, float, boolean, and button
columns; single-row selection; column-title sorting; global text filtering;
formatted cells; and edit and action signals. Search inputs, pagination,
multi-selection, runtime column hiding, persistent widths, custom drawing,
and virtualization are intentionally out of scope.

## Data and interaction boundaries

`TableView` duplicates source rows into internal source and display lists. It
maps rendered `TreeItem` objects back to the matching row and stores only the
stable row ID as item metadata. Sorting and filtering affect the display list,
never the caller's rows.

Edits and button clicks emit intent (`row_id`, column key, and, for edits, a
parsed value). The receiving screen validates the intent, changes
authoritative game data if appropriate, and reloads the view. `TableView`
never silently changes caller-owned rows.

## Safety and test contract

Missing values render as blank values. Invalid tree interaction indices and
non-editable columns are ignored. Row IDs must be supplied by callers through
the configurable `row_id_key`; the control does not synthesize or repair IDs.

GUT coverage will prove stable-ID selection, filtering, typed sorting, and
the non-mutating edit/action signal contract. A minimal scene-based test host
will exercise the wrapped `Tree` through the public `TableView` API.
