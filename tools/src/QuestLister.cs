// TBCGuide build tooling - authoring aid: list the quests of a zone for a faction.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// `tools/build.ps1 zonequests "<Zone>" <Alliance|Horde>` prints every quest whose start NPC/object
// spawns in the zone (or whose quest zone is the zone), with level, giver location, finisher,
// prerequisites and race/class limits. Guide authors use it to write routes from real data
// instead of memory.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;

namespace TBCGuideTools
{
    public static class QuestLister
    {
        public static string List(string addOnDir, string zoneName, string faction)
        {
            var db = BundledDb.Load(addOnDir);
            int zone;
            if (!db.ZoneByName.TryGetValue(zoneName, out zone)) return "unknown zone " + zoneName;
            int fmask = faction == "Alliance" ? 1101 : 690;
            string f = faction == "Alliance" ? "A" : "H";
            var rows = new List<Tuple<int, int, string>>();
            foreach (var kv in db.Quests)
            {
                var r = kv.Value;
                int races = BundledDb.Num(r, BundledDb.Q_RACES);
                if (races != 0 && (races & fmask) == 0) continue;
                // Skip holiday/event quests (level -1) and repeatables: never part of a leveling route.
                if (BundledDb.Num(r, BundledDb.Q_LEVEL) < 0 || (BundledDb.Num(r, BundledDb.Q_SPECIAL) & 1) != 0) continue;
                string qn = BundledDb.Str(r, 1) ?? "";
                if (qn.StartsWith("BETA") || qn.Contains("[Not Used]") || qn.Contains("UNUSED") || qn.Contains("<NYI>") || qn.StartsWith("[OLD]")) continue;
                int qz = BundledDb.Num(r, BundledDb.Q_ZONE);
                bool inZone = qz > 0 && db.Parent(qz) == zone;
                string giver = null;
                foreach (var n in BundledDb.Ids(r, BundledDb.Q_SNPC))
                {
                    LTable npc;
                    if (!db.Npcs.TryGetValue(n, out npc)) continue;
                    string fr = BundledDb.Str(npc, BundledDb.N_FRIENDLY) ?? "";
                    foreach (var sp in db.NpcSpawns(n))
                        if ((int)sp[0] == zone || db.Parent((int)sp[0]) == zone)
                        {
                            inZone = true;
                            giver = string.Format(CultureInfo.InvariantCulture, "{0} ({1:0.0},{2:0.0}){3}", BundledDb.Str(npc, 1), sp[1], sp[2], fr.Contains(f) || fr == "" ? "" : " [hostile?]");
                            break;
                        }
                    if (giver != null) break;
                }
                foreach (var o in BundledDb.Ids(r, BundledDb.Q_SOBJ))
                    foreach (var sp in db.ObjSpawns(o))
                        if ((int)sp[0] == zone && giver == null) { inZone = true; giver = string.Format(CultureInfo.InvariantCulture, "obj {0} ({1:0.0},{2:0.0})", db.ObjName(o), sp[1], sp[2]); }
                if (!inZone) continue;
                if (giver == null)
                {
                    var items = BundledDb.Ids(r, BundledDb.Q_SITEM);
                    giver = items.Count > 0 ? "item " + items[0] : "?";
                }
                var ender = BundledDb.Ids(r, BundledDb.Q_ENPC).Select(n => db.NpcName(n)).FirstOrDefault() ??
                            BundledDb.Ids(r, BundledDb.Q_EOBJ).Select(o => "obj " + db.ObjName(o)).FirstOrDefault() ?? "?";
                var pre = BundledDb.Ids(r, BundledDb.Q_PREG).Concat(BundledDb.Ids(r, BundledDb.Q_PRES)).ToList();
                int classes = BundledDb.Num(r, BundledDb.Q_CLASSES);
                var sb = new StringBuilder();
                sb.AppendFormat("{0,6} L{1,2}/{2,2} {3}", kv.Key, BundledDb.Num(r, BundledDb.Q_REQ), BundledDb.Num(r, BundledDb.Q_LEVEL), BundledDb.Str(r, 1));
                sb.Append("  | from " + giver + " -> " + ender);
                if (pre.Count > 0) sb.Append("  | pre " + string.Join(",", pre.Select(x => x.ToString()).ToArray()));
                if (races != 0 && races != fmask) sb.Append("  | races " + races);
                if (classes != 0) sb.Append("  | classes " + classes);
                int special = BundledDb.Num(r, BundledDb.Q_SPECIAL);
                if ((special & 1) != 0) sb.Append("  | repeatable");
                var obj = BundledDb.Tab(r, BundledDb.Q_OBJ);
                if (obj == null && BundledDb.Tab(r, BundledDb.Q_TRIGGER) == null) sb.Append("  | talk/deliver");
                rows.Add(Tuple.Create(BundledDb.Num(r, BundledDb.Q_REQ), kv.Key, sb.ToString()));
            }
            var outp = new StringBuilder();
            outp.AppendLine(zoneName + " (" + zone + ") - " + faction + " - " + rows.Count + " quests");
            foreach (var row in rows.OrderBy(x => x.Item1).ThenBy(x => x.Item2)) outp.AppendLine(row.Item3);
            return outp.ToString();
        }
    }
}
