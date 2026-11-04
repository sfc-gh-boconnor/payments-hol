"""One-off ORS precompute for DA3 (run against an account with OpenRouteService installed).

For every branch in BARCLAYS_HOL.RETAIL.BRANCHES this computes, with the ORS app's MATRIX and
ISOCHRONES functions:
  * drive and walk time/distance from every branch in a city to every H3 res-8 cell around it
  * 10 and 20 minute drive and 15 minute walk isochrone polygons per branch
and writes them as seed files under data/retail/, so event accounts never need ORS.

Usage: python3 setup/tools/ors_precompute.py <snow-connection>
"""
import csv, gzip, json, os, subprocess, sys, time

CONN = sys.argv[1] if len(sys.argv) > 1 else "lkrtfh"
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "retail")
# lab city -> ORS region provisioned for it
REGION = {"London": "London", "Manchester": "Manchester", "Birmingham": "Birmingham", "Leeds": "Leeds",
          "Glasgow": "Glasgow", "Edinburgh": "Edinburgh", "Bristol": "Bristol", "Cardiff": "Cardiff"}
# map extract bounds per region (min_lat, max_lat, min_lon, max_lon): ORS rejects points outside them
BOUNDS = {"London": (51.28, 51.7, -0.6, 0.42), "Manchester": (53.31, 53.65, -2.52, -1.79),
          "Birmingham": (52.38, 52.63, -2.2, -1.7), "Leeds": (53.65, 53.88, -1.89, -1.28),
          "Glasgow": (55.75, 55.96, -4.53, -3.86), "Edinburgh": (55.7, 56.1, -3.58, -2.77),
          "Bristol": (51.34, 51.59, -2.93, -2.27), "Cardiff": (51.04, 53.766, -6.183, -2.648)}
MARGIN = 0.01        # keep cells this far (degrees) inside the extract edge
PROFILES = ["driving-car", "foot-walking"]
CHUNK = 900          # destinations per MATRIX call
DISK_K = 20          # H3 res-8 rings around each branch (~9 km)
ISOS = [("driving-car", 10), ("driving-car", 20), ("foot-walking", 15)]


def q(sql):
    """Run one statement with snow sql and return the rows as lists."""
    out = subprocess.run(["snow", "sql", "-c", CONN, "--format", "json", "-q", "USE WAREHOUSE DEFAULT_WH; " + sql],
                         capture_output=True, text=True, check=True).stdout
    res = json.loads(out[out.index("["):])
    return [list(r.values()) for r in res[-1]]


def ors_call(sql, ok, label, tries=8):
    """Retry while the gateway is busy (service_unreachable); return other ORS errors to the caller."""
    for attempt in range(tries):
        (r,) = q(sql)[0]
        r = json.loads(r) if isinstance(r, str) else r
        if ok(r) or "service_unreachable" not in json.dumps(r):
            return r
        time.sleep(15 * (attempt + 1))
    raise SystemExit(f"{label}: {str(r)[:300]}")


def matrix(bs, chunk, profile, region, label):
    """Travel times from branches bs to cells chunk. Cells ORS can't route to (water, no road
    nearby) fail the whole request, so split the chunk until they are isolated and skipped."""
    locs = [[float(b[2]), float(b[3])] for b in bs] + [[float(c[1]), float(c[2])] for c in chunk]
    body = {"locations": locs, "metrics": ["duration", "distance"],
            "sources": list(range(len(bs))), "destinations": list(range(len(bs), len(locs)))}
    m = ors_call(f"SELECT OPENROUTESERVICE_APP.CORE.MATRIX('{profile}', PARSE_JSON($${json.dumps(body)}$$), '{region}')",
                 lambda r: "durations" in r, label)
    if "durations" in m:
        return [(b[0], c[0], m["durations"][bi][ci], m["distances"][bi][ci])
                for bi, b in enumerate(bs) for ci, c in enumerate(chunk)]
    if len(chunk) == 1:
        print("skipped unroutable cell", label, chunk[0][0], flush=True)
        return []
    half = len(chunk) // 2
    return matrix(bs, chunk[:half], profile, region, label) + matrix(bs, chunk[half:], profile, region, label)


os.makedirs(OUT, exist_ok=True)
branches = q("SELECT BRANCH_ID, CITY, LON, LAT FROM BARCLAYS_HOL.RETAIL.BRANCHES ORDER BY CITY, BRANCH_ID")

# H3 cells within DISK_K rings of any branch in the city, with the cell centre
cells = {}
for city in REGION:
    cells[city] = q(f"""
        SELECT DISTINCT c.value::STRING AS CELL,
               ST_X(H3_CELL_TO_POINT(c.value::STRING)) AS LON, ST_Y(H3_CELL_TO_POINT(c.value::STRING)) AS LAT
        FROM BARCLAYS_HOL.RETAIL.BRANCHES b,
             LATERAL FLATTEN(H3_GRID_DISK(H3_LATLNG_TO_CELL_STRING(b.LAT, b.LON, 8), {DISK_K})) c
        WHERE b.CITY = '{city}'""")
    lo_lat, hi_lat, lo_lon, hi_lon = BOUNDS[city]
    cells[city] = [c for c in cells[city]
                   if lo_lat + MARGIN < float(c[2]) < hi_lat - MARGIN and lo_lon + MARGIN < float(c[1]) < hi_lon - MARGIN]
    print(city, len(cells[city]), "cells", flush=True)

# One part file per city and profile, so an interrupted run resumes where it stopped
PARTS = os.path.join(OUT, "parts")
os.makedirs(PARTS, exist_ok=True)
for city, region in REGION.items():
    bs = [b for b in branches if b[1] == city]
    unroutable = set()
    for profile in PROFILES:
        part = os.path.join(PARTS, f"{city}_{profile}.csv")
        # cells the car can't reach (sea, no roads) aren't walkable either
        cs = [c for c in cells[city] if c[0] not in unroutable]
        if not os.path.exists(part):
            rows = []
            for i in range(0, len(cs), CHUNK):
                rows += matrix(bs, cs[i:i + CHUNK], profile, region, f"{city} {profile}")
            with open(part + ".tmp", "w", newline="") as f:
                csv.writer(f).writerows([r[0], r[1], profile, round(r[2]), round(r[3])] for r in rows if r[2] is not None)
            os.rename(part + ".tmp", part)
        with open(part) as f:
            routed = {r[1] for r in csv.reader(f)}
        unroutable |= {c[0] for c in cs if c[0] not in routed}
        print(city, profile, "done", flush=True)

with gzip.open(os.path.join(OUT, "branch_cell_travel.csv.gz"), "wt", newline="") as f:
    w = csv.writer(f)
    w.writerow(["BRANCH_ID", "H3_CELL", "PROFILE", "DURATION_S", "DISTANCE_M"])
    for city in REGION:
        for profile in PROFILES:
            with open(os.path.join(PARTS, f"{city}_{profile}.csv")) as pf:
                w.writerows(csv.reader(pf))

with gzip.open(os.path.join(OUT, "branch_isochrones.csv.gz"), "wt", newline="") as f:
    w = csv.writer(f)
    w.writerow(["BRANCH_ID", "PROFILE", "MINUTES", "GEOJSON"])
    for b in branches:
        for profile, minutes in ISOS:
            geo = None
            for attempt in range(8):
                rows = q(f"""SELECT ST_ASGEOJSON(GEOJSON)::STRING FROM TABLE(OPENROUTESERVICE_APP.CORE.ISOCHRONES(
                             '{profile}', {float(b[2])}::FLOAT, {float(b[3])}::FLOAT, {minutes}, '{REGION[b[1]]}'))""")
                if rows and rows[0][0]:
                    geo = rows[0][0]
                    break
                time.sleep(15 * (attempt + 1))
            if not geo:
                raise SystemExit(f"no isochrone {b[0]} {profile} {minutes}")
            w.writerow([b[0], profile, minutes, geo])
print("written to", os.path.abspath(OUT))
