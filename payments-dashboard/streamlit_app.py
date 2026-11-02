import os
import streamlit as st

st.set_page_config(
    page_title="Payments Ops",
    page_icon=":material/payments:",
    layout="wide",
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=300)
def load_kpis():
    return conn.query("""
        SELECT PAYMENT_TYPE, REGION, CHANNEL, CUSTOMER_SECTOR, RM_NAME, RM_TEAM,
               PAYMENT_DAY, TOTAL_PAYMENTS, TOTAL_VOLUME_GBP, SUCCESS_RATE_PCT,
               AVG_PROCESSING_TIME_MS, P95_PROCESSING_TIME_MS,
               SUCCESSFUL_PAYMENTS, FAILED_PAYMENTS
        FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
    """)


@st.cache_data(ttl=300)
def load_sla():
    return conn.query("""
        SELECT PAYMENT_TYPE, PAYMENT_DAY, SLA_NAME,
               SLA_TARGET_PCT, SLA_THRESHOLD_MS,
               ACTUAL_SUCCESS_RATE, ACTUAL_P95_MS,
               TOTAL_PAYMENTS, FAILED_PAYMENTS, SLA_STATUS
        FROM BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE
    """)


@st.cache_data(ttl=300)
def load_error_summary():
    return conn.query("""
        SELECT e.ERROR_CATEGORY, e.ERROR_DESCRIPTION, e.IS_RETRYABLE,
               COUNT(*) AS ERROR_COUNT
        FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS p
        JOIN BARCLAYS_HOL.RAW_DATA.ERROR_CODES e ON p.ERROR_CODE = e.ERROR_CODE
        WHERE p.STATUS IN ('FAILED','RETURNED')
        GROUP BY e.ERROR_CATEGORY, e.ERROR_DESCRIPTION, e.IS_RETRYABLE
        ORDER BY ERROR_COUNT DESC
    """)


def fmt_num(n):
    if abs(n) >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f}B"
    if abs(n) >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if abs(n) >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(int(n))


with st.spinner("Loading payments data..."):
    kpis = load_kpis()
    sla = load_sla()
    errors = load_error_summary()

# --- Sidebar filters ---
with st.sidebar:
    st.markdown("### :material/filter_list: Filters")

    scheme_options = sorted(kpis["PAYMENT_TYPE"].unique())
    selected_schemes = st.multiselect("Payment scheme", scheme_options, default=scheme_options)

    region_options = sorted(kpis["REGION"].unique())
    selected_regions = st.multiselect("Region", region_options, default=region_options)

    sector_options = sorted(kpis["CUSTOMER_SECTOR"].dropna().unique())
    selected_sectors = st.multiselect("Sector", sector_options, default=sector_options)

    rm_options = sorted(kpis["RM_NAME"].dropna().unique())
    selected_rms = st.multiselect("Relationship manager", rm_options, default=rm_options)

    if st.button(
        ":material/refresh: Reload data", on_click=lambda: (
            load_kpis.clear(), load_sla.clear(), load_error_summary.clear()
        )
    ):
        st.rerun()

filtered = kpis[
    (kpis["PAYMENT_TYPE"].isin(selected_schemes))
    & (kpis["REGION"].isin(selected_regions))
    & (kpis["CUSTOMER_SECTOR"].isin(selected_sectors) | kpis["CUSTOMER_SECTOR"].isna())
    & (kpis["RM_NAME"].isin(selected_rms) | kpis["RM_NAME"].isna())
]

st.title("Payments operations")

# --- Headline KPIs ---
total_payments = int(filtered["TOTAL_PAYMENTS"].sum())
total_volume = filtered["TOTAL_VOLUME_GBP"].sum()
total_successful = int(filtered["SUCCESSFUL_PAYMENTS"].sum())
total_failed = int(filtered["FAILED_PAYMENTS"].sum())
overall_success = round(total_successful / max(total_payments, 1) * 100, 2)
avg_p95 = round(filtered["P95_PROCESSING_TIME_MS"].mean(), 0) if len(filtered) > 0 else 0

with st.container(horizontal=True):
    st.metric("Total payments", fmt_num(total_payments), border=True)
    st.metric("Volume", f"£{fmt_num(total_volume)}", border=True)
    st.metric("Success rate", f"{overall_success}%", border=True)
    st.metric("Failed", fmt_num(total_failed), border=True)
    st.metric("P95 latency", f"{int(avg_p95)} ms", border=True)

# --- Tabs ---
tab_volume, tab_sla, tab_errors = st.tabs([
    ":material/bar_chart: Volume & performance",
    ":material/verified: SLA compliance",
    ":material/error: Error analysis",
])

# ===== TAB 1: Volume =====
with tab_volume:
    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True, height="stretch"):
            st.subheader("Daily payment volume")
            daily = (
                filtered.groupby("PAYMENT_DAY")["TOTAL_PAYMENTS"]
                .sum().reset_index().sort_values("PAYMENT_DAY")
            )
            st.area_chart(daily, x="PAYMENT_DAY", y="TOTAL_PAYMENTS", color="#00D4AA")

    with col2:
        with st.container(border=True, height="stretch"):
            st.subheader("Volume by scheme")
            by_scheme = (
                filtered.groupby("PAYMENT_TYPE")["TOTAL_PAYMENTS"]
                .sum().reset_index().sort_values("TOTAL_PAYMENTS", ascending=False)
            )
            st.bar_chart(by_scheme, x="PAYMENT_TYPE", y="TOTAL_PAYMENTS", color="#00D4AA", horizontal=True)

    col3, col4 = st.columns(2)

    with col3:
        with st.container(border=True, height="stretch"):
            st.subheader("Volume by sector")
            by_sector = (
                filtered.dropna(subset=["CUSTOMER_SECTOR"])
                .groupby("CUSTOMER_SECTOR")["TOTAL_PAYMENTS"]
                .sum().reset_index().sort_values("TOTAL_PAYMENTS", ascending=False)
            )
            st.bar_chart(by_sector, x="CUSTOMER_SECTOR", y="TOTAL_PAYMENTS", color="#00D4AA", horizontal=True)

    with col4:
        with st.container(border=True, height="stretch"):
            st.subheader("Volume by RM")
            by_rm = (
                filtered.dropna(subset=["RM_NAME"])
                .groupby("RM_NAME")["TOTAL_PAYMENTS"]
                .sum().reset_index().sort_values("TOTAL_PAYMENTS", ascending=False)
            )
            st.bar_chart(by_rm, x="RM_NAME", y="TOTAL_PAYMENTS", color="#00D4AA", horizontal=True)

    with st.container(border=True):
        st.subheader("Success rate by scheme & region")
        pivot = filtered.groupby(["PAYMENT_TYPE", "REGION"]).agg(
            successful=("SUCCESSFUL_PAYMENTS", "sum"),
            total=("TOTAL_PAYMENTS", "sum"),
        ).reset_index()
        pivot["SUCCESS_RATE"] = round(pivot["successful"] / pivot["total"].clip(lower=1) * 100, 2)
        st.dataframe(
            pivot[["PAYMENT_TYPE", "REGION", "SUCCESS_RATE", "total"]].rename(
                columns={"total": "TOTAL_PAYMENTS"}
            ),
            column_config={
                "SUCCESS_RATE": st.column_config.ProgressColumn(
                    "Success rate %", min_value=0, max_value=100, format="%.1f%%"
                ),
                "TOTAL_PAYMENTS": st.column_config.NumberColumn(format="%d"),
            },
            hide_index=True,
        )

# ===== TAB 2: SLA =====
with tab_sla:
    sla_filtered = sla[sla["PAYMENT_TYPE"].isin(selected_schemes)]

    status_counts = sla_filtered["SLA_STATUS"].value_counts()
    compliant = int(status_counts.get("COMPLIANT", 0))
    at_risk = int(status_counts.get("AT RISK", 0))
    breach = int(status_counts.get("BREACH", 0))
    total_sla = compliant + at_risk + breach

    with st.container(horizontal=True):
        st.metric("Compliant", f"{compliant:,}", border=True)
        st.metric(
            "At risk", f"{at_risk:,}",
            delta=f"{round(at_risk / max(total_sla, 1) * 100, 1)}%",
            delta_color="off", border=True,
        )
        st.metric(
            "Breach", f"{breach:,}",
            delta=f"{round(breach / max(total_sla, 1) * 100, 1)}%",
            delta_color="inverse", border=True,
        )

    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True, height="stretch"):
            st.subheader("SLA status by scheme")
            sla_by_scheme = (
                sla_filtered.groupby(["PAYMENT_TYPE", "SLA_STATUS"])
                .size().reset_index(name="COUNT")
            )
            st.bar_chart(sla_by_scheme, x="PAYMENT_TYPE", y="COUNT", color="SLA_STATUS", stack=True)

    with col2:
        with st.container(border=True, height="stretch"):
            st.subheader("Breach trend (last 30 days)")
            recent = sla_filtered[sla_filtered["SLA_STATUS"] == "BREACH"].copy()
            if len(recent) > 0:
                breach_daily = (
                    recent.groupby("PAYMENT_DAY").size()
                    .reset_index(name="BREACHES").sort_values("PAYMENT_DAY").tail(30)
                )
                st.line_chart(breach_daily, x="PAYMENT_DAY", y="BREACHES", color="#FF4B4B")
            else:
                st.info("No SLA breaches in the selected filters.", icon=":material/check_circle:")

    with st.container(border=True):
        st.subheader("SLA detail")
        st.dataframe(
            sla_filtered[
                ["PAYMENT_DAY", "PAYMENT_TYPE", "SLA_NAME", "SLA_STATUS",
                 "ACTUAL_SUCCESS_RATE", "SLA_TARGET_PCT", "ACTUAL_P95_MS", "SLA_THRESHOLD_MS"]
            ].sort_values(["PAYMENT_DAY", "PAYMENT_TYPE"], ascending=[False, True]),
            column_config={
                "ACTUAL_SUCCESS_RATE": st.column_config.ProgressColumn(
                    "Actual success %", min_value=0, max_value=100, format="%.2f%%"
                ),
                "SLA_TARGET_PCT": st.column_config.NumberColumn("SLA target %", format="%.2f%%"),
                "ACTUAL_P95_MS": st.column_config.NumberColumn("P95 (ms)", format="%d"),
                "SLA_THRESHOLD_MS": st.column_config.NumberColumn("SLA limit (ms)", format="%d"),
            },
            hide_index=True,
        )

# ===== TAB 3: Errors =====
with tab_errors:
    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True, height="stretch"):
            st.subheader("Errors by category")
            by_cat = (
                errors.groupby("ERROR_CATEGORY")["ERROR_COUNT"]
                .sum().reset_index().sort_values("ERROR_COUNT", ascending=False)
            )
            st.bar_chart(by_cat, x="ERROR_CATEGORY", y="ERROR_COUNT", color="#FF4B4B", horizontal=True)

    with col2:
        with st.container(border=True, height="stretch"):
            st.subheader("Retryable vs non-retryable")
            retry = errors.groupby("IS_RETRYABLE")["ERROR_COUNT"].sum().reset_index()
            retry["IS_RETRYABLE"] = retry["IS_RETRYABLE"].map({True: "Retryable", False: "Non-retryable"})
            st.bar_chart(retry, x="IS_RETRYABLE", y="ERROR_COUNT", color="#FF8C42")

    with st.container(border=True):
        st.subheader("Error breakdown")
        st.dataframe(
            errors,
            column_config={
                "ERROR_COUNT": st.column_config.BarChartColumn("Volume", y_min=0),
                "IS_RETRYABLE": st.column_config.CheckboxColumn("Retryable"),
            },
            hide_index=True,
        )
