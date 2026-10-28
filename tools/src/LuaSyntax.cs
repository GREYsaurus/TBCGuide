// TBCGuide build tooling - Lua 5.1 syntax checker and global-usage linter.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// A recursive-descent parser for the Lua 5.1 grammar (the dialect embedded in
// the WoW client). It does not execute anything. Besides syntax errors it
// records every global variable read and write with scope tracking, so the
// build can flag typos and API names that are not on the target-client
// allowlist.

using System;
using System.Collections.Generic;
using System.Text;

namespace TBCGuideTools
{
    public enum TK { Name, Number, String, Op, Keyword, EOF }

    public struct Token
    {
        public TK Kind;
        public string Text;
        public int Line;
        public override string ToString() { return Kind + ":" + Text; }
    }

    public sealed class LuaSyntaxError : Exception
    {
        public int Line;
        public LuaSyntaxError(string msg, int line) : base(msg) { Line = line; }
    }

    public sealed class GlobalUse
    {
        public string Name;
        public int Line;
        public bool Write;
        public string Field; // first field accessed, e.g. C_Map in C_Map.GetBestMapForUnit
    }

    public sealed class LuaLexer
    {
        static readonly HashSet<string> Keywords = new HashSet<string>(new[] {
            "and","break","do","else","elseif","end","false","for","function","if","in",
            "local","nil","not","or","repeat","return","then","true","until","while" });

        static readonly string[] Ops3 = { "..." };
        static readonly string[] Ops2 = { "==", "~=", "<=", ">=", "..", "::" };
        const string Ops1 = "+-*/%^#<>=(){}[];:,.";

        public static List<Token> Lex(string s)
        {
            var toks = new List<Token>();
            int p = 0, line = 1, n = s.Length;
            while (true)
            {
                // whitespace and comments
                while (p < n)
                {
                    char c = s[p];
                    if (c == '\n') { line++; p++; continue; }
                    if (c == ' ' || c == '\t' || c == '\r' || c == '\f' || c == '\v') { p++; continue; }
                    if (c == '-' && p + 1 < n && s[p + 1] == '-')
                    {
                        p += 2;
                        int lvl = LongLevel(s, p);
                        if (lvl >= 0) { ReadLong(s, ref p, ref line, lvl); continue; }
                        while (p < n && s[p] != '\n') p++;
                        continue;
                    }
                    break;
                }
                if (p >= n) { toks.Add(new Token { Kind = TK.EOF, Text = "<eof>", Line = line }); return toks; }
                char ch = s[p];
                int startLine = line;
                if (char.IsLetter(ch) || ch == '_')
                {
                    int st = p;
                    while (p < n && (char.IsLetterOrDigit(s[p]) || s[p] == '_')) p++;
                    string w = s.Substring(st, p - st);
                    toks.Add(new Token { Kind = Keywords.Contains(w) ? TK.Keyword : TK.Name, Text = w, Line = startLine });
                    continue;
                }
                if (char.IsDigit(ch) || (ch == '.' && p + 1 < n && char.IsDigit(s[p + 1])))
                {
                    int st = p;
                    if (ch == '0' && p + 1 < n && (s[p + 1] == 'x' || s[p + 1] == 'X'))
                    {
                        p += 2;
                        while (p < n && Uri.IsHexDigit(s[p])) p++;
                    }
                    else
                    {
                        while (p < n && (char.IsLetterOrDigit(s[p]) || s[p] == '.' ||
                               ((s[p] == '+' || s[p] == '-') && (s[p - 1] == 'e' || s[p - 1] == 'E')))) p++;
                    }
                    toks.Add(new Token { Kind = TK.Number, Text = s.Substring(st, p - st), Line = startLine });
                    continue;
                }
                if (ch == '"' || ch == '\'')
                {
                    char q = ch; p++;
                    var sb = new StringBuilder();
                    while (true)
                    {
                        if (p >= n) throw new LuaSyntaxError("unfinished string", startLine);
                        char c = s[p++];
                        if (c == q) break;
                        if (c == '\n') throw new LuaSyntaxError("unfinished string", startLine);
                        if (c == '\\')
                        {
                            if (p >= n) throw new LuaSyntaxError("unfinished string", startLine);
                            char e = s[p++];
                            if (e == '\n') line++;
                            else if (!"abfnrtv\\\"'0123456789\r".Contains(e.ToString()))
                                throw new LuaSyntaxError("invalid escape sequence '\\" + e + "'", line);
                            sb.Append('\\').Append(e);
                            continue;
                        }
                        sb.Append(c);
                    }
                    toks.Add(new Token { Kind = TK.String, Text = sb.ToString(), Line = startLine });
                    continue;
                }
                if (ch == '[')
                {
                    int lvl = LongLevel(s, p);
                    if (lvl >= 0)
                    {
                        string v = ReadLong(s, ref p, ref line, lvl);
                        toks.Add(new Token { Kind = TK.String, Text = v, Line = startLine });
                        continue;
                    }
                }
                string op = null;
                foreach (var o in Ops3) if (string.CompareOrdinal(s, p, o, 0, o.Length) == 0) { op = o; break; }
                if (op == null) foreach (var o in Ops2) if (string.CompareOrdinal(s, p, o, 0, o.Length) == 0) { op = o; break; }
                if (op == null && Ops1.IndexOf(ch) >= 0) op = ch.ToString();
                if (op == null || op == "::") throw new LuaSyntaxError("unexpected symbol '" + ch + "'", line);
                p += op.Length;
                toks.Add(new Token { Kind = TK.Op, Text = op, Line = startLine });
            }
        }

        static int LongLevel(string s, int p)
        {
            if (p >= s.Length || s[p] != '[') return -1;
            int q = p + 1, lvl = 0;
            while (q < s.Length && s[q] == '=') { lvl++; q++; }
            return (q < s.Length && s[q] == '[') ? lvl : -1;
        }

        static string ReadLong(string s, ref int p, ref int line, int lvl)
        {
            int startLine = line;
            p += lvl + 2;
            string close = "]" + new string('=', lvl) + "]";
            int e = s.IndexOf(close, p, StringComparison.Ordinal);
            if (e < 0) throw new LuaSyntaxError("unfinished long string/comment", startLine);
            string v = s.Substring(p, e - p);
            foreach (char c in v) if (c == '\n') line++;
            p = e + close.Length;
            return v;
        }
    }

    public sealed class LuaChecker
    {
        List<Token> t;
        int i;
        readonly List<HashSet<string>> scopes = new List<HashSet<string>>();
        public readonly List<GlobalUse> Globals = new List<GlobalUse>();
        // Track whether each function body is vararg so `...` use can be checked.
        readonly Stack<bool> varargStack = new Stack<bool>();

        public static LuaChecker Check(string source)
        {
            var c = new LuaChecker();
            c.t = LuaLexer.Lex(source);
            c.i = 0;
            c.Open();
            c.varargStack.Push(true); // main chunk is vararg
            c.Block();
            if (c.Cur.Kind != TK.EOF) c.Err("'<eof>' expected near '" + c.Cur.Text + "'");
            return c;
        }

        Token Cur { get { return t[i]; } }
        Token Peek(int k) { return t[Math.Min(i + k, t.Count - 1)]; }
        void Next() { if (i < t.Count - 1) i++; }
        void Err(string m) { throw new LuaSyntaxError(m, Cur.Line); }
        bool Is(string op) { return (Cur.Kind == TK.Op || Cur.Kind == TK.Keyword) && Cur.Text == op; }
        bool Accept(string op) { if (Is(op)) { Next(); return true; } return false; }
        void Expect(string op, string what)
        {
            if (!Accept(op)) Err("'" + op + "' expected" + (what != null ? " (to close " + what + ")" : "") + " near '" + Cur.Text + "'");
        }
        string Name()
        {
            if (Cur.Kind != TK.Name) Err("<name> expected near '" + Cur.Text + "'");
            string n = Cur.Text; Next(); return n;
        }

        void Open() { scopes.Add(new HashSet<string>()); }
        void Close() { scopes.RemoveAt(scopes.Count - 1); }
        void Declare(string n) { scopes[scopes.Count - 1].Add(n); }
        bool IsLocal(string n)
        {
            for (int k = scopes.Count - 1; k >= 0; k--) if (scopes[k].Contains(n)) return true;
            return false;
        }

        bool BlockEnd()
        {
            return Cur.Kind == TK.EOF || Is("end") || Is("else") || Is("elseif") || Is("until");
        }

        void Block()
        {
            while (!BlockEnd())
            {
                if (Is("return"))
                {
                    Next();
                    if (!BlockEnd() && !Is(";")) ExprList();
                    Accept(";");
                    if (!BlockEnd()) Err("'end' expected near '" + Cur.Text + "'");
                    return;
                }
                if (Is("break"))
                {
                    Next(); Accept(";");
                    if (!BlockEnd()) Err("'end' expected near '" + Cur.Text + "'");
                    return;
                }
                Statement();
                Accept(";");
            }
        }

        void Statement()
        {
            int line = Cur.Line;
            if (Accept("if"))
            {
                Expr(); Expect("then", null); Open(); Block(); Close();
                while (Accept("elseif")) { Expr(); Expect("then", null); Open(); Block(); Close(); }
                if (Accept("else")) { Open(); Block(); Close(); }
                Expect("end", "'if' at line " + line);
                return;
            }
            if (Accept("while"))
            {
                Expr(); Expect("do", null); Open(); Block(); Close(); Expect("end", "'while' at line " + line);
                return;
            }
            if (Accept("do")) { Open(); Block(); Close(); Expect("end", "'do' at line " + line); return; }
            if (Accept("for"))
            {
                string n1 = Name();
                if (Accept("="))
                {
                    Expr(); Expect(",", null); Expr();
                    if (Accept(",")) Expr();
                    Expect("do", null);
                    Open(); Declare(n1); Block(); Close();
                }
                else
                {
                    var names = new List<string> { n1 };
                    while (Accept(",")) names.Add(Name());
                    Expect("in", null);
                    ExprList();
                    Expect("do", null);
                    Open(); foreach (var n in names) Declare(n); Block(); Close();
                }
                Expect("end", "'for' at line " + line);
                return;
            }
            if (Accept("repeat"))
            {
                Open(); Block(); Expect("until", "'repeat' at line " + line); Expr(); Close();
                return;
            }
            if (Accept("function"))
            {
                // funcname: Name {'.' Name} [':' Name]
                int nl = Cur.Line;
                string root = Name();
                bool method = false, dotted = false;
                string field = null;
                while (Accept(".")) { string f = Name(); if (field == null) field = f; dotted = true; }
                if (Accept(":")) { Name(); method = true; }
                if (!IsLocal(root))
                    Globals.Add(new GlobalUse { Name = root, Line = nl, Write = !(dotted || method), Field = field });
                FuncBody(method, line);
                return;
            }
            if (Accept("local"))
            {
                if (Accept("function"))
                {
                    string n = Name();
                    Declare(n);
                    FuncBody(false, line);
                    return;
                }
                var names = new List<string>();
                do { names.Add(Name()); } while (Accept(","));
                if (Accept("=")) ExprList();
                foreach (var n in names) Declare(n);
                return;
            }
            // exprstat: func call or assignment
            bool isCall;
            var target = SuffixedExpr(out isCall, true);
            if (Is("=") || Is(","))
            {
                var targets = new List<KeyValuePair<string, int>> { target };
                while (Accept(","))
                {
                    bool c2;
                    var tg = SuffixedExpr(out c2, true);
                    if (c2) Err("syntax error near '" + Cur.Text + "'");
                    targets.Add(tg);
                }
                if (isCall) Err("syntax error near '='");
                Expect("=", null);
                ExprList();
                foreach (var tg in targets)
                    if (tg.Key != null) Globals.Add(new GlobalUse { Name = tg.Key, Line = tg.Value, Write = true });
            }
            else if (!isCall)
            {
                Err("syntax error near '" + Cur.Text + "'");
            }
        }

        void FuncBody(bool method, int line)
        {
            Open();
            if (method) Declare("self");
            Expect("(", null);
            bool vararg = false;
            if (!Is(")"))
            {
                do
                {
                    if (Accept("...")) { vararg = true; break; }
                    Declare(Name());
                } while (Accept(","));
            }
            Expect(")", null);
            varargStack.Push(vararg);
            Block();
            varargStack.Pop();
            Expect("end", "'function' at line " + line);
            Close();
        }

        void ExprList() { Expr(); while (Accept(",")) Expr(); }

        static readonly Dictionary<string, int[]> BinPri = new Dictionary<string, int[]> {
            {"+", new[]{6,6}}, {"-", new[]{6,6}}, {"*", new[]{7,7}}, {"/", new[]{7,7}}, {"%", new[]{7,7}},
            {"^", new[]{10,9}}, {"..", new[]{5,4}},
            {"==", new[]{3,3}}, {"<", new[]{3,3}}, {"<=", new[]{3,3}}, {"~=", new[]{3,3}}, {">", new[]{3,3}}, {">=", new[]{3,3}},
            {"and", new[]{2,2}}, {"or", new[]{1,1}} };
        const int UnaryPri = 8;

        void Expr() { SubExpr(0); }

        void SubExpr(int limit)
        {
            if (Is("not") || Is("-") || Is("#")) { Next(); SubExpr(UnaryPri); }
            else SimpleExpr();
            while (true)
            {
                if (!(Cur.Kind == TK.Op || Cur.Kind == TK.Keyword)) break;
                int[] pr;
                if (!BinPri.TryGetValue(Cur.Text, out pr) || pr[0] <= limit) break;
                Next();
                SubExpr(pr[1]);
            }
        }

        void SimpleExpr()
        {
            switch (Cur.Kind)
            {
                case TK.Number: Next(); return;
                case TK.String: Next(); return;
            }
            if (Accept("nil") || Accept("true") || Accept("false")) return;
            if (Is("..."))
            {
                if (!varargStack.Peek()) Err("cannot use '...' outside a vararg function near '...'");
                Next(); return;
            }
            if (Is("{")) { TableCons(); return; }
            if (Accept("function")) { FuncBody(false, Cur.Line); return; }
            bool c;
            SuffixedExpr(out c, false);
        }

        // Returns (globalName, line) when the expression is a bare global variable, else (null,0).
        KeyValuePair<string, int> SuffixedExpr(out bool isCall, bool statement)
        {
            isCall = false;
            string bare = null; int bareLine = 0;
            bool bareIsGlobal = false;
            if (Cur.Kind == TK.Name)
            {
                bare = Cur.Text; bareLine = Cur.Line;
                bareIsGlobal = !IsLocal(bare);
                Next();
            }
            else if (Accept("("))
            {
                Expr(); Expect(")", null);
            }
            else Err("unexpected symbol near '" + Cur.Text + "'");

            bool suffixed = false;
            string firstField = null;
            while (true)
            {
                if (Is("."))
                {
                    Next(); string f = Name();
                    if (!suffixed) firstField = f;
                    suffixed = true; isCall = false;
                }
                else if (Is("["))
                {
                    Next(); Expr(); Expect("]", null); suffixed = true; isCall = false;
                }
                else if (Is(":"))
                {
                    Next(); Name(); CallArgs(); suffixed = true; isCall = true;
                }
                else if (Is("(") || Is("{") || Cur.Kind == TK.String)
                {
                    CallArgs(); suffixed = true; isCall = true;
                }
                else break;
            }
            if (bare != null && bareIsGlobal)
            {
                if (suffixed)
                {
                    Globals.Add(new GlobalUse { Name = bare, Line = bareLine, Write = false, Field = firstField });
                    return new KeyValuePair<string, int>(null, 0);
                }
                // Could be read or assignment target; caller decides. Record a read only if not assigned.
                if (!statement || !(Is("=") || Is(",")))
                    Globals.Add(new GlobalUse { Name = bare, Line = bareLine, Write = false });
                return new KeyValuePair<string, int>(bare, bareLine);
            }
            return new KeyValuePair<string, int>(null, 0);
        }

        void CallArgs()
        {
            if (Cur.Kind == TK.String) { Next(); return; }
            if (Is("{")) { TableCons(); return; }
            Expect("(", null);
            if (!Is(")")) ExprList();
            Expect(")", null);
        }

        void TableCons()
        {
            int line = Cur.Line;
            Expect("{", null);
            while (!Is("}"))
            {
                if (Is("[")) { Next(); Expr(); Expect("]", null); Expect("=", null); Expr(); }
                else if (Cur.Kind == TK.Name && Peek(1).Kind == TK.Op && Peek(1).Text == "=") { Next(); Next(); Expr(); }
                else Expr();
                if (!Accept(",") && !Accept(";")) break;
            }
            Expect("}", "'{' at line " + line);
        }
    }
}
