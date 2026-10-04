#!/usr/bin/env python3
"""Natural Earth admin-0 countries geojson -> per-country outline assets.

One-off, dev-time-only build step (not run by the app or CI). Reads a
locally downloaded copy of Natural Earth's public-domain
``ne_50m_admin_0_countries.geojson``
(https://github.com/nvkelso/natural-earth-vector, geojson folder) and emits:

  assets/countries/{ISO_A2}.json
    {"iso": "KR", "name": "South Korea",
     "bbox": [minLon, minLat, maxLon, maxLat],
     "rings": [[[lon, lat], ...], ...]}

  assets/countries/_index.json
    {"KR": [minLon, minLat, maxLon, maxLat], ...}

Only exterior rings are kept (holes dropped), rings smaller than 1% of the
group's largest ring area are dropped (kills tiny islets, keeps e.g. Jeju),
and every kept ring is simplified with Douglas-Peucker so each file stays a
few KB. No third-party dependencies (stdlib only) -- this script exists so
the app can resolve "which country is this pin in" and draw its outline
fully offline, no `geocoding`/network call involved.

Usage:
    python3 tools/build_countries.py <path-to-ne_50m_admin_0_countries.geojson> \
        [--out assets/countries] [--min-area-ratio 0.01]
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from typing import Iterable

Point = tuple[float, float]
Ring = list[Point]


def shoelace_area(ring: Ring) -> float:
    """Unsigned polygon area in squared-degree units (relative-size only)."""
    n = len(ring)
    if n < 3:
        return 0.0
    total = 0.0
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        total += x1 * y2 - x2 * y1
    return abs(total) / 2.0


def ring_bbox(ring: Ring) -> tuple[float, float, float, float]:
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return (min(lons), min(lats), max(lons), max(lats))


def union_bbox(
    boxes: Iterable[tuple[float, float, float, float]],
) -> tuple[float, float, float, float]:
    boxes = list(boxes)
    return (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def _perp_distance(p: Point, a: Point, b: Point) -> float:
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    proj_x, proj_y = ax + t * dx, ay + t * dy
    return math.hypot(px - proj_x, py - proj_y)


def douglas_peucker(points: Ring, epsilon: float) -> Ring:
    """Iterative Douglas-Peucker simplification (recursion-free to avoid
    hitting Python's recursion limit on large rings)."""
    if len(points) < 3 or epsilon <= 0:
        return list(points)

    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]

    while stack:
        start, end = stack.pop()
        if end <= start + 1:
            continue
        a, b = points[start], points[end]
        max_dist = -1.0
        max_idx = -1
        for i in range(start + 1, end):
            d = _perp_distance(points[i], a, b)
            if d > max_dist:
                max_dist = d
                max_idx = i
        if max_dist > epsilon:
            keep[max_idx] = True
            stack.append((start, max_idx))
            stack.append((max_idx, end))

    return [p for p, k in zip(points, keep) if k]


def exterior_rings_of(geometry: dict) -> list[Ring]:
    gtype = geometry.get("type")
    coords = geometry.get("coordinates", [])
    rings: list[Ring] = []
    if gtype == "Polygon":
        if coords:
            rings.append([(float(x), float(y)) for x, y in coords[0]])
    elif gtype == "MultiPolygon":
        for polygon in coords:
            if polygon:
                rings.append([(float(x), float(y)) for x, y in polygon[0]])
    return rings


def resolve_iso2(props: dict) -> str | None:
    for key in ("ISO_A2", "ISO_A2_EH"):
        value = props.get(key)
        if value and value != "-99":
            return value
    return None


def epsilon_for_bbox(bbox: tuple[float, float, float, float]) -> float:
    """Bigger countries tolerate coarser simplification; keeps every file a
    similar order of magnitude in size regardless of country extent."""
    min_lon, min_lat, max_lon, max_lat = bbox
    diagonal = math.hypot(max_lon - min_lon, max_lat - min_lat)
    return max(0.004, diagonal * 0.0015)


def build(input_path: str, out_dir: str, min_area_ratio: float) -> None:
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    groups: dict[str, dict] = {}
    skipped: list[str] = []

    for feature in data["features"]:
        props = feature.get("properties", {})
        iso = resolve_iso2(props)
        if iso is None:
            skipped.append(props.get("ADMIN") or props.get("NAME") or "?")
            continue
        name = props.get("NAME_EN") or props.get("NAME") or props.get("ADMIN") or iso
        group = groups.setdefault(iso, {"name": name, "rings": []})
        group["rings"].extend(exterior_rings_of(feature["geometry"]))

    os.makedirs(out_dir, exist_ok=True)
    index: dict[str, list[float]] = {}
    total_bytes = 0

    for iso, group in sorted(groups.items()):
        rings = [r for r in group["rings"] if len(r) >= 3]
        if not rings:
            continue
        areas = [shoelace_area(r) for r in rings]
        max_area = max(areas)
        kept = [
            r for r, a in zip(rings, areas) if max_area == 0 or a >= max_area * min_area_ratio
        ]

        bbox = union_bbox(ring_bbox(r) for r in kept)
        eps = epsilon_for_bbox(bbox)
        simplified = [douglas_peucker(r, eps) for r in kept]
        # Round to 5 decimal places (~1.1m precision) -- plenty for a tiny
        # map sticker and keeps the JSON text compact.
        rounded = [[[round(lon, 5), round(lat, 5)] for lon, lat in r] for r in simplified]

        payload = {
            "iso": iso,
            "name": group["name"],
            "bbox": [round(v, 5) for v in bbox],
            "rings": rounded,
        }
        out_path = os.path.join(out_dir, f"{iso}.json")
        text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
        total_bytes += len(text.encode("utf-8"))
        index[iso] = payload["bbox"]

    index_path = os.path.join(out_dir, "_index.json")
    index_text = json.dumps(index, separators=(",", ":"), sort_keys=True)
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(index_text)
    total_bytes += len(index_text.encode("utf-8"))

    print(f"Wrote {len(index)} countries to {out_dir}")
    print(f"Total size: {total_bytes / 1024:.1f} KB (incl. _index.json)")
    if skipped:
        print(f"Skipped {len(skipped)} features with no usable ISO2 code: {skipped}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Path to ne_50m_admin_0_countries.geojson")
    parser.add_argument("--out", default="assets/countries", help="Output directory")
    parser.add_argument(
        "--min-area-ratio",
        type=float,
        default=0.01,
        help="Drop rings smaller than this fraction of the country's largest ring",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    build(args.input, args.out, args.min_area_ratio)


if __name__ == "__main__":
    main()
