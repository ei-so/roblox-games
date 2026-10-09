# Relentless Guardians (Leash Chase) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the burst/winded/surge chase with a two-phase leash chase (snap to X behind + constant rage once the carrier leaves the guardian's biome), retune egg weights so speed decides, and ship the related copy.

**Architecture:** All chase logic stays in `GuardianService.luau`; the new rules live in small pure helpers (`leashOffset`, `inPhase2`, `pickTarget`, `chaseFactor`) that the Luau test harness exercises directly, and `step()` wires them up. The client only adds a snap effect in `Effects.luau`. Numbers come from a new pacing-sim script and are approved by the user before any game file changes.

**Tech Stack:** Roblox Luau (Studio via Roblox_Studio MCP), Python test runners driving the standalone `luau` runtime (`$env:TEMP/steal-a-mount-luau-0.741`), Python pacing sim in `steal-a-ride/tools/pacing-sim`.

**Spec:** `steal-a-ride/docs/superpowers/specs/2026-10-09-guardian-leash-design.md`

## Global Constraints

- Applies to every guardian except the Forest Chicken (`Config.Biomes[1]`), which keeps a plain chase: no leash, no rage.
- Phase 2 starts when the TARGET is outside the guardian's own biome; chase ends only at the safe line or a catch.
- X = `Config.Guardian.catchRadius + g.radius + Config.Guardian.leashBuffer`, `leashBuffer = 15` (sim may change it, user approves).
- Phase 2: full speed, no tiredness, no Blood Moon boost, no lunge (see Review Focus 1). Phase 1: as today minus burst/winded/surge.
- Escape patches never end a chase: the guardian holds (no advance, no catch) while the target stands on a usable one.
- Lock-on: keep the current target until its chase ends; then nearest remaining carrier.
- Snap = instant teleport + signature puff (its `Config.GuardianFX` step burst) at both ends + a short whoosh.
- Egg weights: typical first-attempt rider x weight ≈ guardian speed x 1.05; Secret weight lets top riders win. Guardian/mount/saddle speeds unchanged.
- Speed Soda +10% for 20 s; player-facing text never shows a percentage: "Speed Boost for 20s".
- What's New: v1/v2 published and frozen; v3 unpublished (may be edited); new v4 "Relentless guardians".
- Studio and local must end byte-identical (LF-normalised djb2 signatures); install with targeted `multi_edit`, never whole-file overwrites.
- Project rule: no git commits unless the user asks; checkpoints go in `HANDOFF.md` (AGENTS.md).
- Run all 7 test runners after each code task:
  `foreach ($t in Get-ChildItem steal-a-ride/tests/run_*.py) { python -X utf8 $t.FullName --runtime "$env:TEMP/steal-a-mount-luau-0.741" }` (PowerShell, from the project root).

## Review Focus

1. **Lunge at leash distance**: the guardian lunges within `lungeRange (15) + g.radius`, which equals the leash distance; with lunge on in phase 2 every leashed rider is caught. Expect: no lunge in phase 2. Pinned in Task 3 (`chaseTarget` gets `raging` and skips the lunge) and Task 4's Play check.
2. **Target in a gap between biomes** (20-stud strips belong to no biome, `biomeAt` returns nil): expect phase 2 (the target has left the guardian's biome). Pinned in Task 2 test (`inPhase2(false, "Lake", nil) == true`).
3. **Guardian exactly on top of the target / zero offset**: expect no snap and no NaN (it is inside the leash). Pinned in Task 2 test (`leashOffset(0, 0, 20)` returns nil).
4. **Target dies, leaves the game or crosses the safe line mid-chase**: expect lock-on to drop them and pick the next carrier or go home. Pinned in Task 2 test (`pickTarget` with the current target missing from candidates) and Task 4 Play check.
5. **Carrier standing on a patch when phase 2 begins far away**: expect the guardian to snap to X (leash still applies while holding) but not catch. Pinned in Task 3 implementation order (leash before hold) and Task 4 Play check.

---

### Task 1: Pacing sim for the leash chase (numbers for user approval)

**Files:**
- Modify: `steal-a-ride/tools/pacing-sim/progress.py` (`run()` signature + one line)
- Create: `steal-a-ride/tools/pacing-sim/leash.py`
- Output: `steal-a-ride/tools/pacing-sim/leash-out.txt`

**Interfaces:**
- Produces: `leash-out.txt` with a `CONFIG` block (per-biome `carry`, `secretMult`, `leashBuffer`) consumed verbatim by Task 5, and the pacing report the user approves.

- [ ] **Step 1: Let `run()` record the ride speed at each biome's first attempt**

In `progress.py` change the signature and add the record right after the attempt is chosen:

```python
def run(P, seed, verbose=False, target="Cosmic", tries=None):
```

```python
        i, b, p, soda = best
        if tries is not None:
            tries.setdefault(b, base)  # free riding speed (mount + rarity + saddle) at the first attempt of b
        if soda: st["cash"] -= gear
```

- [ ] **Step 2: Create `leash.py`**

```python
"""Leash chase (spec 2026-10-09-guardian-leash-design): phase 1 inside the guardian's biome as installed minus the
rage stages; phase 2 once the carrier leaves it: snap to BUFFER behind, full speed, no tiredness, no lunge, leash
every step. Derives per-biome egg weights so the typical first-attempt rider beats each guardian by MARGIN.
Run: python leash.py  (from this folder)  -> leash-out.txt"""
import functools, statistics, math
import progress, rage, mystic
from progress import BIOMES, NESTZ, S, report, run

BUFFER, MARGIN = 15.0, 1.05
SAFE = 175  # progress.SAFEZ is -175: dist = -NESTZ - 175


def chase_leash(gs, v, dist, exit_, gap, dash=False, lunge=False, dt=0.01, buffer=BUFFER, tm=0.95):
    p, g, t = 0.0, -gap, 0.0  # carrier and guardian (front of its catch reach) along the road
    lunge_ready, lunge_until = 0.0, -1.0
    while p < dist:
        phase2 = p >= exit_
        if phase2:
            g = max(g, p - buffer)  # leash
            f = 1.0
        else:
            f = min(1, .45 + .55 * t / 2)
            if t > 12: f *= tm
            if lunge and p - g <= 15 and t >= lunge_ready: lunge_until, lunge_ready = t + .4, t + 4
        sg = gs * f * (1.5 if (not phase2 and t < lunge_until) else 1)
        sp = v * (2 if dash and (t % 8) < 1.5 else 1)
        p += sp * dt; g += sg * dt; t += dt
        if g >= p:
            return False
    return True


def use(buffer=BUFFER):
    @functools.lru_cache(maxsize=None)
    def escape_prob(gs, v, dist, fly, dash, tired):
        b = next(x for x in BIOMES if -NESTZ[x] - SAFE == dist)
        exit_ = math.inf if b == "Forest" else rage.EXIT[b]
        gaps = range(6, 37, 3)
        return sum(chase_leash(gs, v, dist, exit_, gp, dash=dash, lunge=not fly, buffer=buffer, tm=tired)
                   for gp in gaps) / len(gaps)
    progress.escapeProb = escape_prob


def first_tries(P, n=200):
    """ride speed at the first attempt of each biome under the INSTALLED chase (rage burst + Forest surge)"""
    rage.use(1.15, 4, 0.85, forestSurge=True)
    seen = {b: [] for b in BIOMES}
    for s in range(n):
        d = {}
        run(P, s, target=mystic.M, tries=d)
        for b, v in d.items():
            seen[b].append(v)
    return seen


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else math.nan


if __name__ == "__main__":
    P = mystic.P(guard=88)
    seen = first_tries(P)
    carry, top = dict(P["carry"]), {}
    print(f"leash buffer {BUFFER}, margin x{MARGIN}")
    print(f"{'biome':12} {'guard':>6} {'ride med':>9} {'ride p90':>9} {'old w':>6} {'new w':>6} {'carry':>6} {'flag'}")
    for b in BIOMES[1:]:
        gs = P["guard"][b] * S
        med, p90 = pct(seen[b], .5), pct(seen[b], .9)
        raw = MARGIN * gs / med
        carry[b] = round(min(1.0, raw), 3)
        top[b] = MARGIN * gs / (p90 * carry[b])
        print(f"{b:12} {gs:6.1f} {med:9.1f} {p90:9.1f} {P['carry'][b]:6.2f} {carry[b]:6.3f} {med*carry[b]:6.1f} {'NEEDS SLOWER GUARDIAN' if raw > 1 else ''}")
    secret = round(min(1.0, max(top.values())), 3)
    print(f"secretMult {secret} (top p90 rider beats every guardian by x{MARGIN})")
    old = dict(P)
    new = dict(P, carry=carry)
    use()
    report(old, n=200, label="leash, OLD weights", target="Cosmic")
    report(new, n=200, label="leash, NEW weights", target="Cosmic")
    report(new, n=200, label="leash, NEW weights", target=mystic.M)
    print("CONFIG")
    for b in BIOMES:
        print(f"  carry {b} = {carry[b]}")
    print(f"  secretMult = {secret}")
    print(f"  leashBuffer = {BUFFER}")
```

- [ ] **Step 3: Run it**

Run (bash, from `steal-a-ride/tools/pacing-sim`): `python leash.py 2>&1 | tee leash-out.txt`
Expected: a table for Lake..MysticGrove, a `secretMult` line, three pacing lines, and the `CONFIG` block; no traceback.

- [ ] **Step 4: Check the targets**

From `leash-out.txt` confirm: no `NEEDS SLOWER GUARDIAN` flag (if any appears, note which biome); first Cosmic (NEW weights, target Cosmic) median ≈ 3 h real; first Mystic Grove median 30-45 real min after first Cosmic (use the `first deposit` columns: (Mys - Cos) x 2.56).
If pacing is off, adjust `MARGIN` (1.03-1.10) or `BUFFER` (10-25), rerun, and keep the run you will propose.

- [ ] **Step 5: STOP and report to the user**

Report the table (old vs new weight per biome, carry speed vs guardian speed), `secretMult`, `leashBuffer`, pacing (first Cosmic, Cosmic -> Mystic gap), any flags, and the phase-2 no-lunge rule (Review Focus 1). **Do not start Task 2 until the user approves the numbers.** Record the approved numbers in `HANDOFF.md`.

---

### Task 2: Pure leash helpers in GuardianService (tested)

**Files:**
- Modify: `steal-a-ride/src/ServerScriptService/Services/GuardianService.luau` (add four exported functions; replace `chaseFactor`)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`guardian_harness`)

**Interfaces:**
- Produces (used by Task 3):
  - `GuardianService.leashOffset(dx: number, dz: number, x: number): (number?, number?)`: `dx, dz` = guardian minus target (horizontal). Returns nil when `sqrt(dx²+dz²) <= x` (including a zero offset, so no division by zero), else the offset of length `x` along the same direction.
  - `GuardianService.inPhase2(isForestGuardian: boolean, ownBiome: string, targetBiome: string?): boolean`: `not isForestGuardian and targetBiome ~= ownBiome`.
  - `GuardianService.pickTarget(current: any?, dists: { [any]: number }): any?`: `current` if `dists[current]` exists, else the key with the smallest distance, else nil.
  - `GuardianService.chaseFactor(chasing: number, raging: boolean, noLane: boolean?, weather: number?): number`: wind-up from patrol pace over `chaseRamp`; when `raging`: no tiredness and no weather; otherwise tiredness after `tireAfter` and x weather; x `noLaneSpeedMult` if `noLane`.

- [ ] **Step 0: Back up the files this plan changes**

Copy `src/ServerScriptService/Services/GuardianService.luau`, `src/StarterPlayer/StarterPlayerScripts/Effects.luau`, `src/ReplicatedStorage/Shared/Config.luau`, `src/ServerScriptService/Services/GearService.luau`, `src/StarterGui/MainUI/ShopUI.luau`, `tests/run_feedback_checks.py` and `tests/run_secret_checks.py` into a new folder `steal-a-ride/before-leash-20261009/` (same relative layout). Confirm Studio still equals these copies (signature check as in Task 4 Step 5); if not, stop and report.

- [ ] **Step 1: Replace the old rage asserts with the new helper tests**

In `guardian_harness()` replace everything from `local G=Config.Guardian` down to (and including) the `nh(...)` asserts, i.e. the lines up to just before `for _,b in Config.Biomes do` (the sound checks), with:

```lua
local G=Config.Guardian
assert(G.leashBuffer==15,"leash buffer as approved")
assert(G.burstMult==nil and G.windedMult==nil and G.rageMult==nil and G.rageDistance==nil and G.burstSeconds==nil,"old rage stages removed")
assert(GuardianService.nextPhase==nil and GuardianService.nearHome==nil,"old rage phase helpers removed")
local cf=GuardianService.chaseFactor
local function near(a,b) return math.abs(a-b)<1e-9 end
assert(near(cf(0,false,false),G.patrolSpeedMult),"a chase starts at patrol pace")
assert(cf(5,false,false)==1,"full speed after the wind-up")
assert(near(cf(G.tireAfter+1,false,false),G.tiredMult),"phase 1 still tires")
assert(cf(G.tireAfter+1,true,false)==1,"raging never tires")
local bm=G.bloodMoonMult
assert(near(cf(5,false,false,bm),bm),"Blood Moon speeds phase 1")
assert(cf(5,true,false,bm)==1,"Blood Moon does not boost a raging guardian")
assert(near(cf(5,true,true),G.noLaneSpeedMult),"no-lane penalty still applies")
local lo=GuardianService.leashOffset
assert(lo(3,4,10)==nil,"inside the leash: no snap")
local ox,oz=lo(0,30,10)
assert(near(ox,0) and near(oz,10),"snap keeps the direction, at exactly X")
ox,oz=lo(-30,40,20)
assert(near(ox,-12) and near(oz,16),"diagonal snap at exactly X")
ox,oz=lo(0,0,20)
assert(ox==nil,"on top of the target: nothing to snap")
local ip=GuardianService.inPhase2
assert(ip(false,"Lake","Lake")==false,"target inside the guardian's biome: phase 1")
assert(ip(false,"Lake","Forest")==true,"target left the biome: phase 2")
assert(ip(false,"Lake",nil)==true,"target in a gap between biomes: phase 2")
assert(ip(true,"Forest",nil)==false and ip(true,"Forest","Lake")==false,"the Chicken never leashes")
local pt=GuardianService.pickTarget
assert(pt("a",{a=50,b=10})=="a","lock-on keeps the current target")
assert(pt("a",{b=30,c=10})=="c","current target gone: nearest remaining carrier")
assert(pt(nil,{})==nil,"nobody left: no target")
```

Also change the harness's final `print` to:

```lua
print("PASS: leash helpers (offset, phase, lock-on), phase-1 tiredness/Blood Moon, rage never tires; sounds; patch warning ramp")
```

- [ ] **Step 2: Run, expect failure**

Run the feedback runner (Global Constraints command, `run_feedback_checks.py` only).
Expected: FAIL in the guardian harness (`leash buffer as approved` — `leashBuffer` doesn't exist yet). Note: the Config part lands in Task 5; until then add `leashBuffer = 15` now to `Config.Guardian` (one key, same line as `lungeCooldown`), and remove the five old keys, because the helpers read them:

```lua
	lungeRange = 15, lungeMult = 1.5, lungeSeconds = 0.4, lungeCooldown = 4, -- close and clear: a short burst (phase 1 only)
	leashBuffer = 15 } -- out of its biome the guardian is never more than catch reach + this behind its target
```

and delete these three lines from `Config.Guardian`:

```lua
	rageDistance = 60, rageMult = 1.3, -- prey this close to the safe line: final surge, full speed x rageMult (ignores tiredness)
	-- leaving its own biome while chasing (Forest: the prey crossing the middle of the Forest) it enrages: a burst of
	-- burstMult for burstSeconds, then winded (windedMult) until the final surge. Burst/surge never stack with Blood Moon.
	burstMult = 1.15, burstSeconds = 4, windedMult = 0.85, -- tools/pacing-sim/rage.py: first Cosmic ~3.0 h (now 2.9)
```

Run again. Expected: FAIL at `chaseFactor`/`leashOffset` (helpers not written yet).

- [ ] **Step 3: Write the helpers**

In `GuardianService.luau` replace the whole `-- chase pace:` comment + `function GuardianService.chaseFactor(...)` and the `nextPhase` and `nearHome` functions (with their comments) with:

```lua
-- chase pace: winds up from patrol pace to full speed. Phase 1 (target in its biome) tires on long runs and takes the
-- Blood Moon boost; raging (phase 2) is steady full speed.
function GuardianService.chaseFactor(chasing: number, raging: boolean, noLane: boolean?, weather: number?): number
	local G = Config.Guardian
	local factor = math.min(1, G.patrolSpeedMult + (1 - G.patrolSpeedMult) * chasing / G.chaseRamp)
	if not raging then
		if chasing > G.tireAfter then
			factor *= G.tiredMult
		end
		factor *= weather or 1
	end
	return noLane and factor * G.noLaneSpeedMult or factor
end

-- leash: (dx, dz) = guardian minus target. Past x, the offset to teleport to (same direction, length x); else nil.
function GuardianService.leashOffset(dx: number, dz: number, x: number): (number?, number?)
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= x then
		return nil, nil
	end
	return dx / d * x, dz / d * x
end

-- phase 2 = the target is out of the guardian's own biome (a gap between biomes counts); never for the Chicken
function GuardianService.inPhase2(isForestGuardian: boolean, ownBiome: string, targetBiome: string?): boolean
	return not isForestGuardian and targetBiome ~= ownBiome
end

-- lock-on: keep the current target while it is still chaseable, else the nearest remaining carrier
function GuardianService.pickTarget(current: any?, dists: { [any]: number }): any?
	if current ~= nil and dists[current] then
		return current
	end
	local best, bestD
	for who, d in dists do
		if not bestD or d < bestD then
			best, bestD = who, d
		end
	end
	return best
end
```

Note `leashOffset(0,0,20)` returns nil because `0 <= 20`; that satisfies the zero-offset test.

- [ ] **Step 4: Temporarily keep `step()` compiling**

`step()` still calls `nextPhase`/`nearHome` and `moveToward` passes `g.ragePhase` to `chaseFactor`. In `moveToward` change the call to:

```lua
		speed *= GuardianService.chaseFactor(os.clock() - g.chaseStart, g.raging == true, g.noLane, GuardianService.speedMultiplier)
```

and in `step()` replace the block from `local pz = player.Character.HumanoidRootPart.Position.Z` through the `enrage(g, player, phase)` `end` with nothing (Task 3 rewrites this section). Leave the rest.

- [ ] **Step 5: Run, expect pass**

Run all 7 runners. Expected: all exit 0; `run_feedback_checks.py` prints the new PASS line and `compiled 61 Luau sources`.

- [ ] **Step 6: Checkpoint** — note in `HANDOFF.md`: helpers added, local only, not installed.

---

### Task 3: Wire the leash chase into GuardianService

**Files:**
- Modify: `steal-a-ride/src/ServerScriptService/Services/GuardianService.luau` (`huntable`, `findTarget`, `calm/enrage/wind/goHome`, `chaseTarget`, `step`, `start`, top-of-file locals and header comment)

**Interfaces:**
- Consumes: Task 2 helpers.
- Produces: model attributes `Raging` (true while phase 2), `ChaseTarget` (UserId), `Snap` (counter, bumped on every teleport), `SnapFrom` (Vector3, position before the teleport); Notify `"rage"` once when phase 2 starts. `Winded` is no longer set.

- [ ] **Step 1: Header comment and locals**

Replace lines 1-6 (header comment) with:

```lua
-- Guardians: patrol a circle around the nest, turn on a grabber almost instantly (Config.Guardian.wakeDelay) and chase.
-- Phase 1 (target in its biome): wind-up, lunge, pathing, tiredness, Blood Moon. Phase 2 (target out of its biome,
-- never the Forest Chicken): enraged at steady full speed and leashed: never more than catch reach + leashBuffer behind,
-- teleporting back (Snap attribute; clients puff). Locks on to one target; escape patches only pause it (no advance,
-- no catch). The chase ends only in the safe zone or on a catch. Anchored models moved with PivotTo on Heartbeat.
```

Delete the two locals `forestFarZ` and `forestMid` (lines 37-38) and their assignments in `start()` (`forestFarZ = ...`, `forestMid = ...`).

- [ ] **Step 2: Split `huntable` so patches no longer drop the target**

Replace `huntable` with:

```lua
-- a carrier who can still be chased: has an egg and isn't home yet. onPatch: standing on an escape patch they can use
-- (the guardian holds off while they stay there, but keeps them as its target)
local function huntable(player)
	local root = player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not player:GetAttribute("CarryingEgg") or root.Position.Z > safeZ then
		return nil, nil, false
	end
	local biomeId = biomeAt(root.Position.Z)
	return root, biomeId, biomeId ~= nil and GuardianService.canEscape(player, biomeId)
end
```

- [ ] **Step 3: Lock-on `findTarget`**

Replace `findTarget` with:

```lua
-- the locked-on target if still chaseable, else the nearest remaining carrier (drops the uncatchable from the list)
local function findTarget(g)
	local dists = {}
	for player in g.prey do
		local root = huntable(player)
		if not root then
			g.prey[player] = nil
		else
			dists[player] = g.canFly and (root.Position - g.cf.Position).Magnitude or (flat(root.Position) - flat(g.cf.Position)).Magnitude
		end
	end
	local target = GuardianService.pickTarget(g.target, dists)
	if target ~= g.target then
		g.target, g.chaseStart = target, os.clock() -- a new chase winds up from patrol pace
		g.raging = false
		calm(g)
	end
	if g.model:GetAttribute("ChaseTarget") ~= (target and target.UserId) then
		g.model:SetAttribute("ChaseTarget", target and target.UserId)
	end
	return target, target and dists[target]
end
```

- [ ] **Step 4: Rage helpers**

Replace the rage comment, `calm`, `enrage`, `wind` and `goHome` with:

```lua
-- phase 2 enrages it: red glow for everyone, roar + warning for the prey, until the chase ends
local function calm(g)
	g.model:SetAttribute("Raging", nil)
	local glow = g.model:FindFirstChild("RageGlow")
	if glow then glow:Destroy() end
end

local function enrage(g, player)
	calm(g)
	g.raging = true
	g.model:SetAttribute("Raging", true)
	local glow = Instance.new("Highlight")
	glow.Name = "RageGlow"
	glow.FillColor, glow.OutlineColor = Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 200, 60)
	glow.FillTransparency = 0.45
	glow.Parent = g.model
	Notify:FireClient(player, "rage", g.biome.id)
end

local function goHome(g)
	g.raging, g.target = false, nil
	calm(g)
	g.model:SetAttribute("ChaseTarget", nil)
	g.state = "return"
	table.clear(g.prey) -- carriers still in its biome get picked up again by the pass-through check
end
```

- [ ] **Step 5: No lunge while raging**

In `chaseTarget`, change the lunge trigger line to:

```lua
	if not g.raging and see and dist <= G.lungeRange + g.radius and now >= (g.lungeReadyAt or 0) then
```

- [ ] **Step 6: The snap**

Add above `local function step(dt: number)`:

```lua
-- leash snap: teleport to exactly X behind the target (flyers at its height), puff on clients, restart pathing
local function snap(g, targetPos: Vector3, ox: number, oz: number)
	local from = g.cf.Position
	local y = g.canFly and math.max(g.home.Position.Y, targetPos.Y) or g.home.Position.Y
	local pos = Vector3.new(targetPos.X + ox, y, targetPos.Z + oz)
	g.cf = CFrame.lookAt(pos, Vector3.new(targetPos.X, y, targetPos.Z))
	g.waypoints, g.pathAt, g.windowPos, g.windowAt, g.pushUntil = nil, 0, nil, os.clock(), 0
	g.model:SetAttribute("SnapFrom", from)
	g.model:SetAttribute("Snap", (g.model:GetAttribute("Snap") or 0) + 1)
end
```

- [ ] **Step 7: Rewrite the chase branch and the pass-through check in `step()`**

The pass-through loop at the top of `step()` needs no edit: `huntable` now also returns `onPatch`, which that loop ignores, so a carrier standing on a patch in the guardian's biome is still noticed. Then replace the whole `if g.state == "chase" then ... elseif g.state == "return" then` block's chase part with:

```lua
		if g.state == "chase" then
			local player, dist = findTarget(g)
			if not player then
				goHome(g)
			else
				local root, targetBiome, onPatch = huntable(player)
				local tpos = root.Position
				g.noLane = not GuardianService.hasLane(player, g.biome.id)
				if GuardianService.inPhase2(g.biome.id == Config.Biomes[1].id, g.biome.id, targetBiome) then
					if not g.raging then
						enrage(g, player)
					end
					local reach = Config.Guardian.catchRadius + g.radius + Config.Guardian.leashBuffer
					local ox, oz = GuardianService.leashOffset(g.cf.Position.X - tpos.X, g.cf.Position.Z - tpos.Z, reach)
					if ox then
						snap(g, tpos, ox, oz)
						dist = reach
					end
				end
				if onPatch then
					-- holding: stays on the target, no advance, no catch
				elseif dist <= Config.Guardian.catchRadius + g.radius
					and (g.canFly or math.abs(tpos.Y - g.cf.Position.Y) <= g.height * .5 + Config.Guardian.catchRadius) then
					catch(g, player)
				else
					local target, mult = chaseTarget(g, tpos, dist, now)
					moveToward(g, target, dt, mult)
				end
			end
		elseif g.state == "return" then
```

Also change the waking line so a fresh chase starts from patrol pace even if the target is unchanged:

```lua
		if g.state == "waking" and now >= g.wakeAt then
			g.state, g.chaseStart, g.target = "chase", now, nil
```

(`g.target = nil` makes `findTarget` lock on afresh and reset `chaseStart`/rage.)

- [ ] **Step 8: Compile + full test run**

Run all 7 runners. Expected: all exit 0 (the guardian harness only touches the helpers; compile covers the rest).
Then grep for leftovers: `rg -n "ragePhase|rageAt|nextPhase|nearHome|forestMid|forestFarZ|wind\(|Winded" steal-a-ride/src/ServerScriptService/Services/GuardianService.luau` — expected: no matches.

- [ ] **Step 9: Checkpoint** — `HANDOFF.md`: GuardianService rewired locally; not installed.

---

### Task 4: Client snap effect, tiers, and Studio Play verification of the chase

**Files:**
- Modify: `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/Effects.luau` (`guardianTier`, `watchGuardian`, `"rage"` comment)
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`guardian_fx_harness`)

**Interfaces:**
- Consumes: Task 3 attributes `Snap`, `SnapFrom`, `Raging`.

- [ ] **Step 1: Update the tier test**

In `guardian_fx_harness` delete the line

```lua
assert(guardianTier(model({ChaseTarget=1,OutOfBiome=true,Winded=true}))==1,"winded after the burst: dimmed back to calm")
```

- [ ] **Step 2: Remove the Winded tier**

In `Effects.luau` `guardianTier`, delete:

```lua
	elseif g:GetAttribute("Winded") then -- spent its burst: dimmed back down until the final surge
		return 1
```

and change the `"rage"` branch comment to `-- it left its biome after you: enraged until home or caught (its alert again, louder)`.

- [ ] **Step 3: Snap puff + whoosh**

In `watchGuardian`, after `local stepFX = guardianFX(g, biomeId, size)`, add:

```lua
	-- leash snap: its signature puff where it vanished and where it reappears, and a whoosh
	g:GetAttributeChangedSignal("Snap"):Connect(function()
		local def = GFX.guardians[biomeId] and GFX.guardians[biomeId].step
		local to = g:GetPivot().Position - Vector3.new(0, size.Y / 2 - 0.5, 0)
		if not def or not near(to, 200) then return end
		local from = g:GetAttribute("SnapFrom")
		if typeof(from) == "Vector3" then
			fxBurst(def, from - Vector3.new(0, size.Y / 2 - 0.5, 0), 30)
		end
		fxBurst(def, to, 30)
		voice(MFX.whoosh, g.PrimaryPart or nil, 0.5)
	end)
```

(`fxBurst`, `GFX`, `near`, `voice`, `MFX` already exist in `Effects.luau`.)

- [ ] **Step 4: Run tests**

Run all 7 runners. Expected: all exit 0.

- [ ] **Step 5: Install Task 2-4 code in Studio**

Studio id from `list_roblox_studios` ("Steal a Mount"). In Edit mode: compute Studio signatures of GuardianService, Effects, Config (djb2 of LF-normalised `Source`, trailing newlines stripped) and compare with the copies in `steal-a-ride/before-leash-20261009/` (Task 2 Step 0). If Studio differs from those backups, stop and report (someone else changed Studio). Otherwise back up the 3 scripts into `ServerStorage.LeashBackup20261009` (Clone) and install with `multi_edit` using the same old/new strings as Tasks 2-4. Verify Studio == local signatures for all 3.

- [ ] **Step 6: Play checks (fakeStore; restore nothing needed)**

Start Play; server: `ServerStorage.TestHooks:Invoke("fakeStore")`, give + mount a fast rider (`give "BabyDragon" "Legendary"`, `mount`, `set SaddleLevel 10`). Use client-side `Humanoid:MoveTo` driving (scripted jumps via `ChangeState(Jumping)`), never teleport the character while it carries an egg (anti-speed drop). For each check log the guardian's attributes every 0.25 s:
1. Reported bug: `grab "MysticGrove"`, drive toward home along x=20 into Cosmic; expect `ChaseTarget` stays set and `Raging=true` from the moment z > -2705, and the spider follows into Cosmic and beyond (gap ≤ catch reach + 15 + small slack) until caught or the safe line.
2. Leash snap: with a rider faster than the guardian (e.g. Lake egg with the Legendary dragon), after leaving the Lake the `Snap` counter increments and the gap never exceeds X + one frame of movement; client log shows the BiomeHatch-style burst parts appear (check `workspace` for the burst holder parts created by `fxBurst` at the old position).
3. No lunge in phase 2: during check 2 the guardian's `Lunging`/speed spikes don't occur (spider only has `Lunging` attribute; for others confirm no catch while the rider is faster).
4. Patch hold: drive onto an escape patch you have the ability for in a later biome; expect `ChaseTarget` stays, the guardian stops advancing (gap constant), no catch; stepping off resumes.
5. Chicken unchanged: `grab "Forest"`; expect no `Raging`, no `Snap`, normal chase.
6. Blood Moon: `TestHooks:Invoke("weather","BloodMoon")`; in phase 1 the guardian is faster (compare closing speed), in phase 2 it is not.
Stop Play. Record results.

- [ ] **Step 7: Checkpoint** — `HANDOFF.md`: installed + Play results (each check pass/fail with numbers).

---

### Task 5: Egg weights, Soda and Guide copy (approved numbers)

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`carry` per biome in `Config.Biomes`, `Config.Carry.secretMult`, `Config.Gear.soda.boost`, Guide tips `nests`)
- Modify: `steal-a-ride/src/ServerScriptService/Services/GearService.luau:47`
- Modify: `steal-a-ride/src/StarterGui/MainUI/ShopUI.luau:76`
- Test: `steal-a-ride/tests/run_feedback_checks.py` (`movement_harness` plan table, `main()`), `steal-a-ride/tests/run_secret_checks.py:53`

**Interfaces:**
- Consumes: the user-approved `CONFIG` block from `leash-out.txt` (Task 1).

- [ ] **Step 1: Update the tests to the approved numbers**

In `movement_harness` replace the third value of each `plan` entry with the approved `carry` for that biome, keep guardian speed and income, and replace the Secret line with the approved multiplier, e.g. if `secretMult = 0.9`:

```lua
    assert(math.abs(secret-want[3]*.9)<1e-9 and secret<=want[3],b.id.." Secret Egg uses the approved Secret weight")
```

Replace `if prev then assert(want[3]<prev,"eggs get heavier with biome depth") end` with `if prev then assert(want[3]<=prev+1e-9,"eggs never get lighter with depth") end` only if the approved weights are not strictly decreasing (otherwise leave it).
Add after `assert(Config.Gear.priceSeconds==300 ...`:

```lua
assert(math.abs(Config.Gear.soda.boost-0.10)<1e-9,"Speed Soda is +10%")
```

In `run_secret_checks.py:53` replace `.8` with the approved multiplier and the message with `'Secret Eggs use the approved Secret weight'`.
In `run_feedback_checks.py` `main()`, before `with tempfile...`, add:

```python
    for rel in ("ServerScriptService/Services/GearService.luau", "StarterGui/MainUI/ShopUI.luau"):
        text = (ROOT / "src" / rel).read_text(encoding="utf-8-sig")
        assert "+25%" not in text, f"{rel}: Soda text must not show a percentage"
        assert "Speed Boost for 20s" in text, f"{rel}: Soda text should read 'Speed Boost for 20s'"
```

- [ ] **Step 2: Run, expect failure**

Run all 7 runners. Expected: `run_feedback_checks.py` fails on the Soda text assert; carry asserts fail.

- [ ] **Step 3: Apply the numbers and copy**

- Each biome's `carry = <approved>` in `Config.Biomes` (Forest unchanged unless the sim changed it).
- `Config.Carry = { secretMult = <approved>, -- Secret Eggs keep this fraction of their biome's normal carry speed (leash sim 2026-10-09)`
- `soda = { boost = 0.10, duration = 20 },`
- `GearService.luau:47`: `Notify:FireClient(player, "toast", "Speed Soda! Speed Boost for 20s")`
- `ShopUI.luau:76`: `return ("Speed Boost for 20s  ·  You have %d"):format(player:GetAttribute("GearSoda") or 0), player:GetAttribute("GearPrice") or 50`
- Guide tip `nests` body, replace the last sentence `Guardians tire on long chases, but rage when you're close to safety.` with `Leave a guardian's biome with its egg and it follows you all the way home, enraged and never far behind: outrun it, Dash when it closes in, or catch your breath on an escape patch.`

- [ ] **Step 4: Run, expect pass** — all 7 runners exit 0.

- [ ] **Step 5: Install in Studio** — same procedure as Task 4 Step 5 for Config, GearService, ShopUI (backups into `ServerStorage.LeashBackup20261009`), verify signatures equal.

- [ ] **Step 6: Checkpoint** — `HANDOFF.md`.

---

### Task 6: What's New v3 rewording + v4

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`Config.WhatsNew` v3 lines, new v4 entry)
- Test: existing `whats_new_harness` (structure, ordering, newest-first) covers it.

- [ ] **Step 1: Edit v3**

Replace the v3 lines

```lua
			"The <b>mushroom caps</b> now lead all the way to the exit: hop from cap to cap to shake off the Giant Spider",
			"Hide on the last cap, then slip out of the grove before it softens",
```

with

```lua
			"The <b>mushroom caps</b> now line the way to the exit: hop on one to catch your breath",
```

- [ ] **Step 2: Add v4 after v3**

```lua
	{
		version = 4,
		title = "Relentless guardians",
		lines = {
			"Leave a guardian's biome with its egg and it <b>follows you all the way home</b>, never far behind",
			"Once you're out of its biome it stays <b>enraged</b> until you're home or caught",
			"Faster rides win: upgrade your <b>Saddle</b> and pets to outrun it",
			"<b>Dash</b> can save you when it closes in",
			"Escape patches let you catch your breath, but the chase goes on",
			"Egg weights have been retuned for the new chase",
			"Speed Soda is now a <b>Speed Boost for 20s</b>",
		},
	},
```

- [ ] **Step 3: Run tests** — all 7 runners exit 0.
- [ ] **Step 4: Install Config edit in Studio**, verify signatures equal.
- [ ] **Step 5: Checkpoint** — `HANDOFF.md`.

---

### Task 7: Final verification and handoff

- [ ] **Step 1: Full Studio/local signature sweep** of all 61 scripts (same method as the 2026-10-09 audit): expect 0 differences.
- [ ] **Step 2: One end-to-end Play run per new rule** (re-run Task 4 Step 6 checks 1-6 with the final weights) plus: Speed Soda toast reads "Speed Soda! Speed Boost for 20s"; the Shop row reads "Speed Boost for 20s"; the What's New panel shows v4 then v3 for a player whose `WhatsNew` attribute is set to 2.
- [ ] **Step 3: Rerun `python leash.py` once with the installed numbers** and confirm the pacing lines match the approved report.
- [ ] **Step 4: Update `HANDOFF.md`**: replace the in-progress entries with one final entry (files changed, Studio backups `ServerStorage.LeashBackup20261009` + `steal-a-ride/before-leash-20261009/`, approved numbers, Play results, NOT published). Tell the user it is ready to publish.
