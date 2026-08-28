# Developer & Agent Docs

This folder is the entry point for anyone — human or agent — who needs to
**run**, **test**, or **modify** this codebase, as opposed to reading about
what the game is meant to become. Design intent and narrative live in
[`docs/plans/`](../plans/) and [`docs/designs/`](../designs/); this folder
is operational only.

This documentation is meant to be a roadmap to the code: the general layout and function of the code. It is meant to be a practical guide: where to go in order to maintain or modify the game. It is not meant to be a function-for-function recap of the codebase. Always aim to be **useful** to developers as your first priority.

## Start here

| Task | Read |
|---|---|
| Launch the game and drive it manually (play, jump to a scene, take screenshots) | [running-the-game.md](running-the-game.md) |
| Run the automated test suite, or write a new test | [testing.md](testing.md) |
| Get oriented in the codebase before making a change | [code-map.md](code-map.md) |
| Play N headless battles and log balance/outcome data | [running-the-game.md](running-the-game.md#run-the-headless-battle-simulator) |
| Run full headless campaigns for pacing/telemetry data | [running-the-game.md](running-the-game.md#run-full-headless-campaigns) |
| Run reproducible, deterministic battle policy scenarios | [running-the-game.md](running-the-game.md#run-reproducible-battle-scenarios) |

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
- **Expedition** — the *template* data for an encounter site (`GameSession.EXPEDITIONS`
  and `ContentCatalog` encounter definitions): fixed stats, position, and clear XP values.
- **Encounter** (or **encounter instance**) — a *spawned, live* copy of an
  expedition sitting on the World Map (`GameSession.active_encounters`), with
  its own id and position. Clearing one removes it permanently; a new
  instance (same or different expedition) may spawn later to refill the
  vacancy.
- **Campaign Objective** — an authored milestone node along the 12-stage campaign
  ladder (`GameSession.CAMPAIGN_OBJECTIVES`), unlocking the next objective and
  encounter upon victory until reaching the Final Boss.
- **Journal** — the durable chronological log and quest system (`GameSession.journal_entries`),
  divided into `log` and `quests` sections, browsed via `scenes/ui/journal.tscn`.
- **Reward** — gold, crystals, and gear queued in `GameSession._battle_context.reward` on
  victory, transferred to party carry (`GameSession.resolve_battle_victory`), and deposited into
  permanent storage upon returning to the Encampment (`GameSession.deposit_pending_reward`).
- **AudioManager** — the autoload owning sound effect playback, music crossfading,
  volume/mute preferences (`user://audio-settings.json`), and audio bus routing (`scripts/autoload/audio_manager.gd`).
- **GameConfig** — the read-only autoload that loads the shipped balance
  configuration once and provides typed fallback-safe lookups. Never owns
  gameplay state.
- **GameManager** — the autoload owning navigation (scene changes) and
  thin validation wrappers. Never owns durable game state.
- **GameSession** — the autoload owning all durable session state and game
  rules (parties, roster, encounters, progression, stores, item ownership,
  and workshop jobs) with domain services. Never touches the scene tree.

See [code-map.md](code-map.md) for how these fit together in code.

## Further reading

- [`docs/designs/`](../designs/) — design specifications implemented by these systems, including combat, monsters, classes, movement/AP, equipment, and UI layout.
- [`AGENTS.md`](../../AGENTS.md) (repo root) — branching and plan-writing workflow for this project.

Dated directories under `docs/plans/` (e.g. `docs/plans/2026-08-07-guild-hall-and-full-party-battles/`,
written per `AGENTS.md`'s "Writing implementation plans" section) are
per-feature implementation plans; in practice they get deleted once merged
to `main` rather than kept around, so don't expect a link to one of these to
stay valid — check git history if you need one. The documents in `docs/designs/`
are the durable reference for what's shipped and designed.
