-- =====================================================
-- DE3: Real-time payments - reference SQL
-- Streaming itself is Python (de3_stream.py); this is the SQL around it.
-- =====================================================
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;

-- 1. Landing table. Snowpipe Streaming writes to it through its default pipe PAYMENT_EVENTS-STREAMING.
CREATE TABLE IF NOT EXISTS BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS (
    EVENT_ID       STRING,
    PAYMENT_REF    STRING,
    CUSTOMER_ID    STRING,
    SCHEME         STRING,
    AMOUNT         NUMBER(18,2),
    CURRENCY       STRING,
    STATUS         STRING,
    FAILURE_REASON STRING,
    EVENT_TS       TIMESTAMP_NTZ,
    CHANNEL_ID     NUMBER,           -- with STREAM_OFFSET, finds gaps or duplicates per channel
    STREAM_OFFSET  NUMBER,
    INGESTED_AT    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DE3: payment events streamed with Snowpipe Streaming';

-- 2. Your streaming key (registered from the notebook with ALTER USER ADD KEY PAIR)
SHOW USER KEY PAIRS;

-- 3. Freshness: events per minute and end-to-end latency, last 15 minutes
SELECT DATE_TRUNC('minute', EVENT_TS)                     AS MINUTE,
       COUNT(*)                                           AS EVENTS,
       COUNT_IF(STATUS = 'FAILED')                        AS FAILED,
       MEDIAN(DATEDIFF('millisecond', EVENT_TS, CONVERT_TIMEZONE('UTC', INGESTED_AT)::TIMESTAMP_NTZ)) / 1000 AS MEDIAN_LAG_S,
       APPROX_PERCENTILE(DATEDIFF('millisecond', EVENT_TS, CONVERT_TIMEZONE('UTC', INGESTED_AT)::TIMESTAMP_NTZ), 0.95) / 1000 AS P95_LAG_S
FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS
WHERE EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1
ORDER BY 1;

-- 4. Ops floor on the shared interactive warehouse: zero-copy, straight off the streamed table
USE WAREHOUSE HOL_INTERACTIVE_WH;

SELECT SCHEME, COUNT(*) AS FAILED_PAYMENTS, SUM(AMOUNT) AS FAILED_VALUE
FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS
WHERE STATUS = 'FAILED' AND EVENT_TS >= DATEADD('minute', -10, SYSDATE())
GROUP BY SCHEME
ORDER BY FAILED_VALUE DESC;

SELECT c.CUSTOMER_NAME, e.SCHEME, COUNT(*) AS FAILED_PAYMENTS, SUM(e.AMOUNT) AS FAILED_VALUE
FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS e
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = e.CUSTOMER_ID
WHERE e.STATUS = 'FAILED' AND e.EVENT_TS >= DATEADD('minute', -10, SYSDATE())
GROUP BY 1, 2
ORDER BY FAILED_VALUE DESC
LIMIT 10;

-- Interactive warehouses reject DML and procedures: switch back before creating anything
USE WAREHOUSE BARCLAYS_WH;

-- 5. Incidents: failing clusters in the last 15 minutes, refreshed every minute
CREATE OR REPLACE DYNAMIC TABLE BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS
  TARGET_LAG = '1 minute'
  WAREHOUSE = BARCLAYS_WH
  COMMENT = 'DE3: failing payment clusters in the last 15 minutes, refreshed every minute'
AS
SELECT e.CUSTOMER_ID,
       c.CUSTOMER_NAME,
       e.SCHEME,
       e.FAILURE_REASON,
       COUNT(*)         AS FAILED_PAYMENTS,
       SUM(e.AMOUNT)    AS FAILED_VALUE,
       MIN(e.EVENT_TS)  AS FIRST_FAILURE,
       MAX(e.EVENT_TS)  AS LAST_FAILURE
FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS e
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = e.CUSTOMER_ID
WHERE e.STATUS = 'FAILED'
  AND e.EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) >= 5;

SELECT * FROM BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS ORDER BY FAILED_PAYMENTS DESC;

-- 6. Clean up
-- ALTER USER REMOVE KEY PAIR DE3_STREAMING_KEY;
