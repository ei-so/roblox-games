# Base Stun Stick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Base owners get a stick (only inside their own base) that stuns a thief carrying an egg stolen from them and sends the egg back to their incubator; stick looks are a 5-tier Cash cosmetic ladder.

**Architecture:** Stick logic lives in `StealService` (it already owns `robbedAt`, `insidePlot` and the 0.3 s tick). The server builds a Roblox `Tool` and listens to `Tool.Activated` on the server (it replicates natively — no new RemoteEvent). Cosmetics reuse the base-cosmetics system (`Config.Base.items`, `"base:<id>"` shop items, `data.Base.owned/equipped`, Base panel) with a new `stick` slot plus two additions: income-scaled price (`incomeMinutes`) and a `requires` gate.

**Tech Stack:** Roblox Luau. Local `steal-a-ride/src` mirrors Studio; changes are installed into Studio with the Roblox Studio MCP (`execute_luau` find/replace on `.Source`, guarded by exact-match checks). Offline checks: Python harness that inlines Luau modules and runs the official `luau.exe` (`$env:TEMP/steal-a-mount-luau-0.741`).

**Spec:** `steal-a-ride/docs/superpowers/specs/2026-10-09-base-stun-stick-design.md`

## Global Constraints

- Hit egg goes straight back to the owner's incubator (`EggService.take` + `HatchService.give`).
- Only a player carrying an egg with `egg.stolenFrom == owner` can be hit; anyone else = whiff.
- Stun = 2 s (`SpeedService.stun`). Range 7 studs. Swing cooldown 0.8 s.
- On a hit, clear `robbedAt[owner]` (the 60 s robCooldown) so the thief may retry after the stun.
- Stick exists only while the owner stands inside their own plot (`insidePlot`); auto-equipped on entry, destroyed on exit.
- Tiers: Wooden (free) → Iron 10 min → Gold 30 min → Crystal 60 min → Glitch 120 min of income; each requires the previous; price floor `Config.Gear.minPrice` (500); kept through rebirth (existing `data.Base`, no save-schema change).
- Glitch tier uses the OG badge palette: red `rgb(255, 42, 79)` / cyan `rgb(37, 232, 255)`.
- Project convention: no git commits/publish unless the user asks. Each task backs up touched files to `steal-a-ride/before-stick-20261009/` first and records progress in `HANDOFF.md`.
- Deviation from spec (approved-safe simplification): no `StickSwing` RemoteEvent — `Tool.Activated` already fires on the server.

## Review Focus

1. Thief standing just outside the plot boundary while owner is inside → hit still allowed (only the owner must be inside); range check is the limit. Test: Task 2 case "thief outside plot but in range is hit".
2. Owner swings repeatedly on a valid thief → second swing within 0.8 s does nothing and never double-gives the egg. Test: Task 2 cooldown case.
3. Thief carrying an egg stolen from a *different* player, inside your base → whiff, egg untouched. Test: Task 2 bystander case.
4. Buying Gold without Iron (e.g. crafted remote call) → refused, no cash taken. Test: Task 1 `requires` case.
5. Pressing key 1 in base: GearUI binds 1-2-3 and the default backpack binds 1 to the stick → must not break Net Gun use. Checked in Task 4 Play step (manual; report result).

---

### Task 1: Stick tiers in Config + income price and `requires` gate

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Config.luau` (Base.slots ~L213, Base.items after `gateGolden` ~L279, new `Config.Stick` + `Config.basePrice` after `Config.Gear` ~L315)
- Modify: `src/ServerScriptService/Services/BaseService.luau` (`price` L25-31, header hook, `start` L783-796)
- Modify: `src/ServerScriptService/Main.luau` (wiring near L90)
- Test: `tests/run_stick_checks.py` (new)

**Interfaces:**
- Produces: `Config.Stick = { range = 7, stun = 2, cooldown = 0.8 }`; `Config.basePrice(item, income: number): number`; `BaseService.price(data, itemId, income: number?): number?` (nil = not for sale/locked, 0 = owned/free); `BaseService.incomeOf(player): number` hook (set by Main to `CreatureService.incomeOf`). Stick item fields: `id, slot="stick", name, color, material (Enum.Material name), price=0 | incomeMinutes, requires?, trail?, glitch?, burst`.

- [ ] **Step 1: Backup**

```bash
cd "/c/Users/Desktop/Documents/Roblox Games/steal-a-ride"
mkdir -p before-stick-20261009
cp src/ReplicatedStorage/Shared/Config.luau src/ServerScriptService/Services/BaseService.luau src/ServerScriptService/Main.luau src/ServerScriptService/Services/StealService.luau src/ServerScriptService/Services/GearService.luau src/StarterGui/MainUI/BaseUI.luau before-stick-20261009/
```

- [ ] **Step 2: Write the failing test** — create `tests/run_stick_checks.py`:

```python
"""Base stun stick: tier pricing/gating and StealService.swing hit rules."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module

ROOT = Path(__file__).resolve().parents[1] / 'src'

PRELUDE = r'''
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,new=function(r,g,b) return {R=r,G=g,B=b} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local ColorSequence={new=function() return {} end}
local NumberSequence={new=function() return {} end}
local Vector3={new=function() return {} end}
local Vector2={new=function() return {} end}
local NumberRange={new=function() return {} end}
local CFrame={new=function() return {} end}
local Instance={new=function() return setmetatable({},{__index=function() return function() end end}) end}
'''


def pricing():
    config = module('ReplicatedStorage/Shared/Config.luau', {})
    base = (ROOT / 'ServerScriptService/Services/BaseService.luau').read_text(encoding='utf-8-sig')
    price = base[base.index('function BaseService.price'):base.index('function BaseService.equipped')]
    return PRELUDE + 'local Config=' + config + '\nlocal Base=Config.Base\nlocal BaseService={}\n' + price + r'''
local ids={}
for _,item in Config.Base.items do if item.slot=='stick' then table.insert(ids,item.id) end end
assert(table.concat(ids,',')=='stickWood,stickIron,stickGold,stickCrystal,stickGlitch','five stick tiers in order')
local slotOk=false
for _,s in Config.Base.slots do if s.id=='stick' then slotOk=true end end
assert(slotOk,'stick slot in Base panel')
assert(Config.Stick.range==7 and Config.Stick.stun==2 and Config.Stick.cooldown==0.8,'stick tuning')
local I=Config.Base.itemById
assert(Config.basePrice(I.stickIron,10)==6000,'10 min of $10/s')
assert(Config.basePrice(I.stickGlitch,10)==72000,'120 min of $10/s')
assert(Config.basePrice(I.stickIron,0)==Config.Gear.minPrice,'price floor')
assert(Config.basePrice(I.colorOcean,999)==2500,'fixed-price items unchanged')
local data={Base={owned={},equipped={}}}
assert(BaseService.price(data,'stickWood',10)==0,'wood free')
assert(BaseService.price(data,'stickIron',10)==6000,'iron needs nothing')
assert(BaseService.price(data,'stickGold',10)==nil,'gold locked without iron')
data.Base.owned.stickIron=true
assert(BaseService.price(data,'stickIron',10)==0,'owned = equip only')
assert(BaseService.price(data,'stickGold',10)==18000,'gold unlocked by iron')
assert(BaseService.price(data,'colorOcean')==2500,'old callers without income still work')
print('PASS: stick tiers, income pricing, floor, requires gate')
'''


def swing():
    steal = module('ServerScriptService/Services/StealService.luau', {
        'local Players = game:GetService("Players")': '',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")': '',
        'local Debris = game:GetService("Debris")': '',
        'local Config = require(ReplicatedStorage.Shared.Config)': '',
        'local DataService = require(script.Parent.DataService)': '',
        'local PlotService = require(script.Parent.PlotService)': '',
        'local EggService = require(script.Parent.EggService)': '',
        'local HatchService = require(script.Parent.HatchService)': '',
        'local GuardianService = require(script.Parent.GuardianService)': '',
        'local SpeedService = require(script.Parent.SpeedService)': '',
        'local BaseService = require(script.Parent.BaseService)': '',
        'local Notify = ReplicatedStorage.Remotes.Notify': '',
    })
    return PRELUDE + r'''
local now=100
local os={clock=function() return now end,time=function() return 0 end}
local vmt={}
local function vec(x,z) return setmetatable({X=x,Y=0,Z=z,Magnitude=math.sqrt(x*x+z*z)},vmt) end
vmt.__sub=function(a,b) return vec(a.X-b.X,a.Z-b.Z) end
local function mk(name,x,z)
    local root={Position=vec(x,z)}
    local hum={Health=100}
    local p={DisplayName=name,UserId=#name}
    p.Character={FindFirstChild=function(_,n) if n=='HumanoidRootPart' then return root end end,FindFirstChildOfClass=function() return hum end}
    p.root=root
    return p
end
local owner,thief,other=mk('Owner',0,0),mk('Thief',5,0),mk('Other',100,0)
local Players={GetPlayers=function() return {owner,thief,other} end,PlayerRemoving={Connect=function() end}}
local Debris={AddItem=function() end}
local workspace={GetAttribute=function() return nil end}
local Config={Steal={robCooldown=60,catchGrace=3,shieldSeconds=0,carrierRange=8},Plot={lockSeconds=60,lockPerRebirth=0},
    Stick={range=7,stun=2,cooldown=0.8},Base={itemById={stickWood={color={},burst=10}}}}
local DataService={get=function() return {Rebirths=0} end,playtime=function() return 99999 end}
local plot={Floor={Position=vec(0,0),Size={X=40,Z=40}}}
local PlotService={get=function(p) if p==owner then return plot end end}
local carriers={}
local EggService={carriers=function() return carriers end,isCarrying=function(p) return carriers[p]~=nil end,
    take=function(p) local e=carriers[p];carriers[p]=nil;return e end,attach=function(p,e) carriers[p]=e;return true end}
local given={}
local HatchService={give=function(p,e) table.insert(given,{p,e}) end}
local GuardianService={caughtAt={}}
local stunned={}
local SpeedService={stun=function(p,s) stunned[p]=s end}
local BaseService={equipped=function() return 'stickWood' end}
local toasts={}
local Notify={FireClient=function(_,p,_,msg) table.insert(toasts,{p,msg}) end}
local StealService=''' + steal + r'''

-- thief steals owner's carried egg: robCooldown starts
local egg={biome='Forest'}
carriers[owner]=egg
StealService.stealFromCarrier(thief,owner)
assert(carriers[thief]==egg and egg.stolenFrom==owner,'fixture: thief carries owner egg')
assert(not StealService.canSteal(other,owner),'fixture: robCooldown active')

-- owner outside own plot: no hit
owner.root.Position=vec(30,0);thief.root.Position=vec(33,0)
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'no hit outside your base')

-- thief out of range
now+=1;owner.root.Position=vec(0,0);thief.root.Position=vec(10,0)
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'no hit beyond 7 studs')

-- bystander carrying someone else's stolen egg
now+=1;local other_egg={biome='Lake',stolenFrom=other};carriers[other]=other_egg;other.root.Position=vec(2,0);thief.root.Position=vec(30,0)
assert(StealService.swing(owner)==nil and carriers[other]==other_egg,'whiff on bystander')
carriers[other]=nil;other.root.Position=vec(100,0)

-- thief just outside the plot edge (owner inside) but in range: hit
now+=1;owner.root.Position=vec(17,0);thief.root.Position=vec(22,0)
assert(StealService.swing(owner)==thief,'hit thief in range even past the plot edge')
assert(carriers[thief]==nil and given[1][1]==owner and given[1][2]==egg,'egg back to owner incubator')
assert(stunned[thief]==2,'thief stunned 2s')
assert(StealService.canSteal(thief,owner),'robCooldown cleared after a stick hit')

-- cooldown: re-steal then swing twice within 0.8 s
carriers[thief]=egg
now+=0.5
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'swing cooldown 0.8s')
now+=0.4
assert(StealService.swing(owner)==thief and #given==2,'swing works after cooldown, one give per hit')
print('PASS: stick swing rules (base-only, range, bystander whiff, edge, egg home, stun, cooldown clear, swing cooldown)')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-stick-') as temp:
        for name, source in (('pricing', pricing()), ('swing', swing())):
            script = Path(temp) / f'{name}.luau'
            script.write_text(source, encoding='utf-8')
            subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
```

- [ ] **Step 3: Run it to verify it fails**

Run: `cd steal-a-ride/tests && python -X utf8 run_stick_checks.py --runtime "$TEMP/steal-a-mount-luau-0.741"`
Expected: FAIL in `pricing` with `five stick tiers in order` (or `attempt to call nil` for `Config.basePrice`).

- [ ] **Step 4: Config** — in `Config.Base.slots`, append the Stick slot to the last row:

```lua
		{ id = "statue", title = "Statue" }, { id = "banners", title = "Banners" }, { id = "gate", title = "Gate" },
		{ id = "stick", title = "Stick" },
```

After the `gateGolden` item line, add:

```lua
		-- base stun stick looks (StealService builds the Tool). incomeMinutes = price in minutes of the buyer's income; requires = previous tier
		{ id = "stickWood", slot = "stick", name = "Wooden Stick", price = 0, color = rgb(150, 105, 60), material = "Wood", burst = 10 },
		{ id = "stickIron", slot = "stick", name = "Iron Stick", incomeMinutes = 10, color = rgb(165, 170, 180), material = "Metal", burst = 15 },
		{ id = "stickGold", slot = "stick", name = "Gold Stick", incomeMinutes = 30, requires = "stickIron", color = rgb(255, 200, 60),
			material = "SmoothPlastic", trail = true, burst = 20 },
		{ id = "stickCrystal", slot = "stick", name = "Crystal Stick", incomeMinutes = 60, requires = "stickGold", color = rgb(130, 230, 255),
			material = "Glass", trail = true, burst = 30 },
		{ id = "stickGlitch", slot = "stick", name = "Glitch Stick", incomeMinutes = 120, requires = "stickCrystal", color = rgb(255, 42, 79),
			material = "Neon", trail = true, glitch = true, burst = 45 },
```

After the `Config.Gear = {...}` block, add:

```lua
-- Base stun stick: only inside your own base; hits a carrier of an egg stolen from you (StealService.swing)
Config.Stick = { range = 7, stun = 2, cooldown = 0.8 }

-- Base cosmetic price: fixed, or minutes of income for incomeMinutes items (stick tiers), never below the gear floor
function Config.basePrice(item, income: number): number
	if item.incomeMinutes then
		return math.max(Config.Gear.minPrice, math.floor(item.incomeMinutes * 60 * income))
	end
	return item.price
end
```

- [ ] **Step 5: BaseService** — under `local BaseService = {}` add the hook:

```lua
BaseService.incomeOf = function(_player) return 0 end -- set by Main (CreatureService): income-priced items
```

Replace `BaseService.price`:

```lua
-- Cost to take this item: nil = not for sale (or locked behind `requires`), 0 = owned or free (equip only)
function BaseService.price(data, itemId, income: number?): number?
	local item = Base.itemById[itemId]
	if not item then
		return nil
	end
	if item.price == 0 or data.Base.owned[itemId] then
		return 0
	end
	if item.requires and not data.Base.owned[item.requires] then
		return nil
	end
	return Config.basePrice(item, income or 0)
end
```

In `BaseService.start`, change the two lines:

```lua
			local cost = BaseService.price(data, item.id, BaseService.incomeOf(player))
			return cost, function()
				data.Base.owned[item.id] = item.price ~= 0 or nil
```

- [ ] **Step 6: Main wiring** — next to `GearService.isShielded = StealService.shielded` add:

```lua
BaseService.incomeOf = CreatureService.incomeOf
```

- [ ] **Step 7: Run pricing check** — same command as Step 3. Expected: `PASS: stick tiers, income pricing, floor, requires gate`, then the `swing` script FAILS (`attempt to call a nil value (field 'swing')` or loader `test loader dependency changed`) — that is Task 2.

- [ ] **Step 8: HANDOFF** — record Task 1 done (local only, not installed).

---

### Task 2: StealService stick (tool give/remove, swing, hit FX)

**Files:**
- Modify: `src/ServerScriptService/Services/StealService.luau` (requires L3-10; new code after `insidePlot` ~L144; `tick` loop ~L150)
- Test: `tests/run_stick_checks.py` (swing part from Task 1)

**Interfaces:**
- Consumes: `Config.Stick`, `Config.Base.itemById[id].{name,color,material,trail,glitch,burst}`, `BaseService.equipped(data, "stick")`, `SpeedService.stun(player, seconds)`, `EggService.carriers()/take()`, `HatchService.give(player, egg)`.
- Produces: `StealService.swing(owner): Player?` (returns the hit thief, nil on whiff/refusal).

- [ ] **Step 1: Requires** — after `local Players = game:GetService("Players")` add `local Debris = game:GetService("Debris")`; after the GuardianService require add:

```lua
local SpeedService = require(script.Parent.SpeedService)
local BaseService = require(script.Parent.BaseService)
```

Update the header comment's first line to: `-- PvP: steal eggs from carriers and from unlocked bases (never creatures), take-backs, the base stun stick,`

- [ ] **Step 2: Swing + tool** — directly after the `insidePlot` function, add:

```lua
-- Base stun stick: owners hold it only inside their own plot. A hit on someone carrying an egg stolen from the owner
-- stuns them, sends the egg home and clears the robbed cooldown (they may try again once the stun ends).
local lastSwing = {} -- [owner] = os.clock()

local function hitFx(root, item)
	local burst = Instance.new("ParticleEmitter")
	burst.Color = item.glitch and ColorSequence.new(Color3.fromRGB(255, 42, 79), Color3.fromRGB(37, 232, 255)) or ColorSequence.new(item.color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Speed = NumberRange.new(10, 18)
	burst.Lifetime = NumberRange.new(0.3, 0.5)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Parent = root
	burst:Emit(item.burst)
	Debris:AddItem(burst, 1)
end

function StealService.swing(owner)
	local now = os.clock()
	if now - (lastSwing[owner] or -math.huge) < Config.Stick.cooldown then
		return nil
	end
	lastSwing[owner] = now
	local plot, root = PlotService.get(owner), rootOf(owner)
	local humanoid = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if not plot or not root or not humanoid or humanoid.Health <= 0 or not insidePlot(plot, root.Position) then
		return nil
	end
	local thief, best
	for carrier, egg in EggService.carriers() do
		local r = rootOf(carrier)
		local d = r and (r.Position - root.Position).Magnitude
		if egg.stolenFrom == owner and d and d <= Config.Stick.range and (not best or d < best) then
			thief, best = carrier, d
		end
	end
	if not thief then
		return nil
	end
	local egg = EggService.take(thief)
	HatchService.give(owner, egg)
	SpeedService.stun(thief, Config.Stick.stun)
	robbedAt[owner] = nil
	hitFx(rootOf(thief), Config.Base.itemById[BaseService.equipped(DataService.get(owner), "stick")])
	Notify:FireClient(owner, "toast", "Whacked! Your egg is back home.")
	Notify:FireClient(thief, "toast", owner.DisplayName .. " whacked you! The egg went home.")
	return thief
end

local function buildStick(owner, itemId)
	local item = Config.Base.itemById[itemId]
	local tool = Instance.new("Tool")
	tool.Name = "Stick"
	tool.CanBeDropped = false
	tool.ToolTip = item.name
	tool:SetAttribute("Skin", itemId)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 4.2)
	handle.Color = item.color
	handle.Material = Enum.Material[item.material]
	handle.CanCollide, handle.Massless = false, true
	handle.Parent = tool
	tool.Grip = CFrame.new(0, 0, -1.6) -- held near one end; tune in Play if it looks off
	if item.trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0, 2), Vector3.new(0, 0, 1)
		a0.Parent, a1.Parent = handle, handle
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.Color = item.glitch and ColorSequence.new(Color3.fromRGB(255, 42, 79), Color3.fromRGB(37, 232, 255)) or ColorSequence.new(item.color)
		trail.Parent = handle
	end
	tool.Activated:Connect(function() -- Tool activation replicates to the server: no RemoteEvent needed
		local anim = Instance.new("StringValue")
		anim.Name, anim.Value = "toolanim", "Slash" -- the default Animate script plays a slash
		anim.Parent = tool
		StealService.swing(owner)
	end)
	return tool
end

-- give (auto-equipped) inside your own plot, re-skin on equip change, remove outside
local function syncStick(player, root)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (character and character:FindFirstChild("Stick")) or (backpack and backpack:FindFirstChild("Stick"))
	local plot, data = PlotService.get(player), DataService.get(player)
	local want = root and plot and data and insidePlot(plot, root.Position) and BaseService.equipped(data, "stick")
	if tool and tool:GetAttribute("Skin") ~= want then
		tool:Destroy()
		tool = nil
	end
	if want and not tool then
		buildStick(player, want).Parent = character
	end
end
```

- [ ] **Step 3: Tick** — in `tick()`, inside `for _, player in Players:GetPlayers() do`, right after `local egg = carriers[player]`, add:

```lua
		syncStick(player, root)
```

In `StealService.start`'s `PlayerRemoving` handler change to:

```lua
		robbedAt[player], lockedUntil[player], lastSwing[player] = nil, nil, nil
```

- [ ] **Step 4: Run checks** — `python -X utf8 run_stick_checks.py --runtime "$TEMP/steal-a-mount-luau-0.741"`. Expected: both PASS lines. If the swing harness fails on a missing Roblox global stub, add a `{new=function() return {} end}` stub for it to `PRELUDE` — never weaken an assertion.

- [ ] **Step 5: Regression** — `python -X utf8 run_feedback_checks.py --runtime "$TEMP/steal-a-mount-luau-0.741"` (includes all-source compile). Expected: all groups PASS. If a loader dependency string changed in StealService/BaseService, update that test's replacement map only.

- [ ] **Step 6: HANDOFF** — record Task 2 done (local only).

---

### Task 3: Base panel shows stick prices and locks; client income

**Files:**
- Modify: `src/StarterGui/MainUI/BaseUI.luau` (`refresh` ~L74-100)
- Modify: `src/ServerScriptService/Services/GearService.luau` (price refresh loop ~L128)

**Interfaces:**
- Consumes: `Config.basePrice(item, income)`, item `requires`; player attribute `Income` (new, set by GearService).
- Produces: player attribute `Income: number` (raw income/s, not the boosted HUD rate), refreshed every 2 s.

- [ ] **Step 1: Income attribute** — in GearService's "keep gear prices current" loop, after `player:SetAttribute("GearPrice", GearService.price(player))` add:

```lua
					player:SetAttribute("Income", CreatureService.incomeOf(player)) -- Base panel prices income-scaled stick tiers
```

- [ ] **Step 2: BaseUI refresh** — replace the item loop body's non-owned branch. Full new loop:

```lua
	local income = player:GetAttribute("Income") or 0
	for _, item in Config.Base.items do
		local row = rows[item.id]
		row.Visible = item.slot == current
		local isEquipped = (equipped[item.slot] or defaults[item.slot]) == item.id
		local isOwned = item.price == 0 or owned[item.id]
		local price = Config.basePrice(item, income)
		if isEquipped then
			row.Buy.Text, row.Buy.BackgroundColor3, row.Desc.Text = "Equipped", GREY, item.slot == "stick" and "Whack thieves in your base" or "In your base now"
		elseif isOwned then
			row.Buy.Text, row.Buy.BackgroundColor3, row.Desc.Text = "Equip", BLUE, item.price == 0 and "Free" or "Owned"
		elseif item.requires and not owned[item.requires] then
			row.Buy.Text, row.Buy.BackgroundColor3 = "Locked", GREY
			row.Desc.Text = "Unlock " .. Config.Base.itemById[item.requires].name .. " first"
		else
			row.Buy.Text = "$" .. Format.number(price)
			row.Buy.BackgroundColor3 = cash >= price and GREEN or GREY
			row.Desc.Text = cash >= price and "Yours forever, even after rebirth" or "Need more cash"
		end
	end
```

(Stick items have `color`, so the existing swatch shows each tier's colour.)

- [ ] **Step 3: Compile** — `python -X utf8 run_feedback_checks.py --runtime "$TEMP/steal-a-mount-luau-0.741"` → all PASS; then `run_stick_checks.py` → PASS.

- [ ] **Step 4: HANDOFF** — record Task 3 done (local only).

---

### Task 4: Install in Studio and Play-verify

**Files:** Studio scripts `ReplicatedStorage.Shared.Config`, `ServerScriptService.Main` (+ its `Services` StealService, BaseService, GearService), `StarterGui.MainUI.BaseUI`.

- [ ] **Step 1: Confirm Studio == backup** — for each of the 6 files, compare Studio `#Source` with the backup's UTF-8 byte length (`python -c "print(len(open(p,encoding='utf-8').read().encode()))"`). Any mismatch → stop and report (another agent may have changed Studio).
- [ ] **Step 2: Install** — for each file, `execute_luau` (Edit) that checks `Source == <backup text>` then sets `Source = <new local text>` (long-bracket strings `[=====[ ... ]=====]`; assert the marker isn't in the text). Re-compare byte lengths to local.
- [ ] **Step 3: Play — tool lifecycle** — start Play; on Server: teleport character inside own plot → within 1 s `Character.Stick` exists with `Skin == "stickWood"`; teleport outside → Stick gone from Character and Backpack. Screenshot the held stick; adjust `tool.Grip` if it's held wrong (update local + Studio together).
- [ ] **Step 4: Play — activation reaches server** — on Server connect a temporary listener to `Character.Stick.Activated` that sets an attribute; on Client call `tool:Activate()`; confirm the attribute set and a slash plays. Disconnect/remove the attribute.
- [ ] **Step 5: Play — purchase/reskin** — on Server give test cash via `DataService.addCash`, `ShopService.buy(player, "base:stickGold")` → false (locked); buy `base:stickIron` → true, cash dropped by `Config.basePrice(Iron, incomeOf)`, the held stick re-skins to Iron within 1 s. Open Base panel → Stick tab: Wood "Equip", Iron "Equipped", Gold priced, Crystal/Glitch "Locked". Screenshot. Restore the player's cash/owned items afterwards (or use the test save convention noted in HANDOFF).
- [ ] **Step 6: Key 1 conflict** — in base, press `1` on Client (`user_keyboard_input`): record whether Net Gun still fires / stick toggles. Report result to the user; don't change binding unless it breaks Net Gun.
- [ ] **Step 7: Stop Play, Edit state clean** — no leftover test attributes/instances; Studio sources equal local.
- [ ] **Step 8: HANDOFF + spec** — mark INSTALLED + Play-verified (state what was and wasn't verified: 2-player hit is covered only by the offline harness), note backups `before-stick-20261009/`, and update the spec's "Files touched" to drop the `StickSwing` remote.
