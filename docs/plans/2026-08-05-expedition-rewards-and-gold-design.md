# Expedition Rewards and Gold Design

## Purpose

Turn the existing settlement-to-battle route into the first repeatable expedition loop. A player chooses between two fixed expeditions, accepts a clear risk/reward trade-off, wins or loses a tactical battle, and brings any earned gold back to the Encampment.

This is a product-design document. It defines player outcomes, state boundaries, and scope gates; it is not an implementation plan.

## Player loop

```text
Encampment
  -> choose Goblin Camp or a tougher expedition
  -> travel and enter its battle
  -> win: the site clears and its fixed reward becomes pending
     or lose: the party returns home with no reward
  -> return to the Encampment
  -> pending reward is deposited as player gold exactly once
  -> choose the remaining or next expedition
```

Delaying payment until the return makes an expedition feel like a trip with spoils to bring home, rather than a battle that changes an abstract counter.

## Expedition choices

The World Map contains two persistent expedition sites:

| Site | Tactical role | Reward | Result on victory |
| --- | --- | --- | --- |
| Goblin Camp | Lower-risk introductory battle | Fixed lower gold amount | Site clears; reward becomes pending |
| Second expedition | Tougher battle using the existing combat vocabulary | Fixed higher gold amount | Site clears; reward becomes pending |

The second expedition differs through its enemy setup or combat statistics, not through a new combat subsystem. Its world-map presentation communicates its name, greater danger, and fixed gold reward before the player enters.

Exact site names, enemy composition, and gold values are implementation-level balance choices. They should make the higher reward visibly justify the greater tactical risk without random reward rolls.

## Resource model

Gold is the first banked player resource. It is campaign state, starts at zero in a new campaign, and is intended to fund a later improvement slice.

Each deployed party can carry one pending expedition reward. A battle victory records the selected site's fixed reward as that pending amount while marking the site complete. It does not add the amount to banked gold on the World Map.

When the party returns to the Encampment, the campaign deposits the pending amount into banked gold and clears the pending amount in the same state transition. The Encampment confirms the received amount and shows the new total. This must be idempotent: revisiting the Encampment, changing scenes, or reopening a panel cannot pay a reward a second time.

Defeat grants no pending or banked gold. It retains the current outcome: return the party to the Starting Settlement and leave the expedition available for a later attempt.

## Information panel

Strategic screens gain a consistent information panel on the right side of the screen. This slice uses it only to expose the player's banked gold:

```text
Information
-----------
Gold: <banked amount>
```

The panel appears at least on the Encampment and World Map, where the player makes expedition and future spending decisions. It is a reusable container, not a gold-specific widget: later resources, party status, supplies, or objectives can be added without moving the basic layout.

The banked amount is the primary value. During an expedition, a small pending reward indication may appear on the World Map if it improves clarity, but it must clearly remain separate from spendable gold and is not required here.

## State and scene boundaries

- `GameSession` owns durable campaign resources, pending rewards, site completion, party deployment, and party location.
- `GameManager` owns named transitions, including the route that returns a party to the Encampment.
- The battle outcome identifies the current expedition and asks campaign state to record its victory reward; the battlefield does not own gold totals.
- The settlement/encampment return transition performs the single deposit.
- Strategic scenes read resource state to render the information panel and emit no direct cross-scene mutations.

These boundaries preserve the existing rule that scene scripts express player intent while `GameSession` owns durable campaign state.

## Completion criteria

- A new campaign starts with zero banked gold and no pending reward.
- The player can see two expeditions whose danger and fixed rewards differ.
- Winning either expedition clears its map site and records, but does not yet bank, its reward.
- Returning to the Encampment deposits that reward exactly once and visibly updates the gold total.
- Losing grants no gold, returns the party home, and leaves the site retryable.
- The right-side information panel shows the same banked gold total on the Encampment and World Map.
- The ordinary settlement-to-expedition-to-return route remains playable; debug scenarios support focused checks but do not replace this end-to-end verification.

## Out of scope

- Gold spending, shops, equipment, recruitment, training, or settlement upgrades
- Random reward rolls, loot inventories, items, or multiple currencies
- Save/load persistence and enabling Continue or Load
- Additional party members, multiple deployed parties, or new tactical rules
- Durable presentation art or audio beyond clarity-oriented reuse of the current visual language

The next slice should add one deliberately small gold-funded improvement only after this reward and choice loop has been played and understood.
