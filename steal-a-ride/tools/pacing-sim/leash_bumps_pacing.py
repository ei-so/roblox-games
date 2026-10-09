"""Pacing with rider bumps in the escape model (leash_slots.chase_bumps), buffers 25/30, fresh vs 2nd slot.
Also Mystic escape odds at a 0.25 s bump. Run: python leash_bumps_pacing.py -> leash-bumps-out.txt"""
import functools, math
import progress, rage, mystic, leash_slots as ls
from progress import BIOMES, NESTZ, S, report


def use_bumps(buffer):
    @functools.lru_cache(maxsize=None)
    def escape_prob(gs, v, dist, fly, dash, tired):
        b = next(x for x in BIOMES if -NESTZ[x] - 175 == dist)
        exit_ = math.inf if b == "Forest" else rage.EXIT[b]
        return sum(ls.chase_bumps(gs, v, dist, exit_, 6 + (i % 11) * 3, buffer, dash, seed=i, dt=0.01) for i in range(22)) / 22
    progress.escapeProb = escape_prob


if __name__ == "__main__":
    M = mystic.M
    gs, dist, exit_ = 88 * S, -NESTZ[M] - 175, rage.EXIT[M]
    ls.STALL_S = 0.25
    print("Mystic odds with 0.25 s bumps (no Dash / Dash):")
    for r in (0.97, 1.0, 1.03, 1.05):
        print(f"  rider x{r}: " + "  ".join(f"b{b} {ls.odds(gs, gs*r, dist, exit_, b, False, True):.0%}/{ls.odds(gs, gs*r, dist, exit_, b, True, True):.0%}" for b in (25, 30)))
    ls.STALL_S = 0.2
    P = mystic.P(guard=88)
    carry = {"Forest": .96, "Lake": .934, "Desert": .866, "Jungle": .927, "Tundra": .859, "Volcano": .828, "Cosmic": .925, M: .927}
    for b in (25, 30):
        use_bumps(b)
        for slot in (False, True):
            Q = dict(P, carry=carry, soda=1.10, secondSlot=slot)
            label = f"bumps b{b} {'2nd slot' if slot else 'fresh'}"
            report(Q, n=120, label=label, target=M)
