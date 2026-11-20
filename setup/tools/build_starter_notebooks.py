#!/usr/bin/env python3
"""Build the starter notebooks in notebooks/ from the module READMEs.

Each starter has the module title and one markdown heading per notebook step, naming
the cells that step's prompt asks Cortex Code to add. Attendees still build every cell
with Cortex Code; the starter saves the setup and keeps the cells in order.
Rerun after changing a module's steps:  python3 setup/tools/build_starter_notebooks.py
"""
import hashlib, json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULES = {  # notebook name: (module folder, title)
    "da2_feedback_analysis": ("da2_aisql_feedback", "DA2: AI SQL on customer feedback"),
    "da3_branch_network": ("da3_branch_network_geo", "DA3: Branch network and catchment analysis"),
    "de3_realtime_payments": ("de3_realtime_payments", "DE3: Real-time payments"),
    "gov3_ai_gateway": ("gov3_ai_gateway", "GOV3: AI governance with Cortex AI Gateway"),
}
CELL = re.compile(r"\b(SQL|Python|code|markdown) cell(?: named ([a-z_0-9]+))?")

# Plain-English explanation shown under each step heading in a starter, keyed by the start of the heading.
EXPLAIN = {
    "de3_realtime_payments": {
        "Create the Postgres instance": (
            "**What this does:** creates **HOL_PAYMENTS_PG**, a Snowflake Postgres database that plays the part of the bank's "
            "payment engine, the operational system where payments are written as they happen. It runs inside Snowflake, so "
            "there's no server to set up. It takes 3 to 5 minutes. Postgres shows its admin password only once, so the helper "
            "saves it straight into a Snowflake secret instead of printing it."
        ),
        "Reveal the connection": (
            "**What this does:** connects this notebook to the new Postgres database and creates the table the payment engine "
            "writes to, `payments.payment_events`. You copy the host, user and password from the Lab Companion into the cell "
            "below. The table starts empty. It has a primary key, which lets the mirror in the next step copy updates and "
            "deletes, not just new rows."
        ),
        "Mirror Postgres into Snowflake": (
            "**What this does:** switches on **Data Mirroring**, which copies every change in the Postgres table into Snowflake "
            "continuously, with no pipeline to build or schedule. The copy lands as an open Iceberg table in the new database "
            "`PAYMENTS_MIRROR`. Alongside it you get `$live`, which is only seconds behind Postgres, and `$changes`, a feed of "
            "every insert, update and delete."
        ),
        "Stream payments": (
            "**What this does:** pretends to be the payment engine. For 5 minutes it writes about 20 payments a second into "
            "Postgres, around 6,000 in total. Halfway through, one corporate client's SEPA payments start failing with "
            "\"Beneficiary bank unavailable\": that's the incident the rest of the module finds."
        ),
        "Measure how fresh": (
            "**What this does:** checks how far behind Postgres the Snowflake copy is. It counts payments per minute, then "
            "measures the gap between the newest payment and now, in `$live` (about 20 to 40 seconds) and in the main table "
            "(up to a minute, because changes are merged every minute). That gap is the end-to-end delay from the payment "
            "engine to Snowflake."
        ),
        "Serve the ops floor": (
            "**What this does:** runs the queries an operations dashboard would refresh every few seconds, such as failed "
            "payments by scheme and the clients with the most failed value, on the **interactive warehouse** "
            "`HOL_INTERACTIVE_WH`. It reads the mirrored Iceberg table directly, with no copy. Interactive warehouses are "
            "built for many people, apps or agents asking quick questions at once, not for heavy one-off analysis, so the "
            "cell switches back to `BARCLAYS_WH` at the end."
        ),
        "Flag incidents": (
            "**What this does:** creates a dynamic table, `DT_PAYMENT_INCIDENTS`, that looks at the last 15 minutes of failed "
            "payments and flags any client with 5 or more failures for the same scheme and reason. It refreshes itself every "
            "minute, so a new problem shows up within a minute of it starting in Postgres. You then draft the message the "
            "operations team would send to the client's relationship manager."
        ),
    },
}

# Code cells that come pre-filled in a starter, under the step whose heading starts with the key.
# Attendees edit these rather than asking Cortex Code to write them.
PRESET = {
    "de3_realtime_payments": {
        "Reveal the connection": (
            "# Paste the values from the Lab Companion > DE3 > Reveal Postgres connection, then run this cell.\n"
            "# Keep the quotes. Don't share the password.\n"
            'PG_HOST = "<host_here>"\n'
            'PG_USER = "<user_here>"\n'
            'PG_PASS = "<pg_pass_here>"\n'
        ),
    },
}


def cell_id(*parts):
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:8]


def md(name, text):
    return {"cell_type": "markdown", "id": cell_id(name, text), "metadata": {}, "source": text.splitlines(keepends=True)}


def code(name, text):
    return {"cell_type": "code", "id": cell_id(name, text), "metadata": {}, "execution_count": None,
            "outputs": [], "source": text.splitlines(keepends=True)}


def steps(readme):
    """(heading, prompt) for each step whose prompt adds notebook cells."""
    out = []
    for block in re.split(r"^### ", readme, flags=re.M)[1:]:
        heading = block.splitlines()[0].strip()
        prompt = re.search(r"```prompt\n(.*?)```", block, re.S)
        if prompt and " cell" in prompt.group(1) and not (heading.startswith("Create the") and heading.endswith("notebook")):
            out.append((heading, prompt.group(1)))
    return out


def describe(prompt):
    cells = []
    for kind, name in CELL.findall(prompt):
        if kind == "markdown" and not name:
            continue  # the title cell is already in the starter
        cells.append(f"`{name}` ({kind})" if name else f"a {kind} cell")
    return ", ".join(dict.fromkeys(cells))


def build(nb_name, folder, title):
    readme = (ROOT / "vignettes" / folder / "README.md").read_text()
    cells = [md(nb_name, f"# {title}\n\nStarter notebook for [{folder.split('_')[0].upper()}](../vignettes/{folder}/README.md). "
                "Paste each step's prompt into the Cortex Code sidebar with this notebook open: Cortex Code adds the cells "
                "under the matching heading, and you run them.\n\nWork in the **payments-hol** Workspace so Cortex Code can "
                "find the reference files in `vignettes/`.")]
    for i, (heading, prompt) in enumerate(steps(readme), 1):
        what = describe(prompt)
        about = next((t for k, t in EXPLAIN.get(nb_name, {}).items() if heading.startswith(k)), "")
        text = f"## {i}. {heading}" + (f"\n\n{about}" if about else "") + (f"\n\nCells for this step: {what}." if what else "")
        cells.append(md(nb_name, text))
        for prefix, source in PRESET.get(nb_name, {}).items():
            if heading.startswith(prefix):
                cells.append(code(nb_name, source))
    nb = {"cells": cells,
          "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                       "language_info": {"name": "python"}},
          "nbformat": 4, "nbformat_minor": 5}
    path = ROOT / "notebooks" / f"{nb_name}.ipynb"
    path.write_text(json.dumps(nb, indent=1) + "\n")
    return path, len(cells) - 1


if __name__ == "__main__":
    (ROOT / "notebooks").mkdir(exist_ok=True)
    for nb_name, (folder, title) in MODULES.items():
        path, n = build(nb_name, folder, title)
        print(f"{path.relative_to(ROOT)}: {n} cells after the title")
