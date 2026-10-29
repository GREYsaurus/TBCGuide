"""Coverage counts for roaming routes, from docs/research/roaming-dispositions.csv and the compiled routes.

Definitions (docs/ROAMING.md, "Coverage"):
  unique routes        distinct point sets (a route block reused by another quest counts once)
  objectives supported quest objectives with a route (own or reused)
  reviewed             objectives with any disposition other than "Not researched"
usage: python -I tools/research/roam_coverage.py
"""
import csv, collections, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
rows = list(csv.DictReader(open(os.path.join(ROOT, "docs", "research", "roaming-dispositions.csv"), encoding="utf-8")))
lua = open(os.path.join(ROOT, "TBCGuide", "Guides", "Compiled", "Routes.lua"), encoding="utf-8").read()
blocks = re.findall(r"zone=(\d+).*?objs=\{(.*?)\},\s*pts=\{(.*?)\} \}", lua, re.S)
geoms = {(z, p) for z, _, p in blocks}
objs = sum(len(re.findall(r"\{i=", o)) for _, o, _ in blocks)
st = collections.Counter(r["status"] for r in rows)
quests = {r["quest"] for r in rows if r["status"] in ("Verified and implemented", "Existing route reused — association verified")}
print("route blocks in Routes.lua:", len(blocks))
print("unique routes (distinct point sets):", len(geoms))
print("quest objectives with a route:", objs, "in", len(quests), "quests")
print("candidate objectives in the record:", len(rows))
for k, v in st.most_common(): print("  %-45s %d" % (k, v))
print("reviewed (anything but Not researched):", len(rows) - st.get("Not researched", 0))
z = collections.Counter(r["zone"] for r in rows if r["status"] in ("Verified and implemented", "Existing route reused — association verified"))
print("zones with routes:", len(z))
