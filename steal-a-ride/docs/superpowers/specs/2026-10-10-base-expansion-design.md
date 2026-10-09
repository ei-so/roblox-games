# Base expansion lot: design

Date: 2026-10-10. Status: written, awaiting user review. Nothing built.

## Goal

Late-game players (Rebirth 10+) have maxed the pen (20) and incubators (6) and have nothing left to buy at home. A buyable
lot behind every base gives them a long cash goal and room for 10 more pen spots and 2 more incubators.

## User decisions

- Unlock: Rebirth 10 **and** cash.
- Lot price: tied to income, floor $50B. Moving creatures out of the pen must never lower it.
- The lot raises the limits (pen 20 -> 30, incubators 6 -> 8); each new slot is then bought one by one.
- Pen slots 21-30 total about $200B; incubator 7 = $10B, incubator 8 = $20B.
- Bought at the lot itself (sign + prompt behind the base), not at a shop.

## Space (measured in Studio, 2026-10-09)

- Plots are 60 x 60 (`HomeRow.Plots.Plot1..8`), centres x = +-50, z = +-35 / +-105; front (door) faces the road at x +-20,
  back wall at x +-80 (`Side` attribute gives the direction).
- Behind each back wall: `SafeZone.Floor` continues to x +-110, so a 28 x 58 strip (x +-81..+-109, same z as the plot)
  is free. Nothing else stands there.
- Pen pedestals (`Plot.Pen`, 20 parts, attr `Slot` 1..20) and incubator pads (`Plot.Incubators`, 6 parts, attr `Slot`
  1..6) are map parts; `CreatureService.renderPen` and `HatchService` loop over the folders and use `Slot`, so extra
  parts numbered 21..30 / 7..8 work without new render code.

## Layout (per plot, mirrored by `Side`)

- **Lot area** `Plot.Expansion` (Model): floor 28 x 58 at the base floor height, outer walls on the three open sides
  (same height as base walls), 2 pen columns x 5 rows (pedestals Slot 21..30, same size and 8 x 10 spacing as the main
  pen), 2 incubator pads (Slot 7, 8) along the outer wall. Pedestals/pads live in the existing `Plot.Pen` /
  `Plot.Incubators` folders so the current loops find them.
- **Locked state** (owner has not bought): a low wooden fence across the base's back wall opening, a "For Sale" sign
  facing into the base, the lot's pedestals/pads hidden (Transparency 1, no prompts). The base's back wall stays solid.
- **Bought state**: fence + sign hidden, a 20-stud gap opens in the middle of the back wall (wall split into two
  segments + a centre segment that toggles CanCollide/Transparency), lot floor/walls take the owner's base colour and
  floor cosmetics, pedestals/pads show as owned or not owned like the main ones (0 / 0.75 transparency).
- The lot is reachable only through the base. Built for all 8 plots by an edit-time tool
  `ServerStorage.BuildTools.BuildBaseExpansion` (rerunnable, like BuildPlazaDecor); runtime only toggles states.

## Rules

- **Lot price** (server, `Config.expansionPrice(priceIncome)`):
  `max(Config.Expansion.minPrice = 50e9, priceIncome * Config.Expansion.incomeSeconds = 6 * 3600)`, where priceIncome is
  `CreatureService.priceIncomeOf(player)` (best PenSlots creatures anywhere, VIP/friend multipliers). Pen / Stable /
  riding moves cannot lower it. Selling creatures lowers it, but the creatures and their income are gone for good.
- **Buy**: E prompt on the sign, owner only. Server checks: owner of this plot, `data.Rebirths >= 10`, not already
  bought, `data.Cash >= price` at that moment. Then `data.BaseExpanded = true`, cash deducted, lot switches to bought
  state, toast "Your base expanded! Buy new pen slots and incubators at Sam's Upgrades stall."
- **Sign text**: below Rebirth 10 "Unlocks at Rebirth 10"; at 10+ "Base Expansion $X" (live, from the `Income`
  attribute the client already gets) with the prompt; hidden once bought.
- **Limits**: `Config.Plot.maxPen` 20 -> 30 and `maxIncubators` 6 -> 8 only when `BaseExpanded`; otherwise they stay
  20 / 6 (helper `Config.penMax(expanded)` / `Config.incubatorMax(expanded)`, used by ShopService, ShopUI and any
  existing maxPen/maxIncubators reads).
- **Slot prices**: `Config.Costs.penSlot(slot)` keeps `250 * 3^(slot-7)` for 7..20; 21..30 = `1.75e9 * 1.5^(slot-21)`
  (1.75B, 2.6B, 3.9B, 5.9B, 8.9B, 13B, 20B, 30B, 45B, 67B; total ~198B). `Config.Costs.incubators[7] = 10e9`,
  `[8] = 20e9`.
- **Sam's rows**: when the next slot is beyond 20 / 6 and the lot is not bought, the row reads "Needs the base
  expansion (Rebirth 10)" and the button is grey "LOCKED"; the server refuses the buy.
- **Rebirth**: `BaseExpanded` and bought slots are kept (RebirthService already keeps IncubatorCount / PenSlots).
- **Stealing / lock**: the lot is part of the base. `StealService.insidePlot` also counts the lot floor when the owner
  has `BaseExpanded`, so the lock push-out, stun stick and "own plot" checks cover it. Incubators 7-8 can be stolen from
  like the others (existing pad code).
- **Rebirth rewards** "incubator" / "pen" (Rebirths 1-9) keep their current cap check at 6 / 20 (a Rebirth 1-9 player
  cannot own the lot), so nothing changes there.
- **Save**: one new field `BaseExpanded = false` in DataService defaults (reconcile fills it for old saves); replicated
  as player attribute `BaseExpanded`.

## Player-facing text

- What's New (next unpublished version): "Rebirth 10 unlocks a **Base Expansion** behind your base: 10 more pen spots
  and 2 more incubators".
- Guide `upgrades` tip gains: "From Rebirth 10 you can buy the lot behind your base for 10 more pen slots and 2 more
  incubators."

## Files

- Studio map + new `BuildTools/BuildBaseExpansion.luau`.
- `Config` (Expansion table, price helper, limits helpers, slot prices, What's New, Guide).
- `DataService` (default), new `ServerScriptService/Services/ExpansionService.luau` (sign + prompt, buy, locked/bought
  state toggle when a plot is claimed or freed), `ShopService` + `ShopUI` (limits/locked rows), `StealService.insidePlot`,
  `Main` wiring.
- Tests in `tests/run_feedback_checks.py`.

## Testing

- Unit: price floor at 0 / low income; price = 6 h income above the floor; **emptying the pen does not change the price**
  (priceIncomeOf); Rebirth 9 refused, 10 allowed; second buy refused; limits 20/6 before and 30/8 after; slot 21..30 and
  incubator 7/8 prices; ShopService refuses slot 21 without the lot; flag survives rebirth; insidePlot covers the lot
  only when expanded.
- Play (fakeStore + DataLoadFailed so no board writes): sign text at R9 and R10; buy the lot; back wall opens, fence
  gone; buy slot 21 and incubator 7 at Sam's; place a creature on pedestal 21; deposit and hatch an egg on incubator 7;
  standing in the lot counts as inside the plot (stun stick equips there); re-claiming the plot (as on rejoin) keeps the
  bought state; screenshots before/after. The lock push-out of a real second player is covered by the insidePlot unit
  test only: it needs a 2-player test server (user check).

## Out of scope

- More than one expansion, Robux shortcut, changing the main base layout, rebirth-reward changes.
