"""GOV3 reference: call models through Cortex AI Gateway from a Workspace notebook.

Run in a notebook with the external access integration HOL_NOTEBOOK_ACCESS_INTEGRATION enabled.
Cells, in order:
  1. make_key_pair()       - generate a key pair and register its public key on your own user
  2. gateway_url(session)  - the gateway endpoint for this account
  3. ask_openai / ask_claude - send requests through the gateway with a short-lived key-pair JWT
"""
import base64
import hashlib
import json
import time
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

KEY_NAME = "GOV3_GATEWAY_KEY"
ROLE = "HOL_PARTICIPANT"


def make_key_pair(session, key_name=KEY_NAME, role=ROLE):
    """Generate an RSA key in memory and register its public key on the current user.

    The key is restricted to HOL_PARTICIPANT and expires after a day, so it can only do what
    the lab role can do. The private key never leaves the notebook session.
    """
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_der = key.public_key().public_bytes(serialization.Encoding.DER,
                                               serialization.PublicFormat.SubjectPublicKeyInfo)
    # Rerunning the cell replaces the key (REMOVE KEY PAIR has no IF EXISTS)
    try:
        session.sql(f"ALTER USER REMOVE KEY PAIR {key_name}").collect()
    except Exception:
        pass
    session.sql(f"ALTER USER ADD KEY PAIR {key_name} PUBLIC_KEY = '{base64.b64encode(public_der).decode()}' "
                f"ROLE_RESTRICTION = '{role}' DAYS_TO_EXPIRY = 1 COMMENT = 'GOV3/DE3 lab key'").collect()
    return key


def account_info(session):
    """Account identifier (for the JWT), public host and user for this session."""
    org, acct, user = session.sql(
        "SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(), CURRENT_USER()").collect()[0]
    host = f"{org}-{acct}".lower().replace("_", "-") + ".snowflakecomputing.com"
    return f"{org}-{acct}".upper(), host, user.upper()


def gateway_url(session):
    return f"https://{account_info(session)[1]}/api/v2/aigateways/snowflake"


def key_pair_jwt(session, key, minutes=50):
    """A key-pair JWT signed with key: what Snowflake REST APIs, the gateway included, accept."""
    account, _, user = account_info(session)
    public_der = key.public_key().public_bytes(serialization.Encoding.DER,
                                               serialization.PublicFormat.SubjectPublicKeyInfo)
    fingerprint = "SHA256:" + base64.b64encode(hashlib.sha256(public_der).digest()).decode()
    now = int(time.time())
    claims = {"iss": f"{account}.{user}.{fingerprint}", "sub": f"{account}.{user}", "iat": now, "exp": now + minutes * 60}

    def b64(data):
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    signing_input = b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode()) + "." + b64(json.dumps(claims).encode())
    signature = key.sign(signing_input.encode(), padding.PKCS1v15(), hashes.SHA256())
    return signing_input + "." + b64(signature)


def _post(url, token, body, conversation_id=None):
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}",
               "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT"}
    if conversation_id:
        headers["x-snowflake-ai-gateway-conversation-id"] = conversation_id
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def ask_openai(session, key, prompt, model="openai-gpt-5", conversation_id="gov3-lab"):
    """OpenAI Chat Completions format (/v1/chat/completions): every model except Claude."""
    r = _post(gateway_url(session) + "/v1/chat/completions", key_pair_jwt(session, key),
              {"model": model, "messages": [{"role": "user", "content": prompt}]}, conversation_id)
    return r["choices"][0]["message"]["content"], r.get("usage")


def ask_claude(session, key, prompt, model="claude-sonnet-4-5", conversation_id="gov3-lab"):
    """Anthropic Messages format (/v1/messages): Claude models only."""
    r = _post(gateway_url(session) + "/v1/messages", key_pair_jwt(session, key),
              {"model": model, "max_tokens": 400, "messages": [{"role": "user", "content": prompt}]}, conversation_id)
    return r["content"][0]["text"], r.get("usage")
