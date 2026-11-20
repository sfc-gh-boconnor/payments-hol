-- DA0: the totals the interactive report must match (Cortex Code builds the report itself).
-- Run as HOL_PARTICIPANT on BARCLAYS_WH. Expect 50,000 payments, 428 failed, 96.08% success.
SELECT COUNT(*)                                                       AS payments,
       COUNT_IF(STATUS = 'FAILED')                                    AS failed,
       COUNT_IF(STATUS = 'RETURNED')                                  AS returned,
       ROUND(100 * COUNT_IF(STATUS = 'COMPLETED') / COUNT(*), 2)      AS success_rate_pct,
       ROUND(SUM(IFF(CURRENCY = 'GBP', AMOUNT, AMOUNT * FX_RATE)) / 1e9, 1) AS gbp_volume_bn
FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS;
