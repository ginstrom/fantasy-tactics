# Battle Loot Store — Plan Index

**Goal:** Bring `GameSession`'s loot pipeline in line with the confirmed
design: three loot stores — battle, party, encampment — all sharing the
exact same data shape, connected by exactly one shared function that merges
battle into party and party into encampment.

**Background:** two of the three stores already exist and already match:
`pending_gear`/`pending_mana_crystals`/`pending_reward` (the party store,
"everything a deployed party is carrying") and `banked_gear`/
`mana_crystals`/`gold` (the encampment store), joined by one existing merge
function, `GameSession.deposit_pending_reward()`. The battle store does not
exist as a real, separately-persisted structure today: loot rolls straight
into `pending_*` the moment it's earned, and the victory summary screen
shows a before/after *delta* computed in `battlefield.gd`'s
`_finish_victory()` rather than reading a real store. This plan adds the
missing third store and generalizes the merge into one shared function both
directions use.

## Design decisions

- New `GameSession` fields: `battle_gear: Dictionary`, `battle_mana_
  crystals: Dictionary`, `battle_reward: int` — the same shape `pending_*`
  and `banked_gear`/`mana_crystals`/`gold` already use. `reset()` clears
  all three, matching every other loot field.
- A new private helper, `GameSession._merge_counts(source: Dictionary, dest:
  Dictionary) -> void`, adds every count in `source` into `dest` in place.
  This is the one function both merges share:
  - `GameSession.merge_battle_loot_into_party()` (new) — battle -> party.
  - `GameSession.deposit_pending_reward()` (existing, refactored to call
    `_merge_counts()` instead of hand-rolling the same loop) — party ->
    encampment.
- Loot rolling moves from `pending_*` to `battle_*`:
  `_roll_and_queue_loot()` and the encounter gold bonus in
  `complete_current_encounter()` write to `battle_reward`/`battle_mana_
  crystals`/`battle_gear` instead.
- The battle store merges into the party store when the player leaves the
  victory summary screen for the World Map. `GameManager.go_to_world_map()`
  is the single call site for that transition — both the real "click OK on
  the summary" path (`battle_result.gd`) and `GameManager.complete_battle()`
  (the screenshot-tour shortcut that skips the summary screen entirely)
  route through it — so `merge_battle_loot_into_party()` is called there,
  not from `battle_result.gd` itself. This also means it's a safe no-op
  every other time `go_to_world_map()` fires (game menu, camp nav, Party
  Details' Back button) since the battle store is already empty by then.
- `battlefield.gd`'s `_finish_victory()` no longer computes a before/after
  delta to isolate "this battle's own loot" — it reads `GameSession.
  battle_reward`/`battle_mana_crystals`/`battle_gear` directly, since those
  fields now *are* this battle's own loot, untouched by anything else until
  the merge. `_dict_counts_delta()` is deleted as dead code.
- Net effect for players: none. The party's own store (and anything reading
  it live, e.g. Party Details' [Equip]) already could only be reached by
  going through the World Map, which was already the only way out of the
  victory summary screen — so the timing of when loot "becomes usable" does
  not change, only how the code models it internally.

## Steps

1. [Battle loot store](01-battle-loot-store.md) — the whole change, kept as
   one step. Its two tasks are additive-then-cutover: Task 1 only adds new,
   unused-so-far surface (safe to land alone); Task 2 is the one atomic
   behavior change (loot-rolling's target field) and cannot be split further
   without leaving `make check` red partway through, since every consumer
   (GameSession's own tests, GameManager, battlefield.gd, and their tests)
   depends on loot landing in the same place at the same time.

## Shared workflow

Per `AGENTS.md`:

1. `git checkout main && git pull`
2. `git checkout -b battle-loot-store`
3. Implement Task 1, then Task 2, with TDD (red/green) — see the step file.
4. Run `make check` after each task; both must be green before moving on.
5. Manual verification via `make play` (see the step file's checklist) once
   both tasks are done.
6. Commit each task separately.
7. `git checkout main && git merge battle-loot-store`, then delete the
   branch. Only push to `origin` or open a PR if the user asks.

## Full-suite regression check

After merging, run `make check` once more from `main`. Manually play one
full loop: deploy a party, clear the Goblin Camp, confirm the victory
summary still shows just that battle's own gold/loot, click OK, confirm
Party Details on the World Map now shows that same loot in its table, then
return to the Encampment and confirm it banked correctly into Stores.
