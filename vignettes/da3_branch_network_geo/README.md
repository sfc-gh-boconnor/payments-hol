# DA3: Branch network and catchment analysis

| | |
|---|---|
| **Persona** | Data Analyst (Retail Banking) |
| **Time** | ~45 min |
| **Prerequisites** | C1 only. Uses the retail branch network in `BARCLAYS_HOL.RETAIL`, built at provisioning |
| **Reference SQL** | [`da3.sql`](da3.sql) |

## Business question
> Which branches could we consolidate, which nearby branches would absorb their customers, and how much longer would those customers have to travel?

## What you'll build
- Notebook `da3_branch_network` with a network map, drive-time catchments and an H3 density map
- Table `CUSTOMER_NEAREST_BRANCH` (every customer's fastest and second-fastest branch by real drive time)
- Table `BRANCH_CLOSURE_IMPACT` (saving, footfall, added drive time, lost walk-in access and disruption risk per branch)
- Streamlit app `BRANCH_NETWORK_MAP` with a real basemap: catchments, customer density and a closure what-if
- Semantic view `SV_BRANCH_NETWORK` and agent `BRANCH_NETWORK_ADVISOR` that answers consolidation questions in plain English

## Real travel times, not straight lines
Straight-line distance understates real journeys: rivers, one-way systems and motorways all change how far a branch really is. The retail data includes travel times from [OpenRouteService](https://openrouteservice.org/) (ORS), an open-source routing engine over OpenStreetMap roads:
- `BRANCH_CELL_TRAVEL`: drive and walk time and distance from every branch to every H3 cell (about 0.7 km²) around it, from the ORS **MATRIX** function
- `BRANCH_ISOCHRONES`: the area reachable from each branch within a 10 and 20 minute drive and a 15 minute walk, from the ORS **ISOCHRONES** function, stored as `GEOGRAPHY` polygons

These were precomputed once so the lab runs in any account.

**Compute your own:** OpenRouteService runs natively in Snowflake on Snowpark Container Services, so you can calculate travel times, isochrones and route optimisations for your own branches and customers without data leaving Snowflake. It exposes SQL functions such as `OPENROUTESERVICE_APP.CORE.MATRIX`, `ISOCHRONES`, `DIRECTIONS` and `OPTIMIZATION`. See the quickstart [Build Routing Solution in Snowflake with Snowflake CoCo](https://www.snowflake.com/en/developers/guides/oss-install-openrouteservice-native-app/).

## Steps
### Open the DA3 starter notebook
Where: the **payments-hol** Workspace (not My Workspace) > file explorer > `notebooks/da3_branch_network.ipynb`
Open the starter notebook `da3_branch_network`: it has the title and one numbered heading per step, so Cortex Code puts each cell in the right place. If you can't see the `notebooks/` and `vignettes/` folders in the file explorer, you're in the wrong Workspace: switch to **payments-hol** from the Workspace dropdown (top left) before you go on. (No starter? Use **+ > Notebook** in payments-hol and name it `da3_branch_network`.) When it asks for compute, choose the compute pool **NOTEBOOK_POOL** and the warehouse **BARCLAYS_WH**. You'll build the analysis as cells in this notebook: Cortex Code adds them for you, and you run each one. The data is a synthetic UK retail network in `BARCLAYS_HOL.RETAIL`: about 60 branches in 8 cities, ATMs, 20,000 retail customers with a home location and H3 cell, a year of branch visits, and the ORS travel times and catchments described above.
Expect: the starter notebook open in payments-hol, with its numbered headings and a connected kernel

### Map the branch network
Where: the Cortex Code sidebar, with `da3_branch_network` open
```prompt
In the open notebook da3_branch_network, put each cell I ask for under its matching numbered heading. Under heading 1, add a SQL cell named network that returns every branch from BARCLAYS_HOL.RETAIL.BRANCHES (BRANCH_NAME, CITY, FORMAT, LAT, LON) plus the standalone ATMs from BARCLAYS_HOL.RETAIL.ATMS. Then add a Python cell that plots network as an altair map: LON on x, LAT on y, branches coloured by CITY and sized by FORMAT, ATMs as small grey points, with a tooltip showing the name. Run both.
```
Expect: a scatter map of the UK with clusters of branches around eight cities. Hover over a point to see the branch.

### Measure drive-time catchments
```prompt
Add a SQL cell named catchments that uses BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES (the driving-car rows, 10 and 20 minutes) to count how many customers in BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS live inside each branch's catchment, with ST_WITHIN(HOME_LOCATION, CATCHMENT) and only customers in the branch's own city. Also show each catchment's area in km2 with ST_AREA. Then add a Python cell that draws the 10 minute drive catchments for Leeds as altair polygons (convert CATCHMENT with ST_ASGEOJSON) with the Leeds branches on top. Run both and explain what an isochrone is.
```
Expect: a table of customers within 10 and 20 minutes of each branch, and a Leeds map where the city-centre catchments almost completely overlap. An isochrone follows the road network, so catchments are irregular shapes, not circles.

### Find each customer's fastest branch
```prompt
Add a SQL cell named nearest that creates the table BARCLAYS_HOL.ANALYTICS.CUSTOMER_NEAREST_BRANCH: for every customer in BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS, the fastest and second-fastest branch in the same city by drive time, joining BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL on the customer's HOME_H3_CELL with PROFILE 'driving-car'. Columns: CUSTOMER_ID, CITY, AGE_BAND, SEGMENT, DIGITAL_ACTIVE, NEAREST_BRANCH_ID, NEAREST_DRIVE_MIN, NEAREST_DRIVE_KM, SECOND_BRANCH_ID, SECOND_DRIVE_MIN, and NEAREST_WALK_MIN (the shortest 'foot-walking' time to any branch). Run it and show the median drive and walk minutes per city.
```
Expect: all 20,000 customers, each with two branches. The median drive to a branch is about 7 minutes; walking times are much longer and vary more by city.
Check: da3_catchment

### Find overlapping branches
```prompt
Add a SQL cell named overlaps that finds pairs of branches in the same city whose 10 minute drive catchments in BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES overlap by 80% or more (area of ST_INTERSECTION divided by the smaller catchment), with the straight-line distance between them in km. Run it and explain why these pairs are consolidation candidates.
```
Expect: the Manchester, Glasgow and Leeds city-centre pairs at the top. Their customers can reach either branch in the same drive time.

### Map customer density with H3
```prompt
Add a SQL cell named density that counts BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS per HOME_H3_CELL (H3 resolution 8), returning each cell's centre LAT and LON from H3_CELL_TO_POINT, CITY and customer count. Then add a Python cell with an altair map of the cells for Cardiff, coloured by customer count, with the Cardiff branches from network layered on top. Run both.
```
Expect: a heat map of Cardiff with customers clustered around the city, and a separate pocket to the south-west around **Barry**, served by one branch. That's the branch that would be hardest to close.

### Model the closure impact
```prompt
Add a SQL cell named closure_impact that creates the table BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT from CUSTOMER_NEAREST_BRANCH, BARCLAYS_HOL.RETAIL.BRANCHES, BARCLAYS_HOL.RETAIL.BRANCH_VISITS and BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL. One row per branch: assume it closes and its customers move to their second-fastest branch. Columns: BRANCH_ID, BRANCH_NAME, CITY, FORMAT, ANNUAL_SAVING_GBP (the branch's ANNUAL_COST_GBP), VISITS_12M, COST_PER_VISIT_GBP, CUSTOMERS_AFFECTED, AVG_ADDED_DRIVE_MIN and P90_ADDED_DRIVE_MIN (SECOND_DRIVE_MIN minus NEAREST_DRIVE_MIN), LOSE_WALK_IN_ACCESS (customers within a 15 minute walk of the closing branch but not of the receiving branch, using the 'foot-walking' rows), VULNERABLE_CUSTOMERS (not digitally active or aged 75+), MAIN_RECEIVING_BRANCH (the most common second-fastest branch) and DISRUPTION_RISK (HIGH if P90_ADDED_DRIVE_MIN is 10 or more or VULNERABLE_CUSTOMERS is 200 or more, MEDIUM if P90_ADDED_DRIVE_MIN is 4 or more or LOSE_WALK_IN_ACCESS is 100 or more, otherwise LOW). Run it and list the 5 best candidates: LOW risk, highest cost per visit.
```
Expect: Leeds Boar Lane and Manchester King Street at the top: high cost, low footfall, and only a minute or two of extra driving. Barry is HIGH risk: a much longer drive for hundreds of vulnerable customers.
Check: da3_closure_impact

### Build the semantic view
Where: the Cortex Code sidebar
```prompt
Create a semantic view BARCLAYS_HOL.ANALYTICS.SV_BRANCH_NETWORK over BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT (logical table closures, primary key BRANCH_ID) and BARCLAYS_HOL.ANALYTICS.CUSTOMER_NEAREST_BRANCH (logical table customers, primary key CUSTOMER_ID, related to closures on NEAREST_BRANCH_ID). Facts for saving, visits, cost per visit, added drive minutes, lost walk-in access and vulnerable customers; dimensions for branch name, city, format, disruption risk, receiving branch, age band, segment and digital active; metrics total_saving_gbp, branch_count, customer_count and avg_drive_min. Describe the travel times as OpenRouteService drive minutes. Add a verified query for "Which branches could close with the least added travel time?". Then query it with SEMANTIC_VIEW for total saving and branch count by city and disruption risk.
```
Expect: the semantic view created, and a table of savings by city and risk tier
Check: da3_semantic_view

### Build the branch network map app
Notebook charts have no basemap, so build a Streamlit app that draws the network on a real map.
Where: payments-hol Workspace > **+ > Streamlit App**, then the Cortex Code sidebar
```prompt
Build a Streamlit in Snowflake app BARCLAYS_HOL.ANALYTICS.BRANCH_NETWORK_MAP titled "Branch network map" on the container runtime (RUNTIME_NAME SYSTEM$ST_CONTAINER_RUNTIME_PY3_11, compute pool SYSTEM_COMPUTE_POOL_CPU, query warehouse BARCLAYS_WH, external access integration PYPI_ACCESS_INTEGRATION). Use st.connection("snowflake").session(). Include a pyproject.toml next to the app file with requires-python ">=3.11" and dependencies "streamlit>=1.50", "snowflake-snowpark-python" and "pydeck", because the container runtime installs them from PyPI. Sidebar: a city picker (default Leeds) from BARCLAYS_HOL.RETAIL.BRANCHES (columns BRANCH_ID, BRANCH_NAME, CITY, FORMAT, LAT, LON), a catchment picker mapping "10 min drive", "20 min drive" and "15 min walk" to BRANCH_ISOCHRONES PROFILE/MINUTES values driving-car/10, driving-car/20 and foot-walking/15, and a customer density toggle. Draw one st.pydeck_chart with map_style "light" (a Carto basemap), centred on the mean LAT/LON of the city's branches at zoom 10.5, with three layers: a semi-transparent blue PolygonLayer of the city's BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES catchments (select ST_ASGEOJSON(CATCHMENT)::STRING, parse it with json, and take the outer ring of a Polygon or the first polygon of a MultiPolygon), an orange H3HexagonLayer of BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS counted by HOME_H3_CELL for the city with opacity scaled by count, and a dark blue ScatterplotLayer of branches (radius 180 m) on top. pydeck uses one tooltip template for all layers, so add a TIP text column to each layer's dataframe ("<BRANCH_NAME> (<FORMAT>)" for branches, "<BRANCH_NAME>: <catchment> catchment" for polygons, "<n> customers" for hexagons) and set tooltip={"text": "{TIP}"}. Below the map, show "What if a branch closes?" as a table from BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT for the city with BRANCH_NAME, ANNUAL_SAVING_GBP, COST_PER_VISIT_GBP, AVG_ADDED_DRIVE_MIN, P90_ADDED_DRIVE_MIN, LOSE_WALK_IN_ACCESS, VULNERABLE_CUSTOMERS, DISRUPTION_RISK and MAIN_RECEIVING_BRANCH, LOW risk first. Cache queries with st.cache_data.
```
Expect: a map of Leeds with streets underneath, overlapping blue catchments around Boar Lane and the city centre, orange customer hexagons and the closure table below. The first start takes a minute or two while the container starts. A reference version is in `da3_branch_map.py` and `pyproject.toml`. If the app reports a missing pyproject.toml, Streamlit version or snowflake module, ask Cortex Code to add that file with those dependencies and attach PYPI_ACCESS_INTEGRATION.
Check: da3_map_app

### Ask Cortex Analyst
Where: Snowsight > **AI & ML > Cortex Analyst** > `SV_BRANCH_NETWORK`
Ask these in plain English, one at a time: "Which 3 branches in Manchester could close with the least added travel time?", "How much could we save by closing all LOW risk branches with fewer than 500 visits?" and "Which branch closure would cost the most customers their walk-in access?"
Expect: SQL generated over the semantic view, and answers that match your notebook

### Create the branch network advisor agent
Where: payments-hol Workspace > **+ > Agent** > **Create with CoCo** (recommended)
```prompt
Create a Cortex Agent BARCLAYS_HOL.ANALYTICS.BRANCH_NETWORK_ADVISOR with display name "Branch Network Advisor" that advises a UK retail bank on its branch network. Tool: a Cortex Analyst tool Analyst on semantic view BARCLAYS_HOL.ANALYTICS.SV_BRANCH_NETWORK, on warehouse BARCLAYS_WH. Response instructions: for a consolidation question, return a ranked list of candidate branches with annual saving and cost per visit, the branch that absorbs their customers and the added drive time (average and p90 minutes), customers who lose walk-in access, the disruption risk and vulnerable customers affected, and a short 90-day transition plan. Never recommend closing a HIGH disruption-risk branch without saying why and what mitigation is needed. Sample questions: "What is the consolidation opportunity in Leeds?", "Which 3 branches could close with the least added travel time?", "Which branch would be hardest to close, and why?"
```
Expect: Cortex Code drafts the agent, you review it, and it's created. It appears in Snowsight under **AI & ML > Agents**.
Check: da3_agent

### Ask for a consolidation plan
Where: Snowsight > **AI & ML > Agents > BRANCH_NETWORK_ADVISOR**
Paste: the **BRANCH_NETWORK_ADVISOR** agent chat (not the Cortex Code sidebar)
```prompt
What is the consolidation opportunity in Leeds? Give me the candidates, the saving, which branch absorbs the customers, the extra drive time, the risk, and a 90-day transition plan.
```
Expect: Leeds Boar Lane recommended, with about GBP 690,000 a year saved, customers moving to Leeds City Centre for a minute or two of extra driving, LOW risk and a phased 90-day plan. Then ask "Should we close Barry?" and see it explain the HIGH risk. Compare the answers with your map app.

## Check your work
`CUSTOMER_NEAREST_BRANCH` covers all 20,000 customers with drive times, `BRANCH_CLOSURE_IMPACT` ranks Leeds Boar Lane and Manchester King Street as the best LOW-risk candidates, and `BRANCH_NETWORK_ADVISOR` answers consolidation questions over `SV_BRANCH_NETWORK`.

## Barclayflake note
The same pattern works on real data: geocode branch addresses to `GEOGRAPHY`, use customer postcode centroids, and run OpenRouteService on Snowpark Container Services for live travel times and catchments. Spatial joins, H3, routing and the agent all run in Snowflake, so customer locations never leave the governed platform.
