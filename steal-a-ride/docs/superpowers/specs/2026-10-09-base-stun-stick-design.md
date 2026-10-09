# Base Stun Stick — design

Status: approved in chat 2026-10-09 (user). Implemented + installed in Studio 2026-10-09 (not published).

## Goal
Give base owners a way to defend against raiders: a stick, usable only inside their own base, that stuns a thief carrying an egg stolen from them and sends the egg back home. Cosmetic stick tiers are bought with in-game Cash.

## User decisions
- Hit egg goes **straight back to the owner's incubator** (not dropped on the ground).
- **Only players carrying an egg stolen from you** can be hit — including further down a chain (you → A → B: you can hit B); anyone else = whiff. Dropping an egg ends its theft history.
- Stun lasts **2 s**.
- After a stick hit, the victim's 60 s `robCooldown` is **cleared** — the thief may try again as soon as the stun ends.
- Cosmetics: **tier ladder** Wooden (free) → Iron → Gold → Crystal → Glitch; looks only; each tier requires the previous; price = minutes of the buyer's income (10 / 30 / 60 / 120); kept through rebirth.

## Behaviour
1. **Holding it.** `StealService.tick` (every 0.3 s) already knows each player's position and plot. When a player is inside their own plot (`insidePlot`), the server ensures a `Tool` named `Stick` is in their Backpack (or equipped); when outside, it destroys it. Standard Roblox Tool → click / tap / console activate for free (Backpack CoreGui is enabled in this game).
2. **Swing.** Server-side `Tool.Activated` (it replicates natively, no remote) calls `StealService.activate`, which ignores clicks inside the cooldown, then `StealService.swing(owner)`:
   - Swing cooldown 0.8 s per owner; ignore if inside cooldown.
   - Require owner alive and inside own plot.
   - Find nearest player within `Config.Stick.range` (7 studs) whose carried egg has `stolenFrom == owner`.
   - None → whiff (swing animation/sound only, no toast spam).
   - Hit → `SpeedService.stun(thief, 2)`; `egg = EggService.take(thief)`; `HatchService.give(owner, egg)`; `robbedAt[owner] = nil`; toasts: owner "Whacked! Your egg is back home.", thief "<Owner> whacked you! The egg went home."
3. **Effects.** Swing: short tool swing (Tool grip tween or default slash anim) + whoosh sound (`SoundService.SFX.StickSwing`, asset 9120972444, played at the stick on accepted swings only). Hit: flash/sparks on thief scaled by tier + bonk (`SoundService.SFX.StickHit`, asset 137041944943141, played at the thief).

## Cosmetics
- New slot `stick` in `Config.Base.items`: `stickWood` (price 0), `stickIron`, `stickGold`, `stickCrystal`, `stickGlitch`, each with `incomeMinutes` (10/30/60/120), `requires` (previous id), and look fields (color, material, neon, trail).
- `BaseService.price` extended: `incomeMinutes` → `max(Config.Gear.minPrice, minutes*60*income)`; refuse purchase if `requires` not owned. Buy/equip flow stays `"base:<id>"` through ShopService; ownership in existing `data.Base.owned/equipped` (no save-schema change).
- Base panel shows the Stick slot; locked tiers show "Requires <prev>".
- Tool is (re)built from the equipped stick item when given; re-give on equip change.
- Glitch tier visuals match the redesigned OG badge style (see OG badge task).

## Files touched
- `ReplicatedStorage/Shared/Config.luau` — `Config.Stick`, stick items.
- `ServerScriptService/Services/StealService.luau` — give/remove tool in tick, `swing`, cooldown clear.
- `ServerScriptService/Services/BaseService.luau` — income price + `requires` gate.
- `ServerScriptService/Main.luau` — wire `BaseService.incomeOf`. (No `StickSwing` remote: server-side `Tool.Activated` is used.)
- `StarterGui/MainUI/BaseUI.luau` — Stick slot, locked state.
- `StarterPlayerScripts/ClientMain.luau` — Backpack CoreGui disabled (stick is fully automatic, per user).

## Errors / edge cases
- Owner leaves plot mid-swing → server plot check refuses.
- Thief dies / leaves → existing drop path; no stick involvement.
- Shielded players can't steal, so they're never valid targets; no extra check needed.
- Mama phase: stealing disabled already; stick naturally has no targets.
- Locked base pushes non-owners out; stick still works if a thief is inside before lock.

## Testing
- Luau check script (alongside existing `run_*_checks.py`): outside plot → no hit; non-thief target → whiff; thief with your egg → stunned, egg in incubator, robCooldown cleared; swing cooldown respected; tier purchase refused without previous tier; price scales with income.
- Studio Play, 2 players: raid → whack in base → egg back in incubator; leave base → tool gone; buy Iron → stick re-skins.
