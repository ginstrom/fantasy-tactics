# Step 2: Implement Variable Vacancy Delays

## Milestone

Encounter and recruitment vacancies resolve one bounded, testable delay at
creation while the current weighted encounter-template and position generation
remain unchanged.

## Setup

On `feature/variable-vacancy-generation` (or the prepared plan branch), first
run the failing Step 1 tests. Read `docs/dev/code-map.md` and the population
methods in `scripts/autoload/game_session.gd`.

## Files

- Modify: `config/game_config.json`
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Green Implementation

Add `encounter_vacancy_jitter_turns: 5` and
`recruitment_vacancy_jitter_turns: 5` to the population config. Add and load
matching `GameSession` values beside the bases.

Add `vacancy_delay_roll`, defaulting to inclusive `randi_range(minimum,
maximum)`, and restore it from `reset_injectable_rolls()`. Add a shared
`_resolve_vacancy_delay(base_turns, jitter_turns)` helper that clamps the
minimum to one and calls the seam with inclusive `base-jitter` and
`base+jitter` bounds. Use it only in `_start_encounter_vacancy()` and
`_start_recruitment_vacancy()`.

Do not alter `_advance_*_vacancies()`, `_choose_encounter_template()`,
`_choose_encounter_position()`, or instance-id generation. Correct their
nearby stale comments where they say reset starts with one active encounter.

## Verification

Run focused vacancy tests, focused refill tests, `make check`,
`godot --headless --path . --editor --quit`, and `git diff --check`.
Expected: every command exits zero and the suite reports `All tests passed`.

## Commit

Stage `config/game_config.json`, `scripts/autoload/game_session.gd`, and
`tests/unit/test_game_session.gd`; commit as `feat: jitter population vacancy
delays`.

## Completion Check

Forced lower/base/upper results are stored once per vacancy; existing cap,
no-catch-up, weighted-template, and distinct-position tests remain green.

## User Signoff and Merge

Do not merge yet. Complete Step 4 manual verification, obtain user signoff,
then merge locally and delete the branch. Do not push.
