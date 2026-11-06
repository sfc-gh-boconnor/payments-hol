"""DE3 reference: stream payment events through Snowflake Postgres into Snowflake-managed Iceberg.

Run in the DE3 Workspace notebook (role HOL_PARTICIPANT, external access
HOL_NOTEBOOK_ACCESS_INTEGRATION on) after `pip install psycopg2-binary`.

  1. create_postgres(session)    creates HOL_PAYMENTS_PG and saves its one-time admin password
                                 straight into BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET (never printed).
                                 The Lab Companion's "Reveal Postgres connection" reads it back.
  2. connect(host, user, password) / create_source_table(conn)
  3. start_mirror(session)       Data Mirroring: Postgres -> Snowflake-managed Iceberg,
                                 PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS (+ $live, $changes)
  4. stream_payments(conn)       a live feed of payment events, with an incident in the second half:
                                 one corporate client's SEPA payments start failing with
                                 "Beneficiary bank unavailable".

Snowpipe Streaming isn't used here: Workspace notebooks run in Snowpark Container Services,
where its key-pair sign-in is rejected (error 395090). See de3_stream.py for that SDK.
"""
import datetime
import json
import random
import time
import uuid

INSTANCE = "HOL_PAYMENTS_PG"
SECRET = "BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET"
POLICY = "HOL_PG_POLICY"
MIRROR = "payments_mirror"
TARGET_DB = "PAYMENTS_MIRROR"
PG_SCHEMA = "payments"
ADMIN_USER = "snowflake_admin"
SCHEMES = ["FASTER_PAYMENTS", "BACS", "CHAPS", "SEPA", "SWIFT"]


def _sql_literal(value):
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def _row(row):
    return row.as_dict() if hasattr(row, "as_dict") else dict(row)


def _admin_password(result):
    """The snowflake_admin password from a CREATE or RESET ACCESS result (never print it)."""
    data = _row(result[0])
    data = {k.lower(): v for k, v in data.items()}
    if data.get("password"):
        return data["password"]
    roles = data.get("access_roles")
    if isinstance(roles, str):
        roles = json.loads(roles)
    if isinstance(roles, dict):
        return roles.get(ADMIN_USER)
    for role in roles or []:
        if role.get("name") == ADMIN_USER:
            return role.get("password")
    raise ValueError("No snowflake_admin password in the result")


def _save_password(session, password):
    session.sql(f"ALTER SECRET {SECRET} SET USERNAME = '{ADMIN_USER}' PASSWORD = {_sql_literal(password)}").collect()


def instance_state(session):
    rows = session.sql(f"SHOW POSTGRES INSTANCES LIKE '{INSTANCE}'").collect()
    return _row(rows[0]) if rows else None


def wait_ready(session, timeout_s=600):
    """Wait until the instance is READY (creation takes 2 to 5 minutes); returns its host."""
    start = time.time()
    while time.time() - start < timeout_s:
        info = instance_state(session)
        state = (info or {}).get("state")
        if state == "READY":
            return info["host"]
        print(f"{INSTANCE}: {state or 'not visible yet'} ({int(time.time() - start)} s)")
        time.sleep(20)
    raise TimeoutError(f"{INSTANCE} isn't READY after {timeout_s} s")


def create_postgres(session):
    """Create HOL_PAYMENTS_PG (STANDARD_M, the smallest size Data Mirroring supports) and save its password."""
    if instance_state(session):
        print(f"{INSTANCE} already exists. If its password was lost, run reset_password(session).")
        return wait_ready(session)
    result = session.sql(f"""CREATE POSTGRES INSTANCE {INSTANCE}
        COMPUTE_FAMILY = 'STANDARD_M' STORAGE_SIZE_GB = 10
        AUTHENTICATION_AUTHORITY = POSTGRES POSTGRES_VERSION = 18
        NETWORK_POLICY = '{POLICY}'
        COMMENT = 'DE3: operational payments database streamed into Snowflake'""").collect()
    # The password is in this result and nowhere else: save it, don't display it
    _save_password(session, _admin_password(result))
    print(f"Created {INSTANCE}; the snowflake_admin password is saved in {SECRET}.")
    return wait_ready(session)


def reset_password(session):
    """Issue a new snowflake_admin password (the old one stops working) and save it."""
    result = session.sql(f"ALTER POSTGRES INSTANCE {INSTANCE} RESET ACCESS {ADMIN_USER}").collect()
    _save_password(session, _admin_password(result))
    print(f"New password saved in {SECRET}: reveal it again in the Lab Companion.")


def connect(host, user, password):
    import psycopg2
    conn = psycopg2.connect(host=host, port=5432, dbname="postgres", user=user, password=password,
                            sslmode="require", connect_timeout=15)
    conn.autocommit = True
    return conn


def create_source_table(conn):
    with conn.cursor() as cur:
        cur.execute(f"CREATE SCHEMA IF NOT EXISTS {PG_SCHEMA}")
        cur.execute(f"""CREATE TABLE IF NOT EXISTS {PG_SCHEMA}.payment_events (
            event_id       UUID PRIMARY KEY,
            payment_ref    TEXT NOT NULL,
            customer_id    TEXT NOT NULL,
            scheme         TEXT NOT NULL,
            amount         NUMERIC(18,2) NOT NULL,
            currency       TEXT NOT NULL,
            status         TEXT NOT NULL,
            failure_reason TEXT,
            event_ts       TIMESTAMP NOT NULL,
            created_at     TIMESTAMPTZ NOT NULL DEFAULT now())""")
        cur.execute(f"SELECT COUNT(*) FROM {PG_SCHEMA}.payment_events")
        return cur.fetchone()[0]


def start_mirror(session, refresh_interval="1 minute"):
    """Mirror the payments schema into Snowflake-managed Iceberg tables in PAYMENTS_MIRROR."""
    session.sql(f"GRANT USAGE ON POSTGRES INSTANCE {INSTANCE} TO APPLICATION SNOWFLAKE").collect()
    existing = [_row(r) for r in session.sql("SELECT * FROM TABLE(SNOWFLAKE.POSTGRES.LIST_MIRRORS())").collect()]
    if any(str(m.get("MIRROR_NAME", "")).lower() == MIRROR for m in existing):
        print(f"{MIRROR} already exists")
    else:
        session.sql(f"""CALL SNOWFLAKE.POSTGRES.CREATE_MIRROR(
            mirror_name => '{MIRROR}', postgres_instance => '{INSTANCE}', postgres_database => 'postgres',
            target_database => '{TARGET_DB}', postgres_schemas => ['{PG_SCHEMA}'],
            refresh_interval => '{refresh_interval}', target_table_type => 'ICEBERG')""").collect()
    return mirror_status(session)


def mirror_status(session):
    return [_row(r) for r in session.sql(f"CALL SNOWFLAKE.POSTGRES.LIST_MIRRORED_TABLES('{MIRROR}')").collect()]


def stream_payments(conn, session, minutes=5, per_second=20):
    """Insert a live payment feed into Postgres; the second half carries the SEPA incident."""
    from psycopg2.extras import execute_values

    customers = [r[0] for r in session.sql(
        "SELECT CUSTOMER_ID FROM BARCLAYS_HOL.RAW_DATA.CUSTOMERS ORDER BY CUSTOMER_ID").collect()]
    incident_client = customers[len(customers) // 3]
    seconds = int(minutes * 60)
    total = seconds * per_second
    sent = 0
    start = time.time()
    with conn.cursor() as cur:
        for second in range(seconds):
            rows = []
            for _ in range(per_second):
                sent += 1
                incident = sent > total // 2 and random.random() < 0.15
                scheme = "SEPA" if incident else random.choice(SCHEMES)
                failed = incident or random.random() < 0.03
                rows.append((
                    str(uuid.uuid4()), f"PAY-RT-{sent:07d}",
                    incident_client if incident else random.choice(customers),
                    scheme, round(random.lognormvariate(9, 1.4), 2), "EUR" if scheme == "SEPA" else "GBP",
                    "FAILED" if failed else "COMPLETED",
                    ("Beneficiary bank unavailable" if incident
                     else random.choice(["Invalid account", "Insufficient funds", "Sanctions check"])) if failed else None,
                    datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)))
            # One statement per second's batch: a round trip per row can't keep up
            execute_values(cur, f"""INSERT INTO {PG_SCHEMA}.payment_events
                (event_id, payment_ref, customer_id, scheme, amount, currency, status, failure_reason, event_ts)
                VALUES %s""", rows)
            if (second + 1) % 30 == 0:
                print(f"{sent:,} events sent ({int(time.time() - start)} s)")
            time.sleep(max(0, start + second + 1 - time.time()))
    return sent
