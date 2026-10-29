// TBCGuide build tooling - route optimization model / audit (tools/build.ps1 routes).
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Walks every race/class route (start guide -> @next chain -> level 70) step by step, the way a
// player would, and measures what the bundled data can actually support:
//   * correctness  - prerequisite ORDER (a prerequisite turned in later on the same route is an
//                    impossible order => error), complete/turn-in before accept, quest log over
//                    the 25-quest cap (error), duplicate pickups;
//   * XP proxies   - quests accepted while far below the estimated character level (reduced quest
//                    XP: the TBC formula scales quest XP down once the character is 6+ levels
//                    above the quest), quests gated above the estimated level, quests picked up
//                    and never turned in on the route (log space and travel for nothing);
//   * travel       - per guide: straight-line distance between consecutive located steps (zone
//                    map percent; comparable only within one zone), zone changes, and hub
//                    revisits (returning to a place already visited and left).
// The "model level" at a step comes from an XP model (see XpModel below): quest XP from QuestieDB's
// TBC quest XP table, the post-2.3 XP-to-level table, and a documented assumption for kill XP. Without
// the XP table (run `build.ps1 fetch`) it falls back to interpolating @levels. Either way it is a
// planning estimate, NOT a measurement; no XP/hour figure is ever produced.
// Output: docs/ROUTE_AUDIT.md and docs/generated/route-metrics.csv. If
// docs/generated/route-metrics-baseline.csv exists, the report compares against it.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

namespace TBCGuideTools
{
    public sealed class GuideMetrics
    {
        public string Id, Name;
        public int Steps, Quests, Located, ZoneChanges, Clusters, Revisits, LowXp, HeavyLowXp, LevelGated, Abandoned, Escort, Group;
        public double Distance;
        public double RouteDistSum; public int RouteCount; // per race/class route, only the steps that route sees
        // XP model per guide, summed over routes: model level in/out, quests-only level in/out, grind levels.
        public double XpIn, XpOut, QIn, QOut, Lift; public int XpRoutes;
        public double RouteDistance { get { return RouteCount > 0 ? RouteDistSum / RouteCount : 0; } }

        public static string Header = "guide,steps,quests,distance,zoneChanges,hubRevisits,lowXp,heavyLowXp,levelGated,abandoned,escort,group,routeDistance";
        public string Csv()
        {
            return string.Join(",", new[] { Id, Steps.ToString(), Quests.ToString(), Distance.ToString("0.0", CultureInfo.InvariantCulture),
                ZoneChanges.ToString(), Revisits.ToString(), LowXp.ToString(), HeavyLowXp.ToString(), LevelGated.ToString(),
                Abandoned.ToString(), Escort.ToString(), Group.ToString(), RouteDistance.ToString("0.0", CultureInfo.InvariantCulture) });
        }
    }

    public sealed class RouteAudit
    {
        public List<string> Errors = new List<string>();
        public List<string> Warnings = new List<string>();
        public Dictionary<string, GuideMetrics> Guides = new Dictionary<string, GuideMetrics>();
        public Dictionary<string, int> MaxLog = new Dictionary<string, int>();      // route key -> peak quest log size
        public Dictionary<string, string> MaxLogAt = new Dictionary<string, string>();
        public List<string> Findings = new List<string>();                          // per-guide detail lines
        public int Routes;
        public bool XpModel;
        public Dictionary<string, double> StepLevel = new Dictionary<string, double>(); // "source:line" -> lowest model level on arrival
        public List<string[]> Gates = new List<string[]>(); // guide, src:line, quest, title, req, model level, quests-only level, route
    }

    // ---------------------------------------------------------------- XP model
    // Inputs (all documented in docs/ROUTE_OPTIMIZATION.md):
    //  * quest XP: QuestieDB support/QuestXP/xpDB-tbc.lua, the TBC value in each line's comment
    //    ("TBC: <questLevel>: <xp>/<difficulty>"), i.e. the full reward at or below quest level + 5;
    //  * reduced quest XP above that: 80/60/40/20/10 % at +6/+7/+8/+9/+10 levels (warcraft.wiki.gg,
    //    "Experience point", Quest XP), rounded to 5;
    //  * XP to next level: the post-patch-2.3 table (warcraft.wiki.gg, "Experience to level",
    //    "pre-Wrath" table), which is the TBC Classic ruleset;
    //  * kill XP: NOT data. Assumed to add KillShare x the quest XP earned (0.5 = kills are a third
    //    of all XP), a common rule of thumb for quest-driven leveling. Discovery XP, rested XP,
    //    groups and dungeons are not counted. "level N" / "grind N" steps lift the model to N.
    public sealed class XpModel
    {
        public static readonly int[] ToNext = { 0,
            400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
            8700, 9800, 11000, 12300, 13600, 15000, 16400, 17800, 19300, 20800,
            22400, 24000, 25500, 27200, 28900, 30500, 32200, 33900, 36300, 38800,
            41600, 44600, 48000, 51400, 55000, 58700, 62400, 66200, 70200, 74300,
            78500, 82800, 87100, 91600, 96300, 101000, 105800, 110700, 115700, 120900,
            126100, 131500, 137000, 142500, 148200, 154000, 159900, 165800, 172000, 494000,
            574700, 614400, 650300, 682300, 710200, 734100, 753700, 768900, 779700 };
        public const double KillShare = 0.5;
        public Dictionary<int, int[]> Quest = new Dictionary<int, int[]>(); // id -> { questLevel, xp }

        public static XpModel Load(string root)
        {
            string p = Path.Combine(root, ".cache", "upstream", "questiedb", "support", "QuestXP", "xpDB-tbc.lua");
            if (!File.Exists(p)) return null;
            var m = new XpModel();
            var rx = new System.Text.RegularExpressions.Regex(@"^\s*\[(\d+)\]\s*=\s*\{[^}]*\},.*TBC:\s*(-?\d+):\s*(\d+)/");
            foreach (var line in File.ReadLines(p))
            {
                var mm = rx.Match(line);
                if (mm.Success) m.Quest[int.Parse(mm.Groups[1].Value)] = new[] { int.Parse(mm.Groups[2].Value), int.Parse(mm.Groups[3].Value) };
            }
            return m.Quest.Count > 0 ? m : null;
        }

        public int Reward(int quest, int level)
        {
            int[] q;
            if (!Quest.TryGetValue(quest, out q) || q[1] <= 0) return 0;
            int diff = level - q[0];
            double f = diff <= 5 ? 1 : diff == 6 ? 0.8 : diff == 7 ? 0.6 : diff == 8 ? 0.4 : diff == 9 ? 0.2 : 0.1;
            return (int)(Math.Round(q[1] * f / 5) * 5);
        }

        // Character progress along a route.
        public sealed class State
        {
            public int Level = 1; public double Xp; public int QLevel = 1; public double QXp; // QLevel/QXp: quests only
            public int Grinds;
            static void Add(ref int level, ref double xp, double gain)
            {
                xp += gain;
                while (level < 70 && xp >= ToNext[level]) { xp -= ToNext[level]; level++; }
            }
            public void TurnIn(XpModel m, int quest)
            {
                int r = m.Reward(quest, Level);
                Add(ref Level, ref Xp, r * (1 + KillShare));
                Add(ref QLevel, ref QXp, m.Reward(quest, QLevel));
            }
            public double Lifted; // levels added by level/grind steps (the grinding the quests leave)
            public void Reach(int level)
            {
                if (Level < level) { Lifted += level - Exact; Level = level; Xp = 0; Grinds++; }
                if (QLevel < level) { QLevel = level; QXp = 0; }
            }
            public double Exact { get { return Level + (Level < 70 ? Xp / ToNext[Level] : 0); } }
            public double QExact { get { return QLevel + (QLevel < 70 ? QXp / ToNext[QLevel] : 0); } }
        }
    }

    public static class RouteAnalyzer
    {
        const int LogCap = 25;          // TBC quest log size
        const int LogWarn = 22;
        const double HubRadius = 3.5;
        const double ZoneChangeCost = 25;   // per-route travel: a zone change, as a fixed approximation   // map percent: steps closer than this are "the same place"

        static bool StepApplies(CStep s, string race, string cls, string faction)
        {
            if (s.Races != null && !s.Races.Contains(race)) return false;
            if (s.Classes != null && !s.Classes.Contains(cls)) return false;
            if (s.Faction != null && s.Faction != faction) return false;
            return true;
        }

        // Piecewise-linear estimate anchored on @levels and on the guide's own "level N" checkpoints.
        static readonly Dictionary<CGuide, double[]> estCache = new Dictionary<CGuide, double[]>();
        static double EstLevel(CGuide g, int i)
        {
            double[] est;
            if (!estCache.TryGetValue(g, out est))
            {
                int n = g.Steps.Count;
                var anchors = new List<KeyValuePair<int, double>> { new KeyValuePair<int, double>(0, g.MinLevel) };
                for (int k = 0; k < n; k++)
                    if ((g.Steps[k].Kind == "level" || g.Steps[k].Kind == "grind") && g.Steps[k].Level > 0) anchors.Add(new KeyValuePair<int, double>(k, g.Steps[k].Level));
                if (anchors[anchors.Count - 1].Key < n - 1) anchors.Add(new KeyValuePair<int, double>(n - 1, Math.Max(g.MaxLevel, anchors[anchors.Count - 1].Value)));
                est = new double[n];
                for (int a = 0; a + 1 < anchors.Count; a++)
                {
                    int k0 = anchors[a].Key, k1 = anchors[a + 1].Key;
                    double v0 = anchors[a].Value, v1 = Math.Max(v0, anchors[a + 1].Value);
                    for (int k = k0; k <= k1 && k < n; k++) est[k] = k1 == k0 ? v1 : v0 + (v1 - v0) * (k - k0) / (double)(k1 - k0);
                }
                estCache[g] = est;
            }
            return i < est.Length ? est[i] : g.MaxLevel;
        }

        public static RouteAudit Run(string root, string addOnDir)
        {
            var comp = GuideCompiler.CompileAll(Path.Combine(root, "guides-src"), addOnDir, false);
            var a = new RouteAudit();
            foreach (var e in comp.Errors) a.Errors.Add("compile: " + e);
            var db = comp.Db;
            foreach (var g in comp.Guides) a.Guides[g.Id] = Travel(g, db);

            // Quests turned in anywhere on a route are known per route; pre-compute positions.
            var combos = Validator.LoadCombos(addOnDir);
            var xpm = XpModel.Load(root);
            a.XpModel = xpm != null;
            var lowXpSeen = new HashSet<string>();
            var gatedSeen = new HashSet<string>();
            var abandonedSeen = new HashSet<string>();
            foreach (var c in combos)
            {
                string race = c.Item1, cls = c.Item2, faction = c.Item3;
                var route = Validator.Route(comp.Guides, race, cls, faction);
                string key = race + "/" + cls;
                a.Routes++;
                // Flatten the applicable steps.
                var flat = new List<Tuple<CGuide, int, CStep>>();
                foreach (var g in route.Guides)
                    for (int i = 0; i < g.Steps.Count; i++)
                        if (StepApplies(g.Steps[i], race, cls, faction)) flat.Add(Tuple.Create(g, i, g.Steps[i]));
                // Per-route travel: what this race/class actually walks in each guide. Same metric as
                // Travel(): straight lines in zone-map percent, zone changes cost ZoneChangeCost.
                foreach (var grp in flat.GroupBy(f => f.Item1))
                {
                    double d = 0; int lz = -1; double px = 0, py = 0;
                    foreach (var f in grp)
                    {
                        var st = f.Item3;
                        if (st.X < 0 || st.Zone <= 0) continue;
                        if (lz == st.Zone) d += Math.Sqrt((st.X - px) * (st.X - px) + (st.Y - py) * (st.Y - py));
                        else if (lz > 0) d += ZoneChangeCost;
                        lz = st.Zone; px = st.X; py = st.Y;
                    }
                    var gm2 = a.Guides[grp.Key.Id];
                    gm2.RouteDistSum += d; gm2.RouteCount++;
                }
                var turninPos = new Dictionary<int, int>();
                for (int k = 0; k < flat.Count; k++)
                    if (flat[k].Item3.Kind == "turnin" && flat[k].Item3.Quest > 0 && !turninPos.ContainsKey(flat[k].Item3.Quest))
                        turninPos[flat[k].Item3.Quest] = k;

                var xs = new XpModel.State();
                CGuide xg = null; double xin = 0, qin = 0, lin = 0;
                Action closeGuide = () =>
                {
                    if (xg == null || xpm == null) return;
                    var m = a.Guides[xg.Id];
                    m.XpIn += xin; m.XpOut += xs.Exact; m.QIn += qin; m.QOut += xs.QExact; m.Lift += xs.Lifted - lin; m.XpRoutes++;
                };
                var log = new Dictionary<int, string>();   // quest -> guide id where accepted
                var done = new HashSet<int>();
                int peak = 0; string peakAt = "";
                for (int k = 0; k < flat.Count; k++)
                {
                    var g = flat[k].Item1; var s = flat[k].Item3; int q = s.Quest;
                    if (g != xg) { closeGuide(); xg = g; xin = xs.Exact; qin = xs.QExact; lin = xs.Lifted; }
                    if (xpm != null)
                    {
                        string sk = g.Source + ":" + s.Line;
                        double cur; double lv = xs.Exact;
                        if (!a.StepLevel.TryGetValue(sk, out cur) || lv < cur) a.StepLevel[sk] = lv;
                    }
                    if ((s.Kind == "level" || s.Kind == "grind") && s.Level > 0) { xs.Reach(s.Level); continue; }
                    if (q <= 0) continue;
                    string where = g.Id + " (" + (s.Title ?? q.ToString()) + ") [" + g.Source + ":" + s.Line + "]";
                    LTable rec; db.Quests.TryGetValue(q, out rec);
                    if (s.Kind == "accept")
                    {
                        if (done.Contains(q) && !Repeatable(rec)) { a.Warnings.Add(key + ": " + where + ": accepts a quest already turned in"); continue; }
                        if (log.ContainsKey(q)) { a.Warnings.Add(key + ": " + where + ": duplicate pickup (already in log)"); continue; }
                        if (rec != null)
                        {
                            foreach (var p in BundledDb.Ids(rec, BundledDb.Q_PREG))
                            {
                                int pos;
                                if (!done.Contains(p) && turninPos.TryGetValue(p, out pos) && pos > k)
                                    a.Errors.Add(key + ": " + where + ": prerequisite " + p + " is turned in LATER on this route (impossible order) " + At(flat[pos]));
                            }
                            var single = BundledDb.Ids(rec, BundledDb.Q_PRES);
                            if (single.Count > 0 && !single.Any(done.Contains))
                            {
                                int pos;
                                var later = single.Where(p => turninPos.TryGetValue(p, out pos) && pos > k).ToList();
                                if (later.Count > 0)
                                    a.Errors.Add(key + ": " + where + ": all prerequisites (any of " + string.Join("/", single.Select(x => x.ToString()).ToArray()) + ") come LATER on this route " + At(flat[turninPos[later[0]]]));
                            }
                            double est = xpm != null ? xs.Exact : EstLevel(g, flat[k].Item2);
                            int req = BundledDb.Num(rec, BundledDb.Q_REQ), ql = BundledDb.Num(rec, BundledDb.Q_LEVEL);
                            var gm = a.Guides[g.Id];
                            string tag = g.Id + "#" + q;
                            bool gated = xpm != null ? req > xs.Level : req > est + 1.0;
                            if (gated && gatedSeen.Add(tag))
                            {
                                gm.LevelGated++;
                                a.Gates.Add(new[] { g.Id, g.Source + ":" + s.Line, q.ToString(), s.Title, req.ToString(), est.ToString("0.0", CultureInfo.InvariantCulture),
                                    xpm != null ? xs.QLevel.ToString() : "", key });
                                a.Findings.Add(g.Id + ": level-gated pickup: " + s.Title + " (" + q + ") needs " + req + ", model level " + est.ToString("0.0", CultureInfo.InvariantCulture)
                                    + (xpm != null ? " (quests only: " + xs.QLevel + ")" : "") + " [" + g.Source + ":" + s.Line + ", " + key + "]");
                            }
                            if (ql > 0 && est - ql >= 6 && !s.Optional && lowXpSeen.Add(tag))
                            {
                                gm.LowXp++;
                                if (est - ql >= 8) gm.HeavyLowXp++;
                                a.Findings.Add(g.Id + ": reduced-XP quest: " + s.Title + " (" + q + ", level " + ql + ") at estimated level " + est.ToString("0.0", CultureInfo.InvariantCulture));
                            }
                        }
                        log[q] = g.Id;
                        if (log.Count > peak) { peak = log.Count; peakAt = where; }
                    }
                    else if (s.Kind == "turnin")
                    {
                        // Dungeon quest XP is left out: gates must hold for players who skip dungeons.
                        if (xpm != null && s.Dungeon == null && !done.Contains(q) && (log.ContainsKey(q) || StartsFromItem(rec))) xs.TurnIn(xpm, q);
                        if (!log.ContainsKey(q) && !done.Contains(q) && !StartsFromItem(rec) && !s.Optional)
                            a.Warnings.Add(key + ": " + where + ": turn-in of a quest never accepted on this route");
                        log.Remove(q);
                        done.Add(q);
                    }
                    else if (s.Kind == "complete")
                    {
                        if (!log.ContainsKey(q) && !done.Contains(q) && !StartsFromItem(rec))
                            a.Errors.Add(key + ": " + where + ": complete step before the quest is accepted");
                    }
                }
                closeGuide();
                a.MaxLog[key] = peak; a.MaxLogAt[key] = peakAt;
                if (peak > LogCap) a.Errors.Add(key + ": quest log would hold " + peak + " quests (cap " + LogCap + ") at " + peakAt);
                else if (peak > LogWarn) a.Warnings.Add(key + ": quest log peaks at " + peak + "/" + LogCap + " at " + peakAt);
                foreach (var kv in log)
                {
                    if (abandonedSeen.Add(kv.Value + "#" + kv.Key))
                    {
                        a.Guides[kv.Value].Abandoned++;
                        a.Findings.Add(kv.Value + ": accepted but never turned in on the route: " + kv.Key + " " + BundledDb.Str(db.Quests.ContainsKey(kv.Key) ? db.Quests[kv.Key] : null, BundledDb.Q_NAME));
                    }
                }
            }
            // De-duplicate route-level messages that repeat for every class of a race.
            a.Errors = a.Errors.Distinct().ToList();
            a.Warnings = a.Warnings.Distinct().ToList();
            return a;
        }

        static string At(Tuple<CGuide, int, CStep> f) { return "(turned in at " + f.Item1.Source + ":" + f.Item3.Line + ")"; }

        static bool Repeatable(LTable rec) { return rec != null && (BundledDb.Num(rec, BundledDb.Q_SPECIAL) & 1) != 0; }
        static bool StartsFromItem(LTable rec) { return rec != null && BundledDb.Ids(rec, BundledDb.Q_SITEM).Count > 0; }

        // Travel metrics for one guide, over all of its located steps (class/race filters ignored).
        static GuideMetrics Travel(CGuide g, BundledDb db)
        {
            var m = new GuideMetrics { Id = g.Id, Name = g.Name, Steps = g.Steps.Count };
            m.Quests = g.Steps.Where(s => s.Quest > 0).Select(s => s.Quest).Distinct().Count();
            var centers = new List<double[]>(); // zone, x, y
            int lastCluster = -1, lastZone = -1;
            double lx = 0, ly = 0;
            var visits = new Dictionary<int, int>();
            foreach (var s in g.Steps)
            {
                if (s.Kind == "accept" && s.Quest > 0)
                {
                    LTable rec;
                    if (db.Quests.TryGetValue(s.Quest, out rec) && (BundledDb.Num(rec, 26) & 2) != 0) m.Escort++;
                }
                if (s.Elite || s.Group >= 0 || s.Dungeon != null) m.Group++;
                if (s.X < 0 || s.Zone <= 0) continue;
                // complete-steps point at objective areas: counted for distance, not for hubs.
                m.Located++;
                if (lastZone == s.Zone) m.Distance += Math.Sqrt((s.X - lx) * (s.X - lx) + (s.Y - ly) * (s.Y - ly));
                else if (lastZone > 0) m.ZoneChanges++;
                lastZone = s.Zone; lx = s.X; ly = s.Y;
                if (s.Kind != "accept" && s.Kind != "turnin") { lastCluster = -2; continue; }
                int ci = -1;
                for (int i = 0; i < centers.Count; i++)
                {
                    var c = centers[i];
                    if ((int)c[0] == s.Zone && Math.Abs(c[1] - s.X) < HubRadius && Math.Abs(c[2] - s.Y) < HubRadius) { ci = i; break; }
                }
                if (ci < 0) { centers.Add(new[] { s.Zone, s.X, s.Y }); ci = centers.Count - 1; }
                if (ci != lastCluster)
                {
                    int v; visits.TryGetValue(ci, out v); visits[ci] = v + 1;
                }
                lastCluster = ci;
            }
            m.Clusters = centers.Count;
            m.Revisits = visits.Values.Sum(v => v - 1);
            return m;
        }

        // ---------------------------------------------------------------- report
        public static Dictionary<string, string[]> ReadCsv(string path)
        {
            var r = new Dictionary<string, string[]>();
            if (!File.Exists(path)) return r;
            foreach (var line in File.ReadAllLines(path).Skip(1))
            {
                var f = line.Split(',');
                if (f.Length > 1) r[f[0]] = f;
            }
            return r;
        }

        public static void Write(string root, RouteAudit a)
        {
            string gen = Path.Combine(root, "docs", "generated");
            Directory.CreateDirectory(gen);
            var csv = new List<string> { GuideMetrics.Header };
            csv.AddRange(a.Guides.Values.OrderBy(m => m.Id, StringComparer.Ordinal).Select(m => m.Csv()));
            File.WriteAllLines(Path.Combine(gen, "route-metrics.csv"), csv.ToArray());
            var gates = new List<string> { "guide,source,quest,title,requiredLevel,modelLevel,questsOnlyLevel,route" };
            gates.AddRange(a.Gates.Select(x => string.Join(",", x.Select(v => "\"" + (v ?? "").Replace("\"", "'") + "\"").ToArray())));
            File.WriteAllLines(Path.Combine(gen, "level-gates.csv"), gates.ToArray());
            var lv = new List<string> { "step,modelLevel" };
            lv.AddRange(a.StepLevel.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => x.Key + "," + x.Value.ToString("0.00", CultureInfo.InvariantCulture)));
            File.WriteAllLines(Path.Combine(gen, "step-levels.csv"), lv.ToArray());
            var baseline = ReadCsv(Path.Combine(gen, "route-metrics-baseline.csv"));
            // XP per guide (averages over the race/class routes that walk it).
            var gx = new List<string> { "guide,routes,modelIn,modelOut,questsOnlyIn,questsOnlyOut,grindLevels" };
            Func<double, string> F = v => v.ToString("0.00", CultureInfo.InvariantCulture);
            foreach (var m in a.Guides.Values.Where(m => m.XpRoutes > 0).OrderBy(m => m.Id, StringComparer.Ordinal))
            {
                double n = m.XpRoutes;
                gx.Add(m.Id + "," + m.XpRoutes + "," + F(m.XpIn / n) + "," + F(m.XpOut / n) + "," + F(m.QIn / n) + "," + F(m.QOut / n) + "," + F(m.Lift / n));
            }
            File.WriteAllLines(Path.Combine(gen, "guide-xp.csv"), gx.ToArray());

            var sb = new StringBuilder();
            sb.AppendLine("# Route audit");
            sb.AppendLine();
            sb.AppendLine("Generated by `tools/build.ps1 routes` (tools/src/RouteAnalyzer.cs). Do not edit by hand.");
            sb.AppendLine();
            sb.AppendLine(a.XpModel
                ? "Every race/class route is walked step by step. **Model level** comes from the XP model: QuestieDB's TBC quest XP for each turn-in, the post-2.3 XP-to-level table, plus an ASSUMED kill XP of half the quest XP (no rested, discovery, group or dungeon XP; dungeon quest turn-ins add nothing). `level`/`grind` steps lift it to their level. It is a planning estimate, not a measurement. Distances are straight lines in zone-map percent, comparable only within the same guide. Method and limits: `docs/ROUTE_OPTIMIZATION.md`."
                : "Every race/class route is walked step by step. **Estimated level** interpolates between each guide's `@levels` and its own `level N` checkpoints (the XP table was not found; run `build.ps1 fetch`). It is a planning estimate, not a measurement. Distances are straight lines in zone-map percent, comparable only within the same guide. Method and limits: `docs/ROUTE_OPTIMIZATION.md`.");
            sb.AppendLine();
            sb.AppendLine("## Summary");
            sb.AppendLine();
            sb.AppendLine("| Check | Result |");
            sb.AppendLine("|---|---|");
            sb.AppendLine("| Routes walked | " + a.Routes + " |");
            sb.AppendLine("| Order errors (prerequisite later, complete before accept, log over cap) | " + a.Errors.Count + " |");
            sb.AppendLine("| Warnings | " + a.Warnings.Count + " |");
            sb.AppendLine("| Peak quest log (worst route) | " + (a.MaxLog.Count > 0 ? a.MaxLog.Values.Max() : 0) + " / " + LogCap + " |");
            sb.AppendLine("| Reduced-XP pickups (6+ levels below estimate) | " + a.Guides.Values.Sum(m => m.LowXp) + " |");
            sb.AppendLine("| Level-gated pickups | " + a.Guides.Values.Sum(m => m.LevelGated) + " |");
            sb.AppendLine("| Accepted, never turned in | " + a.Guides.Values.Sum(m => m.Abandoned) + " |");
            sb.AppendLine("| Hub revisits (all guides) | " + a.Guides.Values.Sum(m => m.Revisits) + " |");
            sb.AppendLine();
            sb.AppendLine("## Per guide");
            sb.AppendLine();
            bool cmp = baseline.Count > 0;
            sb.AppendLine(cmp ? "Values in brackets are the baseline (`docs/generated/route-metrics-baseline.csv`, the 0.1.0 routes)." : "No baseline file found.");
            sb.AppendLine();
            sb.AppendLine("| Guide | Steps | Quests | Distance | Per-character travel | Hub revisits | Reduced-XP | Level-gated | Never turned in | Escort/event | Group |");
            sb.AppendLine("|---|---|---|---|---|---|---|---|---|---|---|");
            foreach (var m in a.Guides.Values.OrderBy(x => x.Id, StringComparer.Ordinal))
            {
                string[] b; baseline.TryGetValue(m.Id, out b);
                Func<object, int, string> cell = (v, col) =>
                {
                    string s = v is double ? ((double)v).ToString("0", CultureInfo.InvariantCulture) : v.ToString();
                    if (b == null || col >= b.Length) return s;
                    string bv = b[col];
                    double d; if (double.TryParse(bv, NumberStyles.Float, CultureInfo.InvariantCulture, out d)) bv = d.ToString("0", CultureInfo.InvariantCulture);
                    return bv == s ? s : s + " (" + bv + ")";
                };
                sb.AppendLine(string.Format("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |", m.Id,
                    cell(m.Steps, 1), cell(m.Quests, 2), cell(m.Distance, 3), cell(m.RouteDistance, 12), cell(m.Revisits, 5), cell(m.LowXp, 6),
                    cell(m.LevelGated, 8), cell(m.Abandoned, 9), cell(m.Escort, 10), cell(m.Group, 11)));
            }
            sb.AppendLine();
            sb.AppendLine("## Peak quest log per route");
            sb.AppendLine();
            sb.AppendLine("| Route | Peak | At |");
            sb.AppendLine("|---|---|---|");
            foreach (var kv in a.MaxLog.OrderByDescending(x => x.Value).ThenBy(x => x.Key).Take(15))
                sb.AppendLine("| " + kv.Key + " | " + kv.Value + " | " + a.MaxLogAt[kv.Key].Replace("|", "/") + " |");
            sb.AppendLine();
            sb.AppendLine("## Errors");
            sb.AppendLine();
            if (a.Errors.Count == 0) sb.AppendLine("None.");
            foreach (var e in a.Errors.Take(200)) sb.AppendLine("- " + e);
            sb.AppendLine();
            sb.AppendLine("## Warnings");
            sb.AppendLine();
            if (a.Warnings.Count == 0) sb.AppendLine("None.");
            foreach (var w in a.Warnings.Take(300)) sb.AppendLine("- " + w);
            sb.AppendLine();
            sb.AppendLine("## Findings (per guide)");
            sb.AppendLine();
            foreach (var f in a.Findings.Distinct().OrderBy(x => x, StringComparer.Ordinal)) sb.AppendLine("- " + f);
            File.WriteAllText(Path.Combine(root, "docs", "ROUTE_AUDIT.md"), sb.ToString(), new UTF8Encoding(false));
        }
    }
}
