# Step 1 - Developer documentation audit

## Milestone

`docs/dev/` reliably tells a contributor how to run, test, and navigate the
current project.

## Setup

1. Start from updated `main` on `docs/refresh-dev-and-game-design`.
2. Read `docs/dev/README.md`, `running-the-game.md`, `testing.md`, and
   `code-map.md`.
3. Cross-check each changed claim against `Makefile`, `project.godot`,
   `scripts/autoload/`, `scripts/tools/`, and relevant tests.

## Red/green documentation workflow

1. Record each stale claim and its current source-of-truth location.
2. Update only the affected guide sections: current autoload ownership,
   available workshop/UI domains, debug scenarios, deterministic scenario
   runner, and verification commands.
3. Re-read every command and path from the edited pages; run the referenced
   headless validation command to prove it remains usable.

## Verification

```bash
godot --headless --path . --editor --quit
make check
git diff --check
```

## Manual verification

Run `make play`, open the F9 debug menu, and confirm the documented scenario
names still match the overlay.

## Commit and merge

After the user confirms the manual check, commit the documentation changes,
merge the branch locally to `main`, delete the branch, and do not push.
