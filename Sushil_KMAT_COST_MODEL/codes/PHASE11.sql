-- Phase 11 ML monitoring policies, outcome recording, and metric evaluation
-- Co-authored with CoCo
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- ============================================================
-- PHASE 11A — PREFLIGHT AND EXACT OBJECT INVENTORY
--
-- All Phase 11A objects are deployed in:
--   KMAT_COST_MODEL_DB.CORE_ML
--
-- Existing official cost output:
--   KMAT_COST_MODEL_DB.CORE_OUTPUT
--
-- This script also shows the actual schema locations of the
-- governed V2 and V3 procedures. It does not assume a schema.
-- ============================================================


-- ------------------------------------------------------------
-- 1. DISPLAY ACTUAL GOVERNED PROCEDURE LOCATIONS
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'RUN_KMAT_COST_SIMULATION_GOVERNED_V2'
IN DATABASE KMAT_COST_MODEL_DB;

SHOW PROCEDURES LIKE
    'RUN_KMAT_COST_SIMULATION_GOVERNED_V3'
IN DATABASE KMAT_COST_MODEL_DB;


-- ------------------------------------------------------------
-- 2. REQUIRED OBJECT CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'TABLE'
        ),
        (
            'CORE_ML',
            'KMAT_COST_FACTOR_RESOLUTION_V1',
            'TABLE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_COST_FACTOR_RESOLUTION_CURRENT_V1',
            'VIEW'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'VIEW'
        ),
        (
            'CORE_ML',
            'ML_DECISION_RESULT_V1',
            'TABLE'
        ),
        (
            'CORE_ML',
            'ML_DECISION_OVERRIDE_V1',
            'TABLE'
        ),
        (
            'CORE_ML',
            'VW_ML_DECISION_POLICY_CURRENT_V1',
            'VIEW'
        ),
        (
            'CORE_OUTPUT',
            'KMAT_CONFIGURED_COST_SUMMARY',
            'TABLE'
        )
    AS required(
        SCHEMA_NAME,
        OBJECT_NAME,
        OBJECT_TYPE
    )
),
FOUND_OBJECTS AS (
    SELECT
        TABLE_SCHEMA AS SCHEMA_NAME,
        TABLE_NAME AS OBJECT_NAME,
        TABLE_TYPE AS OBJECT_TYPE
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.TABLES
)
SELECT
    required.SCHEMA_NAME,
    required.OBJECT_NAME,
    required.OBJECT_TYPE
FROM REQUIRED_OBJECTS required
LEFT JOIN FOUND_OBJECTS found
    ON required.SCHEMA_NAME = found.SCHEMA_NAME
   AND required.OBJECT_NAME = found.OBJECT_NAME
WHERE found.OBJECT_NAME IS NULL
ORDER BY
    required.SCHEMA_NAME,
    required.OBJECT_NAME;


-- ------------------------------------------------------------
-- 3. REQUIRED COLUMN CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'SIMULATION_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'KMAT_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'RFQ_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'OFFICIAL_COST_CALCULATED_AT'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'CSS_DECISION_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'CSS_RAW_ML_VALUE'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'CSS_MODEL_NAME'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'CSS_MODEL_VERSION'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'FMIS_DECISION_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'FMIS_MODEL_NAME'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'TDS_DECISION_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'TDS_MODEL_NAME'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'BMCS_DECISION_ID'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'BMCS_RAW_CORRECT_MAPPING_PROBABILITY'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD'
        ),
        (
            'CORE_ML',
            'KMAT_GOVERNED_COST_INPUT_V2',
            'OFFICIAL_TARGET_PRICE_USD'
        ),

        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'CSS_RULE_VALUE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'CSS_ML_VALUE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'RESOLVED_SCRAP_RATE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'FMIS_RULE_VALUE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'RESOLVED_FMIS_MULTIPLIER'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'TDS_RULE_VALUE'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'RESOLVED_TDS_FACTOR'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'RESOLVED_BMCS_STATUS'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'SAFETY_GATE_PASS_FLAG'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'COST_ENGINE_CONSUMPTION_ALLOWED_FLAG'
        ),
        (
            'CORE_ML',
            'VW_KMAT_PHASE10B_HIERARCHY_V1',
            'OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG'
        )
    AS required(
        SCHEMA_NAME,
        OBJECT_NAME,
        COLUMN_NAME
    )
)
SELECT
    required.SCHEMA_NAME,
    required.OBJECT_NAME,
    required.COLUMN_NAME
FROM REQUIRED_COLUMNS required
LEFT JOIN KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.COLUMNS found
    ON required.SCHEMA_NAME = found.TABLE_SCHEMA
   AND required.OBJECT_NAME = found.TABLE_NAME
   AND required.COLUMN_NAME = found.COLUMN_NAME
WHERE found.COLUMN_NAME IS NULL
ORDER BY
    required.SCHEMA_NAME,
    required.OBJECT_NAME,
    required.COLUMN_NAME;


-- ------------------------------------------------------------
-- 4. PHASE 10B SAFETY CHECK
--
-- Expected for SIM_001:
--   PHASE10B_READY_ROWS = 1
--   PHASE10B_INVALID_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS PHASE10B_READY_ROWS,

    COUNT_IF(
        SAFETY_GATE_PASS_FLAG = FALSE
        OR COST_ENGINE_CONSUMPTION_ALLOWED_FLAG = FALSE
        OR OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG = TRUE
    ) AS PHASE10B_INVALID_ROWS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE10B_HIERARCHY_V1

WHERE SIMULATION_ID = 'SIM_001';

-- ============================================================
-- PHASE 11A — MONITORING AND ACTUAL-OUTCOME FEEDBACK
--
-- Exact deployment schema:
--   KMAT_COST_MODEL_DB.CORE_ML
--
-- Official cost output remains:
--   KMAT_COST_MODEL_DB.CORE_OUTPUT
--
-- This phase does not change:
--   * deterministic cost formulas,
--   * Phase 9 decision authority,
--   * Phase 10 resolved factors,
--   * official cost or price.
-- ============================================================


-- ============================================================
-- 1. MODEL ACTUAL OUTCOMES
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_MODEL_ACTUAL_OUTCOME_V1 (
        OUTCOME_ID VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR NOT NULL,
        KMAT_ID VARCHAR NOT NULL,
        RFQ_ID VARCHAR,
        MODEL_DOMAIN VARCHAR NOT NULL,

        OUTCOME_DATE DATE NOT NULL,

        ACTUAL_NUMERIC_VALUE FLOAT,
        ACTUAL_TEXT_STATUS VARCHAR,
        ACTUAL_MAPPING_CORRECT_FLAG BOOLEAN,

        OUTCOME_SOURCE VARCHAR NOT NULL,
        EVIDENCE_REFERENCE VARCHAR,
        NOTES VARCHAR,

        IS_ACTIVE BOOLEAN NOT NULL DEFAULT TRUE,

        RECORDED_BY VARCHAR NOT NULL,
        RECORDED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP(),

        UPDATED_BY VARCHAR NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP()
    );


-- ============================================================
-- 2. REALISED COST OUTCOMES
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_ACTUAL_OUTCOME_V1 (
        COST_OUTCOME_ID VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR NOT NULL,
        KMAT_ID VARCHAR NOT NULL,
        RFQ_ID VARCHAR,

        OUTCOME_DATE DATE NOT NULL,

        ACTUAL_MATERIAL_COST_USD FLOAT,
        ACTUAL_LABOR_COST_USD FLOAT,
        ACTUAL_MACHINE_COST_USD FLOAT,
        ACTUAL_OVERHEAD_COST_USD FLOAT,

        ACTUAL_TOTAL_COST_USD FLOAT NOT NULL,
        ACTUAL_FINAL_PRICE_USD FLOAT,

        OUTCOME_SOURCE VARCHAR NOT NULL,
        EVIDENCE_REFERENCE VARCHAR,
        NOTES VARCHAR,

        IS_ACTIVE BOOLEAN NOT NULL DEFAULT TRUE,

        RECORDED_BY VARCHAR NOT NULL,
        RECORDED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP(),

        UPDATED_BY VARCHAR NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP()
    );


-- ============================================================
-- 3. APPEND-ONLY OUTCOME AUDIT
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 (
        AUDIT_EVENT_ID VARCHAR NOT NULL,
        AUDIT_EVENT_TYPE VARCHAR NOT NULL,

        OUTCOME_ID VARCHAR NOT NULL,
        OUTCOME_TYPE VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR NOT NULL,
        KMAT_ID VARCHAR NOT NULL,
        RFQ_ID VARCHAR,
        MODEL_DOMAIN VARCHAR,

        OUTCOME_DATE DATE NOT NULL,

        ACTUAL_NUMERIC_VALUE FLOAT,
        ACTUAL_TEXT_STATUS VARCHAR,
        ACTUAL_MAPPING_CORRECT_FLAG BOOLEAN,

        ACTUAL_TOTAL_COST_USD FLOAT,
        ACTUAL_FINAL_PRICE_USD FLOAT,

        OUTCOME_SOURCE VARCHAR NOT NULL,
        EVIDENCE_REFERENCE VARCHAR,
        NOTES VARCHAR,

        EVENT_ACTOR VARCHAR NOT NULL,
        AUDITED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP()
    );


-- ============================================================
-- 4. MONITORING POLICY
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_MONITORING_POLICY_V1 (
        MONITORING_POLICY_ID VARCHAR NOT NULL,

        MODEL_DOMAIN VARCHAR NOT NULL,
        METRIC_KEY VARCHAR NOT NULL,
        METRIC_NAME VARCHAR NOT NULL,
        METRIC_UNIT VARCHAR NOT NULL,

        POLICY_VERSION VARCHAR NOT NULL,
        POLICY_STATUS VARCHAR NOT NULL,

        THRESHOLD_DIRECTION VARCHAR NOT NULL,
        WARNING_THRESHOLD FLOAT,
        CRITICAL_THRESHOLD FLOAT,
        MIN_SAMPLE_SIZE NUMBER NOT NULL,

        EFFECTIVE_FROM TIMESTAMP_NTZ NOT NULL,
        EFFECTIVE_TO TIMESTAMP_NTZ,

        APPROVED_BY VARCHAR,
        APPROVED_AT TIMESTAMP_NTZ,

        CREATED_BY VARCHAR
            DEFAULT CURRENT_USER(),
        CREATED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP(),

        UPDATED_BY VARCHAR
            DEFAULT CURRENT_USER(),
        UPDATED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP(),

        COMMENTS VARCHAR
    );


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_MONITORING_POLICY_V1 target

USING (
    SELECT *
    FROM VALUES
        (
            'CSS_ML_COVERAGE_V1',
            'CSS',
            'ML_DECISION_COVERAGE_PCT',
            'CSS ML Decision Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            80.0::FLOAT,
            50.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures CSS shadow-decision availability.'
        ),
        (
            'CSS_OUTCOME_COVERAGE_V1',
            'CSS',
            'MODEL_OUTCOME_COVERAGE_PCT',
            'CSS Actual Outcome Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            60.0::FLOAT,
            30.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures CSS actual-outcome availability.'
        ),
        (
            'CSS_FINAL_MAE_V1',
            'CSS',
            'FINAL_MAE',
            'CSS Final Mean Absolute Error',
            'RATE',
            'V1',
            'ACTIVE',
            'MAX',
            0.03::FLOAT,
            0.05::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Compares final governed scrap rate with actual scrap rate.'
        ),
        (
            'CSS_ML_MAE_V1',
            'CSS',
            'ML_MAE',
            'CSS ML Mean Absolute Error',
            'RATE',
            'V1',
            'ACTIVE',
            'MAX',
            0.03::FLOAT,
            0.05::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Advisory diagnostic for CSS ML recommendation.'
        ),

        (
            'FMIS_ML_COVERAGE_V1',
            'FMIS',
            'ML_DECISION_COVERAGE_PCT',
            'FMIS ML Decision Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            80.0::FLOAT,
            50.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures FMIS shadow-decision availability.'
        ),
        (
            'FMIS_OUTCOME_COVERAGE_V1',
            'FMIS',
            'MODEL_OUTCOME_COVERAGE_PCT',
            'FMIS Actual Outcome Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            60.0::FLOAT,
            30.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures FMIS actual-outcome availability.'
        ),
        (
            'FMIS_FINAL_MAE_V1',
            'FMIS',
            'FINAL_MAE',
            'FMIS Final Mean Absolute Error',
            'MULTIPLIER',
            'V1',
            'ACTIVE',
            'MAX',
            0.03::FLOAT,
            0.05::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Compares final multiplier with actual realised multiplier.'
        ),
        (
            'FMIS_ML_MAE_V1',
            'FMIS',
            'ML_MAE',
            'FMIS ML Mean Absolute Error',
            'MULTIPLIER',
            'V1',
            'ACTIVE',
            'MAX',
            0.03::FLOAT,
            0.05::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Advisory diagnostic for FMIS recommendation.'
        ),

        (
            'TDS_ML_COVERAGE_V1',
            'TDS',
            'ML_DECISION_COVERAGE_PCT',
            'TDS ML Decision Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            80.0::FLOAT,
            50.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures TDS shadow-decision availability.'
        ),
        (
            'TDS_OUTCOME_COVERAGE_V1',
            'TDS',
            'MODEL_OUTCOME_COVERAGE_PCT',
            'TDS Actual Outcome Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            60.0::FLOAT,
            30.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures TDS actual-outcome availability.'
        ),
        (
            'TDS_FINAL_MAE_V1',
            'TDS',
            'FINAL_MAE',
            'TDS Final Mean Absolute Error',
            'FACTOR',
            'V1',
            'ACTIVE',
            'MAX',
            0.15::FLOAT,
            0.25::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Compares final tooling factor with actual realised factor.'
        ),
        (
            'TDS_ML_MAE_V1',
            'TDS',
            'ML_MAE',
            'TDS ML Mean Absolute Error',
            'FACTOR',
            'V1',
            'ACTIVE',
            'MAX',
            0.15::FLOAT,
            0.25::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Advisory diagnostic for TDS recommendation.'
        ),

        (
            'BMCS_ML_COVERAGE_V1',
            'BMCS',
            'ML_DECISION_COVERAGE_PCT',
            'BMCS ML Decision Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            80.0::FLOAT,
            50.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Only RFQ/BMCS-applicable simulations enter the denominator.'
        ),
        (
            'BMCS_OUTCOME_COVERAGE_V1',
            'BMCS',
            'MODEL_OUTCOME_COVERAGE_PCT',
            'BMCS Actual Outcome Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            60.0::FLOAT,
            30.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures reviewed mapping-outcome availability.'
        ),
        (
            'BMCS_BRIER_V1',
            'BMCS',
            'BMCS_BRIER_SCORE',
            'BMCS Brier Score',
            'SCORE',
            'V1',
            'ACTIVE',
            'MAX',
            0.15::FLOAT,
            0.25::FLOAT,
            20,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Probability-calibration diagnostic only.'
        ),

        (
            'ALL_SAFETY_FAILURE_V1',
            'ALL',
            'SAFETY_FAILURE_COUNT',
            'Safety Gate Failures',
            'COUNT',
            'V1',
            'ACTIVE',
            'MAX',
            1.0::FLOAT,
            1.0::FLOAT,
            1,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Any safety failure is critical.'
        ),
        (
            'ALL_COST_BLOCKED_V1',
            'ALL',
            'COST_BLOCKED_COUNT',
            'Blocked Cost Contracts',
            'COUNT',
            'V1',
            'ACTIVE',
            'MAX',
            1.0::FLOAT,
            1.0::FLOAT,
            1,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Any blocked official contract is critical.'
        ),
        (
            'ALL_RECALC_REQUIRED_V1',
            'ALL',
            'RECALC_REQUIRED_COUNT',
            'Cost Recalculation Required',
            'COUNT',
            'V1',
            'ACTIVE',
            'MAX',
            1.0::FLOAT,
            1.0::FLOAT,
            1,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'A resolved factor must not be paired with stale cost.'
        ),
        (
            'ALL_COST_OUTCOME_COVERAGE_V1',
            'ALL',
            'COST_ACTUAL_COVERAGE_PCT',
            'Realised Cost Coverage',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MIN',
            60.0::FLOAT,
            30.0::FLOAT,
            5,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Measures availability of realised total cost.'
        ),
        (
            'ALL_COST_VARIANCE_V1',
            'ALL',
            'COST_ABS_VARIANCE_PCT',
            'Absolute Cost Variance',
            'PERCENT',
            'V1',
            'ACTIVE',
            'MAX',
            5.0::FLOAT,
            10.0::FLOAT,
            10,
            CURRENT_TIMESTAMP(),
            NULL::TIMESTAMP_NTZ,
            'SYSTEM_PHASE11A',
            CURRENT_TIMESTAMP(),
            'Compares official risk-adjusted cost with realised cost.'
        )
    AS policies(
        MONITORING_POLICY_ID,
        MODEL_DOMAIN,
        METRIC_KEY,
        METRIC_NAME,
        METRIC_UNIT,
        POLICY_VERSION,
        POLICY_STATUS,
        THRESHOLD_DIRECTION,
        WARNING_THRESHOLD,
        CRITICAL_THRESHOLD,
        MIN_SAMPLE_SIZE,
        EFFECTIVE_FROM,
        EFFECTIVE_TO,
        APPROVED_BY,
        APPROVED_AT,
        COMMENTS
    )
) source

ON target.MONITORING_POLICY_ID =
   source.MONITORING_POLICY_ID

WHEN MATCHED THEN UPDATE SET
    MODEL_DOMAIN = source.MODEL_DOMAIN,
    METRIC_KEY = source.METRIC_KEY,
    METRIC_NAME = source.METRIC_NAME,
    METRIC_UNIT = source.METRIC_UNIT,
    POLICY_VERSION = source.POLICY_VERSION,
    POLICY_STATUS = source.POLICY_STATUS,
    THRESHOLD_DIRECTION =
        source.THRESHOLD_DIRECTION,
    WARNING_THRESHOLD =
        source.WARNING_THRESHOLD,
    CRITICAL_THRESHOLD =
        source.CRITICAL_THRESHOLD,
    MIN_SAMPLE_SIZE =
        source.MIN_SAMPLE_SIZE,
    EFFECTIVE_FROM =
        source.EFFECTIVE_FROM,
    EFFECTIVE_TO =
        source.EFFECTIVE_TO,
    APPROVED_BY =
        source.APPROVED_BY,
    APPROVED_AT =
        source.APPROVED_AT,
    UPDATED_BY =
        CURRENT_USER(),
    UPDATED_AT =
        CURRENT_TIMESTAMP(),
    COMMENTS =
        source.COMMENTS

WHEN NOT MATCHED THEN INSERT (
    MONITORING_POLICY_ID,
    MODEL_DOMAIN,
    METRIC_KEY,
    METRIC_NAME,
    METRIC_UNIT,

    POLICY_VERSION,
    POLICY_STATUS,

    THRESHOLD_DIRECTION,
    WARNING_THRESHOLD,
    CRITICAL_THRESHOLD,
    MIN_SAMPLE_SIZE,

    EFFECTIVE_FROM,
    EFFECTIVE_TO,

    APPROVED_BY,
    APPROVED_AT,

    COMMENTS
)
VALUES (
    source.MONITORING_POLICY_ID,
    source.MODEL_DOMAIN,
    source.METRIC_KEY,
    source.METRIC_NAME,
    source.METRIC_UNIT,

    source.POLICY_VERSION,
    source.POLICY_STATUS,

    source.THRESHOLD_DIRECTION,
    source.WARNING_THRESHOLD,
    source.CRITICAL_THRESHOLD,
    source.MIN_SAMPLE_SIZE,

    source.EFFECTIVE_FROM,
    source.EFFECTIVE_TO,

    source.APPROVED_BY,
    source.APPROVED_AT,

    source.COMMENTS
);


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_POLICY_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .KMAT_MONITORING_POLICY_V1
WHERE POLICY_STATUS = 'ACTIVE'
  AND EFFECTIVE_FROM <= CURRENT_TIMESTAMP()
  AND (
      EFFECTIVE_TO IS NULL
      OR EFFECTIVE_TO > CURRENT_TIMESTAMP()
  )
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        MODEL_DOMAIN,
        METRIC_KEY
    ORDER BY
        EFFECTIVE_FROM DESC,
        CREATED_AT DESC,
        MONITORING_POLICY_ID DESC
) = 1;


-- ============================================================
-- 5. RECORD MODEL ACTUAL OUTCOME
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RECORD_KMAT_MODEL_ACTUAL_OUTCOME_V1(
            P_OUTCOME_ID VARCHAR,
            P_SIMULATION_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_OUTCOME_DATE DATE,

            P_ACTUAL_NUMERIC_VALUE FLOAT,
            P_ACTUAL_TEXT_STATUS VARCHAR,
            P_ACTUAL_MAPPING_CORRECT_FLAG BOOLEAN,

            P_OUTCOME_SOURCE VARCHAR,
            P_EVIDENCE_REFERENCE VARCHAR,
            P_NOTES VARCHAR,
            P_RECORDED_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_SIMULATION_COUNT NUMBER DEFAULT 0;

    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;

    V_ACTUAL_NUMERIC_VALUE FLOAT;
    V_ACTUAL_TEXT_STATUS VARCHAR;

    V_AUDIT_EVENT_ID VARCHAR;
BEGIN
    IF (
        P_OUTCOME_ID IS NULL
        OR LENGTH(TRIM(P_OUTCOME_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OUTCOME_ID is required.''
        );
    END IF;

    IF (
        P_SIMULATION_ID IS NULL
        OR LENGTH(TRIM(P_SIMULATION_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_SIMULATION_ID is required.''
        );
    END IF;

    IF (
        P_MODEL_DOMAIN IS NULL
        OR UPPER(TRIM(P_MODEL_DOMAIN))
            NOT IN (
                ''CSS'',
                ''FMIS'',
                ''TDS'',
                ''BMCS''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_MODEL_DOMAIN must be CSS, FMIS, TDS, or BMCS.''
        );
    END IF;

    IF (P_OUTCOME_DATE IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OUTCOME_DATE is required.''
        );
    END IF;

    IF (
        P_OUTCOME_SOURCE IS NULL
        OR LENGTH(TRIM(P_OUTCOME_SOURCE)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OUTCOME_SOURCE is required.''
        );
    END IF;

    IF (
        P_RECORDED_BY IS NULL
        OR LENGTH(TRIM(P_RECORDED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_RECORDED_BY is required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_SIMULATION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_COST_FACTOR_RESOLUTION_CURRENT_V1
    WHERE SIMULATION_ID = :P_SIMULATION_ID;

    IF (V_SIMULATION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one Phase 10B simulation result is required.'',
            ''simulation_count'', V_SIMULATION_COUNT
        );
    END IF;

    SELECT
        KMAT_ID,
        RFQ_ID
    INTO
        :V_KMAT_ID,
        :V_RFQ_ID
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_COST_FACTOR_RESOLUTION_CURRENT_V1
    WHERE SIMULATION_ID = :P_SIMULATION_ID;

    V_MODEL_DOMAIN :=
        UPPER(TRIM(P_MODEL_DOMAIN));

    V_ACTUAL_NUMERIC_VALUE :=
        P_ACTUAL_NUMERIC_VALUE;

    V_ACTUAL_TEXT_STATUS :=
        UPPER(TRIM(P_ACTUAL_TEXT_STATUS));

    IF (V_MODEL_DOMAIN = ''CSS'') THEN
        IF (
            V_ACTUAL_NUMERIC_VALUE IS NULL
            OR V_ACTUAL_NUMERIC_VALUE < 0.0
            OR V_ACTUAL_NUMERIC_VALUE > 1.0
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''CSS actual value must be between 0 and 1.''
            );
        END IF;

    ELSEIF (V_MODEL_DOMAIN = ''FMIS'') THEN
        IF (
            V_ACTUAL_NUMERIC_VALUE IS NULL
            OR V_ACTUAL_NUMERIC_VALUE <= 0.0
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''FMIS actual multiplier must be greater than 0.''
            );
        END IF;

    ELSEIF (V_MODEL_DOMAIN = ''TDS'') THEN
        IF (
            V_ACTUAL_NUMERIC_VALUE IS NULL
            OR V_ACTUAL_NUMERIC_VALUE < 1.0
            OR V_ACTUAL_NUMERIC_VALUE > 3.5
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''TDS actual factor must be between 1.0 and 3.5.''
            );
        END IF;

    ELSE
        IF (P_ACTUAL_MAPPING_CORRECT_FLAG IS NULL) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''BMCS requires P_ACTUAL_MAPPING_CORRECT_FLAG.''
            );
        END IF;

        V_ACTUAL_NUMERIC_VALUE :=
            IFF(
                P_ACTUAL_MAPPING_CORRECT_FLAG,
                1.0,
                0.0
            );

        V_ACTUAL_TEXT_STATUS :=
            COALESCE(
                V_ACTUAL_TEXT_STATUS::VARCHAR,
                IFF(
                    P_ACTUAL_MAPPING_CORRECT_FLAG,
                    ''CORRECT_MAPPING'',
                    ''INCORRECT_MAPPING''
                )::VARCHAR
            );
    END IF;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MODEL_ACTUAL_OUTCOME_V1
    SET
        IS_ACTIVE = FALSE,
        UPDATED_BY = TRIM(:P_RECORDED_BY),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE SIMULATION_ID = :P_SIMULATION_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND OUTCOME_ID <> :P_OUTCOME_ID
      AND IS_ACTIVE = TRUE;

    MERGE INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MODEL_ACTUAL_OUTCOME_V1 target

    USING (
        SELECT :P_OUTCOME_ID AS OUTCOME_ID
    ) source

    ON target.OUTCOME_ID = source.OUTCOME_ID

    WHEN MATCHED THEN UPDATE SET
        SIMULATION_ID =
            :P_SIMULATION_ID,
        KMAT_ID =
            :V_KMAT_ID,
        RFQ_ID =
            :V_RFQ_ID,
        MODEL_DOMAIN =
            :V_MODEL_DOMAIN,
        OUTCOME_DATE =
            :P_OUTCOME_DATE,

        ACTUAL_NUMERIC_VALUE =
            :V_ACTUAL_NUMERIC_VALUE,
        ACTUAL_TEXT_STATUS =
            :V_ACTUAL_TEXT_STATUS,
        ACTUAL_MAPPING_CORRECT_FLAG =
            :P_ACTUAL_MAPPING_CORRECT_FLAG,

        OUTCOME_SOURCE =
            TRIM(:P_OUTCOME_SOURCE),
        EVIDENCE_REFERENCE =
            :P_EVIDENCE_REFERENCE,
        NOTES =
            :P_NOTES,

        IS_ACTIVE =
            TRUE,

        UPDATED_BY =
            TRIM(:P_RECORDED_BY),
        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        OUTCOME_ID,

        SIMULATION_ID,
        KMAT_ID,
        RFQ_ID,
        MODEL_DOMAIN,

        OUTCOME_DATE,

        ACTUAL_NUMERIC_VALUE,
        ACTUAL_TEXT_STATUS,
        ACTUAL_MAPPING_CORRECT_FLAG,

        OUTCOME_SOURCE,
        EVIDENCE_REFERENCE,
        NOTES,

        IS_ACTIVE,

        RECORDED_BY,
        RECORDED_AT,
        UPDATED_BY,
        UPDATED_AT
    )
    VALUES (
        :P_OUTCOME_ID,

        :P_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,
        :V_MODEL_DOMAIN,

        :P_OUTCOME_DATE,

        :V_ACTUAL_NUMERIC_VALUE,
        :V_ACTUAL_TEXT_STATUS,
        :P_ACTUAL_MAPPING_CORRECT_FLAG,

        TRIM(:P_OUTCOME_SOURCE),
        :P_EVIDENCE_REFERENCE,
        :P_NOTES,

        TRUE,

        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP(),
        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP()
    );

    V_AUDIT_EVENT_ID :=
        UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_ACTUAL_OUTCOME_AUDIT_V1 (
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,

                OUTCOME_ID,
                OUTCOME_TYPE,

                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,
                MODEL_DOMAIN,

                OUTCOME_DATE,

                ACTUAL_NUMERIC_VALUE,
                ACTUAL_TEXT_STATUS,
                ACTUAL_MAPPING_CORRECT_FLAG,

                ACTUAL_TOTAL_COST_USD,
                ACTUAL_FINAL_PRICE_USD,

                OUTCOME_SOURCE,
                EVIDENCE_REFERENCE,
                NOTES,

                EVENT_ACTOR,
                AUDITED_AT
            )
    VALUES (
        :V_AUDIT_EVENT_ID,
        ''MODEL_ACTUAL_OUTCOME_RECORDED'',

        :P_OUTCOME_ID,
        ''MODEL'',

        :P_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,
        :V_MODEL_DOMAIN,

        :P_OUTCOME_DATE,

        :V_ACTUAL_NUMERIC_VALUE,
        :V_ACTUAL_TEXT_STATUS,
        :P_ACTUAL_MAPPING_CORRECT_FLAG,

        NULL::FLOAT,
        NULL::FLOAT,

        TRIM(:P_OUTCOME_SOURCE),
        :P_EVIDENCE_REFERENCE,
        :P_NOTES,

        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP()
    );

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_11A'',
        ''outcome_id'', P_OUTCOME_ID,
        ''simulation_id'', P_SIMULATION_ID,
        ''model_domain'', V_MODEL_DOMAIN,
        ''actual_numeric_value'',
            V_ACTUAL_NUMERIC_VALUE,
        ''actual_text_status'',
            V_ACTUAL_TEXT_STATUS,
        ''actual_mapping_correct'',
            P_ACTUAL_MAPPING_CORRECT_FLAG,
        ''outcome_date'', P_OUTCOME_DATE,
        ''audit_event_id'', V_AUDIT_EVENT_ID
    );
END;
';


-- ============================================================
-- 6. RECORD REALISED COST OUTCOME
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RECORD_KMAT_COST_ACTUAL_OUTCOME_V1(
            P_COST_OUTCOME_ID VARCHAR,
            P_SIMULATION_ID VARCHAR,
            P_OUTCOME_DATE DATE,

            P_ACTUAL_MATERIAL_COST_USD FLOAT,
            P_ACTUAL_LABOR_COST_USD FLOAT,
            P_ACTUAL_MACHINE_COST_USD FLOAT,
            P_ACTUAL_OVERHEAD_COST_USD FLOAT,

            P_ACTUAL_TOTAL_COST_USD FLOAT,
            P_ACTUAL_FINAL_PRICE_USD FLOAT,

            P_OUTCOME_SOURCE VARCHAR,
            P_EVIDENCE_REFERENCE VARCHAR,
            P_NOTES VARCHAR,
            P_RECORDED_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_SIMULATION_COUNT NUMBER DEFAULT 0;

    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;

    V_AUDIT_EVENT_ID VARCHAR;
BEGIN
    IF (
        P_COST_OUTCOME_ID IS NULL
        OR LENGTH(TRIM(P_COST_OUTCOME_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_COST_OUTCOME_ID is required.''
        );
    END IF;

    IF (
        P_SIMULATION_ID IS NULL
        OR LENGTH(TRIM(P_SIMULATION_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_SIMULATION_ID is required.''
        );
    END IF;

    IF (P_OUTCOME_DATE IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OUTCOME_DATE is required.''
        );
    END IF;

    IF (
        P_ACTUAL_TOTAL_COST_USD IS NULL
        OR P_ACTUAL_TOTAL_COST_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_ACTUAL_TOTAL_COST_USD must be non-negative.''
        );
    END IF;

    IF (
        P_ACTUAL_MATERIAL_COST_USD IS NOT NULL
        AND P_ACTUAL_MATERIAL_COST_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Material actual cost cannot be negative.''
        );
    END IF;

    IF (
        P_ACTUAL_LABOR_COST_USD IS NOT NULL
        AND P_ACTUAL_LABOR_COST_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Labor actual cost cannot be negative.''
        );
    END IF;

    IF (
        P_ACTUAL_MACHINE_COST_USD IS NOT NULL
        AND P_ACTUAL_MACHINE_COST_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Machine actual cost cannot be negative.''
        );
    END IF;

    IF (
        P_ACTUAL_OVERHEAD_COST_USD IS NOT NULL
        AND P_ACTUAL_OVERHEAD_COST_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Overhead actual cost cannot be negative.''
        );
    END IF;

    IF (
        P_ACTUAL_FINAL_PRICE_USD IS NOT NULL
        AND P_ACTUAL_FINAL_PRICE_USD < 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Actual final price cannot be negative.''
        );
    END IF;

    IF (
        P_OUTCOME_SOURCE IS NULL
        OR LENGTH(TRIM(P_OUTCOME_SOURCE)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OUTCOME_SOURCE is required.''
        );
    END IF;

    IF (
        P_RECORDED_BY IS NULL
        OR LENGTH(TRIM(P_RECORDED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_RECORDED_BY is required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_SIMULATION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_COST_FACTOR_RESOLUTION_CURRENT_V1
    WHERE SIMULATION_ID = :P_SIMULATION_ID;

    IF (V_SIMULATION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one Phase 10B simulation result is required.'',
            ''simulation_count'', V_SIMULATION_COUNT
        );
    END IF;

    SELECT
        KMAT_ID,
        RFQ_ID
    INTO
        :V_KMAT_ID,
        :V_RFQ_ID
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_COST_FACTOR_RESOLUTION_CURRENT_V1
    WHERE SIMULATION_ID = :P_SIMULATION_ID;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_COST_ACTUAL_OUTCOME_V1
    SET
        IS_ACTIVE = FALSE,
        UPDATED_BY = TRIM(:P_RECORDED_BY),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE SIMULATION_ID = :P_SIMULATION_ID
      AND COST_OUTCOME_ID <> :P_COST_OUTCOME_ID
      AND IS_ACTIVE = TRUE;

    MERGE INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_COST_ACTUAL_OUTCOME_V1 target

    USING (
        SELECT
            :P_COST_OUTCOME_ID
                AS COST_OUTCOME_ID
    ) source

    ON target.COST_OUTCOME_ID =
       source.COST_OUTCOME_ID

    WHEN MATCHED THEN UPDATE SET
        SIMULATION_ID =
            :P_SIMULATION_ID,
        KMAT_ID =
            :V_KMAT_ID,
        RFQ_ID =
            :V_RFQ_ID,

        OUTCOME_DATE =
            :P_OUTCOME_DATE,

        ACTUAL_MATERIAL_COST_USD =
            :P_ACTUAL_MATERIAL_COST_USD,
        ACTUAL_LABOR_COST_USD =
            :P_ACTUAL_LABOR_COST_USD,
        ACTUAL_MACHINE_COST_USD =
            :P_ACTUAL_MACHINE_COST_USD,
        ACTUAL_OVERHEAD_COST_USD =
            :P_ACTUAL_OVERHEAD_COST_USD,

        ACTUAL_TOTAL_COST_USD =
            :P_ACTUAL_TOTAL_COST_USD,
        ACTUAL_FINAL_PRICE_USD =
            :P_ACTUAL_FINAL_PRICE_USD,

        OUTCOME_SOURCE =
            TRIM(:P_OUTCOME_SOURCE),
        EVIDENCE_REFERENCE =
            :P_EVIDENCE_REFERENCE,
        NOTES =
            :P_NOTES,

        IS_ACTIVE =
            TRUE,

        UPDATED_BY =
            TRIM(:P_RECORDED_BY),
        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        COST_OUTCOME_ID,

        SIMULATION_ID,
        KMAT_ID,
        RFQ_ID,

        OUTCOME_DATE,

        ACTUAL_MATERIAL_COST_USD,
        ACTUAL_LABOR_COST_USD,
        ACTUAL_MACHINE_COST_USD,
        ACTUAL_OVERHEAD_COST_USD,

        ACTUAL_TOTAL_COST_USD,
        ACTUAL_FINAL_PRICE_USD,

        OUTCOME_SOURCE,
        EVIDENCE_REFERENCE,
        NOTES,

        IS_ACTIVE,

        RECORDED_BY,
        RECORDED_AT,
        UPDATED_BY,
        UPDATED_AT
    )
    VALUES (
        :P_COST_OUTCOME_ID,

        :P_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,

        :P_OUTCOME_DATE,

        :P_ACTUAL_MATERIAL_COST_USD,
        :P_ACTUAL_LABOR_COST_USD,
        :P_ACTUAL_MACHINE_COST_USD,
        :P_ACTUAL_OVERHEAD_COST_USD,

        :P_ACTUAL_TOTAL_COST_USD,
        :P_ACTUAL_FINAL_PRICE_USD,

        TRIM(:P_OUTCOME_SOURCE),
        :P_EVIDENCE_REFERENCE,
        :P_NOTES,

        TRUE,

        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP(),
        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP()
    );

    V_AUDIT_EVENT_ID :=
        UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_ACTUAL_OUTCOME_AUDIT_V1 (
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,

                OUTCOME_ID,
                OUTCOME_TYPE,

                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,
                MODEL_DOMAIN,

                OUTCOME_DATE,

                ACTUAL_NUMERIC_VALUE,
                ACTUAL_TEXT_STATUS,
                ACTUAL_MAPPING_CORRECT_FLAG,

                ACTUAL_TOTAL_COST_USD,
                ACTUAL_FINAL_PRICE_USD,

                OUTCOME_SOURCE,
                EVIDENCE_REFERENCE,
                NOTES,

                EVENT_ACTOR,
                AUDITED_AT
            )
    VALUES (
        :V_AUDIT_EVENT_ID,
        ''COST_ACTUAL_OUTCOME_RECORDED'',

        :P_COST_OUTCOME_ID,
        ''COST'',

        :P_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,
        NULL::VARCHAR,

        :P_OUTCOME_DATE,

        NULL::FLOAT,
        NULL::VARCHAR,
        NULL::BOOLEAN,

        :P_ACTUAL_TOTAL_COST_USD,
        :P_ACTUAL_FINAL_PRICE_USD,

        TRIM(:P_OUTCOME_SOURCE),
        :P_EVIDENCE_REFERENCE,
        :P_NOTES,

        TRIM(:P_RECORDED_BY),
        CURRENT_TIMESTAMP()
    );

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_11A'',
        ''cost_outcome_id'',
            P_COST_OUTCOME_ID,
        ''simulation_id'', P_SIMULATION_ID,
        ''actual_total_cost_usd'',
            P_ACTUAL_TOTAL_COST_USD,
        ''actual_final_price_usd'',
            P_ACTUAL_FINAL_PRICE_USD,
        ''outcome_date'', P_OUTCOME_DATE,
        ''audit_event_id'', V_AUDIT_EVENT_ID
    );
END;
';


-- ============================================================
-- 7. MODEL FEEDBACK DETAIL
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
AS
WITH LATEST_OUTCOME AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MODEL_ACTUAL_OUTCOME_V1
    WHERE IS_ACTIVE = TRUE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY
            SIMULATION_ID,
            MODEL_DOMAIN
        ORDER BY
            OUTCOME_DATE DESC,
            UPDATED_AT DESC,
            OUTCOME_ID DESC
    ) = 1
),
MODEL_ROWS AS (
    SELECT
        hierarchy.SIMULATION_ID,
        hierarchy.KMAT_ID,
        hierarchy.RFQ_ID,

        'CSS' AS MODEL_DOMAIN,
        TRUE AS MONITORING_ELIGIBLE_FLAG,

        phase10a.CSS_DECISION_ID
            AS DECISION_ID,

        IFF(
            phase10a.CSS_DECISION_ID IS NOT NULL,
            TRUE,
            FALSE
        ) AS DECISION_AVAILABLE_FLAG,

        phase10a.CSS_POLICY_ID
            AS POLICY_ID,
        phase10a.CSS_POLICY_VERSION
            AS POLICY_VERSION,
        phase10a.CSS_DEPLOYMENT_MODE
            AS DEPLOYMENT_MODE,

        phase10a.CSS_MODEL_NAME
            AS MODEL_NAME,
        phase10a.CSS_MODEL_VERSION
            AS MODEL_VERSION,
        phase10a.CSS_FEATURE_SET_VERSION
            AS FEATURE_SET_VERSION,

        hierarchy.CSS_RULE_VALUE::FLOAT
            AS RULE_VALUE,
        hierarchy.CSS_ML_VALUE::FLOAT
            AS ML_ADVISORY_VALUE,
        phase10a.CSS_RAW_ML_VALUE::FLOAT
            AS ML_PROBABILITY_VALUE,
        hierarchy.CSS_OVERRIDE_VALUE::FLOAT
            AS OVERRIDE_VALUE,
        hierarchy.RESOLVED_SCRAP_RATE::FLOAT
            AS FINAL_RESOLVED_VALUE,

        NULL::VARCHAR
            AS FINAL_TEXT_STATUS,

        hierarchy.CSS_RESOLVED_SOURCE
            AS FINAL_SOURCE,

        phase10a.OFFICIAL_COST_CALCULATED_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1
            hierarchy

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_GOVERNED_COST_INPUT_V2
            phase10a
        ON hierarchy.SIMULATION_ID =
           phase10a.SIMULATION_ID

    UNION ALL

    SELECT
        hierarchy.SIMULATION_ID,
        hierarchy.KMAT_ID,
        hierarchy.RFQ_ID,

        'FMIS',
        TRUE,

        phase10a.FMIS_DECISION_ID,

        IFF(
            phase10a.FMIS_DECISION_ID IS NOT NULL,
            TRUE,
            FALSE
        ),

        phase10a.FMIS_POLICY_ID,
        phase10a.FMIS_POLICY_VERSION,
        phase10a.FMIS_DEPLOYMENT_MODE,

        phase10a.FMIS_MODEL_NAME,
        phase10a.FMIS_MODEL_VERSION,
        phase10a.FMIS_FEATURE_SET_VERSION,

        hierarchy.FMIS_RULE_VALUE::FLOAT,
        hierarchy.FMIS_ML_VALUE::FLOAT,
        NULL::FLOAT,
        hierarchy.FMIS_OVERRIDE_VALUE::FLOAT,
        hierarchy.RESOLVED_FMIS_MULTIPLIER::FLOAT,

        NULL::VARCHAR,

        hierarchy.FMIS_RESOLVED_SOURCE,

        phase10a.OFFICIAL_COST_CALCULATED_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1
            hierarchy

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_GOVERNED_COST_INPUT_V2
            phase10a
        ON hierarchy.SIMULATION_ID =
           phase10a.SIMULATION_ID

    UNION ALL

    SELECT
        hierarchy.SIMULATION_ID,
        hierarchy.KMAT_ID,
        hierarchy.RFQ_ID,

        'TDS',
        TRUE,

        phase10a.TDS_DECISION_ID,

        IFF(
            phase10a.TDS_DECISION_ID IS NOT NULL,
            TRUE,
            FALSE
        ),

        phase10a.TDS_POLICY_ID,
        phase10a.TDS_POLICY_VERSION,
        phase10a.TDS_DEPLOYMENT_MODE,

        phase10a.TDS_MODEL_NAME,
        phase10a.TDS_MODEL_VERSION,
        phase10a.TDS_FEATURE_SET_VERSION,

        hierarchy.TDS_RULE_VALUE::FLOAT,
        hierarchy.TDS_ML_VALUE::FLOAT,
        NULL::FLOAT,
        hierarchy.TDS_OVERRIDE_VALUE::FLOAT,
        hierarchy.RESOLVED_TDS_FACTOR::FLOAT,

        NULL::VARCHAR,

        hierarchy.TDS_RESOLVED_SOURCE,

        phase10a.OFFICIAL_COST_CALCULATED_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1
            hierarchy

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_GOVERNED_COST_INPUT_V2
            phase10a
        ON hierarchy.SIMULATION_ID =
           phase10a.SIMULATION_ID

    UNION ALL

    SELECT
        hierarchy.SIMULATION_ID,
        hierarchy.KMAT_ID,
        hierarchy.RFQ_ID,

        'BMCS',

        IFF(
            hierarchy.RFQ_ID IS NOT NULL
            OR COALESCE(
                hierarchy.BMCS_OFFICIAL_STATUS,
                'NOT_APPLICABLE'
            ) <> 'NOT_APPLICABLE',
            TRUE,
            FALSE
        ),

        phase10a.BMCS_DECISION_ID,

        IFF(
            phase10a.BMCS_DECISION_ID IS NOT NULL,
            TRUE,
            FALSE
        ),

        phase10a.BMCS_POLICY_ID,
        phase10a.BMCS_POLICY_VERSION,
        phase10a.BMCS_DEPLOYMENT_MODE,

        phase10a.BMCS_MODEL_NAME,
        phase10a.BMCS_MODEL_VERSION,
        phase10a.BMCS_FEATURE_SET_VERSION,

        NULL::FLOAT,
        hierarchy.BMCS_ML_SCORE::FLOAT,
        phase10a
            .BMCS_RAW_CORRECT_MAPPING_PROBABILITY
            ::FLOAT,
        NULL::FLOAT,
        NULL::FLOAT,

        hierarchy.RESOLVED_BMCS_STATUS,

        hierarchy.BMCS_RESOLVED_SOURCE,

        phase10a.OFFICIAL_COST_CALCULATED_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1
            hierarchy

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_GOVERNED_COST_INPUT_V2
            phase10a
        ON hierarchy.SIMULATION_ID =
           phase10a.SIMULATION_ID
)
SELECT
    model_row.SIMULATION_ID,
    model_row.KMAT_ID,
    model_row.RFQ_ID,

    model_row.MODEL_DOMAIN,
    model_row.MONITORING_ELIGIBLE_FLAG,

    model_row.DECISION_ID,
    model_row.DECISION_AVAILABLE_FLAG,

    model_row.POLICY_ID,
    model_row.POLICY_VERSION,
    model_row.DEPLOYMENT_MODE,

    model_row.MODEL_NAME,
    model_row.MODEL_VERSION,
    model_row.FEATURE_SET_VERSION,

    model_row.RULE_VALUE,
    model_row.ML_ADVISORY_VALUE,
    model_row.ML_PROBABILITY_VALUE,
    model_row.OVERRIDE_VALUE,
    model_row.FINAL_RESOLVED_VALUE,
    model_row.FINAL_TEXT_STATUS,
    model_row.FINAL_SOURCE,

    outcome.OUTCOME_ID,
    outcome.OUTCOME_DATE,
    outcome.ACTUAL_NUMERIC_VALUE,
    outcome.ACTUAL_TEXT_STATUS,
    outcome.ACTUAL_MAPPING_CORRECT_FLAG,
    outcome.OUTCOME_SOURCE,
    outcome.EVIDENCE_REFERENCE,

    IFF(
        outcome.OUTCOME_ID IS NOT NULL,
        TRUE,
        FALSE
    ) AS OUTCOME_AVAILABLE_FLAG,

    IFF(
        outcome.ACTUAL_NUMERIC_VALUE IS NOT NULL
        AND model_row.RULE_VALUE IS NOT NULL,
        ABS(
            model_row.RULE_VALUE
            - outcome.ACTUAL_NUMERIC_VALUE
        ),
        NULL::FLOAT
    ) AS RULE_ABS_ERROR,

    IFF(
        outcome.ACTUAL_NUMERIC_VALUE IS NOT NULL
        AND model_row.ML_ADVISORY_VALUE IS NOT NULL
        AND model_row.MODEL_DOMAIN <> 'BMCS',
        ABS(
            model_row.ML_ADVISORY_VALUE
            - outcome.ACTUAL_NUMERIC_VALUE
        ),
        NULL::FLOAT
    ) AS ML_ABS_ERROR,

    IFF(
        outcome.ACTUAL_NUMERIC_VALUE IS NOT NULL
        AND model_row.FINAL_RESOLVED_VALUE IS NOT NULL,
        ABS(
            model_row.FINAL_RESOLVED_VALUE
            - outcome.ACTUAL_NUMERIC_VALUE
        ),
        NULL::FLOAT
    ) AS FINAL_ABS_ERROR,

    IFF(
        model_row.MODEL_DOMAIN = 'BMCS'
        AND model_row.ML_PROBABILITY_VALUE IS NOT NULL
        AND outcome.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL,
        POWER(
            model_row.ML_PROBABILITY_VALUE
            - IFF(
                outcome.ACTUAL_MAPPING_CORRECT_FLAG,
                1.0,
                0.0
            ),
            2
        ),
        NULL::FLOAT
    ) AS BMCS_BRIER_SCORE,

    IFF(
        model_row.MODEL_DOMAIN = 'BMCS'
        AND model_row.ML_PROBABILITY_VALUE IS NOT NULL
        AND outcome.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL,
        IFF(
            (
                model_row.ML_PROBABILITY_VALUE >= 0.5
                AND outcome
                    .ACTUAL_MAPPING_CORRECT_FLAG
            )
            OR
            (
                model_row.ML_PROBABILITY_VALUE < 0.5
                AND NOT outcome
                    .ACTUAL_MAPPING_CORRECT_FLAG
            ),
            TRUE,
            FALSE
        ),
        NULL::BOOLEAN
    ) AS BMCS_CLASSIFICATION_CORRECT_FLAG,

    IFF(
        outcome.OUTCOME_DATE IS NOT NULL
        AND model_row
            .OFFICIAL_COST_CALCULATED_AT
            IS NOT NULL,
        DATEDIFF(
            'day',
            model_row
                .OFFICIAL_COST_CALCULATED_AT
                ::DATE,
            outcome.OUTCOME_DATE
        ),
        NULL::NUMBER
    ) AS FEEDBACK_DELAY_DAYS

FROM MODEL_ROWS model_row

LEFT JOIN LATEST_OUTCOME outcome
    ON model_row.SIMULATION_ID =
       outcome.SIMULATION_ID
   AND model_row.MODEL_DOMAIN =
       outcome.MODEL_DOMAIN;


-- ============================================================
-- 8. COST FEEDBACK DETAIL
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_COST_FEEDBACK_DETAIL_V1
AS
WITH LATEST_COST_OUTCOME AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_COST_ACTUAL_OUTCOME_V1
    WHERE IS_ACTIVE = TRUE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY SIMULATION_ID
        ORDER BY
            OUTCOME_DATE DESC,
            UPDATED_AT DESC,
            COST_OUTCOME_ID DESC
    ) = 1
)
SELECT
    phase10a.SIMULATION_ID,
    phase10a.KMAT_ID,
    phase10a.RFQ_ID,

    phase10a.OFFICIAL_COST_CALCULATED_AT,

    phase10a.MATERIAL_COST_USD
        AS OFFICIAL_MATERIAL_COST_USD,

    phase10a.LABOR_COST_USD
        AS OFFICIAL_LABOR_COST_USD,

    phase10a.MACHINE_COST_USD
        AS OFFICIAL_MACHINE_COST_USD,

    phase10a.OVERHEAD_COST_USD
        AS OFFICIAL_OVERHEAD_COST_USD,

    phase10a
        .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD
        AS OFFICIAL_TOTAL_COST_USD,

    phase10a.OFFICIAL_TARGET_PRICE_USD
        AS OFFICIAL_TARGET_PRICE_USD,

    outcome.COST_OUTCOME_ID,
    outcome.OUTCOME_DATE,

    outcome.ACTUAL_MATERIAL_COST_USD,
    outcome.ACTUAL_LABOR_COST_USD,
    outcome.ACTUAL_MACHINE_COST_USD,
    outcome.ACTUAL_OVERHEAD_COST_USD,

    outcome.ACTUAL_TOTAL_COST_USD,
    outcome.ACTUAL_FINAL_PRICE_USD,

    outcome.OUTCOME_SOURCE,
    outcome.EVIDENCE_REFERENCE,

    IFF(
        outcome.COST_OUTCOME_ID IS NOT NULL,
        TRUE,
        FALSE
    ) AS OUTCOME_AVAILABLE_FLAG,

    IFF(
        outcome.ACTUAL_TOTAL_COST_USD IS NOT NULL,
        outcome.ACTUAL_TOTAL_COST_USD
        - phase10a
            .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD,
        NULL::FLOAT
    ) AS TOTAL_COST_VARIANCE_USD,

    IFF(
        outcome.ACTUAL_TOTAL_COST_USD IS NOT NULL,
        ABS(
            outcome.ACTUAL_TOTAL_COST_USD
            - phase10a
                .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD
        ),
        NULL::FLOAT
    ) AS ABS_TOTAL_COST_VARIANCE_USD,

    IFF(
        outcome.ACTUAL_TOTAL_COST_USD IS NOT NULL
        AND NULLIF(
            phase10a
                .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD,
            0.0
        ) IS NOT NULL,
        (
            ABS(
                outcome.ACTUAL_TOTAL_COST_USD
                - phase10a
                    .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD
            )
            /
            NULLIF(
                phase10a
                    .OFFICIAL_RISK_ADJUSTED_TOTAL_COST_USD,
                0.0
            )
        ) * 100.0,
        NULL::FLOAT
    ) AS ABS_TOTAL_COST_VARIANCE_PCT,

    IFF(
        outcome.ACTUAL_FINAL_PRICE_USD IS NOT NULL,
        outcome.ACTUAL_FINAL_PRICE_USD
        - phase10a.OFFICIAL_TARGET_PRICE_USD,
        NULL::FLOAT
    ) AS FINAL_PRICE_VARIANCE_USD

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .KMAT_GOVERNED_COST_INPUT_V2
        phase10a

LEFT JOIN LATEST_COST_OUTCOME outcome
    ON phase10a.SIMULATION_ID =
       outcome.SIMULATION_ID;


-- ============================================================
-- 9. DOMAIN AND OPERATIONAL SUMMARIES
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
AS
SELECT
    MODEL_DOMAIN,

    COUNT_IF(
        MONITORING_ELIGIBLE_FLAG = TRUE
    ) AS ELIGIBLE_SIMULATION_COUNT,

    COUNT_IF(
        MONITORING_ELIGIBLE_FLAG = TRUE
        AND DECISION_AVAILABLE_FLAG = TRUE
    ) AS ML_DECISION_COUNT,

    IFF(
        COUNT_IF(
            MONITORING_ELIGIBLE_FLAG = TRUE
        ) = 0,
        NULL::FLOAT,
        (
            COUNT_IF(
                MONITORING_ELIGIBLE_FLAG = TRUE
                AND DECISION_AVAILABLE_FLAG = TRUE
            )
            /
            COUNT_IF(
                MONITORING_ELIGIBLE_FLAG = TRUE
            )
        ) * 100.0
    ) AS ML_DECISION_COVERAGE_PCT,

    COUNT_IF(
        MONITORING_ELIGIBLE_FLAG = TRUE
        AND OUTCOME_AVAILABLE_FLAG = TRUE
    ) AS ACTUAL_OUTCOME_COUNT,

    IFF(
        COUNT_IF(
            MONITORING_ELIGIBLE_FLAG = TRUE
        ) = 0,
        NULL::FLOAT,
        (
            COUNT_IF(
                MONITORING_ELIGIBLE_FLAG = TRUE
                AND OUTCOME_AVAILABLE_FLAG = TRUE
            )
            /
            COUNT_IF(
                MONITORING_ELIGIBLE_FLAG = TRUE
            )
        ) * 100.0
    ) AS ACTUAL_OUTCOME_COVERAGE_PCT,

    AVG(RULE_ABS_ERROR)
        AS AVG_RULE_ABS_ERROR,

    AVG(ML_ABS_ERROR)
        AS AVG_ML_ABS_ERROR,

    AVG(FINAL_ABS_ERROR)
        AS AVG_FINAL_ABS_ERROR,

    SQRT(
        AVG(
            POWER(
                FINAL_ABS_ERROR,
                2
            )
        )
    ) AS FINAL_RMSE,

    AVG(BMCS_BRIER_SCORE)
        AS AVG_BMCS_BRIER_SCORE,

    IFF(
        COUNT_IF(
            BMCS_CLASSIFICATION_CORRECT_FLAG
                IS NOT NULL
        ) = 0,
        NULL::FLOAT,
        (
            COUNT_IF(
                BMCS_CLASSIFICATION_CORRECT_FLAG
                    = TRUE
            )
            /
            COUNT_IF(
                BMCS_CLASSIFICATION_CORRECT_FLAG
                    IS NOT NULL
            )
        ) * 100.0
    ) AS BMCS_CLASSIFICATION_ACCURACY_PCT,

    AVG(FEEDBACK_DELAY_DAYS)
        AS AVG_FEEDBACK_DELAY_DAYS,

    CURRENT_TIMESTAMP()
        AS OBSERVED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1

GROUP BY MODEL_DOMAIN;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1
AS
SELECT
    (
        SELECT COUNT(*)
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS TOTAL_SIMULATION_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                SAFETY_GATE_PASS_FLAG = FALSE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS SAFETY_FAILURE_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                COST_ENGINE_CONSUMPTION_ALLOWED_FLAG
                    = FALSE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS COST_BLOCKED_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG
                    = TRUE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS RECALC_REQUIRED_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                ANY_OVERRIDE_USED_FLAG = TRUE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS OVERRIDE_USED_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                ANY_ML_USED_FLAG = TRUE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS ML_USED_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                ANY_SAFE_DEFAULT_USED_FLAG = TRUE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_PHASE10B_HIERARCHY_V1
    ) AS SAFE_DEFAULT_USED_COUNT,

    (
        SELECT COALESCE(
            COUNT_IF(
                OUTCOME_AVAILABLE_FLAG = TRUE
            ),
            0
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_COST_FEEDBACK_DETAIL_V1
    ) AS COST_ACTUAL_OUTCOME_COUNT,

    IFF(
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_KMAT_COST_FEEDBACK_DETAIL_V1
        ) = 0,
        NULL::FLOAT,
        (
            (
                SELECT COALESCE(
                    COUNT_IF(
                        OUTCOME_AVAILABLE_FLAG = TRUE
                    ),
                    0
                )
                FROM
                    KMAT_COST_MODEL_DB.CORE_ML
                        .VW_KMAT_COST_FEEDBACK_DETAIL_V1
            )
            /
            (
                SELECT COUNT(*)
                FROM
                    KMAT_COST_MODEL_DB.CORE_ML
                        .VW_KMAT_COST_FEEDBACK_DETAIL_V1
            )
        ) * 100.0
    ) AS COST_ACTUAL_COVERAGE_PCT,

    (
        SELECT AVG(
            ABS_TOTAL_COST_VARIANCE_PCT
        )
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_KMAT_COST_FEEDBACK_DETAIL_V1
        WHERE OUTCOME_AVAILABLE_FLAG = TRUE
    ) AS AVG_ABS_COST_VARIANCE_PCT,

    CURRENT_TIMESTAMP()
        AS OBSERVED_AT;


-- ============================================================
-- 10. CURRENT METRICS AND ALERTS
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_METRIC_CURRENT_V1
AS
SELECT
    MODEL_DOMAIN,
    'ML_DECISION_COVERAGE_PCT'
        AS METRIC_KEY,
    ML_DECISION_COVERAGE_PCT
        AS METRIC_VALUE,
    ELIGIBLE_SIMULATION_COUNT
        AS SAMPLE_SIZE,
    ML_DECISION_COUNT
        AS NUMERATOR_VALUE,
    ELIGIBLE_SIMULATION_COUNT
        AS DENOMINATOR_VALUE,
    'PERCENT'
        AS METRIC_UNIT,
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1

UNION ALL

SELECT
    MODEL_DOMAIN,
    'MODEL_OUTCOME_COVERAGE_PCT',
    ACTUAL_OUTCOME_COVERAGE_PCT,
    ELIGIBLE_SIMULATION_COUNT,
    ACTUAL_OUTCOME_COUNT,
    ELIGIBLE_SIMULATION_COUNT,
    'PERCENT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1

UNION ALL

SELECT
    MODEL_DOMAIN,
    'FINAL_MAE',
    AVG_FINAL_ABS_ERROR,
    ACTUAL_OUTCOME_COUNT,
    NULL::FLOAT,
    NULL::FLOAT,
    CASE
        WHEN MODEL_DOMAIN = 'CSS'
            THEN 'RATE'
        WHEN MODEL_DOMAIN = 'FMIS'
            THEN 'MULTIPLIER'
        WHEN MODEL_DOMAIN = 'TDS'
            THEN 'FACTOR'
        ELSE 'SCORE'
    END,
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
WHERE MODEL_DOMAIN IN (
    'CSS',
    'FMIS',
    'TDS'
)

UNION ALL

SELECT
    MODEL_DOMAIN,
    'ML_MAE',
    AVG_ML_ABS_ERROR,
    ACTUAL_OUTCOME_COUNT,
    NULL::FLOAT,
    NULL::FLOAT,
    CASE
        WHEN MODEL_DOMAIN = 'CSS'
            THEN 'RATE'
        WHEN MODEL_DOMAIN = 'FMIS'
            THEN 'MULTIPLIER'
        WHEN MODEL_DOMAIN = 'TDS'
            THEN 'FACTOR'
        ELSE 'SCORE'
    END,
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
WHERE MODEL_DOMAIN IN (
    'CSS',
    'FMIS',
    'TDS'
)

UNION ALL

SELECT
    MODEL_DOMAIN,
    'BMCS_BRIER_SCORE',
    AVG_BMCS_BRIER_SCORE,
    ACTUAL_OUTCOME_COUNT,
    NULL::FLOAT,
    NULL::FLOAT,
    'SCORE',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
WHERE MODEL_DOMAIN = 'BMCS'

UNION ALL

SELECT
    MODEL_DOMAIN,
    'BMCS_CLASSIFICATION_ACCURACY_PCT',
    BMCS_CLASSIFICATION_ACCURACY_PCT,
    ACTUAL_OUTCOME_COUNT,
    NULL::FLOAT,
    NULL::FLOAT,
    'PERCENT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
WHERE MODEL_DOMAIN = 'BMCS'

UNION ALL

SELECT
    'ALL',
    'SAFETY_FAILURE_COUNT',
    SAFETY_FAILURE_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    SAFETY_FAILURE_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'COST_BLOCKED_COUNT',
    COST_BLOCKED_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    COST_BLOCKED_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'RECALC_REQUIRED_COUNT',
    RECALC_REQUIRED_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    RECALC_REQUIRED_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'COST_ACTUAL_COVERAGE_PCT',
    COST_ACTUAL_COVERAGE_PCT,
    TOTAL_SIMULATION_COUNT,
    COST_ACTUAL_OUTCOME_COUNT,
    TOTAL_SIMULATION_COUNT,
    'PERCENT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'COST_ABS_VARIANCE_PCT',
    AVG_ABS_COST_VARIANCE_PCT,
    COST_ACTUAL_OUTCOME_COUNT,
    NULL::FLOAT,
    NULL::FLOAT,
    'PERCENT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'OVERRIDE_USED_COUNT',
    OVERRIDE_USED_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    OVERRIDE_USED_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'ML_USED_COUNT',
    ML_USED_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    ML_USED_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1

UNION ALL

SELECT
    'ALL',
    'SAFE_DEFAULT_USED_COUNT',
    SAFE_DEFAULT_USED_COUNT::FLOAT,
    TOTAL_SIMULATION_COUNT,
    SAFE_DEFAULT_USED_COUNT,
    TOTAL_SIMULATION_COUNT,
    'COUNT',
    OBSERVED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_ALERT_CURRENT_V1
AS
SELECT
    metric.MODEL_DOMAIN,
    metric.METRIC_KEY,

    COALESCE(
        policy.METRIC_NAME,
        metric.METRIC_KEY
    ) AS METRIC_NAME,

    metric.METRIC_VALUE,
    metric.METRIC_UNIT,
    metric.SAMPLE_SIZE,
    metric.NUMERATOR_VALUE,
    metric.DENOMINATOR_VALUE,

    policy.MONITORING_POLICY_ID,
    policy.POLICY_VERSION,
    policy.THRESHOLD_DIRECTION,
    policy.WARNING_THRESHOLD,
    policy.CRITICAL_THRESHOLD,
    policy.MIN_SAMPLE_SIZE,

    CASE
        WHEN policy.MONITORING_POLICY_ID IS NULL
            THEN 'INFORMATIONAL'

        WHEN metric.METRIC_VALUE IS NULL
            THEN 'NO_DATA'

        WHEN metric.SAMPLE_SIZE
             < policy.MIN_SAMPLE_SIZE
            THEN 'INSUFFICIENT_DATA'

        WHEN policy.THRESHOLD_DIRECTION = 'MAX'
         AND metric.METRIC_VALUE
             >= policy.CRITICAL_THRESHOLD
            THEN 'CRITICAL'

        WHEN policy.THRESHOLD_DIRECTION = 'MAX'
         AND metric.METRIC_VALUE
             >= policy.WARNING_THRESHOLD
            THEN 'WARNING'

        WHEN policy.THRESHOLD_DIRECTION = 'MIN'
         AND metric.METRIC_VALUE
             <= policy.CRITICAL_THRESHOLD
            THEN 'CRITICAL'

        WHEN policy.THRESHOLD_DIRECTION = 'MIN'
         AND metric.METRIC_VALUE
             <= policy.WARNING_THRESHOLD
            THEN 'WARNING'

        ELSE 'HEALTHY'
    END AS ALERT_STATUS,

    CASE
        WHEN policy.MONITORING_POLICY_ID IS NULL
            THEN
                'No active monitoring threshold is assigned.'

        WHEN metric.METRIC_VALUE IS NULL
            THEN
                'No actual outcome is available for this metric.'

        WHEN metric.SAMPLE_SIZE
             < policy.MIN_SAMPLE_SIZE
            THEN
                'More observations are required before evaluating the threshold.'

        WHEN policy.THRESHOLD_DIRECTION = 'MAX'
         AND metric.METRIC_VALUE
             >= policy.CRITICAL_THRESHOLD
            THEN
                'Metric is at or above the critical maximum.'

        WHEN policy.THRESHOLD_DIRECTION = 'MAX'
         AND metric.METRIC_VALUE
             >= policy.WARNING_THRESHOLD
            THEN
                'Metric is at or above the warning maximum.'

        WHEN policy.THRESHOLD_DIRECTION = 'MIN'
         AND metric.METRIC_VALUE
             <= policy.CRITICAL_THRESHOLD
            THEN
                'Metric is at or below the critical minimum.'

        WHEN policy.THRESHOLD_DIRECTION = 'MIN'
         AND metric.METRIC_VALUE
             <= policy.WARNING_THRESHOLD
            THEN
                'Metric is at or below the warning minimum.'

        ELSE
            'Metric is within the active threshold.'
    END AS ALERT_MESSAGE,

    metric.OBSERVED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_METRIC_CURRENT_V1
        metric

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_POLICY_CURRENT_V1
        policy
    ON metric.MODEL_DOMAIN =
       policy.MODEL_DOMAIN
   AND metric.METRIC_KEY =
       policy.METRIC_KEY;


-- ============================================================
-- 11. MONITORING RUN AND SNAPSHOT TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.KMAT_MONITORING_RUN_V1 (
        MONITORING_RUN_ID VARCHAR NOT NULL,

        RUN_STATUS VARCHAR NOT NULL,

        METRIC_COUNT NUMBER NOT NULL,
        HEALTHY_COUNT NUMBER NOT NULL,
        WARNING_COUNT NUMBER NOT NULL,
        CRITICAL_COUNT NUMBER NOT NULL,
        INSUFFICIENT_DATA_COUNT NUMBER NOT NULL,
        NO_DATA_COUNT NUMBER NOT NULL,
        INFORMATIONAL_COUNT NUMBER NOT NULL,

        METRIC_SNAPSHOT VARIANT,

        RUN_BY VARCHAR NOT NULL,
        STARTED_AT TIMESTAMP_NTZ NOT NULL,
        COMPLETED_AT TIMESTAMP_NTZ NOT NULL,

        CREATED_AT TIMESTAMP_NTZ
            DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .KMAT_MONITORING_METRIC_SNAPSHOT_V1 (
            MONITORING_RUN_ID VARCHAR NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            METRIC_KEY VARCHAR NOT NULL,
            METRIC_NAME VARCHAR NOT NULL,

            METRIC_VALUE FLOAT,
            METRIC_UNIT VARCHAR NOT NULL,
            SAMPLE_SIZE NUMBER,

            WARNING_THRESHOLD FLOAT,
            CRITICAL_THRESHOLD FLOAT,
            MIN_SAMPLE_SIZE NUMBER,

            ALERT_STATUS VARCHAR NOT NULL,
            ALERT_MESSAGE VARCHAR,

            OBSERVED_AT TIMESTAMP_NTZ NOT NULL,
            SNAPSHOT_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 12. MONITORING SNAPSHOT PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_KMAT_MONITORING_V1(
            P_MONITORING_RUN_ID VARCHAR,
            P_RUN_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_COUNT NUMBER DEFAULT 0;

    V_STARTED_AT TIMESTAMP_NTZ;
    V_COMPLETED_AT TIMESTAMP_NTZ;

    V_METRIC_COUNT NUMBER DEFAULT 0;
    V_HEALTHY_COUNT NUMBER DEFAULT 0;
    V_WARNING_COUNT NUMBER DEFAULT 0;
    V_CRITICAL_COUNT NUMBER DEFAULT 0;
    V_INSUFFICIENT_COUNT NUMBER DEFAULT 0;
    V_NO_DATA_COUNT NUMBER DEFAULT 0;
    V_INFORMATIONAL_COUNT NUMBER DEFAULT 0;

    V_RUN_STATUS VARCHAR;
    V_METRIC_SNAPSHOT VARIANT;
BEGIN
    IF (
        P_MONITORING_RUN_ID IS NULL
        OR LENGTH(TRIM(P_MONITORING_RUN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_MONITORING_RUN_ID is required.''
        );
    END IF;

    IF (
        P_RUN_BY IS NULL
        OR LENGTH(TRIM(P_RUN_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_RUN_BY is required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MONITORING_RUN_V1
    WHERE MONITORING_RUN_ID =
          :P_MONITORING_RUN_ID;

    IF (V_EXISTING_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_11A'',
                ''monitoring_run_id'',
                    MONITORING_RUN_ID,
                ''run_status'', RUN_STATUS,
                ''metric_count'', METRIC_COUNT,
                ''healthy_count'', HEALTHY_COUNT,
                ''warning_count'', WARNING_COUNT,
                ''critical_count'', CRITICAL_COUNT,
                ''insufficient_data_count'',
                    INSUFFICIENT_DATA_COUNT,
                ''no_data_count'', NO_DATA_COUNT,
                ''informational_count'',
                    INFORMATIONAL_COUNT,
                ''completed_at'', COMPLETED_AT
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .KMAT_MONITORING_RUN_V1
            WHERE MONITORING_RUN_ID =
                  :P_MONITORING_RUN_ID
        );
    END IF;

    IF (V_EXISTING_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Monitoring run ID is not unique.'',
            ''existing_count'', V_EXISTING_COUNT
        );
    END IF;

    V_STARTED_AT :=
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MONITORING_METRIC_SNAPSHOT_V1 (
                MONITORING_RUN_ID,

                MODEL_DOMAIN,
                METRIC_KEY,
                METRIC_NAME,

                METRIC_VALUE,
                METRIC_UNIT,
                SAMPLE_SIZE,

                WARNING_THRESHOLD,
                CRITICAL_THRESHOLD,
                MIN_SAMPLE_SIZE,

                ALERT_STATUS,
                ALERT_MESSAGE,

                OBSERVED_AT,
                SNAPSHOT_AT
            )
    SELECT
        :P_MONITORING_RUN_ID,

        MODEL_DOMAIN,
        METRIC_KEY,
        METRIC_NAME,

        METRIC_VALUE::FLOAT,
        METRIC_UNIT,
        SAMPLE_SIZE,

        WARNING_THRESHOLD::FLOAT,
        CRITICAL_THRESHOLD::FLOAT,
        MIN_SAMPLE_SIZE,

        ALERT_STATUS,
        ALERT_MESSAGE,

        OBSERVED_AT,
        CURRENT_TIMESTAMP()

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_MONITORING_ALERT_CURRENT_V1;

    SELECT
        COUNT(*)::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS = ''HEALTHY''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS = ''WARNING''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS = ''CRITICAL''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS =
                    ''INSUFFICIENT_DATA''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS = ''NO_DATA''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                ALERT_STATUS =
                    ''INFORMATIONAL''
            ),
            0
        )::NUMBER

    INTO
        :V_METRIC_COUNT,
        :V_HEALTHY_COUNT,
        :V_WARNING_COUNT,
        :V_CRITICAL_COUNT,
        :V_INSUFFICIENT_COUNT,
        :V_NO_DATA_COUNT,
        :V_INFORMATIONAL_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MONITORING_METRIC_SNAPSHOT_V1

    WHERE MONITORING_RUN_ID =
          :P_MONITORING_RUN_ID;

    SELECT OBJECT_AGG(
        MODEL_DOMAIN
        || ''::''
        || METRIC_KEY,

        OBJECT_CONSTRUCT_KEEP_NULL(
            ''metric_name'', METRIC_NAME,
            ''metric_value'', METRIC_VALUE,
            ''metric_unit'', METRIC_UNIT,
            ''sample_size'', SAMPLE_SIZE,
            ''alert_status'', ALERT_STATUS,
            ''alert_message'', ALERT_MESSAGE
        )
    )
    INTO :V_METRIC_SNAPSHOT
    FROM (
        SELECT *
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .KMAT_MONITORING_METRIC_SNAPSHOT_V1
        WHERE MONITORING_RUN_ID =
              :P_MONITORING_RUN_ID
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY MODEL_DOMAIN, METRIC_KEY
            ORDER BY METRIC_VALUE DESC NULLS LAST
        ) = 1
    );

    IF (V_CRITICAL_COUNT > 0) THEN
        V_RUN_STATUS :=
            ''ATTENTION_REQUIRED'';

    ELSEIF (V_WARNING_COUNT > 0) THEN
        V_RUN_STATUS :=
            ''WARNING'';

    ELSE
        V_RUN_STATUS :=
            ''HEALTHY'';
    END IF;

    V_COMPLETED_AT :=
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MONITORING_RUN_V1 (
                MONITORING_RUN_ID,

                RUN_STATUS,

                METRIC_COUNT,
                HEALTHY_COUNT,
                WARNING_COUNT,
                CRITICAL_COUNT,
                INSUFFICIENT_DATA_COUNT,
                NO_DATA_COUNT,
                INFORMATIONAL_COUNT,

                METRIC_SNAPSHOT,

                RUN_BY,
                STARTED_AT,
                COMPLETED_AT,

                CREATED_AT
            )
    SELECT
        :P_MONITORING_RUN_ID,

        :V_RUN_STATUS,

        :V_METRIC_COUNT,
        :V_HEALTHY_COUNT,
        :V_WARNING_COUNT,
        :V_CRITICAL_COUNT,
        :V_INSUFFICIENT_COUNT,
        :V_NO_DATA_COUNT,
        :V_INFORMATIONAL_COUNT,

        :V_METRIC_SNAPSHOT,

        TRIM(:P_RUN_BY),
        :V_STARTED_AT,
        :V_COMPLETED_AT,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_11A'',

        ''monitoring_run_id'',
            P_MONITORING_RUN_ID,

        ''run_status'', V_RUN_STATUS,

        ''metric_count'', V_METRIC_COUNT,
        ''healthy_count'', V_HEALTHY_COUNT,
        ''warning_count'', V_WARNING_COUNT,
        ''critical_count'', V_CRITICAL_COUNT,
        ''insufficient_data_count'',
            V_INSUFFICIENT_COUNT,
        ''no_data_count'', V_NO_DATA_COUNT,
        ''informational_count'',
            V_INFORMATIONAL_COUNT,

        ''run_by'', P_RUN_BY,
        ''started_at'', V_STARTED_AT,
        ''completed_at'', V_COMPLETED_AT
    );
END;
';


-- ============================================================
-- 13. MONITORING DASHBOARD VIEW
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE11A_MONITORING_DASHBOARD_V1
AS
SELECT
    alert.MODEL_DOMAIN,
    alert.METRIC_KEY,
    alert.METRIC_NAME,

    alert.METRIC_VALUE,
    alert.METRIC_UNIT,
    alert.SAMPLE_SIZE,

    alert.WARNING_THRESHOLD,
    alert.CRITICAL_THRESHOLD,
    alert.MIN_SAMPLE_SIZE,

    alert.ALERT_STATUS,
    alert.ALERT_MESSAGE,

    alert.POLICY_VERSION,
    alert.OBSERVED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_ALERT_CURRENT_V1
        alert;

-- ============================================================
-- PHASE 11A — VERIFICATION
--
-- This verification does not insert synthetic actual outcomes.
-- It validates the monitoring pipeline with the outcomes that
-- currently exist. Low sample size is reported as
-- INSUFFICIENT_DATA rather than as a production failure.
-- ============================================================


-- ------------------------------------------------------------
-- 1. OBJECT INVENTORY
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'RECORD_KMAT_MODEL_ACTUAL_OUTCOME_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RECORD_KMAT_COST_ACTUAL_OUTCOME_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_KMAT_MONITORING_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- ------------------------------------------------------------
-- 2. POLICY CHECK
--
-- Expected:
--   ACTIVE_MONITORING_POLICY_COUNT = 20
--   INVALID_POLICY_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ACTIVE_MONITORING_POLICY_COUNT,

    COUNT_IF(
        THRESHOLD_DIRECTION
            NOT IN ('MIN', 'MAX')
        OR MIN_SAMPLE_SIZE < 1
        OR WARNING_THRESHOLD IS NULL
        OR CRITICAL_THRESHOLD IS NULL
    ) AS INVALID_POLICY_ROWS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_POLICY_CURRENT_V1;


-- ------------------------------------------------------------
-- 3. CURRENT MODEL AND COST FEEDBACK
-- ------------------------------------------------------------

SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_DOMAIN_SUMMARY_V1
ORDER BY MODEL_DOMAIN;


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1;


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
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
    METRIC_KEY;


-- ------------------------------------------------------------
-- 4. CREATE IDEMPOTENT MONITORING SNAPSHOT
-- ------------------------------------------------------------

CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_KMAT_MONITORING_V1(
            'PHASE11A_MONITORING_001',
            'PHASE11A_VERIFICATION'
        );


-- Re-run to verify idempotent behaviour.
CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_KMAT_MONITORING_V1(
            'PHASE11A_MONITORING_001',
            'PHASE11A_VERIFICATION'
        );


-- ------------------------------------------------------------
-- 5. SNAPSHOT AND RUN HISTORY
-- ------------------------------------------------------------

SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .KMAT_MONITORING_RUN_V1
WHERE MONITORING_RUN_ID =
      'PHASE11A_MONITORING_001';


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .KMAT_MONITORING_METRIC_SNAPSHOT_V1
WHERE MONITORING_RUN_ID =
      'PHASE11A_MONITORING_001'
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
    METRIC_KEY;


-- ------------------------------------------------------------
-- 6. SAFETY INTEGRITY
--
-- Expected:
--   SAFETY_FAILURE_COUNT = 0
--   COST_BLOCKED_COUNT = 0
--   RECALC_REQUIRED_COUNT = 0
-- ------------------------------------------------------------

SELECT
    SAFETY_FAILURE_COUNT,
    COST_BLOCKED_COUNT,
    RECALC_REQUIRED_COUNT,

    OVERRIDE_USED_COUNT,
    ML_USED_COUNT,
    SAFE_DEFAULT_USED_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1;


-- ------------------------------------------------------------
-- 7. FINAL PHASE 11A CLOSURE
--
-- This closes Phase 11A infrastructure even when actual
-- outcome sample sizes are not yet sufficient.
-- ------------------------------------------------------------

WITH RUN_RESULT AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .KMAT_MONITORING_RUN_V1
    WHERE MONITORING_RUN_ID =
          'PHASE11A_MONITORING_001'
),
SAFETY AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_MONITORING_OPERATIONAL_SUMMARY_V1
),
OBJECTS AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_KMAT_MONITORING_POLICY_CURRENT_V1
        ) AS ACTIVE_POLICY_COUNT,

        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .KMAT_MONITORING_METRIC_SNAPSHOT_V1
            WHERE MONITORING_RUN_ID =
                  'PHASE11A_MONITORING_001'
        ) AS SNAPSHOT_METRIC_COUNT
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            run_result.MONITORING_RUN_ID
                IS NOT NULL
            AND objects.ACTIVE_POLICY_COUNT = 20
            AND objects.SNAPSHOT_METRIC_COUNT > 0
            AND safety.SAFETY_FAILURE_COUNT = 0
            AND safety.COST_BLOCKED_COUNT = 0
            AND safety.RECALC_REQUIRED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_11A',

    'monitoring_run_id',
        run_result.MONITORING_RUN_ID,

    'monitoring_run_status',
        run_result.RUN_STATUS,

    'active_policy_count',
        objects.ACTIVE_POLICY_COUNT,

    'snapshot_metric_count',
        objects.SNAPSHOT_METRIC_COUNT,

    'healthy_count',
        run_result.HEALTHY_COUNT,

    'warning_count',
        run_result.WARNING_COUNT,

    'critical_count',
        run_result.CRITICAL_COUNT,

    'insufficient_data_count',
        run_result.INSUFFICIENT_DATA_COUNT,

    'no_data_count',
        run_result.NO_DATA_COUNT,

    'safety_failure_count',
        safety.SAFETY_FAILURE_COUNT,

    'cost_blocked_count',
        safety.COST_BLOCKED_COUNT,

    'recalculation_required_count',
        safety.RECALC_REQUIRED_COUNT,

    'actual_outcome_authority',
        'FEEDBACK_ONLY',

    'official_cost_changed',
        FALSE,

    'business_decision_allowed',
        FALSE
) AS PHASE11A_RESULT

FROM RUN_RESULT run_result
CROSS JOIN SAFETY safety
CROSS JOIN OBJECTS objects;

SHOW PROCEDURES LIKE 'SET_ML_DEPLOYMENT_CAPABILITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'CREATE_ML_POLICY_CANDIDATE_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'SUBMIT_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'REFRESH_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'REVIEW_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'ROLLBACK_ML_DEPLOYMENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'CANCEL_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

-- Expected: 70, 0.
SELECT
    COUNT(*) AS ACTIVE_GATE_POLICY_COUNT,
    COUNT_IF(
        MODEL_DOMAIN NOT IN ('CSS','FMIS','TDS','BMCS')
        OR TARGET_MODE NOT IN ('CONTROLLED','PRODUCTION')
        OR COMPARISON_OPERATOR NOT IN ('MIN','MAX')
        OR REQUIRED_VALUE IS NULL
        OR MIN_SAMPLE_SIZE < 1
    ) AS INVALID_GATE_POLICY_ROWS
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_POLICY_CURRENT_V1;

-- Expected: zero rows.
SELECT
    MODEL_DOMAIN,
    TARGET_MODE,
    METRIC_KEY,
    COUNT(*) AS DUPLICATE_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_POLICY_CURRENT_V1
GROUP BY MODEL_DOMAIN,TARGET_MODE,METRIC_KEY
HAVING COUNT(*) > 1;

-- Expected: zero rows. This protects OBJECT_AGG sources.
SELECT
    GATE_POLICY_ID,
    COUNT(*) AS DUPLICATE_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_EVALUATION_V1
GROUP BY GATE_POLICY_ID
HAVING COUNT(*) > 1;

-- Expected: zero rows. Deployment metrics are deduplicated before gate joins.
SELECT
    MODEL_DOMAIN,
    METRIC_KEY,
    COUNT(*) AS DUPLICATE_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_METRIC_CURRENT_V1
GROUP BY MODEL_DOMAIN,METRIC_KEY
HAVING COUNT(*) > 1;

-- Expected: 4 active capabilities and 0 ready capabilities.
SELECT
    COUNT(*) AS ACTIVE_CAPABILITY_COUNT,
    COUNT_IF(READY_FLAG=TRUE) AS READY_CAPABILITY_COUNT,
    COUNT_IF(
        MODEL_DOMAIN IN ('CSS','FMIS','TDS')
        AND CAPABILITY_KEY <> 'GOVERNED_COST_RECALCULATION_READY_FLAG'
    ) AS INVALID_COST_CAPABILITY_ROWS,
    COUNT_IF(
        MODEL_DOMAIN='BMCS'
        AND CAPABILITY_KEY <> 'BMCS_BUSINESS_GATE_READY_FLAG'
    ) AS INVALID_BMCS_CAPABILITY_ROWS
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1;

-- Expected: 8 rows. READY_ROW_COUNT should be 0 initially.
CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE11B_DEPLOYMENT_DASHBOARD_V1
AS
SELECT
    readiness.MODEL_DOMAIN,
    readiness.TARGET_MODE,
    readiness.READINESS_STATUS,
    readiness.REQUIRED_GATE_COUNT,
    readiness.PASS_GATE_COUNT,
    readiness.FAIL_GATE_COUNT,
    readiness.NO_DATA_GATE_COUNT,
    readiness.INSUFFICIENT_GATE_COUNT,
    readiness.LATEST_METRIC_OBSERVED_AT,
    readiness.EVALUATED_AT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1 readiness;

SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE11B_DEPLOYMENT_DASHBOARD_V1
ORDER BY MODEL_DOMAIN,TARGET_MODE;

SELECT
    COUNT(*) AS READINESS_ROW_COUNT,
    COUNT_IF(READINESS_STATUS='READY') AS READY_ROW_COUNT,
    COUNT_IF(
        READINESS_STATUS NOT IN ('READY','NOT_READY','NO_DATA','INSUFFICIENT_DATA')
    ) AS INVALID_READINESS_ROWS
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1;

-- Expected: 5 total, 2 controlled, 3 production.
CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1
WHERE REQUIREMENT_STATUS = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY TARGET_MODE, APPROVAL_STAGE
    ORDER BY CREATED_AT DESC, REQUIREMENT_ID DESC
) = 1;

SELECT
    COUNT(*) AS REQUIREMENT_COUNT,
    COUNT_IF(TARGET_MODE='CONTROLLED') AS CONTROLLED_REQUIREMENTS,
    COUNT_IF(TARGET_MODE='PRODUCTION') AS PRODUCTION_REQUIREMENTS
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1;

-- Active authority must remain SHADOW and disabled.
SELECT
    MODEL_DOMAIN,
    POLICY_ID,
    POLICY_VERSION,
    DEPLOYMENT_MODE,
    AUTO_USE_ALLOWED_FLAG,
    OFFICIAL_COST_IMPACT_ALLOWED_FLAG,
    BUSINESS_DECISION_ALLOWED_FLAG
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
ORDER BY MODEL_DOMAIN;

WITH GATES AS (
    SELECT
        COUNT(*) AS GATE_COUNT,
        COUNT_IF(
            MODEL_DOMAIN NOT IN ('CSS','FMIS','TDS','BMCS')
            OR TARGET_MODE NOT IN ('CONTROLLED','PRODUCTION')
            OR COMPARISON_OPERATOR NOT IN ('MIN','MAX')
            OR MIN_SAMPLE_SIZE < 1
        ) AS INVALID_GATE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_POLICY_CURRENT_V1
),
CAPABILITIES AS (
    SELECT
        COUNT(*) AS CAPABILITY_COUNT,
        COUNT_IF(READY_FLAG=TRUE) AS READY_CAPABILITY_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1
),
READINESS AS (
    SELECT
        COUNT(*) AS READINESS_COUNT,
        COUNT_IF(READINESS_STATUS='READY') AS READY_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1
),
APPROVALS AS (
    SELECT COUNT(*) AS REQUIREMENT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
),
POLICIES AS (
    SELECT
        COUNT(*) AS ACTIVE_POLICY_COUNT,
        COUNT_IF(DEPLOYMENT_MODE='SHADOW') AS SHADOW_POLICY_COUNT,
        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG=TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG=TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG=TRUE
        ) AS AUTHORITY_ENABLED_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',IFF(
        gates.GATE_COUNT=70
        AND gates.INVALID_GATE_COUNT=0
        AND capabilities.CAPABILITY_COUNT=4
        AND capabilities.READY_CAPABILITY_COUNT=0
        AND readiness.READINESS_COUNT=8
        AND readiness.READY_COUNT=0
        AND approvals.REQUIREMENT_COUNT=5
        AND policies.ACTIVE_POLICY_COUNT=4
        AND policies.SHADOW_POLICY_COUNT=4
        AND policies.AUTHORITY_ENABLED_COUNT=0,
        'SUCCESS','FAILED'
    ),
    'phase','PHASE_11B',
    'active_gate_policy_count',gates.GATE_COUNT,
    'active_capability_count',capabilities.CAPABILITY_COUNT,
    'ready_capability_count',capabilities.READY_CAPABILITY_COUNT,
    'readiness_row_count',readiness.READINESS_COUNT,
    'ready_deployment_count',readiness.READY_COUNT,
    'approval_requirement_count',approvals.REQUIREMENT_COUNT,
    'active_policy_count',policies.ACTIVE_POLICY_COUNT,
    'shadow_policy_count',policies.SHADOW_POLICY_COUNT,
    'authority_enabled_count',policies.AUTHORITY_ENABLED_COUNT,
    'deployment_workflow_status','BLOCKED_UNTIL_CAPABILITY_AND_EVIDENCE_PASS',
    'official_cost_changed',FALSE,
    'policy_activated',FALSE
) AS PHASE11B_RESULT
FROM GATES gates
CROSS JOIN CAPABILITIES capabilities
CROSS JOIN READINESS readiness
CROSS JOIN APPROVALS approvals
CROSS JOIN POLICIES policies;

-- ============================================================
-- PHASE 11B — PROCEDURE DEPLOYMENT DIAGNOSTIC
-- ============================================================

SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;


-- SHOW only lists procedures visible to the current role.
SHOW USER PROCEDURES
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- Direct information-schema check.
SELECT
    PROCEDURE_CATALOG,
    PROCEDURE_SCHEMA,
    PROCEDURE_NAME,
    ARGUMENT_SIGNATURE,
    DATA_TYPE,
    PROCEDURE_LANGUAGE,
    CREATED,
    LAST_ALTERED
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'SET_ML_DEPLOYMENT_CAPABILITY_V1',
      'CREATE_ML_POLICY_CANDIDATE_V1',
      'SUBMIT_ML_DEPLOYMENT_REQUEST_V1',
      'REFRESH_ML_DEPLOYMENT_REQUEST_V1',
      'REVIEW_ML_DEPLOYMENT_REQUEST_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1',
      'ROLLBACK_ML_DEPLOYMENT_V1',
      'CANCEL_ML_DEPLOYMENT_REQUEST_V1'
  )
ORDER BY PROCEDURE_NAME;


-- Confirm how far the Phase 11B deployment ran.
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE,
    CREATED,
    LAST_ALTERED
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORE_ML'
  AND (
      TABLE_NAME LIKE 'ML_DEPLOYMENT%'
      OR TABLE_NAME LIKE 'VW_ML_DEPLOYMENT%'
      OR TABLE_NAME =
          'VW_KMAT_PHASE11B_DEPLOYMENT_DASHBOARD_V1'
  )
ORDER BY TABLE_NAME;


-- Inspect recent Phase 11B failures in this session.
SELECT
    START_TIME,
    QUERY_TYPE,
    EXECUTION_STATUS,
    ERROR_CODE,
    ERROR_MESSAGE,
    QUERY_TEXT
FROM TABLE(
    KMAT_COST_MODEL_DB.INFORMATION_SCHEMA
        .QUERY_HISTORY_BY_SESSION(
            RESULT_LIMIT => 200
        )
)
WHERE (
        QUERY_TEXT ILIKE '%ML_DEPLOYMENT%'
        OR QUERY_TEXT ILIKE '%PHASE11B%'
      )
ORDER BY START_TIME DESC;


-- Inspect schema privileges available to the current role.
SHOW GRANTS ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

-- ============================================================
-- PHASE 11B — PROCEDURES-ONLY REDEPLOYMENT
--
-- Run only after phase11b_00_procedure_diagnostic.sql confirms
-- the Phase 11B tables/views exist and the role can create
-- procedures in KMAT_COST_MODEL_DB.CORE_ML.
--
-- All procedure names are fully qualified.
-- ============================================================

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(
    P_CAPABILITY_ID VARCHAR,
    P_MODEL_DOMAIN VARCHAR,
    P_CAPABILITY_KEY VARCHAR,
    P_CAPABILITY_VERSION VARCHAR,
    P_READY_FLAG BOOLEAN,
    P_EVIDENCE_REFERENCE VARCHAR,
    P_APPROVAL_REASON VARCHAR,
    P_APPROVED_BY VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_COUNT NUMBER DEFAULT 0;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
    V_EVENT_ID VARCHAR;
BEGIN
    IF (P_CAPABILITY_ID IS NULL OR LENGTH(TRIM(P_CAPABILITY_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_CAPABILITY_ID is required.'');
    END IF;

    IF (
        P_MODEL_DOMAIN IS NULL
        OR UPPER(TRIM(P_MODEL_DOMAIN)) NOT IN (''CSS'',''FMIS'',''TDS'',''BMCS'')
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_MODEL_DOMAIN must be CSS, FMIS, TDS, or BMCS.'');
    END IF;

    IF (P_CAPABILITY_KEY IS NULL OR LENGTH(TRIM(P_CAPABILITY_KEY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_CAPABILITY_KEY is required.'');
    END IF;

    IF (
        UPPER(TRIM(P_MODEL_DOMAIN)) IN (''CSS'',''FMIS'',''TDS'')
        AND UPPER(TRIM(P_CAPABILITY_KEY)) <> ''GOVERNED_COST_RECALCULATION_READY_FLAG''
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Cost domains require GOVERNED_COST_RECALCULATION_READY_FLAG.'');
    END IF;

    IF (
        UPPER(TRIM(P_MODEL_DOMAIN)) = ''BMCS''
        AND UPPER(TRIM(P_CAPABILITY_KEY)) <> ''BMCS_BUSINESS_GATE_READY_FLAG''
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''BMCS requires BMCS_BUSINESS_GATE_READY_FLAG.'');
    END IF;

    IF (P_CAPABILITY_VERSION IS NULL OR LENGTH(TRIM(P_CAPABILITY_VERSION)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_CAPABILITY_VERSION is required.'');
    END IF;

    IF (
        P_READY_FLAG
        AND (P_EVIDENCE_REFERENCE IS NULL OR LENGTH(TRIM(P_EVIDENCE_REFERENCE)) = 0)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''A READY capability requires an evidence reference.'');
    END IF;

    IF (P_APPROVAL_REASON IS NULL OR LENGTH(TRIM(P_APPROVAL_REASON)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_APPROVAL_REASON is required.'');
    END IF;

    IF (P_APPROVED_BY IS NULL OR LENGTH(TRIM(P_APPROVED_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_APPROVED_BY is required.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1
    WHERE CAPABILITY_ID = :P_CAPABILITY_ID;

    IF (V_EXISTING_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''CAPABILITY_ID already exists.'');
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1
    SET
        CAPABILITY_STATUS = ''RETIRED'',
        EFFECTIVE_TO = CURRENT_TIMESTAMP(),
        UPDATED_BY = TRIM(:P_APPROVED_BY),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE MODEL_DOMAIN = UPPER(TRIM(:P_MODEL_DOMAIN))
      AND CAPABILITY_KEY = UPPER(TRIM(:P_CAPABILITY_KEY))
      AND CAPABILITY_STATUS = ''ACTIVE'';

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 (
        CAPABILITY_ID,MODEL_DOMAIN,CAPABILITY_KEY,CAPABILITY_VERSION,
        CAPABILITY_STATUS,READY_FLAG,EVIDENCE_REFERENCE,APPROVAL_REASON,
        EFFECTIVE_FROM,EFFECTIVE_TO,APPROVED_BY,APPROVED_AT,
        CREATED_BY,CREATED_AT,UPDATED_BY,UPDATED_AT
    )
    SELECT
        TRIM(:P_CAPABILITY_ID),UPPER(TRIM(:P_MODEL_DOMAIN)),UPPER(TRIM(:P_CAPABILITY_KEY)),
        TRIM(:P_CAPABILITY_VERSION),''ACTIVE'',:P_READY_FLAG,:P_EVIDENCE_REFERENCE,
        TRIM(:P_APPROVAL_REASON),CURRENT_TIMESTAMP(),NULL::TIMESTAMP_NTZ,
        TRIM(:P_APPROVED_BY),CURRENT_TIMESTAMP(),CURRENT_USER(),CURRENT_TIMESTAMP(),
        CURRENT_USER(),CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Capability insert did not affect exactly one row.'',''inserted_rows'',V_INSERTED_ROWS);
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,''DEPLOYMENT_CAPABILITY_SET'',NULL::VARCHAR,UPPER(TRIM(:P_MODEL_DOMAIN)),
        NULL::VARCHAR,NULL::VARCHAR,NULL::VARCHAR,IFF(:P_READY_FLAG,''READY'',''NOT_READY''),
        NULL::NUMBER,TRIM(:P_APPROVED_BY),TRIM(:P_APPROVAL_REASON),
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''capability_id'',TRIM(:P_CAPABILITY_ID),
            ''capability_key'',UPPER(TRIM(:P_CAPABILITY_KEY)),
            ''capability_version'',TRIM(:P_CAPABILITY_VERSION),
            ''ready_flag'',:P_READY_FLAG,
            ''evidence_reference'',:P_EVIDENCE_REFERENCE
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''phase'',''PHASE_11B'',
        ''capability_id'',P_CAPABILITY_ID,
        ''model_domain'',UPPER(TRIM(P_MODEL_DOMAIN)),
        ''capability_key'',UPPER(TRIM(P_CAPABILITY_KEY)),
        ''capability_version'',P_CAPABILITY_VERSION,
        ''ready_flag'',P_READY_FLAG,
        ''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(
    P_DEPLOYMENT_REQUEST_ID VARCHAR,
    P_MODEL_DOMAIN VARCHAR,
    P_CANDIDATE_POLICY_VERSION VARCHAR,
    P_REQUESTED_BY VARCHAR,
    P_BUSINESS_JUSTIFICATION VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_REQUEST_COUNT NUMBER DEFAULT 0;
    V_CANDIDATE_COUNT NUMBER DEFAULT 0;
    V_OPEN_CANDIDATE_REQUEST_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_POLICY_COUNT NUMBER DEFAULT 0;
    V_READINESS_COUNT NUMBER DEFAULT 0;

    V_TARGET_MODE VARCHAR;
    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_MODEL_NAME VARCHAR;
    V_CANDIDATE_MODEL_VERSION VARCHAR;
    V_CANDIDATE_FEATURE_SET_VERSION VARCHAR;

    V_FROM_POLICY_ID VARCHAR;
    V_FROM_POLICY_VERSION VARCHAR;
    V_FROM_DEPLOYMENT_MODE VARCHAR;

    V_READINESS_STATUS VARCHAR;
    V_REQUIRED_GATE_COUNT NUMBER DEFAULT 0;
    V_PASS_GATE_COUNT NUMBER DEFAULT 0;
    V_FAIL_GATE_COUNT NUMBER DEFAULT 0;
    V_NO_DATA_GATE_COUNT NUMBER DEFAULT 0;
    V_INSUFFICIENT_GATE_COUNT NUMBER DEFAULT 0;

    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_SNAPSHOT VARIANT;
    V_EVIDENCE_VERSION NUMBER DEFAULT 1;
    V_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (P_DEPLOYMENT_REQUEST_ID IS NULL OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_DEPLOYMENT_REQUEST_ID is required.'');
    END IF;

    IF (
        P_MODEL_DOMAIN IS NULL
        OR UPPER(TRIM(P_MODEL_DOMAIN)) NOT IN (''CSS'',''FMIS'',''TDS'',''BMCS'')
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_MODEL_DOMAIN must be CSS, FMIS, TDS, or BMCS.'');
    END IF;

    IF (P_CANDIDATE_POLICY_VERSION IS NULL OR LENGTH(TRIM(P_CANDIDATE_POLICY_VERSION)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_CANDIDATE_POLICY_VERSION is required.'');
    END IF;

    IF (P_REQUESTED_BY IS NULL OR LENGTH(TRIM(P_REQUESTED_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REQUESTED_BY is required.'');
    END IF;

    IF (P_BUSINESS_JUSTIFICATION IS NULL OR LENGTH(TRIM(P_BUSINESS_JUSTIFICATION)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_BUSINESS_JUSTIFICATION is required.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_REQUEST_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_EXISTING_REQUEST_COUNT = 1) THEN
        SELECT
            REQUEST_STATUS,
            READINESS_STATUS,
            EVIDENCE_VERSION
        INTO
            :V_REQUEST_STATUS,
            :V_READINESS_STATUS,
            :V_EVIDENCE_VERSION
        FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
        WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''SUCCESS'',
            ''idempotent_replay'',TRUE,
            ''phase'',''PHASE_11B'',
            ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
            ''request_status'',V_REQUEST_STATUS,
            ''readiness_status'',V_READINESS_STATUS,
            ''evidence_version'',V_EVIDENCE_VERSION
        );
    END IF;

    IF (V_EXISTING_REQUEST_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Deployment request ID is not unique.'');
    END IF;

    SELECT
        COUNT(*),MAX(POLICY_ID),MAX(DEPLOYMENT_MODE),
        MAX(GET(POLICY_CONFIG,''candidate_model_name'')::VARCHAR),
        MAX(GET(POLICY_CONFIG,''candidate_model_version'')::VARCHAR),
        MAX(GET(POLICY_CONFIG,''candidate_feature_set_version'')::VARCHAR)
    INTO
        :V_CANDIDATE_COUNT,:V_CANDIDATE_POLICY_ID,:V_TARGET_MODE,
        :V_CANDIDATE_MODEL_NAME,:V_CANDIDATE_MODEL_VERSION,:V_CANDIDATE_FEATURE_SET_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    WHERE MODEL_DOMAIN = UPPER(TRIM(:P_MODEL_DOMAIN))
      AND POLICY_VERSION = TRIM(:P_CANDIDATE_POLICY_VERSION)
      AND POLICY_STATUS = ''DRAFT'';

    IF (V_CANDIDATE_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one DRAFT candidate policy is required.'',''candidate_count'',V_CANDIDATE_COUNT);
    END IF;

    SELECT COUNT(*)
    INTO :V_OPEN_CANDIDATE_REQUEST_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE CANDIDATE_POLICY_ID = :V_CANDIDATE_POLICY_ID
      AND CANDIDATE_POLICY_VERSION = TRIM(:P_CANDIDATE_POLICY_VERSION)
      AND REQUEST_STATUS NOT IN (''REJECTED'',''CANCELLED'',''ROLLED_BACK'');

    IF (V_OPEN_CANDIDATE_REQUEST_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'',''ERROR'',
            ''message'',''An open deployment request already exists for this candidate policy.'',
            ''open_request_count'',V_OPEN_CANDIDATE_REQUEST_COUNT
        );
    END IF;

    IF (V_TARGET_MODE NOT IN (''CONTROLLED'',''PRODUCTION'')) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Candidate target mode must be CONTROLLED or PRODUCTION.'');
    END IF;

    IF (
        V_CANDIDATE_MODEL_NAME IS NULL
        OR V_CANDIDATE_MODEL_VERSION IS NULL
        OR V_CANDIDATE_FEATURE_SET_VERSION IS NULL
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Candidate policy must contain complete model lineage in POLICY_CONFIG.'');
    END IF;

    SELECT COUNT(*),MAX(POLICY_ID),MAX(POLICY_VERSION),MAX(DEPLOYMENT_MODE)
    INTO :V_ACTIVE_POLICY_COUNT,:V_FROM_POLICY_ID,:V_FROM_POLICY_VERSION,:V_FROM_DEPLOYMENT_MODE
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = UPPER(TRIM(:P_MODEL_DOMAIN));

    IF (V_ACTIVE_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one active source policy is required.'',''active_policy_count'',V_ACTIVE_POLICY_COUNT);
    END IF;

    SELECT
        COUNT(*),MAX(READINESS_STATUS),MAX(REQUIRED_GATE_COUNT),MAX(PASS_GATE_COUNT),
        MAX(FAIL_GATE_COUNT),MAX(NO_DATA_GATE_COUNT),MAX(INSUFFICIENT_GATE_COUNT)
    INTO
        :V_READINESS_COUNT,:V_READINESS_STATUS,:V_REQUIRED_GATE_COUNT,:V_PASS_GATE_COUNT,
        :V_FAIL_GATE_COUNT,:V_NO_DATA_GATE_COUNT,:V_INSUFFICIENT_GATE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1
    WHERE MODEL_DOMAIN = UPPER(TRIM(:P_MODEL_DOMAIN))
      AND TARGET_MODE = :V_TARGET_MODE;

    IF (V_READINESS_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one readiness result is required.'',''readiness_count'',V_READINESS_COUNT);
    END IF;

    SELECT OBJECT_AGG(
        GATE_POLICY_ID,
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''metric_key'',METRIC_KEY,''metric_name'',METRIC_NAME,
            ''metric_value'',METRIC_VALUE,''metric_unit'',METRIC_UNIT,
            ''sample_size'',SAMPLE_SIZE,''comparison_operator'',COMPARISON_OPERATOR,
            ''required_value'',REQUIRED_VALUE,''minimum_sample_size'',MIN_SAMPLE_SIZE,
            ''gate_status'',GATE_STATUS,''gate_message'',GATE_MESSAGE,
            ''observed_at'',OBSERVED_AT,''gate_policy_version'',GATE_POLICY_VERSION
        )
    )
    INTO :V_EVIDENCE_SNAPSHOT
    FROM (
        SELECT
            GATE_POLICY_ID,METRIC_KEY,METRIC_NAME,METRIC_VALUE,METRIC_UNIT,SAMPLE_SIZE,
            COMPARISON_OPERATOR,REQUIRED_VALUE,MIN_SAMPLE_SIZE,GATE_STATUS,GATE_MESSAGE,
            OBSERVED_AT,GATE_POLICY_VERSION
        FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_EVALUATION_V1
        WHERE MODEL_DOMAIN = UPPER(TRIM(:P_MODEL_DOMAIN))
          AND TARGET_MODE = :V_TARGET_MODE
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY GATE_POLICY_ID
            ORDER BY OBSERVED_AT DESC NULLS LAST,GATE_POLICY_ID DESC
        ) = 1
    );

    V_REQUEST_STATUS := IFF(V_READINESS_STATUS = ''READY'',''SUBMITTED'',''GATE_BLOCKED'');
    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 (
        DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,TARGET_MODE,
        FROM_POLICY_ID,FROM_POLICY_VERSION,FROM_DEPLOYMENT_MODE,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,
        CANDIDATE_MODEL_NAME,CANDIDATE_MODEL_VERSION,CANDIDATE_FEATURE_SET_VERSION,
        REQUEST_STATUS,READINESS_STATUS,EVIDENCE_VERSION,
        REQUIRED_GATE_COUNT,PASS_GATE_COUNT,FAIL_GATE_COUNT,NO_DATA_GATE_COUNT,INSUFFICIENT_GATE_COUNT,
        EVIDENCE_SNAPSHOT,EVIDENCE_CAPTURED_AT,
        REQUESTED_BY,REQUESTED_AT,BUSINESS_JUSTIFICATION,
        APPROVED_BY,APPROVED_AT,ACTIVATED_BY,ACTIVATED_AT,
        ROLLED_BACK_BY,ROLLED_BACK_AT,ROLLBACK_REASON,
        LAST_REFRESHED_BY,LAST_REFRESHED_AT,CREATED_AT,UPDATED_AT
    )
    SELECT
        TRIM(:P_DEPLOYMENT_REQUEST_ID),UPPER(TRIM(:P_MODEL_DOMAIN)),:V_TARGET_MODE,
        :V_FROM_POLICY_ID,:V_FROM_POLICY_VERSION,:V_FROM_DEPLOYMENT_MODE,
        :V_CANDIDATE_POLICY_ID,TRIM(:P_CANDIDATE_POLICY_VERSION),
        :V_CANDIDATE_MODEL_NAME,:V_CANDIDATE_MODEL_VERSION,:V_CANDIDATE_FEATURE_SET_VERSION,
        :V_REQUEST_STATUS,:V_READINESS_STATUS,:V_EVIDENCE_VERSION,
        :V_REQUIRED_GATE_COUNT,:V_PASS_GATE_COUNT,:V_FAIL_GATE_COUNT,:V_NO_DATA_GATE_COUNT,:V_INSUFFICIENT_GATE_COUNT,
        :V_EVIDENCE_SNAPSHOT,CURRENT_TIMESTAMP(),
        TRIM(:P_REQUESTED_BY),CURRENT_TIMESTAMP(),TRIM(:P_BUSINESS_JUSTIFICATION),
        NULL::VARCHAR,NULL::TIMESTAMP_NTZ,NULL::VARCHAR,NULL::TIMESTAMP_NTZ,
        NULL::VARCHAR,NULL::TIMESTAMP_NTZ,NULL::VARCHAR,
        TRIM(:P_REQUESTED_BY),CURRENT_TIMESTAMP(),CURRENT_TIMESTAMP(),CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Deployment request insert did not affect exactly one row.'',''inserted_rows'',V_INSERTED_ROWS);
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,''DEPLOYMENT_REQUEST_SUBMITTED'',TRIM(:P_DEPLOYMENT_REQUEST_ID),
        UPPER(TRIM(:P_MODEL_DOMAIN)),:V_CANDIDATE_POLICY_ID,TRIM(:P_CANDIDATE_POLICY_VERSION),
        :V_TARGET_MODE,:V_REQUEST_STATUS,:V_EVIDENCE_VERSION,TRIM(:P_REQUESTED_BY),
        TRIM(:P_BUSINESS_JUSTIFICATION),
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''readiness_status'',:V_READINESS_STATUS,
            ''required_gate_count'',:V_REQUIRED_GATE_COUNT,
            ''pass_gate_count'',:V_PASS_GATE_COUNT,
            ''fail_gate_count'',:V_FAIL_GATE_COUNT,
            ''no_data_gate_count'',:V_NO_DATA_GATE_COUNT,
            ''insufficient_gate_count'',:V_INSUFFICIENT_GATE_COUNT,
            ''from_policy_id'',:V_FROM_POLICY_ID,
            ''from_policy_version'',:V_FROM_POLICY_VERSION,
            ''from_deployment_mode'',:V_FROM_DEPLOYMENT_MODE
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''idempotent_replay'',FALSE,''phase'',''PHASE_11B'',
        ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
        ''model_domain'',UPPER(TRIM(P_MODEL_DOMAIN)),''target_mode'',V_TARGET_MODE,
        ''candidate_policy_id'',V_CANDIDATE_POLICY_ID,
        ''candidate_policy_version'',P_CANDIDATE_POLICY_VERSION,
        ''request_status'',V_REQUEST_STATUS,''readiness_status'',V_READINESS_STATUS,
        ''evidence_version'',V_EVIDENCE_VERSION,
        ''required_gate_count'',V_REQUIRED_GATE_COUNT,''pass_gate_count'',V_PASS_GATE_COUNT,
        ''fail_gate_count'',V_FAIL_GATE_COUNT,''no_data_gate_count'',V_NO_DATA_GATE_COUNT,
        ''insufficient_gate_count'',V_INSUFFICIENT_GATE_COUNT,''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(
    P_DEPLOYMENT_REQUEST_ID VARCHAR,
    P_REFRESHED_BY VARCHAR,
    P_REFRESH_REASON VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;
    V_CURRENT_STATUS VARCHAR;
    V_CURRENT_EVIDENCE_VERSION NUMBER;

    V_READINESS_STATUS VARCHAR;
    V_REQUIRED_GATE_COUNT NUMBER DEFAULT 0;
    V_PASS_GATE_COUNT NUMBER DEFAULT 0;
    V_FAIL_GATE_COUNT NUMBER DEFAULT 0;
    V_NO_DATA_GATE_COUNT NUMBER DEFAULT 0;
    V_INSUFFICIENT_GATE_COUNT NUMBER DEFAULT 0;

    V_NEW_REQUEST_STATUS VARCHAR;
    V_NEW_EVIDENCE_VERSION NUMBER;
    V_EVIDENCE_SNAPSHOT VARIANT;
    V_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (P_DEPLOYMENT_REQUEST_ID IS NULL OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_DEPLOYMENT_REQUEST_ID is required.'');
    END IF;

    IF (P_REFRESHED_BY IS NULL OR LENGTH(TRIM(P_REFRESHED_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REFRESHED_BY is required.'');
    END IF;

    IF (P_REFRESH_REASON IS NULL OR LENGTH(TRIM(P_REFRESH_REASON)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REFRESH_REASON is required.'');
    END IF;

    SELECT
        COUNT(*),MAX(MODEL_DOMAIN),MAX(TARGET_MODE),MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),MAX(REQUEST_STATUS),MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_COUNT,:V_MODEL_DOMAIN,:V_TARGET_MODE,:V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,:V_CURRENT_STATUS,:V_CURRENT_EVIDENCE_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one deployment request is required.'',''request_count'',V_REQUEST_COUNT);
    END IF;

    IF (V_CURRENT_STATUS IN (''ACTIVATED'',''ROLLED_BACK'',''CANCELLED'')) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Evidence cannot be refreshed for a completed request.'',''request_status'',V_CURRENT_STATUS);
    END IF;

    SELECT
        MAX(READINESS_STATUS),MAX(REQUIRED_GATE_COUNT),MAX(PASS_GATE_COUNT),
        MAX(FAIL_GATE_COUNT),MAX(NO_DATA_GATE_COUNT),MAX(INSUFFICIENT_GATE_COUNT)
    INTO
        :V_READINESS_STATUS,:V_REQUIRED_GATE_COUNT,:V_PASS_GATE_COUNT,
        :V_FAIL_GATE_COUNT,:V_NO_DATA_GATE_COUNT,:V_INSUFFICIENT_GATE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND TARGET_MODE = :V_TARGET_MODE;

    SELECT OBJECT_AGG(
        GATE_POLICY_ID,
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''metric_key'',METRIC_KEY,''metric_name'',METRIC_NAME,
            ''metric_value'',METRIC_VALUE,''metric_unit'',METRIC_UNIT,
            ''sample_size'',SAMPLE_SIZE,''comparison_operator'',COMPARISON_OPERATOR,
            ''required_value'',REQUIRED_VALUE,''minimum_sample_size'',MIN_SAMPLE_SIZE,
            ''gate_status'',GATE_STATUS,''gate_message'',GATE_MESSAGE,
            ''observed_at'',OBSERVED_AT,''gate_policy_version'',GATE_POLICY_VERSION
        )
    )
    INTO :V_EVIDENCE_SNAPSHOT
    FROM (
        SELECT
            GATE_POLICY_ID,METRIC_KEY,METRIC_NAME,METRIC_VALUE,METRIC_UNIT,SAMPLE_SIZE,
            COMPARISON_OPERATOR,REQUIRED_VALUE,MIN_SAMPLE_SIZE,GATE_STATUS,GATE_MESSAGE,
            OBSERVED_AT,GATE_POLICY_VERSION
        FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_GATE_EVALUATION_V1
        WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
          AND TARGET_MODE = :V_TARGET_MODE
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY GATE_POLICY_ID
            ORDER BY OBSERVED_AT DESC NULLS LAST,GATE_POLICY_ID DESC
        ) = 1
    );

    V_NEW_EVIDENCE_VERSION := V_CURRENT_EVIDENCE_VERSION + 1;
    V_NEW_REQUEST_STATUS := IFF(V_READINESS_STATUS = ''READY'',''SUBMITTED'',''GATE_BLOCKED'');
    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    SET
        REQUEST_STATUS = :V_NEW_REQUEST_STATUS,
        READINESS_STATUS = :V_READINESS_STATUS,
        EVIDENCE_VERSION = :V_NEW_EVIDENCE_VERSION,
        REQUIRED_GATE_COUNT = :V_REQUIRED_GATE_COUNT,
        PASS_GATE_COUNT = :V_PASS_GATE_COUNT,
        FAIL_GATE_COUNT = :V_FAIL_GATE_COUNT,
        NO_DATA_GATE_COUNT = :V_NO_DATA_GATE_COUNT,
        INSUFFICIENT_GATE_COUNT = :V_INSUFFICIENT_GATE_COUNT,
        EVIDENCE_SNAPSHOT = :V_EVIDENCE_SNAPSHOT,
        EVIDENCE_CAPTURED_AT = CURRENT_TIMESTAMP(),
        APPROVED_BY = NULL,
        APPROVED_AT = NULL,
        LAST_REFRESHED_BY = TRIM(:P_REFRESHED_BY),
        LAST_REFRESHED_AT = CURRENT_TIMESTAMP(),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Request refresh did not update exactly one row.'',''updated_rows'',V_UPDATED_ROWS);
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,''DEPLOYMENT_EVIDENCE_REFRESHED'',:P_DEPLOYMENT_REQUEST_ID,:V_MODEL_DOMAIN,
        :V_CANDIDATE_POLICY_ID,:V_CANDIDATE_POLICY_VERSION,:V_TARGET_MODE,
        :V_NEW_REQUEST_STATUS,:V_NEW_EVIDENCE_VERSION,TRIM(:P_REFRESHED_BY),TRIM(:P_REFRESH_REASON),
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''previous_evidence_version'',:V_CURRENT_EVIDENCE_VERSION,
            ''new_evidence_version'',:V_NEW_EVIDENCE_VERSION,
            ''readiness_status'',:V_READINESS_STATUS,
            ''required_gate_count'',:V_REQUIRED_GATE_COUNT,
            ''pass_gate_count'',:V_PASS_GATE_COUNT,
            ''fail_gate_count'',:V_FAIL_GATE_COUNT,
            ''no_data_gate_count'',:V_NO_DATA_GATE_COUNT,
            ''insufficient_gate_count'',:V_INSUFFICIENT_GATE_COUNT,
            ''prior_approvals_invalidated'',TRUE
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''phase'',''PHASE_11B'',
        ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
        ''request_status'',V_NEW_REQUEST_STATUS,
        ''readiness_status'',V_READINESS_STATUS,
        ''evidence_version'',V_NEW_EVIDENCE_VERSION,
        ''prior_approvals_invalidated'',TRUE,
        ''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(
    P_APPROVAL_ID VARCHAR,
    P_DEPLOYMENT_REQUEST_ID VARCHAR,
    P_APPROVAL_STAGE VARCHAR,
    P_REVIEW_ACTION VARCHAR,
    P_REVIEWED_BY VARCHAR,
    P_REVIEW_NOTE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_READINESS_STATUS VARCHAR;
    V_REQUESTED_BY VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_STAGE_REQUIRED_COUNT NUMBER DEFAULT 0;
    V_EXISTING_APPROVAL_COUNT NUMBER DEFAULT 0;
    V_REVIEWER_REUSE_COUNT NUMBER DEFAULT 0;
    V_REQUIRED_APPROVAL_COUNT NUMBER DEFAULT 0;
    V_APPROVED_STAGE_COUNT NUMBER DEFAULT 0;
    V_REJECTED_STAGE_COUNT NUMBER DEFAULT 0;
    V_NEW_REQUEST_STATUS VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (P_APPROVAL_ID IS NULL OR LENGTH(TRIM(P_APPROVAL_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_APPROVAL_ID is required.'');
    END IF;

    IF (P_DEPLOYMENT_REQUEST_ID IS NULL OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_DEPLOYMENT_REQUEST_ID is required.'');
    END IF;

    IF (
        P_APPROVAL_STAGE IS NULL
        OR UPPER(TRIM(P_APPROVAL_STAGE)) NOT IN (''TECHNICAL'',''BUSINESS'',''RISK'')
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_APPROVAL_STAGE must be TECHNICAL, BUSINESS, or RISK.'');
    END IF;

    IF (
        P_REVIEW_ACTION IS NULL
        OR UPPER(TRIM(P_REVIEW_ACTION)) NOT IN (''APPROVE'',''REJECT'')
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REVIEW_ACTION must be APPROVE or REJECT.'');
    END IF;

    IF (P_REVIEWED_BY IS NULL OR LENGTH(TRIM(P_REVIEWED_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REVIEWED_BY is required.'');
    END IF;

    IF (P_REVIEW_NOTE IS NULL OR LENGTH(TRIM(P_REVIEW_NOTE)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_REVIEW_NOTE is required.'');
    END IF;

    SELECT
        COUNT(*),MAX(MODEL_DOMAIN),MAX(TARGET_MODE),MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),MAX(REQUEST_STATUS),MAX(READINESS_STATUS),
        MAX(REQUESTED_BY),MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_COUNT,:V_MODEL_DOMAIN,:V_TARGET_MODE,:V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,:V_REQUEST_STATUS,:V_READINESS_STATUS,
        :V_REQUESTED_BY,:V_EVIDENCE_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one deployment request is required.'',''request_count'',V_REQUEST_COUNT);
    END IF;

    IF (V_REQUEST_STATUS NOT IN (''SUBMITTED'',''APPROVAL_IN_PROGRESS'')) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Request is not open for review.'',''request_status'',V_REQUEST_STATUS);
    END IF;

    IF (V_READINESS_STATUS <> ''READY'') THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Deployment gates are not READY.'',''readiness_status'',V_READINESS_STATUS);
    END IF;

    IF (UPPER(TRIM(P_REVIEWED_BY)) = UPPER(TRIM(V_REQUESTED_BY))) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Requester cannot approve their own deployment request.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_STAGE_REQUIRED_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
    WHERE TARGET_MODE = :V_TARGET_MODE
      AND APPROVAL_STAGE = UPPER(TRIM(:P_APPROVAL_STAGE));

    IF (V_STAGE_REQUIRED_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Approval stage is not required for the target mode.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_APPROVAL_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1
    WHERE APPROVAL_ID = :P_APPROVAL_ID
       OR (
            DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID
            AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
            AND APPROVAL_STAGE = UPPER(TRIM(:P_APPROVAL_STAGE))
       );

    IF (V_EXISTING_APPROVAL_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Approval ID or stage approval already exists for the current evidence version.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_REVIEWER_REUSE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
      AND UPPER(TRIM(REVIEWED_BY)) = UPPER(TRIM(:P_REVIEWED_BY));

    IF (V_REVIEWER_REUSE_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''The same reviewer cannot approve more than one stage for an evidence version.'');
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 (
        APPROVAL_ID,DEPLOYMENT_REQUEST_ID,EVIDENCE_VERSION,
        APPROVAL_STAGE,REVIEW_ACTION,REVIEWED_BY,REVIEW_NOTE,REVIEWED_AT,CREATED_AT
    )
    SELECT
        TRIM(:P_APPROVAL_ID),TRIM(:P_DEPLOYMENT_REQUEST_ID),:V_EVIDENCE_VERSION,
        UPPER(TRIM(:P_APPROVAL_STAGE)),UPPER(TRIM(:P_REVIEW_ACTION)),
        TRIM(:P_REVIEWED_BY),TRIM(:P_REVIEW_NOTE),CURRENT_TIMESTAMP(),CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Approval insert did not affect exactly one row.'',''inserted_rows'',V_INSERTED_ROWS);
    END IF;

    SELECT COUNT(*)
    INTO :V_REQUIRED_APPROVAL_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
    WHERE TARGET_MODE = :V_TARGET_MODE;

    SELECT
        COUNT_IF(approval.REVIEW_ACTION = ''APPROVE''),
        COUNT_IF(approval.REVIEW_ACTION = ''REJECT'')
    INTO :V_APPROVED_STAGE_COUNT,:V_REJECTED_STAGE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1 requirement
    LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1 approval
        ON approval.DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID
       AND approval.EVIDENCE_VERSION = :V_EVIDENCE_VERSION
       AND approval.APPROVAL_STAGE = requirement.APPROVAL_STAGE
    WHERE requirement.TARGET_MODE = :V_TARGET_MODE;

    IF (UPPER(TRIM(P_REVIEW_ACTION)) = ''REJECT'') THEN
        V_NEW_REQUEST_STATUS := ''REJECTED'';
    ELSE
        V_NEW_REQUEST_STATUS := IFF(
            V_APPROVED_STAGE_COUNT = V_REQUIRED_APPROVAL_COUNT
            AND V_REJECTED_STAGE_COUNT = 0,
            ''APPROVED'',''APPROVAL_IN_PROGRESS''
        );
    END IF;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    SET
        REQUEST_STATUS = :V_NEW_REQUEST_STATUS,
        APPROVED_BY = IFF(:V_NEW_REQUEST_STATUS=''APPROVED'',TRIM(:P_REVIEWED_BY),NULL::VARCHAR),
        APPROVED_AT = IFF(:V_NEW_REQUEST_STATUS=''APPROVED'',CURRENT_TIMESTAMP(),NULL::TIMESTAMP_NTZ),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,
        IFF(UPPER(TRIM(:P_REVIEW_ACTION))=''APPROVE'',''DEPLOYMENT_STAGE_APPROVED'',''DEPLOYMENT_STAGE_REJECTED''),
        :P_DEPLOYMENT_REQUEST_ID,:V_MODEL_DOMAIN,:V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,:V_TARGET_MODE,:V_NEW_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,TRIM(:P_REVIEWED_BY),TRIM(:P_REVIEW_NOTE),
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''approval_id'',TRIM(:P_APPROVAL_ID),
            ''approval_stage'',UPPER(TRIM(:P_APPROVAL_STAGE)),
            ''review_action'',UPPER(TRIM(:P_REVIEW_ACTION)),
            ''required_approval_count'',:V_REQUIRED_APPROVAL_COUNT,
            ''approved_stage_count'',:V_APPROVED_STAGE_COUNT,
            ''rejected_stage_count'',:V_REJECTED_STAGE_COUNT
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''phase'',''PHASE_11B'',
        ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
        ''approval_id'',P_APPROVAL_ID,
        ''approval_stage'',UPPER(TRIM(P_APPROVAL_STAGE)),
        ''review_action'',UPPER(TRIM(P_REVIEW_ACTION)),
        ''evidence_version'',V_EVIDENCE_VERSION,
        ''request_status'',V_NEW_REQUEST_STATUS,
        ''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(
    P_DEPLOYMENT_REQUEST_ID VARCHAR,
    P_ACTIVATED_BY VARCHAR,
    P_CONFIRMATION_PHRASE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_FROM_POLICY_ID VARCHAR;
    V_FROM_POLICY_VERSION VARCHAR;
    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_READINESS_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_EVIDENCE_CAPTURED_AT TIMESTAMP_NTZ;

    V_CURRENT_ACTIVE_COUNT NUMBER DEFAULT 0;
    V_CURRENT_ACTIVE_POLICY_ID VARCHAR;
    V_CURRENT_ACTIVE_POLICY_VERSION VARCHAR;
    V_CANDIDATE_COUNT NUMBER DEFAULT 0;
    V_CANDIDATE_AUTO_USE BOOLEAN;
    V_CANDIDATE_COST_IMPACT BOOLEAN;
    V_CANDIDATE_BUSINESS_DECISION BOOLEAN;
    V_CANDIDATE_QUALITY_REQUIRED BOOLEAN;
    V_CANDIDATE_OOD_ALLOWED BOOLEAN;
    V_CANDIDATE_ENGINEER_APPROVAL BOOLEAN;
    V_REQUIRED_APPROVAL_COUNT NUMBER DEFAULT 0;
    V_APPROVED_STAGE_COUNT NUMBER DEFAULT 0;
    V_REJECTED_STAGE_COUNT NUMBER DEFAULT 0;
    V_CURRENT_READINESS_STATUS VARCHAR;

    V_RETIRED_ROWS NUMBER DEFAULT 0;
    V_ACTIVATED_ROWS NUMBER DEFAULT 0;
    V_REQUEST_UPDATED_ROWS NUMBER DEFAULT 0;
    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    IF (P_DEPLOYMENT_REQUEST_ID IS NULL OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_DEPLOYMENT_REQUEST_ID is required.'');
    END IF;

    IF (P_ACTIVATED_BY IS NULL OR LENGTH(TRIM(P_ACTIVATED_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_ACTIVATED_BY is required.'');
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE <> (''ACTIVATE::'' || P_DEPLOYMENT_REQUEST_ID)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Confirmation phrase must equal ACTIVATE::<DEPLOYMENT_REQUEST_ID>.'');
    END IF;

    SELECT
        COUNT(*),MAX(MODEL_DOMAIN),MAX(TARGET_MODE),
        MAX(FROM_POLICY_ID),MAX(FROM_POLICY_VERSION),
        MAX(CANDIDATE_POLICY_ID),MAX(CANDIDATE_POLICY_VERSION),
        MAX(REQUEST_STATUS),MAX(READINESS_STATUS),MAX(EVIDENCE_VERSION),MAX(EVIDENCE_CAPTURED_AT)
    INTO
        :V_REQUEST_COUNT,:V_MODEL_DOMAIN,:V_TARGET_MODE,
        :V_FROM_POLICY_ID,:V_FROM_POLICY_VERSION,
        :V_CANDIDATE_POLICY_ID,:V_CANDIDATE_POLICY_VERSION,
        :V_REQUEST_STATUS,:V_READINESS_STATUS,:V_EVIDENCE_VERSION,:V_EVIDENCE_CAPTURED_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one deployment request is required.'',''request_count'',V_REQUEST_COUNT);
    END IF;

    IF (V_REQUEST_STATUS <> ''APPROVED'') THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Deployment request must be APPROVED.'',''request_status'',V_REQUEST_STATUS);
    END IF;

    IF (V_READINESS_STATUS <> ''READY'') THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Stored request readiness is not READY.'',''readiness_status'',V_READINESS_STATUS);
    END IF;

    IF (V_EVIDENCE_CAPTURED_AT < DATEADD(''hour'',-24,CURRENT_TIMESTAMP())) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Evidence is older than 24 hours. Refresh and reapprove.'',''evidence_captured_at'',V_EVIDENCE_CAPTURED_AT);
    END IF;

    SELECT MAX(READINESS_STATUS)
    INTO :V_CURRENT_READINESS_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_READINESS_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND TARGET_MODE = :V_TARGET_MODE;

    IF (V_CURRENT_READINESS_STATUS <> ''READY'') THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Current deployment readiness is no longer READY.'',''current_readiness_status'',V_CURRENT_READINESS_STATUS);
    END IF;

    SELECT COUNT(*),MAX(POLICY_ID),MAX(POLICY_VERSION)
    INTO :V_CURRENT_ACTIVE_COUNT,:V_CURRENT_ACTIVE_POLICY_ID,:V_CURRENT_ACTIVE_POLICY_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN;

    IF (
        V_CURRENT_ACTIVE_COUNT <> 1
        OR V_CURRENT_ACTIVE_POLICY_ID <> V_FROM_POLICY_ID
        OR V_CURRENT_ACTIVE_POLICY_VERSION <> V_FROM_POLICY_VERSION
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''message'',''The active source policy changed after request submission.'',
            ''expected_policy_id'',V_FROM_POLICY_ID,
            ''expected_policy_version'',V_FROM_POLICY_VERSION,
            ''current_policy_id'',V_CURRENT_ACTIVE_POLICY_ID,
            ''current_policy_version'',V_CURRENT_ACTIVE_POLICY_VERSION
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_CANDIDATE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    WHERE POLICY_ID = :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION = :V_CANDIDATE_POLICY_VERSION
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND DEPLOYMENT_MODE = :V_TARGET_MODE
      AND POLICY_STATUS = ''DRAFT'';

    IF (V_CANDIDATE_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Candidate policy is not an exact DRAFT match.'',''candidate_count'',V_CANDIDATE_COUNT);
    END IF;

    SELECT
        AUTO_USE_ALLOWED_FLAG,
        OFFICIAL_COST_IMPACT_ALLOWED_FLAG,
        BUSINESS_DECISION_ALLOWED_FLAG,
        QUALITY_PASS_REQUIRED_FLAG,
        OOD_USE_ALLOWED_FLAG,
        ENGINEER_APPROVAL_REQUIRED_FLAG
    INTO
        :V_CANDIDATE_AUTO_USE,
        :V_CANDIDATE_COST_IMPACT,
        :V_CANDIDATE_BUSINESS_DECISION,
        :V_CANDIDATE_QUALITY_REQUIRED,
        :V_CANDIDATE_OOD_ALLOWED,
        :V_CANDIDATE_ENGINEER_APPROVAL
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    WHERE POLICY_ID = :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION = :V_CANDIDATE_POLICY_VERSION
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND DEPLOYMENT_MODE = :V_TARGET_MODE
      AND POLICY_STATUS = ''DRAFT'';

    IF (
        NOT COALESCE(V_CANDIDATE_QUALITY_REQUIRED,FALSE)
        OR COALESCE(V_CANDIDATE_OOD_ALLOWED,FALSE)
        OR NOT COALESCE(V_CANDIDATE_ENGINEER_APPROVAL,FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Candidate must require quality pass and engineer approval, and must reject OOD use.'');
    END IF;

    IF (
        V_TARGET_MODE = ''CONTROLLED''
        AND COALESCE(V_CANDIDATE_AUTO_USE,FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''CONTROLLED candidate cannot enable automatic use.'');
    END IF;

    IF (
        COALESCE(V_CANDIDATE_AUTO_USE,FALSE)
        AND NOT COALESCE(V_CANDIDATE_BUSINESS_DECISION,FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Automatic use requires business-decision permission.'');
    END IF;

    IF (
        COALESCE(V_CANDIDATE_COST_IMPACT,FALSE)
        AND NOT COALESCE(V_CANDIDATE_BUSINESS_DECISION,FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Official cost impact requires business-decision permission.'');
    END IF;

    IF (
        V_MODEL_DOMAIN = ''BMCS''
        AND COALESCE(V_CANDIDATE_COST_IMPACT,FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''BMCS can never directly affect cost.'');
    END IF;

    SELECT COUNT(*)
    INTO :V_REQUIRED_APPROVAL_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
    WHERE TARGET_MODE = :V_TARGET_MODE;

    SELECT
        COUNT_IF(approval.REVIEW_ACTION=''APPROVE''),
        COUNT_IF(approval.REVIEW_ACTION=''REJECT'')
    INTO :V_APPROVED_STAGE_COUNT,:V_REJECTED_STAGE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1 requirement
    LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1 approval
        ON approval.DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID
       AND approval.EVIDENCE_VERSION = :V_EVIDENCE_VERSION
       AND approval.APPROVAL_STAGE = requirement.APPROVAL_STAGE
    WHERE requirement.TARGET_MODE = :V_TARGET_MODE;

    IF (
        V_REQUIRED_APPROVAL_COUNT = 0
        OR V_APPROVED_STAGE_COUNT <> V_REQUIRED_APPROVAL_COUNT
        OR V_REJECTED_STAGE_COUNT > 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'',''ERROR'',''message'',''All required current-evidence approvals are required.'',
            ''required_approval_count'',V_REQUIRED_APPROVAL_COUNT,
            ''approved_stage_count'',V_APPROVED_STAGE_COUNT,
            ''rejected_stage_count'',V_REJECTED_STAGE_COUNT
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    SET POLICY_STATUS=''RETIRED'',EFFECTIVE_TO=CURRENT_TIMESTAMP(),UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE POLICY_ID=:V_FROM_POLICY_ID
      AND POLICY_VERSION=:V_FROM_POLICY_VERSION
      AND MODEL_DOMAIN=:V_MODEL_DOMAIN
      AND POLICY_STATUS=''ACTIVE'';

    V_RETIRED_ROWS := SQLROWCOUNT;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    SET
        POLICY_STATUS=''ACTIVE'',EFFECTIVE_FROM=CURRENT_TIMESTAMP(),EFFECTIVE_TO=NULL,
        APPROVED_BY=TRIM(:P_ACTIVATED_BY),APPROVED_AT=CURRENT_TIMESTAMP(),UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE POLICY_ID=:V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION=:V_CANDIDATE_POLICY_VERSION
      AND MODEL_DOMAIN=:V_MODEL_DOMAIN
      AND POLICY_STATUS=''DRAFT'';

    V_ACTIVATED_ROWS := SQLROWCOUNT;

    IF (V_RETIRED_ROWS <> 1 OR V_ACTIVATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'',''ERROR'',''message'',''Atomic policy transition did not affect exactly one source and one candidate row.'',
            ''retired_rows'',V_RETIRED_ROWS,''activated_rows'',V_ACTIVATED_ROWS
        );
    END IF;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    SET REQUEST_STATUS=''ACTIVATED'',ACTIVATED_BY=TRIM(:P_ACTIVATED_BY),
        ACTIVATED_AT=CURRENT_TIMESTAMP(),UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE DEPLOYMENT_REQUEST_ID=:P_DEPLOYMENT_REQUEST_ID
      AND REQUEST_STATUS=''APPROVED'';

    V_REQUEST_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_REQUEST_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Deployment request activation update did not affect exactly one row.'',''updated_rows'',V_REQUEST_UPDATED_ROWS);
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,''DEPLOYMENT_ACTIVATED'',:P_DEPLOYMENT_REQUEST_ID,:V_MODEL_DOMAIN,
        :V_CANDIDATE_POLICY_ID,:V_CANDIDATE_POLICY_VERSION,:V_TARGET_MODE,
        ''ACTIVATED'',:V_EVIDENCE_VERSION,TRIM(:P_ACTIVATED_BY),
        ''All current gates and required approvals passed.'',
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''from_policy_id'',:V_FROM_POLICY_ID,
            ''from_policy_version'',:V_FROM_POLICY_VERSION,
            ''activated_policy_id'',:V_CANDIDATE_POLICY_ID,
            ''activated_policy_version'',:V_CANDIDATE_POLICY_VERSION,
            ''target_mode'',:V_TARGET_MODE,
            ''approved_stage_count'',:V_APPROVED_STAGE_COUNT,
            ''required_approval_count'',:V_REQUIRED_APPROVAL_COUNT,
            ''evidence_version'',:V_EVIDENCE_VERSION
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''phase'',''PHASE_11B'',
        ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
        ''model_domain'',V_MODEL_DOMAIN,
        ''from_policy_id'',V_FROM_POLICY_ID,''from_policy_version'',V_FROM_POLICY_VERSION,
        ''activated_policy_id'',V_CANDIDATE_POLICY_ID,
        ''activated_policy_version'',V_CANDIDATE_POLICY_VERSION,
        ''deployment_mode'',V_TARGET_MODE,''request_status'',''ACTIVATED'',
        ''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(
    P_DEPLOYMENT_REQUEST_ID VARCHAR,
    P_ROLLED_BACK_BY VARCHAR,
    P_ROLLBACK_REASON VARCHAR,
    P_CONFIRMATION_PHRASE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_FROM_POLICY_ID VARCHAR;
    V_FROM_POLICY_VERSION VARCHAR;
    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_CURRENT_ACTIVE_COUNT NUMBER DEFAULT 0;
    V_CURRENT_ACTIVE_POLICY_ID VARCHAR;
    V_CURRENT_ACTIVE_POLICY_VERSION VARCHAR;
    V_PREVIOUS_POLICY_COUNT NUMBER DEFAULT 0;

    V_RETIRED_ROWS NUMBER DEFAULT 0;
    V_REACTIVATED_ROWS NUMBER DEFAULT 0;
    V_REQUEST_UPDATED_ROWS NUMBER DEFAULT 0;
    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    IF (P_DEPLOYMENT_REQUEST_ID IS NULL OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_DEPLOYMENT_REQUEST_ID is required.'');
    END IF;

    IF (P_ROLLED_BACK_BY IS NULL OR LENGTH(TRIM(P_ROLLED_BACK_BY)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_ROLLED_BACK_BY is required.'');
    END IF;

    IF (P_ROLLBACK_REASON IS NULL OR LENGTH(TRIM(P_ROLLBACK_REASON)) = 0) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''P_ROLLBACK_REASON is required.'');
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE <> (''ROLLBACK::'' || P_DEPLOYMENT_REQUEST_ID)
    ) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Confirmation phrase must equal ROLLBACK::<DEPLOYMENT_REQUEST_ID>.'');
    END IF;

    SELECT
        COUNT(*),MAX(MODEL_DOMAIN),MAX(TARGET_MODE),MAX(FROM_POLICY_ID),
        MAX(FROM_POLICY_VERSION),MAX(CANDIDATE_POLICY_ID),MAX(CANDIDATE_POLICY_VERSION),
        MAX(REQUEST_STATUS),MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_COUNT,:V_MODEL_DOMAIN,:V_TARGET_MODE,:V_FROM_POLICY_ID,
        :V_FROM_POLICY_VERSION,:V_CANDIDATE_POLICY_ID,:V_CANDIDATE_POLICY_VERSION,
        :V_REQUEST_STATUS,:V_EVIDENCE_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Exactly one deployment request is required.'',''request_count'',V_REQUEST_COUNT);
    END IF;

    IF (V_REQUEST_STATUS <> ''ACTIVATED'') THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Only an ACTIVATED deployment can be rolled back.'',''request_status'',V_REQUEST_STATUS);
    END IF;

    SELECT COUNT(*),MAX(POLICY_ID),MAX(POLICY_VERSION)
    INTO :V_CURRENT_ACTIVE_COUNT,:V_CURRENT_ACTIVE_POLICY_ID,:V_CURRENT_ACTIVE_POLICY_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN;

    IF (
        V_CURRENT_ACTIVE_COUNT <> 1
        OR V_CURRENT_ACTIVE_POLICY_ID <> V_CANDIDATE_POLICY_ID
        OR V_CURRENT_ACTIVE_POLICY_VERSION <> V_CANDIDATE_POLICY_VERSION
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',
            ''message'',''The currently active policy is not the policy activated by this request. A newer deployment may exist.'',
            ''current_policy_id'',V_CURRENT_ACTIVE_POLICY_ID,
            ''current_policy_version'',V_CURRENT_ACTIVE_POLICY_VERSION
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_PREVIOUS_POLICY_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    WHERE POLICY_ID = :V_FROM_POLICY_ID
      AND POLICY_VERSION = :V_FROM_POLICY_VERSION
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_STATUS = ''RETIRED'';

    IF (V_PREVIOUS_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Previous policy is not available as a single RETIRED row.'',''previous_policy_count'',V_PREVIOUS_POLICY_COUNT);
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    SET POLICY_STATUS=''RETIRED'',EFFECTIVE_TO=CURRENT_TIMESTAMP(),UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE POLICY_ID=:V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION=:V_CANDIDATE_POLICY_VERSION
      AND MODEL_DOMAIN=:V_MODEL_DOMAIN
      AND POLICY_STATUS=''ACTIVE'';

    V_RETIRED_ROWS := SQLROWCOUNT;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    SET
        POLICY_STATUS=''ACTIVE'',EFFECTIVE_FROM=CURRENT_TIMESTAMP(),EFFECTIVE_TO=NULL,
        APPROVED_BY=TRIM(:P_ROLLED_BACK_BY),APPROVED_AT=CURRENT_TIMESTAMP(),UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE POLICY_ID=:V_FROM_POLICY_ID
      AND POLICY_VERSION=:V_FROM_POLICY_VERSION
      AND MODEL_DOMAIN=:V_MODEL_DOMAIN
      AND POLICY_STATUS=''RETIRED'';

    V_REACTIVATED_ROWS := SQLROWCOUNT;

    IF (V_RETIRED_ROWS <> 1 OR V_REACTIVATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'',''ERROR'',''message'',''Atomic rollback did not affect exactly one current and one previous policy row.'',
            ''retired_rows'',V_RETIRED_ROWS,''reactivated_rows'',V_REACTIVATED_ROWS
        );
    END IF;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    SET
        REQUEST_STATUS=''ROLLED_BACK'',
        ROLLED_BACK_BY=TRIM(:P_ROLLED_BACK_BY),
        ROLLED_BACK_AT=CURRENT_TIMESTAMP(),
        ROLLBACK_REASON=TRIM(:P_ROLLBACK_REASON),
        UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE DEPLOYMENT_REQUEST_ID=:P_DEPLOYMENT_REQUEST_ID
      AND REQUEST_STATUS=''ACTIVATED'';

    V_REQUEST_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_REQUEST_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(''status'',''ERROR'',''message'',''Rollback request update did not affect exactly one row.'',''updated_rows'',V_REQUEST_UPDATED_ROWS);
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 (
        EVENT_ID,EVENT_TYPE,DEPLOYMENT_REQUEST_ID,MODEL_DOMAIN,
        CANDIDATE_POLICY_ID,CANDIDATE_POLICY_VERSION,TARGET_MODE,
        REQUEST_STATUS,EVIDENCE_VERSION,EVENT_ACTOR,EVENT_REASON,EVENT_DETAILS,EVENT_AT
    )
    SELECT
        :V_EVENT_ID,''DEPLOYMENT_ROLLED_BACK'',:P_DEPLOYMENT_REQUEST_ID,:V_MODEL_DOMAIN,
        :V_CANDIDATE_POLICY_ID,:V_CANDIDATE_POLICY_VERSION,:V_TARGET_MODE,
        ''ROLLED_BACK'',:V_EVIDENCE_VERSION,TRIM(:P_ROLLED_BACK_BY),TRIM(:P_ROLLBACK_REASON),
        OBJECT_CONSTRUCT_KEEP_NULL(
            ''retired_candidate_policy_id'',:V_CANDIDATE_POLICY_ID,
            ''retired_candidate_policy_version'',:V_CANDIDATE_POLICY_VERSION,
            ''restored_policy_id'',:V_FROM_POLICY_ID,
            ''restored_policy_version'',:V_FROM_POLICY_VERSION
        ),CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'',''SUCCESS'',''phase'',''PHASE_11B'',
        ''deployment_request_id'',P_DEPLOYMENT_REQUEST_ID,
        ''model_domain'',V_MODEL_DOMAIN,
        ''retired_policy_id'',V_CANDIDATE_POLICY_ID,
        ''retired_policy_version'',V_CANDIDATE_POLICY_VERSION,
        ''restored_policy_id'',V_FROM_POLICY_ID,
        ''restored_policy_version'',V_FROM_POLICY_VERSION,
        ''request_status'',''ROLLED_BACK'',''event_id'',V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'',''ERROR'',''phase'',''PHASE_11B'',
            ''sqlcode'',SQLCODE,''sqlerrm'',SQLERRM,''sqlstate'',SQLSTATE
        );
END;
';

-- ============================================================
-- PHASE 11B — PROCEDURE VISIBILITY VERIFICATION
-- ============================================================

WITH REQUIRED_PROCEDURES AS (
    SELECT COLUMN1::VARCHAR AS PROCEDURE_NAME
    FROM VALUES
        ('SET_ML_DEPLOYMENT_CAPABILITY_V1'),
        ('CREATE_ML_POLICY_CANDIDATE_V1'),
        ('SUBMIT_ML_DEPLOYMENT_REQUEST_V1'),
        ('REFRESH_ML_DEPLOYMENT_REQUEST_V1'),
        ('REVIEW_ML_DEPLOYMENT_REQUEST_V1'),
        ('ACTIVATE_APPROVED_ML_DEPLOYMENT_V1'),
        ('ROLLBACK_ML_DEPLOYMENT_V1'),
        ('CANCEL_ML_DEPLOYMENT_REQUEST_V1')
),
FOUND_PROCEDURES AS (
    SELECT DISTINCT PROCEDURE_NAME
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
)
SELECT
    required.PROCEDURE_NAME AS MISSING_PROCEDURE_NAME
FROM REQUIRED_PROCEDURES required
LEFT JOIN FOUND_PROCEDURES found
    ON required.PROCEDURE_NAME =
       found.PROCEDURE_NAME
WHERE found.PROCEDURE_NAME IS NULL
ORDER BY required.PROCEDURE_NAME;


SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE11B_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'SET_ML_DEPLOYMENT_CAPABILITY_V1',
      'CREATE_ML_POLICY_CANDIDATE_V1',
      'SUBMIT_ML_DEPLOYMENT_REQUEST_V1',
      'REFRESH_ML_DEPLOYMENT_REQUEST_V1',
      'REVIEW_ML_DEPLOYMENT_REQUEST_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1',
      'ROLLBACK_ML_DEPLOYMENT_V1',
      'CANCEL_ML_DEPLOYMENT_REQUEST_V1'
  );


SHOW USER PROCEDURES
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;