# Base Expansion Lot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Rebirth-10 lot behind every base that raises the pen limit to 30 and incubators to 8, bought at a For Sale sign for max($50B, 6 h of price income).

**Architecture:** Pure rules live in `Config` (price, limits, slot prices) so server, client and tests share them. A new `ExpansionService` owns the sign, prompt, purchase and the per-plot locked/bought state; the map parts are built once in Studio by an edit-time tool, and runtime only toggles them. Existing pen/incubator loops already key off the `Slot` attribute, so new parts slot in; only limit reads and the inside-plot check change.

**Tech Stack:** Roblox Luau (Studio via MCP), local Luau runtime tests in `steal-a-ride/tests/run_feedback_checks.py` (`--runtime <luau dir>`).

**Spec:** `steal-a-ride/docs/superpowers/specs/2026-10-10-base-expansion-design.md`

## Global Constraints

- Unlock: `data.Rebirths >= 10`. One lot per player; flag `BaseExpanded` (saved, kept through rebirth).
- Lot price = `max(50e9, priceIncome * 6 * 3600)`, priceIncome = `CreatureService.priceIncomeOf(player)`; never `incomeOf`.
- Limits: pen 20 / incubators 6 without the lot; 30 / 8 with it.
- Pen slot price: `250 * 3^(slot-7)` for 7..20; `1.75e9 * 1.5^(slot-21)` for 21..30. Incubator 7 = `10e9`, 8 = `20e9`.
- Lot strip per plot: 28 x 58, from the back wall (Floor.X + Side*30) outward to Floor.X + Side*59 (x +-81..+-109), same z as the plot. `Side` = plot attribute (-1 left, +1 right); outward = `Side`.
- Gap in the back wall: 20 studs, centred.
- Decor parts: anchored; small parts CanCollide/CanQuery/CanTouch false and CastShadow false; no lights, particles or sounds.
- Copy: sign "Unlocks at Rebirth 10" / "Base Expansion $X"; toast "Your base expanded! Buy new pen slots and incubators at Sam's Upgrades stall."; Sam's locked row "Needs the base expansion (Rebirth 10)" + button "LOCKED"; What's New and Guide lines exactly as in the spec.
- Workflow (AGENTS.md / HANDOFF.md): update HANDOFF.md at start and after each task; back up Studio scripts to `ServerStorage.ExpansionBackup20261010` before overwriting; Studio source must equal local (LF djb2) after each install; Play tests use TestHooks `fakeStore` and set attr `DataLoadFailed` true so no global boards are written. **Commits and publishing only after the user says so.**

## Review Focus

1. A plot freed by a leaving owner and claimed by a new player must show the locked lot (fence, sign, solid wall), never the previous owner's bought state. → Task 5 test `reset clears a bought plot`.
2. A returning player whose save has `BaseExpanded` gets a different plot than last time → the new plot shows bought state on join. → Task 5 test `apply on any plot`.
3. Spamming the prompt (or two triggers in one frame) charges once. → Task 5 test `second buy refused`.
4. Pens/incubator pads 21-30 / 7-8 stay fully hidden while the lot is not bought (not ghost-visible through the fence) and appear as not-owned (0.75 / 0.7) after. → Task 5 test on the hide rule.
5. Game passes (Incubators +2, PenSlots +5) keep capping at the base 6 / 20 even after the lot (they are one-time join grants, not lot slots). → Task 1 test.

---

### Task 1: Config rules and save field

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (Config.Plot ~218, Config.Costs ~417)
- Modify: `steal-a-ride/src/ServerScriptService/Services/DataService.luau` (defaults)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (new `expansion_harness`, registered in `main()`'s list)

**Interfaces:**
- Produces: `Config.Expansion = { rebirth = 10, minPrice = 50e9, incomeSeconds = 21600, maxPen = 30, maxIncubators = 8, gap = 20 }`; `Config.expansionPrice(priceIncome: number): number`; `Config.penMax(expanded: boolean?): number`; `Config.incubatorMax(expanded: boolean?): number`; `Config.Costs.penSlot(slot)` extended; `Config.Costs.incubators[7] = 10e9, [8] = 20e9`; DataService default `BaseExpanded = false`.

- [ ] **Step 1: Write the failing test** (`expansion_harness`, loads Config via `module()`):

```lua
assert(Config.expansionPrice(0)==50e9 and Config.expansionPrice(2e6)==50e9,"lot price floor $50B")
assert(Config.expansionPrice(1e7)==1e7*21600,"lot price = 6 h of price income above the floor")
assert(Config.penMax(false)==20 and Config.penMax(true)==30 and Config.penMax(nil)==20,"pen limit")
assert(Config.incubatorMax(false)==6 and Config.incubatorMax(true)==8,"incubator limit")
assert(Config.Costs.penSlot(20)==250*3^13,"slots 7-20 unchanged")
assert(math.abs(Config.Costs.penSlot(21)-1.75e9)<1 and math.abs(Config.Costs.penSlot(30)-1.75e9*1.5^9)<1,"slots 21-30")
local total=0 for s=21,30 do total+=Config.Costs.penSlot(s) end
assert(total>190e9 and total<205e9,"all ten ~ $200B")
assert(Config.Costs.incubators[7]==10e9 and Config.Costs.incubators[8]==20e9,"incubators 7/8")
assert(Config.Plot.maxPen==20 and Config.Plot.maxIncubators==6,"pass caps stay at the base limits")
print("PASS: base expansion price, limits and slot prices")
```

- [ ] **Step 2: Run** `python steal-a-ride/tests/run_feedback_checks.py --runtime <luau dir>` — Expected: FAIL (`expansionPrice` nil).
- [ ] **Step 3: Implement** the Interfaces above in Config (keep `Config.Plot.maxPen/maxIncubators` = 20/6) and add `BaseExpanded = false` to DataService `defaults()`.
- [ ] **Step 4: Run** the same command — Expected: `PASS: base expansion price, limits and slot prices`, all other groups PASS, compile PASS.
- [ ] **Step 5: Commit** (only with the user's OK): `git add` Config, DataService, test; message `Base expansion: config rules and save flag`.

### Task 2: Shop limits and locked rows

**Files:**
- Modify: `steal-a-ride/src/ServerScriptService/Services/ShopService.luau` (ITEMS.pen ~43, ITEMS.incubator ~35)
- Modify: `steal-a-ride/src/StarterGui/MainUI/ShopUI.luau` (incubator/pen `info` ~73-80, `refresh`)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`expansion_harness` + the existing ShopService harness if one loads it; otherwise load ShopService via `module()` with stub DataService/CreatureService/HatchService/SpeedService)

**Interfaces:**
- Consumes: Task 1 `Config.penMax`, `Config.incubatorMax`, `Config.Costs`.
- Produces: ShopService reads `data.BaseExpanded`; player attribute `BaseExpanded` (set by `ShopService.sync`) for the client.

- [ ] **Step 1: Write the failing test:** with `data = {PenSlots=20, IncubatorCount=6, Cash=1e12, BaseExpanded=false}`: `ShopService.buy(player,"pen")==false` and `ShopService.buy(player,"incubator")==false`; set `BaseExpanded=true`: pen buy true and `data.PenSlots==21`, cash down by `1.75e9`; incubator buy true, `data.IncubatorCount==7`, cash down by `10e9`; with `PenSlots=30` pen buy false; `IncubatorCount=8` incubator buy false.
- [ ] **Step 2: Run** — Expected: FAIL (pen 21 bought or nil cost path).
- [ ] **Step 3: Implement:** pen item caps at `Config.penMax(data.BaseExpanded)`; incubator item returns nil when `n > Config.incubatorMax(data.BaseExpanded)`; `ShopService.sync` sets attr `BaseExpanded`. ShopUI: the pen/incubator rows use the same helpers with `player:GetAttribute("BaseExpanded")`; when not expanded and at 20 / 6 with `(player:GetAttribute("Rebirths") or 0)` any value, the desc reads `"Needs the base expansion (Rebirth 10)"` and the button `"LOCKED"` grey (third return value from `info`, like the gear restock path); otherwise unchanged `n/max` text.
- [ ] **Step 4: Run** — Expected: all PASS.
- [ ] **Step 5: Commit** (user OK): `Base expansion: shop limits and locked rows`.

### Task 3: The lot counts as inside the base

**Files:**
- Modify: `steal-a-ride/src/ServerScriptService/Services/StealService.luau:151-155` (`insidePlot`) and its 3 callers
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`expansion_harness`)

**Interfaces:**
- Produces: `StealService.insidePlot(plot, pos: Vector3): boolean` (exported; true inside `plot.Floor`, or inside `plot.Expansion.Floor` when `plot:GetAttribute("Expanded")` is true). Task 5 sets the plot attribute `Expanded`.

- [ ] **Step 1: Write the failing test** with table stubs for plot/Floor/Expansion.Floor (Position/Size as `{X,Y,Z}` tables built with a tiny Vector3 stub): a point in the lot is outside when `Expanded` is false, inside when true; a point in the base is inside either way; a point beyond the lot is outside.
- [ ] **Step 2: Run** — Expected: FAIL (`insidePlot` not exported).
- [ ] **Step 3: Implement** the exported function; replace the local and keep the 3 call sites (`swing`, stick sync, locked push-out) using it.
- [ ] **Step 4: Run** — Expected: all PASS.
- [ ] **Step 5: Commit** (user OK): `Base expansion: lot counts as inside the base`.

### Task 4: Map build tool (Studio)

**Files:**
- Create: `steal-a-ride/src/ServerStorage/BuildTools/BuildBaseExpansion.luau` (ModuleScript returning `function(): string`, rerunnable like `BuildPlazaDecor`)
- Studio: run it once; parts go into each `workspace.HomeRow.Plots.PlotN`

**Interfaces:**
- Produces per plot: `Plot.Expansion` (Model) with `Floor` (28 x 58, top flush with `Plot.Floor` top), `WallOuter`/`WallSideA`/`WallSideB` (same height/material as `Plot.Wall`), `Fence` (Model, low wooden fence across the back opening), `Sign` (Part with SurfaceGui `Line1` facing into the base), `BackGap` (the 20-stud centre piece of the back wall; the original back `Wall` part is split into two segments either side of it); pen pedestals cloned from an existing `Plot.Pen` pedestal with attr `Slot` 21..30 (2 columns x 5 rows, same 8 x 10 spacing, rows at the main pen's z values) placed in `Plot.Pen`; incubator pads cloned from `Plot.Incubators` pad with attr `Slot` 7, 8 along the outer wall placed in `Plot.Incubators`. Rerun destroys and rebuilds `Expansion`, slot-21+ pedestals and slot-7/8 pads, and restores the original back wall from attr `OriginalWall` before splitting again.

- [ ] **Step 1: Write the tool** (no unit test: map geometry). Back-wall identification: the `Wall` part whose X is `Floor.X + Side*30`.
- [ ] **Step 2: Install + run in Studio Edit** (HttpService fetch from the local `python -m http.server`, restore HttpEnabled). Expected return: `Base expansion lots built on 8 plots`.
- [ ] **Step 3: Verify:** run it a second time; positions of `Expansion.Floor`, pedestal 21, pad 7 identical between runs; `Plot1`/`Plot2` (left/right) mirror correctly; screenshot top-down of two plots.
- [ ] **Step 4: Commit** (user OK): `Base expansion: lot map parts`.

### Task 5: ExpansionService (sign, buy, state)

**Files:**
- Create: `steal-a-ride/src/ServerScriptService/Services/ExpansionService.luau`
- Modify: `steal-a-ride/src/ServerScriptService/Main.luau` (start; after `PlotService.assign` in onPlayerReady; PlayerRemoving before `PlotService.release`; `RebirthService.afterRebirth`)
- Modify: `steal-a-ride/src/ServerScriptService/Services/CreatureService.luau` (`renderPen` transparency ~88) and `HatchService.luau` (pad transparency ~113-114)
- Modify: `steal-a-ride/src/ServerScriptService/Services/BaseService.luau` (add hook `BaseService.afterApply = function(_player) end`, called at the end of `BaseService.apply`; Main sets it to `ExpansionService.apply`, so cosmetic changes reach the lot without a require cycle)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`expansion_harness`)

**Interfaces:**
- Consumes: Task 1 `Config.expansionPrice`, `Config.Expansion`; Task 4 part names; `CreatureService.priceIncomeOf`, `DataService.get/addCash`, `PlotService.get`, `Notify`.
- Produces: `ExpansionService.canBuy(data, price: number): (boolean, string?)` (pure; reasons "rebirth", "owned", "cash"); `ExpansionService.setState(plot, expanded: boolean)` (fence/sign/BackGap/lot pedestals+pads; sets plot attr `Expanded`; when expanded copies `Plot.Floor` Color/Material/MaterialVariant to `Expansion.Floor` and the base wall Color/Material to the lot walls); `ExpansionService.apply(player)`; `ExpansionService.reset(plot)` (= `setState(plot, false)` + sign "Unlocks at Rebirth 10"); `ExpansionService.start()` (prompts on every plot's sign, 2 s loop updating the owner's sign text/prompt Enabled); `Config.hiddenSlot(slot, kind: "pen"|"incubator", expanded): boolean` used by renderPen/HatchService (true when slot is beyond the base limit and not expanded → Transparency 1, no label).

- [ ] **Step 1: Write the failing tests:** `canBuy({Rebirths=9,Cash=1e12},50e9)` → false,"rebirth"; `{Rebirths=10,Cash=49e9}` → false,"cash"; `{Rebirths=10,Cash=50e9}` → true; `{Rebirths=12,Cash=1e12,BaseExpanded=true}` → false,"owned" (second buy refused); `Config.hiddenSlot(21,"pen",false)==true`, `(21,"pen",true)==false`, `(20,"pen",false)==false`, `(7,"incubator",false)==true`; `setState`/`reset` on a stub plot flips `Expanded`, fence/sign visibility and BackGap CanCollide (reset after a bought state ends locked: Review Focus 1); `apply` on a plot other than the save's last one shows bought (Review Focus 2: apply reads only `data.BaseExpanded`); `setState(plot,true)` copies the stub `Plot.Floor` colour to `Expansion.Floor`; in the existing `rebirth_harness`, a save with `BaseExpanded=true` still has it after `RebirthService.rebirth` (spec: kept through rebirth).
- [ ] **Step 2: Run** — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** ExpansionService per Interfaces. Buy path on prompt trigger: owner check (`plot:GetAttribute("OwnerUserId") == player.UserId`), price from `Config.expansionPrice(CreatureService.priceIncomeOf(player))` at trigger time, `canBuy`, then `DataService.addCash(player, -price)`, `data.BaseExpanded = true`, `ShopService.sync(player)`, `setState(plot, true)`, toast (spec copy). Non-owner trigger: toast "This lot belongs to another player". Sign text: R<10 "Unlocks at Rebirth 10"; else `"Base Expansion $" .. Format.number(price)`; hidden when bought. Wire Main as listed (incl. `BaseService.afterApply`); renderPen/HatchService use `Config.hiddenSlot(slot, kind, plot:GetAttribute("Expanded"))`.
- [ ] **Step 4: Run** — Expected: all PASS, compile PASS.
- [ ] **Step 5: Install in Studio** (backup first; Studio == local djb2 for every changed script).
- [ ] **Step 6: Commit** (user OK): `Base expansion: ExpansionService`.

### Task 6: Text, Play verification, handoff

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (What's New: next unpublished version; Guide `upgrades` tip — exact spec lines)
- Modify: `HANDOFF.md`

- [ ] **Step 1: Add the two text lines** (spec "Player-facing text"); run the suite — Expected: all PASS.
- [ ] **Step 2: Install Config; Play** (fakeStore + `DataLoadFailed`): with TestHooks `set Rebirths 9` sign reads "Unlocks at Rebirth 10", prompt disabled; `set Rebirths 10` → "Base Expansion $50B" (or 6 h income); move every creature out of the pen (RemoveFromPen) → sign price unchanged; `set Cash` below price → buy refused toast; enough cash → buy: fence gone, gap open, pedestals 21-30 at 0.75, pads 7-8 at 0.7, Cash down by the price; Sam's rows: pen "$1.75B", incubator "$10B"; buy both; place a creature on slot 21 (PlaceInPen) and see it on pedestal 21; deposit an egg (TestHooks `fillIncubators`) and see it on pad 7; stand in the lot → stun stick equips (insidePlot); trigger the prompt again → refused; call `ExpansionService.reset` path via leaving is not testable solo, so re-run `apply` after `set BaseExpanded false` → locked state returns; screenshots before/after; console has no new errors.
- [ ] **Step 3: Update HANDOFF.md** with changed files, Studio state, verification results, unverified items (2-player lock push-out, real plot hand-over after a leave), and next step "user publishes".
- [ ] **Step 4: Commit** (user OK): `Base expansion: text and verification`.
