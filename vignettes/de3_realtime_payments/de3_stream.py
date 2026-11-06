"""Optional reference (not used in the DE3 steps): stream payment events with Snowpipe Streaming.

DE3 itself streams through Snowflake Postgres and Data Mirroring (de3_postgres.py).

Run in a Workspace notebook with the external access integration HOL_NOTEBOOK_ACCESS_INTEGRATION
enabled, after `!pip install "snowpipe-streaming>=1.5"`. Streams ~5,000 synthetic payment events into
BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS through its default pipe PAYMENT_EVENTS-STREAMING.

Notebooks run in Snowpark Container Services, where Snowflake rejects key-pair sign-in (error
395090), so inside a notebook the client signs in with the container's own token (SPCS auth). The
key-pair path is for running this file outside Snowflake, for example from a laptop.

The planted story: halfway through, SEPA payments for one corporate client start failing with
"Beneficiary bank unavailable" - the ops floor should spot it within seconds.
"""
import base64
import datetime
import json
import os
import random
import tempfile
import time
import uuid

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

KEY_NAME = "DE3_STREAMING_KEY"
ROLE = "HOL_PARTICIPANT"
SCHEMES = ["FASTER_PAYMENTS", "BACS", "CHAPS", "SEPA", "SWIFT"]


def make_key_pair(session, key_name=KEY_NAME, role=ROLE):
    """Generate an RSA key in memory and register its public key on your own user (1 day, HOL_PARTICIPANT)."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_der = key.public_key().public_bytes(serialization.Encoding.DER,
                                               serialization.PublicFormat.SubjectPublicKeyInfo)
    try:
        session.sql(f"ALTER USER REMOVE KEY PAIR {key_name}").collect()
    except Exception:
        pass  # first run: no key to remove (REMOVE KEY PAIR has no IF EXISTS)
    session.sql(f"ALTER USER ADD KEY PAIR {key_name} PUBLIC_KEY = '{base64.b64encode(public_der).decode()}' "
                f"ROLE_RESTRICTION = '{role}' DAYS_TO_EXPIRY = 1 COMMENT = 'DE3 lab streaming key'").collect()
    return key


SPCS_TOKEN = "/snowflake/session/token"


def streaming_client(session, key=None, client_name="de3_payments"):
    """A Snowpipe Streaming client for PAYMENT_EVENTS as the current user.

    In a notebook it signs in with the container token; elsewhere it needs key from make_key_pair.
    """
    from snowflake.ingest.streaming import StreamingIngestClient

    org, acct, user = session.sql(
        "SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(), CURRENT_USER()").collect()[0]
    host = f"{org}-{acct}".lower().replace("_", "-") + ".snowflakecomputing.com"
    profile = {"account": f"{org}-{acct}".upper(), "url": f"https://{host}:443", "role": ROLE}
    if os.path.exists(SPCS_TOKEN):
        profile.update(authorization_type="SPCS", spcs_token_path=SPCS_TOKEN)
    elif key is None:
        raise ValueError("Outside a notebook, pass key = make_key_pair(session)")
    else:
        pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption()).decode()
        profile.update(authorization_type="JWT", user=user, private_key=pem)
    # The SDK reads its profile from a file; keep it private (it can hold the key) and remove it once the client is open
    fd, path = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(profile, f)
    try:
        return StreamingIngestClient(client_name=client_name, db_name="BARCLAYS_HOL", schema_name="REALTIME",
                                     pipe_name="PAYMENT_EVENTS-STREAMING", profile_json=path)
    finally:
        os.remove(path)


def stream_payments(session, client, events=5000, per_second=100, channel_name="payments_feed_1"):
    """Stream events at about per_second; returns the last committed offset."""
    customers = [r[0] for r in session.sql(
        "SELECT CUSTOMER_ID FROM BARCLAYS_HOL.RAW_DATA.CUSTOMERS ORDER BY CUSTOMER_ID").collect()]
    incident_client = customers[len(customers) // 3]
    channel, _ = client.open_channel(channel_name=channel_name)
    channel_id = abs(hash(channel_name)) % 1000
    for i in range(1, events + 1):
        incident = i > events // 2 and random.random() < 0.15
        scheme = "SEPA" if incident else random.choice(SCHEMES)
        failed = incident or random.random() < 0.03
        channel.append_row({
            "EVENT_ID": str(uuid.uuid4()),
            "PAYMENT_REF": f"PAY-RT-{i:07d}",
            "CUSTOMER_ID": incident_client if incident else random.choice(customers),
            "SCHEME": scheme,
            "AMOUNT": round(random.lognormvariate(9, 1.4), 2),
            "CURRENCY": "EUR" if scheme == "SEPA" else "GBP",
            "STATUS": "FAILED" if failed else "COMPLETED",
            "FAILURE_REASON": ("Beneficiary bank unavailable" if incident
                               else random.choice(["Invalid account", "Insufficient funds", "Sanctions check"])) if failed else None,
            "EVENT_TS": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).isoformat(),
            "CHANNEL_ID": channel_id,
            "STREAM_OFFSET": i,
        }, offset_token=str(i))
        if i % per_second == 0:
            time.sleep(1)
    channel.wait_for_flush(timeout_seconds=60)
    for _ in range(30):
        if channel.get_latest_committed_offset_token() == str(events):
            break
        time.sleep(2)
    return channel.get_latest_committed_offset_token()
