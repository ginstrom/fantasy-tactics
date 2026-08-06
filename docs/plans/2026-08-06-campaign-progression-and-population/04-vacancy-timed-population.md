# Task 4: Vacancy-timed encounter and recruitment population

## Objective

Replace always-available catalogues with deterministic active-instance lists
that start small and refill only after their category's own vacancy timer.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/world/world_map.gd`
- Modify: `scripts/ui/recruitment.gd`
- Modify: `scripts/tools/screenshot_tour.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_recruitment.gd`
- Modify: `tests/unit/test_debug_scenarios.gd`
- Modify: `translations/en.tres`

## Steps

1. Write failing session tests for reset state: exactly one active Goblin Camp,
   exactly one active Warrior offer, zero vacancy clocks, and no unavailable
   static entries rendered as available.
2. Add failing tests for encounter vacancies: clearing an active site removes
   that instance, starts one 15-turn clock, does not refill at turns 1–14,
   refills at turn 15 only when fewer than two instances are active, and does
   not accrue or catch up extra spawns while the two-site cap is full.
3. Add equivalent recruitment tests: a successful purchase starts a 30-turn
   vacancy clock; refill occurs at turn 30 only under the four-offer cap;
   failed purchases do not start a clock. Test generated IDs never collide
   with roster or historical candidates.
4. Add world-map/recruitment screen tests showing only active instances and
   offers are interactive; a cleared instance remains non-enterable; and the
   UI refreshes after an End Turn or reopening the screen. Update debug and
   screenshot fixtures to select currently active IDs rather than constants.
5. Run tests red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session,test_world_map,test_recruitment,test_debug_scenarios -gexit
   ```

6. Implement `GameSession` template records separately from active encounter
   instances. Give each spawned instance a stable unique ID, a template ID,
   an unoccupied in-bounds map position, and copied reward/enemy data. A
   cleared instance is recorded historically and never reopens; a later spawn
   is a distinct instance. Seed Goblin Camp only. Seed only `warrior_002` as
   the initial offer. Use deterministic template/position selection so tests
   and screenshots stay repeatable.
7. Advance only the relevant vacancy timers inside successful
   `end_world_turn()`. If a category is at capacity, no new cooldown starts.
   A newly opened vacancy starts exactly when a site clears or a purchase
   succeeds. Keep active-battle End Turn blocking intact.
8. Change map and recruitment code to query active session records, never the
   static dictionaries. Preserve selection-before-activation, cleared-site
   rejection, World Map recovery, and the Information Panel behavior.
9. Rerun focused tests green, then commit:

   ```bash
   git add scripts/autoload/game_session.gd scripts/world/world_map.gd \
     scripts/ui/recruitment.gd scripts/tools/screenshot_tour.gd translations/en.tres \
     tests/unit/test_game_session.gd tests/unit/test_world_map.gd \
     tests/unit/test_recruitment.gd tests/unit/test_debug_scenarios.gd
   git commit -m "feat: populate encounters and recruits over time"
   ```

## Milestone

The campaign begins sparse, holds at most two active sites and four active
offers, and refills each cleared or hired slot predictably after its own wait.
