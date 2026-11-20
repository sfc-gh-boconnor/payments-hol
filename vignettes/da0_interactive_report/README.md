# DA0: Interactive payments report with Cortex Code

| | |
|---|---|
| **Persona** | Data Analyst |
| **Time** | ~30 min |
| **Prerequisites** | Core C1 only |

## Business question
> Can ops and RMs get the client 360 from C1 as a live, interactive report they can filter themselves, refreshed every morning?

## What you'll build
- An interactive, Barclays-branded HTML payments report, built by Cortex Code
- Your own variation of it: new brand, charts or filters
- A daily Cortex Code automation that rebuilds the report with fresh data

## Steps
### Build an interactive report
Where: the **CoCo** tab, in your C1 session or a **New session**
1. Paste the prompt below into the **How can I help?** box.
2. Press **Allow** on each **Run this command?** card while it queries and builds.
3. Open the preview link Cortex Code gives you.
```prompt
Using the payments, accounts, customers, relationship managers and feedback tables in BARCLAYS_HOL.RAW_DATA, build an interactive HTML report of corporate payments health. Show headline figures, a monthly trend, a breakdown by payment type, and a sortable table of clients with their RM, failed payments and feedback. Let me filter by payment type, region and channel. Brand it Barclays (navy and cyan, red for failures). My role is read-only. Preview it and give me the link.
```
Paste: the **How can I help?** box in the **CoCo** tab
Expect: Cortex Code explores the tables, builds the report and gives you a preview link

### Make it yours
Where: the same CoCo session
Now ask for your own changes, one prompt at a time. Some ideas:
- **Rebrand it:** "Re-skin the report in Snowflake brand colours: Snowflake Blue #29B5E8, Mid Blue #11567F, Midnight #000000."
- **Add a chart:** "Add a heatmap of failure rate by region and payment type."
- **Add a filter:** "Add a relationship manager filter that also filters the client table."
- **Explain the numbers:** "Add a short summary at the top of the three things ops should act on this week."
- **Make it for one audience:** "Make a one-page version for RMs that only shows their own clients."
1. Paste one idea, or write your own.
2. Open the new preview link and check the change.
3. Repeat until you're happy with it.
**Tip:** ask for one change at a time. If something breaks, say "undo the last change".
Expect: an updated preview after each prompt, with your changes and the totals unchanged

### Refresh the report every morning
Where: the same CoCo session
The report embeds its data, so it shows the numbers from when it was built. A daily automation rebuilds it with fresh data.
1. Paste the prompt below.
2. Check the summary Cortex Code shows: name, schedule and read-only.
3. Let it run once now, so you can see the refreshed report.
4. Find it later under **Automations** in the CoCo side nav (below **New session**).
```prompt
Set up a daily Cortex Code automation called PAYMENTS_REPORT_REFRESH that runs at 07:00 Europe/London. Each run: re-run the queries behind the interactive payments report we just built, rebuild the same report with today's data, check the totals against BARCLAYS_HOL.RAW_DATA, and save it in the same place with today's date in the definitions section. It runs unattended, so it must not ask questions and must stay read-only. Create it paused, run it once now so I can see the result, then start the schedule.
```
Paste: the **How can I help?** box in the **CoCo** tab
Expect: Cortex Code summarises the automation, creates it paused, runs it once and shows the rebuilt report, then asks before starting the schedule. Each run uses your default role (`HOL_PARTICIPANT`).

## Check your work
Your report preview opens, filters change the headline figures, and **Reset** brings them back to 50,000 payments.

## Barclayflake note
At Barclays the same report would read from the governed data product views rather than RAW_DATA, and be shared through Snowflake Intelligence instead of a preview link.
