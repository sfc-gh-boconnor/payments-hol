# DS0: Tour the retail data as a data scientist

| | |
|---|---|
| **Persona** | Data Scientist |
| **Time** | ~20 min |
| **Prerequisites** | Facilitator setup complete |

## Business question
> What can we predict from the retail banking data, what does a good training set look like, and where are the traps?

## What you'll build
- Nothing yet: you tour the retail data product with Cortex Code as a data scientist (the labels, the features, the class balance and the leakage traps), then pick a model to build in DS1 or DS2.

## Steps
### Open Cortex Code
Where: Snowsight home page, the **Home / CoCo** toggle (top left) > **CoCo**
Media: start_open_coco.mp4 | Home > CoCo, then paste the first prompt
1. At the top left of Snowsight, switch the toggle from **Home** to **CoCo**.
2. Close the **CoCo mode (preview)** pop-up if it appears.
3. Press **New session**.
4. Paste each prompt in this module into the **How can I help?** box.
When Cortex Code wants to run a query, it shows a **Run this command?** card:
- **Allow** lets it run
- **Skip** stops it
**Tip:** you're signed in as `HOL_PARTICIPANT`, with `BARCLAYS_WH` and `BARCLAYS_HOL` as your defaults. Cortex Code uses them, so you don't need to set a role or warehouse.
Expect: the Cortex Code screen with a **How can I help?** box

### Find the labels
```prompt
I'm a data scientist exploring the retail banking tables in BARCLAYS_HOL.RAW_DATA (the RB_ tables). Which columns could be targets for a model? For attrition (RB_CUSTOMERS.CHURNED and CHURN_DATE) and fraud (RB_TRANSACTIONS.IS_FRAUD and FRAUD_TYPE), show the rate, the counts and how they change by month, and say how imbalanced each one is.
```
**Tip:** rare labels are normal in banking. Accuracy is a useless metric when 98% of customers stay.
Expect: about 9% of customers left over the year and about 0.4% of transactions are fraud, in four fraud types, so both labels are heavily imbalanced

### Meet the features
```prompt
For attrition, which signals in RB_CUSTOMERS, RB_ACCOUNTS joined to RB_PRODUCTS, RB_EMPLOYMENT and RB_MONTHLY_SNAPSHOT look different for customers who left? Compare leavers with stayers on tenure, product count, savings rate (and legacy savings products), salary trend, app logins, branch visits, home branch and complaints. Show it as one table.
```
Expect: leavers have shorter tenure (about 59 months against 89), fewer products and three times the complaints, and are five times as likely to be branch-reliant at one of the three closure branches. Low-rate legacy savers only stand out when the balance is large.

### Spot the leakage
```prompt
If I train an attrition model on these tables, which columns would leak the answer? Check CHURN_DATE, CHURN_REASON, RB_MONTHLY_SNAPSHOT.CHURNED_FLAG, RB_ACCOUNTS.CLOSED_DATE and STATUS, and the snapshot months just before a customer leaves. Explain how to build point-in-time features from an observation date, so the model only sees what we knew at the time.
```
**Important:** a model that sees the future looks brilliant in training and fails in production.
Expect: all of those columns leak, and so do the last months before leaving, when salary credits fade. The fix is one observation date (for example 31 Aug 2026), features only from before it, and the label from the 3 months after.

### See what fraud looks like
```prompt
For RB_TRANSACTIONS, profile the four fraud types: typical amount, hour of day, online or not, new payee, merchant country and how quickly the transactions follow each other. What features would an anomaly detector need, given we can't rely on labels for new fraud patterns?
```
Expect: card testing is a burst of tiny online payments then a big one; impossible travel is two countries within an hour; account takeover is night-time transfers to new payees; APP scams are large Faster Payments to new payees, often from older customers

### Pick your model
```prompt
Summarise what we found as a short modelling brief for two models: an attrition classifier (target, observation window, features, leakage to avoid, metric) and a fraud anomaly detector (features, how to evaluate without trusting labels). Which tables would each read?
```
Expect: a two-part brief. Then build them:
- **DS1** trains the attrition model in a notebook, tracks it in an experiment and registers it
- **DS2** (optional) builds the fraud anomaly model the same way
Check: ds0_labels_toured

## Check your work
You have profiled the retail labels and features, including the monthly snapshot and the transaction ledger.

## Barclayflake note
At Barclays a model like this goes through model risk review. Point-in-time features, a tracked experiment and a registered, versioned model are the evidence that review asks for.
