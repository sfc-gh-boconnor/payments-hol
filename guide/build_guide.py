"""Build guide/index.html from the repo's own README and SQL files.

Run from the repo root:  python3 guide/build_guide.py
The guide is a single self-contained HTML file (no external scripts or fonts).
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PATHWAYS = {
    "Data Engineer":   ["DE1", "DE2", "GOV2"],
    "Data Analyst":    ["DA2", "DA1"],
    "Payments Ops":    ["OPS1", "OPS2", "DA2"],
    "AI Builder":      ["AI1", "AI3", "AI2"],
    "Governance":      ["GOV1", "GOV2", "AI3"],
}


def md_to_html(md: str) -> str:
    """Minimal markdown for the vignette READMEs: headings, tables, lists, quotes, code, links."""
    out, in_list, in_table = [], None, False

    def inline(s):
        s = html.escape(s)
        s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
        s = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", s)
        s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<span class="ref">\1</span>', s)
        return s

    def close():
        nonlocal in_list, in_table
        if in_list:
            out.append(f"</{in_list}>")
            in_list = None
        if in_table:
            out.append("</table>")
            in_table = False

    for line in md.splitlines():
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if all(set(c) <= set("-: ") for c in cells):
                continue
            if not in_table:
                close()
                out.append('<table>')
                in_table = True
            if any(cells):
                out.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in cells) + "</tr>")
            continue
        m = re.match(r"^(#{1,3}) (.*)", line)
        if m:
            close()
            lvl = len(m.group(1)) + 1
            out.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>")
        elif re.match(r"^\d+\. ", line):
            if in_list != "ol":
                close()
                out.append("<ol>")
                in_list = "ol"
            item = re.sub(r"^\d+\. ", "", line)
            out.append(f"<li>{inline(item)}</li>")
        elif line.startswith("- "):
            if in_list != "ul":
                close()
                out.append("<ul>")
                in_list = "ul"
            out.append(f"<li>{inline(line[2:])}</li>")
        elif line.startswith("> "):
            close()
            out.append(f"<blockquote>{inline(line[2:])}</blockquote>")
        elif line.strip():
            close()
            out.append(f"<p>{inline(line)}</p>")
        else:
            close()
    close()
    return "\n".join(out)


def module(code, title, readme_html, sql_path):
    sql = sql_path.read_text() if sql_path and sql_path.exists() else ""
    return {"code": code, "title": title, "body": readme_html,
            "sql": sql, "sql_name": str(sql_path.relative_to(ROOT)) if sql else ""}


def main():
    modules = [module("C1", "Explore the Iceberg data product",
                      "<p>Shared core for every pathway. Read the published Iceberg tables, prove the "
                      "read-only guard-rails and build a first client 360 query.</p>",
                      ROOT / "core" / "C1_explore_iceberg.sql"),
               module("C2", "Data product tour",
                      md_to_html((ROOT / "core" / "C2_data_product_tour.md").read_text()), None)]
    order = ["de", "da", "ops", "ai", "gov"]
    for d in sorted((ROOT / "vignettes").iterdir(), key=lambda p: (order.index(re.match(r"[a-z]+", p.name).group()), p.name)):
        readme = (d / "README.md").read_text()
        code, title = re.match(r"# (\w+): (.*)", readme).groups()
        body = md_to_html("\n".join(readme.splitlines()[1:]))
        modules.append(module(code, title, body, next(d.glob("*.sql"))))
    catchups = [module(p.stem, "Catch-up: " + p.stem.replace("_", " "),
                       "<p>Run this if a vignette lists it as a prerequisite and you have not built it yet.</p>", p)
                for p in sorted((ROOT / "setup" / "catchup").glob("*.sql"))]

    data = json.dumps({"modules": modules + catchups, "pathways": PATHWAYS})
    page = TEMPLATE.replace("__DATA__", data.replace("</", "<\\/"))
    (ROOT / "guide" / "index.html").write_text(page)
    print(f"guide/index.html written: {len(modules)} modules, {len(catchups)} catch-ups")


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Barclays Payments HOL v2 - Lab Guide</title>
<style>
:root{--blue:#29B5E8;--navy:#11567F;--ink:#1F2937;--muted:#6B7280;--line:#E5E7EB;--bg:#F7FAFC}
*{box-sizing:border-box}body{margin:0;font-family:-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);background:var(--bg)}
header{background:var(--navy);color:#fff;padding:18px 28px}header h1{margin:0;font-size:20px}header p{margin:4px 0 0;opacity:.8;font-size:13px}
.wrap{display:flex;min-height:calc(100vh - 70px)}
nav{width:300px;background:#fff;border-right:1px solid var(--line);padding:16px;overflow-y:auto}
nav h3{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:18px 0 6px}
.persona{display:flex;flex-wrap:wrap;gap:6px}.persona button{border:1px solid var(--blue);background:#fff;color:var(--navy);border-radius:14px;padding:4px 10px;font-size:12px;cursor:pointer}
.persona button.on{background:var(--blue);color:#fff}
.item{display:block;width:100%;text-align:left;border:0;background:none;padding:7px 8px;border-radius:6px;cursor:pointer;font-size:13px;color:var(--ink)}
.item:hover{background:#EEF7FC}.item.on{background:#DFF2FB;font-weight:600}.item.dim{opacity:.35}
.item .c{display:inline-block;min-width:42px;font-weight:700;color:var(--navy)}.item .done{float:right;color:#15803D}
main{flex:1;padding:28px 40px;max-width:1100px;overflow-y:auto}
main h2{font-size:24px;margin:0 0 4px}main h3{margin-top:26px;color:var(--navy)}
table{border-collapse:collapse;margin:10px 0}td{border:1px solid var(--line);padding:6px 10px;font-size:14px;vertical-align:top}
blockquote{border-left:4px solid var(--blue);margin:10px 0;padding:6px 14px;background:#fff}
code{background:#EEF2F7;padding:1px 5px;border-radius:4px;font-size:13px}
.sqlbar{display:flex;justify-content:space-between;align-items:center;margin-top:24px}
pre{background:#0F172A;color:#E2E8F0;padding:16px;border-radius:8px;overflow:auto;font-size:12.5px;line-height:1.45;max-height:620px}
.btn{background:var(--blue);color:#fff;border:0;border-radius:6px;padding:7px 12px;font-size:13px;cursor:pointer}
.btn.ghost{background:#fff;color:var(--navy);border:1px solid var(--line)}.ref{color:var(--navy);font-weight:600}
.muted{color:var(--muted);font-size:13px}
</style></head><body>
<header><h1>Barclays Payments Operations - Hands-on Lab v2</h1>
<p>Corporate banking payments data product on Snowflake - Iceberg to governed AI agents. Synthetic data only.</p></header>
<div class="wrap"><nav>
<h3>Choose your pathway</h3><div class="persona" id="personas"></div>
<h3>Shared core</h3><div id="core"></div>
<h3>Vignettes</h3><div id="vign"></div>
<h3>Catch-up scripts</h3><div id="catch"></div>
</nav><main id="main"></main></div>
<script>
const D = __DATA__;
const byCode = Object.fromEntries(D.modules.map(m => [m.code, m]));
let persona = localStorage.getItem('hol_persona') || '';
const done = JSON.parse(localStorage.getItem('hol_done') || '{}');
function esc(s){return s.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
function navItem(m){
  const b = document.createElement('button'); b.className = 'item'; b.dataset.code = m.code;
  b.innerHTML = '<span class="c">' + esc(m.code.length > 6 ? '' : m.code) + '</span>' + esc(m.title) + (done[m.code] ? '<span class="done">done</span>' : '');
  b.onclick = () => show(m.code); return b;
}
function render(){
  const P = document.getElementById('personas'); P.innerHTML = '';
  ['All', ...Object.keys(D.pathways)].forEach(p => {
    const b = document.createElement('button'); b.textContent = p;
    if ((p === 'All' && !persona) || p === persona) b.className = 'on';
    b.onclick = () => { persona = p === 'All' ? '' : p; localStorage.setItem('hol_persona', persona); render(); };
    P.appendChild(b);
  });
  const sets = {core: [], vign: [], catch: []};
  D.modules.forEach(m => (m.code === 'C1' || m.code === 'C2' ? sets.core : m.sql_name.includes('catchup') ? sets.catch : sets.vign).push(m));
  const order = persona ? D.pathways[persona] : null;
  if (order) sets.vign.sort((a, b) => (order.indexOf(a.code) + 1 || 99) - (order.indexOf(b.code) + 1 || 99));
  for (const [id, list] of Object.entries(sets)) {
    const el = document.getElementById(id); el.innerHTML = '';
    list.forEach(m => { const n = navItem(m); if (order && id === 'vign' && !order.includes(m.code)) n.classList.add('dim'); el.appendChild(n); });
  }
}
function show(code){
  const m = byCode[code];
  document.querySelectorAll('.item').forEach(i => i.classList.toggle('on', i.dataset.code === code));
  let h = '<h2>' + esc(m.code) + ': ' + esc(m.title) + '</h2>' + m.body;
  if (m.sql) h += '<div class="sqlbar"><span class="muted">' + esc(m.sql_name) + '</span><span>'
      + '<button class="btn ghost" id="cp">Copy SQL</button> <button class="btn" id="dn">' + (done[code] ? 'Completed' : 'Mark complete') + '</button></span></div>'
      + '<pre>' + esc(m.sql) + '</pre>';
  const main = document.getElementById('main'); main.innerHTML = h; main.scrollTop = 0;
  const cp = document.getElementById('cp');
  if (cp) cp.onclick = () => navigator.clipboard.writeText(m.sql).then(() => cp.textContent = 'Copied');
  const dn = document.getElementById('dn');
  if (dn) dn.onclick = () => { done[code] = !done[code]; localStorage.setItem('hol_done', JSON.stringify(done)); render(); show(code); };
}
render();
show('C1');
</script></body></html>
"""

if __name__ == "__main__":
    main()
