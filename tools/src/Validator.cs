// TBCGuide build tooling - content validation and coverage report.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Checks (errors fail the build; warnings are reported):
//   * every race/class combination (Database/RaceClass.lua) has a start guide and a guide
//     chain that reaches level 70 without level gaps, cycles or dead ends;
//   * guides compile (quest resolution etc. - see GuideCompiler);
//   * every class has a leveling build and a level-70 build; every build is legal against the
//     client talent tables (ranks, tier gating, prerequisites, 61-point budget);
//   * manifest interface matches Config/Target.lua; saved variables declared;
//   * bundled database sanity (counts, dangling references from guides).
// The coverage report (docs/COVERAGE_REPORT.md) is generated from the same data, so it can never
// claim more than the checks actually found.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    public sealed class ValidationResult
    {
        public int Errors, Warnings;
        public List<string> Messages = new List<string>();
        public string Summary { get { return string.Format("validate: {0} error(s), {1} warning(s)", Errors, Warnings); } }
        public void Err(string m) { Errors++; Messages.Add("ERROR " + m); }
        public void Warn(string m) { Warnings++; Messages.Add("warn  " + m); }
        public void Info(string m) { Messages.Add("info  " + m); }
    }

    public sealed class TalentInfo { public int Id, Tier, Col, Ranks, Tab, PreId, PreRank; public string Name, Class, TabName; }

    public sealed class BuildCheck
    {
        public string Id, Name, Class, Kind, Role, File;
        public int Points;
        public int[] PerTab = new int[3];
        public List<string> Errors = new List<string>();
    }

    public sealed class RouteInfo
    {
        public string Race, Class, Faction;
        public List<CGuide> Guides = new List<CGuide>();
        public List<string> Problems = new List<string>();
        public int ReachedLevel;
    }

    public static class Validator
    {
        // ---------------------------------------------------------------- talent data
        static readonly Regex TalentLine = new Regex("\\{id=(\\d+),name=\"((?:[^\"\\\\]|\\\\.)*)\",tier=(\\d+),column=(\\d+),ranks=(\\d+),spells=\\{[^}]*\\}(?:,prereq=\\{(\\d+),(\\d+)\\})?\\}");
        static readonly Regex ClassLine = new Regex(@"^T\.(\w+) = \{");
        static readonly Regex TabLine = new Regex("^\\s*\\{id=(\\d+),name=\"([^\"]+)\"");

        public static Dictionary<string, List<TalentInfo>> LoadTalents(string addOnDir)
        {
            var d = new Dictionary<string, List<TalentInfo>>();
            string cls = null, tabName = null; int tab = 0;
            foreach (var line in File.ReadAllLines(Path.Combine(addOnDir, "Talents", "Data", "TalentTrees.lua")))
            {
                var cm = ClassLine.Match(line);
                if (cm.Success) { cls = cm.Groups[1].Value; tab = 0; d[cls] = new List<TalentInfo>(); continue; }
                var tm = TalentLine.Match(line);
                if (tm.Success && cls != null)
                {
                    d[cls].Add(new TalentInfo
                    {
                        Id = int.Parse(tm.Groups[1].Value), Name = (string)LuaLiteralReader.ParseValue("\"" + tm.Groups[2].Value + "\"", "t"),
                        Tier = int.Parse(tm.Groups[3].Value), Col = int.Parse(tm.Groups[4].Value), Ranks = int.Parse(tm.Groups[5].Value),
                        PreId = tm.Groups[6].Success ? int.Parse(tm.Groups[6].Value) : 0, PreRank = tm.Groups[7].Success ? int.Parse(tm.Groups[7].Value) : 0,
                        Tab = tab, Class = cls, TabName = tabName
                    });
                    continue;
                }
                var tb = TabLine.Match(line);
                if (tb.Success && cls != null && line.Contains("background=")) { tab++; tabName = tb.Groups[2].Value; }
            }
            return d;
        }

        // Parses Talents/Builds/*.lua: ns.RegisterTalentBuilds("CLASS", { ...literal... })
        static readonly Regex RegisterCall = new Regex("RegisterTalentBuilds\\(\\s*\"(\\w+)\"\\s*,");

        public static List<BuildCheck> CheckBuilds(string addOnDir, Dictionary<string, List<TalentInfo>> talents)
        {
            var result = new List<BuildCheck>();
            foreach (var f in Directory.GetFiles(Path.Combine(addOnDir, "Talents", "Builds"), "*.lua").OrderBy(x => x))
            {
                string text = File.ReadAllText(f);
                var m = RegisterCall.Match(text);
                if (!m.Success) { result.Add(new BuildCheck { File = Path.GetFileName(f), Id = "?", Errors = { "no RegisterTalentBuilds call" } }); continue; }
                string cls = m.Groups[1].Value;
                int open = text.IndexOf('{', m.Index + m.Length);
                int close = MatchBrace(text, open);
                LTable list;
                try { list = LuaLiteralReader.ParseValue(text.Substring(open, close - open + 1), Path.GetFileName(f)) as LTable; }
                catch (Exception e) { result.Add(new BuildCheck { File = Path.GetFileName(f), Id = "?", Errors = { "parse error: " + e.Message } }); continue; }
                List<TalentInfo> tl;
                talents.TryGetValue(cls, out tl);
                foreach (var kv in list.Pairs())
                {
                    var b = kv.Value as LTable;
                    if (b == null) continue;
                    var bc = new BuildCheck
                    {
                        File = Path.GetFileName(f), Class = cls, Id = b.Get("id") as string, Name = b.Get("name") as string,
                        Kind = b.Get("kind") as string, Role = b.Get("role") as string
                    };
                    result.Add(bc);
                    if (bc.Id == null || bc.Name == null || bc.Kind == null) bc.Errors.Add("missing id/name/kind");
                    if (tl == null) { bc.Errors.Add("no talent data for class " + cls); continue; }
                    var ranks = new Dictionary<int, int>();
                    var picks = b.Get("picks") as LTable;
                    if (picks == null) { bc.Errors.Add("no picks"); continue; }
                    int n = 0;
                    foreach (var pk in picks.Pairs())
                    {
                        var p = pk.Value as LTable;
                        string nm = p == null ? null : p.Get(1) as string;
                        int count = p != null && p.Get(2) is double ? (int)(double)p.Get(2) : 1;
                        var matches = tl.Where(x => string.Equals(x.Name, nm, StringComparison.OrdinalIgnoreCase)).ToList();
                        if (matches.Count == 0 && nm != null && nm.Contains(":"))
                        {
                            var parts = nm.Split(new[] { ':' }, 2);
                            matches = tl.Where(x => string.Equals(x.TabName, parts[0], StringComparison.OrdinalIgnoreCase) && string.Equals(x.Name, parts[1], StringComparison.OrdinalIgnoreCase)).ToList();
                        }
                        if (matches.Count != 1) { bc.Errors.Add((matches.Count == 0 ? "unknown" : "ambiguous") + " talent '" + nm + "'"); continue; }
                        var t = matches[0];
                        for (int k = 0; k < count; k++)
                        {
                            n++;
                            int cur; ranks.TryGetValue(t.Id, out cur);
                            int inTab = bc.PerTab[t.Tab - 1];
                            if (cur >= t.Ranks) bc.Errors.Add(string.Format("point {0}: {1} exceeds max rank {2}", n, t.Name, t.Ranks));
                            else if (inTab < (t.Tier - 1) * 5) bc.Errors.Add(string.Format("point {0}: {1} (tier {2}) needs {3} points in {4}, has {5}", n, t.Name, t.Tier, (t.Tier - 1) * 5, t.TabName, inTab));
                            else if (t.PreId > 0)
                            {
                                int pr; ranks.TryGetValue(t.PreId, out pr);
                                if (pr < t.PreRank)
                                {
                                    var pre = tl.FirstOrDefault(x => x.Id == t.PreId);
                                    bc.Errors.Add(string.Format("point {0}: {1} requires {2} {3}/{4} (has {5})", n, t.Name, pre != null ? pre.Name : "?", t.PreRank, pre != null ? pre.Ranks : 0, pr));
                                }
                            }
                            ranks[t.Id] = cur + 1;
                            bc.PerTab[t.Tab - 1]++;
                        }
                    }
                    bc.Points = n;
                    if (n > 61) bc.Errors.Add(n + " points exceeds 61");
                    if (n < 61) bc.Errors.Add("only " + n + " of 61 points allocated");
                }
            }
            return result;
        }

        static int MatchBrace(string s, int open)
        {
            int depth = 0; bool str = false; char q = '\0';
            for (int i = open; i < s.Length; i++)
            {
                char c = s[i];
                if (str) { if (c == '\\') { i++; continue; } if (c == q) str = false; continue; }
                if (c == '"' || c == '\'') { str = true; q = c; continue; }
                if (c == '-' && i + 1 < s.Length && s[i + 1] == '-') { while (i < s.Length && s[i] != '\n') i++; continue; }
                if (c == '{') depth++;
                else if (c == '}') { depth--; if (depth == 0) return i; }
            }
            return s.Length - 1;
        }

        // ---------------------------------------------------------------- race/class
        static readonly Regex RaceLine = new Regex("^\\s+(\\w+) = \\{id=(\\d+),faction=\"(\\w+)\",name=\"[^\"]+\",classes=\\{([^}]*)\\}");

        public static List<Tuple<string, string, string>> LoadCombos(string addOnDir)
        {
            var l = new List<Tuple<string, string, string>>();
            foreach (var line in File.ReadAllLines(Path.Combine(addOnDir, "Database", "RaceClass.lua")))
            {
                var m = RaceLine.Match(line);
                if (!m.Success) continue;
                foreach (Match c in Regex.Matches(m.Groups[4].Value, "\"(\\w+)\""))
                    l.Add(Tuple.Create(m.Groups[1].Value, c.Groups[1].Value, m.Groups[3].Value));
            }
            return l;
        }

        static bool Applies(CGuide g, string race, string cls, string faction)
        {
            if (g.Faction != "Both" && g.Faction != faction) return false;
            if (g.Races != null && !g.Races.Contains(race)) return false;
            if (g.Classes != null && !g.Classes.Contains(cls)) return false;
            return true;
        }

        public static RouteInfo Route(List<CGuide> guides, string race, string cls, string faction)
        {
            var r = new RouteInfo { Race = race, Class = cls, Faction = faction };
            var start = guides.FirstOrDefault(g => g.Start && g.Races != null && g.Races.Contains(race) && Applies(g, race, cls, faction));
            if (start == null) { r.Problems.Add("no start guide"); return r; }
            var seen = new HashSet<string>();
            var cur = start;
            int lastMax = 0;
            while (cur != null)
            {
                if (!seen.Add(cur.Id)) { r.Problems.Add("cycle at " + cur.Id); break; }
                if (!Applies(cur, race, cls, faction)) r.Problems.Add(cur.Id + " does not apply to this race/class/faction");
                if (lastMax > 0 && cur.MinLevel > lastMax + 2) r.Problems.Add(string.Format("level gap {0} -> {1} entering {2}", lastMax, cur.MinLevel, cur.Id));
                r.Guides.Add(cur);
                lastMax = Math.Max(lastMax, cur.MaxLevel);
                CGuide next = null;
                foreach (var n in cur.Next)
                {
                    List<string> l;
                    if (n.Value.TryGetValue("races", out l) && !l.Contains(race)) continue;
                    if (n.Value.TryGetValue("classes", out l) && !l.Contains(cls)) continue;
                    if (n.Value.TryGetValue("faction", out l) && l[0] != faction) continue;
                    next = guides.FirstOrDefault(g => g.Id == n.Key);
                    if (next != null) break;
                }
                cur = next;
            }
            r.ReachedLevel = lastMax;
            if (lastMax < 70) r.Problems.Add("route ends at level " + lastMax);
            return r;
        }

        // ---------------------------------------------------------------- run
        public static ValidationResult Run(string root, string addOnDir)
        {
            var v = new ValidationResult();
            var comp = GuideCompiler.CompileAll(Path.Combine(root, "guides-src"), addOnDir, false);
            foreach (var e in comp.Errors) v.Err("guide: " + e);
            v.Info(comp.Summary);

            // Race/class coverage
            var combos = LoadCombos(addOnDir);
            if (combos.Count != 52) v.Warn("expected 52 race/class combinations for TBC, found " + combos.Count);
            foreach (var c in combos)
            {
                var r = Route(comp.Guides, c.Item1, c.Item2, c.Item3);
                foreach (var p in r.Problems) v.Err(string.Format("route {0} {1}: {2}", c.Item1, c.Item2, p));
            }
            // Guides must not offer races/classes that cannot exist
            var legal = new HashSet<string>(combos.Select(c => c.Item1 + "/" + c.Item2));
            foreach (var g in comp.Guides)
                if (g.Races != null && g.Classes != null)
                    foreach (var r in g.Races) foreach (var cl in g.Classes)
                            if (!legal.Contains(r + "/" + cl)) v.Warn(g.Id + " lists illegal combination " + r + "/" + cl);
            foreach (var g in comp.Guides)
                foreach (var s in g.Steps)
                    if (s.Classes != null && s.Races != null)
                        foreach (var r in s.Races) foreach (var cl in s.Classes)
                                if (!legal.Contains(r + "/" + cl)) v.Warn(g.Id + ": step targets illegal combination " + r + "/" + cl);
            if (!comp.Guides.Any(g => g.Chapter == "Outland")) v.Err("no Outland guides");
            // Reachability: every guide should be on at least one route
            var used = new HashSet<string>();
            foreach (var c in combos) foreach (var g in Route(comp.Guides, c.Item1, c.Item2, c.Item3).Guides) used.Add(g.Id);
            foreach (var g in comp.Guides) if (!used.Contains(g.Id)) v.Warn("guide " + g.Id + " is not on any race/class route (reachable from the browser only)");

            // Talents
            var talents = LoadTalents(addOnDir);
            int talentCount = talents.Values.Sum(x => x.Count);
            if (talentCount < 500) v.Err("talent data looks incomplete (" + talentCount + " talents)");
            var builds = CheckBuilds(addOnDir, talents);
            foreach (var b in builds) foreach (var e in b.Errors) v.Err(string.Format("build {0} ({1}): {2}", b.Id, b.File, e));
            foreach (var cls in new[] { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" })
            {
                if (!builds.Any(b => b.Class == cls && b.Kind == "leveling")) v.Err(cls + " has no leveling build");
                if (!builds.Any(b => b.Class == cls && b.Kind == "endgame")) v.Err(cls + " has no level-70 build");
            }
            if (builds.Select(b => b.Id).Distinct().Count() != builds.Count) v.Err("duplicate build ids");

            // Manifest vs target config
            string toc = File.ReadAllText(Path.Combine(addOnDir, "TBCGuide.toc"));
            string target = File.ReadAllText(Path.Combine(addOnDir, "Config", "Target.lua"));
            var ti = Regex.Match(toc, @"## Interface:\s*(\d+)");
            var ci = Regex.Match(target, @"interface\s*=\s*(\d+)");
            if (!ti.Success || !ci.Success || ti.Groups[1].Value != ci.Groups[1].Value)
                v.Err("TOC interface and Config/Target.lua interface differ");
            if (!toc.Contains("## SavedVariables: TBCGuideDB") || !toc.Contains("## SavedVariablesPerCharacter: TBCGuideCharDB"))
                v.Err("saved variables not declared in TOC");

            // Database sanity
            var db = comp.Db;
            if (db.Quests.Count < 5000) v.Err("quest database looks truncated (" + db.Quests.Count + ")");
            int missingNames = db.Quests.Values.Count(q => !(q.Get(1) is string));
            if (missingNames > 0) v.Err(missingNames + " quest records without names");
            int npcMissing = 0;
            foreach (var q in db.Quests.Values)
                foreach (var id in BundledDb.Ids(q, BundledDb.Q_SNPC).Concat(BundledDb.Ids(q, BundledDb.Q_ENPC)))
                    if (!db.Npcs.ContainsKey(id)) npcMissing++;
            if (npcMissing > 50) v.Warn(npcMissing + " quest giver references point at NPCs missing from the data");
            v.Info(string.Format("database: {0} quests, {1} npcs, {2} objects, {3} items, {4} zones", db.Quests.Count, db.Npcs.Count, db.Objects.Count, db.Items.Count, db.UiMap.Count));
            v.Info(string.Format("talents: {0} talents, {1} builds", talentCount, builds.Count));
            return v;
        }

        // ---------------------------------------------------------------- report
        public static void WriteCoverageReport(string root, string addOnDir, string path)
        {
            var comp = GuideCompiler.CompileAll(Path.Combine(root, "guides-src"), addOnDir, false);
            var combos = LoadCombos(addOnDir);
            var talents = LoadTalents(addOnDir);
            var builds = CheckBuilds(addOnDir, talents);
            var v = Run(root, addOnDir);
            var sb = new StringBuilder();
            sb.AppendLine("# TBCGuide coverage report");
            sb.AppendLine();
            sb.AppendLine("Generated by `tools/build.ps1 report` from the actual guide sources, compiled data and talent files.");
            sb.AppendLine("It reports what the automated checks found. It is **not** evidence of in-game testing: none of this has been run in the game client.");
            sb.AppendLine();
            sb.AppendLine("## Summary");
            sb.AppendLine();
            sb.AppendLine("| Item | Count |");
            sb.AppendLine("|---|---|");
            sb.AppendLine("| Guides | " + comp.Guides.Count + " (" + comp.Guides.Count(g => g.Chapter == "Azeroth") + " Azeroth, " + comp.Guides.Count(g => g.Chapter == "Outland") + " Outland) |");
            sb.AppendLine("| Guide steps | " + comp.Guides.Sum(g => g.Steps.Count) + " |");
            int qsteps = comp.Guides.Sum(g => g.Steps.Count(s => s.Quest > 0));
            sb.AppendLine("| Quest steps (accept/complete/turn-in) | " + qsteps + " |");
            sb.AppendLine("| Distinct quests referenced | " + comp.Guides.SelectMany(g => g.Steps).Where(s => s.Quest > 0).Select(s => s.Quest).Distinct().Count() + " |");
            sb.AppendLine("| Steps with database-derived coordinates | " + comp.Guides.Sum(g => g.Steps.Count(s => s.X >= 0 && s.Verified)) + " |");
            sb.AppendLine("| Steps with hand-written coordinates (unverified) | " + comp.Guides.Sum(g => g.Steps.Count(s => s.X >= 0 && !s.Verified)) + " |");
            sb.AppendLine("| Race/class combinations | " + combos.Count + " |");
            sb.AppendLine("| Talent builds | " + builds.Count + " (" + builds.Count(b => b.Errors.Count == 0) + " pass validation) |");
            sb.AppendLine("| Validation | " + v.Summary + " |");
            sb.AppendLine("| Compiler warnings | " + comp.Warnings.Count + " (see docs/generated/guide-warnings.log) |");
            sb.AppendLine();
            sb.AppendLine("## Race/class routes (level 1 to 70)");
            sb.AppendLine();
            sb.AppendLine("Each race/class combination is followed from its racial start guide through the `@next` chain.");
            sb.AppendLine();
            sb.AppendLine("| Race | Class | Faction | Guides | Reaches | Problems |");
            sb.AppendLine("|---|---|---|---|---|---|");
            foreach (var c in combos.OrderBy(x => x.Item3).ThenBy(x => x.Item1).ThenBy(x => x.Item2))
            {
                var r = Route(comp.Guides, c.Item1, c.Item2, c.Item3);
                sb.AppendLine(string.Format("| {0} | {1} | {2} | {3} | {4} | {5} |", c.Item1, c.Item2, c.Item3, r.Guides.Count, r.ReachedLevel, r.Problems.Count == 0 ? "none" : string.Join("; ", r.Problems.ToArray())));
            }
            sb.AppendLine();
            sb.AppendLine("## Guides");
            sb.AppendLine();
            sb.AppendLine("| Guide | Faction | Levels | Zone | Steps | Quests | Optional/elite/group steps |");
            sb.AppendLine("|---|---|---|---|---|---|---|");
            foreach (var g in comp.Guides.OrderBy(g => g.Chapter == "Outland").ThenBy(g => g.MinLevel).ThenBy(g => g.Faction))
            {
                sb.AppendLine(string.Format("| {0} | {1} | {2}-{3} | {4} | {5} | {6} | {7} |", g.Name, g.Faction, g.MinLevel, g.MaxLevel, g.ZoneName,
                    g.Steps.Count, g.Steps.Where(s => s.Quest > 0).Select(s => s.Quest).Distinct().Count(),
                    g.Steps.Count(s => s.Optional || s.Elite || s.Group >= 0)));
            }
            sb.AppendLine();
            sb.AppendLine("### Zones covered");
            sb.AppendLine();
            var az = comp.Guides.Where(g => g.Chapter == "Azeroth").Select(g => g.ZoneName).Distinct().OrderBy(x => x).ToList();
            var ol = comp.Guides.Where(g => g.Chapter == "Outland").Select(g => g.ZoneName).Distinct().OrderBy(x => x).ToList();
            sb.AppendLine("- **Azeroth (" + az.Count + "):** " + string.Join(", ", az.ToArray()));
            sb.AppendLine("- **Outland (" + ol.Count + "):** " + string.Join(", ", ol.ToArray()));
            sb.AppendLine();
            sb.AppendLine("## Talent builds");
            sb.AppendLine();
            sb.AppendLine("| Class | Build | Kind | Role | Points (trees) | Validation |");
            sb.AppendLine("|---|---|---|---|---|---|");
            foreach (var b in builds.OrderBy(b => b.Class).ThenBy(b => b.Kind))
                sb.AppendLine(string.Format("| {0} | {1} | {2} | {3} | {4} ({5}/{6}/{7}) | {8} |", b.Class, b.Name, b.Kind, b.Role, b.Points, b.PerTab[0], b.PerTab[1], b.PerTab[2], b.Errors.Count == 0 ? "pass" : string.Join("; ", b.Errors.ToArray())));
            sb.AppendLine();
            sb.AppendLine("## Data awaiting verification");
            sb.AppendLine();
            sb.AppendLine("- Guide **routes, ordering and notes** are original and were written without in-game testing. Quest ids, names, faction/race/class limits and NPC coordinates come from the database, but the practical route (XP sufficiency, travel efficiency) needs play-testing.");
            sb.AppendLine("- **" + comp.Warnings.Count(w => w.Contains("no objective locations")) + " complete-steps** have no objective location in the data (escort, talk or event quests). The arrow cannot target them; the step text still shows the objective.");
            sb.AppendLine("- **" + comp.Warnings.Count(w => w.Contains("prerequisite")) + " prerequisite warnings**: a quest's prerequisite is not turned in on the route (usually an alternative chain). The engine auto-skips unavailable quests at runtime.");
            sb.AppendLine("- **Class advice** text (Classes/ClassAdvice.lua) is marked unverified. Ability training levels are from developer knowledge.");
            sb.AppendLine("- **Talent builds** are legal against the 2.5.6 client tables, but how good they are is a judgement call, not something tested.");
            sb.AppendLine();
            sb.AppendLine("## Known compatibility limitations");
            sb.AppendLine();
            sb.AppendLine("See docs/KNOWN_LIMITATIONS.md and docs/COMPATIBILITY.md.");
            File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
        }
    }
}
