# 1D chase home along the road, mirroring GuardianService: ramp .45->1 over 2 s, tired x(tm) after 12 s,
# rage x1.3 within 60 studs of the safe line (overrides tired), Blood Moon x1.15. Flyers: no lunge.
def chase(gs, v, dist, gap, tm=0.95, dash=False, blood=False, lunge=False, dt=0.005, rage=True):
    p, g, t = 0.0, -gap, 0.0           # player pos, guardian front-of-catch-reach pos
    lungeReady = 0.0; lungeUntil = -1
    while p < dist:
        f = min(1, .45 + .55 * t / 2)
        if rage and dist - p <= 60: f *= 1.3
        elif t > 12: f *= tm
        sg = gs * f * (1.15 if blood else 1)
        if lunge and p - g <= 15 and t >= lungeReady: lungeUntil, lungeReady = t + .4, t + 4
        if t < lungeUntil: sg *= 1.5
        sp = v * (2 if dash and (t % 8) < 1.5 else 1)
        p += sp * dt; g += sg * dt; t += dt
        if g >= p: return f"CAUGHT at {p:5.0f}/{dist} ({t:4.1f}s)"
    return f"ESCAPED ({t:4.1f}s, margin {p-g:4.0f})"

def minv(gs, dist, gap, **k):
    lo, hi = 20, 300
    for _ in range(40):
        mid = (lo+hi)/2
        if chase(gs, mid, dist, gap, **k).startswith("ESC"): hi = mid
        else: lo = mid
    return hi

S = 1.25
volc = lambda rar, sad, mut, abil=True: 63.75*S + rar + mut + (0 if abil else 2) + sad
builds = {
 "typical: Volcano Common Hellpup(Dash), saddle 10": (volc(0,10,0), True),
 "strong: Volcano Legendary Hellpup, saddle 20, Cursed": (volc(12,20,3), True),
 "strong, no Dash mount (Legendary Salamander)": (volc(12,20,3), False),
}
D = {"Cosmic": 2336, "Volcano": 1766}
for gap in (36, 20):
  print(f"\n=== head start {gap} studs (36 = best case: grab on the far side of its patrol, 20 = typical)")
  for name, gsNew, gsOld, carry, d, lunge in [("Cosmic", 125, 90.625, .8, D["Cosmic"], False), ("Volcano", 100, 75, .82, D["Volcano"], True)]:
    for bname, (base, dash) in builds.items():
        vNew, vOld = base*carry, base
        print(f"{name:7} {bname:52} OLD v={vOld:5.1f}: {chase(gsOld, vOld, d, gap, tm=.8, dash=dash, lunge=lunge):34} NEW v={vNew:5.1f}: {chase(gsNew, vNew, d, gap, dash=dash, lunge=lunge)}")
        print(f"{'':7} {'   + Speed Soda (+25%)':52} {'':47} NEW v={vNew*1.25:5.1f}: {chase(gsNew, vNew*1.25, d, gap, dash=dash, lunge=lunge)}")

print("\n=== slowest carrying speed that escapes (head start 20), new tired 0.95")
for name, d, lunge in (("Cosmic", D["Cosmic"], False), ("Volcano", D["Volcano"], True)):
    for gs in ([125, 110, 105, 100, 95] if name == "Cosmic" else [100, 90, 85, 80]):
        print(f"{name:7} guardian {gs:5.1f}: no Dash {minv(gs, d, 20, lunge=lunge):6.1f} | Dash {minv(gs, d, 20, dash=True, lunge=lunge):6.1f} | Dash+BloodMoon {minv(gs, d, 20, dash=True, blood=True, lunge=lunge):6.1f}")
