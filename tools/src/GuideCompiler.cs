// TBCGuide build tooling - guide compiler (guides-src/*.guide -> TBCGuide/Guides/Compiled/*.lua)
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Guide sources are written in a small line-based format (docs/GUIDE_FORMAT.md). The compiler:
//   * resolves quest references (id, name, or "id name") against the bundled quest database,
//     honouring faction/race/class restrictions and earlier accepts on the route;
//   * attaches NPC names and coordinates FROM THE DATABASE (never invented), choosing the spawn
//     nearest to the previous step so routes read naturally;
//   * resolves trainers, flight masters and innkeepers by NPC flags in the guide's zone;
//   * reports problems: unknown/ambiguous quests, faction or race mismatches, level mismatches,
//     prerequisites not covered by the route, turn-ins without accepts, bad coordinates.
// Hard problems are errors (build fails); soft ones are warnings in docs/generated.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    // ---------------------------------------------------------------- bundled DB reader
    public sealed class BundledDb
    {
        public Dictionary<int, LTable> Quests = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Npcs = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Objects = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Items = new Dictionary<int, LTable>();
        public Dictionary<int, string> ZoneNames = new Dictionary<int, string>();
        public Dictionary<int, int> ZoneParent = new Dictionary<int, int>();
        public Dictionary<int, int> UiMap = new Dictionary<int, int>();
        public Dictionary<string, List<int>> QuestsByName = new Dictionary<string, List<int>>();
        public Dictionary<string, int> ZoneByName = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        // Positions in our generated records (Database/Schema.lua)
        public const int Q_NAME = 1, Q_REQ = 2, Q_LEVEL = 3, Q_RACES = 4, Q_CLASSES = 5, Q_SNPC = 6, Q_SOBJ = 7, Q_SITEM = 8,
            Q_ENPC = 9, Q_EOBJ = 10, Q_OBJTEXT = 11, Q_OBJ = 12, Q_PREG = 13, Q_PRES = 14, Q_ZONE = 15, Q_EXCL = 16,
            Q_NEXT = 17, Q_BREAD = 18, Q_SPECIAL = 19, Q_MAXLVL = 20, Q_TRIGGER = 21;
        public const int N_NAME = 1, N_MINL = 2, N_MAXL = 3, N_RANK = 4, N_ZONE = 5, N_SPAWNS = 6, N_FRIENDLY = 7, N_SUB = 8, N_FLAGS = 9;
        public const int O_NAME = 1, O_ZONE = 2, O_SPAWNS = 3;
        public const int I_NAME = 1, I_NPCDROPS = 2, I_OBJDROPS = 3;

        static readonly Regex RecordLine = new Regex(@"^([QNOI])\[(\d+)\]=(.*)$");
        static readonly Regex ZoneLine = new Regex("^\\[(\\d+)\\]=(\"(?:[^\"\\\\]|\\\\.)*\"|\\d+),$");

        public static BundledDb Load(string addOnDir)
        {
            var db = new BundledDb();
            string dir = Path.Combine(addOnDir, "Database", "QuestieTBC");
            foreach (var file in new[] { "Quests.lua", "Npcs.lua", "Objects.lua", "Items.lua" })
            {
                foreach (var line in File.ReadLines(Path.Combine(dir, file)))
                {
                    var m = RecordLine.Match(line);
                    if (!m.Success) continue;
                    var t = LuaLiteralReader.ParseValue(m.Groups[3].Value, file) as LTable;
                    int id = int.Parse(m.Groups[2].Value);
                    switch (m.Groups[1].Value)
                    {
                        case "Q": db.Quests[id] = t; break;
                        case "N": db.Npcs[id] = t; break;
                        case "O": db.Objects[id] = t; break;
                        case "I": db.Items[id] = t; break;
                    }
                }
            }
            string section = null;
            foreach (var line in File.ReadLines(Path.Combine(dir, "Zones.lua")))
            {
                if (line.StartsWith("Z.uiMap")) { section = "ui"; continue; }
                if (line.StartsWith("Z.names")) { section = "names"; continue; }
                if (line.StartsWith("Z.parent")) { section = "parent"; continue; }
                var m = ZoneLine.Match(line);
                if (!m.Success) continue;
                int k = int.Parse(m.Groups[1].Value);
                string v = m.Groups[2].Value;
                if (section == "names") db.ZoneNames[k] = (string)LuaLiteralReader.ParseValue(v, "Zones.lua");
                else if (section == "parent") db.ZoneParent[k] = int.Parse(v);
                else if (section == "ui") db.UiMap[k] = int.Parse(v);
            }
            foreach (var kv in db.ZoneNames)
                if (!db.ZoneByName.ContainsKey(kv.Value) && db.UiMap.ContainsKey(kv.Key)) db.ZoneByName[kv.Value] = kv.Key;
            foreach (var kv in db.Quests)
            {
                string n = Str(kv.Value, Q_NAME);
                if (n == null) continue;
                string key = Norm(n);
                List<int> l;
                if (!db.QuestsByName.TryGetValue(key, out l)) { l = new List<int>(); db.QuestsByName[key] = l; }
                l.Add(kv.Key);
            }
            return db;
        }

        public static string Norm(string s)
        {
            s = s.Trim().ToLowerInvariant().Replace('’', '\'');
            return Regex.Replace(s, @"\s+", " ");
        }

        public static string Str(LTable t, int i) { return t == null ? null : t.Get(i) as string; }
        public static int Num(LTable t, int i) { if (t == null) return 0; object v = t.Get(i); return v is double ? (int)(double)v : 0; }
        public static LTable Tab(LTable t, int i) { return t == null ? null : t.Get(i) as LTable; }
        public static List<int> Ids(LTable t, int i) { var x = Tab(t, i); return x == null ? new List<int>() : x.IntList(); }

        public int Parent(int area)
        {
            int g = 0, p;
            while (ZoneParent.TryGetValue(area, out p) && p != area && g++ < 8) area = p;
            return area;
        }

        // Spawns for npc/object as list of (zone, x, y)
        public List<double[]> Spawns(LTable spawns)
        {
            var r = new List<double[]>();
            if (spawns == null) return r;
            foreach (var kv in spawns.Pairs())
            {
                var pts = kv.Value as LTable;
                if (pts == null || !(kv.Key is double)) continue;
                foreach (var p in pts.Pairs())
                {
                    var pt = p.Value as LTable;
                    if (pt == null) continue;
                    r.Add(new[] { (double)kv.Key, (double)pt.Get(1), (double)pt.Get(2) });
                }
            }
            return r;
        }

        public List<double[]> NpcSpawns(int id) { LTable n; return Npcs.TryGetValue(id, out n) ? Spawns(Tab(n, N_SPAWNS)) : new List<double[]>(); }
        public List<double[]> ObjSpawns(int id) { LTable o; return Objects.TryGetValue(id, out o) ? Spawns(Tab(o, O_SPAWNS)) : new List<double[]>(); }
        public string NpcName(int id) { LTable n; return Npcs.TryGetValue(id, out n) ? Str(n, N_NAME) : null; }
        public string ObjName(int id) { LTable o; return Objects.TryGetValue(id, out o) ? Str(o, O_NAME) : null; }
    }

    // ---------------------------------------------------------------- compiled model
    public sealed class CStep
    {
        public string Kind;
        public int Quest, Obj, Level;
        public string Title, Npc, Text, Place, Dest, GuideRef, Dungeon, Faction;
        public int Zone; public double X = -1, Y = -1;
        public bool Verified = true, Optional, Elite;
        public int Group = -1; // -1 none, 0 unspecified size, n = group size
        public List<string> Classes, Races;
        public int Line;
        public int NpcId;                        // giver/finisher/talk NPC chosen for the step (0 = none)
        public int MarkIcon;                     // raid target icon 1-8 from [mark=...] (0 = none)
        public string MarkTarget;                // optional explicit target: NPC id or exact NPC name
        public List<int> MarkNpcs;               // resolved NPC ids the add-on may mark for this step
        public List<string> Mobs;                // grind: mob names (as spelled in the database)
        public string Location;                  // grind: where to find them (free text)
    }

    public sealed class CGuide
    {
        public string Id, Name, Faction, Chapter, ZoneName, Desc, Source;
        public int Zone, MinLevel, MaxLevel;
        public bool Start;
        public List<string> Races, Classes;
        public List<KeyValuePair<string, Dictionary<string, List<string>>>> Next = new List<KeyValuePair<string, Dictionary<string, List<string>>>>();
        public List<CStep> Steps = new List<CStep>();
    }

    public sealed class CompileResult
    {
        public List<CGuide> Guides = new List<CGuide>();
        public List<string> Errors = new List<string>();
        public List<string> Warnings = new List<string>();
        public string Summary;
        public BundledDb Db;
    }

    // ---------------------------------------------------------------- compiler
    public static class GuideCompiler
    {
        public static readonly string[] AllianceRaces = { "Human", "Dwarf", "NightElf", "Gnome", "Draenei" };
        public static readonly string[] HordeRaces = { "Orc", "Scourge", "Tauren", "Troll", "BloodElf" };
        public static readonly Dictionary<string, int> RaceBit = new Dictionary<string, int> {
            {"Human",1},{"Orc",2},{"Dwarf",4},{"NightElf",8},{"Scourge",16},{"Tauren",32},{"Gnome",64},{"Troll",128},{"BloodElf",512},{"Draenei",1024} };
        public static readonly Dictionary<string, int> ClassBit = new Dictionary<string, int> {
            {"WARRIOR",1},{"PALADIN",2},{"HUNTER",4},{"ROGUE",8},{"PRIEST",16},{"SHAMAN",64},{"MAGE",128},{"WARLOCK",256},{"DRUID",1024} };
        // Classes each race can play (from Database/RaceClass.lua, CharBaseInfo build 2.5.6).
        public static readonly Dictionary<string, string[]> RaceClasses = new Dictionary<string, string[]> {
            {"Human", new[]{"WARRIOR","PALADIN","ROGUE","PRIEST","MAGE","WARLOCK"}},
            {"Orc", new[]{"WARRIOR","HUNTER","ROGUE","SHAMAN","WARLOCK"}},
            {"Dwarf", new[]{"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST"}},
            {"NightElf", new[]{"WARRIOR","HUNTER","ROGUE","PRIEST","DRUID"}},
            {"Scourge", new[]{"WARRIOR","ROGUE","PRIEST","MAGE","WARLOCK"}},
            {"Tauren", new[]{"WARRIOR","HUNTER","SHAMAN","DRUID"}},
            {"Gnome", new[]{"WARRIOR","ROGUE","MAGE","WARLOCK"}},
            {"Troll", new[]{"WARRIOR","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE"}},
            {"BloodElf", new[]{"PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK"}},
            {"Draenei", new[]{"WARRIOR","PALADIN","HUNTER","PRIEST","SHAMAN","MAGE"}} };
        static readonly Dictionary<string, string> ClassTrainerSub = new Dictionary<string, string> {
            {"WARRIOR","Warrior Trainer"},{"PALADIN","Paladin Trainer"},{"HUNTER","Hunter Trainer"},{"ROGUE","Rogue Trainer"},
            {"PRIEST","Priest Trainer"},{"SHAMAN","Shaman Trainer"},{"MAGE","Mage Trainer"},{"WARLOCK","Warlock Trainer"},{"DRUID","Druid Trainer"} };
        static readonly Dictionary<string, string> RaceAlias = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            {"Human","Human"},{"Dwarf","Dwarf"},{"Gnome","Gnome"},{"NightElf","NightElf"},{"Night Elf","NightElf"},{"Draenei","Draenei"},
            {"Orc","Orc"},{"Troll","Troll"},{"Tauren","Tauren"},{"Undead","Scourge"},{"Scourge","Scourge"},{"BloodElf","BloodElf"},{"Blood Elf","BloodElf"} };

        const int ALLIANCE_MASK = 1101, HORDE_MASK = 690;
        const int FLAG_TRAINER = 16, FLAG_FLIGHT = 8192, FLAG_INN = 65536;

        static readonly HashSet<string> Verbs = new HashSet<string>(new[] {
            "accept","turnin","complete","goto","note","train","fp","fly","hs","bind","level","travel","guide","talk","buy","use","collect","grind" });

        public static CompileResult CompileAll(string srcDir, string addOnDir, bool write = true)
        {
            var res = new CompileResult();
            res.Db = BundledDb.Load(addOnDir);
            var files = Directory.Exists(srcDir)
                ? Directory.GetFiles(srcDir, "*.guide", SearchOption.AllDirectories).OrderBy(f => f, StringComparer.Ordinal).ToList()
                : new List<string>();
            var state = new Dictionary<string, RouteState> { { "Alliance", new RouteState() }, { "Horde", new RouteState() }, { "Both", new RouteState() } };
            foreach (var f in files)
            {
                string rel = f.Substring(srcDir.Length).TrimStart('\\', '/').Replace('\\', '/');
                try { ParseFile(f, rel, res, state); }
                catch (Exception e) { res.Errors.Add(rel + ": " + e.Message); }
            }
            CrossChecks(res, state);
            if (res.Errors.Count == 0 && write) Write(res, addOnDir);
            int steps = res.Guides.Sum(g => g.Steps.Count);
            int quests = res.Guides.SelectMany(g => g.Steps).Where(s => s.Quest > 0).Select(s => s.Quest).Distinct().Count();
            res.Summary = string.Format("guides: {0} guides, {1} steps, {2} distinct quests, {3} error(s), {4} warning(s)",
                res.Guides.Count, steps, quests, res.Errors.Count, res.Warnings.Count);
            return res;
        }

        sealed class RouteState
        {
            public Dictionary<string, int> AcceptedByName = new Dictionary<string, int>();
            public HashSet<int> Accepted = new HashSet<int>();
            public HashSet<int> TurnedIn = new HashSet<int>();
            public List<KeyValuePair<int, string>> PendingPrereqChecks = new List<KeyValuePair<int, string>>();
        }

        // ------------------------------------------------------------------ parsing
        static void ParseFile(string path, string rel, CompileResult res, Dictionary<string, RouteState> states)
        {
            var lines = File.ReadAllLines(path, Encoding.UTF8);
            CGuide g = null;
            double lx = -1, ly = -1; int lz = 0;
            for (int n = 0; n < lines.Length; n++)
            {
                string raw = lines[n];
                string line = raw.Trim();
                string where = rel + ":" + (n + 1);
                if (line.Length == 0 || line.StartsWith("#") || line.StartsWith("//")) continue;
                if (line.StartsWith("@"))
                {
                    int sp = line.IndexOf(' ');
                    string key = (sp < 0 ? line.Substring(1) : line.Substring(1, sp - 1)).ToLowerInvariant();
                    string val = sp < 0 ? "" : line.Substring(sp + 1).Trim();
                    if (key == "guide")
                    {
                        if (g != null) FinishGuide(g, res, where);
                        g = new CGuide { Id = val, Source = rel };
                        lx = ly = -1; lz = 0;
                        if (res.Guides.Any(x => x.Id == val)) res.Errors.Add(where + ": duplicate guide id " + val);
                        res.Guides.Add(g);
                        continue;
                    }
                    if (g == null) { res.Errors.Add(where + ": directive before @guide"); continue; }
                    switch (key)
                    {
                        case "name": g.Name = val; break;
                        case "faction":
                            if (val != "Alliance" && val != "Horde" && val != "Both") res.Errors.Add(where + ": faction must be Alliance, Horde or Both");
                            g.Faction = val; break;
                        case "races": g.Races = ParseRaces(val, where, res); break;
                        case "classes": g.Classes = ParseClasses(val, where, res); break;
                        case "levels":
                            var lm = Regex.Match(val, @"^(\d+)\s*-\s*(\d+)$");
                            if (!lm.Success) { res.Errors.Add(where + ": @levels must be like 1-10"); break; }
                            g.MinLevel = int.Parse(lm.Groups[1].Value); g.MaxLevel = int.Parse(lm.Groups[2].Value);
                            if (g.MinLevel < 1 || g.MaxLevel > 70 || g.MinLevel > g.MaxLevel) res.Errors.Add(where + ": invalid level range");
                            break;
                        case "zone":
                            int zid;
                            if (!res.Db.ZoneByName.TryGetValue(val, out zid)) res.Errors.Add(where + ": unknown zone '" + val + "'");
                            g.Zone = zid; g.ZoneName = val; lz = zid; break;
                        case "chapter":
                            if (val != "Azeroth" && val != "Outland") res.Errors.Add(where + ": chapter must be Azeroth or Outland");
                            g.Chapter = val; break;
                        case "start": g.Start = true; break;
                        case "desc": g.Desc = string.IsNullOrEmpty(g.Desc) ? val : g.Desc + " " + val; break;
                        case "next":
                            var parts = Regex.Match(val, @"^(\S+)(.*)$");
                            var cond = ParseFlags(parts.Groups[2].Value.Trim(), where, res);
                            var condLists = new Dictionary<string, List<string>>();
                            if (cond.ContainsKey("race")) condLists["races"] = ParseRaces(cond["race"], where, res);
                            if (cond.ContainsKey("class")) condLists["classes"] = ParseClasses(cond["class"], where, res);
                            if (cond.ContainsKey("faction")) condLists["faction"] = new List<string> { cond["faction"] };
                            g.Next.Add(new KeyValuePair<string, Dictionary<string, List<string>>>(parts.Groups[1].Value, condLists));
                            break;
                        default: res.Errors.Add(where + ": unknown directive @" + key); break;
                    }
                    continue;
                }
                if (g == null) { res.Errors.Add(where + ": step before @guide"); continue; }
                if (g.Faction == null) { res.Errors.Add(where + ": @faction must precede steps"); continue; }
                var st = states[g.Faction];
                ParseStep(line, where, g, res, st, ref lz, ref lx, ref ly);
            }
            if (g != null) FinishGuide(g, res, rel + ":eof");
        }

        static void FinishGuide(CGuide g, CompileResult res, string where)
        {
            if (string.IsNullOrEmpty(g.Name)) res.Errors.Add(g.Id + ": missing @name");
            if (g.Faction == null) res.Errors.Add(g.Id + ": missing @faction");
            if (g.MaxLevel == 0) res.Errors.Add(g.Id + ": missing @levels");
            if (g.Chapter == null) res.Errors.Add(g.Id + ": missing @chapter");
            if (g.Steps.Count == 0) res.Errors.Add(g.Id + ": no steps");
            if (g.Start && (g.Races == null || g.Races.Count == 0)) res.Errors.Add(g.Id + ": @start guide must declare @races");
            if (g.Races != null)
                foreach (var r in g.Races)
                {
                    bool ok = g.Faction == "Both" || (g.Faction == "Alliance" ? AllianceRaces.Contains(r) : HordeRaces.Contains(r));
                    if (!ok) res.Errors.Add(g.Id + ": race " + r + " is not " + g.Faction);
                }
        }

        static readonly Regex FlagGroup = new Regex(@"\[([^\]]*)\]\s*$");

        static Dictionary<string, string> ParseFlags(string s, string where, CompileResult res)
        {
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (Match m in Regex.Matches(s, @"\[([^\]]*)\]"))
            {
                foreach (var part in m.Groups[1].Value.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    string p = part.Trim();
                    int eq = p.IndexOf('=');
                    if (eq < 0) d[p] = "";
                    else d[p.Substring(0, eq).Trim()] = p.Substring(eq + 1).Trim();
                }
            }
            return d;
        }

        static List<string> ParseRaces(string s, string where, CompileResult res)
        {
            var l = new List<string>();
            foreach (var p in s.Split(','))
            {
                string r;
                if (RaceAlias.TryGetValue(p.Trim(), out r)) l.Add(r); else res.Errors.Add(where + ": unknown race '" + p.Trim() + "'");
            }
            return l;
        }

        static List<string> ParseClasses(string s, string where, CompileResult res)
        {
            var l = new List<string>();
            foreach (var p in s.Split(','))
            {
                string c = p.Trim().ToUpperInvariant();
                if (ClassBit.ContainsKey(c)) l.Add(c); else res.Errors.Add(where + ": unknown class '" + p.Trim() + "'");
            }
            return l;
        }

        static readonly Regex Coord = new Regex(@"^(\d{1,2}(?:\.\d+)?|100)\s*,\s*(\d{1,2}(?:\.\d+)?|100)");

        static void ParseStep(string line, string where, CGuide g, CompileResult res, RouteState st, ref int lz, ref double lx, ref double ly)
        {
            // Layout: <verb> <args> [flags]... | <text> [flags]...
            string text = null;
            int bar = line.IndexOf(" | ", StringComparison.Ordinal);
            if (bar >= 0) { text = line.Substring(bar + 3).Trim(); line = line.Substring(0, bar).Trim(); }
            else if (line.EndsWith(" |")) line = line.Substring(0, line.Length - 2);
            string flagsText = "";
            while (true)
            {
                var fm = FlagGroup.Match(line);
                if (!fm.Success) break;
                flagsText = fm.Value + flagsText;
                line = line.Substring(0, fm.Index).TrimEnd();
            }
            while (text != null)
            {
                var fm = FlagGroup.Match(text);
                if (!fm.Success) break;
                flagsText = fm.Value + flagsText;
                text = text.Substring(0, fm.Index).TrimEnd();
            }
            if (text == "") text = null;
            var flags = ParseFlags(flagsText, where, res);
            int sp = line.IndexOf(' ');
            string verb = (sp < 0 ? line : line.Substring(0, sp)).ToLowerInvariant();
            string arg = sp < 0 ? "" : line.Substring(sp + 1).Trim();
            if (!Verbs.Contains(verb)) { res.Errors.Add(where + ": unknown step type '" + verb + "'"); return; }

            var s = new CStep { Kind = verb, Text = text };
            int ln; int colon = where.LastIndexOf(':');
            s.Line = colon >= 0 && int.TryParse(where.Substring(colon + 1), out ln) ? ln : 0;
            string v;
            if (flags.TryGetValue("class", out v)) s.Classes = ParseClasses(v, where, res);
            if (flags.TryGetValue("race", out v)) s.Races = ParseRaces(v, where, res);
            if (flags.ContainsKey("optional")) s.Optional = true;
            if (flags.ContainsKey("elite")) s.Elite = true;
            if (flags.TryGetValue("group", out v)) { int gs; s.Group = int.TryParse(v, out gs) ? gs : 0; }
            if (flags.TryGetValue("dungeon", out v)) s.Dungeon = v;
            if (flags.TryGetValue("obj", out v)) s.Obj = int.Parse(v);
            if (flags.ContainsKey("unverified")) s.Verified = false;
            if (flags.TryGetValue("mark", out v)) ParseMark(v, s, where, res);
            int stepZone = g.Zone;
            if (flags.TryGetValue("zone", out v))
            {
                if (!res.Db.ZoneByName.TryGetValue(v, out stepZone)) res.Errors.Add(where + ": unknown zone '" + v + "'");
            }
            if (s.Races != null && g.Races != null && s.Races.Any(r => !g.Races.Contains(r)))
                res.Warnings.Add(where + ": step race filter includes races outside the guide's @races");
            if (s.Races != null)
                foreach (var r in s.Races)
                    if (g.Faction != "Both" && (g.Faction == "Alliance") != AllianceRaces.Contains(r)) res.Errors.Add(where + ": race " + r + " not in faction " + g.Faction);

            double ax = -1, ay = -1;
            if (flags.TryGetValue("at", out v))
            {
                var cm = Coord.Match(v);
                if (!cm.Success) res.Errors.Add(where + ": bad at= coordinates");
                else { ax = D(cm.Groups[1].Value); ay = D(cm.Groups[2].Value); }
            }

            switch (verb)
            {
                case "accept":
                case "turnin":
                case "complete":
                {
                    int q = ResolveQuest(arg, verb, where, g, s, res, st);
                    if (q <= 0) return;
                    s.Quest = q;
                    var rec = res.Db.Quests[q];
                    s.Title = BundledDb.Str(rec, BundledDb.Q_NAME);
                    CheckQuestFit(q, rec, where, g, s, res);
                    if (verb == "accept")
                    {
                        st.Accepted.Add(q);
                        st.AcceptedByName[BundledDb.Norm(s.Title)] = q;
                        foreach (var pre in BundledDb.Ids(rec, BundledDb.Q_PREG))
                            if (!st.TurnedIn.Contains(pre)) st.PendingPrereqChecks.Add(new KeyValuePair<int, string>(pre, where + " (" + s.Title + ")"));
                        var single = BundledDb.Ids(rec, BundledDb.Q_PRES);
                        if (single.Count > 0 && !single.Any(p => st.TurnedIn.Contains(p)))
                            st.PendingPrereqChecks.Add(new KeyValuePair<int, string>(-single[0], where + " (" + s.Title + ")"));
                        PlaceGiver(res.Db, BundledDb.Ids(rec, BundledDb.Q_SNPC), BundledDb.Ids(rec, BundledDb.Q_SOBJ), s, stepZone, ref lz, ref lx, ref ly);
                        var items = BundledDb.Ids(rec, BundledDb.Q_SITEM);
                        if (s.Npc == null && items.Count > 0)
                        {
                            LTable it;
                            string iname = res.Db.Items.TryGetValue(items[0], out it) ? BundledDb.Str(it, BundledDb.I_NAME) : ("item " + items[0]);
                            if (s.Text == null) s.Text = "Starts from the item " + iname + ".";
                        }
                    }
                    else if (verb == "turnin")
                    {
                        if (!st.Accepted.Contains(q) && BundledDb.Ids(rec, BundledDb.Q_SITEM).Count == 0)
                            res.Warnings.Add(where + ": turn-in of '" + s.Title + "' (" + q + ") with no earlier accept on this faction's routes");
                        st.TurnedIn.Add(q);
                        PlaceGiver(res.Db, BundledDb.Ids(rec, BundledDb.Q_ENPC), BundledDb.Ids(rec, BundledDb.Q_EOBJ), s, stepZone, ref lz, ref lx, ref ly);
                    }
                    else
                    {
                        if (!st.Accepted.Contains(q)) res.Warnings.Add(where + ": complete '" + s.Title + "' (" + q + ") before any accept");
                        // No fixed coordinates: the add-on targets the nearest objective live.
                        double ox, oy; int oz;
                        if (ObjectiveLocation(res.Db, rec, stepZone, lx, ly, out oz, out ox, out oy)) { lz = oz; lx = ox; ly = oy; }
                        else if (rec.Get(BundledDb.Q_OBJ) == null && rec.Get(BundledDb.Q_TRIGGER) == null && ax < 0)
                            res.Warnings.Add(where + ": '" + s.Title + "' has no objective locations in the database; add [at=x,y] or a goto");
                    }
                    break;
                }
                case "goto":
                {
                    var cm = Coord.Match(arg);
                    if (!cm.Success) { res.Errors.Add(where + ": goto needs x,y"); return; }
                    ax = D(cm.Groups[1].Value); ay = D(cm.Groups[2].Value);
                    s.Verified = false; // authored coordinates are not machine-checked
                    if (s.Text == null) s.Text = arg.Substring(cm.Length).Trim().Length > 0 ? arg.Substring(cm.Length).Trim() : null;
                    break;
                }
                case "talk":
                {
                    int npc = ResolveNpc(res.Db, arg, g.Faction, stepZone, lx, ly);
                    if (npc <= 0) { res.Errors.Add(where + ": NPC '" + arg + "' not found in database for " + g.Faction); return; }
                    s.Npc = res.Db.NpcName(npc);
                    s.NpcId = npc;
                    PlaceAt(res.Db.NpcSpawns(npc), s, stepZone, ref lz, ref lx, ref ly);
                    break;
                }
                case "train":
                {
                    EmitTrainSteps(g, s, res, stepZone, where, ref lz, ref lx, ref ly);
                    return;
                }
                case "fp":
                case "bind":
                {
                    if (g.Faction == "Both")
                    {
                        // Service NPCs are faction-specific: emit one step per faction.
                        foreach (var fac in new[] { "Alliance", "Horde" })
                        {
                            var fs = new CStep { Kind = verb, Text = s.Text, Optional = s.Optional, Place = arg, Faction = fac, Verified = s.Verified };
                            int fnpc = FindService(res.Db, verb == "fp" ? FLAG_FLIGHT : FLAG_INN, fac, stepZone, lx, ly, null);
                            if (fnpc > 0)
                            {
                                fs.Npc = res.Db.NpcName(fnpc);
                                int tz = lz; double tx = lx, ty = ly;
                                PlaceAt(res.Db.NpcSpawns(fnpc), fs, stepZone, ref tz, ref tx, ref ty);
                            }
                            else res.Warnings.Add(where + ": no " + fac + " " + (verb == "fp" ? "flight master" : "innkeeper") + " found in zone for " + arg);
                            g.Steps.Add(fs);
                        }
                        return;
                    }
                    s.Place = arg;
                    int flag = verb == "fp" ? FLAG_FLIGHT : FLAG_INN;
                    int npc = FindService(res.Db, flag, g.Faction, stepZone, lx, ly, null);
                    if (npc > 0)
                    {
                        s.Npc = res.Db.NpcName(npc);
                        PlaceAt(res.Db.NpcSpawns(npc), s, stepZone, ref lz, ref lx, ref ly);
                    }
                    else res.Warnings.Add(where + ": no " + (verb == "fp" ? "flight master" : "innkeeper") + " found in zone for " + arg);
                    break;
                }
                case "fly":
                case "hs":
                case "travel":
                    s.Dest = arg.Length > 0 ? arg : null;
                    if (verb == "travel" && s.Text == null) s.Text = "Travel to " + arg;
                    break;
                case "level":
                    int lvl;
                    if (!int.TryParse(arg, out lvl) || lvl < 2 || lvl > 70) { res.Errors.Add(where + ": level needs 2-70"); return; }
                    s.Level = lvl;
                    break;
                case "grind":
                    if (!ParseGrind(arg, s, stepZone, where, res, lz, lx, ly)) return;
                    break;
                case "guide":
                    s.GuideRef = arg;
                    break;
                case "note":
                case "buy":
                case "use":
                case "collect":
                    if (s.Text == null) s.Text = arg;
                    else s.Text = arg + " - " + s.Text;
                    if (string.IsNullOrEmpty(s.Text)) res.Errors.Add(where + ": " + verb + " needs text");
                    break;
            }
            if (ax >= 0)
            {
                if (ax > 100 || ay > 100) res.Errors.Add(where + ": coordinates out of range");
                s.X = ax; s.Y = ay; s.Zone = stepZone;
                lx = ax; ly = ay; lz = stepZone;
                if (verb != "goto") s.Verified = false;
            }
            if (s.MarkIcon > 0) ResolveMark(s, stepZone, where, res);
            g.Steps.Add(s);
        }

        // ------------------------------------------------------------------ grind steps
        // grind <level> <Mob>[, <Mob>...] [@ <location>]
        // Completes like a level step. Every mob must exist in the bundled database AND spawn in this
        // step's zone, so a guide cannot name invented or out-of-zone mobs. Without [at=x,y] the
        // step points at the database spawn of those mobs nearest the previous step.
        // Note: [at=x,y] still updates the position (same as every other step type).
        static bool ParseGrind(string arg, CStep s, int zone, string where, CompileResult res, int lz, double lx, double ly)
        {
            var m = Regex.Match(arg, @"^(\d+)\s+([^@]+?)\s*(?:@\s*(.+))?$");
            int lvl;
            if (!m.Success || !int.TryParse(m.Groups[1].Value, out lvl) || lvl < 2 || lvl > 70)
            {
                res.Errors.Add(where + ": grind needs '<level 2-70> <Mob>[, <Mob>] [@ location]'");
                return false;
            }
            s.Level = lvl;
            s.Location = m.Groups[3].Success ? m.Groups[3].Value.Trim() : null;
            s.Mobs = new List<string>();
            var spawns = new List<double[]>();
            var db = res.Db;
            int parent = db.Parent(zone);
            foreach (var raw in m.Groups[2].Value.Split(','))
            {
                string want = BundledDb.Norm(raw);
                if (want.Length == 0) continue;
                string canonical = null;
                foreach (var kv in db.Npcs)
                {
                    string name = BundledDb.Str(kv.Value, BundledDb.N_NAME);
                    if (name == null || BundledDb.Norm(name) != want) continue;
                    var here = db.NpcSpawns(kv.Key).Where(sp => db.Parent((int)sp[0]) == parent).ToList();
                    if (here.Count == 0) continue;
                    canonical = name;
                    spawns.AddRange(here);
                }
                if (canonical == null)
                {
                    res.Errors.Add(where + ": grind mob '" + raw.Trim() + "' has no spawns in " + (db.ZoneNames.ContainsKey(zone) ? db.ZoneNames[zone] : ("zone " + zone)) + " in the database");
                    return false;
                }
                s.Mobs.Add(canonical);
            }
            if (s.Mobs.Count == 0) { res.Errors.Add(where + ": grind needs at least one mob"); return false; }
            // Point at the spawn nearest the previous step, but on copies: a grind step must not move
            // the compiler's position, or later steps would resolve different trainers/NPCs.
            // [at=x,y] (applied by the caller) overrides this, e.g. to name a specific camp.
            int tz = lz; double tx = lx, ty = ly;
            PlaceAt(spawns, s, zone, ref tz, ref tx, ref ty);
            return true;
        }

        // ------------------------------------------------------------------ raid markers
        // [mark=skull] marks the step's own NPCs: accept -> quest givers, turnin -> finishers,
        // talk -> that NPC, complete -> kill-objective creatures (and the 1-3 NPCs that drop a quest item). [mark=skull:1234] targets an NPC
        // id; [mark=skull:Name] an exact NPC name, which must resolve to ONE id (else: error, use
        // the id). The add-on only ever matches units by NPC id, never by name.
        public static readonly string[] MarkNames = { "", "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" };

        static void ParseMark(string v, CStep s, string where, CompileResult res)
        {
            string icon = v, target = null;
            int c = v.IndexOf(':');
            if (c >= 0) { icon = v.Substring(0, c).Trim(); target = v.Substring(c + 1).Trim(); }
            int idx = Array.IndexOf(MarkNames, icon.ToLowerInvariant());
            int n;
            if (idx <= 0 && int.TryParse(icon, out n) && n >= 1 && n <= 8) idx = n;
            if (idx <= 0) { res.Errors.Add(where + ": unknown raid marker '" + icon + "' (use star, circle, diamond, triangle, moon, square, cross, skull or 1-8)"); return; }
            s.MarkIcon = idx;
            s.MarkTarget = string.IsNullOrEmpty(target) ? null : target;
        }

        static void ResolveMark(CStep s, int zone, string where, CompileResult res)
        {
            var db = res.Db;
            var ids = new List<int>();
            LTable rec = null;
            if (s.Quest > 0) db.Quests.TryGetValue(s.Quest, out rec);
            if (s.MarkTarget == null)
            {
                if (s.Kind == "accept" && rec != null) ids.AddRange(BundledDb.Ids(rec, BundledDb.Q_SNPC));
                else if (s.Kind == "turnin" && rec != null) ids.AddRange(BundledDb.Ids(rec, BundledDb.Q_ENPC));
                else if (s.Kind == "complete" && rec != null)
                {
                    var obj = BundledDb.Tab(rec, BundledDb.Q_OBJ);
                    var cl = obj == null ? null : obj.Get("c") as LTable;
                    var kl = obj == null ? null : obj.Get("k") as LTable;
                    if (cl != null) ids.AddRange(cl.IntList());
                    if (kl != null) ids.AddRange(kl.IntList());
                    // Item objectives: the NPCs that drop the item, only when it is a specific drop
                    // (at most 3 sources, e.g. a named mob's head) - never a common drop table.
                    var il = obj == null ? null : obj.Get("i") as LTable;
                    if (il != null)
                        foreach (var item in il.IntList())
                        {
                            LTable it;
                            if (!db.Items.TryGetValue(item, out it)) continue;
                            var drops = BundledDb.Ids(it, BundledDb.I_NPCDROPS);
                            if (drops.Count > 0 && drops.Count <= 3) ids.AddRange(drops);
                        }
                }
                else if (s.NpcId > 0) ids.Add(s.NpcId);
                if (ids.Count == 0) { res.Errors.Add(where + ": [mark] has no NPC to mark for this step; add a target, e.g. [mark=skull:1234]"); return; }
            }
            else
            {
                int id;
                if (int.TryParse(s.MarkTarget, out id))
                {
                    if (!db.Npcs.ContainsKey(id)) { res.Errors.Add(where + ": [mark] NPC id " + id + " is not in the database"); return; }
                    ids.Add(id);
                }
                else
                {
                    string want = BundledDb.Norm(s.MarkTarget);
                    var byName = db.Npcs.Where(kv => BundledDb.Norm(BundledDb.Str(kv.Value, BundledDb.N_NAME) ?? "") == want).Select(kv => kv.Key).ToList();
                    if (byName.Count > 1)
                    {
                        // Prefer the ones this step is about, then the ones spawning in this zone.
                        var related = new HashSet<int>();
                        if (rec != null)
                        {
                            foreach (var x in BundledDb.Ids(rec, BundledDb.Q_SNPC)) related.Add(x);
                            foreach (var x in BundledDb.Ids(rec, BundledDb.Q_ENPC)) related.Add(x);
                            var obj = BundledDb.Tab(rec, BundledDb.Q_OBJ);
                            foreach (var key in new[] { "c", "k" }) { var t = obj == null ? null : obj.Get(key) as LTable; if (t != null) foreach (var x in t.IntList()) related.Add(x); }
                        }
                        var narrowed = byName.Where(related.Contains).ToList();
                        if (narrowed.Count == 0) narrowed = byName.Where(x => db.NpcSpawns(x).Any(sp => db.Parent((int)sp[0]) == db.Parent(zone))).ToList();
                        if (narrowed.Count > 0) byName = narrowed;
                    }
                    if (byName.Count == 0) { res.Errors.Add(where + ": [mark] NPC '" + s.MarkTarget + "' not found in the database"); return; }
                    if (byName.Count > 1) { res.Errors.Add(where + ": [mark] NPC name '" + s.MarkTarget + "' is ambiguous (ids " + string.Join(",", byName.Select(x => x.ToString()).ToArray()) + "); use the id"); return; }
                    ids.AddRange(byName);
                }
            }
            s.MarkNpcs = ids.Distinct().OrderBy(x => x).ToList();
        }

        static double D(string s) { return double.Parse(s, CultureInfo.InvariantCulture); }

        static int RaceMaskOf(IEnumerable<string> races)
        {
            int m = 0;
            foreach (var r in races) m |= RaceBit[r];
            return m;
        }

        static int ResolveQuest(string arg, string verb, string where, CGuide g, CStep s, CompileResult res, RouteState st)
        {
            var db = res.Db;
            var m = Regex.Match(arg, @"^(\d+)\s*(.*)$");
            if (m.Success)
            {
                int id = int.Parse(m.Groups[1].Value);
                LTable rec;
                if (!db.Quests.TryGetValue(id, out rec)) { res.Errors.Add(where + ": quest id " + id + " is not in the TBC database"); return -1; }
                string given = m.Groups[2].Value.Trim();
                if (given.Length > 0 && BundledDb.Norm(given) != BundledDb.Norm(BundledDb.Str(rec, BundledDb.Q_NAME)))
                    res.Errors.Add(where + ": quest " + id + " is '" + BundledDb.Str(rec, BundledDb.Q_NAME) + "', not '" + given + "'");
                return id;
            }
            string key = BundledDb.Norm(arg);
            List<int> cands;
            if (!db.QuestsByName.TryGetValue(key, out cands))
            {
                var near = db.QuestsByName.Keys.Where(k => k.Contains(key) || key.Contains(k)).Take(3).ToList();
                res.Errors.Add(where + ": no quest named '" + arg + "'" + (near.Count > 0 ? " (similar: " + string.Join("; ", near.ToArray()) + ")" : ""));
                return -1;
            }
            // For turn-in/complete prefer the id accepted earlier on this route.
            int prev;
            if (verb != "accept" && st.AcceptedByName.TryGetValue(key, out prev) && cands.Contains(prev)) return prev;

            int fmask = g.Faction == "Alliance" ? ALLIANCE_MASK : g.Faction == "Horde" ? HORDE_MASK : (ALLIANCE_MASK | HORDE_MASK);
            var races = s.Races ?? g.Races;
            int rmask = races != null ? RaceMaskOf(races) : fmask;
            bool both = g.Faction == "Both";
            var classes = s.Classes ?? g.Classes;
            var filtered = cands.Where(id =>
            {
                var r = db.Quests[id];
                int qr = BundledDb.Num(r, BundledDb.Q_RACES);
                if (qr != 0 && (qr & rmask) == 0) return false;
                if (both && qr != 0 && ((qr & ALLIANCE_MASK) == 0 || (qr & HORDE_MASK) == 0)) return false;
                int qc = BundledDb.Num(r, BundledDb.Q_CLASSES);
                if (qc != 0 && classes != null && !classes.Any(c => (ClassBit[c] & qc) != 0)) return false;
                if (qc != 0 && classes == null) return false; // class quests need a [class=] filter
                return true;
            }).ToList();
            if (filtered.Count == 0)
            {
                // A class quest referenced without [class=...] - report clearly.
                var classOnly = cands.Where(id => BundledDb.Num(db.Quests[id], BundledDb.Q_CLASSES) != 0).ToList();
                if (classOnly.Count > 0) res.Errors.Add(where + ": '" + arg + "' is a class quest; add [class=...] (ids " + string.Join(",", classOnly.Select(x => x.ToString()).ToArray()) + ")");
                else res.Errors.Add(where + ": '" + arg + "' exists but not for " + g.Faction + (races != null ? " (" + string.Join(",", races.ToArray()) + ")" : "") + " (ids " + string.Join(",", cands.Select(x => x.ToString()).ToArray()) + ")");
                return -1;
            }
            if (filtered.Count == 1) return filtered[0];
            // Same-named chains (e.g. "The Night Watch" x3): on accept, take the link that is not done
            // yet and whose prerequisites this route has already turned in.
            if (verb == "accept")
            {
                var ready = filtered.Where(id =>
                {
                    if (st.Accepted.Contains(id) || st.TurnedIn.Contains(id)) return false;
                    var r = db.Quests[id];
                    var grp = BundledDb.Ids(r, BundledDb.Q_PREG);
                    var one = BundledDb.Ids(r, BundledDb.Q_PRES);
                    if (grp.Any(p => !st.TurnedIn.Contains(p))) return false;
                    if (one.Count > 0 && !one.Any(p => st.TurnedIn.Contains(p))) return false;
                    return true;
                }).ToList();
                if (ready.Count == 1) return ready[0];
                if (ready.Count > 1) filtered = ready;
            }
            else
            {
                var open = filtered.Where(id => st.Accepted.Contains(id) && !st.TurnedIn.Contains(id)).ToList();
                if (open.Count == 1) return open[0];
            }
            if (filtered.Count == 1) return filtered[0];
            // Prefer quests located in the guide zone, then those whose level fits.
            int zone = g.Zone;
            var inZone = filtered.Where(id =>
            {
                var r = db.Quests[id];
                int qz = BundledDb.Num(r, BundledDb.Q_ZONE);
                if (qz > 0 && db.Parent(qz) == db.Parent(zone)) return true;
                foreach (var n in BundledDb.Ids(r, BundledDb.Q_SNPC))
                    foreach (var sp in db.NpcSpawns(n)) if ((int)sp[0] == zone) return true;
                return false;
            }).ToList();
            if (inZone.Count == 1) return inZone[0];
            var pool = inZone.Count > 0 ? inZone : filtered;
            var lvlFit = pool.Where(id => { int rl = BundledDb.Num(db.Quests[id], BundledDb.Q_REQ); return rl >= g.MinLevel - 5 && rl <= g.MaxLevel + 1; }).ToList();
            if (lvlFit.Count == 1) return lvlFit[0];
            // Identical repeatable copies: take the lowest id but warn.
            var final = lvlFit.Count > 0 ? lvlFit : pool;
            res.Errors.Add(where + ": quest name '" + arg + "' is ambiguous for " + g.Faction + "; use one of ids " + string.Join(",", final.Select(x => x.ToString()).ToArray()));
            return -1;
        }

        static void CheckQuestFit(int q, LTable rec, string where, CGuide g, CStep s, CompileResult res)
        {
            int races = BundledDb.Num(rec, BundledDb.Q_RACES);
            int fmask = g.Faction == "Alliance" ? ALLIANCE_MASK : HORDE_MASK;
            if (g.Faction == "Both")
            {
                if (races != 0 && ((races & ALLIANCE_MASK) == 0 || (races & HORDE_MASK) == 0)) res.Errors.Add(where + ": quest " + q + " is faction-specific; not allowed in a Both guide");
            }
            else if (races != 0 && (races & fmask) == 0) res.Errors.Add(where + ": quest " + q + " is not available to " + g.Faction);
            var rlist = s.Races ?? g.Races;
            if (races != 0 && rlist != null)
            {
                var bad = rlist.Where(r => (RaceBit[r] & races) == 0).ToList();
                if (bad.Count > 0 && bad.Count == rlist.Count) res.Errors.Add(where + ": quest " + q + " not available to " + string.Join(",", rlist.ToArray()));
                else if (bad.Count > 0 && s.Kind == "accept")
                    res.Warnings.Add(where + ": quest " + q + " (" + BundledDb.Str(rec, 1) + ") not available to " + string.Join(",", bad.ToArray()) + "; engine will auto-skip for them");
            }
            int classes = BundledDb.Num(rec, BundledDb.Q_CLASSES);
            if (classes != 0)
            {
                var cl = s.Classes ?? g.Classes;
                if (cl == null) res.Errors.Add(where + ": class quest " + q + " needs [class=...]");
                else if (cl.Any(c => (ClassBit[c] & classes) == 0)) res.Errors.Add(where + ": quest " + q + " is not available to all of " + string.Join(",", cl.ToArray()));
            }
            int req = BundledDb.Num(rec, BundledDb.Q_REQ);
            if (s.Kind == "accept" && req > g.MaxLevel) res.Warnings.Add(where + ": quest " + q + " requires level " + req + " but guide ends at " + g.MaxLevel);
            int maxl = BundledDb.Num(rec, BundledDb.Q_MAXLVL);
            if (s.Kind == "accept" && maxl > 0 && maxl < g.MinLevel) res.Warnings.Add(where + ": quest " + q + " max level " + maxl + " below guide start");
            int special = BundledDb.Num(rec, BundledDb.Q_SPECIAL);
            if ((special & 1) != 0 && s.Kind == "accept") res.Warnings.Add(where + ": quest " + q + " is repeatable");
        }

        static void PlaceGiver(BundledDb db, List<int> npcs, List<int> objs, CStep s, int zone, ref int lz, ref double lx, ref double ly)
        {
            double bestD = double.MaxValue; double[] best = null; string who = null;
            foreach (var n in npcs)
                foreach (var sp in db.NpcSpawns(n))
                {
                    double d = Dist(sp, zone, lz, lx, ly);
                    if (d < bestD) { bestD = d; best = sp; who = db.NpcName(n); s.NpcId = n; }
                }
            foreach (var o in objs)
                foreach (var sp in db.ObjSpawns(o))
                {
                    double d = Dist(sp, zone, lz, lx, ly);
                    if (d < bestD) { bestD = d; best = sp; who = db.ObjName(o); }
                }
            if (who == null && npcs.Count > 0) who = db.NpcName(npcs[0]);
            if (who == null && objs.Count > 0) who = db.ObjName(objs[0]);
            s.Npc = who;
            if (best != null)
            {
                s.Zone = (int)best[0]; s.X = best[1]; s.Y = best[2];
                lz = s.Zone; lx = s.X; ly = s.Y;
            }
        }

        static void PlaceAt(List<double[]> spawns, CStep s, int zone, ref int lz, ref double lx, ref double ly)
        {
            double bestD = double.MaxValue; double[] best = null;
            foreach (var sp in spawns) { double d = Dist(sp, zone, lz, lx, ly); if (d < bestD) { bestD = d; best = sp; } }
            if (best == null) return;
            s.Zone = (int)best[0]; s.X = best[1]; s.Y = best[2];
            lz = s.Zone; lx = s.X; ly = s.Y;
        }

        // Distance heuristic: same zone as last point -> euclidean; guide zone -> +1000; else +5000.
        static double Dist(double[] sp, int guideZone, int lz, double lx, double ly)
        {
            int z = (int)sp[0];
            if (lx >= 0 && z == lz) return Math.Sqrt((sp[1] - lx) * (sp[1] - lx) + (sp[2] - ly) * (sp[2] - ly));
            if (z == guideZone) return 1000;
            return 5000;
        }

        static bool ObjectiveLocation(BundledDb db, LTable rec, int zone, double lx, double ly, out int oz, out double ox, out double oy)
        {
            oz = 0; ox = oy = -1;
            var obj = BundledDb.Tab(rec, BundledDb.Q_OBJ);
            var spawns = new List<double[]>();
            if (obj != null)
            {
                foreach (var key in new[] { "c", "k" })
                {
                    var l = obj.Get(key) as LTable;
                    if (l != null) foreach (var id in l.IntList()) spawns.AddRange(db.NpcSpawns(id));
                }
                var ol = obj.Get("o") as LTable;
                if (ol != null) foreach (var id in ol.IntList()) spawns.AddRange(db.ObjSpawns(id));
                var il = obj.Get("i") as LTable;
                if (il != null)
                    foreach (var id in il.IntList())
                    {
                        LTable it;
                        if (!db.Items.TryGetValue(id, out it)) continue;
                        foreach (var n in BundledDb.Ids(it, BundledDb.I_NPCDROPS)) spawns.AddRange(db.NpcSpawns(n));
                        foreach (var o in BundledDb.Ids(it, BundledDb.I_OBJDROPS)) spawns.AddRange(db.ObjSpawns(o));
                    }
            }
            var trig = BundledDb.Tab(rec, BundledDb.Q_TRIGGER);
            if (trig != null) spawns.AddRange(db.Spawns(trig.Get(2) as LTable));
            if (spawns.Count == 0) return false;
            double bestD = double.MaxValue; double[] best = null;
            foreach (var sp in spawns) { double d = Dist(sp, zone, zone, lx, ly); if (d < bestD) { bestD = d; best = sp; } }
            oz = (int)best[0]; ox = best[1]; oy = best[2];
            return true;
        }

        static int ResolveNpc(BundledDb db, string arg, string faction, int zone, double lx, double ly)
        {
            int id;
            if (int.TryParse(arg, out id)) return db.Npcs.ContainsKey(id) ? id : -1;
            string f = faction == "Alliance" ? "A" : faction == "Horde" ? "H" : "AH";
            int best = -1; double bestD = double.MaxValue;
            foreach (var kv in db.Npcs)
            {
                if (!string.Equals(BundledDb.Str(kv.Value, BundledDb.N_NAME), arg, StringComparison.OrdinalIgnoreCase)) continue;
                string fr = BundledDb.Str(kv.Value, BundledDb.N_FRIENDLY) ?? "";
                if (fr.Length > 0 && !fr.Contains(f)) continue;
                foreach (var sp in db.NpcSpawns(kv.Key))
                {
                    double d = Dist(sp, zone, zone, lx, ly);
                    if (d < bestD) { bestD = d; best = kv.Key; }
                }
                if (best < 0) best = kv.Key;
            }
            return best;
        }

        static int FindService(BundledDb db, int flag, string faction, int zone, double lx, double ly, string subName)
        {
            string f = faction == "Alliance" ? "A" : faction == "Horde" ? "H" : "AH";
            int best = -1; double bestD = double.MaxValue;
            foreach (var kv in db.Npcs)
            {
                var n = kv.Value;
                if ((BundledDb.Num(n, BundledDb.N_FLAGS) & flag) == 0) continue;
                string fr = BundledDb.Str(n, BundledDb.N_FRIENDLY) ?? "";
                if (!fr.Contains(f)) continue;
                if (subName != null && !string.Equals(BundledDb.Str(n, BundledDb.N_SUB), subName, StringComparison.OrdinalIgnoreCase)) continue;
                foreach (var sp in db.NpcSpawns(kv.Key))
                {
                    if ((int)sp[0] != zone && db.Parent((int)sp[0]) != db.Parent(zone)) continue;
                    double d = (lx >= 0) ? Math.Sqrt((sp[1] - lx) * (sp[1] - lx) + (sp[2] - ly) * (sp[2] - ly)) : 0;
                    if (d < bestD) { bestD = d; best = kv.Key; }
                }
            }
            return best;
        }

        static void EmitTrainSteps(CGuide g, CStep template, CompileResult res, int zone, string where, ref int lz, ref double lx, ref double ly)
        {
            // Which classes can be on this guide?
            var races = template.Races ?? g.Races ?? (g.Faction == "Alliance" ? AllianceRaces.ToList() : g.Faction == "Horde" ? HordeRaces.ToList() : AllianceRaces.Concat(HordeRaces).ToList());
            var classes = new HashSet<string>();
            foreach (var r in races) foreach (var c in RaceClasses[r]) classes.Add(c);
            if (template.Classes != null) classes.IntersectWith(template.Classes);
            if (g.Classes != null) classes.IntersectWith(g.Classes);
            double sx = lx, sy = ly; int sz = lz;
            foreach (var c in classes.OrderBy(c => c))
            {
                var s = new CStep { Kind = "train", Text = template.Text, Optional = template.Optional, Races = template.Races, Classes = new List<string> { c } };
                int npc = FindService(res.Db, FLAG_TRAINER, g.Faction, zone, sx, sy, ClassTrainerSub[c]);
                if (npc > 0)
                {
                    s.Npc = res.Db.NpcName(npc);
                    int tz = sz; double tx = sx, ty = sy;
                    PlaceAt(res.Db.NpcSpawns(npc), s, zone, ref tz, ref tx, ref ty);
                }
                else if (template.Text == null)
                {
                    s.Text = "No " + ClassTrainerSub[c].ToLowerInvariant() + " in this zone - train at the next town or capital.";
                }
                g.Steps.Add(s);
            }
        }

        // ------------------------------------------------------------------ cross checks
        static void CrossChecks(CompileResult res, Dictionary<string, RouteState> states)
        {
            var ids = new HashSet<string>(res.Guides.Select(g => g.Id));
            foreach (var g in res.Guides)
            {
                foreach (var n in g.Next)
                    if (!ids.Contains(n.Key)) res.Errors.Add(g.Id + ": @next references unknown guide " + n.Key);
                foreach (var s in g.Steps)
                    if (s.Kind == "guide" && !ids.Contains(s.GuideRef)) res.Errors.Add(g.Id + ": guide step references unknown guide " + s.GuideRef);
            }
            foreach (var kv in states)
            {
                foreach (var p in kv.Value.PendingPrereqChecks)
                {
                    int pre = Math.Abs(p.Key);
                    if (!kv.Value.TurnedIn.Contains(pre))
                    {
                        LTable r;
                        string nm = res.Db.Quests.TryGetValue(pre, out r) ? BundledDb.Str(r, 1) : "?";
                        res.Warnings.Add(p.Value + ": prerequisite " + pre + " '" + nm + "' is not turned in anywhere on " + kv.Key + " routes" + (p.Key < 0 ? " (one of several alternatives)" : ""));
                    }
                }
            }
        }

        // ------------------------------------------------------------------ output
        static string L(string s) { return s == null ? "nil" : LuaWriter.Str(s); }
        static string LList(List<string> l) { return "{" + string.Join(",", l.Select(x => LuaWriter.Str(x)).ToArray()) + "}"; }

        public static string StepLua(CStep s)
        {
            var sb = new StringBuilder("{" + LuaWriter.Str(s.Kind));
            if (s.Quest > 0) sb.Append(",q=").Append(s.Quest);
            if (s.Obj > 0) sb.Append(",obj=").Append(s.Obj);
            if (s.Title != null) sb.Append(",title=").Append(L(s.Title));
            if (s.Npc != null) sb.Append(",npc=").Append(L(s.Npc));
            if (s.X >= 0) sb.Append(",z=").Append(s.Zone).Append(",x=").Append(LuaWriter.Num(s.X)).Append(",y=").Append(LuaWriter.Num(s.Y));
            if (s.Text != null) sb.Append(",text=").Append(L(s.Text));
            if (s.Place != null) sb.Append(",place=").Append(L(s.Place));
            if (s.Dest != null) sb.Append(",dest=").Append(L(s.Dest));
            if (s.Level > 0) sb.Append(",level=").Append(s.Level);
            if (s.GuideRef != null) sb.Append(",guide=").Append(L(s.GuideRef));
            if (s.Mobs != null) sb.Append(",mobs=").Append(LList(s.Mobs));
            if (s.Location != null) sb.Append(",location=").Append(L(s.Location));
            if (s.Classes != null) sb.Append(",classes=").Append(LList(s.Classes));
            if (s.Races != null) sb.Append(",races=").Append(LList(s.Races));
            if (s.Faction != null) sb.Append(",faction=").Append(L(s.Faction));
            if (s.Optional) sb.Append(",optional=true");
            if (s.Elite) sb.Append(",elite=true");
            if (s.Group >= 0) sb.Append(",group=").Append(s.Group > 0 ? s.Group.ToString() : "true");
            if (s.Dungeon != null) sb.Append(",dungeon=").Append(L(s.Dungeon));
            if (s.MarkNpcs != null && s.MarkNpcs.Count > 0)
                sb.Append(",mark={i=").Append(s.MarkIcon).Append(",npcs={").Append(string.Join(",", s.MarkNpcs.Select(x => x.ToString()).ToArray())).Append("}}");
            sb.Append(",v=").Append(s.Verified ? 1 : 0);
            return sb.Append("}").ToString();
        }

        static void Write(CompileResult res, string addOnDir)
        {
            string outDir = Path.Combine(addOnDir, "Guides", "Compiled");
            Directory.CreateDirectory(outDir);
            foreach (var old in Directory.GetFiles(outDir, "*.lua")) File.Delete(old);
            var bySource = res.Guides.GroupBy(g => g.Source).OrderBy(x => x.Key, StringComparer.Ordinal).ToList();
            var xml = new StringBuilder("<Ui xmlns=\"http://www.blizzard.com/wow/ui/\">\n");
            xml.Append("<!-- GENERATED by tools/build.ps1 guides. Lists compiled guide files in route order. -->\n");
            foreach (var grp in bySource)
            {
                string fname = Regex.Replace(grp.Key.Replace(".guide", ""), @"[^A-Za-z0-9_]+", "_") + ".lua";
                var sb = new StringBuilder();
                sb.Append("-- TBCGuide - compiled guide data. GENERATED from guides-src/" + grp.Key + " by tools/build.ps1 guides.\n");
                sb.Append("-- DO NOT EDIT: edit the .guide source and rebuild. Guide routes and notes are original TBCGuide content\n");
                sb.Append("-- (GPL-3.0-only); quest ids, NPC names and coordinates were looked up in the bundled QuestieDB-derived data.\n");
                sb.Append("local _, ns = ...\n");
                foreach (var g in grp)
                {
                    sb.Append("ns.Guides:Register({\n");
                    sb.Append("  id=" + L(g.Id) + ", name=" + L(g.Name) + ", faction=" + L(g.Faction) + ", chapter=" + L(g.Chapter) + ",\n");
                    sb.Append("  minLevel=" + g.MinLevel + ", maxLevel=" + g.MaxLevel + ", zone=" + g.Zone + ", zoneName=" + L(g.ZoneName));
                    if (g.Start) sb.Append(", start=true");
                    if (g.Races != null) sb.Append(", races=" + LList(g.Races));
                    if (g.Classes != null) sb.Append(", classes=" + LList(g.Classes));
                    if (g.Desc != null) sb.Append(",\n  desc=" + L(g.Desc));
                    sb.Append(",\n  next={");
                    foreach (var n in g.Next)
                    {
                        sb.Append("{id=" + L(n.Key));
                        List<string> l;
                        if (n.Value.TryGetValue("races", out l)) sb.Append(",races=" + LList(l));
                        if (n.Value.TryGetValue("classes", out l)) sb.Append(",classes=" + LList(l));
                        if (n.Value.TryGetValue("faction", out l)) sb.Append(",faction=" + LuaWriter.Str(l[0]));
                        sb.Append("},");
                    }
                    sb.Append("},\n  steps={\n");
                    foreach (var s in g.Steps) sb.Append("    ").Append(StepLua(s)).Append(",\n");
                    sb.Append("  },\n})\n");
                }
                File.WriteAllText(Path.Combine(outDir, fname), sb.ToString(), new UTF8Encoding(false));
                xml.Append("  <Script file=\"" + fname + "\"/>\n");
            }
            xml.Append("</Ui>\n");
            File.WriteAllText(Path.Combine(outDir, "Guides.xml"), xml.ToString(), new UTF8Encoding(false));
        }
    }
}
