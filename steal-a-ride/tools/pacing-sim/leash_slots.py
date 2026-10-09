"""Leash buffer vs a 2nd mount slot (Dash pet) and rider bumps (2026-10-09 follow-up to leash.py).
Part 1: Mystic escape odds by rider speed relative to the spider, with/without Dash, with/without bumps, per buffer.
Part 2: pacing (first Cosmic, Mystic gap) per buffer for a fresh player and for one with a 2nd slot from the start.
Run: python leash_slots.py  (from this folder) -> leash-slots-out.txt"""
import functools, math, random
import progress, rage, mystic, leash
from progress import BIOMES, NESTZ, S, report

STALL_EVERY, STALL_S = 6.0, 0.2  # bump model: a 0.2 s stop every ~6 s (props, turns), jittered per run


def chase_bumps(gs, v, dist, exit_, gap, buffer, dash=False, seed=0, dt=0.005):
    rng = random.Random(seed)
    p, g, t = 0.0, -gap, 0.0
    nxt = rng.uniform(2, STALL_EVERY * 1.5)
    stall_until, dash_ready, dash_until = -1.0, 0.0, -1.0
    while p < dist:
        if t >= nxt:
            stall_until, nxt = t + STALL_S, t + rng.uniform(.5, 1.5) * STALL_EVERY
        phase2 = p >= exit_
        if phase2:
            g = max(g, p - buffer)
        f = 1.0 if phase2 else min(1, .45 + .55 * t / 2)
        # panic Dash: used when the guardian is within half the buffer (a human presses it when it closes in)
        if dash and t >= dash_ready and p - g < buffer * .5:
            dash_until, dash_ready = t + 1.5, t + 8
        sp = 0 if t < stall_until else v * (2 if t < dash_until else 1)
        p += sp * dt; g += gs * f * dt; t += dt
        if g >= p:
            return False
    return True


def odds(gs, v, dist, exit_, buffer, dash, bumps, n=40):
    if not bumps:
        return sum(chase_bumps(gs, v, dist, exit_, gp, buffer, dash, seed=-1) if False else
                   leash.chase_leash(gs, v, dist, exit_, gp, dash=dash, buffer=buffer) for gp in range(6, 37, 3)) / 11
    return sum(chase_bumps(gs, v, dist, exit_, 6 + (i % 11) * 3, buffer, dash, seed=i) for i in range(n)) / n


if __name__ == "__main__":
    M = mystic.M
    gs, dist, exit_ = 88 * S, -NESTZ[M] - 175, rage.EXIT[M]
    print(f"Part 1: Mystic Grove escape odds (spider {gs:.0f}), bumps = {STALL_S}s stop every ~{STALL_EVERY:.0f}s")
    print(f"{'rider/spider':>12} " + " ".join(f"{f'b{b} {d}':>14}" for b in (15, 20, 25) for d in ("", "+Dash")))
    for r in (0.95, 0.97, 0.99, 1.01, 1.03, 1.05, 1.08):
        row = []
        for b in (15, 20, 25):
            for d in (False, True):
                row.append(f"{odds(gs, gs * r, dist, exit_, b, d, False):4.0%}/{odds(gs, gs * r, dist, exit_, b, d, True):4.0%}")
        print(f"{r:12.2f} " + " ".join(f"{x:>14}" for x in row))
    print("(each cell: no bumps / with bumps)")
    print("Part 2: pacing with the installed weights")
    P = mystic.P(guard=88)
    carry = {"Forest": .96, "Lake": .934, "Desert": .866, "Jungle": .927, "Tundra": .859, "Volcano": .828, "Cosmic": .925, M: .927}
    for b in (15, 20, 25):
        leash.use(buffer=b)
        for slot in (False, True):
            Q = dict(P, carry=carry, soda=1.10, secondSlot=slot)
            label = f"buffer {b} {'2nd slot' if slot else 'fresh'}"
            report(Q, n=200, label=label + " Cos", target="Cosmic")
            report(Q, n=200, label=label + " Mys", target=M)
