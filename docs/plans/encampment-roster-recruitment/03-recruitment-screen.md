# 03 — Recruitment Screen and Summary Action

## Milestone

Recruitment renders candidates in `TableView`; selection shows an explicit affordable purchase action, and successful purchase routes to Roster.

## Files

- Create: `scenes/ui/recruitment.tscn`, `scripts/ui/recruitment.gd`, `scripts/ui/recruitment.gd.uid`, `tests/unit/test_recruitment.gd`, `tests/unit/test_recruitment.gd.uid`
- Modify: `scenes/ui/units.tscn`, `scripts/ui/units.gd`, `scenes/ui/information_panel.tscn`, `scripts/ui/information_panel.gd`
- Modify: `scripts/autoload/game_manager.gd`, `tests/unit/test_units.gd`, `tests/unit/test_information_panel.gd`, `tests/unit/test_game_manager.gd`

## Steps

1. **Red:** create Recruitment tests for Name/Class/Level/Cost columns, current-only candidate rows, empty state, Back → Units, and Escape. Require selecting a candidate to show its 10-gold summary/action; action is disabled with 0 gold, enabled at 10, routes to Roster only after a one-time purchase, and refreshes safely when the displayed candidate became stale.
2. **Red:** require enabled/routed Recruitment in Units. Add InformationPanel tests for `refresh_recruitment_candidate(id)`, stable-ID signal emission, insufficient-funds disabled state, and clearing its optional section when party/adventurer/bare refresh occurs.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_recruitment,test_units,test_information_panel,test_game_manager -gexit
   ```

   Expected: missing screen and panel API failures.
4. **Green:** create the Recruitment scene/controller with `RecruitmentTable: TableView`, columns including translated cost formatting, empty label, Back, and InformationPanel. Table selection must not itself purchase.
5. **Green:** extend InformationPanel with candidate name/class/level/cost rows, disabled-by-default recruit button, `recruit_selected(candidate_id)`, and `refresh_recruitment_candidate(id)`. Resolve the candidate fresh from `GameSession`; normal refresh methods hide/clear candidate rows.
6. **Green:** add a narrow `GameManager.purchase_recruit(id)` Error wrapper. Recruitment calls it from the panel signal, goes to Roster only on `OK`, otherwise clears selection and refreshes. Enable/connect Recruitment in Units.
7. Re-run focused tests. Commit:

   ```bash
   git add scenes/ui/recruitment.tscn scripts/ui/recruitment.gd scripts/ui/recruitment.gd.uid scenes/ui/units.tscn scripts/ui/units.gd scenes/ui/information_panel.tscn scripts/ui/information_panel.gd scripts/autoload/game_manager.gd tests/unit/test_recruitment.gd tests/unit/test_recruitment.gd.uid tests/unit/test_units.gd tests/unit/test_information_panel.gd tests/unit/test_game_manager.gd
   git commit -m "feat: add gold-costed recruitment"
   ```
