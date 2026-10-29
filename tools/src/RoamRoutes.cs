// TBCGuide - roaming hunting routes: parses guides-src/routes/*.routes, checks them against the bundled
// database and writes TBCGuide/Guides/Compiled/Routes.lua (docs/ROAMING.md).
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// A route belongs to one quest and one or more of its objectives (log objective index), each a kill
// of listed NPCs or an item that the listed NPCs drop. The checks are what the data can prove:
//   * the quest exists, the objective index fits, kill NPCs are the quest's kill targets and drop NPCs
//     really drop the item (Items: NPC drops);
//   * a quest with both kill and item objectives is rejected (its log order cannot be checked here);
//   * every point is within POINT_MAX yards of a bundled spawn of a target in the route's zone, and
//     every leg's midpoint within LEG_MAX yards (the bundled data keeps 10 spawns per NPC; the full
//     upstream check is the research step in docs/ROAMING.md);
//   * points are far enough apart that their arrival circles never overlap (2 x radius + 10 yards).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    public sealed class RoamObjective { public int Index; public string Kind; public int Item; public List<int> Npcs = new List<int>(); }
    public sealed class RoamPoint { public double X, Y, R; public string Note; }

    public sealed class RoamRoute
    {
        public string Name, Where; public int Quest, Zone; public double W, H, Radius; public bool Loop;
        public List<RoamObjective> Objs = new List<RoamObjective>();
        public List<RoamPoint> Points = new List<RoamPoint>();
    }

    public static class RoamRoutes
    {
        const double POINT_MAX = 130, LEG_MAX = 160, R_MIN = 10, R_MAX = 40;  // coarse: bundled data keeps 10 spawns per NPC
        const int P_MIN = 3, P_MAX = 12;
        static readonly Regex Coord = new Regex(@"^(\d{1,2}(?:\.\d+)?)\s*,\s*(\d{1,2}(?:\.\d+)?)(?:\s+r=(\d+))?$");

        public static List<RoamRoute> Compile(string srcDir, CompileResult res)
        {
            var routes = new List<RoamRoute>();
            string dir = Path.Combine(srcDir, "routes");
            if (!Directory.Exists(dir)) return routes;
            foreach (var f in Directory.GetFiles(dir, "*.routes").OrderBy(x => x, StringComparer.Ordinal))
                Parse(f, "routes/" + Path.GetFileName(f), res, routes);
            foreach (var r in routes) Check(r, res);
            // A route is only useful on a guide's complete step for its quest.
            var onGuide = new HashSet<int>(res.Guides.SelectMany(g => g.Steps).Where(s => s.Kind == "complete").Select(s => s.Quest));
            foreach (var r in routes)
                if (!onGuide.Contains(r.Quest)) res.Warnings.Add(r.Where + ": quest " + r.Quest + " has no complete step in any guide");
            return routes;
        }

        static double Num(string s) { return double.Parse(s, CultureInfo.InvariantCulture); }

        static void Parse(string path, string rel, CompileResult res, List<RoamRoute> routes)
        {
            int zone = 0; double w = 0, h = 0; RoamRoute cur = null; int ln = 0;
            foreach (var raw in File.ReadLines(path))
            {
                ln++;
                string where = rel + ":" + ln;
                string line = raw; int hash = line.IndexOf('#');
                string note = null;
                int bar = line.IndexOf(" | ", StringComparison.Ordinal);
                if (bar >= 0) { note = line.Substring(bar + 3).Trim(); line = line.Substring(0, bar); }
                else if (hash >= 0) line = line.Substring(0, hash);
                line = line.Trim();
                if (line.Length == 0) continue;
                int sp = line.IndexOf(' ');
                string verb = (sp < 0 ? line : line.Substring(0, sp)).ToLowerInvariant();
                string arg = sp < 0 ? "" : line.Substring(sp + 1).Trim();
                if (verb == "zone")
                {
                    var m = Regex.Match(arg, @"^(.+?)\s+([\d.]+)x([\d.]+)$");
                    if (!m.Success || !res.Db.ZoneByName.TryGetValue(m.Groups[1].Value, out zone)) { res.Errors.Add(where + ": zone needs '<zone name> <width>x<height>' (yards)"); continue; }
                    w = Num(m.Groups[2].Value); h = Num(m.Groups[3].Value);
                    continue;
                }
                if (verb == "route")
                {
                    if (cur != null) res.Errors.Add(where + ": route without 'end' before it");
                    if (zone == 0) res.Errors.Add(where + ": route before a zone line");
                    cur = new RoamRoute { Name = arg, Where = where, Zone = zone, W = w, H = h };
                    continue;
                }
                if (cur == null) { res.Errors.Add(where + ": '" + verb + "' outside a route"); continue; }
                switch (verb)
                {
                    case "quest": int q; if (int.TryParse(arg, out q)) cur.Quest = q; else res.Errors.Add(where + ": quest needs an id"); break;
                    case "radius": cur.Radius = Num(arg); break;
                    case "loop": cur.Loop = true; break;
                    case "kill":
                    case "drop":
                    {
                        var parts = arg.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                        var o = new RoamObjective { Kind = verb };
                        int need = verb == "kill" ? 2 : 3;
                        if (parts.Length != need || !int.TryParse(parts[0], out o.Index)) { res.Errors.Add(where + ": " + (verb == "kill" ? "kill <objective> <npc,...>" : "drop <objective> <item> <npc,...>")); break; }
                        if (verb == "drop" && !int.TryParse(parts[1], out o.Item)) { res.Errors.Add(where + ": bad item id"); break; }
                        foreach (var n in parts[need - 1].Split(',')) { int id; if (int.TryParse(n, out id)) o.Npcs.Add(id); else res.Errors.Add(where + ": bad NPC id '" + n + "'"); }
                        cur.Objs.Add(o);
                        break;
                    }
                    case "point":
                    {
                        var m = Coord.Match(arg);
                        if (!m.Success) { res.Errors.Add(where + ": point needs x,y [r=yards]"); break; }
                        cur.Points.Add(new RoamPoint { X = Num(m.Groups[1].Value), Y = Num(m.Groups[2].Value), R = m.Groups[3].Success ? Num(m.Groups[3].Value) : 0, Note = note });
                        break;
                    }
                    case "end": routes.Add(cur); cur = null; break;
                    default: res.Errors.Add(where + ": unknown route line '" + verb + "'"); break;
                }
            }
            if (cur != null) res.Errors.Add(rel + ": route '" + cur.Name + "' has no 'end'");
        }

        static double Yd(RoamRoute r, double x1, double y1, double x2, double y2)
        {
            double dx = (x1 - x2) / 100 * r.W, dy = (y1 - y2) / 100 * r.H;
            return Math.Sqrt(dx * dx + dy * dy);
        }

        static void Check(RoamRoute r, CompileResult res)
        {
            var db = res.Db;
            string w = r.Where + " (" + r.Name + ")";
            LTable rec;
            if (!db.Quests.TryGetValue(r.Quest, out rec)) { res.Errors.Add(w + ": unknown quest " + r.Quest); return; }
            var obj = BundledDb.Tab(rec, BundledDb.Q_OBJ);
            var kills = obj == null ? new List<int>() : (obj.Get("c") as LTable ?? new LTable()).IntList();
            var items = obj == null ? new List<int>() : (obj.Get("i") as LTable ?? new LTable()).IntList();
            var objects = obj == null ? new List<int>() : (obj.Get("o") as LTable ?? new LTable()).IntList();
            if (kills.Count > 0 && (items.Count > 0 || objects.Count > 0))
                res.Errors.Add(w + ": quest " + r.Quest + " mixes kill and other objectives; its log order cannot be checked");
            if (r.Objs.Count == 0) res.Errors.Add(w + ": no kill/drop objective");
            if (r.Radius < R_MIN || r.Radius > R_MAX) res.Errors.Add(w + ": radius must be " + R_MIN + "-" + R_MAX + " yards");
            if (!r.Loop) res.Errors.Add(w + ": only looping routes are supported (add 'loop')");
            if (r.Points.Count < P_MIN || r.Points.Count > P_MAX) res.Errors.Add(w + ": needs " + P_MIN + "-" + P_MAX + " points");
            if (r.W <= 0 || r.H <= 0) res.Errors.Add(w + ": zone size missing");
            var spawns = new List<double[]>();
            foreach (var o in r.Objs)
            {
                if (o.Kind == "kill")
                {
                    if (o.Index < 1 || o.Index > kills.Count) res.Errors.Add(w + ": quest " + r.Quest + " has no kill objective " + o.Index);
                    else if (o.Npcs.Count != 1 || o.Npcs[0] != kills[o.Index - 1])
                        res.Errors.Add(w + ": kill objective " + o.Index + " is NPC " + kills[o.Index - 1] + " (" + db.NpcName(kills[o.Index - 1]) + ")");
                }
                else
                {
                    if (o.Index < 1 || o.Index > items.Count || items[o.Index - 1] != o.Item) res.Errors.Add(w + ": item objective " + o.Index + " is not item " + o.Item);
                    LTable it;
                    var drops = db.Items.TryGetValue(o.Item, out it) ? BundledDb.Ids(it, BundledDb.I_NPCDROPS) : new List<int>();
                    foreach (var n in o.Npcs)
                        if (!drops.Contains(n)) res.Errors.Add(w + ": NPC " + n + " (" + db.NpcName(n) + ") does not drop item " + o.Item);
                }
                foreach (var n in o.Npcs)
                {
                    var here = db.NpcSpawns(n).Where(s => (int)s[0] == r.Zone).ToList();
                    if (here.Count == 0) res.Errors.Add(w + ": NPC " + n + " (" + db.NpcName(n) + ") has no spawns in this zone");
                    spawns.AddRange(here);
                }
            }
            if (spawns.Count == 0) return;
            Func<double, double, double> near = (x, y) => spawns.Min(s => Yd(r, x, y, s[1], s[2]));
            for (int i = 0; i < r.Points.Count; i++)
            {
                var p = r.Points[i];
                double rad = p.R > 0 ? p.R : r.Radius;
                if (p.R > 0 && (p.R < R_MIN || p.R > R_MAX)) res.Errors.Add(w + ": point " + (i + 1) + " radius must be " + R_MIN + "-" + R_MAX);
                double d = near(p.X, p.Y);
                if (d > POINT_MAX) res.Errors.Add(w + ": point " + (i + 1) + " is " + Math.Round(d) + " yd from any known spawn of its targets");
                var q = r.Points[(i + 1) % r.Points.Count];
                double m = near((p.X + q.X) / 2, (p.Y + q.Y) / 2);
                if (m > LEG_MAX) res.Errors.Add(w + ": the leg from point " + (i + 1) + " passes " + Math.Round(m) + " yd from any known spawn");
                for (int j = i + 1; j < r.Points.Count; j++)
                {
                    var o2 = r.Points[j];
                    double need = rad + (o2.R > 0 ? o2.R : r.Radius) + 10;
                    double dd = Yd(r, p.X, p.Y, o2.X, o2.Y);
                    if (dd < need) res.Errors.Add(w + ": points " + (i + 1) + " and " + (j + 1) + " are " + Math.Round(dd) + " yd apart; need " + need + " so arrival circles cannot overlap");
                }
            }
        }

        public static string Lua(List<RoamRoute> routes, BundledDb db)
        {
            var sb = new StringBuilder();
            sb.Append("-- TBCGuide - roaming hunting routes. GENERATED from guides-src/routes by tools/build.ps1 guides.\n");
            sb.Append("-- DO NOT EDIT: edit the .routes source and rebuild. Route points come from QuestieDB-derived spawn data\n");
            sb.Append("-- (docs/ROAMING.md); the route selection and order are original TBCGuide content (GPL-3.0-only).\n");
            sb.Append("local _, ns = ...\nns.RoamRoutes = {\n");
            foreach (var g in routes.GroupBy(r => r.Quest).OrderBy(g => g.Key))
            {
                sb.Append("  [" + g.Key + "] = {\n");
                foreach (var r in g)
                {
                    sb.Append("    { name=" + LuaWriter.Str(r.Name) + ", zone=" + r.Zone + ", r=" + Fmt(r.Radius) + ", loop=" + (r.Loop ? "true" : "false") + ",\n");
                    sb.Append("      objs={");
                    sb.Append(string.Join(",", r.Objs.Select(o => "{i=" + o.Index + ",kind=" + LuaWriter.Str(o.Kind) + (o.Item > 0 ? ",item=" + o.Item : "")
                        + ",name=" + LuaWriter.Str(ObjName(db, o) ?? "")
                        + ",npcs={" + string.Join(",", o.Npcs.Select(n => n.ToString(CultureInfo.InvariantCulture)).ToArray()) + "}}").ToArray()));
                    sb.Append("},\n      pts={");
                    sb.Append(string.Join(",", r.Points.Select(p => "{" + Fmt(p.X) + "," + Fmt(p.Y) + (p.R > 0 ? ",r=" + Fmt(p.R) : "") + (p.Note != null ? ",note=" + LuaWriter.Str(p.Note) : "") + "}").ToArray()));
                    sb.Append("} },\n");
                }
                sb.Append("  },\n");
            }
            sb.Append("}\n");
            return sb.ToString();
        }

        // The English name the quest log shows for this objective: the NPC (kills) or the item (drops).
        static string ObjName(BundledDb db, RoamObjective o)
        {
            if (o.Kind == "kill") return o.Npcs.Count > 0 ? db.NpcName(o.Npcs[0]) : null;
            LTable it;
            return db.Items.TryGetValue(o.Item, out it) ? BundledDb.Str(it, BundledDb.I_NAME) : null;
        }

        static string Fmt(double v) { return v.ToString("0.###", CultureInfo.InvariantCulture); }

        static readonly Regex EventWords = new Regex(@"\b(escort|protect|defend|survive|waves?|guard\b.*\buntil|keep .* alive)\b", RegexOptions.IgnoreCase);

        // One row per guide complete step: whether it could get a route or should keep a single waypoint, and
        // why, plus whether it has one now (docs/generated/roaming-candidates.csv). The classification never
        // depends on existing routes, so research tools can rerun on it. Nothing here creates a route.
        public static List<string[]> Inventory(CompileResult res)
        {
            var db = res.Db;
            var routed = new HashSet<int>(res.Routes.Select(r => r.Quest));
            var rows = new List<string[]>();
            var seen = new HashSet<string>();
            foreach (var g in res.Guides)
                foreach (var s in g.Steps.Where(x => x.Kind == "complete" && x.Quest > 0))
                {
                    if (!seen.Add(g.Id + ":" + s.Quest + ":" + s.Obj)) continue;
                    LTable rec; db.Quests.TryGetValue(s.Quest, out rec);
                    var obj = BundledDb.Tab(rec, BundledDb.Q_OBJ);
                    Func<string, List<int>> ids = k => obj == null ? new List<int>() : (obj.Get(k) as LTable ?? new LTable()).IntList();
                    var kills = ids("c"); var items = ids("i"); var objs = ids("o"); var credit = ids("k");
                    string text = BundledDb.Str(rec, BundledDb.Q_OBJTEXT) ?? "";
                    var targets = new List<string>();
                    string status, why = "";
                    Func<int, int> here = n => db.NpcSpawns(n).Count(p => db.Parent((int)p[0]) == db.Parent(g.Zone));
                    foreach (var n in kills) targets.Add("kill " + n + " " + db.NpcName(n) + " (" + here(n) + " spawns here)");
                    foreach (var i in items)
                    {
                        LTable it; db.Items.TryGetValue(i, out it);
                        var dn = BundledDb.Ids(it, BundledDb.I_NPCDROPS); var dobj = BundledDb.Ids(it, BundledDb.I_OBJDROPS);
                        targets.Add("item " + i + " " + (it != null ? BundledDb.Str(it, BundledDb.I_NAME) : "?") + " from " + dn.Count + " NPC(s), " + dobj.Count + " object(s)");
                    }
                    if (s.Dungeon != null) { status = "keep single waypoint"; why = "dungeon: " + s.Dungeon; }
                    else if (EventWords.IsMatch(text)) { status = "keep single waypoint"; why = "escort or scripted event wording"; }
                    else if (kills.Count == 0 && items.Count == 0) { status = "keep single waypoint"; why = objs.Count > 0 || credit.Count > 0 ? "object or event objective" : "no kill or item objective"; }
                    else if (kills.Count > 0 && (items.Count > 0 || objs.Count > 0)) { status = "needs review"; why = "mixed objective types (log order unchecked)"; }
                    else if (items.Count > 0 && items.Any(i => { LTable it; return !db.Items.TryGetValue(i, out it) || BundledDb.Ids(it, BundledDb.I_NPCDROPS).Count == 0 || BundledDb.Ids(it, BundledDb.I_OBJDROPS).Count > 0; }))
                    { status = "keep single waypoint"; why = "item comes from objects or has no NPC drop source"; }
                    else if (kills.Any(n => here(n) <= 2 || BundledDb.Num(db.Npcs.ContainsKey(n) ? db.Npcs[n] : null, BundledDb.N_RANK) > 0))
                    { status = "keep single waypoint"; why = "named, elite or fixed-spawn enemy"; }
                    else { status = "candidate (no route yet)"; why = kills.Count > 0 ? "kill area" : "kill-for-drop area"; }
                    rows.Add(new[] { g.Id, s.Quest.ToString(CultureInfo.InvariantCulture), s.Obj > 0 ? s.Obj.ToString(CultureInfo.InvariantCulture) : "",
                        BundledDb.Str(rec, BundledDb.Q_NAME) ?? "?", status, why, string.Join("; ", targets.ToArray()), routed.Contains(s.Quest) ? "yes" : "" });
                }
            return rows;
        }
    }
}
