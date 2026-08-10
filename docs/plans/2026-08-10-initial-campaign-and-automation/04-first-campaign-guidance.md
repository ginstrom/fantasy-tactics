# Step 4: Add a Dismissible First-Campaign Guide

## Milestone

A new player receives short contextual next-action guidance through one reward-to-improvement loop, without a modal or input blocker.

## Setup and files

Work after Step 3. Read `tests/unit/test_first_campaign_ui_flow.gd`, Encampment/Party/Deploy/World Map scripts, and the localization section of `docs/dev/code-map.md`.

- Create: `scripts/ui/campaign_guide.gd`, `scenes/ui/campaign_guide.tscn`, `tests/unit/test_campaign_guide.gd`
- Modify: `scripts/autoload/game_session.gd`, `scripts/ui/encampment.gd`, `scripts/world/world_map.gd`
- Modify: `scenes/ui/encampment.tscn`, `scenes/world/world_map.tscn`, `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`, `tests/unit/test_first_campaign_ui_flow.gd`

## Red

Add a compact durable `tutorial_progress` field (included in Step 1 snapshot work). Test a derived `get_campaign_guide_state()` for form party, deploy, select/commit route, enter site, return to bank, and choose the first affordable improvement. Each message must show once, be dismissible, and survive save/load.

In the UI-flow test, instantiate real scenes and push a click through a guided World Map region. Assert the guide uses `MOUSE_FILTER_IGNORE` (or equivalent) and does not prevent selection/routing. Run focused guide/UI-flow tests; expected: FAIL because guide state and scene do not exist.

## Green

Implement derived guide-state query plus explicit dismissal recording. The guide renders one localized message, optional target cue, and Dismiss action; it does not route or alter campaign state except explicit dismissal. Instance it only on Encampment/World Map surfaces. Do not add battle modals, timers, forced input, or F9 dependencies.

Update screenshot tour only if a deterministic tour route should show the guide. Run focused tests, `make check`, editor scan, `git diff --check`, and `make screenshots` (or `xvfb-run make screenshots`).

## Manual verification and commit

Run `make play` without F9; follow the guide through party creation, deployment, travel, battle, banking, and recruitment/equipment/Guild Hall. Confirm each message is concise/dismissible and does not reappear after resume.

```bash
git add scripts/autoload/game_session.gd scripts/ui/campaign_guide.gd scenes/ui/campaign_guide.tscn scripts/ui/encampment.gd scripts/world/world_map.gd scenes/ui/encampment.tscn scenes/world/world_map.tscn translations/en.tres tests/unit/test_game_session.gd tests/unit/test_first_campaign_ui_flow.gd tests/unit/test_campaign_guide.gd
git commit -m "feat: guide the opening campaign loop"
```

Include tour files only if changed. Record results for Step 8; do not merge before signoff.
