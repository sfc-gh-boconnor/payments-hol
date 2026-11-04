# DE3: Real-time payments: stream, serve, act

| | |
|---|---|
| **Persona** | Data Engineer (Payments Operations) |
| **Time** | ~40 min |
| **Prerequisites** | C1 only. Uses `BARCLAYS_HOL.REALTIME` and the shared interactive warehouse `HOL_INTERACTIVE_WH`, created at provisioning |
| **Reference** | [`de3.sql`](de3.sql), [`de3_stream.py`](de3_stream.py) |

## Business question
> A corporate client's payments are failing right now. How does the operations floor see it within seconds, not after tonight's dbt build, and serve that view to everyone watching at once?

## What you'll build
- Table `BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS`, fed by **Snowpipe Streaming** from a notebook
- About 5,000 synthetic payment events streamed in real time, with an incident hidden in the stream
- Ops-floor queries served from the **interactive warehouse** `HOL_INTERACTIVE_WH`, straight off the streamed table
- Dynamic table `DT_PAYMENT_INCIDENTS` that flags failing payment clusters within a minute

## End-to-end real-time analytics in Snowflake
- **Connectivity:** Snowpipe Streaming (GA) writes rows into tables seconds after they happen, through a **pipe** and named **channels**; every table gets a default pipe called `<TABLE>-STREAMING`. **Elastic Channels** scale ingestion without managing channels yourself. **Datastream** (public preview soon) streams change data from operational databases.
- **Transformation:** dynamic tables refresh on a target lag measured in minutes or seconds. **Streaming transformations** (private preview) transform rows as they arrive.
- **Serving:** **Interactive Analytics** (GA): interactive warehouses return sub-second answers at high concurrency, directly on standard, dynamic or Iceberg tables, with no copy. They're built for dashboards, APIs and agents, with a 5 second statement limit and a 24 hour minimum run time once resumed, which is why the lab shares one.

## Steps
### Create the DE3 notebook
Where: payments-hol Workspace > **+ > Notebook**
Name it `de3_realtime_payments`, with the compute pool **NOTEBOOK_POOL** and the warehouse **BARCLAYS_WH**. Open the notebook's settings (**⋮** > **Notebook settings** > **External access**) and turn on **HOL_NOTEBOOK_ACCESS_INTEGRATION**: the notebook installs the Snowpipe Streaming SDK from PyPI and streams to this account's endpoint.
Expect: an empty notebook with a connected kernel and the external access integration enabled

### Create the landing table
Where: the Cortex Code sidebar, with `de3_realtime_payments` open
```prompt
In the open notebook de3_realtime_payments, add a markdown cell titled "DE3: Real-time payments", then a SQL cell named landing that creates the table BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS (if it doesn't exist) with columns EVENT_ID STRING, PAYMENT_REF STRING, CUSTOMER_ID STRING, SCHEME STRING, AMOUNT NUMBER(18,2), CURRENCY STRING, STATUS STRING, FAILURE_REASON STRING, EVENT_TS TIMESTAMP_NTZ, CHANNEL_ID NUMBER, STREAM_OFFSET NUMBER and INGESTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), with a comment saying it's fed by Snowpipe Streaming. Run it and explain the default pipe PAYMENT_EVENTS-STREAMING that Snowpipe Streaming will use, and why CHANNEL_ID and STREAM_OFFSET are in the payload.
```
Expect: an empty `PAYMENT_EVENTS` table. You don't create a pipe: Snowpipe Streaming uses the default `PAYMENT_EVENTS-STREAMING` pipe. `CHANNEL_ID` and `STREAM_OFFSET` let you find gaps or duplicates later, per channel.

### Install the SDK and give yourself a key
```prompt
Add a Python cell named setup_stream that runs !pip install snowpipe-streaming, then generates an RSA key pair in memory with the cryptography package and registers the public key on my own user with ALTER USER ADD KEY PAIR DE3_STREAMING_KEY PUBLIC_KEY = '<base64 DER public key>' ROLE_RESTRICTION = 'HOL_PARTICIPANT' DAYS_TO_EXPIRY = 1 (remove any existing DE3_STREAMING_KEY first in a try/except), using get_active_session(). Keep the private key in a variable called key; never print or save it. Use vignettes/de3_realtime_payments/de3_stream.py in the Workspace as the reference.
```
Expect: the SDK installed and `DE3_STREAMING_KEY` registered on your user. Streaming clients authenticate with a key pair; this one is tied to `HOL_PARTICIPANT` and expires tomorrow.

### Stream payments in real time
```prompt
Add a Python cell named stream that opens a Snowpipe Streaming client (snowflake.ingest.streaming.StreamingIngestClient) for BARCLAYS_HOL.REALTIME pipe PAYMENT_EVENTS-STREAMING as my user with key, using account <ORG>-<ACCOUNT>, url https://<org>-<account>.snowflakecomputing.com:443 with underscores replaced by hyphens, and role HOL_PARTICIPANT in the profile JSON (write it to a private temp file and delete it once the client is open). Open channel payments_feed_1 and append 5,000 payment events at about 100 a second: customers from BARCLAYS_HOL.RAW_DATA.CUSTOMERS, schemes FASTER_PAYMENTS, BACS, CHAPS, SEPA and SWIFT, about 3% failed. In the second half, 15% of events are failed SEPA payments for one client with FAILURE_REASON 'Beneficiary bank unavailable'. Use each event's sequence number as the offset token and STREAM_OFFSET. Wait until the last offset is committed, print it and close the client. Follow stream_payments in de3_stream.py.
```
Expect: the cell runs for about a minute and prints a committed offset of `5000`. While it runs, open a SQL worksheet and run `SELECT COUNT(*) FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS` a few times: the count climbs as events land, seconds after they're sent.
Check: de3_events

### Measure how fresh the data is
```prompt
Add a SQL cell named freshness over BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS: events per minute for the last 15 minutes, failed events per minute, and the median and 95th percentile seconds between EVENT_TS and INGESTED_AT (convert INGESTED_AT to UTC and TIMESTAMP_NTZ first). Run it and explain what the numbers say about end-to-end latency.
```
Expect: about 6,000 events a minute while streaming (the stream cell sends about 100 a second), each queryable within seconds of being sent. Failures jump in the second half of the run: that's the incident.

### Serve the ops floor from the interactive warehouse
```prompt
Add a SQL cell named ops_floor that runs USE WAREHOUSE HOL_INTERACTIVE_WH, then the queries a payments operations dashboard would refresh every few seconds directly on BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS: failed payments and failed value by scheme in the last 10 minutes, and the 10 clients with the most failed value in the last 10 minutes joined to BARCLAYS_HOL.RAW_DATA.CUSTOMERS for the name. Then switch back with USE WAREHOUSE BARCLAYS_WH. Run it and explain zero-copy interactive analytics: why there's no copy or conversion of the table, and when the 5 second statement limit matters.
```
Expect: answers from `HOL_INTERACTIVE_WH` in about half a second once it's warm, straight off the table you're streaming into, with no copy. One client stands out with a cluster of failed SEPA payments. On a few thousand rows a standard warehouse is quick too: the interactive warehouse earns its keep when hundreds of screens, APIs or agents run these queries every few seconds at once. Heavy one-off analysis belongs on a standard warehouse, and DML is rejected, which is why the cell switches back.

### Flag incidents automatically
```prompt
Add a SQL cell named incidents that creates the dynamic table BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS with TARGET_LAG '1 minute' on warehouse BARCLAYS_WH: failed payments in PAYMENT_EVENTS from the last 15 minutes grouped by CUSTOMER_ID (with CUSTOMER_NAME from BARCLAYS_HOL.RAW_DATA.CUSTOMERS), SCHEME and FAILURE_REASON, with the failed count, failed value, first and last failure, keeping groups with at least 5 failures. Then query it, largest first, and draft the message the operations team would send to the client's relationship manager.
```
Expect: one incident: a single client's SEPA payments failing with "Beneficiary bank unavailable", with the count, value and time window. The table refreshes every minute on its own, so the moment a new cluster starts, it appears. This is the same pattern as DE2's live SLA breaches, now on streamed data. Cortex Code automations (GOV2) could post it to the ops team.
Check: de3_incidents

## Check your work
`PAYMENT_EVENTS` holds at least 1,000 streamed events, and `DT_PAYMENT_INCIDENTS` exists. Remove your key when you're done: `ALTER USER REMOVE KEY PAIR DE3_STREAMING_KEY` (it expires tomorrow anyway).

## Barclayflake note
One platform takes payments from event to answer in seconds: streamed in through Snowpipe Streaming, flagged by a dynamic table, and served to every screen on the ops floor by an interactive warehouse, with the same governance as the rest of the data.
