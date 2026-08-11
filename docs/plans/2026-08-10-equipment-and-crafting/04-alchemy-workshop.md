# Step 4 — Alchemy Workshop

## Milestone

The Alchemy Workshop crafts Healing Potions into Encampment Stores after seven
World Map Turns. Adventurers carry up to ten items, can transfer a carried
item in battle for 2 AP, and consume a held healing potion with a separate
2-AP action.

## Contract

- Build Level 1 for 50 gold; upgrade to Level 2 for 50 gold.
- Exactly one workshop job may run at a time. Completion after seven World
  Map Turns is snapshot-safe and puts the result in Stores.
- Level 1 crafts a 1-6 HP Healing Potion for 10 gold and one mana crystal.
- Level 2 additionally crafts a 2-8 HP Greater Healing Potion for 20 gold
  and one tier-2-or-higher mana crystal.
- Each adventurer carries at most ten individual items, including weapon,
  armor, and potions. Stores are virtual loot storage, not battle inventory.
- A living active player unit transfers an item it carries to a living ally
  with capacity for 2 AP. The action is atomic on failure.
- A living active player unit uses a held potion on itself for 2 AP. Healing
  is capped at maximum health; successful use consumes exactly one potion;
  failed/full-health attempts consume neither AP nor an item; potions cannot
  revive.
- Level 3, tonics, permanent alchemical enhancements, and timed effects are
  deferred until their own approved design.

## Red/green delivery

Branch as `feat/alchemy-workshop`. Add failing tests first for workshop
cost/material/job gates, job persistence/completion, per-adventurer item
capacity and snapshot persistence, transfer validation, and potion action
atomicity/healing bounds. Implement durable inventory and workshop APIs in
`GameSession`, then battle legality in `BattleController`, then the workshop
and inventory UI. Run focused GUT tests after each red/green cycle, then
`make check`, `godot --headless --path . --editor --quit`, mixed combat
simulations, and `git diff --check`. Use `make play` to craft each potion,
equip it before deployment, transfer one item, and use each potion. After
user signoff, commit, merge locally, delete the branch, and do not push.
