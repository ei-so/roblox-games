"""Crystal Caverns (biome 9, plan 2026-10-10) on top of the installed model: Mystic Grove as tuned (spider 88, carry
.927), leash buffer 30 with 0.2 s rider bumps (leash_bumps_pacing), installed carry weights, soda x1.10.
Climb riders start the in-biome race WALLS * leadPerWall studs further ahead (each wall they climb while the Golem
detours through the gap); everyone else races normally. After the cave exit the leash applies as usual.
Run: python crystal.py  (from this folder)"""
import functools, math
import progress, rage, mystic, leash_slots as ls
from progress import BIOMES, NESTZ, SPECIES, MOUNTBASE, S, report

C = "CrystalCaverns"
WALLS = 4
DEPTH = 700                                 # biome depth (Mystic 640)
ENTRANCE = -2705 - 640                      # Mystic Grove FarZ
BIOMES.append(C)
NESTZ[C] = ENTRANCE - round(DEPTH * 0.7)    # nest 70% in, like Mystic (448 of 640)
SPECIES[C] = [("CrystalBeetle", None), ("GemGecko", "Climb"), ("CrystalPangolin", None)]
MOUNTBASE[C] = 90                           # x1.25 in-game = 112.5 (Mystic 84 = 105)
rage.EXIT[C] = ENTRANCE - NESTZ[C]          # studs from the nest to the cave exit
CARRY = {"Forest": .96, "Lake": .934, "Desert": .866, "Jungle": .927, "Tundra": .859, "Volcano": .828, "Cosmic": .925,
         mystic.M: .927}                    # installed (Config)
LEAD = {"perWall": 35.0, "keep": False}     # set by P(); read by the escape model
# keep=False: installed leash, the Golem snaps to 30 studs behind at the cave exit, so the wall lead is gone there.
# keep=True (proposal): a Climb rider keeps the studs won on the walls: the Golem's leash is 30 + that lead.


def chase_climb(gs, v, dist, exit_, gap, dash, seed, climb):
    lead = WALLS * LEAD["perWall"] if climb else 0
    buffer = 30 + (lead if LEAD["keep"] else 0)
    return ls.chase_bumps(gs, v, dist, exit_, gap + lead, buffer, dash, seed=seed, dt=0.01)


def odds(gs, v, b, dash, climb, n=22):
    dist, exit_ = -NESTZ[b] - 175, (math.inf if b == "Forest" else rage.EXIT[b])
    return sum(chase_climb(gs, v, dist, exit_, 6 + (i % 11) * 3, dash, i, climb) for i in range(n)) / n


def use():
    """installed escape model (bumps, buffer 30) + the Climb lead in Crystal Caverns"""
    @functools.lru_cache(maxsize=None)
    def escape_prob(gs, v, dist, fly, dash, tired, climb=False, lead=None):
        b = next(x for x in BIOMES if -NESTZ[x] - 175 == dist)
        return odds(gs, v, b, dash, climb and b == C)
    def wrapped(gs, v, dist, fly, dash, tired, climb=False):
        return escape_prob(gs, v, dist, fly, dash, tired, climb, (LEAD["perWall"], LEAD["keep"]) if climb else None)
    progress.escapeProb = wrapped


def P(guard=96, income=32000, carry=.93, hatch=300, mountBase=90, leadPerWall=35, secondSlot=False):
    MOUNTBASE[C] = mountBase
    LEAD["perWall"] = leadPerWall
    base = mystic.P(guard=88)
    return dict(base, guard=dict(base["guard"], **{C: guard}), income=dict(base["income"], **{C: income}),
                carry=dict(CARRY, **{C: carry}), hatch=dict(base["hatch"], **{C: hatch}), soda=1.10,
                climbBiomes=(C,), secondSlot=secondSlot)


if __name__ == "__main__":
    use()
    print(f"Crystal Caverns: entrance {ENTRANCE}, nest {NESTZ[C]}, exit {rage.EXIT[C]} studs from the nest, {WALLS} walls")
    report(P(), n=120, label="Mystic (reference)", target=mystic.M)
    report(P(), n=120, label="Crystal, guard 96", target=C)
