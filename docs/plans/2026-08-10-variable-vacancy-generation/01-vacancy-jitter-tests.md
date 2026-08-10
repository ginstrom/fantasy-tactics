# Step 1: Specify Variable Vacancy Delays with Failing Tests

## Milestone

`GameSession` has failing, deterministic tests that define an independently
resolved inclusive jitter range for encounter and recruitment vacancies.

## Setup

From the repository root, preserve unrelated work and create the feature
branch if it does not already exist:

```bash
git checkout main && git pull
git checkout -b feature/variable-vacancy-generation
```

For this prepared plan branch, continue on `plan/variable-vacancy-generation`
instead; do not create a worktree. Read `docs/dev/testing.md` before editing.

## Files

- Modify: `tests/unit/test_game_session.gd`
- Read: `scripts/autoload/game_session.gd`
- Read: `config/game_config.json`

## Red: Write the Tests

Add a test helper that replaces a planned `session.vacancy_delay_roll` callable
and records the inclusive bounds it receives. Add focused tests near the
existing population tests:

```gdscript
func test_encounter_vacancy_rolls_the_inclusive_base_plus_or_minus_jitter_once() -> void:
    var session: Node = GameSessionScript.new()
    autofree(session)
    var calls := 0
    session.vacancy_delay_roll = func(minimum: int, maximum: int) -> int:
        calls += 1
        assert_eq(minimum, 10)
        assert_eq(maximum, 20)
        return minimum

    session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
    session.complete_current_encounter()

    assert_eq(calls, 1)
    assert_eq(session.encounter_vacancies[0].turns_remaining, 10)
```

Add the matching recruitment test with bounds `25` and `35`, returning the
maximum. Add a base-result test returning 15/30 and update the old
"exactly turn fifteen/thirty" tests to force the base result before advancing
their existing loop. This preserves their purpose: validating tick, refill,
cap, and no-catch-up behavior rather than random-number distribution.

Add a one-roll-only test that advances several World Map turns after vacancy
creation and confirms the callable count remains one. Add `after_each` cleanup
that restores the production callable through the planned
`reset_injectable_rolls()` extension, mirroring existing random seams.

## Verify Red

Run:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=vacancy -gexit
```

Expected: the new tests fail because `vacancy_delay_roll` and/or the jittered
delay behavior does not yet exist. Existing fixed-delay tests may fail once
rewritten; do not change implementation in this step.

## Green Boundary

Do not add production code here. The tests must not use real randomness,
sleeping, or broad statistical assertions. They should inspect the stored
resolved delay and use forced returns at the lower, base, and upper values.

## Commit

After Step 2 turns the suite green, include these tests in its focused commit;
do not commit a knowingly failing test-only revision unless an explicit review
checkpoint requires it.

## Completion Check

The test file states the complete timing contract: encounter 10–20,
recruitment 25–35, one roll per vacancy, and unchanged ticking/cap semantics.

## User Signoff and Merge

This step is not independently mergeable. Complete all steps, obtain user
manual-verification signoff in Step 4, then merge locally only with:

```bash
git checkout main && git merge feature/variable-vacancy-generation
git branch -d feature/variable-vacancy-generation
```

Do not push or open a PR unless asked.
