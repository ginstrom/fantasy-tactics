# Stage 4 Play Session Template

Copy this file per session (e.g. `stage-4-session-S1.md`, kept outside Git —
see [running-the-game.md § Run a Stage 4 play session](running-the-game.md)).
It records one complete fresh manual campaign against the protocol in
[campaign-loop.md § Stage 4 evidence and presentation contract](../designs/campaign-loop.md#stage-4-evidence-and-presentation-contract).

Use anonymous session labels only. Never record a real name, account, or
other personal data.

## Session header

| Field | Value |
|---|---|
| Session label | e.g. `S1` |
| Build commit | `git rev-parse --short HEAD` |
| Date | |
| Player | "Project owner" or an anonymous label the user approved for this session |
| Dev tools used | Must be "None" for the session to count as a valid fresh-campaign record — see the protocol's "Dev tools permitted" row |

## Checkpoint log

One row per required checkpoint (New Game; each objective's entry and
resolution; recovery/upgrade; Withdraw or Battle Retreat, when it occurs;
defeat/wipe, when it occurs; save/load; victory; free play). Do not skip a
checkpoint that occurred, and do not fabricate one that did not.

| Checkpoint | World Map Turn | Objective id (if any) | Player's stated expectation *before* being told | Observed outcome | Screenshot/report path |
|---|---|---|---|---|---|
| | | | | | |

## Findings

One row per finding surfaced during the session. A finding is *repeated*
only when it occurs in two independent complete sessions, or deterministic
`make campaign-sim` evidence corroborates it — otherwise log it as a
single-session observation. A single severe accessibility or blocking
finding may be escalated immediately without waiting for a repeat.

| Field | Value |
|---|---|
| Session label / build commit | |
| Objective / checkpoint | Which checkpoint above this finding belongs to |
| Observed behavior | What the game actually did |
| Player interpretation | What the player believed was happening at the time |
| Expected contract | The design-doc rule or D9 acceptance observation this behavior should match |
| Severity | Blocking / Major / Minor / Cosmetic |
| Repeat count | 1 (this session only) or 2+ (independent sessions or sim-corroborated) |
| Supporting screenshot/report path | |
| Suspected owner | Pacing, comprehension/feedback, accessibility, presentation/audio, or rules (out of Stage 4 scope) |
| Decision | Fix now / defer to Stage 5 / not a finding (expected behavior) |
| Recheck result | Filled in after a fix, in a later session |
| Stage 5 deferral rationale | Required only when Decision is "defer to Stage 5" |
