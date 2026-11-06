# DE3: Real-time payments: stream, mirror, serve, act

| | |
|---|---|
| **Persona** | Data Engineer (Payments Operations) |
| **Time** | ~45 min |
| **Prerequisites** | C1 only. Uses `BARCLAYS_HOL.REALTIME`, the shared interactive warehouse `HOL_INTERACTIVE_WH`, and grants to create a Snowflake Postgres instance and mirror it (all set up at provisioning) |
| **Reference** | [`de3.sql`](de3.sql), [`de3_postgres.py`](de3_postgres.py) |

## Business question
> A corporate client's payments are failing right now. How does the operations floor see it within seconds, not after tonight's dbt build, and serve that view to everyone watching at once?

## What you'll build
- A **Snowflake Postgres** instance `HOL_PAYMENTS_PG`: the operational payments database the payment engine writes to
- A live feed of payment events into Postgres, with an incident hidden in the stream
- A **Data Mirror** that streams every change from Postgres into **Snowflake-managed Iceberg** tables in `PAYMENTS_MIRROR`, with `$live` (seconds behind) and `$changes` (the change feed)
- Ops-floor queries served from the **interactive warehouse** `HOL_INTERACTIVE_WH`, straight off the mirrored table
- Dynamic table `DT_PAYMENT_INCIDENTS` that flags failing payment clusters within a minute

## End-to-end real-time analytics in Snowflake
- **Connectivity:** **Snowflake Postgres** runs the operational database inside Snowflake, and **Data Mirroring** (preview) streams its changes continuously into open Iceberg tables, with no pipeline to run. For events from apps and Kafka, **Snowpipe Streaming** (GA) writes rows into tables seconds after they happen through a pipe and named channels, and **Elastic Channels** scale it. (Snowpipe Streaming isn't used in this notebook: Workspace notebooks run in Snowpark Container Services, where its key-pair sign-in is rejected. [`de3_stream.py`](de3_stream.py) shows the SDK for an app outside Snowflake.)
- **Transformation:** dynamic tables refresh on a target lag measured in minutes or seconds. **Streaming transformations** (private preview) transform rows as they arrive.
- **Serving:** **Interactive Analytics** (GA): interactive warehouses return sub-second answers at high concurrency, directly on standard, dynamic or Iceberg tables, with no copy. They're built for dashboards, APIs and agents, with a 5 second statement limit and a 24 hour minimum run time once resumed, which is why the lab shares one.

## Steps
### Open the DE3 starter notebook
Where: the **payments-hol** Workspace (not My Workspace) > file explorer > `notebooks/de3_realtime_payments.ipynb`
Open the starter notebook `de3_realtime_payments`: it has the title and one numbered heading per step, so Cortex Code puts each cell in the right place. If you can't see the `notebooks/` and `vignettes/` folders in the file explorer, you're in the wrong Workspace: switch to **payments-hol** from the Workspace dropdown (top left) before you go on. (No starter? Use **+ > Notebook** in payments-hol and name it `de3_realtime_payments`.) Choose the compute pool **NOTEBOOK_POOL** and the warehouse **BARCLAYS_WH**, and check the role is **HOL_PARTICIPANT**. Open the notebook's settings (**⋮** > **Notebook settings** > **External access**) and turn on **HOL_NOTEBOOK_ACCESS_INTEGRATION**: the notebook installs the Postgres driver from PyPI and connects to Postgres on port 5432.
Expect: the starter notebook open in payments-hol with its numbered headings, a connected kernel and the external access integration enabled

### Create the Postgres instance
You don't write the Postgres code yourself: the Workspace has a tested helper, `vignettes/de3_realtime_payments/de3_postgres.py`, and these cells import it.
Where: the Cortex Code sidebar, with `de3_realtime_payments` open
```prompt
In the open notebook de3_realtime_payments, put each cell I ask for under its matching numbered heading. Under heading 1, add a Python cell named create_pg that runs !pip install psycopg2-binary, makes vignettes/de3_realtime_payments/de3_postgres.py importable (search upwards from the current working directory for a folder containing vignettes/de3_realtime_payments/de3_postgres.py and add that folder to sys.path), imports de3_postgres as pg, and runs host = pg.create_postgres(get_active_session()). Don't rewrite the helper and never print the password. Then add a markdown cell explaining what create_postgres does: the instance size and why, the network policy, and what happens to the one-time password.
```
Expect: the cell prints the instance moving through CREATING, STARTING and FINALIZING, then returns its host after 3 to 5 minutes. `HOL_PAYMENTS_PG` uses `STANDARD_M`, the smallest size Data Mirroring supports, with the network policy `HOL_PG_POLICY`. Its `snowflake_admin` password is shown only once, in the CREATE result, so the helper saves it straight into the secret `BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET` without printing it.
Check: de3_postgres

### Reveal the connection and connect
Where: the Lab Companion > **DE3** > **Reveal Postgres connection**, then the notebook
Click **Reveal Postgres connection**: it reads the secret and shows the host, user and password with copy buttons. Paste them into a new Python cell under heading 2:
```python
PG_HOST = "<host>"
PG_USER = "snowflake_admin"
PG_PASS = "<password>"
```
Run it, then paste this into the Cortex Code sidebar:
```prompt
Under heading 2, after my connection cell, add a Python cell named source_table that opens conn = pg.connect(PG_HOST, PG_USER, PG_PASS) and runs pg.create_source_table(conn), printing the row count it returns. Then explain the table it created in Postgres and why it has a primary key.
```
Expect: `0` rows in the new Postgres table `payments.payment_events`. The primary key lets the mirror carry updates and deletes as well as inserts. Keep the password out of anything you share. You can reveal it again any time, for example after a kernel restart. If the Lab Companion says the password wasn't saved, run `pg.reset_password(get_active_session())` and reveal again.

### Mirror Postgres into Snowflake
```prompt
Under heading 3, add a Python cell named mirror that runs pg.start_mirror(get_active_session()) and shows the result as a table. Then add a markdown cell explaining Snowflake Postgres Data Mirroring: what CREATE_MIRROR creates in PAYMENTS_MIRROR (an Iceberg table plus $live and $changes), who owns it, and what refresh_interval means.
```
Expect: `payments.payment_events` in state `REPLICATING` in the new database `PAYMENTS_MIRROR`. The mirror owns `PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS`, a Snowflake-managed Iceberg table in open Parquet, plus `PAYMENT_EVENTS$live` (the table plus changes not merged yet, so it's seconds behind) and `PAYMENT_EVENTS$changes` (the change feed). Changes merge into the base table every minute (`refresh_interval`). Nothing to schedule or run: the mirror keeps going on its own.
Check: de3_mirror

### Stream payments into Postgres
```prompt
Under heading 4, add a Python cell named stream that runs pg.stream_payments(conn, get_active_session()) to insert about 20 payment events a second into Postgres for 5 minutes, and prints the total it returns. Then explain in a markdown cell what the stream sends, including the SEPA incident in the second half.
```
Expect: the cell runs for 5 minutes, printing progress every 30 seconds, and sends about 6,000 events. While it runs, open a SQL worksheet and run `SELECT COUNT(*) FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS$live` a few times: the count climbs about 20 to 40 seconds behind Postgres. Halfway through, one corporate client's SEPA payments start failing with "Beneficiary bank unavailable".

### Measure how fresh the data is
```prompt
Under heading 5, add a SQL cell named freshness: events and failed events per minute for the last 15 minutes from PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS$live, then the seconds between the newest EVENT_TS and SYSDATE() in both PAYMENT_EVENTS$live and the base table PAYMENT_EVENTS, then the count of rows per _CHANGE_TYPE in PAYMENT_EVENTS$changes. Run it and explain what the numbers say about end-to-end latency from Postgres to Snowflake.
```
Expect: about 1,200 events a minute while streaming, with `$live` about 20 to 40 seconds behind and the base table up to a minute behind (its refresh interval). Failures jump in the second half: that's the incident. `$changes` shows one `I` (insert) per event; an update would appear as a `D` and an `I`.

### Serve the ops floor from the interactive warehouse
```prompt
Under heading 6, add a SQL cell named ops_floor that runs USE WAREHOUSE HOL_INTERACTIVE_WH, then the queries a payments operations dashboard would refresh every few seconds directly on PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS: failed payments and failed value by scheme in the last 15 minutes, and the 10 clients with the most failed value in the last 15 minutes joined to BARCLAYS_HOL.RAW_DATA.CUSTOMERS for the name. Then switch back with USE WAREHOUSE BARCLAYS_WH. Run it and explain zero-copy interactive analytics on an Iceberg table: why there's no copy or conversion, and when the 5 second statement limit matters.
```
Expect: answers from `HOL_INTERACTIVE_WH` in well under a second once it's warm, straight off the mirrored Iceberg table, with no copy. SEPA stands out, and one client has a cluster of failed SEPA payments. On a few thousand rows a standard warehouse is quick too: the interactive warehouse earns its keep when hundreds of screens, APIs or agents run these queries every few seconds at once. Heavy one-off analysis belongs on a standard warehouse, and DML is rejected, which is why the cell switches back.

### Flag incidents automatically
```prompt
Under heading 7, add a SQL cell named incidents that creates the dynamic table BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS with TARGET_LAG '1 minute' on warehouse BARCLAYS_WH: failed payments in PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS from the last 15 minutes grouped by CUSTOMER_ID (with CUSTOMER_NAME from BARCLAYS_HOL.RAW_DATA.CUSTOMERS), SCHEME and FAILURE_REASON, with the failed count, failed value, first and last failure, keeping groups with at least 5 failures. Then query it, largest first, and draft the message the operations team would send to the client's relationship manager.
```
Expect: one incident: Crown Logistics' SEPA payments failing with "Beneficiary bank unavailable", with the count, value and time window. The table refreshes every minute on its own, so the moment a new cluster starts in Postgres, it appears here. This is the same pattern as DE2's live SLA breaches, now on data streaming out of an operational database. Cortex Code automations (GOV2) could post it to the ops team.
Check: de3_incidents

## Check your work
`HOL_PAYMENTS_PG` is READY, `PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS` is replicating with at least 1,000 events, and `DT_PAYMENT_INCIDENTS` exists.

## After the lab
The Postgres instance bills while it runs. Suspend it when you're done (`ALTER POSTGRES INSTANCE HOL_PAYMENTS_PG SUSPEND`); the facilitator's teardown drops the mirror and the instance.

## Barclayflake note
One platform takes payments from the operational database to an answer in seconds: written to Snowflake Postgres, mirrored continuously into open Iceberg tables, flagged by a dynamic table, and served to every screen on the ops floor by an interactive warehouse, with the same governance as the rest of the data.
