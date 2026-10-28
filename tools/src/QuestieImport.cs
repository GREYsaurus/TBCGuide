// TBCGuide build tooling - QuestieDB (TBC) importer.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Reads the raw TBC entity tables from a pinned QuestieDB source checkout and
// writes the trimmed, re-keyed Lua data files that ship in
// TBCGuide/Database/QuestieTBC/. The output layout is documented in
// TBCGuide/Database/Schema.lua and docs/DATA_PIPELINE.md.
//
// The data itself is upstream material (see THIRD_PARTY_LICENSES.md); this
// file is only the transformation.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    public sealed class QuestieData
    {
        public Dictionary<int, LTable> Quests = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Npcs = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Objects = new Dictionary<int, LTable>();
        public Dictionary<int, LTable> Items = new Dictionary<int, LTable>();
        public Dictionary<int, int> AreaToUiMap = new Dictionary<int, int>();
        public Dictionary<int, string> AreaNames = new Dictionary<int, string>();
        public Dictionary<int, int> SubZoneParent = new Dictionary<int, int>();
        public List<string> Warnings = new List<string>();

        // Upstream key indices (src/meta/*Meta.lua at the pinned commit).
        public const int Q_NAME = 1, Q_STARTED = 2, Q_FINISHED = 3, Q_REQLEVEL = 4, Q_LEVEL = 5, Q_RACES = 6,
            Q_CLASSES = 7, Q_OBJTEXT = 8, Q_TRIGGER = 9, Q_OBJECTIVES = 10, Q_SOURCEITEM = 11, Q_PREGROUP = 12,
            Q_PRESINGLE = 13, Q_CHILD = 14, Q_INGROUP = 15, Q_EXCLUSIVE = 16, Q_ZONE = 17, Q_SKILL = 18,
            Q_MINREP = 19, Q_MAXREP = 20, Q_REQSOURCE = 21, Q_NEXT = 22, Q_FLAGS = 23, Q_SPECIAL = 24,
            Q_PARENT = 25, Q_REPREWARD = 26, Q_BREADCRUMBFOR = 27, Q_BREADCRUMBS = 28, Q_EXTRAOBJ = 29,
            Q_REQSPELL = 30, Q_REQSPEC = 31, Q_MAXLEVEL = 32;
        public const int N_NAME = 1, N_MINLEVEL = 4, N_MAXLEVEL = 5, N_RANK = 6, N_SPAWNS = 7, N_WAYPOINTS = 8,
            N_ZONE = 9, N_QSTARTS = 10, N_QENDS = 11, N_FACTIONID = 12, N_FRIENDLY = 13, N_SUBNAME = 14, N_FLAGS = 15;
        public const int O_NAME = 1, O_QSTARTS = 2, O_QENDS = 3, O_SPAWNS = 4, O_ZONE = 5;
        public const int I_NAME = 1, I_NPCDROPS = 2, I_OBJDROPS = 3, I_ITEMDROPS = 4, I_STARTQUEST = 5,
            I_VENDORS = 14;

        static Dictionary<int, LTable> LoadEntityFile(string path, string marker)
        {
            string text = File.ReadAllText(path, Encoding.UTF8);
            string body = LuaLiteralReader.ExtractLongString(text, marker);
            var root = LuaLiteralReader.ParseValue(body, Path.GetFileName(path)) as LTable;
            if (root == null) throw new LuaParseException(path + ": data is not a table");
            var d = new Dictionary<int, LTable>();
            foreach (var kv in root.Pairs())
            {
                var row = kv.Value as LTable;
                if (kv.Key is double && row != null) d[(int)(double)kv.Key] = row;
            }
            return d;
        }

        public static QuestieData Load(string qdbRoot)
        {
            var q = new QuestieData();
            string dir = Path.Combine(qdbRoot, "data", "TBC");
            q.Quests = LoadEntityFile(Path.Combine(dir, "tbcQuestDB.lua"), "QuestieDB.questData");
            q.Npcs = LoadEntityFile(Path.Combine(dir, "tbcNpcDB.lua"), "QuestieDB.npcData");
            q.Objects = LoadEntityFile(Path.Combine(dir, "tbcObjectDB.lua"), "QuestieDB.objectData");
            q.Items = LoadEntityFile(Path.Combine(dir, "tbcItemDB.lua"), "QuestieDB.itemData");
            q.LoadZones(qdbRoot);
            return q;
        }

        static readonly Regex MapLine = new Regex(@"^\s*\[(\d+)\]\s*=\s*(\d+),?\s*(?:--\s*(.*))?$");

        void LoadZones(string qdbRoot)
        {
            string z = Path.Combine(qdbRoot, "support", "Zones");
            // uiMapIdToAreaId: [uiMap] = areaId, -- Name
            foreach (var line in File.ReadAllLines(Path.Combine(z, "uiMapIdToAreaId.lua")))
            {
                var m = MapLine.Match(line);
                if (!m.Success) continue;
                int ui = int.Parse(m.Groups[1].Value), area = int.Parse(m.Groups[2].Value);
                if (area == 0) continue;
                if (!AreaToUiMap.ContainsKey(area)) AreaToUiMap[area] = ui;
                string nm = m.Groups[3].Value.Trim();
                if (nm.Length > 0 && !AreaNames.ContainsKey(area)) AreaNames[area] = nm;
            }
            // areaIdToUiMapId overrides win.
            foreach (var line in File.ReadAllLines(Path.Combine(z, "areaIdToUiMapId.lua")))
            {
                var m = MapLine.Match(line);
                if (!m.Success) continue;
                int area = int.Parse(m.Groups[1].Value), ui = int.Parse(m.Groups[2].Value);
                if (area == 0) continue;
                AreaToUiMap[area] = ui;
                string nm = m.Groups[3].Value.Trim();
                if (nm.Length > 0 && !AreaNames.ContainsKey(area)) AreaNames[area] = nm;
            }
            string sub = File.ReadAllText(Path.Combine(z, "subZoneToParentZone.lua"));
            int lb = sub.IndexOf("[[return", StringComparison.Ordinal);
            if (lb >= 0)
            {
                var t = LuaLiteralReader.ParseValue(LuaLiteralReader.ExtractLongString(sub.Substring(lb - 2), "="), "subZoneToParentZone") as LTable;
                if (t != null)
                    foreach (var kv in t.Pairs())
                        if (kv.Key is double && kv.Value is double) SubZoneParent[(int)(double)kv.Key] = (int)(double)kv.Value;
            }
            else
            {
                foreach (var line in sub.Split('\n'))
                {
                    var m = MapLine.Match(line);
                    if (m.Success) SubZoneParent[int.Parse(m.Groups[1].Value)] = int.Parse(m.Groups[2].Value);
                }
            }
        }

        // ---- helpers -------------------------------------------------------

        public static string S(LTable t, int i) { return t == null ? null : t.Get(i) as string; }
        public static int N(LTable t, int i)
        {
            if (t == null) return 0;
            object v = t.Get(i);
            return v is double ? (int)(double)v : 0;
        }
        public static LTable T(LTable t, int i) { return t == null ? null : t.Get(i) as LTable; }
        public static List<int> Ids(LTable t) { return t == null ? new List<int>() : t.IntList(); }

        public int ParentZone(int area)
        {
            int guard = 0;
            int p;
            while (SubZoneParent.TryGetValue(area, out p) && p != area && guard++ < 8) area = p;
            return area;
        }

        public List<int> QuestStartNpcs(LTable q) { return Ids(T(T(q, Q_STARTED), 1)); }
        public List<int> QuestStartObjects(LTable q) { return Ids(T(T(q, Q_STARTED), 2)); }
        public List<int> QuestStartItems(LTable q) { return Ids(T(T(q, Q_STARTED), 3)); }
        public List<int> QuestEndNpcs(LTable q) { return Ids(T(T(q, Q_FINISHED), 1)); }
        public List<int> QuestEndObjects(LTable q) { return Ids(T(T(q, Q_FINISHED), 2)); }

        // Objective groups: 1 creatures, 2 objects, 3 items, 4 reputation, 5 killCredit, 6 spell
        public List<int> ObjectiveIds(LTable q, int group)
        {
            var r = new List<int>();
            var g = T(T(q, Q_OBJECTIVES), group);
            if (g == null) return r;
            if (group == 5)
            {
                foreach (var kv in g.Pairs())
                {
                    var kc = kv.Value as LTable;
                    if (kc == null) continue;
                    r.AddRange(Ids(T(kc, 1)));
                    int root = N(kc, 2);
                    if (root > 0) r.Add(root);
                }
                return r;
            }
            foreach (var kv in g.Pairs())
            {
                var e = kv.Value as LTable;
                if (e != null) { int id = N(e, 1); if (id > 0) r.Add(id); }
            }
            return r;
        }
    }

    public static class QuestieExporter
    {
        const int MaxSpawnsGiver = 4;
        const int MaxSpawnsMob = 10;
        const int MaxZonesPerNpc = 3;
        const int MaxDropSources = 12;

        // npcFlags (TBC): gossip 1, questgiver 2, vendor 128, flightmaster 8192, trainer 16,
        // class trainer 32, profession trainer 64, innkeeper 65536, banker 131072.
        const int FLAG_TRAINER = 16, FLAG_FLIGHTMASTER = 8192, FLAG_INNKEEPER = 65536;

        static string Hdr(string what, string provenance)
        {
            return "-- TBCGuide - " + what + "\n" +
                   "-- GENERATED by tools/build.ps1 import-questie. DO NOT EDIT BY HAND.\n" +
                   "-- Derived from QuestieDB TBC data. " + provenance + "\n" +
                   "-- Upstream data licence/attribution: see NOTICE.md and THIRD_PARTY_LICENSES.md.\n" +
                   "-- The transformation code is GPL-3.0-only; upstream data keeps its upstream terms.\n" +
                   "local _, ns = ...\n";
        }

        static LTable Trim(LTable spawns, int maxPerZone, int maxZones, int preferZone)
        {
            if (spawns == null) return null;
            var zones = new List<KeyValuePair<int, LTable>>();
            foreach (var kv in spawns.Pairs())
            {
                var pts = kv.Value as LTable;
                if (kv.Key is double && pts != null && pts.Count > 0) zones.Add(new KeyValuePair<int, LTable>((int)(double)kv.Key, pts));
            }
            zones.Sort((a, b) =>
            {
                if (a.Key == preferZone) return -1;
                if (b.Key == preferZone) return 1;
                return b.Value.Count.CompareTo(a.Value.Count);
            });
            var outT = new LTable();
            int nz = 0;
            foreach (var z in zones)
            {
                if (nz++ >= maxZones) break;
                var pts = new LTable();
                int n = z.Value.Count;
                int take = Math.Min(n, maxPerZone);
                for (int k = 0; k < take; k++)
                {
                    int idx = 1 + (int)((long)k * n / take);
                    var pt = z.Value.Get(idx) as LTable;
                    if (pt == null) continue;
                    object x = pt.Get(1), y = pt.Get(2);
                    if (!(x is double) || !(y is double)) continue;
                    double dx = (double)x, dy = (double)y;
                    if (dx < 0 || dy < 0) continue; // upstream uses -1,-1 for instanced/unknown
                    var p2 = new LTable(); p2.Append(Math.Round(dx, 1)); p2.Append(Math.Round(dy, 1));
                    pts.Append(p2);
                }
                if (pts.Count > 0) outT.Set((double)z.Key, pts);
            }
            return outT.Pairs().Any() ? outT : null;
        }

        static LTable IdTable(IEnumerable<int> ids, int max)
        {
            var t = new LTable();
            int n = 0;
            foreach (var id in ids) { if (n++ >= max) break; t.Append((double)id); }
            return t.Count > 0 ? t : null;
        }

        public static Dictionary<string, int> Export(QuestieData d, string outDir, string provenance)
        {
            Directory.CreateDirectory(outDir);
            var stats = new Dictionary<string, int>();
            var needNpc = new HashSet<int>();
            var giverNpc = new HashSet<int>();
            var needObj = new HashSet<int>();
            var needItem = new HashSet<int>();

            // ---------------- Quests ----------------
            var sb = new StringBuilder(Hdr("Quest records", provenance));
            sb.Append("local Q = ns.QDB.quests\n");
            foreach (var id in d.Quests.Keys.OrderBy(k => k))
            {
                var q = d.Quests[id];
                string name = QuestieData.S(q, QuestieData.Q_NAME);
                if (string.IsNullOrEmpty(name)) continue;
                var r = new LTable();
                r.Append(name);                                                         // 1 name
                r.Append((double)QuestieData.N(q, QuestieData.Q_REQLEVEL));               // 2 requiredLevel
                r.Append((double)QuestieData.N(q, QuestieData.Q_LEVEL));                  // 3 questLevel
                r.Append((double)QuestieData.N(q, QuestieData.Q_RACES));                  // 4 requiredRaces
                r.Append((double)QuestieData.N(q, QuestieData.Q_CLASSES));                // 5 requiredClasses
                var sn = d.QuestStartNpcs(q); var so = d.QuestStartObjects(q); var si = d.QuestStartItems(q);
                var en = d.QuestEndNpcs(q); var eo = d.QuestEndObjects(q);
                r.Append(IdTable(sn, 20));                                              // 6 start npcs
                r.Append(IdTable(so, 20));                                              // 7 start objects
                r.Append(IdTable(si, 5));                                               // 8 start items
                r.Append(IdTable(en, 20));                                              // 9 end npcs
                r.Append(IdTable(eo, 20));                                              // 10 end objects
                var ot = QuestieData.T(q, QuestieData.Q_OBJTEXT);
                string otxt = null;
                if (ot != null)
                {
                    var parts = new List<string>();
                    foreach (var kv in ot.Pairs()) if (kv.Value is string) parts.Add((string)kv.Value);
                    otxt = string.Join("\n", parts.ToArray());
                }
                r.Append(otxt);                                                         // 11 objective text
                var obj = new LTable();
                var oc = d.ObjectiveIds(q, 1); var oo = d.ObjectiveIds(q, 2); var oi = d.ObjectiveIds(q, 3);
                var ok = d.ObjectiveIds(q, 5);
                if (oc.Count > 0) obj.Set("c", IdTable(oc, 30));
                if (oo.Count > 0) obj.Set("o", IdTable(oo, 30));
                if (oi.Count > 0) obj.Set("i", IdTable(oi, 30));
                if (ok.Count > 0) obj.Set("k", IdTable(ok, 30));
                var rep = QuestieData.T(QuestieData.T(q, QuestieData.Q_OBJECTIVES), 4);
                if (rep != null && rep.Get(1) is double) obj.Set("r", rep);
                r.Append(obj.Pairs().Any() ? obj : null);                               // 12 objectives
                r.Append(QuestieData.T(q, QuestieData.Q_PREGROUP));                     // 13 preQuestGroup (all)
                r.Append(QuestieData.T(q, QuestieData.Q_PRESINGLE));                    // 14 preQuestSingle (any)
                r.Append((double)QuestieData.N(q, QuestieData.Q_ZONE));                   // 15 zoneOrSort
                r.Append(QuestieData.T(q, QuestieData.Q_EXCLUSIVE));                    // 16 exclusiveTo
                r.Append((double)QuestieData.N(q, QuestieData.Q_NEXT));                   // 17 nextQuestInChain
                r.Append((double)QuestieData.N(q, QuestieData.Q_BREADCRUMBFOR));          // 18 breadcrumbFor
                r.Append((double)QuestieData.N(q, QuestieData.Q_SPECIAL));                // 19 specialFlags
                r.Append((double)QuestieData.N(q, QuestieData.Q_MAXLEVEL));               // 20 requiredMaxLevel
                var trig = QuestieData.T(q, QuestieData.Q_TRIGGER);
                LTable trigOut = null;
                if (trig != null)
                {
                    trigOut = new LTable();
                    trigOut.Append(QuestieData.S(trig, 1) ?? "");
                    var tz = Trim(QuestieData.T(trig, 2), 3, 2, 0);
                    if (tz != null) trigOut.Append(tz);
                }
                r.Append(trigOut);                                                      // 21 triggerEnd {text, spawns}
                r.Append(QuestieData.T(q, QuestieData.Q_SKILL));                        // 22 requiredSkill
                r.Append(QuestieData.T(q, QuestieData.Q_MINREP));                       // 23 requiredMinRep
                int srcItem = QuestieData.N(q, QuestieData.Q_SOURCEITEM);
                r.Append((double)srcItem);                                              // 24 sourceItemId
                r.Append((double)QuestieData.N(q, QuestieData.Q_PARENT));                 // 25 parentQuest

                // normalise trailing zeros to nil for compactness
                for (int k = 1; k <= r.Count; k++)
                {
                    var v = r.Arr[k];
                    if (v is double && (double)v == 0 && k >= 13) r.Arr[k] = null;
                }
                sb.Append("Q[").Append(id).Append("]=").Append(LuaWriter.Table(r)).Append('\n');

                foreach (var n in sn) { needNpc.Add(n); giverNpc.Add(n); }
                foreach (var n in en) { needNpc.Add(n); giverNpc.Add(n); }
                foreach (var n in oc) needNpc.Add(n);
                foreach (var n in ok) needNpc.Add(n);
                foreach (var o in so) needObj.Add(o);
                foreach (var o in eo) needObj.Add(o);
                foreach (var o in oo) needObj.Add(o);
                foreach (var i in oi) needItem.Add(i);
                foreach (var i in si) needItem.Add(i);
                if (srcItem > 0) needItem.Add(srcItem);
                var rsrc = QuestieData.T(q, QuestieData.Q_REQSOURCE);
                foreach (var i in QuestieData.Ids(rsrc)) needItem.Add(i);
            }
            File.WriteAllText(Path.Combine(outDir, "Quests.lua"), sb.ToString(), new UTF8Encoding(false));
            stats["quests"] = d.Quests.Count;

            // ---------------- Items ----------------
            sb = new StringBuilder(Hdr("Item records (quest-relevant subset)", provenance));
            sb.Append("local I = ns.QDB.items\n");
            int itemCount = 0;
            foreach (var id in needItem.OrderBy(k => k))
            {
                LTable it;
                if (!d.Items.TryGetValue(id, out it)) { d.Warnings.Add("item " + id + " referenced by a quest is missing from upstream item data"); continue; }
                var r = new LTable();
                r.Append(QuestieData.S(it, QuestieData.I_NAME) ?? ("Item " + id));
                var drops = QuestieData.Ids(QuestieData.T(it, QuestieData.I_NPCDROPS));
                var odrops = QuestieData.Ids(QuestieData.T(it, QuestieData.I_OBJDROPS));
                r.Append(IdTable(drops, MaxDropSources));
                r.Append(IdTable(odrops, MaxDropSources));
                r.Append((double)QuestieData.N(it, QuestieData.I_STARTQUEST));
                var vend = QuestieData.Ids(QuestieData.T(it, QuestieData.I_VENDORS));
                r.Append(IdTable(vend, 6));
                foreach (var n in drops.Take(MaxDropSources)) needNpc.Add(n);
                foreach (var n in vend.Take(6)) needNpc.Add(n);
                foreach (var o in odrops.Take(MaxDropSources)) needObj.Add(o);
                sb.Append("I[").Append(id).Append("]=").Append(LuaWriter.Table(r)).Append('\n');
                itemCount++;
            }
            File.WriteAllText(Path.Combine(outDir, "Items.lua"), sb.ToString(), new UTF8Encoding(false));
            stats["items"] = itemCount;

            // Service NPCs: trainers, flight masters, innkeepers.
            foreach (var kv in d.Npcs)
            {
                int fl = QuestieData.N(kv.Value, QuestieData.N_FLAGS);
                if ((fl & (FLAG_TRAINER | FLAG_FLIGHTMASTER | FLAG_INNKEEPER)) != 0) needNpc.Add(kv.Key);
            }

            // ---------------- NPCs ----------------
            sb = new StringBuilder(Hdr("NPC records (quest/service subset)", provenance));
            sb.Append("local N = ns.QDB.npcs\n");
            int npcCount = 0;
            foreach (var id in needNpc.OrderBy(k => k))
            {
                LTable n;
                if (!d.Npcs.TryGetValue(id, out n)) { d.Warnings.Add("npc " + id + " referenced but missing from upstream npc data"); continue; }
                var r = new LTable();
                r.Append(QuestieData.S(n, QuestieData.N_NAME) ?? ("NPC " + id));       // 1 name
                r.Append((double)QuestieData.N(n, QuestieData.N_MINLEVEL));            // 2 minLevel
                r.Append((double)QuestieData.N(n, QuestieData.N_MAXLEVEL));            // 3 maxLevel
                r.Append((double)QuestieData.N(n, QuestieData.N_RANK));                // 4 rank
                int zone = QuestieData.N(n, QuestieData.N_ZONE);
                r.Append((double)zone);                                                // 5 zoneID
                bool giver = giverNpc.Contains(id);
                r.Append(Trim(QuestieData.T(n, QuestieData.N_SPAWNS), giver ? MaxSpawnsGiver : MaxSpawnsMob, MaxZonesPerNpc, zone)); // 6 spawns
                r.Append(QuestieData.S(n, QuestieData.N_FRIENDLY));                    // 7 friendlyToFaction
                r.Append(QuestieData.S(n, QuestieData.N_SUBNAME));                     // 8 subName
                r.Append((double)QuestieData.N(n, QuestieData.N_FLAGS));               // 9 npcFlags
                bool hasWp = QuestieData.T(n, QuestieData.N_WAYPOINTS) != null;
                r.Append(hasWp ? (object)true : null);                                 // 10 patrols (has waypoints)
                sb.Append("N[").Append(id).Append("]=").Append(LuaWriter.Table(r)).Append('\n');
                npcCount++;
            }
            File.WriteAllText(Path.Combine(outDir, "Npcs.lua"), sb.ToString(), new UTF8Encoding(false));
            stats["npcs"] = npcCount;

            // ---------------- Objects ----------------
            sb = new StringBuilder(Hdr("Game object records (quest subset)", provenance));
            sb.Append("local O = ns.QDB.objects\n");
            int objCount = 0;
            foreach (var id in needObj.OrderBy(k => k))
            {
                LTable o;
                if (!d.Objects.TryGetValue(id, out o)) { d.Warnings.Add("object " + id + " referenced but missing from upstream object data"); continue; }
                var r = new LTable();
                r.Append(QuestieData.S(o, QuestieData.O_NAME) ?? ("Object " + id));
                int zone = QuestieData.N(o, QuestieData.O_ZONE);
                r.Append((double)zone);
                r.Append(Trim(QuestieData.T(o, QuestieData.O_SPAWNS), MaxSpawnsMob, MaxZonesPerNpc, zone));
                sb.Append("O[").Append(id).Append("]=").Append(LuaWriter.Table(r)).Append('\n');
                objCount++;
            }
            File.WriteAllText(Path.Combine(outDir, "Objects.lua"), sb.ToString(), new UTF8Encoding(false));
            stats["objects"] = objCount;

            // ---------------- Zones ----------------
            sb = new StringBuilder(Hdr("Zone tables (areaId -> uiMapId, names, subzone parents)", provenance));
            sb.Append("local Z = ns.QDB.zones\n");
            sb.Append("Z.uiMap = {\n");
            foreach (var kv in d.AreaToUiMap.OrderBy(k => k.Key)) sb.Append("[").Append(kv.Key).Append("]=").Append(kv.Value).Append(",\n");
            sb.Append("}\nZ.names = {\n");
            foreach (var kv in d.AreaNames.OrderBy(k => k.Key)) sb.Append("[").Append(kv.Key).Append("]=").Append(LuaWriter.Str(kv.Value)).Append(",\n");
            sb.Append("}\nZ.parent = {\n");
            foreach (var kv in d.SubZoneParent.OrderBy(k => k.Key)) sb.Append("[").Append(kv.Key).Append("]=").Append(kv.Value).Append(",\n");
            sb.Append("}\n");
            File.WriteAllText(Path.Combine(outDir, "Zones.lua"), sb.ToString(), new UTF8Encoding(false));
            stats["zones"] = d.AreaToUiMap.Count;
            stats["subzones"] = d.SubZoneParent.Count;
            stats["warnings"] = d.Warnings.Count;
            return stats;
        }
    }
}
