"""Build RB_NAME_MENTIONS: people named in outside records, written the way
those records really spell them, for the AI5 fuzzy name matching step.

Each mention is a fraud victim, a mule account holder or a dispute claimant
as written by a police force, another bank, a dispute form or a watchlist:
nicknames, typos, initials, swapped order, alternate surname spellings,
day and month swapped in the date of birth. TRUE_CUSTOMER_ID is the answer key
(NULL for people who aren't customers) and VARIATION says what was changed.

Deterministic (no AI): run from the repo root with the data venv,
    python setup/tools/build_name_mentions.py
and commit data/retail_text/rb_name_mentions.csv.gz. LOAD_LAB_DATA loads it.
"""
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

ROOT = Path(__file__).resolve().parents[2]
RB = ROOT / "data/retail_bank"
OUT = ROOT / "data/retail_text"
SEED = 20261122

NICKNAMES = {
    "Elizabeth": ["Liz", "Beth", "Lizzie", "Betty"], "William": ["Bill", "Will", "Billy"], "Robert": ["Bob", "Rob", "Bobby"],
    "Margaret": ["Maggie", "Peggy", "Meg"], "James": ["Jim", "Jimmy", "Jamie"], "Katherine": ["Kate", "Kathy", "Katie"],
    "Catherine": ["Cath", "Cathy", "Kate"], "Richard": ["Rick", "Dick", "Richie"], "Thomas": ["Tom", "Tommy"],
    "Michael": ["Mike", "Mick"], "Christopher": ["Chris", "Kit"], "Jennifer": ["Jen", "Jenny"], "Daniel": ["Dan", "Danny"],
    "Matthew": ["Matt"], "Anthony": ["Tony"], "Joseph": ["Joe", "Joey"], "Samuel": ["Sam"], "Samantha": ["Sam", "Sammy"],
    "Alexander": ["Alex", "Sandy"], "Alexandra": ["Alex", "Sasha"], "Patricia": ["Pat", "Trish"], "Susan": ["Sue", "Susie"],
    "Deborah": ["Debbie", "Deb"], "Rebecca": ["Becky", "Becca"], "Victoria": ["Vicky", "Tori"], "Jonathan": ["Jon", "Johnny"],
    "John": ["Jack", "Johnny"], "Edward": ["Ed", "Eddie", "Ted"], "Andrew": ["Andy", "Drew"], "Stephen": ["Steve"],
    "Steven": ["Steve"], "Benjamin": ["Ben"], "Nicholas": ["Nick"], "Charlotte": ["Lottie", "Charlie"], "Eleanor": ["Ellie", "Nell"],
    "Frederick": ["Fred", "Freddie"], "Harold": ["Harry"], "Henry": ["Harry", "Hal"], "Gregory": ["Greg"], "Peter": ["Pete"],
    "David": ["Dave", "Davy"], "Timothy": ["Tim"], "Philip": ["Phil"], "Kenneth": ["Ken", "Kenny"], "Ronald": ["Ron", "Ronnie"],
    "Dorothy": ["Dot", "Dottie"], "Judith": ["Judy"], "Christine": ["Chris", "Chrissie"], "Pamela": ["Pam"], "Gillian": ["Gill"],
    "Josephine": ["Jo", "Josie"], "Joanne": ["Jo"], "Abigail": ["Abby"], "Jessica": ["Jess"], "Natalie": ["Nat"],
    "Oliver": ["Ollie"], "Isabella": ["Bella", "Izzy"], "Sophia": ["Sophie"], "Gabriel": ["Gabe"], "Zachary": ["Zac"],
}
SURNAME_SPELLINGS = [("son", "sen"), ("ey", "y"), ("ie", "y"), ("ph", "f"), ("Mac", "Mc"), ("Mc", "Mac"), ("ll", "l"),
                     ("tt", "t"), ("nn", "n"), ("ck", "k"), ("Th", "T"), ("ou", "ow"), ("ei", "ie"), ("ae", "e")]
SOURCES = {"POLICE_REPORT": "victim named in an Action Fraud crime report",
           "BANK_REFERRAL": "account holder named by another bank in a mule referral",
           "DISPUTE_FORM": "claimant on a paper card dispute form",
           "WATCHLIST": "name on the internal financial crime watchlist"}


def typo(s, rng):
    if len(s) < 4:
        return s
    i = int(rng.integers(1, len(s) - 1))
    op = rng.choice(["swap", "drop", "double", "vowel"])
    if op == "swap":
        return s[:i] + s[i + 1] + s[i] + s[i + 2:]
    if op == "drop":
        return s[:i] + s[i + 1:]
    if op == "double":
        return s[:i] + s[i] + s[i:]
    vowels = "aeiou"
    j = next((k for k in range(i, len(s)) if s[k] in vowels), None)
    return s if j is None else s[:j] + rng.choice([v for v in vowels if v != s[j]]) + s[j + 1:]


def respell(last, rng):
    for a, b in rng.permutation(SURNAME_SPELLINGS).tolist():
        if a in last:
            return last.replace(a, b, 1)
    return typo(last, rng)


def vary(first, last, dob, rng):
    """One realistic variation of a name and date of birth, and what was changed."""
    dob_s = f"{dob:%d/%m/%Y}"
    options = ["EXACT", "TYPO", "INITIAL", "REVERSED", "SURNAME_SPELLING"]
    if first in NICKNAMES:
        options += ["NICKNAME", "NICKNAME"]
    if dob.day <= 12 and dob.day != dob.month:
        options.append("DOB_DAY_MONTH_SWAPPED")
    v = rng.choice(options)
    name = f"{first} {last}"
    if v == "TYPO":
        name = f"{typo(first, rng)} {last}" if rng.random() < 0.5 else f"{first} {typo(last, rng)}"
    elif v == "INITIAL":
        name = f"{first[0]}. {last}"
    elif v == "REVERSED":
        name = f"{last.upper()}, {first}"
    elif v == "SURNAME_SPELLING":
        name = f"{first} {respell(last, rng)}"
    elif v == "NICKNAME":
        name = f"{rng.choice(NICKNAMES[first])} {last}"
    elif v == "DOB_DAY_MONTH_SWAPPED":
        dob_s = f"{dob:%m/%d/%Y}"
    if rng.random() < 0.25:            # some records shout the whole name
        name = name.upper()
    return name, dob_s, v


def main():
    rng = np.random.default_rng(SEED)
    fake = Faker("en_GB")
    Faker.seed(SEED)
    cu = pd.read_csv(RB / "rb_customers.csv.gz", parse_dates=["DATE_OF_BIRTH"], low_memory=False)
    tx = pd.read_csv(RB / "rb_transactions.csv.gz", usecols=["CUSTOMER_ID", "IS_FRAUD"], low_memory=False)
    victims = tx.loc[tx.IS_FRAUD.astype(str).str.lower().isin(["true", "1"]), "CUSTOMER_ID"].drop_duplicates()
    # mostly fraud victims, plus other customers, so matches aren't only in one small group
    pool = pd.concat([cu[cu.CUSTOMER_ID.isin(victims)].sample(160, random_state=SEED),
                      cu[~cu.CUSTOMER_ID.isin(victims)].sample(80, random_state=SEED)])
    rows = []
    for c in pool.itertuples():
        name, dob, v = vary(c.FIRST_NAME, c.LAST_NAME, c.DATE_OF_BIRTH, rng)
        src = rng.choice(list(SOURCES), p=[0.4, 0.25, 0.25, 0.1])
        town = c.CITY if rng.random() < 0.85 else None          # not every record has a town
        rows.append((src, name, dob if rng.random() < 0.8 else None, town, c.CUSTOMER_ID, v))
    # people who aren't customers: some share a surname and town with a customer, to make it harder
    for i in range(60):
        if i < 25:
            c = cu.sample(1, random_state=SEED + i).iloc[0]
            first = fake.first_name_female() if c.SEX == "F" else fake.first_name_male()
            name, town = f"{first} {c.LAST_NAME}", c.CITY
        else:
            name, town = fake.name(), rng.choice(cu.CITY.unique())
        dob = fake.date_of_birth(minimum_age=18, maximum_age=90)
        rows.append((rng.choice(list(SOURCES)), name.upper() if rng.random() < 0.25 else name,
                     f"{dob:%d/%m/%Y}" if rng.random() < 0.8 else None, town, None, "NOT_A_CUSTOMER"))
    df = pd.DataFrame(rows, columns=["SOURCE", "NAME_AS_WRITTEN", "DOB_AS_WRITTEN", "TOWN", "TRUE_CUSTOMER_ID", "VARIATION"])
    df = df.sample(frac=1, random_state=SEED).reset_index(drop=True)
    df.insert(0, "MENTION_ID", [f"NM{100000 + i}" for i in range(len(df))])
    df.insert(2, "SOURCE_DESCRIPTION", df.SOURCE.map(SOURCES))
    df.to_csv(OUT / "rb_name_mentions.csv.gz", index=False, compression="gzip")
    print(f"rb_name_mentions: {len(df)} rows", df.VARIATION.value_counts().to_dict())


if __name__ == "__main__":
    main()
