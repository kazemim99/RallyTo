"""Loads the padel, squash and badminton places (items.json and plan.json from build_items.py) into Rallyto.

- A new place is created with each of its sports.
- A place already in the catalog under the same Google place (a tennis club that also has padel, say) keeps its
  record and gains the sports it lacks (unless that listing is on the review list); nothing it has is changed.
- Places similar by name to a visible club in their city are reported, then imported anyway with --allow-similar.
- Places listed in plan.json (uncertain, not public, or a second listing of one place) are hidden for review.

Credentials from RALLYTO_ADMIN_EMAIL / RALLYTO_ADMIN_PASSWORD. Safe to re-run.
Usage: python import_racket.py --api http://localhost:5100 [--allow-similar]
"""
import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent))
from import_to_rallyto import Api  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", required=True)
    ap.add_argument("--allow-similar", action="store_true")
    a = ap.parse_args()
    api = Api(a.api)
    api.sign_in(os.environ["RALLYTO_ADMIN_EMAIL"], os.environ["RALLYTO_ADMIN_PASSWORD"])
    items = json.loads((HERE / "items.json").read_text(encoding="utf8"))
    plan = json.loads((HERE / "plan.json").read_text(encoding="utf8"))
    by_ref = {x["item"]["sourceRef"]: x for x in items}

    totals, ids, added = {}, {}, 0
    batch = [x["item"] for x in items]
    for i in range(0, len(batch), 50):
        res = api.call("POST", "/api/v1/admin/venues/import", {"items": batch[i:i + 50], "allowSimilar": a.allow_similar})
        for o in res["items"]:
            totals[o["outcome"]] = totals.get(o["outcome"], 0) + 1
            if o["venueId"]:
                ids[o["sourceRef"]] = (o["venueId"], o["outcome"])
            else:
                print(f"  {o['outcome']}: {by_ref[o['sourceRef']]['item']['name']} - {o['message']}")
    print("import:", totals)

    # Existing places: add the racket sports they lack, keep everything else as it is.
    for ref, (venue_id, outcome) in ids.items():
        if outcome != "Existing" or ref in plan:  # an uncertain sport is not added to a club players already see
            continue
        v = api.call("GET", f"/api/v1/admin/venues/{venue_id}")
        have = {s["sportCode"] for s in v["sports"]}
        new = [s for s in by_ref[ref]["item"]["sports"] if s["sportCode"] not in have]
        if not new:
            continue
        api.call("PUT", f"/api/v1/admin/venues/{venue_id}", {
            "cityId": v["cityId"], "name": v["name"], "address": v["address"], "phone": v["phone"],
            "latitude": v["latitude"], "longitude": v["longitude"], "sports": v["sports"] + new, "allowSimilar": True})
        added += 1
        print(f"  + {'، '.join(s['sportCode'] for s in new)} → {v['name']}")
        if v["status"] != "Active":
            # The tennis import hid this record (uncertain tennis, or a second listing of a club already in the
            # catalog), so players would not see the confirmed sport just added. Decide by hand: unhide without
            # tennis, or move the sport to the visible record of the same club.
            print(f"    ! {v['name']} is hidden: the sport added above is not visible to players")
    print(f"sports added to existing places: {added}")

    hidden = 0
    for ref, (venue_id, outcome) in ids.items():
        if ref in plan and outcome == "Created":
            api.call("POST", f"/api/v1/admin/venues/{venue_id}/hide")
            hidden += 1
    print(f"hidden for review: {hidden}")


if __name__ == "__main__":
    main()
