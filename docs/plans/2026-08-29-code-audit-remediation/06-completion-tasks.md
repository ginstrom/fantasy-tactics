To mark Step 6 complete, finish these items in order:

1. Add two Battlefield-level playback regressions in `tests/unit/test_battlefield.gd` using the deterministic ranged-enemy fixture:

   - Surviving opportunity reaction: assert rendered frames progress `move → reaction`, and the reaction frame shows the enemy at its projected destination with reduced health.
   - Lethal opportunity reaction: assert rendered frames progress `move → reaction`, with the enemy visible on the move frame and absent only on the reaction frame.

   Drive the playback one controlled beat at a time—rather than polling until completion—using `enemy_turn_beat_seconds` and awaited frames/timers. Assert rendering-facing sprites or frame-render output at each beat.

2. Re-run the updated focused scene tests and both battle test files:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=<reaction_playback_test> -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   ```

3. Run the final repository gates against the current dirty branch:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

4. Request another independent read-only review. It must confirm:
   - no playback renderer path reads live `units`, visibility, or stale-marker state;
   - `run_enemy_turn() -> Array` remains synchronous and frame indexes match returned steps;
   - both move/reaction cases pass at controller and Battlefield layers.

5. Do the manual check with `make play`:
   - load the recorded battle scenario;
   - observe a normal enemy movement/attack sequence;
   - observe a reaction sequence if reachable;
   - confirm no unit teleports, loses health early, or disappears before its displayed beat.

6. After your explicit signoff only:
   - stage the four Step 6 files;
   - commit with `fix(battle): render enemy turns from per-step state`;
   - merge `fix/enemy-playback-state` locally into `main`;
   - delete the branch and record the verification/manual-review handoff.

The branch currently has uncommitted changes in the two battle scripts and two battle test files. The controller-level reaction coverage is now present; the remaining substantive gap is the pair of scene-level reaction-playback tests.