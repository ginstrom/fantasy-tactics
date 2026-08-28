# Step 05 — Enemy playback design decision

**Objective:** Select a minimal, testable way to render each enemy-turn beat
from that beat's state rather than the final synchronous simulation state.

**Dependency:** Step 04 merged. **Branch:** `design/enemy-playback-state`.

## Investigation and decision record

Do not alter gameplay rules in this step. Read `BattleController.run_enemy_turn()`,
the `Battlefield._play_enemy_turn()` loop, existing `Unit` duplication/state
construction seams, and battle tests. Produce `docs/designs/enemy-playback-state.md`
with one of these measured options:

1. **Recorded visual timeline (recommended if affordable):** record immutable
   per-step unit positions/alive/HP/facing states alongside existing result
   dictionaries; playback draws the recorded state. This preserves synchronous
   rules resolution.
2. **Incremental simulation:** turn `run_enemy_turn()` into a sequence whose
   rules execute one beat at a time. Choose only if it retains determinism,
   cancellation, and all current callers without a second rules path.
3. **Do nothing:** allowed only if a representative recorded/reproduced run
   disproves the audit's final-state redraw claim.

Capture a deterministic reproduction: an early enemy movement followed by a
later death or later destination. Record screenshots/video frames or test
state logs proving the incorrect early draw. Include memory/complexity impact,
callers affected, test seam, and a rejection rationale for the alternatives.

Run `make check`, editor parse, and `git diff --check`; request an independent
read-only review of the decision record. Present the chosen option and evidence
to the user. Only after explicit approval commit the design record locally as
`docs(battle): choose enemy playback state model`, merge/delete the branch,
and proceed to Step 06. A rejected option returns to this step.
