"""Decides which imported places stay visible: medium-confidence rows and the weaker listings of a place listed more
than once (within 60 m) are hidden for an admin to review. Writes plan.json."""
import json
import math
from pathlib import Path

HERE = Path(__file__).parent
GENERIC = ("زمین تنیس (", "تنیس (")


def metres(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a["latitude"], a["longitude"], b["latitude"], b["longitude"]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))


def score(x):
    it = x["item"]
    return (x["confidence"] == "بالا", not it["name"].startswith(GENERIC), it["phone"] is not None,
            it["googleReviewCount"] or 0, it["profile"]["workingHours"] is not None)


def main():
    items = json.loads((HERE / "items.json").read_text(encoding="utf8"))
    parent = list(range(len(items)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if metres(items[i]["item"], items[j]["item"]) < 60:
                parent[find(i)] = find(j)
    groups = {}
    for i in range(len(items)):
        groups.setdefault(find(i), []).append(i)

    hidden = {}
    for members in groups.values():
        best = max(members, key=lambda i: score(items[i]))
        for i in members:
            if i != best:
                hidden[items[i]["item"]["sourceRef"]] = f"تکراری احتمالی «{items[best]['item']['name']}»"
        for i in members:
            if items[i]["confidence"] != "بالا":
                hidden.setdefault(items[i]["item"]["sourceRef"], "تنیس بودن قطعی نیست (اطمینان متوسط)")
    multi = [g for g in groups.values() if len(g) > 1]
    (HERE / "plan.json").write_text(json.dumps(hidden, ensure_ascii=False, indent=1), encoding="utf8")
    print(f"groups with >1 listing: {len(multi)} ({sum(len(g) for g in multi)} listings); hidden: {len(hidden)}; visible: {len(items) - len(hidden)}")
    for g in multi[:12]:
        print(" | ".join(("*" if items[i]["item"]["sourceRef"] not in hidden else "") + items[i]["item"]["name"] for i in g))


if __name__ == "__main__":
    main()
