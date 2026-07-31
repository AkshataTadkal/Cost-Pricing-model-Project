import json
import re
import os
from datetime import datetime, date
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session


# ============================================================
# KMAT Truck Cost Model — Final Governed Streamlit Integration
#
# Preserves the complete Cortex RFQ, BMCS, configuration, risk,
# history, comparison, component-impact, batch-demo, monitoring,
# and verified-outcome workflows.
#
# Financial truth:
# - CORE_INTERNAL.RUN_KMAT_COST_SIMULATION_GOVERNED_V3 remains
#   the deterministic governed simulation entry point.
# - The UI never activates a model deployment or enables runtime
#   authority.
# - Candidate runtime use is available only through the secure
#   Phase 13B resolver and only when the database control plane
#   reports an open path with complete inference metadata.
#
# Security and governance display:
# - Phase 13A runtime authority, domain switches and decisions.
# - Phase 13B grant compliance, policy seals and secure identity.
# - Corrected approved-override precedence through the V2 view.
# ============================================================

DB_NAME = "KMAT_COST_MODEL_DB"
KMAT_ID = "KMAT_TRUCK_01"

SECURE_ACTIVATION_ENTRY_POINT = (
    f"{DB_NAME}.CORE_ML."
    "ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1"
)
SECURE_RUNTIME_RESOLVER = (
    f"{DB_NAME}.CORE_ML."
    "RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1"
)
SECURE_OVERRIDE_SUBMIT = (
    f"{DB_NAME}.CORE_ML."
    "SUBMIT_ML_DECISION_OVERRIDE_V2"
)
SECURE_OVERRIDE_REVIEW = (
    f"{DB_NAME}.CORE_ML."
    "REVIEW_ML_DECISION_OVERRIDE_V2"
)

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


def is_missing(value) -> bool:
    if value is None:
        return True
    try:
        return bool(pd.isna(value))
    except Exception:
        return False


def optional_rate(value) -> str:
    if is_missing(value):
        return "—"
    return f"{as_float(value) * 100.0:.2f}%"


def optional_multiplier(value, decimals: int = 4) -> str:
    if is_missing(value):
        return "—"
    return f"{as_float(value):.{decimals}f}x"


def optional_score(value) -> str:
    if is_missing(value):
        return "—"
    return f"{as_float(value):.2f}"


def yes_no(value) -> str:
    return "Yes" if bool(value) else "No"


def parse_procedure_result(raw_result) -> Dict:
    if raw_result is None:
        return {}

    if isinstance(raw_result, dict):
        return raw_result

    if hasattr(raw_result, "as_dict"):
        try:
            return raw_result.as_dict()
        except Exception:
            pass

    try:
        return json.loads(raw_result)
    except Exception:
        pass

    try:
        return json.loads(str(raw_result))
    except Exception:
        return {
            "status": "UNKNOWN",
            "raw_result": str(raw_result),
        }


def money(value) -> str:
    return f"${as_float(value):,.2f}"


def pct(value) -> str:
    return f"{as_float(value):,.2f}%"


def utc_stamp() -> str:
    return datetime.utcnow().strftime("%Y%m%d_%H%M%S")


def optional_text(value, fallback: str = "—") -> str:
    if is_missing(value):
        return fallback
    cleaned = str(value).strip()
    return cleaned if cleaned else fallback


def first_present(
    row: pd.Series,
    keys: List[str],
) -> Tuple[Optional[str], Any]:
    for key in keys:
        if key in row.index and not is_missing(row.get(key)):
            return key, row.get(key)
    return None, None


def make_runtime_decision_id(
    model_domain: str,
    simulation_id: str,
) -> str:
    raw_id = (
        f"RT_{model_domain}_{simulation_id}_{utc_stamp()}"
        .upper()
    )
    cleaned = re.sub(r"[^A-Z0-9_-]+", "_", raw_id)
    return cleaned[:60]


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
    """
    Run the deterministic governed cost flow.

    This is intentionally not replaced by a deployment activation
    procedure. Model activation and deterministic cost simulation are
    different responsibilities.
    """
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION_GOVERNED_V3(
            {sql_literal(simulation_id)}
        )
    """)
    raw_result = rows[0][0] if rows else None
    return parse_procedure_result(raw_result)


@st.cache_data(ttl=30)
def load_session_identity() -> Dict[str, Any]:
    df = query_df("""
        SELECT
            CURRENT_USER()::VARCHAR
                AS ACTUAL_USER,
            CURRENT_ROLE()::VARCHAR
                AS ACTIVE_ROLE,
            CURRENT_WAREHOUSE()::VARCHAR
                AS ACTIVE_WAREHOUSE,
            CURRENT_DATABASE()::VARCHAR
                AS ACTIVE_DATABASE,
            CURRENT_SCHEMA()::VARCHAR
                AS ACTIVE_SCHEMA,
            CURRENT_SESSION()::NUMBER
                AS SESSION_ID
    """)

    if df.empty:
        return {}

    return df.iloc[0].to_dict()


@st.cache_data(ttl=30)
def load_runtime_authority_dashboard() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1
        ORDER BY MODEL_DOMAIN
    """)


@st.cache_data(ttl=30)
def load_security_control_dashboard() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1
    """)


@st.cache_data(ttl=30)
def load_policy_seal_integrity() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1
        ORDER BY MODEL_DOMAIN
    """)


def load_streamlit_runtime_inputs(
    simulation_id: str,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
        WHERE SIMULATION_ID =
              {sql_literal(simulation_id)}
        ORDER BY MODEL_DOMAIN
    """)


def load_runtime_decisions(
    simulation_id: str,
    limit: int = 100,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            RUNTIME_DECISION_ID,
            RUNTIME_AUTHORITY_ID,
            MODEL_DOMAIN,
            AUTHORITY_MODE,

            POLICY_ID,
            POLICY_VERSION,

            SIMULATION_ID,
            RULE_VALUE,
            CANDIDATE_VALUE,
            FINAL_RUNTIME_VALUE,

            GLOBAL_SWITCH_OPEN_FLAG,
            DOMAIN_SWITCH_OPEN_FLAG,
            AUTHORITY_ENABLED_FLAG,
            REQUEST_FRESH_FLAG,
            POLICY_MATCH_FLAG,
            POLICY_FINGERPRINT_MATCH_FLAG,
            PRODUCTION_EXIT_GATE_PASS_FLAG,

            QUALITY_PASS_FLAG,
            OOD_FLAG,
            OVERALL_GUARDRAIL_PASS_FLAG,
            ENGINEER_APPROVED_FLAG,
            CAPACITY_RESERVED_FLAG,

            RUNTIME_AUTHORISED_FLAG,
            OFFICIAL_COST_IMPACT_AUTHORISED_FLAG,
            BUSINESS_DECISION_AUTHORISED_FLAG,

            FINAL_RUNTIME_SOURCE,
            DECISION_STATUS,
            DECISION_REASON,

            REQUESTED_BY,
            DECIDED_AT
        FROM {DB_NAME}.CORE_ML
            .VW_ML_RUNTIME_DECISION_CURRENT_V1
        WHERE SIMULATION_ID =
              {sql_literal(simulation_id)}
        ORDER BY DECIDED_AT DESC
        LIMIT {int(limit)}
    """)


def load_approved_override_display(
    simulation_id: str,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2
        WHERE SIMULATION_ID =
              {sql_literal(simulation_id)}
        ORDER BY MODEL_DOMAIN
    """)


def resolve_secure_runtime_authority(
    runtime_decision_id: str,
    model_domain: str,
    simulation_id: str,

    rule_value,
    candidate_value,

    quality_pass_flag: bool,
    ood_flag: bool,

    engineer_approved_flag: bool,
    engineer_approval_reference: Optional[str],
) -> Dict:
    """
    Call the Phase 13B secure runtime resolver.

    The procedure captures CURRENT_USER() inside Snowflake. This UI does
    not pass a caller-controlled actor name.
    """
    runtime_decision_id = normalize_id(
        runtime_decision_id,
        "Runtime decision ID",
    )
    model_domain = str(model_domain or "").strip().upper()
    if model_domain not in {"CSS", "FMIS", "TDS", "BMCS"}:
        raise ValueError("Model domain must be CSS, FMIS, TDS, or BMCS.")

    simulation_id = normalize_id(
        simulation_id,
        "Simulation ID",
    )

    def numeric_sql(value) -> str:
        if is_missing(value):
            return "NULL"
        return str(float(value))

    rows = run_sql(f"""
        CALL {SECURE_RUNTIME_RESOLVER}(
            {sql_literal(runtime_decision_id)},
            {sql_literal(model_domain)},
            {sql_literal(simulation_id)},

            {numeric_sql(rule_value)},
            {numeric_sql(candidate_value)},

            {"TRUE" if bool(quality_pass_flag) else "FALSE"},
            {"TRUE" if bool(ood_flag) else "FALSE"},

            {"TRUE" if bool(engineer_approved_flag) else "FALSE"},
            {sql_literal(engineer_approval_reference)}
        )
    """)

    raw_result = rows[0][0] if rows else None
    return parse_procedure_result(raw_result)


def extract_runtime_input(
    governed_row: pd.Series,
    model_domain: str,
) -> Dict[str, Any]:
    """
    Read runtime inputs already produced by the governed decision view.

    Candidate execution is disabled when required quality/OOD metadata is
    unavailable. The UI never invents those safety flags.
    """
    domain = str(model_domain or "").strip().upper()

    input_map = {
        "CSS": {
            "rule": ["CSS_RULE_VALUE"],
            "candidate": [
                "CSS_ML_VALUE",
                "CSS_RECOMMENDED_ML_VALUE",
            ],
            "quality": [
                "CSS_FEATURE_QUALITY_PASS_FLAG",
                "CSS_QUALITY_PASS_FLAG",
            ],
            "ood": [
                "CSS_MODEL_OOD_FLAG",
                "CSS_OOD_FLAG",
            ],
        },
        "FMIS": {
            "rule": ["FMIS_RULE_VALUE"],
            "candidate": [
                "FMIS_ML_VALUE",
                "FMIS_RECOMMENDED_ML_VALUE",
            ],
            "quality": [
                "FMIS_FEATURE_QUALITY_PASS_FLAG",
                "FMIS_QUALITY_PASS_FLAG",
            ],
            "ood": [
                "FMIS_MODEL_OOD_FLAG",
                "FMIS_OOD_FLAG",
            ],
        },
        "TDS": {
            "rule": ["TDS_RULE_VALUE"],
            "candidate": [
                "TDS_ML_VALUE",
                "TDS_RECOMMENDED_ML_VALUE",
            ],
            "quality": [
                "TDS_FEATURE_QUALITY_PASS_FLAG",
                "TDS_QUALITY_PASS_FLAG",
            ],
            "ood": [
                "TDS_MODEL_OOD_FLAG",
                "TDS_OOD_FLAG",
            ],
        },
        "BMCS": {
            "rule": [
                "BMCS_RULE_PROBABILITY",
                "BMCS_RULE_VALUE",
            ],
            "candidate": [
                "BMCS_ML_PROBABILITY",
                "BMCS_RAW_ML_VALUE",
            ],
            "quality": [
                "BMCS_FEATURE_QUALITY_PASS_FLAG",
                "BMCS_QUALITY_PASS_FLAG",
            ],
            "ood": [
                "BMCS_MODEL_OOD_FLAG",
                "BMCS_OOD_FLAG",
            ],
        },
    }

    if domain not in input_map:
        return {
            "ready": False,
            "reason": "Unsupported model domain.",
        }

    keys = input_map[domain]
    rule_key, rule_value = first_present(
        governed_row,
        keys["rule"],
    )
    candidate_key, candidate_value = first_present(
        governed_row,
        keys["candidate"],
    )
    quality_key, quality_value = first_present(
        governed_row,
        keys["quality"],
    )
    ood_key, ood_value = first_present(
        governed_row,
        keys["ood"],
    )

    missing_fields = []
    if candidate_key is None:
        missing_fields.append("candidate value")
    if quality_key is None:
        missing_fields.append("quality flag")
    if ood_key is None:
        missing_fields.append("OOD flag")
    if domain != "BMCS" and rule_key is None:
        missing_fields.append("rule value")

    return {
        "ready": len(missing_fields) == 0,
        "reason": (
            ""
            if not missing_fields
            else "Missing " + ", ".join(missing_fields) + "."
        ),
        "rule_key": rule_key,
        "rule_value": rule_value,
        "candidate_key": candidate_key,
        "candidate_value": candidate_value,
        "quality_key": quality_key,
        "quality_pass_flag": (
            bool(quality_value)
            if quality_key is not None
            else False
        ),
        "ood_key": ood_key,
        "ood_flag": (
            bool(ood_value)
            if ood_key is not None
            else True
        ),
        "inference_success_flag": False,
        "source": "PHASE10C_FALLBACK",
    }


def extract_runtime_input_from_secure_view(
    runtime_input_df: pd.DataFrame,
    model_domain: str,
    governed_row: pd.Series,
) -> Dict[str, Any]:
    domain = str(model_domain or "").strip().upper()

    if (
        not runtime_input_df.empty
        and "MODEL_DOMAIN" in runtime_input_df.columns
    ):
        matched = runtime_input_df[
            runtime_input_df[
                "MODEL_DOMAIN"
            ].astype(str).str.upper()
            == domain
        ]

        if not matched.empty:
            row = matched.iloc[0]

            return {
                "ready": bool(
                    row.get(
                        "RUNTIME_INPUT_READY_FLAG",
                        False,
                    )
                ),
                "reason": optional_text(
                    row.get(
                        "RUNTIME_INPUT_STATUS"
                    ),
                    "RUNTIME_INPUT_NOT_READY",
                ),
                "decision_id": row.get("DECISION_ID"),
                "rule_key": "RUNTIME_RULE_VALUE",
                "rule_value": row.get(
                    "RUNTIME_RULE_VALUE"
                ),
                "candidate_key": (
                    "RUNTIME_CANDIDATE_VALUE"
                ),
                "candidate_value": row.get(
                    "RUNTIME_CANDIDATE_VALUE"
                ),
                "quality_key": (
                    "FEATURE_QUALITY_PASS_FLAG"
                ),
                "quality_pass_flag": bool(
                    row.get(
                        "FEATURE_QUALITY_PASS_FLAG",
                        False,
                    )
                ),
                "ood_key": "MODEL_OOD_FLAG",
                "ood_flag": bool(
                    row.get(
                        "MODEL_OOD_FLAG",
                        True,
                    )
                ),
                "inference_success_flag": bool(
                    row.get(
                        "MODEL_INFERENCE_SUCCESS_FLAG",
                        False,
                    )
                ),
                "source": (
                    "VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1"
                ),
            }

    fallback = extract_runtime_input(
        governed_row,
        domain,
    )
    fallback["reason"] = (
        "Secure runtime-input view unavailable or returned no "
        "latest decision row. "
        + fallback.get("reason", "")
    ).strip()
    return fallback


def prepare_governance_for_existing_simulation(
    simulation_id: str,
) -> Dict:
    """
    Attach Phase 10A and Phase 10B governance to an already-computed
    simulation, such as an RFQ quote result.

    This does not rerun the deterministic cost engine and therefore does
    not overwrite the RFQ pipeline's final BMCS trust patch.
    """
    phase10a_rows = run_sql(f"""
        CALL {DB_NAME}.CORE_ML.PREPARE_KMAT_GOVERNED_COST_INPUT_V2(
            {sql_literal(simulation_id)}
        )
    """)
    phase10a_raw = phase10a_rows[0][0] if phase10a_rows else None
    phase10a_result = parse_procedure_result(phase10a_raw)

    if phase10a_result.get("status") != "SUCCESS":
        return {
            "status": "ERROR",
            "phase": "PHASE_10C",
            "message": "Phase 10A governance preparation failed.",
            "simulation_id": simulation_id,
            "phase10a_result": phase10a_result,
        }

    phase10b_rows = run_sql(f"""
        CALL {DB_NAME}.CORE_ML.RESOLVE_KMAT_COST_FACTOR_HIERARCHY_V1(
            {sql_literal(simulation_id)}
        )
    """)
    phase10b_raw = phase10b_rows[0][0] if phase10b_rows else None
    phase10b_result = parse_procedure_result(phase10b_raw)

    return {
        "status": (
            "SUCCESS"
            if phase10b_result.get("status") == "SUCCESS"
            else "ERROR"
        ),
        "phase": "PHASE_10C",
        "simulation_id": simulation_id,
        "phase10a_result": phase10a_result,
        "phase10b_result": phase10b_result,
    }


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


def load_phase10c_decision_display(
    simulation_id: str,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML.VW_KMAT_PHASE10C_DECISION_DISPLAY_V1
        WHERE SIMULATION_ID = {sql_literal(simulation_id)}
    """)


def load_phase10c_audit(
    simulation_id: str,
    limit: int = 50,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT
            PHASE_NAME,
            AUDIT_EVENT_ID,
            AUDIT_EVENT_TYPE,
            EVENT_STATUS,
            EVENT_REASON,

            FINAL_SCRAP_RATE,
            FINAL_FMIS_MULTIPLIER,
            FINAL_TDS_FACTOR,
            FINAL_BMCS_STATUS,

            SAFETY_GATE_PASS_FLAG,
            COST_ENGINE_CONSUMPTION_ALLOWED_FLAG,

            EVENT_ACTOR,
            EVENT_AT
        FROM (
            SELECT
                'PHASE_10A' AS PHASE_NAME,
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,
                INTEGRATION_STATUS AS EVENT_STATUS,
                INTEGRATION_REASON AS EVENT_REASON,

                FINAL_SCRAP_RATE::FLOAT
                    AS FINAL_SCRAP_RATE,
                FINAL_FMIS_MULTIPLIER::FLOAT
                    AS FINAL_FMIS_MULTIPLIER,
                FINAL_TDS_FACTOR::FLOAT
                    AS FINAL_TDS_FACTOR,
                BMCS_SHADOW_COMPARISON_STATUS
                    AS FINAL_BMCS_STATUS,

                SAFETY_GATE_PASS_FLAG,
                COST_ENGINE_CONSUMPTION_ALLOWED_FLAG,

                AUDITED_BY AS EVENT_ACTOR,
                AUDITED_AT AS EVENT_AT
            FROM {DB_NAME}.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2
            WHERE SIMULATION_ID = {sql_literal(simulation_id)}

            UNION ALL

            SELECT
                'PHASE_10B' AS PHASE_NAME,
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,
                RESOLUTION_STATUS AS EVENT_STATUS,
                RESOLUTION_REASON AS EVENT_REASON,

                RESOLVED_SCRAP_RATE::FLOAT
                    AS FINAL_SCRAP_RATE,
                RESOLVED_FMIS_MULTIPLIER::FLOAT
                    AS FINAL_FMIS_MULTIPLIER,
                RESOLVED_TDS_FACTOR::FLOAT
                    AS FINAL_TDS_FACTOR,
                RESOLVED_BMCS_STATUS
                    AS FINAL_BMCS_STATUS,

                SAFETY_GATE_PASS_FLAG,
                COST_ENGINE_CONSUMPTION_ALLOWED_FLAG,

                AUDITED_BY AS EVENT_ACTOR,
                AUDITED_AT AS EVENT_AT
            FROM {DB_NAME}.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1
            WHERE SIMULATION_ID = {sql_literal(simulation_id)}
        )
        ORDER BY EVENT_AT DESC
        LIMIT {int(limit)}
    """)


def build_governed_factor_table(row: pd.Series) -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "Factor": "CSS Scrap Rate",
                "Rule / Official": optional_rate(
                    row.get("CSS_RULE_VALUE")
                ),
                "ML Advisory": optional_rate(
                    row.get("CSS_ML_VALUE")
                ),
                "Approved Override": optional_rate(
                    row.get("CSS_OVERRIDE_VALUE")
                ),
                "Safe Default": optional_rate(
                    row.get("CSS_SAFE_DEFAULT_VALUE")
                ),
                "Final Governed": optional_rate(
                    row.get("RESOLVED_SCRAP_RATE")
                ),
                "Final Source": str(
                    row.get("CSS_RESOLVED_SOURCE", "N/A")
                ),
                "ML Eligible": yes_no(
                    row.get("CSS_ML_ELIGIBLE_FLAG", False)
                ),
                "Override Eligible": yes_no(
                    row.get(
                        "CSS_OVERRIDE_ELIGIBLE_FLAG",
                        False,
                    )
                ),
            },
            {
                "Factor": "FMIS Material Multiplier",
                "Rule / Official": optional_multiplier(
                    row.get("FMIS_RULE_VALUE")
                ),
                "ML Advisory": optional_multiplier(
                    row.get("FMIS_ML_VALUE")
                ),
                "Approved Override": optional_multiplier(
                    row.get("FMIS_OVERRIDE_VALUE")
                ),
                "Safe Default": optional_multiplier(
                    row.get("FMIS_SAFE_DEFAULT_VALUE")
                ),
                "Final Governed": optional_multiplier(
                    row.get("RESOLVED_FMIS_MULTIPLIER")
                ),
                "Final Source": str(
                    row.get("FMIS_RESOLVED_SOURCE", "N/A")
                ),
                "ML Eligible": yes_no(
                    row.get("FMIS_ML_ELIGIBLE_FLAG", False)
                ),
                "Override Eligible": yes_no(
                    row.get(
                        "FMIS_OVERRIDE_ELIGIBLE_FLAG",
                        False,
                    )
                ),
            },
            {
                "Factor": "TDS Tooling Factor",
                "Rule / Official": optional_multiplier(
                    row.get("TDS_RULE_VALUE"),
                    2,
                ),
                "ML Advisory": optional_multiplier(
                    row.get("TDS_ML_VALUE"),
                    2,
                ),
                "Approved Override": optional_multiplier(
                    row.get("TDS_OVERRIDE_VALUE"),
                    2,
                ),
                "Safe Default": optional_multiplier(
                    row.get("TDS_SAFE_DEFAULT_VALUE"),
                    2,
                ),
                "Final Governed": optional_multiplier(
                    row.get("RESOLVED_TDS_FACTOR"),
                    2,
                ),
                "Final Source": str(
                    row.get("TDS_RESOLVED_SOURCE", "N/A")
                ),
                "ML Eligible": yes_no(
                    row.get("TDS_ML_ELIGIBLE_FLAG", False)
                ),
                "Override Eligible": yes_no(
                    row.get(
                        "TDS_OVERRIDE_ELIGIBLE_FLAG",
                        False,
                    )
                ),
            },
        ]
    )


def build_model_lineage_table(row: pd.Series) -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "Domain": "CSS",
                "Deployment Mode": row.get(
                    "CSS_DEPLOYMENT_MODE",
                    "N/A",
                ),
                "Policy Version": row.get(
                    "CSS_POLICY_VERSION",
                    "N/A",
                ),
                "Model Name": row.get(
                    "CSS_MODEL_NAME",
                    "N/A",
                ),
                "Model Version": row.get(
                    "CSS_MODEL_VERSION",
                    "N/A",
                ),
                "Feature Set": row.get(
                    "CSS_FEATURE_SET_VERSION",
                    "N/A",
                ),
            },
            {
                "Domain": "FMIS",
                "Deployment Mode": row.get(
                    "FMIS_DEPLOYMENT_MODE",
                    "N/A",
                ),
                "Policy Version": row.get(
                    "FMIS_POLICY_VERSION",
                    "N/A",
                ),
                "Model Name": row.get(
                    "FMIS_MODEL_NAME",
                    "N/A",
                ),
                "Model Version": row.get(
                    "FMIS_MODEL_VERSION",
                    "N/A",
                ),
                "Feature Set": row.get(
                    "FMIS_FEATURE_SET_VERSION",
                    "N/A",
                ),
            },
            {
                "Domain": "TDS",
                "Deployment Mode": row.get(
                    "TDS_DEPLOYMENT_MODE",
                    "N/A",
                ),
                "Policy Version": row.get(
                    "TDS_POLICY_VERSION",
                    "N/A",
                ),
                "Model Name": row.get(
                    "TDS_MODEL_NAME",
                    "N/A",
                ),
                "Model Version": row.get(
                    "TDS_MODEL_VERSION",
                    "N/A",
                ),
                "Feature Set": row.get(
                    "TDS_FEATURE_SET_VERSION",
                    "N/A",
                ),
            },
            {
                "Domain": "BMCS",
                "Deployment Mode": row.get(
                    "BMCS_DEPLOYMENT_MODE",
                    "N/A",
                ),
                "Policy Version": row.get(
                    "BMCS_POLICY_VERSION",
                    "N/A",
                ),
                "Model Name": row.get(
                    "BMCS_MODEL_NAME",
                    "N/A",
                ),
                "Model Version": row.get(
                    "BMCS_MODEL_VERSION",
                    "N/A",
                ),
                "Feature Set": row.get(
                    "BMCS_FEATURE_SET_VERSION",
                    "N/A",
                ),
            },
        ]
    )


def record_model_actual_outcome(
    outcome_id: str,
    simulation_id: str,
    model_domain: str,
    outcome_date,
    actual_numeric_value,
    actual_text_status: str,
    actual_mapping_correct_flag,
    outcome_source: str,
    evidence_reference: str,
    notes: str,
    recorded_by: str,
) -> Dict:
    numeric_sql = (
        "NULL"
        if actual_numeric_value is None
        else str(float(actual_numeric_value))
    )
    mapping_sql = (
        "NULL"
        if actual_mapping_correct_flag is None
        else (
            "TRUE"
            if bool(actual_mapping_correct_flag)
            else "FALSE"
        )
    )

    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_ML
            .RECORD_KMAT_MODEL_ACTUAL_OUTCOME_V1(
                {sql_literal(outcome_id)},
                {sql_literal(simulation_id)},
                {sql_literal(model_domain)},
                {sql_literal(str(outcome_date))}::DATE,

                {numeric_sql},
                {sql_literal(actual_text_status)},
                {mapping_sql},

                {sql_literal(outcome_source)},
                {sql_literal(evidence_reference)},
                {sql_literal(notes)},
                {sql_literal(recorded_by)}
            )
    """)

    raw_result = rows[0][0] if rows else None
    return parse_procedure_result(raw_result)


def record_cost_actual_outcome(
    cost_outcome_id: str,
    simulation_id: str,
    outcome_date,
    actual_material_cost,
    actual_labor_cost,
    actual_machine_cost,
    actual_overhead_cost,
    actual_total_cost,
    actual_final_price,
    outcome_source: str,
    evidence_reference: str,
    notes: str,
    recorded_by: str,
) -> Dict:
    def optional_number(value) -> str:
        if value is None:
            return "NULL"
        return str(float(value))

    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_ML
            .RECORD_KMAT_COST_ACTUAL_OUTCOME_V1(
                {sql_literal(cost_outcome_id)},
                {sql_literal(simulation_id)},
                {sql_literal(str(outcome_date))}::DATE,

                {optional_number(actual_material_cost)},
                {optional_number(actual_labor_cost)},
                {optional_number(actual_machine_cost)},
                {optional_number(actual_overhead_cost)},

                {optional_number(actual_total_cost)},
                {optional_number(actual_final_price)},

                {sql_literal(outcome_source)},
                {sql_literal(evidence_reference)},
                {sql_literal(notes)},
                {sql_literal(recorded_by)}
            )
    """)

    raw_result = rows[0][0] if rows else None
    return parse_procedure_result(raw_result)


def run_phase11a_monitoring(
    monitoring_run_id: str,
    run_by: str,
) -> Dict:
    rows = run_sql(f"""
        CALL {DB_NAME}.CORE_ML.RUN_KMAT_MONITORING_V1(
            {sql_literal(monitoring_run_id)},
            {sql_literal(run_by)}
        )
    """)
    raw_result = rows[0][0] if rows else None
    return parse_procedure_result(raw_result)


def load_phase11a_dashboard() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_PHASE11A_MONITORING_DASHBOARD_V1
        ORDER BY
            CASE ALERT_STATUS
                WHEN 'CRITICAL' THEN 1
                WHEN 'WARNING' THEN 2
                WHEN 'NO_DATA' THEN 3
                WHEN 'INSUFFICIENT_DATA' THEN 4
                WHEN 'HEALTHY' THEN 5
                ELSE 6
            END,
            MODEL_DOMAIN,
            METRIC_KEY
    """)


def load_phase11a_domain_summary() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
        ORDER BY MODEL_DOMAIN
    """)


def load_phase11a_operational_summary() -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1
    """)


def load_phase11a_model_feedback(
    simulation_id: str,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
        WHERE SIMULATION_ID = {sql_literal(simulation_id)}
        ORDER BY MODEL_DOMAIN
    """)


def load_phase11a_cost_feedback(
    simulation_id: str,
) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML
            .VW_KMAT_COST_FEEDBACK_DETAIL_V1
        WHERE SIMULATION_ID = {sql_literal(simulation_id)}
    """)


def load_phase11a_runs(limit: int = 50) -> pd.DataFrame:
    return query_df(f"""
        SELECT *
        FROM {DB_NAME}.CORE_ML.KMAT_MONITORING_RUN_V1
        ORDER BY COMPLETED_AT DESC
        LIMIT {int(limit)}
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
            BOM_MATCH_CONFIDENCE_SCORE,
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
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
    score_result = run_bmcs_scoring(rfq_id)
    if score_result.get("status") != "SUCCESS":
        return {"status": "ERROR", "stage": "BMCS_SCORING", "detail": score_result}

    prepare_result = prepare_rfq_simulation_inputs(rfq_id)
    if prepare_result.get("status") != "SUCCESS":
        return {"status": "ERROR", "stage": "PREPARE_RFQ_INPUTS", "detail": prepare_result}

    simulation_id = prepare_result.get("simulation_id")
    cost_result = run_kmat_engine(simulation_id)
    return {
        "status": cost_result.get("status", "UNKNOWN"),
        "stage": "COMPLETE",
        "rfq_id": rfq_id,
        "simulation_id": simulation_id,
        "bmcs_result": score_result,
        "prepare_result": prepare_result,
        "cost_result": cost_result,
    }


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
            padding: 18px 18px;
            border-radius: 22px;
            border: 1px solid rgba(255,255,255,0.16);
            background:
                linear-gradient(145deg, rgba(255,255,255,0.13), rgba(255,255,255,0.055)),
                radial-gradient(circle at 94% 12%, var(--kpi-glow, rgba(99,230,255,0.18)), transparent 34%);
            box-shadow: 0 14px 38px rgba(0,0,0,0.24);
            min-height: 138px;
        }

        .kpi-label {
            color: var(--text-faint);
            font-size: 0.78rem;
            font-weight: 800;
            letter-spacing: 0.08em;
            text-transform: uppercase;
        }

        .kpi-value {
            color: #ffffff;
            font-size: 1.8rem;
            font-weight: 900;
            letter-spacing: -0.035em;
            margin-top: 8px;
            word-break: break-word;
        }

        .kpi-note {
            color: var(--text-soft);
            font-size: 0.86rem;
            margin-top: 8px;
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
            padding: 14px 16px;
            border-radius: 18px;
            border: 1px solid rgba(255,255,255,0.15);
            background: rgba(255,255,255,0.07);
        }
        .config-chip .label {
            color: var(--text-faint);
            font-size: 0.74rem;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            font-weight: 800;
        }
        .config-chip .value {
            color: #ffffff;
            font-size: 1.35rem;
            font-weight: 900;
            margin-top: 5px;
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



def inject_consistent_glass_overrides():
    """Final visual-system pass only. Does not change app logic, SQL, or calculations."""
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap');

        :root {
            --ui-bg: #07111f;
            --ui-panel: rgba(255,255,255,0.072);
            --ui-panel-2: rgba(255,255,255,0.045);
            --ui-border: rgba(255,255,255,0.118);
            --ui-border-strong: rgba(125,211,252,0.24);
            --ui-text: #edf6ff;
            --ui-muted: rgba(237,246,255,0.66);
            --ui-faint: rgba(237,246,255,0.48);
            --ui-accent: #7dd3fc;
            --ui-accent-2: #a78bfa;
            --ui-success: #86efac;
            --ui-warning: #fcd34d;
            --ui-danger: #fb7185;
        }

        html, body, .stApp, [data-testid="stAppViewContainer"] {
            font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
            color: var(--ui-text) !important;
        }

        .stApp, [data-testid="stAppViewContainer"] {
            background:
                radial-gradient(circle at 7% 9%, rgba(125,211,252,0.16) 0, transparent 30%),
                radial-gradient(circle at 92% 8%, rgba(167,139,250,0.14) 0, transparent 28%),
                radial-gradient(circle at 70% 95%, rgba(134,239,172,0.07) 0, transparent 32%),
                linear-gradient(145deg, #06101e 0%, #0a1526 50%, #0f172a 100%) !important;
        }

        [data-testid="stHeader"] { background: transparent !important; }
        #MainMenu, footer { visibility: hidden !important; }

        .block-container {
            max-width: 1480px !important;
            padding-top: 1.35rem !important;
            padding-bottom: 3rem !important;
        }

        /* Sidebar: formal, quiet, consistent */
        section[data-testid="stSidebar"], [data-testid="stSidebar"] {
            background: linear-gradient(180deg, rgba(8,16,30,0.98), rgba(10,21,38,0.96)) !important;
            border-right: 1px solid rgba(255,255,255,0.105) !important;
            box-shadow: 16px 0 42px rgba(0,0,0,0.20) !important;
        }
        section[data-testid="stSidebar"] .block-container {
            padding: 1.35rem 1rem 2rem 1rem !important;
        }
        section[data-testid="stSidebar"] h3,
        section[data-testid="stSidebar"] h4,
        section[data-testid="stSidebar"] p,
        section[data-testid="stSidebar"] label,
        section[data-testid="stSidebar"] span {
            color: rgba(237,246,255,0.86) !important;
        }

        /* Hero: compact professional glass, not loud */
        .glass-hero {
            padding: 28px 32px !important;
            border-radius: 24px !important;
            border: 1px solid var(--ui-border) !important;
            background:
                linear-gradient(135deg, rgba(255,255,255,0.095), rgba(255,255,255,0.042)),
                radial-gradient(circle at 96% 12%, rgba(125,211,252,0.16), transparent 34%) !important;
            box-shadow: 0 22px 58px rgba(0,0,0,0.30), inset 0 1px 0 rgba(255,255,255,0.10) !important;
            backdrop-filter: blur(18px) !important;
            margin-bottom: 1.35rem !important;
        }
        .glass-hero:after { opacity: 0.35 !important; }
        .hero-eyebrow {
            color: #dff7ff !important;
            background: rgba(125,211,252,0.105) !important;
            border: 1px solid rgba(125,211,252,0.22) !important;
            border-radius: 999px !important;
            padding: 7px 12px !important;
            font-size: 0.74rem !important;
            letter-spacing: 0.075em !important;
        }
        .hero-title {
            color: #f8fbff !important;
            font-size: clamp(2.05rem, 3.4vw, 3.35rem) !important;
            line-height: 1.02 !important;
            letter-spacing: -0.052em !important;
            font-weight: 850 !important;
        }
        .hero-subtitle {
            color: var(--ui-muted) !important;
            font-size: 0.98rem !important;
            max-width: 1020px !important;
        }
        .hero-pills { gap: 8px !important; margin-top: 16px !important; }
        .pill {
            background: rgba(255,255,255,0.055) !important;
            border: 1px solid rgba(255,255,255,0.105) !important;
            color: rgba(237,246,255,0.82) !important;
            padding: 7px 11px !important;
            font-size: 0.78rem !important;
            font-weight: 650 !important;
        }

        /* Tabs: remove the odd rectangle; use clean glass pills */
        .stTabs [data-baseweb="tab-list"],
        div[data-baseweb="tab-list"] {
            background: transparent !important;
            border: 0 !important;
            box-shadow: none !important;
            padding: 0 2px 14px 2px !important;
            margin: 0 0 12px 0 !important;
            gap: 7px !important;
            align-items: center !important;
            overflow-x: auto !important;
            scrollbar-width: thin !important;
        }
        .stTabs [data-baseweb="tab-list"]::before,
        .stTabs [data-baseweb="tab-list"]::after,
        div[data-baseweb="tab-list"]::before,
        div[data-baseweb="tab-list"]::after {
            display: none !important;
            content: none !important;
        }
        .stTabs [data-baseweb="tab"],
        button[data-baseweb="tab"] {
            min-height: 38px !important;
            height: 38px !important;
            border-radius: 999px !important;
            padding: 0 13px !important;
            margin: 0 !important;
            background: rgba(255,255,255,0.045) !important;
            border: 1px solid rgba(255,255,255,0.095) !important;
            color: rgba(237,246,255,0.70) !important;
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.045) !important;
            transition: background 160ms ease, border-color 160ms ease, color 160ms ease, box-shadow 160ms ease !important;
            white-space: nowrap !important;
        }
        .stTabs [data-baseweb="tab"]:hover,
        button[data-baseweb="tab"]:hover {
            color: rgba(248,251,255,0.92) !important;
            background: rgba(255,255,255,0.070) !important;
            border-color: rgba(125,211,252,0.20) !important;
        }
        .stTabs [data-baseweb="tab"] p,
        button[data-baseweb="tab"] p {
            color: inherit !important;
            font-size: 0.88rem !important;
            font-weight: 700 !important;
            line-height: 1 !important;
            margin: 0 !important;
        }
        .stTabs [aria-selected="true"],
        button[data-baseweb="tab"][aria-selected="true"] {
            color: #f8fbff !important;
            background: linear-gradient(135deg, rgba(125,211,252,0.18), rgba(167,139,250,0.14)) !important;
            border: 1px solid rgba(125,211,252,0.30) !important;
            box-shadow: 0 10px 24px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.11) !important;
        }
        .stTabs [data-baseweb="tab-highlight"],
        .stTabs [data-baseweb="tab-border"],
        div[data-baseweb="tab-highlight"],
        div[data-baseweb="tab-border"] {
            display: none !important;
        }
        div[data-baseweb="tab-panel"] { padding-top: 0.35rem !important; }

        /* Section headings: less informal, tighter */
        .section-title {
            margin: 1.10rem 0 0.75rem 0 !important;
            color: #f8fbff !important;
            font-size: 1.18rem !important;
            font-weight: 800 !important;
            letter-spacing: -0.028em !important;
            gap: 9px !important;
        }
        .section-title .dot {
            width: 8px !important;
            height: 8px !important;
            background: linear-gradient(135deg, var(--ui-accent), var(--ui-accent-2)) !important;
            box-shadow: 0 0 14px rgba(125,211,252,0.45) !important;
        }
        .tab-subtitle {
            color: var(--ui-muted) !important;
            font-size: 0.93rem !important;
            margin: -0.2rem 0 1.05rem 0 !important;
            line-height: 1.55 !important;
        }

        /* Consistent card system */
        .glass-card,
        .mini-card,
        .rfq-callout,
        [data-testid="stExpander"] {
            border-radius: 18px !important;
            border: 1px solid var(--ui-border) !important;
            background: linear-gradient(180deg, var(--ui-panel), var(--ui-panel-2)) !important;
            box-shadow: 0 14px 34px rgba(0,0,0,0.20), inset 0 1px 0 rgba(255,255,255,0.055) !important;
            backdrop-filter: blur(14px) !important;
        }
        .glass-card { padding: 18px !important; margin-bottom: 0.95rem !important; }
        .mini-card { min-height: 112px !important; padding: 15px !important; }
        .rfq-callout { padding: 16px 18px !important; margin: 0.35rem 0 0.90rem 0 !important; }
        .rfq-callout-title { font-size: 1.02rem !important; font-weight: 800 !important; }
        .rfq-callout-text { color: var(--ui-muted) !important; font-size: 0.90rem !important; }

        .kpi-card,
        [data-testid="metric-container"] {
            min-height: 126px !important;
            border-radius: 18px !important;
            border: 1px solid var(--ui-border) !important;
            background:
                linear-gradient(145deg, rgba(255,255,255,0.085), rgba(255,255,255,0.035)),
                radial-gradient(circle at 96% 8%, var(--kpi-glow, rgba(125,211,252,0.10)), transparent 34%) !important;
            box-shadow: 0 12px 30px rgba(0,0,0,0.20), inset 0 1px 0 rgba(255,255,255,0.07) !important;
            padding: 16px !important;
        }
        .kpi-label,
        [data-testid="metric-container"] label {
            color: var(--ui-faint) !important;
            font-size: 0.72rem !important;
            font-weight: 800 !important;
            letter-spacing: 0.075em !important;
            text-transform: uppercase !important;
        }
        .kpi-value,
        [data-testid="stMetricValue"] {
            color: #f8fbff !important;
            font-family: 'JetBrains Mono', ui-monospace, monospace !important;
            font-size: clamp(1.22rem, 1.65vw, 1.72rem) !important;
            font-weight: 800 !important;
            letter-spacing: -0.035em !important;
            line-height: 1.18 !important;
            word-break: break-word !important;
            overflow-wrap: anywhere !important;
        }
        .kpi-note,
        [data-testid="stMetricDelta"] {
            color: var(--ui-muted) !important;
            font-size: 0.80rem !important;
            line-height: 1.35 !important;
        }

        .config-chip {
            border-radius: 16px !important;
            border: 1px solid var(--ui-border) !important;
            background: rgba(255,255,255,0.046) !important;
            padding: 13px 14px !important;
            min-height: 92px !important;
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.045) !important;
        }
        .config-chip .label { color: var(--ui-faint) !important; font-size: 0.70rem !important; }
        .config-chip .value { color: #f8fbff !important; font-size: 1.15rem !important; font-weight: 800 !important; }

        /* Inputs/buttons: same visual language */
        div.stButton > button,
        .stButton > button {
            min-height: 42px !important;
            border-radius: 12px !important;
            border: 1px solid rgba(125,211,252,0.22) !important;
            background: linear-gradient(135deg, rgba(125,211,252,0.18), rgba(167,139,250,0.16)) !important;
            color: #f8fbff !important;
            font-weight: 800 !important;
            box-shadow: 0 10px 24px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.09) !important;
        }
        div.stButton > button:hover,
        .stButton > button:hover {
            transform: translateY(-1px) !important;
            border-color: rgba(125,211,252,0.42) !important;
            background: linear-gradient(135deg, rgba(125,211,252,0.25), rgba(167,139,250,0.22)) !important;
        }
        .stDownloadButton > button {
            background: rgba(255,255,255,0.055) !important;
            color: rgba(237,246,255,0.86) !important;
            border-color: rgba(255,255,255,0.12) !important;
        }

        .stSelectbox > div > div,
        .stTextInput > div > div > input,
        .stNumberInput > div > div > input,
        .stDateInput > div > div > input,
        .stTextArea textarea,
        div[data-baseweb="select"] > div {
            border-radius: 12px !important;
            background: rgba(255,255,255,0.045) !important;
            border: 1px solid rgba(255,255,255,0.105) !important;
            color: var(--ui-text) !important;
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.035) !important;
        }
        label[data-testid="stWidgetLabel"] p {
            color: rgba(237,246,255,0.78) !important;
            font-weight: 700 !important;
            font-size: 0.86rem !important;
        }

        /* Notes/alerts */
        .soft-note,
        .warning-note,
        .success-note,
        [data-testid="stAlert"] {
            border-radius: 16px !important;
            border: 1px solid var(--ui-border) !important;
            background: rgba(255,255,255,0.050) !important;
            color: rgba(237,246,255,0.86) !important;
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.045) !important;
        }
        .success-note { border-color: rgba(134,239,172,0.22) !important; background: rgba(134,239,172,0.055) !important; }
        .warning-note { border-color: rgba(252,211,77,0.22) !important; background: rgba(252,211,77,0.055) !important; }

        /* Tables/charts */
        [data-testid="stDataFrame"],
        .stDataFrame,
        .stBarChart,
        .stLineChart {
            border-radius: 16px !important;
            border: 1px solid var(--ui-border) !important;
            background: rgba(255,255,255,0.035) !important;
            box-shadow: 0 12px 28px rgba(0,0,0,0.16) !important;
            overflow: hidden !important;
        }
        [data-testid="stDataFrame"] th,
        [data-testid="stDataFrame"] thead tr th {
            background: rgba(255,255,255,0.055) !important;
            color: rgba(237,246,255,0.68) !important;
            font-size: 0.72rem !important;
            font-weight: 800 !important;
            letter-spacing: 0.055em !important;
            text-transform: uppercase !important;
        }

        /* Expander formalization */
        [data-testid="stExpander"] details summary,
        .streamlit-expanderHeader {
            color: rgba(237,246,255,0.86) !important;
            font-weight: 750 !important;
            background: transparent !important;
        }
        [data-testid="stFileUploader"] {
            border-radius: 16px !important;
            border: 1px dashed rgba(125,211,252,0.26) !important;
            background: rgba(125,211,252,0.035) !important;
            padding: 10px !important;
        }
        [data-testid="stFileUploader"] section {
            border-radius: 14px !important;
            border-color: rgba(255,255,255,0.13) !important;
            background: rgba(255,255,255,0.035) !important;
        }

        h1, h2, h3, h4 { color: #f8fbff !important; letter-spacing: -0.03em !important; }
        p, li { color: rgba(237,246,255,0.78) !important; }
        hr { border-color: rgba(255,255,255,0.10) !important; }

        ::-webkit-scrollbar { width: 7px; height: 7px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.16); border-radius: 999px; }

        @media (max-width: 1200px) {
            .stTabs [data-baseweb="tab"] p,
            button[data-baseweb="tab"] p { font-size: 0.82rem !important; }
            .stTabs [data-baseweb="tab"],
            button[data-baseweb="tab"] { padding: 0 10px !important; }
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
    st.markdown(
        f"""
        <div class="kpi-card" style="--kpi-glow: {glow};">
            <div class="kpi-label">{safe_html(label)}</div>
            <div class="kpi-value">{safe_html(value)}</div>
            <div class="kpi-note">{safe_html(note_text)}</div>
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
            <h1 class="hero-title">Truck Configuration Cost Command Center</h1>
            <div class="hero-subtitle">
                A polished Snowflake + Streamlit workspace for Cortex RFQ intake and configurable truck costing.
                Upload customer RFQs, extract KMAT characteristics, validate BMCS trust, run the governed Snowpark engine,
                compare rule, ML, override, default, and final decisions, and explain baseline plus risk-adjusted cost with confidence.
                Runtime candidate use is governed by policy fingerprints, kill switches, secure procedures, and deterministic fallback.
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
                <span class="pill">Governed Decision Hierarchy</span>
                <span class="pill">Secure Runtime Boundary</span>
                <span class="pill">Policy Fingerprints + Seals</span>
                <span class="pill">Least-Privilege Procedures</span>
                <span class="pill">Shadow ML Advisory</span>
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
    page_title="KMAT Governed Cost Command Center",
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
inject_consistent_glass_overrides()
initialize_widget_state()
allowed_values = load_allowed_values_cached()
render_hero()

try:
    session_identity = load_session_identity()
except Exception as identity_exc:
    session_identity = {
        "ACTUAL_USER": "UNAVAILABLE",
        "ACTIVE_ROLE": "UNAVAILABLE",
        "ACTIVE_WAREHOUSE": "UNAVAILABLE",
        "IDENTITY_ERROR": str(identity_exc),
    }

actual_snowflake_user = optional_text(
    session_identity.get("ACTUAL_USER"),
    "UNAVAILABLE",
)
active_snowflake_role = optional_text(
    session_identity.get("ACTIVE_ROLE"),
    "UNAVAILABLE",
)

with st.expander("About this dashboard", expanded=False):
    st.write(
        """
- Upload or paste an RFQ and use Cortex to extract KMAT configuration values such as ENGINE, CAB, WHEEL, and COLOR.
- Review BMCS confidence, risk-adjusted costing, and trusted-cost eligibility before running the final KMAT cost simulation.
- Compare deterministic rules, ML advisory values, approved shadow overrides, safe defaults, and final governed values.
- Inspect policy/model lineage, safety gates, runtime kill switches, policy fingerprints, policy seals, and audit events.
- The dashboard contains no deployment-activation or runtime-enablement action; those remain separate governed administrative operations.
        """
    )

# -----------------------------
# Sidebar configuration
# -----------------------------

with st.sidebar:
    st.markdown("### ⚙️ Configuration Studio")
    st.caption("Choose a preset or manually configure the KMAT truck.")

    with st.expander("🔐 Snowflake Security Context", expanded=False):
        st.text_input(
            "Actual Snowflake user",
            value=actual_snowflake_user,
            disabled=True,
            key="sidebar_actual_snowflake_user",
        )
        st.text_input(
            "Active Snowflake role",
            value=active_snowflake_role,
            disabled=True,
            key="sidebar_active_snowflake_role",
        )
        st.caption(
            "Secure procedures capture CURRENT_USER() inside "
            "Snowflake. Owner and executor roles must never be "
            "assigned to normal application users."
        )

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
    "🧭 Governed Decisions",
    "📜 Scenario History",
    "📊 Compare Scenarios",
    "🔍 Component Impact",
    "🚀 Batch Demo Runner",
    "📈 Monitoring & Outcomes",
])
# -----------------------------
# Tab 3: Configure & Run
# -----------------------------

with main_tabs[2]:
    section("Build Configuration", "🧩")
    st.markdown('<div class="tab-subtitle">Select a truck variant and run the deterministic governed Snowpark cost flow. Runtime model activation is a separate administrative process and is not exposed by this dashboard.</div>', unsafe_allow_html=True)

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
        note("This action writes the selected configuration to CORE_INPUT, runs the deterministic governed cost procedure, refreshes CORE_OUTPUT, and records the governed decision hierarchy. It does not activate or enable a model.", "soft")

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
                phase10b_result = procedure_result.get(
                    "phase10b_result",
                    {},
                )
                note(
                    f"Simulation {simulation_id} completed successfully. "
                    f"Hierarchy status: "
                    f"{phase10b_result.get('resolution_status', 'N/A')}.",
                    "success",
                )
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

            risk_tabs = st.tabs(["🧱 Component Risk", "🏭 Operation TDS", "🧾 Overhead Risk", "📝 Notes"])
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
                st.write(row.get("RISK_CALCULATION_NOTES", "No notes found."))
                note("Baseline cost remains the audit foundation. Risk-adjusted cost adds explainable CSS, FMIS, and TDS adjustments; BMCS controls whether an RFQ-derived quotation is trusted, review-recommended, or preliminary.", "soft")

# -----------------------------
# Tab 5: Governed Decisions
# -----------------------------

with main_tabs[4]:
    section("Governed Decision and Cost Authority", "🧭")
    st.markdown(
        '<div class="tab-subtitle">'
        'Compare deterministic rules, ML advisory values, approved '
        'overrides, safe defaults, and the final governed values used '
        'by the current policy. This tab does not activate a deployment '
        'or enable runtime authority.'
        '</div>',
        unsafe_allow_html=True,
    )

    section("Secure Runtime and Privilege Control Plane", "🔐")

    try:
        security_control_df = load_security_control_dashboard()
    except Exception as exc:
        security_control_df = pd.DataFrame()
        note(
            "Security dashboard is unavailable to the active role: "
            f"{exc}",
            "warning",
        )

    try:
        runtime_authority_df = load_runtime_authority_dashboard()
    except Exception as exc:
        runtime_authority_df = pd.DataFrame()
        note(
            "Runtime-authority dashboard is unavailable to the "
            f"active role: {exc}",
            "warning",
        )

    try:
        policy_seal_df = load_policy_seal_integrity()
    except Exception as exc:
        policy_seal_df = pd.DataFrame()
        note(
            "Policy-seal integrity view is unavailable to the "
            f"active role: {exc}",
            "warning",
        )

    security_row = (
        security_control_df.iloc[0]
        if not security_control_df.empty
        else pd.Series(dtype=object)
    )

    open_runtime_path_count = (
        int(
            runtime_authority_df[
                "RUNTIME_CANDIDATE_PATH_OPEN_FLAG"
            ].fillna(False).astype(bool).sum()
        )
        if (
            not runtime_authority_df.empty
            and "RUNTIME_CANDIDATE_PATH_OPEN_FLAG"
                in runtime_authority_df.columns
        )
        else 0
    )

    enabled_runtime_authority_count = (
        int(
            (
                runtime_authority_df[
                    "AUTHORITY_STATUS"
                ].astype(str).str.upper()
                == "ENABLED"
            ).sum()
        )
        if (
            not runtime_authority_df.empty
            and "AUTHORITY_STATUS"
                in runtime_authority_df.columns
        )
        else 0
    )

    security_violation_count = sum(
        int(
            as_float(
                security_row.get(column_name, 0)
            )
        )
        for column_name in [
            "MISSING_REQUIRED_GRANT_COUNT",
            "BYPASS_GRANT_VIOLATION_COUNT",
            "FUNCTIONAL_ROLE_DML_VIOLATION_COUNT",
            "APPEND_ONLY_VIOLATION_COUNT",
            "POLICY_SEAL_MISMATCH_COUNT",
            "OVERRIDE_PRECEDENCE_VIOLATION_COUNT",
        ]
    )

    active_policy_seal_count = (
        int(
            policy_seal_df[
                "ACTIVE_SEAL_PRESENT_FLAG"
            ].fillna(False).astype(bool).sum()
        )
        if (
            not policy_seal_df.empty
            and "ACTIVE_SEAL_PRESENT_FLAG"
                in policy_seal_df.columns
        )
        else 0
    )

    security_cols = st.columns(5)
    with security_cols[0]:
        kpi_card(
            "Snowflake User",
            actual_snowflake_user,
            active_snowflake_role,
            "rgba(99,230,255,0.20)",
        )
    with security_cols[1]:
        kpi_card(
            "Security State",
            optional_text(
                security_row.get(
                    "SECURITY_CONTROL_STATUS"
                ),
                "UNAVAILABLE",
            ),
            f"{security_violation_count} detected violation(s)",
            (
                "rgba(126,247,196,0.22)"
                if security_violation_count == 0
                else "rgba(255,143,171,0.24)"
            ),
        )
    with security_cols[2]:
        kpi_card(
            "Runtime Paths Open",
            str(open_runtime_path_count),
            "Candidate path requires all gates",
            (
                "rgba(126,247,196,0.22)"
                if open_runtime_path_count > 0
                else "rgba(255,209,102,0.22)"
            ),
        )
    with security_cols[3]:
        kpi_card(
            "Enabled Authorities",
            str(enabled_runtime_authority_count),
            "Expected zero before a real pilot",
            "rgba(177,151,252,0.20)",
        )
    with security_cols[4]:
        kpi_card(
            "Active Policy Seals",
            str(active_policy_seal_count),
            "Created only by secure activation",
            "rgba(255,209,102,0.20)",
        )

    if security_violation_count > 0:
        note(
            "The privilege dashboard reports a control violation. "
            "Do not use any runtime candidate path until the grant "
            "snapshot and integrity findings are resolved.",
            "warning",
        )
    elif open_runtime_path_count == 0:
        note(
            "All runtime candidate paths are closed. The deterministic "
            "governed cost hierarchy remains the operational result.",
            "success",
        )
    else:
        note(
            "At least one runtime candidate path is open. Every "
            "candidate decision must pass through the secure runtime "
            "resolver and can still fall back deterministically.",
            "warning",
        )

    with st.expander(
        "Runtime authority, policy seals, and security dashboard",
        expanded=False,
    ):
        security_tabs = st.tabs(
            [
                "Runtime Authority",
                "Policy Seals",
                "Privilege Dashboard",
            ]
        )
        with security_tabs[0]:
            st.dataframe(
                runtime_authority_df,
                use_container_width=True,
                hide_index=True,
            )
        with security_tabs[1]:
            st.dataframe(
                policy_seal_df,
                use_container_width=True,
                hide_index=True,
            )
        with security_tabs[2]:
            st.dataframe(
                security_control_df,
                use_container_width=True,
                hide_index=True,
            )

        st.caption(
            "Official activation entry point: "
            f"{SECURE_ACTIVATION_ENTRY_POINT}. "
            "Activation and runtime enablement are intentionally not "
            "available as Streamlit buttons."
        )

    governed_history_df = load_history(250)
    governed_ids = (
        list(
            dict.fromkeys(
                governed_history_df["SIMULATION_ID"]
                .dropna()
                .astype(str)
                .tolist()
            )
        )
        if not governed_history_df.empty
        else []
    )

    if not governed_ids:
        note(
            "Run a governed simulation before opening the decision view.",
            "soft",
        )
    else:
        default_governed_id = st.session_state.get(
            "last_simulation_id",
            governed_ids[0],
        )
        if default_governed_id not in governed_ids:
            default_governed_id = governed_ids[0]

        governed_sim_id = st.selectbox(
            "Select governed simulation",
            governed_ids,
            index=governed_ids.index(default_governed_id),
            key="phase10c_simulation_id",
        )

        governed_df = load_phase10c_decision_display(
            governed_sim_id
        )

        if governed_df.empty:
            note(
                "No Phase 10B hierarchy row exists for this simulation. "
                "Run the simulation through "
                "RUN_KMAT_COST_SIMULATION_GOVERNED_V3 first.",
                "warning",
            )
        else:
            governed_row = governed_df.iloc[0]

            try:
                secure_runtime_input_df = (
                    load_streamlit_runtime_inputs(
                        governed_sim_id
                    )
                )
            except Exception as exc:
                secure_runtime_input_df = pd.DataFrame()
                note(
                    "The secure Streamlit runtime-input view is "
                    "not available. Runtime execution remains "
                    f"disabled. Details: {exc}",
                    "soft",
                )

            safety_pass = bool(
                governed_row.get(
                    "SAFETY_GATE_PASS_FLAG",
                    False,
                )
            )
            consumption_allowed = bool(
                governed_row.get(
                    "COST_ENGINE_CONSUMPTION_ALLOWED_FLAG",
                    False,
                )
            )
            recalc_required = bool(
                governed_row.get(
                    "OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG",
                    False,
                )
            )
            any_ml_used = bool(
                governed_row.get("ANY_ML_USED_FLAG", False)
            )
            any_override_used = bool(
                governed_row.get(
                    "ANY_OVERRIDE_USED_FLAG",
                    False,
                )
            )
            any_default_used = bool(
                governed_row.get(
                    "ANY_SAFE_DEFAULT_USED_FLAG",
                    False,
                )
            )

            if any_override_used:
                authority_label = "Engineer Override"
            elif any_ml_used:
                authority_label = "Governed ML"
            elif any_default_used:
                authority_label = "Safe Default"
            else:
                authority_label = "Deterministic Rule"

            top_cols = st.columns(5)
            with top_cols[0]:
                kpi_card(
                    "Resolution",
                    str(
                        governed_row.get(
                            "RESOLUTION_STATUS",
                            "N/A",
                        )
                    ),
                    str(
                        governed_row.get(
                            "DISPLAY_DEPLOYMENT_MODE",
                            "N/A",
                        )
                    ),
                    "rgba(99,230,255,0.20)",
                )
            with top_cols[1]:
                kpi_card(
                    "Safety Gate",
                    "PASS" if safety_pass else "BLOCKED",
                    str(
                        governed_row.get(
                            "RESOLUTION_REASON",
                            "No reason available.",
                        )
                    ),
                    (
                        "rgba(126,247,196,0.22)"
                        if safety_pass
                        else "rgba(255,143,171,0.24)"
                    ),
                )
            with top_cols[2]:
                kpi_card(
                    "Cost Contract",
                    (
                        "READY"
                        if consumption_allowed
                        else "BLOCKED"
                    ),
                    (
                        "No cost recalculation required"
                        if not recalc_required
                        else "Official cost recalculation required"
                    ),
                    (
                        "rgba(126,247,196,0.22)"
                        if consumption_allowed
                        else "rgba(255,209,102,0.24)"
                    ),
                )
            with top_cols[3]:
                kpi_card(
                    "Final Authority",
                    authority_label,
                    "Override → ML → Rule → Default",
                    "rgba(177,151,252,0.22)",
                )
            with top_cols[4]:
                kpi_card(
                    "Quote Trust",
                    str(
                        governed_row.get(
                            "OFFICIAL_QUOTE_TRUST_STATUS",
                            "N/A",
                        )
                    ),
                    (
                        "Trusted cost allowed"
                        if bool(
                            governed_row.get(
                                "OFFICIAL_TRUSTED_COST_ALLOWED_FLAG",
                                False,
                            )
                        )
                        else "Trusted cost not allowed"
                    ),
                    "rgba(255,209,102,0.22)",
                )

            if recalc_required:
                note(
                    "A resolved factor differs from the factor already "
                    "used by the official engine. The contract is blocked "
                    "until cost is recalculated using that resolved value.",
                    "warning",
                )
            elif safety_pass and consumption_allowed:
                note(
                    "The hierarchy is safe. Under the current SHADOW "
                    "policies, ML and approved overrides remain advisory "
                    "and deterministic factors remain official.",
                    "success",
                )
            else:
                note(
                    "The hierarchy is currently blocked. Review the "
                    "resolution reason before using the cost result.",
                    "warning",
                )

            section("Rule → ML → Override → Final", "🔀")
            factor_table = build_governed_factor_table(
                governed_row
            )
            st.dataframe(
                factor_table,
                use_container_width=True,
                hide_index=True,
            )

            section("Secure Runtime Boundary", "🔒")
            st.markdown(
                '<div class="tab-subtitle">'
                'This control is inactive while the domain path is '
                'blocked. It becomes callable only when the database '
                'reports an open runtime path and the governed decision '
                'row contains explicit candidate, quality, and OOD '
                'metadata. No safety flag is invented by the UI.'
                '</div>',
                unsafe_allow_html=True,
            )

            runtime_domain = st.selectbox(
                "Runtime model domain",
                ["CSS", "FMIS", "TDS", "BMCS"],
                key="secure_runtime_domain",
            )

            runtime_input = (
                extract_runtime_input_from_secure_view(
                    secure_runtime_input_df,
                    runtime_domain,
                    governed_row,
                )
            )

            domain_runtime_row = pd.Series(dtype=object)
            if (
                not runtime_authority_df.empty
                and "MODEL_DOMAIN"
                    in runtime_authority_df.columns
            ):
                domain_match = runtime_authority_df[
                    runtime_authority_df[
                        "MODEL_DOMAIN"
                    ].astype(str).str.upper()
                    == runtime_domain
                ]
                if not domain_match.empty:
                    domain_runtime_row = (
                        domain_match.iloc[0]
                    )

            domain_path_open = bool(
                domain_runtime_row.get(
                    "RUNTIME_CANDIDATE_PATH_OPEN_FLAG",
                    False,
                )
            )
            require_engineer_approval = bool(
                domain_runtime_row.get(
                    "REQUIRE_ENGINEER_APPROVAL_FLAG",
                    False,
                )
            )

            runtime_cols = st.columns(4)
            with runtime_cols[0]:
                kpi_card(
                    "Domain Path",
                    (
                        "OPEN"
                        if domain_path_open
                        else "BLOCKED"
                    ),
                    optional_text(
                        domain_runtime_row.get(
                            "AUTHORITY_STATUS"
                        ),
                        "No enabled authority",
                    ),
                    (
                        "rgba(126,247,196,0.22)"
                        if domain_path_open
                        else "rgba(255,143,171,0.22)"
                    ),
                )
            with runtime_cols[1]:
                kpi_card(
                    "Rule Value",
                    optional_score(
                        runtime_input.get(
                            "rule_value"
                        )
                    ),
                    optional_text(
                        runtime_input.get("rule_key"),
                        "Unavailable",
                    ),
                    "rgba(99,230,255,0.18)",
                )
            with runtime_cols[2]:
                kpi_card(
                    "Candidate Value",
                    optional_score(
                        runtime_input.get(
                            "candidate_value"
                        )
                    ),
                    optional_text(
                        runtime_input.get(
                            "candidate_key"
                        ),
                        "Unavailable",
                    ),
                    "rgba(177,151,252,0.18)",
                )
            with runtime_cols[3]:
                kpi_card(
                    "Inference Metadata",
                    (
                        "READY"
                        if runtime_input.get("ready")
                        else "INCOMPLETE"
                    ),
                    (
                        "Inference, quality, and OOD are explicit"
                        if runtime_input.get("ready")
                        else runtime_input.get(
                            "reason",
                            "Unavailable",
                        )
                    ),
                    (
                        "rgba(126,247,196,0.18)"
                        if runtime_input.get("ready")
                        else "rgba(255,209,102,0.20)"
                    ),
                )

            engineer_approved = False
            engineer_reference = None

            if require_engineer_approval:
                engineer_cols = st.columns([0.8, 1.8])
                with engineer_cols[0]:
                    engineer_approved = st.checkbox(
                        "Engineer approval confirmed",
                        value=False,
                        key=(
                            "secure_runtime_engineer_approved_"
                            f"{runtime_domain}"
                        ),
                    )
                with engineer_cols[1]:
                    engineer_reference = st.text_input(
                        "Engineer approval reference",
                        value="",
                        key=(
                            "secure_runtime_engineer_reference_"
                            f"{runtime_domain}"
                        ),
                    )

            runtime_acknowledged = st.checkbox(
                "I understand that this records an auditable runtime "
                "decision and never bypasses deterministic fallback.",
                value=False,
                key=(
                    "secure_runtime_acknowledged_"
                    f"{governed_sim_id}_{runtime_domain}"
                ),
            )

            engineer_gate_pass = (
                not require_engineer_approval
                or (
                    engineer_approved
                    and bool(
                        str(
                            engineer_reference or ""
                        ).strip()
                    )
                )
            )

            runtime_call_ready = (
                domain_path_open
                and bool(
                    runtime_input.get("ready")
                )
                and bool(
                    runtime_input.get(
                        "inference_success_flag",
                        False,
                    )
                )
                and security_violation_count == 0
                and runtime_acknowledged
                and engineer_gate_pass
            )

            if not domain_path_open:
                note(
                    "The database runtime path is BLOCKED for "
                    f"{runtime_domain}. The secure resolver button "
                    "remains disabled and deterministic values remain "
                    "official.",
                    "soft",
                )
            elif not runtime_input.get("ready"):
                note(
                    "The runtime path is open, but this simulation does "
                    "not expose a complete secure runtime-input "
                    "record. Candidate execution remains disabled.",
                    "warning",
                )

            execute_runtime_clicked = st.button(
                "Resolve Through Secure Runtime Boundary",
                type="primary",
                use_container_width=True,
                disabled=not runtime_call_ready,
                key=(
                    "secure_runtime_resolve_"
                    f"{governed_sim_id}_{runtime_domain}"
                ),
            )

            if execute_runtime_clicked:
                try:
                    runtime_decision_id = (
                        make_runtime_decision_id(
                            runtime_domain,
                            governed_sim_id,
                        )
                    )

                    with st.spinner(
                        "Resolving the candidate through the secure "
                        "Snowflake runtime boundary..."
                    ):
                        runtime_result = (
                            resolve_secure_runtime_authority(
                                runtime_decision_id=(
                                    runtime_decision_id
                                ),
                                model_domain=runtime_domain,
                                simulation_id=governed_sim_id,

                                rule_value=runtime_input.get(
                                    "rule_value"
                                ),
                                candidate_value=(
                                    runtime_input.get(
                                        "candidate_value"
                                    )
                                ),

                                quality_pass_flag=bool(
                                    runtime_input.get(
                                        "quality_pass_flag"
                                    )
                                ),
                                ood_flag=bool(
                                    runtime_input.get(
                                        "ood_flag"
                                    )
                                ),

                                engineer_approved_flag=(
                                    engineer_approved
                                ),
                                engineer_approval_reference=(
                                    engineer_reference
                                ),
                            )
                        )

                    st.session_state[
                        "last_secure_runtime_result"
                    ] = runtime_result

                    if runtime_result.get("status") == "SUCCESS":
                        runtime_authorised = bool(
                            runtime_result.get(
                                "runtime_authorised",
                                False,
                            )
                        )
                        note(
                            "Secure runtime decision recorded. "
                            f"Runtime authorised: "
                            f"{'YES' if runtime_authorised else 'NO'}. "
                            f"Final source: "
                            f"{runtime_result.get('final_runtime_source', 'N/A')}.",
                            (
                                "success"
                                if runtime_authorised
                                else "warning"
                            ),
                        )
                    else:
                        note(
                            "Secure runtime resolution did not return "
                            "SUCCESS.",
                            "warning",
                        )

                    st.json(runtime_result)

                except Exception as exc:
                    st.error(
                        "Secure runtime resolution failed: "
                        f"{exc}"
                    )

            try:
                runtime_decision_df = (
                    load_runtime_decisions(
                        governed_sim_id,
                        50,
                    )
                )
            except Exception as exc:
                runtime_decision_df = pd.DataFrame()
                note(
                    "Runtime decision history is unavailable to the "
                    f"active role: {exc}",
                    "soft",
                )

            with st.expander(
                "Auditable runtime decisions for this simulation",
                expanded=False,
            ):
                if runtime_decision_df.empty:
                    note(
                        "No secure runtime decision has been recorded "
                        "for this simulation.",
                        "soft",
                    )
                else:
                    st.dataframe(
                        runtime_decision_df,
                        use_container_width=True,
                        hide_index=True,
                    )

                try:
                    approved_override_df = (
                        load_approved_override_display(
                            governed_sim_id
                        )
                    )
                except Exception:
                    approved_override_df = pd.DataFrame()

                st.markdown(
                    "**Approved override precedence (V2)**"
                )
                if approved_override_df.empty:
                    note(
                        "No governed override row is available for "
                        "this simulation or the active role does not "
                        "have access to the secure view.",
                        "soft",
                    )
                else:
                    st.dataframe(
                        approved_override_df,
                        use_container_width=True,
                        hide_index=True,
                    )

            detail_cols = st.columns(3)
            with detail_cols[0]:
                kpi_card(
                    "Official Risk Cost",
                    money(
                        governed_row.get(
                            "OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD",
                            0,
                        )
                    ),
                    "Stored deterministic/risk-adjusted result",
                    "rgba(255,143,171,0.20)",
                )
            with detail_cols[1]:
                kpi_card(
                    "Official Target Price",
                    money(
                        governed_row.get(
                            "OFFICIAL_TARGET_PRICE_USD",
                            0,
                        )
                    ),
                    "Stored official target price",
                    "rgba(99,230,255,0.20)",
                )
            with detail_cols[2]:
                kpi_card(
                    "BMCS Final Status",
                    str(
                        governed_row.get(
                            "RESOLVED_BMCS_STATUS",
                            "N/A",
                        )
                    ),
                    str(
                        governed_row.get(
                            "BMCS_RESOLVED_SOURCE",
                            "N/A",
                        )
                    ),
                    "rgba(177,151,252,0.22)",
                )

            section("BMCS Trust and Review Gate", "🧠")
            bmcs_cols = st.columns(4)
            with bmcs_cols[0]:
                kpi_card(
                    "BMCS ML Score",
                    optional_score(
                        governed_row.get("BMCS_ML_SCORE")
                    ),
                    "Advisory only",
                    "rgba(99,230,255,0.18)",
                )
            with bmcs_cols[1]:
                kpi_card(
                    "Official Status",
                    str(
                        governed_row.get(
                            "BMCS_OFFICIAL_STATUS",
                            "N/A",
                        )
                    ),
                    "Phase 7/manual configuration result",
                    "rgba(126,247,196,0.18)",
                )
            with bmcs_cols[2]:
                kpi_card(
                    "Approved Override",
                    str(
                        governed_row.get(
                            "BMCS_OVERRIDE_STATUS",
                            "—",
                        )
                    ),
                    (
                        "Eligible"
                        if bool(
                            governed_row.get(
                                "BMCS_OVERRIDE_ELIGIBLE_FLAG",
                                False,
                            )
                        )
                        else "Not eligible under current policy"
                    ),
                    "rgba(255,209,102,0.18)",
                )
            with bmcs_cols[3]:
                kpi_card(
                    "Safe Default",
                    str(
                        governed_row.get(
                            "BMCS_SAFE_DEFAULT_STATUS",
                            "REVIEW_REQUIRED",
                        )
                    ),
                    "Used only when official status is unavailable",
                    "rgba(255,143,171,0.18)",
                )

            section("Policy and Model Lineage", "🧬")
            lineage_df = build_model_lineage_table(
                governed_row
            )
            st.dataframe(
                lineage_df,
                use_container_width=True,
                hide_index=True,
            )

            with st.expander(
                "Resolution reasons and control flags",
                expanded=False,
            ):
                reason_rows = pd.DataFrame(
                    [
                        {
                            "Domain": "CSS",
                            "Final Source": governed_row.get(
                                "CSS_RESOLVED_SOURCE",
                                "N/A",
                            ),
                            "Reason": governed_row.get(
                                "CSS_RESOLUTION_REASON",
                                "",
                            ),
                        },
                        {
                            "Domain": "FMIS",
                            "Final Source": governed_row.get(
                                "FMIS_RESOLVED_SOURCE",
                                "N/A",
                            ),
                            "Reason": governed_row.get(
                                "FMIS_RESOLUTION_REASON",
                                "",
                            ),
                        },
                        {
                            "Domain": "TDS",
                            "Final Source": governed_row.get(
                                "TDS_RESOLVED_SOURCE",
                                "N/A",
                            ),
                            "Reason": governed_row.get(
                                "TDS_RESOLUTION_REASON",
                                "",
                            ),
                        },
                        {
                            "Domain": "BMCS",
                            "Final Source": governed_row.get(
                                "BMCS_RESOLVED_SOURCE",
                                "N/A",
                            ),
                            "Reason": governed_row.get(
                                "BMCS_RESOLUTION_REASON",
                                "",
                            ),
                        },
                    ]
                )
                st.dataframe(
                    reason_rows,
                    use_container_width=True,
                    hide_index=True,
                )

                control_rows = pd.DataFrame(
                    [
                        {
                            "Control": "Any override used",
                            "Value": yes_no(any_override_used),
                        },
                        {
                            "Control": "Any ML used",
                            "Value": yes_no(any_ml_used),
                        },
                        {
                            "Control": "Any safe default used",
                            "Value": yes_no(any_default_used),
                        },
                        {
                            "Control": "Cost recalculation required",
                            "Value": yes_no(recalc_required),
                        },
                        {
                            "Control": "Business review update required",
                            "Value": yes_no(
                                governed_row.get(
                                    "BUSINESS_REVIEW_UPDATE_REQUIRED_FLAG",
                                    False,
                                )
                            ),
                        },
                        {
                            "Control": "Cost consumption allowed",
                            "Value": yes_no(
                                consumption_allowed
                            ),
                        },
                    ]
                )
                st.dataframe(
                    control_rows,
                    use_container_width=True,
                    hide_index=True,
                )

            section("Governance Audit Trail", "🧾")
            audit_df = load_phase10c_audit(
                governed_sim_id,
                50,
            )
            if audit_df.empty:
                note(
                    "No Phase 10A or Phase 10B audit events found.",
                    "soft",
                )
            else:
                st.dataframe(
                    audit_df,
                    use_container_width=True,
                    hide_index=True,
                )
                st.download_button(
                    "Download governance audit CSV",
                    data=dataframe_to_csv_bytes(audit_df),
                    file_name=(
                        f"{governed_sim_id}"
                        "_governance_audit.csv"
                    ),
                    mime="text/csv",
                    key="download_phase10c_audit",
                )

            with st.expander(
                "Latest governed procedure JSON",
                expanded=False,
            ):
                st.json(
                    st.session_state.get(
                        "last_procedure_result",
                        {},
                    )
                )


# -----------------------------
# Tab 6: Scenario History
# -----------------------------

with main_tabs[5]:
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
# Tab 7: Compare Scenarios
# -----------------------------

with main_tabs[6]:
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
# Tab 8: Component Impact
# -----------------------------

with main_tabs[7]:
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
# Tab 9: Batch Demo Runner
# -----------------------------

with main_tabs[8]:
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

        top_cols = st.columns(4)
        with top_cols[0]:
            kpi_card("BMCS", f"{score:.0f}%", review_status, "rgba(126,247,196,0.20)" if score >= 90 else "rgba(255,209,102,0.22)" if score >= 70 else "rgba(255,143,171,0.24)")
        with top_cols[1]:
            kpi_card("Review Required", "YES" if review_required else "NO", "Engineering gate", "rgba(255,143,171,0.20)" if review_required else "rgba(126,247,196,0.18)")
        with top_cols[2]:
            kpi_card("Final Cost Allowed", "YES" if final_allowed else "NO", "Trusted quote flag", "rgba(126,247,196,0.18)" if final_allowed else "rgba(255,143,171,0.24)")
        with top_cols[3]:
            kpi_card("Risk Level", str(selected_rfq.get("BMCS_RISK_LEVEL", "N/A")), str(selected_rfq.get("RULE_VALIDATION_STATUS", "N/A")), "rgba(99,230,255,0.18)")

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
        action_cols = st.columns(3)
        with action_cols[0]:
            score_clicked = st.button("Run BMCS Scoring", use_container_width=True, key="btn_run_bmcs_scoring")
        with action_cols[1]:
            prepare_clicked = st.button("Prepare RFQ Inputs", use_container_width=True, key="btn_prepare_rfq_inputs_bmcs")
        with action_cols[2]:
            full_clicked = st.button("Score + Prepare + Cost", type="primary", use_container_width=True, key="btn_full_rfq_flow")

        if score_clicked:
            try:
                with st.spinner("Running rule-based BMCS scoring..."):
                    result = run_bmcs_scoring(selected_rfq_id)
                st.session_state["last_bmcs_result"] = result
                if result.get("status") == "SUCCESS":
                    note(f"BMCS scoring completed for {selected_rfq_id}.", "success")
                    st.json(result)
                    soft_rerun()
                else:
                    note("BMCS scoring did not return SUCCESS.", "warning")
                    st.json(result)
            except Exception as exc:
                st.error(f"BMCS scoring failed: {exc}")

        if prepare_clicked:
            try:
                with st.spinner("Preparing RFQ simulation input tables..."):
                    result = prepare_rfq_simulation_inputs(selected_rfq_id)
                st.session_state["last_rfq_prepare_result"] = result
                if result.get("status") == "SUCCESS":
                    note(f"RFQ inputs prepared for simulation {result.get('simulation_id')}.", "success")
                    st.json(result)
                else:
                    note("RFQ input preparation did not return SUCCESS.", "warning")
                    st.json(result)
            except Exception as exc:
                st.error(f"RFQ preparation failed: {exc}")

        if full_clicked:
            try:
                with st.spinner("Scoring BMCS, preparing simulation inputs, and running KMAT cost engine..."):
                    result = run_rfq_cost_flow(selected_rfq_id)
                st.session_state["last_rfq_cost_flow_result"] = result
                if result.get("status") == "SUCCESS":
                    sim_id = result.get("simulation_id")
                    st.session_state["last_simulation_id"] = sim_id
                    st.session_state["last_procedure_result"] = result.get("cost_result", {})
                    note(f"RFQ cost flow completed. Simulation {sim_id} is now available in the output tables.", "success")
                    st.json(result)
                    soft_rerun()
                else:
                    note(f"RFQ cost flow stopped at stage {result.get('stage')}.", "warning")
                    st.json(result)
            except Exception as exc:
                st.error(f"RFQ cost flow failed: {exc}")

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
                Step 1: Upload or paste RFQ → Step 2: Process with Cortex → Step 3: Review BMCS → Step 4: Prepare simulation → Step 5: Run cost engine.
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
        kpi_card("5. Costing", "Run", "Deterministic cost + governed hierarchy", "rgba(255,143,171,0.18)")

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
        "Use the buttons from left to right. Process the RFQ with Cortex, run the existing RFQ quote pipeline, then attach Phase 10A/10B governance without overwriting the RFQ trust result.",
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
                quote_simulation_id = quote_result.get(
                    "simulation_id"
                )
                st.session_state["last_simulation_id"] = (
                    quote_simulation_id
                )

                governance_result = (
                    prepare_governance_for_existing_simulation(
                        quote_simulation_id
                    )
                    if quote_simulation_id
                    else {
                        "status": "ERROR",
                        "message": (
                            "RFQ quote result did not return "
                            "a simulation_id."
                        ),
                    }
                )
                quote_result["phase10c_governance"] = (
                    governance_result
                )
                st.session_state[
                    "last_procedure_result"
                ] = governance_result

                note(
                    f"Full RFQ quote pipeline completed for "
                    f"{normalized_rfq_id}. Trust status: "
                    f"{quote_result.get('quote_trust_status')}. "
                    f"Governance status: "
                    f"{governance_result.get('status', 'UNKNOWN')}.",
                    (
                        "success"
                        if governance_result.get("status")
                        == "SUCCESS"
                        else "warning"
                    ),
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
                kpi_card("BMCS", f"{as_float(r.get('BOM_MATCH_CONFIDENCE_SCORE', 0)):.2f}%", str(r.get("REVIEW_STATUS", "N/A")), "rgba(99,230,255,0.22)")
            with status_cols[1]:
                kpi_card("Review Status", str(r.get("REVIEW_STATUS", "N/A")), f"Final allowed: {r.get('FINAL_TRUSTED_COST_ALLOWED_FLAG', 'N/A')}", "rgba(255,209,102,0.22)")
            with status_cols[2]:
                kpi_card("Complexity", str(r.get("RFQ_COMPLEXITY_CATEGORY", "N/A")), "AI_CLASSIFY result", "rgba(177,151,252,0.20)")
            with status_cols[3]:
                kpi_card("Simulation", str(r.get("SIMULATION_ID", "N/A")), "RFQ-linked cost run", "rgba(126,247,196,0.18)")
            with status_cols[4]:
                kpi_card("Cortex Status", str(r.get("CORTEX_PROCESSING_STATUS", "N/A")), "Document intake status", "rgba(255,143,171,0.20)")

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
                    "BOM_MATCH_CONFIDENCE_SCORE",
                    "REVIEW_STATUS",
                    "REVIEW_REQUIRED_FLAG",
                    "FINAL_TRUSTED_COST_ALLOWED_FLAG",
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

# -----------------------------
# Tab 10: Monitoring and Outcomes
# -----------------------------

with main_tabs[9]:
    section("Monitoring and Actual-Outcome Feedback", "📈")
    st.markdown(
        '<div class="tab-subtitle">'
        'Record verified realised outcomes, compare rule and ML '
        'performance, and snapshot operational safety metrics. '
        'Feedback remains advisory and does not change official cost. The UI displays the authenticated Snowflake user for all operator actions.'
        '</div>',
        unsafe_allow_html=True,
    )

    operational_df = load_phase11a_operational_summary()

    if not operational_df.empty:
        operational_row = operational_df.iloc[0]
        monitor_cols = st.columns(5)

        with monitor_cols[0]:
            kpi_card(
                "Simulations",
                str(
                    int(
                        as_float(
                            operational_row.get(
                                "TOTAL_SIMULATION_COUNT",
                                0,
                            )
                        )
                    )
                ),
                "Phase 10B monitored runs",
                "rgba(99,230,255,0.20)",
            )

        with monitor_cols[1]:
            kpi_card(
                "Safety Failures",
                str(
                    int(
                        as_float(
                            operational_row.get(
                                "SAFETY_FAILURE_COUNT",
                                0,
                            )
                        )
                    )
                ),
                "Expected zero",
                (
                    "rgba(126,247,196,0.22)"
                    if as_float(
                        operational_row.get(
                            "SAFETY_FAILURE_COUNT",
                            0,
                        )
                    ) == 0
                    else "rgba(255,143,171,0.24)"
                ),
            )

        with monitor_cols[2]:
            kpi_card(
                "Blocked Contracts",
                str(
                    int(
                        as_float(
                            operational_row.get(
                                "COST_BLOCKED_COUNT",
                                0,
                            )
                        )
                    )
                ),
                "Expected zero",
                (
                    "rgba(126,247,196,0.22)"
                    if as_float(
                        operational_row.get(
                            "COST_BLOCKED_COUNT",
                            0,
                        )
                    ) == 0
                    else "rgba(255,143,171,0.24)"
                ),
            )

        with monitor_cols[3]:
            kpi_card(
                "Recalculation Required",
                str(
                    int(
                        as_float(
                            operational_row.get(
                                "RECALC_REQUIRED_COUNT",
                                0,
                            )
                        )
                    )
                ),
                "Prevents stale official cost",
                (
                    "rgba(126,247,196,0.22)"
                    if as_float(
                        operational_row.get(
                            "RECALC_REQUIRED_COUNT",
                            0,
                        )
                    ) == 0
                    else "rgba(255,209,102,0.24)"
                ),
            )

        with monitor_cols[4]:
            kpi_card(
                "Cost Outcome Coverage",
                (
                    "—"
                    if is_missing(
                        operational_row.get(
                            "COST_ACTUAL_COVERAGE_PCT"
                        )
                    )
                    else (
                        f"{as_float(operational_row.get('COST_ACTUAL_COVERAGE_PCT')):.1f}%"
                    )
                ),
                "Verified realised costs",
                "rgba(177,151,252,0.22)",
            )

    snapshot_cols = st.columns([1.2, 1.2, 1.0])
    with snapshot_cols[0]:
        monitoring_actor = st.text_input(
            "Monitoring operator",
            value=actual_snowflake_user,
            disabled=True,
            key="phase11a_monitoring_actor",
            help=(
                "The UI uses the authenticated Snowflake user rather "
                "than a caller-entered actor name."
            ),
        )
    with snapshot_cols[1]:
        monitoring_run_id = st.text_input(
            "Monitoring run ID",
            value=f"MONITOR_{utc_stamp()}",
            key="phase11a_monitoring_run_id",
        )
    with snapshot_cols[2]:
        st.write("")
        st.write("")
        run_monitoring_clicked = st.button(
            "Run Monitoring Snapshot",
            type="primary",
            use_container_width=True,
            key="phase11a_run_monitoring",
        )

    if run_monitoring_clicked:
        try:
            monitoring_result = run_phase11a_monitoring(
                monitoring_run_id,
                monitoring_actor,
            )
            st.session_state[
                "last_phase11a_monitoring_result"
            ] = monitoring_result

            if monitoring_result.get("status") == "SUCCESS":
                note(
                    "Monitoring snapshot completed. "
                    f"Run status: "
                    f"{monitoring_result.get('run_status', 'N/A')}.",
                    "success",
                )
            else:
                note(
                    "Monitoring snapshot failed: "
                    f"{monitoring_result}",
                    "warning",
                )
        except Exception as exc:
            note(
                f"Monitoring snapshot failed: {exc}",
                "warning",
            )

    dashboard_df = load_phase11a_dashboard()

    section("Current Monitoring Alerts", "🚨")
    if dashboard_df.empty:
        note(
            "No monitoring metrics are available.",
            "soft",
        )
    else:
        st.dataframe(
            dashboard_df,
            use_container_width=True,
            hide_index=True,
        )

    section("Domain Performance Summary", "📊")
    domain_summary_df = load_phase11a_domain_summary()
    if domain_summary_df.empty:
        note(
            "No model-domain monitoring summary is available.",
            "soft",
        )
    else:
        st.dataframe(
            domain_summary_df,
            use_container_width=True,
            hide_index=True,
        )

    section("Record Verified Model Outcome", "✅")
    history_for_feedback = load_history(250)
    feedback_simulation_ids = (
        list(
            dict.fromkeys(
                history_for_feedback["SIMULATION_ID"]
                .dropna()
                .astype(str)
                .tolist()
            )
        )
        if not history_for_feedback.empty
        else []
    )

    if not feedback_simulation_ids:
        note(
            "No simulation is available for feedback entry.",
            "soft",
        )
    else:
        with st.form(
            "phase11a_model_outcome_form",
            clear_on_submit=False,
        ):
            model_form_cols = st.columns(4)

            with model_form_cols[0]:
                feedback_simulation_id = st.selectbox(
                    "Simulation",
                    feedback_simulation_ids,
                    key="phase11a_model_feedback_sim",
                )

            with model_form_cols[1]:
                feedback_domain = st.selectbox(
                    "Model domain",
                    ["CSS", "FMIS", "TDS", "BMCS"],
                    key="phase11a_feedback_domain",
                )

            with model_form_cols[2]:
                feedback_outcome_date = st.date_input(
                    "Outcome date",
                    key="phase11a_model_outcome_date",
                )

            with model_form_cols[3]:
                feedback_actor = st.text_input(
                    "Recorded by",
                    value=actual_snowflake_user,
                    disabled=True,
                    key="phase11a_model_actor",
                    help=(
                        "The authenticated Snowflake user is recorded "
                        "for this UI action."
                    ),
                )

            domain_defaults = {
                "CSS": 0.06,
                "FMIS": 1.05,
                "TDS": 1.40,
                "BMCS": 1.0,
            }

            if feedback_domain == "BMCS":
                mapping_result = st.selectbox(
                    "Was the KMAT mapping correct?",
                    ["Correct", "Incorrect"],
                    key="phase11a_bmcs_mapping_result",
                )
                feedback_numeric_value = None
                feedback_mapping_flag = (
                    mapping_result == "Correct"
                )
                feedback_text_status = (
                    "CORRECT_MAPPING"
                    if feedback_mapping_flag
                    else "INCORRECT_MAPPING"
                )
            else:
                feedback_numeric_value = st.number_input(
                    "Verified actual numeric value",
                    min_value=0.0,
                    value=float(
                        domain_defaults[feedback_domain]
                    ),
                    step=0.01,
                    format="%.6f",
                    key="phase11a_model_numeric_value",
                )
                feedback_mapping_flag = None
                feedback_text_status = st.text_input(
                    "Actual status or label",
                    value="VERIFIED_ACTUAL",
                    key="phase11a_model_text_status",
                )

            feedback_source = st.selectbox(
                "Outcome source",
                [
                    "ENGINEERING_ACTUAL",
                    "QUALITY_ACTUAL",
                    "ERP_ACTUAL",
                    "SUPPLIER_ACTUAL",
                    "ENGINEER_REVIEW",
                    "MANUAL_VALIDATION",
                ],
                key="phase11a_model_source",
            )

            feedback_evidence = st.text_input(
                "Evidence reference",
                value="",
                key="phase11a_model_evidence",
            )

            feedback_notes = st.text_area(
                "Outcome notes",
                value="",
                key="phase11a_model_notes",
            )

            model_submit = st.form_submit_button(
                "Record Model Outcome",
                type="primary",
                use_container_width=True,
            )

        if model_submit:
            outcome_id = (
                f"{feedback_domain}_ACTUAL_"
                f"{feedback_simulation_id}_"
                f"{utc_stamp()}"
            )
            try:
                model_outcome_result = (
                    record_model_actual_outcome(
                        outcome_id=outcome_id,
                        simulation_id=feedback_simulation_id,
                        model_domain=feedback_domain,
                        outcome_date=feedback_outcome_date,
                        actual_numeric_value=(
                            feedback_numeric_value
                        ),
                        actual_text_status=(
                            feedback_text_status
                        ),
                        actual_mapping_correct_flag=(
                            feedback_mapping_flag
                        ),
                        outcome_source=feedback_source,
                        evidence_reference=feedback_evidence,
                        notes=feedback_notes,
                        recorded_by=feedback_actor,
                    )
                )

                if (
                    model_outcome_result.get("status")
                    == "SUCCESS"
                ):
                    note(
                        f"Recorded {feedback_domain} actual "
                        f"outcome for {feedback_simulation_id}.",
                        "success",
                    )
                else:
                    note(
                        "Model outcome was not recorded: "
                        f"{model_outcome_result}",
                        "warning",
                    )
            except Exception as exc:
                note(
                    f"Model outcome entry failed: {exc}",
                    "warning",
                )

        section("Record Verified Realised Cost", "💰")

        with st.form(
            "phase11a_cost_outcome_form",
            clear_on_submit=False,
        ):
            cost_form_cols = st.columns(3)

            with cost_form_cols[0]:
                cost_feedback_simulation = st.selectbox(
                    "Cost simulation",
                    feedback_simulation_ids,
                    key="phase11a_cost_feedback_sim",
                )

            with cost_form_cols[1]:
                cost_outcome_date = st.date_input(
                    "Cost outcome date",
                    key="phase11a_cost_outcome_date",
                )

            with cost_form_cols[2]:
                cost_feedback_actor = st.text_input(
                    "Cost recorded by",
                    value=actual_snowflake_user,
                    disabled=True,
                    key="phase11a_cost_actor",
                    help=(
                        "The authenticated Snowflake user is recorded "
                        "for this UI action."
                    ),
                )

            cost_value_cols = st.columns(3)

            with cost_value_cols[0]:
                actual_total_cost = st.number_input(
                    "Actual total cost (USD)",
                    min_value=0.0,
                    value=0.0,
                    step=100.0,
                    key="phase11a_actual_total_cost",
                )

            with cost_value_cols[1]:
                actual_final_price = st.number_input(
                    "Actual final price (USD)",
                    min_value=0.0,
                    value=0.0,
                    step=100.0,
                    key="phase11a_actual_final_price",
                )

            with cost_value_cols[2]:
                cost_source = st.selectbox(
                    "Cost source",
                    [
                        "ERP_ACTUAL",
                        "FINANCE_ACTUAL",
                        "SUPPLIER_ACTUAL",
                        "MANUAL_VALIDATION",
                    ],
                    key="phase11a_cost_source",
                )

            with st.expander(
                "Optional realised cost breakdown",
                expanded=False,
            ):
                breakdown_cols = st.columns(4)
                with breakdown_cols[0]:
                    actual_material_cost = st.number_input(
                        "Material",
                        min_value=0.0,
                        value=0.0,
                        step=100.0,
                        key="phase11a_actual_material",
                    )
                with breakdown_cols[1]:
                    actual_labor_cost = st.number_input(
                        "Labor",
                        min_value=0.0,
                        value=0.0,
                        step=50.0,
                        key="phase11a_actual_labor",
                    )
                with breakdown_cols[2]:
                    actual_machine_cost = st.number_input(
                        "Machine",
                        min_value=0.0,
                        value=0.0,
                        step=50.0,
                        key="phase11a_actual_machine",
                    )
                with breakdown_cols[3]:
                    actual_overhead_cost = st.number_input(
                        "Overhead",
                        min_value=0.0,
                        value=0.0,
                        step=50.0,
                        key="phase11a_actual_overhead",
                    )

            cost_evidence = st.text_input(
                "Cost evidence reference",
                value="",
                key="phase11a_cost_evidence",
            )

            cost_notes = st.text_area(
                "Cost outcome notes",
                value="",
                key="phase11a_cost_notes",
            )

            cost_submit = st.form_submit_button(
                "Record Realised Cost",
                type="primary",
                use_container_width=True,
            )

        if cost_submit:
            if actual_total_cost <= 0:
                note(
                    "Actual total cost must be greater than zero "
                    "before recording the realised cost.",
                    "warning",
                )
            else:
                cost_outcome_id = (
                    f"COST_ACTUAL_"
                    f"{cost_feedback_simulation}_"
                    f"{utc_stamp()}"
                )

                try:
                    cost_outcome_result = (
                        record_cost_actual_outcome(
                            cost_outcome_id=(
                                cost_outcome_id
                            ),
                            simulation_id=(
                                cost_feedback_simulation
                            ),
                            outcome_date=cost_outcome_date,
                            actual_material_cost=(
                                actual_material_cost
                                if actual_material_cost > 0
                                else None
                            ),
                            actual_labor_cost=(
                                actual_labor_cost
                                if actual_labor_cost > 0
                                else None
                            ),
                            actual_machine_cost=(
                                actual_machine_cost
                                if actual_machine_cost > 0
                                else None
                            ),
                            actual_overhead_cost=(
                                actual_overhead_cost
                                if actual_overhead_cost > 0
                                else None
                            ),
                            actual_total_cost=(
                                actual_total_cost
                            ),
                            actual_final_price=(
                                actual_final_price
                                if actual_final_price > 0
                                else None
                            ),
                            outcome_source=cost_source,
                            evidence_reference=cost_evidence,
                            notes=cost_notes,
                            recorded_by=cost_feedback_actor,
                        )
                    )

                    if (
                        cost_outcome_result.get("status")
                        == "SUCCESS"
                    ):
                        note(
                            f"Recorded realised cost for "
                            f"{cost_feedback_simulation}.",
                            "success",
                        )
                    else:
                        note(
                            "Realised cost was not recorded: "
                            f"{cost_outcome_result}",
                            "warning",
                        )
                except Exception as exc:
                    note(
                        f"Cost outcome entry failed: {exc}",
                        "warning",
                    )

        section("Simulation Feedback Detail", "🔬")
        feedback_detail_sim = st.selectbox(
            "Feedback detail simulation",
            feedback_simulation_ids,
            key="phase11a_feedback_detail_sim",
        )

        model_feedback_df = load_phase11a_model_feedback(
            feedback_detail_sim
        )
        cost_feedback_df = load_phase11a_cost_feedback(
            feedback_detail_sim
        )

        feedback_tabs = st.tabs(
            [
                "Model Feedback",
                "Cost Feedback",
                "Monitoring Runs",
            ]
        )

        with feedback_tabs[0]:
            st.dataframe(
                model_feedback_df,
                use_container_width=True,
                hide_index=True,
            )

        with feedback_tabs[1]:
            st.dataframe(
                cost_feedback_df,
                use_container_width=True,
                hide_index=True,
            )

        with feedback_tabs[2]:
            monitoring_runs_df = load_phase11a_runs(50)
            st.dataframe(
                monitoring_runs_df,
                use_container_width=True,
                hide_index=True,
            )