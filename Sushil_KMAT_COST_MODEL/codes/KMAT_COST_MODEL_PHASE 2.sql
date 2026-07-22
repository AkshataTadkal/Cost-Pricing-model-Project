--Using the same warehouse as used in Phase 1
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

--Creating the Snowpark python procedure 
CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION(SIMULATION_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS
$$
import json
from datetime import datetime


DB_NAME = "KMAT_COST_MODEL_DB"


def sql_escape(value):
    """
    Small helper to safely place simple string values into SQL literals.
    For this project, SIMULATION_ID values are controlled sample IDs.
    """
    if value is None:
        return ""
    return str(value).replace("'", "''")


def to_float(value, default=0.0):
    """
    Convert Snowflake numeric/NULL values into Python float.
    NULL becomes default.
    """
    if value is None:
        return default
    try:
        return float(value)
    except Exception:
        return default


def parse_rule(rule_obj):
    """
    Snowflake VARIANT may arrive as dict-like object or string.
    Normalize it into a Python dict.
    """
    if rule_obj is None:
        return {}

    if isinstance(rule_obj, dict):
        return rule_obj

    if isinstance(rule_obj, str):
        try:
            return json.loads(rule_obj)
        except Exception:
            return {}

    try:
        return dict(rule_obj)
    except Exception:
        return {}


def normalize_text(value):
    """
    Normalize characteristic values for comparison.
    ENGINE = V8 and engine = v8 should match.
    """
    if value is None:
        return ""
    return str(value).strip().upper()


def evaluate_rule(rule_obj, selections):
    """
    Evaluate JSON dependency rules.

    Supported Version 1 rule formats:

    1. DEFAULT rule:
       {"type": "DEFAULT"}

    2. Simple equality:
       {"characteristic": "ENGINE", "operator": "=", "value": "V8"}

    3. Not equal:
       {"characteristic": "ENGINE", "operator": "!=", "value": "V6"}

    4. IN list:
       {"characteristic": "ENGINE", "operator": "IN", "value": ["V6", "V8"]}

    5. AND rule:
       {"all": [rule1, rule2]}

    6. OR rule:
       {"any": [rule1, rule2]}
    """
    rule = parse_rule(rule_obj)

    if not rule:
        return False

    rule_type = normalize_text(rule.get("type"))
    if rule_type == "DEFAULT":
        return True

    if "all" in rule:
        return all(evaluate_rule(child_rule, selections) for child_rule in rule.get("all", []))

    if "any" in rule:
        return any(evaluate_rule(child_rule, selections) for child_rule in rule.get("any", []))

    characteristic = normalize_text(rule.get("characteristic"))
    operator = normalize_text(rule.get("operator", "="))
    expected_value = rule.get("value")

    if characteristic == "":
        return False

    actual_value = normalize_text(selections.get(characteristic))

    if operator in ("=", "=="):
        return actual_value == normalize_text(expected_value)

    if operator in ("!=", "<>"):
        return actual_value != normalize_text(expected_value)

    if operator == "IN":
        if isinstance(expected_value, list):
            expected_values = [normalize_text(v) for v in expected_value]
        else:
            expected_values = [normalize_text(expected_value)]
        return actual_value in expected_values

    return False


def append_rows(session, table_name_parts, rows, schema):
    """
    Append rows into a Snowflake table only when rows exist.
    """
    if not rows:
        return

    df = session.create_dataframe(rows, schema=schema)
    df.write.mode("append").save_as_table(table_name_parts)


def run(session, SIMULATION_ID):
    sim_id = sql_escape(SIMULATION_ID)
    calculated_at = datetime.utcnow()

    # ------------------------------------------------------------
    # 1. Validate simulation header
    # ------------------------------------------------------------
    header_rows = session.sql(f"""
        SELECT
            SIMULATION_ID,
            KMAT_ID,
            CUSTOMER_ID,
            SCENARIO_NAME
        FROM {DB_NAME}.CORE_INPUT.SIMULATION_HEADER
        WHERE SIMULATION_ID = '{sim_id}'
    """).collect()

    if len(header_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"Simulation ID {SIMULATION_ID} not found in CORE_INPUT.SIMULATION_HEADER"
        })

    header = header_rows[0]
    kmat_id = header["KMAT_ID"]

    # ------------------------------------------------------------
    # 2. Read simulation parameters
    # ------------------------------------------------------------
    param_rows = session.sql(f"""
        SELECT
            COALESCE(MATERIAL_COST_MULTIPLIER, 1.00) AS MATERIAL_COST_MULTIPLIER,
            COALESCE(LABOR_RATE_MULTIPLIER, 1.00) AS LABOR_RATE_MULTIPLIER,
            COALESCE(MACHINE_RATE_MULTIPLIER, 1.00) AS MACHINE_RATE_MULTIPLIER,
            COALESCE(OVERHEAD_MULTIPLIER, 1.00) AS OVERHEAD_MULTIPLIER,
            COALESCE(TARGET_MARGIN_PCT, 0.35) AS TARGET_MARGIN_PCT,
            COALESCE(FLOOR_MARKUP_PCT, 0.10) AS FLOOR_MARKUP_PCT,
            COALESCE(CEILING_MARKUP_PCT, 0.60) AS CEILING_MARKUP_PCT
        FROM {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS
        WHERE SIMULATION_ID = '{sim_id}'
    """).collect()

    if len(param_rows) == 0:
        material_multiplier = 1.00
        labor_multiplier = 1.00
        machine_multiplier = 1.00
        overhead_multiplier = 1.00
        target_margin_pct = 0.35
        floor_markup_pct = 0.10
        ceiling_markup_pct = 0.60
    else:
        params = param_rows[0]
        material_multiplier = to_float(params["MATERIAL_COST_MULTIPLIER"], 1.00)
        labor_multiplier = to_float(params["LABOR_RATE_MULTIPLIER"], 1.00)
        machine_multiplier = to_float(params["MACHINE_RATE_MULTIPLIER"], 1.00)
        overhead_multiplier = to_float(params["OVERHEAD_MULTIPLIER"], 1.00)
        target_margin_pct = to_float(params["TARGET_MARGIN_PCT"], 0.35)
        floor_markup_pct = to_float(params["FLOOR_MARKUP_PCT"], 0.10)
        ceiling_markup_pct = to_float(params["CEILING_MARKUP_PCT"], 0.60)

    # ------------------------------------------------------------
    # 3. Read selected characteristics into Python dictionary
    # ------------------------------------------------------------
    selection_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            SELECTED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        WHERE SIMULATION_ID = '{sim_id}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
    """).collect()

    selections = {}
    for row in selection_rows:
        selections[normalize_text(row["CHARACTERISTIC_NAME"])] = normalize_text(row["SELECTED_VALUE"])

    # ------------------------------------------------------------
    # 4. Clear existing output for same simulation
    # ------------------------------------------------------------
    output_tables = [
        "CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS",
        "CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS",
        "CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS",
        "CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY"
    ]

    for table_name in output_tables:
        session.sql(f"""
            DELETE FROM {DB_NAME}.{table_name}
            WHERE SIMULATION_ID = '{sim_id}'
        """).collect()

    # ------------------------------------------------------------
    # 5. Evaluate Super BOM component rules
    # ------------------------------------------------------------
    bom_rows = session.sql(f"""
        SELECT
            bom.KMAT_ID,
            bom.COMPONENT_ID,
            bom.COMPONENT_DESCRIPTION,
            bom.QUANTITY,
            bom.UOM,
            bom.RULE_ID,
            bom.IS_BULK_MATERIAL,
            bom.COST_COMPONENT_GROUP,
            dr.RULE_JSON,
            mc.ITEM_ID AS COST_ITEM_ID,
            mc.STANDARD_COST_USD
        FROM {DB_NAME}.CORE_INPUT.KMAT_SUPER_BOM bom
        JOIN {DB_NAME}.CORE_INPUT.DEPENDENCY_RULES dr
            ON bom.RULE_ID = dr.RULE_ID
        LEFT JOIN {DB_NAME}.CORE_INPUT.MATERIAL_COSTS mc
            ON bom.COMPONENT_ID = mc.ITEM_ID
        WHERE bom.KMAT_ID = '{sql_escape(kmat_id)}'
    """).collect()

    component_output_rows = []
    material_total = 0.0
    selected_component_count = 0
    missing_material_cost_count = 0

    for row in bom_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_component_count += 1

            quantity = to_float(row["QUANTITY"], 0.0)

            cost_missing = row["COST_ITEM_ID"] is None or row["STANDARD_COST_USD"] is None
            if cost_missing:
                missing_material_cost_count += 1

            # COALESCE(cost, 0) behavior
            standard_cost = to_float(row["STANDARD_COST_USD"], 0.0)

            line_material_cost = quantity * standard_cost * material_multiplier
            material_total += line_material_cost

            component_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                row["COMPONENT_ID"],
                row["COMPONENT_DESCRIPTION"],
                quantity,
                row["UOM"],
                row["RULE_ID"],
                bool(row["IS_BULK_MATERIAL"]),
                row["COST_COMPONENT_GROUP"],
                standard_cost,
                line_material_cost,
                bool(cost_missing),
                calculated_at
            ))

    append_rows(
        session,
        [DB_NAME, "CORE_OUTPUT", "KMAT_CONFIGURED_COMPONENT_COSTS"],
        component_output_rows,
        [
            "SIMULATION_ID",
            "KMAT_ID",
            "COMPONENT_ID",
            "COMPONENT_DESCRIPTION",
            "QUANTITY",
            "UOM",
            "RULE_ID",
            "IS_BULK_MATERIAL",
            "COST_COMPONENT_GROUP",
            "STANDARD_COST_USD",
            "LINE_MATERIAL_COST_USD",
            "COST_MISSING_FLAG",
            "CALCULATED_AT"
        ]
    )

    # ------------------------------------------------------------
    # 6. Evaluate Super Routing operation rules
    # ------------------------------------------------------------
    routing_rows = session.sql(f"""
        SELECT
            rt.KMAT_ID,
            rt.OPERATION_ID,
            rt.OPERATION_DESCRIPTION,
            rt.WORK_CENTER_ID,
            rt.LABOR_HOURS,
            rt.MACHINE_HOURS,
            rt.RULE_ID,
            dr.RULE_JSON,
            wr.LABOR_RATE_USD_PER_HOUR,
            wr.MACHINE_RATE_USD_PER_HOUR
        FROM {DB_NAME}.CORE_INPUT.KMAT_SUPER_ROUTING rt
        JOIN {DB_NAME}.CORE_INPUT.DEPENDENCY_RULES dr
            ON rt.RULE_ID = dr.RULE_ID
        LEFT JOIN {DB_NAME}.CORE_INPUT.WORK_CENTER_RATES wr
            ON rt.WORK_CENTER_ID = wr.WORK_CENTER_ID
        WHERE rt.KMAT_ID = '{sql_escape(kmat_id)}'
    """).collect()

    operation_output_rows = []
    labor_total = 0.0
    machine_total = 0.0
    selected_operation_count = 0

    for row in routing_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_operation_count += 1

            labor_hours = to_float(row["LABOR_HOURS"], 0.0)
            machine_hours = to_float(row["MACHINE_HOURS"], 0.0)

            labor_rate = to_float(row["LABOR_RATE_USD_PER_HOUR"], 0.0)
            machine_rate = to_float(row["MACHINE_RATE_USD_PER_HOUR"], 0.0)

            labor_cost = labor_hours * labor_rate * labor_multiplier
            machine_cost = machine_hours * machine_rate * machine_multiplier

            labor_total += labor_cost
            machine_total += machine_cost

            operation_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                row["OPERATION_ID"],
                row["OPERATION_DESCRIPTION"],
                row["WORK_CENTER_ID"],
                labor_hours,
                machine_hours,
                labor_rate,
                machine_rate,
                labor_cost,
                machine_cost,
                row["RULE_ID"],
                calculated_at
            ))

    append_rows(
        session,
        [DB_NAME, "CORE_OUTPUT", "KMAT_CONFIGURED_OPERATION_COSTS"],
        operation_output_rows,
        [
            "SIMULATION_ID",
            "KMAT_ID",
            "OPERATION_ID",
            "OPERATION_DESCRIPTION",
            "WORK_CENTER_ID",
            "LABOR_HOURS",
            "MACHINE_HOURS",
            "LABOR_RATE_USD_PER_HOUR",
            "MACHINE_RATE_USD_PER_HOUR",
            "LABOR_COST_USD",
            "MACHINE_COST_USD",
            "RULE_ID",
            "CALCULATED_AT"
        ]
    )

    # ------------------------------------------------------------
    # 7. Evaluate overhead rules
    # ------------------------------------------------------------
    overhead_rows = session.sql(f"""
        SELECT
            oh.KMAT_ID,
            oh.OVERHEAD_ID,
            oh.OVERHEAD_DESCRIPTION,
            oh.BASIS,
            oh.RATE_VALUE,
            oh.RULE_ID,
            dr.RULE_JSON
        FROM {DB_NAME}.CORE_INPUT.OVERHEAD_RATES oh
        JOIN {DB_NAME}.CORE_INPUT.DEPENDENCY_RULES dr
            ON oh.RULE_ID = dr.RULE_ID
        WHERE oh.KMAT_ID = '{sql_escape(kmat_id)}'
    """).collect()

    overhead_output_rows = []
    overhead_total = 0.0
    selected_overhead_count = 0

    for row in overhead_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_overhead_count += 1

            basis = normalize_text(row["BASIS"])
            rate_value = to_float(row["RATE_VALUE"], 0.0)

            if basis == "MATERIAL_PERCENT":
                overhead_cost = material_total * rate_value
            elif basis == "LABOR_PERCENT":
                overhead_cost = labor_total * rate_value
            elif basis == "MACHINE_PERCENT":
                overhead_cost = machine_total * rate_value
            elif basis == "TOTAL_COST_PERCENT":
                overhead_cost = (material_total + labor_total + machine_total) * rate_value
            elif basis == "FIXED":
                overhead_cost = rate_value
            else:
                overhead_cost = 0.0

            overhead_cost = overhead_cost * overhead_multiplier
            overhead_total += overhead_cost

            overhead_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                row["OVERHEAD_ID"],
                row["OVERHEAD_DESCRIPTION"],
                row["BASIS"],
                rate_value,
                overhead_cost,
                row["RULE_ID"],
                calculated_at
            ))

    append_rows(
        session,
        [DB_NAME, "CORE_OUTPUT", "KMAT_CONFIGURED_OVERHEAD_COSTS"],
        overhead_output_rows,
        [
            "SIMULATION_ID",
            "KMAT_ID",
            "OVERHEAD_ID",
            "OVERHEAD_DESCRIPTION",
            "BASIS",
            "RATE_VALUE",
            "OVERHEAD_COST_USD",
            "RULE_ID",
            "CALCULATED_AT"
        ]
    )

    # ------------------------------------------------------------
    # 8. Cost summary and pricing preview
    # ------------------------------------------------------------
    total_configured_cost = material_total + labor_total + machine_total + overhead_total

    floor_price = total_configured_cost * (1.0 + floor_markup_pct)
    target_price = total_configured_cost * (1.0 + target_margin_pct)
    ceiling_price = total_configured_cost * (1.0 + ceiling_markup_pct)

    summary_rows = [(
        SIMULATION_ID,
        kmat_id,
        material_total,
        labor_total,
        machine_total,
        overhead_total,
        total_configured_cost,
        floor_price,
        target_price,
        ceiling_price,
        calculated_at
    )]

    append_rows(
        session,
        [DB_NAME, "CORE_OUTPUT", "KMAT_CONFIGURED_COST_SUMMARY"],
        summary_rows,
        [
            "SIMULATION_ID",
            "KMAT_ID",
            "MATERIAL_COST_USD",
            "LABOR_COST_USD",
            "MACHINE_COST_USD",
            "OVERHEAD_COST_USD",
            "TOTAL_CONFIGURED_COST_USD",
            "FLOOR_PRICE_USD",
            "TARGET_PRICE_USD",
            "CEILING_PRICE_USD",
            "CALCULATED_AT"
        ]
    )

    return json.dumps({
        "status": "SUCCESS",
        "simulation_id": SIMULATION_ID,
        "kmat_id": kmat_id,
        "selected_components": selected_component_count,
        "selected_operations": selected_operation_count,
        "selected_overheads": selected_overhead_count,
        "missing_material_cost_count": missing_material_cost_count,
        "material_cost_usd": round(material_total, 4),
        "labor_cost_usd": round(labor_total, 4),
        "machine_cost_usd": round(machine_total, 4),
        "overhead_cost_usd": round(overhead_total, 4),
        "total_configured_cost_usd": round(total_configured_cost, 4),
        "floor_price_usd": round(floor_price, 4),
        "target_price_usd": round(target_price, 4),
        "ceiling_price_usd": round(ceiling_price, 4)
    })
$$;

SHOW PROCEDURES LIKE 'RUN_KMAT_COST_SIMULATION' IN SCHEMA KMAT_COST_MODEL_DB.CORE_INTERNAL;

CALL KMAT_COST_MODEL_DB.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('SIM_001');

--Validate component output
SELECT
    SIMULATION_ID,
    KMAT_ID,
    COMPONENT_ID,
    COMPONENT_DESCRIPTION,
    QUANTITY,
    UOM,
    RULE_ID,
    IS_BULK_MATERIAL,
    COST_COMPONENT_GROUP,
    STANDARD_COST_USD,
    LINE_MATERIAL_COST_USD,
    COST_MISSING_FLAG
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
WHERE SIMULATION_ID = 'SIM_001'
ORDER BY COST_COMPONENT_GROUP, COMPONENT_ID;

--Validate Material Cost
SELECT
    SIMULATION_ID,
    KMAT_ID,
    SUM(LINE_MATERIAL_COST_USD) AS TOTAL_MATERIAL_COST_USD
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
WHERE SIMULATION_ID = 'SIM_001'
GROUP BY SIMULATION_ID, KMAT_ID;

--Validate Operation Output
SELECT
    SIMULATION_ID,
    KMAT_ID,
    OPERATION_ID,
    OPERATION_DESCRIPTION,
    WORK_CENTER_ID,
    LABOR_HOURS,
    MACHINE_HOURS,
    LABOR_RATE_USD_PER_HOUR,
    MACHINE_RATE_USD_PER_HOUR,
    LABOR_COST_USD,
    MACHINE_COST_USD,
    RULE_ID
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
WHERE SIMULATION_ID = 'SIM_001'
ORDER BY OPERATION_ID;

--Validate Labour and Machine totals
SELECT
    SIMULATION_ID,
    KMAT_ID,
    SUM(LABOR_COST_USD) AS TOTAL_LABOR_COST_USD,
    SUM(MACHINE_COST_USD) AS TOTAL_MACHINE_COST_USD
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
WHERE SIMULATION_ID = 'SIM_001'
GROUP BY SIMULATION_ID, KMAT_ID;

--Validate Overhead output
SELECT
    SIMULATION_ID,
    KMAT_ID,
    OVERHEAD_ID,
    OVERHEAD_DESCRIPTION,
    BASIS,
    RATE_VALUE,
    OVERHEAD_COST_USD,
    RULE_ID
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
WHERE SIMULATION_ID = 'SIM_001'
ORDER BY OVERHEAD_ID;

--Validate Final Summary
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
    CEILING_PRICE_USD
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID = 'SIM_001';

--Confirm missing Cost
SELECT
    COMPONENT_ID,
    IS_BULK_MATERIAL,
    STANDARD_COST_USD,
    LINE_MATERIAL_COST_USD,
    COST_MISSING_FLAG
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
WHERE SIMULATION_ID = 'SIM_001'
  AND COST_MISSING_FLAG = TRUE;

--Confirm bulk material inclusion
SELECT
    COMPONENT_ID,
    IS_BULK_MATERIAL,
    STANDARD_COST_USD,
    LINE_MATERIAL_COST_USD
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
WHERE SIMULATION_ID = 'SIM_001'
  AND IS_BULK_MATERIAL = TRUE
ORDER BY COMPONENT_ID;

--Create a simple results view
CREATE OR REPLACE VIEW KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SIMULATION_RESULT AS
SELECT
    s.SIMULATION_ID,
    s.KMAT_ID,
    h.CUSTOMER_ID,
    h.SCENARIO_NAME,
    s.MATERIAL_COST_USD,
    s.LABOR_COST_USD,
    s.MACHINE_COST_USD,
    s.OVERHEAD_COST_USD,
    s.TOTAL_CONFIGURED_COST_USD,
    s.FLOOR_PRICE_USD,
    s.TARGET_PRICE_USD,
    s.CEILING_PRICE_USD,
    s.CALCULATED_AT
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY s
JOIN KMAT_COST_MODEL_DB.CORE_INPUT.SIMULATION_HEADER h
    ON s.SIMULATION_ID = h.SIMULATION_ID
   AND s.KMAT_ID = h.KMAT_ID;

SELECT * FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SIMULATION_RESULT
WHERE SIMULATION_ID = 'SIM_001';

--Create a component detail view 
CREATE OR REPLACE VIEW KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SELECTED_COMPONENTS AS
SELECT
    SIMULATION_ID,
    KMAT_ID,
    COMPONENT_ID,
    COMPONENT_DESCRIPTION,
    QUANTITY,
    UOM,
    IS_BULK_MATERIAL,
    COST_COMPONENT_GROUP,
    STANDARD_COST_USD,
    LINE_MATERIAL_COST_USD,
    COST_MISSING_FLAG
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS;

SELECT * FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SELECTED_COMPONENTS
WHERE SIMULATION_ID = 'SIM_001'
ORDER BY COST_COMPONENT_GROUP, COMPONENT_ID;

--Create a Operation Detail View 
CREATE OR REPLACE VIEW KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SELECTED_OPERATIONS AS
SELECT
    SIMULATION_ID,
    KMAT_ID,
    OPERATION_ID,
    OPERATION_DESCRIPTION,
    WORK_CENTER_ID,
    LABOR_HOURS,
    MACHINE_HOURS,
    LABOR_RATE_USD_PER_HOUR,
    MACHINE_RATE_USD_PER_HOUR,
    LABOR_COST_USD,
    MACHINE_COST_USD
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS;

SELECT * FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.V_KMAT_SELECTED_OPERATIONS
WHERE SIMULATION_ID = 'SIM_001'
ORDER BY OPERATION_ID;