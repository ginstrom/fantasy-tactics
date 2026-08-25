# Step 4 — Journal and battle outcome level-up cards

**Milestone:** Journal entries and the Battle Outcome level-up list use
wrapping cards while unread/read and required-perk contracts remain intact.

**Depends on:** Step 3 merged.

**Branch:** `feat/card-navigator-journal-levelups` from updated `main`.

**Files:**

- Create: `scenes/ui/journal_entry_card.tscn`, `scripts/ui/journal_entry_card.gd`
- Modify: `scenes/ui/journal.tscn`, `scripts/ui/journal.gd`
- Modify: `scenes/ui/level_up.tscn`, `scripts/ui/level_up.gd`
- Modify: `scenes/ui/battle_result.tscn`, `scripts/ui/battle_result.gd`
- Modify: `tests/unit/test_journal.gd`, `tests/unit/test_level_up.gd`,
  `tests/unit/test_battle_result.gd`, `tests/unit/test_battlefield.gd`
- Modify: `translations/en.tres`

## Red/green tasks

1. Add Journal tests for per-section chronological snapshots, wrapped
   navigation, Close/Escape return to the same active section and last
   entry, and the current acknowledgement behavior. Ensure an entry deleted
   or unavailable during viewing safely closes.
2. Add Battle Outcome tests with two leveled units: View opens the chosen
   first card; arrows wrap through `leveled_up_ids` order; resolving a perk
   refreshes that card; Close/Escape returns to outcome; and the outcome
   cannot finish while either required perk remains pending.
3. Run the focused files and confirm failures before migration.
4. Replace Journal's bespoke `DetailPanel` with `JournalEntryCard` hosted by
   `CardNavigator`. Mark the opened entry read through the existing
   `GameSession` API; retain section-specific ordering.
5. Make `LevelUp` a card body (not a second full-screen overlay) when hosted
   by Battle Outcome. Retain its `resolved` signal and existing perk-choice
   guard. The navigator Close path must never call `resolved` or erase a
   pending choice; Battle Outcome's final OK remains disabled/guarded until
   all `leveled_up_ids` are resolved.
6. Run focused green tests, then `make check`, editor validation, and diff
   check.

## Manual check and handoff

In `make play`, open Journal Log and Quests independently, wrap entries, and
return with Close/Escape. Win or use a deterministic debug scenario that
levels two party members; open either result entry, wrap, make one required
choice, close, reopen, make the other, and only then dismiss the outcome.
Reviewer checks no event is lost, no perk is skipped, and battle input stays
locked behind the outcome. After signoff, commit/merge locally and record
the precise test counts for the exit gate.
