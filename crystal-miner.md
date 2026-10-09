# Crystal Miner: Roblox Incremental Game Spec

An idle clicker game. The player mines **Crystals**, buys generators that mine for them, upgrades their income, and rebirths for a permanent multiplier.

> **For the AI reading this:** use your Roblox Studio MCP tools to build everything in **Phase 1** in the currently open place. **Don't build Phase 2** unless the user asks for a specific item.

---

## How to work

1. Inspect Workspace, ServerScriptService, ReplicatedStorage and StarterGui first. Don't delete anything you didn't create. If objects with the names below already exist, replace them.
2. Create every Script, LocalScript and ModuleScript by running Luau in Studio (`Instance.new`, then set `.Source`). Use the exact names and locations below.
3. When you're done, start a playtest and read the Output console. Fix every error or warning from your scripts and repeat until the playtest runs clean.
4. Stop the playtest and summarize what you built.

---

## Phase 1: Core game

### Architecture (the server owns all state)

```
ReplicatedStorage
  Shared (Folder)
    Config (ModuleScript)     -- all tuning numbers below
    Format (ModuleScript)     -- number formatting
  Remotes (Folder)            -- RemoteEvents: Click, BuyGenerator, BuyUpgrade, Rebirth
ServerScriptService
  GameServer (Script)         -- all game state and DataStore saving
StarterGui
  GameUI (ScreenGui, ResetOnSpawn = false)
    UIController (LocalScript)
```

- The server owns all state. The client only fires remotes and displays values.
- Replicate state through **Player attributes**: `Crystals`, `PerSecond`, `ClickPower`, `RebirthTokens`, `Rebirths`, `RunEarned`, plus `Gen_<id>` (count owned) and `Upg_<id>` (level). The client listens with `AttributeChanged`. Don't use polling or remotes that push state.
- Validate every remote: correct argument types, known ids, amount in `{1, 10, "max"}`, enough currency.
- Rate-limit `Click` to **20 per second per player** and silently drop extra clicks.
- leaderstats: `StringValue "Crystals"` (formatted) and `IntValue "Rebirths"`.

### Generators

Cost of the next one = `baseCost * 1.15^owned`

| id | Name | Base cost | Crystals/sec |
|---|---|---:|---:|
| `pickaxe` | Pickaxe Buddy | 15 | 0.5 |
| `drill` | Drill | 100 | 2 |
| `cart` | Mine Cart | 1,100 | 10 |
| `excavator` | Excavator | 12,000 | 50 |
| `goldmine` | Gold Mine | 130,000 | 260 |
| `factory` | Crystal Factory | 1,400,000 | 1,400 |
| `spacemine` | Space Mine | 20,000,000 | 7,800 |

- **Bulk cost of n:** `baseCost * 1.15^owned * (1.15^n - 1) / 0.15`
- **Max:** the largest n the player can afford. Solve it with logs, then clamp so the cost is never more than their Crystals.

### Upgrades

| id | Name | Cost | Effect |
|---|---|---|---|
| `clickpower` | Sharper Pickaxe | `100 * 5^level` | Each level doubles base click |
| `efficiency` | Better Tools | `1000 * 10^level` | Generator output ×1.5 per level |

### Formulas

```
globalMult  = 1 + 0.10 * RebirthTokens
PerSecond   = sum(owned * perSecond) * 1.5^efficiencyLevel * globalMult
Click value = 2^clickpowerLevel * globalMult + 0.01 * PerSecond
```

### Rebirth

- Unlocks when `RunEarned >= 1,000,000`.
- Grants `floor(sqrt(RunEarned / 1e6))` Rebirth Tokens.
- Resets Crystals, generators, upgrades and RunEarned. Tokens and the Rebirths count carry over.

### Server tick

Every 1 second, add `PerSecond` to `Crystals` and `RunEarned`. Use **one** loop over all players, not one loop per player.

### Saving

- DataStore `"CrystalMiner_v1"`, key `"u_" .. UserId`.
- Save Crystals, RunEarned, generators, upgrades, RebirthTokens, Rebirths and LastOnline (`os.time()`).
- Load with `pcall` and up to 3 retries. **If loading fails, never save that player's data this session** (don't overwrite real data with defaults), and show the player a warning.
- Save with `UpdateAsync` on `PlayerRemoving`, on a 60-second autosave and in `game:BindToClose`.
- **Offline earnings** on join = `min(now - LastOnline, 8 hours) * PerSecond * 0.5`, shown in a popup: *"While you were away you earned X"*.

### Number format (Format module)

- Below 1000: up to 1 decimal place, with no trailing `.0`.
- Above that, use suffixes with 2 decimals (`1.23M`): K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc
- Past Dc, use scientific notation (`1.23e36`).

### UI (must work on PC and phone)

- **Top bar:** Crystals (big), Crystals/sec, and Rebirth Tokens with the current multiplier.
- **MINE button (center-left):** on click, fire `Click`, tween the button scale down and back up, and spawn a `+X` label that floats up and fades out.
- **Shop panel (right):** a ScrollingFrame with UIListLayout and AutomaticCanvasSize.
  - Generators and Upgrades sections.
  - Each row shows name, owned count or level, production, cost and a Buy button.
  - An x1 / x10 / Max toggle at the top for generators.
  - Buy buttons the player can't afford are greyed out.
- **Rebirth button:** shows how many tokens the player would get. It's disabled with *"Reach 1M to rebirth"* until unlocked, and asks for confirmation before rebirthing.
- **Style:** UICorner, UIStroke, UIPadding and scale-based sizes. Dark theme with one accent color (crystal cyan).
- The client computes costs from Config **for display only**. The server recomputes costs and has the final say.

### Done when

- [ ] Clicking mines Crystals and shows the float-up text
- [ ] Generators and upgrades can be bought (x1, x10 and Max)
- [ ] Crystals go up every second
- [ ] Rebirth works and the multiplier applies
- [ ] Data saves between sessions, and offline earnings show up
- [ ] The playtest Output shows no errors from these scripts

---

## Phase 2: Add-ons (only build when the user asks)

1. **Polish:** a click sound, a buy sound, a particle burst on the MINE button, and a counter that animates up smoothly instead of jumping.
2. **3D world:** a big glowing crystal in Workspace with a ClickDetector that also mines through the same `Click` remote. Each generator type a player owns shows up as a small model around the crystal.
3. **Retention:** a daily login reward with a streak, plus 10 achievements (first rebirth, 1M crystals, 100 drills, etc.) that each give +1% permanent income. Save them in the existing DataStore entry.
4. **Monetization:** a "2x Crystals" game pass and a "Crystal Pack" developer product. Handle `ProcessReceipt` idempotently (store receipt IDs) and use placeholder IDs the user can swap later.
5. **Balance:** simulate a player who buys the cheapest best-value item every second, report time-to-first-rebirth, then tune Config so the first rebirth takes about 20 minutes.

---

## Setup notes (for the user)

- **Saving won't work in Studio until you turn it on.** Publish the place, then enable *Game Settings → Security → Enable Studio Access to API Services*.
- **If something breaks:** tell the AI *"Playtest, read the Output, and fix all errors from your scripts."*
- **To add Phase 2 features:** tell the AI *"Build Phase 2, item 1 from crystal-miner.md"*, and so on.
