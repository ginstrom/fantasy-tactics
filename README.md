# Fantasy Tactics

Lean Godot 4 starter for a 2D turn-based tactics game with a first playable
settlement-to-goblin-camp campaign loop.

## Requirements

- [Godot 4.7.1](https://godotengine.org/download) (stable)

## Getting started

1. Install Godot 4.7.1.
2. Open Godot → **Import** → select `project.godot` in this repo.
3. Press **Import & Edit** to open the project.

## Development commands

With Godot 4.7.1 available on your `PATH` as `godot`, use the included Makefile:

```bash
make help         # List available commands
make editor       # Open the project in Godot
make play         # Run the project
make test         # Run the GUT test suite headlessly
make check        # Run the current validation suite
make screenshots  # Capture a screenshot of every scene/state into ./screenshots
```

`make play` runs a debug build. Press `F9` from a campaign screen to open the
development-only scenario menu, which can jump to New Campaign, Encampment,
Party Manager, Party Ready to Depart, Party on World Map, Goblin Camp Battle,
or Orc Outpost Battle. The menu is not created in non-debug exports.

## Screenshots

`make screenshots` drives the game through every known scene and notable UI
state, saving a numbered PNG per state to `./screenshots`. It's a real render
(not headless), so it needs an available display; the window is positioned
off-screen so it doesn't interrupt you. The tour covers expedition and reward
states too: the World Map with both expedition labels and the gold panel, the
World Map right after a Goblin Camp victory but before the reward is
deposited, and the Encampment after the reward is deposited.

The tour is a plain list of steps in
`scripts/tools/screenshot_tour.gd` — as new scenes or UI states are added to
the game, add a step for them there. Each step is just a name and a
`Callable` that leaves the game showing whatever should be captured.

## Folder map

```
fantasy-tactics/
├── project.godot       # Godot project settings
├── icon.svg            # Project icon
├── docs/plans/         # Design and implementation plans
├── scenes/             # Godot scenes (boot, UI, world, local, battle)
├── scripts/            # GDScript (autoload, UI, world, local, battle logic)
├── tests/              # GUT unit tests
├── addons/gut/         # GUT test framework
├── translations/       # Translation resources (one per locale)
└── assets/             # Sprites, audio, fonts
    ├── sprites/
    ├── audio/
    └── fonts/
```

## Localization

Player-facing scenes and scripts never contain literal copy — they reference
stable translation keys (e.g. `menu.new_game`, `battle.end_turn`) that are
resolved through Godot's `tr()`/translation system at runtime.

To add a new key:

1. Add the key and its English copy to `translations/en.tres`, in the
   `messages` dictionary (`"my.new_key": "My new copy"`).
2. Reference the key wherever it's shown to the player:
   - In a `.tscn` file, set the Label/Button's `text` property to the key
     itself — Godot auto-translates Control text at render time.
   - In a script, call `tr("my.new_key")` and assign the result.
3. Run `make check` to confirm the key resolves (see
   `tests/unit/test_localization.gd` for the pattern).

To add a new locale, create `translations/<locale>.tres` with the same
`messages` keys translated, then register it in `GameManager`
(`scripts/autoload/game_manager.gd`) alongside `EN_TRANSLATION` via
`TranslationServer.add_translation(...)`. Only add a locale once its
reviewed translations are available — don't add empty or machine-translated
placeholder content.

## Tests

Uses [GUT](https://github.com/bitwes/Gut) 9.7.1. Run it with:

```bash
make test
```

## License

MIT — see [LICENSE](LICENSE).
