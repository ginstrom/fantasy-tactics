# Step 1: Durable Journal Domain and Snapshot Contract

**Milestone:** `GameSession` appends important events, reports unread state,
acknowledges one record, and snapshots the result.

**Source contracts:** `docs/plans/2026-08-25-information-design.md`,
`docs/dev/code-map.md`, `scripts/autoload/game_session.gd`,
`scripts/save/campaign_snapshot.gd`, `tests/unit/test_game_session.gd`, and
`tests/unit/test_campaign_snapshot.gd`.

**Files:** modify `scripts/autoload/game_session.gd`,
`scripts/save/campaign_snapshot.gd`, `tests/unit/test_game_session.gd`, and
`tests/unit/test_campaign_snapshot.gd`.

1. Branch `feat/information-design-journal-domain`. Add a failing GUT test for
   `append_journal_entry(kind, title_key, detail, section)` returning a stable
   id and preserving deterministic chronological order. Run
   `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit`;
   confirm it fails because the API is missing.
2. Add the smallest GameSession schema: id, sequence, section (`log`/`quests`),
   kind, title key/detail, and `read`; reset it in `reset()` and expose query
   methods only. Re-run the test green.
3. Add failing tests for aggregate Log/Quests/Journal unread flags and
   idempotent `mark_journal_entry_read(id)` affecting only its entry. Run the
   focused file red; implement only the query/acknowledgement API; re-run green.
4. Add failing snapshot round-trip and malformed-record atomic-rejection tests.
   Run `-gselect=test_campaign_snapshot.gd` red. Add snapshot export,
   backward-compatible normalization, and strict validation; rerun both files
   green and `git diff --check`.
5. Request read-only review. After user signs off on test output, commit only
   these files, merge locally, delete branch, and hand off schema/migration facts.
