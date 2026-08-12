# Step 1: Starting Shop Economy, Upgrade, and Rename

> **Branch:** `feat/shop-economy-and-rename` (off updated local `main`)

## Setup

```bash
git checkout main && git pull
git checkout -b feat/shop-economy-and-rename
```

## Goal

Ship a level-1 Shop in every new campaign, retain passive Shop income to the
player, add the defined Shop cash/upgrade/catalogue rules, and remove visible
"Trading Post" wording without breaking old saves.

## Contract

- `GameSession.shop_level` starts at `1`; `shop_gold` starts at `100`.
- Level 1 offers only `_iron` weapons. `upgrade_shop()` costs 50 player gold,
  moves to level 2, caps refills at 200, and additionally offers `_steel`
  weapons. Armour is not part of either catalogue in this slice.
- `sell_item()` must validate the complete sale price and Shop cash before
  mutating inventory, player gold, or Shop gold. A sale moves sale-price gold
  from Shop to player. `buy_item()` accepts only the unlocked catalogue,
  validates player gold, and moves purchase-price gold from player to Shop.
- At each successful `end_world_turn()` whose incremented `world_turn % 10 ==
  0`, refill Shop gold to `max(shop_gold, shop_gold_cap())`; do not lower an
  over-cap value. Keep existing passive income to player gold every successful
  turn.
- New snapshots write `shop_level` and `shop_gold`. Import old snapshots by
  deriving level 1/0 from `has_trading_post` and a safe starting pool when no
  Shop fields exist; new-game state is level 1 regardless of that legacy flag.
  Keep legacy snapshot support only; all player-visible text/routes use Shop.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`, `scripts/autoload/game_config.gd`
- Modify: `scripts/ui/trade.gd`, `scripts/ui/trading_post.gd`, `scenes/ui/trade.tscn`, `scenes/ui/trading_post.tscn`, `translations/en.tres`
- Modify: Shop-facing debug/screenshot labels and all affected existing tests.
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_trade.gd`, `tests/unit/test_trading_post.gd`, `tests/unit/test_full_trade_loop_integration.gd`, `tests/unit/test_localization.gd`

## Red/Green Tasks

1. Add failing session tests for new-game level/cash, level-1 iron-only
   catalogue, rejected steel purchase, atomic cash-limited sale, buy adding
   Shop gold, level-2 upgrade cost/catalogue, turn-10 top-up, no top-up on a
   blocked turn, no over-cap reduction, and retained passive player income.
   Run the focused test file and confirm the new assertions fail.
2. Add failing snapshot tests for Shop round trips and legacy `has_trading_post`
   migration. Assert an invalid level/cash import changes no live state.
3. Add failing UI tests: Trade always lists Stores and Shop, Shop displays its
   cash/level and only unlocked weapon rows, and an unavailable action is
   disabled. Update old purchase-gate expectations rather than retaining a
   second purchase path.
4. Implement the smallest `GameSession` API: cap/catalogue queries,
   `can_upgrade_shop`/`upgrade_shop`, validation-before-mutation buy/sell, and
   periodic refill. Extend snapshot normalization/export/import atomically.
5. Rename user-visible translation keys, scene text, labels, test names, and
   `GameManager.go_to_shop()`; retain an internal legacy route alias only when
   it prevents compatibility churn. Run `rg -n -i 'Trading Post'` and leave
   only documented legacy-schema/internal allowlist matches.
6. Run focused tests green, then `godot --headless --path . --editor --quit`,
   `make check`, and `git diff --check`.

## Manual milestone and merge

With `make play`, start a new campaign and verify Shop is immediately reachable,
has 100 Shop gold, sells iron weapons only, and adds passive player income on a
successful End Turn. Sell until Shop funds block the next sale; buy an item and
verify its purchase price increases Shop funds. At 10 turns verify refill only
up to its cap. Upgrade for 50 player gold; verify a 200 cap and steel weapons.
After user signoff, commit, merge this branch locally into `main`, and delete it.
