# Top Players Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A wooden Top Players podium board at the Plaza's centre back that shows the current server's top 3 (rebirths > index > income) as real 3D avatar figures with name, rebirth title, index count and income; the three leaderboards restyled to match; "Squire" title for 0-1 rebirths.

**Architecture:** Map parts come from a rerunnable edit-time build tool (`BuildTopPlayers`, same pattern as `BuildPlaza`); a new `TopPlayersService` ranks players with a pure `rank()` (unit-tested), draws the card text and stands `CreateHumanoidModelFromUserId` figures on the card ledges. `Config.rebirthTitle` gains Squire; `PlazaService` gets the dark-wood list panel.

**Tech Stack:** Roblox Luau (Studio via Roblox_Studio MCP: `execute_luau`, `multi_edit`, `start_stop_play`, `screen_capture`), Python test runners driving the standalone `luau` runtime (`$env:TEMP/steal-a-mount-luau-0.741`).

**Spec:** `steal-a-ride/docs/superpowers/specs/2026-10-09-top-players-board-design.md`

## Global Constraints

- Current server only: no DataStore, no cross-server data for this board.
- Rank: most rebirths, then larger creature index (count of `data.Index` keys), then higher income per second, then join order.
- Podium order left to right: #2, #1, #3; #1 taller and raised; badges gold 1, silver 2, bronze 3.
- Card rows: display name, rebirth title, `Index N`, income as `$` .. `Format.number(income)` .. `/s`.
- Fewer than 3 players: missing cards read "Waiting for a challenger", no figure.
- `Config.rebirthTitle(0) == Config.rebirthTitle(1) == "Squire"`; titles from 2 rebirths unchanged.
- Style B wooden notice board; text font `Enum.Font.FredokaOne`; everything faces the arch (-Z).
- Board centre (0, 211); leaderboards stay at x -30 / 30 / 60, z 211. Index stall to (-58, 198): the spec's "about (-62, 205)" would put its 14-stud base into the decor pine at (-72, 206), so it moves 4 studs in and 7 forward, still in the back-left corner.
- Spawn keeps facing the arch; its pad becomes invisible (Transparency 1), never deleted.
- What's New: v1-v4 are published and frozen; add `version = 5`.
- Project rule: no git commits unless the user asks; checkpoints go in `HANDOFF.md` (AGENTS.md). UI work: read `C:/Users/Desktop/.codex/skills/impeccable/SKILL.md` and its `references/design-craft.md` before Task 4.
- Studio and local must end byte-identical (LF-normalised djb2 signatures); install changed scripts with targeted `multi_edit` hunks, create new scripts with `multi_edit` + `className`.
- Run all 7 test runners after each code task (PowerShell, from the project root):
  `foreach ($t in Get-ChildItem steal-a-ride/tests/run_*.py) { python -X utf8 $t.FullName --runtime "$env:TEMP/steal-a-mount-luau-0.741" }`

## Review Focus

1. **Avatar load fails or is slow** (`CreateHumanoidModelFromUserId` errors or yields seconds): expect the card text to show at once, no figure, a retry after `Config.TopPlayers.retry` seconds, and no duplicate figures if refreshes overlap. Pinned in Task 3 (a `building[userId]` guard + `retryAt`) and Task 5 Play check 3.
2. **A top player leaves while their figure is still being built**: expect the late figure to be destroyed, not parked on a ledge. Pinned in Task 3 (`place()` re-checks the current top before parenting) and Task 5 Play check 4.
3. **Huge avatars** (tall packages, big accessories): expect the figure scaled down to fit the card's figure zone. Pinned in Task 3 (`ScaleTo(math.min(1, maxH / size.Y))`) and Task 5 Play check 3 (measure the figure's box).
4. **Player whose data has not loaded**: expect them skipped until it loads. Pinned in Task 3 (`entries()` skips `DataService.get(player) == nil`) and Task 2 test (rank of an empty list).
5. **Squire breaking existing title code**: rank-up toast must not fire at rebirth 1, base sign and rebirth menu read "Squire" / "next: Lesser Lord in 2". Pinned in Task 1 tests (existing rebirth harness toast asserts still pass + new asserts).

---

### Task 1: Squire title for 0-1 rebirths

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`Config.rebirthTitle`, its comment)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`rebirth_harness`, line with `Config.rebirthTitle(0)==nil`)

**Interfaces:**
- Produces: `Config.rebirthTitle(n: number): string` (never nil; "Squire" below 2). Used by Task 2 `cardText` and Task 4 Most Rebirths rows.

- [ ] **Step 0: Back up and confirm Studio matches local**

Copy `src/ReplicatedStorage/Shared/Config.luau`, `src/ServerScriptService/Services/PlazaService.luau`, `src/ServerScriptService/Main.luau` and `tests/run_feedback_checks.py` into a new `steal-a-ride/before-top-players-20261009/` (same relative layout). In Studio (Edit) compute the signatures of Config, PlazaService and Main and compare with these copies; if any differs, stop and report (someone changed Studio).

- [ ] **Step 1: Write the failing test**

In `rebirth_harness` replace

```lua
assert(Config.rebirthTitle(0)==nil and Config.rebirthTitle(1)==nil and Config.rebirthTitle(2)=="Lesser Lord" and Config.rebirthTitle(3)=="Lesser Lord"
```

with

```lua
assert(Config.rebirthTitle(0)=="Squire" and Config.rebirthTitle(1)=="Squire" and Config.rebirthTitle(2)=="Lesser Lord" and Config.rebirthTitle(3)=="Lesser Lord"
```

- [ ] **Step 2: Run it, expect failure**

Run the feedback runner only: `python -X utf8 steal-a-ride/tests/run_feedback_checks.py --runtime "$env:TEMP/steal-a-mount-luau-0.741"`
Expected: FAIL with `a title every 2 rebirths`.

- [ ] **Step 3: Implement**

Replace in `Config.luau`

```lua
-- a Lordship title every 2 rebirths (menu, rank-up toast, Top Rebirths board, base sign)
Config.RebirthTitles = { "Lesser Lord", "Iron Lord", "Silver Lord", "Golden Lord", "Platinum Lord",
	"Emerald Lord", "Royal Lord", "Mythic Lord", "Celestial Lord", "Divine Overlord" }
function Config.rebirthTitle(n: number): string?
	return Config.RebirthTitles[math.min(n // 2, #Config.RebirthTitles)]
end
```

with

```lua
-- a Lordship title every 2 rebirths (menu, rank-up toast, leaderboards, base sign); Squire before the first one
Config.RebirthTitles = { "Lesser Lord", "Iron Lord", "Silver Lord", "Golden Lord", "Platinum Lord",
	"Emerald Lord", "Royal Lord", "Mythic Lord", "Celestial Lord", "Divine Overlord" }
function Config.rebirthTitle(n: number): string
	return n < 2 and "Squire" or Config.RebirthTitles[math.min(n // 2, #Config.RebirthTitles)]
end
```

Callers (read, no change needed): `RebirthService.luau:118` toast fires only when the title changes (1 vs 0 are both Squire: no toast; 2 is Lesser Lord: toast), `RebirthUI.luau:65` shows "Title: Squire  ·  next: Lesser Lord in 2", `PlotService.luau:18` sign second line "Squire", `PlazaService.luau:287` (Task 4 rewrites this format).

- [ ] **Step 4: Run all 7 runners, expect pass**

Expected: all exit 0; the rebirth harness's existing toast asserts ("rebirth 2: first title", "rebirth 3 keeps the same title") still pass.

- [ ] **Step 5: Checkpoint** — `HANDOFF.md`: Squire done locally, not installed.

---

### Task 2: TopPlayersService pure ranking and card text

**Files:**
- Create: `steal-a-ride/src/ServerScriptService/Services/TopPlayersService.luau`
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (add `Config.TopPlayers` after `Config.Plaza`)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (new `top_players_harness`, registered in `main()`)

**Interfaces:**
- Consumes: `Config.rebirthTitle` (Task 1), `Format.number`.
- Produces (used by Task 3):
  - `TopPlayersService.rank(entries: {Entry}): {Entry}` — Entry = `{ key: any, rebirths: number, index: number, income: number, order: number }` plus any extra fields; returns a new list of at most 3, best first; never reorders the input.
  - `TopPlayersService.indexCount(index: {[string]: boolean}?): number`
  - `TopPlayersService.cardText(e: { name: string, rebirths: number, index: number, income: number }): { name: string, title: string, index: string, income: string }`
  - `Config.TopPlayers = { refresh = 3, retry = 30, waiting = "Waiting for a challenger" }`

- [ ] **Step 1: Write the failing test**

Add to `run_feedback_checks.py` after `plaza_harness`:

```python
def top_players_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    fmt=module("ReplicatedStorage/Shared/Format.luau",{})
    mod=module("ServerScriptService/Services/TopPlayersService.luau",{
        'local Players = game:GetService("Players")':'local Players = {}',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'local ReplicatedStorage = {}',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local Format = require(ReplicatedStorage.Shared.Format)':'',
        'local DataService = require(script.Parent.DataService)':'local DataService = {}',
        'local CreatureService = require(script.Parent.CreatureService)':'local CreatureService = {}'})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
"""
    checks=r"""
local T=TopPlayersService
local function e(key,r,i,inc,o) return {key=key,rebirths=r,index=i,income=inc,order=o} end
local top=T.rank({e("a",2,10,5,1),e("b",5,1,1,2),e("c",2,30,1,3),e("d",0,99,999,4)})
assert(#top==3 and top[1].key=="b" and top[2].key=="c" and top[3].key=="a","rebirths first, then index; only 3 shown")
top=T.rank({e("a",1,5,10,1),e("b",1,5,20,2)})
assert(#top==2 and top[1].key=="b" and top[2].key=="a","same rebirths and index: higher income first; 2 players fill 2 cards")
top=T.rank({e("a",1,5,10,2),e("b",1,5,10,1)})
assert(top[1].key=="b","full tie: whoever joined first")
assert(#T.rank({})==0,"empty server: nobody on the board")
local input={e("a",1,1,1,1),e("b",2,1,1,2)}
T.rank(input)
assert(input[1].key=="a","rank never reorders the caller's list")
assert(T.indexCount({Fox_Rare=true,Fox_Epic=true,Chick_Common=true})==3 and T.indexCount(nil)==0,"index count = discovered species+rarity combos")
local t=T.cardText({name="KuroZen",rebirths=20,index=318,income=126400000})
assert(t.name=="KuroZen" and t.title=="Divine Overlord" and t.index=="Index 318" and t.income=="$126.40M/s","card rows: name, title, index, income")
assert(T.cardText({name="New",rebirths=1,index=0,income=0}).title=="Squire","0-1 rebirths: Squire")
assert(Config.TopPlayers.refresh==3 and Config.TopPlayers.retry==30 and Config.TopPlayers.waiting=="Waiting for a challenger","board settings")
print("PASS: Top Players rank (rebirths > index > income > join order, top 3), index count, card text")
"""
    return pre+"local Config="+cfg+"\nlocal Format="+fmt+"\nlocal TopPlayersService="+mod+checks
```

In `main()` add `top_players_harness` to the `for extra in (...)` tuple right after `plaza_harness`.

- [ ] **Step 2: Run it, expect failure**

Run the feedback runner. Expected: FAIL, Python `FileNotFoundError` for `TopPlayersService.luau` (the module doesn't exist yet).

- [ ] **Step 3: Implement**

Add after `Config.Plaza = {...}` in `Config.luau`:

```lua
-- Top Players board (Plaza centre): this server's best 3, refreshed every `refresh` s; a failed avatar load retries after `retry` s
Config.TopPlayers = { refresh = 3, retry = 30, waiting = "Waiting for a challenger" }
```

Create `TopPlayersService.luau` (runtime parts are added in Task 3):

```lua
-- Top Players board (Plaza centre back): the 3 best players in this server by rebirths, then creature index, then
-- income. The board is map parts (ServerStorage.BuildTools.BuildTopPlayers); this service writes each card and stands
-- the player's own avatar on their card's ledge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)

local TopPlayersService = {}

-- entries: { key, rebirths, index, income, order }; returns a new list of the best 3, best first
function TopPlayersService.rank(entries)
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.rebirths ~= b.rebirths then return a.rebirths > b.rebirths end
		if a.index ~= b.index then return a.index > b.index end
		if a.income ~= b.income then return a.income > b.income end
		return a.order < b.order
	end)
	local top = {}
	for i = 1, math.min(3, #list) do
		top[i] = list[i]
	end
	return top
end

-- discovered species + rarity combos (keys of data.Index)
function TopPlayersService.indexCount(index): number
	local n = 0
	for _ in index or {} do
		n += 1
	end
	return n
end

function TopPlayersService.cardText(e)
	return { name = e.name, title = Config.rebirthTitle(e.rebirths), index = "Index " .. e.index,
		income = "$" .. Format.number(e.income) .. "/s" }
end

return TopPlayersService
```

- [ ] **Step 4: Run all 7 runners, expect pass**

Expected: all exit 0; feedback prints the new PASS line and `compiled 62 Luau sources`.

- [ ] **Step 5: Checkpoint** — `HANDOFF.md`.

---

### Task 3: TopPlayersService runtime: cards, figures, refresh loop

**Files:**
- Modify: `steal-a-ride/src/ServerScriptService/Services/TopPlayersService.luau` (add runtime above `return`)
- Modify: `steal-a-ride/src/ServerScriptService/Main.luau` (require + start)

**Interfaces:**
- Consumes: Task 2 functions; map parts from Task 4: `workspace.Plaza.TopPlayers` with `Card1..3` (Part, front face toward -Z, Card1 = #1) and `Ledge1..3` (Part; figure stands on its top face).
- Produces: `TopPlayersService.start()`; attribute-free.

- [ ] **Step 1: Add the runtime**

Insert before `return TopPlayersService`:

```lua
local T = Config.TopPlayers
local rgb = Color3.fromRGB
local MEDAL = { rgb(255, 205, 80), rgb(205, 212, 225), rgb(214, 135, 80) }
local MEDAL_TEXT = { rgb(70, 45, 5), rgb(40, 44, 55), rgb(60, 28, 10) }
local cards = {} -- [rank] = { part, ledge, badge, name, title, index, income, waiting }
local figures = {} -- [userId] = Model (placed or parked)
local building, retryAt = {}, {} -- [userId] = true while CreateHumanoidModelFromUserId runs / os.clock() of next try
local joined, joinCount = {}, 0
local current = {} -- [rank] = userId on the board

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3 = 1, Enum.Font.FredokaOne, true, rgb(255, 255, 255)
	for k, v in props do t[k] = v end
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(30, 18, 10), 2
	stroke.Parent = t
	t.Parent = parent
	return t
end

-- card face (fractions from the top): badge 0-0.14, figure zone 0.14-0.58 (the ledge top sits at 0.58), then name,
-- title, index, income rows
local function buildCard(rank, part, ledge)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "Card", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.LightInfluence, gui.MaxDistance = 0, 150
	gui.Parent = part
	local badge = Instance.new("Frame")
	badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.26, 0.11)
	badge.BackgroundColor3 = MEDAL[rank]
	badge.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(rank), TextColor3 = MEDAL_TEXT[rank] })
	local function row(y, h, color)
		return label(gui, { Position = UDim2.fromScale(0.06, y), Size = UDim2.fromScale(0.88, h), Text = "", TextColor3 = color })
	end
	cards[rank] = {
		part = part, ledge = ledge,
		waiting = row(0.3, 0.12, rgb(190, 170, 150)),
		name = row(0.6, 0.085, MEDAL[rank]),
		title = row(0.705, 0.075, rgb(205, 190, 255)),
		index = row(0.8, 0.075, rgb(245, 235, 220)),
		income = row(0.895, 0.075, rgb(255, 225, 140)),
	}
end

local function setText(card, text)
	card.waiting.Text = text and "" or T.waiting
	card.name.Text = text and text.name or ""
	card.title.Text = text and text.title or ""
	card.index.Text = text and text.index or ""
	card.income.Text = text and text.income or ""
end

local function onBoard(userId)
	return table.find(current, userId) ~= nil
end

-- stand the figure on its card's ledge (scaled to the figure zone) or park it in ServerStorage
local function place(userId)
	local fig = figures[userId]
	if not fig then return end
	local rank = table.find(current, userId)
	if not rank then
		fig:Destroy()
		figures[userId] = nil
		return
	end
	local card = cards[rank]
	local maxH = card.part.Size.Y * 0.44
	fig:ScaleTo(1)
	local _, size = fig:GetBoundingBox()
	fig:ScaleTo(math.min(1, maxH / size.Y))
	local box, scaled = fig:GetBoundingBox()
	local pivotToBottom = fig:GetPivot().Position.Y - (box.Position.Y - scaled.Y / 2)
	local top = card.ledge.Position + Vector3.new(0, card.ledge.Size.Y / 2, 0)
	fig:PivotTo(CFrame.new(top.X, top.Y + pivotToBottom, top.Z)) -- default orientation looks -Z, at the arch
	fig.Parent = workspace.Plaza.TopPlayers
end

local function build(player)
	local userId = player.UserId
	if figures[userId] or building[userId] or os.clock() < (retryAt[userId] or 0) then return end
	building[userId] = true
	task.spawn(function()
		local ok, fig = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
		building[userId] = nil
		if not ok or not fig then
			retryAt[userId] = os.clock() + T.retry
			return
		end
		fig.Name = "Figure_" .. userId
		for _, d in fig:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
			end
		end
		local hum = fig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = hum
			fig.HumanoidRootPart.Anchored = true
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://507766666" -- Roblox's default R15 idle (as the shopkeepers)
			local idle = animator:LoadAnimation(anim)
			idle.Looped = true
			idle:Play()
		else
			fig.PrimaryPart.Anchored = true
		end
		figures[userId] = fig
		place(userId) -- destroys it if the player dropped off the board while it was building
	end)
end

local function entries()
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			table.insert(list, { key = player, name = player.DisplayName, rebirths = data.Rebirths or 0,
				index = TopPlayersService.indexCount(data.Index), income = CreatureService.incomeOf(player),
				order = joined[player] or math.huge })
		end
	end
	return list
end

function TopPlayersService.refresh()
	if #cards < 3 then return end
	local top = TopPlayersService.rank(entries())
	local was = current
	current = {}
	for rank = 1, 3 do
		local e = top[rank]
		current[rank] = e and e.key.UserId
		setText(cards[rank], e and TopPlayersService.cardText(e))
	end
	for _, userId in was do
		if not onBoard(userId) and figures[userId] then
			figures[userId]:Destroy()
			figures[userId] = nil
		end
	end
	for rank = 1, 3 do
		local e = top[rank]
		if e then
			if figures[e.key.UserId] then
				if was[rank] ~= e.key.UserId then place(e.key.UserId) end
			else
				build(e.key)
			end
		end
	end
end

function TopPlayersService.start()
	local board = workspace:WaitForChild("Plaza"):WaitForChild("TopPlayers", 30)
	if not board then
		warn("TopPlayersService: workspace.Plaza.TopPlayers is missing (run ServerStorage.BuildTools.BuildTopPlayers)")
		return
	end
	for rank = 1, 3 do
		buildCard(rank, board:WaitForChild("Card" .. rank), board:WaitForChild("Ledge" .. rank))
	end
	local function join(player)
		joinCount += 1
		joined[player] = joinCount
	end
	for _, player in Players:GetPlayers() do join(player) end
	Players.PlayerAdded:Connect(function(player)
		join(player)
		TopPlayersService.refresh()
	end)
	Players.PlayerRemoving:Connect(function(player)
		joined[player], retryAt[player.UserId] = nil, nil
		task.defer(TopPlayersService.refresh) -- after the player is gone from GetPlayers
	end)
	task.spawn(function()
		while true do
			TopPlayersService.refresh()
			task.wait(T.refresh)
		end
	end)
end
```

Note `place()` re-reads `current`, so a figure finished after its player left the board is destroyed (Review Focus 2); `building[userId]` stops overlapping refreshes from building twice (Review Focus 1).

- [ ] **Step 2: Wire it into Main**

In `Main.luau` add after `local FriendService = require(Services.FriendService)`:

```lua
local TopPlayersService = require(Services.TopPlayersService)
```

and after `PlazaService.start()`:

```lua
TopPlayersService.start()
```

- [ ] **Step 3: Run all 7 runners, expect pass**

Expected: all exit 0 (compile covers the runtime; Task 2 tests still pass because the harness never calls `start`).

- [ ] **Step 4: Checkpoint** — `HANDOFF.md`.

---

### Task 4: Board build tool, leaderboard restyle, Index stall move, spawn pad

**Files:**
- Create: `steal-a-ride/src/ServerStorage/BuildTools/BuildTopPlayers.luau`
- Modify: `steal-a-ride/src/ServerScriptService/Services/PlazaService.luau` (`buildBoard` colours, Most Rebirths `format`, new pure `PlazaService.rebirthText`)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`plaza_harness`)

**Interfaces:**
- Produces: `workspace.Plaza.TopPlayers` with parts `Card1..3`, `Ledge1..3` (consumed by Task 3); `PlazaService.rebirthText(v: number): string`.

- [ ] **Step 0: Read the UI guidance** — `C:/Users/Desktop/.codex/skills/impeccable/SKILL.md` and `references/design-craft.md` (AGENTS.md rule). Keep the user's approved choices (style B, podium, colours below).

- [ ] **Step 1: Write the failing test**

In `plaza_harness` checks, before the final `print`, add:

```lua
assert(PlazaService.rebirthText(12)=="12 · Emerald Lord" and PlazaService.rebirthText(1)=="1 · Squire","Most Rebirths rows: count and title")
```

and change the print to `print("PASS: Plaza showcase picks rarest per owner then fills; chest pays 10 min of income (min $1000) every 4 h; rebirth rows with titles")`.

The harness stubs `Format` as `{}`; change that replacement to load the real module:

```python
        'local Format = require(ReplicatedStorage.Shared.Format)':'local Format = ' + module("ReplicatedStorage/Shared/Format.luau",{}),
```

- [ ] **Step 2: Run, expect failure** — feedback runner fails with `attempt to call a nil value` (rebirthText missing).

- [ ] **Step 3: PlazaService changes**

Add after `PlazaService.chestReward`:

```lua
-- Most Rebirths rows: "12 · Emerald Lord"
function PlazaService.rebirthText(v: number): string
	return Format.number(v) .. " · " .. Config.rebirthTitle(v)
end
```

Replace the Most Rebirths `format = function(v) ... end` block with `format = PlazaService.rebirthText`.

In `buildBoard` change the panel and default row colours to the wooden style:

```lua
	frame.Size, frame.BackgroundColor3 = UDim2.fromScale(1, 1), rgb(52, 34, 22)
```

```lua
			TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = MEDALS[i] or rgb(240, 228, 210) })
```

and in `label` change the stroke colour to `rgb(30, 18, 10)`.

- [ ] **Step 4: Run all 7 runners, expect pass.**

- [ ] **Step 5: Create the build tool**

```lua
-- Edit-time tool (not used at runtime): the Top Players board at the Plaza's centre back (wooden notice board, three
-- podium cards with ledges for the avatars, crown, lanterns), the same wooden frame on the three leaderboards, the
-- Index stall moved to the back-left corner, and the spawn pad hidden (the spawn itself stays).
--   require(game.ServerStorage.BuildTools.BuildTopPlayers)()
-- Rerunning rebuilds the board and re-applies the rest. TopPlayersService fills the cards and stands the figures.
local rgb = Color3.fromRGB
local FLOOR = 0.4 -- top of Plaza.Floor
local WOOD, DARKWOOD, PANEL, DARK = rgb(120, 78, 44), rgb(70, 45, 26), rgb(48, 32, 22), rgb(40, 40, 55)
local GOLD = rgb(255, 205, 80)
local X, Z = 0, 211 -- board centre; its front faces the arch (-Z)
local INDEX_X, INDEX_Z = -58, 198 -- Index stall's new base centre
-- podium: rank -> card centre x, width, height (bottoms aligned; #1 taller)
local CARDS = { { x = 0, w = 9, h = 14.2 }, { x = -9.8, w = 8.6, h = 13 }, { x = 9.8, w = 8.6, h = 13 } }
local FRAMES = { { GOLD, Enum.Material.Neon }, { rgb(200, 205, 215), Enum.Material.Metal }, { rgb(196, 120, 70), Enum.Material.Metal } }
local CARD_BOTTOM = FLOOR + 3.4

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cframe, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end

local function plankText(target, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0
	gui.Parent = target
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3, t.Text = UDim2.fromScale(1, 1), 1, Enum.Font.FredokaOne, true, GOLD, text
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(60, 35, 10), 3
	stroke.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.Parent = t
end

return function()
	local plaza = workspace.Plaza
	local old = plaza:FindFirstChild("TopPlayers")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "TopPlayers"
	m.Parent = plaza

	-- frame: back panel, posts, top beam, header plank, crown
	part(m, "Back", Vector3.new(30, 18, 0.8), CFrame.new(X, FLOOR + 2.5 + 9, Z), DARKWOOD, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		part(m, "Post", Vector3.new(1.4, 22.6, 1.4), CFrame.new(X + s * 15.7, FLOOR + 11.3, Z), WOOD, Enum.Material.Wood)
	end
	part(m, "Beam", Vector3.new(36, 1.2, 1.6), CFrame.new(X, FLOOR + 22, Z), WOOD, Enum.Material.Wood)
	plankText(part(m, "Header", Vector3.new(20, 3.2, 0.6), CFrame.new(X, FLOOR + 19.8, Z - 0.7), WOOD, Enum.Material.Wood), "TOP PLAYERS")
	part(m, "CrownBase", Vector3.new(4, 0.8, 0.5), CFrame.new(X, FLOOR + 23, Z - 0.6), GOLD, Enum.Material.Neon)
	for i, dx in { -1.6, 0, 1.6 } do
		local h = i == 2 and 1.8 or 1.4
		part(m, "CrownSpike", Vector3.new(0.8, h, 0.5), CFrame.new(X + dx, FLOOR + 23.4 + h / 2, Z - 0.6), GOLD, Enum.Material.Neon)
	end
	-- lanterns hanging off the beam ends
	for _, s in { -1, 1 } do
		part(m, "Chain", Vector3.new(0.2, 1.5, 0.2), CFrame.new(X + s * 17.4, FLOOR + 20.65, Z), DARK, Enum.Material.Metal)
		local lantern = part(m, "Lantern", Vector3.new(1.3, 1.8, 1.3), CFrame.new(X + s * 17.4, FLOOR + 19, Z), rgb(255, 190, 110), Enum.Material.Neon,
			{ CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 16, 1.5, rgb(255, 200, 130)
		light.Parent = lantern
	end
	-- podium cards (Card1 = #1 in the centre) with metal frames and a ledge for each figure
	for rank, c in CARDS do
		local y = CARD_BOTTOM + c.h / 2
		part(m, "Frame" .. rank, Vector3.new(c.w + 0.6, c.h + 0.6, 0.3), CFrame.new(c.x, y, Z - 0.5), FRAMES[rank][1], FRAMES[rank][2])
		part(m, "Card" .. rank, Vector3.new(c.w, c.h, 0.2), CFrame.new(c.x, y, Z - 0.75), PANEL)
		local ledgeTop = CARD_BOTTOM + c.h * 0.42
		part(m, "Ledge" .. rank, Vector3.new(4.2, 0.6, 2.6), CFrame.new(c.x, ledgeTop - 0.3, Z - 2.1), WOOD, Enum.Material.Wood)
	end

	-- leaderboards: same wood instead of the neon gold frame and dark posts, plus a cap plank
	for _, board in plaza.Leaderboards:GetChildren() do
		board.Frame.Color, board.Frame.Material = WOOD, Enum.Material.Wood
		for _, p in board:GetChildren() do
			if p.Name == "Post" then
				p.Color, p.Material = WOOD, Enum.Material.Wood
			elseif p.Name == "Cap" then
				p:Destroy()
			end
		end
		board.Screen.Color = PANEL
		local s = board.Screen
		part(board, "Cap", Vector3.new(18, 1, 1.4), CFrame.new(s.Position.X, s.Position.Y + s.Size.Y / 2 + 0.9, s.Position.Z + 0.2), WOOD, Enum.Material.Wood)
	end

	-- Index stall (counter, keeper, books, prompt) to the back-left corner, still facing the arch
	local index = plaza.IndexBoard
	local base = index.Base.Position
	index:PivotTo(index:GetPivot() + Vector3.new(INDEX_X - base.X, 0, INDEX_Z - base.Z))

	-- spawn: keeps working and facing the arch; only the yellow pad disappears
	local spawn = plaza.SpawnLocation
	spawn.Transparency = 1
	for _, d in spawn:GetDescendants() do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
	end
	return "Top Players board built; leaderboards restyled; Index stall moved; spawn pad hidden"
end
```

- [ ] **Step 6: Run all 7 runners** — expect exit 0 (`compiled 63 Luau sources`).

- [ ] **Step 7: Checkpoint** — `HANDOFF.md`.

---

### Task 5: What's New v5, Studio install, build, Play checks

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`Config.WhatsNew`)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`whats_new_harness` latest-version assert)

- [ ] **Step 1: Failing test** — replace

```lua
assert(v==4 and W[#W].title=="Relentless guardians","latest update is v4 Relentless guardians")
```

with

```lua
assert(v==5 and W[#W].title=="Top players","latest update is v5 Top players")
```

Run feedback runner: expected FAIL `latest update is v5 Top players`.

- [ ] **Step 2: Add v5** after the v4 entry (before the closing `}` of `Config.WhatsNew`):

```lua
	{
		version = 5,
		title = "Top players",
		lines = {
			"A new <b>Top Players</b> board in the Plaza shows this server's best three, in their own outfits",
			"New players are now <b>Squires</b> until their first title at 2 rebirths",
			"The Plaza leaderboards have a fresh wooden look",
		},
	},
```

Run all 7 runners: expected all exit 0.

- [ ] **Step 3: Install in Studio** (Studio "Steal a Mount"; open it with `Start-Process "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:123937616497204+universeId:10769659624"` if `list_roblox_studios` doesn't show it). In Edit mode:
  1. Compute Studio signatures (djb2 of LF-normalised `Source`, trailing newlines stripped) of Config, PlazaService and Main; they must still equal the copies in `steal-a-ride/before-top-players-20261009/` (Task 1 Step 0). If not, stop and report.
  2. Back up Config, PlazaService, Main into `ServerStorage.TopPlayersBackup20261009` (Clone).
  3. Apply the local diffs as targeted `multi_edit` hunks (generate old/new pairs from `difflib` against the backups, verify locally that applying them reproduces the files exactly).
  4. Create `ServerScriptService.Services.TopPlayersService` and `ServerStorage.BuildTools.BuildTopPlayers` with `multi_edit` (`className: "ModuleScript"`, first edit `old_string: ""` = full file).
  5. Verify Studio == local signatures for all 5.
  6. Run the build tool on a fresh clone so no cached module is reused:
     `local c = game.ServerStorage.BuildTools.BuildTopPlayers:Clone(); c.Parent = game.ServerStorage; local r = require(c)(); c:Destroy(); return r`
     Expected: `Top Players board built; leaderboards restyled; Index stall moved; spawn pad hidden`.

- [ ] **Step 4: Edit-mode screenshots** — `screen_capture` with `camera_position` (0, 12, 175) `look_at_position` (0, 11, 211) (front of the board), and (-40, 14, 170) → (-58, 5, 198) (Index stall), and (20, 10, 185) → (30, 8, 211) (restyled board). Send them to the user with `SendUserFile`. Check: no part overlaps (cards vs header, lanterns vs posts, Index stall vs pine/Fuse), spawn pad invisible.

- [ ] **Step 5: Play checks** (start Play; server `ServerStorage.TestHooks:Invoke("fakeStore")` after the player's data loads):
  1. Solo: Card1 shows the player's name, title, `Index N`, income; Card2 and Card3 read "Waiting for a challenger" and have no figure.
  2. `TestHooks:Invoke("set", "Rebirths", 12)` → within 3 s Card1 title reads "Emerald Lord".
  3. A figure `Figure_<userId>` appears on `Ledge1` within ~5 s: log its bounding box height (<= Card1 height x 0.44 + 0.05) and that its bottom sits on the ledge top (±0.1); every BasePart has CanCollide false; the idle animation plays (Animator has a playing track).
  4. Stop Play right after Play start once (figure still building) and once normally: no errors in `get_console_output` from TopPlayersService.
  5. Rebirth menu shows "Title: Squire · next: Lesser Lord in 2" for a player set to `Rebirths` 0; base sign shows "Squire" as its second line.
  6. Client screenshot at phone size (resize the Studio Play window is not available: instead `screen_capture` from 25 studs in front of the board at the height of a standing character): names and rows readable.
  Restore nothing (fake store). Stop Play.

- [ ] **Step 6: Checkpoint** — `HANDOFF.md`: installed + build run + Play results (each check pass/fail with numbers), not published.

---

### Task 6: Final verification and handoff

- [ ] **Step 1: Full Studio/local signature sweep** of every script (exclude backup folders): expect 63 equal, 0 differences (Studio-only check scripts listed separately).
- [ ] **Step 2: Console check** after one more Play start/stop: no new errors.
- [ ] **Step 3: Update `HANDOFF.md`**: one final entry (files changed, Studio backups `ServerStorage.TopPlayersBackup20261009` + `steal-a-ride/before-top-players-20261009/`, map changes from BuildTopPlayers (board, leaderboard frames, Index stall at (-58,198), spawn pad hidden), Play results, NOT published). Tell the user it is ready to publish (map changes live in the place file, so publishing from Studio is required).
