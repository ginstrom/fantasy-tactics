# Task 07: Screenshot tour's Stores step shows Sell enabled

## Objective

The screenshot tour's `stores` step runs before its `trading_post` step,
so the Stores screenshot renders with the Sell button disabled (no Trading
Post owned yet) — not the representative screenshot a developer skimming
the tour's output would expect. Give the `stores` step its own
`has_trading_post = true`, matching how it already seeds `banked_gear`/
`mana_crystals` for a representative shot.

This is screenshot-tour-only, dev-tooling behavior — it has no test suite
of its own (per the existing codebase convention; `scripts/tools/` is
explicitly non-test tooling per `docs/dev/code-map.md`'s directory map)
and does not affect shipped gameplay.

## Files

- Modify: `scripts/tools/screenshot_tour.gd`

## Depends on

None.

## Steps

1. **Update the `stores` step.** In `scripts/tools/screenshot_tour.gd`,
   find:

   ```gdscript
   		{"name": "stores", "action": func() -> void:
   			GameSession.banked_gear = {"shortsword_iron": 1}
   			GameSession.mana_crystals = {1: 2}
   			GameManager.go_to_stores()},
   ```

   and add `has_trading_post = true` so the Sell button renders enabled:

   ```gdscript
   		{"name": "stores", "action": func() -> void:
   			GameSession.banked_gear = {"shortsword_iron": 1}
   			GameSession.mana_crystals = {1: 2}
   			GameSession.has_trading_post = true
   			GameManager.go_to_stores()},
   ```

2. **Run the full suite** — this file has no dedicated tests, so this step
   just confirms the edit didn't break anything else:

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

3. **Regenerate the screenshots and confirm the Stores frame now shows Sell
   enabled:**

   ```bash
   make screenshots
   ```

   Check `screenshots/07_stores.png` (the exact filename number may shift
   if earlier steps were added/removed — check the tour's console output
   for the actual path) — the Sell button should no longer be greyed out.

4. **Commit** only this task's file:

   ```bash
   git add scripts/tools/screenshot_tour.gd
   git commit -m "fix: seed has_trading_post for the screenshot tour's Stores step"
   ```

## Milestone

The Stores screenshot in the developer tour is representative of a
player who already owns the Trading Post — the more common state once
they've unlocked selling at all.
