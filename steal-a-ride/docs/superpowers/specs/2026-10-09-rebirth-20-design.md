# Rebirth 20, later mount slot, fewer kept creatures, income-priced saddle

Date: 2026-10-09. Status: **approved by user 2026-10-09 (with the title change below); nothing implemented yet.**

## Goal (user decisions)

- Rebirths go up to **20** (today 10). Rebirth 20 should take **days, not weeks**: about **30–35 hours of play** from a fresh save (roughly 1–2 weeks at 3–4 h/day, a few days for a dedicated player).
- The second free mount slot moves from **Rebirth 3 to Rebirth 6** (the Extra Mount Robux pass is unchanged).
- Kept creatures through a rebirth: **1, +1 every 4 rebirths** (today: +1 at 3, 6 and 9).
- The saddle is too cheap mid/late game: its price follows income, like gear already does.
- **Luck** rewards at Rebirth 10 and 20.
- **Lordship titles** every 2 rebirths (no overhead tag).
- An 8th biome comes later: the table stays data so it can require that biome.

## Sim evidence (`tools/pacing-sim/rebirth.py`, `rebirth-out*.txt`)

A greedy bot plays from a fresh save through every rebirth on the installed values (with the 2026-10-09 rage
rework). Hours are bot hours × 2.56, the factor calibrated on one real player; the sim ignores offline income,
daily rewards, Lucky Eggs, weather, Mama and PvP, so real players are probably somewhat faster.

| Setup | R10 reached | R20 reached |
|---|---|---|
| Today's table (×4 per level), today's rules | 54.6 h (R10 alone 26.5 h) | – |
| Keep +1/4, saddle 15 s, ×1.5 then ×1.1 | 25.5 h | 44 h |
| Keep +1/4, saddle 10 s, ×1.5 then ×1.1 | 20 h | 37 h |
| Keep +1/4, fixed saddle, ×1.5 then ×1.1 | 12.5 h | 25 h |
| **Chosen: keep +1/4, saddle 8 s, ×1.5 then ×1.15** | **14.7 h** | **31.1 h** |

Findings: late income only grows by the +50% rebirth bonus, so geometric costs explode (×1.8 → R20 193 h).
The time per rebirth is mostly the **rebuild** after the reset, and the saddle price drives it far more than
the number of kept creatures. The chosen setup gives a steady 1.4–1.8 h per rebirth and keeps a fresh player's
first Cosmic egg at **3.0 h** (unchanged).

## Rebirth table

Cost: today up to R4, then ×1.5 per level to R10, then ×1.15 per level to R20 (rounded). Every rebirth still
gives +50% income (`RebirthIncomeStep`). A full reward (incubators/pen already maxed) becomes a Lucky Egg, as today.

| R | Cost | Needs | Reward | Kept creatures |
|---|---|---|---|---|
| 1 | $100K | Jungle | +1 incubator | 1 |
| 2 | $1M | Tundra | +2 pen slots | 1 |
| 3 | $10M | Volcano | +1 incubator (was the mount slot) | 1 |
| 4 | $100M | Cosmic | +1 incubator | 2 |
| 5 | $400M | Cosmic | +2 pen slots | 2 |
| 6 | $600M | Cosmic | **2nd mount slot** (was an incubator) | 2 |
| 7 | $900M | Cosmic | +2 pen slots | 2 |
| 8 | $1.35B | Cosmic | +1 incubator | 3 |
| 9 | $2B | Cosmic | +2 pen slots | 3 |
| 10 | $3B | Cosmic | **Luck I**: +5% of hatches roll one rarity higher (permanent) | 3 |
| 11 | $3.5B | Cosmic | Lucky Egg | 3 |
| 12 | $4B | Cosmic | Lucky Egg | 4 |
| 13 | $4.6B | Cosmic | Lucky Egg | 4 |
| 14 | $5.3B | Cosmic | Lucky Egg | 4 |
| 15 | $6.1B | Cosmic | Lucky Egg | 4 |
| 16 | $7B | Cosmic | Lucky Egg | 5 |
| 17 | $8.1B | Cosmic | Lucky Egg | 5 |
| 18 | $9.3B | Cosmic | Lucky Egg | 5 |
| 19 | $10.7B | Cosmic | Lucky Egg | 5 |
| 20 | $12.3B | Cosmic | **Luck II**: +10% total | 6 |

Kept = `1 + rebirths // 4` (ridden mounts are pre-picked, as today).

## Mechanics

- **Mount slots** (`MountService.slots`): `1 + (Rebirths >= 6 and 1 or 0) + ExtraMount pass`. Players at R3–R5 who ride
  two creatures get the extra one sent back to the Stable on their next join (existing `MountService.trim`); no
  creature is lost.
- **Rebirth luck**: a permanent chance of one rarity up, added to the Lucky pass chance (pass 10% + R10 5% = 15%;
  R20 → 20%). It never rolls above Legendary from a normal egg (same as the pass). The Store's odds disclosure
  (`Config.hatchOdds`) takes the player's total up-chance so shown odds stay exact.
- **Saddle price**: level L costs `max(100 × 1.85^L, income per second × 8 × 1.15^L)`. A fresh player pays today's
  prices; late game a full 0→20 rebuild costs about 16 minutes of income. The Gear Shop shows the live price.
- **Lordship titles** (every 2 rebirths; none before Rebirth 2):

  | Rebirths | Title | Rebirths | Title |
  |---|---|---|---|
  | 2–3 | Lesser Lord | 12–13 | Emerald Lord |
  | 4–5 | Iron Lord | 14–15 | Royal Lord |
  | 6–7 | Silver Lord | 16–17 | Mythic Lord |
  | 8–9 | Golden Lord | 18–19 | Celestial Lord |
  | 10–11 | Platinum Lord | 20 | Divine Overlord |

  `Config.rebirthTitle(n)` returns the title (or nil). Shown in four places, none overhead: the Rebirth menu
  (current title, next title and how many rebirths away), a rank-up toast when a rebirth reaches a new tier
  ("You are now an Iron Lord!"), the Top Rebirths board next to each name, and the player's base sign.
- **8th biome later**: the "Needs" column is data; when the new biome ships, the later rebirths can require it
  (and the sim re-run).

## Changes (implementation sketch)

- `Config.luau`: REBIRTHS to 20 with the table above and reward kinds `incubator`/`pen`/`mount`/`luck`/`lucky`;
  `rebirthKeep(n) = 1 + n // 4`; rebirth luck values; saddle price uses income (`saddleSeconds = 8`); `hatchOdds`
  takes an up-chance; Guide "rebirth" tip text (kept creatures, R20).
- `RebirthService`: new reward kinds (`luck` sets nothing extra, it's derived from Rebirths; `lucky` gives the Lucky Egg).
- `MountService.slots`: R6.
- `HatchService.roll`: up-chance = pass + rebirth luck.
- Saddle purchase (Gear Shop service + UI): price from the player's current income.
- Rebirth menu: new rewards, kept count, current/next title. RebirthService: rank-up toast. Top Rebirths board and base sign: title next to the name.
- Tests: rebirth table monotonic + 20 entries, keep rule, slots at R6, luck odds sum to 1 and match `roll`,
  saddle price floor and scaling, rebirthTitle every 2 rebirths; existing rebirth/legacy harnesses updated. Play: TestHooks rebirth to R6/R10/R20.

## Not in scope

Saddle max level, gear prices (already income-based), the Extra Mount pass, income per rebirth, Mama/weather.
