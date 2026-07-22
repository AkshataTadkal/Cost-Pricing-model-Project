import json
import re
import os
from datetime import datetime, date
from decimal import Decimal
from typing import Dict, List, Tuple

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session


# ============================================================
# KMAT Truck Cost Model - Phase 7C Streamlit UI - Uniform KPI Layout
# Adds uniform KPI cards across Configure, History, Compare, Component Impact, RFQ/BMCS, and Cortex tabs,
# while preserving Phase 4B scenario history, comparison, batch demo,
# component impact, and exportable tables.
#
# Backend expected from Phases 1, 2, 5A, 5B, 5C, 6A-6D, and 7A:
# - Database: KMAT_COST_MODEL_DB
# - Procedures: CORE_INTERNAL.RUN_KMAT_COST_SIMULATION(SIMULATION_ID), CORE_INTERNAL.RUN_CORTEX_RFQ_INTAKE_PIPELINE(RFQ_ID), CORE_INTERNAL.RUN_CORTEX_RFQ_QUOTE_PIPELINE(RFQ_ID)
# - Input tables in CORE_INPUT, including Phase 5A risk tables, Phase 6 RFQ/BMCS tables, and Phase 7A RFQ_DOC_STAGE/Cortex fields
# - Output tables in CORE_OUTPUT, including Phase 5B risk columns and Phase 6C BMCS trust columns
# ============================================================

DB_NAME = "KMAT_COST_MODEL_DB"
KMAT_ID = "KMAT_TRUCK_01"

session = get_active_session()


# -----------------------------
# Utility helpers
# -----------------------------

def sql_literal(value: str) -> str:
    """Safely wrap a value as a Snowflake SQL string literal."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def sql_in(values: List[str]) -> str:
    """Build a safe SQL IN list from simple string IDs."""
    if not values:
        return "('')"
    return "(" + ", ".join(sql_literal(v) for v in values) + ")"


def normalize_id(value: str, label: str = "ID") -> str:
    cleaned = str(value or "").strip().upper()
    if not re.fullmatch(r"[A-Z0-9_-]{1,60}", cleaned):
        raise ValueError(f"{label} can contain only letters, numbers, underscore, and hyphen, max 60 characters.")
    return cleaned


def run_sql(sql: str):
    return session.sql(sql).collect()


def query_df(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def as_float(value) -> float:
    if value is None:
        return 0.0
    if isinstance(value, Decimal):
        return float(value)
    try:
        return float(value)
    except Exception:
        return 0.0


def money(value) -> str:
    return f"${as_float(value):,.2f}"


def pct(value) -> str:
    return f"{as_float(value):,.2f}%"


def utc_stamp() -> str:
    return datetime.utcnow().strftime("%Y%m%d_%H%M%S")


# -----------------------------
# Backend access functions
# -----------------------------

@st.cache_data(ttl=60)
def load_allowed_values_cached() -> Dict[str, List[str]]:
    df = query_df(f"""
        SELECT
            CHARACTERISTIC_NAME,
            ALLOWED_VALUE,
            DISPLAY_ORDER
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_MASTER
        WHERE KMAT_ID = {sql_literal(KMAT_ID)}
          AND ACTIVE_FLAG = TRUE
        ORDER BY DISPLAY_ORDER, ALLOWED_VALUE
    """)

    allowed = {}
    if not df.empty:
        for char_name, group_df in df.groupby("CHARACTERISTIC_NAME", sort=False):
            allowed[char_name] = group_df["ALLOWED_VALUE"].tolist()

    allowed.setdefault("ENGINE", ["V6", "V8"])
    allowed.setdefault("CAB", ["STANDARD", "PREMIUM"])
    allowed.setdefault("WHEEL", ["STANDARD", "OFFROAD"])
    allowed.setdefault("COLOR", ["RED", "BLUE"])
    return allowed


def clear_simulation_inputs(simulation_id: str):
    sim_lit = sql_literal(simulation_id)
    run_sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES WHERE SIMULATION_ID = {sim_lit}")
    run_sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS WHERE SIMULATION_ID = {sim_lit}")

    # Phase 5A production context is used by FMIS to choose the forecast month.
    try:
        run_sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT WHERE SIMULATION_ID = {sim_lit}")
    except Exception:
        pass

    run_sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_HEADER WHERE SIMULATION_ID = {sim_lit}")

    # This table exists only if the user completed the optional Phase 3 component-adjustment enhancement.
    # Ignore failure if it does not exist.
    try:
        run_sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.COMPONENT_COST_ADJUSTMENTS WHERE SIMULATION_ID = {sim_lit}")
    except Exception:
        pass


def reset_and_insert_simulation(
    simulation_id: str,
    customer_id: str,
    scenario_name: str,
    selections: Dict[str, str],
    material_multiplier: float,
    labor_multiplier: float,
    machine_multiplier: float,
    overhead_multiplier: float,
    target_markup_pct: float,
    floor_markup_pct: float,
    ceiling_markup_pct: float,
    planned_production_date,
    plant_id: str,
    production_line_id: str,
    batch_quantity: float,
):
    clear_simulation_inputs(simulation_id)

    sim_lit = sql_literal(simulation_id)

    run_sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.SIMULATION_HEADER
        (SIMULATION_ID, KMAT_ID, CUSTOMER_ID, SCENARIO_NAME)
        VALUES
        (
            {sim_lit},
            {sql_literal(KMAT_ID)},
            {sql_literal(customer_id)},
            {sql_literal(scenario_name)}
        )
    """)

    value_rows = []
    for characteristic_name, selected_value in selections.items():
        value_rows.append(
            f"({sim_lit}, {sql_literal(KMAT_ID)}, {sql_literal(characteristic_name)}, {sql_literal(selected_value)})"
        )

    run_sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        (SIMULATION_ID, KMAT_ID, CHARACTERISTIC_NAME, SELECTED_VALUE)
        VALUES
        {", ".join(value_rows)}
    """)

    run_sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS
        (
            SIMULATION_ID,
            MATERIAL_COST_MULTIPLIER,
            LABOR_RATE_MULTIPLIER,
            MACHINE_RATE_MULTIPLIER,
            OVERHEAD_MULTIPLIER,
            TARGET_MARGIN_PCT,
            FLOOR_MARKUP_PCT,
            CEILING_MARKUP_PCT
        )
        VALUES
        (
            {sim_lit},
            {material_multiplier},
            {labor_multiplier},
            {machine_multiplier},
            {overhead_multiplier},
            {target_markup_pct},
            {floor_markup_pct},
            {ceiling_markup_pct}
        )
    """)

    # Phase 5A production context. FMIS uses the planned production month.
    planned_date_str = str(planned_production_date)
    run_sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
        (
            SIMULATION_ID,
            KMAT_ID,
            PLANT_ID,
            PRODUCTION_LINE_ID,
            PLANNED_PRODUCTION_DATE,
            BATCH_QUANTITY
        )
        VALUES
        (
            {sim_lit},
            {sql_literal(KMAT_ID)},
            {sql_literal(plant_id)},
            {sql_literal(production_line_id)},
            TO_DATE({sql_literal(planned_date_str)}),
            {batch_quantity}
        )
    """)


def run_kmat_engine(simulation_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION({sql_literal(simulation_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def run_one_simulation(
    simulation_id: str,
    customer_id: str,
    scenario_name: str,
    selections: Dict[str, str],
    material_multiplier: float,
    labor_multiplier: float,
    machine_multiplier: float,
    overhead_multiplier: float,
    target_markup_pct: float,
    floor_markup_pct: float,
    ceiling_markup_pct: float,
    planned_production_date=None,
    plant_id: str = "PLANT_US_01",
    production_line_id: str = "TRUCK_LINE_01",
    batch_quantity: float = 10.0,
) -> Dict:
    reset_and_insert_simulation(
        simulation_id=simulation_id,
        customer_id=customer_id,
        scenario_name=scenario_name,
        selections=selections,
        material_multiplier=material_multiplier,
        labor_multiplier=labor_multiplier,
        machine_multiplier=machine_multiplier,
        overhead_multiplier=overhead_multiplier,
        target_markup_pct=target_markup_pct,
        floor_markup_pct=floor_markup_pct,
        ceiling_markup_pct=ceiling_markup_pct,
        planned_production_date=planned_production_date or date(2026, 9, 15),
        plant_id=plant_id,
        production_line_id=production_line_id,
        batch_quantity=batch_quantity,
    )
    return run_kmat_engine(simulation_id)


def load_summary(simulation_id: str) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            SIMULATION_ID,
            KMAT_ID,

            MATERIAL_COST_USD,
            LABOR_COST_USD,
            MACHINE_COST_USD,
            OVERHEAD_COST_USD,
            TOTAL_CONFIGURED_COST_USD,
            FLOOR_PRICE_USD,
            TARGET_PRICE_USD,
            CEILING_PRICE_USD,

            BASELINE_MATERIAL_COST_USD,
            BASELINE_LABOR_COST_USD,
            BASELINE_MACHINE_COST_USD,
            BASELINE_OVERHEAD_COST_USD,
            BASELINE_TOTAL_COST_USD,

            CSS_SCORE,
            SCRAP_RATE_APPLIED,
            SCRAP_RISK_LEVEL,
            AVG_WEIGHTED_FMIS,
            MAX_TDS_FACTOR,

            COMMODITY_ADJUSTMENT_USD,
            SCRAP_ADJUSTMENT_USD,
            TOOLING_ADJUSTMENT_USD,
            OVERHEAD_ADJUSTMENT_USD,

            RISK_ADJUSTED_MATERIAL_COST_USD,
            RISK_ADJUSTED_LABOR_COST_USD,
            RISK_ADJUSTED_MACHINE_COST_USD,
            RISK_ADJUSTED_OVERHEAD_COST_USD,
            RISK_ADJUSTED_TOTAL_COST_USD,

            TOTAL_RISK_UPLIFT_USD,
            TOTAL_RISK_UPLIFT_PCT,
            RISK_MODEL_VERSION,
            RISK_CALCULATION_STATUS,
            RISK_CALCULATION_NOTES,

            RFQ_ID,
            SOURCE_DOCUMENT_NAME,
            BMCS_CONFIGURATION_VERSION,
            BOM_MATCH_CONFIDENCE_SCORE,
            BMCS_REVIEW_STATUS,
            BMCS_REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            QUOTE_TRUST_STATUS,
            BMCS_ASSESSMENT_METHOD,
            BMCS_ASSESSMENT_VERSION,
            BMCS_ASSESSMENT_NOTES,

            CALCULATED_AT
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        WHERE SIMULATION_ID = {sql_literal(simulation_id)}
    """)


def load_results(simulation_id: str) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    sim_lit = sql_literal(simulation_id)

    summary_df = load_summary(simulation_id)

    components_df = query_df(f"""
        SELECT
            COMPONENT_ID,
            COMPONENT_DESCRIPTION,
            QUANTITY,
            UOM,
            RULE_ID,
            IS_BULK_MATERIAL,
            COST_COMPONENT_GROUP,
            STANDARD_COST_USD,
            LINE_MATERIAL_COST_USD,
            COST_MISSING_FLAG,

            SCRAP_APPLICABLE_FLAG,
            CSS_SCORE,
            SCRAP_RATE_APPLIED,
            SCRAP_ADJUSTED_QUANTITY,
            WEIGHTED_FMIS,
            FORWARD_UNIT_COST_USD,
            BASE_LINE_MATERIAL_COST_USD,
            COMMODITY_ADJUSTMENT_USD,
            SCRAP_ADJUSTMENT_USD,
            ADJUSTED_LINE_MATERIAL_COST_USD,
            FMIS_FALLBACK_FLAG,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
        WHERE SIMULATION_ID = {sim_lit}
        ORDER BY COST_COMPONENT_GROUP, COMPONENT_ID
    """)

    operations_df = query_df(f"""
        SELECT
            OPERATION_ID,
            OPERATION_DESCRIPTION,
            WORK_CENTER_ID,
            LABOR_HOURS,
            MACHINE_HOURS,
            LABOR_RATE_USD_PER_HOUR,
            MACHINE_RATE_USD_PER_HOUR,
            LABOR_COST_USD,
            MACHINE_COST_USD,
            RULE_ID,

            OPERATING_RATE_USD_PER_HOUR,
            MAINTENANCE_RATE_USD_PER_HOUR,
            TDS_FACTOR,
            BASE_MACHINE_COST_USD,
            ADJUSTED_MACHINE_RATE_USD_PER_HOUR,
            ADJUSTED_MACHINE_COST_USD,
            TOOLING_ADJUSTMENT_USD,
            TDS_FALLBACK_FLAG,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
        WHERE SIMULATION_ID = {sim_lit}
        ORDER BY OPERATION_ID
    """)

    overhead_df = query_df(f"""
        SELECT
            OVERHEAD_ID,
            OVERHEAD_DESCRIPTION,
            BASIS,
            RATE_VALUE,
            OVERHEAD_COST_USD,
            RULE_ID,

            BASE_OVERHEAD_COST_USD,
            OVERHEAD_CALCULATION_BASIS_COST_USD,
            ADJUSTED_OVERHEAD_COST_USD,
            OVERHEAD_ADJUSTMENT_USD,
            RISK_ADJUSTED_FLAG,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
        WHERE SIMULATION_ID = {sim_lit}
        ORDER BY OVERHEAD_ID
    """)

    return summary_df, components_df, operations_df, overhead_df


def load_history(limit: int = 100) -> pd.DataFrame:
    return query_df(f"""
        WITH cfg AS (
            SELECT
                SIMULATION_ID,
                KMAT_ID,
                LISTAGG(CHARACTERISTIC_NAME || '=' || SELECTED_VALUE, ', ')
                    WITHIN GROUP (ORDER BY CHARACTERISTIC_NAME) AS CONFIGURATION
            FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
            WHERE KMAT_ID = {sql_literal(KMAT_ID)}
            GROUP BY SIMULATION_ID, KMAT_ID
        )
        SELECT
            h.SIMULATION_ID,
            h.SCENARIO_NAME,
            h.CUSTOMER_ID,
            cfg.CONFIGURATION,

            p.MATERIAL_COST_MULTIPLIER,
            p.LABOR_RATE_MULTIPLIER,
            p.MACHINE_RATE_MULTIPLIER,
            p.OVERHEAD_MULTIPLIER,
            p.TARGET_MARGIN_PCT,

            ctx.PLANT_ID,
            ctx.PRODUCTION_LINE_ID,
            ctx.PLANNED_PRODUCTION_DATE,
            ctx.BATCH_QUANTITY,

            s.MATERIAL_COST_USD,
            s.LABOR_COST_USD,
            s.MACHINE_COST_USD,
            s.OVERHEAD_COST_USD,
            s.TOTAL_CONFIGURED_COST_USD,
            s.FLOOR_PRICE_USD,
            s.TARGET_PRICE_USD,
            s.CEILING_PRICE_USD,

            s.CSS_SCORE,
            s.SCRAP_RATE_APPLIED,
            s.SCRAP_RISK_LEVEL,
            s.AVG_WEIGHTED_FMIS,
            s.MAX_TDS_FACTOR,
            s.COMMODITY_ADJUSTMENT_USD,
            s.SCRAP_ADJUSTMENT_USD,
            s.TOOLING_ADJUSTMENT_USD,
            s.OVERHEAD_ADJUSTMENT_USD,
            s.RISK_ADJUSTED_TOTAL_COST_USD,
            s.TOTAL_RISK_UPLIFT_USD,
            s.TOTAL_RISK_UPLIFT_PCT,
            s.RISK_CALCULATION_STATUS,

            s.RFQ_ID,
            s.BOM_MATCH_CONFIDENCE_SCORE,
            s.BMCS_REVIEW_STATUS,
            s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
            s.QUOTE_TRUST_STATUS,

            s.CALCULATED_AT,
            h.CREATED_AT
        FROM {DB_NAME}.CORE_INPUT.SIMULATION_HEADER h
        LEFT JOIN cfg
            ON h.SIMULATION_ID = cfg.SIMULATION_ID
           AND h.KMAT_ID = cfg.KMAT_ID
        LEFT JOIN {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS p
            ON h.SIMULATION_ID = p.SIMULATION_ID
        LEFT JOIN {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT ctx
            ON h.SIMULATION_ID = ctx.SIMULATION_ID
           AND h.KMAT_ID = ctx.KMAT_ID
        LEFT JOIN {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY s
            ON h.SIMULATION_ID = s.SIMULATION_ID
           AND h.KMAT_ID = s.KMAT_ID
        WHERE h.KMAT_ID = {sql_literal(KMAT_ID)}
        ORDER BY COALESCE(s.CALCULATED_AT, h.CREATED_AT) DESC
        LIMIT {int(limit)}
    """)


def load_compare(simulation_ids: List[str]) -> pd.DataFrame:
    if not simulation_ids:
        return pd.DataFrame()

    df = query_df(f"""
        WITH cfg AS (
            SELECT
                SIMULATION_ID,
                KMAT_ID,
                LISTAGG(CHARACTERISTIC_NAME || '=' || SELECTED_VALUE, ', ')
                    WITHIN GROUP (ORDER BY CHARACTERISTIC_NAME) AS CONFIGURATION
            FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
            WHERE SIMULATION_ID IN {sql_in(simulation_ids)}
            GROUP BY SIMULATION_ID, KMAT_ID
        )
        SELECT
            s.SIMULATION_ID,
            h.SCENARIO_NAME,
            h.CUSTOMER_ID,
            cfg.CONFIGURATION,

            p.MATERIAL_COST_MULTIPLIER,
            p.LABOR_RATE_MULTIPLIER,
            p.MACHINE_RATE_MULTIPLIER,
            p.OVERHEAD_MULTIPLIER,
            p.TARGET_MARGIN_PCT,

            s.MATERIAL_COST_USD,
            s.LABOR_COST_USD,
            s.MACHINE_COST_USD,
            s.OVERHEAD_COST_USD,
            s.TOTAL_CONFIGURED_COST_USD,
            s.FLOOR_PRICE_USD,
            s.TARGET_PRICE_USD,
            s.CEILING_PRICE_USD,

            s.CSS_SCORE,
            s.SCRAP_RATE_APPLIED,
            s.SCRAP_RISK_LEVEL,
            s.AVG_WEIGHTED_FMIS,
            s.MAX_TDS_FACTOR,
            s.COMMODITY_ADJUSTMENT_USD,
            s.SCRAP_ADJUSTMENT_USD,
            s.TOOLING_ADJUSTMENT_USD,
            s.OVERHEAD_ADJUSTMENT_USD,
            s.RISK_ADJUSTED_TOTAL_COST_USD,
            s.TOTAL_RISK_UPLIFT_USD,
            s.TOTAL_RISK_UPLIFT_PCT,

            s.RFQ_ID,
            s.BOM_MATCH_CONFIDENCE_SCORE,
            s.BMCS_REVIEW_STATUS,
            s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
            s.QUOTE_TRUST_STATUS,

            s.CALCULATED_AT
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY s
        JOIN {DB_NAME}.CORE_INPUT.SIMULATION_HEADER h
            ON s.SIMULATION_ID = h.SIMULATION_ID
           AND s.KMAT_ID = h.KMAT_ID
        LEFT JOIN {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS p
            ON s.SIMULATION_ID = p.SIMULATION_ID
        LEFT JOIN cfg
            ON s.SIMULATION_ID = cfg.SIMULATION_ID
           AND s.KMAT_ID = cfg.KMAT_ID
        WHERE s.SIMULATION_ID IN {sql_in(simulation_ids)}
        ORDER BY s.SIMULATION_ID
    """)

    if not df.empty:
        # Profit is shown two ways:
        # baseline profit = target price - baseline total cost
        # risk-adjusted profit = target price - risk-adjusted cost
        df["TARGET_PROFIT_USD"] = df["TARGET_PRICE_USD"].apply(as_float) - df["TOTAL_CONFIGURED_COST_USD"].apply(as_float)
        df["RISK_ADJUSTED_TARGET_PROFIT_USD"] = df["TARGET_PRICE_USD"].apply(as_float) - df["RISK_ADJUSTED_TOTAL_COST_USD"].apply(as_float)
        df["RISK_ADJUSTED_GROSS_MARGIN_PCT"] = df.apply(
            lambda r: ((as_float(r["TARGET_PRICE_USD"]) - as_float(r["RISK_ADJUSTED_TOTAL_COST_USD"])) / as_float(r["TARGET_PRICE_USD"]) * 100.0)
            if as_float(r["TARGET_PRICE_USD"]) else 0.0,
            axis=1,
        )
        df["TARGET_GROSS_MARGIN_PCT"] = df.apply(
            lambda r: ((as_float(r["TARGET_PRICE_USD"]) - as_float(r["TOTAL_CONFIGURED_COST_USD"])) / as_float(r["TARGET_PRICE_USD"]) * 100.0)
            if as_float(r["TARGET_PRICE_USD"]) else 0.0,
            axis=1,
        )
        df["TARGET_MARKUP_ON_COST_PCT"] = df.apply(
            lambda r: ((as_float(r["TARGET_PRICE_USD"]) / as_float(r["TOTAL_CONFIGURED_COST_USD"])) - 1.0) * 100.0
            if as_float(r["TOTAL_CONFIGURED_COST_USD"]) else 0.0,
            axis=1,
        )
    return df


def add_baseline_deltas(compare_df: pd.DataFrame, baseline_id: str) -> pd.DataFrame:
    if compare_df.empty or baseline_id not in set(compare_df["SIMULATION_ID"]):
        return compare_df

    baseline_row = compare_df[compare_df["SIMULATION_ID"] == baseline_id].iloc[0]
    baseline_cost = as_float(baseline_row["TOTAL_CONFIGURED_COST_USD"])
    baseline_risk_cost = as_float(baseline_row.get("RISK_ADJUSTED_TOTAL_COST_USD", 0))
    baseline_price = as_float(baseline_row["TARGET_PRICE_USD"])
    baseline_profit = as_float(baseline_row["TARGET_PROFIT_USD"])
    baseline_risk_profit = as_float(baseline_row.get("RISK_ADJUSTED_TARGET_PROFIT_USD", 0))

    out = compare_df.copy()
    out["COST_DELTA_VS_BASELINE_USD"] = out["TOTAL_CONFIGURED_COST_USD"].apply(as_float) - baseline_cost
    out["COST_DELTA_VS_BASELINE_PCT"] = out["COST_DELTA_VS_BASELINE_USD"].apply(
        lambda x: (x / baseline_cost * 100.0) if baseline_cost else 0.0
    )
    out["RISK_COST_DELTA_VS_BASELINE_USD"] = out["RISK_ADJUSTED_TOTAL_COST_USD"].apply(as_float) - baseline_risk_cost
    out["RISK_COST_DELTA_VS_BASELINE_PCT"] = out["RISK_COST_DELTA_VS_BASELINE_USD"].apply(
        lambda x: (x / baseline_risk_cost * 100.0) if baseline_risk_cost else 0.0
    )
    out["TARGET_PRICE_DELTA_VS_BASELINE_USD"] = out["TARGET_PRICE_USD"].apply(as_float) - baseline_price
    out["PROFIT_DELTA_VS_BASELINE_USD"] = out["TARGET_PROFIT_USD"].apply(as_float) - baseline_profit
    out["RISK_PROFIT_DELTA_VS_BASELINE_USD"] = out["RISK_ADJUSTED_TARGET_PROFIT_USD"].apply(as_float) - baseline_risk_profit
    return out


def load_component_impact(baseline_id: str, scenario_id: str) -> pd.DataFrame:
    base_df = query_df(f"""
        SELECT
            COMPONENT_ID,
            COMPONENT_DESCRIPTION,
            COST_COMPONENT_GROUP,
            IS_BULK_MATERIAL,
            COST_MISSING_FLAG,
            LINE_MATERIAL_COST_USD AS BASELINE_LINE_MATERIAL_COST_USD,
            ADJUSTED_LINE_MATERIAL_COST_USD AS BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD,
            TRUE AS SELECTED_IN_BASELINE
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
        WHERE SIMULATION_ID = {sql_literal(baseline_id)}
    """)

    scen_df = query_df(f"""
        SELECT
            COMPONENT_ID,
            COMPONENT_DESCRIPTION,
            COST_COMPONENT_GROUP,
            IS_BULK_MATERIAL,
            COST_MISSING_FLAG,
            LINE_MATERIAL_COST_USD AS SCENARIO_LINE_MATERIAL_COST_USD,
            ADJUSTED_LINE_MATERIAL_COST_USD AS SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD,
            TRUE AS SELECTED_IN_SCENARIO
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
        WHERE SIMULATION_ID = {sql_literal(scenario_id)}
    """)

    if base_df.empty and scen_df.empty:
        return pd.DataFrame()

    merged = pd.merge(
        base_df,
        scen_df,
        on="COMPONENT_ID",
        how="outer",
        suffixes=("_BASE", "_SCENARIO"),
    )

    merged["COMPONENT_DESCRIPTION"] = merged["COMPONENT_DESCRIPTION_SCENARIO"].combine_first(merged["COMPONENT_DESCRIPTION_BASE"])
    merged["COST_COMPONENT_GROUP"] = merged["COST_COMPONENT_GROUP_SCENARIO"].combine_first(merged["COST_COMPONENT_GROUP_BASE"])
    merged["BASELINE_LINE_MATERIAL_COST_USD"] = merged["BASELINE_LINE_MATERIAL_COST_USD"].fillna(0).apply(as_float)
    merged["SCENARIO_LINE_MATERIAL_COST_USD"] = merged["SCENARIO_LINE_MATERIAL_COST_USD"].fillna(0).apply(as_float)
    merged["BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD"] = merged["BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD"].fillna(0).apply(as_float)
    merged["SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD"] = merged["SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD"].fillna(0).apply(as_float)
    merged["COMPONENT_COST_DELTA_USD"] = merged["SCENARIO_LINE_MATERIAL_COST_USD"] - merged["BASELINE_LINE_MATERIAL_COST_USD"]
    merged["RISK_ADJUSTED_COMPONENT_DELTA_USD"] = merged["SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD"] - merged["BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD"]
    merged["SELECTED_IN_BASELINE"] = merged["SELECTED_IN_BASELINE"].fillna(False).astype(bool)
    merged["SELECTED_IN_SCENARIO"] = merged["SELECTED_IN_SCENARIO"].fillna(False).astype(bool)

    display_cols = [
        "COMPONENT_ID",
        "COMPONENT_DESCRIPTION",
        "COST_COMPONENT_GROUP",
        "BASELINE_LINE_MATERIAL_COST_USD",
        "SCENARIO_LINE_MATERIAL_COST_USD",
        "COMPONENT_COST_DELTA_USD",
        "BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD",
        "SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD",
        "RISK_ADJUSTED_COMPONENT_DELTA_USD",
        "SELECTED_IN_BASELINE",
        "SELECTED_IN_SCENARIO",
    ]
    return merged[display_cols].sort_values("RISK_ADJUSTED_COMPONENT_DELTA_USD", ascending=False)


def load_rfq_bmcs_status(limit: int = 200) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            RFQ_ID,
            CUSTOMER_ID,
            CUSTOMER_NAME,
            SOURCE_DOCUMENT_NAME,
            SOURCE_DOCUMENT_TYPE,
            SOURCE_DOCUMENT_TEXT,
            ORIGINAL_DOCUMENT_TEXT,
            PROCESSING_TEXT_EN,
            RFQ_SUMMARY,
            RFQ_COMPLEXITY_CATEGORY,
            RFQ_COMPLEXITY_REASON,
            DOCUMENT_STATUS,

            SIMULATION_ID,
            CONFIGURATION_VERSION,
            EXTRACTED_CONFIGURATION_JSON,
            ENGINE,
            CAB,
            WHEEL,
            COLOR,
            EXTRACTION_METHOD,
            EXTRACTION_MODEL_NAME,
            CORTEX_EXTRACTION_REASONING,

            RULE_BASED_BMCS_SCORE,
            CORTEX_BMCS_SCORE,
            BOM_MATCH_CONFIDENCE_SCORE,
            CORTEX_BMCS_REVIEW_STATUS,
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            FINAL_BMCS_METHOD,
            CORTEX_BMCS_REASONING,
            BMCS_RISK_LEVEL,
            RULE_VALIDATION_STATUS,
            ASSESSMENT_METHOD,
            ASSESSMENT_VERSION,
            ASSESSMENT_NOTES
        FROM {DB_NAME}.CORE_INPUT.VW_RFQ_BMCS_STATUS
        WHERE KMAT_ID = {sql_literal(KMAT_ID)}
        ORDER BY RFQ_ID
        LIMIT {int(limit)}
    """)

def load_rfq_scoring_detail(rfq_id: str) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            RFQ_ID,
            SIMULATION_ID,
            CHARACTERISTIC_NAME,
            EXTRACTED_VALUE,
            VALID_VALUE_FLAG,
            MATCHED_SIGNAL_FLAG,
            MATCHED_SIGNAL_PHRASES,
            CHARACTERISTIC_SCORE_NOTES,
            CREATED_AT
        FROM {DB_NAME}.CORE_INPUT.BMCS_SCORING_DETAIL
        WHERE RFQ_ID = {sql_literal(rfq_id)}
        ORDER BY CHARACTERISTIC_NAME
    """)


def run_bmcs_scoring(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def run_cortex_bmcs_assessment(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_BMCS_ASSESSMENT({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def prepare_rfq_simulation_inputs(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def run_rfq_cost_flow(rfq_id: str) -> Dict:
    """
    Phase 7B unified RFQ quote flow.

    This calls the Snowflake wrapper that runs:
    1. Hybrid Cortex BMCS
    2. RFQ simulation preparation
    3. Deterministic KMAT cost engine
    4. Output summary patch with final hybrid BMCS trust status
    """
    return run_cortex_rfq_quote_pipeline(rfq_id)


def get_bmcs_note_kind(review_status: str, final_allowed) -> str:
    status = str(review_status or "").upper()
    if status == "AUTO_APPROVED":
        return "success"
    if status == "REVIEW_RECOMMENDED":
        return "warning"
    if status == "REVIEW_REQUIRED" or final_allowed is False:
        return "warning"
    return "soft"


def dataframe_to_csv_bytes(df: pd.DataFrame) -> bytes:
    return df.to_csv(index=False).encode("utf-8")
def safe_filename(value: str) -> str:
    cleaned = str(value or "uploaded_rfq.txt").strip()
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", cleaned)
    cleaned = cleaned.strip("._")
    return cleaned or "uploaded_rfq.txt"

def vertical_record_table(record: Dict, fields: List[str] = None) -> pd.DataFrame:
    """
    Converts one dataframe row/dict into a vertical Field-Value table.
    This is easier to read in Streamlit than a wide horizontal row.
    """
    if record is None:
        return pd.DataFrame(columns=["Field", "Value"])

    if fields is None:
        fields = list(record.keys())

    rows = []

    for field in fields:
        value = record.get(field, "")

        if isinstance(value, (dict, list)):
            value = json.dumps(value, indent=2)

        if pd.isna(value) if not isinstance(value, (dict, list)) else False:
            value = ""

        rows.append({
            "Field": field,
            "Value": str(value)
        })

    return pd.DataFrame(rows)

def upload_rfq_file_to_stage(rfq_id: str, uploaded_file) -> Dict:
    """
    Uploads the Streamlit RFQ file to Snowflake internal stage and verifies the exact path.
    The procedure later reads the same SOURCE_STAGE_RELATIVE_PATH through TO_FILE().
    """
    if uploaded_file is None:
        return {
            "uploaded": False,
            "stage_name": None,
            "relative_path": None,
            "source_document_name": None,
            "source_document_type": None,
        }

    safe_rfq_id = normalize_id(rfq_id, "RFQ ID")
    filename = safe_filename(uploaded_file.name)
    local_dir = f"/tmp/{safe_rfq_id}"
    os.makedirs(local_dir, exist_ok=True)
    local_path = f"{local_dir}/{filename}"

    with open(local_path, "wb") as f:
        f.write(uploaded_file.getbuffer())

    stage_folder = f"@{DB_NAME}.CORE_INPUT.RFQ_DOC_STAGE/{safe_rfq_id}"
    put_result = session.file.put(
        local_path,
        stage_folder,
        overwrite=True,
        auto_compress=False,
    )

    try:
        os.remove(local_path)
    except Exception:
        pass

    # Verify immediately. This avoids guessing the final staged path.
    list_rows = run_sql(f"LIST @{DB_NAME}.CORE_INPUT.RFQ_DOC_STAGE/{safe_rfq_id}")
    if not list_rows:
        raise RuntimeError(
            "The RFQ file upload completed but no file was visible in RFQ_DOC_STAGE. "
            f"PUT result: {put_result}"
        )

    staged_names = []
    for row in list_rows:
        try:
            staged_names.append(str(row["name"]))
        except Exception:
            staged_names.append(str(row[0]))

    matched_name = None
    for staged_name in staged_names:
        if staged_name.lower().endswith("/" + filename.lower()) or staged_name.lower().endswith(filename.lower()):
            matched_name = staged_name
            break

    if matched_name is None:
        raise RuntimeError(
            "The uploaded file was not found under the expected RFQ folder. "
            f"Expected file: {filename}. Files found: {staged_names}. PUT result: {put_result}"
        )

    upper_name = matched_name.upper()
    upper_marker = f"RFQ_DOC_STAGE/{safe_rfq_id}/".upper()
    if upper_marker in upper_name:
        start_pos = upper_name.index(upper_marker) + len("RFQ_DOC_STAGE/")
        relative_path = matched_name[start_pos:]
    else:
        folder_marker = f"{safe_rfq_id}/"
        upper_folder_marker = folder_marker.upper()
        if upper_folder_marker in upper_name:
            start_pos = upper_name.index(upper_folder_marker)
            relative_path = matched_name[start_pos:]
        else:
            relative_path = f"{safe_rfq_id}/{filename}"

    extension = filename.split(".")[-1].upper() if "." in filename else "UNKNOWN"

    return {
        "uploaded": True,
        "stage_name": "CORE_INPUT.RFQ_DOC_STAGE",
        "relative_path": relative_path,
        "source_document_name": filename,
        "source_document_type": extension,
    }


def upsert_rfq_header_for_cortex(
    rfq_id: str,
    customer_id: str,
    customer_name: str,
    source_document_name: str,
    source_document_type: str,
    source_document_text: str,
    source_language_code: str,
    source_stage_name: str = None,
    source_stage_relative_path: str = None,
):
    rfq_id = normalize_id(rfq_id, "RFQ ID")
    customer_id = normalize_id(customer_id, "Customer ID")

    run_sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.RFQ_HEADER t
        USING (
            SELECT
                {sql_literal(rfq_id)} AS RFQ_ID,
                {sql_literal(KMAT_ID)} AS KMAT_ID,
                {sql_literal(customer_id)} AS CUSTOMER_ID,
                {sql_literal(customer_name)} AS CUSTOMER_NAME,
                {sql_literal(source_document_name)} AS SOURCE_DOCUMENT_NAME,
                {sql_literal(source_document_type)} AS SOURCE_DOCUMENT_TYPE,
                {sql_literal(source_document_text)} AS SOURCE_DOCUMENT_TEXT,
                {sql_literal(source_stage_name)} AS SOURCE_STAGE_NAME,
                {sql_literal(source_stage_relative_path)} AS SOURCE_STAGE_RELATIVE_PATH,
                {sql_literal(source_document_text)} AS ORIGINAL_DOCUMENT_TEXT,
                {sql_literal(source_language_code)} AS SOURCE_LANGUAGE_CODE,
                'UPLOADED' AS DOCUMENT_STATUS,
                CURRENT_TIMESTAMP() AS RFQ_RECEIVED_AT
        ) s
        ON t.RFQ_ID = s.RFQ_ID
        WHEN MATCHED THEN UPDATE SET
            t.KMAT_ID = s.KMAT_ID,
            t.CUSTOMER_ID = s.CUSTOMER_ID,
            t.CUSTOMER_NAME = s.CUSTOMER_NAME,
            t.SOURCE_DOCUMENT_NAME = s.SOURCE_DOCUMENT_NAME,
            t.SOURCE_DOCUMENT_TYPE = s.SOURCE_DOCUMENT_TYPE,
            t.SOURCE_DOCUMENT_TEXT = s.SOURCE_DOCUMENT_TEXT,
            t.SOURCE_STAGE_NAME = s.SOURCE_STAGE_NAME,
            t.SOURCE_STAGE_RELATIVE_PATH = s.SOURCE_STAGE_RELATIVE_PATH,
            t.ORIGINAL_DOCUMENT_TEXT = s.ORIGINAL_DOCUMENT_TEXT,
            t.SOURCE_LANGUAGE_CODE = s.SOURCE_LANGUAGE_CODE,
            t.DOCUMENT_STATUS = s.DOCUMENT_STATUS,
            t.RFQ_RECEIVED_AT = s.RFQ_RECEIVED_AT,
            t.UPDATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            RFQ_ID,
            KMAT_ID,
            CUSTOMER_ID,
            CUSTOMER_NAME,
            SOURCE_DOCUMENT_NAME,
            SOURCE_DOCUMENT_TYPE,
            SOURCE_DOCUMENT_TEXT,
            SOURCE_STAGE_NAME,
            SOURCE_STAGE_RELATIVE_PATH,
            ORIGINAL_DOCUMENT_TEXT,
            SOURCE_LANGUAGE_CODE,
            DOCUMENT_STATUS,
            RFQ_RECEIVED_AT
        )
        VALUES (
            s.RFQ_ID,
            s.KMAT_ID,
            s.CUSTOMER_ID,
            s.CUSTOMER_NAME,
            s.SOURCE_DOCUMENT_NAME,
            s.SOURCE_DOCUMENT_TYPE,
            s.SOURCE_DOCUMENT_TEXT,
            s.SOURCE_STAGE_NAME,
            s.SOURCE_STAGE_RELATIVE_PATH,
            s.ORIGINAL_DOCUMENT_TEXT,
            s.SOURCE_LANGUAGE_CODE,
            s.DOCUMENT_STATUS,
            s.RFQ_RECEIVED_AT
        )
    """)


def run_cortex_rfq_intake(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_RFQ_INTAKE_PIPELINE({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def prepare_rfq_simulation_inputs(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}

def run_cortex_rfq_quote_pipeline(rfq_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_RFQ_QUOTE_PIPELINE({sql_literal(rfq_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}

def load_rfq_cortex_status(rfq_id: str = None) -> pd.DataFrame:
    where_clause = ""
    if rfq_id:
        where_clause = f"WHERE RFQ_ID = {sql_literal(rfq_id)}"

    return query_df(f"""
        SELECT
            RFQ_ID,
            CUSTOMER_ID,
            CUSTOMER_NAME,
            SOURCE_DOCUMENT_NAME,
            SOURCE_DOCUMENT_TYPE,
            SOURCE_STAGE_RELATIVE_PATH,
            DOCUMENT_STATUS,
            CORTEX_PROCESSING_STATUS,
            TEXT_EXTRACTION_METHOD,
            TRANSLATION_METHOD,
            RFQ_SUMMARY,
            RFQ_COMPLEXITY_CATEGORY,
            RFQ_COMPLEXITY_REASON,

            SIMULATION_ID,
            CONFIGURATION_VERSION,
            ENGINE,
            CAB,
            WHEEL,
            COLOR,
            EXTRACTION_METHOD,
            CORTEX_EXTRACTION_SCORES,
            CORTEX_EXTRACTION_REASONING,

            RULE_BASED_BMCS_SCORE,
            CORTEX_BMCS_SCORE,
            BOM_MATCH_CONFIDENCE_SCORE,
            CORTEX_BMCS_REVIEW_STATUS,
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            FINAL_BMCS_METHOD,
            CORTEX_BMCS_REASONING,
            BMCS_RISK_LEVEL,
            RULE_VALIDATION_STATUS
        FROM {DB_NAME}.CORE_INPUT.VW_RFQ_BMCS_STATUS
        {where_clause}
        ORDER BY RFQ_ID
    """)

def load_rfq_quote_summary(rfq_id: str) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            SIMULATION_ID,
            RFQ_ID,
            SOURCE_DOCUMENT_NAME,

            BOM_MATCH_CONFIDENCE_SCORE,
            BMCS_REVIEW_STATUS,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            QUOTE_TRUST_STATUS,
            BMCS_ASSESSMENT_METHOD,
            BMCS_ASSESSMENT_VERSION,

            BASELINE_TOTAL_COST_USD,
            RISK_ADJUSTED_TOTAL_COST_USD,
            TOTAL_RISK_UPLIFT_USD,
            TOTAL_RISK_UPLIFT_PCT,

            CSS_SCORE,
            SCRAP_RATE_APPLIED,
            SCRAP_RISK_LEVEL,
            AVG_WEIGHTED_FMIS,
            MAX_TDS_FACTOR,

            CALCULATED_AT
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        WHERE RFQ_ID = {sql_literal(rfq_id)}
        ORDER BY CALCULATED_AT DESC
        LIMIT 1
    """)

def load_bmcs_scoring_detail_for_rfq(rfq_id: str) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            RFQ_ID,
            SIMULATION_ID,
            CHARACTERISTIC_NAME,
            EXTRACTED_VALUE,
            VALID_VALUE_FLAG,
            MATCHED_SIGNAL_FLAG,
            MATCHED_SIGNAL_PHRASES,
            CHARACTERISTIC_SCORE_NOTES
        FROM {DB_NAME}.CORE_INPUT.BMCS_SCORING_DETAIL
        WHERE RFQ_ID = {sql_literal(rfq_id)}
        ORDER BY CHARACTERISTIC_NAME
    """)


def run_cortex_css_explanation_assist(simulation_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_CSS_EXPLANATION_ASSIST({sql_literal(simulation_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def load_cortex_css_explanation_assist(simulation_id: str) -> pd.DataFrame:
    try:
        return query_df(f"""
            SELECT
                SIMULATION_ID,
                KMAT_ID,
                CONFIGURATION,
                OFFICIAL_CSS_SCORE,
                OFFICIAL_SCRAP_RATE_APPLIED,
                OFFICIAL_SCRAP_RISK_LEVEL,
                CORTEX_SCRAP_RISK_BAND,
                CORTEX_REASONING,
                CORTEX_ENGINEERING_REVIEW_NOTE,
                ASSIST_METHOD,
                OFFICIAL_COST_OVERRIDE_FLAG,
                ASSESSMENT_STATUS,
                ASSESSMENT_NOTES,
                UPDATED_AT
            FROM {DB_NAME}.CORE_INPUT.VW_CORTEX_CSS_EXPLANATION_ASSIST
            WHERE SIMULATION_ID = {sql_literal(simulation_id)}
            ORDER BY UPDATED_AT DESC
            LIMIT 1
        """)
    except Exception:
        return pd.DataFrame()


def upsert_commodity_market_note(
    market_note_id: str,
    commodity_group: str,
    source_name: str,
    note_title: str,
    note_text: str,
    target_forecast_month,
):
    market_note_id = normalize_id(market_note_id, "Market Note ID")
    commodity_group = normalize_id(commodity_group, "Commodity Group")
    month_str = str(target_forecast_month)

    run_sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.COMMODITY_MARKET_NOTES t
        USING (
            SELECT
                {sql_literal(market_note_id)} AS MARKET_NOTE_ID,
                {sql_literal(commodity_group)} AS COMMODITY_GROUP,
                {sql_literal(source_name)} AS SOURCE_NAME,
                {sql_literal(note_title)} AS NOTE_TITLE,
                {sql_literal(note_text)} AS NOTE_TEXT,
                TO_DATE({sql_literal(month_str)}) AS TARGET_FORECAST_MONTH,
                'READY_FOR_CORTEX' AS NOTE_STATUS
        ) s
        ON t.MARKET_NOTE_ID = s.MARKET_NOTE_ID
        WHEN MATCHED THEN UPDATE SET
            t.COMMODITY_GROUP = s.COMMODITY_GROUP,
            t.SOURCE_NAME = s.SOURCE_NAME,
            t.NOTE_TITLE = s.NOTE_TITLE,
            t.NOTE_TEXT = s.NOTE_TEXT,
            t.TARGET_FORECAST_MONTH = s.TARGET_FORECAST_MONTH,
            t.NOTE_STATUS = s.NOTE_STATUS,
            t.ACTIVE_FLAG = TRUE,
            t.UPDATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            MARKET_NOTE_ID,
            COMMODITY_GROUP,
            SOURCE_NAME,
            NOTE_TITLE,
            NOTE_TEXT,
            TARGET_FORECAST_MONTH,
            NOTE_STATUS
        )
        VALUES (
            s.MARKET_NOTE_ID,
            s.COMMODITY_GROUP,
            s.SOURCE_NAME,
            s.NOTE_TITLE,
            s.NOTE_TEXT,
            s.TARGET_FORECAST_MONTH,
            s.NOTE_STATUS
        )
    """)


def run_cortex_fmis_signal_assist(market_note_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_FMIS_SIGNAL_ASSIST({sql_literal(market_note_id)})
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def load_cortex_fmis_signal_assist(market_note_id: str = None, limit: int = 20) -> pd.DataFrame:
    try:
        where_clause = ""
        if market_note_id:
            where_clause = f"WHERE MARKET_NOTE_ID = {sql_literal(market_note_id)}"

        return query_df(f"""
            SELECT
                MARKET_NOTE_ID,
                SOURCE_NAME,
                NOTE_TITLE,
                INPUT_COMMODITY_GROUP,
                TARGET_FORECAST_MONTH,
                CORTEX_EXTRACTED_COMMODITY,
                CORTEX_PRICE_DIRECTION,
                CORTEX_RISK_LEVEL,
                CORTEX_SIGNAL_TIME_HORIZON,
                CORTEX_KEY_DRIVERS,
                CORTEX_SUPPLIER_IMPACT,
                CORTEX_MARKET_SUMMARY,
                CORTEX_FMIS_EXPLANATION,
                CORTEX_REVIEW_NOTE,
                OFFICIAL_FMIS_OVERRIDE_FLAG,
                ASSIST_METHOD,
                ASSESSMENT_STATUS,
                ASSESSMENT_NOTES,
                UPDATED_AT
            FROM {DB_NAME}.CORE_INPUT.VW_CORTEX_FMIS_SIGNAL_ASSIST
            {where_clause}
            ORDER BY UPDATED_AT DESC NULLS LAST
            LIMIT {int(limit)}
        """)
    except Exception:
        return pd.DataFrame()



def upsert_tooling_maintenance_note(
    maintenance_note_id: str,
    simulation_id: str,
    work_center_id: str,
    source_name: str,
    note_title: str,
    note_text: str,
):
    maintenance_note_id = normalize_id(maintenance_note_id, "Maintenance Note ID")
    simulation_id = normalize_id(simulation_id, "Simulation ID")
    work_center_id = normalize_id(work_center_id, "Work Center ID")

    run_sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.TOOLING_MAINTENANCE_NOTES t
        USING (
            SELECT
                {sql_literal(maintenance_note_id)} AS MAINTENANCE_NOTE_ID,
                {sql_literal(simulation_id)} AS SIMULATION_ID,
                {sql_literal(work_center_id)} AS WORK_CENTER_ID,
                {sql_literal(source_name)} AS SOURCE_NAME,
                {sql_literal(note_title)} AS NOTE_TITLE,
                {sql_literal(note_text)} AS NOTE_TEXT,
                'READY_FOR_CORTEX' AS NOTE_STATUS
        ) s
        ON t.MAINTENANCE_NOTE_ID = s.MAINTENANCE_NOTE_ID
        WHEN MATCHED THEN UPDATE SET
            t.SIMULATION_ID = s.SIMULATION_ID,
            t.WORK_CENTER_ID = s.WORK_CENTER_ID,
            t.SOURCE_NAME = s.SOURCE_NAME,
            t.NOTE_TITLE = s.NOTE_TITLE,
            t.NOTE_TEXT = s.NOTE_TEXT,
            t.NOTE_STATUS = s.NOTE_STATUS,
            t.ACTIVE_FLAG = TRUE,
            t.UPDATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            MAINTENANCE_NOTE_ID,
            SIMULATION_ID,
            WORK_CENTER_ID,
            SOURCE_NAME,
            NOTE_TITLE,
            NOTE_TEXT,
            NOTE_STATUS
        )
        VALUES (
            s.MAINTENANCE_NOTE_ID,
            s.SIMULATION_ID,
            s.WORK_CENTER_ID,
            s.SOURCE_NAME,
            s.NOTE_TITLE,
            s.NOTE_TEXT,
            s.NOTE_STATUS
        )
    """)


def run_cortex_tds_explanation_assist(simulation_id: str, maintenance_note_id: str = None) -> Dict:
    note_sql = "NULL"
    if maintenance_note_id and str(maintenance_note_id).strip():
        note_sql = sql_literal(normalize_id(maintenance_note_id, "Maintenance Note ID"))

    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_TDS_EXPLANATION_ASSIST(
            {sql_literal(simulation_id)},
            {note_sql}
        )
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def load_cortex_tds_explanation_assist(
    simulation_id: str = None,
    maintenance_note_id: str = None,
    limit: int = 20,
) -> pd.DataFrame:
    try:
        filters = []
        if simulation_id:
            filters.append(f"SIMULATION_ID = {sql_literal(simulation_id)}")
        if maintenance_note_id:
            filters.append(f"MAINTENANCE_NOTE_ID = {sql_literal(maintenance_note_id)}")

        where_clause = ""
        if filters:
            where_clause = "WHERE " + " AND ".join(filters)

        return query_df(f"""
            SELECT
                SIMULATION_ID,
                KMAT_ID,
                MAINTENANCE_NOTE_ID,
                CONFIGURATION,
                OFFICIAL_MAX_TDS_FACTOR,
                OFFICIAL_TOOLING_ADJUSTMENT_USD,
                CORTEX_TOOLING_STRAIN_BAND,
                CORTEX_EXTRACTED_WORK_CENTER,
                CORTEX_EXTRACTED_STRAIN_SIGNAL,
                CORTEX_EXTRACTED_SEVERITY,
                CORTEX_EXTRACTED_RELATED_OPERATION,
                CORTEX_EXTRACTED_IMPACT,
                CORTEX_REASONING,
                CORTEX_ENGINEERING_REVIEW_NOTE,
                ASSIST_METHOD,
                OFFICIAL_COST_OVERRIDE_FLAG,
                ASSESSMENT_STATUS,
                ASSESSMENT_NOTES,
                UPDATED_AT
            FROM {DB_NAME}.CORE_INPUT.VW_CORTEX_TDS_EXPLANATION_ASSIST
            {where_clause}
            ORDER BY UPDATED_AT DESC NULLS LAST
            LIMIT {int(limit)}
        """)
    except Exception:
        return pd.DataFrame()



def run_cortex_cost_explanation(simulation_id: str) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_COST_EXPLANATION(
            {sql_literal(simulation_id)}
        )
    """)
    raw_result = rows[0][0] if rows else "{}"
    try:
        return json.loads(raw_result)
    except Exception:
        return {"status": "UNKNOWN", "raw_result": str(raw_result)}


def load_cortex_cost_explanation_summary(simulation_id: str = None, limit: int = 20) -> pd.DataFrame:
    try:
        where_clause = ""
        if simulation_id:
            where_clause = f"WHERE SIMULATION_ID = {sql_literal(simulation_id)}"

        return query_df(f"""
            SELECT
                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,
                CONFIGURATION,
                BASELINE_TOTAL_COST_USD,
                RISK_ADJUSTED_TOTAL_COST_USD,
                TOTAL_RISK_UPLIFT_USD,
                TOTAL_RISK_UPLIFT_PCT,
                CSS_SCORE,
                SCRAP_RISK_LEVEL,
                AVG_WEIGHTED_FMIS,
                MAX_TDS_FACTOR,
                BOM_MATCH_CONFIDENCE_SCORE,
                BMCS_REVIEW_STATUS,
                QUOTE_TRUST_STATUS,
                EXECUTIVE_SUMMARY,
                COST_DRIVER_EXPLANATION,
                RISK_UPLIFT_EXPLANATION,
                BMCS_TRUST_EXPLANATION,
                ENGINEERING_REVIEW_NOTE,
                ASSIST_METHOD,
                OFFICIAL_COST_OVERRIDE_FLAG,
                ASSESSMENT_STATUS,
                ASSESSMENT_NOTES,
                UPDATED_AT
            FROM {DB_NAME}.CORE_INPUT.VW_CORTEX_COST_EXPLANATION_SUMMARY
            {where_clause}
            ORDER BY UPDATED_AT DESC NULLS LAST
            LIMIT {int(limit)}
        """)
    except Exception:
        return pd.DataFrame()

# -----------------------------
# Scenario presets
# -----------------------------

PRESETS = {
    "Premium Baseline": {
        "suffix": "BASE",
        "scenario_name": "Premium Baseline - V8 Premium Offroad Red",
        "selections": {"ENGINE": "V8", "CAB": "PREMIUM", "WHEEL": "OFFROAD", "COLOR": "RED"},
        "material": 1.00,
        "labor": 1.00,
        "machine": 1.00,
        "overhead": 1.00,
        "target": 0.35,
        "floor": 0.10,
        "ceiling": 0.60,
    },
    "Material +10%": {
        "suffix": "MAT10",
        "scenario_name": "Material Cost Increase 10 Percent",
        "selections": {"ENGINE": "V8", "CAB": "PREMIUM", "WHEEL": "OFFROAD", "COLOR": "RED"},
        "material": 1.10,
        "labor": 1.00,
        "machine": 1.00,
        "overhead": 1.00,
        "target": 0.35,
        "floor": 0.10,
        "ceiling": 0.60,
    },
    "Labor +15% and Overhead +5%": {
        "suffix": "LAB15_OH5",
        "scenario_name": "Labor Increase 15 Percent and Overhead Increase 5 Percent",
        "selections": {"ENGINE": "V8", "CAB": "PREMIUM", "WHEEL": "OFFROAD", "COLOR": "RED"},
        "material": 1.00,
        "labor": 1.15,
        "machine": 1.00,
        "overhead": 1.05,
        "target": 0.35,
        "floor": 0.10,
        "ceiling": 0.60,
    },
    "Target Markup 40%": {
        "suffix": "MARGIN40",
        "scenario_name": "Target Markup Change from 35 Percent to 40 Percent",
        "selections": {"ENGINE": "V8", "CAB": "PREMIUM", "WHEEL": "OFFROAD", "COLOR": "RED"},
        "material": 1.00,
        "labor": 1.00,
        "machine": 1.00,
        "overhead": 1.00,
        "target": 0.40,
        "floor": 0.10,
        "ceiling": 0.60,
    },
    "Economy Truck": {
        "suffix": "ECONOMY",
        "scenario_name": "Economy Truck - V6 Standard Cab Standard Wheel Blue",
        "selections": {"ENGINE": "V6", "CAB": "STANDARD", "WHEEL": "STANDARD", "COLOR": "BLUE"},
        "material": 1.00,
        "labor": 1.00,
        "machine": 1.00,
        "overhead": 1.00,
        "target": 0.35,
        "floor": 0.10,
        "ceiling": 0.60,
    },
}


def initialize_widget_state():
    defaults = PRESETS["Premium Baseline"]
    st.session_state.setdefault("ui_simulation_id", f"SIM_UI_{utc_stamp()}")
    st.session_state.setdefault("ui_customer_id", "CUST_UI_001")
    st.session_state.setdefault("ui_scenario_name", defaults["scenario_name"])
    st.session_state.setdefault("ui_engine", defaults["selections"]["ENGINE"])
    st.session_state.setdefault("ui_cab", defaults["selections"]["CAB"])
    st.session_state.setdefault("ui_wheel", defaults["selections"]["WHEEL"])
    st.session_state.setdefault("ui_color", defaults["selections"]["COLOR"])
    st.session_state.setdefault("ui_material", defaults["material"])
    st.session_state.setdefault("ui_labor", defaults["labor"])
    st.session_state.setdefault("ui_machine", defaults["machine"])
    st.session_state.setdefault("ui_overhead", defaults["overhead"])
    st.session_state.setdefault("ui_target_pct", int(defaults["target"] * 100))
    st.session_state.setdefault("ui_floor_pct", int(defaults["floor"] * 100))
    st.session_state.setdefault("ui_ceiling_pct", int(defaults["ceiling"] * 100))
    st.session_state.setdefault("ui_planned_date", date(2026, 9, 15))
    st.session_state.setdefault("ui_plant_id", "PLANT_US_01")
    st.session_state.setdefault("ui_line_id", "TRUCK_LINE_01")
    st.session_state.setdefault("ui_batch_qty", 10.0)


def apply_preset_to_state(preset_name: str, new_id: bool = True):
    preset = PRESETS[preset_name]
    if new_id:
        st.session_state["ui_simulation_id"] = f"SIM_UI_{preset['suffix']}_{utc_stamp()}"
    st.session_state["ui_scenario_name"] = preset["scenario_name"]
    st.session_state["ui_engine"] = preset["selections"]["ENGINE"]
    st.session_state["ui_cab"] = preset["selections"]["CAB"]
    st.session_state["ui_wheel"] = preset["selections"]["WHEEL"]
    st.session_state["ui_color"] = preset["selections"]["COLOR"]
    st.session_state["ui_material"] = preset["material"]
    st.session_state["ui_labor"] = preset["labor"]
    st.session_state["ui_machine"] = preset["machine"]
    st.session_state["ui_overhead"] = preset["overhead"]
    st.session_state["ui_target_pct"] = int(preset["target"] * 100)
    st.session_state["ui_floor_pct"] = int(preset["floor"] * 100)
    st.session_state["ui_ceiling_pct"] = int(preset["ceiling"] * 100)



# -----------------------------
# UI design helpers
# -----------------------------

def inject_custom_css():
    st.markdown(
        """
        <style>
        :root {
            --bg-1: #07111f;
            --bg-2: #10233f;
            --glass: rgba(255, 255, 255, 0.09);
            --glass-strong: rgba(255, 255, 255, 0.14);
            --stroke: rgba(255, 255, 255, 0.20);
            --text-soft: rgba(246, 249, 255, 0.76);
            --text-faint: rgba(246, 249, 255, 0.58);
            --cyan: #63e6ff;
            --blue: #8ab4ff;
            --violet: #b197fc;
            --green: #7ef7c4;
            --amber: #ffd166;
            --rose: #ff8fab;
        }

        .stApp {
            background:
                radial-gradient(circle at 8% 12%, rgba(99, 230, 255, 0.28) 0, transparent 28%),
                radial-gradient(circle at 88% 8%, rgba(177, 151, 252, 0.22) 0, transparent 30%),
                radial-gradient(circle at 72% 86%, rgba(126, 247, 196, 0.14) 0, transparent 25%),
                linear-gradient(135deg, #06101f 0%, #0a1830 42%, #10112b 100%);
            color: #f8fbff;
        }

        .block-container {
            padding-top: 1.2rem;
            padding-bottom: 3rem;
            max-width: 1440px;
        }

        [data-testid="stSidebar"] {
            background: linear-gradient(180deg, rgba(255,255,255,0.11), rgba(255,255,255,0.045));
            border-right: 1px solid rgba(255,255,255,0.16);
            backdrop-filter: blur(18px);
        }

        [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p,
        [data-testid="stSidebar"] label,
        [data-testid="stSidebar"] span {
            color: rgba(248,251,255,0.90) !important;
        }

        .glass-hero {
            position: relative;
            padding: 30px 32px;
            border-radius: 28px;
            border: 1px solid rgba(255,255,255,0.20);
            background:
                linear-gradient(135deg, rgba(255,255,255,0.16), rgba(255,255,255,0.06)),
                radial-gradient(circle at 92% 12%, rgba(99,230,255,0.28), transparent 38%);
            box-shadow: 0 24px 80px rgba(0,0,0,0.36);
            backdrop-filter: blur(22px);
            overflow: hidden;
            margin-bottom: 1.25rem;
        }

        .glass-hero:after {
            content: "";
            position: absolute;
            width: 260px;
            height: 260px;
            border-radius: 999px;
            right: -90px;
            top: -110px;
            background: rgba(99,230,255,0.20);
            filter: blur(8px);
        }

        .hero-eyebrow {
            display: inline-flex;
            gap: 8px;
            align-items: center;
            color: #07111f;
            background: linear-gradient(90deg, var(--cyan), var(--green));
            padding: 7px 12px;
            border-radius: 999px;
            font-size: 0.80rem;
            font-weight: 800;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            margin-bottom: 12px;
        }

        .hero-title {
            font-size: clamp(2.0rem, 4vw, 4.0rem);
            line-height: 1.02;
            margin: 0;
            font-weight: 900;
            letter-spacing: -0.055em;
            color: #ffffff;
        }

        .hero-subtitle {
            max-width: 860px;
            margin-top: 14px;
            color: var(--text-soft);
            font-size: 1.02rem;
            line-height: 1.65;
        }

        .hero-pills {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 18px;
        }

        .pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            border-radius: 999px;
            color: rgba(255,255,255,0.92);
            background: rgba(255,255,255,0.10);
            border: 1px solid rgba(255,255,255,0.16);
            font-size: 0.85rem;
            font-weight: 650;
        }

        .glass-card {
            padding: 20px 20px;
            border-radius: 22px;
            border: 1px solid rgba(255,255,255,0.16);
            background: linear-gradient(180deg, rgba(255,255,255,0.12), rgba(255,255,255,0.055));
            box-shadow: 0 18px 48px rgba(0,0,0,0.23);
            backdrop-filter: blur(18px);
            margin-bottom: 1rem;
        }

        .mini-card {
            padding: 16px 16px;
            border-radius: 20px;
            border: 1px solid rgba(255,255,255,0.14);
            background: rgba(255,255,255,0.075);
            box-shadow: 0 12px 32px rgba(0,0,0,0.18);
            min-height: 116px;
        }

        .kpi-card {
            box-sizing: border-box;
            width: 100%;
            height: 148px;
            min-height: 148px;
            max-height: 148px;
            padding: 16px 16px 14px 16px;
            border-radius: 20px;
            border: 1px solid rgba(255,255,255,0.16);
            background:
                linear-gradient(145deg, rgba(255,255,255,0.13), rgba(255,255,255,0.055)),
                radial-gradient(circle at 94% 12%, var(--kpi-glow, rgba(99,230,255,0.18)), transparent 34%);
            box-shadow: 0 14px 38px rgba(0,0,0,0.24);
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            overflow: hidden;
            margin: 0 0 14px 0;
        }

        .kpi-label {
            color: var(--text-faint);
            font-size: 0.72rem;
            line-height: 1.1;
            font-weight: 850;
            letter-spacing: 0.075em;
            text-transform: uppercase;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            min-height: 16px;
        }

        .kpi-value {
            color: #ffffff;
            font-size: clamp(1.08rem, 1.55vw, 1.46rem);
            line-height: 1.08;
            font-weight: 900;
            letter-spacing: -0.028em;
            margin-top: 6px;
            overflow: hidden;
            word-break: break-word;
            overflow-wrap: anywhere;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            min-height: 34px;
        }

        .kpi-note {
            color: var(--text-soft);
            font-size: 0.78rem;
            line-height: 1.25;
            margin-top: 8px;
            overflow: hidden;
            overflow-wrap: anywhere;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            min-height: 36px;
        }

        [data-testid="column"] .kpi-card {
            align-self: stretch;
        }

        .section-title {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 1.45rem;
            font-weight: 900;
            letter-spacing: -0.025em;
            color: #ffffff;
            margin: 1.0rem 0 0.85rem 0;
        }

        .section-title .dot {
            height: 12px;
            width: 12px;
            border-radius: 99px;
            background: linear-gradient(135deg, var(--cyan), var(--violet));
            box-shadow: 0 0 22px rgba(99,230,255,0.9);
        }

        .soft-note {
            padding: 14px 16px;
            border-radius: 18px;
            background: rgba(99,230,255,0.10);
            border: 1px solid rgba(99,230,255,0.22);
            color: rgba(248,251,255,0.84);
        }

        .warning-note {
            padding: 14px 16px;
            border-radius: 18px;
            background: rgba(255,209,102,0.11);
            border: 1px solid rgba(255,209,102,0.24);
            color: rgba(255,248,228,0.92);
        }

        .success-note {
            padding: 14px 16px;
            border-radius: 18px;
            background: rgba(126,247,196,0.10);
            border: 1px solid rgba(126,247,196,0.24);
            color: rgba(235,255,248,0.92);
        }

        .tab-subtitle {
            color: var(--text-soft);
            margin-top: -0.35rem;
            margin-bottom: 1rem;
            line-height: 1.6;
        }

        .config-chip {
            box-sizing: border-box;
            height: 88px;
            min-height: 88px;
            padding: 14px 16px;
            border-radius: 18px;
            border: 1px solid rgba(255,255,255,0.15);
            background: rgba(255,255,255,0.07);
            overflow: hidden;
            margin-bottom: 12px;
        }
        .config-chip .label {
            color: var(--text-faint);
            font-size: 0.72rem;
            line-height: 1.1;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            font-weight: 850;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .config-chip .value {
            color: #ffffff;
            font-size: clamp(1.05rem, 1.35vw, 1.28rem);
            line-height: 1.12;
            font-weight: 900;
            margin-top: 7px;
            overflow: hidden;
            overflow-wrap: anywhere;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
        }

        div.stButton > button:first-child {
            border-radius: 14px;
            border: 1px solid rgba(255,255,255,0.18);
            background: linear-gradient(135deg, rgba(99,230,255,0.96), rgba(177,151,252,0.94));
            color: #07111f;
            font-weight: 850;
            box-shadow: 0 13px 34px rgba(99,230,255,0.20);
            transition: all 0.18s ease;
        }
        div.stButton > button:first-child:hover {
            transform: translateY(-1px);
            box-shadow: 0 16px 42px rgba(99,230,255,0.30);
            border: 1px solid rgba(255,255,255,0.34);
        }

        .stTabs [data-baseweb="tab-list"] {
            gap: 10px;
            background: rgba(255,255,255,0.065);
            border: 1px solid rgba(255,255,255,0.12);
            padding: 9px;
            border-radius: 18px;
            backdrop-filter: blur(14px);
        }
        .stTabs [data-baseweb="tab"] {
            height: 44px;
            border-radius: 14px;
            color: rgba(255,255,255,0.74);
            font-weight: 750;
        }
        .stTabs [aria-selected="true"] {
            color: #06101f !important;
            background: linear-gradient(135deg, var(--cyan), var(--green));
        }

        /* Uniform spacing for all KPI rows */
        div[data-testid="column"] {
            min-width: 0;
        }

        div[data-testid="column"] > div {
            min-width: 0;
        }

        [data-testid="stDataFrame"] {
            border-radius: 18px;
            overflow: hidden;
            border: 1px solid rgba(255,255,255,0.13);
            box-shadow: 0 12px 30px rgba(0,0,0,0.16);
        }

        [data-testid="stExpander"] {
            border: 1px solid rgba(255,255,255,0.14);
            border-radius: 18px;
            background: rgba(255,255,255,0.06);
        }

        hr {
            border-color: rgba(255,255,255,0.11) !important;
        }

        h1, h2, h3, h4 { color: #ffffff; }
        p, li { color: rgba(248,251,255,0.82); }

        .small-muted {
            color: var(--text-faint);
            font-size: 0.85rem;
        }


        .workflow-grid-note {
            color: rgba(248,251,255,0.74);
            font-size: 0.88rem;
            line-height: 1.55;
            margin-top: 6px;
        }

        .rfq-callout {
            padding: 18px 20px;
            border-radius: 22px;
            border: 1px solid rgba(99,230,255,0.22);
            background:
                linear-gradient(135deg, rgba(99,230,255,0.12), rgba(177,151,252,0.08)),
                rgba(255,255,255,0.055);
            box-shadow: 0 16px 44px rgba(0,0,0,0.20);
            margin: 0.4rem 0 1rem 0;
        }

        .rfq-callout-title {
            color: #ffffff;
            font-size: 1.15rem;
            font-weight: 900;
            margin-bottom: 6px;
            letter-spacing: -0.02em;
        }

        .rfq-callout-text {
            color: rgba(248,251,255,0.78);
            font-size: 0.93rem;
            line-height: 1.55;
        }

        [data-testid="stFileUploader"] {
            padding: 12px;
            border-radius: 18px;
            border: 1px dashed rgba(99,230,255,0.36);
            background: rgba(99,230,255,0.055);
        }

        [data-testid="stFileUploader"] section {
            border-radius: 16px !important;
            border-color: rgba(255,255,255,0.18) !important;
            background: rgba(255,255,255,0.055) !important;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def soft_rerun():
    if hasattr(st, "rerun"):
        st.rerun()
    elif hasattr(st, "experimental_rerun"):
        st.experimental_rerun()


def safe_html(value) -> str:
    text = str(value if value is not None else "")
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def section(title: str, icon: str = ""):
    icon_html = f"<span>{safe_html(icon)}</span>" if icon else ""
    st.markdown(
        f"""
        <div class="section-title"><span class="dot"></span>{icon_html}<span>{safe_html(title)}</span></div>
        """,
        unsafe_allow_html=True,
    )


def note(text: str, kind: str = "soft"):
    cls = {"soft": "soft-note", "warning": "warning-note", "success": "success-note"}.get(kind, "soft-note")
    st.markdown(f'<div class="{cls}">{safe_html(text)}</div>', unsafe_allow_html=True)


def kpi_card(label: str, value: str, note_text: str = "", glow: str = "rgba(99,230,255,0.18)"):
    """
    Uniform KPI card used everywhere in the app.

    The CSS clamps long values/notes so Configure & Run, Scenario History,
    Compare Scenarios, Component Impact, RFQ/BMCS, and Cortex RFQ Intake
    all keep the same card height and spacing.
    """
    label_html = safe_html(label)
    value_html = safe_html(value)
    note_html = safe_html(note_text)
    st.markdown(
        f"""
        <div class="kpi-card" style="--kpi-glow: {glow};">
            <div class="kpi-label" title="{label_html}">{label_html}</div>
            <div class="kpi-value" title="{value_html}">{value_html}</div>
            <div class="kpi-note" title="{note_html}">{note_html}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def config_chip(label: str, value: str):
    st.markdown(
        f"""
        <div class="config-chip">
            <div class="label">{safe_html(label)}</div>
            <div class="value">{safe_html(value)}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_hero():
    st.markdown(
        """
        <div class="glass-hero">
            <div class="hero-eyebrow">🚚 KMAT Cost Intelligence</div>
            <h1 class="hero-title">KMAT Configuration Cost Command Center</h1>
            <div class="hero-subtitle">
                A polished Snowflake + Streamlit workspace for Cortex RFQ intake and configurable truck costing.
                Upload customer RFQs, extract KMAT characteristics, validate BMCS trust, run the Snowpark engine,
                compare scenarios, and explain baseline plus risk-adjusted cost with confidence.
            </div>
            <div class="hero-pills">
                <span class="pill">JSON Rule Evaluation</span>
                <span class="pill">Super BOM + Routing</span>
                <span class="pill">Material + Labor + Machine + Overhead</span>
                <span class="pill">Bulk Material Included</span>
                <span class="pill">COALESCE Missing Cost → 0</span>
                <span class="pill">CSS + FMIS + TDS Risk Layer</span>
                <span class="pill">Cortex RFQ Upload</span>
                <span class="pill">RFQ/BMCS Trust Gate</span>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def format_table_money(df: pd.DataFrame, cols: List[str]) -> pd.DataFrame:
    out = df.copy()
    for col in cols:
        if col in out.columns:
            out[col] = out[col].apply(lambda x: round(as_float(x), 2))
    return out

# ============================================================
# Streamlit UI - polished glass/classy version
# ============================================================

st.set_page_config(
    page_title="KMAT Truck Cost Command Center",
    page_icon="🚚",
    layout="wide",
    initial_sidebar_state="expanded",
)



st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap');

html, body, [data-testid="stAppViewContainer"] {
    background:
        radial-gradient(circle at 10% 10%, rgba(103,232,249,0.15) 0%, transparent 26%),
        radial-gradient(circle at 90% 8%, rgba(139,92,246,0.15) 0%, transparent 28%),
        radial-gradient(circle at 55% 92%, rgba(56,189,248,0.10) 0%, transparent 30%),
        linear-gradient(145deg, #06101E 0%, #0D1628 48%, #111B2D 100%) !important;
    color: #EEF6FF !important;
    font-family: 'Inter', sans-serif !important;
}

[data-testid="stHeader"] {
    background: transparent !important;
}

[data-testid="stSidebar"] {
    background: linear-gradient(180deg, rgba(12,22,38,0.96), rgba(8,16,30,0.98)) !important;
    border-right: 1px solid rgba(255,255,255,0.10) !important;
}

.block-container {
    padding-top: 1.4rem !important;
    padding-bottom: 2.6rem !important;
}

/* Hero banner */
.hero-banner {
    background: linear-gradient(135deg, rgba(255,255,255,0.12), rgba(255,255,255,0.05)) !important;
    border: 1px solid rgba(255,255,255,0.14) !important;
    border-radius: 24px !important;
    padding: 30px 36px !important;
    margin-bottom: 26px !important;
    position: relative !important;
    overflow: hidden !important;
    box-shadow: 0 20px 60px rgba(0,0,0,0.30), inset 0 1px 0 rgba(255,255,255,0.10) !important;
    backdrop-filter: blur(16px) !important;
}
.hero-banner::before {
    content: '';
    position: absolute;
    top: -70px;
    right: -70px;
    width: 220px;
    height: 220px;
    background: radial-gradient(circle, rgba(103,232,249,0.18) 0%, transparent 70%);
    border-radius: 50%;
}
.hero-title {
    font-size: 32px !important;
    font-weight: 800 !important;
    color: #FFFFFF !important;
    margin: 0 0 6px 0 !important;
    letter-spacing: -0.04em !important;
}
.hero-sub {
    font-size: 14px !important;
    color: rgba(238,246,255,0.72) !important;
    margin: 0 !important;
}
.hero-badge {
    display: inline-flex !important;
    align-items: center !important;
    gap: 8px !important;
    background: rgba(103,232,249,0.10) !important;
    border: 1px solid rgba(103,232,249,0.24) !important;
    color: #67E8F9 !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    padding: 6px 12px !important;
    border-radius: 999px !important;
    margin-bottom: 12px !important;
    text-transform: uppercase !important;
    letter-spacing: 0.08em !important;
}

/* Tabs */
.stTabs [data-baseweb="tab-list"] {
    background: rgba(255,255,255,0.07) !important;
    border-radius: 16px !important;
    padding: 6px !important;
    gap: 6px !important;
    border: 1px solid rgba(255,255,255,0.10) !important;
}
.stTabs [data-baseweb="tab"] {
    background: transparent !important;
    color: rgba(238,246,255,0.72) !important;
    border-radius: 999px !important;
    font-size: 13px !important;
    font-weight: 600 !important;
    padding: 10px 18px !important;
    border: none !important;
}
.stTabs [aria-selected="true"] {
    background: linear-gradient(135deg, #38BDF8 0%, #8B5CF6 100%) !important;
    color: #FFFFFF !important;
    box-shadow: 0 8px 24px rgba(56,189,248,0.25) !important;
}
.stTabs [data-baseweb="tab-highlight"],
.stTabs [data-baseweb="tab-border"] {
    display: none !important;
}

/* KPI cards */
[data-testid="metric-container"] {
    background: linear-gradient(145deg, rgba(255,255,255,0.12), rgba(255,255,255,0.05)) !important;
    border: 1px solid rgba(255,255,255,0.12) !important;
    border-radius: 18px !important;
    padding: 18px 20px !important;
    box-shadow: 0 16px 40px rgba(0,0,0,0.22), inset 0 1px 0 rgba(255,255,255,0.10) !important;
    backdrop-filter: blur(12px) !important;
}
[data-testid="metric-container"] label {
    color: rgba(238,246,255,0.66) !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    text-transform: uppercase !important;
    letter-spacing: 0.08em !important;
}
[data-testid="stMetricValue"] {
    color: #67E8F9 !important;
    font-size: 24px !important;
    font-weight: 800 !important;
    font-family: 'JetBrains Mono', monospace !important;
}
[data-testid="stMetricDelta"] {
    font-size: 12px !important;
}

/* Buttons */
.stButton > button {
    background: linear-gradient(135deg, #38BDF8 0%, #8B5CF6 100%) !important;
    color: #FFFFFF !important;
    border: none !important;
    border-radius: 12px !important;
    font-weight: 700 !important;
    font-size: 14px !important;
    padding: 10px 22px !important;
    box-shadow: 0 10px 28px rgba(56,189,248,0.25) !important;
}
.stButton > button:hover {
    transform: translateY(-1px) !important;
    box-shadow: 0 14px 32px rgba(56,189,248,0.32) !important;
}

/* Inputs */
.stSelectbox > div > div,
.stTextInput > div > div > input,
.stNumberInput > div > div > input,
.stTextArea textarea {
    background: rgba(255,255,255,0.06) !important;
    border: 1px solid rgba(255,255,255,0.12) !important;
    border-radius: 12px !important;
    color: #EAF4FF !important;
}
.stSlider [data-baseweb="slider"] div[role="slider"] {
    background: #67E8F9 !important;
    border-color: #67E8F9 !important;
}

/* Dataframes and charts */
.stDataFrame,
[data-testid="stDataFrame"] {
    border: 1px solid rgba(255,255,255,0.12) !important;
    border-radius: 14px !important;
    overflow: hidden !important;
}
[data-testid="stDataFrame"] th {
    background: rgba(255,255,255,0.05) !important;
    color: rgba(238,246,255,0.70) !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    text-transform: uppercase !important;
}
.stBarChart, .stLineChart {
    background: rgba(255,255,255,0.05) !important;
    border: 1px solid rgba(255,255,255,0.10) !important;
    border-radius: 14px !important;
    padding: 12px !important;
}

/* Alerts and expanders */
.stSuccess > div,
.stWarning > div,
.stError > div,
.stInfo > div,
.streamlit-expanderHeader,
.streamlit-expanderContent {
    border-radius: 14px !important;
    border: 1px solid rgba(255,255,255,0.10) !important;
    backdrop-filter: blur(10px) !important;
}
.streamlit-expanderContent {
    background: rgba(255,255,255,0.04) !important;
}

/* Misc */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.18); border-radius: 999px; }

#MainMenu { visibility: hidden; }
footer { visibility: hidden; }
</style>
""", unsafe_allow_html=True)

inject_custom_css()

# UI-only polish overrides: consistent KPI/card sizing and cleaner RFQ/Risk layout.
# No backend logic, SQL calls, procedure names, or calculations are changed here.
st.markdown("""
<style>
/* ============================================================
   Phase 7C UI polish override - layout only
   ============================================================ */

/* Global spacing hygiene */
.block-container {
    padding-top: 1.15rem !important;
    padding-left: 2.2rem !important;
    padding-right: 2.2rem !important;
}

[data-testid="stVerticalBlock"] {
    gap: 0.72rem !important;
}

[data-testid="column"] {
    padding-left: 0.28rem !important;
    padding-right: 0.28rem !important;
}

/* Consistent custom KPI cards */
.kpi-card {
    height: 150px !important;
    min-height: 150px !important;
    max-height: 150px !important;
    padding: 16px 16px !important;
    border-radius: 20px !important;
    display: flex !important;
    flex-direction: column !important;
    justify-content: flex-start !important;
    overflow: hidden !important;
    box-sizing: border-box !important;
}

.kpi-label {
    font-size: 0.70rem !important;
    line-height: 1.15 !important;
    letter-spacing: 0.075em !important;
    min-height: 16px !important;
    max-height: 18px !important;
    overflow: hidden !important;
    white-space: nowrap !important;
    text-overflow: ellipsis !important;
}

.kpi-value {
    font-size: clamp(1.08rem, 1.42vw, 1.48rem) !important;
    line-height: 1.08 !important;
    letter-spacing: -0.025em !important;
    margin-top: 7px !important;
    min-height: 42px !important;
    max-height: 48px !important;
    overflow: hidden !important;
    overflow-wrap: anywhere !important;
    word-break: break-word !important;
    display: -webkit-box !important;
    -webkit-line-clamp: 2 !important;
    -webkit-box-orient: vertical !important;
}

.kpi-note {
    font-size: 0.76rem !important;
    line-height: 1.24 !important;
    margin-top: 8px !important;
    min-height: 36px !important;
    max-height: 38px !important;
    overflow: hidden !important;
    overflow-wrap: anywhere !important;
    display: -webkit-box !important;
    -webkit-line-clamp: 2 !important;
    -webkit-box-orient: vertical !important;
}

/* Streamlit native metric cards, used in a few existing areas */
[data-testid="metric-container"] {
    height: 126px !important;
    min-height: 126px !important;
    max-height: 126px !important;
    padding: 16px 18px !important;
    overflow: hidden !important;
    box-sizing: border-box !important;
}

[data-testid="metric-container"] label {
    font-size: 0.68rem !important;
    line-height: 1.1 !important;
    max-width: 100% !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
}

[data-testid="stMetricValue"] {
    font-size: clamp(1.04rem, 1.35vw, 1.42rem) !important;
    line-height: 1.12 !important;
    overflow-wrap: anywhere !important;
    word-break: break-word !important;
}

[data-testid="stMetricDelta"] {
    font-size: 0.72rem !important;
    line-height: 1.15 !important;
}

/* Standardized config chips */
.config-chip {
    height: 88px !important;
    min-height: 88px !important;
    max-height: 88px !important;
    padding: 13px 15px !important;
    border-radius: 17px !important;
    overflow: hidden !important;
    box-sizing: border-box !important;
}

.config-chip .label {
    font-size: 0.68rem !important;
    line-height: 1.1 !important;
    white-space: nowrap !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
}

.config-chip .value {
    font-size: clamp(1.05rem, 1.22vw, 1.28rem) !important;
    line-height: 1.1 !important;
    margin-top: 7px !important;
    overflow: hidden !important;
    overflow-wrap: anywhere !important;
    display: -webkit-box !important;
    -webkit-line-clamp: 2 !important;
    -webkit-box-orient: vertical !important;
}

/* Cleaner notes and sections */
.section-title {
    font-size: 1.26rem !important;
    margin: 0.82rem 0 0.58rem 0 !important;
    gap: 8px !important;
}

.section-title .dot {
    width: 10px !important;
    height: 10px !important;
}

.tab-subtitle {
    font-size: 0.91rem !important;
    line-height: 1.48 !important;
    margin-bottom: 0.72rem !important;
}

.soft-note,
.warning-note,
.success-note {
    padding: 12px 14px !important;
    border-radius: 16px !important;
    font-size: 0.88rem !important;
    line-height: 1.42 !important;
    margin-bottom: 0.50rem !important;
}

/* Dataframes/tables: less visual bulk */
[data-testid="stDataFrame"] {
    border-radius: 14px !important;
    margin-top: 0.28rem !important;
    margin-bottom: 0.72rem !important;
}

[data-testid="stDataFrame"] div[role="gridcell"],
[data-testid="stDataFrame"] div[role="columnheader"] {
    font-size: 0.80rem !important;
}

/* Expander and tabs spacing */
[data-testid="stExpander"] {
    margin-top: 0.45rem !important;
    margin-bottom: 0.60rem !important;
}

.stTabs [data-baseweb="tab-list"] {
    gap: 6px !important;
    padding: 7px !important;
    margin-bottom: 0.75rem !important;
}

.stTabs [data-baseweb="tab"] {
    height: 40px !important;
    padding: 8px 14px !important;
    font-size: 0.84rem !important;
}

/* RFQ/Risk heavy text areas and JSON blocks should not dominate the page */
textarea {
    font-size: 0.86rem !important;
    line-height: 1.38 !important;
}

[data-testid="stJson"] {
    font-size: 0.80rem !important;
}

/* File uploaders and inputs are compact but readable */
[data-testid="stFileUploader"] {
    padding: 10px !important;
    border-radius: 16px !important;
}

.stTextInput input,
.stTextArea textarea,
.stSelectbox div[data-baseweb="select"] {
    font-size: 0.88rem !important;
}
</style>
""", unsafe_allow_html=True)

initialize_widget_state()
allowed_values = load_allowed_values_cached()
render_hero()

with st.expander("About this dashboard", expanded=False):
    st.write(
        """
       - Upload or paste an RFQ and use Cortex to extract KMAT configuration values such as ENGINE, CAB, WHEEL, and COLOR.
- Review BMCS confidence, risk-adjusted costing, and trusted-cost eligibility before running the final KMAT cost simulation.
- Compare deterministic baseline cost with CSS, FMIS, and TDS risk-adjusted cost for better quotation decisions.
        """
    )

# -----------------------------
# Sidebar configuration
# -----------------------------

with st.sidebar:
    st.markdown("### ⚙️ Configuration Studio")
    st.caption("Choose a preset or manually configure the KMAT truck.")

    selected_preset = st.selectbox("Scenario Preset", list(PRESETS.keys()))
    col_preset_1, col_preset_2 = st.columns(2)
    with col_preset_1:
        if st.button("Apply", use_container_width=True):
            apply_preset_to_state(selected_preset, new_id=True)
            soft_rerun()
    with col_preset_2:
        if st.button("New ID", use_container_width=True):
            st.session_state["ui_simulation_id"] = f"SIM_UI_{utc_stamp()}"
            soft_rerun()

    st.markdown("---")
    st.markdown("#### Run Identity")
    st.text_input("Simulation ID", key="ui_simulation_id")
    st.text_input("Customer ID", key="ui_customer_id")
    st.text_input("Scenario Name", key="ui_scenario_name")

    st.markdown("---")
    st.markdown("#### Truck Characteristics")
    st.selectbox("ENGINE", allowed_values["ENGINE"], key="ui_engine")
    st.selectbox("CAB", allowed_values["CAB"], key="ui_cab")
    st.selectbox("WHEEL", allowed_values["WHEEL"], key="ui_wheel")
    st.selectbox("COLOR", allowed_values["COLOR"], key="ui_color")

    st.markdown("---")
    st.markdown("#### Cost Multipliers")
    st.number_input("Material Cost Multiplier", min_value=0.00, max_value=5.00, step=0.05, key="ui_material")
    st.number_input("Labor Rate Multiplier", min_value=0.00, max_value=5.00, step=0.05, key="ui_labor")
    st.number_input("Machine Rate Multiplier", min_value=0.00, max_value=5.00, step=0.05, key="ui_machine")
    st.number_input("Overhead Multiplier", min_value=0.00, max_value=5.00, step=0.05, key="ui_overhead")

    st.markdown("---")
    st.markdown("#### Pricing Guardrails")
    st.slider("Target Markup on Cost (%)", min_value=0, max_value=100, step=1, key="ui_target_pct")
    st.slider("Floor Markup on Cost (%)", min_value=0, max_value=100, step=1, key="ui_floor_pct")
    st.slider("Ceiling Markup on Cost (%)", min_value=0, max_value=150, step=1, key="ui_ceiling_pct")

    st.markdown("---")
    st.markdown("#### Risk Context")
    st.date_input("Planned Production Date", key="ui_planned_date")
    st.text_input("Plant ID", key="ui_plant_id")
    st.text_input("Production Line ID", key="ui_line_id")
    st.number_input("Batch Quantity", min_value=1.0, max_value=100000.0, step=1.0, key="ui_batch_qty")

selected_characteristics = {
    "ENGINE": st.session_state["ui_engine"],
    "CAB": st.session_state["ui_cab"],
    "WHEEL": st.session_state["ui_wheel"],
    "COLOR": st.session_state["ui_color"],
}

main_tabs = st.tabs([
    "📄 Cortex RFQ Intake",
    "🧾 RFQ/BMCS Review",
    "✨ Configure & Run",
    "🛡️ Risk Layer",
    "📜 Scenario History",
    "📊 Compare Scenarios",
    "🔍 Component Impact",
    "🚀 Batch Demo Runner",
])
# -----------------------------
# Tab 3: Configure & Run
# -----------------------------

with main_tabs[2]:
    section("Build Configuration", "🧩")
    st.markdown('<div class="tab-subtitle">Select a truck variant and run the Snowpark cost engine. The results below are written back to Snowflake output tables.</div>', unsafe_allow_html=True)

    config_cols = st.columns(4)
    with config_cols[0]:
        config_chip("ENGINE", selected_characteristics["ENGINE"])
    with config_cols[1]:
        config_chip("CAB", selected_characteristics["CAB"])
    with config_cols[2]:
        config_chip("WHEEL", selected_characteristics["WHEEL"])
    with config_cols[3]:
        config_chip("COLOR", selected_characteristics["COLOR"])

    st.markdown(" ")
    param_cols = st.columns(4)
    with param_cols[0]:
        kpi_card("Material Multiplier", f"{st.session_state['ui_material']:.2f}x", "Applies to selected material lines", "rgba(99,230,255,0.22)")
    with param_cols[1]:
        kpi_card("Labor Multiplier", f"{st.session_state['ui_labor']:.2f}x", "Applies to selected routing labor", "rgba(126,247,196,0.20)")
    with param_cols[2]:
        kpi_card("Machine Multiplier", f"{st.session_state['ui_machine']:.2f}x", "Applies to machine-hour cost", "rgba(177,151,252,0.20)")
    with param_cols[3]:
        kpi_card("Overhead Multiplier", f"{st.session_state['ui_overhead']:.2f}x", "Applies after overhead rules", "rgba(255,209,102,0.20)")

    run_col_1, run_col_2 = st.columns([1, 2.4])
    with run_col_1:
        run_button = st.button("Run Simulation", type="primary", use_container_width=True)
    with run_col_2:
        note("This action writes the selected configuration to CORE_INPUT, calls RUN_KMAT_COST_SIMULATION, and refreshes the output cards/tables from CORE_OUTPUT.", "soft")

    if run_button:
        try:
            simulation_id = normalize_id(st.session_state["ui_simulation_id"], "Simulation ID")
            customer_id = normalize_id(st.session_state["ui_customer_id"], "Customer ID")

            with st.spinner("Running KMAT cost simulation in Snowflake..."):
                procedure_result = run_one_simulation(
                    simulation_id=simulation_id,
                    customer_id=customer_id,
                    scenario_name=st.session_state["ui_scenario_name"],
                    selections=selected_characteristics,
                    material_multiplier=float(st.session_state["ui_material"]),
                    labor_multiplier=float(st.session_state["ui_labor"]),
                    machine_multiplier=float(st.session_state["ui_machine"]),
                    overhead_multiplier=float(st.session_state["ui_overhead"]),
                    target_markup_pct=float(st.session_state["ui_target_pct"]) / 100.0,
                    floor_markup_pct=float(st.session_state["ui_floor_pct"]) / 100.0,
                    ceiling_markup_pct=float(st.session_state["ui_ceiling_pct"]) / 100.0,
                    planned_production_date=st.session_state["ui_planned_date"],
                    plant_id=normalize_id(st.session_state["ui_plant_id"], "Plant ID"),
                    production_line_id=normalize_id(st.session_state["ui_line_id"], "Production Line ID"),
                    batch_quantity=float(st.session_state["ui_batch_qty"]),
                )

            st.session_state["last_simulation_id"] = simulation_id
            st.session_state["last_procedure_result"] = procedure_result

            if procedure_result.get("status") == "SUCCESS":
                note(f"Simulation {simulation_id} completed successfully. Results are now available in CORE_OUTPUT.", "success")
            else:
                note("Stored procedure did not return SUCCESS. Open the Procedure JSON tab for details.", "warning")
                st.json(procedure_result)

        except Exception as exc:
            st.error(f"Simulation failed: {exc}")

    last_sim_id = st.session_state.get("last_simulation_id")
    if last_sim_id:
        summary_df, components_df, operations_df, overhead_df = load_results(last_sim_id)

        if summary_df.empty:
            note("No summary output found for the last simulation yet.", "warning")
        else:
            row = summary_df.iloc[0]
            section(f"Configured Cost Summary · {last_sim_id}", "💎")

            metric_cols = st.columns(5)
            with metric_cols[0]:
                kpi_card("Material", money(row["MATERIAL_COST_USD"]), "Selected BOM + bulk rows", "rgba(99,230,255,0.22)")
            with metric_cols[1]:
                kpi_card("Labor", money(row["LABOR_COST_USD"]), "Selected routing labor", "rgba(126,247,196,0.20)")
            with metric_cols[2]:
                kpi_card("Machine", money(row["MACHINE_COST_USD"]), "Machine hour cost", "rgba(177,151,252,0.20)")
            with metric_cols[3]:
                kpi_card("Overhead", money(row["OVERHEAD_COST_USD"]), "Factory + material handling", "rgba(255,209,102,0.20)")
            with metric_cols[4]:
                kpi_card("Total Cost", money(row["TOTAL_CONFIGURED_COST_USD"]), "Full configured build cost", "rgba(255,143,171,0.20)")

            price_cols = st.columns(3)
            with price_cols[0]:
                kpi_card("Floor Price", money(row["FLOOR_PRICE_USD"]), f"{st.session_state['ui_floor_pct']}% markup floor", "rgba(126,247,196,0.18)")
            with price_cols[1]:
                kpi_card("Target Price", money(row["TARGET_PRICE_USD"]), f"{st.session_state['ui_target_pct']}% target markup", "rgba(99,230,255,0.22)")
            with price_cols[2]:
                kpi_card("Ceiling Price", money(row["CEILING_PRICE_USD"]), f"{st.session_state['ui_ceiling_pct']}% ceiling markup", "rgba(177,151,252,0.22)")

            risk_cols = st.columns(4)
            with risk_cols[0]:
                kpi_card("Baseline Cost", money(row.get("BASELINE_TOTAL_COST_USD", row["TOTAL_CONFIGURED_COST_USD"])), "Layer 1 deterministic cost", "rgba(99,230,255,0.18)")
            with risk_cols[1]:
                kpi_card("Risk-Adjusted Cost", money(row.get("RISK_ADJUSTED_TOTAL_COST_USD", row["TOTAL_CONFIGURED_COST_USD"])), "Layer 2 CSS + FMIS + TDS", "rgba(255,143,171,0.20)")
            with risk_cols[2]:
                kpi_card("Risk Uplift", money(row.get("TOTAL_RISK_UPLIFT_USD", 0)), f"{as_float(row.get('TOTAL_RISK_UPLIFT_PCT', 0)):.2f}% above baseline", "rgba(255,209,102,0.22)")
            with risk_cols[3]:
                kpi_card("Risk Status", str(row.get("RISK_CALCULATION_STATUS", "N/A")), f"CSS {as_float(row.get('CSS_SCORE', 0)):.0f} · {row.get('SCRAP_RISK_LEVEL', 'N/A')}", "rgba(126,247,196,0.18)")

            bmcs_review_status = row.get("BMCS_REVIEW_STATUS", "NOT_APPLICABLE")
            quote_trust_status = row.get("QUOTE_TRUST_STATUS", "TRUSTED_MANUAL_CONFIGURATION")
            if pd.notna(row.get("RFQ_ID", None)) and str(row.get("RFQ_ID", "")).strip():
                bmcs_cols = st.columns(4)
                with bmcs_cols[0]:
                    kpi_card("RFQ ID", str(row.get("RFQ_ID", "N/A")), str(row.get("SOURCE_DOCUMENT_NAME", "")), "rgba(99,230,255,0.18)")
                with bmcs_cols[1]:
                    kpi_card("BMCS", f"{as_float(row.get('BOM_MATCH_CONFIDENCE_SCORE', 0)):.0f}%", str(bmcs_review_status), "rgba(126,247,196,0.18)")
                with bmcs_cols[2]:
                    kpi_card("Quote Trust", str(quote_trust_status), "BMCS-controlled status", "rgba(255,209,102,0.20)")
                with bmcs_cols[3]:
                    allowed = bool(row.get("FINAL_TRUSTED_COST_ALLOWED_FLAG", True))
                    kpi_card("Final Cost Allowed", "YES" if allowed else "NO", "Engineering gate", "rgba(255,143,171,0.20)")
                if not bool(row.get("FINAL_TRUSTED_COST_ALLOWED_FLAG", True)):
                    note("BMCS requires engineering review. The cost is calculated for visibility, but it should be treated as preliminary, not a final trusted quotation.", "warning")
                elif str(bmcs_review_status).upper() == "REVIEW_RECOMMENDED":
                    note("BMCS recommends engineering review. Costing can proceed, but the mapping should be checked before final quote release.", "warning")

            bridge_df = pd.DataFrame({
                "Bridge Step": ["Baseline", "Commodity", "Scrap", "Tooling", "Overhead Adj", "Risk Adjusted"],
                "Cost USD": [
                    as_float(row.get("BASELINE_TOTAL_COST_USD", row["TOTAL_CONFIGURED_COST_USD"])),
                    as_float(row.get("COMMODITY_ADJUSTMENT_USD", 0)),
                    as_float(row.get("SCRAP_ADJUSTMENT_USD", 0)),
                    as_float(row.get("TOOLING_ADJUSTMENT_USD", 0)),
                    as_float(row.get("OVERHEAD_ADJUSTMENT_USD", 0)),
                    as_float(row.get("RISK_ADJUSTED_TOTAL_COST_USD", row["TOTAL_CONFIGURED_COST_USD"])),
                ],
            })
            section("Baseline to Risk-Adjusted Cost Bridge", "🛡️")
            st.bar_chart(bridge_df, x="Bridge Step", y="Cost USD", use_container_width=True)

            cost_breakdown = pd.DataFrame(
                {
                    "Cost Type": ["Material", "Labor", "Machine", "Overhead"],
                    "Cost USD": [
                        as_float(row["MATERIAL_COST_USD"]),
                        as_float(row["LABOR_COST_USD"]),
                        as_float(row["MACHINE_COST_USD"]),
                        as_float(row["OVERHEAD_COST_USD"]),
                    ],
                }
            )
            section("Cost Breakdown", "📈")
            st.bar_chart(cost_breakdown, x="Cost Type", y="Cost USD", use_container_width=True)

            missing_count = int(components_df["COST_MISSING_FLAG"].sum()) if not components_df.empty else 0
            bulk_count = int(components_df["IS_BULK_MATERIAL"].sum()) if not components_df.empty else 0

            status_cols = st.columns(2)
            with status_cols[0]:
                note(f"Bulk material rows included in costing: {bulk_count}", "success")
            with status_cols[1]:
                note(f"Rows with missing material cost handled as 0: {missing_count}", "warning" if missing_count else "success")

            detail_tabs = st.tabs(["🧱 Components", "🏭 Operations", "🧾 Overhead", "{} Procedure JSON"])
            with detail_tabs[0]:
                st.dataframe(
                    format_table_money(components_df, ["STANDARD_COST_USD", "LINE_MATERIAL_COST_USD", "BASE_LINE_MATERIAL_COST_USD", "COMMODITY_ADJUSTMENT_USD", "SCRAP_ADJUSTMENT_USD", "ADJUSTED_LINE_MATERIAL_COST_USD", "FORWARD_UNIT_COST_USD"]),
                    use_container_width=True,
                    hide_index=True,
                )
                st.download_button(
                    "Download components CSV",
                    data=dataframe_to_csv_bytes(components_df),
                    file_name=f"{last_sim_id}_components.csv",
                    mime="text/csv",
                )
            with detail_tabs[1]:
                st.dataframe(
                    format_table_money(operations_df, ["LABOR_RATE_USD_PER_HOUR", "MACHINE_RATE_USD_PER_HOUR", "LABOR_COST_USD", "MACHINE_COST_USD", "BASE_MACHINE_COST_USD", "ADJUSTED_MACHINE_COST_USD", "TOOLING_ADJUSTMENT_USD", "ADJUSTED_MACHINE_RATE_USD_PER_HOUR"]),
                    use_container_width=True,
                    hide_index=True,
                )
            with detail_tabs[2]:
                st.dataframe(
                    format_table_money(overhead_df, ["RATE_VALUE", "OVERHEAD_COST_USD", "BASE_OVERHEAD_COST_USD", "OVERHEAD_CALCULATION_BASIS_COST_USD", "ADJUSTED_OVERHEAD_COST_USD", "OVERHEAD_ADJUSTMENT_USD"]),
                    use_container_width=True,
                    hide_index=True,
                )
            with detail_tabs[3]:
                st.json(st.session_state.get("last_procedure_result", {}))
    else:
        note("Choose a configuration in the sidebar and click Run Simulation.", "soft")

# -----------------------------
# Tab 4: Risk Layer
# -----------------------------

with main_tabs[3]:
    section("Risk-Adjusted Costing Layer", "🛡️")
    st.markdown(
        '<div class="tab-subtitle">This tab explains the Phase 5 upgrade: baseline deterministic cost plus CSS scrap risk, FMIS forward material index, and TDS tooling degradation.</div>',
        unsafe_allow_html=True,
    )

    history_df = load_history(200)
    available_ids = history_df["SIMULATION_ID"].dropna().tolist() if not history_df.empty else []

    if not available_ids:
        note("Run at least one simulation after Phase 5C to view risk-adjusted costing.", "soft")
    else:
        default_risk_id = st.session_state.get("last_simulation_id", available_ids[0])
        if default_risk_id not in available_ids:
            default_risk_id = available_ids[0]

        risk_sim_id = st.selectbox(
            "Select Simulation",
            available_ids,
            index=available_ids.index(default_risk_id),
            key="risk_layer_simulation_id",
        )

        summary_df, components_df, operations_df, overhead_df = load_results(risk_sim_id)

        if summary_df.empty:
            note("No cost summary found for this simulation. Run the procedure first.", "warning")
        else:
            row = summary_df.iloc[0]

            c1, c2, c3, c4 = st.columns(4)
            with c1:
                kpi_card("Baseline Cost", money(row.get("BASELINE_TOTAL_COST_USD", 0)), "Deterministic Layer 1", "rgba(99,230,255,0.20)")
            with c2:
                kpi_card("Risk-Adjusted Cost", money(row.get("RISK_ADJUSTED_TOTAL_COST_USD", 0)), "CSS + FMIS + TDS", "rgba(255,143,171,0.22)")
            with c3:
                kpi_card("Total Risk Uplift", money(row.get("TOTAL_RISK_UPLIFT_USD", 0)), f"{as_float(row.get('TOTAL_RISK_UPLIFT_PCT', 0)):.2f}% above baseline", "rgba(255,209,102,0.20)")
            with c4:
                kpi_card("Risk Model", str(row.get("RISK_MODEL_VERSION", "N/A")), str(row.get("RISK_CALCULATION_STATUS", "N/A")), "rgba(126,247,196,0.18)")

            section("Operational Risk Scores", "📌")
            s1, s2, s3 = st.columns(3)
            with s1:
                kpi_card("CSS", f"{as_float(row.get('CSS_SCORE', 0)):.0f}", f"Scrap rate {as_float(row.get('SCRAP_RATE_APPLIED', 0))*100:.2f}% · {row.get('SCRAP_RISK_LEVEL', 'N/A')}", "rgba(255,143,171,0.20)")
            with s2:
                kpi_card("Avg FMIS", f"{as_float(row.get('AVG_WEIGHTED_FMIS', 1)):.4f}x", "Weighted forward material index", "rgba(99,230,255,0.22)")
            with s3:
                kpi_card("Max TDS", f"{as_float(row.get('MAX_TDS_FACTOR', 1)):.2f}x", "Highest selected operation strain", "rgba(177,151,252,0.22)")

            bridge_df = pd.DataFrame({
                "Bridge Step": ["Baseline", "Commodity", "Scrap", "Tooling", "Overhead Adj", "Risk Adjusted"],
                "Cost USD": [
                    as_float(row.get("BASELINE_TOTAL_COST_USD", 0)),
                    as_float(row.get("COMMODITY_ADJUSTMENT_USD", 0)),
                    as_float(row.get("SCRAP_ADJUSTMENT_USD", 0)),
                    as_float(row.get("TOOLING_ADJUSTMENT_USD", 0)),
                    as_float(row.get("OVERHEAD_ADJUSTMENT_USD", 0)),
                    as_float(row.get("RISK_ADJUSTED_TOTAL_COST_USD", 0)),
                ],
            })
            section("Baseline → Risk-Adjusted Cost Bridge", "🌉")
            st.bar_chart(bridge_df, x="Bridge Step", y="Cost USD", use_container_width=True)

            adj_cols = st.columns(4)
            with adj_cols[0]:
                kpi_card("Commodity Uplift", money(row.get("COMMODITY_ADJUSTMENT_USD", 0)), "FMIS impact", "rgba(99,230,255,0.18)")
            with adj_cols[1]:
                kpi_card("Scrap Uplift", money(row.get("SCRAP_ADJUSTMENT_USD", 0)), "CSS material buffer", "rgba(255,143,171,0.18)")
            with adj_cols[2]:
                kpi_card("Tooling Uplift", money(row.get("TOOLING_ADJUSTMENT_USD", 0)), "TDS machine cost", "rgba(177,151,252,0.18)")
            with adj_cols[3]:
                kpi_card("Overhead Uplift", money(row.get("OVERHEAD_ADJUSTMENT_USD", 0)), "Recalculated overhead", "rgba(255,209,102,0.18)")

            risk_tabs = st.tabs(["🧱 Component Risk", "🏭 Operation TDS", "🧾 Overhead Risk", "🧠 CSS Assist", "🌐 FMIS Assist", "⚙️ TDS Assist", "📑 Cost Summary", "📝 Notes"])
            with risk_tabs[0]:
                cols = [
                    "COMPONENT_ID", "COMPONENT_DESCRIPTION", "IS_BULK_MATERIAL", "COST_MISSING_FLAG",
                    "SCRAP_APPLICABLE_FLAG", "WEIGHTED_FMIS", "BASE_LINE_MATERIAL_COST_USD",
                    "COMMODITY_ADJUSTMENT_USD", "SCRAP_ADJUSTMENT_USD", "ADJUSTED_LINE_MATERIAL_COST_USD"
                ]
                cols = [c for c in cols if c in components_df.columns]
                st.dataframe(format_table_money(components_df[cols], [
                    "BASE_LINE_MATERIAL_COST_USD", "COMMODITY_ADJUSTMENT_USD", "SCRAP_ADJUSTMENT_USD", "ADJUSTED_LINE_MATERIAL_COST_USD"
                ]), use_container_width=True, hide_index=True)
            with risk_tabs[1]:
                cols = [
                    "OPERATION_ID", "OPERATION_DESCRIPTION", "WORK_CENTER_ID", "MACHINE_HOURS",
                    "OPERATING_RATE_USD_PER_HOUR", "MAINTENANCE_RATE_USD_PER_HOUR", "TDS_FACTOR",
                    "BASE_MACHINE_COST_USD", "ADJUSTED_MACHINE_COST_USD", "TOOLING_ADJUSTMENT_USD"
                ]
                cols = [c for c in cols if c in operations_df.columns]
                st.dataframe(format_table_money(operations_df[cols], [
                    "OPERATING_RATE_USD_PER_HOUR", "MAINTENANCE_RATE_USD_PER_HOUR", "BASE_MACHINE_COST_USD",
                    "ADJUSTED_MACHINE_COST_USD", "TOOLING_ADJUSTMENT_USD"
                ]), use_container_width=True, hide_index=True)
            with risk_tabs[2]:
                cols = [
                    "OVERHEAD_ID", "BASIS", "RATE_VALUE", "BASE_OVERHEAD_COST_USD",
                    "ADJUSTED_OVERHEAD_COST_USD", "OVERHEAD_ADJUSTMENT_USD"
                ]
                cols = [c for c in cols if c in overhead_df.columns]
                st.dataframe(format_table_money(overhead_df[cols], [
                    "RATE_VALUE", "BASE_OVERHEAD_COST_USD", "ADJUSTED_OVERHEAD_COST_USD", "OVERHEAD_ADJUSTMENT_USD"
                ]), use_container_width=True, hide_index=True)
            with risk_tabs[3]:
                st.markdown("#### Cortex CSS Explanation Assist")
                note(
                    "Advisory only: Cortex explains the official deterministic CSS result. It does not override CSS, scrap rate, or risk-adjusted cost.",
                    "soft",
                )

                css_action_cols = st.columns([1, 2])
                with css_action_cols[0]:
                    run_css_assist_clicked = st.button(
                        "Generate CSS Explanation",
                        use_container_width=True,
                        key=f"btn_css_assist_{risk_sim_id}",
                    )
                with css_action_cols[1]:
                    st.caption("Runs CORE_INTERNAL.RUN_CORTEX_CSS_EXPLANATION_ASSIST for the selected simulation.")

                if run_css_assist_clicked:
                    try:
                        with st.spinner("Generating advisory CSS explanation with Cortex..."):
                            css_result = run_cortex_css_explanation_assist(risk_sim_id)

                        st.session_state["last_css_assist_result"] = css_result

                        if css_result.get("status") == "SUCCESS":
                            note("Cortex CSS explanation generated successfully.", "success")
                        else:
                            note("Cortex CSS explanation did not return SUCCESS.", "warning")

                        st.json(css_result)

                    except Exception as exc:
                        st.error(f"Cortex CSS explanation failed: {exc}")

                css_assist_df = load_cortex_css_explanation_assist(risk_sim_id)

                if css_assist_df.empty:
                    note("No Cortex CSS explanation found yet for this simulation. Click Generate CSS Explanation.", "soft")
                else:
                    css_row = css_assist_df.iloc[0]

                    css_cols = st.columns(4)
                    with css_cols[0]:
                        kpi_card(
                            "Official CSS",
                            f"{as_float(css_row.get('OFFICIAL_CSS_SCORE', 0)):.0f}",
                            str(css_row.get("OFFICIAL_SCRAP_RISK_LEVEL", "N/A")),
                            "rgba(255,143,171,0.20)",
                        )
                    with css_cols[1]:
                        kpi_card(
                            "Official Scrap Rate",
                            f"{as_float(css_row.get('OFFICIAL_SCRAP_RATE_APPLIED', 0))*100:.2f}%",
                            "Deterministic cost engine",
                            "rgba(255,209,102,0.20)",
                        )
                    with css_cols[2]:
                        kpi_card(
                            "Cortex Band",
                            str(css_row.get("CORTEX_SCRAP_RISK_BAND", "N/A")),
                            "Advisory classification",
                            "rgba(177,151,252,0.20)",
                        )
                    with css_cols[3]:
                        override_flag = bool(css_row.get("OFFICIAL_COST_OVERRIDE_FLAG", False))
                        kpi_card(
                            "Cost Override",
                            "YES" if override_flag else "NO",
                            str(css_row.get("ASSIST_METHOD", "N/A")),
                            "rgba(126,247,196,0.18)",
                        )

                    st.markdown("#### Cortex Reasoning")
                    st.write(css_row.get("CORTEX_REASONING", ""))

                    st.markdown("#### Engineering Review Note")
                    st.write(css_row.get("CORTEX_ENGINEERING_REVIEW_NOTE", ""))

                    st.dataframe(css_assist_df, use_container_width=True, hide_index=True)

            with risk_tabs[4]:
                st.markdown("#### Cortex FMIS Signal + Explanation Assist")
                note(
                    "Advisory only: Cortex reads supplier or market notes and explains commodity signals. It does not override official FMIS, material index forecasts, or material cost.",
                    "soft",
                )

                st.session_state.setdefault("fmis_market_note_id", f"NOTE_UI_{utc_stamp()}")

                fmis_top_cols = st.columns(4)
                with fmis_top_cols[0]:
                    kpi_card(
                        "Official Avg FMIS",
                        f"{as_float(row.get('AVG_WEIGHTED_FMIS', 1)):.4f}x",
                        "From current cost engine",
                        "rgba(99,230,255,0.22)",
                    )
                with fmis_top_cols[1]:
                    kpi_card(
                        "Commodity Uplift",
                        money(row.get("COMMODITY_ADJUSTMENT_USD", 0)),
                        "Official material impact",
                        "rgba(255,209,102,0.20)",
                    )
                with fmis_top_cols[2]:
                    kpi_card(
                        "Official Source",
                        "FMIS Table",
                        "MATERIAL_INDEX_FORECASTS",
                        "rgba(126,247,196,0.18)",
                    )
                with fmis_top_cols[3]:
                    kpi_card(
                        "Override",
                        "NO",
                        "Assist layer only",
                        "rgba(177,151,252,0.20)",
                    )

                fmis_form_cols = st.columns([1, 1])
                with fmis_form_cols[0]:
                    market_note_id = st.text_input(
                        "Market Note ID",
                        key="fmis_market_note_id",
                    )
                    commodity_group = st.selectbox(
                        "Commodity Group",
                        ["STEEL", "ALUMINUM", "RUBBER", "CHEMICALS", "OTHER"],
                        key="fmis_commodity_group",
                    )
                    target_forecast_month = st.date_input(
                        "Target Forecast Month",
                        value=date(2026, 9, 1),
                        key="fmis_target_forecast_month",
                    )
                with fmis_form_cols[1]:
                    source_name = st.text_input(
                        "Source Name",
                        value="Supplier Market Update",
                        key="fmis_source_name",
                    )
                    note_title = st.text_input(
                        "Note Title",
                        value="Commodity market signal for planned production",
                        key="fmis_note_title",
                    )

                note_text = st.text_area(
                    "Supplier / Market Note",
                    height=150,
                    placeholder="Example: Steel suppliers are warning of upward price pressure next quarter due to higher energy costs and port delays.",
                    key="fmis_note_text",
                )

                fmis_action_cols = st.columns([1, 2])
                with fmis_action_cols[0]:
                    run_fmis_clicked = st.button(
                        "Save + Run FMIS Assist",
                        use_container_width=True,
                        key=f"btn_fmis_assist_{risk_sim_id}",
                    )
                with fmis_action_cols[1]:
                    st.caption("Runs CORE_INTERNAL.RUN_CORTEX_FMIS_SIGNAL_ASSIST for the market note. Official FMIS remains unchanged.")

                if run_fmis_clicked:
                    try:
                        normalized_note_id = normalize_id(market_note_id, "Market Note ID")
                        if not note_text.strip():
                            raise ValueError("Please enter supplier or market note text before running FMIS Assist.")

                        with st.spinner("Saving market note and running Cortex FMIS Signal Assist..."):
                            upsert_commodity_market_note(
                                market_note_id=normalized_note_id,
                                commodity_group=commodity_group,
                                source_name=source_name,
                                note_title=note_title,
                                note_text=note_text.strip(),
                                target_forecast_month=target_forecast_month,
                            )
                            fmis_result = run_cortex_fmis_signal_assist(normalized_note_id)

                        st.session_state["last_fmis_market_note_id"] = normalized_note_id
                        st.session_state["last_fmis_assist_result"] = fmis_result

                        if fmis_result.get("status") == "SUCCESS":
                            note("Cortex FMIS signal assist completed successfully.", "success")
                        else:
                            note("Cortex FMIS signal assist did not return SUCCESS.", "warning")

                        st.json(fmis_result)

                    except Exception as exc:
                        st.error(f"Cortex FMIS signal assist failed: {exc}")

                selected_market_note_id = st.session_state.get("last_fmis_market_note_id", market_note_id)
                fmis_assist_df = load_cortex_fmis_signal_assist(selected_market_note_id, limit=1)

                if fmis_assist_df.empty:
                    note("No Cortex FMIS signal result found yet. Save and run FMIS Assist to generate one.", "soft")
                else:
                    fmis_row = fmis_assist_df.iloc[0]

                    signal_cols = st.columns(4)
                    with signal_cols[0]:
                        kpi_card(
                            "Extracted Commodity",
                            str(fmis_row.get("CORTEX_EXTRACTED_COMMODITY", "N/A")),
                            f"Input: {fmis_row.get('INPUT_COMMODITY_GROUP', 'N/A')}",
                            "rgba(99,230,255,0.22)",
                        )
                    with signal_cols[1]:
                        kpi_card(
                            "Price Direction",
                            str(fmis_row.get("CORTEX_PRICE_DIRECTION", "N/A")),
                            str(fmis_row.get("CORTEX_SIGNAL_TIME_HORIZON", "")),
                            "rgba(255,209,102,0.20)",
                        )
                    with signal_cols[2]:
                        kpi_card(
                            "Risk Level",
                            str(fmis_row.get("CORTEX_RISK_LEVEL", "N/A")),
                            str(fmis_row.get("CORTEX_KEY_DRIVERS", "")),
                            "rgba(255,143,171,0.20)",
                        )
                    with signal_cols[3]:
                        override_flag = bool(fmis_row.get("OFFICIAL_FMIS_OVERRIDE_FLAG", False))
                        kpi_card(
                            "FMIS Override",
                            "YES" if override_flag else "NO",
                            str(fmis_row.get("ASSIST_METHOD", "N/A")),
                            "rgba(126,247,196,0.18)",
                        )

                    st.markdown("#### Market Summary")
                    st.write(fmis_row.get("CORTEX_MARKET_SUMMARY", ""))

                    st.markdown("#### FMIS Explanation")
                    st.write(fmis_row.get("CORTEX_FMIS_EXPLANATION", ""))

                    st.markdown("#### Review Note")
                    st.write(fmis_row.get("CORTEX_REVIEW_NOTE", ""))

                    st.dataframe(fmis_assist_df, use_container_width=True, hide_index=True)

                recent_fmis_df = load_cortex_fmis_signal_assist(limit=10)
                if not recent_fmis_df.empty:
                    st.markdown("#### Recent FMIS Signal Assist Results")
                    st.dataframe(recent_fmis_df, use_container_width=True, hide_index=True)

            with risk_tabs[5]:
                st.markdown("#### Cortex TDS Explanation Assist")
                note(
                    "Advisory only: Cortex explains tooling strain and maintenance signals. It does not override official TDS, operation TDS rules, or machine cost.",
                    "soft",
                )

                tds_top_cols = st.columns(4)
                with tds_top_cols[0]:
                    kpi_card(
                        "Official Max TDS",
                        f"{as_float(row.get('MAX_TDS_FACTOR', 1)):.2f}x",
                        "From current cost engine",
                        "rgba(177,151,252,0.22)",
                    )
                with tds_top_cols[1]:
                    kpi_card(
                        "Tooling Uplift",
                        money(row.get("TOOLING_ADJUSTMENT_USD", 0)),
                        "Official machine impact",
                        "rgba(255,209,102,0.20)",
                    )
                with tds_top_cols[2]:
                    kpi_card(
                        "Official Source",
                        "TDS Rules",
                        "OPERATION_TDS_RULES",
                        "rgba(126,247,196,0.18)",
                    )
                with tds_top_cols[3]:
                    kpi_card(
                        "Override",
                        "NO",
                        "Assist layer only",
                        "rgba(99,230,255,0.22)",
                    )

                st.session_state.setdefault("tds_maintenance_note_id", f"NOTE_TDS_UI_{utc_stamp()}")

                work_center_options = []
                if not operations_df.empty and "WORK_CENTER_ID" in operations_df.columns:
                    work_center_options = sorted([str(x) for x in operations_df["WORK_CENTER_ID"].dropna().unique().tolist()])
                if not work_center_options:
                    work_center_options = ["WC_ASSEMBLY", "WC_PAINT", "WC_QA"]

                tds_form_cols = st.columns([1, 1])
                with tds_form_cols[0]:
                    maintenance_note_id = st.text_input(
                        "Maintenance Note ID",
                        key="tds_maintenance_note_id",
                    )
                    work_center_id = st.selectbox(
                        "Work Center",
                        work_center_options,
                        key="tds_work_center_id",
                    )
                with tds_form_cols[1]:
                    tds_source_name = st.text_input(
                        "Source Name",
                        value="Maintenance Log",
                        key="tds_source_name",
                    )
                    tds_note_title = st.text_input(
                        "Note Title",
                        value="Tooling strain observation for selected simulation",
                        key="tds_note_title",
                    )

                tds_note_text = st.text_area(
                    "Maintenance / Tooling Note",
                    height=150,
                    placeholder="Example: Assembly fixture showed abnormal vibration during V8 offroad builds. Maintenance observed faster fixture wear after premium cab and offroad wheel batches.",
                    key="tds_note_text",
                )

                tds_action_cols = st.columns([1, 1, 2])
                with tds_action_cols[0]:
                    run_tds_with_note_clicked = st.button(
                        "Save + Run TDS Assist",
                        use_container_width=True,
                        key=f"btn_tds_assist_note_{risk_sim_id}",
                    )
                with tds_action_cols[1]:
                    run_tds_without_note_clicked = st.button(
                        "Run Without Note",
                        use_container_width=True,
                        key=f"btn_tds_assist_no_note_{risk_sim_id}",
                    )
                with tds_action_cols[2]:
                    st.caption("Runs CORE_INTERNAL.RUN_CORTEX_TDS_EXPLANATION_ASSIST. Official TDS and machine cost remain unchanged.")

                if run_tds_with_note_clicked or run_tds_without_note_clicked:
                    try:
                        selected_note_id = None

                        with st.spinner("Running Cortex TDS Explanation Assist..."):
                            if run_tds_with_note_clicked:
                                normalized_note_id = normalize_id(maintenance_note_id, "Maintenance Note ID")
                                if not tds_note_text.strip():
                                    raise ValueError("Please enter a maintenance/tooling note, or use Run Without Note.")

                                upsert_tooling_maintenance_note(
                                    maintenance_note_id=normalized_note_id,
                                    simulation_id=risk_sim_id,
                                    work_center_id=work_center_id,
                                    source_name=tds_source_name,
                                    note_title=tds_note_title,
                                    note_text=tds_note_text.strip(),
                                )
                                selected_note_id = normalized_note_id

                            tds_result = run_cortex_tds_explanation_assist(
                                simulation_id=risk_sim_id,
                                maintenance_note_id=selected_note_id,
                            )

                        st.session_state["last_tds_maintenance_note_id"] = selected_note_id or "NO_NOTE"
                        st.session_state["last_tds_assist_result"] = tds_result

                        if tds_result.get("status") == "SUCCESS":
                            note("Cortex TDS explanation assist completed successfully.", "success")
                        else:
                            note("Cortex TDS explanation assist did not return SUCCESS.", "warning")

                        st.json(tds_result)

                    except Exception as exc:
                        st.error(f"Cortex TDS explanation assist failed: {exc}")

                tds_assist_df = load_cortex_tds_explanation_assist(risk_sim_id, limit=1)

                if tds_assist_df.empty:
                    note("No Cortex TDS explanation found yet for this simulation. Run TDS Assist to generate one.", "soft")
                else:
                    tds_row = tds_assist_df.iloc[0]

                    strain_cols = st.columns(4)
                    with strain_cols[0]:
                        kpi_card(
                            "Cortex Strain Band",
                            str(tds_row.get("CORTEX_TOOLING_STRAIN_BAND", "N/A")),
                            "Advisory classification",
                            "rgba(177,151,252,0.22)",
                        )
                    with strain_cols[1]:
                        kpi_card(
                            "Extracted Severity",
                            str(tds_row.get("CORTEX_EXTRACTED_SEVERITY", "N/A")),
                            str(tds_row.get("CORTEX_EXTRACTED_WORK_CENTER", "")),
                            "rgba(255,143,171,0.20)",
                        )
                    with strain_cols[2]:
                        kpi_card(
                            "Related Operation",
                            str(tds_row.get("CORTEX_EXTRACTED_RELATED_OPERATION", "N/A")),
                            str(tds_row.get("CORTEX_EXTRACTED_STRAIN_SIGNAL", "")),
                            "rgba(255,209,102,0.20)",
                        )
                    with strain_cols[3]:
                        override_flag = bool(tds_row.get("OFFICIAL_COST_OVERRIDE_FLAG", False))
                        kpi_card(
                            "TDS Override",
                            "YES" if override_flag else "NO",
                            str(tds_row.get("ASSIST_METHOD", "N/A")),
                            "rgba(126,247,196,0.18)",
                        )

                    signal_record = {
                        "Maintenance Note ID": tds_row.get("MAINTENANCE_NOTE_ID", ""),
                        "Extracted Work Center": tds_row.get("CORTEX_EXTRACTED_WORK_CENTER", ""),
                        "Strain Signal": tds_row.get("CORTEX_EXTRACTED_STRAIN_SIGNAL", ""),
                        "Severity": tds_row.get("CORTEX_EXTRACTED_SEVERITY", ""),
                        "Related Operation": tds_row.get("CORTEX_EXTRACTED_RELATED_OPERATION", ""),
                        "Impact": tds_row.get("CORTEX_EXTRACTED_IMPACT", ""),
                    }
                    st.dataframe(vertical_record_table(signal_record), use_container_width=True, hide_index=True)

                    st.markdown("#### TDS Reasoning")
                    st.write(tds_row.get("CORTEX_REASONING", ""))

                    st.markdown("#### Engineering Review Note")
                    st.write(tds_row.get("CORTEX_ENGINEERING_REVIEW_NOTE", ""))

                    st.dataframe(tds_assist_df, use_container_width=True, hide_index=True)

                recent_tds_df = load_cortex_tds_explanation_assist(limit=10)
                if not recent_tds_df.empty:
                    st.markdown("#### Recent TDS Explanation Assist Results")
                    st.dataframe(recent_tds_df, use_container_width=True, hide_index=True)

            with risk_tabs[6]:
                st.markdown("#### Cortex Cost Explanation + Executive Summary")
                note(
                    "Advisory only: Cortex explains the official deterministic cost output. It does not override cost, CSS, FMIS, TDS, BMCS, or quote trust status.",
                    "soft",
                )

                explanation_top_cols = st.columns(4)
                with explanation_top_cols[0]:
                    kpi_card(
                        "Baseline Cost",
                        money(row.get("BASELINE_TOTAL_COST_USD", 0)),
                        "Official deterministic cost",
                        "rgba(99,230,255,0.20)",
                    )
                with explanation_top_cols[1]:
                    kpi_card(
                        "Risk-Adjusted Cost",
                        money(row.get("RISK_ADJUSTED_TOTAL_COST_USD", 0)),
                        "Official CSS + FMIS + TDS output",
                        "rgba(255,143,171,0.20)",
                    )
                with explanation_top_cols[2]:
                    kpi_card(
                        "Risk Uplift",
                        money(row.get("TOTAL_RISK_UPLIFT_USD", 0)),
                        f"{as_float(row.get('TOTAL_RISK_UPLIFT_PCT', 0)):.2f}% above baseline",
                        "rgba(255,209,102,0.20)",
                    )
                with explanation_top_cols[3]:
                    kpi_card(
                        "Override",
                        "NO",
                        "Explanation layer only",
                        "rgba(126,247,196,0.18)",
                    )

                explanation_action_cols = st.columns([1, 2])
                with explanation_action_cols[0]:
                    run_cost_explanation_clicked = st.button(
                        "Generate Executive Summary",
                        use_container_width=True,
                        key=f"btn_cost_explanation_{risk_sim_id}",
                    )
                with explanation_action_cols[1]:
                    st.caption("Runs CORE_INTERNAL.RUN_CORTEX_COST_EXPLANATION for the selected simulation. Official cost remains unchanged.")

                if run_cost_explanation_clicked:
                    try:
                        with st.spinner("Generating Cortex cost explanation and executive summary..."):
                            explanation_result = run_cortex_cost_explanation(risk_sim_id)

                        st.session_state["last_cost_explanation_result"] = explanation_result

                        if explanation_result.get("status") == "SUCCESS":
                            note("Cortex cost explanation generated successfully.", "success")
                        else:
                            note("Cortex cost explanation did not return SUCCESS.", "warning")

                        st.json(explanation_result)

                    except Exception as exc:
                        st.error(f"Cortex cost explanation failed: {exc}")

                cost_explanation_df = load_cortex_cost_explanation_summary(risk_sim_id, limit=1)

                if cost_explanation_df.empty:
                    note("No Cortex cost explanation found yet for this simulation. Click Generate Executive Summary.", "soft")
                else:
                    explanation_row = cost_explanation_df.iloc[0]

                    explanation_status_cols = st.columns(4)
                    with explanation_status_cols[0]:
                        kpi_card(
                            "BMCS Trust",
                            str(explanation_row.get("QUOTE_TRUST_STATUS", "N/A")),
                            str(explanation_row.get("BMCS_REVIEW_STATUS", "N/A")),
                            "rgba(177,151,252,0.20)",
                        )
                    with explanation_status_cols[1]:
                        kpi_card(
                            "CSS",
                            f"{as_float(explanation_row.get('CSS_SCORE', 0)):.0f}",
                            str(explanation_row.get("SCRAP_RISK_LEVEL", "N/A")),
                            "rgba(255,143,171,0.20)",
                        )
                    with explanation_status_cols[2]:
                        kpi_card(
                            "FMIS",
                            f"{as_float(explanation_row.get('AVG_WEIGHTED_FMIS', 1)):.4f}x",
                            "Official weighted index",
                            "rgba(99,230,255,0.20)",
                        )
                    with explanation_status_cols[3]:
                        kpi_card(
                            "TDS",
                            f"{as_float(explanation_row.get('MAX_TDS_FACTOR', 1)):.2f}x",
                            "Official max factor",
                            "rgba(255,209,102,0.20)",
                        )

                    summary_tabs = st.tabs([
                        "Executive Summary",
                        "Cost Drivers",
                        "Risk Uplift",
                        "BMCS Trust",
                        "Engineering Note",
                        "Raw Row",
                    ])

                    with summary_tabs[0]:
                        st.write(explanation_row.get("EXECUTIVE_SUMMARY", ""))
                    with summary_tabs[1]:
                        st.write(explanation_row.get("COST_DRIVER_EXPLANATION", ""))
                    with summary_tabs[2]:
                        st.write(explanation_row.get("RISK_UPLIFT_EXPLANATION", ""))
                    with summary_tabs[3]:
                        st.write(explanation_row.get("BMCS_TRUST_EXPLANATION", ""))
                    with summary_tabs[4]:
                        st.write(explanation_row.get("ENGINEERING_REVIEW_NOTE", ""))
                    with summary_tabs[5]:
                        st.dataframe(cost_explanation_df, use_container_width=True, hide_index=True)

                recent_explanation_df = load_cortex_cost_explanation_summary(limit=10)
                if not recent_explanation_df.empty:
                    st.markdown("#### Recent Cost Explanation Results")
                    recent_cols = [
                        "SIMULATION_ID",
                        "RFQ_ID",
                        "BASELINE_TOTAL_COST_USD",
                        "RISK_ADJUSTED_TOTAL_COST_USD",
                        "TOTAL_RISK_UPLIFT_PCT",
                        "QUOTE_TRUST_STATUS",
                        "ASSESSMENT_STATUS",
                        "UPDATED_AT",
                    ]
                    recent_cols = [c for c in recent_cols if c in recent_explanation_df.columns]
                    st.dataframe(
                        format_table_money(recent_explanation_df[recent_cols], [
                            "BASELINE_TOTAL_COST_USD",
                            "RISK_ADJUSTED_TOTAL_COST_USD",
                        ]),
                        use_container_width=True,
                        hide_index=True,
                    )

            with risk_tabs[7]:
                st.write(row.get("RISK_CALCULATION_NOTES", "No notes found."))
                note("Baseline cost remains the audit foundation. Risk-adjusted cost adds explainable CSS, FMIS, and TDS adjustments; BMCS controls whether an RFQ-derived quotation is trusted, review-recommended, or preliminary.", "soft")

# -----------------------------
# Tab 5: Scenario History
# -----------------------------

with main_tabs[4]:
    section("Saved Simulation History", "📜")
    st.markdown('<div class="tab-subtitle">Every run is stored by SIMULATION_ID, making the dashboard useful for audit trails and comparison.</div>', unsafe_allow_html=True)
    history_limit = st.slider("Rows to show", min_value=10, max_value=500, value=100, step=10)
    history_df = load_history(history_limit)

    if history_df.empty:
        note("No simulations found yet. Run a simulation first.", "soft")
    else:
        hist_summary = history_df.dropna(subset=["TOTAL_CONFIGURED_COST_USD"])
        if not hist_summary.empty:
            c1, c2, c3, c4 = st.columns(4)
            with c1:
                kpi_card("Saved Runs", f"{len(history_df):,}", "Most recent records shown", "rgba(99,230,255,0.20)")
            with c2:
                kpi_card("Avg Total Cost", money(hist_summary["TOTAL_CONFIGURED_COST_USD"].mean()), "Across completed runs", "rgba(126,247,196,0.18)")
            with c3:
                kpi_card("Max Total Cost", money(hist_summary["TOTAL_CONFIGURED_COST_USD"].max()), "Highest completed run", "rgba(255,209,102,0.20)")
            with c4:
                kpi_card("Avg Target Price", money(hist_summary["TARGET_PRICE_USD"].mean()), "Across completed runs", "rgba(177,151,252,0.20)")

        st.dataframe(format_table_money(history_df, [
            "MATERIAL_COST_USD", "LABOR_COST_USD", "MACHINE_COST_USD", "OVERHEAD_COST_USD",
            "TOTAL_CONFIGURED_COST_USD", "FLOOR_PRICE_USD", "TARGET_PRICE_USD", "CEILING_PRICE_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TOTAL_RISK_UPLIFT_USD", "COMMODITY_ADJUSTMENT_USD", "SCRAP_ADJUSTMENT_USD", "TOOLING_ADJUSTMENT_USD", "OVERHEAD_ADJUSTMENT_USD"
        ]), use_container_width=True, hide_index=True)
        st.download_button(
            "Download history CSV",
            data=dataframe_to_csv_bytes(history_df),
            file_name="kmat_simulation_history.csv",
            mime="text/csv",
        )

# -----------------------------
# Tab 6: Compare Scenarios
# -----------------------------

with main_tabs[5]:
    section("Scenario Comparison", "📊")
    st.markdown('<div class="tab-subtitle">Choose a baseline and compare cost, price, profit, and cost-driver shifts.</div>', unsafe_allow_html=True)
    history_df = load_history(200)
    available_ids = history_df["SIMULATION_ID"].dropna().tolist() if not history_df.empty else []

    if len(available_ids) < 1:
        note("Run at least one simulation to enable comparison.", "soft")
    else:
        default_compare = available_ids[: min(5, len(available_ids))]
        select_cols = st.columns([1, 2])
        with select_cols[0]:
            baseline_id = st.selectbox("Baseline Simulation", available_ids, index=0, key="compare_baseline")
        with select_cols[1]:
            compare_ids = st.multiselect("Scenarios to Compare", available_ids, default=default_compare, key="compare_ids")

        compare_df = load_compare(compare_ids)
        compare_df = add_baseline_deltas(compare_df, baseline_id)

        if compare_df.empty:
            note("No output rows found for selected simulations. Make sure the procedure ran successfully.", "warning")
        else:
            if "TARGET_PROFIT_USD" in compare_df.columns:
                best_profit_row = compare_df.sort_values("TARGET_PROFIT_USD", ascending=False).iloc[0]
                lowest_cost_row = compare_df.sort_values("TOTAL_CONFIGURED_COST_USD", ascending=True).iloc[0]
                c1, c2, c3 = st.columns(3)
                with c1:
                    kpi_card("Baseline", baseline_id, "Reference simulation", "rgba(99,230,255,0.18)")
                with c2:
                    kpi_card("Best Profit", safe_html(best_profit_row["SIMULATION_ID"]), money(best_profit_row["TARGET_PROFIT_USD"]), "rgba(126,247,196,0.20)")
                with c3:
                    kpi_card("Lowest Cost", safe_html(lowest_cost_row["SIMULATION_ID"]), money(lowest_cost_row["TOTAL_CONFIGURED_COST_USD"]), "rgba(255,209,102,0.20)")

            display_cols = [
                "SIMULATION_ID",
                "SCENARIO_NAME",
                "CONFIGURATION",
                "MATERIAL_COST_USD",
                "LABOR_COST_USD",
                "MACHINE_COST_USD",
                "OVERHEAD_COST_USD",
                "TOTAL_CONFIGURED_COST_USD",
                "RISK_ADJUSTED_TOTAL_COST_USD",
                "TOTAL_RISK_UPLIFT_USD",
                "TOTAL_RISK_UPLIFT_PCT",
                "RISK_COST_DELTA_VS_BASELINE_USD",
                "RISK_COST_DELTA_VS_BASELINE_PCT",
                "TARGET_PRICE_USD",
                "TARGET_PROFIT_USD",
                "RISK_ADJUSTED_TARGET_PROFIT_USD",
                "RISK_PROFIT_DELTA_VS_BASELINE_USD",
                "RISK_ADJUSTED_GROSS_MARGIN_PCT",
                "TARGET_MARKUP_ON_COST_PCT",
            ]
            display_cols = [c for c in display_cols if c in compare_df.columns]
            st.dataframe(format_table_money(compare_df[display_cols], [
                "MATERIAL_COST_USD", "LABOR_COST_USD", "MACHINE_COST_USD", "OVERHEAD_COST_USD",
                "TOTAL_CONFIGURED_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TOTAL_RISK_UPLIFT_USD", "RISK_COST_DELTA_VS_BASELINE_USD", "TARGET_PRICE_USD",
                "TARGET_PROFIT_USD", "RISK_ADJUSTED_TARGET_PROFIT_USD", "RISK_PROFIT_DELTA_VS_BASELINE_USD"
            ]), use_container_width=True, hide_index=True)

            chart_df = compare_df[["SIMULATION_ID", "TOTAL_CONFIGURED_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TARGET_PRICE_USD", "RISK_ADJUSTED_TARGET_PROFIT_USD"]].copy()
            section("Cost, Price, and Profit", "💹")
            st.bar_chart(chart_df, x="SIMULATION_ID", y=["TOTAL_CONFIGURED_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TARGET_PRICE_USD", "RISK_ADJUSTED_TARGET_PROFIT_USD"], use_container_width=True)

            if "COST_DELTA_VS_BASELINE_USD" in compare_df.columns:
                delta_df = compare_df[["SIMULATION_ID", "RISK_COST_DELTA_VS_BASELINE_USD", "RISK_PROFIT_DELTA_VS_BASELINE_USD"]].copy()
                section("Delta vs Baseline", "⚖️")
                st.bar_chart(delta_df, x="SIMULATION_ID", y=["RISK_COST_DELTA_VS_BASELINE_USD", "RISK_PROFIT_DELTA_VS_BASELINE_USD"], use_container_width=True)

            breakdown_df = compare_df[[
                "SIMULATION_ID",
                "MATERIAL_COST_USD",
                "LABOR_COST_USD",
                "MACHINE_COST_USD",
                "OVERHEAD_COST_USD",
            ]].copy()
            section("Cost Breakdown by Scenario", "🧮")
            st.bar_chart(breakdown_df, x="SIMULATION_ID", y=["MATERIAL_COST_USD", "LABOR_COST_USD", "MACHINE_COST_USD", "OVERHEAD_COST_USD"], use_container_width=True)

            st.download_button(
                "Download comparison CSV",
                data=dataframe_to_csv_bytes(compare_df),
                file_name="kmat_scenario_comparison.csv",
                mime="text/csv",
            )
            st.caption("Target markup is markup on cost. Gross margin % is calculated as profit divided by target price.")

# -----------------------------
# Tab 7: Component Impact
# -----------------------------

with main_tabs[6]:
    section("Component-Level Impact", "🔍")
    st.markdown('<div class="tab-subtitle">Compare selected BOM components between two runs to explain why cost changed.</div>', unsafe_allow_html=True)
    history_df = load_history(200)
    available_ids = history_df["SIMULATION_ID"].dropna().tolist() if not history_df.empty else []

    if len(available_ids) < 2:
        note("Run at least two simulations to compare component impact.", "soft")
    else:
        col_a, col_b = st.columns(2)
        with col_a:
            baseline_component_id = st.selectbox("Baseline", available_ids, index=0, key="component_baseline")
        with col_b:
            scenario_component_id = st.selectbox("Scenario", available_ids, index=1 if len(available_ids) > 1 else 0, key="component_scenario")

        impact_df = load_component_impact(baseline_component_id, scenario_component_id)

        if impact_df.empty:
            note("No component outputs found for selected simulations.", "warning")
        else:
            added = int(((impact_df["SELECTED_IN_BASELINE"] == False) & (impact_df["SELECTED_IN_SCENARIO"] == True)).sum())
            removed = int(((impact_df["SELECTED_IN_BASELINE"] == True) & (impact_df["SELECTED_IN_SCENARIO"] == False)).sum())
            changed = int((impact_df["COMPONENT_COST_DELTA_USD"].abs() > 0).sum())
            c1, c2, c3 = st.columns(3)
            with c1:
                kpi_card("Added Components", f"{added}", "Selected only in scenario", "rgba(126,247,196,0.18)")
            with c2:
                kpi_card("Removed Components", f"{removed}", "Selected only in baseline", "rgba(255,143,171,0.18)")
            with c3:
                kpi_card("Changed Cost Lines", f"{changed}", "Non-zero delta rows", "rgba(99,230,255,0.20)")

            st.dataframe(format_table_money(impact_df, [
                "BASELINE_LINE_MATERIAL_COST_USD", "SCENARIO_LINE_MATERIAL_COST_USD", "COMPONENT_COST_DELTA_USD",
                "BASELINE_ADJUSTED_LINE_MATERIAL_COST_USD", "SCENARIO_ADJUSTED_LINE_MATERIAL_COST_USD", "RISK_ADJUSTED_COMPONENT_DELTA_USD"
            ]), use_container_width=True, hide_index=True)

            top_delta_df = impact_df.copy()
            top_delta_df["ABS_DELTA"] = top_delta_df["RISK_ADJUSTED_COMPONENT_DELTA_USD"].abs()
            top_delta_df = top_delta_df.sort_values("ABS_DELTA", ascending=False).head(10)
            section("Top Component Cost Deltas", "📌")
            st.bar_chart(top_delta_df, x="COMPONENT_ID", y="RISK_ADJUSTED_COMPONENT_DELTA_USD", use_container_width=True)

            st.download_button(
                "Download component impact CSV",
                data=dataframe_to_csv_bytes(impact_df),
                file_name=f"component_impact_{baseline_component_id}_vs_{scenario_component_id}.csv",
                mime="text/csv",
            )

# -----------------------------
# Tab 8: Batch Demo Runner
# -----------------------------

with main_tabs[7]:
    section("One-Click Demo Scenario Runner", "🚀")
    st.markdown('<div class="tab-subtitle">Create a clean set of demo runs for presentation: baseline, cost inflation, markup change, and economy truck.</div>', unsafe_allow_html=True)

    batch_cols = st.columns(2)
    with batch_cols[0]:
        batch_prefix = st.text_input("Batch Prefix", value=f"DEMO_{utc_stamp()}")
    with batch_cols[1]:
        batch_customer_id = st.text_input("Batch Customer ID", value="CUST_DEMO_001")

    selected_batch_presets = st.multiselect(
        "Scenarios to Run",
        list(PRESETS.keys()),
        default=list(PRESETS.keys()),
    )

    note("Recommended demo flow: run all presets, open Compare Scenarios, choose the baseline, then open Component Impact for premium vs economy truck.", "soft")

    if st.button("Run Selected Demo Scenarios", type="primary"):
        try:
            prefix = normalize_id(batch_prefix, "Batch Prefix")
            customer_id = normalize_id(batch_customer_id, "Batch Customer ID")
            batch_results = []

            with st.spinner("Running selected demo scenarios..."):
                for preset_name in selected_batch_presets:
                    preset = PRESETS[preset_name]
                    sim_id = normalize_id(f"{prefix}_{preset['suffix']}", "Simulation ID")
                    result = run_one_simulation(
                        simulation_id=sim_id,
                        customer_id=customer_id,
                        scenario_name=preset["scenario_name"],
                        selections=preset["selections"],
                        material_multiplier=preset["material"],
                        labor_multiplier=preset["labor"],
                        machine_multiplier=preset["machine"],
                        overhead_multiplier=preset["overhead"],
                        target_markup_pct=preset["target"],
                        floor_markup_pct=preset["floor"],
                        ceiling_markup_pct=preset["ceiling"],
                        planned_production_date=st.session_state["ui_planned_date"],
                        plant_id=normalize_id(st.session_state["ui_plant_id"], "Plant ID"),
                        production_line_id=normalize_id(st.session_state["ui_line_id"], "Production Line ID"),
                        batch_quantity=float(st.session_state["ui_batch_qty"]),
                    )
                    batch_results.append({
                        "simulation_id": sim_id,
                        "preset": preset_name,
                        "status": result.get("status"),
                        "baseline_total_cost_usd": result.get("baseline_total_cost_usd"),
                        "risk_adjusted_total_cost_usd": result.get("risk_adjusted_total_cost_usd"),
                        "total_risk_uplift_usd": result.get("total_risk_uplift_usd"),
                    })

            batch_result_df = pd.DataFrame(batch_results)
            note("Batch demo scenarios completed. Open the comparison tab to analyze the result.", "success")
            st.dataframe(format_table_money(batch_result_df, ["baseline_total_cost_usd", "risk_adjusted_total_cost_usd", "total_risk_uplift_usd"]), use_container_width=True, hide_index=True)

            run_ids = batch_result_df["simulation_id"].tolist()
            compare_df = load_compare(run_ids)
            if not compare_df.empty:
                compare_df = add_baseline_deltas(compare_df, run_ids[0])
                section("Batch Comparison Preview", "📊")
                st.dataframe(format_table_money(compare_df, [
                    "MATERIAL_COST_USD", "LABOR_COST_USD", "MACHINE_COST_USD", "OVERHEAD_COST_USD",
                    "TOTAL_CONFIGURED_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TOTAL_RISK_UPLIFT_USD", "TARGET_PRICE_USD", "RISK_ADJUSTED_TARGET_PROFIT_USD"
                ]), use_container_width=True, hide_index=True)
                st.bar_chart(compare_df, x="SIMULATION_ID", y=["TOTAL_CONFIGURED_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TARGET_PRICE_USD"], use_container_width=True)

        except Exception as exc:
            st.error(f"Batch run failed: {exc}")


# -----------------------------
# Tab 2: RFQ / BMCS Review
# -----------------------------

with main_tabs[1]:
    section("RFQ / BOM Match Confidence", "📄")
    st.markdown(
        '<div class="tab-subtitle">Validate whether customer RFQ text has been translated into the correct KMAT configuration before relying on the cost result. BMCS is the trust gate before final quotation.</div>',
        unsafe_allow_html=True,
    )

    try:
        rfq_df = load_rfq_bmcs_status(200)
    except Exception as exc:
        rfq_df = pd.DataFrame()
        st.error(f"Unable to load RFQ/BMCS data. Confirm Phase 6A, 6B, and 6C objects exist. Details: {exc}")

    if rfq_df.empty:
        note("No RFQ/BMCS records found. Load Phase 6A sample RFQs first, then run the BMCS scoring procedure.", "soft")
    else:
        rfq_options = rfq_df["RFQ_ID"].dropna().tolist()
        selected_rfq_id = st.selectbox("Select RFQ", rfq_options, index=0, key="selected_bmcs_rfq")
        selected_rfq = rfq_df[rfq_df["RFQ_ID"] == selected_rfq_id].iloc[0]
        selected_sim_id = str(selected_rfq.get("SIMULATION_ID", ""))

        score = as_float(selected_rfq.get("BOM_MATCH_CONFIDENCE_SCORE", 0))
        review_status = str(selected_rfq.get("REVIEW_STATUS", "MISSING_ASSESSMENT"))
        final_allowed = bool(selected_rfq.get("FINAL_TRUSTED_COST_ALLOWED_FLAG", False))
        review_required = bool(selected_rfq.get("REVIEW_REQUIRED_FLAG", False))

        top_cols = st.columns(5)
        with top_cols[0]:
            kpi_card("Rule BMCS", f"{as_float(selected_rfq.get('RULE_BASED_BMCS_SCORE', 0)):.2f}%", "Rule-based text match", "rgba(99,230,255,0.20)")
        with top_cols[1]:
            kpi_card("Cortex BMCS", f"{as_float(selected_rfq.get('CORTEX_BMCS_SCORE', 0)):.2f}%", "AI_COMPLETE assessment", "rgba(177,151,252,0.20)")
        with top_cols[2]:
            kpi_card("Final BMCS", f"{score:.2f}%", str(selected_rfq.get("FINAL_BMCS_METHOD", "N/A")), "rgba(126,247,196,0.20)" if score >= 90 else "rgba(255,209,102,0.22)" if score >= 70 else "rgba(255,143,171,0.24)")
        with top_cols[3]:
            kpi_card("Review Required", "YES" if review_required else "NO", review_status, "rgba(255,143,171,0.20)" if review_required else "rgba(126,247,196,0.18)")
        with top_cols[4]:
            kpi_card("Final Cost Allowed", "YES" if final_allowed else "NO", "Trusted quote flag", "rgba(126,247,196,0.18)" if final_allowed else "rgba(255,143,171,0.24)")

        if review_status == "AUTO_APPROVED":
            note("High-confidence RFQ mapping. The configuration can proceed automatically to costing.", "success")
        elif review_status == "REVIEW_RECOMMENDED":
            note("Medium-confidence RFQ mapping. Costing can proceed, but engineering review is recommended before quote release.", "warning")
        elif review_status == "REVIEW_REQUIRED":
            note("Low-confidence RFQ mapping. Do not present this as a final trusted cost until engineering review is completed.", "warning")
        else:
            note("BMCS assessment is missing or incomplete for this RFQ.", "warning")

        section("RFQ Source and Extracted Configuration", "🧾")
        info_cols = st.columns([1.1, 1.4])
        with info_cols[0]:
            st.markdown("**RFQ Metadata**")
            st.dataframe(
                pd.DataFrame([{
                    "RFQ_ID": selected_rfq.get("RFQ_ID"),
                    "Customer": selected_rfq.get("CUSTOMER_NAME"),
                    "Document": selected_rfq.get("SOURCE_DOCUMENT_NAME"),
                    "Document Type": selected_rfq.get("SOURCE_DOCUMENT_TYPE"),
                    "Simulation ID": selected_sim_id,
                    "Extraction Method": selected_rfq.get("EXTRACTION_METHOD"),
                    "Model Placeholder": selected_rfq.get("EXTRACTION_MODEL_NAME"),
                }]),
                use_container_width=True,
                hide_index=True,
            )
            st.markdown("**Customer RFQ Text**")
            st.text_area("RFQ Text", value=str(selected_rfq.get("SOURCE_DOCUMENT_TEXT", "")), height=150, disabled=True, label_visibility="collapsed")
        with info_cols[1]:
            config_df = pd.DataFrame([{
                "ENGINE": selected_rfq.get("ENGINE"),
                "CAB": selected_rfq.get("CAB"),
                "WHEEL": selected_rfq.get("WHEEL"),
                "COLOR": selected_rfq.get("COLOR"),
            }])
            st.markdown("**Extracted KMAT Configuration**")
            st.dataframe(config_df, use_container_width=True, hide_index=True)
            try:
                extracted_json = selected_rfq.get("EXTRACTED_CONFIGURATION_JSON")
                st.json(json.loads(extracted_json) if isinstance(extracted_json, str) else extracted_json)
            except Exception:
                st.write(selected_rfq.get("EXTRACTED_CONFIGURATION_JSON"))

        section("BMCS Actions", "⚙️")
        action_cols = st.columns(2)
        with action_cols[0]:
            hybrid_clicked = st.button(
                "Run Hybrid Cortex BMCS",
                use_container_width=True,
                key="btn_run_hybrid_cortex_bmcs",
            )
        with action_cols[1]:
            full_clicked = st.button(
                "Run Full RFQ Quote Pipeline",
                type="primary",
                use_container_width=True,
                key="btn_full_rfq_flow",
            )

        if hybrid_clicked:
            try:
                with st.spinner("Running hybrid Cortex BMCS assessment..."):
                    result = run_cortex_bmcs_assessment(selected_rfq_id)
                st.session_state["last_hybrid_bmcs_result"] = result
                if result.get("status") == "SUCCESS":
                    note(f"Hybrid Cortex BMCS completed for {selected_rfq_id}.", "success")
                    st.json(result)
                    soft_rerun()
                else:
                    note("Hybrid Cortex BMCS did not return SUCCESS.", "warning")
                    st.json(result)
            except Exception as exc:
                st.error(f"Hybrid Cortex BMCS failed: {exc}")

        if full_clicked:
            try:
                with st.spinner("Running hybrid BMCS, preparing simulation inputs, and running KMAT cost engine..."):
                    result = run_cortex_rfq_quote_pipeline(selected_rfq_id)
                st.session_state["last_rfq_cost_flow_result"] = result
                if result.get("status") == "SUCCESS":
                    sim_id = result.get("simulation_id")
                    st.session_state["last_simulation_id"] = sim_id
                    st.session_state["last_procedure_result"] = result.get("cost_result", {})
                    note(
                        f"Full RFQ quote pipeline completed for {selected_rfq_id}. "
                        f"Trust status: {result.get('quote_trust_status')}",
                        "success",
                    )
                    st.json(result)
                    soft_rerun()
                else:
                    note("Full RFQ quote pipeline did not return SUCCESS.", "warning")
                    st.json(result)
            except Exception as exc:
                st.error(f"Full RFQ quote pipeline failed: {exc}")

        section("Scoring Evidence", "🔎")
        detail_df = load_rfq_scoring_detail(selected_rfq_id)
        if detail_df.empty:
            note("No scoring detail rows found yet. Click Run BMCS Scoring to generate explanation rows.", "soft")
        else:
            st.dataframe(detail_df, use_container_width=True, hide_index=True)
            st.download_button(
                "Download BMCS scoring detail CSV",
                data=dataframe_to_csv_bytes(detail_df),
                file_name=f"{selected_rfq_id}_bmcs_scoring_detail.csv",
                mime="text/csv",
            )

        section("Cost Output Linked to RFQ", "💰")
        if selected_sim_id:
            summary_df = load_summary(selected_sim_id)
        else:
            summary_df = pd.DataFrame()

        if summary_df.empty:
            note("No cost output exists yet for this RFQ simulation. Use Score + Prepare + Cost.", "soft")
        else:
            row = summary_df.iloc[0]
            cost_cols = st.columns(5)
            with cost_cols[0]:
                kpi_card("Simulation", selected_sim_id, str(row.get("QUOTE_TRUST_STATUS", "N/A")), "rgba(99,230,255,0.18)")
            with cost_cols[1]:
                kpi_card("Baseline Cost", money(row.get("BASELINE_TOTAL_COST_USD", row.get("TOTAL_CONFIGURED_COST_USD", 0))), "Deterministic cost", "rgba(99,230,255,0.18)")
            with cost_cols[2]:
                kpi_card("Risk-Adjusted Cost", money(row.get("RISK_ADJUSTED_TOTAL_COST_USD", 0)), "CSS + FMIS + TDS", "rgba(255,143,171,0.20)")
            with cost_cols[3]:
                kpi_card("Risk Uplift", money(row.get("TOTAL_RISK_UPLIFT_USD", 0)), f"{as_float(row.get('TOTAL_RISK_UPLIFT_PCT', 0)):.2f}%", "rgba(255,209,102,0.20)")
            with cost_cols[4]:
                kpi_card("Trusted Final?", "YES" if bool(row.get("FINAL_TRUSTED_COST_ALLOWED_FLAG", False)) else "NO", str(row.get("BMCS_REVIEW_STATUS", "N/A")), "rgba(126,247,196,0.18)" if bool(row.get("FINAL_TRUSTED_COST_ALLOWED_FLAG", False)) else "rgba(255,143,171,0.24)")

            display_cols = [
                "SIMULATION_ID", "RFQ_ID", "SOURCE_DOCUMENT_NAME", "BOM_MATCH_CONFIDENCE_SCORE",
                "BMCS_REVIEW_STATUS", "FINAL_TRUSTED_COST_ALLOWED_FLAG", "QUOTE_TRUST_STATUS",
                "BASELINE_TOTAL_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TOTAL_RISK_UPLIFT_USD",
                "TOTAL_RISK_UPLIFT_PCT", "TARGET_PRICE_USD", "RISK_CALCULATION_STATUS"
            ]
            display_cols = [c for c in display_cols if c in summary_df.columns]
            st.dataframe(format_table_money(summary_df[display_cols], [
                "BASELINE_TOTAL_COST_USD", "RISK_ADJUSTED_TOTAL_COST_USD", "TOTAL_RISK_UPLIFT_USD", "TARGET_PRICE_USD"
            ]), use_container_width=True, hide_index=True)

        section("All RFQ/BMCS Records", "📚")
        display_cols = [
            "RFQ_ID", "CUSTOMER_NAME", "SOURCE_DOCUMENT_NAME", "SIMULATION_ID",
            "ENGINE", "CAB", "WHEEL", "COLOR", "BOM_MATCH_CONFIDENCE_SCORE",
            "REVIEW_STATUS", "REVIEW_REQUIRED_FLAG", "FINAL_TRUSTED_COST_ALLOWED_FLAG",
            "BMCS_RISK_LEVEL", "RULE_VALIDATION_STATUS"
        ]
        display_cols = [c for c in display_cols if c in rfq_df.columns]
        st.dataframe(rfq_df[display_cols], use_container_width=True, hide_index=True)
        st.download_button(
            "Download RFQ BMCS status CSV",
            data=dataframe_to_csv_bytes(rfq_df),
            file_name="rfq_bmcs_status.csv",
            mime="text/csv",
        )

# -----------------------------
# Tab 1: Cortex RFQ Upload / Intake
# -----------------------------

with main_tabs[0]:
    section("Cortex RFQ Document Intake", "📄")
    st.markdown(
        '<div class="tab-subtitle">Upload an RFQ document or paste RFQ text. Cortex handles text extraction, translation, summary, KMAT configuration extraction, RFQ complexity classification, and BMCS scoring.</div>',
        unsafe_allow_html=True,
    )

    st.markdown(
        """
        <div class="rfq-callout">
            <div class="rfq-callout-title">Uniform RFQ-to-Cost Workflow</div>
            <div class="rfq-callout-text">
                Step 1: Upload or paste RFQ → Step 2: Process with Cortex → Step 3: Run full hybrid BMCS quote pipeline.
                For PDF uploads, the Snowflake stage must use server-side encryption: <b>ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')</b>.
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    flow_cols = st.columns(5)
    with flow_cols[0]:
        kpi_card("1. RFQ Source", "Upload/Paste", "PDF, DOCX, TXT, or manual text", "rgba(99,230,255,0.18)")
    with flow_cols[1]:
        kpi_card("2. Cortex Intake", "Extract", "AI_EXTRACT + AI_TRANSLATE", "rgba(177,151,252,0.18)")
    with flow_cols[2]:
        kpi_card("3. Summary", "Classify", "SUMMARIZE + AI_CLASSIFY", "rgba(255,209,102,0.18)")
    with flow_cols[3]:
        kpi_card("4. BMCS", "Validate", "Confidence + review status", "rgba(126,247,196,0.18)")
    with flow_cols[4]:
        kpi_card("5. Costing", "Run", "Deterministic KMAT engine", "rgba(255,143,171,0.18)")

    st.markdown("---")
    section("RFQ Input", "🧾")

    intake_cols = st.columns([1.0, 1.15])

    with intake_cols[0]:
        st.markdown("#### RFQ Identity")
        rfq_id = st.text_input(
            "RFQ ID",
            value=f"RFQ_UI_{utc_stamp()}",
            key="cortex_rfq_id",
            help="Use a fresh RFQ ID when testing a new upload.",
        )
        rfq_customer_id = st.text_input(
            "Customer ID",
            value="CUST_RFQ_UI_001",
            key="cortex_rfq_customer_id",
        )
        rfq_customer_name = st.text_input(
            "Customer Name",
            value="Demo Customer",
            key="cortex_rfq_customer_name",
        )
        source_language_code = st.selectbox(
            "Source Language",
            ["en", "auto", "hi", "de", "fr", "es", "it", "pt", "ja"],
            index=0,
            help="Use auto for non-English RFQs when the source language is unknown.",
            key="cortex_source_language",
        )

    with intake_cols[1]:
        st.markdown("#### RFQ Document / Text")
        input_mode = st.radio(
            "Input Mode",
            ["Upload document", "Paste text"],
            horizontal=True,
            key="cortex_rfq_input_mode",
        )

        uploaded_rfq_file = None
        pasted_rfq_text = ""

        if input_mode == "Upload document":
            uploaded_rfq_file = st.file_uploader(
                "Upload PDF, DOCX, or TXT RFQ",
                type=["pdf", "docx", "txt"],
                key="cortex_rfq_file_upload",
                help="For PDFs, use a searchable PDF. Scanned/image PDFs need OCR or Document AI.",
            )
            if uploaded_rfq_file is not None:
                st.caption(f"Selected file: {uploaded_rfq_file.name}")
            st.text_area(
                "Optional note / fallback RFQ text",
                height=110,
                placeholder="Optional: paste text here only if you also want a text fallback.",
                key="cortex_rfq_optional_text_area",
            )
        else:
            pasted_rfq_text = st.text_area(
                "Paste RFQ text",
                height=220,
                placeholder="Example: Heavy-duty red truck with premium cabin, enhanced terrain package and high-output engine.",
                key="cortex_rfq_text_area",
            )

    note(
        "Use the buttons from left to right. First process the RFQ with Cortex, then run the full RFQ quote pipeline. The pipeline preserves hybrid Cortex BMCS in the cost output.",
        "soft",
    )

    action_cols = st.columns([1, 1])

    with action_cols[0]:
        save_process_clicked = st.button(
            "Save + Process RFQ with Cortex",
            type="primary",
            use_container_width=True,
            key="btn_save_process_cortex_rfq",
        )
    
    with action_cols[1]:
        full_quote_clicked = st.button(
            "Run Full RFQ Quote Pipeline",
            use_container_width=True,
            key="btn_run_full_rfq_quote_pipeline",
        )

    if save_process_clicked:
        try:
            normalized_rfq_id = normalize_id(rfq_id, "RFQ ID")
            normalized_customer_id = normalize_id(rfq_customer_id, "Customer ID")

            if input_mode == "Upload document" and uploaded_rfq_file is None:
                raise ValueError("Please upload an RFQ document or switch to Paste text mode.")
            if input_mode == "Paste text" and not pasted_rfq_text.strip():
                raise ValueError("Please paste RFQ text or switch to Upload document mode.")

            with st.spinner("Uploading RFQ and running Cortex intake pipeline..."):
                upload_result = upload_rfq_file_to_stage(normalized_rfq_id, uploaded_rfq_file)

                source_document_name = upload_result["source_document_name"] or f"{normalized_rfq_id}_manual_text.txt"
                source_document_type = upload_result["source_document_type"] or "TEXT"
                source_text_for_header = pasted_rfq_text.strip() if input_mode == "Paste text" else ""

                upsert_rfq_header_for_cortex(
                    rfq_id=normalized_rfq_id,
                    customer_id=normalized_customer_id,
                    customer_name=rfq_customer_name,
                    source_document_name=source_document_name,
                    source_document_type=source_document_type,
                    source_document_text=source_text_for_header,
                    source_language_code=source_language_code,
                    source_stage_name=upload_result["stage_name"],
                    source_stage_relative_path=upload_result["relative_path"],
                )

                cortex_result = run_cortex_rfq_intake(normalized_rfq_id)

            st.session_state["last_cortex_rfq_id"] = normalized_rfq_id
            st.session_state["last_cortex_result"] = cortex_result

            if cortex_result.get("status") == "SUCCESS":
                note(f"RFQ {normalized_rfq_id} processed successfully with Cortex.", "success")
            else:
                note("Cortex RFQ processing did not return SUCCESS. Review the JSON below.", "warning")

            st.json(cortex_result)

        except Exception as exc:
            st.error(f"Cortex RFQ intake failed: {exc}")
            if "Client Side Encryption" in str(exc) or "SNOWFLAKE_SSE" in str(exc):
                note("Fix the RFQ_DOC_STAGE using server-side encryption: CREATE OR REPLACE STAGE CORE_INPUT.RFQ_DOC_STAGE ENCRYPTION=(TYPE='SNOWFLAKE_SSE') DIRECTORY=(ENABLE=TRUE); then re-upload the file.", "warning")

    selected_rfq_for_actions = st.session_state.get("last_cortex_rfq_id", rfq_id)

    if full_quote_clicked:
        try:
            selected_rfq_for_actions = st.session_state.get("last_cortex_rfq_id", rfq_id)
            normalized_rfq_id = normalize_id(selected_rfq_for_actions, "RFQ ID")
    
            with st.spinner("Running full Cortex RFQ quote pipeline..."):
                quote_result = run_cortex_rfq_quote_pipeline(normalized_rfq_id)
    
            st.session_state["last_cortex_quote_result"] = quote_result
    
            if quote_result.get("status") == "SUCCESS":
                st.session_state["last_simulation_id"] = quote_result.get("simulation_id")
                note(
                    f"Full RFQ quote pipeline completed for {normalized_rfq_id}. "
                    f"Trust status: {quote_result.get('quote_trust_status')}",
                    "success",
                )
            else:
                note("Full RFQ quote pipeline did not return SUCCESS.", "warning")
    
            st.json(quote_result)
    
        except Exception as exc:
            st.error(f"Full RFQ quote pipeline failed: {exc}")

    st.markdown("---")
    section("RFQ Cortex Status", "🧠")

    lookup_cols = st.columns([1.2, 0.8])
    with lookup_cols[0]:
        rfq_lookup_id = st.text_input(
            "View RFQ Status",
            value=st.session_state.get("last_cortex_rfq_id", rfq_id),
            key="cortex_lookup_rfq_id",
        )
    with lookup_cols[1]:
        st.markdown(" ")
        if st.button("Refresh Status", use_container_width=True, key="btn_refresh_rfq_status"):
            soft_rerun()

    try:
        status_df = load_rfq_cortex_status(normalize_id(rfq_lookup_id, "RFQ ID"))

        if status_df.empty:
            note("No RFQ status found yet. Process an RFQ above first.", "soft")
        else:
            r = status_df.iloc[0]

            status_cols = st.columns(5)

            with status_cols[0]:
                kpi_card(
                    "Rule BMCS",
                    f"{as_float(r.get('RULE_BASED_BMCS_SCORE', 0)):.2f}%",
                    "Rule-based score",
                    "rgba(99,230,255,0.22)",
                )

            with status_cols[1]:
                kpi_card(
                    "Cortex BMCS",
                    f"{as_float(r.get('CORTEX_BMCS_SCORE', 0)):.2f}%",
                    "AI_COMPLETE score",
                    "rgba(177,151,252,0.20)",
                )

            with status_cols[2]:
                kpi_card(
                    "Final BMCS",
                    f"{as_float(r.get('BOM_MATCH_CONFIDENCE_SCORE', 0)):.2f}%",
                    str(r.get("FINAL_BMCS_METHOD", "N/A")),
                    "rgba(126,247,196,0.18)",
                )

            with status_cols[3]:
                kpi_card(
                    "Review Status",
                    str(r.get("REVIEW_STATUS", "N/A")),
                    f"Final allowed: {r.get('FINAL_TRUSTED_COST_ALLOWED_FLAG', 'N/A')}",
                    "rgba(255,209,102,0.22)",
                )

            with status_cols[4]:
                kpi_card(
                    "Complexity",
                    str(r.get("RFQ_COMPLEXITY_CATEGORY", "N/A")),
                    "AI_CLASSIFY result",
                    "rgba(255,143,171,0.20)",
                )

            section("Extracted KMAT Configuration", "🧩")
            config_cols = st.columns(4)
            with config_cols[0]:
                config_chip("ENGINE", str(r.get("ENGINE", "N/A")))
            with config_cols[1]:
                config_chip("CAB", str(r.get("CAB", "N/A")))
            with config_cols[2]:
                config_chip("WHEEL", str(r.get("WHEEL", "N/A")))
            with config_cols[3]:
                config_chip("COLOR", str(r.get("COLOR", "N/A")))

            quote_summary_df = load_rfq_quote_summary(normalize_id(rfq_lookup_id, "RFQ ID"))

            if not quote_summary_df.empty:
                q = quote_summary_df.iloc[0]

                section("RFQ Quote Output", "💰")

                quote_cols = st.columns(5)

                with quote_cols[0]:
                    kpi_card(
                        "Baseline Cost",
                        money(q.get("BASELINE_TOTAL_COST_USD", 0)),
                        "Deterministic Layer 1 cost",
                        "rgba(99,230,255,0.22)",
                    )

                with quote_cols[1]:
                    kpi_card(
                        "Risk-Adjusted Cost",
                        money(q.get("RISK_ADJUSTED_TOTAL_COST_USD", 0)),
                        "CSS + FMIS + TDS cost",
                        "rgba(255,143,171,0.20)",
                    )

                with quote_cols[2]:
                    kpi_card(
                        "Risk Uplift",
                        money(q.get("TOTAL_RISK_UPLIFT_USD", 0)),
                        f"{as_float(q.get('TOTAL_RISK_UPLIFT_PCT', 0)):.2f}% above baseline",
                        "rgba(255,209,102,0.22)",
                    )

                with quote_cols[3]:
                    kpi_card(
                        "Quote Trust",
                        str(q.get("QUOTE_TRUST_STATUS", "N/A")),
                        str(q.get("BMCS_REVIEW_STATUS", "N/A")),
                        "rgba(126,247,196,0.18)",
                    )

                with quote_cols[4]:
                    kpi_card(
                        "Final BMCS",
                        f"{as_float(q.get('BOM_MATCH_CONFIDENCE_SCORE', 0)):.2f}%",
                        str(q.get("BMCS_ASSESSMENT_METHOD", "N/A")),
                        "rgba(177,151,252,0.20)",
                    )

                st.dataframe(
                    format_table_money(
                        quote_summary_df,
                        [
                            "BASELINE_TOTAL_COST_USD",
                            "RISK_ADJUSTED_TOTAL_COST_USD",
                            "TOTAL_RISK_UPLIFT_USD",
                        ],
                    ),
                    use_container_width=True,
                    hide_index=True,
                )
            else:
                note("No RFQ quote output found yet. Run the full RFQ quote pipeline.", "soft")

            rfq_detail_tabs = st.tabs([
                "📌 Summary",
                "🧾 Processing Text",
                "🧠 Cortex Reasoning",
                "📊 BMCS Evidence",
                "{} Raw Status",
            ])

            with rfq_detail_tabs[0]:
                st.markdown("#### RFQ Summary")
                st.write(r.get("RFQ_SUMMARY", ""))

                summary_fields = [
                    "RFQ_ID",
                    "CUSTOMER_NAME",
                    "SOURCE_DOCUMENT_NAME",
                    "SOURCE_DOCUMENT_TYPE",
                    "TEXT_EXTRACTION_METHOD",
                    "TRANSLATION_METHOD",
                    "EXTRACTION_METHOD",
                    "RULE_VALIDATION_STATUS",
                ]

                detail_df = vertical_record_table(r.to_dict(), summary_fields)
                
                st.dataframe(
                    detail_df,
                    use_container_width=True,
                    hide_index=True,
                    height=320,
                )

            with rfq_detail_tabs[1]:
                st.markdown("#### English Processing Text")
                processing_text = r.get("PROCESSING_TEXT_EN") or r.get("SOURCE_DOCUMENT_TEXT") or r.get("ORIGINAL_DOCUMENT_TEXT") or ""
                st.text_area(
                    "Processed RFQ Text",
                    value=str(processing_text),
                    height=320,
                    key="rfq_processing_text_display",
                    disabled=True,
                )

            with rfq_detail_tabs[2]:
                st.markdown("#### Cortex Extraction Reasoning")
                st.write(r.get("CORTEX_EXTRACTION_REASONING", ""))

                st.markdown("#### RFQ Complexity Reason")
                st.write(r.get("RFQ_COMPLEXITY_REASON", ""))

                st.markdown("#### Cortex BMCS Reasoning")
                st.write(r.get("CORTEX_BMCS_REASONING", ""))

                st.markdown("#### Cortex BMCS Review Status")
                st.write(r.get("CORTEX_BMCS_REVIEW_STATUS", ""))

                st.markdown("#### Cortex Extraction Scores")
                st.json(r.get("CORTEX_EXTRACTION_SCORES"))

            with rfq_detail_tabs[3]:
                bmcs_detail_df = load_bmcs_scoring_detail_for_rfq(normalize_id(rfq_lookup_id, "RFQ ID"))
                if bmcs_detail_df.empty:
                    note("No BMCS scoring detail found.", "soft")
                else:
                    st.dataframe(bmcs_detail_df, use_container_width=True, hide_index=True)

            with rfq_detail_tabs[4]:
                raw_record = status_df.iloc[0].to_dict()
            
                st.markdown("#### RFQ & Document Details")
                rfq_fields = [
                    "RFQ_ID",
                    "CUSTOMER_ID",
                    "CUSTOMER_NAME",
                    "SOURCE_DOCUMENT_NAME",
                    "SOURCE_DOCUMENT_TYPE",
                    "SOURCE_STAGE_RELATIVE_PATH",
                    "DOCUMENT_STATUS",
                ]
            
                st.dataframe(
                    vertical_record_table(raw_record, rfq_fields),
                    use_container_width=True,
                    hide_index=True,
                    height=300,
                )
            
                st.markdown("#### Cortex Processing Details")
                cortex_fields = [
                    "CORTEX_PROCESSING_STATUS",
                    "TEXT_EXTRACTION_METHOD",
                    "TRANSLATION_METHOD",
                    "RFQ_COMPLEXITY_CATEGORY",
                    "RFQ_COMPLEXITY_REASON",
                    "EXTRACTION_METHOD",
                    "CONFIGURATION_VERSION",
                ]
            
                st.dataframe(
                    vertical_record_table(raw_record, cortex_fields),
                    use_container_width=True,
                    hide_index=True,
                    height=340,
                )
            
                st.markdown("#### Extracted KMAT Configuration")
                config_fields = [
                    "ENGINE",
                    "CAB",
                    "WHEEL",
                    "COLOR",
                ]
            
                st.dataframe(
                    vertical_record_table(raw_record, config_fields),
                    use_container_width=True,
                    hide_index=True,
                    height=220,
                )
            
                st.markdown("#### BMCS / Trust Gate")
                bmcs_fields = [
                    "RULE_BASED_BMCS_SCORE",
                    "CORTEX_BMCS_SCORE",
                    "BOM_MATCH_CONFIDENCE_SCORE",
                    "CORTEX_BMCS_REVIEW_STATUS",
                    "REVIEW_STATUS",
                    "REVIEW_REQUIRED_FLAG",
                    "FINAL_TRUSTED_COST_ALLOWED_FLAG",
                    "FINAL_BMCS_METHOD",
                    "BMCS_RISK_LEVEL",
                    "RULE_VALIDATION_STATUS",
                ]
            
                st.dataframe(
                    vertical_record_table(raw_record, bmcs_fields),
                    use_container_width=True,
                    hide_index=True,
                    height=300,
                )
            
                with st.expander("View complete raw row as JSON"):
                    st.json(raw_record)

            st.download_button(
                "Download RFQ Cortex Status CSV",
                data=dataframe_to_csv_bytes(status_df),
                file_name=f"{normalize_id(rfq_lookup_id, 'RFQ ID')}_cortex_status.csv",
                mime="text/csv",
            )

    except Exception as exc:
        st.error(f"Unable to load RFQ Cortex status: {exc}")
