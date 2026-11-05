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


def cell_id(*parts):
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:8]


def md(name, text):
    return {"cell_type": "markdown", "id": cell_id(name, text), "metadata": {}, "source": text.splitlines(keepends=True)}


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
        cells.append(md(nb_name, f"## {i}. {heading}\n\nCells for this step: {what}." if what else f"## {i}. {heading}"))
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
        print(f"{path.relative_to(ROOT)}: {n} sections")
