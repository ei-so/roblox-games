from progress import *
B = BASE
def V(**k):
    P = dict(B); P.update(k); return P
G = lambda **d: dict(B["guard"], **d)
H = lambda m: {b: v * m for b, v in B["hatch"].items()}
for j, g, hm, refill, sg in [(45,(52,60,76),1.5,360,1.85),(44,(52,60,76),1.5,360,1.85),(44,(52,60,76),2,420,1.9),(44,(50,58,74),2,420,1.9),(42,(50,58,74),2,420,1.9)]:
    report(V(guard=G(Jungle=j, Tundra=g[0], Volcano=g[1], Cosmic=g[2]), hatch=H(hm), refill=refill, saddleGrowth=sg), n=100,
           label=f"J{j} T{g[0]} V{g[1]} C{g[2]} h{hm} r{refill} s{sg}")
