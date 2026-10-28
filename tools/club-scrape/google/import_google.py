"""Replaces the club catalog with the Google Maps list (items.json from build_items.py, plan.json from plan.py).

Phases, each safe to re-run:
  snapshot  saves the current venues to old_venues.json
  hide-old  hides the clubs imported from tennix.ir/tennisor.ir (hidden, not deleted; reversible from the admin panel)
  import    imports the Google places; places similar to a club still visible are reported, not imported
  hide-plan hides the uncertain and duplicate places listed in plan.json
  carry     gives a new place the photos and profile of the old club at the same spot (within 150 m)

Credentials from RALLYTO_ADMIN_EMAIL / RALLYTO_ADMIN_PASSWORD.
Usage: python import_google.py --api http://localhost:5100 snapshot hide-old import hide-plan carry
"""
import argparse
import json
import math
import os
import re
import sys
import tempfile
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent))
from import_to_rallyto import Api  # noqa: E402

CARRY_METRES = 150

def metres(a_lat, a_lng, b_lat, b_lng):
    la1, lo1, la2, lo2 = map(math.radians, (a_lat, a_lng, b_lat, b_lng))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))

def all_venues(api: Api) -> list[dict]:
    out, page = [], 1
    while True:
        res = api.call("GET", f"/api/v1/admin/venues?page={page}&pageSize=100")
        out += res["items"]
        if page * 100 >= res["totalCount"]:
            return out
        page += 1

def snapshot(api: Api, _):
    venues = all_venues(api)
    path = HERE / "old_venues.json"
    if path.exists():
        print("snapshot: old_venues.json already exists, kept")
        return
    path.write_text(json.dumps(venues, ensure_ascii=False, indent=1), encoding="utf8")
    print(f"snapshot: {len(venues)} venues")

def hide_old(api: Api, _):
    n = 0
    for v in all_venues(api):
        ref = v.get("sourceUrl") or ""
        if v["status"] == "Active" and ("tennix.ir" in ref or "tennisor.ir" in ref):
            api.call("POST", f"/api/v1/admin/venues/{v['id']}/hide")
            n += 1
    print(f"hide-old: hidden {n}")

def run_import(api: Api, items):
    totals, similar = {}, []
    batch = [x["item"] for x in items]
    for i in range(0, len(batch), 50):
        res = api.call("POST", "/api/v1/admin/venues/import", {"items": batch[i:i + 50], "allowSimilar": False})
        for o in res["items"]:
            totals[o["outcome"]] = totals.get(o["outcome"], 0) + 1
            if o["outcome"] in ("Similar", "Invalid"):
                similar.append(o)
    print("import:", totals)
    for o in similar:
        name = next(x["item"]["name"] for x in items if x["item"]["sourceRef"] == o["sourceRef"])
        print(f"  {o['outcome']}: {name} - {o['message']}")

def hide_plan(api: Api, items):
    plan = json.loads((HERE / "plan.json").read_text(encoding="utf8"))
    venues = {v["googlePlaceId"]: v for v in all_venues(api) if v.get("googlePlaceId")}
    n = 0
    for x in items:
        it = x["item"]
        v = venues.get(it["googlePlaceId"])
        if v and it["sourceRef"] in plan and v["status"] == "Active":
            api.call("POST", f"/api/v1/admin/venues/{v['id']}/hide")
            n += 1
    print(f"hide-plan: hidden {n}")

def carry(api: Api, _):
    old = [v for v in json.loads((HERE / "old_venues.json").read_text(encoding="utf8"))
           if v.get("latitude") and ("tennix.ir" in (v.get("sourceUrl") or "") or "tennisor.ir" in (v.get("sourceUrl") or ""))]
    new = [v for v in all_venues(api) if v.get("googlePlaceId") and v["status"] == "Active" and v.get("latitude")]
    # Each old club goes to its nearest visible new place within reach, and each new place takes one old club.
    pairs = sorted(((metres(o["latitude"], o["longitude"], n["latitude"], n["longitude"]), o, n) for o in old for n in new),
                   key=lambda p: p[0])
    used_old, used_new, matched = set(), set(), []
    for d, o, n in pairs:
        if d > CARRY_METRES:
            break
        if o["id"] in used_old or n["id"] in used_new:
            continue
        used_old.add(o["id"])
        used_new.add(n["id"])
        matched.append((d, o, n))

    photos = 0
    for d, o, n in matched:
        if not n["images"]:
            for path in o["images"]:
                with urllib.request.urlopen(api.base + path, timeout=60) as r:
                    data = r.read()
                with tempfile.NamedTemporaryFile(suffix=Path(path).suffix, delete=False) as f:
                    f.write(data)
                try:
                    api.upload(n["id"], Path(f.name))
                    photos += 1
                finally:
                    os.unlink(f.name)
        description = o["description"] or n["description"]
        if o["description"] and n["description"] and n["description"] not in o["description"]:
            description = f"{o['description']}\n\n{n['description']}"
        api.call("PUT", f"/api/v1/admin/venues/{n['id']}/profile", {
            "tagline": n["tagline"] or o["tagline"],
            "description": description[:4000] if description else None,
            "website": n["website"] or o["website"],
            "instagram": n["instagram"] or o["instagram"],
            "telegram": n["telegram"] or o["telegram"],
            "workingHours": n["workingHours"] or o["workingHours"],
            "amenities": list(dict.fromkeys(n["amenities"] + o["amenities"]))[:30],
            "courtTypes": list(dict.fromkeys(n["courtTypes"] + o["courtTypes"]))[:30],
        })
        # The old listing knew the courts better (count, surface, lighting); keep Google's name, place and phone.
        old_sport = next((s for s in o["sports"] if s["sportCode"] == "tennis"), None)
        new_sport = next((s for s in n["sports"] if s["sportCode"] == "tennis"), None)
        if old_sport and new_sport:
            sport = {**new_sport,
                     "courtCount": new_sport["courtCount"] or old_sport["courtCount"],
                     "surface": new_sport["surface"] or old_sport["surface"],
                     "setting": old_sport["setting"],
                     "hasLighting": new_sport["hasLighting"] or old_sport["hasLighting"]}
            api.call("PUT", f"/api/v1/admin/venues/{n['id']}", {
                "cityId": n["cityId"], "name": n["name"], "address": n["address"], "phone": n["phone"] or (o["phone"] if re.fullmatch(r"0\d{10}",o["phone"] or "") else None),
                "latitude": n["latitude"], "longitude": n["longitude"], "allowSimilar": True,
                "sports": [sport if s["sportCode"] == "tennis" else s for s in n["sports"]]})
    print(f"carry: {len(matched)} places took over an old club's profile, {photos} photos copied")
    (HERE / "carry.json").write_text(json.dumps([{"metres": round(d), "old": o["name"], "new": n["name"]} for d, o, n in matched],
                                                ensure_ascii=False, indent=1), encoding="utf8")

PHASES = {"snapshot": snapshot, "hide-old": hide_old, "import": run_import, "hide-plan": hide_plan, "carry": carry}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", required=True)
    ap.add_argument("phases", nargs="+", choices=list(PHASES))
    a = ap.parse_args()
    api = Api(a.api)
    api.sign_in(os.environ["RALLYTO_ADMIN_EMAIL"], os.environ["RALLYTO_ADMIN_PASSWORD"])
    items = json.loads((HERE / "items.json").read_text(encoding="utf8"))
    for phase in a.phases:
        PHASES[phase](api, items)

if __name__ == "__main__":
    main()
