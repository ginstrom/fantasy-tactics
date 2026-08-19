# Step 3: Restored and Tested Audio Bus Contract

**Branch:** `fix/audio-bus-contract`  
**Depends on:** Step 2 merged  
**Milestone:** Godot loads the tracked Master/Music/SFX layout, and tests fail if its project configuration or routing is removed.

## Setup

Read `docs/dev/README.md` and `docs/dev/testing.md`, then confirm Step 2 is merged before creating the regular branch:

```bash
git status --short --branch
git checkout main && git pull
git checkout -b fix/audio-bus-contract
make check
```

Preserve unrelated generated `.uid` files; the existing `project.godot` audio-layout deletion is this step's target, so inspect it before changing it.

## Files

- Modify: `project.godot`
- Modify: `default_bus_layout.tres` only if routing validation exposes a defect
- Modify: `scripts/autoload/audio_manager.gd`
- Modify: `tests/unit/test_audio_manager.gd`
- Create: `tests/unit/test_project_audio_contract.gd`
- Modify: `docs/dev/running-the-game.md`

## TDD tasks

### Task 1: Restore and structurally test the project-owned layout

1. Add `test_project_audio_contract.gd` that reads `project.godot`, asserts its `[audio]` section names `res://default_bus_layout.tres`, loads that resource, and asserts Music/SFX exist and each sends to Master.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_project_audio_contract.gd -gexit
   ```

   Expected: failure in the current checkout because the `[audio]` section is missing.
3. Restore the exact layout reference in `project.godot`. Do not replace the tracked layout unless the routing assertion identifies a real defect.
4. Re-run the focused test. Expected: pass.

### Task 2: Expose missing required buses instead of silently no-oping

1. Add an AudioManager test for a validation helper that reports each required `BUS_NAMES` entry missing from `AudioServer`.
2. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_audio_manager.gd -gexit`.

   Expected: failure because volume/mute helpers silently return for absent buses.
3. Add startup validation called by `_ready()` that emits one actionable error per missing required bus. Do not dynamically create buses: the project resource must remain the source of truth. Preserve failure-soft behavior for missing audio clips.
4. Re-run focused tests. Expected: pass with restored layout and no missing-bus diagnostics.

### Task 3: Prove independent controls and document recovery

1. Extend audio tests to assert valid Music/SFX indices before setting volume/mute and to prove muting Music leaves SFX unmuted, and vice versa.
2. Run the focused audio tests. Expected: pass.
3. Add troubleshooting guidance in `docs/dev/running-the-game.md`: if Music/SFX controls do nothing, verify the project bus-layout setting and run the audio-contract test.

### Task 4: Verify, sign off, commit, merge

1. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_project_audio_contract.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_audio_manager.gd -gexit
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

2. Manual `make play` check: verify Music, SFX, and Master controls independently; then play a muted battle and confirm floating text/combat logs carry all tactical information.
3. Stage only this step's files; check staged diff; commit:

   ```bash
   git add project.godot default_bus_layout.tres scripts/autoload/audio_manager.gd tests/unit/test_audio_manager.gd tests/unit/test_project_audio_contract.gd docs/dev/running-the-game.md
   git diff --cached --check
   git commit -m "fix(audio): restore required music and sfx bus layout"
   ```

4. After user sign-off, merge locally and delete only this branch:

   ```bash
   git checkout main
   git merge fix/audio-bus-contract
   git branch -d fix/audio-bus-contract
   ```
