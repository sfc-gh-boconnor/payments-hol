# Retail banking data product (RB_*)

Synthetic retail banking customers on real UK geography, for the Payments HOL. Loaded by `setup/08_retail_bank_seed.sql` and published as Snowflake-managed Iceberg in `BARCLAYS_HOL.RAW_DATA`, next to `PAYMENTS`.

**Real:** property locations, postcodes, street names, area statistics and deprivation.
**Synthetic:** every person, name, house number, account, balance and transaction. No row describes a real person or a real customer.

| File | Table | Rows | Size |
| --- | --- | --- | --- |
| `rb_customers.csv.gz` | `RB_CUSTOMERS` | 20,000 | 1.7 MB |
| `rb_products.csv.gz` | `RB_PRODUCTS` | 25 | under 0.1 MB |
| `rb_accounts.csv.gz` | `RB_ACCOUNTS` | ~44,000 | 0.7 MB |
| `rb_employment.csv.gz` | `RB_EMPLOYMENT` | 20,000 | 0.3 MB |
| `rb_salary_history.csv.gz` | `RB_SALARY_HISTORY` | ~40,000 | 0.3 MB |
| `rb_monthly_snapshot.csv.gz` | `RB_MONTHLY_SNAPSHOT` | ~229,000 | 5.7 MB |
| `rb_transactions.csv.gz` | `RB_TRANSACTIONS` | ~1.3 million | 19.0 MB |

As-of date: **20 November 2026**. Snapshots cover December 2025 to November 2026. The transaction ledger covers the last 90 days for every customer still with the bank in that window.

## How it ties to the rest of the lab

- Customers live inside the DA3 drive-time footprint (`data/retail/branch_cell_travel.csv.gz`), in the same 8 cities and with the same city weights as the DA3 customers.
- `HOME_BRANCH_ID` is the nearest `RETAIL.BRANCHES` branch by drive time, and `HOME_BRANCH_DRIVE_S` is that drive time.
- Customers of the three DA3 closure candidates (`BR-MAN-90`, `BR-LDS-90`, `BR-CDF-90`) who aren't digitally active are more likely to leave (`CHURN_REASON = BRANCH_ACCESS`). Their churn rate is about twice the average, so DA3's closure question gets a revenue-at-risk answer.
- The existing DA3 tables in `BARCLAYS_HOL.RETAIL` are unchanged.

## How each field is made

**Location:**
- `HOME_LAT`, `HOME_LON`: a real OS Open UPRN property point near the postcode's centroid, rounded to 3 decimal places (about 100 m). The UPRN itself isn't published, so no synthetic person is pinned to a real household.
- `POSTCODE`: a live residential (small-user) postcode from the ONS NSPL.
- `ADDRESS_LINE_1`: a synthetic house number, plus "Flat n" for some renters, and the nearest real named road from OS Open Names. It is realistic, not an addressable home.

**Deprivation:** `IMD_DECILE` is 1 for the most deprived and 10 for the least, within each nation's own index:
- England: IMD 2025 (rank from NSPL);
- Wales: WIMD (rank from NSPL);
- Scotland: SIMD 2020v2, from the Scottish Government postcode lookup (NSPL carries no Scottish rank).

Deciles from different nations aren't directly comparable.

**Demographics:**
- `AGE`, `HOUSING_TENURE`, `HOUSEHOLD_TYPE`, `EMPLOYMENT_STATUS` and `OCCUPATION_CLASS` (NS-SeC) are drawn from the Census 2021 mix of the customer's **own LSOA**. Each customer has their own area profile, so demographics and deprivation agree with real geography.
- Draws are made consistent with age: retired only from 58, students mostly under 30, "66 and over" households only for those aged 66+, and outright ownership more likely with age.
- **Scotland:** Census 2022 data zones aren't on Nomis, so Glasgow and Edinburgh customers use the England and Wales LSOA mix for the same deprivation decile.

**Income:**
- `ANNUAL_INCOME_GBP` comes from typical earnings for the occupation class, then scaled down for part-time work, unemployment, inactivity, retirement and age under 25, and adjusted slightly by deprivation.
- These are modelled values, not ONS small-area income estimates.

**Behaviour:**
- `DIGITAL_ACTIVE` is about 72% overall. It falls with age and with deprivation: about 63% in decile 1 against 77% in decile 10.
- `PREFERRED_CHANNEL`, `CREDIT_SCORE`, `CREDIT_BAND`, `VULNERABLE_FLAG` (aged 75+, long-term sick, low-income lone parent, plus some background) and `SEGMENT` follow from the profile.

**Identity:** `FIRST_NAME`, `LAST_NAME`, `SEX` and `DATE_OF_BIRTH` are synthetic (Faker `en_GB`).

## Products, pay and affordability

**`RB_PRODUCTS`: generic product catalogue (25 products, no real bank's names)**
- **Families:** current accounts (Everyday, Plus, Premier, Student, Young Adult), savings (Easy Access, Rewards, 1- and 2-year fixed), cash ISAs, credit cards, personal and car loans, mortgages (2- and 5-year fixed, tracker, standard variable rate) and insurance (home, travel, life).
- **Per product:** monthly fee, rate, term, minimum income, minimum credit score and age, channels, launch date and whether it is still on sale.
- **Two legacy savings products** are closed to new customers and pay under 1.4%. The rate-sensitive savers who leave sit on these.

**`RB_ACCOUNTS.PRODUCT_ID` links every holding to the catalogue**
- Card and loan holders meet their product's income and score rules.
- Loans and mortgages carry `TERM_MONTHS` and `MONTHLY_PAYMENT_GBP` (amortising).
- Fixed savings, ISAs and mortgages carry a `MATURITY_DATE`. About 860 mature in the next 3 months, a retention moment.
- About 1 in 4 mortgages whose fix has ended drift onto the standard variable rate. The rest re-fix.

**`RB_EMPLOYMENT`, one row per customer**
- `INCOME_SOURCE` (salary, self-employment, pension, benefits, student income).
- A synthetic `EMPLOYER_NAME` and `EMPLOYER_SECTOR`, matched to the occupation class and shared by colleagues in the same city. The names are invented, and a check rejects any that match a list of large UK employers.
- `PAY_FREQUENCY` and `PAY_DAY`. Weekly pay is only for routine and semi-routine jobs.
- `GROSS_ANNUAL_GBP`, `INCOME_TAX_ANNUAL_GBP`, `NATIONAL_INSURANCE_ANNUAL_GBP` and `NET_MONTHLY_GBP`:
  - tax uses 2025/26 bands, with rUK thresholds frozen into 2026/27 and Scottish bands for Glasgow and Edinburgh;
  - the personal allowance tapers above £100k;
  - NI is 8% and 2% for employees, 6% and 2% for the self-employed, and none on pensions;
  - it is an estimate: no student loan, pension contributions or other deductions.
- Payroll credits in `RB_TRANSACTIONS` name the employer or payer, on the right day and frequency. `SALARY_IN_GBP` in the snapshot is net pay.

**`RB_SALARY_HISTORY`, about three years per working customer**
- Annual reviews each April, roughly in line with UK average earnings growth (5.5%, 4.8%, 3.8%).
- Promotions, and income changes for the self-employed.
- Each history ends at today's gross pay.

**Affordability on `RB_CUSTOMERS`**
- `TOTAL_DEBT_GBP`: open card, loan and mortgage balances, reconciled to the accounts.
- `DEBT_TO_INCOME`.
- `MONTHLY_COMMITMENTS_GBP`: repayments, insurance premiums, a 3% card minimum, housing (rent or mortgage, with us or another lender) and bills.
- `DISPOSABLE_INCOME_GBP`: net pay minus commitments and average card spend over the last 3 months.
- `AFFORDABILITY_BAND`: STRETCHED, TIGHT, COMFORTABLE or STRONG.

## ML signals (planted on purpose)

**Attrition**
- `CHURNED`, `CHURN_DATE` and `CHURN_REASON` on customers; `CHURNED_FLAG` on their final snapshot. About 9% leave over 12 months.
- Drivers:
  - tenure under 2 years;
  - rate-sensitive savers (over £15k at under 1.6%);
  - single-product customers;
  - non-digital customers of closure-candidate branches;
  - complaints (`COMPLAINTS_12M`);
  - age under 30;
  - mortgage holders are less likely to leave.
- In the 2-3 months before leaving: salary credits fade, balances and savings run down, app logins drop, and `FPS_OUT` switch transfers to other banks appear in the ledger.
- A plain logistic regression on customer features reaches an AUC of about 0.76.

**Profitability**
- `REVENUE_GBP`, `COST_TO_SERVE_GBP` and `PROFIT_GBP` per month.
- Revenue is deposit margin, the savings margin against the rate paid, card interest, loan and mortgage margin, overdraft interest and fees, plus interchange.
- Cost is servicing, branch visits and calls.
- About 32% of customers are unprofitable over the year. Branch-heavy and low-balance customers cost the most to serve.

**Forecasting**
- Monthly seasonality in card spend: a December peak, a January dip and a summer high (December is about 1.5x January).
- Salary on the 24th to 28th, bills at the start of the month.

**Fraud and anomalies**
- `IS_FRAUD` and `FRAUD_TYPE` on transactions, about 0.38% of rows, in four patterns:
  - **CARD_TESTING:** 4-8 tiny foreign online charges within minutes, then a large electronics purchase.
  - **IMPOSSIBLE_TRAVEL:** card-present spend in two countries 50 minutes apart.
  - **APP_SCAM:** large Faster Payments to new payees ("safe account", "HMRC refund"), mostly from customers aged 65+.
  - **ACCOUNT_TAKEOVER:** a run of night-time transfers to new payees.
- An unsupervised isolation forest on amount, hour, country, new payee and online flags reaches an AUC of about 0.98. Genuine card spend happens between 06:00 and midnight.

**Personalisation:** life stage, household, tenure, spend mix by category, product gaps (for example savers with no ISA, renters with a deposit-sized balance, card holders near their limit) and marketing consent.

## Limitations

- **Correlations between fields come from the rules above,** not from real joint distributions. Each field matches its own census distribution in the customer's area. The checks hold the tenure mix within 0.10 and the occupation mix within 0.04 total variation distance of each customer's own-LSOA census mix.
- **Homes lie within about 9 km of a branch,** the reach of the existing drive-time data.
- **Amounts, rates and costs are plausible, not calibrated** to any real bank.

## Rebuild

The build is reproducible: it uses a fixed seed, and the gzip timestamps are zeroed so unchanged data gives identical files.

```bash
python3 -m venv ~/data_sources/venv
~/data_sources/venv/bin/pip install pandas numpy h3 scikit-learn pyproj pyarrow faker openpyxl
# downloads, ~1 GB, into ~/data_sources/ogl (not committed):
#   open_uprn.zip            OS Open UPRN, CSV, GB
#   open_names.zip           OS Open Names, CSV, GB
#   nspl.zip                 ONS National Statistics Postcode Lookup (August 2026)
#   simd2020_postcodes.xlsx  SIMD 2020v2 postcode lookup (Scottish Government)
#   work/branches.csv        BARCLAYS_HOL.RETAIL.BRANCHES export
~/data_sources/venv/bin/python setup/tools/build_retail_bank.py prep      # also fetches Census 2021 from Nomis
~/data_sources/venv/bin/python setup/tools/build_retail_bank.py generate
~/data_sources/venv/bin/python setup/tools/build_retail_bank.py validate  # must end ALL CHECKS PASSED
```

## Attribution

- Contains OS data © Crown copyright and database rights 2026. OS Open UPRN and OS Open Names, used under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
- Contains Royal Mail data © Royal Mail copyright and database right 2026.
- Contains National Statistics data © Crown copyright and database right 2026: ONS National Statistics Postcode Lookup and Census 2021 (via Nomis), under the Open Government Licence v3.0.
- English Indices of Deprivation 2025 (MHCLG) and Welsh Index of Multiple Deprivation (Welsh Government), via NSPL, under the Open Government Licence v3.0.
- Scottish Index of Multiple Deprivation 2020v2, © Scottish Government, under the Open Government Licence v3.0.
