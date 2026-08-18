# Equipment Handbook

## Purpose and status

This is the long-term contract for normal equipment, permanent improvements, magical gear, runes, crafting, and tactical consumables. It extends the current Trade, Stores, and unit-inventory loop. **Shipped** is live behaviour; **Next slice** is approved delivery; later sections are design intent only.

## Equipment layers

An owned item has one immutable base definition plus permanent modifier categories. Different categories stack; a stronger tier in the same category replaces the earlier tier.

```text
Iron Longsword
  base item: longsword_iron
  blacksmith treatment: Sharpened (+1 raw damage)
  alchemical enhancement: Advanced Accuracy (+20 Accuracy; replaces Basic +10)
  rune: Thorn Rune (may Paralyze a melee attacker)
```

| Layer | Purpose | Rule |
|---|---|---|
| Base item | Shape, normal damage/protection, slot, permissions | Exactly one. |
| Blacksmith treatment | Physical improvement | One tier; higher replaces lower. |
| Alchemical enhancement | Permanent magical statistic modifier | One tier per family; Advanced replaces Basic. |
| Rune | Socketed passive/triggered effect | One socket initially; stacks with treatment/enhancement. |
| Consumable | One-use tactical item | Not equipment; consumed on use. |

Normal gear is a base item only. Improved gear adds a treatment. Magical gear adds an enhancement and/or rune; it is not a disconnected duplicate catalogue.

## Normal equipment — Shipped baseline

| Weapon | Iron damage | Steel damage |
|---|---:|---:|
| Dagger | 1–4 | 2–5 |
| Shortsword | 1–6 | 2–7 |
| Longsword | 1–8 | 2–9 |
| Two-handed sword | 1–10 | 2–11 |

| Armor | Guard Bonus | Damage Resistance |
|---|---:|---:|
| Leather | +10 | 10% |
| Chainmail | +15 | 20% |
| Splint armor | +15 | 25% |
| Platemail | +15 | 30% |
| Full plate | +15 | 35% |

Armor Guard adds directly as a percentage to unit Base Guard (e.g., base Guard 30 + armor Guard 15 = 45% hit subtraction, capped at 95% total Guard). (Note: Future armor bulk will apply movement, AP, and dodge penalties, but is deferred for initial implementation).

Class equipment permissions are future class data. The current Warrior-compatible catalogue remains valid unchanged.

## Item instances & Representation

All items share the exact same representation; base weapons simply have their improvement slots empty and can stack in Stores/Shops. In Shops and inventories, items stack like-with-like:

```text
Item                         Type     Qty   Sale Price
Iron Longsword               Weapon   3     10
Sharpened Iron Longsword     Weapon   1     20
```

An item instance has one slot per enhancement family (one smithing treatment, one alchemical enchantment family, and socketed runes):

```yaml
id: "gear_00042"
base_item_id: "longsword_iron"
type: "weapon"
material: "iron"
enhancements:
  smithing: "sharpened"
  enchantment: "accuracy_1"
  runes: ["thorn"]
```

`GameSession` owns catalogues, instances, banked normal-item stacks, unit-held item ids, recipes, and materials. The active weapon/armor pointer becomes an owned item id. Craft, equip, upgrade, rune replacement, sale, and snapshot import preserve ownership exactly once. Invalid inputs, missing requirements, duplicate ids, incompatible slots, or unavailable sockets leave all state unchanged.

When an adventurer dies, battle aftermath validates ownership before mutation
and atomically transfers that adventurer's equipped, carried, and unique
modified items to the party loot pool. Those items return to the Encampment
bank after a successful retreat. A dead adventurer may not retain item
ownership in the save or aftermath input. The campaign-level death, retreat,
and wipe contract is defined in the
[Borderlands Campaign Loop](campaign-loop.md#defeat-death-and-retreat).

## Generic Action Points & Item Action Costs

The [Movement and Action Points](movement-and-action-points.md) guide owns the
AP foundation. In-combat item interactions consume AP from the fixed 6-AP Round budget:
* **Consume Potion:** 2 AP
* **Use Tactical Item:** 2 AP
* **Transfer Item to Adjacent Unit:** 2 AP

## Crafting buildings

Recipes are data: stable id, building requirement, inputs, and result. Exact gold/crystal values are balance data chosen from simulations, never UI literals.

| Building | First capability | Inputs | Result |
|---|---|---|---|
| Blacksmith | Craft normal Iron/Steel gear; Sharpened | gold, base gear | normal item or `smithing: sharpened` instance |
| Alchemy Workshop | Potions; Basic Accuracy | gold, mana crystals | consumable or `enchantment: accuracy_basic` instance |
| Runic Workshop | Socket found Thorn Rune | instance, rune, mana crystals | instance with `runes: [thorn]` |

Sharpened adds +1 raw weapon damage after the weapon roll and before Might/Resistance. Basic Accuracy adds +10 Accuracy permanently; Advanced Accuracy replaces it rather than stacking. Compatible Accuracy and Guard enhancements may coexist in separate enchantment family slots. The first recipes use existing gold, gear, and mana crystals; do not invent generic reagents until a recipe needs a distinct decision.

## Potions — Alchemy Workshop slice

Potions are stackable Store items assigned to a unit before battle. Consuming a potion during combat costs 2 AP.

| Potion | First effect | Constraint |
|---|---|---|
| Healing Potion | Restore a tuned health amount | Cannot revive a defeated unit. |
| Accuracy Tonic | Temporary Accuracy increase | Explicit duration and refresh rule. |
| Guard Tonic | Temporary Guard increase | Explicit duration and cap interaction. |

Potions use the generic timed-effect system, not bespoke `Unit` flags or free UI buttons.

## Runes — Runic Workshop slice

An item begins with a fixed number of rune sockets (initially 1 socket). When socketing a new rune over an existing one, **the displaced rune is returned to the Stores**. (A future scrapping mechanic will allow breaking down items for base materials).

The first reference rune is **Thorn Rune** for armor: when a wearer is hit by a melee attack, it has a stated chance to apply Paralyze to the attacker. It requires common trigger timing, attack tags, chance resolution, duration, immunity, stacking/refresh rules, UI feedback, and AI treatment. A special-case paralyze callback is out of scope. The initial weapon rune is **Blood Rune** which on hit inflicts 1-3 bleeding damage for the next 3 rounds.

## Delivery and verification

1. **Shipped:** generic AP replaces movement-plus-one-attack with 6 AP, 1-AP movement, and 3-AP attacks.
2. Item instances: retain normal-item compatibility and snapshots; add category replacement.
3. Blacksmith: normal recipes and Sharpened +1 damage.
4. Alchemy Workshop: three potions, Basic Accuracy, and timed effects.
5. Runic Workshop: one socket and Thorn Rune after event/status support.

Each slice begins red with tests for atomic resource consumption, persistence, AP legality, and deterministic combat effects. Then run focused GUT tests, `make check`, editor scan, seeded battle simulations, and a manual `make play` route before local merge.
