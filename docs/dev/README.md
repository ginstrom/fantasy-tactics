# Developer & Agent Docs

This folder is the entry point for anyone — human or agent — who needs to
**run**, **test**, or **modify** this codebase, as opposed to reading about
what the game is meant to become. Design intent and narrative live in
[`docs/plans/`](../plans/) and [`docs/vision.md`](../vision.md); this folder
is operational only.

## Start here

| Task | Read |
|---|---|
| Launch the game and drive it manually (play, jump to a scene, take screenshots) | [running-the-game.md](running-the-game.md) |
| Run the automated test suite, or write a new test | [testing.md](testing.md) |
| Get oriented in the codebase before making a change | [code-map.md](code-map.md) |

Each page uses the same structure: **Prerequisites**, then one **Steps /
Verification / Troubleshooting** block per task. If a step doesn't say how to
verify it worked, that's a bug in the doc — fix it rather than guessing.

## Repository-wide prerequisites

- **Godot 4.7.1** (stable), available on `PATH` as `godot`. Confirm with:
  ```
  godot --version
  ```
  Expected output starts with `4.7.1.stable`.
- All commands below are run from the repository root — the directory
  containing `project.godot`.
- Prefer the `make` targets in [`../../Makefile`](../../Makefile) over
  hand-rolled `godot` invocations; they encode the exact flags this project
  needs (headless mode for tests, off-screen positioning for screenshots).

## Terminology

These docs, and the codebase itself, use these terms consistently. Don't
substitute synonyms when writing new docs or tests here — an agent matching
strings against this page depends on it.

- **Encampment** — the player's home base screen (`scenes/ui/encampment.tscn`).
  Not "settlement" or "camp" in prose, though `STARTING_SETTLEMENT_ID` is the
  underlying location id.
- **World Map** — the screen where a deployed party travels between the
  Encampment and encounters (`scenes/world/world_map.tscn`).
- **Battlefield** — the tactical combat screen (`scenes/battle/battlefield.tscn`).
- **Party** — a group of adventurers tracked in `GameSession.parties`. The
  first-playable campaign supports exactly one.
- **Adventurer** — a unit in the player's roster (`GameSession.adventurers`),
  whether or not it's assigned to a party.
- **Expedition** — the *template* data for an encounter site (`GameSession.EXPEDITIONS`):
  fixed stats, reward, XP values. Never mutated at runtime.
- **Encounter** (or **encounter instance**) — a *spawned, live* copy of an
  expedition sitting on the World Map (`GameSession.active_encounters`), with
  its own id and position. Clearing one removes it permanently; a new
  instance (same or different expedition) may spawn later to refill the
  vacancy.
- **Reward** — gold queued in `GameSession.pending_reward` on victory, and
  only added to `GameSession.gold` once the party returns to the Encampment
  (`GameSession.deposit_pending_reward`).
- **GameManager** — the autoload owning navigation (scene changes) and
  thin validation wrappers. Never owns durable game state.
- **GameSession** — the autoload owning all durable session state and game
  rules (parties, roster, encounters, progression, gold). Never touches the
  scene tree.

See [code-map.md](code-map.md) for how these fit together in code.

## Further reading

- [`docs/plans/first-playable-campaign/game-design.md`](../plans/first-playable-campaign/game-design.md) — the design doc these systems implement.
- [`docs/plans/first-playable-campaign/game-loop-flow.md`](../plans/first-playable-campaign/game-loop-flow.md) — the minimal end-to-end loop the game must support.
- [`docs/plans/2026-08-06-campaign-progression-and-population/design.md`](../plans/2026-08-06-campaign-progression-and-population/design.md) — XP/leveling and vacancy-timed population rules.
- [`AGENTS.md`](../../AGENTS.md) (repo root) — branching and plan-writing workflow for this project.
