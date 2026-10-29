// TBCGuide build tooling - Lua lint + manifest check.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// 1. Every shipped .lua file must parse as Lua 5.1 (hard error otherwise).
// 2. Every file referenced by the .toc (directly or through <Script file=> / <Include file=> in XML)
//    must exist, and every shipped .lua file must be referenced (no orphans).
// 3. Global writes must be on the allowlist (catches a forgotten `local`).
// 4. Global reads must be Lua 5.1 builtins, our own globals, or on tools/wow_api_allowlist.txt.
//    The allowlist is the curated list of client APIs the add-on is allowed to depend on; an
//    unknown global is an error so API use is always a deliberate, reviewed decision.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace TBCGuideTools
{
    public sealed class LintResult
    {
        public int Errors, Warnings, Files;
        public List<string> Messages = new List<string>();
        public string Summary { get { return string.Format("lint: {0} files, {1} error(s), {2} warning(s)", Files, Errors, Warnings); } }
        public void Err(string m) { Errors++; Messages.Add("ERROR " + m); }
        public void Warn(string m) { Warnings++; Messages.Add("warn  " + m); }
    }

    public static class Linter
    {
        static readonly HashSet<string> LuaBuiltins = new HashSet<string>(new[] {
            "_G","assert","error","getmetatable","setmetatable","ipairs","pairs","next","pcall","xpcall","print",
            "rawequal","rawget","rawset","select","tonumber","tostring","type","unpack","loadstring","collectgarbage",
            "string","table","math","coroutine","os","debug","bit","date","time","strsplit","strjoin","strtrim",
            "tinsert","tremove","wipe","format","floor","ceil","abs","min","max","sort","gsub","strfind","strlower",
            "strupper","strsub","strlen","strmatch","gmatch","mod","random","sqrt","hooksecurefunc","securecall",
            "issecurevariable","geterrorhandler","seterrorhandler","setfenv","getfenv" });

        static readonly HashSet<string> OwnGlobalsWrite = new HashSet<string>(new[] {
            "TBCGuide","TBCGuideDB","TBCGuideCharDB","SLASH_TBCGUIDE1","SLASH_TBCGUIDE2","SLASH_TBCGEAR1" });

        public static LintResult Run(string addOnDir, string allowlistPath)
        {
            var r = new LintResult();
            var allow = new HashSet<string>();
            if (File.Exists(allowlistPath))
                foreach (var line in File.ReadAllLines(allowlistPath))
                {
                    string l = line.Trim();
                    int c = l.IndexOf('#');
                    if (c >= 0) l = l.Substring(0, c).Trim();
                    if (l.Length > 0) allow.Add(l);
                }

            // Manifest
            var tocPath = Directory.GetFiles(addOnDir, "*.toc").FirstOrDefault();
            if (tocPath == null) { r.Err("no .toc in " + addOnDir); return r; }
            var referenced = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var order = new List<string>();
            CollectToc(addOnDir, tocPath, referenced, order, r);
            var toc = File.ReadAllLines(tocPath);
            var iface = toc.FirstOrDefault(l => l.StartsWith("## Interface:"));
            if (iface == null) r.Err("toc: missing ## Interface");
            if (!toc.Any(l => l.StartsWith("## SavedVariables:"))) r.Err("toc: missing ## SavedVariables");

            var all = Directory.GetFiles(addOnDir, "*.lua", SearchOption.AllDirectories);
            foreach (var f in all)
            {
                string rel = Rel(addOnDir, f);
                if (!referenced.Contains(rel)) r.Warn(rel + ": not referenced by the .toc or any included XML (not loaded)");
            }

            foreach (var rel in order)
            {
                string full = Path.Combine(addOnDir, rel);
                if (!rel.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)) continue;
                r.Files++;
                string src = File.ReadAllText(full, Encoding.UTF8);
                if (src.Length > 0 && src[0] == '﻿') r.Warn(rel + ": UTF-8 BOM (harmless but avoid)");
                LuaChecker chk;
                try { chk = LuaChecker.Check(src); }
                catch (LuaSyntaxError e) { r.Err(rel + ":" + e.Line + ": " + e.Message); continue; }
                bool generatedData = rel.Replace('/', '\\').StartsWith("Database\\QuestieTBC", StringComparison.OrdinalIgnoreCase);
                if (generatedData) continue; // data files: syntax only
                var reported = new HashSet<string>();
                foreach (var g in chk.Globals)
                {
                    if (g.Write)
                    {
                        if (OwnGlobalsWrite.Contains(g.Name)) continue;
                        if (allow.Contains("write:" + g.Name)) continue;
                        r.Err(rel + ":" + g.Line + ": assignment to global '" + g.Name + "' (missing local?)");
                        continue;
                    }
                    if (LuaBuiltins.Contains(g.Name) || OwnGlobalsWrite.Contains(g.Name)) continue;
                    string qualified = g.Field != null ? g.Name + "." + g.Field : null;
                    if (allow.Contains(g.Name)) continue;
                    if (qualified != null && allow.Contains(qualified)) continue;
                    string key = qualified ?? g.Name;
                    if (reported.Add(key)) r.Err(rel + ":" + g.Line + ": unknown global '" + key + "' (not on tools/wow_api_allowlist.txt)");
                }
            }
            return r;
        }

        static string Rel(string root, string full)
        {
            return full.Substring(root.Length).TrimStart('\\', '/').Replace('/', '\\');
        }

        static readonly Regex XmlFile = new Regex("<(?:Script|Include)\\s+file=\"([^\"]+)\"", RegexOptions.IgnoreCase);

        static void CollectToc(string root, string toc, HashSet<string> referenced, List<string> order, LintResult r)
        {
            foreach (var raw in File.ReadAllLines(toc))
            {
                string l = raw.Trim();
                if (l.Length == 0 || l.StartsWith("#")) continue;
                AddRef(root, l.Replace('/', '\\'), referenced, order, r, "toc");
            }
        }

        static void AddRef(string root, string rel, HashSet<string> referenced, List<string> order, LintResult r, string from)
        {
            string full = Path.Combine(root, rel);
            if (!File.Exists(full)) { r.Err(from + ": referenced file missing: " + rel); return; }
            if (!referenced.Add(rel)) { r.Warn(from + ": file listed twice: " + rel); return; }
            order.Add(rel);
            if (rel.EndsWith(".xml", StringComparison.OrdinalIgnoreCase))
            {
                string dir = Path.GetDirectoryName(rel);
                foreach (Match m in XmlFile.Matches(File.ReadAllText(full)))
                    AddRef(root, Path.Combine(dir, m.Groups[1].Value.Replace('/', '\\')), referenced, order, r, rel);
            }
        }
    }
}
