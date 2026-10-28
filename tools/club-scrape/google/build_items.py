"""Builds the Rallyto import items from rows.json (the Google Maps spreadsheet) and the Persian translations
out1..4.json. Writes items.json; prints anything it cannot place."""
import json
import re
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).parent

# Towns the province/county dataset lacks, mapped to the county they belong to (the address keeps the town).
COUNTY = {
    "سهند": "اسکو", "بهارستان@اصفهان": "اصفهان", "درچه": "خمینی شهر", "دستگرد": "برخوار", "زرین‌شهر": "لنجان",
    "شاهین‌شهر": "شاهین شهرو میمه", "فولادشهر": "لنجان", "احمدآباد مصدق": "نظرآباد", "کردان": "ساوجبلاغ",
    "بندر امام حسن": "دیلم", "بندر سیراف": "کنگان", "اندیشه": "شهریار", "باغستان": "شهریار", "باقرشهر": "ری",
    "جیتو": "ورامین", "خانلق": "ری", "صباشهر": "شهریار", "لواسان": "شمیرانات", "پرند": "رباط کریم",
    "شاندیز": "طرقبه شاندیز", "چابهار": "چاه بهار", "لار": "لارستان", "امیرکلا": "بابل", "خلیل‌شهر": "بهشهر",
    "سلمان‌شهر": "عباس آباد", "قائم‌شهر": "قایم شهر", "نمک‌آبرود": "چالوس", "دهبارز": "رودان", "سیری": "ابوموسی",
    "لاوان": "بندر لنگه", "چاه‌دراز": "خمیر", "کیش": "بندر لنگه", "بندر ترکمن": "ترکمن",
}
SURFACE_LABEL = {"Clay": "خاک رس", "Hard": "هارد", "Grass": "چمن طبیعی", "ArtificialGrass": "چمن مصنوعی"}
FA_DIGITS = str.maketrans("0123456789", "۰۱۲۳۴۵۶۷۸۹")


def norm(s: str) -> str:
    return re.sub(r"[\s‌\-]+", "", (s or "").replace("ك", "ک").replace("ي", "ی").replace("آ", "ا"))


def phone(raw) -> str | None:
    """+98 914 421 1217 -> 09144211217; +98 21 2621 6153 -> 02126216153. Foreign numbers are dropped."""
    digits = re.sub(r"\D", "", str(raw or ""))
    if not digits.startswith("98") or len(digits) != 12:
        return None
    return "0" + digits[2:]


def load_cities():
    by_province = defaultdict(dict)
    for line in (HERE / "cities.txt").read_text(encoding="utf8").splitlines():
        cid, city, province = line.split("|")
        by_province[norm(province)][norm(city)] = int(cid)
    return by_province


def main() -> None:
    rows = json.loads((HERE / "rows.json").read_text(encoding="utf8"))
    fa = {}
    for k in range(1, 5):
        fa.update(json.loads((HERE / f"out{k}.json").read_text(encoding="utf8")))
    cities = load_cities()

    items, problems = [], []
    for r in rows:
        t = fa[str(r["id"])]
        province = cities[norm(r["province"])]
        county = COUNTY.get(f"{t['city_fa']}@{r['province']}") or COUNTY.get(t["city_fa"]) or t["city_fa"]
        city_id = province.get(norm(county))
        if city_id is None:
            problems.append(f"{r['id']}: no city for {t['city_fa']} ({r['province']})")
            continue

        rating = float(r["rating"]) if r["rating"] else None
        reviews = int(r["reviews"]) if r["reviews"] is not None else (0 if rating else None)
        court_types = [SURFACE_LABEL[t["surface"]]] if t.get("surface") else []
        if t.get("indoor") is True:
            court_types.append("سرپوشیده")
        elif t.get("indoor") is False:
            court_types.append("روباز")
        setting = "Indoor" if t.get("indoor") is True else "Outdoor"
        count = t.get("court_count") if isinstance(t.get("court_count"), int) and 1 <= t["court_count"] <= 100 else None

        items.append({
            "rowId": r["id"],
            "confidence": r["confidence"],
            "near": r["near"],
            "item": {
                "sourceRef": f"google:{r['place_id']}",
                "sourceUrl": r["maps_url"] or f"https://www.google.com/maps/place/?q=place_id:{r['place_id']}",
                "googlePlaceId": r["place_id"],
                "googleRating": rating,
                "googleReviewCount": reviews,
                "cityId": city_id,
                "name": t["name_fa"].strip(),
                "address": t["address_fa"].strip(),
                "phone": phone(r["phone"]),
                "latitude": r["lat"],
                "longitude": r["lng"],
                "sports": [{"sportCode": "tennis", "courtCount": count, "setting": setting, "surface": t.get("surface"), "hasLighting": False}],
                "profile": {
                    "tagline": None,
                    "description": t.get("info_fa"),
                    "website": None, "instagram": None, "telegram": None,
                    "workingHours": t.get("hours_fa"),
                    "amenities": [],
                    "courtTypes": court_types,
                },
            },
        })

    (HERE / "items.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf8")
    print(f"items: {len(items)}, problems: {len(problems)}")
    for p in problems:
        print("  ", p)


if __name__ == "__main__":
    main()
