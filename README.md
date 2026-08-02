# Fantasy Tactics

Lean Godot 4 starter for a 2D turn-based tactics game — scene flow and folder conventions only, no gameplay systems yet.

## Requirements

- [Godot 4.7.1](https://godotengine.org/download) (stable)

## Getting started

1. Install Godot 4.7.1.
2. Open Godot → **Import** → select `project.godot` in this repo.
3. Press **Import & Edit** to open the project.

## Development commands

With Godot 4.7.1 available on your `PATH` as `godot`, use the included Makefile:

```bash
make help    # List available commands
make editor  # Open the project in Godot
make play    # Run the project
make test    # Run the GUT test suite headlessly
make check   # Run the current validation suite
```

## Folder map

```
fantasy-tactics/
├── project.godot       # Godot project settings
├── icon.svg            # Project icon
├── docs/plans/         # Design and implementation plans
├── scenes/             # Godot scenes (boot, UI, game)
├── scripts/            # GDScript (autoload, UI, game logic)
├── tests/              # GUT unit tests
├── addons/gut/         # GUT test framework
└── assets/             # Sprites, audio, fonts
    ├── sprites/
    ├── audio/
    └── fonts/
```

## Tests

Uses [GUT](https://github.com/bitwes/Gut) 9.7.1. Run it with:

```bash
make test
```

## License

MIT — see [LICENSE](LICENSE).
