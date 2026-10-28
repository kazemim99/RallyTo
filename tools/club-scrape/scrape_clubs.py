"""Collect tennis clubs (with images) from tennix.ir and tennisor.ir public JSON APIs.

Both sites allow crawling in robots.txt. Requests are throttled (--delay, default 0.4s).
Output (under --out, default ./output):
  clubs.json / clubs.csv      normalized records, one per club
  images/<source>/<slug>/...  downloaded images

Usage: python scrape_clubs.py [--out output] [--delay 0.4] [--no-images]
"""
import argparse
import csv
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

UA = {"User-Agent": "Mozilla/5.0 (Rallyto club research)", "Accept": "application/json, image/*, */*"}


def fetch(url: str, retries: int = 3) -> bytes:
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001 - retry on any transport error
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"{url}: {last}")


def get_json(url: str):
    return json.loads(fetch(url).decode("utf8"))


def absurl(base: str, path: str | None) -> str | None:
    return urllib.parse.urljoin(base, path) if path else None


def uniq(seq):
    seen, out = set(), []
    for x in seq:
        if x and x not in seen:
            seen.add(x)
            out.append(x)
    return out


def tennix() -> list[dict]:
    base = "https://tennix.ir"
    rows = []
    for c in get_json(f"{base}/api/clubs"):
        images = uniq([absurl(base, c.get("image")), absurl(base, c.get("coverImage"))]
                      + [absurl(base, g) for g in (c.get("gallery") or [])])
        rows.append({
            "source": "tennix.ir", "source_id": str(c["id"]), "slug": c["slug"],
            "source_url": f"{base}/clubs/{c['slug']}",
            "name": c["name"], "city": c.get("city"), "address": c.get("address"),
            "latitude": float(c["latitude"]) if c.get("latitude") else None,
            "longitude": float(c["longitude"]) if c.get("longitude") else None,
            "phone": c.get("phone"), "website": c.get("website"),
            "instagram": c.get("instagram"), "telegram": c.get("telegram"),
            "courts": c.get("courts"), "court_types": c.get("courtTypes") or [],
            "amenities": c.get("amenities") or [], "hours": c.get("hours"),
            "rating": c.get("rating"), "tagline": c.get("tagline"),
            "description": re.sub(r"<[^>]+>", " ", c.get("description") or "").strip() or None,
            "image_urls": images,
        })
    return rows


def tennisor() -> list[dict]:
    api, site = "https://api.tennisor.ir/api", "https://tennisor.ir"
    rows, page = [], 1
    while True:
        res = get_json(f"{api}/clubs?per_page=100&page={page}")
        for c in res["data"]:
            media = [m["url"] for m in sorted(c.get("media") or [], key=lambda m: m.get("sort_order", 0))
                     if m.get("type", "image") == "image"]
            city = c.get("city")
            rows.append({
                "source": "tennisor.ir", "source_id": str(c["id"]), "slug": c["slug"],
                "source_url": f"{site}/clubs/{c['slug']}",
                "name": c["name"],
                "city": city.get("name") if isinstance(city, dict) else city,
                "address": c.get("address"), "latitude": c.get("lat"), "longitude": c.get("lng"),
                "phone": c.get("phone"), "website": c.get("website"), "instagram": None, "telegram": None,
                "courts": c.get("courts_count"),
                "court_types": [t.get("label") if isinstance(t, dict) else t for t in c.get("court_types") or []],
                "amenities": [k for k, f in (("indoor", "has_indoor"), ("outdoor", "has_outdoor"),
                                             ("lighting", "has_lighting"), ("coach", "has_coach")) if c.get(f)],
                "hours": None, "rating": c.get("rating_avg"), "tagline": None,
                "description": c.get("description"),
                "image_urls": uniq([c.get("logo"), c.get("cover_image") if isinstance(c.get("cover_image"), str) else None] + media),
            })
        if page >= res["meta"]["last_page"]:
            return rows
        page += 1


def download_images(rows: list[dict], out: Path, delay: float) -> None:
    for i, row in enumerate(rows, 1):
        folder = out / "images" / row["source"] / row["slug"]
        row["images"] = []
        for n, url in enumerate(row["image_urls"]):
            ext = Path(urllib.parse.urlparse(url).path).suffix.lower() or ".jpg"
            dest = folder / f"{n:02d}{ext}"
            try:
                if not dest.exists() or dest.stat().st_size == 0:
                    folder.mkdir(parents=True, exist_ok=True)
                    data = fetch(url)
                    time.sleep(delay)
                    if not data:
                        raise RuntimeError("empty response")
                    dest.write_bytes(data)
                row["images"].append(str(dest.relative_to(out)).replace("\\", "/"))
            except Exception as e:  # noqa: BLE001
                print(f"  ! {url}: {e}")
        if i % 20 == 0:
            print(f"  images: {i}/{len(rows)} clubs")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="output")
    ap.add_argument("--delay", type=float, default=0.4)
    ap.add_argument("--no-images", action="store_true")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    rows = tennix() + tennisor()
    print(f"clubs: {len(rows)}")
    if not a.no_images:
        download_images(rows, out, a.delay)

    (out / "clubs.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf8")
    cols = ["source", "source_id", "slug", "name", "city", "address", "latitude", "longitude", "phone", "website",
            "instagram", "telegram", "courts", "court_types", "hours", "rating", "source_url", "images"]
    with (out / "clubs.csv").open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({**r, "court_types": "|".join(r["court_types"]),
                        "images": "|".join(r.get("images", []))})
    print("done ->", out.resolve())


if __name__ == "__main__":
    main()
