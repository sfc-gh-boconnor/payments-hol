"""Unstructured data for the retail banking data product: call centre transcripts, emails,
complaints, and a financial crime evidence pack (fraud cases, SAR narratives, disputes,
screenshots and police report PDFs).

Everything links to the RB_ tables (data/retail_bank): each record carries a real CUSTOMER_ID,
and where it fits an ACCOUNT_ID or TXN_ID, and its topic follows that customer's story - leavers
complain before they go, fraud victims call about their actual fraud, stretched customers ask
for help. The wording is written once by AI_COMPLETE from a facts sheet per record, then
committed, so attendees never pay to generate it.

  python build_retail_text.py facts      # facts and prompts -> data/retail_text/_prompts.csv.gz
  python build_retail_text.py generate   # AI_COMPLETE in Snowflake (snow connection, default hvennf)
  python build_retail_text.py tables     # rebuild the tables from _generated.csv.gz (no model calls)
  python build_retail_text.py evidence   # screenshots and PDFs -> data/retail_text/evidence/
  python build_retail_text.py validate   # text matches the facts, no real identifiers
"""
import gzip
import os
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

ROOT = Path(__file__).resolve().parents[2]
RB = ROOT / "data/retail_bank"
OUT = ROOT / "data/retail_text"
EVID = OUT / "evidence"
SEED = 20261121
AS_OF = pd.Timestamp("2026-11-20")
CONN = os.environ.get("RB_TEXT_CONNECTION", "hvennf")
MODEL = "claude-sonnet-4-5"
BANK = "the bank"  # generic: no real bank's name in the text

N_CALLS, N_EMAILS, N_COMPLAINTS, N_CASES, N_SARS, N_DISPUTES = 1000, 300, 200, 300, 60, 120


def log(*a):
    print(*a, flush=True)


def read(name):
    return pd.read_csv(RB / f"{name}.csv.gz", low_memory=False)


def money(x):
    return f"£{abs(float(x)):,.2f}"


STYLE = (f"Write in UK English. The bank is only ever called '{BANK}' (never a real bank name). "
         "Use only the names, amounts, dates and products in the facts; invent nothing else that identifies anyone. "
         "Never write account numbers, sort codes, card numbers, phone numbers, email addresses, postcodes, street addresses or dates of birth. "
         "Return only the requested text, no preamble.")


def transcript_prompt(f):
    return (f"Write a realistic call centre transcript between a bank agent and a retail customer, 12 to 22 turns, "
            f"each line starting 'AGENT:' or 'CUSTOMER:'. The call starts at {f['start']:%H:%M} on {f['start']:%A %d %B %Y}, so greet accordingly. "
            f"The agent introduces themself as {f['agent']}. Security: the agent says the customer has passed security checks; "
            f"never say a date of birth, address, postcode or any security answer. "
            f"Facts: customer {f['first']} {f['last']}, {f['age']}, lives in {f['city']}, home branch {f['branch']}. "
            f"Reason for the call: {f['reason']}. Details: {f['details']}. "
            f"Customer mood: {f['mood']}. Outcome: {f['outcome']}. {STYLE}")


def email_prompt(f):
    return (f"Write an email from a retail bank customer to {BANK}'s customer service, 80 to 180 words, with a subject line "
            f"on the first line as 'Subject: ...'. Facts: from {f['first']} {f['last']} in {f['city']}. Topic: {f['reason']}. "
            f"Details: {f['details']}. Tone: {f['mood']}. Sign off with the first name only. {STYLE}")


def complaint_prompt(f):
    return (f"Write a formal complaint a customer made to {BANK}, as the complaint handler logged it: 100 to 200 words, "
            f"first person from the customer, then a line 'Requested outcome: ...'. Facts: {f['first']} {f['last']}, {f['city']}. "
            f"Category: {f['reason']}. Details: {f['details']}. Tone: {f['mood']}. {STYLE}")


def case_prompt(f):
    return (f"Write fraud investigator case notes for a bank's fraud operations team: dated bullet entries (use the dates given), "
            f"120 to 220 words, covering the report, what the transactions show, contact with the customer, checks made, and the decision "
            f"with its reason. Facts: case {f['case_id']}, customer {f['first']} {f['last']} aged {f['age']}, fraud type {f['fraud_type']}. "
            f"Transactions: {f['details']}. Reported on {f['reported']}. Decision: {f['outcome']}. {STYLE}")


def sar_prompt(f):
    return (f"Write the narrative section of a Suspicious Activity Report a bank's money laundering reporting officer would file, "
            f"150 to 250 words, factual and neutral: who, what, when, why it is suspicious, and the action taken. Facts: subject account "
            f"holder {f['first']} {f['last']}, {f['city']}. Pattern: {f['reason']}. Activity: {f['details']}. Action: {f['outcome']}. "
            f"Refer to the subject by name, and to counterparties only by the payee names given. {STYLE}")


def dispute_prompt(f):
    return (f"Write a customer's card dispute (chargeback) statement, 60 to 140 words, first person. Facts: {f['first']} {f['last']}, "
            f"merchant {f['merchant']}, amount {f['amount']} on {f['date']}. Reason: {f['reason']}. Details: {f['details']}. {STYLE}")


def facts():
    rng = np.random.default_rng(SEED)
    fake = Faker("en_GB"); fake.seed_instance(SEED)
    cu, ac, tx = read("rb_customers"), read("rb_accounts"), read("rb_transactions")
    pr, em = read("rb_products"), read("rb_employment")
    # branch names are defined in setup/07 (SQL), so read them from the account
    import json
    out = subprocess.run(["snow", "sql", "-c", CONN, "--role", "HOL_ADMIN", "--format", "json", "-q",
                          "SELECT BRANCH_ID, BRANCH_NAME FROM BARCLAYS_HOL.RETAIL.BRANCHES"], capture_output=True, text=True, check=True).stdout
    br = pd.DataFrame(json.loads(out[out.index("["):]))
    cu = cu.merge(em[["CUSTOMER_ID", "EMPLOYER_NAME", "NET_MONTHLY_GBP"]], on="CUSTOMER_ID")
    cu = cu.merge(br, left_on="HOME_BRANCH_ID", right_on="BRANCH_ID", how="left")
    cu = cu.set_index("CUSTOMER_ID")
    held = ac.merge(pr[["PRODUCT_ID", "PRODUCT_NAME", "PRODUCT_FAMILY", "TIER"]], on="PRODUCT_ID")
    tx["TXN_TS"] = pd.to_datetime(tx.TXN_TS)
    agents = [fake.first_name() for _ in range(40)]
    rows = []

    def base(cid, kind, rid, when):
        c = cu.loc[cid]
        return {"kind": kind, "record_id": rid, "CUSTOMER_ID": cid, "first": c.FIRST_NAME, "last": c.LAST_NAME, "age": int(c.AGE),
                "city": c.CITY, "branch": c.BRANCH_NAME, "agent": rng.choice(agents), "ts": when, "ACCOUNT_ID": None, "TXN_ID": None}

    def when_before(end, lo, hi):
        return (pd.Timestamp(end) - pd.Timedelta(days=float(rng.uniform(lo, hi)))).floor("min")

    # ---- leavers: why they are going, in the weeks before CHURN_DATE
    leavers = cu[cu.CHURNED].copy()
    reasons = {
        "BETTER_RATE_ELSEWHERE": ("savings rate", "their {p} pays {r}% while other banks advertise over 4%; balance about {b}", "frustrated", "agent offers the current Rewards Saver rate; customer says they will think about moving"),
        "BRANCH_ACCESS": ("branch closure", "their branch {branch} is closing or hard to reach; they do not use the app and want to pay in cash and cheques", "upset, worried", "agent explains the nearest branch and the Post Office; customer is unhappy"),
        "SERVICE_COMPLAINTS": ("repeated service problems", "a payment was delayed and they have complained {n} times this year without a fix", "angry", "agent logs another complaint; customer mentions switching banks"),
        "EARLY_TENURE": ("switching offer", "they joined recently and have been offered a switching bonus by another bank", "matter-of-fact", "agent cannot match the offer; customer asks how to close the account"),
        "OTHER": ("closing the account", "they are moving in with a partner who banks elsewhere", "friendly", "agent explains the account closure process"),
    }
    for cid in leavers.sample(250, random_state=1).index:
        c = cu.loc[cid]
        topic, det, mood, outc = reasons.get(c.CHURN_REASON, reasons["OTHER"])
        sav = held[(held.CUSTOMER_ID == cid) & held.PRODUCT_FAMILY.eq("SAVINGS")]
        p = sav.PRODUCT_NAME.iat[0] if len(sav) else "savings account"
        r = sav.INTEREST_RATE_PCT.iat[0] if len(sav) else 1.0
        b = money(sav.BALANCE_GBP.iat[0]) if len(sav) else "a few thousand pounds"
        f = base(cid, "call", None, when_before(c.CHURN_DATE, 15, 75))
        f.update(reason=topic, details=det.format(p=p, r=r, b=b, branch=c.BRANCH_NAME, n=max(int(c.COMPLAINTS_12M), 2)), mood=mood, outcome=outc,
                 topic="ATTRITION_RISK", queue="RETENTION")
        rows.append(f)

    # ---- fraud victims: the call reporting their actual fraud
    fr = tx[tx.IS_FRAUD]
    victims = fr.groupby("CUSTOMER_ID").agg(FRAUD_TYPE=("FRAUD_TYPE", "first"), TXN_ID=("TXN_ID", "first"), ACCOUNT_ID=("ACCOUNT_ID", "first"),
                                            FIRST_TS=("TXN_TS", "min"), N=("TXN_ID", "size"), LOSS=("AMOUNT_GBP", lambda s: -s.sum()),
                                            MERCHANT=("MERCHANT", "first"))
    story = {
        "APP_SCAM": ("reporting a scam", "they were phoned by someone claiming to be from {BANK}'s fraud team and told to move money to a 'safe account'; {n} payments totalling {loss} to payee '{m}'", "distressed"),
        "ACCOUNT_TAKEOVER": ("payments they did not make", "{n} transfers totalling {loss} left the account overnight to a new payee they do not recognise; they had clicked a link in a text about a parcel", "panicked"),
        "CARD_TESTING": ("unknown card payments", "{n} small online card payments then one large one to '{m}', {loss} in total, which they did not make", "confused"),
        "IMPOSSIBLE_TRAVEL": ("card used abroad", "their card was used for {loss} in two countries an hour apart while they were at home in {city}", "alarmed"),
    }
    for cid, v in victims.sample(200, random_state=2).iterrows():
        topic, det, mood = story[v.FRAUD_TYPE]
        f = base(cid, "call", None, (v.FIRST_TS + pd.Timedelta(hours=float(rng.uniform(2, 40)))).floor("min"))
        f.update(reason=topic, details=det.format(BANK=BANK, n=int(v.N), loss=money(v.LOSS), m=v.MERCHANT, city=cu.loc[cid].CITY), mood=mood,
                 outcome="agent blocks the card or payee, opens a fraud case and explains next steps", topic="FRAUD_REPORT", queue="FRAUD",
                 ACCOUNT_ID=v.ACCOUNT_ID, TXN_ID=v.TXN_ID)
        rows.append(f)

    # ---- stretched customers: affordability and vulnerability
    stretched = cu[(cu.AFFORDABILITY_BAND == "STRETCHED") & ~cu.CHURNED]
    for cid in stretched.sample(150, random_state=3).index:
        c = cu.loc[cid]
        debt = held[(held.CUSTOMER_ID == cid) & held.PRODUCT_FAMILY.isin(["PERSONAL_LOAN", "MORTGAGE", "CREDIT_CARD"])]
        what = debt.PRODUCT_NAME.iat[0] if len(debt) else "their overdraft"
        f = base(cid, "call", None, when_before(AS_OF, 1, 85))
        f.update(reason="struggling with repayments", details=f"money is tight after rent or mortgage and bills; net pay about {money(c.NET_MONTHLY_GBP)} a month; worried about {what}",
                 mood="anxious, embarrassed" + (", mentions a health condition" if c.VULNERABLE_FLAG else ""),
                 outcome="agent offers a payment plan and signposts free debt advice", topic="FINANCIAL_DIFFICULTY", queue="COLLECTIONS")
        rows.append(f)

    # ---- everyday calls
    everyday = [
        ("fixed rate ending", "their {p} matures soon and they want to know the options", "calm", "agent explains new fixed rates", "PRODUCT_MATURITY", "SAVINGS"),
        ("lost card", "they lost their debit card on a night out", "slightly stressed", "agent cancels the card and orders a new one", "CARD_SERVICES", "CARDS"),
        ("app login problem", "they cannot log in to the app after changing phone", "impatient", "agent walks them through re-registering", "DIGITAL_SUPPORT", "DIGITAL"),
        ("mortgage overpayment", "they want to overpay their {p}", "friendly", "agent explains overpayment limits", "MORTGAGE_SERVICING", "MORTGAGES"),
        ("salary not arrived", "their pay from {e} has not arrived", "worried", "agent finds the payment is pending and due today", "PAYMENT_QUERY", "GENERAL"),
        ("change of address", "they have moved within {city}", "friendly", "agent updates the address after security checks", "ACCOUNT_ADMIN", "GENERAL"),
    ]
    pool = cu[~cu.CHURNED].sample(400, random_state=4).index
    for cid in pool:
        c = cu.loc[cid]
        topic, det, mood, outc, tag, q = everyday[int(rng.integers(len(everyday)))]
        hp = held[held.CUSTOMER_ID == cid]
        p = hp.PRODUCT_NAME.iat[int(rng.integers(len(hp)))] if len(hp) else "account"
        f = base(cid, "call", None, when_before(AS_OF, 1, 85))
        f.update(reason=topic, details=det.format(p=p, e=c.EMPLOYER_NAME if isinstance(c.EMPLOYER_NAME, str) else "their employer", city=c.CITY),
                 mood=mood, outcome=outc, topic=tag, queue=q)
        rows.append(f)

    calls = pd.DataFrame(rows)
    calls["record_id"] = [f"CALL{100000 + i}" for i in range(len(calls))]
    # calls happen in contact-centre hours (08:00-20:00), keeping the day from the story
    calls["start"] = (pd.to_datetime(calls.ts).dt.normalize() + pd.to_timedelta(rng.uniform(8, 19.5, len(calls)), unit="h")).dt.floor("s")
    late = calls.TXN_ID.notna() & (calls.start < pd.to_datetime(calls.ts))  # a fraud call can't come before the fraud
    calls.loc[late, "start"] = calls.loc[late, "start"] + pd.Timedelta(days=1)
    calls["prompt"] = calls.apply(transcript_prompt, axis=1)

    # ---- emails and complaints reuse the same stories with a different channel
    pick = calls.sample(N_EMAILS, random_state=5).copy()
    pick["kind"] = "email"; pick["record_id"] = [f"EML{100000 + i}" for i in range(len(pick))]
    pick["ts"] = pick.ts + pd.to_timedelta(rng.uniform(1, 6, len(pick)), unit="D")
    pick["prompt"] = pick.apply(email_prompt, axis=1)
    cat = {"ATTRITION_RISK": "SAVINGS_RATES", "FRAUD_REPORT": "FRAUD_REFUND", "FINANCIAL_DIFFICULTY": "ARREARS_HANDLING",
           "CARD_SERVICES": "CARDS", "DIGITAL_SUPPORT": "DIGITAL_SERVICES", "PRODUCT_MATURITY": "SAVINGS_RATES",
           "MORTGAGE_SERVICING": "MORTGAGES", "PAYMENT_QUERY": "PAYMENTS", "ACCOUNT_ADMIN": "SERVICE"}
    comp = calls[calls.topic.isin(["ATTRITION_RISK", "FRAUD_REPORT", "FINANCIAL_DIFFICULTY", "DIGITAL_SUPPORT", "PAYMENT_QUERY"])].sample(N_COMPLAINTS, random_state=6).copy()
    comp["kind"] = "complaint"; comp["record_id"] = [f"CMP{100000 + i}" for i in range(len(comp))]
    comp["reason"] = comp.topic.map(cat)
    comp["mood"] = "firm and formal"
    comp["ts"] = comp.ts + pd.to_timedelta(rng.uniform(2, 10, len(comp)), unit="D")
    comp["prompt"] = comp.apply(complaint_prompt, axis=1)

    # ---- financial crime: fraud cases, SAR narratives, disputes
    case_rows = []
    vic = victims.sample(N_CASES, random_state=7)
    decision = {"APP_SCAM": ["REIMBURSED_PSR_RULES", "PARTIAL_REIMBURSEMENT_GROSS_NEGLIGENCE", "REIMBURSED_PSR_RULES"],
                "ACCOUNT_TAKEOVER": ["REFUNDED_UNAUTHORISED", "REFUNDED_UNAUTHORISED", "DECLINED_CUSTOMER_SHARED_CODES"],
                "CARD_TESTING": ["REFUNDED_UNAUTHORISED"], "IMPOSSIBLE_TRAVEL": ["REFUNDED_UNAUTHORISED"]}
    for i, (cid, v) in enumerate(vic.iterrows()):
        lines = fr[fr.CUSTOMER_ID == cid].sort_values("TXN_TS")
        det = "; ".join(f"{t.TXN_TS:%d %b %Y %H:%M} {t.CHANNEL} {money(t.AMOUNT_GBP)} to {t.MERCHANT} ({t.MERCHANT_COUNTRY})" for t in lines.itertuples())
        f = base(cid, "case", f"FRC{100000 + i}", (v.FIRST_TS + pd.Timedelta(hours=float(rng.uniform(2, 40)))).floor("min"))
        dec = rng.choice(decision[v.FRAUD_TYPE])
        f.update(case_id=f["record_id"], fraud_type=v.FRAUD_TYPE, details=det, reported=f"{f['ts']:%d %b %Y}", outcome=dec.replace("_", " ").lower(),
                 decision=dec, loss=round(float(v.LOSS), 2), ACCOUNT_ID=v.ACCOUNT_ID, TXN_ID=v.TXN_ID, topic=v.FRAUD_TYPE)
        f["prompt"] = case_prompt(f)
        case_rows.append(f)
    cases = pd.DataFrame(case_rows)

    sar_rows = []
    ato = victims[victims.FRAUD_TYPE.isin(["ACCOUNT_TAKEOVER", "APP_SCAM"])].sample(N_SARS, random_state=8)
    patterns = ["funds received and moved on within minutes (possible money mule)", "multiple new payees set up overnight after a password reset",
                "authorised push payments to a payee reported by other banks", "rapid in-and-out transfers just under internal review thresholds"]
    for i, (cid, v) in enumerate(ato.iterrows()):
        lines = fr[fr.CUSTOMER_ID == cid]
        f = base(cid, "sar", f"SAR{100000 + i}", (v.FIRST_TS + pd.Timedelta(days=float(rng.uniform(3, 20)))).floor("min"))
        f.update(reason=rng.choice(patterns), details=f"{len(lines)} outbound payments totalling {money(v.LOSS)} on {v.FIRST_TS:%d %b %Y} to payee(s) {', '.join(sorted(set(lines.MERCHANT)))}",
                 outcome=rng.choice(["account restricted and SAR filed with the NCA", "SAR filed with the NCA; consent requested before releasing remaining funds", "relationship exited and SAR filed with the NCA"]),
                 ACCOUNT_ID=v.ACCOUNT_ID, TXN_ID=v.TXN_ID, topic="SAR")
        f["prompt"] = sar_prompt(f)
        sar_rows.append(f)
    sars = pd.DataFrame(sar_rows)

    disp_rows = []
    card = tx[tx.CHANNEL.eq("CARD") & tx.CATEGORY.isin(["RETAIL", "TRAVEL"]) & (tx.AMOUNT_GBP < -40)]
    ct = fr[fr.FRAUD_TYPE.eq("CARD_TESTING") & (fr.AMOUNT_GBP < -300)]
    dreasons = [("GOODS_NOT_RECEIVED", "the order never arrived and the merchant stopped replying"), ("DAMAGED_GOODS", "the item arrived broken; photos attached"),
                ("CANCELLED_BOOKING", "they cancelled the booking within the free cancellation period but were still charged; booking confirmation attached"),
                ("REFUND_NOT_PROCESSED", "the merchant promised a refund that never came; screenshot of the refund policy attached")]
    for i, t in enumerate(pd.concat([card.sample(N_DISPUTES - 30, random_state=9), ct.sample(30, random_state=10)]).itertuples()):
        fraud = bool(t.IS_FRAUD)
        if fraud:
            code, det = "UNAUTHORISED", "they did not make this payment and still have their card"
        elif t.CATEGORY == "TRAVEL":  # bookings only from travel merchants
            code, det = dreasons[2]
        else:
            code, det = [dreasons[0], dreasons[1], dreasons[3]][i % 3]
        f = base(t.CUSTOMER_ID, "dispute", f"DSP{100000 + i}", (t.TXN_TS + pd.Timedelta(days=float(rng.uniform(2, 20)))).floor("min"))
        f.update(merchant=t.MERCHANT, amount=money(t.AMOUNT_GBP), date=f"{t.TXN_TS:%d %b %Y}", reason=code.replace("_", " ").lower(), details=det,
                 dispute_reason=code, ACCOUNT_ID=t.ACCOUNT_ID, TXN_ID=t.TXN_ID, topic=code, loss=round(-float(t.AMOUNT_GBP), 2))
        f["prompt"] = dispute_prompt(f)
        disp_rows.append(f)
    disputes = pd.DataFrame(disp_rows)

    allp = pd.concat([calls, pick, comp, cases, sars, disputes], ignore_index=True)
    OUT.mkdir(parents=True, exist_ok=True)
    allp.to_csv(OUT / "_prompts.csv.gz", index=False, compression={"method": "gzip", "mtime": 0})
    log(f"facts: {allp.kind.value_counts().to_dict()} -> {OUT / '_prompts.csv.gz'}")


def snow(sql):
    r = subprocess.run(["snow", "sql", "-c", CONN, "--role", "HOL_ADMIN", "-q", sql], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(r.stdout[-2000:] + r.stderr[-2000:])
    return r.stdout


def generate(kind=None):
    """Run every prompt (or one kind: call, email, complaint, case, sar, dispute) through AI_COMPLETE, and download."""
    allp = pd.read_csv(OUT / "_prompts.csv.gz")
    p = allp if kind is None else allp[allp.kind == kind]
    tmp = OUT / "_prompts_upload.csv.gz"
    p[["record_id", "prompt"]].to_csv(tmp, index=False, compression={"method": "gzip", "mtime": 0})
    snow("USE WAREHOUSE BARCLAYS_WH; CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.SEED; CREATE STAGE IF NOT EXISTS BARCLAYS_HOL.SEED.RB_TEXT_GEN;")
    subprocess.run(["snow", "stage", "copy", str(tmp), "@BARCLAYS_HOL.SEED.RB_TEXT_GEN/in/", "--overwrite", "-c", CONN, "--role", "HOL_ADMIN"], check=True, capture_output=True)
    snow(f"""USE WAREHOUSE BARCLAYS_WH; USE SCHEMA BARCLAYS_HOL.SEED;
CREATE OR REPLACE TABLE RB_TEXT_OUT (RECORD_ID VARCHAR, TEXT VARCHAR);
CREATE OR REPLACE TABLE RB_TEXT_PROMPTS (RECORD_ID VARCHAR, PROMPT VARCHAR);
COPY INTO RB_TEXT_PROMPTS FROM @RB_TEXT_GEN/in/ FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP);
CREATE TABLE IF NOT EXISTS RB_TEXT_OUT (RECORD_ID VARCHAR, TEXT VARCHAR);
INSERT INTO RB_TEXT_OUT SELECT p.RECORD_ID, AI_COMPLETE('{MODEL}', p.PROMPT, {{'temperature': 0.7, 'max_tokens': 1400}})
  FROM RB_TEXT_PROMPTS p WHERE p.RECORD_ID NOT IN (SELECT RECORD_ID FROM RB_TEXT_OUT WHERE TEXT IS NOT NULL);
COPY INTO @RB_TEXT_GEN/out/text.csv.gz FROM (SELECT RECORD_ID, TEXT FROM RB_TEXT_OUT WHERE TEXT IS NOT NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY RECORD_ID ORDER BY RECORD_ID) = 1)
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP) HEADER = TRUE SINGLE = TRUE OVERWRITE = TRUE MAX_FILE_SIZE = 500000000;""")
    tmp.unlink()
    subprocess.run(["snow", "stage", "copy", "@BARCLAYS_HOL.SEED.RB_TEXT_GEN/out/text.csv.gz", str(OUT), "-c", CONN, "--role", "HOL_ADMIN"], check=True, capture_output=True)
    new = pd.read_csv(OUT / "text.csv.gz").rename(columns=str.upper)
    (OUT / "text.csv.gz").unlink()
    if kind is not None and (OUT / "_generated.csv.gz").exists():
        old = pd.read_csv(OUT / "_generated.csv.gz").rename(columns=str.upper)
        new = pd.concat([old[~old.RECORD_ID.isin(new.RECORD_ID)], new])
    new.to_csv(OUT / "_generated.csv.gz", index=False, compression={"method": "gzip", "mtime": 0})  # kept: `tables` rebuilds without the model
    tables()


def tables():
    gen = pd.read_csv(OUT / "_generated.csv.gz").rename(columns=str.upper)
    write_tables(pd.read_csv(OUT / "_prompts.csv.gz"), gen.set_index("RECORD_ID").TEXT)


PHONE = re.compile(r"\b0\d{3,4}\s?\d{3}\s?\d{3,4}\b|\+44[\d ]{9,13}")


def clean(t):
    t = re.sub(r"\n{3,}", "\n\n", str(t).strip().strip('"'))
    t = PHONE.sub("[number removed]", t)
    t = re.sub(r"\b\d{8}\b|\b\d{2}-\d{2}-\d{2}\b|\b(?:\d[ -]?){13,16}\b", "[number removed]", t)  # account, sort code, card
    return re.sub(r"\b[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}\b", "[postcode removed]", t)


def write_tables(p, text):
    p = p.assign(TEXT=p.record_id.map(text).map(clean), ts=pd.to_datetime(p.ts))
    missing = p.TEXT.isin(["nan", ""]).sum()
    if missing:
        log(f"warning: {missing} prompts have no text yet; rerun generate")
    gz = {"method": "gzip", "compresslevel": 9, "mtime": 0}
    c = p[p.kind == "call"].copy()
    c["start"] = pd.to_datetime(c.start)
    dur = (c.TEXT.str.count("\n") * 22 + 60).astype(int)
    c["end"] = c.start + pd.to_timedelta(dur, unit="s")
    header = ("Call " + c.record_id + " | " + c.start.dt.strftime("%d %b %Y") + " | " + c.start.dt.strftime("%H:%M:%S") + " to "
              + c.end.dt.strftime("%H:%M:%S") + " | queue " + c.queue + " | agent " + c.agent + "\n\n")
    calls = pd.DataFrame({"CALL_ID": c.record_id, "CUSTOMER_ID": c.CUSTOMER_ID, "ACCOUNT_ID": c.ACCOUNT_ID, "TXN_ID": c.TXN_ID,
                          "CALL_START_TS": c.start, "CALL_END_TS": c.end, "DURATION_S": dur, "QUEUE": c.queue,
                          "AGENT_FIRST_NAME": c.agent, "TOPIC": c.topic, "TRANSCRIPT": header + c.TEXT})
    e = p[p.kind == "email"]
    subj = e.TEXT.str.extract(r"^Subject:\s*(.*)$", flags=re.M)[0]
    emails = pd.DataFrame({"EMAIL_ID": e.record_id, "CUSTOMER_ID": e.CUSTOMER_ID, "RECEIVED_TS": e.ts, "SUBJECT": subj,
                           "BODY": e.TEXT.str.replace(r"^Subject:.*\n+", "", regex=True), "TOPIC": e.topic})
    k = p[p.kind == "complaint"]
    status = np.where(k.ts > AS_OF - pd.Timedelta(days=20), "OPEN", np.where(k.record_id.str[-1].isin(list("0123")), "UPHELD", np.where(k.record_id.str[-1].isin(list("45")), "PARTIALLY_UPHELD", "NOT_UPHELD")))
    complaints = pd.DataFrame({"COMPLAINT_ID": k.record_id, "CUSTOMER_ID": k.CUSTOMER_ID, "RECEIVED_TS": k.ts, "CATEGORY": k.reason,
                               "STATUS": status, "REDRESS_GBP": np.where(status == "UPHELD", 150.0, np.where(status == "PARTIALLY_UPHELD", 50.0, 0.0)),
                               "COMPLAINT_TEXT": k.TEXT})
    f = p[p.kind == "case"]
    cases = pd.DataFrame({"CASE_ID": f.record_id, "CUSTOMER_ID": f.CUSTOMER_ID, "ACCOUNT_ID": f.ACCOUNT_ID, "FIRST_FRAUD_TXN_ID": f.TXN_ID,
                          "FRAUD_TYPE": f.fraud_type, "REPORTED_TS": f.ts, "LOSS_GBP": f.loss, "DECISION": f.decision,
                          "STATUS": "CLOSED", "INVESTIGATOR_NOTES": f.TEXT})
    s = p[p.kind == "sar"]
    sars = pd.DataFrame({"SAR_ID": s.record_id, "CUSTOMER_ID": s.CUSTOMER_ID, "ACCOUNT_ID": s.ACCOUNT_ID, "FILED_TS": s.ts,
                         "PATTERN": s.reason, "ACTION": s.outcome, "NARRATIVE": s.TEXT})
    d = p[p.kind == "dispute"]
    disputes = pd.DataFrame({"DISPUTE_ID": d.record_id, "CUSTOMER_ID": d.CUSTOMER_ID, "ACCOUNT_ID": d.ACCOUNT_ID, "TXN_ID": d.TXN_ID,
                             "OPENED_TS": d.ts, "MERCHANT": d.merchant, "AMOUNT_GBP": d.loss, "REASON_CODE": d.dispute_reason,
                             "CUSTOMER_STATEMENT": d.TEXT})
    for name, df in {"rb_call_transcripts": calls, "rb_emails": emails, "rb_complaints": complaints, "rb_fraud_cases": cases,
                     "rb_sar_narratives": sars, "rb_disputes": disputes}.items():
        path = OUT / f"{name}.csv.gz"
        df.to_csv(path, index=False, compression=gz)
        log(f"  {path.relative_to(ROOT)}: {len(df):,} rows, {path.stat().st_size / 1e6:.2f} MB")


# ---- evidence files (no AI: drawn from the facts, so every detail is checkable)

def evidence():
    from PIL import Image, ImageDraw, ImageFont
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    rng = np.random.default_rng(SEED + 1)
    cases, disputes = pd.read_csv(OUT / "rb_fraud_cases.csv.gz"), pd.read_csv(OUT / "rb_disputes.csv.gz")
    cu = read("rb_customers").set_index("CUSTOMER_ID")
    EVID.mkdir(parents=True, exist_ok=True)
    for f in EVID.glob("*"):
        f.unlink()

    def font(size, bold=False):
        for n in (["Arial Bold.ttf", "Helvetica-Bold.ttf"] if bold else ["Arial.ttf", "Helvetica.ttc"]):
            for d in ("/System/Library/Fonts/Supplemental", "/System/Library/Fonts", "/Library/Fonts"):
                if Path(d, n).exists():
                    return ImageFont.truetype(str(Path(d, n)), size)
        return ImageFont.load_default()

    def watermark(img):
        d = ImageDraw.Draw(img)
        d.text((12, img.height - 26), "SYNTHETIC - TRAINING DATA", fill=(200, 40, 40), font=font(14, True))
        return img

    index = []
    # Phishing texts submitted by APP scam and account takeover victims
    lures = {"ACCOUNT_TAKEOVER": ["Royal Parcel: your parcel is held, a £1.99 redelivery fee is due. Pay at parcel-redeliver-uk.info",
                                  "We could not deliver your parcel. Reschedule now: uk-delivery-help.com/track"],
             "APP_SCAM": ["THE BANK: a new payee was added to your account. If this was NOT you call us on the number we will text you.",
                          "HMRC: you are owed a tax refund of £326.40. Claim before midnight: hmrc-refund-claims.co"]}
    first_ts = pd.to_datetime(read("rb_transactions").set_index("TXN_ID").TXN_TS)
    phish = cases[cases.FRAUD_TYPE.isin(lures)].head(40)
    for r in phish.itertuples():
        img = Image.new("RGB", (420, 640), (242, 242, 247))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 420, 70], fill=(250, 250, 252)); d.text((150, 25), "Messages", fill=(0, 0, 0), font=font(20, True))
        sent = first_ts[r.FIRST_FRAUD_TXN_ID] - pd.Timedelta(hours=float(rng.uniform(6, 72)))  # the lure comes before the fraud
        d.text((20, 90), "Text message, " + sent.strftime("%d %b %H:%M"), fill=(120, 120, 120), font=font(13))
        msg = rng.choice(lures[r.FRAUD_TYPE])
        words, lines, cur = msg.split(), [], ""
        for w in words:
            if len(cur) + len(w) > 34:
                lines.append(cur); cur = w
            else:
                cur = f"{cur} {w}".strip()
        lines.append(cur)
        d.rounded_rectangle([18, 115, 380, 130 + 24 * len(lines)], radius=18, fill=(229, 229, 234))
        for i, l in enumerate(lines):
            d.text((32, 123 + 24 * i), l, fill=(0, 0, 0), font=font(17))
        name = f"{r.CASE_ID}_phishing_sms.png"
        watermark(img).save(EVID / name, optimize=True)
        index.append((name, "PHISHING_SCREENSHOT", r.CASE_ID, None, r.CUSTOMER_ID, sent.floor("min")))

    # Police report PDFs for APP scams and account takeovers
    for i, r in enumerate(cases[cases.FRAUD_TYPE.isin(["APP_SCAM", "ACCOUNT_TAKEOVER"])].head(50).itertuples()):
        c = cu.loc[r.CUSTOMER_ID]
        ref = f"NFRC{pd.Timestamp(r.REPORTED_TS):%y%m}{100000 + i}"
        name = f"{r.CASE_ID}_police_report.pdf"
        pdf = canvas.Canvas(str(EVID / name), pagesize=A4, invariant=1)
        w, h = A4
        pdf.setFont("Helvetica-Bold", 16); pdf.drawString(50, h - 60, "Fraud and Cyber Crime Report - Crime Reference Confirmation")
        pdf.setFont("Helvetica", 11)
        lines = [f"Crime reference number: {ref}", f"Date reported: {pd.Timestamp(r.REPORTED_TS) + pd.Timedelta(days=1):%d %B %Y}",
                 f"Reported by: {c.FIRST_NAME} {c.LAST_NAME}", f"Town: {c.CITY}",
                 f"Offence: {'Authorised push payment fraud (impersonation)' if r.FRAUD_TYPE == 'APP_SCAM' else 'Unauthorised access to a bank account'}",
                 f"Amount lost: {money(r.LOSS_GBP)}", "Financial institution: the bank (retail current account)",
                 "Summary: the victim reports payments made from their account as described to the bank's fraud team.",
                 "This report has been passed to the National Fraud Intelligence Bureau for assessment."]
        for k, l in enumerate(lines):
            pdf.drawString(50, h - 110 - 22 * k, l)
        pdf.setFillColorRGB(0.8, 0.15, 0.15); pdf.setFont("Helvetica-Bold", 12)
        pdf.drawString(50, 50, "SYNTHETIC - TRAINING DATA. Not a real police document.")
        pdf.save()
        index.append((name, "POLICE_REPORT_PDF", r.CASE_ID, None, r.CUSTOMER_ID, (pd.Timestamp(r.REPORTED_TS) + pd.Timedelta(days=1)).normalize()))

    # Dispute evidence: booking confirmations, refund policies, damaged goods
    for r in disputes[disputes.REASON_CODE.isin(["CANCELLED_BOOKING", "REFUND_NOT_PROCESSED", "DAMAGED_GOODS"])].head(60).itertuples():
        img = Image.new("RGB", (640, 420), (255, 255, 255))
        d = ImageDraw.Draw(img)
        if r.REASON_CODE == "CANCELLED_BOOKING":
            d.rectangle([0, 0, 640, 60], fill=(0, 53, 128)); d.text((20, 18), f"{r.MERCHANT} - Booking confirmation", fill="white", font=font(20, True))
            for k, l in enumerate([f"Guest: {cu.loc[r.CUSTOMER_ID].FIRST_NAME} {cu.loc[r.CUSTOMER_ID].LAST_NAME}", f"Total paid: {money(r.AMOUNT_GBP)}",
                                   "Free cancellation until 48 hours before arrival", f"Cancelled on: {pd.Timestamp(r.OPENED_TS) - pd.Timedelta(days=5):%d %b %Y}",
                                   "Cancellation status: CONFIRMED - refund due"]):
                d.text((30, 90 + 40 * k), l, fill=(30, 30, 30), font=font(18))
            kind = "BOOKING_CONFIRMATION"
        elif r.REASON_CODE == "REFUND_NOT_PROCESSED":
            d.text((30, 30), f"{r.MERCHANT} - Returns and refunds", fill=(0, 0, 0), font=font(22, True))
            for k, l in enumerate(["We refund returned items within 14 days of receiving them.", "Refunds go back to the original payment card.",
                                   "You will receive an email when your refund is processed.", f"Your return was received: {pd.Timestamp(r.OPENED_TS) - pd.Timedelta(days=30):%d %b %Y}"]):
                d.text((30, 90 + 40 * k), l, fill=(40, 40, 40), font=font(17))
            kind = "REFUND_POLICY_SCREENSHOT"
        else:  # a simple illustration of a damaged parcel, not a photo
            d.rectangle([170, 110, 470, 330], fill=(196, 150, 100), outline=(120, 80, 40), width=4)
            d.line([(170, 180), (470, 180)], fill=(150, 110, 70), width=3)
            d.line([(300, 110), (340, 200), (310, 260), (360, 330)], fill=(60, 30, 10), width=6)
            d.polygon([(380, 250), (440, 230), (430, 300)], fill=(90, 90, 90))
            d.text((30, 30), f"Item from {r.MERCHANT} as delivered", fill=(0, 0, 0), font=font(20, True))
            kind = "DAMAGED_GOODS_PHOTO"
        name = f"{r.DISPUTE_ID}_{kind.lower()}.png"
        watermark(img).save(EVID / name, optimize=True)
        index.append((name, kind, None, r.DISPUTE_ID, r.CUSTOMER_ID, pd.Timestamp(r.OPENED_TS)))

    idx = pd.DataFrame(index, columns=["FILE_NAME", "EVIDENCE_TYPE", "CASE_ID", "DISPUTE_ID", "CUSTOMER_ID", "EVIDENCE_DATE"])
    idx.to_csv(OUT / "rb_evidence_files.csv.gz", index=False, compression={"method": "gzip", "mtime": 0})
    size = sum(f.stat().st_size for f in EVID.glob("*")) / 1e6
    log(f"evidence: {len(idx)} files, {size:.1f} MB; index {idx.EVIDENCE_TYPE.value_counts().to_dict()}")


def validate():
    ok = True

    def check(name, cond, detail=""):
        nonlocal ok
        ok &= bool(cond)
        log(f"  [{'ok' if cond else 'FAIL'}] {name} {detail}")

    p = pd.read_csv(OUT / "_prompts.csv.gz")
    cu = read("rb_customers").set_index("CUSTOMER_ID")
    tx = read("rb_transactions").set_index("TXN_ID")
    t = {n: pd.read_csv(OUT / f"{n}.csv.gz") for n in ["rb_call_transcripts", "rb_emails", "rb_complaints", "rb_fraud_cases", "rb_sar_narratives", "rb_disputes"]}
    text_col = {"rb_call_transcripts": "TRANSCRIPT", "rb_emails": "BODY", "rb_complaints": "COMPLAINT_TEXT", "rb_fraud_cases": "INVESTIGATOR_NOTES",
                "rb_sar_narratives": "NARRATIVE", "rb_disputes": "CUSTOMER_STATEMENT"}
    log("Links to the retail customers")
    for n, df in t.items():
        check(f"{n}: every CUSTOMER_ID is in RB_CUSTOMERS", df.CUSTOMER_ID.isin(cu.index).all(), f"{len(df):,} rows")
        check(f"{n}: every row has text", df[text_col[n]].fillna("").str.len().gt(40).all())
    for n, col in [("rb_call_transcripts", "TXN_ID"), ("rb_fraud_cases", "FIRST_FRAUD_TXN_ID"), ("rb_disputes", "TXN_ID")]:
        ids = t[n][col].dropna()
        check(f"{n}: every {col} is in RB_TRANSACTIONS", ids.isin(tx.index).all(), f"{len(ids):,} linked")
    fc = t["rb_fraud_cases"]
    check("fraud cases are on transactions labelled fraud", tx.loc[fc.FIRST_FRAUD_TXN_ID, "IS_FRAUD"].all())
    leave = t["rb_call_transcripts"][t["rb_call_transcripts"].TOPIC.eq("ATTRITION_RISK")]
    churn = pd.to_datetime(leave.CUSTOMER_ID.map(cu.CHURN_DATE))
    check("retention calls come before the customer leaves", (pd.to_datetime(leave.CALL_START_TS) < churn).all(), f"{len(leave)} calls")
    ct = t["rb_call_transcripts"]
    st, en = pd.to_datetime(ct.CALL_START_TS), pd.to_datetime(ct.CALL_END_TS)
    check("calls have a start and end time in contact-centre hours", (en > st).all() and st.dt.hour.between(8, 20).all())
    check("transcripts open with their date and time", (ct.TRANSCRIPT.str[:80].str.contains(r"\d{2}:\d{2}:\d{2} to")).all())
    fr_calls = ct[ct.TXN_ID.notna()]
    first_fraud = pd.to_datetime(tx.loc[fr_calls.TXN_ID, "TXN_TS"]).to_numpy()
    check("fraud report calls come after the fraud", (pd.to_datetime(fr_calls.CALL_END_TS).dt.normalize().to_numpy() >= pd.to_datetime(first_fraud).normalize()).all())

    log("Text matches the facts")
    for n in ["rb_call_transcripts", "rb_emails", "rb_sar_narratives", "rb_fraud_cases"]:  # complaints and disputes are first-person
        df = t[n]
        first = df.CUSTOMER_ID.map(cu.FIRST_NAME)
        hit = [f in str(x) for f, x in zip(first, df[text_col[n]])]
        check(f"{n}: names the customer", np.mean(hit) > (0.6 if n == "rb_fraud_cases" else 0.85), f"{np.mean(hit):.0%}")
    amt = fc.apply(lambda r: f"{abs(r.LOSS_GBP):,.2f}" in str(r.INVESTIGATOR_NOTES) or f"{abs(r.LOSS_GBP):,.0f}" in str(r.INVESTIGATOR_NOTES), axis=1).mean()
    check("fraud case notes quote the loss or the transactions", amt > 0.5 or fc.INVESTIGATOR_NOTES.str.contains("£").mean() > 0.95, f"{amt:.0%} quote the exact total")
    log("No real identifiers")
    allt = pd.concat([t[n][text_col[n]] for n in t]).fillna("")
    bank = allt.str.contains(r"\b(?:Barclays|HSBC|Lloyds|NatWest|Santander|Halifax|Nationwide|Monzo|Starling)\b", case=False).sum()
    check("no real bank names in the text", bank == 0, f"{bank} mentions")
    acct = allt.str.contains(r"\b\d{8}\b|\b\d{2}-\d{2}-\d{2}\b|\b(?:\d[ -]?){13,16}\b").sum()
    check("no account, sort code or card numbers", acct == 0, f"{acct} rows")
    phone = allt.str.contains(PHONE).sum()
    check("no phone numbers", phone == 0, f"{phone} rows")
    mail = allt.str.contains(r"[\w.]+@[\w-]+\.\w+").sum()
    pcs = set(cu.POSTCODE.str.replace(" ", ""))
    found = allt.str.findall(r"\b[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}\b").explode().dropna().str.replace(" ", "")
    check("no invented postcodes (only the customer's own)", found.isin(pcs).all(), f"{(~found.isin(pcs)).sum()} invented")
    dob = allt.str.contains(r"(?i)(born|date of birth)[^.\n]{0,30}(19|20)\d{2}|nineteen (?:forty|fifty|sixty|seventy|eighty|ninety)").sum()
    check("no dates of birth spoken", dob == 0, f"{dob} rows")
    check("no email addresses", mail == 0, f"{mail} rows")
    if (OUT / "rb_evidence_files.csv.gz").exists():
        ev = pd.read_csv(OUT / "rb_evidence_files.csv.gz")
        check("every evidence file exists", all((EVID / f).exists() for f in ev.FILE_NAME), f"{len(ev)} files")
        check("evidence links to a case or dispute", (ev.CASE_ID.isin(fc.CASE_ID) | ev.DISPUTE_ID.isin(t["rb_disputes"].DISPUTE_ID)).all())
    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file() and not f.name.startswith("_")) / 1e6
    check("text and evidence under 25 MB", size < 25, f"{size:.1f} MB")
    log("ALL CHECKS PASSED" if ok else "SOME CHECKS FAILED")
    return ok


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "validate"
    fn = {"facts": facts, "generate": generate, "tables": tables, "evidence": evidence, "validate": validate}[stage]
    fn(*sys.argv[2:3])
