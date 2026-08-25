# Step 5 — Coverage audit, regression gate, and handoff

**Milestone:** Every current player-facing table/list has an explicit card
navigation disposition, automated coverage is complete, and the UI is
manually accepted as one coherent system.

**Depends on:** Steps 1–4 merged.

**Branch:** `feat/card-navigator-exit-gate` from updated `main`.

**Files:**

- Modify: `docs/dev/code-map.md`
- Modify: `docs/designs/` documentation only where it describes a migrated
  player-facing detail flow
- Modify: affected focused tests only for audit gaps discovered below
- Create: `docs/plans/2026-08-25-card-navigation/verification.md`

## Red/green tasks

1. Inventory all current `TableView`, `LootTable`, and dynamic Journal list
callers. Record one of: **navigable card integrated** (Roster, Add Member,
Party Details members, Recruitment, Shop, Stores, party carry, battle loot,
Journal, Battle Outcome level-ups) or **not a detailed-entry list** with a
reason (currently Buildings, Trade, Deploy Party, and assignment selectors).
2. Add a failing focused regression test for every integrated caller that
does not prove its displayed-order snapshot, wraparound, Close/Escape
restoration, and stale-ID behavior. Do not claim a non-detail action list is
covered by a superficial navigator test.
3. Implement only the missing tests/documentation or narrowly scoped fixes;
do not expand the excluded lists into invented detail cards.
4. Run focused UI tests, then `make check`,
`godot --headless --path . --editor --quit`, `git diff --check`, and
`make screenshots`. Capture exact pass counts/paths and any known visual
limitations in `verification.md`.

## Manual acceptance and merge

Run `make play` and record: visual dominance/centering; arrows and `N of M`;
first/last wrapping; Close and Escape restoration; stale-entry safety after
recruit/sell; source-local item actions; Journal section preservation; and a
two-member required-perk outcome. Manual approval is required before commit.

The reviewer must inspect `git diff <base>...HEAD` for unrelated behavior,
duplicate detail shells, route-context persistence, and any plan/document
claim not backed by test evidence. After user signoff, commit the audit,
merge locally to `main`, delete branch, and hand off the merge commit,
verification output, manual results, exclusions, and future-call-site rule:
new player-facing detailed rows must use `CardNavigator` rather than create a
new bespoke detail overlay.
