# OPS3: Payments operations in Snowflake CoWork

| | |
|---|---|
| **Persona** | Payments Ops lead / relationship manager (business user) |
| **Time** | ~45 min |
| **Prerequisites** | C1 only. Uses the ready-made agent **Payments Ops CoWork** (`SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_OPS_COWORK`), built at provisioning |
| **Reference** | [`ops3.sql`](ops3.sql) |

## Business question
> I run payments operations, not SQL. Can I ask about failures in plain English, get a chart I can keep, investigate why a sector is getting worse, have the weekly numbers sent to me automatically, hand a relationship manager a briefing deck, and publish a dashboard my team opens every morning?

## What you'll build
- A saved **chart artifact** and a shared **thread** from a CoWork conversation
- A **Deep Research** report on why a sector's payment failures are rising
- A weekly CoWork **automation**
- A generated **PowerPoint briefing** for a relationship manager
- An **AI dashboard** built by Cortex Code in the Workspace, published as a dashboard artifact and opened in CoWork

## Snowflake CoWork
Snowflake CoWork (formerly Snowflake Intelligence) is the agentic app for business users: they ask questions in plain English and agents answer with governed SQL, charts and documents. Everything respects the same row access policies, masking and roles as the rest of Snowflake. The agent you use here, **Payments Ops CoWork**, has two tools: a Cortex Analyst tool over the semantic view `BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS` (a year of payments with client, sector, relationship manager and client feedback), and the **code execution** tool, which CoWork uses to build documents.

## Steps
### Open CoWork with the payments agent
Where: Snowsight > **AI & ML > CoWork** (or the CoWork app), then choose the agent **Payments Ops CoWork**
CoWork opens on its own page. Pick **Payments Ops CoWork** in the agent picker and check the role is **HOL_PARTICIPANT** and the warehouse **BARCLAYS_WH** (the settings under your name).
Paste: the **CoWork** chat box (not the Cortex Code sidebar)
```prompt
What can you tell me about our payments? Give me a short overview of volume, failures and the clients and schemes that matter most this year.
```
Expect: a plain-English overview with a few numbers and a table or chart. Open **Show details** under the answer to see the SQL the agent generated and the semantic view it used: every answer is traceable.
Check: ops3_cowork_used

### Make a chart and save it
Paste: the **CoWork** chat box
```prompt
Show monthly failed payment value by scheme for the last 12 months as a stacked bar chart, with SEPA in red.
```
Expect: a stacked bar chart, with a note on how it was built. Use the chart's **Save** option to keep it as a **chart artifact**: it re-runs its query when you open it, with your own access, so it stays current. Then use **Share** on the conversation to save it as a **thread** snapshot. Find both under **Projects > Artifacts**.

### Investigate with Deep Research
Paste: the **CoWork** chat box. Choose **+ > Deep Research** first.
```prompt
What are Logistics clients saying in their feedback over the last four months compared with the rest of the year, are any of them talking about leaving us, do their payment failures explain it, and what should their relationship managers do first?
```
Expect: CoWork splits the question into several investigations, runs them in parallel and writes a structured report in up to 10 minutes, with every claim traced to its query. Logistics feedback has turned negative recently, and Logistics clients are the only ones talking about reviewing other banks, moving their payments or tendering their banking (the same story DA2 finds). Their payment failure rate isn't unusually high, so the report should point at service and communication rather than payment failures: that's the kind of conclusion a single chart wouldn't give you. Ask a follow-up such as "break that down by relationship manager": it runs as a normal chat turn on top of the report.

### Get the numbers every week
Paste: the **CoWork** chat box
```prompt
Every Monday at 8am, show me the 5 clients with the most failed payment value in the previous week, with their relationship manager and main failing scheme. Set this up as an automation.
```
Expect: CoWork offers to create an **automation** that re-runs the question on fresh data on that schedule. Accept it, then open the **Automations** tab to see it, run it once now and read the result there. (Lab users have no email address, so the result isn't emailed.) Pause or delete it at the end of the lab.

### Generate a briefing for the relationship manager
Paste: the **CoWork** chat box
```prompt
Create a one-page PowerPoint briefing for Crown Logistics' relationship manager: payment volume and success rate over the last 12 months, failed payments by scheme, what the client has said in recent feedback, and three recommended actions for the next client call.
```
Expect: a **.pptx** you can preview and download, built by the agent's code execution tool from the data it just queried. You can upload your own PowerPoint template so documents match house style. The file can be saved as a **file artifact** to share.

### Build an AI dashboard with Cortex Code
Where: payments-hol Workspace > **+ > Dashboard** (Preview), then the Cortex Code sidebar
Create a dashboard named `payments_ops`, then ask Cortex Code to build it. Dashboards are stored as a `.dash` file in the Workspace: each tile is a SQL query rendered as a chart, table or text.
```prompt
Using the /dashboard skill, build the open dashboard payments_ops on the semantic view BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS (or the views PAYMENT_ACTIVITY and CLIENT_FEEDBACK in BARCLAYS_HOL.COWORK_PACK). Add a scorecard row with total payment value, success rate and failed value for the selected period; a stacked bar chart of monthly failed value by scheme; a table of the top 10 clients by failed value with sector and relationship manager; and a bar chart of failed payments by error code. Add filters for scheme and sector and a date range defaulting to the last 12 months, and make clicking a scheme in the failed value chart filter the other tiles.
```
Expect: a dashboard with live tiles, filters and a chart action, all SQL you can open and edit. Iterate in plain English ("make the trend weekly", "add a feedback rating tile"). Check the numbers match what CoWork told you.

### Publish the dashboard to CoWork
Where: the open `payments_ops` dashboard > **Share**
Under **Who has access**, add the role **HOL_PARTICIPANT** with **Can view**, then **Create**. The link is copied to your clipboard. Open it: the dashboard opens in **CoWork**, where you can ask a follow-up on any tile, for example "why did SEPA failures jump in this month?".
Expect: the published dashboard in CoWork and under **Projects > Artifacts**. Tiles run with each viewer's own privileges (caller's rights), so a viewer who can't see a table sees no data. Publishing later changes from the Workspace keeps the same link.

## Check your work
`ops3_cowork_used` passes once you've asked **Payments Ops CoWork** a question. The chart, thread, automation, document and dashboard are artifacts you can see under **Projects > Artifacts** and in CoWork's Automations tab; Snowflake doesn't yet expose artifacts to SQL, so there's no automatic check for them.

## Barclayflake note
The payments ops lead gets answers, investigations, recurring reports, client-ready documents and a team dashboard in one governed place, from the same semantic view and with the same access controls the data team set up, instead of waiting for a new report.
