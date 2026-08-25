# Step 2: Journal Navigation and Views

**Milestone:** Encampment opens Journal; Log/Quests show durable records or a
placeholder and clear unread state only for viewed entries.

**Depends on:** Step 1 merged.

**Source contracts:** `docs/plans/2026-08-25-information-design.md`,
`scenes/ui/camp_nav.tscn`, `scripts/ui/camp_nav.gd`,
`scripts/autoload/game_manager.gd`, and existing UI scene/test pairs.

**Files:** create `scenes/ui/journal.tscn`, `scripts/ui/journal.gd`, and
`tests/unit/test_journal.gd`; modify `scenes/ui/camp_nav.tscn`,
`scripts/ui/camp_nav.gd`, `scripts/autoload/game_manager.gd`,
`tests/unit/test_camp_nav.gd`, and `translations/en.tres`.

1. Branch `feat/information-design-journal-ui`. Write failing camp-nav tests
   for Journal routing and its aggregate `!` badge. Run
   `-gselect=test_camp_nav.gd` red. Add `JOURNAL_SCENE`, `go_to_journal()`,
   button/badge, and refresh binding; keep GameManager routing-only. Re-run green.
2. Write failing scene tests: Quests shows an explicit accepted-quest empty
   state; Log is chronological; Log/Quests badges reflect their own unread
   items; View clears one Log item only. Run `-gselect=test_journal.gd` red.
3. Implement the Encampment-style Journal with left Quests/Log selector,
   GameSession read-only rendering, individual View acknowledgement/detail,
   and translations. Do not implement accepted-quest behavior or mutate Guild
   Hall offers. Run focused tests green and `git diff --check`.
4. Review, then request manual check: open Journal, inspect empty Quests, seed
   and view one Log record, and confirm only its badge clears. After signoff,
   commit, merge locally, delete branch, and hand off UI constraints.
