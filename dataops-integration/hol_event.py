#!/usr/bin/env python3
"""Create, check and end DataOps events for the Payments HOL (stdlib only).

  python3 dataops-integration/hol_event.py create <slug> --name "..." --pool 10 \
      --start 2026-12-01T09:00 --end 2026-12-01T17:00 [--wait]
  python3 dataops-integration/hol_event.py status <slug>
  python3 dataops-integration/hol_event.py instructions <slug>   # re-apply event_instructions.md
  python3 dataops-integration/hol_event.py rerun <slug>          # re-run configure for every account
  python3 dataops-integration/hol_event.py end <slug> --yes      # decommission accounts (irreversible)

Token: DATAOPS_TOKEN, or the macOS keychain item "dataops-token". It is a
DataOps (app.dataops.live) personal access token with api scope; the same token
works for the event admin API and the project pipelines.
"""
import argparse
import datetime as dt
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

ADMIN = "https://admin.dataops.live/api/v1/event_management"
GITLAB = "https://app.dataops.live/api/v4"
PROJECT = "snowflake/hands-on-lab-drafts/RO-barclays-test"
INSTRUCTIONS = Path(__file__).resolve().parent / "event_instructions.md"
# Values tested on the reference events; the admin API rejects any other top-level group.
DEFAULTS = {
    "location": "Virtual",
    "delivery_format": "HANDS_ON_LAB",
    "organization_account_identifier": "SFSEHOL-SFSEHOL_ADMIN",
    "dataops_configure_project_pipe_file": "full-ci.yml",
    "dataops_configure_project_git_ref": "main",
    "dataops_top_level_group_path": "event",
    "snowflake_account_region_group": "aws_us_west_2",
    "snowflake_account_edition": "ENTERPRISE",
}


def token():
    if os.environ.get("DATAOPS_TOKEN"):
        return os.environ["DATAOPS_TOKEN"]
    try:
        return subprocess.check_output(
            ["security", "find-generic-password", "-s", "dataops-token", "-w"],
            stderr=subprocess.DEVNULL).decode().strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("No DataOps token: set DATAOPS_TOKEN or add keychain item 'dataops-token'.")


def call(method, url, body=None, gitlab=False, raw=False):
    headers = {"PRIVATE-TOKEN": TOKEN} if gitlab else {"Authorization": f"Bearer {TOKEN}"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            payload = r.read()
            return payload if raw else json.loads(payload or b"null")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        raise SystemExit(f"{method} {url} -> HTTP {e.code}: {detail}") from None


def iso(value):
    """Accept 2026-12-01T09:00 (UTC) or a full ISO timestamp with offset."""
    t = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if t.tzinfo is None:
        t = t.replace(tzinfo=dt.timezone.utc)
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def accounts(slug):
    d = call("GET", f"{ADMIN}/events/{slug}/accounts?page=1&page_size=200")
    return d if isinstance(d, list) else d.get("accounts", [])


def companion_url(account):
    """LAB_COMPANION_URL from the account's Configure Attendee Account dotenv (what the instructions page reads)."""
    pipeline = (account.get("latest_pipeline_url") or "").rsplit("/", 1)[-1]
    if not pipeline.isdigit():
        return None
    proj = f"{GITLAB}/projects/{urllib.parse.quote(PROJECT, safe='')}"
    jobs = call("GET", f"{proj}/pipelines/{pipeline}/jobs?per_page=100", gitlab=True)
    job = next((j for j in jobs if j["name"] == "Configure Attendee Account" and j["status"] == "success"), None)
    if not job:
        return None
    try:
        archive = zipfile.ZipFile(io.BytesIO(call("GET", f"{proj}/jobs/{job['id']}/artifacts", gitlab=True, raw=True)))
    except (SystemExit, zipfile.BadZipFile):
        return None
    for name in archive.namelist():
        if name.endswith("attendee_account_outputs.env"):
            for line in archive.read(name).decode().splitlines():
                if line.startswith("LAB_COMPANION_URL="):
                    return line.split("=", 1)[1]
    return None


def show_status(slug):
    d = call("GET", f"{ADMIN}/events/{slug}/details")
    pool = d.get("account_pool") or {}
    print(f"{d['name']} ({slug})  approval={d['approval_status']}  "
          f"{d['start_datetime']} -> {d['end_datetime']}  project={d['project']}")
    print(f"accounts: {pool.get('total_ready_child_accounts', 0)}/{pool.get('pool_size', '?')} ready, "
          f"{pool.get('total_allocated_child_accounts', 0)} allocated")
    rows = accounts(slug)
    for a in rows:
        url = companion_url(a) if a["status"] == "ready" else None
        flag = "" if a["status"] != "ready" else ("  LAB_COMPANION_URL " + url if url else "  WARNING: no LAB_COMPANION_URL")
        print(f"  {a['slug']:8} {a['status']:22} allocated={a['has_been_allocated']}{flag}")
    return rows


def cmd_create(args):
    if not INSTRUCTIONS.exists():
        sys.exit(f"Missing {INSTRUCTIONS}")
    now = dt.datetime.now(dt.timezone.utc)
    start = iso(args.start)
    end = iso(args.end)
    # Provision a day ahead (accounts take ~15 min, and stay idle until the event),
    # or in 5 minutes when the event is less than a day away
    start_t = dt.datetime.fromisoformat(start.replace("Z", "+00:00"))
    build_default = max(start_t - dt.timedelta(hours=24), now + dt.timedelta(minutes=5))
    body = dict(DEFAULTS)
    body.update({
        "name": args.name,
        "initial_pool_size": args.pool,
        "dataops_configure_project_path": PROJECT,
        "build_date": iso(args.build) if args.build else build_default.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "start_date": start,
        "end_date": end,
        "decommission_date": iso(args.decommission) if args.decommission
        else (dt.datetime.fromisoformat(end.replace("Z", "+00:00")) + dt.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "instructions": INSTRUCTIONS.read_text(),
    })
    if args.region:
        body["snowflake_account_region_group"] = args.region
    if args.domains:
        body["allowed_email_domains"] = args.domains
    print(json.dumps({k: v for k, v in body.items() if k != "instructions"}, indent=1))
    if args.dry_run:
        return
    print(call("POST", f"{ADMIN}/{args.slug}", body))
    try:
        print(call("POST", f"{ADMIN}/{args.slug}/approve"))
    except SystemExit as e:
        print(f"Could not approve automatically ({e}). Ask a DataOps admin to approve the event.")
    print(f"Registration: https://go.dataops.live/{args.slug}")
    if args.wait:
        wait_ready(args.slug, args.pool)


def wait_ready(slug, expected, timeout_min=60):
    deadline = time.time() + timeout_min * 60
    while time.time() < deadline:
        rows = accounts(slug)
        states = {a["slug"]: a["status"] for a in rows}
        print(time.strftime("%H:%M:%S"), states or "no accounts yet")
        if any(s == "error" for s in states.values()):
            print("An account is in error: check its latest pipeline (hol_event.py status), fix, then hol_event.py rerun.")
            break
        if len(rows) >= expected and all(s == "ready" for s in states.values()):
            break
        time.sleep(60)
    show_status(slug)


def cmd_end(args):
    rows = accounts(args.slug)
    live = [a for a in rows if a["status"] not in ("decommissioned", "pending-decommissioning")]
    print(f"Will decommission {len(live)} account(s): {', '.join(a['slug'] for a in live) or 'none'}")
    if not args.yes:
        sys.exit("Irreversible. Re-run with --yes to decommission.")
    for a in live:
        try:
            call("POST", f"{ADMIN}/events/{args.slug}/accounts/{a['id']}/decommission?remain_allocated=false")
        except SystemExit as e:
            # The API has returned 500 after starting the decommission; the status check below is authoritative
            print(f"  {a['slug']}: {e}")
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    call("PATCH", f"{ADMIN}/{args.slug}", {"end_date": now, "decommission_date": now})
    time.sleep(10)
    show_status(args.slug)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("create")
    c.add_argument("slug", help="URL name, e.g. payments-hol-london-dec26 (go.dataops.live/<slug>)")
    c.add_argument("--name", required=True)
    c.add_argument("--pool", type=int, required=True, help="number of attendee accounts")
    c.add_argument("--start", required=True, help="event start, UTC unless an offset is given")
    c.add_argument("--end", required=True)
    c.add_argument("--build", help="when to start provisioning (default: 24 h before --start)")
    c.add_argument("--decommission", help="default: 2 days after --end")
    c.add_argument("--region", help=f"default {DEFAULTS['snowflake_account_region_group']}")
    c.add_argument("--domains", nargs="*", help="allowed attendee email domains")
    c.add_argument("--wait", action="store_true", help="wait until every account is ready")
    c.add_argument("--dry-run", action="store_true")
    for name in ("status", "instructions", "rerun"):
        sub.add_parser(name).add_argument("slug")
    e = sub.add_parser("end")
    e.add_argument("slug")
    e.add_argument("--yes", action="store_true")
    args = p.parse_args()

    if args.cmd == "create":
        cmd_create(args)
    elif args.cmd == "status":
        show_status(args.slug)
    elif args.cmd == "instructions":
        print(call("PATCH", f"{ADMIN}/{args.slug}", {"instructions": INSTRUCTIONS.read_text()}))
    elif args.cmd == "rerun":
        ids = [a["id"] for a in accounts(args.slug) if a["status"] not in ("decommissioned", "pending-decommissioning")]
        print(call("POST", f"{ADMIN}/{args.slug}/rerun_configure_pipeline", {"child_account_ids": ids}))
    elif args.cmd == "end":
        cmd_end(args)


if __name__ == "__main__":
    TOKEN = token()
    main()
