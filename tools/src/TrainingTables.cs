// TBCGuide build tooling - class trainer spells from the client DB2 tables.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Input (tools/upstream.json clientTables): SkillLine, SkillLineAbility, SpellLevels, SpellName,
// Spell (rank text) and Talent.
// Output: TBCGuide/Classes/TrainingData.lua - for every class, each spell rank a trainer can teach:
//   spell id, level it becomes available (SpellLevels.BaseLevel), rank, the previous rank's id,
//   the English name (documentation only; the add-on shows the client's localized name),
//   whether the spell family comes from a talent, and the race mask when only some races get it.
// Rules (docs/TRAINER.md):
//   - class spell skill lines only (SkillLine category 7 with the class-spec flag, plus Poisons);
//     pet, weapon and profession lines are not included;
//   - the class is SkillLineAbility.ClassMask, or the skill line's class (SkillRaceClassInfo) when
//     the row carries 0 (true for some real spells such as Evocation and Steady Shot);
//   - level 1 spells are known from character creation and are left out;
//   - helper spells the trainer never lists (passives, "Effect" spells, judgement effects and a
//     short list of named effect auras) are left out by name;
//   - rank 1 of a talent spell comes from the talent, so it is left out; its higher ranks are
//     trainer ranks that need the previous rank (talent = 1);
//   - ranks are chained by name and rank text, not by SupercedesSpell (not filled in for every
//     family); with several spells for one name and rank (Holy Shock's heal and damage parts)
//     the lowest id is the learned spell.
// Whether a spell comes from a class quest instead of the trainer is NOT in the client tables;
// TBCGuide/Classes/TrainingNotes.lua lists those by hand.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    public static class TrainingTables
    {
        static readonly Dictionary<int, string> ClassBit = new Dictionary<int, string> {
            {1,"WARRIOR"},{2,"PALADIN"},{4,"HUNTER"},{8,"ROGUE"},{16,"PRIEST"},{64,"SHAMAN"},{128,"MAGE"},{256,"WARLOCK"},{1024,"DRUID"} };

        public static readonly Regex Helper = new Regex(
            @"Passive|\(DND\)| Effect$|^Judgement of |^(Chilled|Pounce Bleed|Lightwell Renew|Moonkin Aura|Blood Corruption|Holy Vengeance|Clearcasting|Focused|Impact|Frostbite|Enraged Defense|Feline Grace|Spirit Weapons|Arcane Missile|Ignite|Intuition|Pyroclasm|Revenge Stun|Improved Mend Pet|Felfire)$");

        sealed class Entry { public int Id, Level, Rank, Prev, Race; public string Name, Skip; public bool Talent, Marked; }

        public static string Export(string db2Dir, string addOnDir, string build)
        {
            Func<string, string> P = t => Path.Combine(db2Dir, t + ".csv");
            foreach (var t in new[] { "SkillLine", "SkillLineAbility", "SpellLevels" })
                if (!File.Exists(P(t))) return "training: skipped (" + t + ".csv missing; run fetch)";

            var lines = new HashSet<int>(Csv.Read(P("SkillLine"))
                .Where(r => Csv.I(r, "CategoryID") == 7 && (Csv.I(r, "Flags") == 16 || Csv.I(r, "ID") == 40))
                .Select(r => Csv.I(r, "ID")));
            var name = new Dictionary<int, string>();
            foreach (var r in Csv.Read(P("SpellName"))) name[Csv.I(r, "ID")] = r["Name_lang"];
            var sub = new Dictionary<int, string>();
            foreach (var r in Csv.Read(P("Spell"))) sub[Csv.I(r, "ID")] = r["NameSubtext_lang"];
            var level = new Dictionary<int, int>();
            foreach (var r in Csv.Read(P("SpellLevels")))
                if (Csv.I(r, "DifficultyID") == 0) level[Csv.I(r, "SpellID")] = Csv.I(r, "BaseLevel");
            var talent = new HashSet<int>();
            var talentClass = new Dictionary<int, string>(); // spell -> class of the talent
            foreach (var r in Csv.Read(P("Talent")))
            {
                string tc; ClientTables.ClassFile.TryGetValue(Csv.I(r, "ClassID"), out tc);
                for (int k = 0; k < 9; k++) { int s = Csv.I(r, "SpellRank_" + k); if (s > 0) { talent.Add(s); if (tc != null) talentClass[s] = tc; } }
            }

            var perClass = ClassBit.Values.ToDictionary(c => c, c => new Dictionary<string, Entry>());
            var talentNames = new HashSet<string>(); // "CLASS#name" of talent spell families
            var rx = new Regex(@"^Rank (\d+)$");
            int skippedHelper = 0, skippedLevel = 0, skippedTalent = 0;
            // The class of each class skill line (SkillRaceClassInfo); Poisons is the rogue's.
            var lineClass = new Dictionary<int, int> { { 40, 8 } };
            if (File.Exists(P("SkillRaceClassInfo")))
                foreach (var r in Csv.Read(P("SkillRaceClassInfo")))
                {
                    int sk = Csv.I(r, "SkillID"), cm = Csv.I(r, "ClassMask");
                    if (lines.Contains(sk) && ClassBit.ContainsKey(cm)) lineClass[sk] = cm;
                }
            foreach (var r in Csv.Read(P("SkillLineAbility")))
            {
                if (!lines.Contains(Csv.I(r, "SkillLine"))) continue;
                int mask = Csv.I(r, "ClassMask"), sp = Csv.I(r, "Spell");
                // Most rows name the class; some real trainer spells (Evocation, Steady Shot, Ice
                // Lance ...) carry 0 and get the skill line's class instead.
                bool marked = mask != 0;
                if (!marked && !lineClass.TryGetValue(Csv.I(r, "SkillLine"), out mask)) continue;
                string n; if (!name.TryGetValue(sp, out n) || string.IsNullOrEmpty(n)) continue;
                int lv; level.TryGetValue(sp, out lv);
                string st; sub.TryGetValue(sp, out st);
                var m = rx.Match(st ?? "");
                int rank = m.Success ? int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) : 0;
                // Kept for chaining ranks; Skip says why it is not listed itself.
                string skip = null;
                if (talent.Contains(sp))
                {
                    string tc; if (talentClass.TryGetValue(sp, out tc)) talentNames.Add(tc + "#" + n);
                    skip = "talent";
                }
                else if (lv <= 1) skip = "level";
                else if (Helper.IsMatch(n)) skip = "helper";
                foreach (var cb in ClassBit)
                {
                    if ((mask & cb.Key) == 0) continue;
                    string key = n + "#" + rank + "#" + Csv.I(r, "RaceMask_0");
                    Entry e;
                    // One spell per name and rank: the talent's own spell, then a row that names
                    // the class, then the lowest id (proc and effect copies share names).
                    if (perClass[cb.Value].TryGetValue(key, out e))
                    {
                        if (e.Skip == "talent") continue;
                        if (skip != "talent" && (e.Marked && !marked)) continue;
                        if (skip != "talent" && e.Marked == marked && e.Id < sp) continue;
                    }
                    perClass[cb.Value][key] = new Entry { Id = sp, Level = lv, Rank = rank, Name = n, Race = Csv.I(r, "RaceMask_0"), Skip = skip, Marked = marked };
                }
            }

            var sb = new StringBuilder();
            sb.Append("-- TBCGuide - class trainer spells (spell id, level, rank, previous rank, English name, talent family, race mask)\n");
            sb.Append("-- GENERATED by tools/build.ps1 import-client from client SkillLineAbility/SpellLevels/SpellName/Talent (build " + build + "). DO NOT EDIT.\n");
            sb.Append("-- Rules: tools/src/TrainingTables.cs and docs/TRAINER.md. Names are for reading this file; the add-on shows GetSpellInfo names.\n");
            sb.Append("local _, ns = ...\n");
            sb.Append("ns.TrainingData = {\n  build = " + LuaWriter.Str(build) + ",\n  classes = {\n");
            var summary = new List<string>();
            int total = 0;
            foreach (var cls in perClass.OrderBy(c => c.Key))
            {
                var list = cls.Value.Values.ToList();
                foreach (var e in list) e.Talent = talentNames.Contains(cls.Key + "#" + e.Name);
                // Previous rank: same name and race mask, rank - 1.
                var byKey = list.ToDictionary(e => e.Name + "#" + e.Rank + "#" + e.Race);
                foreach (var e in list)
                {
                    Entry p;
                    if (e.Rank > 1 && byKey.TryGetValue(e.Name + "#" + (e.Rank - 1) + "#" + e.Race, out p)) e.Prev = p.Id;
                    else if (e.Rank > 1 && e.Race != 0 && byKey.TryGetValue(e.Name + "#" + (e.Rank - 1) + "#0", out p)) e.Prev = p.Id;
                }
                // Talent families: only ranks 2+ are trained (rank 1 is the talent; unranked
                // spells of the family are its helper parts).
                foreach (var e in list) if (e.Skip == null && e.Talent && e.Rank < 2) e.Skip = "talent";
                foreach (var e in list)
                    if (e.Skip == "talent") skippedTalent++; else if (e.Skip == "level") skippedLevel++; else if (e.Skip == "helper") skippedHelper++;
                list = list.Where(e => e.Skip == null).ToList();
                list = list.OrderBy(e => e.Level).ThenBy(e => e.Name, StringComparer.Ordinal).ThenBy(e => e.Rank).ToList();
                sb.Append("    " + cls.Key + " = {\n");
                foreach (var e in list)
                    sb.Append("      {" + e.Id + "," + e.Level + "," + e.Rank + "," + e.Prev + "," + LuaWriter.Str(e.Name) + "," + (e.Talent ? 1 : 0) + "," + e.Race + "},\n");
                sb.Append("    },\n");
                total += list.Count;
                summary.Add("training " + cls.Key + ": " + list.Count + " ranks (" + list.Count(e => e.Talent) + " talent ranks)");
            }
            sb.Append("  },\n}\n");
            string outDir = Path.Combine(addOnDir, "Classes");
            Directory.CreateDirectory(outDir);
            File.WriteAllText(Path.Combine(outDir, "TrainingData.lua"), sb.ToString(), new UTF8Encoding(false));
            summary.Add("training total: " + total + " ranks; left out: " + skippedLevel + " level-1, " + skippedHelper + " helper, " + skippedTalent + " talent rank-1 spells");
            return string.Join(Environment.NewLine, summary.ToArray());
        }
    }
}
