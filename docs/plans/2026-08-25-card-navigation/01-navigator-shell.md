# Step 1 — Navigator shell and test contract

**Milestone:** A reusable full-screen navigator can render caller-provided
content for a stable ordered ID snapshot, wraps correctly, and closes without
changing game state.

**Branch:** `feat/card-navigator-shell` from current `main`.

**Files:**

- Create: `scenes/ui/card_navigator.tscn`
- Create: `scripts/ui/card_navigator.gd`
- Create: `tests/unit/test_card_navigator.gd`
- Modify: `translations/en.tres`
- Modify: `docs/dev/code-map.md`

## Red/green tasks

1. Add tests that instantiate the real scene and assert: full-screen input
   blocking; centered card panel; `open(["a", "b", "c"], "a")` emits/requests
   `a`; previous selects `c`; next selects `a` after `c`; count reads `1 of
   3`; and a one-item session disables both arrows.
2. Run
   `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_card_navigator.gd -gexit`.
   Expect failure because the scene/script do not exist.
3. Add `CardNavigator` with an ID-snapshot API (for example `open_ids`,
   `show_id`, and `close`), `card_changed(id)` and `closed(last_id)` signals,
   a `ContentContainer` for caller-owned card bodies, and defensive rejection
   of an empty snapshot or an ID absent from it. Make button handlers use
   modular index arithmetic; never mutate caller rows or `GameSession`.
4. Add localized strings for Previous, Next, Close, and `%d of %d`; connect
   Escape to Close; focus the selected card's first focusable control or
   Close; and expose one focused restoration target supplied by the caller.
5. Re-run the focused test until green. Add tests for Escape being handled,
   Close returning the final ID, invalid initial ID refusing to open, and a
   caller replacing content without retaining the old child.
6. Update the UI component map with the new shell and its ownership boundary.

## Verification and review

Run the focused command above, `godot --headless --path . --editor --quit`,
and `git diff --check`. Reviewer checks that it is not folded into
`ModalDialog`, does not touch `GameSession`/`GameManager`, and owns no
domain-specific rendering. Manual `make play`: use a temporary/dev harness
only if needed to see the centered shell, arrows, and Escape behavior.

After user signoff, commit only listed files with
`feat(ui): add reusable card navigator`, merge locally, delete the branch,
and record the base/merge commit and API contract for Step 2.
