#!/usr/bin/env python3
"""Build the synthetic retail banking data product (RB_* tables) from Open Government Licence data.

Run once, offline, by the lab team. Attendees never run this: provisioning loads the gzipped CSVs it
writes to data/retail_bank/. Real geography, synthetic people:

- homes are real OS Open UPRN property points, sampled inside the existing DA3 drive-time footprint
  (the H3 res-8 cells in data/retail/branch_cell_travel.csv.gz), so every customer has a drive time
  to their branch;
- each home gets its real postcode, LSOA and deprivation rank (ONS NSPL) and the nearest real street
  name (OS Open Names); the house number and the person are synthetic;
- each person is drawn from the Census 2021 mix of their own LSOA (age, tenure, household, economic
  activity, NS-SeC), so demographics and deprivation agree with real geography;
- products, transactions and monthly snapshots are generated from the profile, with attrition,
  profitability, seasonality and fraud signals planted for ML (documented in data/retail_bank/README.md).

Stages are cached in the work directory, so a rerun only redoes what changed:
  python setup/tools/build_retail_bank.py prep       # filter the open data to the footprint
  python setup/tools/build_retail_bank.py generate   # write data/retail_bank/*.csv.gz
  python setup/tools/build_retail_bank.py validate   # distribution, integrity, signal and size checks

Needs: pandas, numpy, h3, scikit-learn (see the venv note in data/retail_bank/README.md).
Source downloads (not committed) go in RB_SOURCES, default ~/data_sources/ogl; see data/retail_bank/README.md.
"""
import os
import sys
import zipfile
from pathlib import Path

import h3
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SOURCES = Path(os.environ.get("RB_SOURCES", Path.home() / "data_sources/ogl"))
WORK = SOURCES / "work"
OUT = ROOT / "data/retail_bank"
SEED = 20261120
H3_RES = 8

# Same city weights as the DA3 customers (setup/07_retail_geo_seed.sql)
CITY_SHARE = {"London": 0.24, "Manchester": 0.13, "Birmingham": 0.13, "Leeds": 0.10,
              "Glasgow": 0.10, "Bristol": 0.10, "Cardiff": 0.10, "Edinburgh": 0.10}
N_CUSTOMERS = 20_000


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------- prep

def footprint():
    """H3 cells with a drive time, with their nearest branch by drive time."""
    path = WORK / "footprint.parquet"
    if path.exists():
        return pd.read_parquet(path)
    t = pd.read_csv(ROOT / "data/retail/branch_cell_travel.csv.gz")
    t = t[t.PROFILE == "driving-car"].sort_values("DURATION_S")
    fp = t.drop_duplicates("H3_CELL")[["H3_CELL", "BRANCH_ID", "DURATION_S", "DISTANCE_M"]]
    br = pd.read_csv(WORK / "branches.csv")
    fp = fp.merge(br[["BRANCH_ID", "CITY"]], on="BRANCH_ID")
    fp.to_parquet(path)
    log(f"footprint: {len(fp):,} cells")
    return fp


def uprns(fp):
    """OS Open UPRN points inside the footprint cells."""
    path = WORK / "uprn_footprint.parquet"
    if path.exists():
        return pd.read_parquet(path)
    cells = set(fp.H3_CELL)
    # one box per city: a single box from Cardiff to Edinburgh would cover most of GB
    pts = pd.DataFrame([(c, *h3.cell_to_latlng(c)) for c in cells], columns=["H3_CELL", "lat", "lon"]).merge(fp[["H3_CELL", "CITY"]])
    boxes = pts.groupby("CITY").agg(a=("lat", "min"), b=("lat", "max"), c=("lon", "min"), d=("lon", "max"))
    z = zipfile.ZipFile(SOURCES / "open_uprn.zip")
    name = next(n for n in z.namelist() if n.lower().endswith(".csv"))
    keep = []
    with z.open(name) as f:
        for i, ch in enumerate(pd.read_csv(f, chunksize=2_000_000, usecols=["UPRN", "LATITUDE", "LONGITUDE"])):
            inbox = np.zeros(len(ch), bool)
            for _, r in boxes.iterrows():
                inbox |= (ch.LATITUDE.between(r.a - 0.005, r.b + 0.005) & ch.LONGITUDE.between(r.c - 0.008, r.d + 0.008)).to_numpy()
            ch = ch[inbox]
            if len(ch):
                ch = ch.assign(H3_CELL=[h3.latlng_to_cell(a, b, H3_RES) for a, b in zip(ch.LATITUDE, ch.LONGITUDE)])
                keep.append(ch[ch.H3_CELL.isin(cells)])
            log(f"  uprn chunk {i}: kept {sum(map(len, keep)):,}")
    u = pd.concat(keep, ignore_index=True)
    u.to_parquet(path)
    log(f"uprns in footprint: {len(u):,}")
    return u


def postcodes(fp):
    """Live residential (small-user) postcodes in the footprint, with LSOA, LA, deprivation and OAC."""
    path = WORK / "postcodes.parquet"
    if path.exists():
        return pd.read_parquet(path)
    cells = set(fp.H3_CELL)
    z = zipfile.ZipFile(SOURCES / "nspl.zip")
    cols = ["pcds", "doterm", "usrtypind", "lsoa21cd", "msoa21cd", "lad26cd", "ctry26cd", "oac21ind", "lat", "long", "imd25ind"]
    parts = []
    for n in z.namelist():
        if "/multi_csv/" in n and n.endswith(".csv"):
            d = pd.read_csv(z.open(n), usecols=cols, dtype=str)
            d = d[d.doterm.isna() & (d.usrtypind == "0") & d.lat.notna()]
            d["lat"], d["long"] = d.lat.astype(float), d.long.astype(float)
            d = d[d.lat < 90]  # 99.999999 marks postcodes with no grid reference
            d["H3_CELL"] = [h3.latlng_to_cell(a, b, H3_RES) for a, b in zip(d.lat, d.long)]
            parts.append(d[d.H3_CELL.isin(cells)])
    pc = pd.concat(parts, ignore_index=True).drop(columns=["doterm", "usrtypind"])
    pc["imd25ind"] = pd.to_numeric(pc.imd25ind, errors="coerce")
    # Deprivation decile within each nation's own index (IMD 2025 England, WIMD Wales):
    # NSPL gives the rank; the number of areas comes from the lookups shipped with NSPL
    n_areas = {"E92000001": 33755, "W92000004": 1917}
    pc["IMD_DECILE"] = np.ceil(pc.imd25ind / pc.ctry26cd.map(n_areas) * 10).clip(1, 10).astype("Int64")
    # NSPL has no deprivation rank for Scotland (the field is 0), so take SIMD 2020v2 by postcode
    # from the Scottish Government's postcode lookup
    simd = pd.read_excel(SOURCES / "simd2020_postcodes.xlsx", sheet_name="All postcodes", usecols=["Postcode", "SIMD2020_Decile"])
    simd = simd.set_index(simd.Postcode.str.replace(" ", "")).SIMD2020_Decile
    scot = pc.ctry26cd == "S92000003"
    pc.loc[scot, "IMD_DECILE"] = pc.loc[scot, "pcds"].str.replace(" ", "").map(simd).astype("Int64")
    pc = pc[pc.IMD_DECILE.notna()]
    pc.to_parquet(path)
    log(f"residential postcodes in footprint: {len(pc):,}")
    return pc


def streets():
    """OS Open Names named roads, as lat/lon points, for the footprint cities."""
    path = WORK / "streets.parquet"
    if path.exists():
        return pd.read_parquet(path)
    from pyproj import Transformer
    to_wgs = Transformer.from_crs("EPSG:27700", "EPSG:4326", always_xy=True)
    z = zipfile.ZipFile(SOURCES / "open_names.zip")
    header = pd.read_csv(z.open("Doc/OS_Open_Names_Header.csv")).columns.tolist()
    parts = []
    for n in z.namelist():
        if n.startswith("Data/") and n.endswith(".csv"):
            d = pd.read_csv(z.open(n), header=None, names=header, usecols=["NAME1", "LOCAL_TYPE", "GEOMETRY_X", "GEOMETRY_Y", "POSTCODE_DISTRICT"], dtype={"NAME1": str})
            parts.append(d[d.LOCAL_TYPE == "Named Road"])
    s = pd.concat(parts, ignore_index=True)
    s["lon"], s["lat"] = to_wgs.transform(s.GEOMETRY_X.to_numpy(), s.GEOMETRY_Y.to_numpy())
    s = s[["NAME1", "POSTCODE_DISTRICT", "lat", "lon"]].rename(columns={"NAME1": "STREET"})
    s.to_parquet(path)
    log(f"named roads: {len(s):,}")
    return s


# Census 2021 (England and Wales) on Nomis, by LSOA 2021. Each entry: dataset id, the category
# dimension and how its categories map to the bands used in RB_CUSTOMERS.
CENSUS = {
    "age": ("NM_2020_1", "c2021_age_19"),            # TS007A age by five-year bands
    "tenure": ("NM_2072_1", "c2021_tenure_9"),       # TS054 tenure
    "household": ("NM_2023_1", "c2021_hhcomp_15"),   # TS003 household composition
    "econ": ("NM_2083_1", "c2021_eastat_20"),        # TS066 economic activity status
    "nssec": ("NM_2079_1", "c2021_nssec_10"),        # TS062 NS-SeC
}


def census(pc):
    """Census 2021 counts per LSOA for every English and Welsh LSOA in the footprint, from Nomis."""
    import io
    import urllib.error
    import urllib.request
    out = {}
    lads = sorted(pc.loc[pc.ctry26cd != "S92000003", "lad26cd"].unique())
    lsoas = set(pc.lsoa21cd)
    for key, (ds, dim) in CENSUS.items():
        path = WORK / f"census_{key}.parquet"
        if path.exists():
            out[key] = pd.read_parquet(path)
            continue
        frames = []
        def fetch(geo):
            rows, offset = [], 0
            while True:  # Nomis returns at most 25,000 rows per call, so page with recordoffset
                url = (f"https://www.nomisweb.co.uk/api/v01/dataset/{ds}.data.csv?date=latest&geography={geo}"
                       f"&measures=20100&select=geography_code,{dim}_code,{dim}_name,obs_value&recordoffset={offset}")
                with urllib.request.urlopen(url, timeout=300) as r:
                    body = r.read()
                if not body.strip():
                    break
                page = pd.read_csv(io.BytesIO(body))
                rows.append(page)
                if len(page) < 25_000:
                    break
                offset += 25_000
            return rows

        for lad in lads:
            try:
                frames += fetch(f"{lad}TYPE151")
            except urllib.error.HTTPError:
                # a 2026 LA code Nomis's 2021 geography doesn't know: ask for its LSOAs directly
                codes = sorted(pc.loc[pc.lad26cd == lad, "lsoa21cd"].unique())
                for i in range(0, len(codes), 100):
                    frames += fetch(",".join(codes[i:i + 100]))
        d = pd.concat(frames, ignore_index=True)
        d.columns = ["LSOA", "CODE", "CATEGORY", "N"]
        d = d[d.LSOA.isin(lsoas) & (d.CODE.astype(str) != "0")]  # code 0 is the total
        d.to_parquet(path)
        out[key] = d
        log(f"census {key}: {d.LSOA.nunique():,} LSOAs, {d.CATEGORY.nunique()} categories")
    return out


# ---------------------------------------------------------------- generate

AS_OF = pd.Timestamp("2026-11-20")
MONTHS = pd.period_range("2025-12", "2026-11", freq="M")  # 12 monthly snapshots
LEDGER_DAYS = 90                                            # transaction ledger window, every active customer
SEASON = dict(zip(range(1, 13), [0.86, 0.90, 0.95, 1.00, 1.00, 1.04, 1.08, 1.10, 0.96, 1.00, 1.06, 1.28]))
CLOSURE_CANDIDATES = {"BR-MAN-90", "BR-LDS-90", "BR-CDF-90"}  # the DA3 closure story

ADULT_AGE = {  # census 5-year band -> (low, high) of the adult age range it contributes
    "Aged 15 to 19 years": (18, 19), "Aged 20 to 24 years": (20, 24), "Aged 25 to 29 years": (25, 29),
    "Aged 30 to 34 years": (30, 34), "Aged 35 to 39 years": (35, 39), "Aged 40 to 44 years": (40, 44),
    "Aged 45 to 49 years": (45, 49), "Aged 50 to 54 years": (50, 54), "Aged 55 to 59 years": (55, 59),
    "Aged 60 to 64 years": (60, 64), "Aged 65 to 69 years": (65, 69), "Aged 70 to 74 years": (70, 74),
    "Aged 75 to 79 years": (75, 79), "Aged 80 to 84 years": (80, 84), "Aged 85 years and over": (85, 94),
}
TENURE = {"_0": "OWNS_OUTRIGHT", "_1": "MORTGAGE", "_2": "SHARED_OWNERSHIP", "_3": "SOCIAL_RENT",
          "_4": "SOCIAL_RENT", "_5": "PRIVATE_RENT", "_6": "PRIVATE_RENT", "_7": "RENT_FREE"}
HOUSEHOLD = {"_1": "SINGLE_66_PLUS", "_2": "SINGLE", "_3": "COUPLE_66_PLUS", "_4": "COUPLE_NO_CHILDREN",
             "_5": "COUPLE_WITH_CHILDREN", "_6": "COUPLE_ADULT_CHILDREN", "_7": "COUPLE_NO_CHILDREN",
             "_8": "COUPLE_WITH_CHILDREN", "_9": "COUPLE_ADULT_CHILDREN", "_10": "LONE_PARENT",
             "_11": "LONE_PARENT_ADULT_CHILDREN", "_12": "OTHER_FAMILY", "_13": "SHARED_WITH_CHILDREN",
             "_14": "SHARED_OR_STUDENTS"}
ECON = {"_1": "EMPLOYED_PART_TIME", "_2": "EMPLOYED_FULL_TIME", "_3": "SELF_EMPLOYED", "_4": "SELF_EMPLOYED",
        "_5": "SELF_EMPLOYED", "_6": "SELF_EMPLOYED", "_7": "UNEMPLOYED", "_8": "STUDENT", "_9": "STUDENT",
        "_10": "STUDENT", "_11": "STUDENT", "_12": "STUDENT", "_13": "STUDENT", "_14": "STUDENT",
        "_15": "RETIRED", "_16": "STUDENT", "_17": "LOOKING_AFTER_HOME", "_18": "LONG_TERM_SICK", "_19": "OTHER_INACTIVE"}
NSSEC = {"_1": "HIGHER_PROFESSIONAL", "_2": "LOWER_PROFESSIONAL", "_3": "INTERMEDIATE", "_4": "SMALL_EMPLOYER",
         "_5": "LOWER_SUPERVISORY", "_6": "SEMI_ROUTINE", "_7": "ROUTINE", "_8": "NEVER_WORKED", "_9": "STUDENT"}
# Gross annual personal income, GBP thousands, (median, spread) by NS-SeC class
INCOME = {"HIGHER_PROFESSIONAL": (62, 0.45), "LOWER_PROFESSIONAL": (41, 0.40), "INTERMEDIATE": (29, 0.35),
          "SMALL_EMPLOYER": (31, 0.70), "LOWER_SUPERVISORY": (30, 0.35), "SEMI_ROUTINE": (21, 0.40),
          "ROUTINE": (22, 0.40), "NEVER_WORKED": (11, 0.50), "STUDENT": (9, 0.60)}


def dists(census):
    """Per-LSOA category probabilities for each census table, in our band names."""
    maps = {"tenure": TENURE, "household": HOUSEHOLD, "econ": ECON, "nssec": NSSEC}
    out = {}
    for key, d in census.items():
        d = d[d.CODE.astype(str).str.startswith("_")].copy()  # leaf categories only
        d["N"] = d.N.astype(float)
        if key == "age":
            d = d[d.CATEGORY.isin(ADULT_AGE)]
            d.loc[d.CATEGORY == "Aged 15 to 19 years", "N"] *= 0.4  # only 18 and 19 are adults
            d["BAND"] = d.CATEGORY
        else:
            d["BAND"] = d.CODE.astype(str).map(maps[key])
        p = d.groupby(["LSOA", "BAND"]).N.sum().unstack(fill_value=0)
        out[key] = p.div(p.sum(axis=1), axis=0)
    return out


def scottish_fallback(dist, pc):
    """Scotland's data zones aren't on Nomis: use the England and Wales mix for the same deprivation decile."""
    ew = pc[pc.ctry26cd != "S92000003"].drop_duplicates("lsoa21cd").set_index("lsoa21cd").IMD_DECILE
    by_decile = {k: v.join(ew).groupby("IMD_DECILE").mean() for k, v in dist.items()}
    return by_decile


def draw(rng, probs, cols, compat=None):
    """One category per row from a row-wise probability matrix, optionally reweighted by a compatibility matrix."""
    p = probs.copy()
    if compat is not None:
        p = p * compat
    p = p / p.sum(axis=1, keepdims=True)
    u = rng.random((len(p), 1))
    idx = (p.cumsum(axis=1) < u).sum(axis=1).clip(0, len(cols) - 1)
    return np.asarray(cols)[idx]


def customers(rng, fp, uprn, pc, streets_df, census):
    """RB_CUSTOMERS: real places, synthetic people drawn from their own LSOA's census mix."""
    from faker import Faker
    from sklearn.neighbors import KDTree
    fake = Faker("en_GB")
    Faker.seed(SEED)

    pc = pc.merge(fp[["H3_CELL", "BRANCH_ID", "DURATION_S", "CITY"]], on="H3_CELL")
    # Sample residential postcodes per city, favouring those closer to a branch (banks recruit locally)
    picks = []
    for city, share in CITY_SHARE.items():
        c = pc[pc.CITY == city]
        w = np.exp(-c.DURATION_S.to_numpy() / 2400.0)  # mild pull towards branches, keeps the area's real deprivation mix
        picks.append(c.sample(n=round(N_CUSTOMERS * share), weights=w, replace=True, random_state=rng.integers(1e9)))
    cu = pd.concat(picks, ignore_index=True)
    n = len(cu)

    # Home: a real UPRN point near the postcode centroid, in the same H3 cell
    u = uprn[uprn.H3_CELL.isin(set(cu.H3_CELL))].reset_index(drop=True)
    tree = KDTree(np.c_[u.LATITUDE, u.LONGITUDE * np.cos(np.radians(53))])
    _, nn = tree.query(np.c_[cu.lat, cu.long * np.cos(np.radians(53))], k=8)
    choice = nn[np.arange(n), rng.integers(0, 8, n)]
    cu["UPRN"], cu["HOME_LAT"], cu["HOME_LON"] = u.UPRN.to_numpy()[choice], u.LATITUDE.to_numpy()[choice], u.LONGITUDE.to_numpy()[choice]
    cu["HOME_H3_CELL"] = [h3.latlng_to_cell(a, b, H3_RES) for a, b in zip(cu.HOME_LAT, cu.HOME_LON)]
    # Don't pin a synthetic person to a real household: publish the location to ~100 m, not the property
    cu["HOME_LAT"], cu["HOME_LON"] = cu.HOME_LAT.round(3), cu.HOME_LON.round(3)

    # Street: the nearest real named road; house number synthetic
    st = streets_df[streets_df.lat.between(cu.HOME_LAT.min() - 0.05, cu.HOME_LAT.max() + 0.05)].reset_index(drop=True)
    stree = KDTree(np.c_[st.lat, st.lon * np.cos(np.radians(53))])
    _, sn = stree.query(np.c_[cu.HOME_LAT, cu.HOME_LON * np.cos(np.radians(53))], k=1)
    cu["STREET"] = st.STREET.to_numpy()[sn[:, 0]]

    # Demographics from the customer's own LSOA (Scotland: same-decile England and Wales mix)
    dist = dists(census)
    scot = scottish_fallback(dist, pc)
    is_scot = (cu.ctry26cd == "S92000003").to_numpy()

    def lsoa_probs(key):
        cols = dist[key].columns
        p = dist[key].reindex(cu.lsoa21cd).to_numpy().copy()
        sp = scot[key].reindex(cu.IMD_DECILE.astype(int)).reindex(columns=cols).to_numpy()
        p[is_scot] = sp[is_scot]
        missing = np.isnan(p).any(axis=1)
        p[missing] = np.nanmean(dist[key].to_numpy(), axis=0)
        return p, cols

    p, cols = lsoa_probs("age")
    band = draw(rng, p, cols)
    lo = np.array([ADULT_AGE[b][0] for b in band]); hi = np.array([ADULT_AGE[b][1] for b in band])
    age = rng.integers(lo, hi + 1)
    cu["AGE"] = age

    def compat_matrix(cols, rule):
        return np.array([[rule(a, c) for c in cols] for a in age], dtype=float)

    p, cols = lsoa_probs("econ")
    cu["EMPLOYMENT_STATUS"] = draw(rng, p, cols, compat_matrix(cols, lambda a, c:
        (a >= 58) * 1.0 if c == "RETIRED" else (0.05 if a >= 67 else 1.0) if c.startswith(("EMPLOYED", "SELF")) else
        (1.0 if a <= 30 else 0.03) if c == "STUDENT" else 1.0))
    p, cols = lsoa_probs("household")
    cu["HOUSEHOLD_TYPE"] = draw(rng, p, cols, compat_matrix(cols, lambda a, c:
        (1.0 if a >= 66 else 0.0) if "66_PLUS" in c else (0.15 if a >= 66 else 1.0) if c in ("SINGLE",) else
        (1.0 if 22 <= a <= 60 else 0.1) if "WITH_CHILDREN" in c or c == "LONE_PARENT" else 1.0))
    p, cols = lsoa_probs("tenure")
    cu["HOUSING_TENURE"] = draw(rng, p, cols, compat_matrix(cols, lambda a, c:
        (np.clip((a - 35) / 25, 0.03, 1.6)) if c == "OWNS_OUTRIGHT" else (1.0 if 25 <= a <= 64 else 0.15) if c == "MORTGAGE" else 1.0))
    p, cols = lsoa_probs("nssec")
    occ = draw(rng, p, cols)
    occ = np.where(cu.EMPLOYMENT_STATUS == "STUDENT", "STUDENT", occ)
    cu["OCCUPATION_CLASS"] = occ

    # Income from occupation class, scaled down for part-time, unemployed and retired
    med = np.array([INCOME[o][0] for o in occ]); spread = np.array([INCOME[o][1] for o in occ])
    inc = med * np.exp(rng.normal(0, spread))
    emp = cu.EMPLOYMENT_STATUS.to_numpy()
    inc *= np.select([emp == "EMPLOYED_PART_TIME", np.isin(emp, ["UNEMPLOYED", "LONG_TERM_SICK", "LOOKING_AFTER_HOME", "OTHER_INACTIVE"]), emp == "RETIRED"], [0.5, 0.35, 0.55], 1.0)
    inc *= np.where(age < 25, 0.7, 1.0) * (1 + 0.03 * (cu.IMD_DECILE.to_numpy(float) - 5.5))  # affluent areas earn more
    cu["ANNUAL_INCOME_GBP"] = (np.round(inc * 1000, -2)).clip(3000, 450000)
    cu["INCOME_BAND"] = pd.cut(cu.ANNUAL_INCOME_GBP, [0, 15e3, 25e3, 40e3, 60e3, 100e3, 1e9],
                               labels=["UNDER_15K", "15K_25K", "25K_40K", "40K_60K", "60K_100K", "100K_PLUS"]).astype(str)

    # Identity: fake names and dates of birth; real postcode, synthetic house number
    sex = np.where(rng.random(n) < 0.515, "F", "M")
    cu["SEX"] = sex
    cu["FIRST_NAME"] = [fake.first_name_female() if s == "F" else fake.first_name_male() for s in sex]
    cu["LAST_NAME"] = [fake.last_name() for _ in range(n)]
    dob = AS_OF - pd.to_timedelta(age * 365.25 + rng.integers(0, 365, n), unit="D")
    cu["DATE_OF_BIRTH"] = dob.normalize()
    rent = np.isin(cu.HOUSING_TENURE, ["SOCIAL_RENT", "PRIVATE_RENT"])
    flat = np.where(rent & (rng.random(n) < np.where(cu.CITY == "London", 0.75, 0.45)), [f"Flat {k}, " for k in rng.integers(1, 40, n)], "")
    cu["ADDRESS_LINE_1"] = [f"{f}{k} {s}" for f, k, s in zip(flat, rng.integers(1, 180, n), cu.STREET)]
    cu["POSTCODE"] = cu.pcds

    # Banking relationship
    tenure_years = np.clip(rng.gamma(1.6, 4.5, n) * np.clip(age / 45, 0.3, 1.6), 0.1, age - 16)
    cu["CUSTOMER_SINCE"] = (AS_OF - pd.to_timedelta(tenure_years * 365.25, unit="D")).normalize()
    z = -1.75 + 0.065 * (age - 40) - 0.17 * (cu.IMD_DECILE.to_numpy(float) - 5.5) + 0.6 * (cu.EMPLOYMENT_STATUS == "RETIRED")  # logit of NOT digital
    cu["DIGITAL_ACTIVE"] = rng.random(n) > 1 / (1 + np.exp(-z))
    cu["PREFERRED_CHANNEL"] = np.where(cu.DIGITAL_ACTIVE, np.where(rng.random(n) < 0.8, "APP", "ONLINE"),
                                       np.where(rng.random(n) < 0.65, "BRANCH", "PHONE"))
    cu["HOME_BRANCH_ID"], cu["HOME_BRANCH_DRIVE_S"] = cu.BRANCH_ID, cu.DURATION_S
    score = 640 + 2.2 * (age - 40).clip(-20, 30) + 9 * (cu.IMD_DECILE.to_numpy(float) - 5.5) + 0.9 * (cu.ANNUAL_INCOME_GBP / 1000).clip(0, 120) + rng.normal(0, 55, n)
    score -= 60 * np.isin(emp, ["UNEMPLOYED", "LONG_TERM_SICK"])
    cu["CREDIT_SCORE"] = np.round(score).clip(300, 999).astype(int)
    cu["CREDIT_BAND"] = pd.cut(cu.CREDIT_SCORE, [0, 560, 720, 880, 960, 1000], labels=["VERY_POOR", "POOR", "FAIR", "GOOD", "EXCELLENT"]).astype(str)
    cu["VULNERABLE_FLAG"] = (age >= 75) | (emp == "LONG_TERM_SICK") | ((cu.ANNUAL_INCOME_GBP < 12000) & (cu.HOUSEHOLD_TYPE == "LONE_PARENT")) | (rng.random(n) < 0.03)
    cu["MARKETING_CONSENT"] = rng.random(n) < 0.62
    cu["ACQUISITION_CHANNEL"] = np.where(tenure_years > 12, "BRANCH", rng.choice(["BRANCH", "ONLINE", "APP", "SWITCH_SERVICE", "PARTNER"], n, p=[0.25, 0.3, 0.25, 0.15, 0.05]))
    cu["SEGMENT"] = np.select([age < 25, cu.ANNUAL_INCOME_GBP >= 100e3, cu.ANNUAL_INCOME_GBP >= 50e3],
                              ["YOUNG_ADULT", "PREMIER", "MASS_AFFLUENT"], "MASS")
    cu["CUSTOMER_ID"] = [f"RB{100000 + i}" for i in range(n)]
    cu = cu.rename(columns={"lsoa21cd": "LSOA_CODE", "msoa21cd": "MSOA_CODE", "lad26cd": "LOCAL_AUTHORITY_CODE", "oac21ind": "AREA_CLASSIFICATION"})
    return cu


def accounts(rng, cu):
    """RB_ACCOUNTS: product holdings driven by life stage, income, tenure and credit."""
    n = len(cu)
    age, inc = cu.AGE.to_numpy(), cu.ANNUAL_INCOME_GBP.to_numpy()
    good = cu.CREDIT_SCORE.to_numpy() >= 720
    rows = []
    def add(mask, product, opened, balance, limit=None, rate=None):
        idx = np.flatnonzero(mask)
        for i in idx:
            rows.append((cu.CUSTOMER_ID.iat[i], product, opened[i], balance[i], None if limit is None else limit[i], None if rate is None else rate[i]))
    since = cu.CUSTOMER_SINCE.to_numpy()
    def opened_after(base, max_years):
        yrs = rng.random(n) * np.minimum(max_years, (AS_OF - pd.to_datetime(base)).days / 365.25)
        return (pd.to_datetime(base) + pd.to_timedelta(yrs * 365.25, unit="D")).normalize()
    monthly = inc / 12
    add(np.ones(n, bool), "CURRENT_ACCOUNT", pd.to_datetime(since).normalize(),
        np.round(monthly * rng.gamma(1.4, 0.45, n) - rng.random(n) * 300 * (inc < 20e3), 2), np.where(good, 1500, 500).astype(float), np.zeros(n))
    sav = rng.random(n) < np.clip(0.25 + inc / 150e3 + (age - 40) / 120, 0.1, 0.85)
    sav_bal = np.round(np.exp(rng.normal(np.log(np.clip(inc * 0.25 * (age / 40), 500, None)), 1.0)), 2)
    # Rate-sensitive savers: big balances on an old, low rate, the classic attrition risk
    sav_rate = np.where(rng.random(n) < 0.3, rng.uniform(0.5, 1.5, n), rng.uniform(3.0, 4.6, n))
    add(sav, "SAVINGS", opened_after(since, 15), sav_bal, None, np.round(sav_rate, 2))
    isa = rng.random(n) < np.clip(0.08 + inc / 200e3 + (age > 45) * 0.1, 0, 0.6)
    add(isa, "CASH_ISA", opened_after(since, 10), np.round(rng.uniform(1000, 20000, n) * np.clip(inc / 40e3, 0.3, 3), 2), None, np.round(rng.uniform(3.5, 4.8, n), 2))
    cc = good & (age >= 21) & (inc >= 10000) & (rng.random(n) < 0.55)  # catalogue rules: see PRODUCTS
    lim = np.round(np.clip(inc * rng.uniform(0.05, 0.25, n), 500, 25000), -2)
    add(cc, "CREDIT_CARD", opened_after(since, 12), np.round(lim * rng.beta(1.2, 3.5, n), 2), lim, np.full(n, 24.9))
    loan = (age.clip(21, 70) == age) & (rng.random(n) < 0.12) & (cu.CREDIT_SCORE.to_numpy() >= 560) & (inc >= 12000)
    add(loan, "PERSONAL_LOAN", opened_after(since, 5), np.round(rng.uniform(2000, 25000, n), 2), None, np.round(rng.uniform(6.5, 14.9, n), 2))
    mort = (cu.HOUSING_TENURE.to_numpy() == "MORTGAGE") & (rng.random(n) < 0.35)
    add(mort, "MORTGAGE", opened_after(since, 20), np.round(np.clip(inc * rng.uniform(2.0, 4.5, n), 40e3, 1.5e6), 2), None, np.round(rng.uniform(3.8, 5.6, n), 2))
    ac = pd.DataFrame(rows, columns=["CUSTOMER_ID", "PRODUCT", "OPENED_DATE", "BALANCE_GBP", "LIMIT_GBP", "INTEREST_RATE_PCT"])
    ac["ACCOUNT_ID"] = [f"RBA{1000000 + i}" for i in range(len(ac))]
    ac["STATUS"] = "OPEN"
    return ac


# Generic product catalogue (no real bank's product names). Rates and fees are plausible for late 2026.
# (id, name, family, tier, monthly fee, rate %, term months, min income, min score, min age, channels, launched, active, description)
PRODUCTS = [
    ("PRD-CA-EVD", "Everyday Current Account", "CURRENT_ACCOUNT", "STANDARD", 0, 0.0, None, 0, 0, 18, "ALL", "2015-03-01", True, "Free current account with arranged overdraft"),
    ("PRD-CA-PLS", "Plus Current Account", "CURRENT_ACCOUNT", "PLUS", 4.5, 0.0, None, 30000, 650, 18, "ALL", "2019-06-01", True, "Packaged account with travel and phone insurance"),
    ("PRD-CA-PRM", "Premier Current Account", "CURRENT_ACCOUNT", "PREMIER", 0, 0.0, None, 75000, 700, 18, "ALL", "2017-01-15", True, "Premier banking for higher earners"),
    ("PRD-CA-STU", "Student Account", "CURRENT_ACCOUNT", "STUDENT", 0, 0.0, None, 0, 0, 17, "DIGITAL", "2020-08-01", True, "Interest-free overdraft for students"),
    ("PRD-CA-YNG", "Young Adult Account", "CURRENT_ACCOUNT", "STANDARD", 0, 0.0, None, 0, 0, 18, "DIGITAL", "2021-02-01", True, "For 18 to 24 year olds, app only"),
    ("PRD-SV-EAS", "Easy Access Saver", "SAVINGS", "STANDARD", 0, 3.25, None, 0, 0, 16, "ALL", "2023-04-01", True, "Variable rate, unlimited withdrawals"),
    ("PRD-SV-RWD", "Rewards Saver", "SAVINGS", "PLUS", 0, 4.10, None, 0, 0, 18, "DIGITAL", "2024-09-01", True, "Higher variable rate with one free withdrawal a month"),
    ("PRD-SV-FX1", "1-Year Fixed Saver", "SAVINGS", "STANDARD", 0, 4.40, 12, 0, 0, 18, "ALL", "2025-01-01", True, "Fixed for 12 months, no withdrawals"),
    ("PRD-SV-FX2", "2-Year Fixed Saver", "SAVINGS", "STANDARD", 0, 4.20, 24, 0, 0, 18, "ALL", "2025-01-01", True, "Fixed for 24 months, no withdrawals"),
    ("PRD-SV-LGY", "Classic Saver (legacy)", "SAVINGS", "LEGACY", 0, 0.75, None, 0, 0, 16, "BRANCH", "2009-05-01", False, "Closed to new customers; legacy variable rate"),
    ("PRD-SV-BND", "Branch Bonus Saver (legacy)", "SAVINGS", "LEGACY", 0, 1.35, None, 0, 0, 16, "BRANCH", "2013-02-01", False, "Closed to new customers; bonus period ended"),
    ("PRD-IS-EAS", "Easy Access Cash ISA", "ISA", "STANDARD", 0, 3.95, None, 0, 0, 18, "ALL", "2022-04-06", True, "Tax-free, variable rate"),
    ("PRD-IS-FX1", "1-Year Fixed Cash ISA", "ISA", "STANDARD", 0, 4.35, 12, 0, 0, 18, "ALL", "2025-04-06", True, "Tax-free, fixed for 12 months"),
    ("PRD-CC-EVD", "Everyday Credit Card", "CREDIT_CARD", "STANDARD", 0, 24.9, None, 10000, 720, 21, "ALL", "2018-01-01", True, "Representative 24.9% APR variable"),
    ("PRD-CC-RWD", "Rewards Credit Card", "CREDIT_CARD", "PLUS", 0, 26.9, None, 25000, 800, 21, "ALL", "2021-05-01", True, "Cashback on spend, 26.9% APR"),
    ("PRD-CC-BTR", "Balance Transfer Card", "CREDIT_CARD", "STANDARD", 0, 24.9, None, 15000, 760, 21, "DIGITAL", "2022-03-01", True, "0% on balance transfers for 24 months"),
    ("PRD-LN-PER", "Personal Loan", "PERSONAL_LOAN", "STANDARD", 0, 9.9, 48, 12000, 560, 21, "ALL", "2016-01-01", True, "Fixed rate, 1 to 5 years, £1k to £35k"),
    ("PRD-LN-CAR", "Car Loan", "PERSONAL_LOAN", "STANDARD", 0, 8.4, 60, 15000, 620, 21, "ALL", "2019-01-01", True, "Fixed rate for a vehicle purchase"),
    ("PRD-MG-FX2", "2-Year Fixed Mortgage", "MORTGAGE", "STANDARD", 0, 4.29, 300, 25000, 600, 21, "ALL", "2024-01-01", True, "Fixed for 2 years, then standard variable"),
    ("PRD-MG-FX5", "5-Year Fixed Mortgage", "MORTGAGE", "STANDARD", 0, 4.49, 300, 25000, 600, 21, "ALL", "2024-01-01", True, "Fixed for 5 years, then standard variable"),
    ("PRD-MG-TRK", "Tracker Mortgage", "MORTGAGE", "STANDARD", 0, 4.94, 300, 25000, 600, 21, "ALL", "2022-01-01", True, "Base rate plus 0.94%"),
    ("PRD-MG-SVR", "Standard Variable Rate", "MORTGAGE", "STANDARD", 0, 7.24, 300, 0, 0, 21, "ALL", "2008-01-01", True, "What a mortgage reverts to when its fixed rate ends"),
    ("PRD-IN-HOM", "Home Insurance", "INSURANCE", "STANDARD", 24, None, 12, 0, 0, 18, "ALL", "2018-01-01", True, "Buildings and contents, monthly premium"),
    ("PRD-IN-TRV", "Annual Travel Insurance", "INSURANCE", "STANDARD", 7, None, 12, 0, 0, 18, "DIGITAL", "2019-01-01", True, "Worldwide annual multi-trip cover"),
    ("PRD-IN-LIF", "Life Insurance", "INSURANCE", "STANDARD", 18, None, 240, 0, 0, 18, "ALL", "2018-01-01", True, "Level term cover"),
]
PRODUCT_COLS = ["PRODUCT_ID", "PRODUCT_NAME", "PRODUCT_FAMILY", "TIER", "MONTHLY_FEE_GBP", "INTEREST_RATE_PCT", "TERM_MONTHS",
                "MIN_INCOME_GBP", "MIN_CREDIT_SCORE", "MIN_AGE", "CHANNEL_AVAILABILITY", "LAUNCH_DATE", "IS_ACTIVE", "DESCRIPTION"]


def annuity(principal, rate_pct, months):
    """Monthly repayment on an amortising loan."""
    r = np.asarray(rate_pct, float) / 100 / 12
    return np.where(r > 0, principal * r / (1 - (1 + r) ** -np.asarray(months, float)), principal / np.asarray(months, float))


def link_products(rng, cu, ac):
    """Give every account a catalogue PRODUCT_ID it is eligible for, plus terms, payments and maturities;
    add insurance policies. Rate-sensitive savers sit on closed legacy products."""
    p = pd.DataFrame(PRODUCTS, columns=PRODUCT_COLS).set_index("PRODUCT_ID")
    c = cu.set_index("CUSTOMER_ID").loc[ac.CUSTOMER_ID]
    age, inc, score, seg = c.AGE.to_numpy(), c.ANNUAL_INCOME_GBP.to_numpy(), c.CREDIT_SCORE.to_numpy(), c.SEGMENT.to_numpy()
    fam, n = ac.PRODUCT.to_numpy(), len(ac)
    pick = np.full(n, None, object)
    u = rng.random(n)
    student = c.EMPLOYMENT_STATUS.to_numpy() == "STUDENT"
    ca = fam == "CURRENT_ACCOUNT"
    pick[ca] = np.select([student[ca], (seg == "PREMIER")[ca], (age < 25)[ca], ((inc >= 30000) & (score >= 650) & (u < 0.25))[ca]],
                         ["PRD-CA-STU", "PRD-CA-PRM", "PRD-CA-YNG", "PRD-CA-PLS"], "PRD-CA-EVD")
    sv = fam == "SAVINGS"
    rate = ac.INTEREST_RATE_PCT.to_numpy(float)
    legacy = sv & (rate < 1.6)
    pick[legacy] = np.where(rate[legacy] < 1.0, "PRD-SV-LGY", "PRD-SV-BND")
    cur = sv & ~legacy
    pick[cur] = rng.choice(["PRD-SV-EAS", "PRD-SV-RWD", "PRD-SV-FX1", "PRD-SV-FX2"], cur.sum(), p=[0.45, 0.25, 0.2, 0.1])
    isa = fam == "CASH_ISA"
    pick[isa] = np.where(rng.random(isa.sum()) < 0.65, "PRD-IS-EAS", "PRD-IS-FX1")
    cc = fam == "CREDIT_CARD"
    pick[cc] = np.select([((inc >= 25000) & (score >= 800))[cc], ((score >= 760) & (rng.random(n) < 0.3))[cc]], ["PRD-CC-RWD", "PRD-CC-BTR"], "PRD-CC-EVD")
    ln = fam == "PERSONAL_LOAN"
    pick[ln] = np.where(((inc >= 15000) & (score >= 620) & (u < 0.35))[ln], "PRD-LN-CAR", "PRD-LN-PER")
    mg = fam == "MORTGAGE"
    opened = pd.to_datetime(ac.OPENED_DATE)
    yrs_on = ((AS_OF - opened).dt.days / 365.25).to_numpy()
    fixed = rng.choice(["PRD-MG-FX2", "PRD-MG-FX5", "PRD-MG-TRK"], n, p=[0.5, 0.38, 0.12])
    fix_len = np.where(fixed == "PRD-MG-FX2", 2, np.where(fixed == "PRD-MG-FX5", 5, 99))
    # a fixed rate that started more than its term ago has reverted to the standard variable rate
    # when a fix ends most borrowers re-fix; about 1 in 4 drift onto the standard variable rate
    pick[mg] = np.where((yrs_on[mg] > fix_len[mg]) & (rng.random(mg.sum()) < 0.25), "PRD-MG-SVR", fixed[mg])
    ac = ac.assign(PRODUCT_ID=pick)
    ac["PRODUCT"] = ac.PRODUCT.replace({"CASH_ISA": "ISA"})

    # Rates follow the product (legacy savers keep their old rate; card rate from the card product)
    prod_rate = ac.PRODUCT_ID.map(p.INTEREST_RATE_PCT).to_numpy(float)
    keep_own = legacy | (fam == "PERSONAL_LOAN")
    ac["INTEREST_RATE_PCT"] = np.where(keep_own | np.isnan(prod_rate), ac.INTEREST_RATE_PCT, prod_rate).round(2)
    term = ac.PRODUCT_ID.map(p.TERM_MONTHS).to_numpy(float)
    term = np.where(ln, rng.choice([24, 36, 48, 60], n), term)
    ac["TERM_MONTHS"] = np.where(np.isin(fam, ["PERSONAL_LOAN", "MORTGAGE"]) | ac.PRODUCT_ID.str.contains("FX").to_numpy(), term, np.nan)
    elapsed = (yrs_on * 12).round()
    remaining = np.clip(np.nan_to_num(term) - elapsed, 12, None)
    pay = np.where(np.isin(fam, ["PERSONAL_LOAN", "MORTGAGE"]), annuity(ac.BALANCE_GBP.to_numpy(float), ac.INTEREST_RATE_PCT.to_numpy(float), remaining), np.nan)
    ac["MONTHLY_PAYMENT_GBP"] = np.round(pay, 2)
    # Fixed savings, ISAs and mortgages mature: some in the next 3 months, a retention moment
    fix_months = np.select([ac.PRODUCT_ID.isin(["PRD-SV-FX1", "PRD-IS-FX1"]), ac.PRODUCT_ID.eq("PRD-SV-FX2"), ac.PRODUCT_ID.eq("PRD-MG-FX2"), ac.PRODUCT_ID.eq("PRD-MG-FX5")], [12, 24, 24, 60], 0)
    start = opened + pd.to_timedelta(np.floor(np.where(fix_months > 0, (yrs_on * 12) // np.maximum(fix_months, 1), 0) * fix_months) * 30.44, unit="D")
    ac["MATURITY_DATE"] = np.where(fix_months > 0, (start + pd.to_timedelta(fix_months * 30.44, unit="D")).dt.normalize(), pd.NaT)

    # Insurance policies (no balance, a monthly premium)
    owner = cu.HOUSING_TENURE.isin(["OWNS_OUTRIGHT", "MORTGAGE", "SHARED_OWNERSHIP"]).to_numpy()
    k = len(cu)
    pol = [(owner & (rng.random(k) < 0.28), "PRD-IN-HOM"), ((cu.ANNUAL_INCOME_GBP.to_numpy() > 25000) & (rng.random(k) < 0.12), "PRD-IN-TRV"),
           (cu.HOUSING_TENURE.eq("MORTGAGE").to_numpy() & (rng.random(k) < 0.22), "PRD-IN-LIF")]
    ins = []
    for mask, pid in pol:
        idx = np.flatnonzero(mask)
        prem = p.at[pid, "MONTHLY_FEE_GBP"] * rng.uniform(0.7, 1.5, len(idx))
        opened_i = pd.Series(pd.to_datetime(cu.CUSTOMER_SINCE.iloc[idx].to_numpy()) + pd.to_timedelta(rng.uniform(0, 5, len(idx)) * 365.25, unit="D")).clip(upper=AS_OF)
        ins.append(pd.DataFrame({"CUSTOMER_ID": cu.CUSTOMER_ID.iloc[idx].to_numpy(), "PRODUCT": "INSURANCE", "PRODUCT_ID": pid,
                                 "OPENED_DATE": opened_i.dt.normalize().to_numpy(), "BALANCE_GBP": 0.0, "STATUS": "OPEN",
                                 "MONTHLY_PAYMENT_GBP": prem.round(2), "TERM_MONTHS": p.at[pid, "TERM_MONTHS"]}))
    ins = pd.concat(ins, ignore_index=True)
    ins["ACCOUNT_ID"] = [f"RBA{2000000 + i}" for i in range(len(ins))]
    ac = pd.concat([ac, ins], ignore_index=True)
    ac["MONTHLY_FEE_GBP"] = np.where(ac.PRODUCT == "INSURANCE", 0.0, ac.PRODUCT_ID.map(p.MONTHLY_FEE_GBP).fillna(0))
    return ac, p.reset_index()


# ---- employment and pay

EMPLOYER_STEMS = ["Larkmere", "Ashcombe", "Brindlewood", "Corvane", "Daleford", "Fenwick Vale", "Greystone", "Harrowgate", "Ironbridge",
                  "Kestrelwood", "Lowmoor", "Marlow Reach", "Netherby", "Oakhaven", "Pennant", "Quarrybank", "Rosedale", "Saltmarsh",
                  "Thornbury", "Underhill", "Westcote", "Yarrowby", "Brackenfield", "Cobalt Lane", "Elderhaven", "Highcliff", "Linden Row"]
SECTOR_SUFFIX = {"HEALTH": ["Health Trust", "Care Partnership", "Medical Practice"], "PUBLIC_SECTOR": ["Borough Council", "City Council", "Housing Association"],
                 "EDUCATION": ["Academy Trust", "College", "University"], "FINANCE": ["Capital LLP", "Financial Services Ltd", "Insurance plc"],
                 "TECHNOLOGY": ["Digital Ltd", "Software Ltd", "Systems plc"], "RETAIL": ["Retail Group", "Stores Ltd", "Foods Ltd"],
                 "HOSPITALITY": ["Hospitality Ltd", "Hotels Group", "Kitchens Ltd"], "LOGISTICS": ["Logistics Ltd", "Freight Ltd", "Distribution plc"],
                 "CONSTRUCTION": ["Construction Ltd", "Building Services", "Developments Ltd"], "MANUFACTURING": ["Engineering plc", "Manufacturing Ltd", "Industries Ltd"],
                 "PROFESSIONAL": ["Consulting LLP", "Solicitors LLP", "Accountants LLP"], "CREATIVE": ["Studios Ltd", "Media Ltd", "Design Ltd"]}
SECTOR_BY_CLASS = {  # NS-SeC -> sector weights
    "HIGHER_PROFESSIONAL": {"FINANCE": 0.2, "TECHNOLOGY": 0.2, "PROFESSIONAL": 0.2, "HEALTH": 0.15, "EDUCATION": 0.1, "PUBLIC_SECTOR": 0.1, "CREATIVE": 0.05},
    "LOWER_PROFESSIONAL": {"HEALTH": 0.2, "EDUCATION": 0.2, "PUBLIC_SECTOR": 0.15, "FINANCE": 0.1, "TECHNOLOGY": 0.1, "PROFESSIONAL": 0.1, "CREATIVE": 0.1, "RETAIL": 0.05},
    "INTERMEDIATE": {"PUBLIC_SECTOR": 0.25, "FINANCE": 0.2, "HEALTH": 0.15, "PROFESSIONAL": 0.15, "RETAIL": 0.1, "LOGISTICS": 0.1, "EDUCATION": 0.05},
    "SMALL_EMPLOYER": {"CONSTRUCTION": 0.3, "HOSPITALITY": 0.2, "RETAIL": 0.15, "CREATIVE": 0.15, "PROFESSIONAL": 0.1, "LOGISTICS": 0.1},
    "LOWER_SUPERVISORY": {"MANUFACTURING": 0.25, "CONSTRUCTION": 0.2, "LOGISTICS": 0.2, "RETAIL": 0.15, "HEALTH": 0.1, "HOSPITALITY": 0.1},
    "SEMI_ROUTINE": {"RETAIL": 0.3, "HEALTH": 0.2, "HOSPITALITY": 0.2, "LOGISTICS": 0.15, "EDUCATION": 0.15},
    "ROUTINE": {"LOGISTICS": 0.3, "MANUFACTURING": 0.25, "CONSTRUCTION": 0.2, "HOSPITALITY": 0.15, "RETAIL": 0.1},
    "NEVER_WORKED": {"RETAIL": 0.4, "HOSPITALITY": 0.4, "LOGISTICS": 0.2},
    "STUDENT": {"HOSPITALITY": 0.5, "RETAIL": 0.4, "EDUCATION": 0.1},
}
# Large UK employers the synthetic names must never match (validation guard)
REAL_EMPLOYERS = {"tesco", "nhs", "barclays", "hsbc", "lloyds", "natwest", "sainsbury", "asda", "bt group", "unilever", "bp", "shell",
                  "vodafone", "rolls-royce", "bae systems", "amazon", "google", "deloitte", "pwc", "kpmg", "ey", "accenture", "aviva",
                  "legal & general", "santander", "nationwide", "marks & spencer", "john lewis", "royal mail", "network rail"}


def uk_tax_ni(gross, scottish, self_employed):
    """Income tax and NI for a year, 2025/26 bands (rUK thresholds frozen into 2026/27; Scottish bands for Scotland).
    Personal allowance tapers above £100k. Simplified: no student loan, pension or other deductions."""
    g = np.asarray(gross, float)
    pa = np.clip(12570 - np.maximum(g - 100000, 0) / 2, 0, 12570)
    def bands(edges, rates):
        tax = np.zeros_like(g)
        lo = pa.copy()
        for top, r in zip(edges, rates):
            hi = np.maximum(pa, top) if top != np.inf else np.full_like(g, np.inf)
            tax += np.clip(np.minimum(g, hi) - lo, 0, None) * r
            lo = np.maximum(lo, hi)
        return tax
    ruk = bands([50270, 125140, np.inf], [0.20, 0.40, 0.45])
    sco = bands([15397, 27491, 43662, 75000, 125140, np.inf], [0.19, 0.20, 0.21, 0.42, 0.45, 0.48])
    tax = np.where(scottish, sco, ruk)
    main, upper = np.where(self_employed, 0.06, 0.08), 0.02
    ni = np.clip(np.minimum(g, 50270) - 12570, 0, None) * main + np.clip(g - 50270, 0, None) * upper
    return tax, ni


def employment(rng, cu):
    """RB_EMPLOYMENT: employer, sector, pay frequency and day, gross and net pay for every customer."""
    n = len(cu)
    emp = cu.EMPLOYMENT_STATUS.to_numpy()
    occ = cu.OCCUPATION_CLASS.to_numpy()
    working = np.char.startswith(emp.astype(str), ("EMPLOYED")) | np.char.startswith(emp.astype(str), "SELF")
    self_emp = emp == "SELF_EMPLOYED"
    sector = np.array([rng.choice(list(SECTOR_BY_CLASS[o]), p=np.array(list(SECTOR_BY_CLASS[o].values())) / sum(SECTOR_BY_CLASS[o].values())) for o in occ])
    # a fixed pool of employers per city and sector, so colleagues share an employer
    pool = {}
    def employer(city, sec):
        key = (city, sec)
        if key not in pool:
            stems = rng.choice(EMPLOYER_STEMS, 6, replace=False)
            pool[key] = [f"{s} {rng.choice(SECTOR_SUFFIX[sec])}" for s in stems]
        return rng.choice(pool[key])
    name = np.array([employer(c, s) if w and not se else None for c, s, w, se in zip(cu.CITY, sector, working, self_emp)], object)
    name = np.where(self_emp, "Self-employed", name)
    routine = np.isin(occ, ["ROUTINE", "SEMI_ROUTINE", "NEVER_WORKED"])
    freq = np.where(~working, np.where(emp == "RETIRED", "MONTHLY", None),
                    np.where(self_emp, "MONTHLY", np.where(routine & (rng.random(n) < 0.25), "WEEKLY",
                                                           np.where(rng.random(n) < 0.07, "FOUR_WEEKLY", "MONTHLY"))))
    pay_day = np.where(freq == "MONTHLY", rng.choice([25, 26, 27, 28, 28, 28], n), np.where(freq == None, None, 5))  # 5 = Friday
    gross = cu.ANNUAL_INCOME_GBP.to_numpy(float)
    scottish = cu.CITY.isin(["Glasgow", "Edinburgh"]).to_numpy()
    tax, ni = uk_tax_ni(gross, scottish, self_emp)
    ni = np.where(working, ni, 0.0)  # no NI on pensions or benefits
    tax = np.where(np.isin(emp, ["UNEMPLOYED", "LONG_TERM_SICK", "LOOKING_AFTER_HOME", "OTHER_INACTIVE", "STUDENT"]) & ~working, 0.0, tax)
    net = (gross - tax - ni) / 12
    years_in_job = np.clip(rng.gamma(1.5, 3.0, n), 0.2, np.maximum(cu.AGE.to_numpy() - 17, 0.3))
    start = (AS_OF - pd.to_timedelta(years_in_job * 365.25, unit="D")).normalize()
    income_source = np.select([working & ~self_emp, self_emp, emp == "RETIRED", emp == "STUDENT"], ["SALARY", "SELF_EMPLOYMENT", "PENSION", "STUDENT_INCOME"], "BENEFITS")
    return pd.DataFrame({"CUSTOMER_ID": cu.CUSTOMER_ID, "INCOME_SOURCE": income_source, "EMPLOYER_NAME": name,
                         "EMPLOYER_SECTOR": np.where(working, sector, None), "PAY_FREQUENCY": np.where(freq == None, "MONTHLY", freq),
                         "PAY_DAY": pay_day, "EMPLOYMENT_START": np.where(working, start, pd.NaT),
                         "GROSS_ANNUAL_GBP": gross.round(0), "INCOME_TAX_ANNUAL_GBP": tax.round(0), "NATIONAL_INSURANCE_ANNUAL_GBP": ni.round(0),
                         "NET_MONTHLY_GBP": net.round(2), "TAX_REGIME": np.where(scottish, "SCOTLAND", "ENGLAND_WALES_NI")})


def salary_history(rng, emp):
    """RB_SALARY_HISTORY: about three years of pay changes per working customer, ending at today's gross."""
    rows = []
    for r in emp[emp.INCOME_SOURCE.isin(["SALARY", "SELF_EMPLOYMENT"])].itertuples():
        start = pd.Timestamp(r.EMPLOYMENT_START)
        events = [pd.Timestamp(f"{y}-04-01") for y in (2024, 2025, 2026) if pd.Timestamp(f"{y}-04-01") > start]
        steps = []
        for d in events:  # annual reviews, roughly in line with UK average earnings growth
            reason = "INCOME_CHANGE" if r.INCOME_SOURCE == "SELF_EMPLOYMENT" else rng.choice(["ANNUAL_REVIEW", "PROMOTION"], p=[0.88, 0.12])
            rise = rng.normal({2024: 0.055, 2025: 0.048, 2026: 0.038}[d.year], 0.02) + (0.09 if reason == "PROMOTION" else 0)
            steps.append((d, reason, max(rise, 0)))
        gross = r.GROSS_ANNUAL_GBP
        hist = [(AS_OF.normalize() if not steps else steps[-1][0], gross, steps[-1][1] if steps else "STARTED")]
        for i in range(len(steps) - 1, 0, -1):
            gross = gross / (1 + steps[i][2])
            hist.append((steps[i - 1][0], gross, steps[i - 1][1]))
        if steps:
            gross = gross / (1 + steps[0][2])
            hist.append((max(start, AS_OF - pd.Timedelta(days=3 * 365)), gross, "STARTED" if start > AS_OF - pd.Timedelta(days=3 * 365) else "IN_ROLE"))
        if not steps:
            hist = [(max(start, AS_OF - pd.Timedelta(days=3 * 365)), r.GROSS_ANNUAL_GBP, "STARTED")]
        for d, g, why in sorted(hist):
            rows.append((r.CUSTOMER_ID, d.normalize(), round(g, -1), why, r.EMPLOYER_NAME))
    h = pd.DataFrame(rows, columns=["CUSTOMER_ID", "EFFECTIVE_DATE", "GROSS_ANNUAL_GBP", "CHANGE_REASON", "EMPLOYER_NAME"])
    return h.drop_duplicates(["CUSTOMER_ID", "EFFECTIVE_DATE"], keep="last")


def affordability(cu, ac, emp, sn, housing):
    """Debt, commitments and disposable income per customer, from the tables above."""
    debt = ac[ac.PRODUCT.isin(["CREDIT_CARD", "PERSONAL_LOAN", "MORTGAGE"]) & ac.STATUS.eq("OPEN")].groupby("CUSTOMER_ID").BALANCE_GBP.sum()
    repay = ac[ac.STATUS.eq("OPEN")].groupby("CUSTOMER_ID").MONTHLY_PAYMENT_GBP.sum()
    card_min = ac[ac.PRODUCT.eq("CREDIT_CARD") & ac.STATUS.eq("OPEN")].groupby("CUSTOMER_ID").BALANCE_GBP.sum() * 0.03
    spend = sn[pd.to_datetime(sn.MONTH) >= MONTHS[-3].to_timestamp()].groupby("CUSTOMER_ID").CARD_SPEND_GBP.mean()
    e = emp.set_index("CUSTOMER_ID")
    ids = cu.CUSTOMER_ID
    total_debt = ids.map(debt).fillna(0)
    commitments = ids.map(repay).fillna(0) + ids.map(card_min).fillna(0) + ids.map(housing).fillna(0) + BILLS_MONTHLY
    net = ids.map(e.NET_MONTHLY_GBP)
    disposable = net - commitments - ids.map(spend).fillna(0)
    dti = total_debt / ids.map(e.GROSS_ANNUAL_GBP).clip(lower=1)
    band = np.select([disposable < 0, (disposable < 250) | (dti > 4.5), disposable < 1000], ["STRETCHED", "TIGHT", "COMFORTABLE"], "STRONG")
    return pd.DataFrame({"TOTAL_DEBT_GBP": total_debt.round(2).to_numpy(), "DEBT_TO_INCOME": dti.round(2).to_numpy(),
                         "MONTHLY_COMMITMENTS_GBP": commitments.round(2).to_numpy(), "DISPOSABLE_INCOME_GBP": disposable.round(2).to_numpy(),
                         "AFFORDABILITY_BAND": band})


BILLS_MONTHLY = 295  # council tax, energy and mobile direct debits in the ledger


def churn(rng, cu, ac):
    """Attrition: a monthly hazard driven by planted reasons; returns the churn month (or NaT)."""
    n = len(cu)
    tenure = (AS_OF - cu.CUSTOMER_SINCE).dt.days.to_numpy() / 365.25
    held = ac.groupby("CUSTOMER_ID").PRODUCT.agg(set).reindex(cu.CUSTOMER_ID)
    sav = ac[ac.PRODUCT == "SAVINGS"].set_index("CUSTOMER_ID")
    low_rate_saver = cu.CUSTOMER_ID.map(((sav.INTEREST_RATE_PCT < 1.6) & (sav.BALANCE_GBP > 15000)).groupby(level=0).any()).fillna(False).to_numpy(bool)
    single_product = held.map(len).to_numpy(float) == 1
    branch_reliant = (~cu.DIGITAL_ACTIVE.to_numpy(bool)) & cu.HOME_BRANCH_ID.isin(CLOSURE_CANDIDATES).to_numpy(bool)
    complaints = rng.poisson(np.where(cu.SEGMENT == "PREMIER", 0.25, 0.15) * 12, n) * (rng.random(n) < 0.35)
    logit = (-6.55 + 1.5 * (tenure < 2) + 1.9 * low_rate_saver + 0.9 * single_product + 1.8 * branch_reliant
             + 0.65 * np.minimum(complaints, 4) + 0.6 * (cu.AGE.to_numpy() < 30) - 0.8 * cu.HOUSING_TENURE.eq("MORTGAGE").to_numpy())
    hazard = 1 / (1 + np.exp(-np.asarray(logit, float)))
    month = np.full(n, -1)
    for m in range(len(MONTHS)):
        alive = month < 0
        hit = alive & (rng.random(n) < hazard)
        month[hit] = m
    cu["COMPLAINTS_12M"] = complaints
    cu["CHURN_REASON"] = np.where(month < 0, None, np.select(
        [low_rate_saver, branch_reliant, complaints >= 2, tenure < 2], ["BETTER_RATE_ELSEWHERE", "BRANCH_ACCESS", "SERVICE_COMPLAINTS", "EARLY_TENURE"], "OTHER"))
    return month


def snapshots(rng, cu, ac, churn_month, emp, housing):
    """RB_MONTHLY_SNAPSHOT: one row per customer per month until they leave, with revenue and cost."""
    n, M = len(cu), len(MONTHS)
    bal = ac.pivot_table(index="CUSTOMER_ID", columns="PRODUCT", values="BALANCE_GBP", aggfunc="sum").reindex(cu.CUSTOMER_ID).fillna(0)
    premiums = ac[ac.PRODUCT == "INSURANCE"].groupby("CUSTOMER_ID").MONTHLY_PAYMENT_GBP.sum().reindex(cu.CUSTOMER_ID).fillna(0).to_numpy()
    fees = ac.groupby("CUSTOMER_ID").MONTHLY_FEE_GBP.sum().reindex(cu.CUSTOMER_ID).fillna(0).to_numpy()
    rate = ac[ac.PRODUCT == "SAVINGS"].groupby("CUSTOMER_ID").INTEREST_RATE_PCT.mean().reindex(cu.CUSTOMER_ID).fillna(0).to_numpy()
    nprod = ac.groupby("CUSTOMER_ID").size().reindex(cu.CUSTOMER_ID).to_numpy()
    salary = emp.set_index("CUSTOMER_ID").NET_MONTHLY_GBP.reindex(cu.CUSTOMER_ID).to_numpy()  # net pay after tax and NI
    # discretionary spend comes out of what's left after housing, bills and repayments
    repay = ac[ac.STATUS.eq("OPEN")].groupby("CUSTOMER_ID").MONTHLY_PAYMENT_GBP.sum().reindex(cu.CUSTOMER_ID).fillna(0).to_numpy()
    house = cu.CUSTOMER_ID.map(lambda c: housing.get(c, (0, None))[0]).to_numpy(float)
    spend_base = np.maximum(salary - house - BILLS_MONTHLY - repay, 60) * rng.uniform(0.55, 1.05, n)
    digital = cu.DIGITAL_ACTIVE.to_numpy()
    rows = []
    for m, per in enumerate(MONTHS):
        alive = (churn_month < 0) | (churn_month >= m)
        to_go = np.where(churn_month >= 0, churn_month - m, 99)  # months until leaving
        fade = np.select([to_go == 0, to_go == 1, to_go == 2], [0.15, 0.45, 0.8], 1.0)  # salary redirected away
        season = SEASON[per.month]
        sal = salary * fade * rng.normal(1, 0.03, n)
        spend = spend_base * season * np.where(to_go <= 1, 0.6, 1.0) * rng.normal(1, 0.12, n)
        cur = np.maximum(bal["CURRENT_ACCOUNT"].to_numpy() * np.where(to_go <= 2, fade, 1.0) + (sal - spend) * 0.3, -1500)
        savings = bal.get("SAVINGS", 0).to_numpy() * np.where(to_go <= 1, 0.2, 1.0) * (1 + 0.002 * m)
        card = bal.get("CREDIT_CARD", 0).to_numpy() * season * rng.normal(1, 0.1, n)
        logins = np.where(digital, rng.poisson(np.where(to_go <= 2, 6, 22), n), rng.poisson(0.5, n))
        visits = rng.poisson(np.where(digital, 0.1, 1.1) * np.where(cu.AGE.to_numpy() >= 70, 1.5, 1.0), n)
        revenue = (np.maximum(cur, 0) * 0.025 + savings * np.maximum(4.6 - rate, 0.4) / 100 + card * 0.22 * 0.6
                   + bal.get("PERSONAL_LOAN", 0).to_numpy() * 0.045 + bal.get("MORTGAGE", 0).to_numpy() * 0.009
                   + np.maximum(-cur, 0) * 0.39) / 12 + spend * 0.002 + (cur < 0) * 5 + premiums * 0.25 + fees
        cost = 1.6 + visits * 8 + (~digital) * 1.2 + rng.poisson(0.2, n) * 4  # servicing, branch visits, calls
        df = pd.DataFrame({"CUSTOMER_ID": cu.CUSTOMER_ID, "MONTH": per.to_timestamp(), "SALARY_IN_GBP": sal.round(2),
                           "CARD_SPEND_GBP": spend.round(2), "CURRENT_BALANCE_GBP": cur.round(2), "SAVINGS_BALANCE_GBP": savings.round(2),
                           "CREDIT_CARD_BALANCE_GBP": card.round(2), "PRODUCTS_HELD": nprod, "APP_LOGINS": logins, "BRANCH_VISITS": visits,
                           "REVENUE_GBP": revenue.round(2), "COST_TO_SERVE_GBP": cost.round(2), "CHURNED_FLAG": to_go == 0})
        rows.append(df[alive])
    sn = pd.concat(rows, ignore_index=True)
    sn["PROFIT_GBP"] = (sn.REVENUE_GBP - sn.COST_TO_SERVE_GBP).round(2)
    return sn


MERCHANTS = {  # category -> (MCC, merchants, median amount GBP, share of card spend)
    "GROCERIES": ("5411", ["Tesco", "Sainsbury's", "Asda", "Aldi", "Lidl", "Morrisons", "Co-op", "Waitrose"], 32, 0.30),
    "EATING_OUT": ("5812", ["Pret A Manger", "Greggs", "Nando's", "Costa Coffee", "Wagamama", "Local cafe"], 14, 0.12),
    "TRANSPORT": ("4111", ["TfL", "Trainline", "National Rail", "Uber", "Stagecoach"], 9, 0.10),
    "FUEL": ("5541", ["Shell", "BP", "Esso", "Texaco"], 55, 0.06),
    "RETAIL": ("5311", ["Amazon", "Argos", "John Lewis", "Next", "Primark", "Boots"], 38, 0.16),
    "ENTERTAINMENT": ("7832", ["Netflix", "Spotify", "Odeon", "Ticketmaster", "Steam"], 13, 0.07),
    "TRAVEL": ("4511", ["easyJet", "British Airways", "Ryanair", "Booking.com", "Premier Inn"], 140, 0.05),
    "UTILITIES": ("4900", ["British Gas", "Octopus Energy", "Thames Water", "BT", "Vodafone"], 65, 0.08),
    "GAMBLING": ("7995", ["Bet365", "William Hill", "Paddy Power"], 20, 0.02),
    "CASH": ("6011", ["ATM withdrawal"], 60, 0.04),
}


def ledger(rng, cu, ac, churn_month, emp, housing):
    """RB_TRANSACTIONS: the last LEDGER_DAYS of current-account and card activity, with fraud planted."""
    start = AS_OF - pd.Timedelta(days=LEDGER_DAYS)
    leaver_window = len(MONTHS) - 1 - (LEDGER_DAYS // 30)
    active = (churn_month < 0) | (churn_month >= leaver_window)
    acct = ac[ac.PRODUCT == "CURRENT_ACCOUNT"].set_index("CUSTOMER_ID").ACCOUNT_ID
    cards = ac[ac.PRODUCT == "CREDIT_CARD"].set_index("CUSTOMER_ID").ACCOUNT_ID
    cats = list(MERCHANTS); share = np.array([MERCHANTS[c][3] for c in cats]); share /= share.sum()
    e = emp.set_index("CUSTOMER_ID")
    policies = ac[ac.PRODUCT.isin(["INSURANCE", "PERSONAL_LOAN", "MORTGAGE"])].merge(
        pd.DataFrame(PRODUCTS, columns=PRODUCT_COLS)[["PRODUCT_ID", "PRODUCT_NAME"]], on="PRODUCT_ID").groupby("CUSTOMER_ID")
    out = []
    for i in np.flatnonzero(active):
        c = cu.iloc[i]
        cid, aid = c.CUSTOMER_ID, acct[c.CUSTOMER_ID]
        leaving = 0 <= churn_month[i]
        monthly = e.at[cid, "NET_MONTHLY_GBP"]
        payer = (None if pd.isna(e.at[cid, "EMPLOYER_NAME"]) else e.at[cid, "EMPLOYER_NAME"]) or {"PENSION": "State and workplace pension", "BENEFITS": "DWP Universal Credit",
                                                "STUDENT_INCOME": "Student Loans Company"}.get(e.at[cid, "INCOME_SOURCE"], "Income")
        freq = e.at[cid, "PAY_FREQUENCY"]
        n_card = max(2, int(rng.poisson(np.clip(monthly / 90, 4, 45) * LEDGER_DAYS / 30 * (0.5 if leaving else 1.0))))
        days = rng.uniform(0, LEDGER_DAYS, n_card)
        ts = start.normalize() + pd.to_timedelta(np.floor(days), unit="D") + pd.to_timedelta(rng.normal(14.5, 3.2, n_card).clip(6, 23.9), unit="h")
        cat = rng.choice(cats, n_card, p=share)
        amt = np.array([MERCHANTS[k][2] for k in cat]) * np.exp(rng.normal(0, 0.6, n_card)) * np.array([SEASON[t.month] for t in ts])
        online = np.isin(cat, ["ENTERTAINMENT", "TRAVEL", "UTILITIES"]) | (rng.random(n_card) < 0.25)
        use_card = (c.CUSTOMER_ID in cards.index) & (rng.random(n_card) < 0.3)
        for k in range(n_card):
            out.append((cards[cid] if use_card[k] else aid, cid, ts[k].floor("s"), -round(float(amt[k]), 2), "CARD" if cat[k] != "CASH" else "ATM",
                        cat[k], MERCHANTS[cat[k]][0], rng.choice(MERCHANTS[cat[k]][1]), "GB", bool(online[k]) and cat[k] != "CASH", False, False, None))
        # Salary, direct debits and standing orders, on their usual days
        if freq == "MONTHLY":
            pays = [d + pd.Timedelta(days=int(e.at[cid, "PAY_DAY"] or 28) - 1, hours=6) for d in pd.date_range(start.normalize().replace(day=1), AS_OF, freq="MS")]
            amount = monthly
        else:  # weekly or four-weekly, on Fridays
            step = 7 if freq == "WEEKLY" else 28
            first = start.normalize() + pd.Timedelta(days=(4 - start.weekday()) % 7 + int(rng.integers(0, step)) % step, hours=6)
            pays = list(pd.date_range(first, AS_OF, freq=f"{step}D"))
            amount = monthly * 12 / (52 if freq == "WEEKLY" else 13)
        for pay in pays:
            if start <= pay <= AS_OF and monthly > 0:
                fade = 0.15 if leaving and pay > AS_OF - pd.Timedelta(days=35) else 1.0
                out.append((aid, cid, pay, round(amount * fade * rng.normal(1, 0.01), 2), "FPS_IN", "INCOME", None, payer, "GB", False, False, False, None))
        for d in pd.date_range(start.normalize().replace(day=1), AS_OF, freq="MS"):
            for dd, (name, amount) in enumerate([("Council tax", 150), ("Energy", 120), ("Mobile", 25)]):
                t = d + pd.Timedelta(days=1 + dd * 3, hours=5)
                if start <= t <= AS_OF:
                    out.append((aid, cid, t, -round(amount * rng.uniform(0.7, 1.3), 2), "DIRECT_DEBIT", "BILLS", None, name, "GB", False, False, False, None))
            h_amt, h_name = housing.get(cid, (0, None))
            t = d + pd.Timedelta(days=0, hours=4)
            if h_amt and start <= t <= AS_OF:
                out.append((aid, cid, t, -round(h_amt, 2), "STANDING_ORDER" if h_name == "Rent" else "DIRECT_DEBIT",
                            "HOUSING", None, h_name, "GB", False, False, False, None))
            # repayments and premiums on products held with us
            if cid in policies.groups:
                for pol in policies.get_group(cid).itertuples():
                    t = d + pd.Timedelta(days=14, hours=5)
                    if pol.PRODUCT != "MORTGAGE" and pol.STATUS == "OPEN" and start <= t <= AS_OF and pol.MONTHLY_PAYMENT_GBP == pol.MONTHLY_PAYMENT_GBP:
                        out.append((aid, cid, t, -round(pol.MONTHLY_PAYMENT_GBP, 2), "DIRECT_DEBIT", "INSURANCE" if pol.PRODUCT == "INSURANCE" else "LOAN_REPAYMENT",
                                    None, pol.PRODUCT_NAME, "GB", False, False, False, None))
        # Leavers: switch-out transfers to another bank before they go
        if leaving:
            for _ in range(int(rng.integers(1, 4))):
                t = AS_OF - pd.Timedelta(days=float(rng.uniform(1, 40)))
                out.append((aid, cid, t.floor("s"), -round(float(monthly * rng.uniform(0.5, 2.0)), 2), "FPS_OUT", "TRANSFER", None,
                            rng.choice(["Monzo", "Nationwide", "Chase UK", "Starling", "Santander"]), "GB", True, True, False, None))
    cols = ["ACCOUNT_ID", "CUSTOMER_ID", "TXN_TS", "AMOUNT_GBP", "CHANNEL", "CATEGORY", "MCC", "MERCHANT", "MERCHANT_COUNTRY",
            "IS_ONLINE", "IS_NEW_PAYEE", "IS_FRAUD", "FRAUD_TYPE"]
    tx = pd.DataFrame(out, columns=cols)
    return plant_fraud(rng, cu, tx)


def plant_fraud(rng, cu, tx):
    """About 0.3% of transactions are labelled fraud, in four patterns a model can learn."""
    by_cust = tx.groupby("CUSTOMER_ID")
    custs = cu.set_index("CUSTOMER_ID")
    target = int(len(tx) * 0.003)
    victims = rng.choice(tx.CUSTOMER_ID.unique(), size=max(40, target // 3), replace=False)  # about 3 rows each
    rows = []
    for v in victims:
        acct = by_cust.get_group(v).ACCOUNT_ID.iat[0]
        t0 = AS_OF - pd.Timedelta(days=float(rng.uniform(2, LEDGER_DAYS - 2)))
        old = custs.at[v, "AGE"] >= 65
        kind = rng.choice(["APP_SCAM", "CARD_TESTING", "IMPOSSIBLE_TRAVEL", "ACCOUNT_TAKEOVER"], p=[0.45, 0.2, 0.15, 0.2] if old else [0.15, 0.35, 0.25, 0.25])
        if kind == "CARD_TESTING":  # a burst of tiny online charges, then a big one
            for k in range(int(rng.integers(4, 9))):
                rows.append((acct, v, t0 + pd.Timedelta(minutes=2 * k), -round(float(rng.uniform(0.5, 2.5)), 2), "CARD", "RETAIL", "5999", "Unknown online merchant", rng.choice(["LT", "RO", "US"]), True, False, True, kind))
            rows.append((acct, v, t0 + pd.Timedelta(minutes=25), -round(float(rng.uniform(400, 1800)), 2), "CARD", "RETAIL", "5732", "Electronics online", "US", True, False, True, kind))
        elif kind == "IMPOSSIBLE_TRAVEL":  # card used in two countries an hour apart
            rows.append((acct, v, t0, -round(float(rng.uniform(150, 900)), 2), "CARD", "RETAIL", "5944", "Jewellery store", rng.choice(["AE", "TR", "TH"]), False, False, True, kind))
            rows.append((acct, v, t0 + pd.Timedelta(minutes=50), -round(float(rng.uniform(200, 1200)), 2), "CARD", "RETAIL", "5311", "Department store", rng.choice(["NG", "BR", "MX"]), False, False, True, kind))
        elif kind == "APP_SCAM":  # authorised push payment: new payee, large, often older customers
            for k in range(int(rng.integers(1, 4))):
                rows.append((acct, v, t0 + pd.Timedelta(hours=2 * k), -round(float(rng.uniform(900, 9000)), 2), "FPS_OUT", "TRANSFER", None, rng.choice(["Safe account", "HMRC refund", "Investment platform"]), "GB", True, True, True, kind))
        else:  # account takeover: night-time transfers to new payees
            night = t0.normalize() + pd.Timedelta(hours=float(rng.uniform(1, 4.5)))
            for k in range(int(rng.integers(2, 5))):
                rows.append((acct, v, night + pd.Timedelta(minutes=7 * k), -round(float(rng.uniform(300, 2500)), 2), "FPS_OUT", "TRANSFER", None, "New payee", "GB", True, True, True, kind))
    fr = pd.DataFrame(rows, columns=tx.columns)
    tx = pd.concat([tx, fr], ignore_index=True)
    tx["TXN_TS"] = pd.to_datetime(tx.TXN_TS).dt.floor("s")
    tx = tx.sort_values(["CUSTOMER_ID", "TXN_TS"]).reset_index(drop=True)
    tx.insert(0, "TXN_ID", [f"RBT{10000000 + i}" for i in range(len(tx))])
    return tx


CUSTOMER_COLS = ["CUSTOMER_ID", "FIRST_NAME", "LAST_NAME", "SEX", "DATE_OF_BIRTH", "AGE", "ADDRESS_LINE_1", "POSTCODE", "CITY",
                 "HOME_LAT", "HOME_LON", "HOME_H3_CELL", "LSOA_CODE", "MSOA_CODE", "LOCAL_AUTHORITY_CODE", "IMD_DECILE",
                 "AREA_CLASSIFICATION", "HOUSEHOLD_TYPE", "HOUSING_TENURE", "EMPLOYMENT_STATUS", "OCCUPATION_CLASS",
                 "ANNUAL_INCOME_GBP", "INCOME_BAND", "CREDIT_SCORE", "CREDIT_BAND", "SEGMENT", "CUSTOMER_SINCE",
                 "ACQUISITION_CHANNEL", "DIGITAL_ACTIVE", "PREFERRED_CHANNEL", "VULNERABLE_FLAG", "MARKETING_CONSENT",
                 "HOME_BRANCH_ID", "HOME_BRANCH_DRIVE_S", "COMPLAINTS_12M", "TOTAL_DEBT_GBP", "DEBT_TO_INCOME",
                 "MONTHLY_COMMITMENTS_GBP", "DISPOSABLE_INCOME_GBP", "AFFORDABILITY_BAND", "CHURNED", "CHURN_DATE", "CHURN_REASON"]


def housing_costs(rng, cu, ac, emp):
    """One monthly housing payment per customer: rent, our mortgage, or a mortgage with another lender."""
    ours = ac[ac.PRODUCT.eq("MORTGAGE")].groupby("CUSTOMER_ID").MONTHLY_PAYMENT_GBP.sum()
    net = emp.set_index("CUSTOMER_ID").NET_MONTHLY_GBP
    out = {}
    for cid, ten in zip(cu.CUSTOMER_ID, cu.HOUSING_TENURE):
        if ten == "MORTGAGE":
            out[cid] = (float(ours[cid]), "Mortgage payment") if cid in ours.index else (float(net[cid] * rng.uniform(0.22, 0.35)), "Mortgage (other lender)")
        elif ten in ("PRIVATE_RENT", "SOCIAL_RENT", "SHARED_OWNERSHIP"):
            share = rng.uniform(0.28, 0.42) if ten == "PRIVATE_RENT" else rng.uniform(0.2, 0.3)
            out[cid] = (float(max(net[cid] * share, 350 if ten == "PRIVATE_RENT" else 250)), "Rent")
    return out


def generate():
    rng = np.random.default_rng(SEED)
    fp = footprint()
    u, pc, st = uprns(fp), postcodes(fp), streets()
    cen = census(pc)
    cu = customers(rng, fp, u, pc, st, cen)
    log(f"customers: {len(cu):,}")
    ac = accounts(rng, cu)
    month = churn(rng, cu, ac)
    ac, products = link_products(rng, cu, ac)
    cu["CHURNED"] = month >= 0
    cu["CHURN_DATE"] = [None if m < 0 else (MONTHS[m].to_timestamp(how="end").normalize()) for m in month]
    closed = cu.loc[cu.CHURNED, ["CUSTOMER_ID", "CHURN_DATE"]]
    ac = ac.merge(closed, on="CUSTOMER_ID", how="left")
    ac.loc[ac.CHURN_DATE.notna(), "STATUS"] = "CLOSED"
    ac["CLOSED_DATE"] = ac.pop("CHURN_DATE")
    log(f"accounts: {len(ac):,} on {ac.PRODUCT_ID.nunique()} products, churned customers: {cu.CHURNED.mean():.1%}")
    emp = employment(rng, cu)
    hist = salary_history(rng, emp)
    log(f"employment: {emp.EMPLOYER_NAME.nunique():,} employers, salary history: {len(hist):,} rows")
    housing = housing_costs(rng, cu, ac, emp)
    sn = snapshots(rng, cu, ac, month, emp, housing)
    log(f"snapshots: {len(sn):,}")
    tx = ledger(rng, cu, ac, month, emp, housing)
    log(f"transactions: {len(tx):,}, fraud: {tx.IS_FRAUD.mean():.2%}")
    cu = pd.concat([cu.reset_index(drop=True), affordability(cu, ac, emp, sn, pd.Series({k: v[0] for k, v in housing.items()}))], axis=1)

    OUT.mkdir(parents=True, exist_ok=True)
    tables = {"rb_customers": cu[CUSTOMER_COLS],
              "rb_products": products[PRODUCT_COLS],
              "rb_accounts": ac[["ACCOUNT_ID", "CUSTOMER_ID", "PRODUCT_ID", "PRODUCT", "OPENED_DATE", "CLOSED_DATE", "STATUS", "BALANCE_GBP",
                                 "LIMIT_GBP", "INTEREST_RATE_PCT", "TERM_MONTHS", "MONTHLY_PAYMENT_GBP", "MATURITY_DATE"]],
              "rb_employment": emp, "rb_salary_history": hist,
              "rb_monthly_snapshot": sn, "rb_transactions": tx}
    for name, df in tables.items():
        path = OUT / f"{name}.csv.gz"
        df.to_csv(path, index=False, compression={"method": "gzip", "compresslevel": 9, "mtime": 0})
        log(f"  {path.relative_to(ROOT)}: {len(df):,} rows, {path.stat().st_size / 1e6:.1f} MB")


def validate():
    """Checks the generated files: sources agree, joins hold, signals are learnable, sizes fit git."""
    from sklearn.ensemble import IsolationForest
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    from sklearn.model_selection import train_test_split
    read = lambda n: pd.read_csv(OUT / f"{n}.csv.gz", low_memory=False)
    cu, ac, sn, tx = read("rb_customers"), read("rb_accounts"), read("rb_monthly_snapshot"), read("rb_transactions")
    ok = True
    def check(name, cond, detail=""):
        nonlocal ok
        ok &= bool(cond)
        log(f"  [{'ok' if cond else 'FAIL'}] {name} {detail}")

    log("Distributions against the sources")
    pc = pd.read_parquet(WORK / "postcodes.parquet")
    for city, share in CITY_SHARE.items():
        got = (cu.CITY == city).mean()
        check(f"city share {city}", abs(got - share) < 0.01, f"{got:.3f} vs {share}")
    cen = dists(census(pc))
    ew = cu[cu.LSOA_CODE.isin(cen["age"].index)]
    exp_age = cen["age"].reindex(ew.LSOA_CODE).mean()
    mids = {k: np.mean(v) for k, v in ADULT_AGE.items()}
    exp_mean_age = sum(exp_age[k] * mids[k] for k in exp_age.index)
    check("mean adult age vs own-LSOA census", abs(ew.AGE.mean() - exp_mean_age) < 1.5, f"{ew.AGE.mean():.1f} vs {exp_mean_age:.1f}")
    for key, col in [("tenure", "HOUSING_TENURE"), ("nssec", "OCCUPATION_CLASS")]:
        exp = cen[key].reindex(ew.LSOA_CODE).mean()
        got = ew[col].value_counts(normalize=True).reindex(exp.index, fill_value=0)
        tvd = 0.5 * (exp - got).abs().sum()
        check(f"{key} mix vs own-LSOA census (total variation)", tvd < 0.12, f"{tvd:.3f}")
    check("every IMD decile present", cu.IMD_DECILE.nunique() == 10, str(cu.IMD_DECILE.value_counts().sort_index().to_dict()))
    fpc = pc.merge(footprint()[["H3_CELL", "CITY"]], on="H3_CELL")
    for city in CITY_SHARE:
        exp = fpc[fpc.CITY == city].IMD_DECILE.value_counts(normalize=True)
        got = cu[cu.CITY == city].IMD_DECILE.value_counts(normalize=True).reindex(exp.index, fill_value=0)
        tvd = 0.5 * (exp - got).abs().sum()
        check(f"deprivation mix {city} vs its residential postcodes", tvd < 0.10, f"{tvd:.3f}")
    check("digitally active 70-85%", 0.70 <= cu.DIGITAL_ACTIVE.mean() <= 0.85, f"{cu.DIGITAL_ACTIVE.mean():.0%}")
    dig = cu.groupby("IMD_DECILE").DIGITAL_ACTIVE.mean()
    check("digital use rises with affluence", dig.iloc[-1] > dig.iloc[0], f"decile 1 {dig.iloc[0]:.2f}, decile 10 {dig.iloc[-1]:.2f}")

    log("Integrity")
    br = pd.read_csv(WORK / "branches.csv")
    check("every HOME_BRANCH_ID is a DA3 branch", cu.HOME_BRANCH_ID.isin(br.BRANCH_ID).all())
    check("every home has a drive time", cu.HOME_BRANCH_DRIVE_S.notna().all())
    check("customer ids unique", cu.CUSTOMER_ID.is_unique)
    check("accounts join to customers", ac.CUSTOMER_ID.isin(cu.CUSTOMER_ID).all())
    check("transactions join to accounts", tx.ACCOUNT_ID.isin(ac.ACCOUNT_ID).all())
    check("one current account each", (ac.PRODUCT == "CURRENT_ACCOUNT").sum() == len(cu))
    check("no real property identifiers (no UPRN, location to ~100 m)", "UPRN" not in cu and (cu.HOME_LAT.round(3) == cu.HOME_LAT).all())
    hours = pd.to_datetime(tx.loc[(tx.CHANNEL == "CARD") & ~tx.IS_FRAUD.astype(bool), "TXN_TS"]).dt.hour
    check("genuine card spend is mostly daytime", (hours.between(6, 23)).mean() > 0.97, f"{hours.between(6, 23).mean():.1%} between 06:00 and 23:59")

    log("Products, pay and affordability")
    pr, em, sh = read("rb_products"), read("rb_employment"), read("rb_salary_history")
    check("every account has a catalogue product", ac.PRODUCT_ID.isin(pr.PRODUCT_ID).all())
    held = ac.merge(pr, on="PRODUCT_ID").merge(cu[["CUSTOMER_ID", "AGE", "ANNUAL_INCOME_GBP", "CREDIT_SCORE"]], on="CUSTOMER_ID")
    new_sales = held[held.IS_ACTIVE & held.PRODUCT_FAMILY.isin(["CREDIT_CARD", "PERSONAL_LOAN"])]
    ok_elig = ((new_sales.ANNUAL_INCOME_GBP >= new_sales.MIN_INCOME_GBP) & (new_sales.CREDIT_SCORE >= new_sales.MIN_CREDIT_SCORE)).mean()
    check("lending products meet their income and score rules", ok_elig > 0.97, f"{ok_elig:.1%}")
    check("legacy savers are on closed products", (held[held.TIER.eq("LEGACY")].IS_ACTIVE == False).all())
    svr = held[held.PRODUCT_FAMILY.eq("MORTGAGE")].PRODUCT_ID.eq("PRD-MG-SVR").mean()
    check("5-20% of mortgages on the standard variable rate", 0.05 <= svr <= 0.20, f"{svr:.0%}")
    mat = pd.to_datetime(ac.MATURITY_DATE).between(AS_OF, AS_OF + pd.Timedelta(days=92)).sum()
    check("fixed products maturing in the next 3 months (retention triggers)", mat > 300, f"{mat:,}")
    check("one employment row per customer", em.CUSTOMER_ID.is_unique and len(em) == len(cu))
    check("net pay below gross pay", (em.NET_MONTHLY_GBP * 12 <= em.GROSS_ANNUAL_GBP + 1).all())
    sal = em[em.INCOME_SOURCE.eq("SALARY")]
    rate = (sal.INCOME_TAX_ANNUAL_GBP + sal.NATIONAL_INSURANCE_ANNUAL_GBP) / sal.GROSS_ANNUAL_GBP
    by = rate.groupby(pd.cut(sal.GROSS_ANNUAL_GBP, [0, 20e3, 40e3, 80e3, 1e7])).mean()
    check("effective tax and NI rate rises with income", by.is_monotonic_increasing, str(by.round(3).tolist()))
    occ = sal.CUSTOMER_ID.map(cu.set_index("CUSTOMER_ID").OCCUPATION_CLASS)
    odd = (sal.PAY_FREQUENCY.eq("WEEKLY") & ~occ.isin(["ROUTINE", "SEMI_ROUTINE", "NEVER_WORKED"])).sum()
    check("weekly pay only for routine and semi-routine jobs", odd == 0, f"{odd} others paid weekly")
    last = sh.sort_values("EFFECTIVE_DATE").groupby("CUSTOMER_ID").GROSS_ANNUAL_GBP.last()
    gap = (last - em.set_index("CUSTOMER_ID").GROSS_ANNUAL_GBP.reindex(last.index)).abs()
    check("salary history ends at today's gross", (gap <= 10).mean() > 0.99, f"{(gap <= 10).mean():.1%}")
    named = em.EMPLOYER_NAME.dropna().str.lower()
    clash = named[named.apply(lambda x: any(r in x.split() or x.startswith(r) for r in REAL_EMPLOYERS))]
    check("no real employer names", clash.empty, ", ".join(clash.unique()[:5]))
    payers = set(em.EMPLOYER_NAME.dropna()) | {"State and workplace pension", "DWP Universal Credit", "Student Loans Company"}
    payroll = tx[tx.CATEGORY.eq("INCOME")].MERCHANT.isin(payers).mean()
    check("payroll credits name the employer or payer", payroll > 0.99, f"{payroll:.1%}")
    debt = ac[ac.PRODUCT.isin(["CREDIT_CARD", "PERSONAL_LOAN", "MORTGAGE"]) & ac.STATUS.eq("OPEN")].groupby("CUSTOMER_ID").BALANCE_GBP.sum()
    recon = (cu.set_index("CUSTOMER_ID").TOTAL_DEBT_GBP - debt.reindex(cu.CUSTOMER_ID).fillna(0)).abs().max()
    check("total debt reconciles to account balances", recon < 1, f"max gap {recon:.2f}")
    band = cu.AFFORDABILITY_BAND.value_counts(normalize=True)
    check("affordability bands are spread (no band over 60%)", band.max() < 0.6, str(band.round(2).to_dict()))

    log("ML signals")
    churned = cu.CHURNED.astype(bool)
    check("attrition rate 8-12%", 0.08 <= churned.mean() <= 0.12, f"{churned.mean():.1%}")
    feats = pd.get_dummies(cu[["AGE", "IMD_DECILE", "ANNUAL_INCOME_GBP", "CREDIT_SCORE", "COMPLAINTS_12M", "HOME_BRANCH_DRIVE_S"]].assign(
        DIGITAL=cu.DIGITAL_ACTIVE.astype(int), TENURE=(AS_OF - pd.to_datetime(cu.CUSTOMER_SINCE)).dt.days,
        PRODUCTS=cu.CUSTOMER_ID.map(ac.groupby("CUSTOMER_ID").size()),
        CLOSURE_BRANCH=cu.HOME_BRANCH_ID.isin(CLOSURE_CANDIDATES).astype(int),
        LOW_RATE=cu.CUSTOMER_ID.map(ac[ac.PRODUCT == "SAVINGS"].groupby("CUSTOMER_ID").INTEREST_RATE_PCT.min()).fillna(9)), dtype=float)
    Xtr, Xte, ytr, yte = train_test_split((feats - feats.mean()) / feats.std(), churned, test_size=0.3, random_state=1, stratify=churned)
    auc = roc_auc_score(yte, LogisticRegression(max_iter=500).fit(Xtr, ytr).predict_proba(Xte)[:, 1])
    check("churn is learnable (logistic AUC > 0.70)", auc > 0.70, f"AUC {auc:.2f}")
    prof = sn.groupby("CUSTOMER_ID").PROFIT_GBP.sum()
    check("20-40% of customers unprofitable", 0.2 <= (prof < 0).mean() <= 0.4, f"{(prof < 0).mean():.0%} unprofitable")
    season = sn.assign(m=pd.to_datetime(sn.MONTH).dt.month).groupby("m").CARD_SPEND_GBP.mean()
    check("December spend peak", season.idxmax() == 12, f"Dec/Jan ratio {season[12] / season[1]:.2f}")
    fr = tx.IS_FRAUD.astype(bool)
    check("fraud rate 0.2-0.5%", 0.002 <= fr.mean() <= 0.005, f"{fr.mean():.2%}")
    ts = pd.to_datetime(tx.TXN_TS)
    tf = pd.DataFrame({"amt": tx.AMOUNT_GBP.abs(), "hour": ts.dt.hour, "foreign": (tx.MERCHANT_COUNTRY != "GB").astype(int),
                       "new_payee": tx.IS_NEW_PAYEE.astype(int), "online": tx.IS_ONLINE.astype(int)})
    score = -IsolationForest(n_estimators=100, random_state=1, contamination="auto").fit(tf).score_samples(tf)
    fauc = roc_auc_score(fr, score)
    check("fraud is detectable unsupervised (isolation forest AUC > 0.80)", fauc > 0.80, f"AUC {fauc:.2f}")

    log("Size (GitHub warns at 50 MB per file)")
    for f in sorted(OUT.glob("*.csv.gz")):
        mb = f.stat().st_size / 1e6
        check(f.name, mb < 50, f"{mb:.1f} MB")
    log("ALL CHECKS PASSED" if ok else "SOME CHECKS FAILED")
    return ok


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "prep"
    WORK.mkdir(parents=True, exist_ok=True)
    if stage == "validate":
        sys.exit(0 if validate() else 1)
    if stage == "generate":
        generate()
    if stage == "prep":
        fp = footprint()
        uprns(fp)
        pc = postcodes(fp)
        streets()
        census(pc)
