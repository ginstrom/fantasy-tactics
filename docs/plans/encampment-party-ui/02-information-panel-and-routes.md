# Step 02: Contextual information panel and routes

## Milestone

The reusable right-side panel reliably displays global player context plus an
optional selected party or adventurer summary and raises a View intent; route
ownership remains in `GameManager`.

## Setup

1. Start from merged `main` after Step 01 and create
   `feat/encampment-information-panel`.
2. Review `scenes/ui/information_panel.tscn`,
   `scripts/ui/information_panel.gd`, `scripts/autoload/game_manager.gd`, and
   `tests/unit/test_information_panel.gd`.

## Files

- Modify: `scenes/ui/information_panel.tscn`
- Modify: `scripts/ui/information_panel.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_information_panel.gd`
- Modify: `tests/unit/test_game_manager.gd`

## Red: add focused failing tests

Write tests showing that:

1. `refresh()` always renders `Player: <name>` and `Gold: <amount>`;
2. `refresh_party(party_id)` shows party name, `Members: N`, and a View button;
   unknown IDs clear optional content without hiding player/gold;
3. `refresh_adventurer(adventurer_id)` shows name, class, and level plus View;
   unknown IDs clears optional content safely;
4. each View button emits an ID-bearing signal rather than changing scenes;
5. new `GameManager` named routes for Units, Parties, Party Details,
   Unit Details, and Deploy Party resolve to their declared scenes after those
   scene paths are introduced (initially assert the constants/API surface, not
   a non-existent visual hierarchy).

Run the two focused test files with GUT and confirm they fail on the missing
panel controls/signals/routes.

## Green: minimal implementation

1. Add optional-content containers below the permanent player/gold rows. Use
   `party_selected(party_id)` and `adventurer_selected(adventurer_id)` signals
   from the panel; controls must not call `GameManager`.
2. Replace the current world-map-specific `party_active`/pending-reward view
   with explicit refresh methods. Preserve World Map behavior by having it
   request its selected party summary; keep banked gold as the permanent value.
3. Add translations for member count, class, level, view, Units, Parties,
   Party Details, Unit Details, Deploy Party, and TBD wording.
4. Add route constants and named `GameManager` methods. Detail routes accept
   an ID through a short-lived route context owned by `GameManager`, cleared on
   invalid navigation; do not put UI row selection into `GameSession`.

Run focused tests, then `make check`, editor scan, and `git diff --check`.

## Manual check and commit

Open the World Map debug scenario and verify player/gold remains visible and
party context appears only after map selection. After user signoff:

```bash
git add scenes/ui/information_panel.tscn scripts/ui/information_panel.gd scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_information_panel.gd tests/unit/test_game_manager.gd
git commit -m "feat: add contextual information panel"
git checkout main && git merge --ff-only feat/encampment-information-panel
git branch -d feat/encampment-information-panel
```

Do not push.
