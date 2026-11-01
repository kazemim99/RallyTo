"""Builds the Rallyto import items for padel, squash and badminton places from rows.json (the racket-sports
spreadsheet) and the Persian translations out1..3.json. Writes items.json and plan.json (places hidden for review)."""
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "google"))
from build_items import COUNTY, load_cities, norm, phone  # noqa: E402  (same town→county table as the tennis list)

SPORTS = {"پدل": "padel", "اسکواش": "squash", "بدمینتون": "badminton"}
# A sport whose court setting the listing does not tell: squash and badminton halls are indoor, padel courts outdoor.
DEFAULT_SETTING = {"padel": "Outdoor", "squash": "Indoor", "badminton": "Indoor"}
EXTRA_COUNTY = {"ازیران": "اصفهان", "هشتگرد": "ساوجبلاغ", "ماهدشت": "کرج", "قائن": "قاینات", "طرقبه": "طرقبه شاندیز",
                "رشکلا": "آمل", "سی‌سخت": "دنا", "سوق": "کهگیلویه", "کوچصفهان": "رشت"}


def metres(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a["latitude"], a["longitude"], b["latitude"], b["longitude"]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))


def main() -> None:
    rows = json.loads((HERE / "rows.json").read_text(encoding="utf8"))
    fa = {}
    for k in range(1, 4):
        fa.update(json.loads((HERE / f"out{k}.json").read_text(encoding="utf8")))
    cities = load_cities()
    counties = {**COUNTY, **EXTRA_COUNTY}

    items, problems = [], []
    for r in rows:
        t = fa[str(r["id"])]
        province = cities[norm(r["province"])]
        county = counties.get(f"{t['city_fa']}@{r['province']}") or counties.get(t["city_fa"]) or t["city_fa"]
        city_id = province.get(norm(county))
        if city_id is None:
            problems.append(f"{r['id']}: no city for {t['city_fa']} ({r['province']})")
            continue
        codes = [SPORTS[s.strip()] for s in r["sports"].split("،")]
        count = t.get("court_count") if isinstance(t.get("court_count"), int) and 1 <= t["court_count"] <= 100 else None
        sports = [{
            "sportCode": code,
            "courtCount": count if len(codes) == 1 else None,
            "setting": "Indoor" if t.get("indoor") is True else "Outdoor" if t.get("indoor") is False else DEFAULT_SETTING[code],
            "surface": None,
            "hasLighting": False,
        } for code in codes]
        rating = float(r["rating"]) if r["rating"] else None
        reviews = int(r["reviews"]) if r["reviews"] is not None else (0 if rating else None)
        items.append({
            "rowId": r["id"], "confidence": r["confidence"], "public": t.get("public"), "codes": codes,
            "item": {
                "sourceRef": f"google:{r['place_id']}",
                "sourceUrl": r["maps_url"] or f"https://www.google.com/maps/place/?q=place_id:{r['place_id']}",
                "googlePlaceId": r["place_id"], "googleRating": rating, "googleReviewCount": reviews,
                "cityId": city_id, "name": t["name_fa"].strip(), "address": t["address_fa"].strip(), "phone": phone(r["phone"]),
                "latitude": r["lat"], "longitude": r["lng"], "sports": sports,
                "profile": {"tagline": None, "description": t.get("info_fa"), "website": None, "instagram": None, "telegram": None,
                            "workingHours": t.get("hours_fa"), "amenities": [], "courtTypes": []},
            },
        })

    # Hidden for review: uncertain places, places not open to the public, and the weaker of two listings of one
    # place (within 60 m and sharing a sport).
    plan = {}
    for x in items:
        if x["confidence"] != "بالا":
            plan[x["item"]["sourceRef"]] = "ورزش قطعی نیست (اطمینان متوسط)"
        elif x["public"] is False:
            plan[x["item"]["sourceRef"]] = "برای عموم باز نیست (مدرسه یا دفتر هیئت)"

    def score(x):
        it = x["item"]
        return (x["confidence"] == "بالا", x["public"] is not False, it["phone"] is not None, it["googleReviewCount"] or 0)

    for i, a in enumerate(items):
        for b in items[i + 1:]:
            if set(a["codes"]) & set(b["codes"]) and metres(a["item"], b["item"]) < 60:
                weaker, better = (a, b) if score(a) < score(b) else (b, a)
                plan.setdefault(weaker["item"]["sourceRef"], f"تکراری احتمالی «{better['item']['name']}»")

    (HERE / "items.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf8")
    (HERE / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=1), encoding="utf8")
    print(f"items: {len(items)}, hidden for review: {len(plan)}, problems: {len(problems)}")
    for p in problems:
        print("  ", p)


if __name__ == "__main__":
    main()
