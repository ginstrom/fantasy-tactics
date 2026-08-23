# Step 1 — Stage 4 Evidence and Presentation Contract

**Branch:** `docs/stage-4-evidence-contract`

**Depends on:** clean `main` with the Stage 3 exit gate merged

**Milestone:** A user-approved, privacy-preserving protocol defines what is measured, how a repeated finding is decided, and what “readable 3/4 presentation and purposeful audio” means before any tuning begins.

## Files

- Modify: `docs/designs/campaign-loop.md`
- Modify: `docs/dev/running-the-game.md`
- Create: `docs/dev/stage-4-play-session-template.md`
- Modify: `docs/designs/combat-system.md` only if the approved feedback vocabulary clarifies an existing combat result; do not alter a rule here.
- Modify: `docs/designs/world-map-and-encounters.md` only if the approved arrival/Withdraw wording needs an observable UI label; do not alter a rule here.

## Red/green tasks

1. Add a Stage 4 decision table to `campaign-loop.md`. It must declare: the minimum complete fresh campaigns (three or more), who may play, which assistive settings/dev tools are permitted, required checkpoints (New Game, each objective, recovery/upgrade, Withdraw or Battle Retreat when it occurs, defeat/wipe when it occurs, save/load, victory, free play), and the exact durable facts captured at each checkpoint. Use anonymous session labels only; no personal data.
2. Define the finding record in `stage-4-play-session-template.md`: session label/build commit, objective/checkpoint, observed behavior, player interpretation, expected contract, severity, repeat count, supporting screenshot/report path, suspected owner, decision, recheck result, and Stage 5 deferral rationale. State that a finding is *repeated* only when it occurs in two independent complete sessions or deterministic evidence corroborates it; a single severe accessibility/blocking finding can be escalated immediately.
3. Add one protocol row that pins the fixed automated comparison evidence: `make campaign-sim`, the named seeds `4, 9, 10, 12, 14`, the Stage 3 5/5 requirement, and the report fields that must be preserved. State that a sweep is exploratory and cannot replace the named proof.
4. Resolve D9 in the canonical campaign design as an approval table, not a generic art wish list. The table must say what a first-time player must be able to identify at normal play scale: party/enemy and their facing, hovered/selected/active unit, range/target/mode, hit/miss/critical/heal/retreat result, wound tier, current objective/threat/next unlock, and music/SFX state. For each, name the expected World Map/Battlefield/Encampment surface and an acceptance observation. Include settings requirements for mute/volume and a non-audio/non-colour-only cue where a result is gameplay-critical.
5. Add the permanent “run a Stage 4 session” and “review a local campaign report” instructions to `running-the-game.md`. They must use `make play`, `make campaign-sim`, the template, and local evidence paths; they must not prescribe committing saves/reports/screenshots.
6. Run documentation checks:

   ```bash
   git diff --check
   rg -n "Stage 4|Representative|repeated|non-audio|non-colour" docs/designs/campaign-loop.md docs/dev/running-the-game.md docs/dev/stage-4-play-session-template.md
   ```

   Expected: no whitespace errors; all protocol, decision, and accessibility anchors are present.
7. Stop for user approval of the protocol and D9 table. Do not collect a baseline or write gameplay/presentation code until the user explicitly accepts the measurements and standard.

## Manual check

Read the template while launching a fresh `make play` session. Confirm every required checkpoint can be recorded without a developer needing to interpret hidden state, and that the D9 table describes observable player comprehension rather than asset counts.

## Commit and local merge

After user approval, stage only the listed design/dev files; commit `docs(campaign): define Stage 4 evidence standard`, merge locally to `main`, and delete `docs/stage-4-evidence-contract`. Do not push or open a PR.
