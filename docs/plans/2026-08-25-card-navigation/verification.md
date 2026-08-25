# Card Navigation System — Verification Report & Caller Audit

**Date:** 2026-08-25  
**Plan:** `docs/plans/2026-08-25-card-navigation/`  
**Milestone:** Step 5 — Coverage audit, regression gate, and handoff

---

## 1. TableView / LootTable / Dynamic List Caller Inventory

Every list, table, and dynamic collection in the codebase has been audited and catalogued with an explicit disposition:

### A. Integrated Callers (Navigable Card Navigator)

| Screen / Component | File | List Type | Card Body Component | Key Actions & Behaviors |
|---|---|---|---|---|
| **Roster** | `scripts/ui/roster.gd` | `TableView` (Adventurers) | `UnitDetailCard` | Browse roster, promote, equip/unequip, heal, party assignment. Order snapshot matches displayed table. |
| **Add Member** | `scripts/ui/add_member.gd` | `TableView` (Available Adventurers) | `UnitDetailCard` | Inspect eligible unassigned adventurers, cycle, assign to target party. |
| **Party Details (Members)** | `scripts/ui/party_details.gd` | `TableView` (Party Members) | `UnitDetailCard` | Inspect party members, promote, equip/unequip, heal. |
| **Recruitment** | `scripts/ui/recruitment.gd` | `TableView` (Candidate Offers) | `RecruitmentCard` | Inspect recruitment offers, purchase adventurer (general or targeted). |
| **Shop / Trading Post** | `scripts/ui/trading_post.gd` | `TableView` (Weapon Catalogue) | `ItemDetailCard` | Inspect shop weapons, purchase gear directly from card with gold deduction. |
| **Stores** | `scripts/ui/stores.gd` | `LootTable` (`TableView`) | `ItemDetailCard` | Inspect banked weapons, armor, mana crystals; sell or route to equip. |
| **Party Details (Carry)** | `scripts/ui/party_details.gd` | `LootTable` (`TableView`) | `ItemDetailCard` | Inspect carried gear & crystals of deployed party; equip directly from card. |
| **Battle Result (Loot)** | `scripts/ui/battle_result.gd` | `LootTable` (`TableView`) | `ItemDetailCard` | Inspect victory loot awards (read-only in battle summary). |
| **Journal** | `scripts/ui/journal.gd` | Dynamic List (Chronological entries) | `JournalEntryCard` | Inspect log entries & quests in chronological order, automatically mark entries read upon navigation. |
| **Battle Outcome (Level-Ups)**| `scripts/ui/battle_result.gd`| Dynamic List (Leveled unit rows) | `LevelUp` | Inspect level-up cards, select required perks; gates battle dismissal until all pending perks are chosen. |

### B. Excluded Lists (Non-Detailed Action / Routing Lists)

| Screen / Component | File | List Type | Exclusion Rationale |
|---|---|---|---|
| **Buildings** | `scripts/ui/buildings.gd` | `TableView` | Facility upgrade action list. Each row represents a building facility with an inline Upgrade action; no detailed card inspection needed. |
| **Trade** | `scripts/ui/trade.gd` | `TableView` | Trade route dispatch list. Rows display destinations and dispatch buttons; not a detailed entity list. |
| **Deploy Party** | `scripts/ui/deploy_party.gd` | `TableView` | Selection table to choose which encamped party to deploy into the field; single selection action. |
| **Parties** | `scripts/ui/parties.gd` | `TableView` | Overview table of parties routing directly to `PartyDetails` scene; not an individual card inspection. |
| **Assignment Dropdowns** | `assign_equipment.gd`, `blacksmith.gd`, `alchemy_workshop.gd`, `runic_workshop.gd`, `temple.gd` | `TableView` / `OptionButton` | Quick selectors and recipe pickers; direct inline actions. |

---

## 2. Test Coverage Matrix

Every integrated caller was verified for the 4 essential card navigation contract properties:
1. **Displayed-order snapshot:** Ordered ID list captured at open time.
2. **Wraparound cycling (< and >):** First card wraps backward to last, last card wraps forward to first.
3. **Close / Escape restoration:** Closing or pressing Escape restores the originating list selection and returns focus to the origin control.
4. **Stale-ID / removed item safety:** If an entity is removed or mutated out from under the card, the navigator closes safely without crashing or corrupting state.

| Caller | Displayed-Order Snapshot | Wraparound Cycling | Close / Escape Restoration | Stale-ID Safety | Test Suite File |
|---|:---:|:---:|:---:|:---:|---|
| **Roster** | Verified | Verified | Verified | Verified | `tests/unit/test_roster.gd` |
| **Add Member** | Verified | Verified | Verified | Verified | `tests/unit/test_add_member.gd` |
| **Party Details (Members)** | Verified | Verified | Verified | Verified | `tests/unit/test_party_details.gd` |
| **Recruitment** | Verified | Verified | Verified | Verified | `tests/unit/test_recruitment.gd` |
| **Shop (Trading Post)** | Verified | Verified | Verified | Verified | `tests/unit/test_trading_post.gd` |
| **LootTable (Stores)** | Verified | Verified | Verified | Verified | `tests/unit/test_loot_table.gd`, `tests/unit/test_stores.gd` |
| **Party Carried Loot** | Verified | Verified | Verified | Verified | `tests/unit/test_loot_table.gd`, `tests/unit/test_party_details.gd` |
| **Battle Result Loot** | Verified | Verified | Verified | Verified | `tests/unit/test_loot_table.gd`, `tests/unit/test_battle_result.gd` |
| **Journal** | Verified | Verified | Verified | Verified | `tests/unit/test_journal.gd` |
| **Battle Outcome Level-Ups**| Verified | Verified | Verified | Verified | `tests/unit/test_battle_result.gd` |
| **CardNavigator Component** | Verified | Verified | Verified | Verified | `tests/unit/test_card_navigator.gd` |

---

## 3. Automated Verification Results

All automated gates passed cleanly:

1. **GUT Test Suite (`make check`):**
   ```text
   Scripts: 88
   Tests: 2332
   Passing Tests: 2332
   Asserts: 10014
   Failures: 0
   Status: PASS (All tests passed)
   ```

2. **Godot Headless Editor Check (`godot --headless --path . --editor --quit`):**
   ```text
   Exit code: 0 (No syntax, resource, or autoload errors)
   ```

3. **Git Diff Check (`git diff --check`):**
   ```text
   Exit code: 0 (Clean formatting, no trailing whitespace or EOF issues)
   ```

4. **Screenshot Tour (`make screenshots`):**
   ```text
   Generated 26 of 26 screenshots in screenshots/ directory without warnings or errors.
   ```

---

## 4. Architectural Rules for Future Call Sites

- **CardNavigator is the single standard:** Any new player-facing screen or list presenting inspectable entity details MUST use `CardNavigator` and an appropriate card body control. Bespoke detail modals or overlays should not be created.
- **Ordered Snapshot Contract:** The navigator must always receive the list's exact displayed order at opening time, rather than querying mutable domain models directly during navigation.
- **Focus and Selection Restoration:** Originating lists must pass their activator control as the `return_target` in `open(ids, initial_id, return_target)` so keyboard and gamepad focus returns cleanly upon Close or Escape.
- **Domain State Separation:** `CardNavigator` owns only transient presentation state (indexes, indicators, modal dim backdrop). `GameSession` owns durable state, and scene controllers own transient selection.

---

## 5. Manual Acceptance Checklist

To perform manual acceptance via `make play`:

1. **Roster (`Units -> Roster`):**
   - Click a unit or select [View]. Confirm the `UnitDetailCard` opens centered with modal dimming.
   - Click `>` to cycle forward; verify wraparound from the 4th adventurer back to the 1st.
   - Click `<` to cycle backward; verify wraparound from the 1st adventurer to the 4th.
   - Press `Escape` or click `[x]`; verify the roster table is restored with the last-viewed unit selected.
2. **Add Member (`Units -> Parties -> Party Details -> Add Member`):**
   - Select an available candidate and click [View].
   - Cycle through unassigned adventurers, verify arrows and `N of M` indicator.
   - Close navigator, verify candidate selection is preserved in the table.
3. **Recruitment (`Units -> Recruitment`):**
   - Select a candidate and click [View] / double-click.
   - Verify candidate stats, cost, and class details.
   - Purchase candidate directly from card; verify gold deducts, candidate is recruited to roster, and view returns safely.
4. **Trading Post (`Encampment -> Trade -> Trading Post`):**
   - Open Shop weapon catalogue, click [View].
   - Cycle through weapons (`>` and `<`), verify prices and stats.
   - Purchase an affordable weapon; verify gold deducts and active card refreshes in-place.
5. **Stores (`Encampment -> Trade -> Stores`):**
   - Inspect banked items via [View].
   - Verify sell action works for gear and crystals, quantity dialog opens for stacks > 1.
6. **Journal (`Encampment -> Journal`):**
   - Switch between Quests and Log sections.
   - Click [View] on an entry; verify chronological browsing and automatic unread status resolution.
   - Close navigator via Escape; verify active section is preserved.
7. **Battle Outcome Level-Ups:**
   - Play a battle (e.g. Goblin Camp or Orc Outpost) where party members gain XP and level up.
   - In the victory summary, click [View] next to a leveled adventurer.
   - Cycle between leveled adventurers. Select required perks.
   - Confirm the final [OK] button on the outcome screen remains disabled until all pending perks are chosen.
