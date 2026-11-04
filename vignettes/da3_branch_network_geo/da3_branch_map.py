"""DA3 reference Streamlit app: branch network map (Streamlit in Snowflake, container runtime).

Real basemap (Carto) via st.pydeck_chart: branches, ORS drive/walk catchments,
H3 customer density, and a closure what-if from BRANCH_CLOSURE_IMPACT.
"""
import json

import pandas as pd
import pydeck as pdk
import streamlit as st

st.set_page_config(layout="wide")
session = st.connection("snowflake").session()


@st.cache_data(ttl=600)
def load(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


branches = load("SELECT BRANCH_ID, BRANCH_NAME, CITY, FORMAT, LAT, LON FROM BARCLAYS_HOL.RETAIL.BRANCHES")
st.title("Branch network")

city = st.sidebar.selectbox("City", sorted(branches.CITY.unique()), index=sorted(branches.CITY.unique()).index("Leeds"))
mode = st.sidebar.radio("Catchment", ["10 min drive", "20 min drive", "15 min walk"])
show_density = st.sidebar.checkbox("Customer density (H3)", value=True)
profile, minutes = {"10 min drive": ("driving-car", 10), "20 min drive": ("driving-car", 20),
                    "15 min walk": ("foot-walking", 15)}[mode]

b = branches[branches.CITY == city].copy()
b["TIP"] = b.BRANCH_NAME + " (" + b.FORMAT + ")"
iso = load(f"""
    SELECT i.BRANCH_ID, b.BRANCH_NAME, ST_ASGEOJSON(i.CATCHMENT)::STRING AS GJ
    FROM BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES i JOIN BARCLAYS_HOL.RETAIL.BRANCHES b USING (BRANCH_ID)
    WHERE b.CITY = '{city}' AND i.PROFILE = '{profile}' AND i.MINUTES = {minutes}""")
iso["polygon"] = iso.GJ.apply(lambda g: json.loads(g)["coordinates"][0] if json.loads(g)["type"] == "Polygon"
                              else json.loads(g)["coordinates"][0][0])
iso["TIP"] = iso.BRANCH_NAME + f": {mode} catchment"

layers = [pdk.Layer("PolygonLayer", iso, get_polygon="polygon", get_fill_color=[41, 181, 232, 40],
                    get_line_color=[41, 181, 232, 200], line_width_min_pixels=1, pickable=True)]
if show_density:
    dens = load(f"""SELECT HOME_H3_CELL AS H3, COUNT(*) AS CUSTOMERS FROM BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS
                    WHERE CITY = '{city}' GROUP BY 1""")
    dens["TIP"] = dens.CUSTOMERS.astype(str) + " customers"
    layers.append(pdk.Layer("H3HexagonLayer", dens, get_hexagon="H3", get_fill_color="[255, 140, 0, CUSTOMERS * 6]",
                            extruded=False, pickable=True))
layers.append(pdk.Layer("ScatterplotLayer", b, get_position="[LON, LAT]", get_radius=180,
                        get_fill_color=[17, 86, 127, 230], pickable=True))

st.pydeck_chart(pdk.Deck(
    map_style="light",
    initial_view_state=pdk.ViewState(latitude=b.LAT.mean(), longitude=b.LON.mean(), zoom=10.5),
    layers=layers,
    tooltip={"text": "{TIP}"},
))

st.subheader("What if a branch closes?")
impact = load(f"""SELECT BRANCH_NAME, ANNUAL_SAVING_GBP, COST_PER_VISIT_GBP, AVG_ADDED_DRIVE_MIN, P90_ADDED_DRIVE_MIN,
                         LOSE_WALK_IN_ACCESS, VULNERABLE_CUSTOMERS, DISRUPTION_RISK, MAIN_RECEIVING_BRANCH
                  FROM BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT WHERE CITY = '{city}'
                  ORDER BY DISRUPTION_RISK = 'LOW' DESC, COST_PER_VISIT_GBP DESC""")
st.dataframe(impact, hide_index=True, width="stretch")
