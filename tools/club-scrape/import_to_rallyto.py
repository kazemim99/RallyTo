"""Load the clubs collected by scrape_clubs.py into Rallyto through its admin API.

Credentials come from the environment, never from arguments:
  RALLYTO_ADMIN_EMAIL, RALLYTO_ADMIN_PASSWORD

Re-running is safe: a club is identified by its source reference (<source>:<slug>); clubs already in the catalog
are left untouched and only receive photos while they have none. Clubs similar to an existing one in their city
are skipped and listed unless --allow-similar is given.

Usage: python import_to_rallyto.py --api http://localhost:5000 [--data output] [--allow-similar] [--dry-run]
"""
import argparse
import json
import mimetypes
import os
import re
import sys
import urllib.error
import time
import urllib.request
import uuid
from pathlib import Path

SURFACES = [("چمن مصنوعی", "ArtificialGrass"), ("چمن", "Grass"), ("خاک رس", "Clay"), ("خاکی", "Clay"), ("هارد", "Hard"),
            ("موکت", "Carpet")]
TENNISOR_LABELS = {"indoor": "زمین سرپوشیده", "outdoor": "زمین روباز", "lighting": "نورپردازی شبانه", "coach": "مربی"}
BATCH = 50
# Places the province/city dataset lacks, mapped to the city they administratively belong to. The club's own
# address keeps the original name.
CITY_ALIASES = {"کیش": "بندر لنگه", "درچه": "اصفهان", "فولادشهر": "لنجان"}


def norm(text: str) -> str:
    return re.sub(r"[\s‌]+", "", (text or "").replace("ك", "ک").replace("ي", "ی")).lower()


class Api:
    def __init__(self, base: str):
        self.base, self.token = base.rstrip("/"), None

    def call(self, method: str, path: str, body=None, headers=None, raw: bytes | None = None):
        # The API allows 300 requests a minute per user: pace calls and wait out a 429.
        for attempt in range(6):
            try:
                time.sleep(0.25)
                return self._send(method, path, body, headers, raw)
            except RuntimeError as e:
                if " 429 " not in str(e) or attempt == 5:
                    raise
                time.sleep(15)

    def _send(self, method: str, path: str, body=None, headers=None, raw: bytes | None = None):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        h = {"Accept": "application/json", **(headers or {})}
        if body is not None:
            h["Content-Type"] = "application/json"
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"
        req = urllib.request.Request(f"{self.base}{path}", data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                text = r.read().decode("utf8")
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{method} {path} -> {e.code} {e.read().decode('utf8')[:300]}") from None
        return json.loads(text).get("data") if text else None

    def sign_in(self, email: str, password: str):
        self.token = self.call("POST", "/api/v1/auth/admin/sign-in", {"email": email, "password": password})["accessToken"]

    def upload(self, venue_id: str, file: Path):
        boundary = uuid.uuid4().hex
        mime = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        head = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{file.name}\"\r\n"
                f"Content-Type: {mime}\r\n\r\n").encode()
        raw = head + file.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        return self.call("POST", f"/api/v1/admin/venues/{venue_id}/images", headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, raw=raw)


def city_index(api: Api) -> dict[str, list[int]]:
    index: dict[str, list[tuple[int, bool]]] = {}
    for p in api.call("GET", "/api/v1/provinces"):
        for c in api.call("GET", f"/api/v1/provinces/{p['id']}/cities"):
            index.setdefault(norm(c["name"]), []).append((c["id"], norm(p["name"]) == norm(c["name"])))
    # for duplicated names prefer the city that carries its province's name (e.g. Tehran in Tehran)
    return {k: [i for i, _ in sorted(v, key=lambda t: not t[1])] for k, v in index.items()}


def sport_for(club: dict) -> dict:
    types, amenities = club["court_types"], club["amenities"]
    text = " ".join(types + amenities)
    indoor = "سرپوشیده" in text or "indoor" in amenities
    outdoor = "روباز" in text or "outdoor" in amenities
    setting = "Both" if indoor and (outdoor or club["source"] == "tennix.ir") else "Indoor" if indoor else "Outdoor"
    surface = next((code for label, code in SURFACES if any(label in t for t in types)), None)
    courts = club["courts"] if isinstance(club["courts"], int) and 1 <= club["courts"] <= 100 else None
    lighting = any("نورپردازی" in a or a == "lighting" for a in amenities)
    return {"sportCode": "tennis", "courtCount": courts, "setting": setting, "surface": surface, "hasLighting": lighting}


def link(value: str | None, host: str | None = None) -> str | None:
    """Social handles come as bare names (hotelpardisan) on some listings; the API only takes http(s) links."""
    if not value or re.match(r"https?://", value):
        return value
    handle = value.strip().lstrip("@")
    return f"https://{host}/{handle}" if host and re.fullmatch(r"[A-Za-z0-9_.]+", handle) else None


def item_for(club: dict, city_id: int) -> dict:
    return {
        "sourceRef": f"{club['source']}:{club['slug']}", "sourceUrl": club["source_url"], "cityId": city_id,
        "name": club["name"].strip(), "address": club["address"], "phone": club["phone"],
        "latitude": club["latitude"], "longitude": club["longitude"], "sports": [sport_for(club)],
        "profile": {
            "tagline": club["tagline"], "description": club["description"], "website": club["website"],
            "instagram": link(club["instagram"], "instagram.com"), "telegram": link(club["telegram"], "t.me"), "workingHours": club["hours"],
            "amenities": [TENNISOR_LABELS.get(a, a) for a in club["amenities"]], "courtTypes": club["court_types"],
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", required=True)
    ap.add_argument("--data", default="output")
    ap.add_argument("--allow-similar", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-ref", action="append", default=[], help="source reference to leave out, e.g. tennix.ir:some-slug")
    a = ap.parse_args()
    data = Path(a.data)
    clubs = json.loads((data / "clubs.json").read_text(encoding="utf8"))

    api = Api(a.api)
    api.sign_in(os.environ["RALLYTO_ADMIN_EMAIL"], os.environ["RALLYTO_ADMIN_PASSWORD"])
    cities = city_index(api)

    items, unmatched = [], []
    for club in clubs:
        if f"{club['source']}:{club['slug']}" in a.skip_ref:
            continue
        ids = cities.get(norm(CITY_ALIASES.get(club["city"] or "", club["city"] or "")))
        if not ids:
            unmatched.append(f"{club['name']} ({club['city']})")
            continue
        items.append((club, item_for(club, ids[0])))
    print(f"clubs: {len(clubs)}, city matched: {len(items)}, unmatched: {len(unmatched)}")
    for u in unmatched:
        print("  no city:", u)
    if a.dry_run:
        return 0

    venue_ids: dict[str, str] = {}
    created_refs: set[str] = set()
    totals = {"Created": 0, "Existing": 0, "Similar": 0, "Invalid": 0}
    for i in range(0, len(items), BATCH):
        chunk = items[i:i + BATCH]
        res = api.call("POST", "/api/v1/admin/venues/import", {"items": [it for _, it in chunk], "allowSimilar": a.allow_similar})
        for o in res["items"]:
            totals[o["outcome"]] += 1
            if o["venueId"]:
                venue_ids[o["sourceRef"]] = o["venueId"]
                if o["outcome"] == "Created":
                    created_refs.add(o["sourceRef"])
            elif o["outcome"] in ("Similar", "Invalid"):
                print(f"  {o['outcome']}: {o['sourceRef']} - {o['message']}")
    print("import:", totals)

    uploaded = failed = 0
    for club, it in items:
        vid = venue_ids.get(it["sourceRef"])
        if not vid or (it["sourceRef"] not in created_refs and api.call("GET", f"/api/v1/admin/venues/{vid}")["images"]):
            continue
        for rel in club.get("images", []):
            try:
                api.upload(vid, data / rel)
                uploaded += 1
            except Exception as e:  # noqa: BLE001
                failed += 1
                print(f"  photo failed {rel}: {e}")
    print(f"photos uploaded: {uploaded}, failed: {failed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
