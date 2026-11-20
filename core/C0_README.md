# C0: Tour the data estate

| | |
|---|---|
| **Persona** | All personas |
| **Time** | ~20 min |
| **Prerequisites** | Facilitator setup complete |

## Business question
> What data do we have, how does it fit together, and which part do I want to work on today?

## What you'll build
- Nothing yet: you tour every data product in the account with Cortex Code, from corporate payments to retail customers and the branch network, then pick where to zoom in.

## Steps
### Open Cortex Code
Where: Snowsight home page, the **Home / CoCo** toggle (top left) > **CoCo**
Media: start_open_coco.mp4 | Home > CoCo, then paste the first prompt
1. At the top left of Snowsight, switch the toggle from **Home** to **CoCo**.
2. Close the **CoCo mode (preview)** pop-up if it appears.
3. Press **New session**.
4. Paste each prompt in this module into the **How can I help?** box.
What's on the CoCo screen:
- **New session** starts a fresh chat. Start one for each module, so it begins with a clean context.
- **Automations** lists prompts scheduled to run on their own. You'll create one in GOV2.
When Cortex Code wants to run a query, it shows a **Run this command?** card:
- **Allow** lets it run
- **Skip** stops it
**Tip:** you're signed in as `HOL_PARTICIPANT`, with `BARCLAYS_WH` and `BARCLAYS_HOL` as your defaults. Cortex Code uses them, so you don't need to set a role or warehouse.
Expect: the Cortex Code screen with a **How can I help?** box

### What data do we have?
```prompt
Give me a tour of the BARCLAYS_HOL database. For the RAW_DATA, RETAIL, ANALYTICS and AUDIT_PACK schemas, list every table with its row count and say whether it is Iceberg. Group them into data products: corporate payments, retail banking (the RB_ tables), branch network, analytics and governance.
```
**Tip:** the **Data map** page of this app (top right) shows the same estate as a picture.
Expect: about 35 tables in five data products: nine corporate payments Iceberg tables (PAYMENTS has 50,000 rows), seven RB_ retail Iceberg tables (20,000 customers, about 1.3 million transactions), 57 branches with ATMs and drive times, and analytics and governance tables that fill in as you build

### How does it fit together?
```prompt
How do these data products join? Draw a simple text diagram of the keys between them: corporate payments to accounts, customers and relationship managers, and retail customers to their home branch, products, employer and transactions. Point out any links that cross from one data product to another.
```
**Tip:** compare the diagram with the **Data map** page. The joins should match.
Expect: corporate PAYMENTS > ACCOUNTS > CUSTOMERS > RELATIONSHIP_MANAGERS; retail RB_CUSTOMERS > RB_ACCOUNTS > RB_PRODUCTS, plus RB_EMPLOYMENT and RB_TRANSACTIONS; and the bridge RB_CUSTOMERS.HOME_BRANCH_ID > RETAIL.BRANCHES, where retail customers meet the branch network

### Meet a retail customer
```prompt
Pick one salaried retail customer from BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS who holds a mortgage. Show me their profile and area deprivation decile, their home branch and drive time from RETAIL.BRANCHES, their employer, gross and net monthly pay from RB_EMPLOYMENT, every product they hold by name from RB_ACCOUNTS joined to RB_PRODUCTS, their affordability band, and their last ten transactions.
```
**Tip:** the people are synthetic. The addresses, postcodes and area statistics are real open data.
Expect: one customer end to end: a real UK address, a home branch a few minutes' drive away, an employer and payroll credits on their pay day, products by name (such as a fixed mortgage and an easy access saver) and an affordability band
Check: c0_retail_toured

### Meet a corporate client
```prompt
Now do the same for one corporate client in BARCLAYS_HOL.RAW_DATA.CUSTOMERS: their relationship manager, accounts, payment count and failure rate by payment scheme, and their most recent feedback.
```
Expect: one client, their RM, a few accounts, a failure rate by scheme (CHAPS, BACS, FPS and so on) and a feedback comment

### Pick your zoom
```prompt
Based on what we've seen, suggest three questions a retail bank could answer with this data, one each for attrition, product affordability and fraud, and say which tables each would need.
```
Next: **C1** zooms into one data product, the corporate payments Iceberg tables. Every pathway starts there, then goes its own way.
Expect: three questions, each with the tables it would use
Check: c0_estate_published

## Check your work
Every data product is in your account, and you have queried the retail customer, product and employment tables.

## Barclayflake note
At Barclays these would be separate data products with their own owners: payments operations, retail customer, branch network. Snowflake keeps them in one governed account, so a question that crosses them is a join, not a project.
