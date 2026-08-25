# Step 3 — Recruitment and item cards

**Milestone:** Recruitment, Shop, Stores, and deployed-party/battle loot use
the shared shell for their detailed candidates and items without changing
purchase, sell, equip, or reward rules.

**Depends on:** Step 2 merged.

**Branch:** `feat/card-navigator-items` from updated `main`.

**Files:**

- Create: `scenes/ui/recruitment_card.tscn`, `scripts/ui/recruitment_card.gd`
- Create: `scenes/ui/item_detail_card.tscn`, `scripts/ui/item_detail_card.gd`
- Modify: `scenes/ui/recruitment.tscn`, `scripts/ui/recruitment.gd`
- Modify: `scenes/ui/trading_post.tscn`, `scripts/ui/trading_post.gd`
- Modify: `scenes/ui/loot_table.tscn`, `scripts/ui/loot_table.gd`
- Modify: `scripts/ui/loot_detail_panel.gd`, `scenes/ui/loot_detail_panel.tscn`
- Modify: `scripts/ui/stores.gd`, `scripts/ui/party_details.gd`,
  `scripts/ui/battle_result.gd`
- Modify: `tests/unit/test_recruitment.gd`, `tests/unit/test_loot_table.gd`,
  `tests/unit/test_stores.gd`, `tests/unit/test_trading_post.gd`,
  `tests/unit/test_party_details.gd`, `tests/unit/test_battle_result.gd`
- Modify: `translations/en.tres`

## Red/green tasks

1. Test that Recruitment opens a candidate card from a row/View action and
   cycles over the candidate snapshot. Verify a successful recruit closes,
   refreshes, and follows its existing target-party or Roster return route;
   a stale candidate cannot spend gold.
2. Test Shop item cards include actual item attributes and Buy; they wrap by
   currently displayed catalogue order and revalidate price/catalogue at
   press time. Test Store and carried/battle-loot item cards keep their
   caller-specific Sell/Equip visibility and quantity-dialog behavior.
3. Run the focused test files. Expect red failures for absent card bodies and
   old `LootDetailPanel` behavior.
4. Implement the two bodies and migrate callers. `LootTable` becomes the
   list adapter that supplies its exact `_rows_by_id` display order to
   `CardNavigator`; it continues to emit `equip_requested`/`sold` and does
   not know a caller's route. Retire `LootDetailPanel` only after all callers
   are migrated and its coverage is ported.
5. Preserve transactional validation by calling existing `GameSession`
   purchase/sell/equip methods immediately before mutation. A mutation that
   removes an entry invalidates that entry and closes/rebuilds the session;
   a non-removing action refreshes the active card.
6. Run focused tests, then `make check`, editor validation, and diff check.

## Manual check and handoff

In `make play`, cycle recruits; buy shop gear; cycle stored and carried loot;
sell a stack; and start Equip from an item card. Confirm card close returns
to the exact source list and does not cross into another source's inventory.
Reviewer checks reward pending/banked boundaries and Shop cash validation are
unchanged. After signoff, commit, merge locally, delete branch, and hand the
remaining Journal/Battle integration report to Step 4.
