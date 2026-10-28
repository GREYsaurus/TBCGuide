// TBCGuide build tooling - Lua literal reader/writer.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Parses the subset of Lua used by data files: table constructors, strings
// (short and long-bracket), numbers, booleans, nil and `return` prefixes.
// It deliberately does NOT evaluate code; files containing logic are rejected.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TBCGuideTools
{
    public sealed class LTable
    {
        // 1-based positional part; index 0 unused. Holes are stored as null.
        public readonly List<object> Arr = new List<object>();
        public readonly Dictionary<object, object> Hash = new Dictionary<object, object>();

        public LTable() { Arr.Add(null); }

        public int Count { get { return Arr.Count - 1; } }

        public object Get(object key)
        {
            if (key is double)
            {
                double d = (double)key;
                int i = (int)d;
                if (i == d && i >= 1 && i < Arr.Count) return Arr[i];
            }
            object v;
            return Hash.TryGetValue(key, out v) ? v : null;
        }

        public object Get(int i)
        {
            if (i >= 1 && i < Arr.Count) return Arr[i];
            object v;
            return Hash.TryGetValue((double)i, out v) ? v : null;
        }

        public object Get(string key)
        {
            object v;
            return Hash.TryGetValue(key, out v) ? v : null;
        }

        public void Append(object v) { Arr.Add(v); }

        public void Set(object key, object v)
        {
            if (key is double)
            {
                double d = (double)key;
                int i = (int)d;
                if (i == d && i >= 1 && i < Arr.Count) { Arr[i] = v; return; }
                if (i == d && i == Arr.Count && v != null) { Arr.Add(v); return; }
            }
            if (v == null) Hash.Remove(key); else Hash[key] = v;
        }

        // Every non-nil numeric-indexed or keyed pair.
        public IEnumerable<KeyValuePair<object, object>> Pairs()
        {
            for (int i = 1; i < Arr.Count; i++)
                if (Arr[i] != null) yield return new KeyValuePair<object, object>((double)i, Arr[i]);
            foreach (var kv in Hash) yield return kv;
        }

        public List<int> IntList()
        {
            var r = new List<int>();
            foreach (var kv in Pairs())
                if (kv.Value is double) r.Add((int)(double)kv.Value);
            return r;
        }
    }

    public class LuaParseException : Exception
    {
        public LuaParseException(string msg) : base(msg) { }
    }

    public sealed class LuaLiteralReader
    {
        private readonly string s;
        private int p;
        private readonly string source;

        public LuaLiteralReader(string text, string sourceName)
        {
            s = text; p = 0; source = sourceName ?? "?";
        }

        public static object ParseValue(string text, string sourceName)
        {
            var r = new LuaLiteralReader(text, sourceName);
            r.SkipWs();
            if (r.MatchWord("return")) r.SkipWs();
            object v = r.ReadValue();
            r.SkipWs();
            if (r.p < r.s.Length) r.Fail("trailing content after value");
            return v;
        }

        // Extracts the long-string payload assigned as `<marker> = [[ ... ]]`.
        public static string ExtractLongString(string text, string marker)
        {
            int i = text.IndexOf(marker, StringComparison.Ordinal);
            if (i < 0) throw new LuaParseException("marker not found: " + marker);
            var r = new LuaLiteralReader(text, marker);
            r.p = text.IndexOf('[', i + marker.Length);
            return r.ReadLongBracket();
        }

        private int Line()
        {
            int n = 1;
            for (int i = 0; i < p && i < s.Length; i++) if (s[i] == '\n') n++;
            return n;
        }

        private void Fail(string msg)
        {
            throw new LuaParseException(source + ":" + Line() + ": " + msg);
        }

        public void SkipWs()
        {
            while (p < s.Length)
            {
                char c = s[p];
                if (c == ' ' || c == '\t' || c == '\r' || c == '\n') { p++; continue; }
                if (c == '-' && p + 1 < s.Length && s[p + 1] == '-')
                {
                    p += 2;
                    if (p < s.Length && s[p] == '[')
                    {
                        int save = p;
                        int lvl = LongBracketLevel();
                        if (lvl >= 0) { p = save; ReadLongBracket(); continue; }
                        p = save;
                    }
                    while (p < s.Length && s[p] != '\n') p++;
                    continue;
                }
                break;
            }
        }

        private bool MatchWord(string w)
        {
            if (string.CompareOrdinal(s, p, w, 0, w.Length) != 0) return false;
            int e = p + w.Length;
            if (e < s.Length && (char.IsLetterOrDigit(s[e]) || s[e] == '_')) return false;
            p = e;
            return true;
        }

        // At '[': returns level of [==[ or -1 if not a long bracket. Does not advance.
        private int LongBracketLevel()
        {
            if (p >= s.Length || s[p] != '[') return -1;
            int q = p + 1, lvl = 0;
            while (q < s.Length && s[q] == '=') { lvl++; q++; }
            return (q < s.Length && s[q] == '[') ? lvl : -1;
        }

        private string ReadLongBracket()
        {
            int lvl = LongBracketLevel();
            if (lvl < 0) Fail("expected long bracket");
            p += lvl + 2;
            if (p < s.Length && s[p] == '\r') p++;
            if (p < s.Length && s[p] == '\n') p++;
            string close = "]" + new string('=', lvl) + "]";
            int e = s.IndexOf(close, p, StringComparison.Ordinal);
            if (e < 0) Fail("unterminated long string");
            string v = s.Substring(p, e - p);
            p = e + close.Length;
            return v;
        }

        public object ReadValue()
        {
            SkipWs();
            if (p >= s.Length) Fail("unexpected end of input");
            char c = s[p];
            if (c == '{') return ReadTable();
            if (c == '"' || c == '\'') return ReadQuoted();
            if (c == '[' && LongBracketLevel() >= 0) return ReadLongBracket();
            if (c == '-' || c == '.' || char.IsDigit(c)) return ReadNumber();
            if (MatchWord("nil")) return null;
            if (MatchWord("true")) return true;
            if (MatchWord("false")) return false;
            Fail("unexpected character '" + c + "'");
            return null;
        }

        private double ReadNumber()
        {
            int st = p;
            bool neg = false;
            if (s[p] == '-') { neg = true; p++; SkipWs(); }
            int ns = p;
            if (p + 1 < s.Length && s[p] == '0' && (s[p + 1] == 'x' || s[p + 1] == 'X'))
            {
                p += 2; int hs = p;
                while (p < s.Length && Uri.IsHexDigit(s[p])) p++;
                double hv = (double)Convert.ToInt64(s.Substring(hs, p - hs), 16);
                return neg ? -hv : hv;
            }
            while (p < s.Length && (char.IsDigit(s[p]) || s[p] == '.' || s[p] == 'e' || s[p] == 'E' ||
                   ((s[p] == '+' || s[p] == '-') && (s[p - 1] == 'e' || s[p - 1] == 'E')))) p++;
            if (p == ns) { p = st; Fail("bad number"); }
            double v = double.Parse(s.Substring(ns, p - ns), NumberStyles.Float, CultureInfo.InvariantCulture);
            return neg ? -v : v;
        }

        private string ReadQuoted()
        {
            char q = s[p++];
            var sb = new StringBuilder();
            while (true)
            {
                if (p >= s.Length) Fail("unterminated string");
                char c = s[p++];
                if (c == q) break;
                if (c == '\n') Fail("newline in string");
                if (c != '\\') { sb.Append(c); continue; }
                char e = s[p++];
                switch (e)
                {
                    case 'n': sb.Append('\n'); break;
                    case 't': sb.Append('\t'); break;
                    case 'r': sb.Append('\r'); break;
                    case 'a': sb.Append('\a'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'v': sb.Append('\v'); break;
                    case '\\': sb.Append('\\'); break;
                    case '"': sb.Append('"'); break;
                    case '\'': sb.Append('\''); break;
                    case '\n': sb.Append('\n'); break;
                    default:
                        if (char.IsDigit(e))
                        {
                            int v = e - '0', n = 1;
                            while (n < 3 && p < s.Length && char.IsDigit(s[p])) { v = v * 10 + (s[p++] - '0'); n++; }
                            sb.Append((char)v);
                        }
                        else Fail("bad escape \\" + e);
                        break;
                }
            }
            return sb.ToString();
        }

        private LTable ReadTable()
        {
            p++; // {
            var t = new LTable();
            while (true)
            {
                SkipWs();
                if (p >= s.Length) Fail("unterminated table");
                if (s[p] == '}') { p++; return t; }
                if (s[p] == '[' && LongBracketLevel() < 0)
                {
                    p++;
                    object k = ReadValue();
                    SkipWs();
                    if (p >= s.Length || s[p] != ']') Fail("expected ]");
                    p++; SkipWs();
                    if (p >= s.Length || s[p] != '=') Fail("expected =");
                    p++;
                    object v = ReadValue();
                    if (k == null) Fail("nil table key");
                    t.Set(k, v);
                }
                else if (char.IsLetter(s[p]) || s[p] == '_')
                {
                    int st = p;
                    while (p < s.Length && (char.IsLetterOrDigit(s[p]) || s[p] == '_')) p++;
                    string name = s.Substring(st, p - st);
                    int afterName = p;
                    SkipWs();
                    if (p < s.Length && s[p] == '=' && !(p + 1 < s.Length && s[p + 1] == '='))
                    {
                        p++;
                        t.Set(name, ReadValue());
                    }
                    else
                    {
                        p = st;
                        t.Append(ReadValue());
                    }
                }
                else
                {
                    t.Append(ReadValue());
                }
                SkipWs();
                if (p < s.Length && (s[p] == ',' || s[p] == ';')) { p++; continue; }
                SkipWs();
                if (p < s.Length && s[p] == '}') { p++; return t; }
                Fail("expected , or }");
            }
        }
    }

    public static class LuaWriter
    {
        public static string Str(string v)
        {
            var sb = new StringBuilder("\"");
            foreach (char c in v)
            {
                switch (c)
                {
                    case '\\': sb.Append("\\\\"); break;
                    case '"': sb.Append("\\\""); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 32) sb.Append("\\" + ((int)c).ToString(CultureInfo.InvariantCulture));
                        else sb.Append(c);
                        break;
                }
            }
            return sb.Append('"').ToString();
        }

        public static string Num(double d)
        {
            if (d == Math.Floor(d) && Math.Abs(d) < 1e15) return ((long)d).ToString(CultureInfo.InvariantCulture);
            return d.ToString("0.##", CultureInfo.InvariantCulture);
        }

        public static string Value(object v)
        {
            if (v == null) return "nil";
            if (v is bool) return (bool)v ? "true" : "false";
            if (v is double) return Num((double)v);
            if (v is int) return ((int)v).ToString(CultureInfo.InvariantCulture);
            if (v is string) return Str((string)v);
            if (v is LTable) return Table((LTable)v);
            var list = v as System.Collections.IList;
            if (list != null)
            {
                var sb = new StringBuilder("{");
                for (int i = 0; i < list.Count; i++) { if (i > 0) sb.Append(','); sb.Append(Value(list[i])); }
                return sb.Append('}').ToString();
            }
            throw new ArgumentException("cannot serialise " + v.GetType());
        }

        public static string Table(LTable t)
        {
            var sb = new StringBuilder("{");
            bool first = true;
            int last = t.Count;
            while (last > 0 && t.Arr[last] == null) last--;
            for (int i = 1; i <= last; i++)
            {
                if (!first) sb.Append(',');
                sb.Append(Value(t.Arr[i])); first = false;
            }
            var keys = new List<object>(t.Hash.Keys);
            keys.Sort(CompareKeys);
            foreach (var k in keys)
            {
                if (!first) sb.Append(',');
                first = false;
                string ks = k as string;
                if (ks != null && IsIdent(ks)) sb.Append(ks).Append('=');
                else sb.Append('[').Append(Value(k)).Append("]=");
                sb.Append(Value(t.Hash[k]));
            }
            return sb.Append('}').ToString();
        }

        private static int CompareKeys(object a, object b)
        {
            if (a is double && b is double) return ((double)a).CompareTo((double)b);
            if (a is double) return -1;
            if (b is double) return 1;
            return string.CompareOrdinal(a.ToString(), b.ToString());
        }

        private static readonly HashSet<string> Reserved = new HashSet<string>(new[] {
            "and","break","do","else","elseif","end","false","for","function","if","in",
            "local","nil","not","or","repeat","return","then","true","until","while" });

        public static bool IsIdent(string s)
        {
            if (string.IsNullOrEmpty(s) || Reserved.Contains(s)) return false;
            if (!(char.IsLetter(s[0]) || s[0] == '_') || s[0] > 127) return false;
            foreach (char c in s) if (!(char.IsLetterOrDigit(c) || c == '_') || c > 127) return false;
            return true;
        }
    }
}
