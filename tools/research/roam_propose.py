"""Roaming-route research for TBCGuide (docs/ROAMING.md, "Research and verification").

Proposes patrol loops for guide kill/drop objectives from the FULL upstream QuestieDB TBC spawn list,
applies the data checks every route must pass, merges the human review in
docs/research/roaming-overrides.csv, and writes:
  * docs/research/roaming-dispositions.csv   one row per candidate objective (the persistent record)
  * guides-src/routes/auto_<zone>.routes      routes whose disposition is "Verified and implemented"
Nothing here makes a route acceptable on its own: a route is written only when it passes every
check AND its zone has been reviewed (overrides: zone,<id>,reviewed,...). Run after
`tools/build.ps1 fetch` and `tools/build.ps1 guides` (it reads docs/generated/roaming-candidates.csv).

usage: python -I tools/research/roam_propose.py
"""
import csv, math, os, re, itertools, collections, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UP = os.path.join(ROOT, ".cache", "upstream", "questiedb", "data", "TBC", "tbcNpcDB.lua")
DB2 = os.path.join(ROOT, ".cache", "upstream", "db2", "UiMapAssignment.csv")
BUNDLED = os.path.join(ROOT, "TBCGuide", "Database", "QuestieTBC")
COMPILED = os.path.join(ROOT, "TBCGuide", "Guides", "Compiled")
INV = os.path.join(ROOT, "docs", "generated", "roaming-candidates.csv")
OVR = os.path.join(ROOT, "docs", "research", "roaming-overrides.csv")
OUT = os.path.join(ROOT, "docs", "research", "roaming-dispositions.csv")
ROUTES = os.path.join(ROOT, "guides-src", "routes")

LINK = 45          # yards: spawns closer than this belong to one spawn area
MIN_SPAWNS = 8     # fewer spawns in the area -> static waypoint is enough
MIN_EXTENT = 70    # yards: smaller areas -> static waypoint is enough
GAP = 50           # yards: every 5-yard sample of a leg must be this close to a target spawn
GAP_STRICT = 30    # in zones marked terrain=strict (cliffs, mesas, void edges, lava)
ELITE_CLEAR = 25   # yards a leg keeps from elite/rare non-target spawns
TOWN_CLEAR = 60    # yards a leg keeps from NPCs friendly only to the other faction
CAVE_WORDS = re.compile(r"\b(mine|mines|cave|caves|cavern|tunnels?|crypt|barrow|barrows|burrow|burrows|lair|hive|catacombs?|underground|inside|depths|grotto|den)\b", re.I)

# --- tiny Lua literal reader (enough for QuestieDB records) ---------------------------------------
def lua_value(s, i):
    while s[i] in " \t": i += 1
    c = s[i]
    if c == "{":
        i += 1; arr, h = [], {}
        while True:
            while s[i] in " \t,": i += 1
            if s[i] == "}": return (arr, h), i + 1
            if s[i] == "[":
                k, i = lua_value(s, i + 1); i = s.index("]", i) + 1; i = s.index("=", i) + 1
                v, i = lua_value(s, i); h[k] = v
                continue
            km = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", s[i:])
            if km:
                v, i = lua_value(s, i + km.end()); h[km.group(1)] = v
            else:
                v, i = lua_value(s, i); arr.append(v)
    if c in "'\"":
        j = i + 1; out = []
        while s[j] != c:
            if s[j] == "\\": out.append(s[j + 1]); j += 2
            else: out.append(s[j]); j += 1
        return "".join(out), j + 1
    m = re.match(r"-?\d+(?:\.\d+)?(?:e-?\d+)?|nil|true|false", s[i:])
    t = m.group(0)
    v = None if t == "nil" else True if t == "true" else False if t == "false" else float(t)
    return v, i + len(t)

def load_upstream():
    npcs = {}
    for line in open(UP, encoding="utf-8"):
        m = re.match(r"\[(\d+)\] = ", line)
        if not m: continue
        (a, _), _ = lua_value(line, m.end())
        sp = {}
        if isinstance(a[6], tuple):
            for z, pts in a[6][1].items():
                sp[int(z)] = [(p[0][0], p[0][1]) for p in pts[0] if isinstance(p, tuple) and len(p[0]) >= 2]
        npcs[int(m.group(1))] = {"name": a[0], "rank": int(a[5] or 0), "spawns": sp,
                                 "friendly": a[12] if len(a) > 12 and isinstance(a[12], str) else None,
                                 "minLevel": int(a[3] or 0)}
    return npcs

def load_sizes():
    zones = open(os.path.join(BUNDLED, "Zones.lua"), encoding="utf-8").read()
    ui = {int(a): int(b) for a, b in re.findall(r"^\[(\d+)\]=(\d+),$", zones.split("Z.names")[0], re.M)}
    names = {int(a): b for a, b in re.findall(r'^\[(\d+)\]="((?:[^"\\]|\\.)*)",$', zones.split("Z.names")[1].split("Z.parent")[0], re.M)}
    box = {}
    for r in csv.DictReader(open(DB2, encoding="utf-8")):
        if r["UiMin_0"] == "0" and r["UiMin_1"] == "0" and r["UiMax_0"] == "1" and r["UiMax_1"] == "1":
            box.setdefault(int(r["UiMapID"]), (abs(float(r["Region_4"]) - float(r["Region_1"])), abs(float(r["Region_3"]) - float(r["Region_0"]))))
    return {z: box[u] for z, u in ui.items() if u in box}, names

def bundled(name, prefix):
    out = {}
    for line in open(os.path.join(BUNDLED, name), encoding="utf-8"):
        m = re.match(r"^" + prefix + r"\[(\d+)\]=(.*)$", line.rstrip())
        if m: out[int(m.group(1))] = lua_value(m.group(2), 0)[0]
    return out

# --- geometry ---------------------------------------------------------------------------------------
def yd(size, a, b): return math.hypot((a[0] - b[0]) / 100 * size[0], (a[1] - b[1]) / 100 * size[1])

def components(size, pts):
    n = len(pts); seen = [False] * n; comps = []
    for i in range(n):
        if seen[i]: continue
        stack, comp = [i], []; seen[i] = True
        while stack:
            k = stack.pop(); comp.append(pts[k])
            for j in range(n):
                if not seen[j] and yd(size, pts[k], pts[j]) <= LINK: seen[j] = True; stack.append(j)
        comps.append(comp)
    return comps

def kmeans(size, pts, k):
    cent = [pts[0]]
    while len(cent) < k: cent.append(max(pts, key=lambda s: min(yd(size, s, c) for c in cent)))
    for _ in range(40):
        groups = [[] for _ in cent]
        for s in pts: groups[min(range(k), key=lambda i: yd(size, s, cent[i]))].append(s)
        cent = [(sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g)) if g else cent[i] for i, g in enumerate(groups)]
    return [(round(c[0], 1), round(c[1], 1)) for c in cent]

def leg_samples(size, p, q):
    n = max(1, int(yd(size, p, q) / 5))
    return [(p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n) for t in range(n + 1)]

def crossings(legs):
    def ccw(a, b, c): return (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
    n = 0
    for i, (a, b) in enumerate(legs):
        for c, d in legs[i + 2:]:
            if a == d or b == c: continue
            if ccw(a, b, c) * ccw(a, b, d) < 0 and ccw(c, d, a) * ccw(c, d, b) < 0: n += 1
    return n

def best_loop(size, cent, ok_leg, clear):
    first, rest = cent[0], cent[1:]
    best = None
    for perm in itertools.permutations(rest):
        if len(rest) > 1 and perm[0] > perm[-1]: continue  # each loop once, not in both directions
        loop = [first] + list(perm)
        legs = list(zip(loop, loop[1:] + loop[:1]))
        if not all(ok_leg(p, q) for p, q in legs): continue
        # a leg must not run through another point's arrival circle (no doubling back through the loop)
        if any(min(yd(size, s, o) for s in leg_samples(size, p, q)) < clear
               for p, q in legs for o in loop if o != p and o != q): continue
        if crossings(legs): continue  # a loop that crosses itself is no sensible order
        L = sum(yd(size, p, q) for p, q in legs)
        if best is None or L < best[0]: best = (L, loop)
    return best[1] if best else None

# --- main -------------------------------------------------------------------------------------------
def main():
    npcs = load_upstream()
    sizes, znames = load_sizes()
    quests = bundled("Quests.lua", "Q"); items = bundled("Items.lua", "I")
    ovr = collections.defaultdict(dict)
    if os.path.exists(OVR):
        for r in csv.DictReader(open(OVR, encoding="utf-8")):
            if r["scope"] and not r["scope"].startswith("#"): ovr[r["scope"]][r["key"]] = r
    inv = list(csv.DictReader(open(INV, encoding="utf-8-sig")))
    ecache, tcache = {}, {}
    def zone_elites(zone):
        if zone not in ecache:
            ecache[zone] = [(n, p) for n, d in npcs.items() if d["rank"] > 0 for p in d["spawns"].get(zone, [])]
        return ecache[zone]
    def zone_enemy(zone, sides):
        k = (zone, sides)
        if k not in tcache:
            out = []
            for n, d in npcs.items():
                fr = d["friendly"]
                if not fr or fr == "AH": continue
                if ("A" in sides and fr == "H") or ("H" in sides and fr == "A"):
                    out += d["spawns"].get(zone, [])
            tcache[k] = out
        return tcache[k]
    # guide zone and anchor (the step before the complete step that has coordinates)
    gzone, anchors, steptext = {}, {}, {}
    for f in os.listdir(COMPILED):
        if not f.endswith(".lua") or f == "Routes.lua": continue
        gid, last = None, None
        for line in open(os.path.join(COMPILED, f), encoding="utf-8"):
            m = re.search(r'^\s*id="([^"]+)"', line)
            if m: gid = m.group(1); last = None
            m = re.search(r'^\s*minLevel=.*?zone=(\d+)', line)
            if m and gid: gzone[gid] = int(m.group(1))
            m = re.search(r',z=(\d+),x=([\d.]+),y=([\d.]+)', line)
            if m: last = (int(m.group(1)), float(m.group(2)), float(m.group(3)))
            m = re.search(r'\{"complete",q=(\d+)', line)
            if m and gid:
                anchors.setdefault((gid, int(m.group(1))), last)
                t = re.search(r',text="((?:[^"\\]|\\.)*)"', line)
                if t: steptext[int(m.group(1))] = steptext.get(int(m.group(1)), "") + " " + t.group(1)
    by_q = collections.OrderedDict()
    for r in inv:
        by_q.setdefault(int(r["quest"]), []).append(r)
    rows, routes, sigs = [], collections.defaultdict(list), {}
    handmade = set()
    for fn in os.listdir(ROUTES):
        if fn.endswith(".routes") and not fn.startswith("auto_"):
            handmade |= {int(x) for x in re.findall(r"^quest (\d+)", open(os.path.join(ROUTES, fn), encoding="utf-8").read(), re.M)}
    def items_name(i):
        it = items.get(i)
        return it[0][0] if it and isinstance(it[0][0], str) else "item %d" % i
    for q, rs in by_q.items():
        rec = quests.get(q)
        guides = sorted({r["guide"] for r in rs})
        base = {"quest": q, "title": rs[0]["title"], "guides": " ".join(guides)}
        st0 = rs[0]["status"]
        if q in handmade:
            rows.append(dict(base, obj="", kind="", targets="", zone=znames.get(gzone.get(guides[0]), ""), status="Verified and implemented", route="hand-made (guides-src/routes, not auto_)",
                             coverage="full upstream spawns, see docs/ROAMING.md", path="reviewed by hand", limits="not walked in game", validation="compiler checks + tests/test_roam.lua"))
            continue
        if not st0.startswith("candidate"):
            continue
        obj = rec[0][11] if rec and len(rec[0]) > 11 and isinstance(rec[0][11], tuple) else None
        h = obj[1] if obj else {}
        kills = [int(x) for x in h.get("c", ([], {}))[0]] if "c" in h else []
        its = [int(x) for x in h.get("i", ([], {}))[0]] if "i" in h else []
        text = (rec[0][10] if rec and isinstance(rec[0][10], str) else "") + " " + rs[0]["title"] + " " + steptext.get(q, "")
        objectives = [(i + 1, "kill", None, [n]) for i, n in enumerate(kills)] + \
                     [(i + 1, "drop", it, [int(x) for x in (items.get(it, ([None, ([], {})], {}))[0][1] or ([], {}))[0]]) for i, it in enumerate(its)]
        zone = gzone.get(guides[0])
        # the quest's own zone if the guide zone has no target spawns
        for oi, kind, item, tgt in objectives:
            row = dict(base, obj=oi, kind=kind if kind == "kill" else "drop %d" % item, zone=znames.get(zone, zone),
                       targets=" ".join("%d %s" % (n, npcs.get(n, {}).get("name", "?")) for n in tgt),
                       route="", coverage="", path="", limits="", validation="")
            key = "%d:%d" % (q, oi)
            zo = ovr["zone"].get(str(zone), {}); qo = ovr["objective"].get(key) or ovr["quest"].get(str(q))
            def done(status, **kw):
                row.update(kw); row["status"] = status; rows.append(row)
            if qo and qo["decision"] != "allow":
                done(qo["decision"], limits=qo["reason"]); continue
            if zo.get("decision", "") not in ("", "reviewed", "strict"):
                done(zo["decision"], limits=zo["reason"]); continue
            size = sizes.get(zone)
            if not size: done("Blocked — missing evidence", limits="no map size for zone %s" % zone); continue
            if kind == "drop":
                elite = [n for n in tgt if npcs.get(n, {}).get("rank", 0) > 0]
                tgt = [n for n in tgt if n not in elite and npcs.get(n, {}).get("spawns", {}).get(zone)]
                if not tgt:
                    done("Excluded — reason documented" if elite else "Blocked — missing evidence",
                         limits="only elite/rare droppers here" if elite else "no dropping NPC spawns in this zone"); continue
                row["targets"] = " ".join("%d %s" % (n, npcs[n]["name"]) for n in tgt)
            elif any(npcs.get(n, {}).get("rank", 0) > 0 for n in tgt):
                done("Excluded — reason documented", limits="elite or rare target"); continue
            sp = [(p, n) for n in tgt for p in npcs.get(n, {}).get("spawns", {}).get(zone, [])]
            if len(sp) <= 2:
                done("Static waypoint preferred" if sp else "Blocked — missing evidence",
                     limits=("fixed spawn (%d spawn record%s)" % (len(sp), "" if len(sp) == 1 else "s")) if sp else "no target spawns in the guide's zone"); continue
            if len(sp) < 6:
                done("Blocked — missing evidence", limits="only %d target spawn records in this zone" % len(sp)); continue
            if CAVE_WORDS.search(text) and not (qo and qo["decision"] == "allow"):
                done("Blocked — missing evidence", limits="objective text points to a cave/mine/indoor area; spawn data has no height"); continue
            pts = [p for p, _ in sp]
            comps = sorted(components(size, pts), key=len, reverse=True)
            anc = anchors.get((guides[0], q))
            def score(c):
                if not anc or anc[0] != zone: return len(c)
                d = min(yd(size, (anc[1], anc[2]), p) for p in c)
                return len(c) / (1 + d / 300.0)
            comp = max(comps, key=score)
            ext = max(yd(size, a, b) for a in comp for b in comp) if len(comp) > 1 else 0
            if len(comp) < MIN_SPAWNS or ext < MIN_EXTENT:
                done("Static waypoint preferred", limits="compact spawn area (%d spawns, %.0f yd across)" % (len(comp), ext)); continue
            gap = GAP_STRICT if zo.get("decision") == "strict" else GAP
            sides = "".join(sorted({g[0] for g in guides}))  # A_, H_, B(oth)
            elites = [p for n, p in zone_elites(zone) if n not in tgt]
            enemy = zone_enemy(zone, sides)
            legcache = {}
            def ok_leg(p, q2):
                key = (min(p, q2), max(p, q2))
                if key not in legcache: legcache[key] = ok_leg2(p, q2)
                return legcache[key]
            def ok_leg2(p, q2):
                for s in leg_samples(size, p, q2):
                    if min(yd(size, s, c) for c in comp) > gap: return False
                    if any(yd(size, s, e) < ELITE_CLEAR for e in elites): return False
                    if any(yd(size, s, e) < TOWN_CLEAR for e in enemy): return False
                return True
            loop = None
            k0 = max(3, min(8, int(round(ext / 70.0)) + 1))
            # Try the larger radius first, then 15 yd (more points fit an elongated area); 3-8 points.
            for R in ((20, 15) if ext >= 160 else (15,)):
                for k in sorted(range(3, 9), key=lambda k: (abs(k - k0), k)):
                    if len(comp) < k: continue
                    cent = kmeans(size, comp, k)
                    if min(yd(size, a, b) for a, b in itertools.combinations(cent, 2)) < 2 * R + 10: continue
                    loop = best_loop(size, cent, ok_leg, R + 10)
                    if loop: break
                if loop: break
            if not loop:
                done("Blocked — missing evidence", limits="no non-crossing loop keeps every leg within %d yd of target spawns and clear of elites/other-faction towns" % gap); continue
            worst = max(min(yd(size, s, c) for c in comp) for p, q2 in zip(loop, loop[1:] + loop[:1]) for s in leg_samples(size, p, q2))
            if zo.get("decision") not in ("reviewed", "strict"):
                done("Not researched", limits="proposal passes data checks; zone not reviewed yet", route="(proposal)",
                     coverage="%d spawns, worst leg gap %.0f yd" % (len(comp), worst)); continue
            tkey = frozenset(tgt)
            common = dict(coverage="%d full-upstream spawns in one area (%.0f yd across); every point a spawn-cluster centre" % (len(comp), ext),
                 path="legs sampled every 5 yd: worst %.0f yd from a target spawn (limit %d); >= %d yd from elites, >= %d yd from other-faction NPCs; zone reviewed: %s"
                      % (worst, gap, ELITE_CLEAR, TOWN_CLEAR, zo.get("reason", "")),
                 limits="spawn points only, no terrain/height data; not walked in game")
            same = next((rt for rt in routes[zone] if rt["q"] == q and rt["tkey"] == tkey), None)
            if same:  # another objective of this quest with the same targets: one route serves both
                same["objs"].append((oi, kind, item, tgt))
                done("Existing route reused — association verified", route=same["rid"], validation="same quest, same target NPCs as objective %d" % same["objs"][0][0], **common)
                continue
            first = sigs.get((zone, tkey))
            rid = "%s: %s" % (rs[0]["title"], row["targets"].split(" ", 1)[1] if kind == "kill" else items_name(item))
            if first:  # another quest hunting the same NPCs in the same area: its points are reused
                loop = first["loop"]
                routes[zone].append(dict(rid=rid, q=q, tkey=tkey, objs=[(oi, kind, item, tgt)], R=first["R"], loop=loop, n=len(comp), worst=first["worst"], ext=ext))
                done("Existing route reused — association verified", route=rid, validation="points of route '%s' (same NPCs, same area); quest/objective association checked by the compiler" % first["rid"], **common)
                continue
            rt = dict(rid=rid, q=q, tkey=tkey, objs=[(oi, kind, item, tgt)], R=R, loop=loop, n=len(comp), worst=worst, ext=ext)
            routes[zone].append(rt); sigs[(zone, tkey)] = rt
            done("Verified and implemented", route=rid,
                 coverage="%d full-upstream spawns in one area (%.0f yd across); every point a spawn-cluster centre" % (len(comp), ext),
                 path="legs sampled every 5 yd: worst %.0f yd from a target spawn (limit %d); >= %d yd from elites, >= %d yd from other-faction NPCs; zone reviewed: %s"
                      % (worst, gap, ELITE_CLEAR, TOWN_CLEAR, zo.get("reason", "")),
                 limits="spawn points only, no terrain/height data; not walked in game",
                 validation="compiler checks (tools/src/RoamRoutes.cs)")
            row.update(common)
        # extra guides for the same quest
    # reuse rows: a quest in several guides reuses its route; record each extra association
    for r in list(rows):
        gs = r["guides"].split()
        if len(gs) > 1 and r["status"] == "Verified and implemented":
            r["validation"] += "; also used by " + ", ".join(gs[1:]) + " (Existing route reused — association verified: same quest, complete step present)"
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    cols = ["quest", "obj", "title", "guides", "zone", "kind", "targets", "status", "route", "coverage", "path", "limits", "validation"]
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore"); w.writeheader(); w.writerows(rows)
    for fn in os.listdir(ROUTES):
        if fn.startswith("auto_"): os.remove(os.path.join(ROUTES, fn))
    for zone, rl in routes.items():
        size = sizes[zone]
        name = re.sub(r"[^a-z0-9]+", "_", znames[zone].lower()).strip("_")
        with open(os.path.join(ROUTES, "auto_%s.routes" % name), "w", encoding="utf-8", newline="\n") as f:
            f.write("# GENERATED by tools/research/roam_propose.py from the full QuestieDB TBC spawn list; zone reviewed in\n")
            f.write("# docs/research/roaming-overrides.csv. Each route: points are spawn-cluster centres, legs sampled every 5 yd.\n")
            f.write("# Per-objective records: docs/research/roaming-dispositions.csv. Do not edit by hand: change the overrides.\n")
            f.write("zone %s %.1fx%.1f\n" % (znames[zone], size[0], size[1]))
            for rt in sorted(rl, key=lambda x: (x["q"], x["objs"][0][0])):
                f.write("\n# %d spawns, %.0f yd across, worst leg gap %.0f yd\n" % (rt["n"], rt["ext"], rt["worst"]))
                f.write("route %s\nquest %d\n" % (rt["rid"], rt["q"]))
                for oi, kind, item, tgt in rt["objs"]:
                    f.write(("kill %d %d\n" % (oi, tgt[0])) if kind == "kill" else ("drop %d %d %s\n" % (oi, item, ",".join(str(t) for t in tgt))))
                f.write("radius %d\nloop\n" % rt["R"])
                for pt in rt["loop"]: f.write("point %.1f,%.1f\n" % pt)
                f.write("end\n")
    c = collections.Counter(r["status"] for r in rows)
    print(dict(c)); print("routes:", sum(len(v) for v in routes.values()), "in", len(routes), "zones")

if __name__ == "__main__":
    main()
