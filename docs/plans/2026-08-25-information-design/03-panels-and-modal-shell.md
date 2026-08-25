# Step 3: Panels and Modal Shell

**Milestone:** World Map information has distinct top/right/bottom zones, and
a reusable centered blocking modal supports button and Escape dismissal.

**Depends on:** Step 2 merged.

**Source contracts:** `docs/plans/2026-08-25-information-design.md`,
`scenes/world/world_map.tscn`, `scripts/world/world_map.gd`,
`scenes/ui/information_panel.tscn`, `scripts/ui/campaign_objective_banner.gd`,
and `tests/unit/test_world_map.gd`.

**Files:** create `scenes/ui/modal_dialog.tscn`, `scripts/ui/modal_dialog.gd`,
and `tests/unit/test_modal_dialog.gd`; modify `scenes/world/world_map.tscn`,
`scripts/world/world_map.gd`, `scenes/ui/campaign_objective_banner.tscn`,
`tests/unit/test_world_map.gd`, and `translations/en.tres`.

1. Branch `feat/information-design-panels`. Add a failing modal test that
   proves it blocks underlying input, emits one dismissal through button or
   `ui_cancel`, and refuses Escape for a required unresolved choice. Run
   `-gselect=test_modal_dialog.gd` red.
2. Implement the smallest reusable full-screen dim backdrop, large centered
   content panel, focus handling, dismissal action, and narrow presentation
   API. It owns no game state. Re-run the modal test green.
3. Add failing World Map scene tests asserting objective banner, right
   InformationPanel, and bottom hint have non-intersecting rects at the
   supported viewport and legacy overlapping guidance is absent. Run
   `-gselect=test_world_map.gd` red.
4. Re-layout existing panels into named top/right/bottom containers. Preserve
   InformationPanel data and input semantics; move redundant guidance to the
   compact bottom hint or a future Journal event, not another floating panel.
   Re-run focused tests green, then run `make screenshots` and inspect World Map.
5. Review and request manual `make play` confirmation that no panel obscures
   the board. After signoff commit, merge locally, delete branch, and hand off
   modal API and fixed zone geometry.
