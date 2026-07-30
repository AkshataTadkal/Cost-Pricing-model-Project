-- Phase 12 candidate prediction, backtest, and deployment activationpipeline
-- Co-authored with CoCo
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- ------------------------------------------------------------
-- PREREQUISITE: Ensure deployment request and approval objects exist.
-- These are created in Phase 11 but may not have been deployed.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 (
    DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
    MODEL_DOMAIN VARCHAR NOT NULL,
    TARGET_MODE VARCHAR NOT NULL,
    FROM_POLICY_ID VARCHAR,
    FROM_POLICY_VERSION VARCHAR,
    FROM_DEPLOYMENT_MODE VARCHAR,
    CANDIDATE_POLICY_ID VARCHAR NOT NULL,
    CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,
    CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
    CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
    CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,
    REQUEST_STATUS VARCHAR NOT NULL,
    READINESS_STATUS VARCHAR,
    EVIDENCE_VERSION NUMBER NOT NULL DEFAULT 1,
    REQUIRED_GATE_COUNT NUMBER,
    PASS_GATE_COUNT NUMBER,
    FAIL_GATE_COUNT NUMBER,
    NO_DATA_GATE_COUNT NUMBER,
    INSUFFICIENT_GATE_COUNT NUMBER,
    EVIDENCE_SNAPSHOT VARIANT,
    EVIDENCE_CAPTURED_AT TIMESTAMP_NTZ,
    REQUESTED_BY VARCHAR NOT NULL,
    REQUESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    BUSINESS_JUSTIFICATION VARCHAR,
    APPROVED_BY VARCHAR,
    APPROVED_AT TIMESTAMP_NTZ,
    ACTIVATED_BY VARCHAR,
    ACTIVATED_AT TIMESTAMP_NTZ,
    ROLLED_BACK_BY VARCHAR,
    ROLLED_BACK_AT TIMESTAMP_NTZ,
    ROLLBACK_REASON VARCHAR,
    LAST_REFRESHED_BY VARCHAR,
    LAST_REFRESHED_AT TIMESTAMP_NTZ,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 (
    APPROVAL_ID VARCHAR NOT NULL,
    DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
    EVIDENCE_VERSION NUMBER NOT NULL,
    APPROVAL_STAGE VARCHAR NOT NULL,
    REVIEW_ACTION VARCHAR NOT NULL,
    REVIEWED_BY VARCHAR NOT NULL,
    REVIEW_NOTE VARCHAR,
    REVIEWED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1 AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY DEPLOYMENT_REQUEST_ID, EVIDENCE_VERSION, APPROVAL_STAGE
    ORDER BY REVIEWED_AT DESC, CREATED_AT DESC, APPROVAL_ID DESC
) = 1;

CREATE OR REPLACE VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_WORKFLOW_V1 AS
WITH APPROVAL_STATUS AS (
    SELECT
        DEPLOYMENT_REQUEST_ID,
        EVIDENCE_VERSION,
        COUNT_IF(REVIEW_ACTION = 'APPROVE') AS APPROVED_STAGE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1
    GROUP BY DEPLOYMENT_REQUEST_ID, EVIDENCE_VERSION
),
REQUIREMENT_COUNT AS (
    SELECT
        TARGET_MODE,
        COUNT(*) AS REQUIRED_APPROVAL_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_APPROVAL_REQUIREMENT_CURRENT_V1
    WHERE REQUIRED_FLAG = TRUE
    GROUP BY TARGET_MODE
)
SELECT
    request.*,
    IFF(
        COALESCE(approval.APPROVED_STAGE_COUNT, 0)
            >= COALESCE(req.REQUIRED_APPROVAL_COUNT, 0),
        TRUE,
        FALSE
    ) AS ALL_CURRENT_APPROVALS_COMPLETE_FLAG,
    IFF(
        request.EVIDENCE_CAPTURED_AT IS NOT NULL
        AND request.EVIDENCE_CAPTURED_AT >= DATEADD('DAY', -7, CURRENT_TIMESTAMP()),
        TRUE,
        FALSE
    ) AS EVIDENCE_FRESH_FLAG
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 request
LEFT JOIN APPROVAL_STATUS approval
    ON request.DEPLOYMENT_REQUEST_ID = approval.DEPLOYMENT_REQUEST_ID
   AND request.EVIDENCE_VERSION = approval.EVIDENCE_VERSION
LEFT JOIN REQUIREMENT_COUNT req
    ON request.TARGET_MODE = req.TARGET_MODE;

-- ============================================================
-- PHASE 12A — PREFLIGHT
--
-- Exact execution context:
--   ROLE      = SYSADMIN
--   WAREHOUSE = KMAT_WH
--   DATABASE  = KMAT_COST_MODEL_DB
--   SCHEMA    = CORE_ML
--
-- Every dependency is checked by its exact database, schema
-- and object name. No procedure schema is inferred.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CURRENT EXECUTION CONTEXT
-- ------------------------------------------------------------

SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;


-- ------------------------------------------------------------
-- 2. EXACT PROCEDURE INVENTORY
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'REFRESH_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'REVIEW_ML_DEPLOYMENT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- ------------------------------------------------------------
-- 3. REQUIRED OBJECT CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DECISION_POLICY_V1','TABLE'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','VIEW'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','TABLE'),
        ('CORE_ML','ML_DEPLOYMENT_APPROVAL_V1','TABLE'),
        ('CORE_ML','VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1','VIEW'),
        ('CORE_ML','VW_ML_DEPLOYMENT_WORKFLOW_V1','VIEW'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','VIEW'),
        ('CORE_ML','VW_KMAT_COST_FEEDBACK_DETAIL_V1','VIEW')
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
-- 4. REQUIRED COLUMN CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','MODEL_DOMAIN'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','TARGET_MODE'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_MODEL_NAME'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_MODEL_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_FEATURE_SET_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','REQUEST_STATUS'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','READINESS_STATUS'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','EVIDENCE_VERSION'),

        ('CORE_ML','ML_DECISION_POLICY_V1','FINAL_VALUE_MIN'),
        ('CORE_ML','ML_DECISION_POLICY_V1','FINAL_VALUE_MAX'),
        ('CORE_ML','ML_DECISION_POLICY_V1','MAX_ABS_DEVIATION_FROM_RULE'),
        ('CORE_ML','ML_DECISION_POLICY_V1','MAX_PCT_DEVIATION_FROM_RULE'),

        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','SIMULATION_ID'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','MODEL_DOMAIN'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','MONITORING_ELIGIBLE_FLAG'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','RULE_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ML_ADVISORY_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ML_PROBABILITY_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_NUMERIC_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_MAPPING_CORRECT_FLAG'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','OUTCOME_AVAILABLE_FLAG')
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
-- 5. PROCEDURE CHECK USING INFORMATION_SCHEMA
--
-- Expected:
--   PHASE11B_REQUIRED_PROCEDURE_COUNT = 3
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE11B_REQUIRED_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1',
      'REFRESH_ML_DEPLOYMENT_REQUEST_V1',
      'REVIEW_ML_DEPLOYMENT_REQUEST_V1'
  );


-- ------------------------------------------------------------
-- 6. ACTIVE POLICY SAFETY
--
-- Expected:
--   ACTIVE_POLICY_COUNT = 4
--   SHADOW_POLICY_COUNT = 4
--   AUTHORITY_ENABLED_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,

    COUNT_IF(
        DEPLOYMENT_MODE = 'SHADOW'
    ) AS SHADOW_POLICY_COUNT,

    COUNT_IF(
        AUTO_USE_ALLOWED_FLAG = TRUE
        OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
        OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
    ) AS AUTHORITY_ENABLED_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;

-- ============================================================
-- PHASE 12A — CANDIDATE BACKTESTING AND PROMOTION EVIDENCE
--
-- This phase:
--   * records candidate predictions against a deployment request;
--   * compares candidate, deterministic rule and current ML;
--   * applies model-domain and target-mode backtest gates;
--   * binds evidence to DEPLOYMENT_REQUEST_ID + EVIDENCE_VERSION;
--   * creates a V2 activation gate.
--
-- This phase does not:
--   * activate a policy during deployment;
--   * change official cost;
--   * enable automatic ML authority;
--   * write to Phase 10 cost outputs.
--
-- No OBJECT_AGG is used in this phase.
-- No VARIANT scripting variable is inserted through VALUES.
-- ============================================================


-- ============================================================
-- 1. CANDIDATE PREDICTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_PREDICTION_V1 (
            PREDICTION_ID VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            EVIDENCE_VERSION NUMBER NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,

            CANDIDATE_POLICY_ID VARCHAR NOT NULL,
            CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,

            CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
            CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
            CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,

            PREDICTION_SET_VERSION VARCHAR NOT NULL,

            SIMULATION_ID VARCHAR NOT NULL,
            KMAT_ID VARCHAR,
            RFQ_ID VARCHAR,

            PREDICTED_NUMERIC_VALUE FLOAT NOT NULL,

            QUALITY_PASS_FLAG BOOLEAN NOT NULL,
            OOD_FLAG BOOLEAN NOT NULL,

            PREDICTION_SOURCE VARCHAR NOT NULL,
            SOURCE_REFERENCE VARCHAR,
            NOTES VARCHAR,

            IS_ACTIVE BOOLEAN NOT NULL DEFAULT TRUE,

            PREDICTED_BY VARCHAR NOT NULL,
            PREDICTED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),

            UPDATED_BY VARCHAR NOT NULL,
            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 (
            EVENT_ID VARCHAR NOT NULL,
            EVENT_TYPE VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            EVIDENCE_VERSION NUMBER NOT NULL,

            BACKTEST_RUN_ID VARCHAR,
            PREDICTION_ID VARCHAR,

            MODEL_DOMAIN VARCHAR NOT NULL,
            SIMULATION_ID VARCHAR,

            EVENT_STATUS VARCHAR NOT NULL,
            EVENT_REASON VARCHAR,

            EVENT_ACTOR VARCHAR NOT NULL,
            EVENT_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_CANDIDATE_PREDICTION_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_PREDICTION_V1
WHERE IS_ACTIVE = TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        DEPLOYMENT_REQUEST_ID,
        EVIDENCE_VERSION,
        SIMULATION_ID
    ORDER BY
        UPDATED_AT DESC,
        PREDICTED_AT DESC,
        PREDICTION_ID DESC
) = 1;


-- ============================================================
-- 2. BACKTEST DETAIL AND RUN TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_DETAIL_V1 (
            BACKTEST_RUN_ID VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            EVIDENCE_VERSION NUMBER NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            TARGET_MODE VARCHAR NOT NULL,

            CANDIDATE_POLICY_ID VARCHAR NOT NULL,
            CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,

            SIMULATION_ID VARCHAR NOT NULL,
            KMAT_ID VARCHAR,
            RFQ_ID VARCHAR,

            OUTCOME_AVAILABLE_FLAG BOOLEAN NOT NULL,

            PREDICTION_ID VARCHAR,
            PREDICTION_AVAILABLE_FLAG BOOLEAN NOT NULL,
            PREDICTION_ELIGIBLE_FLAG BOOLEAN NOT NULL,

            QUALITY_PASS_FLAG BOOLEAN,
            OOD_FLAG BOOLEAN,

            RULE_VALUE FLOAT,
            CURRENT_ML_VALUE FLOAT,
            CANDIDATE_VALUE FLOAT,
            ACTUAL_VALUE FLOAT,

            RULE_ABS_ERROR FLOAT,
            CURRENT_ML_ABS_ERROR FLOAT,
            CANDIDATE_ABS_ERROR FLOAT,

            CANDIDATE_BRIER_SCORE FLOAT,
            CANDIDATE_CLASSIFICATION_CORRECT_FLAG BOOLEAN,

            BOUNDS_PASS_FLAG BOOLEAN,
            ABS_DEVIATION_PASS_FLAG BOOLEAN,
            PCT_DEVIATION_PASS_FLAG BOOLEAN,
            OVERALL_GUARDRAIL_PASS_FLAG BOOLEAN,

            EXCLUSION_REASON VARCHAR,

            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_RUN_V1 (
            BACKTEST_RUN_ID VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            EVIDENCE_VERSION NUMBER NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            TARGET_MODE VARCHAR NOT NULL,

            CANDIDATE_POLICY_ID VARCHAR NOT NULL,
            CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,

            CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
            CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
            CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,

            PREDICTION_SET_VERSION VARCHAR,

            BACKTEST_STATUS VARCHAR NOT NULL,
            BACKTEST_REASON VARCHAR NOT NULL,

            ELIGIBLE_OUTCOME_COUNT NUMBER NOT NULL,
            AVAILABLE_PREDICTION_COUNT NUMBER NOT NULL,
            VALID_PREDICTION_COUNT NUMBER NOT NULL,

            PREDICTION_COVERAGE_PCT FLOAT,

            RULE_MAE FLOAT,
            CURRENT_ML_MAE FLOAT,
            CANDIDATE_MAE FLOAT,
            CANDIDATE_RMSE FLOAT,

            CANDIDATE_ERROR_ADVANTAGE_VS_RULE FLOAT,
            CANDIDATE_ERROR_ADVANTAGE_VS_CURRENT_ML FLOAT,

            BMCS_BRIER_SCORE FLOAT,
            BMCS_CLASSIFICATION_ACCURACY_PCT FLOAT,

            GUARDRAIL_PASS_COUNT NUMBER NOT NULL,
            GUARDRAIL_PASS_PCT FLOAT,

            REQUIRED_MIN_SAMPLE_SIZE NUMBER NOT NULL,
            REQUIRED_MIN_COVERAGE_PCT FLOAT NOT NULL,
            REQUIRED_MAX_ERROR FLOAT,
            REQUIRED_MIN_ACCURACY_PCT FLOAT,

            SAMPLE_SIZE_PASS_FLAG BOOLEAN NOT NULL,
            COVERAGE_PASS_FLAG BOOLEAN NOT NULL,
            ERROR_PASS_FLAG BOOLEAN NOT NULL,
            RULE_ADVANTAGE_PASS_FLAG BOOLEAN NOT NULL,
            ACCURACY_PASS_FLAG BOOLEAN NOT NULL,
            GUARDRAIL_PASS_FLAG BOOLEAN NOT NULL,

            RUN_BY VARCHAR NOT NULL,
            STARTED_AT TIMESTAMP_NTZ NOT NULL,
            COMPLETED_AT TIMESTAMP_NTZ NOT NULL,

            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 3. RECORD A CANDIDATE PREDICTION
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RECORD_ML_CANDIDATE_PREDICTION_V1(
            P_PREDICTION_ID VARCHAR,
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_SIMULATION_ID VARCHAR,

            P_PREDICTION_SET_VERSION VARCHAR,
            P_PREDICTED_NUMERIC_VALUE FLOAT,

            P_QUALITY_PASS_FLAG BOOLEAN,
            P_OOD_FLAG BOOLEAN,

            P_PREDICTION_SOURCE VARCHAR,
            P_SOURCE_REFERENCE VARCHAR,
            P_NOTES VARCHAR,
            P_PREDICTED_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_SIMULATION_COUNT NUMBER DEFAULT 0;
    V_EXISTING_PREDICTION_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;
    V_CANDIDATE_MODEL_NAME VARCHAR;
    V_CANDIDATE_MODEL_VERSION VARCHAR;
    V_CANDIDATE_FEATURE_SET_VERSION VARCHAR;

    V_FINAL_MIN FLOAT;
    V_FINAL_MAX FLOAT;

    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PREDICTION_ID IS NULL
        OR LENGTH(TRIM(P_PREDICTION_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_PREDICTION_ID is required.''
        );
    END IF;

    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_DEPLOYMENT_REQUEST_ID is required.''
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
        P_PREDICTION_SET_VERSION IS NULL
        OR LENGTH(TRIM(P_PREDICTION_SET_VERSION)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_PREDICTION_SET_VERSION is required.''
        );
    END IF;

    IF (P_PREDICTED_NUMERIC_VALUE IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_PREDICTED_NUMERIC_VALUE is required.''
        );
    END IF;

    IF (P_QUALITY_PASS_FLAG IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_QUALITY_PASS_FLAG is required.''
        );
    END IF;

    IF (P_OOD_FLAG IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_OOD_FLAG is required.''
        );
    END IF;

    IF (
        P_PREDICTION_SOURCE IS NULL
        OR LENGTH(TRIM(P_PREDICTION_SOURCE)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_PREDICTION_SOURCE is required.''
        );
    END IF;

    IF (
        P_PREDICTED_BY IS NULL
        OR LENGTH(TRIM(P_PREDICTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_PREDICTED_BY is required.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(MODEL_DOMAIN),
        MAX(TARGET_MODE),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),

        MAX(CANDIDATE_MODEL_NAME),
        MAX(CANDIDATE_MODEL_VERSION),
        MAX(CANDIDATE_FEATURE_SET_VERSION)

    INTO
        :V_REQUEST_COUNT,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1

    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one deployment request is required.'',
            ''request_count'', V_REQUEST_COUNT
        );
    END IF;

    IF (
        V_REQUEST_STATUS IN (
            ''ACTIVATED'',
            ''ROLLED_BACK'',
            ''CANCELLED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Candidate predictions cannot be changed for a completed request.'',
            ''request_status'', V_REQUEST_STATUS
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(FINAL_VALUE_MIN::FLOAT),
        MAX(FINAL_VALUE_MAX::FLOAT)
    INTO
        :V_SIMULATION_COUNT,
        :V_FINAL_MIN,
        :V_FINAL_MAX
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_POLICY_V1
    WHERE POLICY_ID =
          :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION
      AND MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_STATUS = ''DRAFT'';

    IF (V_SIMULATION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''The request candidate is not available as one DRAFT policy row.'',
            ''candidate_count'', V_SIMULATION_COUNT
        );
    END IF;

    IF (
        V_FINAL_MIN IS NOT NULL
        AND P_PREDICTED_NUMERIC_VALUE < V_FINAL_MIN
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Candidate prediction is below the policy minimum.'',
            ''policy_minimum'', V_FINAL_MIN
        );
    END IF;

    IF (
        V_FINAL_MAX IS NOT NULL
        AND P_PREDICTED_NUMERIC_VALUE > V_FINAL_MAX
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Candidate prediction is above the policy maximum.'',
            ''policy_maximum'', V_FINAL_MAX
        );
    END IF;

    IF (
        V_MODEL_DOMAIN = ''CSS''
        AND (
            P_PREDICTED_NUMERIC_VALUE < 0.0
            OR P_PREDICTED_NUMERIC_VALUE > 1.0
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''CSS candidate output must be between 0 and 1.''
        );
    END IF;

    IF (
        V_MODEL_DOMAIN = ''FMIS''
        AND P_PREDICTED_NUMERIC_VALUE <= 0.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''FMIS candidate multiplier must be greater than 0.''
        );
    END IF;

    IF (
        V_MODEL_DOMAIN = ''TDS''
        AND (
            P_PREDICTED_NUMERIC_VALUE < 1.0
            OR P_PREDICTED_NUMERIC_VALUE > 3.5
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''TDS candidate factor must be between 1.0 and 3.5.''
        );
    END IF;

    IF (
        V_MODEL_DOMAIN = ''BMCS''
        AND (
            P_PREDICTED_NUMERIC_VALUE < 0.0
            OR P_PREDICTED_NUMERIC_VALUE > 1.0
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''BMCS candidate probability must be between 0 and 1.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(KMAT_ID),
        MAX(RFQ_ID)
    INTO
        :V_SIMULATION_COUNT,
        :V_KMAT_ID,
        :V_RFQ_ID
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
    WHERE SIMULATION_ID = :P_SIMULATION_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN;

    IF (V_SIMULATION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one model-feedback row is required for the simulation and domain.'',
            ''simulation_count'', V_SIMULATION_COUNT
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_PREDICTION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_PREDICTION_V1
    WHERE PREDICTION_ID = :P_PREDICTION_ID;

    IF (V_EXISTING_PREDICTION_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''PREDICTION_ID already exists.'',
            ''prediction_id'', P_PREDICTION_ID
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_PREDICTION_V1
    SET
        IS_ACTIVE = FALSE,
        UPDATED_BY = TRIM(:P_PREDICTED_BY),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID
      AND EVIDENCE_VERSION =
          :V_EVIDENCE_VERSION
      AND SIMULATION_ID =
          :P_SIMULATION_ID
      AND IS_ACTIVE = TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_PREDICTION_V1 (
                PREDICTION_ID,

                DEPLOYMENT_REQUEST_ID,
                EVIDENCE_VERSION,

                MODEL_DOMAIN,

                CANDIDATE_POLICY_ID,
                CANDIDATE_POLICY_VERSION,

                CANDIDATE_MODEL_NAME,
                CANDIDATE_MODEL_VERSION,
                CANDIDATE_FEATURE_SET_VERSION,

                PREDICTION_SET_VERSION,

                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,

                PREDICTED_NUMERIC_VALUE,

                QUALITY_PASS_FLAG,
                OOD_FLAG,

                PREDICTION_SOURCE,
                SOURCE_REFERENCE,
                NOTES,

                IS_ACTIVE,

                PREDICTED_BY,
                PREDICTED_AT,

                UPDATED_BY,
                UPDATED_AT
            )
    SELECT
        TRIM(:P_PREDICTION_ID),

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,

        TRIM(:P_PREDICTION_SET_VERSION),

        TRIM(:P_SIMULATION_ID),
        :V_KMAT_ID,
        :V_RFQ_ID,

        :P_PREDICTED_NUMERIC_VALUE,

        :P_QUALITY_PASS_FLAG,
        :P_OOD_FLAG,

        TRIM(:P_PREDICTION_SOURCE),
        :P_SOURCE_REFERENCE,
        :P_NOTES,

        TRUE,

        TRIM(:P_PREDICTED_BY),
        CURRENT_TIMESTAMP(),

        TRIM(:P_PREDICTED_BY),
        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Prediction insert did not affect exactly one row.'',
            ''inserted_rows'', V_INSERTED_ROWS
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                DEPLOYMENT_REQUEST_ID,
                EVIDENCE_VERSION,

                BACKTEST_RUN_ID,
                PREDICTION_ID,

                MODEL_DOMAIN,
                SIMULATION_ID,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_EVENT_ID,
        ''CANDIDATE_PREDICTION_RECORDED'',

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        TRIM(:P_PREDICTION_ID),

        :V_MODEL_DOMAIN,
        TRIM(:P_SIMULATION_ID),

        IFF(
            :P_QUALITY_PASS_FLAG
            AND NOT :P_OOD_FLAG,
            ''ELIGIBLE'',
            ''ADVISORY_EXCLUDED''
        ),

        CASE
            WHEN NOT :P_QUALITY_PASS_FLAG
                THEN ''Prediction quality check failed.''
            WHEN :P_OOD_FLAG
                THEN ''Prediction is out of distribution.''
            ELSE ''Prediction is eligible for candidate backtesting.''
        END,

        TRIM(:P_PREDICTED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12A'',

        ''prediction_id'', P_PREDICTION_ID,
        ''deployment_request_id'',
            P_DEPLOYMENT_REQUEST_ID,
        ''evidence_version'', V_EVIDENCE_VERSION,

        ''model_domain'', V_MODEL_DOMAIN,
        ''simulation_id'', P_SIMULATION_ID,

        ''quality_pass'', P_QUALITY_PASS_FLAG,
        ''ood_flag'', P_OOD_FLAG,

        ''eligible_for_backtest'',
            P_QUALITY_PASS_FLAG
            AND NOT P_OOD_FLAG,

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


-- ============================================================
-- 4. RUN A REQUEST-SPECIFIC BACKTEST
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_CANDIDATE_BACKTEST_V1(
            P_BACKTEST_RUN_ID VARCHAR,
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_RUN_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_RUN_COUNT NUMBER DEFAULT 0;
    V_ORPHAN_DETAIL_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_POLICY_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_CANDIDATE_MODEL_NAME VARCHAR;
    V_CANDIDATE_MODEL_VERSION VARCHAR;
    V_CANDIDATE_FEATURE_SET_VERSION VARCHAR;

    V_FINAL_MIN FLOAT;
    V_FINAL_MAX FLOAT;
    V_MAX_ABS_DEVIATION FLOAT;
    V_MAX_PCT_DEVIATION FLOAT;

    V_PREDICTION_SET_VERSION VARCHAR;

    V_REQUIRED_MIN_SAMPLE_SIZE NUMBER;
    V_REQUIRED_MIN_COVERAGE_PCT FLOAT;
    V_REQUIRED_MAX_ERROR FLOAT;
    V_REQUIRED_MIN_ACCURACY_PCT FLOAT;

    V_STARTED_AT TIMESTAMP_NTZ;
    V_COMPLETED_AT TIMESTAMP_NTZ;

    V_ELIGIBLE_OUTCOME_COUNT NUMBER DEFAULT 0;
    V_AVAILABLE_PREDICTION_COUNT NUMBER DEFAULT 0;
    V_VALID_PREDICTION_COUNT NUMBER DEFAULT 0;

    V_COVERAGE_PCT FLOAT;

    V_RULE_MAE FLOAT;
    V_CURRENT_ML_MAE FLOAT;
    V_CANDIDATE_MAE FLOAT;
    V_CANDIDATE_RMSE FLOAT;

    V_RULE_ADVANTAGE FLOAT;
    V_CURRENT_ML_ADVANTAGE FLOAT;

    V_BMCS_BRIER FLOAT;
    V_BMCS_ACCURACY_PCT FLOAT;

    V_GUARDRAIL_PASS_COUNT NUMBER DEFAULT 0;
    V_GUARDRAIL_PASS_PCT FLOAT;

    V_SAMPLE_SIZE_PASS BOOLEAN DEFAULT FALSE;
    V_COVERAGE_PASS BOOLEAN DEFAULT FALSE;
    V_ERROR_PASS BOOLEAN DEFAULT FALSE;
    V_RULE_ADVANTAGE_PASS BOOLEAN DEFAULT FALSE;
    V_ACCURACY_PASS BOOLEAN DEFAULT FALSE;
    V_GUARDRAIL_PASS BOOLEAN DEFAULT FALSE;

    V_BACKTEST_STATUS VARCHAR;
    V_BACKTEST_REASON VARCHAR;

    V_DETAIL_INSERTED_ROWS NUMBER DEFAULT 0;
    V_RUN_INSERTED_ROWS NUMBER DEFAULT 0;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    IF (
        P_BACKTEST_RUN_ID IS NULL
        OR LENGTH(TRIM(P_BACKTEST_RUN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_BACKTEST_RUN_ID is required.''
        );
    END IF;

    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_DEPLOYMENT_REQUEST_ID is required.''
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
    INTO :V_EXISTING_RUN_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_RUN_V1
    WHERE BACKTEST_RUN_ID =
          :P_BACKTEST_RUN_ID;

    IF (V_EXISTING_RUN_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_12A'',

                ''backtest_run_id'',
                    BACKTEST_RUN_ID,
                ''deployment_request_id'',
                    DEPLOYMENT_REQUEST_ID,
                ''evidence_version'',
                    EVIDENCE_VERSION,

                ''backtest_status'',
                    BACKTEST_STATUS,
                ''backtest_reason'',
                    BACKTEST_REASON,

                ''eligible_outcome_count'',
                    ELIGIBLE_OUTCOME_COUNT,
                ''valid_prediction_count'',
                    VALID_PREDICTION_COUNT,
                ''prediction_coverage_pct'',
                    PREDICTION_COVERAGE_PCT,

                ''candidate_mae'',
                    CANDIDATE_MAE,
                ''bmcs_brier_score'',
                    BMCS_BRIER_SCORE,
                ''bmcs_accuracy_pct'',
                    BMCS_CLASSIFICATION_ACCURACY_PCT,

                ''completed_at'',
                    COMPLETED_AT
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_CANDIDATE_BACKTEST_RUN_V1
            WHERE BACKTEST_RUN_ID =
                  :P_BACKTEST_RUN_ID
        );
    END IF;

    IF (V_EXISTING_RUN_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''BACKTEST_RUN_ID is not unique.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_ORPHAN_DETAIL_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_DETAIL_V1
    WHERE BACKTEST_RUN_ID =
          :P_BACKTEST_RUN_ID;

    IF (V_ORPHAN_DETAIL_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Orphan backtest detail rows exist for this run ID.'',
            ''orphan_detail_count'',
                V_ORPHAN_DETAIL_COUNT
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(MODEL_DOMAIN),
        MAX(TARGET_MODE),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),

        MAX(CANDIDATE_MODEL_NAME),
        MAX(CANDIDATE_MODEL_VERSION),
        MAX(CANDIDATE_FEATURE_SET_VERSION)

    INTO
        :V_REQUEST_COUNT,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1

    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one deployment request is required.'',
            ''request_count'', V_REQUEST_COUNT
        );
    END IF;

    IF (
        V_REQUEST_STATUS IN (
            ''ACTIVATED'',
            ''ROLLED_BACK'',
            ''CANCELLED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''A completed request cannot create a new candidate backtest.'',
            ''request_status'', V_REQUEST_STATUS
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(FINAL_VALUE_MIN::FLOAT),
        MAX(FINAL_VALUE_MAX::FLOAT),

        MAX(
            MAX_ABS_DEVIATION_FROM_RULE::FLOAT
        ),
        MAX(
            MAX_PCT_DEVIATION_FROM_RULE::FLOAT
        )

    INTO
        :V_POLICY_COUNT,

        :V_FINAL_MIN,
        :V_FINAL_MAX,

        :V_MAX_ABS_DEVIATION,
        :V_MAX_PCT_DEVIATION

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_POLICY_V1

    WHERE POLICY_ID =
          :V_CANDIDATE_POLICY_ID

      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION

      AND MODEL_DOMAIN =
          :V_MODEL_DOMAIN

      AND POLICY_STATUS = ''DRAFT'';

    IF (V_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''The request candidate is not available as one DRAFT policy row.'',
            ''candidate_count'', V_POLICY_COUNT
        );
    END IF;

    SELECT
        MAX(PREDICTION_SET_VERSION)
    INTO :V_PREDICTION_SET_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_CANDIDATE_PREDICTION_CURRENT_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID
      AND EVIDENCE_VERSION =
          :V_EVIDENCE_VERSION;

    V_REQUIRED_MIN_SAMPLE_SIZE :=
        CASE
            WHEN V_MODEL_DOMAIN = ''BMCS''
             AND V_TARGET_MODE = ''CONTROLLED''
                THEN 20
            WHEN V_MODEL_DOMAIN = ''BMCS''
             AND V_TARGET_MODE = ''PRODUCTION''
                THEN 50
            WHEN V_TARGET_MODE = ''CONTROLLED''
                THEN 10
            ELSE 30
        END;

    V_REQUIRED_MIN_COVERAGE_PCT :=
        IFF(
            V_TARGET_MODE = ''CONTROLLED'',
            80.0,
            95.0
        );

    V_REQUIRED_MAX_ERROR :=
        CASE
            WHEN V_MODEL_DOMAIN IN (
                ''CSS'',
                ''FMIS''
            )
             AND V_TARGET_MODE = ''CONTROLLED''
                THEN 0.03
            WHEN V_MODEL_DOMAIN IN (
                ''CSS'',
                ''FMIS''
            )
             AND V_TARGET_MODE = ''PRODUCTION''
                THEN 0.02
            WHEN V_MODEL_DOMAIN = ''TDS''
             AND V_TARGET_MODE = ''CONTROLLED''
                THEN 0.15
            WHEN V_MODEL_DOMAIN = ''TDS''
             AND V_TARGET_MODE = ''PRODUCTION''
                THEN 0.10
            WHEN V_MODEL_DOMAIN = ''BMCS''
             AND V_TARGET_MODE = ''CONTROLLED''
                THEN 0.15
            ELSE 0.10
        END;

    V_REQUIRED_MIN_ACCURACY_PCT :=
        CASE
            WHEN V_MODEL_DOMAIN = ''BMCS''
             AND V_TARGET_MODE = ''CONTROLLED''
                THEN 80.0
            WHEN V_MODEL_DOMAIN = ''BMCS''
             AND V_TARGET_MODE = ''PRODUCTION''
                THEN 90.0
            ELSE NULL::FLOAT
        END;

    V_STARTED_AT := CURRENT_TIMESTAMP();
    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_DETAIL_V1 (
                BACKTEST_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                EVIDENCE_VERSION,

                MODEL_DOMAIN,
                TARGET_MODE,

                CANDIDATE_POLICY_ID,
                CANDIDATE_POLICY_VERSION,

                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,

                OUTCOME_AVAILABLE_FLAG,

                PREDICTION_ID,
                PREDICTION_AVAILABLE_FLAG,
                PREDICTION_ELIGIBLE_FLAG,

                QUALITY_PASS_FLAG,
                OOD_FLAG,

                RULE_VALUE,
                CURRENT_ML_VALUE,
                CANDIDATE_VALUE,
                ACTUAL_VALUE,

                RULE_ABS_ERROR,
                CURRENT_ML_ABS_ERROR,
                CANDIDATE_ABS_ERROR,

                CANDIDATE_BRIER_SCORE,
                CANDIDATE_CLASSIFICATION_CORRECT_FLAG,

                BOUNDS_PASS_FLAG,
                ABS_DEVIATION_PASS_FLAG,
                PCT_DEVIATION_PASS_FLAG,
                OVERALL_GUARDRAIL_PASS_FLAG,

                EXCLUSION_REASON,

                CREATED_AT
            )
    SELECT
        TRIM(:P_BACKTEST_RUN_ID),

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        feedback.SIMULATION_ID,
        feedback.KMAT_ID,
        feedback.RFQ_ID,

        feedback.OUTCOME_AVAILABLE_FLAG,

        prediction.PREDICTION_ID,

        IFF(
            prediction.PREDICTION_ID IS NOT NULL,
            TRUE,
            FALSE
        ),

        IFF(
            prediction.PREDICTION_ID IS NOT NULL
            AND prediction.QUALITY_PASS_FLAG = TRUE
            AND prediction.OOD_FLAG = FALSE,
            TRUE,
            FALSE
        ),

        prediction.QUALITY_PASS_FLAG,
        prediction.OOD_FLAG,

        feedback.RULE_VALUE::FLOAT,

        IFF(
            :V_MODEL_DOMAIN = ''BMCS'',
            feedback.ML_PROBABILITY_VALUE::FLOAT,
            feedback.ML_ADVISORY_VALUE::FLOAT
        ),

        prediction.PREDICTED_NUMERIC_VALUE::FLOAT,

        IFF(
            :V_MODEL_DOMAIN = ''BMCS'',
            IFF(
                feedback.ACTUAL_MAPPING_CORRECT_FLAG,
                1.0,
                0.0
            )::FLOAT,
            feedback.ACTUAL_NUMERIC_VALUE::FLOAT
        ),

        IFF(
            feedback.RULE_VALUE IS NOT NULL
            AND feedback.ACTUAL_NUMERIC_VALUE
                IS NOT NULL
            AND :V_MODEL_DOMAIN <> ''BMCS'',
            ABS(
                feedback.RULE_VALUE
                - feedback.ACTUAL_NUMERIC_VALUE
            ),
            NULL::FLOAT
        ),

        IFF(
            :V_MODEL_DOMAIN = ''BMCS'',
            IFF(
                feedback.ML_PROBABILITY_VALUE
                    IS NOT NULL
                AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
                    IS NOT NULL,
                ABS(
                    feedback.ML_PROBABILITY_VALUE
                    - IFF(
                        feedback
                            .ACTUAL_MAPPING_CORRECT_FLAG,
                        1.0,
                        0.0
                    )
                ),
                NULL::FLOAT
            ),
            IFF(
                feedback.ML_ADVISORY_VALUE
                    IS NOT NULL
                AND feedback.ACTUAL_NUMERIC_VALUE
                    IS NOT NULL,
                ABS(
                    feedback.ML_ADVISORY_VALUE
                    - feedback.ACTUAL_NUMERIC_VALUE
                ),
                NULL::FLOAT
            )
        ),

        IFF(
            prediction.PREDICTION_ID IS NOT NULL
            AND prediction.QUALITY_PASS_FLAG = TRUE
            AND prediction.OOD_FLAG = FALSE,
            ABS(
                prediction.PREDICTED_NUMERIC_VALUE
                - IFF(
                    :V_MODEL_DOMAIN = ''BMCS'',
                    IFF(
                        feedback
                            .ACTUAL_MAPPING_CORRECT_FLAG,
                        1.0,
                        0.0
                    ),
                    feedback.ACTUAL_NUMERIC_VALUE
                )
            ),
            NULL::FLOAT
        ),

        IFF(
            :V_MODEL_DOMAIN = ''BMCS''
            AND prediction.PREDICTION_ID
                IS NOT NULL
            AND prediction.QUALITY_PASS_FLAG = TRUE
            AND prediction.OOD_FLAG = FALSE
            AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
                IS NOT NULL,
            POWER(
                prediction.PREDICTED_NUMERIC_VALUE
                - IFF(
                    feedback
                        .ACTUAL_MAPPING_CORRECT_FLAG,
                    1.0,
                    0.0
                ),
                2
            ),
            NULL::FLOAT
        ),

        IFF(
            :V_MODEL_DOMAIN = ''BMCS''
            AND prediction.PREDICTION_ID
                IS NOT NULL
            AND prediction.QUALITY_PASS_FLAG = TRUE
            AND prediction.OOD_FLAG = FALSE
            AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
                IS NOT NULL,
            IFF(
                (
                    prediction.PREDICTED_NUMERIC_VALUE
                        >= 0.5
                    AND feedback
                        .ACTUAL_MAPPING_CORRECT_FLAG
                )
                OR
                (
                    prediction.PREDICTED_NUMERIC_VALUE
                        < 0.5
                    AND NOT feedback
                        .ACTUAL_MAPPING_CORRECT_FLAG
                ),
                TRUE,
                FALSE
            ),
            NULL::BOOLEAN
        ),

        IFF(
            prediction.PREDICTION_ID IS NULL,
            FALSE,
            (
                (
                    :V_FINAL_MIN IS NULL
                    OR prediction.PREDICTED_NUMERIC_VALUE
                        >= :V_FINAL_MIN
                )
                AND
                (
                    :V_FINAL_MAX IS NULL
                    OR prediction.PREDICTED_NUMERIC_VALUE
                        <= :V_FINAL_MAX
                )
            )
        ),

        IFF(
            prediction.PREDICTION_ID IS NULL,
            FALSE,
            (
                :V_MAX_ABS_DEVIATION IS NULL
                OR feedback.RULE_VALUE IS NULL
                OR ABS(
                    prediction.PREDICTED_NUMERIC_VALUE
                    - feedback.RULE_VALUE
                ) <= :V_MAX_ABS_DEVIATION
            )
        ),

        IFF(
            prediction.PREDICTION_ID IS NULL,
            FALSE,
            (
                :V_MAX_PCT_DEVIATION IS NULL
                OR feedback.RULE_VALUE IS NULL
                OR ABS(feedback.RULE_VALUE) < 0.000000001
                OR (
                    ABS(
                        prediction.PREDICTED_NUMERIC_VALUE
                        - feedback.RULE_VALUE
                    )
                    /
                    ABS(feedback.RULE_VALUE)
                ) * 100.0
                    <= :V_MAX_PCT_DEVIATION
            )
        ),

        IFF(
            prediction.PREDICTION_ID IS NOT NULL
            AND prediction.QUALITY_PASS_FLAG = TRUE
            AND prediction.OOD_FLAG = FALSE

            AND (
                :V_FINAL_MIN IS NULL
                OR prediction.PREDICTED_NUMERIC_VALUE
                    >= :V_FINAL_MIN
            )

            AND (
                :V_FINAL_MAX IS NULL
                OR prediction.PREDICTED_NUMERIC_VALUE
                    <= :V_FINAL_MAX
            )

            AND (
                :V_MAX_ABS_DEVIATION IS NULL
                OR feedback.RULE_VALUE IS NULL
                OR ABS(
                    prediction.PREDICTED_NUMERIC_VALUE
                    - feedback.RULE_VALUE
                ) <= :V_MAX_ABS_DEVIATION
            )

            AND (
                :V_MAX_PCT_DEVIATION IS NULL
                OR feedback.RULE_VALUE IS NULL
                OR ABS(feedback.RULE_VALUE) < 0.000000001
                OR (
                    ABS(
                        prediction.PREDICTED_NUMERIC_VALUE
                        - feedback.RULE_VALUE
                    )
                    /
                    ABS(feedback.RULE_VALUE)
                ) * 100.0
                    <= :V_MAX_PCT_DEVIATION
            ),
            TRUE,
            FALSE
        ),

        CASE
            WHEN prediction.PREDICTION_ID IS NULL
                THEN ''CANDIDATE_PREDICTION_MISSING''
            WHEN prediction.QUALITY_PASS_FLAG = FALSE
                THEN ''CANDIDATE_QUALITY_FAILED''
            WHEN prediction.OOD_FLAG = TRUE
                THEN ''CANDIDATE_OOD''
            ELSE NULL::VARCHAR
        END,

        CURRENT_TIMESTAMP()

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
            feedback

    LEFT JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_CANDIDATE_PREDICTION_CURRENT_V1
            prediction

        ON prediction.DEPLOYMENT_REQUEST_ID =
           :P_DEPLOYMENT_REQUEST_ID

       AND prediction.EVIDENCE_VERSION =
           :V_EVIDENCE_VERSION

       AND prediction.SIMULATION_ID =
           feedback.SIMULATION_ID

    WHERE feedback.MODEL_DOMAIN =
          :V_MODEL_DOMAIN

      AND feedback.MONITORING_ELIGIBLE_FLAG = TRUE

      AND feedback.OUTCOME_AVAILABLE_FLAG = TRUE;

    V_DETAIL_INSERTED_ROWS := SQLROWCOUNT;

    SELECT
        COUNT(*)::NUMBER,

        COUNT_IF(
            PREDICTION_AVAILABLE_FLAG = TRUE
        )::NUMBER,

        COUNT_IF(
            PREDICTION_ELIGIBLE_FLAG = TRUE
        )::NUMBER,

        IFF(
            COUNT(*) = 0,
            NULL::FLOAT,
            (
                COUNT_IF(
                    PREDICTION_ELIGIBLE_FLAG = TRUE
                )
                /
                COUNT(*)
            ) * 100.0
        )::FLOAT,

        AVG(RULE_ABS_ERROR)::FLOAT,
        AVG(CURRENT_ML_ABS_ERROR)::FLOAT,
        AVG(CANDIDATE_ABS_ERROR)::FLOAT,

        SQRT(
            AVG(
                POWER(
                    CANDIDATE_ABS_ERROR,
                    2
                )
            )
        )::FLOAT,

        AVG(CANDIDATE_BRIER_SCORE)::FLOAT,

        IFF(
            COUNT_IF(
                CANDIDATE_CLASSIFICATION_CORRECT_FLAG
                    IS NOT NULL
            ) = 0,
            NULL::FLOAT,
            (
                COUNT_IF(
                    CANDIDATE_CLASSIFICATION_CORRECT_FLAG
                        = TRUE
                )
                /
                COUNT_IF(
                    CANDIDATE_CLASSIFICATION_CORRECT_FLAG
                        IS NOT NULL
                )
            ) * 100.0
        )::FLOAT,

        COUNT_IF(
            PREDICTION_ELIGIBLE_FLAG = TRUE
            AND OVERALL_GUARDRAIL_PASS_FLAG = TRUE
        )::NUMBER,

        IFF(
            COUNT_IF(
                PREDICTION_ELIGIBLE_FLAG = TRUE
            ) = 0,
            NULL::FLOAT,
            (
                COUNT_IF(
                    PREDICTION_ELIGIBLE_FLAG = TRUE
                    AND OVERALL_GUARDRAIL_PASS_FLAG
                        = TRUE
                )
                /
                COUNT_IF(
                    PREDICTION_ELIGIBLE_FLAG = TRUE
                )
            ) * 100.0
        )::FLOAT

    INTO
        :V_ELIGIBLE_OUTCOME_COUNT,

        :V_AVAILABLE_PREDICTION_COUNT,
        :V_VALID_PREDICTION_COUNT,

        :V_COVERAGE_PCT,

        :V_RULE_MAE,
        :V_CURRENT_ML_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,

        :V_BMCS_BRIER,
        :V_BMCS_ACCURACY_PCT,

        :V_GUARDRAIL_PASS_COUNT,
        :V_GUARDRAIL_PASS_PCT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_DETAIL_V1

    WHERE BACKTEST_RUN_ID =
          :P_BACKTEST_RUN_ID;

    V_RULE_ADVANTAGE :=
        IFF(
            V_RULE_MAE IS NOT NULL
            AND V_CANDIDATE_MAE IS NOT NULL,
            V_RULE_MAE - V_CANDIDATE_MAE,
            NULL::FLOAT
        );

    V_CURRENT_ML_ADVANTAGE :=
        IFF(
            V_CURRENT_ML_MAE IS NOT NULL
            AND V_CANDIDATE_MAE IS NOT NULL,
            V_CURRENT_ML_MAE - V_CANDIDATE_MAE,
            NULL::FLOAT
        );

    V_SAMPLE_SIZE_PASS :=
        V_VALID_PREDICTION_COUNT
        >= V_REQUIRED_MIN_SAMPLE_SIZE;

    V_COVERAGE_PASS :=
        COALESCE(
            V_COVERAGE_PCT,
            0.0
        )
        >= V_REQUIRED_MIN_COVERAGE_PCT;

    IF (V_MODEL_DOMAIN = ''BMCS'') THEN
        V_ERROR_PASS :=
            V_BMCS_BRIER IS NOT NULL
            AND V_BMCS_BRIER
                <= V_REQUIRED_MAX_ERROR;

        V_ACCURACY_PASS :=
            V_BMCS_ACCURACY_PCT IS NOT NULL
            AND V_BMCS_ACCURACY_PCT
                >= V_REQUIRED_MIN_ACCURACY_PCT;

        V_RULE_ADVANTAGE_PASS := TRUE;

    ELSE
        V_ERROR_PASS :=
            V_CANDIDATE_MAE IS NOT NULL
            AND V_CANDIDATE_MAE
                <= V_REQUIRED_MAX_ERROR;

        V_ACCURACY_PASS := TRUE;

        V_RULE_ADVANTAGE_PASS :=
            V_RULE_ADVANTAGE IS NOT NULL
            AND V_RULE_ADVANTAGE >= 0.0;
    END IF;

    V_GUARDRAIL_PASS :=
        V_VALID_PREDICTION_COUNT > 0
        AND V_GUARDRAIL_PASS_COUNT
            = V_VALID_PREDICTION_COUNT;

    IF (V_ELIGIBLE_OUTCOME_COUNT = 0) THEN
        V_BACKTEST_STATUS := ''NO_DATA'';
        V_BACKTEST_REASON :=
            ''No verified eligible outcomes are available for the candidate domain.'';

    ELSEIF (NOT V_SAMPLE_SIZE_PASS) THEN
        V_BACKTEST_STATUS :=
            ''INSUFFICIENT_DATA'';
        V_BACKTEST_REASON :=
            ''Valid candidate prediction count is below the target-mode minimum sample size.'';

    ELSEIF (
        NOT V_COVERAGE_PASS
        OR NOT V_ERROR_PASS
        OR NOT V_RULE_ADVANTAGE_PASS
        OR NOT V_ACCURACY_PASS
        OR NOT V_GUARDRAIL_PASS
    ) THEN
        V_BACKTEST_STATUS := ''FAIL'';
        V_BACKTEST_REASON :=
            ''At least one candidate coverage, error, advantage, accuracy or policy-guardrail requirement failed.'';

    ELSE
        V_BACKTEST_STATUS := ''PASS'';
        V_BACKTEST_REASON :=
            ''Candidate passed request-specific offline evidence and policy guardrails.'';
    END IF;

    V_COMPLETED_AT := CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_RUN_V1 (
                BACKTEST_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                EVIDENCE_VERSION,

                MODEL_DOMAIN,
                TARGET_MODE,

                CANDIDATE_POLICY_ID,
                CANDIDATE_POLICY_VERSION,

                CANDIDATE_MODEL_NAME,
                CANDIDATE_MODEL_VERSION,
                CANDIDATE_FEATURE_SET_VERSION,

                PREDICTION_SET_VERSION,

                BACKTEST_STATUS,
                BACKTEST_REASON,

                ELIGIBLE_OUTCOME_COUNT,
                AVAILABLE_PREDICTION_COUNT,
                VALID_PREDICTION_COUNT,

                PREDICTION_COVERAGE_PCT,

                RULE_MAE,
                CURRENT_ML_MAE,
                CANDIDATE_MAE,
                CANDIDATE_RMSE,

                CANDIDATE_ERROR_ADVANTAGE_VS_RULE,
                CANDIDATE_ERROR_ADVANTAGE_VS_CURRENT_ML,

                BMCS_BRIER_SCORE,
                BMCS_CLASSIFICATION_ACCURACY_PCT,

                GUARDRAIL_PASS_COUNT,
                GUARDRAIL_PASS_PCT,

                REQUIRED_MIN_SAMPLE_SIZE,
                REQUIRED_MIN_COVERAGE_PCT,
                REQUIRED_MAX_ERROR,
                REQUIRED_MIN_ACCURACY_PCT,

                SAMPLE_SIZE_PASS_FLAG,
                COVERAGE_PASS_FLAG,
                ERROR_PASS_FLAG,
                RULE_ADVANTAGE_PASS_FLAG,
                ACCURACY_PASS_FLAG,
                GUARDRAIL_PASS_FLAG,

                RUN_BY,
                STARTED_AT,
                COMPLETED_AT,

                CREATED_AT
            )
    SELECT
        TRIM(:P_BACKTEST_RUN_ID),

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,

        :V_PREDICTION_SET_VERSION,

        :V_BACKTEST_STATUS,
        :V_BACKTEST_REASON,

        :V_ELIGIBLE_OUTCOME_COUNT,
        :V_AVAILABLE_PREDICTION_COUNT,
        :V_VALID_PREDICTION_COUNT,

        :V_COVERAGE_PCT,

        :V_RULE_MAE,
        :V_CURRENT_ML_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,

        :V_RULE_ADVANTAGE,
        :V_CURRENT_ML_ADVANTAGE,

        :V_BMCS_BRIER,
        :V_BMCS_ACCURACY_PCT,

        :V_GUARDRAIL_PASS_COUNT,
        :V_GUARDRAIL_PASS_PCT,

        :V_REQUIRED_MIN_SAMPLE_SIZE,
        :V_REQUIRED_MIN_COVERAGE_PCT,
        :V_REQUIRED_MAX_ERROR,
        :V_REQUIRED_MIN_ACCURACY_PCT,

        :V_SAMPLE_SIZE_PASS,
        :V_COVERAGE_PASS,
        :V_ERROR_PASS,
        :V_RULE_ADVANTAGE_PASS,
        :V_ACCURACY_PASS,
        :V_GUARDRAIL_PASS,

        TRIM(:P_RUN_BY),
        :V_STARTED_AT,
        :V_COMPLETED_AT,

        CURRENT_TIMESTAMP();

    V_RUN_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_RUN_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Backtest run insert did not affect exactly one row.'',
            ''inserted_rows'', V_RUN_INSERTED_ROWS
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                DEPLOYMENT_REQUEST_ID,
                EVIDENCE_VERSION,

                BACKTEST_RUN_ID,
                PREDICTION_ID,

                MODEL_DOMAIN,
                SIMULATION_ID,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_EVENT_ID,
        ''CANDIDATE_BACKTEST_COMPLETED'',

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        TRIM(:P_BACKTEST_RUN_ID),
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        :V_BACKTEST_STATUS,
        :V_BACKTEST_REASON,

        TRIM(:P_RUN_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_12A'',

        ''backtest_run_id'', P_BACKTEST_RUN_ID,
        ''deployment_request_id'',
            P_DEPLOYMENT_REQUEST_ID,
        ''evidence_version'', V_EVIDENCE_VERSION,

        ''model_domain'', V_MODEL_DOMAIN,
        ''target_mode'', V_TARGET_MODE,

        ''backtest_status'', V_BACKTEST_STATUS,
        ''backtest_reason'', V_BACKTEST_REASON,

        ''eligible_outcome_count'',
            V_ELIGIBLE_OUTCOME_COUNT,
        ''available_prediction_count'',
            V_AVAILABLE_PREDICTION_COUNT,
        ''valid_prediction_count'',
            V_VALID_PREDICTION_COUNT,
        ''prediction_coverage_pct'',
            V_COVERAGE_PCT,

        ''rule_mae'', V_RULE_MAE,
        ''current_ml_mae'', V_CURRENT_ML_MAE,
        ''candidate_mae'', V_CANDIDATE_MAE,
        ''candidate_rmse'', V_CANDIDATE_RMSE,

        ''candidate_error_advantage_vs_rule'',
            V_RULE_ADVANTAGE,

        ''bmcs_brier_score'', V_BMCS_BRIER,
        ''bmcs_accuracy_pct'',
            V_BMCS_ACCURACY_PCT,

        ''guardrail_pass_pct'',
            V_GUARDRAIL_PASS_PCT,

        ''detail_inserted_rows'',
            V_DETAIL_INSERTED_ROWS,

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


-- ============================================================
-- 5. LATEST BACKTEST AND REQUEST READINESS V2
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_CANDIDATE_BACKTEST_LATEST_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_RUN_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        DEPLOYMENT_REQUEST_ID,
        EVIDENCE_VERSION
    ORDER BY
        COMPLETED_AT DESC,
        CREATED_AT DESC,
        BACKTEST_RUN_ID DESC
) = 1;

CREATE TABLE IF NOT EXISTS KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 (
    DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
    MODEL_DOMAIN VARCHAR NOT NULL,
    TARGET_MODE VARCHAR NOT NULL,
    FROM_POLICY_ID VARCHAR,
    FROM_POLICY_VERSION VARCHAR,
    FROM_DEPLOYMENT_MODE VARCHAR,
    CANDIDATE_POLICY_ID VARCHAR NOT NULL,
    CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,
    CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
    CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
    CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,
    REQUEST_STATUS VARCHAR NOT NULL,
    READINESS_STATUS VARCHAR,
    EVIDENCE_VERSION NUMBER NOT NULL DEFAULT 1,
    REQUIRED_GATE_COUNT NUMBER,
    PASS_GATE_COUNT NUMBER,
    FAIL_GATE_COUNT NUMBER,
    NO_DATA_GATE_COUNT NUMBER,
    INSUFFICIENT_GATE_COUNT NUMBER,
    EVIDENCE_SNAPSHOT VARIANT,
    EVIDENCE_CAPTURED_AT TIMESTAMP_NTZ,
    REQUESTED_BY VARCHAR NOT NULL,
    REQUESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    BUSINESS_JUSTIFICATION VARCHAR,
    APPROVED_BY VARCHAR,
    APPROVED_AT TIMESTAMP_NTZ,
    ACTIVATED_BY VARCHAR,
    ACTIVATED_AT TIMESTAMP_NTZ,
    ROLLED_BACK_BY VARCHAR,
    ROLLED_BACK_AT TIMESTAMP_NTZ,
    ROLLBACK_REASON VARCHAR,
    LAST_REFRESHED_BY VARCHAR,
    LAST_REFRESHED_AT TIMESTAMP_NTZ,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 (
    APPROVAL_ID VARCHAR NOT NULL,
    DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
    EVIDENCE_VERSION NUMBER NOT NULL,
    APPROVAL_STAGE VARCHAR NOT NULL,
    REVIEW_ACTION VARCHAR NOT NULL,
    REVIEWED_BY VARCHAR NOT NULL,
    REVIEW_NOTE VARCHAR,
    REVIEWED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2
AS
WITH APPROVAL_TIMING AS (
    SELECT
        request.DEPLOYMENT_REQUEST_ID,
        request.EVIDENCE_VERSION,

        COUNT_IF(
            approval.REVIEW_ACTION = 'APPROVE'
        ) AS APPROVED_STAGE_COUNT,

        MIN(
            IFF(
                approval.REVIEW_ACTION = 'APPROVE',
                approval.REVIEWED_AT,
                NULL::TIMESTAMP_NTZ
            )
        ) AS EARLIEST_APPROVAL_AT,

        MAX(
            IFF(
                approval.REVIEW_ACTION = 'APPROVE',
                approval.REVIEWED_AT,
                NULL::TIMESTAMP_NTZ
            )
        ) AS LATEST_APPROVAL_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_WORKFLOW_V1
            request

    LEFT JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_APPROVAL_CURRENT_V1
            approval

        ON request.DEPLOYMENT_REQUEST_ID =
           approval.DEPLOYMENT_REQUEST_ID

       AND request.EVIDENCE_VERSION =
           approval.EVIDENCE_VERSION

    GROUP BY
        request.DEPLOYMENT_REQUEST_ID,
        request.EVIDENCE_VERSION
)
SELECT
    request.*,

    backtest.BACKTEST_RUN_ID,
    backtest.BACKTEST_STATUS,
    backtest.BACKTEST_REASON,

    backtest.ELIGIBLE_OUTCOME_COUNT,
    backtest.VALID_PREDICTION_COUNT,
    backtest.PREDICTION_COVERAGE_PCT,

    backtest.CANDIDATE_MAE,
    backtest.BMCS_BRIER_SCORE,
    backtest.BMCS_CLASSIFICATION_ACCURACY_PCT,
    backtest.GUARDRAIL_PASS_PCT,

    backtest.COMPLETED_AT
        AS BACKTEST_COMPLETED_AT,

    approval_timing.EARLIEST_APPROVAL_AT,
    approval_timing.LATEST_APPROVAL_AT,

    IFF(
        backtest.BACKTEST_RUN_ID IS NOT NULL
        AND backtest.BACKTEST_STATUS = 'PASS',
        TRUE,
        FALSE
    ) AS BACKTEST_PASS_FLAG,

    IFF(
        request.ALL_CURRENT_APPROVALS_COMPLETE_FLAG = TRUE
        AND backtest.BACKTEST_RUN_ID IS NOT NULL
        AND approval_timing.EARLIEST_APPROVAL_AT
            >= backtest.COMPLETED_AT,
        TRUE,
        FALSE
    ) AS APPROVALS_AFTER_BACKTEST_FLAG,

    CASE
        WHEN request.READINESS_STATUS <> 'READY'
            THEN request.READINESS_STATUS

        WHEN backtest.BACKTEST_RUN_ID IS NULL
            THEN 'NO_BACKTEST'

        WHEN backtest.BACKTEST_STATUS <> 'PASS'
            THEN 'BACKTEST_' || backtest.BACKTEST_STATUS

        WHEN request.REQUEST_STATUS = 'APPROVED'
         AND request.ALL_CURRENT_APPROVALS_COMPLETE_FLAG = TRUE
         AND (
             approval_timing.EARLIEST_APPROVAL_AT IS NULL
             OR approval_timing.EARLIEST_APPROVAL_AT
                < backtest.COMPLETED_AT
         )
            THEN 'APPROVALS_STALE_FOR_BACKTEST'

        WHEN request.REQUEST_STATUS = 'APPROVED'
         AND request.ALL_CURRENT_APPROVALS_COMPLETE_FLAG = TRUE
         AND request.EVIDENCE_FRESH_FLAG = TRUE
         AND approval_timing.EARLIEST_APPROVAL_AT
             >= backtest.COMPLETED_AT
            THEN 'ACTIVATION_READY'

        ELSE 'BACKTEST_READY_AWAITING_APPROVALS'
    END AS PHASE12A_READINESS_STATUS,

    IFF(
        request.REQUEST_STATUS = 'APPROVED'
        AND request.READINESS_STATUS = 'READY'
        AND request.ALL_CURRENT_APPROVALS_COMPLETE_FLAG = TRUE
        AND request.EVIDENCE_FRESH_FLAG = TRUE
        AND backtest.BACKTEST_STATUS = 'PASS'
        AND approval_timing.EARLIEST_APPROVAL_AT
            >= backtest.COMPLETED_AT,
        TRUE,
        FALSE
    ) AS ACTIVATION_ELIGIBLE_V2_FLAG

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_WORKFLOW_V1
        request

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_CANDIDATE_BACKTEST_LATEST_V1
        backtest

    ON request.DEPLOYMENT_REQUEST_ID =
       backtest.DEPLOYMENT_REQUEST_ID

   AND request.EVIDENCE_VERSION =
       backtest.EVIDENCE_VERSION

LEFT JOIN APPROVAL_TIMING approval_timing
    ON request.DEPLOYMENT_REQUEST_ID =
       approval_timing.DEPLOYMENT_REQUEST_ID

   AND request.EVIDENCE_VERSION =
       approval_timing.EVIDENCE_VERSION;


-- ============================================================
-- 6. V2 ACTIVATION GATE
--
-- V1 remains the atomic policy transition implementation.
-- V2 adds request-specific backtest enforcement before V1.
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_ACTIVATED_BY VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_READINESS_COUNT NUMBER DEFAULT 0;

    V_PHASE12A_STATUS VARCHAR;
    V_BACKTEST_RUN_ID VARCHAR;
    V_BACKTEST_STATUS VARCHAR;
    V_ACTIVATION_ELIGIBLE BOOLEAN;

    V_V1_RESULT VARIANT;
    V_V1_STATUS VARCHAR;
BEGIN
    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_DEPLOYMENT_REQUEST_ID is required.''
        );
    END IF;

    IF (
        P_ACTIVATED_BY IS NULL
        OR LENGTH(TRIM(P_ACTIVATED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_ACTIVATED_BY is required.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(PHASE12A_READINESS_STATUS),
        MAX(BACKTEST_RUN_ID),
        MAX(BACKTEST_STATUS),
        MAX(ACTIVATION_ELIGIBLE_V2_FLAG)

    INTO
        :V_READINESS_COUNT,

        :V_PHASE12A_STATUS,
        :V_BACKTEST_RUN_ID,
        :V_BACKTEST_STATUS,
        :V_ACTIVATION_ELIGIBLE

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2

    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID;

    IF (V_READINESS_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one Phase 12A request-readiness row is required.'',
            ''readiness_count'', V_READINESS_COUNT
        );
    END IF;

    IF (NOT COALESCE(V_ACTIVATION_ELIGIBLE, FALSE)) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12A'',

            ''message'',
                ''Activation is blocked by Phase 12A candidate evidence.'',

            ''deployment_request_id'',
                P_DEPLOYMENT_REQUEST_ID,

            ''phase12a_readiness_status'',
                V_PHASE12A_STATUS,

            ''backtest_run_id'',
                V_BACKTEST_RUN_ID,

            ''backtest_status'',
                V_BACKTEST_STATUS,

            ''activation_eligible_v2'',
                FALSE
        );
    END IF;

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(
                :P_DEPLOYMENT_REQUEST_ID,
                :P_ACTIVATED_BY,
                :P_CONFIRMATION_PHRASE
            )
    INTO :V_V1_RESULT;

    SELECT COALESCE(
        GET(:V_V1_RESULT, ''status'')::VARCHAR,
        ''UNKNOWN''
    )
    INTO :V_V1_STATUS;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_V1_STATUS,
        ''phase'', ''PHASE_12A'',

        ''deployment_request_id'',
            P_DEPLOYMENT_REQUEST_ID,

        ''phase12a_readiness_status'',
            V_PHASE12A_STATUS,

        ''backtest_run_id'',
            V_BACKTEST_RUN_ID,

        ''backtest_status'',
            V_BACKTEST_STATUS,

        ''activation_eligible_v2'',
            TRUE,

        ''phase11b_activation_result'',
            V_V1_RESULT
    );
END;
';


-- ============================================================
-- 7. DASHBOARD
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE12A_CANDIDATE_VALIDATION_V1
AS
SELECT
    readiness.DEPLOYMENT_REQUEST_ID,
    readiness.MODEL_DOMAIN,
    readiness.TARGET_MODE,

    readiness.CANDIDATE_POLICY_ID,
    readiness.CANDIDATE_POLICY_VERSION,

    readiness.CANDIDATE_MODEL_NAME,
    readiness.CANDIDATE_MODEL_VERSION,
    readiness.CANDIDATE_FEATURE_SET_VERSION,

    readiness.REQUEST_STATUS,
    readiness.READINESS_STATUS,
    readiness.EVIDENCE_VERSION,

    readiness.BACKTEST_RUN_ID,
    readiness.BACKTEST_STATUS,
    readiness.BACKTEST_REASON,

    readiness.ELIGIBLE_OUTCOME_COUNT,
    readiness.VALID_PREDICTION_COUNT,
    readiness.PREDICTION_COVERAGE_PCT,

    readiness.CANDIDATE_MAE,
    readiness.BMCS_BRIER_SCORE,
    readiness.BMCS_CLASSIFICATION_ACCURACY_PCT,
    readiness.GUARDRAIL_PASS_PCT,

    readiness.ALL_CURRENT_APPROVALS_COMPLETE_FLAG,
    readiness.EVIDENCE_FRESH_FLAG,
    readiness.APPROVALS_AFTER_BACKTEST_FLAG,

    readiness.PHASE12A_READINESS_STATUS,
    readiness.ACTIVATION_ELIGIBLE_V2_FLAG,

    readiness.BACKTEST_COMPLETED_AT,
    readiness.LATEST_APPROVAL_AT,
    readiness.UPDATED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2
        readiness;


-- ============================================================
-- PHASE 12A — VERIFICATION
--
-- This verification creates no candidate prediction, no
-- backtest evidence and no policy activation.
-- ============================================================


-- ------------------------------------------------------------
-- 1. PROCEDURE INVENTORY
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'RECORD_ML_CANDIDATE_PREDICTION_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_CANDIDATE_BACKTEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- ------------------------------------------------------------
-- 2. REQUIRED PHASE 12A PROCEDURE COUNT
--
-- Expected: 3
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE12A_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'RECORD_ML_CANDIDATE_PREDICTION_V1',
      'RUN_ML_CANDIDATE_BACKTEST_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
  );


-- ------------------------------------------------------------
-- 3. DUPLICATE ACTIVE PREDICTION CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

SELECT
    DEPLOYMENT_REQUEST_ID,
    EVIDENCE_VERSION,
    SIMULATION_ID,
    COUNT(*) AS DUPLICATE_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_PREDICTION_V1
WHERE IS_ACTIVE = TRUE
GROUP BY
    DEPLOYMENT_REQUEST_ID,
    EVIDENCE_VERSION,
    SIMULATION_ID
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 4. ORPHAN DETAIL CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

SELECT
    detail.BACKTEST_RUN_ID,
    COUNT(*) AS ORPHAN_DETAIL_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_DETAIL_V1
        detail
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_RUN_V1
        run
    ON detail.BACKTEST_RUN_ID =
       run.BACKTEST_RUN_ID
WHERE run.BACKTEST_RUN_ID IS NULL
GROUP BY detail.BACKTEST_RUN_ID;


-- ------------------------------------------------------------
-- 5. ACTIVATION SAFETY
--
-- A request cannot be V2 activation-eligible without:
--   * current request readiness READY;
--   * PASS candidate backtest;
--   * current approvals after backtest;
--   * fresh evidence.
--
-- Expected: INVALID_ACTIVATION_ELIGIBLE_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COUNT_IF(
        ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
        AND (
            REQUEST_STATUS <> 'APPROVED'
            OR READINESS_STATUS <> 'READY'
            OR BACKTEST_STATUS <> 'PASS'
            OR ALL_CURRENT_APPROVALS_COMPLETE_FLAG
                = FALSE
            OR EVIDENCE_FRESH_FLAG = FALSE
            OR APPROVALS_AFTER_BACKTEST_FLAG
                = FALSE
        )
    ) AS INVALID_ACTIVATION_ELIGIBLE_ROWS
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2;


-- ------------------------------------------------------------
-- 6. NEGATIVE PROCEDURE TEST
--
-- This must return status ERROR without writing data.
-- ------------------------------------------------------------

CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_CANDIDATE_BACKTEST_V1(
            'PHASE12A_NEGATIVE_TEST',
            'NONEXISTENT_DEPLOYMENT_REQUEST',
            'PHASE12A_VERIFICATION'
        );


-- ------------------------------------------------------------
-- 7. ACTIVE POLICIES MUST REMAIN UNCHANGED
--
-- Expected:
--   ACTIVE_POLICY_COUNT = 4
--   SHADOW_POLICY_COUNT = 4
--   AUTHORITY_ENABLED_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,

    COUNT_IF(
        DEPLOYMENT_MODE = 'SHADOW'
    ) AS SHADOW_POLICY_COUNT,

    COUNT_IF(
        AUTO_USE_ALLOWED_FLAG = TRUE
        OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
        OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
    ) AS AUTHORITY_ENABLED_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;


-- ------------------------------------------------------------
-- 8. DASHBOARD
-- ------------------------------------------------------------

SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE12A_CANDIDATE_VALIDATION_V1
ORDER BY UPDATED_AT DESC;

SELECT
    COALESCE(
        COUNT_IF(
            ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
            AND (
                REQUEST_STATUS <> 'APPROVED'
                OR READINESS_STATUS <> 'READY'
                OR BACKTEST_STATUS <> 'PASS'
                OR ALL_CURRENT_APPROVALS_COMPLETE_FLAG
                    = FALSE
                OR EVIDENCE_FRESH_FLAG = FALSE
                OR APPROVALS_AFTER_BACKTEST_FLAG
                    = FALSE
            )
        ),
        0
    )::NUMBER AS INVALID_ACTIVATION_ELIGIBLE_ROWS
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2;

WITH PROCEDURES AS (
    SELECT
        COUNT(DISTINCT PROCEDURE_NAME)
            AS PROCEDURE_COUNT
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'RECORD_ML_CANDIDATE_PREDICTION_V1',
          'RUN_ML_CANDIDATE_BACKTEST_V1',
          'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
      )
),
PREDICTIONS AS (
    SELECT COUNT(*) AS DUPLICATE_ACTIVE_KEY_COUNT
    FROM (
        SELECT
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,
            SIMULATION_ID
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_PREDICTION_V1
        WHERE IS_ACTIVE = TRUE
        GROUP BY
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,
            SIMULATION_ID
        HAVING COUNT(*) > 1
    )
),
ORPHANS AS (
    SELECT COUNT(*) AS ORPHAN_RUN_COUNT
    FROM (
        SELECT detail.BACKTEST_RUN_ID
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_BACKTEST_DETAIL_V1
                detail
        LEFT JOIN
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_BACKTEST_RUN_V1
                run
            ON detail.BACKTEST_RUN_ID =
               run.BACKTEST_RUN_ID
        WHERE run.BACKTEST_RUN_ID IS NULL
        GROUP BY detail.BACKTEST_RUN_ID
    )
),
SAFETY AS (
    SELECT
        COALESCE(
            COUNT_IF(
                ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
                AND (
                    REQUEST_STATUS <> 'APPROVED'
                    OR READINESS_STATUS <> 'READY'
                    OR BACKTEST_STATUS <> 'PASS'
                    OR ALL_CURRENT_APPROVALS_COMPLETE_FLAG
                        = FALSE
                    OR EVIDENCE_FRESH_FLAG = FALSE
                    OR APPROVALS_AFTER_BACKTEST_FLAG
                        = FALSE
                )
            ),
            0
        )::NUMBER AS INVALID_ACTIVATION_ROWS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2
),
POLICIES AS (
    SELECT
        COUNT(*) AS ACTIVE_POLICY_COUNT,

        COALESCE(
            COUNT_IF(
                DEPLOYMENT_MODE = 'SHADOW'
            ),
            0
        )::NUMBER AS SHADOW_POLICY_COUNT,

        COALESCE(
            COUNT_IF(
                AUTO_USE_ALLOWED_FLAG = TRUE
                OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
                OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
            ),
            0
        )::NUMBER AS AUTHORITY_ENABLED_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            procedures.PROCEDURE_COUNT = 3
            AND predictions
                .DUPLICATE_ACTIVE_KEY_COUNT = 0
            AND orphans.ORPHAN_RUN_COUNT = 0
            AND safety.INVALID_ACTIVATION_ROWS = 0
            AND policies.ACTIVE_POLICY_COUNT = 4
            AND policies.SHADOW_POLICY_COUNT = 4
            AND policies.AUTHORITY_ENABLED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_12A',

    'procedure_count',
        procedures.PROCEDURE_COUNT,

    'duplicate_active_prediction_keys',
        predictions.DUPLICATE_ACTIVE_KEY_COUNT,

    'orphan_backtest_run_count',
        orphans.ORPHAN_RUN_COUNT,

    'invalid_activation_eligible_rows',
        safety.INVALID_ACTIVATION_ROWS,

    'active_policy_count',
        policies.ACTIVE_POLICY_COUNT,

    'shadow_policy_count',
        policies.SHADOW_POLICY_COUNT,

    'authority_enabled_count',
        policies.AUTHORITY_ENABLED_COUNT,

    'candidate_backtest_authority',
        'EVIDENCE_ONLY',

    'activation_entry_point',
        'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',

    'official_cost_changed',
        FALSE,

    'policy_activated',
        FALSE
) AS PHASE12A_RESULT

FROM PROCEDURES procedures
CROSS JOIN PREDICTIONS predictions
CROSS JOIN ORPHANS orphans
CROSS JOIN SAFETY safety
CROSS JOIN POLICIES policies;


-- ============================================================
-- PHASE 12A — VERIFICATION
--
-- This verification creates no candidate prediction, no
-- backtest evidence and no policy activation.
-- ============================================================


-- ------------------------------------------------------------
-- 1. PROCEDURE INVENTORY
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'RECORD_ML_CANDIDATE_PREDICTION_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_CANDIDATE_BACKTEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- ------------------------------------------------------------
-- 2. REQUIRED PHASE 12A PROCEDURE COUNT
--
-- Expected: 3
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE12A_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'RECORD_ML_CANDIDATE_PREDICTION_V1',
      'RUN_ML_CANDIDATE_BACKTEST_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
  );


-- ------------------------------------------------------------
-- 3. DUPLICATE ACTIVE PREDICTION CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

SELECT
    DEPLOYMENT_REQUEST_ID,
    EVIDENCE_VERSION,
    SIMULATION_ID,
    COUNT(*) AS DUPLICATE_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_PREDICTION_V1
WHERE IS_ACTIVE = TRUE
GROUP BY
    DEPLOYMENT_REQUEST_ID,
    EVIDENCE_VERSION,
    SIMULATION_ID
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 4. ORPHAN DETAIL CHECK
--
-- Expected: zero rows.
-- ------------------------------------------------------------

SELECT
    detail.BACKTEST_RUN_ID,
    COUNT(*) AS ORPHAN_DETAIL_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_DETAIL_V1
        detail
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_CANDIDATE_BACKTEST_RUN_V1
        run
    ON detail.BACKTEST_RUN_ID =
       run.BACKTEST_RUN_ID
WHERE run.BACKTEST_RUN_ID IS NULL
GROUP BY detail.BACKTEST_RUN_ID;


-- ------------------------------------------------------------
-- 5. ACTIVATION SAFETY
--
-- A request cannot be V2 activation-eligible without:
--   * current request readiness READY;
--   * PASS candidate backtest;
--   * current approvals after backtest;
--   * fresh evidence.
--
-- Expected: INVALID_ACTIVATION_ELIGIBLE_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COALESCE(
        COUNT_IF(
            ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
            AND (
                REQUEST_STATUS <> 'APPROVED'
                OR READINESS_STATUS <> 'READY'
                OR BACKTEST_STATUS <> 'PASS'
                OR ALL_CURRENT_APPROVALS_COMPLETE_FLAG
                    = FALSE
                OR EVIDENCE_FRESH_FLAG = FALSE
                OR APPROVALS_AFTER_BACKTEST_FLAG
                    = FALSE
            )
        ),
        0
    )::NUMBER AS INVALID_ACTIVATION_ELIGIBLE_ROWS
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2;


-- ------------------------------------------------------------
-- 6. NEGATIVE PROCEDURE TEST
--
-- This must return status ERROR without writing data.
-- ------------------------------------------------------------

CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_CANDIDATE_BACKTEST_V1(
            'PHASE12A_NEGATIVE_TEST',
            'NONEXISTENT_DEPLOYMENT_REQUEST',
            'PHASE12A_VERIFICATION'
        );


-- ------------------------------------------------------------
-- 7. ACTIVE POLICIES MUST REMAIN UNCHANGED
--
-- Expected:
--   ACTIVE_POLICY_COUNT = 4
--   SHADOW_POLICY_COUNT = 4
--   AUTHORITY_ENABLED_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,

    COUNT_IF(
        DEPLOYMENT_MODE = 'SHADOW'
    ) AS SHADOW_POLICY_COUNT,

    COUNT_IF(
        AUTO_USE_ALLOWED_FLAG = TRUE
        OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
        OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
    ) AS AUTHORITY_ENABLED_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;


-- ------------------------------------------------------------
-- 8. DASHBOARD
-- ------------------------------------------------------------

SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE12A_CANDIDATE_VALIDATION_V1
ORDER BY UPDATED_AT DESC;


-- ------------------------------------------------------------
-- 9. FINAL CLOSURE
-- ------------------------------------------------------------

WITH PROCEDURES AS (
    SELECT
        COUNT(DISTINCT PROCEDURE_NAME)
            AS PROCEDURE_COUNT
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'RECORD_ML_CANDIDATE_PREDICTION_V1',
          'RUN_ML_CANDIDATE_BACKTEST_V1',
          'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
      )
),
PREDICTIONS AS (
    SELECT COUNT(*) AS DUPLICATE_ACTIVE_KEY_COUNT
    FROM (
        SELECT
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,
            SIMULATION_ID
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_PREDICTION_V1
        WHERE IS_ACTIVE = TRUE
        GROUP BY
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,
            SIMULATION_ID
        HAVING COUNT(*) > 1
    )
),
ORPHANS AS (
    SELECT COUNT(*) AS ORPHAN_RUN_COUNT
    FROM (
        SELECT detail.BACKTEST_RUN_ID
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_BACKTEST_DETAIL_V1
                detail
        LEFT JOIN
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_CANDIDATE_BACKTEST_RUN_V1
                run
            ON detail.BACKTEST_RUN_ID =
               run.BACKTEST_RUN_ID
        WHERE run.BACKTEST_RUN_ID IS NULL
        GROUP BY detail.BACKTEST_RUN_ID
    )
),
SAFETY AS (
    SELECT
        COALESCE(
            COUNT_IF(
                ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
                AND (
                    REQUEST_STATUS <> 'APPROVED'
                    OR READINESS_STATUS <> 'READY'
                    OR BACKTEST_STATUS <> 'PASS'
                    OR ALL_CURRENT_APPROVALS_COMPLETE_FLAG
                        = FALSE
                    OR EVIDENCE_FRESH_FLAG = FALSE
                    OR APPROVALS_AFTER_BACKTEST_FLAG
                        = FALSE
                )
            ),
            0
        )::NUMBER AS INVALID_ACTIVATION_ROWS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2
),
POLICIES AS (
    SELECT
        COUNT(*) AS ACTIVE_POLICY_COUNT,

        COUNT_IF(
            DEPLOYMENT_MODE = 'SHADOW'
        ) AS SHADOW_POLICY_COUNT,

        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG = TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
        ) AS AUTHORITY_ENABLED_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            procedures.PROCEDURE_COUNT = 3
            AND predictions
                .DUPLICATE_ACTIVE_KEY_COUNT = 0
            AND orphans.ORPHAN_RUN_COUNT = 0
            AND safety.INVALID_ACTIVATION_ROWS = 0
            AND policies.ACTIVE_POLICY_COUNT = 4
            AND policies.SHADOW_POLICY_COUNT = 4
            AND policies.AUTHORITY_ENABLED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_12A',

    'procedure_count',
        procedures.PROCEDURE_COUNT,

    'duplicate_active_prediction_keys',
        predictions.DUPLICATE_ACTIVE_KEY_COUNT,

    'orphan_backtest_run_count',
        orphans.ORPHAN_RUN_COUNT,

    'invalid_activation_eligible_rows',
        safety.INVALID_ACTIVATION_ROWS,

    'active_policy_count',
        policies.ACTIVE_POLICY_COUNT,

    'shadow_policy_count',
        policies.SHADOW_POLICY_COUNT,

    'authority_enabled_count',
        policies.AUTHORITY_ENABLED_COUNT,

    'candidate_backtest_authority',
        'EVIDENCE_ONLY',

    'activation_entry_point',
        'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',

    'official_cost_changed',
        FALSE,

    'policy_activated',
        FALSE
) AS PHASE12A_RESULT

FROM PROCEDURES procedures
CROSS JOIN PREDICTIONS predictions
CROSS JOIN ORPHANS orphans
CROSS JOIN SAFETY safety
CROSS JOIN POLICIES policies;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- PHASE 12B PRECHECK
SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_CANDIDATE_BACKTEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'SET_ML_DEPLOYMENT_CAPABILITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DECISION_POLICY_V1'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2'),
        ('CORE_ML','VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1')
    AS required(SCHEMA_NAME, OBJECT_NAME)
),
FOUND_OBJECTS AS (
    SELECT
        TABLE_SCHEMA AS SCHEMA_NAME,
        TABLE_NAME AS OBJECT_NAME
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.TABLES
)
SELECT
    required.SCHEMA_NAME,
    required.OBJECT_NAME
FROM REQUIRED_OBJECTS required
LEFT JOIN FOUND_OBJECTS found
    ON required.SCHEMA_NAME = found.SCHEMA_NAME
   AND required.OBJECT_NAME = found.OBJECT_NAME
WHERE found.OBJECT_NAME IS NULL
ORDER BY required.SCHEMA_NAME, required.OBJECT_NAME;

WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','MODEL_DOMAIN'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','TARGET_MODE'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','REQUEST_STATUS'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','EVIDENCE_VERSION'),

        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2','BACKTEST_STATUS'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2','APPROVALS_AFTER_BACKTEST_FLAG'),

        ('CORE_ML','VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1','CAPABILITY_KEY'),
        ('CORE_ML','VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1','READY_FLAG'),

        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','SIMULATION_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','KMAT_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','RFQ_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','SAFETY_GATE_PASS_FLAG'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','COST_ENGINE_CONSUMPTION_ALLOWED_FLAG'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG'),

        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','MODEL_DOMAIN'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_NUMERIC_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_MAPPING_CORRECT_FLAG')
    AS required(SCHEMA_NAME, OBJECT_NAME, COLUMN_NAME)
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

SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE12B_REQUIRED_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',
      'RUN_ML_CANDIDATE_BACKTEST_V1',
      'SET_ML_DEPLOYMENT_CAPABILITY_V1'
  );

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,

    COALESCE(
        COUNT_IF(DEPLOYMENT_MODE = 'SHADOW'),
        0
    )::NUMBER AS SHADOW_POLICY_COUNT,

    COALESCE(
        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG = TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
        ),
        0
    )::NUMBER AS AUTHORITY_ENABLED_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;

-- ============================================================
-- PHASE 12B — CONTROLLED PILOT AND CANARY CONTROL PLANE
--
-- Exact schema:
--   KMAT_COST_MODEL_DB.CORE_ML
--
-- Deployment creates infrastructure only:
--   no pilot plan,
--   no assignment,
--   no policy change,
--   no official cost change.
--
-- OBJECT_AGG calls: 0
-- VARIANT scripting variables in VALUES: 0
-- ============================================================


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 (
        PILOT_PLAN_ID VARCHAR NOT NULL,

        DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,

        MODEL_DOMAIN VARCHAR NOT NULL,
        TARGET_MODE VARCHAR NOT NULL,

        CANDIDATE_POLICY_ID VARCHAR NOT NULL,
        CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,

        CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
        CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
        CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,

        PILOT_STATUS VARCHAR NOT NULL,
        PILOT_STATUS_REASON VARCHAR NOT NULL,

        EXPOSURE_PCT FLOAT NOT NULL,
        MAX_DAILY_ASSIGNMENTS NUMBER NOT NULL,
        MAX_TOTAL_ASSIGNMENTS NUMBER NOT NULL,

        SCOPE_MODE VARCHAR NOT NULL,
        REQUIRE_ENGINEER_APPROVAL_FLAG BOOLEAN NOT NULL,
        AUTO_PAUSE_ON_CRITICAL_FLAG BOOLEAN NOT NULL,

        PILOT_START_AT TIMESTAMP_NTZ NOT NULL,
        PILOT_END_AT TIMESTAMP_NTZ NOT NULL,

        CREATED_BY VARCHAR NOT NULL,
        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

        STARTED_BY VARCHAR,
        STARTED_AT TIMESTAMP_NTZ,

        LAST_STATUS_CHANGED_BY VARCHAR NOT NULL,
        LAST_STATUS_CHANGED_AT TIMESTAMP_NTZ NOT NULL,

        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 (
        PILOT_SCOPE_ID VARCHAR NOT NULL,
        PILOT_PLAN_ID VARCHAR NOT NULL,

        SCOPE_TYPE VARCHAR NOT NULL,
        SCOPE_VALUE VARCHAR NOT NULL,
        SCOPE_ACTION VARCHAR NOT NULL,

        IS_ACTIVE BOOLEAN NOT NULL,

        CREATED_BY VARCHAR NOT NULL,
        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

        UPDATED_BY VARCHAR NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 (
        COUNTER_ID VARCHAR NOT NULL,
        PILOT_PLAN_ID VARCHAR NOT NULL,

        COUNTER_TYPE VARCHAR NOT NULL,
        COUNTER_DATE DATE,

        ASSIGNED_COUNT NUMBER NOT NULL,

        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 (
        ASSIGNMENT_ID VARCHAR NOT NULL,

        PILOT_PLAN_ID VARCHAR NOT NULL,
        DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,

        MODEL_DOMAIN VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR NOT NULL,
        KMAT_ID VARCHAR,
        RFQ_ID VARCHAR,

        CANARY_BUCKET_PCT FLOAT NOT NULL,

        SCOPE_ELIGIBLE_FLAG BOOLEAN NOT NULL,
        HASH_ELIGIBLE_FLAG BOOLEAN NOT NULL,
        SAFETY_ELIGIBLE_FLAG BOOLEAN NOT NULL,
        CAPACITY_RESERVED_FLAG BOOLEAN NOT NULL,

        PILOT_ASSIGNED_FLAG BOOLEAN NOT NULL,
        CONTROLLED_USE_ELIGIBLE_FLAG BOOLEAN NOT NULL,

        ASSIGNMENT_STATUS VARCHAR NOT NULL,
        ASSIGNMENT_REASON VARCHAR NOT NULL,

        REQUESTED_BY VARCHAR NOT NULL,
        ASSIGNED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 (
        PILOT_DECISION_ID VARCHAR NOT NULL,
        ASSIGNMENT_ID VARCHAR NOT NULL,

        PILOT_PLAN_ID VARCHAR NOT NULL,
        DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,

        MODEL_DOMAIN VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR NOT NULL,
        KMAT_ID VARCHAR,
        RFQ_ID VARCHAR,

        RULE_VALUE FLOAT,
        CANDIDATE_VALUE FLOAT NOT NULL,
        FINAL_PILOT_VALUE FLOAT,

        QUALITY_PASS_FLAG BOOLEAN NOT NULL,
        OOD_FLAG BOOLEAN NOT NULL,

        BOUNDS_PASS_FLAG BOOLEAN NOT NULL,
        ABS_DEVIATION_PASS_FLAG BOOLEAN NOT NULL,
        PCT_DEVIATION_PASS_FLAG BOOLEAN NOT NULL,
        OVERALL_GUARDRAIL_PASS_FLAG BOOLEAN NOT NULL,

        ENGINEER_APPROVED_FLAG BOOLEAN NOT NULL,
        ENGINEER_APPROVED_BY VARCHAR,
        ENGINEER_APPROVAL_REFERENCE VARCHAR,

        CONTROLLED_USE_AUTHORIZED_FLAG BOOLEAN NOT NULL,
        FINAL_PILOT_SOURCE VARCHAR NOT NULL,

        BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG BOOLEAN NOT NULL,
        OFFICIAL_COST_CHANGED_FLAG BOOLEAN NOT NULL,

        DECISION_STATUS VARCHAR NOT NULL,
        DECISION_REASON VARCHAR NOT NULL,

        IS_ACTIVE BOOLEAN NOT NULL,

        DECIDED_BY VARCHAR NOT NULL,
        DECIDED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 (
        INCIDENT_ID VARCHAR NOT NULL,
        PILOT_PLAN_ID VARCHAR NOT NULL,

        SIMULATION_ID VARCHAR,

        INCIDENT_CATEGORY VARCHAR NOT NULL,
        INCIDENT_SEVERITY VARCHAR NOT NULL,

        INCIDENT_STATUS VARCHAR NOT NULL,
        INCIDENT_DESCRIPTION VARCHAR NOT NULL,
        EVIDENCE_REFERENCE VARCHAR,

        REPORTED_BY VARCHAR NOT NULL,
        REPORTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

        REVIEWED_BY VARCHAR,
        REVIEWED_AT TIMESTAMP_NTZ,
        RESOLUTION_NOTE VARCHAR,

        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 (
        MONITORING_RUN_ID VARCHAR NOT NULL,
        PILOT_PLAN_ID VARCHAR NOT NULL,

        MODEL_DOMAIN VARCHAR NOT NULL,

        PRIOR_PILOT_STATUS VARCHAR NOT NULL,
        RESULTING_PILOT_STATUS VARCHAR NOT NULL,

        MONITORING_STATUS VARCHAR NOT NULL,
        MONITORING_REASON VARCHAR NOT NULL,

        ASSIGNED_COUNT NUMBER NOT NULL,
        CONTROLLED_DECISION_COUNT NUMBER NOT NULL,
        FALLBACK_DECISION_COUNT NUMBER NOT NULL,

        ACTUAL_OUTCOME_COUNT NUMBER NOT NULL,

        RULE_MAE FLOAT,
        CANDIDATE_MAE FLOAT,
        CANDIDATE_RMSE FLOAT,
        CANDIDATE_ADVANTAGE_VS_RULE FLOAT,

        BMCS_BRIER_SCORE FLOAT,
        BMCS_ACCURACY_PCT FLOAT,

        OPEN_CRITICAL_INCIDENT_COUNT NUMBER NOT NULL,
        UNAUTHORISED_CONTROLLED_USE_COUNT NUMBER NOT NULL,
        GUARDRAIL_VIOLATION_COUNT NUMBER NOT NULL,

        REQUIRED_MIN_OUTCOME_COUNT NUMBER NOT NULL,
        REQUIRED_MAX_ERROR FLOAT NOT NULL,
        REQUIRED_MIN_BMCS_ACCURACY_PCT FLOAT,

        AUTO_PAUSE_TRIGGERED_FLAG BOOLEAN NOT NULL,

        RUN_BY VARCHAR NOT NULL,
        STARTED_AT TIMESTAMP_NTZ NOT NULL,
        COMPLETED_AT TIMESTAMP_NTZ NOT NULL,

        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
        EVENT_ID VARCHAR NOT NULL,
        EVENT_TYPE VARCHAR NOT NULL,

        PILOT_PLAN_ID VARCHAR,
        DEPLOYMENT_REQUEST_ID VARCHAR,
        EVIDENCE_VERSION NUMBER,

        ASSIGNMENT_ID VARCHAR,
        PILOT_DECISION_ID VARCHAR,
        INCIDENT_ID VARCHAR,
        MONITORING_RUN_ID VARCHAR,

        MODEL_DOMAIN VARCHAR,
        SIMULATION_ID VARCHAR,

        EVENT_STATUS VARCHAR NOT NULL,
        EVENT_REASON VARCHAR NOT NULL,

        EVENT_ACTOR VARCHAR NOT NULL,
        EVENT_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_PLAN_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PILOT_PLAN_ID
    ORDER BY UPDATED_AT DESC, CREATED_AT DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_SCOPE_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1
WHERE IS_ACTIVE = TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        PILOT_PLAN_ID,
        SCOPE_TYPE,
        SCOPE_VALUE
    ORDER BY
        UPDATED_AT DESC,
        CREATED_AT DESC,
        PILOT_SCOPE_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        PILOT_PLAN_ID,
        SIMULATION_ID
    ORDER BY
        ASSIGNED_AT DESC,
        ASSIGNMENT_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_DECISION_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
WHERE IS_ACTIVE = TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        PILOT_PLAN_ID,
        SIMULATION_ID
    ORDER BY
        UPDATED_AT DESC,
        DECIDED_AT DESC,
        PILOT_DECISION_ID DESC
) = 1;

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_PILOT_PLAN_V1(
        P_PILOT_PLAN_ID VARCHAR,
        P_DEPLOYMENT_REQUEST_ID VARCHAR,

        P_EXPOSURE_PCT FLOAT,
        P_MAX_DAILY_ASSIGNMENTS NUMBER,
        P_MAX_TOTAL_ASSIGNMENTS NUMBER,

        P_SCOPE_MODE VARCHAR,
        P_REQUIRE_ENGINEER_APPROVAL_FLAG BOOLEAN,
        P_AUTO_PAUSE_ON_CRITICAL_FLAG BOOLEAN,

        P_PILOT_START_AT TIMESTAMP_NTZ,
        P_PILOT_END_AT TIMESTAMP_NTZ,

        P_CREATED_BY VARCHAR,
        P_REASON VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_POLICY_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_CANDIDATE_MODEL_NAME VARCHAR;
    V_CANDIDATE_MODEL_VERSION VARCHAR;
    V_CANDIDATE_FEATURE_SET_VERSION VARCHAR;

    V_ACTIVE_POLICY_ID VARCHAR;
    V_ACTIVE_POLICY_VERSION VARCHAR;
    V_ACTIVE_MODE VARCHAR;

    V_BACKTEST_STATUS VARCHAR;
    V_APPROVALS_AFTER_BACKTEST BOOLEAN;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_PILOT_PLAN_ID is required.''
        );
    END IF;

    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''P_DEPLOYMENT_REQUEST_ID is required.''
        );
    END IF;

    IF (
        P_EXPOSURE_PCT IS NULL
        OR P_EXPOSURE_PCT <= 0.0
        OR P_EXPOSURE_PCT > 25.0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_EXPOSURE_PCT must be greater than 0 and at most 25.''
        );
    END IF;

    IF (
        P_MAX_DAILY_ASSIGNMENTS IS NULL
        OR P_MAX_DAILY_ASSIGNMENTS < 1
        OR P_MAX_TOTAL_ASSIGNMENTS IS NULL
        OR P_MAX_TOTAL_ASSIGNMENTS < 1
        OR P_MAX_DAILY_ASSIGNMENTS
            > P_MAX_TOTAL_ASSIGNMENTS
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Assignment caps must be positive and daily cap cannot exceed total cap.''
        );
    END IF;

    IF (
        P_SCOPE_MODE IS NULL
        OR UPPER(TRIM(P_SCOPE_MODE))
            NOT IN (
                ''ALL_ELIGIBLE'',
                ''EXPLICIT_INCLUDE''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_SCOPE_MODE must be ALL_ELIGIBLE or EXPLICIT_INCLUDE.''
        );
    END IF;

    IF (
        P_REQUIRE_ENGINEER_APPROVAL_FLAG IS NULL
        OR P_AUTO_PAUSE_ON_CRITICAL_FLAG IS NULL
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot approval and auto-pause flags are required.''
        );
    END IF;

    IF (NOT P_REQUIRE_ENGINEER_APPROVAL_FLAG) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Controlled pilot decisions require engineer approval.''
        );
    END IF;

    IF (
        P_PILOT_START_AT IS NULL
        OR P_PILOT_END_AT IS NULL
        OR P_PILOT_END_AT <= P_PILOT_START_AT
        OR DATEDIFF(
            ''day'',
            P_PILOT_START_AT,
            P_PILOT_END_AT
        ) > 30
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot window must be valid and no longer than 30 days.''
        );
    END IF;

    IF (
        P_CREATED_BY IS NULL
        OR LENGTH(TRIM(P_CREATED_BY)) = 0
        OR P_REASON IS NULL
        OR LENGTH(TRIM(P_REASON)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_CREATED_BY and P_REASON are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_PLAN_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
    WHERE PILOT_PLAN_ID = :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''PILOT_PLAN_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(request.MODEL_DOMAIN),
        MAX(request.TARGET_MODE),
        MAX(request.REQUEST_STATUS),
        MAX(request.EVIDENCE_VERSION),

        MAX(request.CANDIDATE_POLICY_ID),
        MAX(request.CANDIDATE_POLICY_VERSION),

        MAX(request.CANDIDATE_MODEL_NAME),
        MAX(request.CANDIDATE_MODEL_VERSION),
        MAX(request.CANDIDATE_FEATURE_SET_VERSION),

        MAX(readiness.BACKTEST_STATUS),
        MAX(readiness.APPROVALS_AFTER_BACKTEST_FLAG)

    INTO
        :V_REQUEST_COUNT,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,

        :V_BACKTEST_STATUS,
        :V_APPROVALS_AFTER_BACKTEST

    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
        request

    LEFT JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_REQUEST_READINESS_V2
        readiness
        ON request.DEPLOYMENT_REQUEST_ID =
           readiness.DEPLOYMENT_REQUEST_ID

    WHERE request.DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one deployment request is required.'',
            ''request_count'', V_REQUEST_COUNT
        );
    END IF;

    IF (
        V_REQUEST_STATUS <> ''ACTIVATED''
        OR V_TARGET_MODE <> ''CONTROLLED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot plan requires an ACTIVATED CONTROLLED deployment request.'',
            ''request_status'', V_REQUEST_STATUS,
            ''target_mode'', V_TARGET_MODE
        );
    END IF;

    IF (
        V_BACKTEST_STATUS <> ''PASS''
        OR NOT COALESCE(
            V_APPROVALS_AFTER_BACKTEST,
            FALSE
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Phase 12A PASS evidence and post-backtest approvals are required.'',
            ''backtest_status'', V_BACKTEST_STATUS,
            ''approvals_after_backtest'',
                V_APPROVALS_AFTER_BACKTEST
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(DEPLOYMENT_MODE)
    INTO
        :V_POLICY_COUNT,
        :V_ACTIVE_POLICY_ID,
        :V_ACTIVE_POLICY_VERSION,
        :V_ACTIVE_MODE
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN;

    IF (
        V_POLICY_COUNT <> 1
        OR V_ACTIVE_POLICY_ID
            <> V_CANDIDATE_POLICY_ID
        OR V_ACTIVE_POLICY_VERSION
            <> V_CANDIDATE_POLICY_VERSION
        OR V_ACTIVE_MODE <> ''CONTROLLED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''The active CONTROLLED policy must exactly match the deployment request candidate.'',
            ''active_policy_id'',
                V_ACTIVE_POLICY_ID,
            ''active_policy_version'',
                V_ACTIVE_POLICY_VERSION,
            ''active_mode'', V_ACTIVE_MODE
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 (
            PILOT_PLAN_ID,

            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            MODEL_DOMAIN,
            TARGET_MODE,

            CANDIDATE_POLICY_ID,
            CANDIDATE_POLICY_VERSION,

            CANDIDATE_MODEL_NAME,
            CANDIDATE_MODEL_VERSION,
            CANDIDATE_FEATURE_SET_VERSION,

            PILOT_STATUS,
            PILOT_STATUS_REASON,

            EXPOSURE_PCT,
            MAX_DAILY_ASSIGNMENTS,
            MAX_TOTAL_ASSIGNMENTS,

            SCOPE_MODE,
            REQUIRE_ENGINEER_APPROVAL_FLAG,
            AUTO_PAUSE_ON_CRITICAL_FLAG,

            PILOT_START_AT,
            PILOT_END_AT,

            CREATED_BY,
            CREATED_AT,

            STARTED_BY,
            STARTED_AT,

            LAST_STATUS_CHANGED_BY,
            LAST_STATUS_CHANGED_AT,

            UPDATED_AT
        )
    SELECT
        TRIM(:P_PILOT_PLAN_ID),

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,

        ''DRAFT'',
        TRIM(:P_REASON),

        :P_EXPOSURE_PCT,
        :P_MAX_DAILY_ASSIGNMENTS,
        :P_MAX_TOTAL_ASSIGNMENTS,

        UPPER(TRIM(:P_SCOPE_MODE)),
        :P_REQUIRE_ENGINEER_APPROVAL_FLAG,
        :P_AUTO_PAUSE_ON_CRITICAL_FLAG,

        :P_PILOT_START_AT,
        :P_PILOT_END_AT,

        TRIM(:P_CREATED_BY),
        CURRENT_TIMESTAMP(),

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,

        TRIM(:P_CREATED_BY),
        CURRENT_TIMESTAMP(),

        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot plan insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_PLAN_CREATED'',

        TRIM(:P_PILOT_PLAN_ID),
        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        ''DRAFT'',
        TRIM(:P_REASON),

        TRIM(:P_CREATED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''pilot_plan_id'', P_PILOT_PLAN_ID,
        ''deployment_request_id'',
            P_DEPLOYMENT_REQUEST_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''pilot_status'', ''DRAFT'',

        ''exposure_pct'', P_EXPOSURE_PCT,
        ''max_daily_assignments'',
            P_MAX_DAILY_ASSIGNMENTS,
        ''max_total_assignments'',
            P_MAX_TOTAL_ASSIGNMENTS,

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.UPSERT_ML_PILOT_SCOPE_V1(
        P_PILOT_SCOPE_ID VARCHAR,
        P_PILOT_PLAN_ID VARCHAR,

        P_SCOPE_TYPE VARCHAR,
        P_SCOPE_VALUE VARCHAR,
        P_SCOPE_ACTION VARCHAR,

        P_IS_ACTIVE BOOLEAN,
        P_CHANGED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_PILOT_STATUS VARCHAR;
    V_MODEL_DOMAIN VARCHAR;
    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_EVENT_ID VARCHAR;
    V_MERGED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PILOT_SCOPE_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_SCOPE_ID)) = 0
        OR P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_PILOT_SCOPE_ID and P_PILOT_PLAN_ID are required.''
        );
    END IF;

    IF (
        P_SCOPE_TYPE IS NULL
        OR UPPER(TRIM(P_SCOPE_TYPE))
            NOT IN (
                ''SIMULATION_ID'',
                ''KMAT_ID'',
                ''RFQ_ID''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_SCOPE_TYPE must be SIMULATION_ID, KMAT_ID, or RFQ_ID.''
        );
    END IF;

    IF (
        P_SCOPE_VALUE IS NULL
        OR LENGTH(TRIM(P_SCOPE_VALUE)) = 0
        OR P_SCOPE_ACTION IS NULL
        OR UPPER(TRIM(P_SCOPE_ACTION))
            NOT IN (
                ''INCLUDE'',
                ''EXCLUDE''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''A scope value and INCLUDE or EXCLUDE action are required.''
        );
    END IF;

    IF (
        P_IS_ACTIVE IS NULL
        OR P_CHANGED_BY IS NULL
        OR LENGTH(TRIM(P_CHANGED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_IS_ACTIVE and P_CHANGED_BY are required.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_STATUS),
        MAX(MODEL_DOMAIN),
        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION)
    INTO
        :V_PLAN_COUNT,
        :V_PILOT_STATUS,
        :V_MODEL_DOMAIN,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1
    WHERE PILOT_PLAN_ID = :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one pilot plan is required.''
        );
    END IF;

    IF (
        V_PILOT_STATUS NOT IN (
            ''DRAFT'',
            ''PAUSED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot scope can be changed only while DRAFT or PAUSED.'',
            ''pilot_status'', V_PILOT_STATUS
        );
    END IF;

    MERGE INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 target

    USING (
        SELECT
            TRIM(:P_PILOT_SCOPE_ID)
                AS PILOT_SCOPE_ID
    ) source

    ON target.PILOT_SCOPE_ID =
       source.PILOT_SCOPE_ID

    WHEN MATCHED THEN UPDATE SET
        PILOT_PLAN_ID =
            TRIM(:P_PILOT_PLAN_ID),

        SCOPE_TYPE =
            UPPER(TRIM(:P_SCOPE_TYPE)),
        SCOPE_VALUE =
            TRIM(:P_SCOPE_VALUE),
        SCOPE_ACTION =
            UPPER(TRIM(:P_SCOPE_ACTION)),

        IS_ACTIVE =
            :P_IS_ACTIVE,

        UPDATED_BY =
            TRIM(:P_CHANGED_BY),
        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        PILOT_SCOPE_ID,
        PILOT_PLAN_ID,

        SCOPE_TYPE,
        SCOPE_VALUE,
        SCOPE_ACTION,

        IS_ACTIVE,

        CREATED_BY,
        CREATED_AT,

        UPDATED_BY,
        UPDATED_AT
    )
    VALUES (
        TRIM(:P_PILOT_SCOPE_ID),
        TRIM(:P_PILOT_PLAN_ID),

        UPPER(TRIM(:P_SCOPE_TYPE)),
        TRIM(:P_SCOPE_VALUE),
        UPPER(TRIM(:P_SCOPE_ACTION)),

        :P_IS_ACTIVE,

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP(),

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP()
    );

    V_MERGED_ROWS := SQLROWCOUNT;

    IF (V_MERGED_ROWS <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Scope MERGE did not affect exactly one row.'',
            ''affected_rows'', V_MERGED_ROWS
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_SCOPE_CHANGED'',

        TRIM(:P_PILOT_PLAN_ID),
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        IFF(
            :P_IS_ACTIVE,
            ''ACTIVE'',
            ''INACTIVE''
        ),

        UPPER(TRIM(:P_SCOPE_ACTION))
        || '' ''
        || UPPER(TRIM(:P_SCOPE_TYPE))
        || '' ''
        || TRIM(:P_SCOPE_VALUE),

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''pilot_scope_id'', P_PILOT_SCOPE_ID,
        ''pilot_plan_id'', P_PILOT_PLAN_ID,

        ''scope_type'',
            UPPER(TRIM(P_SCOPE_TYPE)),
        ''scope_value'', P_SCOPE_VALUE,
        ''scope_action'',
            UPPER(TRIM(P_SCOPE_ACTION)),
        ''is_active'', P_IS_ACTIVE,

        ''event_id'', V_EVENT_ID
    );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.START_ML_PILOT_V1(
        P_PILOT_PLAN_ID VARCHAR,
        P_STARTED_BY VARCHAR,
        P_CONFIRMATION_PHRASE VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_DOMAIN_PILOT_COUNT NUMBER DEFAULT 0;
    V_INCLUDE_SCOPE_COUNT NUMBER DEFAULT 0;
    V_CAPABILITY_COUNT NUMBER DEFAULT 0;

    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_REQUEST_STATUS VARCHAR;
    V_ACTIVE_POLICY_MATCH_COUNT NUMBER DEFAULT 0;

    V_PILOT_STATUS VARCHAR;
    V_SCOPE_MODE VARCHAR;
    V_START_AT TIMESTAMP_NTZ;
    V_END_AT TIMESTAMP_NTZ;

    V_CAPABILITY_KEY VARCHAR;
    V_CAPABILITY_READY BOOLEAN;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;

    V_COUNTER_ROWS NUMBER DEFAULT 0;
    V_PLAN_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
        OR P_STARTED_BY IS NULL
        OR LENGTH(TRIM(P_STARTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_PILOT_PLAN_ID and P_STARTED_BY are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> ''START_PILOT::''
               || P_PILOT_PLAN_ID
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Confirmation must equal START_PILOT::<PILOT_PLAN_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),

        MAX(PILOT_STATUS),
        MAX(SCOPE_MODE),
        MAX(PILOT_START_AT),
        MAX(PILOT_END_AT)

    INTO
        :V_PLAN_COUNT,

        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_PILOT_STATUS,
        :V_SCOPE_MODE,
        :V_START_AT,
        :V_END_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    SELECT MAX(REQUEST_STATUS)
    INTO :V_REQUEST_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :V_REQUEST_ID;

    SELECT COUNT(*)
    INTO :V_ACTIVE_POLICY_MATCH_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_ID =
          :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          ''CONTROLLED'';

    IF (
        V_REQUEST_STATUS <> ''ACTIVATED''
        OR V_ACTIVE_POLICY_MATCH_COUNT <> 1
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''The activated request and exact CONTROLLED policy must still match before pilot start.'',
            ''request_status'', V_REQUEST_STATUS,
            ''active_policy_match_count'',
                V_ACTIVE_POLICY_MATCH_COUNT
        );
    END IF;

    IF (V_PILOT_STATUS <> ''DRAFT'') THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Only a DRAFT pilot can be started.'',
            ''pilot_status'', V_PILOT_STATUS
        );
    END IF;

    IF (
        CURRENT_TIMESTAMP() < V_START_AT
        OR CURRENT_TIMESTAMP() >= V_END_AT
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Current time must be inside the configured pilot window.''
        );
    END IF;

    SELECT
        COALESCE(
            COUNT_IF(
                PILOT_STATUS = ''ACTIVE''
                AND MODEL_DOMAIN =
                    :V_MODEL_DOMAIN
            ),
            0
        )::NUMBER
    INTO :V_ACTIVE_DOMAIN_PILOT_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1;

    IF (V_ACTIVE_DOMAIN_PILOT_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Another ACTIVE pilot already exists for this model domain.''
        );
    END IF;

    IF (V_SCOPE_MODE = ''EXPLICIT_INCLUDE'') THEN
        SELECT
            COALESCE(
                COUNT_IF(
                    SCOPE_ACTION = ''INCLUDE''
                ),
                0
            )::NUMBER
        INTO :V_INCLUDE_SCOPE_COUNT
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_PILOT_SCOPE_CURRENT_V1
        WHERE PILOT_PLAN_ID =
              :P_PILOT_PLAN_ID;

        IF (V_INCLUDE_SCOPE_COUNT = 0) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''EXPLICIT_INCLUDE requires at least one active INCLUDE scope row.''
            );
        END IF;
    END IF;

    V_CAPABILITY_KEY :=
        IFF(
            V_MODEL_DOMAIN = ''BMCS'',
            ''BMCS_BUSINESS_GATE_READY_FLAG'',
            ''GOVERNED_COST_RECALCULATION_READY_FLAG''
        );

    SELECT
        COUNT(*),
        MAX(READY_FLAG)
    INTO
        :V_CAPABILITY_COUNT,
        :V_CAPABILITY_READY
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND CAPABILITY_KEY =
          :V_CAPABILITY_KEY;

    IF (
        V_CAPABILITY_COUNT <> 1
        OR NOT COALESCE(
            V_CAPABILITY_READY,
            FALSE
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''The required deployment capability is not READY.'',
            ''capability_key'', V_CAPABILITY_KEY,
            ''capability_ready'',
                V_CAPABILITY_READY
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_CAPACITY_COUNTER_V1 (
                COUNTER_ID,
                PILOT_PLAN_ID,

                COUNTER_TYPE,
                COUNTER_DATE,

                ASSIGNED_COUNT,

                CREATED_AT,
                UPDATED_AT
            )
    SELECT
        TRIM(:P_PILOT_PLAN_ID)
        || ''::TOTAL'',

        TRIM(:P_PILOT_PLAN_ID),

        ''TOTAL'',
        NULL::DATE,

        0,

        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()

    WHERE NOT EXISTS (
        SELECT 1
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_CAPACITY_COUNTER_V1
        WHERE COUNTER_ID =
              TRIM(:P_PILOT_PLAN_ID)
              || ''::TOTAL''
    );

    V_COUNTER_ROWS := SQLROWCOUNT;

    IF (V_COUNTER_ROWS NOT IN (0, 1)) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Unexpected total-counter insert count.'',
            ''inserted_rows'', V_COUNTER_ROWS
        );
    END IF;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
    SET
        PILOT_STATUS = ''ACTIVE'',
        PILOT_STATUS_REASON =
            ''Pilot started after capability and scope validation.'',

        STARTED_BY = TRIM(:P_STARTED_BY),
        STARTED_AT = CURRENT_TIMESTAMP(),

        LAST_STATUS_CHANGED_BY =
            TRIM(:P_STARTED_BY),
        LAST_STATUS_CHANGED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT = CURRENT_TIMESTAMP()

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID
      AND PILOT_STATUS = ''DRAFT'';

    V_PLAN_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_PLAN_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot start did not update exactly one DRAFT plan.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_STARTED'',

        TRIM(:P_PILOT_PLAN_ID),
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        ''ACTIVE'',
        ''Capability, scope, window and policy checks passed.'',

        TRIM(:P_STARTED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''pilot_plan_id'', P_PILOT_PLAN_ID,
        ''pilot_status'', ''ACTIVE'',

        ''model_domain'', V_MODEL_DOMAIN,
        ''capability_key'', V_CAPABILITY_KEY,
        ''capability_ready'', V_CAPABILITY_READY,

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_PILOT_ASSIGNMENT_V1(
        P_ASSIGNMENT_ID VARCHAR,
        P_PILOT_PLAN_ID VARCHAR,
        P_SIMULATION_ID VARCHAR,
        P_REQUESTED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_SIMULATION_COUNT NUMBER DEFAULT 0;

    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_REQUEST_STATUS VARCHAR;
    V_ACTIVE_POLICY_MATCH_COUNT NUMBER DEFAULT 0;

    V_PILOT_STATUS VARCHAR;
    V_SCOPE_MODE VARCHAR;

    V_EXPOSURE_PCT FLOAT;
    V_MAX_DAILY NUMBER;
    V_MAX_TOTAL NUMBER;

    V_START_AT TIMESTAMP_NTZ;
    V_END_AT TIMESTAMP_NTZ;

    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;

    V_SAFETY_PASS BOOLEAN;
    V_CONSUMPTION_ALLOWED BOOLEAN;
    V_RECALC_REQUIRED BOOLEAN;

    V_INCLUDE_MATCH_COUNT NUMBER DEFAULT 0;
    V_EXCLUDE_MATCH_COUNT NUMBER DEFAULT 0;

    V_SCOPE_ELIGIBLE BOOLEAN DEFAULT FALSE;
    V_HASH_ELIGIBLE BOOLEAN DEFAULT FALSE;
    V_SAFETY_ELIGIBLE BOOLEAN DEFAULT FALSE;

    V_BUCKET FLOAT;

    V_TOTAL_RESERVED_ROWS NUMBER DEFAULT 0;
    V_DAILY_RESERVED_ROWS NUMBER DEFAULT 0;
    V_DAILY_COUNTER_ROWS NUMBER DEFAULT 0;

    V_ASSIGNED BOOLEAN DEFAULT FALSE;
    V_CAPACITY_RESERVED BOOLEAN DEFAULT FALSE;

    V_ASSIGNMENT_STATUS VARCHAR;
    V_ASSIGNMENT_REASON VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_ASSIGNMENT_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_ASSIGNMENT_ID IS NULL
        OR LENGTH(TRIM(P_ASSIGNMENT_ID)) = 0
        OR P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
        OR P_SIMULATION_ID IS NULL
        OR LENGTH(TRIM(P_SIMULATION_ID)) = 0
        OR P_REQUESTED_BY IS NULL
        OR LENGTH(TRIM(P_REQUESTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Assignment ID, pilot plan, simulation and requester are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID
      AND SIMULATION_ID =
          :P_SIMULATION_ID;

    IF (V_EXISTING_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_12B'',

                ''assignment_id'', ASSIGNMENT_ID,
                ''pilot_plan_id'', PILOT_PLAN_ID,
                ''simulation_id'', SIMULATION_ID,

                ''canary_bucket_pct'',
                    CANARY_BUCKET_PCT,

                ''pilot_assigned'',
                    PILOT_ASSIGNED_FLAG,

                ''controlled_use_eligible'',
                    CONTROLLED_USE_ELIGIBLE_FLAG,

                ''assignment_status'',
                    ASSIGNMENT_STATUS,

                ''assignment_reason'',
                    ASSIGNMENT_REASON
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
            WHERE PILOT_PLAN_ID =
                  :P_PILOT_PLAN_ID
              AND SIMULATION_ID =
                  :P_SIMULATION_ID
        );
    END IF;

    IF (V_EXISTING_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Current assignment key is not unique.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),

        MAX(PILOT_STATUS),
        MAX(SCOPE_MODE),

        MAX(EXPOSURE_PCT),
        MAX(MAX_DAILY_ASSIGNMENTS),
        MAX(MAX_TOTAL_ASSIGNMENTS),

        MAX(PILOT_START_AT),
        MAX(PILOT_END_AT)

    INTO
        :V_PLAN_COUNT,

        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION,

        :V_PILOT_STATUS,
        :V_SCOPE_MODE,

        :V_EXPOSURE_PCT,
        :V_MAX_DAILY,
        :V_MAX_TOTAL,

        :V_START_AT,
        :V_END_AT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    SELECT MAX(REQUEST_STATUS)
    INTO :V_REQUEST_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :V_REQUEST_ID;

    SELECT COUNT(*)
    INTO :V_ACTIVE_POLICY_MATCH_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_ID =
          :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          ''CONTROLLED'';

    SELECT
        COUNT(*),
        MAX(KMAT_ID),
        MAX(RFQ_ID),

        MAX(SAFETY_GATE_PASS_FLAG),
        MAX(COST_ENGINE_CONSUMPTION_ALLOWED_FLAG),
        MAX(OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG)

    INTO
        :V_SIMULATION_COUNT,
        :V_KMAT_ID,
        :V_RFQ_ID,

        :V_SAFETY_PASS,
        :V_CONSUMPTION_ALLOWED,
        :V_RECALC_REQUIRED

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1

    WHERE SIMULATION_ID =
          :P_SIMULATION_ID;

    IF (V_SIMULATION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one governed simulation hierarchy row is required.''
        );
    END IF;

    SELECT
        ABS(
            MOD(
                HASH(
                    :P_PILOT_PLAN_ID,
                    :P_SIMULATION_ID,
                    :V_MODEL_DOMAIN
                ),
                10000
            )
        ) / 100.0
    INTO :V_BUCKET;

    SELECT
        COALESCE(
            COUNT_IF(
                SCOPE_ACTION = ''INCLUDE''
                AND (
                    (
                        SCOPE_TYPE = ''SIMULATION_ID''
                        AND SCOPE_VALUE =
                            :P_SIMULATION_ID
                    )
                    OR
                    (
                        SCOPE_TYPE = ''KMAT_ID''
                        AND SCOPE_VALUE =
                            :V_KMAT_ID
                    )
                    OR
                    (
                        SCOPE_TYPE = ''RFQ_ID''
                        AND SCOPE_VALUE =
                            :V_RFQ_ID
                    )
                )
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                SCOPE_ACTION = ''EXCLUDE''
                AND (
                    (
                        SCOPE_TYPE = ''SIMULATION_ID''
                        AND SCOPE_VALUE =
                            :P_SIMULATION_ID
                    )
                    OR
                    (
                        SCOPE_TYPE = ''KMAT_ID''
                        AND SCOPE_VALUE =
                            :V_KMAT_ID
                    )
                    OR
                    (
                        SCOPE_TYPE = ''RFQ_ID''
                        AND SCOPE_VALUE =
                            :V_RFQ_ID
                    )
                )
            ),
            0
        )::NUMBER

    INTO
        :V_INCLUDE_MATCH_COUNT,
        :V_EXCLUDE_MATCH_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_SCOPE_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    V_SCOPE_ELIGIBLE :=
        V_EXCLUDE_MATCH_COUNT = 0
        AND (
            V_SCOPE_MODE = ''ALL_ELIGIBLE''
            OR V_INCLUDE_MATCH_COUNT > 0
        );

    V_HASH_ELIGIBLE :=
        V_BUCKET < V_EXPOSURE_PCT;

    V_SAFETY_ELIGIBLE :=
        V_REQUEST_STATUS = ''ACTIVATED''
        AND V_ACTIVE_POLICY_MATCH_COUNT = 1
        AND COALESCE(
            V_SAFETY_PASS,
            FALSE
        )
        AND COALESCE(
            V_CONSUMPTION_ALLOWED,
            FALSE
        )
        AND NOT COALESCE(
            V_RECALC_REQUIRED,
            TRUE
        );

    IF (V_PILOT_STATUS <> ''ACTIVE'') THEN
        V_ASSIGNMENT_STATUS :=
            ''NOT_ASSIGNED'';
        V_ASSIGNMENT_REASON :=
            ''Pilot plan is not ACTIVE.'';

    ELSEIF (
        CURRENT_TIMESTAMP() < V_START_AT
        OR CURRENT_TIMESTAMP() >= V_END_AT
    ) THEN
        V_ASSIGNMENT_STATUS :=
            ''NOT_ASSIGNED'';
        V_ASSIGNMENT_REASON :=
            ''Current time is outside the pilot window.'';

    ELSEIF (NOT V_SCOPE_ELIGIBLE) THEN
        V_ASSIGNMENT_STATUS :=
            ''NOT_ASSIGNED'';
        V_ASSIGNMENT_REASON :=
            ''Simulation is outside the pilot scope.'';

    ELSEIF (NOT V_HASH_ELIGIBLE) THEN
        V_ASSIGNMENT_STATUS :=
            ''NOT_ASSIGNED'';
        V_ASSIGNMENT_REASON :=
            ''Deterministic canary bucket is outside exposure percentage.'';

    ELSEIF (NOT V_SAFETY_ELIGIBLE) THEN
        V_ASSIGNMENT_STATUS :=
            ''NOT_ASSIGNED'';
        V_ASSIGNMENT_REASON :=
            ''Simulation failed the governed safety or consumption gate.'';

    ELSE
        BEGIN TRANSACTION;
        V_TRANSACTION_STARTED := TRUE;

        MERGE INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_CAPACITY_COUNTER_V1 target

        USING (
            SELECT
                TRIM(:P_PILOT_PLAN_ID)
                || ''::DAILY::''
                || CURRENT_DATE()::VARCHAR
                    AS COUNTER_ID
        ) source

        ON target.COUNTER_ID =
           source.COUNTER_ID

        WHEN NOT MATCHED THEN INSERT (
            COUNTER_ID,
            PILOT_PLAN_ID,

            COUNTER_TYPE,
            COUNTER_DATE,

            ASSIGNED_COUNT,

            CREATED_AT,
            UPDATED_AT
        )
        VALUES (
            source.COUNTER_ID,
            TRIM(:P_PILOT_PLAN_ID),

            ''DAILY'',
            CURRENT_DATE(),

            0,

            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );

        V_DAILY_COUNTER_ROWS := SQLROWCOUNT;

        IF (V_DAILY_COUNTER_ROWS NOT IN (0, 1)) THEN
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Unexpected daily-counter MERGE row count.'',
                ''affected_rows'',
                    V_DAILY_COUNTER_ROWS
            );
        END IF;

        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_CAPACITY_COUNTER_V1
        SET
            ASSIGNED_COUNT =
                ASSIGNED_COUNT + 1,
            UPDATED_AT =
                CURRENT_TIMESTAMP()
        WHERE COUNTER_ID =
              TRIM(:P_PILOT_PLAN_ID)
              || ''::TOTAL''
          AND ASSIGNED_COUNT <
              :V_MAX_TOTAL;

        V_TOTAL_RESERVED_ROWS := SQLROWCOUNT;

        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_CAPACITY_COUNTER_V1
        SET
            ASSIGNED_COUNT =
                ASSIGNED_COUNT + 1,
            UPDATED_AT =
                CURRENT_TIMESTAMP()
        WHERE COUNTER_ID =
              TRIM(:P_PILOT_PLAN_ID)
              || ''::DAILY::''
              || CURRENT_DATE()::VARCHAR
          AND ASSIGNED_COUNT <
              :V_MAX_DAILY;

        V_DAILY_RESERVED_ROWS := SQLROWCOUNT;

        IF (
            V_TOTAL_RESERVED_ROWS = 1
            AND V_DAILY_RESERVED_ROWS = 1
        ) THEN
            V_CAPACITY_RESERVED := TRUE;
            V_ASSIGNED := TRUE;

            V_ASSIGNMENT_STATUS :=
                ''ASSIGNED'';
            V_ASSIGNMENT_REASON :=
                ''Scope, hash, safety and capacity checks passed.'';

        ELSE
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            V_CAPACITY_RESERVED := FALSE;
            V_ASSIGNED := FALSE;

            V_ASSIGNMENT_STATUS :=
                ''NOT_ASSIGNED'';
            V_ASSIGNMENT_REASON :=
                ''Pilot daily or total capacity is exhausted.'';
        END IF;
    END IF;

    V_EVENT_ID := UUID_STRING();

    IF (V_ASSIGNED) THEN
        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_ASSIGNMENT_V1 (
                    ASSIGNMENT_ID,

                    PILOT_PLAN_ID,
                    DEPLOYMENT_REQUEST_ID,
                    EVIDENCE_VERSION,

                    MODEL_DOMAIN,

                    SIMULATION_ID,
                    KMAT_ID,
                    RFQ_ID,

                    CANARY_BUCKET_PCT,

                    SCOPE_ELIGIBLE_FLAG,
                    HASH_ELIGIBLE_FLAG,
                    SAFETY_ELIGIBLE_FLAG,
                    CAPACITY_RESERVED_FLAG,

                    PILOT_ASSIGNED_FLAG,
                    CONTROLLED_USE_ELIGIBLE_FLAG,

                    ASSIGNMENT_STATUS,
                    ASSIGNMENT_REASON,

                    REQUESTED_BY,
                    ASSIGNED_AT
                )
        SELECT
            TRIM(:P_ASSIGNMENT_ID),

            TRIM(:P_PILOT_PLAN_ID),
            :V_REQUEST_ID,
            :V_EVIDENCE_VERSION,

            :V_MODEL_DOMAIN,

            TRIM(:P_SIMULATION_ID),
            :V_KMAT_ID,
            :V_RFQ_ID,

            :V_BUCKET,

            :V_SCOPE_ELIGIBLE,
            :V_HASH_ELIGIBLE,
            :V_SAFETY_ELIGIBLE,
            :V_CAPACITY_RESERVED,

            TRUE,
            TRUE,

            :V_ASSIGNMENT_STATUS,
            :V_ASSIGNMENT_REASON,

            TRIM(:P_REQUESTED_BY),
            CURRENT_TIMESTAMP();

        V_ASSIGNMENT_INSERTED_ROWS := SQLROWCOUNT;

        IF (V_ASSIGNMENT_INSERTED_ROWS <> 1) THEN
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Assigned record insert did not affect exactly one row.''
            );
        END IF;

        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_EVENT_AUDIT_V1 (
                    EVENT_ID,
                    EVENT_TYPE,

                    PILOT_PLAN_ID,
                    DEPLOYMENT_REQUEST_ID,
                    EVIDENCE_VERSION,

                    ASSIGNMENT_ID,
                    PILOT_DECISION_ID,
                    INCIDENT_ID,
                    MONITORING_RUN_ID,

                    MODEL_DOMAIN,
                    SIMULATION_ID,

                    EVENT_STATUS,
                    EVENT_REASON,

                    EVENT_ACTOR,
                    EVENT_AT
                )
        SELECT
            :V_EVENT_ID,
            ''PILOT_ASSIGNMENT_RESOLVED'',

            TRIM(:P_PILOT_PLAN_ID),
            :V_REQUEST_ID,
            :V_EVIDENCE_VERSION,

            TRIM(:P_ASSIGNMENT_ID),
            NULL::VARCHAR,
            NULL::VARCHAR,
            NULL::VARCHAR,

            :V_MODEL_DOMAIN,
            TRIM(:P_SIMULATION_ID),

            :V_ASSIGNMENT_STATUS,
            :V_ASSIGNMENT_REASON,

            TRIM(:P_REQUESTED_BY),
            CURRENT_TIMESTAMP();

        COMMIT;
        V_TRANSACTION_STARTED := FALSE;

    ELSE
        BEGIN TRANSACTION;
        V_TRANSACTION_STARTED := TRUE;

        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_ASSIGNMENT_V1 (
                    ASSIGNMENT_ID,

                    PILOT_PLAN_ID,
                    DEPLOYMENT_REQUEST_ID,
                    EVIDENCE_VERSION,

                    MODEL_DOMAIN,

                    SIMULATION_ID,
                    KMAT_ID,
                    RFQ_ID,

                    CANARY_BUCKET_PCT,

                    SCOPE_ELIGIBLE_FLAG,
                    HASH_ELIGIBLE_FLAG,
                    SAFETY_ELIGIBLE_FLAG,
                    CAPACITY_RESERVED_FLAG,

                    PILOT_ASSIGNED_FLAG,
                    CONTROLLED_USE_ELIGIBLE_FLAG,

                    ASSIGNMENT_STATUS,
                    ASSIGNMENT_REASON,

                    REQUESTED_BY,
                    ASSIGNED_AT
                )
        SELECT
            TRIM(:P_ASSIGNMENT_ID),

            TRIM(:P_PILOT_PLAN_ID),
            :V_REQUEST_ID,
            :V_EVIDENCE_VERSION,

            :V_MODEL_DOMAIN,

            TRIM(:P_SIMULATION_ID),
            :V_KMAT_ID,
            :V_RFQ_ID,

            :V_BUCKET,

            :V_SCOPE_ELIGIBLE,
            :V_HASH_ELIGIBLE,
            :V_SAFETY_ELIGIBLE,
            FALSE,

            FALSE,
            FALSE,

            :V_ASSIGNMENT_STATUS,
            :V_ASSIGNMENT_REASON,

            TRIM(:P_REQUESTED_BY),
            CURRENT_TIMESTAMP();

        V_ASSIGNMENT_INSERTED_ROWS := SQLROWCOUNT;

        IF (V_ASSIGNMENT_INSERTED_ROWS <> 1) THEN
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Non-assigned record insert did not affect exactly one row.''
            );
        END IF;

        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_EVENT_AUDIT_V1 (
                    EVENT_ID,
                    EVENT_TYPE,

                    PILOT_PLAN_ID,
                    DEPLOYMENT_REQUEST_ID,
                    EVIDENCE_VERSION,

                    ASSIGNMENT_ID,
                    PILOT_DECISION_ID,
                    INCIDENT_ID,
                    MONITORING_RUN_ID,

                    MODEL_DOMAIN,
                    SIMULATION_ID,

                    EVENT_STATUS,
                    EVENT_REASON,

                    EVENT_ACTOR,
                    EVENT_AT
                )
        SELECT
            :V_EVENT_ID,
            ''PILOT_ASSIGNMENT_RESOLVED'',

            TRIM(:P_PILOT_PLAN_ID),
            :V_REQUEST_ID,
            :V_EVIDENCE_VERSION,

            TRIM(:P_ASSIGNMENT_ID),
            NULL::VARCHAR,
            NULL::VARCHAR,
            NULL::VARCHAR,

            :V_MODEL_DOMAIN,
            TRIM(:P_SIMULATION_ID),

            :V_ASSIGNMENT_STATUS,
            :V_ASSIGNMENT_REASON,

            TRIM(:P_REQUESTED_BY),
            CURRENT_TIMESTAMP();

        COMMIT;
        V_TRANSACTION_STARTED := FALSE;
    END IF;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_12B'',

        ''assignment_id'', P_ASSIGNMENT_ID,
        ''pilot_plan_id'', P_PILOT_PLAN_ID,
        ''simulation_id'', P_SIMULATION_ID,

        ''canary_bucket_pct'', V_BUCKET,
        ''exposure_pct'', V_EXPOSURE_PCT,

        ''scope_eligible'', V_SCOPE_ELIGIBLE,
        ''hash_eligible'', V_HASH_ELIGIBLE,
        ''safety_eligible'', V_SAFETY_ELIGIBLE,
        ''capacity_reserved'',
            V_CAPACITY_RESERVED,

        ''pilot_assigned'', V_ASSIGNED,
        ''controlled_use_eligible'',
            V_ASSIGNED,

        ''assignment_status'',
            V_ASSIGNMENT_STATUS,
        ''assignment_reason'',
            V_ASSIGNMENT_REASON,

        ''official_cost_changed'', FALSE,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_PILOT_DECISION_V1(
        P_PILOT_DECISION_ID VARCHAR,
        P_ASSIGNMENT_ID VARCHAR,

        P_RULE_VALUE FLOAT,
        P_CANDIDATE_VALUE FLOAT,

        P_QUALITY_PASS_FLAG BOOLEAN,
        P_OOD_FLAG BOOLEAN,

        P_ENGINEER_APPROVED_FLAG BOOLEAN,
        P_ENGINEER_APPROVED_BY VARCHAR,
        P_ENGINEER_APPROVAL_REFERENCE VARCHAR,

        P_DECIDED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ASSIGNMENT_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_POLICY_COUNT NUMBER DEFAULT 0;
    V_CAPABILITY_COUNT NUMBER DEFAULT 0;
    V_EXISTING_DECISION_ID_COUNT NUMBER DEFAULT 0;

    V_PLAN_ID VARCHAR;
    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_SIMULATION_ID VARCHAR;
    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;

    V_ASSIGNED BOOLEAN;
    V_CONTROLLED_ELIGIBLE BOOLEAN;

    V_PILOT_STATUS VARCHAR;
    V_REQUIRE_ENGINEER_APPROVAL BOOLEAN;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_FINAL_MIN FLOAT;
    V_FINAL_MAX FLOAT;
    V_MAX_ABS_DEVIATION FLOAT;
    V_MAX_PCT_DEVIATION FLOAT;

    V_CAPABILITY_KEY VARCHAR;
    V_CAPABILITY_READY BOOLEAN;

    V_BOUNDS_PASS BOOLEAN;
    V_ABS_PASS BOOLEAN;
    V_PCT_PASS BOOLEAN;
    V_GUARDRAIL_PASS BOOLEAN;

    V_AUTHORISED BOOLEAN;
    V_FINAL_VALUE FLOAT;
    V_FINAL_SOURCE VARCHAR;
    V_DECISION_STATUS VARCHAR;
    V_DECISION_REASON VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PILOT_DECISION_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_DECISION_ID)) = 0
        OR P_ASSIGNMENT_ID IS NULL
        OR LENGTH(TRIM(P_ASSIGNMENT_ID)) = 0
        OR P_CANDIDATE_VALUE IS NULL
        OR P_QUALITY_PASS_FLAG IS NULL
        OR P_OOD_FLAG IS NULL
        OR P_ENGINEER_APPROVED_FLAG IS NULL
        OR P_DECIDED_BY IS NULL
        OR LENGTH(TRIM(P_DECIDED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Decision ID, assignment, candidate value, flags and actor are required.''
        );
    END IF;

    IF (
        P_ENGINEER_APPROVED_FLAG
        AND (
            P_ENGINEER_APPROVED_BY IS NULL
            OR LENGTH(TRIM(P_ENGINEER_APPROVED_BY)) = 0
            OR P_ENGINEER_APPROVAL_REFERENCE IS NULL
            OR LENGTH(TRIM(P_ENGINEER_APPROVAL_REFERENCE)) = 0
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Approved decisions require approver and approval reference.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_DECISION_ID_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
    WHERE PILOT_DECISION_ID =
          :P_PILOT_DECISION_ID;

    IF (V_EXISTING_DECISION_ID_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''PILOT_DECISION_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(PILOT_PLAN_ID),
        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN),

        MAX(SIMULATION_ID),
        MAX(KMAT_ID),
        MAX(RFQ_ID),

        MAX(PILOT_ASSIGNED_FLAG),
        MAX(CONTROLLED_USE_ELIGIBLE_FLAG)

    INTO
        :V_ASSIGNMENT_COUNT,

        :V_PLAN_ID,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN,

        :V_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,

        :V_ASSIGNED,
        :V_CONTROLLED_ELIGIBLE

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1

    WHERE ASSIGNMENT_ID =
          :P_ASSIGNMENT_ID;

    IF (V_ASSIGNMENT_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one current pilot assignment is required.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_STATUS),
        MAX(REQUIRE_ENGINEER_APPROVAL_FLAG),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION)
    INTO
        :V_PLAN_COUNT,
        :V_PILOT_STATUS,
        :V_REQUIRE_ENGINEER_APPROVAL,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1
    WHERE PILOT_PLAN_ID = :V_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(FINAL_VALUE_MIN::FLOAT),
        MAX(FINAL_VALUE_MAX::FLOAT),

        MAX(
            MAX_ABS_DEVIATION_FROM_RULE::FLOAT
        ),
        MAX(
            MAX_PCT_DEVIATION_FROM_RULE::FLOAT
        )

    INTO
        :V_POLICY_COUNT,

        :V_FINAL_MIN,
        :V_FINAL_MAX,

        :V_MAX_ABS_DEVIATION,
        :V_MAX_PCT_DEVIATION

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1

    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_ID =
          :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          ''CONTROLLED'';

    IF (V_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one active CONTROLLED policy is required.''
        );
    END IF;

    V_CAPABILITY_KEY :=
        IFF(
            V_MODEL_DOMAIN = ''BMCS'',
            ''BMCS_BUSINESS_GATE_READY_FLAG'',
            ''GOVERNED_COST_RECALCULATION_READY_FLAG''
        );

    SELECT
        COUNT(*),
        MAX(READY_FLAG)
    INTO
        :V_CAPABILITY_COUNT,
        :V_CAPABILITY_READY
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DEPLOYMENT_CAPABILITY_CURRENT_V1
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND CAPABILITY_KEY =
          :V_CAPABILITY_KEY;

    V_BOUNDS_PASS :=
        (
            V_FINAL_MIN IS NULL
            OR P_CANDIDATE_VALUE >= V_FINAL_MIN
        )
        AND
        (
            V_FINAL_MAX IS NULL
            OR P_CANDIDATE_VALUE <= V_FINAL_MAX
        );

    V_ABS_PASS :=
        V_MAX_ABS_DEVIATION IS NULL
        OR P_RULE_VALUE IS NULL
        OR ABS(
            P_CANDIDATE_VALUE
            - P_RULE_VALUE
        ) <= V_MAX_ABS_DEVIATION;

    V_PCT_PASS :=
        V_MAX_PCT_DEVIATION IS NULL
        OR P_RULE_VALUE IS NULL
        OR ABS(P_RULE_VALUE) < 0.000000001
        OR (
            ABS(
                P_CANDIDATE_VALUE
                - P_RULE_VALUE
            )
            /
            ABS(P_RULE_VALUE)
        ) * 100.0
            <= V_MAX_PCT_DEVIATION;

    V_GUARDRAIL_PASS :=
        P_QUALITY_PASS_FLAG
        AND NOT P_OOD_FLAG
        AND (
            V_MODEL_DOMAIN = ''BMCS''
            OR P_RULE_VALUE IS NOT NULL
        )
        AND V_BOUNDS_PASS
        AND V_ABS_PASS
        AND V_PCT_PASS;

    V_AUTHORISED :=
        V_PILOT_STATUS = ''ACTIVE''
        AND COALESCE(
            V_ASSIGNED,
            FALSE
        )
        AND COALESCE(
            V_CONTROLLED_ELIGIBLE,
            FALSE
        )
        AND V_GUARDRAIL_PASS
        AND (
            NOT V_REQUIRE_ENGINEER_APPROVAL
            OR P_ENGINEER_APPROVED_FLAG
        )
        AND V_CAPABILITY_COUNT = 1
        AND COALESCE(
            V_CAPABILITY_READY,
            FALSE
        );

    IF (V_AUTHORISED) THEN
        V_FINAL_VALUE :=
            P_CANDIDATE_VALUE;
        V_FINAL_SOURCE :=
            ''CANDIDATE_CONTROLLED'';
        V_DECISION_STATUS :=
            ''CONTROLLED_USE_AUTHORISED'';
        V_DECISION_REASON :=
            ''Assignment, capability, quality, guardrail and engineer approval checks passed.'';

    ELSE
        V_FINAL_VALUE :=
            P_RULE_VALUE;
        V_FINAL_SOURCE :=
            ''DETERMINISTIC_FALLBACK'';
        V_DECISION_STATUS :=
            ''FALLBACK_REQUIRED'';
        V_DECISION_REASON :=
            ''One or more pilot assignment, capability, quality, guardrail or approval checks failed.'';
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
    SET
        IS_ACTIVE = FALSE,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE PILOT_PLAN_ID = :V_PLAN_ID
      AND SIMULATION_ID = :V_SIMULATION_ID
      AND IS_ACTIVE = TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 (
            PILOT_DECISION_ID,
            ASSIGNMENT_ID,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            MODEL_DOMAIN,

            SIMULATION_ID,
            KMAT_ID,
            RFQ_ID,

            RULE_VALUE,
            CANDIDATE_VALUE,
            FINAL_PILOT_VALUE,

            QUALITY_PASS_FLAG,
            OOD_FLAG,

            BOUNDS_PASS_FLAG,
            ABS_DEVIATION_PASS_FLAG,
            PCT_DEVIATION_PASS_FLAG,
            OVERALL_GUARDRAIL_PASS_FLAG,

            ENGINEER_APPROVED_FLAG,
            ENGINEER_APPROVED_BY,
            ENGINEER_APPROVAL_REFERENCE,

            CONTROLLED_USE_AUTHORIZED_FLAG,
            FINAL_PILOT_SOURCE,

            BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG,
            OFFICIAL_COST_CHANGED_FLAG,

            DECISION_STATUS,
            DECISION_REASON,

            IS_ACTIVE,

            DECIDED_BY,
            DECIDED_AT,

            UPDATED_AT
        )
    SELECT
        TRIM(:P_PILOT_DECISION_ID),
        TRIM(:P_ASSIGNMENT_ID),

        :V_PLAN_ID,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,

        :V_SIMULATION_ID,
        :V_KMAT_ID,
        :V_RFQ_ID,

        :P_RULE_VALUE,
        :P_CANDIDATE_VALUE,
        :V_FINAL_VALUE,

        :P_QUALITY_PASS_FLAG,
        :P_OOD_FLAG,

        :V_BOUNDS_PASS,
        :V_ABS_PASS,
        :V_PCT_PASS,
        :V_GUARDRAIL_PASS,

        :P_ENGINEER_APPROVED_FLAG,
        :P_ENGINEER_APPROVED_BY,
        :P_ENGINEER_APPROVAL_REFERENCE,

        :V_AUTHORISED,
        :V_FINAL_SOURCE,

        FALSE,
        FALSE,

        :V_DECISION_STATUS,
        :V_DECISION_REASON,

        TRUE,

        TRIM(:P_DECIDED_BY),
        CURRENT_TIMESTAMP(),

        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot decision insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_DECISION_RECORDED'',

        :V_PLAN_ID,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        TRIM(:P_ASSIGNMENT_ID),
        TRIM(:P_PILOT_DECISION_ID),
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        :V_SIMULATION_ID,

        :V_DECISION_STATUS,
        :V_DECISION_REASON,

        TRIM(:P_DECIDED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''pilot_decision_id'',
            P_PILOT_DECISION_ID,
        ''assignment_id'', P_ASSIGNMENT_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''simulation_id'', V_SIMULATION_ID,

        ''guardrail_pass'', V_GUARDRAIL_PASS,
        ''engineer_approved'',
            P_ENGINEER_APPROVED_FLAG,
        ''capability_ready'',
            V_CAPABILITY_READY,

        ''controlled_use_authorised'',
            V_AUTHORISED,

        ''final_pilot_source'',
            V_FINAL_SOURCE,
        ''final_pilot_value'',
            V_FINAL_VALUE,

        ''bmcs_direct_cost_impact_allowed'',
            FALSE,
        ''official_cost_changed'', FALSE,

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_PILOT_INCIDENT_V1(
        P_INCIDENT_ID VARCHAR,
        P_PILOT_PLAN_ID VARCHAR,
        P_SIMULATION_ID VARCHAR,

        P_INCIDENT_CATEGORY VARCHAR,
        P_INCIDENT_SEVERITY VARCHAR,

        P_INCIDENT_DESCRIPTION VARCHAR,
        P_EVIDENCE_REFERENCE VARCHAR,

        P_REPORTED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_INCIDENT_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;

    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_PILOT_STATUS VARCHAR;
    V_AUTO_PAUSE BOOLEAN;

    V_RESULTING_STATUS VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_INCIDENT_ID IS NULL
        OR LENGTH(TRIM(P_INCIDENT_ID)) = 0
        OR P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''P_INCIDENT_ID and P_PILOT_PLAN_ID are required.''
        );
    END IF;

    IF (
        P_INCIDENT_CATEGORY IS NULL
        OR UPPER(TRIM(P_INCIDENT_CATEGORY))
            NOT IN (
                ''SAFETY'',
                ''COST'',
                ''QUALITY'',
                ''OOD'',
                ''OPERATIONS'',
                ''OTHER''
            )
        OR P_INCIDENT_SEVERITY IS NULL
        OR UPPER(TRIM(P_INCIDENT_SEVERITY))
            NOT IN (
                ''INFO'',
                ''WARNING'',
                ''CRITICAL''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Incident category or severity is invalid.''
        );
    END IF;

    IF (
        P_INCIDENT_DESCRIPTION IS NULL
        OR LENGTH(TRIM(P_INCIDENT_DESCRIPTION)) = 0
        OR P_REPORTED_BY IS NULL
        OR LENGTH(TRIM(P_REPORTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Incident description and reporter are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_INCIDENT_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE INCIDENT_ID = :P_INCIDENT_ID;

    IF (V_EXISTING_INCIDENT_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''INCIDENT_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN),

        MAX(PILOT_STATUS),
        MAX(AUTO_PAUSE_ON_CRITICAL_FLAG)

    INTO
        :V_PLAN_COUNT,

        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN,

        :V_PILOT_STATUS,
        :V_AUTO_PAUSE

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();
    V_RESULTING_STATUS := V_PILOT_STATUS;

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 (
            INCIDENT_ID,
            PILOT_PLAN_ID,

            SIMULATION_ID,

            INCIDENT_CATEGORY,
            INCIDENT_SEVERITY,

            INCIDENT_STATUS,
            INCIDENT_DESCRIPTION,
            EVIDENCE_REFERENCE,

            REPORTED_BY,
            REPORTED_AT,

            REVIEWED_BY,
            REVIEWED_AT,
            RESOLUTION_NOTE,

            UPDATED_AT
        )
    SELECT
        TRIM(:P_INCIDENT_ID),
        TRIM(:P_PILOT_PLAN_ID),

        :P_SIMULATION_ID,

        UPPER(TRIM(:P_INCIDENT_CATEGORY)),
        UPPER(TRIM(:P_INCIDENT_SEVERITY)),

        ''OPEN'',
        TRIM(:P_INCIDENT_DESCRIPTION),
        :P_EVIDENCE_REFERENCE,

        TRIM(:P_REPORTED_BY),
        CURRENT_TIMESTAMP(),

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,
        NULL::VARCHAR,

        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Incident insert did not affect exactly one row.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_INCIDENT_SEVERITY))
            = ''CRITICAL''
        AND COALESCE(V_AUTO_PAUSE, FALSE)
        AND V_PILOT_STATUS = ''ACTIVE''
    ) THEN
        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
        SET
            PILOT_STATUS = ''PAUSED'',
            PILOT_STATUS_REASON =
                ''Automatically paused by critical incident ''
                || TRIM(:P_INCIDENT_ID),

            LAST_STATUS_CHANGED_BY =
                TRIM(:P_REPORTED_BY),
            LAST_STATUS_CHANGED_AT =
                CURRENT_TIMESTAMP(),

            UPDATED_AT =
                CURRENT_TIMESTAMP()

        WHERE PILOT_PLAN_ID =
              :P_PILOT_PLAN_ID
          AND PILOT_STATUS = ''ACTIVE'';

        V_RESULTING_STATUS := ''PAUSED'';
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_INCIDENT_RECORDED'',

        TRIM(:P_PILOT_PLAN_ID),
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        TRIM(:P_INCIDENT_ID),
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        :P_SIMULATION_ID,

        UPPER(TRIM(:P_INCIDENT_SEVERITY)),
        TRIM(:P_INCIDENT_DESCRIPTION),

        TRIM(:P_REPORTED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''incident_id'', P_INCIDENT_ID,
        ''pilot_plan_id'', P_PILOT_PLAN_ID,

        ''incident_severity'',
            UPPER(TRIM(P_INCIDENT_SEVERITY)),
        ''incident_status'', ''OPEN'',

        ''pilot_status_before'',
            V_PILOT_STATUS,
        ''pilot_status_after'',
            V_RESULTING_STATUS,

        ''auto_pause_triggered'',
            V_RESULTING_STATUS = ''PAUSED''
            AND V_PILOT_STATUS = ''ACTIVE'',

        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_PILOT_INCIDENT_V1(
        P_INCIDENT_ID VARCHAR,
        P_REVIEW_ACTION VARCHAR,
        P_RESOLUTION_NOTE VARCHAR,
        P_REVIEWED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_INCIDENT_COUNT NUMBER DEFAULT 0;

    V_PLAN_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;
    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_EVENT_ID VARCHAR;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_INCIDENT_ID IS NULL
        OR LENGTH(TRIM(P_INCIDENT_ID)) = 0
        OR P_REVIEW_ACTION IS NULL
        OR UPPER(TRIM(P_REVIEW_ACTION))
            NOT IN (
                ''RESOLVE'',
                ''KEEP_OPEN''
            )
        OR P_RESOLUTION_NOTE IS NULL
        OR LENGTH(TRIM(P_RESOLUTION_NOTE)) = 0
        OR P_REVIEWED_BY IS NULL
        OR LENGTH(TRIM(P_REVIEWED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Incident, valid action, resolution note and reviewer are required.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_PLAN_ID)
    INTO
        :V_INCIDENT_COUNT,
        :V_PLAN_ID
    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE INCIDENT_ID = :P_INCIDENT_ID;

    IF (V_INCIDENT_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one incident is required.''
        );
    END IF;

    SELECT
        MAX(MODEL_DOMAIN),
        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION)
    INTO
        :V_MODEL_DOMAIN,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1
    WHERE PILOT_PLAN_ID = :V_PLAN_ID;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    SET
        INCIDENT_STATUS =
            IFF(
                UPPER(TRIM(:P_REVIEW_ACTION))
                    = ''RESOLVE'',
                ''RESOLVED'',
                ''OPEN''
            ),

        REVIEWED_BY =
            TRIM(:P_REVIEWED_BY),
        REVIEWED_AT =
            CURRENT_TIMESTAMP(),
        RESOLUTION_NOTE =
            TRIM(:P_RESOLUTION_NOTE),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE INCIDENT_ID =
          :P_INCIDENT_ID;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Incident review did not update exactly one row.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_INCIDENT_REVIEWED'',

        :V_PLAN_ID,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        TRIM(:P_INCIDENT_ID),
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        IFF(
            UPPER(TRIM(:P_REVIEW_ACTION))
                = ''RESOLVE'',
            ''RESOLVED'',
            ''OPEN''
        ),

        TRIM(:P_RESOLUTION_NOTE),

        TRIM(:P_REVIEWED_BY),
        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''incident_id'', P_INCIDENT_ID,
        ''review_action'',
            UPPER(TRIM(P_REVIEW_ACTION)),

        ''incident_status'',
            IFF(
                UPPER(TRIM(P_REVIEW_ACTION))
                    = ''RESOLVE'',
                ''RESOLVED'',
                ''OPEN''
            ),

        ''event_id'', V_EVENT_ID
    );
END;
';

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_OUTCOME_DETAIL_V1
AS
SELECT
    assignment.PILOT_PLAN_ID,
    assignment.DEPLOYMENT_REQUEST_ID,
    assignment.EVIDENCE_VERSION,

    assignment.MODEL_DOMAIN,

    assignment.ASSIGNMENT_ID,
    assignment.SIMULATION_ID,
    assignment.KMAT_ID,
    assignment.RFQ_ID,

    assignment.PILOT_ASSIGNED_FLAG,

    decision.PILOT_DECISION_ID,
    decision.CONTROLLED_USE_AUTHORIZED_FLAG,
    decision.FINAL_PILOT_SOURCE,

    decision.RULE_VALUE,
    decision.CANDIDATE_VALUE,
    decision.FINAL_PILOT_VALUE,

    decision.OVERALL_GUARDRAIL_PASS_FLAG,
    decision.ENGINEER_APPROVED_FLAG,

    IFF(
        decision.PILOT_DECISION_ID IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        TRUE,
        FALSE
    ) AS CANDIDATE_EVALUATION_ELIGIBLE_FLAG,

    feedback.OUTCOME_AVAILABLE_FLAG,

    IFF(
        assignment.MODEL_DOMAIN = 'BMCS',
        IFF(
            feedback.ACTUAL_MAPPING_CORRECT_FLAG,
            1.0,
            0.0
        )::FLOAT,
        feedback.ACTUAL_NUMERIC_VALUE::FLOAT
    ) AS ACTUAL_VALUE,

    IFF(
        assignment.MODEL_DOMAIN <> 'BMCS'
        AND feedback.ACTUAL_NUMERIC_VALUE
            IS NOT NULL
        AND decision.RULE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        ABS(
            decision.RULE_VALUE
            - feedback.ACTUAL_NUMERIC_VALUE
        ),
        NULL::FLOAT
    ) AS RULE_ABS_ERROR,

    IFF(
        feedback.OUTCOME_AVAILABLE_FLAG = TRUE
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        ABS(
            decision.CANDIDATE_VALUE
            - IFF(
                assignment.MODEL_DOMAIN = 'BMCS',
                IFF(
                    feedback
                        .ACTUAL_MAPPING_CORRECT_FLAG,
                    1.0,
                    0.0
                ),
                feedback.ACTUAL_NUMERIC_VALUE
            )
        ),
        NULL::FLOAT
    ) AS CANDIDATE_ABS_ERROR,

    IFF(
        assignment.MODEL_DOMAIN = 'BMCS'
        AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        POWER(
            decision.CANDIDATE_VALUE
            - IFF(
                feedback
                    .ACTUAL_MAPPING_CORRECT_FLAG,
                1.0,
                0.0
            ),
            2
        ),
        NULL::FLOAT
    ) AS BMCS_BRIER_SCORE,

    IFF(
        assignment.MODEL_DOMAIN = 'BMCS'
        AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        IFF(
            (
                decision.CANDIDATE_VALUE >= 0.5
                AND feedback
                    .ACTUAL_MAPPING_CORRECT_FLAG
            )
            OR
            (
                decision.CANDIDATE_VALUE < 0.5
                AND NOT feedback
                    .ACTUAL_MAPPING_CORRECT_FLAG
            ),
            TRUE,
            FALSE
        ),
        NULL::BOOLEAN
    ) AS BMCS_CLASSIFICATION_CORRECT_FLAG

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
        assignment

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_DECISION_CURRENT_V1
        decision
    ON assignment.PILOT_PLAN_ID =
       decision.PILOT_PLAN_ID
   AND assignment.SIMULATION_ID =
       decision.SIMULATION_ID

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
        feedback
    ON assignment.SIMULATION_ID =
       feedback.SIMULATION_ID
   AND assignment.MODEL_DOMAIN =
       feedback.MODEL_DOMAIN;


CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_PILOT_MONITORING_V1(
        P_MONITORING_RUN_ID VARCHAR,
        P_PILOT_PLAN_ID VARCHAR,
        P_RUN_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_RUN_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_PRIOR_STATUS VARCHAR;
    V_RESULTING_STATUS VARCHAR;
    V_AUTO_PAUSE BOOLEAN;

    V_ASSIGNED_COUNT NUMBER DEFAULT 0;
    V_CONTROLLED_COUNT NUMBER DEFAULT 0;
    V_FALLBACK_COUNT NUMBER DEFAULT 0;

    V_OUTCOME_COUNT NUMBER DEFAULT 0;

    V_RULE_MAE FLOAT;
    V_CANDIDATE_MAE FLOAT;
    V_CANDIDATE_RMSE FLOAT;
    V_ADVANTAGE FLOAT;

    V_BRIER FLOAT;
    V_BMCS_ACCURACY FLOAT;

    V_OPEN_CRITICAL_COUNT NUMBER DEFAULT 0;
    V_UNAUTHORISED_COUNT NUMBER DEFAULT 0;
    V_GUARDRAIL_VIOLATION_COUNT NUMBER DEFAULT 0;

    V_REQUIRED_MIN_OUTCOME_COUNT NUMBER;
    V_REQUIRED_MAX_ERROR FLOAT;
    V_REQUIRED_MIN_BMCS_ACCURACY FLOAT;

    V_MONITORING_STATUS VARCHAR;
    V_MONITORING_REASON VARCHAR;

    V_AUTO_PAUSE_TRIGGERED BOOLEAN DEFAULT FALSE;

    V_STARTED_AT TIMESTAMP_NTZ;
    V_COMPLETED_AT TIMESTAMP_NTZ;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_MONITORING_RUN_ID IS NULL
        OR LENGTH(TRIM(P_MONITORING_RUN_ID)) = 0
        OR P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
        OR P_RUN_BY IS NULL
        OR LENGTH(TRIM(P_RUN_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Monitoring run, pilot plan and actor are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_RUN_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_MONITORING_RUN_V1
    WHERE MONITORING_RUN_ID =
          :P_MONITORING_RUN_ID;

    IF (V_EXISTING_RUN_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_12B'',

                ''monitoring_run_id'',
                    MONITORING_RUN_ID,
                ''pilot_plan_id'', PILOT_PLAN_ID,

                ''monitoring_status'',
                    MONITORING_STATUS,
                ''monitoring_reason'',
                    MONITORING_REASON,

                ''prior_pilot_status'',
                    PRIOR_PILOT_STATUS,
                ''resulting_pilot_status'',
                    RESULTING_PILOT_STATUS,

                ''auto_pause_triggered'',
                    AUTO_PAUSE_TRIGGERED_FLAG,

                ''completed_at'', COMPLETED_AT
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_MONITORING_RUN_V1
            WHERE MONITORING_RUN_ID =
                  :P_MONITORING_RUN_ID
        );
    END IF;

    IF (V_EXISTING_RUN_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''MONITORING_RUN_ID is not unique.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(MODEL_DOMAIN),
        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),

        MAX(PILOT_STATUS),
        MAX(AUTO_PAUSE_ON_CRITICAL_FLAG)

    INTO
        :V_PLAN_COUNT,

        :V_MODEL_DOMAIN,
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        :V_PRIOR_STATUS,
        :V_AUTO_PAUSE

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    V_STARTED_AT := CURRENT_TIMESTAMP();

    SELECT
        COALESCE(
            COUNT_IF(
                PILOT_ASSIGNED_FLAG = TRUE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE =
                    ''CANDIDATE_CONTROLLED''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE =
                    ''DETERMINISTIC_FALLBACK''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                OUTCOME_AVAILABLE_FLAG = TRUE
                AND CANDIDATE_EVALUATION_ELIGIBLE_FLAG = TRUE
            ),
            0
        )::NUMBER,

        AVG(RULE_ABS_ERROR),
        AVG(CANDIDATE_ABS_ERROR),

        SQRT(
            AVG(
                POWER(
                    CANDIDATE_ABS_ERROR,
                    2
                )
            )
        ),

        AVG(BMCS_BRIER_SCORE),

        IFF(
            COALESCE(
                COUNT_IF(
                    BMCS_CLASSIFICATION_CORRECT_FLAG
                        IS NOT NULL
                ),
                0
            ) = 0,
            NULL::FLOAT,
            (
                COALESCE(
                    COUNT_IF(
                        BMCS_CLASSIFICATION_CORRECT_FLAG
                            = TRUE
                    ),
                    0
                )
                /
                NULLIF(
                    COALESCE(
                        COUNT_IF(
                            BMCS_CLASSIFICATION_CORRECT_FLAG
                                IS NOT NULL
                        ),
                        0
                    ),
                    0
                )
            ) * 100.0
        )

    INTO
        :V_ASSIGNED_COUNT,
        :V_CONTROLLED_COUNT,
        :V_FALLBACK_COUNT,

        :V_OUTCOME_COUNT,

        :V_RULE_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,

        :V_BRIER,
        :V_BMCS_ACCURACY

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_OUTCOME_DETAIL_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    SELECT
        COALESCE(
            COUNT_IF(
                INCIDENT_STATUS = ''OPEN''
                AND INCIDENT_SEVERITY = ''CRITICAL''
            ),
            0
        )::NUMBER
    INTO :V_OPEN_CRITICAL_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    SELECT
        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE =
                    ''CANDIDATE_CONTROLLED''
                AND CONTROLLED_USE_AUTHORIZED_FLAG
                    = FALSE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE =
                    ''CANDIDATE_CONTROLLED''
                AND OVERALL_GUARDRAIL_PASS_FLAG
                    = FALSE
            ),
            0
        )::NUMBER

    INTO
        :V_UNAUTHORISED_COUNT,
        :V_GUARDRAIL_VIOLATION_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_DECISION_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    V_REQUIRED_MIN_OUTCOME_COUNT := 5;

    V_REQUIRED_MAX_ERROR :=
        CASE
            WHEN V_MODEL_DOMAIN IN (
                ''CSS'',
                ''FMIS''
            )
                THEN 0.03
            WHEN V_MODEL_DOMAIN = ''TDS''
                THEN 0.15
            ELSE 0.15
        END;

    V_REQUIRED_MIN_BMCS_ACCURACY :=
        IFF(
            V_MODEL_DOMAIN = ''BMCS'',
            80.0,
            NULL::FLOAT
        );

    V_ADVANTAGE :=
        IFF(
            V_RULE_MAE IS NOT NULL
            AND V_CANDIDATE_MAE IS NOT NULL,
            V_RULE_MAE - V_CANDIDATE_MAE,
            NULL::FLOAT
        );

    IF (
        V_OPEN_CRITICAL_COUNT > 0
        OR V_UNAUTHORISED_COUNT > 0
        OR V_GUARDRAIL_VIOLATION_COUNT > 0
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';
        V_MONITORING_REASON :=
            ''Critical incident, unauthorised controlled use, or guardrail violation detected.'';

    ELSEIF (
        V_OUTCOME_COUNT <
            V_REQUIRED_MIN_OUTCOME_COUNT
    ) THEN
        V_MONITORING_STATUS :=
            ''INSUFFICIENT_DATA'';
        V_MONITORING_REASON :=
            ''Fewer than five verified pilot outcomes are available.'';

    ELSEIF (
        V_MODEL_DOMAIN = ''BMCS''
        AND (
            V_BRIER IS NULL
            OR V_BRIER >
                V_REQUIRED_MAX_ERROR
            OR V_BMCS_ACCURACY IS NULL
            OR V_BMCS_ACCURACY <
                V_REQUIRED_MIN_BMCS_ACCURACY
        )
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';
        V_MONITORING_REASON :=
            ''BMCS pilot Brier score or diagnostic accuracy failed the controlled threshold.'';

    ELSEIF (
        V_MODEL_DOMAIN <> ''BMCS''
        AND (
            V_CANDIDATE_MAE IS NULL
            OR V_CANDIDATE_MAE >
                V_REQUIRED_MAX_ERROR
            OR V_ADVANTAGE IS NULL
            OR V_ADVANTAGE < 0.0
        )
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';
        V_MONITORING_REASON :=
            ''Candidate pilot error exceeded threshold or underperformed the deterministic rule.'';

    ELSE
        V_MONITORING_STATUS :=
            ''HEALTHY'';
        V_MONITORING_REASON :=
            ''Pilot safety and performance checks passed.'';
    END IF;

    V_RESULTING_STATUS := V_PRIOR_STATUS;

    IF (
        V_MONITORING_STATUS =
            ''ATTENTION_REQUIRED''
        AND COALESCE(V_AUTO_PAUSE, FALSE)
        AND V_PRIOR_STATUS = ''ACTIVE''
    ) THEN
        V_RESULTING_STATUS := ''PAUSED'';
        V_AUTO_PAUSE_TRIGGERED := TRUE;
    END IF;

    V_COMPLETED_AT := CURRENT_TIMESTAMP();
    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    IF (V_AUTO_PAUSE_TRIGGERED) THEN
        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
        SET
            PILOT_STATUS = ''PAUSED'',
            PILOT_STATUS_REASON =
                ''Automatically paused by monitoring run ''
                || TRIM(:P_MONITORING_RUN_ID),

            LAST_STATUS_CHANGED_BY =
                TRIM(:P_RUN_BY),
            LAST_STATUS_CHANGED_AT =
                CURRENT_TIMESTAMP(),

            UPDATED_AT =
                CURRENT_TIMESTAMP()

        WHERE PILOT_PLAN_ID =
              :P_PILOT_PLAN_ID
          AND PILOT_STATUS = ''ACTIVE'';
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 (
            MONITORING_RUN_ID,
            PILOT_PLAN_ID,

            MODEL_DOMAIN,

            PRIOR_PILOT_STATUS,
            RESULTING_PILOT_STATUS,

            MONITORING_STATUS,
            MONITORING_REASON,

            ASSIGNED_COUNT,
            CONTROLLED_DECISION_COUNT,
            FALLBACK_DECISION_COUNT,

            ACTUAL_OUTCOME_COUNT,

            RULE_MAE,
            CANDIDATE_MAE,
            CANDIDATE_RMSE,
            CANDIDATE_ADVANTAGE_VS_RULE,

            BMCS_BRIER_SCORE,
            BMCS_ACCURACY_PCT,

            OPEN_CRITICAL_INCIDENT_COUNT,
            UNAUTHORISED_CONTROLLED_USE_COUNT,
            GUARDRAIL_VIOLATION_COUNT,

            REQUIRED_MIN_OUTCOME_COUNT,
            REQUIRED_MAX_ERROR,
            REQUIRED_MIN_BMCS_ACCURACY_PCT,

            AUTO_PAUSE_TRIGGERED_FLAG,

            RUN_BY,
            STARTED_AT,
            COMPLETED_AT,

            CREATED_AT
        )
    SELECT
        TRIM(:P_MONITORING_RUN_ID),
        TRIM(:P_PILOT_PLAN_ID),

        :V_MODEL_DOMAIN,

        :V_PRIOR_STATUS,
        :V_RESULTING_STATUS,

        :V_MONITORING_STATUS,
        :V_MONITORING_REASON,

        :V_ASSIGNED_COUNT,
        :V_CONTROLLED_COUNT,
        :V_FALLBACK_COUNT,

        :V_OUTCOME_COUNT,

        :V_RULE_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,
        :V_ADVANTAGE,

        :V_BRIER,
        :V_BMCS_ACCURACY,

        :V_OPEN_CRITICAL_COUNT,
        :V_UNAUTHORISED_COUNT,
        :V_GUARDRAIL_VIOLATION_COUNT,

        :V_REQUIRED_MIN_OUTCOME_COUNT,
        :V_REQUIRED_MAX_ERROR,
        :V_REQUIRED_MIN_BMCS_ACCURACY,

        :V_AUTO_PAUSE_TRIGGERED,

        TRIM(:P_RUN_BY),
        :V_STARTED_AT,
        :V_COMPLETED_AT,

        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Monitoring run insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_MONITORING_COMPLETED'',

        TRIM(:P_PILOT_PLAN_ID),
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,
        TRIM(:P_MONITORING_RUN_ID),

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        :V_MONITORING_STATUS,
        :V_MONITORING_REASON,

        TRIM(:P_RUN_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_12B'',

        ''monitoring_run_id'',
            P_MONITORING_RUN_ID,
        ''pilot_plan_id'', P_PILOT_PLAN_ID,

        ''monitoring_status'',
            V_MONITORING_STATUS,
        ''monitoring_reason'',
            V_MONITORING_REASON,

        ''prior_pilot_status'',
            V_PRIOR_STATUS,
        ''resulting_pilot_status'',
            V_RESULTING_STATUS,

        ''assigned_count'', V_ASSIGNED_COUNT,
        ''controlled_decision_count'',
            V_CONTROLLED_COUNT,
        ''fallback_decision_count'',
            V_FALLBACK_COUNT,

        ''actual_outcome_count'',
            V_OUTCOME_COUNT,

        ''candidate_mae'', V_CANDIDATE_MAE,
        ''candidate_advantage_vs_rule'',
            V_ADVANTAGE,

        ''bmcs_brier_score'', V_BRIER,
        ''bmcs_accuracy_pct'',
            V_BMCS_ACCURACY,

        ''open_critical_incident_count'',
            V_OPEN_CRITICAL_COUNT,
        ''unauthorised_controlled_use_count'',
            V_UNAUTHORISED_COUNT,
        ''guardrail_violation_count'',
            V_GUARDRAIL_VIOLATION_COUNT,

        ''auto_pause_triggered'',
            V_AUTO_PAUSE_TRIGGERED,

        ''official_cost_changed'', FALSE,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12B'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.UPDATE_ML_PILOT_STATUS_V1(
        P_PILOT_PLAN_ID VARCHAR,
        P_STATUS_ACTION VARCHAR,
        P_REASON VARCHAR,
        P_CHANGED_BY VARCHAR,
        P_CONFIRMATION_PHRASE VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_OPEN_CRITICAL_COUNT NUMBER DEFAULT 0;

    V_CURRENT_STATUS VARCHAR;
    V_NEW_STATUS VARCHAR;

    V_REQUEST_ID VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_EVENT_ID VARCHAR;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
        OR P_STATUS_ACTION IS NULL
        OR UPPER(TRIM(P_STATUS_ACTION))
            NOT IN (
                ''PAUSE'',
                ''RESUME'',
                ''STOP''
            )
        OR P_REASON IS NULL
        OR LENGTH(TRIM(P_REASON)) = 0
        OR P_CHANGED_BY IS NULL
        OR LENGTH(TRIM(P_CHANGED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot, valid status action, reason and actor are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> UPPER(TRIM(P_STATUS_ACTION))
               || ''::''
               || P_PILOT_PLAN_ID
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Confirmation must equal <ACTION>::<PILOT_PLAN_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(PILOT_STATUS),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN)

    INTO
        :V_PLAN_COUNT,

        :V_CURRENT_STATUS,

        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_STATUS_ACTION)) = ''PAUSE''
        AND V_CURRENT_STATUS <> ''ACTIVE''
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Only an ACTIVE pilot can be paused.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_STATUS_ACTION)) = ''RESUME''
        AND V_CURRENT_STATUS <> ''PAUSED''
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Only a PAUSED pilot can be resumed.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_STATUS_ACTION)) = ''STOP''
        AND V_CURRENT_STATUS
            NOT IN (
                ''DRAFT'',
                ''ACTIVE'',
                ''PAUSED''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Only DRAFT, ACTIVE or PAUSED pilots can be stopped.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_STATUS_ACTION)) = ''RESUME''
    ) THEN
        SELECT
            COALESCE(
                COUNT_IF(
                    INCIDENT_STATUS = ''OPEN''
                    AND INCIDENT_SEVERITY =
                        ''CRITICAL''
                ),
                0
            )::NUMBER
        INTO :V_OPEN_CRITICAL_COUNT
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_PILOT_INCIDENT_V1
        WHERE PILOT_PLAN_ID =
              :P_PILOT_PLAN_ID;

        IF (V_OPEN_CRITICAL_COUNT > 0) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Pilot cannot resume while critical incidents remain open.'',
                ''open_critical_incidents'',
                    V_OPEN_CRITICAL_COUNT
            );
        END IF;
    END IF;

    V_NEW_STATUS :=
        CASE
            WHEN UPPER(TRIM(P_STATUS_ACTION))
                = ''PAUSE''
                THEN ''PAUSED''
            WHEN UPPER(TRIM(P_STATUS_ACTION))
                = ''RESUME''
                THEN ''ACTIVE''
            ELSE ''STOPPED''
        END;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1
    SET
        PILOT_STATUS =
            :V_NEW_STATUS,
        PILOT_STATUS_REASON =
            TRIM(:P_REASON),

        LAST_STATUS_CHANGED_BY =
            TRIM(:P_CHANGED_BY),
        LAST_STATUS_CHANGED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE PILOT_PLAN_ID =
          :P_PILOT_PLAN_ID
      AND PILOT_STATUS =
          :V_CURRENT_STATUS;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Pilot status update did not affect exactly one row.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 (
            EVENT_ID,
            EVENT_TYPE,

            PILOT_PLAN_ID,
            DEPLOYMENT_REQUEST_ID,
            EVIDENCE_VERSION,

            ASSIGNMENT_ID,
            PILOT_DECISION_ID,
            INCIDENT_ID,
            MONITORING_RUN_ID,

            MODEL_DOMAIN,
            SIMULATION_ID,

            EVENT_STATUS,
            EVENT_REASON,

            EVENT_ACTOR,
            EVENT_AT
        )
    SELECT
        :V_EVENT_ID,
        ''PILOT_STATUS_CHANGED'',

        TRIM(:P_PILOT_PLAN_ID),
        :V_REQUEST_ID,
        :V_EVIDENCE_VERSION,

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_MODEL_DOMAIN,
        NULL::VARCHAR,

        :V_NEW_STATUS,
        TRIM(:P_REASON),

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12B'',

        ''pilot_plan_id'', P_PILOT_PLAN_ID,
        ''prior_status'', V_CURRENT_STATUS,
        ''new_status'', V_NEW_STATUS,

        ''status_action'',
            UPPER(TRIM(P_STATUS_ACTION)),

        ''event_id'', V_EVENT_ID
    );
END;
';


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_MONITORING_LATEST_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_PILOT_MONITORING_RUN_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PILOT_PLAN_ID
    ORDER BY
        COMPLETED_AT DESC,
        CREATED_AT DESC,
        MONITORING_RUN_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE12B_PILOT_DASHBOARD_V1
AS
WITH COUNTERS AS (
    SELECT
        PILOT_PLAN_ID,

        MAX(
            IFF(
                COUNTER_TYPE = 'TOTAL',
                ASSIGNED_COUNT,
                NULL::NUMBER
            )
        ) AS TOTAL_ASSIGNED_COUNT,

        MAX(
            IFF(
                COUNTER_TYPE = 'DAILY'
                AND COUNTER_DATE = CURRENT_DATE(),
                ASSIGNED_COUNT,
                NULL::NUMBER
            )
        ) AS TODAY_ASSIGNED_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_CAPACITY_COUNTER_V1

    GROUP BY PILOT_PLAN_ID
),
INCIDENTS AS (
    SELECT
        PILOT_PLAN_ID,

        COALESCE(
            COUNT_IF(
                INCIDENT_STATUS = 'OPEN'
            ),
            0
        )::NUMBER AS OPEN_INCIDENT_COUNT,

        COALESCE(
            COUNT_IF(
                INCIDENT_STATUS = 'OPEN'
                AND INCIDENT_SEVERITY = 'CRITICAL'
            ),
            0
        )::NUMBER AS OPEN_CRITICAL_INCIDENT_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_INCIDENT_V1

    GROUP BY PILOT_PLAN_ID
)
SELECT
    plan.PILOT_PLAN_ID,

    plan.DEPLOYMENT_REQUEST_ID,
    plan.EVIDENCE_VERSION,

    plan.MODEL_DOMAIN,
    plan.TARGET_MODE,

    plan.CANDIDATE_POLICY_ID,
    plan.CANDIDATE_POLICY_VERSION,

    plan.CANDIDATE_MODEL_NAME,
    plan.CANDIDATE_MODEL_VERSION,
    plan.CANDIDATE_FEATURE_SET_VERSION,

    plan.PILOT_STATUS,
    plan.PILOT_STATUS_REASON,

    plan.EXPOSURE_PCT,
    plan.MAX_DAILY_ASSIGNMENTS,
    plan.MAX_TOTAL_ASSIGNMENTS,

    COALESCE(
        counters.TODAY_ASSIGNED_COUNT,
        0
    )::NUMBER AS TODAY_ASSIGNED_COUNT,

    COALESCE(
        counters.TOTAL_ASSIGNED_COUNT,
        0
    )::NUMBER AS TOTAL_ASSIGNED_COUNT,

    COALESCE(
        incidents.OPEN_INCIDENT_COUNT,
        0
    )::NUMBER AS OPEN_INCIDENT_COUNT,

    COALESCE(
        incidents.OPEN_CRITICAL_INCIDENT_COUNT,
        0
    )::NUMBER AS OPEN_CRITICAL_INCIDENT_COUNT,

    monitoring.MONITORING_RUN_ID,
    monitoring.MONITORING_STATUS,
    monitoring.MONITORING_REASON,

    monitoring.ACTUAL_OUTCOME_COUNT,
    monitoring.CANDIDATE_MAE,
    monitoring.CANDIDATE_ADVANTAGE_VS_RULE,

    monitoring.BMCS_BRIER_SCORE,
    monitoring.BMCS_ACCURACY_PCT,

    monitoring.AUTO_PAUSE_TRIGGERED_FLAG,
    monitoring.COMPLETED_AT
        AS LAST_MONITORED_AT,

    plan.PILOT_START_AT,
    plan.PILOT_END_AT,

    plan.CREATED_BY,
    plan.CREATED_AT,
    plan.STARTED_BY,
    plan.STARTED_AT,

    plan.UPDATED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_PLAN_CURRENT_V1
        plan

LEFT JOIN COUNTERS counters
    ON plan.PILOT_PLAN_ID =
       counters.PILOT_PLAN_ID

LEFT JOIN INCIDENTS incidents
    ON plan.PILOT_PLAN_ID =
       incidents.PILOT_PLAN_ID

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_MONITORING_LATEST_V1
        monitoring

    ON plan.PILOT_PLAN_ID =
       monitoring.PILOT_PLAN_ID;

-- ============================================================
-- PHASE 12B — VERIFICATION
--
-- No pilot, assignment, decision or incident is created.
-- ============================================================

SHOW PROCEDURES LIKE
    'CREATE_ML_PILOT_PLAN_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'UPSERT_ML_PILOT_SCOPE_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'START_ML_PILOT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RESOLVE_ML_PILOT_ASSIGNMENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RECORD_ML_PILOT_DECISION_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RECORD_ML_PILOT_INCIDENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'REVIEW_ML_PILOT_INCIDENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_PILOT_MONITORING_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'UPDATE_ML_PILOT_STATUS_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- Expected: 9.
SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE12B_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'CREATE_ML_PILOT_PLAN_V1',
      'UPSERT_ML_PILOT_SCOPE_V1',
      'START_ML_PILOT_V1',
      'RESOLVE_ML_PILOT_ASSIGNMENT_V1',
      'RECORD_ML_PILOT_DECISION_V1',
      'RECORD_ML_PILOT_INCIDENT_V1',
      'REVIEW_ML_PILOT_INCIDENT_V1',
      'RUN_ML_PILOT_MONITORING_V1',
      'UPDATE_ML_PILOT_STATUS_V1'
  );


-- Expected: zero rows.
SELECT
    PILOT_PLAN_ID,
    SIMULATION_ID,
    COUNT(*) AS DUPLICATE_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
GROUP BY
    PILOT_PLAN_ID,
    SIMULATION_ID
HAVING COUNT(*) > 1;


-- Expected: zero rows.
SELECT
    PILOT_PLAN_ID,
    SCOPE_TYPE,
    SCOPE_VALUE,
    COUNT(*) AS DUPLICATE_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_SCOPE_CURRENT_V1
GROUP BY
    PILOT_PLAN_ID,
    SCOPE_TYPE,
    SCOPE_VALUE
HAVING COUNT(*) > 1;


-- Expected: zero orphan decisions.
SELECT
    decision.PILOT_DECISION_ID
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_PILOT_DECISION_V1
        decision
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_PILOT_ASSIGNMENT_V1
        assignment
    ON decision.ASSIGNMENT_ID =
       assignment.ASSIGNMENT_ID
WHERE assignment.ASSIGNMENT_ID IS NULL;


-- Expected: zero invalid controlled-use rows.
SELECT
    COALESCE(
        COUNT_IF(
            FINAL_PILOT_SOURCE =
                'CANDIDATE_CONTROLLED'
            AND (
                CONTROLLED_USE_AUTHORIZED_FLAG = FALSE
                OR OVERALL_GUARDRAIL_PASS_FLAG = FALSE
                OR ENGINEER_APPROVED_FLAG = FALSE
                OR BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG = TRUE
                OR OFFICIAL_COST_CHANGED_FLAG = TRUE
            )
        ),
        0
    )::NUMBER AS INVALID_CONTROLLED_USE_ROWS
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_PILOT_DECISION_V1;


-- Expected after infrastructure deployment:
--   PILOT_PLAN_COUNT = 0
--   ACTIVE_PILOT_COUNT = 0
SELECT
    COUNT(*) AS PILOT_PLAN_COUNT,

    COALESCE(
        COUNT_IF(
            PILOT_STATUS = 'ACTIVE'
        ),
        0
    )::NUMBER AS ACTIVE_PILOT_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_PLAN_CURRENT_V1;


-- Negative, non-writing test. Expected status ERROR.
CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_PILOT_MONITORING_V1(
            'PHASE12B_NEGATIVE_MONITOR',
            'NONEXISTENT_PILOT_PLAN',
            'PHASE12B_VERIFICATION'
        );


-- Policies must still be unchanged.
SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,

    COALESCE(
        COUNT_IF(
            DEPLOYMENT_MODE = 'SHADOW'
        ),
        0
    )::NUMBER AS SHADOW_POLICY_COUNT,

    COALESCE(
        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG = TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
        ),
        0
    )::NUMBER AS AUTHORITY_ENABLED_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE12B_PILOT_DASHBOARD_V1
ORDER BY UPDATED_AT DESC;


WITH PROCEDURES AS (
    SELECT
        COUNT(DISTINCT PROCEDURE_NAME)
            AS PROCEDURE_COUNT
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'CREATE_ML_PILOT_PLAN_V1',
          'UPSERT_ML_PILOT_SCOPE_V1',
          'START_ML_PILOT_V1',
          'RESOLVE_ML_PILOT_ASSIGNMENT_V1',
          'RECORD_ML_PILOT_DECISION_V1',
          'RECORD_ML_PILOT_INCIDENT_V1',
          'REVIEW_ML_PILOT_INCIDENT_V1',
          'RUN_ML_PILOT_MONITORING_V1',
          'UPDATE_ML_PILOT_STATUS_V1'
      )
),
ASSIGNMENT_DUPLICATES AS (
    SELECT COUNT(*) AS DUPLICATE_KEY_COUNT
    FROM (
        SELECT
            PILOT_PLAN_ID,
            SIMULATION_ID
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_PILOT_ASSIGNMENT_CURRENT_V1
        GROUP BY
            PILOT_PLAN_ID,
            SIMULATION_ID
        HAVING COUNT(*) > 1
    )
),
SCOPE_DUPLICATES AS (
    SELECT COUNT(*) AS DUPLICATE_KEY_COUNT
    FROM (
        SELECT
            PILOT_PLAN_ID,
            SCOPE_TYPE,
            SCOPE_VALUE
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_PILOT_SCOPE_CURRENT_V1
        GROUP BY
            PILOT_PLAN_ID,
            SCOPE_TYPE,
            SCOPE_VALUE
        HAVING COUNT(*) > 1
    )
),
ORPHANS AS (
    SELECT COUNT(*) AS ORPHAN_DECISION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_DECISION_V1
            decision
    LEFT JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_ASSIGNMENT_V1
            assignment
        ON decision.ASSIGNMENT_ID =
           assignment.ASSIGNMENT_ID
    WHERE assignment.ASSIGNMENT_ID IS NULL
),
SAFETY AS (
    SELECT
        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE =
                    'CANDIDATE_CONTROLLED'
                AND (
                    CONTROLLED_USE_AUTHORIZED_FLAG = FALSE
                    OR OVERALL_GUARDRAIL_PASS_FLAG = FALSE
                    OR ENGINEER_APPROVED_FLAG = FALSE
                    OR BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG = TRUE
                    OR OFFICIAL_COST_CHANGED_FLAG = TRUE
                )
            ),
            0
        )::NUMBER AS INVALID_CONTROLLED_USE_ROWS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_PILOT_DECISION_V1
),
PILOTS AS (
    SELECT
        COUNT(*) AS PILOT_PLAN_COUNT,

        COALESCE(
            COUNT_IF(
                PILOT_STATUS = 'ACTIVE'
            ),
            0
        )::NUMBER AS ACTIVE_PILOT_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_PLAN_CURRENT_V1
),
POLICIES AS (
    SELECT
        COUNT(*) AS ACTIVE_POLICY_COUNT,

        COALESCE(
            COUNT_IF(
                DEPLOYMENT_MODE = 'SHADOW'
            ),
            0
        )::NUMBER AS SHADOW_POLICY_COUNT,

        COALESCE(
            COUNT_IF(
                AUTO_USE_ALLOWED_FLAG = TRUE
                OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
                OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
            ),
            0
        )::NUMBER AS AUTHORITY_ENABLED_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_DECISION_POLICY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            procedures.PROCEDURE_COUNT = 9
            AND assignment_duplicates
                .DUPLICATE_KEY_COUNT = 0
            AND scope_duplicates
                .DUPLICATE_KEY_COUNT = 0
            AND orphans
                .ORPHAN_DECISION_COUNT = 0
            AND safety
                .INVALID_CONTROLLED_USE_ROWS = 0
            AND pilots.PILOT_PLAN_COUNT = 0
            AND pilots.ACTIVE_PILOT_COUNT = 0
            AND policies.ACTIVE_POLICY_COUNT = 4
            AND policies.SHADOW_POLICY_COUNT = 4
            AND policies.AUTHORITY_ENABLED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_12B',

    'procedure_count',
        procedures.PROCEDURE_COUNT,

    'duplicate_assignment_keys',
        assignment_duplicates
            .DUPLICATE_KEY_COUNT,

    'duplicate_scope_keys',
        scope_duplicates
            .DUPLICATE_KEY_COUNT,

    'orphan_decision_count',
        orphans.ORPHAN_DECISION_COUNT,

    'invalid_controlled_use_rows',
        safety.INVALID_CONTROLLED_USE_ROWS,

    'pilot_plan_count',
        pilots.PILOT_PLAN_COUNT,

    'active_pilot_count',
        pilots.ACTIVE_PILOT_COUNT,

    'active_policy_count',
        policies.ACTIVE_POLICY_COUNT,

    'shadow_policy_count',
        policies.SHADOW_POLICY_COUNT,

    'authority_enabled_count',
        policies.AUTHORITY_ENABLED_COUNT,

    'pilot_authority',
        'INACTIVE_CONTROL_PLANE',

    'maximum_exposure_pct',
        25.0,

    'official_cost_changed',
        FALSE,

    'policy_changed',
        FALSE
) AS PHASE12B_RESULT

FROM PROCEDURES procedures
CROSS JOIN ASSIGNMENT_DUPLICATES assignment_duplicates
CROSS JOIN SCOPE_DUPLICATES scope_duplicates
CROSS JOIN ORPHANS orphans
CROSS JOIN SAFETY safety
CROSS JOIN PILOTS pilots
CROSS JOIN POLICIES policies;

-- ============================================================
-- PHASE 12C — PREFLIGHT
-- Exact context: SYSADMIN / KMAT_WH / KMAT_COST_MODEL_DB / CORE_ML
-- ============================================================

SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;

SHOW PROCEDURES LIKE 'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'UPDATE_ML_PILOT_STATUS_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'RUN_ML_PILOT_MONITORING_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DECISION_POLICY_V1'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2'),
        ('CORE_ML','ML_PILOT_PLAN_V1'),
        ('CORE_ML','VW_ML_PILOT_PLAN_CURRENT_V1'),
        ('CORE_ML','ML_PILOT_ASSIGNMENT_V1'),
        ('CORE_ML','VW_ML_PILOT_ASSIGNMENT_CURRENT_V1'),
        ('CORE_ML','ML_PILOT_DECISION_V1'),
        ('CORE_ML','VW_ML_PILOT_DECISION_CURRENT_V1'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1'),
        ('CORE_ML','ML_PILOT_INCIDENT_V1'),
        ('CORE_ML','ML_PILOT_MONITORING_RUN_V1'),
        ('CORE_ML','VW_ML_PILOT_MONITORING_LATEST_V1'),
        ('CORE_ML','ML_PILOT_EVENT_AUDIT_V1')
    AS required(SCHEMA_NAME, OBJECT_NAME)
),
FOUND_OBJECTS AS (
    SELECT TABLE_SCHEMA AS SCHEMA_NAME, TABLE_NAME AS OBJECT_NAME
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.TABLES
)
SELECT required.SCHEMA_NAME, required.OBJECT_NAME
FROM REQUIRED_OBJECTS required
LEFT JOIN FOUND_OBJECTS found
  ON required.SCHEMA_NAME = found.SCHEMA_NAME
 AND required.OBJECT_NAME = found.OBJECT_NAME
WHERE found.OBJECT_NAME IS NULL
ORDER BY required.SCHEMA_NAME, required.OBJECT_NAME;

WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','MODEL_DOMAIN'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','TARGET_MODE'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','FROM_POLICY_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','FROM_POLICY_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_MODEL_NAME'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_MODEL_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_FEATURE_SET_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','REQUEST_STATUS'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','EVIDENCE_VERSION'),
        ('CORE_ML','ML_PILOT_PLAN_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_PLAN_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','ML_PILOT_PLAN_V1','MODEL_DOMAIN'),
        ('CORE_ML','ML_PILOT_PLAN_V1','CANDIDATE_POLICY_ID'),
        ('CORE_ML','ML_PILOT_PLAN_V1','CANDIDATE_POLICY_VERSION'),
        ('CORE_ML','ML_PILOT_PLAN_V1','CANDIDATE_MODEL_NAME'),
        ('CORE_ML','ML_PILOT_PLAN_V1','CANDIDATE_MODEL_VERSION'),
        ('CORE_ML','ML_PILOT_PLAN_V1','CANDIDATE_FEATURE_SET_VERSION'),
        ('CORE_ML','ML_PILOT_PLAN_V1','PILOT_STATUS'),
        ('CORE_ML','ML_PILOT_PLAN_V1','EXPOSURE_PCT'),
        ('CORE_ML','ML_PILOT_PLAN_V1','STARTED_AT'),
        ('CORE_ML','ML_PILOT_PLAN_V1','LAST_STATUS_CHANGED_AT'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','PILOT_ASSIGNED_FLAG'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','FINAL_PILOT_SOURCE'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','CANDIDATE_EVALUATION_ELIGIBLE_FLAG'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','OUTCOME_AVAILABLE_FLAG'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','RULE_ABS_ERROR'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','CANDIDATE_ABS_ERROR'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','BMCS_BRIER_SCORE'),
        ('CORE_ML','VW_ML_PILOT_OUTCOME_DETAIL_V1','BMCS_CLASSIFICATION_CORRECT_FLAG'),
        ('CORE_ML','VW_ML_PILOT_MONITORING_LATEST_V1','MONITORING_STATUS'),
        ('CORE_ML','VW_ML_PILOT_MONITORING_LATEST_V1','AUTO_PAUSE_TRIGGERED_FLAG'),
        ('CORE_ML','VW_ML_PILOT_MONITORING_LATEST_V1','COMPLETED_AT'),

        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','POLICY_ID'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','POLICY_VERSION'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','DEPLOYMENT_MODE'),

        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2','PHASE12A_READINESS_STATUS'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2','BACKTEST_STATUS'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2','ACTIVATION_ELIGIBLE_V2_FLAG'),

        ('CORE_ML','ML_PILOT_ASSIGNMENT_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_ASSIGNMENT_V1','ASSIGNED_AT'),

        ('CORE_ML','ML_PILOT_DECISION_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_DECISION_V1','FINAL_PILOT_SOURCE'),
        ('CORE_ML','ML_PILOT_DECISION_V1','CONTROLLED_USE_AUTHORIZED_FLAG'),
        ('CORE_ML','ML_PILOT_DECISION_V1','OVERALL_GUARDRAIL_PASS_FLAG'),
        ('CORE_ML','ML_PILOT_DECISION_V1','OFFICIAL_COST_CHANGED_FLAG'),
        ('CORE_ML','ML_PILOT_DECISION_V1','BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG'),
        ('CORE_ML','ML_PILOT_DECISION_V1','UPDATED_AT'),

        ('CORE_ML','ML_PILOT_INCIDENT_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_INCIDENT_V1','INCIDENT_STATUS'),
        ('CORE_ML','ML_PILOT_INCIDENT_V1','INCIDENT_SEVERITY'),
        ('CORE_ML','ML_PILOT_INCIDENT_V1','UPDATED_AT'),

        ('CORE_ML','ML_PILOT_MONITORING_RUN_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_MONITORING_RUN_V1','AUTO_PAUSE_TRIGGERED_FLAG'),
        ('CORE_ML','ML_PILOT_MONITORING_RUN_V1','COMPLETED_AT'),

        ('CORE_ML','ML_PILOT_EVENT_AUDIT_V1','PILOT_PLAN_ID'),
        ('CORE_ML','ML_PILOT_EVENT_AUDIT_V1','EVENT_TYPE'),
        ('CORE_ML','ML_PILOT_EVENT_AUDIT_V1','EVENT_STATUS')
    AS required(SCHEMA_NAME, OBJECT_NAME, COLUMN_NAME)
)
SELECT required.SCHEMA_NAME, required.OBJECT_NAME, required.COLUMN_NAME
FROM REQUIRED_COLUMNS required
LEFT JOIN KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.COLUMNS found
  ON required.SCHEMA_NAME = found.TABLE_SCHEMA
 AND required.OBJECT_NAME = found.TABLE_NAME
 AND required.COLUMN_NAME = found.COLUMN_NAME
WHERE found.COLUMN_NAME IS NULL
ORDER BY required.SCHEMA_NAME, required.OBJECT_NAME, required.COLUMN_NAME;

SELECT COUNT(DISTINCT PROCEDURE_NAME) AS PHASE12C_REQUIRED_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',
      'UPDATE_ML_PILOT_STATUS_V1',
      'RUN_ML_PILOT_MONITORING_V1'
  );

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,
    COALESCE(COUNT_IF(DEPLOYMENT_MODE = 'SHADOW'), 0)::NUMBER
        AS SHADOW_POLICY_COUNT,
    COALESCE(
        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG = TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
        ),
        0
    )::NUMBER AS AUTHORITY_ENABLED_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1;

-- ============================================================
-- PHASE 12C — PILOT EXIT, PRODUCTION READINESS AND PROMOTION GATE
--
-- Deployment creates control infrastructure only.
-- It does not create an exit request, production link,
-- activate a policy, or change official cost.
--
-- OBJECT_AGG calls: 0
-- VARIANT scripting variables in VALUES: 0
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 (
        EXIT_POLICY_ID VARCHAR NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,
        EXIT_POLICY_VERSION VARCHAR NOT NULL,
        POLICY_STATUS VARCHAR NOT NULL,

        MIN_PILOT_DURATION_DAYS FLOAT NOT NULL,
        MIN_ASSIGNED_COUNT NUMBER NOT NULL,
        MIN_CONTROLLED_DECISION_COUNT NUMBER NOT NULL,
        MIN_ACTUAL_OUTCOME_COUNT NUMBER NOT NULL,

        MAX_CANDIDATE_MAE FLOAT,
        MIN_CANDIDATE_ADVANTAGE_VS_RULE FLOAT,
        MAX_BMCS_BRIER_SCORE FLOAT,
        MIN_BMCS_ACCURACY_PCT FLOAT,

        MAX_FALLBACK_RATE_PCT FLOAT NOT NULL,
        MAX_OPEN_INCIDENT_COUNT NUMBER NOT NULL,
        MAX_OPEN_CRITICAL_INCIDENT_COUNT NUMBER NOT NULL,
        MAX_TOTAL_CRITICAL_INCIDENT_COUNT NUMBER NOT NULL,
        MAX_UNAUTHORISED_CONTROLLED_USE_COUNT NUMBER NOT NULL,
        MAX_GUARDRAIL_VIOLATION_COUNT NUMBER NOT NULL,
        MAX_OFFICIAL_COST_CHANGE_COUNT NUMBER NOT NULL,
        MAX_BMCS_DIRECT_COST_IMPACT_COUNT NUMBER NOT NULL,
        MAX_AUTO_PAUSE_EVENT_COUNT NUMBER NOT NULL,
        MAX_MANUAL_PAUSE_EVENT_COUNT NUMBER NOT NULL,
        MAX_EXPOSURE_PCT FLOAT NOT NULL,

        REQUIRE_LATEST_MONITORING_HEALTHY_FLAG BOOLEAN NOT NULL,

        EFFECTIVE_FROM TIMESTAMP_NTZ NOT NULL,
        EFFECTIVE_TO TIMESTAMP_NTZ,

        APPROVED_BY VARCHAR NOT NULL,
        APPROVED_AT TIMESTAMP_NTZ NOT NULL,

        CREATED_BY VARCHAR NOT NULL,
        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        UPDATED_BY VARCHAR NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        COMMENTS VARCHAR
    );

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 target
USING (
    SELECT * FROM VALUES
        ('PILOT_EXIT_CSS_V1','CSS','PHASE12C_EXIT_V1','ACTIVE',
         7.0,20,18,20,0.02,0.0,NULL::FLOAT,NULL::FLOAT,
         10.0,0,0,0,0,0,0,0,0,0,25.0,TRUE,
         'Production readiness threshold for CSS.'),
        ('PILOT_EXIT_FMIS_V1','FMIS','PHASE12C_EXIT_V1','ACTIVE',
         7.0,20,18,20,0.02,0.0,NULL::FLOAT,NULL::FLOAT,
         10.0,0,0,0,0,0,0,0,0,0,25.0,TRUE,
         'Production readiness threshold for FMIS.'),
        ('PILOT_EXIT_TDS_V1','TDS','PHASE12C_EXIT_V1','ACTIVE',
         7.0,20,18,20,0.10,0.0,NULL::FLOAT,NULL::FLOAT,
         10.0,0,0,0,0,0,0,0,0,0,25.0,TRUE,
         'Production readiness threshold for TDS.'),
        ('PILOT_EXIT_BMCS_V1','BMCS','PHASE12C_EXIT_V1','ACTIVE',
         7.0,30,27,30,NULL::FLOAT,NULL::FLOAT,0.10,90.0,
         10.0,0,0,0,0,0,0,0,0,0,25.0,TRUE,
         'Production readiness threshold for BMCS.')
    AS seed(
        EXIT_POLICY_ID, MODEL_DOMAIN, EXIT_POLICY_VERSION, POLICY_STATUS,
        MIN_PILOT_DURATION_DAYS, MIN_ASSIGNED_COUNT,
        MIN_CONTROLLED_DECISION_COUNT, MIN_ACTUAL_OUTCOME_COUNT,
        MAX_CANDIDATE_MAE, MIN_CANDIDATE_ADVANTAGE_VS_RULE,
        MAX_BMCS_BRIER_SCORE, MIN_BMCS_ACCURACY_PCT,
        MAX_FALLBACK_RATE_PCT, MAX_OPEN_INCIDENT_COUNT,
        MAX_OPEN_CRITICAL_INCIDENT_COUNT,
        MAX_TOTAL_CRITICAL_INCIDENT_COUNT,
        MAX_UNAUTHORISED_CONTROLLED_USE_COUNT,
        MAX_GUARDRAIL_VIOLATION_COUNT,
        MAX_OFFICIAL_COST_CHANGE_COUNT,
        MAX_BMCS_DIRECT_COST_IMPACT_COUNT,
        MAX_AUTO_PAUSE_EVENT_COUNT,
        MAX_MANUAL_PAUSE_EVENT_COUNT,
        MAX_EXPOSURE_PCT,
        REQUIRE_LATEST_MONITORING_HEALTHY_FLAG,
        COMMENTS
    )
) source
ON target.EXIT_POLICY_ID = source.EXIT_POLICY_ID
WHEN NOT MATCHED THEN INSERT (
    EXIT_POLICY_ID, MODEL_DOMAIN, EXIT_POLICY_VERSION, POLICY_STATUS,
    MIN_PILOT_DURATION_DAYS, MIN_ASSIGNED_COUNT,
    MIN_CONTROLLED_DECISION_COUNT, MIN_ACTUAL_OUTCOME_COUNT,
    MAX_CANDIDATE_MAE, MIN_CANDIDATE_ADVANTAGE_VS_RULE,
    MAX_BMCS_BRIER_SCORE, MIN_BMCS_ACCURACY_PCT,
    MAX_FALLBACK_RATE_PCT, MAX_OPEN_INCIDENT_COUNT,
    MAX_OPEN_CRITICAL_INCIDENT_COUNT,
    MAX_TOTAL_CRITICAL_INCIDENT_COUNT,
    MAX_UNAUTHORISED_CONTROLLED_USE_COUNT,
    MAX_GUARDRAIL_VIOLATION_COUNT,
    MAX_OFFICIAL_COST_CHANGE_COUNT,
    MAX_BMCS_DIRECT_COST_IMPACT_COUNT,
    MAX_AUTO_PAUSE_EVENT_COUNT,
    MAX_MANUAL_PAUSE_EVENT_COUNT,
    MAX_EXPOSURE_PCT,
    REQUIRE_LATEST_MONITORING_HEALTHY_FLAG,
    EFFECTIVE_FROM, EFFECTIVE_TO,
    APPROVED_BY, APPROVED_AT,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT, COMMENTS
)
VALUES (
    source.EXIT_POLICY_ID, source.MODEL_DOMAIN,
    source.EXIT_POLICY_VERSION, source.POLICY_STATUS,
    source.MIN_PILOT_DURATION_DAYS, source.MIN_ASSIGNED_COUNT,
    source.MIN_CONTROLLED_DECISION_COUNT,
    source.MIN_ACTUAL_OUTCOME_COUNT,
    source.MAX_CANDIDATE_MAE,
    source.MIN_CANDIDATE_ADVANTAGE_VS_RULE,
    source.MAX_BMCS_BRIER_SCORE,
    source.MIN_BMCS_ACCURACY_PCT,
    source.MAX_FALLBACK_RATE_PCT,
    source.MAX_OPEN_INCIDENT_COUNT,
    source.MAX_OPEN_CRITICAL_INCIDENT_COUNT,
    source.MAX_TOTAL_CRITICAL_INCIDENT_COUNT,
    source.MAX_UNAUTHORISED_CONTROLLED_USE_COUNT,
    source.MAX_GUARDRAIL_VIOLATION_COUNT,
    source.MAX_OFFICIAL_COST_CHANGE_COUNT,
    source.MAX_BMCS_DIRECT_COST_IMPACT_COUNT,
    source.MAX_AUTO_PAUSE_EVENT_COUNT,
    source.MAX_MANUAL_PAUSE_EVENT_COUNT,
    source.MAX_EXPOSURE_PCT,
    source.REQUIRE_LATEST_MONITORING_HEALTHY_FLAG,
    CURRENT_TIMESTAMP(), NULL::TIMESTAMP_NTZ,
    CURRENT_USER(), CURRENT_TIMESTAMP(),
    CURRENT_USER(), CURRENT_TIMESTAMP(),
    CURRENT_USER(), CURRENT_TIMESTAMP(), source.COMMENTS
);

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_POLICY_CURRENT_V1
AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1
WHERE POLICY_STATUS = 'ACTIVE'
  AND EFFECTIVE_FROM <= CURRENT_TIMESTAMP()
  AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO > CURRENT_TIMESTAMP())
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY MODEL_DOMAIN
    ORDER BY EFFECTIVE_FROM DESC, UPDATED_AT DESC, EXIT_POLICY_ID DESC
) = 1;


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 (
        REQUIREMENT_ID VARCHAR NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,
        SIGNOFF_STAGE VARCHAR NOT NULL,
        REQUIRED_FLAG BOOLEAN NOT NULL,
        REQUIREMENT_STATUS VARCHAR NOT NULL,
        CREATED_BY VARCHAR NOT NULL,
        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        UPDATED_BY VARCHAR NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 target
USING (
    SELECT * FROM VALUES
        ('CSS_TECHNICAL','CSS','TECHNICAL',TRUE,'ACTIVE'),
        ('CSS_BUSINESS','CSS','BUSINESS',TRUE,'ACTIVE'),
        ('CSS_RISK','CSS','RISK',TRUE,'ACTIVE'),
        ('CSS_FINANCE','CSS','FINANCE',TRUE,'ACTIVE'),
        ('FMIS_TECHNICAL','FMIS','TECHNICAL',TRUE,'ACTIVE'),
        ('FMIS_BUSINESS','FMIS','BUSINESS',TRUE,'ACTIVE'),
        ('FMIS_RISK','FMIS','RISK',TRUE,'ACTIVE'),
        ('FMIS_FINANCE','FMIS','FINANCE',TRUE,'ACTIVE'),
        ('TDS_TECHNICAL','TDS','TECHNICAL',TRUE,'ACTIVE'),
        ('TDS_BUSINESS','TDS','BUSINESS',TRUE,'ACTIVE'),
        ('TDS_RISK','TDS','RISK',TRUE,'ACTIVE'),
        ('TDS_FINANCE','TDS','FINANCE',TRUE,'ACTIVE'),
        ('BMCS_TECHNICAL','BMCS','TECHNICAL',TRUE,'ACTIVE'),
        ('BMCS_BUSINESS','BMCS','BUSINESS',TRUE,'ACTIVE'),
        ('BMCS_RISK','BMCS','RISK',TRUE,'ACTIVE')
    AS seed(
        REQUIREMENT_ID, MODEL_DOMAIN, SIGNOFF_STAGE,
        REQUIRED_FLAG, REQUIREMENT_STATUS
    )
) source
ON target.REQUIREMENT_ID = source.REQUIREMENT_ID
WHEN NOT MATCHED THEN INSERT (
    REQUIREMENT_ID, MODEL_DOMAIN, SIGNOFF_STAGE,
    REQUIRED_FLAG, REQUIREMENT_STATUS,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT
)
VALUES (
    source.REQUIREMENT_ID, source.MODEL_DOMAIN, source.SIGNOFF_STAGE,
    source.REQUIRED_FLAG, source.REQUIREMENT_STATUS,
    CURRENT_USER(), CURRENT_TIMESTAMP(),
    CURRENT_USER(), CURRENT_TIMESTAMP()
);

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1
WHERE REQUIRED_FLAG = TRUE
  AND REQUIREMENT_STATUS = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY MODEL_DOMAIN, SIGNOFF_STAGE
    ORDER BY UPDATED_AT DESC, REQUIREMENT_ID DESC
) = 1;


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 (
        EXIT_REQUEST_ID VARCHAR NOT NULL,
        PILOT_PLAN_ID VARCHAR NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,

        CONTROLLED_DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
        CONTROLLED_POLICY_ID VARCHAR NOT NULL,
        CONTROLLED_POLICY_VERSION VARCHAR NOT NULL,

        CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
        CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
        CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,

        REQUEST_STATUS VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,
        LATEST_ASSESSMENT_ID VARCHAR,

        REQUEST_REASON VARCHAR NOT NULL,
        REQUESTED_BY VARCHAR NOT NULL,
        REQUESTED_AT TIMESTAMP_NTZ NOT NULL,

        CLOSED_BY VARCHAR,
        CLOSED_AT TIMESTAMP_NTZ,
        CLOSURE_REASON VARCHAR,

        CANCELLED_BY VARCHAR,
        CANCELLED_AT TIMESTAMP_NTZ,
        CANCELLATION_REASON VARCHAR,

        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 (
        ASSESSMENT_ID VARCHAR NOT NULL,
        EXIT_REQUEST_ID VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,

        PILOT_PLAN_ID VARCHAR NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,

        EXIT_POLICY_ID VARCHAR NOT NULL,
        EXIT_POLICY_VERSION VARCHAR NOT NULL,

        PILOT_STATUS VARCHAR NOT NULL,
        PILOT_DURATION_DAYS FLOAT,
        EXPOSURE_PCT FLOAT,

        ASSIGNED_COUNT NUMBER NOT NULL,
        CONTROLLED_DECISION_COUNT NUMBER NOT NULL,
        FALLBACK_DECISION_COUNT NUMBER NOT NULL,
        FALLBACK_RATE_PCT FLOAT,
        ACTUAL_OUTCOME_COUNT NUMBER NOT NULL,

        RULE_MAE FLOAT,
        CANDIDATE_MAE FLOAT,
        CANDIDATE_RMSE FLOAT,
        CANDIDATE_ADVANTAGE_VS_RULE FLOAT,

        BMCS_BRIER_SCORE FLOAT,
        BMCS_ACCURACY_PCT FLOAT,

        OPEN_INCIDENT_COUNT NUMBER NOT NULL,
        OPEN_CRITICAL_INCIDENT_COUNT NUMBER NOT NULL,
        TOTAL_CRITICAL_INCIDENT_COUNT NUMBER NOT NULL,

        UNAUTHORISED_CONTROLLED_USE_COUNT NUMBER NOT NULL,
        GUARDRAIL_VIOLATION_COUNT NUMBER NOT NULL,
        OFFICIAL_COST_CHANGE_COUNT NUMBER NOT NULL,
        BMCS_DIRECT_COST_IMPACT_COUNT NUMBER NOT NULL,
        AUTO_PAUSE_EVENT_COUNT NUMBER NOT NULL,
        MANUAL_PAUSE_EVENT_COUNT NUMBER NOT NULL,

        LATEST_MONITORING_RUN_ID VARCHAR,
        LATEST_MONITORING_STATUS VARCHAR,
        LATEST_MONITORING_AUTO_PAUSE_FLAG BOOLEAN,
        LATEST_MONITORING_AT TIMESTAMP_NTZ,

        DURATION_PASS_FLAG BOOLEAN NOT NULL,
        ASSIGNMENT_COUNT_PASS_FLAG BOOLEAN NOT NULL,
        CONTROLLED_DECISION_COUNT_PASS_FLAG BOOLEAN NOT NULL,
        OUTCOME_COUNT_PASS_FLAG BOOLEAN NOT NULL,
        PERFORMANCE_PASS_FLAG BOOLEAN NOT NULL,
        FALLBACK_RATE_PASS_FLAG BOOLEAN NOT NULL,
        INCIDENT_PASS_FLAG BOOLEAN NOT NULL,
        CONTROL_INTEGRITY_PASS_FLAG BOOLEAN NOT NULL,
        EXPOSURE_PASS_FLAG BOOLEAN NOT NULL,
        MONITORING_PASS_FLAG BOOLEAN NOT NULL,

        ASSESSMENT_STATUS VARCHAR NOT NULL,
        ASSESSMENT_REASON VARCHAR NOT NULL,

        ASSESSED_BY VARCHAR NOT NULL,
        STARTED_AT TIMESTAMP_NTZ NOT NULL,
        COMPLETED_AT TIMESTAMP_NTZ NOT NULL,
        CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 (
        SIGNOFF_ID VARCHAR NOT NULL,
        EXIT_REQUEST_ID VARCHAR NOT NULL,
        EVIDENCE_VERSION NUMBER NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,
        SIGNOFF_STAGE VARCHAR NOT NULL,
        REVIEW_ACTION VARCHAR NOT NULL,
        REVIEW_NOTE VARCHAR NOT NULL,
        REVIEWED_BY VARCHAR NOT NULL,
        REVIEWED_AT TIMESTAMP_NTZ NOT NULL
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 (
        PROMOTION_LINK_ID VARCHAR NOT NULL,

        PRODUCTION_DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
        PRODUCTION_EVIDENCE_VERSION NUMBER NOT NULL,

        PILOT_EXIT_REQUEST_ID VARCHAR NOT NULL,
        PILOT_EXIT_EVIDENCE_VERSION NUMBER NOT NULL,

        PILOT_PLAN_ID VARCHAR NOT NULL,
        MODEL_DOMAIN VARCHAR NOT NULL,

        CONTROLLED_POLICY_ID VARCHAR NOT NULL,
        CONTROLLED_POLICY_VERSION VARCHAR NOT NULL,

        PRODUCTION_CANDIDATE_POLICY_ID VARCHAR NOT NULL,
        PRODUCTION_CANDIDATE_POLICY_VERSION VARCHAR NOT NULL,

        CANDIDATE_MODEL_NAME VARCHAR NOT NULL,
        CANDIDATE_MODEL_VERSION VARCHAR NOT NULL,
        CANDIDATE_FEATURE_SET_VERSION VARCHAR NOT NULL,

        LINK_STATUS VARCHAR NOT NULL,
        LINK_REASON VARCHAR NOT NULL,

        REGISTERED_BY VARCHAR NOT NULL,
        REGISTERED_AT TIMESTAMP_NTZ NOT NULL,
        UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID VARCHAR NOT NULL,
        EVENT_TYPE VARCHAR NOT NULL,

        EXIT_REQUEST_ID VARCHAR,
        EVIDENCE_VERSION NUMBER,
        ASSESSMENT_ID VARCHAR,
        SIGNOFF_ID VARCHAR,
        PROMOTION_LINK_ID VARCHAR,

        PILOT_PLAN_ID VARCHAR,
        PRODUCTION_DEPLOYMENT_REQUEST_ID VARCHAR,
        MODEL_DOMAIN VARCHAR,

        EVENT_STATUS VARCHAR NOT NULL,
        EVENT_REASON VARCHAR NOT NULL,
        EVENT_ACTOR VARCHAR NOT NULL,
        EVENT_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_ASSESSMENT_LATEST_V1
AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY EXIT_REQUEST_ID, EVIDENCE_VERSION
    ORDER BY COMPLETED_AT DESC, CREATED_AT DESC, ASSESSMENT_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_SIGNOFF_CURRENT_V1
AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY EXIT_REQUEST_ID, EVIDENCE_VERSION, SIGNOFF_STAGE
    ORDER BY REVIEWED_AT DESC, SIGNOFF_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PRODUCTION_PROMOTION_LINK_CURRENT_V1
AS
SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
WHERE LINK_STATUS = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PRODUCTION_DEPLOYMENT_REQUEST_ID, PRODUCTION_EVIDENCE_VERSION
    ORDER BY REGISTERED_AT DESC, PROMOTION_LINK_ID DESC
) = 1;

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_PILOT_EXIT_REQUEST_V1(
        P_EXIT_REQUEST_ID VARCHAR,
        P_PILOT_PLAN_ID VARCHAR,
        P_REQUEST_REASON VARCHAR,
        P_REQUESTED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_REQUEST_COUNT NUMBER DEFAULT 0;
    V_OPEN_PLAN_REQUEST_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_DEPLOYMENT_REQUEST_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_POLICY_MATCH_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_CONTROLLED_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_CONTROLLED_REQUEST_STATUS VARCHAR;
    V_CONTROLLED_POLICY_ID VARCHAR;
    V_CONTROLLED_POLICY_VERSION VARCHAR;
    V_CANDIDATE_MODEL_NAME VARCHAR;
    V_CANDIDATE_MODEL_VERSION VARCHAR;
    V_CANDIDATE_FEATURE_SET_VERSION VARCHAR;
    V_PILOT_STATUS VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_EXIT_REQUEST_ID)) = 0
        OR P_PILOT_PLAN_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_PLAN_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exit request ID and pilot plan ID are required.''
        );
    END IF;

    IF (
        P_REQUEST_REASON IS NULL
        OR LENGTH(TRIM(P_REQUEST_REASON)) = 0
        OR P_REQUESTED_BY IS NULL
        OR LENGTH(TRIM(P_REQUESTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Request reason and requester are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_REQUEST_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_EXISTING_REQUEST_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''EXIT_REQUEST_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(MODEL_DOMAIN),
        MAX(TARGET_MODE),
        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),
        MAX(CANDIDATE_MODEL_NAME),
        MAX(CANDIDATE_MODEL_VERSION),
        MAX(CANDIDATE_FEATURE_SET_VERSION),
        MAX(PILOT_STATUS)
    INTO
        :V_PLAN_COUNT,
        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,
        :V_CONTROLLED_DEPLOYMENT_REQUEST_ID,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,
        :V_PILOT_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_PLAN_CURRENT_V1
    WHERE PILOT_PLAN_ID = :P_PILOT_PLAN_ID;

    IF (V_PLAN_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot plan is required.'',
            ''pilot_plan_count'', V_PLAN_COUNT
        );
    END IF;

    IF (
        V_TARGET_MODE <> ''CONTROLLED''
        OR V_PILOT_STATUS <> ''STOPPED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Pilot exit requires a STOPPED CONTROLLED pilot.'',
            ''target_mode'', V_TARGET_MODE,
            ''pilot_status'', V_PILOT_STATUS
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(REQUEST_STATUS)
    INTO
        :V_DEPLOYMENT_REQUEST_COUNT,
        :V_CONTROLLED_REQUEST_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :V_CONTROLLED_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND TARGET_MODE = ''CONTROLLED''
      AND CANDIDATE_POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND CANDIDATE_POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION;

    IF (
        V_DEPLOYMENT_REQUEST_COUNT <> 1
        OR V_CONTROLLED_REQUEST_STATUS <> ''ACTIVATED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The exact CONTROLLED deployment request must remain ACTIVATED.'',
            ''deployment_request_count'', V_DEPLOYMENT_REQUEST_COUNT,
            ''request_status'', V_CONTROLLED_REQUEST_STATUS
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_ACTIVE_POLICY_MATCH_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION
      AND DEPLOYMENT_MODE = ''CONTROLLED'';

    IF (V_ACTIVE_POLICY_MATCH_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The exact pilot policy must remain the active CONTROLLED policy.''
        );
    END IF;

    SELECT COALESCE(
        COUNT_IF(
            REQUEST_STATUS NOT IN (
                ''CANCELLED'',
                ''REJECTED'',
                ''CLOSED_PASS''
            )
        ),
        0
    )::NUMBER
    INTO :V_OPEN_PLAN_REQUEST_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    WHERE PILOT_PLAN_ID = :P_PILOT_PLAN_ID;

    IF (V_OPEN_PLAN_REQUEST_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''An open pilot-exit request already exists for this pilot.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 (
        EXIT_REQUEST_ID, PILOT_PLAN_ID, MODEL_DOMAIN,
        CONTROLLED_DEPLOYMENT_REQUEST_ID,
        CONTROLLED_POLICY_ID, CONTROLLED_POLICY_VERSION,
        CANDIDATE_MODEL_NAME, CANDIDATE_MODEL_VERSION,
        CANDIDATE_FEATURE_SET_VERSION,
        REQUEST_STATUS, EVIDENCE_VERSION, LATEST_ASSESSMENT_ID,
        REQUEST_REASON, REQUESTED_BY, REQUESTED_AT,
        CLOSED_BY, CLOSED_AT, CLOSURE_REASON,
        CANCELLED_BY, CANCELLED_AT, CANCELLATION_REASON,
        CREATED_AT, UPDATED_AT
    )
    SELECT
        TRIM(:P_EXIT_REQUEST_ID),
        TRIM(:P_PILOT_PLAN_ID),
        :V_MODEL_DOMAIN,
        :V_CONTROLLED_DEPLOYMENT_REQUEST_ID,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_CANDIDATE_MODEL_NAME,
        :V_CANDIDATE_MODEL_VERSION,
        :V_CANDIDATE_FEATURE_SET_VERSION,
        ''DRAFT'', 0, NULL::VARCHAR,
        TRIM(:P_REQUEST_REASON),
        TRIM(:P_REQUESTED_BY),
        CURRENT_TIMESTAMP(),
        NULL::VARCHAR, NULL::TIMESTAMP_NTZ, NULL::VARCHAR,
        NULL::VARCHAR, NULL::TIMESTAMP_NTZ, NULL::VARCHAR,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Pilot-exit request insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PILOT_EXIT_REQUEST_CREATED'',
        TRIM(:P_EXIT_REQUEST_ID), 0,
        NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR,
        TRIM(:P_PILOT_PLAN_ID), NULL::VARCHAR,
        :V_MODEL_DOMAIN, ''DRAFT'', TRIM(:P_REQUEST_REASON),
        TRIM(:P_REQUESTED_BY), CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''exit_request_id'', P_EXIT_REQUEST_ID,
        ''pilot_plan_id'', P_PILOT_PLAN_ID,
        ''model_domain'', V_MODEL_DOMAIN,
        ''request_status'', ''DRAFT'',
        ''evidence_version'', 0,
        ''controlled_deployment_request_id'', V_CONTROLLED_DEPLOYMENT_REQUEST_ID,
        ''controlled_policy_id'', V_CONTROLLED_POLICY_ID,
        ''controlled_policy_version'', V_CONTROLLED_POLICY_VERSION,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_METRICS_V1
AS
WITH OUTCOMES AS (
    SELECT
        PILOT_PLAN_ID,

        COALESCE(COUNT_IF(PILOT_ASSIGNED_FLAG = TRUE), 0)::NUMBER
            AS ASSIGNED_COUNT,

        COALESCE(
            COUNT_IF(FINAL_PILOT_SOURCE = 'CANDIDATE_CONTROLLED'),
            0
        )::NUMBER AS CONTROLLED_DECISION_COUNT,

        COALESCE(
            COUNT_IF(FINAL_PILOT_SOURCE = 'DETERMINISTIC_FALLBACK'),
            0
        )::NUMBER AS FALLBACK_DECISION_COUNT,

        COALESCE(
            COUNT_IF(
                OUTCOME_AVAILABLE_FLAG = TRUE
                AND CANDIDATE_EVALUATION_ELIGIBLE_FLAG = TRUE
            ),
            0
        )::NUMBER AS ACTUAL_OUTCOME_COUNT,

        AVG(RULE_ABS_ERROR)::FLOAT AS RULE_MAE,
        AVG(CANDIDATE_ABS_ERROR)::FLOAT AS CANDIDATE_MAE,

        SQRT(
            AVG(
                POWER(CANDIDATE_ABS_ERROR, 2)
            )
        )::FLOAT AS CANDIDATE_RMSE,

        AVG(BMCS_BRIER_SCORE)::FLOAT AS BMCS_BRIER_SCORE,

        IFF(
            COALESCE(
                COUNT_IF(
                    BMCS_CLASSIFICATION_CORRECT_FLAG IS NOT NULL
                ),
                0
            ) = 0,
            NULL::FLOAT,
            (
                COALESCE(
                    COUNT_IF(
                        BMCS_CLASSIFICATION_CORRECT_FLAG = TRUE
                    ),
                    0
                )
                /
                NULLIF(
                    COALESCE(
                        COUNT_IF(
                            BMCS_CLASSIFICATION_CORRECT_FLAG IS NOT NULL
                        ),
                        0
                    ),
                    0
                )
            ) * 100.0
        )::FLOAT AS BMCS_ACCURACY_PCT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_OUTCOME_DETAIL_V1
    GROUP BY PILOT_PLAN_ID
),
INCIDENTS AS (
    SELECT
        PILOT_PLAN_ID,
        COALESCE(COUNT_IF(INCIDENT_STATUS = 'OPEN'), 0)::NUMBER
            AS OPEN_INCIDENT_COUNT,
        COALESCE(
            COUNT_IF(
                INCIDENT_STATUS = 'OPEN'
                AND INCIDENT_SEVERITY = 'CRITICAL'
            ),
            0
        )::NUMBER AS OPEN_CRITICAL_INCIDENT_COUNT,
        COALESCE(
            COUNT_IF(INCIDENT_SEVERITY = 'CRITICAL'),
            0
        )::NUMBER AS TOTAL_CRITICAL_INCIDENT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    GROUP BY PILOT_PLAN_ID
),
MONITORING_HISTORY AS (
    SELECT
        PILOT_PLAN_ID,
        COALESCE(
            COUNT_IF(AUTO_PAUSE_TRIGGERED_FLAG = TRUE),
            0
        )::NUMBER AS AUTO_PAUSE_EVENT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1
    GROUP BY PILOT_PLAN_ID
),
STATUS_EVENTS AS (
    SELECT
        PILOT_PLAN_ID,
        COALESCE(
            COUNT_IF(
                EVENT_TYPE = 'PILOT_STATUS_CHANGED'
                AND EVENT_STATUS = 'PAUSED'
            ),
            0
        )::NUMBER AS MANUAL_PAUSE_EVENT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1
    GROUP BY PILOT_PLAN_ID
),
CONTROLS AS (
    SELECT
        PILOT_PLAN_ID,
        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE = 'CANDIDATE_CONTROLLED'
                AND CONTROLLED_USE_AUTHORIZED_FLAG = FALSE
            ),
            0
        )::NUMBER AS UNAUTHORISED_CONTROLLED_USE_COUNT,
        COALESCE(
            COUNT_IF(
                FINAL_PILOT_SOURCE = 'CANDIDATE_CONTROLLED'
                AND OVERALL_GUARDRAIL_PASS_FLAG = FALSE
            ),
            0
        )::NUMBER AS GUARDRAIL_VIOLATION_COUNT,
        COALESCE(
            COUNT_IF(OFFICIAL_COST_CHANGED_FLAG = TRUE),
            0
        )::NUMBER AS OFFICIAL_COST_CHANGE_COUNT,
        COALESCE(
            COUNT_IF(BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG = TRUE),
            0
        )::NUMBER AS BMCS_DIRECT_COST_IMPACT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_DECISION_CURRENT_V1
    GROUP BY PILOT_PLAN_ID
)
SELECT
    plan.PILOT_PLAN_ID,
    plan.DEPLOYMENT_REQUEST_ID AS CONTROLLED_DEPLOYMENT_REQUEST_ID,
    plan.MODEL_DOMAIN,
    plan.CANDIDATE_POLICY_ID AS CONTROLLED_POLICY_ID,
    plan.CANDIDATE_POLICY_VERSION AS CONTROLLED_POLICY_VERSION,
    plan.CANDIDATE_MODEL_NAME,
    plan.CANDIDATE_MODEL_VERSION,
    plan.CANDIDATE_FEATURE_SET_VERSION,

    plan.PILOT_STATUS,
    plan.STARTED_AT AS PILOT_STARTED_AT,
    plan.LAST_STATUS_CHANGED_AT AS PILOT_STOPPED_AT,

    IFF(
        plan.STARTED_AT IS NOT NULL
        AND plan.LAST_STATUS_CHANGED_AT IS NOT NULL
        AND plan.PILOT_STATUS = 'STOPPED',
        DATEDIFF(
            'second',
            plan.STARTED_AT,
            plan.LAST_STATUS_CHANGED_AT
        ) / 86400.0,
        NULL::FLOAT
    ) AS PILOT_DURATION_DAYS,

    plan.EXPOSURE_PCT,

    COALESCE(outcomes.ASSIGNED_COUNT, 0)::NUMBER
        AS ASSIGNED_COUNT,
    COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)::NUMBER
        AS CONTROLLED_DECISION_COUNT,
    COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)::NUMBER
        AS FALLBACK_DECISION_COUNT,

    IFF(
        COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)
        + COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0) = 0,
        NULL::FLOAT,
        (
            COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)
            /
            (
                COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)
                + COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)
            )
        ) * 100.0
    ) AS FALLBACK_RATE_PCT,

    COALESCE(outcomes.ACTUAL_OUTCOME_COUNT, 0)::NUMBER
        AS ACTUAL_OUTCOME_COUNT,

    outcomes.RULE_MAE,
    outcomes.CANDIDATE_MAE,
    outcomes.CANDIDATE_RMSE,

    IFF(
        outcomes.RULE_MAE IS NOT NULL
        AND outcomes.CANDIDATE_MAE IS NOT NULL,
        outcomes.RULE_MAE - outcomes.CANDIDATE_MAE,
        NULL::FLOAT
    ) AS CANDIDATE_ADVANTAGE_VS_RULE,

    outcomes.BMCS_BRIER_SCORE,
    outcomes.BMCS_ACCURACY_PCT,

    COALESCE(incidents.OPEN_INCIDENT_COUNT, 0)::NUMBER
        AS OPEN_INCIDENT_COUNT,
    COALESCE(incidents.OPEN_CRITICAL_INCIDENT_COUNT, 0)::NUMBER
        AS OPEN_CRITICAL_INCIDENT_COUNT,
    COALESCE(incidents.TOTAL_CRITICAL_INCIDENT_COUNT, 0)::NUMBER
        AS TOTAL_CRITICAL_INCIDENT_COUNT,

    COALESCE(controls.UNAUTHORISED_CONTROLLED_USE_COUNT, 0)::NUMBER
        AS UNAUTHORISED_CONTROLLED_USE_COUNT,
    COALESCE(controls.GUARDRAIL_VIOLATION_COUNT, 0)::NUMBER
        AS GUARDRAIL_VIOLATION_COUNT,
    COALESCE(controls.OFFICIAL_COST_CHANGE_COUNT, 0)::NUMBER
        AS OFFICIAL_COST_CHANGE_COUNT,
    COALESCE(controls.BMCS_DIRECT_COST_IMPACT_COUNT, 0)::NUMBER
        AS BMCS_DIRECT_COST_IMPACT_COUNT,
    COALESCE(monitoring_history.AUTO_PAUSE_EVENT_COUNT, 0)::NUMBER
        AS AUTO_PAUSE_EVENT_COUNT,
    COALESCE(status_events.MANUAL_PAUSE_EVENT_COUNT, 0)::NUMBER
        AS MANUAL_PAUSE_EVENT_COUNT,

    monitoring.MONITORING_RUN_ID AS LATEST_MONITORING_RUN_ID,
    monitoring.MONITORING_STATUS AS LATEST_MONITORING_STATUS,
    monitoring.AUTO_PAUSE_TRIGGERED_FLAG
        AS LATEST_MONITORING_AUTO_PAUSE_FLAG,
    monitoring.COMPLETED_AT AS LATEST_MONITORING_AT,

    policy.EXIT_POLICY_ID,
    policy.EXIT_POLICY_VERSION,

    policy.MIN_PILOT_DURATION_DAYS,
    policy.MIN_ASSIGNED_COUNT,
    policy.MIN_CONTROLLED_DECISION_COUNT,
    policy.MIN_ACTUAL_OUTCOME_COUNT,

    policy.MAX_CANDIDATE_MAE,
    policy.MIN_CANDIDATE_ADVANTAGE_VS_RULE,
    policy.MAX_BMCS_BRIER_SCORE,
    policy.MIN_BMCS_ACCURACY_PCT,

    policy.MAX_FALLBACK_RATE_PCT,
    policy.MAX_OPEN_INCIDENT_COUNT,
    policy.MAX_OPEN_CRITICAL_INCIDENT_COUNT,
    policy.MAX_TOTAL_CRITICAL_INCIDENT_COUNT,
    policy.MAX_UNAUTHORISED_CONTROLLED_USE_COUNT,
    policy.MAX_GUARDRAIL_VIOLATION_COUNT,
    policy.MAX_OFFICIAL_COST_CHANGE_COUNT,
    policy.MAX_BMCS_DIRECT_COST_IMPACT_COUNT,
    policy.MAX_AUTO_PAUSE_EVENT_COUNT,
    policy.MAX_MANUAL_PAUSE_EVENT_COUNT,
    policy.MAX_EXPOSURE_PCT,
    policy.REQUIRE_LATEST_MONITORING_HEALTHY_FLAG,

    IFF(
        plan.PILOT_STATUS = 'STOPPED'
        AND plan.STARTED_AT IS NOT NULL
        AND plan.LAST_STATUS_CHANGED_AT IS NOT NULL
        AND DATEDIFF(
            'second',
            plan.STARTED_AT,
            plan.LAST_STATUS_CHANGED_AT
        ) / 86400.0 >= policy.MIN_PILOT_DURATION_DAYS,
        TRUE,
        FALSE
    ) AS DURATION_PASS_FLAG,

    IFF(
        COALESCE(outcomes.ASSIGNED_COUNT, 0)
            >= policy.MIN_ASSIGNED_COUNT,
        TRUE,
        FALSE
    ) AS ASSIGNMENT_COUNT_PASS_FLAG,

    IFF(
        COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)
            >= policy.MIN_CONTROLLED_DECISION_COUNT,
        TRUE,
        FALSE
    ) AS CONTROLLED_DECISION_COUNT_PASS_FLAG,

    IFF(
        COALESCE(outcomes.ACTUAL_OUTCOME_COUNT, 0)
            >= policy.MIN_ACTUAL_OUTCOME_COUNT,
        TRUE,
        FALSE
    ) AS OUTCOME_COUNT_PASS_FLAG,

    IFF(
        plan.MODEL_DOMAIN = 'BMCS',
        outcomes.BMCS_BRIER_SCORE IS NOT NULL
        AND outcomes.BMCS_BRIER_SCORE <= policy.MAX_BMCS_BRIER_SCORE
        AND outcomes.BMCS_ACCURACY_PCT IS NOT NULL
        AND outcomes.BMCS_ACCURACY_PCT >= policy.MIN_BMCS_ACCURACY_PCT,
        outcomes.CANDIDATE_MAE IS NOT NULL
        AND outcomes.CANDIDATE_MAE <= policy.MAX_CANDIDATE_MAE
        AND outcomes.RULE_MAE IS NOT NULL
        AND outcomes.RULE_MAE - outcomes.CANDIDATE_MAE
            >= policy.MIN_CANDIDATE_ADVANTAGE_VS_RULE
    ) AS PERFORMANCE_PASS_FLAG,

    IFF(
        (
            COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)
            + COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)
        ) > 0
        AND (
            COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)
            /
            (
                COALESCE(outcomes.CONTROLLED_DECISION_COUNT, 0)
                + COALESCE(outcomes.FALLBACK_DECISION_COUNT, 0)
            )
        ) * 100.0 <= policy.MAX_FALLBACK_RATE_PCT,
        TRUE,
        FALSE
    ) AS FALLBACK_RATE_PASS_FLAG,

    IFF(
        COALESCE(incidents.OPEN_INCIDENT_COUNT, 0)
            <= policy.MAX_OPEN_INCIDENT_COUNT
        AND COALESCE(incidents.OPEN_CRITICAL_INCIDENT_COUNT, 0)
            <= policy.MAX_OPEN_CRITICAL_INCIDENT_COUNT
        AND COALESCE(incidents.TOTAL_CRITICAL_INCIDENT_COUNT, 0)
            <= policy.MAX_TOTAL_CRITICAL_INCIDENT_COUNT,
        TRUE,
        FALSE
    ) AS INCIDENT_PASS_FLAG,

    IFF(
        COALESCE(controls.UNAUTHORISED_CONTROLLED_USE_COUNT, 0)
            <= policy.MAX_UNAUTHORISED_CONTROLLED_USE_COUNT
        AND COALESCE(controls.GUARDRAIL_VIOLATION_COUNT, 0)
            <= policy.MAX_GUARDRAIL_VIOLATION_COUNT
        AND COALESCE(controls.OFFICIAL_COST_CHANGE_COUNT, 0)
            <= policy.MAX_OFFICIAL_COST_CHANGE_COUNT
        AND COALESCE(controls.BMCS_DIRECT_COST_IMPACT_COUNT, 0)
            <= policy.MAX_BMCS_DIRECT_COST_IMPACT_COUNT
        AND COALESCE(monitoring_history.AUTO_PAUSE_EVENT_COUNT, 0)
            <= policy.MAX_AUTO_PAUSE_EVENT_COUNT
        AND COALESCE(status_events.MANUAL_PAUSE_EVENT_COUNT, 0)
            <= policy.MAX_MANUAL_PAUSE_EVENT_COUNT,
        TRUE,
        FALSE
    ) AS CONTROL_INTEGRITY_PASS_FLAG,

    IFF(
        plan.EXPOSURE_PCT <= policy.MAX_EXPOSURE_PCT,
        TRUE,
        FALSE
    ) AS EXPOSURE_PASS_FLAG,

    IFF(
        (
            NOT policy.REQUIRE_LATEST_MONITORING_HEALTHY_FLAG
            OR monitoring.MONITORING_STATUS = 'HEALTHY'
        )
        AND NOT COALESCE(
            monitoring.AUTO_PAUSE_TRIGGERED_FLAG,
            FALSE
        )
        AND monitoring.COMPLETED_AT IS NOT NULL
        AND plan.LAST_STATUS_CHANGED_AT IS NOT NULL
        AND monitoring.COMPLETED_AT >= plan.LAST_STATUS_CHANGED_AT,
        TRUE,
        FALSE
    ) AS MONITORING_PASS_FLAG

FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_PLAN_CURRENT_V1 plan
JOIN KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_POLICY_CURRENT_V1 policy
  ON plan.MODEL_DOMAIN = policy.MODEL_DOMAIN
LEFT JOIN OUTCOMES outcomes
  ON plan.PILOT_PLAN_ID = outcomes.PILOT_PLAN_ID
LEFT JOIN INCIDENTS incidents
  ON plan.PILOT_PLAN_ID = incidents.PILOT_PLAN_ID
LEFT JOIN CONTROLS controls
  ON plan.PILOT_PLAN_ID = controls.PILOT_PLAN_ID
LEFT JOIN MONITORING_HISTORY monitoring_history
  ON plan.PILOT_PLAN_ID = monitoring_history.PILOT_PLAN_ID
LEFT JOIN STATUS_EVENTS status_events
  ON plan.PILOT_PLAN_ID = status_events.PILOT_PLAN_ID
LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_MONITORING_LATEST_V1 monitoring
  ON plan.PILOT_PLAN_ID = monitoring.PILOT_PLAN_ID;

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_PILOT_EXIT_ASSESSMENT_V1(
        P_ASSESSMENT_ID VARCHAR,
        P_EXIT_REQUEST_ID VARCHAR,
        P_ASSESSED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_ASSESSMENT_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_METRICS_COUNT NUMBER DEFAULT 0;
    V_CONTROLLED_REQUEST_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_POLICY_MATCH_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_PILOT_PLAN_ID VARCHAR;
    V_CONTROLLED_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_CONTROLLED_POLICY_ID VARCHAR;
    V_CONTROLLED_POLICY_VERSION VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_CURRENT_EVIDENCE_VERSION NUMBER;
    V_NEW_EVIDENCE_VERSION NUMBER;
    V_CONTROLLED_REQUEST_STATUS VARCHAR;

    V_EXIT_POLICY_ID VARCHAR;
    V_EXIT_POLICY_VERSION VARCHAR;
    V_PILOT_STATUS VARCHAR;
    V_PILOT_DURATION_DAYS FLOAT;
    V_EXPOSURE_PCT FLOAT;

    V_ASSIGNED_COUNT NUMBER;
    V_CONTROLLED_COUNT NUMBER;
    V_FALLBACK_COUNT NUMBER;
    V_FALLBACK_RATE FLOAT;
    V_OUTCOME_COUNT NUMBER;

    V_RULE_MAE FLOAT;
    V_CANDIDATE_MAE FLOAT;
    V_CANDIDATE_RMSE FLOAT;
    V_ADVANTAGE FLOAT;
    V_BRIER FLOAT;
    V_BMCS_ACCURACY FLOAT;

    V_OPEN_INCIDENT_COUNT NUMBER;
    V_OPEN_CRITICAL_COUNT NUMBER;
    V_TOTAL_CRITICAL_COUNT NUMBER;
    V_UNAUTHORISED_COUNT NUMBER;
    V_GUARDRAIL_COUNT NUMBER;
    V_COST_CHANGE_COUNT NUMBER;
    V_BMCS_COST_COUNT NUMBER;
    V_AUTO_PAUSE_COUNT NUMBER;
    V_MANUAL_PAUSE_COUNT NUMBER;

    V_MONITORING_RUN_ID VARCHAR;
    V_MONITORING_STATUS VARCHAR;
    V_MONITORING_AUTO_PAUSE BOOLEAN;
    V_MONITORING_AT TIMESTAMP_NTZ;

    V_DURATION_PASS BOOLEAN;
    V_ASSIGNMENT_PASS BOOLEAN;
    V_CONTROLLED_COUNT_PASS BOOLEAN;
    V_OUTCOME_PASS BOOLEAN;
    V_PERFORMANCE_PASS BOOLEAN;
    V_FALLBACK_PASS BOOLEAN;
    V_INCIDENT_PASS BOOLEAN;
    V_CONTROL_INTEGRITY_PASS BOOLEAN;
    V_EXPOSURE_PASS BOOLEAN;
    V_MONITORING_PASS BOOLEAN;

    V_ASSESSMENT_STATUS VARCHAR;
    V_ASSESSMENT_REASON VARCHAR;
    V_RESULTING_REQUEST_STATUS VARCHAR;

    V_STARTED_AT TIMESTAMP_NTZ;
    V_COMPLETED_AT TIMESTAMP_NTZ;
    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_ASSESSMENT_ID IS NULL
        OR LENGTH(TRIM(P_ASSESSMENT_ID)) = 0
        OR P_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_EXIT_REQUEST_ID)) = 0
        OR P_ASSESSED_BY IS NULL
        OR LENGTH(TRIM(P_ASSESSED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Assessment ID, exit request and assessor are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_ASSESSMENT_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1
    WHERE ASSESSMENT_ID = :P_ASSESSMENT_ID;

    IF (V_EXISTING_ASSESSMENT_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''ASSESSMENT_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(MODEL_DOMAIN),
        MAX(PILOT_PLAN_ID),
        MAX(CONTROLLED_DEPLOYMENT_REQUEST_ID),
        MAX(CONTROLLED_POLICY_ID),
        MAX(CONTROLLED_POLICY_VERSION),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_COUNT,
        :V_MODEL_DOMAIN,
        :V_PILOT_PLAN_ID,
        :V_CONTROLLED_DEPLOYMENT_REQUEST_ID,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_REQUEST_STATUS,
        :V_CURRENT_EVIDENCE_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot-exit request is required.''
        );
    END IF;

    IF (
        V_REQUEST_STATUS IN (
            ''CLOSED_PASS'',
            ''REJECTED'',
            ''CANCELLED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''A terminal pilot-exit request cannot be refreshed.'',
            ''request_status'', V_REQUEST_STATUS
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(REQUEST_STATUS)
    INTO
        :V_CONTROLLED_REQUEST_COUNT,
        :V_CONTROLLED_REQUEST_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :V_CONTROLLED_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND TARGET_MODE = ''CONTROLLED''
      AND CANDIDATE_POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND CANDIDATE_POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION;

    IF (
        V_CONTROLLED_REQUEST_COUNT <> 1
        OR V_CONTROLLED_REQUEST_STATUS <> ''ACTIVATED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The exact CONTROLLED request must remain ACTIVATED.'',
            ''request_status'', V_CONTROLLED_REQUEST_STATUS
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_ACTIVE_POLICY_MATCH_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION
      AND DEPLOYMENT_MODE = ''CONTROLLED'';

    IF (V_ACTIVE_POLICY_MATCH_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The exact pilot policy must remain active in CONTROLLED mode.''
        );
    END IF;

    V_STARTED_AT := CURRENT_TIMESTAMP();

    SELECT
        COUNT(*),
        MAX(EXIT_POLICY_ID),
        MAX(EXIT_POLICY_VERSION),
        MAX(PILOT_STATUS),
        MAX(PILOT_DURATION_DAYS),
        MAX(EXPOSURE_PCT),
        MAX(ASSIGNED_COUNT),
        MAX(CONTROLLED_DECISION_COUNT),
        MAX(FALLBACK_DECISION_COUNT),
        MAX(FALLBACK_RATE_PCT),
        MAX(ACTUAL_OUTCOME_COUNT),
        MAX(RULE_MAE),
        MAX(CANDIDATE_MAE),
        MAX(CANDIDATE_RMSE),
        MAX(CANDIDATE_ADVANTAGE_VS_RULE),
        MAX(BMCS_BRIER_SCORE),
        MAX(BMCS_ACCURACY_PCT),
        MAX(OPEN_INCIDENT_COUNT),
        MAX(OPEN_CRITICAL_INCIDENT_COUNT),
        MAX(TOTAL_CRITICAL_INCIDENT_COUNT),
        MAX(UNAUTHORISED_CONTROLLED_USE_COUNT),
        MAX(GUARDRAIL_VIOLATION_COUNT),
        MAX(OFFICIAL_COST_CHANGE_COUNT),
        MAX(BMCS_DIRECT_COST_IMPACT_COUNT),
        MAX(AUTO_PAUSE_EVENT_COUNT),
        MAX(MANUAL_PAUSE_EVENT_COUNT),
        MAX(LATEST_MONITORING_RUN_ID),
        MAX(LATEST_MONITORING_STATUS),
        MAX(LATEST_MONITORING_AUTO_PAUSE_FLAG),
        MAX(LATEST_MONITORING_AT),
        MAX(DURATION_PASS_FLAG),
        MAX(ASSIGNMENT_COUNT_PASS_FLAG),
        MAX(CONTROLLED_DECISION_COUNT_PASS_FLAG),
        MAX(OUTCOME_COUNT_PASS_FLAG),
        MAX(PERFORMANCE_PASS_FLAG),
        MAX(FALLBACK_RATE_PASS_FLAG),
        MAX(INCIDENT_PASS_FLAG),
        MAX(CONTROL_INTEGRITY_PASS_FLAG),
        MAX(EXPOSURE_PASS_FLAG),
        MAX(MONITORING_PASS_FLAG)
    INTO
        :V_METRICS_COUNT,
        :V_EXIT_POLICY_ID,
        :V_EXIT_POLICY_VERSION,
        :V_PILOT_STATUS,
        :V_PILOT_DURATION_DAYS,
        :V_EXPOSURE_PCT,
        :V_ASSIGNED_COUNT,
        :V_CONTROLLED_COUNT,
        :V_FALLBACK_COUNT,
        :V_FALLBACK_RATE,
        :V_OUTCOME_COUNT,
        :V_RULE_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,
        :V_ADVANTAGE,
        :V_BRIER,
        :V_BMCS_ACCURACY,
        :V_OPEN_INCIDENT_COUNT,
        :V_OPEN_CRITICAL_COUNT,
        :V_TOTAL_CRITICAL_COUNT,
        :V_UNAUTHORISED_COUNT,
        :V_GUARDRAIL_COUNT,
        :V_COST_CHANGE_COUNT,
        :V_BMCS_COST_COUNT,
        :V_AUTO_PAUSE_COUNT,
        :V_MANUAL_PAUSE_COUNT,
        :V_MONITORING_RUN_ID,
        :V_MONITORING_STATUS,
        :V_MONITORING_AUTO_PAUSE,
        :V_MONITORING_AT,
        :V_DURATION_PASS,
        :V_ASSIGNMENT_PASS,
        :V_CONTROLLED_COUNT_PASS,
        :V_OUTCOME_PASS,
        :V_PERFORMANCE_PASS,
        :V_FALLBACK_PASS,
        :V_INCIDENT_PASS,
        :V_CONTROL_INTEGRITY_PASS,
        :V_EXPOSURE_PASS,
        :V_MONITORING_PASS
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_METRICS_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND CONTROLLED_DEPLOYMENT_REQUEST_ID = :V_CONTROLLED_DEPLOYMENT_REQUEST_ID
      AND CONTROLLED_POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND CONTROLLED_POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION;

    IF (
        V_METRICS_COUNT <> 1
        OR V_PILOT_STATUS <> ''STOPPED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one STOPPED pilot metrics row is required.'',
            ''metrics_count'', V_METRICS_COUNT,
            ''pilot_status'', V_PILOT_STATUS
        );
    END IF;

    IF (
        NOT V_ASSIGNMENT_PASS
        OR NOT V_CONTROLLED_COUNT_PASS
        OR NOT V_OUTCOME_PASS
    ) THEN
        V_ASSESSMENT_STATUS := ''INSUFFICIENT_DATA'';
        V_ASSESSMENT_REASON :=
            ''Pilot assignments, controlled decisions, or verified outcomes are below production minimums.'';
    ELSEIF (
        V_DURATION_PASS
        AND V_PERFORMANCE_PASS
        AND V_FALLBACK_PASS
        AND V_INCIDENT_PASS
        AND V_CONTROL_INTEGRITY_PASS
        AND V_EXPOSURE_PASS
        AND V_MONITORING_PASS
    ) THEN
        V_ASSESSMENT_STATUS := ''PASS'';
        V_ASSESSMENT_REASON :=
            ''Pilot passed duration, evidence, performance, fallback, incident, integrity, exposure and monitoring gates.'';
    ELSE
        V_ASSESSMENT_STATUS := ''FAIL'';
        V_ASSESSMENT_REASON :=
            ''At least one production-readiness gate failed.'';
    END IF;

    V_RESULTING_REQUEST_STATUS :=
        IFF(
            V_ASSESSMENT_STATUS = ''PASS'',
            ''SIGNOFF_PENDING'',
            ''ASSESSMENT_BLOCKED''
        );

    V_NEW_EVIDENCE_VERSION := V_CURRENT_EVIDENCE_VERSION + 1;
    V_COMPLETED_AT := CURRENT_TIMESTAMP();
    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 (
        ASSESSMENT_ID, EXIT_REQUEST_ID, EVIDENCE_VERSION,
        PILOT_PLAN_ID, MODEL_DOMAIN,
        EXIT_POLICY_ID, EXIT_POLICY_VERSION,
        PILOT_STATUS, PILOT_DURATION_DAYS, EXPOSURE_PCT,
        ASSIGNED_COUNT, CONTROLLED_DECISION_COUNT,
        FALLBACK_DECISION_COUNT, FALLBACK_RATE_PCT,
        ACTUAL_OUTCOME_COUNT,
        RULE_MAE, CANDIDATE_MAE, CANDIDATE_RMSE,
        CANDIDATE_ADVANTAGE_VS_RULE,
        BMCS_BRIER_SCORE, BMCS_ACCURACY_PCT,
        OPEN_INCIDENT_COUNT, OPEN_CRITICAL_INCIDENT_COUNT,
        TOTAL_CRITICAL_INCIDENT_COUNT,
        UNAUTHORISED_CONTROLLED_USE_COUNT,
        GUARDRAIL_VIOLATION_COUNT,
        OFFICIAL_COST_CHANGE_COUNT,
        BMCS_DIRECT_COST_IMPACT_COUNT,
        AUTO_PAUSE_EVENT_COUNT,
        MANUAL_PAUSE_EVENT_COUNT,
        LATEST_MONITORING_RUN_ID,
        LATEST_MONITORING_STATUS,
        LATEST_MONITORING_AUTO_PAUSE_FLAG,
        LATEST_MONITORING_AT,
        DURATION_PASS_FLAG,
        ASSIGNMENT_COUNT_PASS_FLAG,
        CONTROLLED_DECISION_COUNT_PASS_FLAG,
        OUTCOME_COUNT_PASS_FLAG,
        PERFORMANCE_PASS_FLAG,
        FALLBACK_RATE_PASS_FLAG,
        INCIDENT_PASS_FLAG,
        CONTROL_INTEGRITY_PASS_FLAG,
        EXPOSURE_PASS_FLAG,
        MONITORING_PASS_FLAG,
        ASSESSMENT_STATUS, ASSESSMENT_REASON,
        ASSESSED_BY, STARTED_AT, COMPLETED_AT, CREATED_AT
    )
    SELECT
        TRIM(:P_ASSESSMENT_ID),
        TRIM(:P_EXIT_REQUEST_ID),
        :V_NEW_EVIDENCE_VERSION,
        :V_PILOT_PLAN_ID,
        :V_MODEL_DOMAIN,
        :V_EXIT_POLICY_ID,
        :V_EXIT_POLICY_VERSION,
        :V_PILOT_STATUS,
        :V_PILOT_DURATION_DAYS,
        :V_EXPOSURE_PCT,
        :V_ASSIGNED_COUNT,
        :V_CONTROLLED_COUNT,
        :V_FALLBACK_COUNT,
        :V_FALLBACK_RATE,
        :V_OUTCOME_COUNT,
        :V_RULE_MAE,
        :V_CANDIDATE_MAE,
        :V_CANDIDATE_RMSE,
        :V_ADVANTAGE,
        :V_BRIER,
        :V_BMCS_ACCURACY,
        :V_OPEN_INCIDENT_COUNT,
        :V_OPEN_CRITICAL_COUNT,
        :V_TOTAL_CRITICAL_COUNT,
        :V_UNAUTHORISED_COUNT,
        :V_GUARDRAIL_COUNT,
        :V_COST_CHANGE_COUNT,
        :V_BMCS_COST_COUNT,
        :V_AUTO_PAUSE_COUNT,
        :V_MANUAL_PAUSE_COUNT,
        :V_MONITORING_RUN_ID,
        :V_MONITORING_STATUS,
        :V_MONITORING_AUTO_PAUSE,
        :V_MONITORING_AT,
        :V_DURATION_PASS,
        :V_ASSIGNMENT_PASS,
        :V_CONTROLLED_COUNT_PASS,
        :V_OUTCOME_PASS,
        :V_PERFORMANCE_PASS,
        :V_FALLBACK_PASS,
        :V_INCIDENT_PASS,
        :V_CONTROL_INTEGRITY_PASS,
        :V_EXPOSURE_PASS,
        :V_MONITORING_PASS,
        :V_ASSESSMENT_STATUS,
        :V_ASSESSMENT_REASON,
        TRIM(:P_ASSESSED_BY),
        :V_STARTED_AT,
        :V_COMPLETED_AT,
        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Assessment insert did not affect exactly one row.''
        );
    END IF;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    SET
        REQUEST_STATUS = :V_RESULTING_REQUEST_STATUS,
        EVIDENCE_VERSION = :V_NEW_EVIDENCE_VERSION,
        LATEST_ASSESSMENT_ID = TRIM(:P_ASSESSMENT_ID),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_CURRENT_EVIDENCE_VERSION;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exit-request evidence update did not affect exactly one row.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PILOT_EXIT_ASSESSMENT_REFRESHED'',
        TRIM(:P_EXIT_REQUEST_ID), :V_NEW_EVIDENCE_VERSION,
        TRIM(:P_ASSESSMENT_ID), NULL::VARCHAR, NULL::VARCHAR,
        :V_PILOT_PLAN_ID, NULL::VARCHAR,
        :V_MODEL_DOMAIN, :V_ASSESSMENT_STATUS,
        :V_ASSESSMENT_REASON,
        TRIM(:P_ASSESSED_BY), CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''assessment_id'', P_ASSESSMENT_ID,
        ''exit_request_id'', P_EXIT_REQUEST_ID,
        ''evidence_version'', V_NEW_EVIDENCE_VERSION,
        ''model_domain'', V_MODEL_DOMAIN,
        ''pilot_plan_id'', V_PILOT_PLAN_ID,
        ''assessment_status'', V_ASSESSMENT_STATUS,
        ''assessment_reason'', V_ASSESSMENT_REASON,
        ''pilot_duration_days'', V_PILOT_DURATION_DAYS,
        ''assigned_count'', V_ASSIGNED_COUNT,
        ''controlled_decision_count'', V_CONTROLLED_COUNT,
        ''fallback_rate_pct'', V_FALLBACK_RATE,
        ''actual_outcome_count'', V_OUTCOME_COUNT,
        ''candidate_mae'', V_CANDIDATE_MAE,
        ''candidate_advantage_vs_rule'', V_ADVANTAGE,
        ''bmcs_brier_score'', V_BRIER,
        ''bmcs_accuracy_pct'', V_BMCS_ACCURACY,
        ''open_incident_count'', V_OPEN_INCIDENT_COUNT,
        ''open_critical_incident_count'', V_OPEN_CRITICAL_COUNT,
        ''total_critical_incident_count'', V_TOTAL_CRITICAL_COUNT,
        ''auto_pause_event_count'', V_AUTO_PAUSE_COUNT,
        ''manual_pause_event_count'', V_MANUAL_PAUSE_COUNT,
        ''control_integrity_pass'', V_CONTROL_INTEGRITY_PASS,
        ''latest_monitoring_status'', V_MONITORING_STATUS,
        ''resulting_request_status'', V_RESULTING_REQUEST_STATUS,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_READINESS_V1
AS
WITH REQUIREMENTS AS (
    SELECT
        MODEL_DOMAIN,
        COUNT(*)::NUMBER AS REQUIRED_SIGNOFF_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
    GROUP BY MODEL_DOMAIN
),
SIGNOFF_STATUS AS (
    SELECT
        request.EXIT_REQUEST_ID,
        request.EVIDENCE_VERSION,

        COALESCE(
            COUNT_IF(signoff.REVIEW_ACTION = 'APPROVE'),
            0
        )::NUMBER AS APPROVED_SIGNOFF_COUNT,

        COALESCE(
            COUNT_IF(signoff.REVIEW_ACTION = 'REJECT'),
            0
        )::NUMBER AS REJECTED_SIGNOFF_COUNT,

        MIN(
            IFF(
                signoff.REVIEW_ACTION = 'APPROVE',
                signoff.REVIEWED_AT,
                NULL::TIMESTAMP_NTZ
            )
        ) AS EARLIEST_APPROVAL_AT,

        MAX(
            IFF(
                signoff.REVIEW_ACTION = 'APPROVE',
                signoff.REVIEWED_AT,
                NULL::TIMESTAMP_NTZ
            )
        ) AS LATEST_APPROVAL_AT

    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 request
    LEFT JOIN
        KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_SIGNOFF_CURRENT_V1 signoff
      ON request.EXIT_REQUEST_ID = signoff.EXIT_REQUEST_ID
     AND request.EVIDENCE_VERSION = signoff.EVIDENCE_VERSION
    GROUP BY request.EXIT_REQUEST_ID, request.EVIDENCE_VERSION
)
SELECT
    request.EXIT_REQUEST_ID,
    request.PILOT_PLAN_ID,
    request.MODEL_DOMAIN,

    request.CONTROLLED_DEPLOYMENT_REQUEST_ID,
    request.CONTROLLED_POLICY_ID,
    request.CONTROLLED_POLICY_VERSION,

    request.CANDIDATE_MODEL_NAME,
    request.CANDIDATE_MODEL_VERSION,
    request.CANDIDATE_FEATURE_SET_VERSION,

    request.REQUEST_STATUS,
    request.EVIDENCE_VERSION,
    request.LATEST_ASSESSMENT_ID,

    assessment.ASSESSMENT_STATUS,
    assessment.ASSESSMENT_REASON,
    assessment.ASSESSED_BY,
    assessment.COMPLETED_AT AS ASSESSMENT_COMPLETED_AT,

    assessment.PILOT_DURATION_DAYS,
    assessment.ASSIGNED_COUNT,
    assessment.CONTROLLED_DECISION_COUNT,
    assessment.FALLBACK_RATE_PCT,
    assessment.ACTUAL_OUTCOME_COUNT,

    assessment.CANDIDATE_MAE,
    assessment.CANDIDATE_ADVANTAGE_VS_RULE,
    assessment.BMCS_BRIER_SCORE,
    assessment.BMCS_ACCURACY_PCT,

    assessment.OPEN_INCIDENT_COUNT,
    assessment.OPEN_CRITICAL_INCIDENT_COUNT,
    assessment.TOTAL_CRITICAL_INCIDENT_COUNT,
    assessment.UNAUTHORISED_CONTROLLED_USE_COUNT,
    assessment.GUARDRAIL_VIOLATION_COUNT,
    assessment.OFFICIAL_COST_CHANGE_COUNT,
    assessment.BMCS_DIRECT_COST_IMPACT_COUNT,
    assessment.AUTO_PAUSE_EVENT_COUNT,
    assessment.MANUAL_PAUSE_EVENT_COUNT,
    assessment.LATEST_MONITORING_STATUS,

    COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0)::NUMBER
        AS REQUIRED_SIGNOFF_COUNT,

    COALESCE(signoff_status.APPROVED_SIGNOFF_COUNT, 0)::NUMBER
        AS APPROVED_SIGNOFF_COUNT,

    COALESCE(signoff_status.REJECTED_SIGNOFF_COUNT, 0)::NUMBER
        AS REJECTED_SIGNOFF_COUNT,

    signoff_status.EARLIEST_APPROVAL_AT,
    signoff_status.LATEST_APPROVAL_AT,

    IFF(
        assessment.ASSESSMENT_ID IS NOT NULL
        AND assessment.ASSESSMENT_STATUS = 'PASS'
        AND assessment.COMPLETED_AT >= DATEADD(
            'hour',
            -24,
            CURRENT_TIMESTAMP()
        ),
        TRUE,
        FALSE
    ) AS ASSESSMENT_FRESH_FLAG,

    IFF(
        COALESCE(signoff_status.REJECTED_SIGNOFF_COUNT, 0) = 0
        AND COALESCE(signoff_status.APPROVED_SIGNOFF_COUNT, 0)
            = COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0)
        AND COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0) > 0,
        TRUE,
        FALSE
    ) AS ALL_SIGNOFFS_COMPLETE_FLAG,

    IFF(
        assessment.ASSESSMENT_ID IS NOT NULL
        AND signoff_status.EARLIEST_APPROVAL_AT >= assessment.COMPLETED_AT,
        TRUE,
        FALSE
    ) AS APPROVALS_AFTER_ASSESSMENT_FLAG,

    CASE
        WHEN request.REQUEST_STATUS = 'CLOSED_PASS'
            THEN 'CLOSED_PASS'
        WHEN request.REQUEST_STATUS = 'CANCELLED'
            THEN 'CANCELLED'
        WHEN request.REQUEST_STATUS = 'REJECTED'
            THEN 'REJECTED'
        WHEN assessment.ASSESSMENT_ID IS NULL
            THEN 'NO_ASSESSMENT'
        WHEN assessment.ASSESSMENT_STATUS <> 'PASS'
            THEN 'ASSESSMENT_' || assessment.ASSESSMENT_STATUS
        WHEN assessment.COMPLETED_AT < DATEADD(
            'hour',
            -24,
            CURRENT_TIMESTAMP()
        )
            THEN 'ASSESSMENT_STALE'
        WHEN COALESCE(signoff_status.REJECTED_SIGNOFF_COUNT, 0) > 0
            THEN 'SIGNOFF_REJECTED'
        WHEN COALESCE(signoff_status.APPROVED_SIGNOFF_COUNT, 0)
            < COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0)
            THEN 'SIGNOFF_PENDING'
        WHEN signoff_status.EARLIEST_APPROVAL_AT < assessment.COMPLETED_AT
            THEN 'SIGNOFF_STALE_FOR_ASSESSMENT'
        ELSE 'CLOSURE_READY'
    END AS EXIT_READINESS_STATUS,

    IFF(
        request.REQUEST_STATUS = 'APPROVED'
        AND assessment.ASSESSMENT_STATUS = 'PASS'
        AND assessment.COMPLETED_AT >= DATEADD(
            'hour',
            -24,
            CURRENT_TIMESTAMP()
        )
        AND COALESCE(signoff_status.REJECTED_SIGNOFF_COUNT, 0) = 0
        AND COALESCE(signoff_status.APPROVED_SIGNOFF_COUNT, 0)
            = COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0)
        AND COALESCE(requirements.REQUIRED_SIGNOFF_COUNT, 0) > 0
        AND signoff_status.EARLIEST_APPROVAL_AT >= assessment.COMPLETED_AT,
        TRUE,
        FALSE
    ) AS EXIT_CLOSURE_ELIGIBLE_FLAG,

    request.REQUESTED_BY,
    request.REQUESTED_AT,
    request.CLOSED_BY,
    request.CLOSED_AT,
    request.UPDATED_AT

FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 request
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_ASSESSMENT_LATEST_V1 assessment
  ON request.EXIT_REQUEST_ID = assessment.EXIT_REQUEST_ID
 AND request.EVIDENCE_VERSION = assessment.EVIDENCE_VERSION
LEFT JOIN REQUIREMENTS requirements
  ON request.MODEL_DOMAIN = requirements.MODEL_DOMAIN
LEFT JOIN SIGNOFF_STATUS signoff_status
  ON request.EXIT_REQUEST_ID = signoff_status.EXIT_REQUEST_ID
 AND request.EVIDENCE_VERSION = signoff_status.EVIDENCE_VERSION;

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_PILOT_EXIT_V1(
        P_SIGNOFF_ID VARCHAR,
        P_EXIT_REQUEST_ID VARCHAR,
        P_SIGNOFF_STAGE VARCHAR,
        P_REVIEW_ACTION VARCHAR,
        P_REVIEW_NOTE VARCHAR,
        P_REVIEWED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_SIGNOFF_ID_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_REQUIREMENT_COUNT NUMBER DEFAULT 0;
    V_EXISTING_STAGE_COUNT NUMBER DEFAULT 0;
    V_REVIEWER_STAGE_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_PILOT_PLAN_ID VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_REQUESTED_BY VARCHAR;

    V_ASSESSMENT_STATUS VARCHAR;
    V_ASSESSED_BY VARCHAR;
    V_ASSESSMENT_COMPLETED_AT TIMESTAMP_NTZ;

    V_REQUIRED_COUNT NUMBER DEFAULT 0;
    V_APPROVED_COUNT NUMBER DEFAULT 0;
    V_REJECTED_COUNT NUMBER DEFAULT 0;
    V_RESULTING_REQUEST_STATUS VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_SIGNOFF_ID IS NULL
        OR LENGTH(TRIM(P_SIGNOFF_ID)) = 0
        OR P_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_EXIT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Sign-off ID and exit-request ID are required.''
        );
    END IF;

    IF (
        P_SIGNOFF_STAGE IS NULL
        OR UPPER(TRIM(P_SIGNOFF_STAGE))
            NOT IN (''TECHNICAL'', ''BUSINESS'', ''RISK'', ''FINANCE'')
        OR P_REVIEW_ACTION IS NULL
        OR UPPER(TRIM(P_REVIEW_ACTION))
            NOT IN (''APPROVE'', ''REJECT'')
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''A valid sign-off stage and APPROVE or REJECT action are required.''
        );
    END IF;

    IF (
        P_REVIEW_NOTE IS NULL
        OR LENGTH(TRIM(P_REVIEW_NOTE)) = 0
        OR P_REVIEWED_BY IS NULL
        OR LENGTH(TRIM(P_REVIEWED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Review note and reviewer are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_SIGNOFF_ID_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1
    WHERE SIGNOFF_ID = :P_SIGNOFF_ID;

    IF (V_EXISTING_SIGNOFF_ID_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''SIGNOFF_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(MODEL_DOMAIN),
        MAX(PILOT_PLAN_ID),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),
        MAX(REQUESTED_BY),
        MAX(ASSESSMENT_STATUS),
        MAX(ASSESSED_BY),
        MAX(ASSESSMENT_COMPLETED_AT)
    INTO
        :V_REQUEST_COUNT,
        :V_MODEL_DOMAIN,
        :V_PILOT_PLAN_ID,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,
        :V_REQUESTED_BY,
        :V_ASSESSMENT_STATUS,
        :V_ASSESSED_BY,
        :V_ASSESSMENT_COMPLETED_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_READINESS_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot-exit readiness row is required.''
        );
    END IF;

    IF (
        V_REQUEST_STATUS NOT IN (''SIGNOFF_PENDING'', ''APPROVED'')
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Sign-off is allowed only for SIGNOFF_PENDING or APPROVED requests.'',
            ''request_status'', V_REQUEST_STATUS
        );
    END IF;

    IF (
        V_ASSESSMENT_STATUS <> ''PASS''
        OR V_ASSESSMENT_COMPLETED_AT < DATEADD(
            ''hour'',
            -24,
            CURRENT_TIMESTAMP()
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''A fresh PASS pilot-exit assessment is required.'',
            ''assessment_status'', V_ASSESSMENT_STATUS,
            ''assessment_completed_at'', V_ASSESSMENT_COMPLETED_AT
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_REQUIREMENT_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND SIGNOFF_STAGE = UPPER(TRIM(:P_SIGNOFF_STAGE));

    IF (V_REQUIREMENT_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The selected sign-off stage is not required for this model domain.''
        );
    END IF;

    IF (
        UPPER(TRIM(P_REVIEW_ACTION)) = ''APPROVE''
        AND (
            UPPER(TRIM(P_REVIEWED_BY)) = UPPER(TRIM(V_REQUESTED_BY))
            OR UPPER(TRIM(P_REVIEWED_BY)) = UPPER(TRIM(V_ASSESSED_BY))
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Requester and assessor cannot approve their own pilot-exit evidence.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_STAGE_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_SIGNOFF_CURRENT_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
      AND SIGNOFF_STAGE = UPPER(TRIM(:P_SIGNOFF_STAGE));

    IF (V_EXISTING_STAGE_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''This sign-off stage already has a decision for the current evidence version.''
        );
    END IF;

    IF (UPPER(TRIM(P_REVIEW_ACTION)) = ''APPROVE'') THEN
        SELECT COUNT(*)
        INTO :V_REVIEWER_STAGE_COUNT
        FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_SIGNOFF_CURRENT_V1
        WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
          AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
          AND REVIEW_ACTION = ''APPROVE''
          AND UPPER(REVIEWED_BY) = UPPER(TRIM(:P_REVIEWED_BY));

        IF (V_REVIEWER_STAGE_COUNT > 0) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'', ''The same reviewer cannot approve multiple sign-off stages.''
            );
        END IF;
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 (
        SIGNOFF_ID, EXIT_REQUEST_ID, EVIDENCE_VERSION,
        MODEL_DOMAIN, SIGNOFF_STAGE,
        REVIEW_ACTION, REVIEW_NOTE,
        REVIEWED_BY, REVIEWED_AT
    )
    SELECT
        TRIM(:P_SIGNOFF_ID),
        TRIM(:P_EXIT_REQUEST_ID),
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN,
        UPPER(TRIM(:P_SIGNOFF_STAGE)),
        UPPER(TRIM(:P_REVIEW_ACTION)),
        TRIM(:P_REVIEW_NOTE),
        TRIM(:P_REVIEWED_BY),
        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Sign-off insert did not affect exactly one row.''
        );
    END IF;

    SELECT COUNT(*)::NUMBER
    INTO :V_REQUIRED_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN;

    SELECT
        COALESCE(COUNT_IF(REVIEW_ACTION = ''APPROVE''), 0)::NUMBER,
        COALESCE(COUNT_IF(REVIEW_ACTION = ''REJECT''), 0)::NUMBER
    INTO
        :V_APPROVED_COUNT,
        :V_REJECTED_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_SIGNOFF_CURRENT_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION;

    V_RESULTING_REQUEST_STATUS :=
        CASE
            WHEN V_REJECTED_COUNT > 0 THEN ''REJECTED''
            WHEN V_REQUIRED_COUNT > 0
             AND V_APPROVED_COUNT = V_REQUIRED_COUNT THEN ''APPROVED''
            ELSE ''SIGNOFF_PENDING''
        END;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    SET
        REQUEST_STATUS = :V_RESULTING_REQUEST_STATUS,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
      AND REQUEST_STATUS IN (''SIGNOFF_PENDING'', ''APPROVED'');

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exit-request sign-off status update did not affect exactly one row.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PILOT_EXIT_SIGNOFF_RECORDED'',
        TRIM(:P_EXIT_REQUEST_ID), :V_EVIDENCE_VERSION,
        NULL::VARCHAR, TRIM(:P_SIGNOFF_ID), NULL::VARCHAR,
        :V_PILOT_PLAN_ID, NULL::VARCHAR,
        :V_MODEL_DOMAIN,
        UPPER(TRIM(:P_REVIEW_ACTION)),
        TRIM(:P_REVIEW_NOTE),
        TRIM(:P_REVIEWED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''signoff_id'', P_SIGNOFF_ID,
        ''exit_request_id'', P_EXIT_REQUEST_ID,
        ''evidence_version'', V_EVIDENCE_VERSION,
        ''model_domain'', V_MODEL_DOMAIN,
        ''signoff_stage'', UPPER(TRIM(P_SIGNOFF_STAGE)),
        ''review_action'', UPPER(TRIM(P_REVIEW_ACTION)),
        ''required_signoff_count'', V_REQUIRED_COUNT,
        ''approved_signoff_count'', V_APPROVED_COUNT,
        ''rejected_signoff_count'', V_REJECTED_COUNT,
        ''resulting_request_status'', V_RESULTING_REQUEST_STATUS,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.CLOSE_ML_PILOT_EXIT_V1(
        P_EXIT_REQUEST_ID VARCHAR,
        P_CLOSED_BY VARCHAR,
        P_CLOSURE_REASON VARCHAR,
        P_CONFIRMATION_PHRASE VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_READINESS_COUNT NUMBER DEFAULT 0;
    V_PLAN_COUNT NUMBER DEFAULT 0;
    V_CONTROLLED_REQUEST_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_POLICY_MATCH_COUNT NUMBER DEFAULT 0;

    V_PILOT_PLAN_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;
    V_CONTROLLED_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_CONTROLLED_POLICY_ID VARCHAR;
    V_CONTROLLED_POLICY_VERSION VARCHAR;

    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_REQUESTED_BY VARCHAR;

    V_ASSESSMENT_ID VARCHAR;
    V_ASSESSMENT_STATUS VARCHAR;
    V_ASSESSMENT_COMPLETED_AT TIMESTAMP_NTZ;
    V_EXIT_READINESS_STATUS VARCHAR;
    V_CLOSURE_ELIGIBLE BOOLEAN;

    V_PILOT_STATUS VARCHAR;
    V_CONTROLLED_REQUEST_STATUS VARCHAR;

    V_MAX_ASSIGNMENT_AT TIMESTAMP_NTZ;
    V_MAX_DECISION_AT TIMESTAMP_NTZ;
    V_MAX_INCIDENT_AT TIMESTAMP_NTZ;
    V_MAX_MONITORING_AT TIMESTAMP_NTZ;
    V_NEW_PILOT_DATA_FLAG BOOLEAN DEFAULT FALSE;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_EXIT_REQUEST_ID)) = 0
        OR P_CLOSED_BY IS NULL
        OR LENGTH(TRIM(P_CLOSED_BY)) = 0
        OR P_CLOSURE_REASON IS NULL
        OR LENGTH(TRIM(P_CLOSURE_REASON)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exit request, closure actor and reason are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE <> (''CLOSE_EXIT::'' || P_EXIT_REQUEST_ID)
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Confirmation must equal CLOSE_EXIT::<EXIT_REQUEST_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_PLAN_ID),
        MAX(MODEL_DOMAIN),
        MAX(CONTROLLED_DEPLOYMENT_REQUEST_ID),
        MAX(CONTROLLED_POLICY_ID),
        MAX(CONTROLLED_POLICY_VERSION),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),
        MAX(REQUESTED_BY),
        MAX(LATEST_ASSESSMENT_ID),
        MAX(ASSESSMENT_STATUS),
        MAX(ASSESSMENT_COMPLETED_AT),
        MAX(EXIT_READINESS_STATUS),
        MAX(EXIT_CLOSURE_ELIGIBLE_FLAG)
    INTO
        :V_READINESS_COUNT,
        :V_PILOT_PLAN_ID,
        :V_MODEL_DOMAIN,
        :V_CONTROLLED_DEPLOYMENT_REQUEST_ID,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,
        :V_REQUESTED_BY,
        :V_ASSESSMENT_ID,
        :V_ASSESSMENT_STATUS,
        :V_ASSESSMENT_COMPLETED_AT,
        :V_EXIT_READINESS_STATUS,
        :V_CLOSURE_ELIGIBLE
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_READINESS_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_READINESS_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot-exit readiness row is required.''
        );
    END IF;

    IF (NOT COALESCE(V_CLOSURE_ELIGIBLE, FALSE)) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Pilot exit is not eligible for closure.'',
            ''request_status'', V_REQUEST_STATUS,
            ''assessment_status'', V_ASSESSMENT_STATUS,
            ''exit_readiness_status'', V_EXIT_READINESS_STATUS
        );
    END IF;

    IF (
        UPPER(TRIM(P_CLOSED_BY)) = UPPER(TRIM(V_REQUESTED_BY))
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The pilot-exit requester cannot close their own request.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_STATUS)
    INTO
        :V_PLAN_COUNT,
        :V_PILOT_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_PLAN_CURRENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    IF (
        V_PLAN_COUNT <> 1
        OR V_PILOT_STATUS <> ''STOPPED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The pilot plan must remain STOPPED at closure.'',
            ''pilot_status'', V_PILOT_STATUS
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(REQUEST_STATUS)
    INTO
        :V_CONTROLLED_REQUEST_COUNT,
        :V_CONTROLLED_REQUEST_STATUS
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :V_CONTROLLED_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND TARGET_MODE = ''CONTROLLED''
      AND CANDIDATE_POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND CANDIDATE_POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION;

    IF (
        V_CONTROLLED_REQUEST_COUNT <> 1
        OR V_CONTROLLED_REQUEST_STATUS <> ''ACTIVATED''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The exact CONTROLLED request must remain ACTIVATED at closure.'',
            ''request_status'', V_CONTROLLED_REQUEST_STATUS
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_ACTIVE_POLICY_MATCH_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION
      AND DEPLOYMENT_MODE = ''CONTROLLED'';

    IF (V_ACTIVE_POLICY_MATCH_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The exact controlled policy must remain active at closure.''
        );
    END IF;

    SELECT MAX(ASSIGNED_AT)
    INTO :V_MAX_ASSIGNMENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_DECISION_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_INCIDENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(COMPLETED_AT)
    INTO :V_MAX_MONITORING_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    V_NEW_PILOT_DATA_FLAG :=
        (
            V_MAX_ASSIGNMENT_AT IS NOT NULL
            AND V_MAX_ASSIGNMENT_AT > V_ASSESSMENT_COMPLETED_AT
        )
        OR (
            V_MAX_DECISION_AT IS NOT NULL
            AND V_MAX_DECISION_AT > V_ASSESSMENT_COMPLETED_AT
        )
        OR (
            V_MAX_INCIDENT_AT IS NOT NULL
            AND V_MAX_INCIDENT_AT > V_ASSESSMENT_COMPLETED_AT
        )
        OR (
            V_MAX_MONITORING_AT IS NOT NULL
            AND V_MAX_MONITORING_AT > V_ASSESSMENT_COMPLETED_AT
        );

    IF (V_NEW_PILOT_DATA_FLAG) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Pilot evidence changed after assessment. Refresh assessment and collect new sign-offs.'',
            ''assessment_completed_at'', V_ASSESSMENT_COMPLETED_AT,
            ''latest_assignment_at'', V_MAX_ASSIGNMENT_AT,
            ''latest_decision_at'', V_MAX_DECISION_AT,
            ''latest_incident_at'', V_MAX_INCIDENT_AT,
            ''latest_monitoring_at'', V_MAX_MONITORING_AT
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    SET
        REQUEST_STATUS = ''CLOSED_PASS'',
        CLOSED_BY = TRIM(:P_CLOSED_BY),
        CLOSED_AT = CURRENT_TIMESTAMP(),
        CLOSURE_REASON = TRIM(:P_CLOSURE_REASON),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION
      AND REQUEST_STATUS = ''APPROVED'';

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Pilot-exit closure did not update exactly one APPROVED request.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PILOT_EXIT_CLOSED'',
        TRIM(:P_EXIT_REQUEST_ID), :V_EVIDENCE_VERSION,
        :V_ASSESSMENT_ID, NULL::VARCHAR, NULL::VARCHAR,
        :V_PILOT_PLAN_ID, NULL::VARCHAR,
        :V_MODEL_DOMAIN, ''CLOSED_PASS'',
        TRIM(:P_CLOSURE_REASON),
        TRIM(:P_CLOSED_BY), CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''exit_request_id'', P_EXIT_REQUEST_ID,
        ''evidence_version'', V_EVIDENCE_VERSION,
        ''pilot_plan_id'', V_PILOT_PLAN_ID,
        ''model_domain'', V_MODEL_DOMAIN,
        ''assessment_id'', V_ASSESSMENT_ID,
        ''assessment_status'', V_ASSESSMENT_STATUS,
        ''request_status'', ''CLOSED_PASS'',
        ''production_promotion_authorised'', FALSE,
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.REGISTER_ML_PRODUCTION_PROMOTION_LINK_V1(
        P_PROMOTION_LINK_ID VARCHAR,
        P_PRODUCTION_DEPLOYMENT_REQUEST_ID VARCHAR,
        P_PILOT_EXIT_REQUEST_ID VARCHAR,
        P_LINK_REASON VARCHAR,
        P_REGISTERED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_EXISTING_LINK_ID_COUNT NUMBER DEFAULT 0;
    V_EXISTING_ACTIVE_LINK_COUNT NUMBER DEFAULT 0;
    V_EXIT_COUNT NUMBER DEFAULT 0;
    V_PRODUCTION_REQUEST_COUNT NUMBER DEFAULT 0;
    V_PRODUCTION_POLICY_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_CONTROLLED_POLICY_COUNT NUMBER DEFAULT 0;

    V_PILOT_PLAN_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;
    V_CONTROLLED_POLICY_ID VARCHAR;
    V_CONTROLLED_POLICY_VERSION VARCHAR;

    V_EXIT_EVIDENCE_VERSION NUMBER;
    V_EXIT_STATUS VARCHAR;
    V_EXIT_CLOSED_AT TIMESTAMP_NTZ;
    V_EXIT_MODEL_NAME VARCHAR;
    V_EXIT_MODEL_VERSION VARCHAR;
    V_EXIT_FEATURE_SET_VERSION VARCHAR;

    V_PRODUCTION_EVIDENCE_VERSION NUMBER;
    V_PRODUCTION_REQUEST_STATUS VARCHAR;
    V_PRODUCTION_TARGET_MODE VARCHAR;
    V_FROM_POLICY_ID VARCHAR;
    V_FROM_POLICY_VERSION VARCHAR;
    V_PRODUCTION_POLICY_ID VARCHAR;
    V_PRODUCTION_POLICY_VERSION VARCHAR;
    V_PRODUCTION_MODEL_NAME VARCHAR;
    V_PRODUCTION_MODEL_VERSION VARCHAR;
    V_PRODUCTION_FEATURE_SET_VERSION VARCHAR;

    V_MAX_ASSIGNMENT_AT TIMESTAMP_NTZ;
    V_MAX_DECISION_AT TIMESTAMP_NTZ;
    V_MAX_INCIDENT_AT TIMESTAMP_NTZ;
    V_MAX_MONITORING_AT TIMESTAMP_NTZ;
    V_NEW_PILOT_DATA_FLAG BOOLEAN DEFAULT FALSE;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_PROMOTION_LINK_ID IS NULL
        OR LENGTH(TRIM(P_PROMOTION_LINK_ID)) = 0
        OR P_PRODUCTION_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_PRODUCTION_DEPLOYMENT_REQUEST_ID)) = 0
        OR P_PILOT_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_PILOT_EXIT_REQUEST_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Promotion link, production request and exit-request IDs are required.''
        );
    END IF;

    IF (
        P_LINK_REASON IS NULL
        OR LENGTH(TRIM(P_LINK_REASON)) = 0
        OR P_REGISTERED_BY IS NULL
        OR LENGTH(TRIM(P_REGISTERED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Link reason and registered-by actor are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_LINK_ID_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
    WHERE PROMOTION_LINK_ID = :P_PROMOTION_LINK_ID;

    IF (V_EXISTING_LINK_ID_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''PROMOTION_LINK_ID already exists.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PILOT_PLAN_ID),
        MAX(MODEL_DOMAIN),
        MAX(CONTROLLED_POLICY_ID),
        MAX(CONTROLLED_POLICY_VERSION),
        MAX(EVIDENCE_VERSION),
        MAX(REQUEST_STATUS),
        MAX(CLOSED_AT),
        MAX(CANDIDATE_MODEL_NAME),
        MAX(CANDIDATE_MODEL_VERSION),
        MAX(CANDIDATE_FEATURE_SET_VERSION)
    INTO
        :V_EXIT_COUNT,
        :V_PILOT_PLAN_ID,
        :V_MODEL_DOMAIN,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_EXIT_EVIDENCE_VERSION,
        :V_EXIT_STATUS,
        :V_EXIT_CLOSED_AT,
        :V_EXIT_MODEL_NAME,
        :V_EXIT_MODEL_VERSION,
        :V_EXIT_FEATURE_SET_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    WHERE EXIT_REQUEST_ID = :P_PILOT_EXIT_REQUEST_ID;

    IF (
        V_EXIT_COUNT <> 1
        OR V_EXIT_STATUS <> ''CLOSED_PASS''
        OR V_EXIT_CLOSED_AT IS NULL
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''A formally CLOSED_PASS pilot-exit request is required.'',
            ''exit_request_count'', V_EXIT_COUNT,
            ''exit_status'', V_EXIT_STATUS,
            ''exit_closed_at'', V_EXIT_CLOSED_AT
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(EVIDENCE_VERSION),
        MAX(REQUEST_STATUS),
        MAX(TARGET_MODE),
        MAX(FROM_POLICY_ID),
        MAX(FROM_POLICY_VERSION),
        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION),
        MAX(CANDIDATE_MODEL_NAME),
        MAX(CANDIDATE_MODEL_VERSION),
        MAX(CANDIDATE_FEATURE_SET_VERSION)
    INTO
        :V_PRODUCTION_REQUEST_COUNT,
        :V_PRODUCTION_EVIDENCE_VERSION,
        :V_PRODUCTION_REQUEST_STATUS,
        :V_PRODUCTION_TARGET_MODE,
        :V_FROM_POLICY_ID,
        :V_FROM_POLICY_VERSION,
        :V_PRODUCTION_POLICY_ID,
        :V_PRODUCTION_POLICY_VERSION,
        :V_PRODUCTION_MODEL_NAME,
        :V_PRODUCTION_MODEL_VERSION,
        :V_PRODUCTION_FEATURE_SET_VERSION
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_PRODUCTION_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN = :V_MODEL_DOMAIN;

    IF (V_PRODUCTION_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one matching production deployment request is required.''
        );
    END IF;

    IF (
        V_PRODUCTION_TARGET_MODE <> ''PRODUCTION''
        OR V_PRODUCTION_REQUEST_STATUS IN (
            ''ACTIVATED'',
            ''ROLLED_BACK'',
            ''REJECTED'',
            ''CANCELLED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The linked request must be a non-terminal PRODUCTION request.'',
            ''target_mode'', V_PRODUCTION_TARGET_MODE,
            ''request_status'', V_PRODUCTION_REQUEST_STATUS
        );
    END IF;

    IF (
        V_FROM_POLICY_ID <> V_CONTROLLED_POLICY_ID
        OR V_FROM_POLICY_VERSION <> V_CONTROLLED_POLICY_VERSION
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Production source policy must exactly match the closed-pilot policy.'',
            ''production_from_policy_id'', V_FROM_POLICY_ID,
            ''production_from_policy_version'', V_FROM_POLICY_VERSION,
            ''pilot_controlled_policy_id'', V_CONTROLLED_POLICY_ID,
            ''pilot_controlled_policy_version'', V_CONTROLLED_POLICY_VERSION
        );
    END IF;

    IF (
        V_PRODUCTION_MODEL_NAME <> V_EXIT_MODEL_NAME
        OR V_PRODUCTION_MODEL_VERSION <> V_EXIT_MODEL_VERSION
        OR V_PRODUCTION_FEATURE_SET_VERSION <> V_EXIT_FEATURE_SET_VERSION
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Production model lineage must exactly match the closed pilot lineage.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_PRODUCTION_POLICY_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_ID = :V_PRODUCTION_POLICY_ID
      AND POLICY_VERSION = :V_PRODUCTION_POLICY_VERSION
      AND DEPLOYMENT_MODE = ''PRODUCTION''
      AND POLICY_STATUS = ''DRAFT'';

    IF (V_PRODUCTION_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Production candidate must remain one DRAFT PRODUCTION policy.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_ACTIVE_CONTROLLED_POLICY_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
    WHERE MODEL_DOMAIN = :V_MODEL_DOMAIN
      AND POLICY_ID = :V_CONTROLLED_POLICY_ID
      AND POLICY_VERSION = :V_CONTROLLED_POLICY_VERSION
      AND DEPLOYMENT_MODE = ''CONTROLLED'';

    IF (V_ACTIVE_CONTROLLED_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''The closed-pilot policy must remain the active CONTROLLED policy.''
        );
    END IF;

    SELECT COALESCE(COUNT_IF(LINK_STATUS = ''ACTIVE''), 0)::NUMBER
    INTO :V_EXISTING_ACTIVE_LINK_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
    WHERE PRODUCTION_DEPLOYMENT_REQUEST_ID = :P_PRODUCTION_DEPLOYMENT_REQUEST_ID
      AND PRODUCTION_EVIDENCE_VERSION = :V_PRODUCTION_EVIDENCE_VERSION;

    IF (V_EXISTING_ACTIVE_LINK_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''An ACTIVE pilot-exit link already exists for this production evidence version.''
        );
    END IF;

    SELECT MAX(ASSIGNED_AT)
    INTO :V_MAX_ASSIGNMENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_DECISION_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_INCIDENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(COMPLETED_AT)
    INTO :V_MAX_MONITORING_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    V_NEW_PILOT_DATA_FLAG :=
        (
            V_MAX_ASSIGNMENT_AT IS NOT NULL
            AND V_MAX_ASSIGNMENT_AT > V_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_DECISION_AT IS NOT NULL
            AND V_MAX_DECISION_AT > V_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_INCIDENT_AT IS NOT NULL
            AND V_MAX_INCIDENT_AT > V_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_MONITORING_AT IS NOT NULL
            AND V_MAX_MONITORING_AT > V_EXIT_CLOSED_AT
        );

    IF (V_NEW_PILOT_DATA_FLAG) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Pilot evidence changed after exit closure. A new exit assessment is required.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 (
        PROMOTION_LINK_ID,
        PRODUCTION_DEPLOYMENT_REQUEST_ID,
        PRODUCTION_EVIDENCE_VERSION,
        PILOT_EXIT_REQUEST_ID,
        PILOT_EXIT_EVIDENCE_VERSION,
        PILOT_PLAN_ID,
        MODEL_DOMAIN,
        CONTROLLED_POLICY_ID,
        CONTROLLED_POLICY_VERSION,
        PRODUCTION_CANDIDATE_POLICY_ID,
        PRODUCTION_CANDIDATE_POLICY_VERSION,
        CANDIDATE_MODEL_NAME,
        CANDIDATE_MODEL_VERSION,
        CANDIDATE_FEATURE_SET_VERSION,
        LINK_STATUS,
        LINK_REASON,
        REGISTERED_BY,
        REGISTERED_AT,
        UPDATED_AT
    )
    SELECT
        TRIM(:P_PROMOTION_LINK_ID),
        TRIM(:P_PRODUCTION_DEPLOYMENT_REQUEST_ID),
        :V_PRODUCTION_EVIDENCE_VERSION,
        TRIM(:P_PILOT_EXIT_REQUEST_ID),
        :V_EXIT_EVIDENCE_VERSION,
        :V_PILOT_PLAN_ID,
        :V_MODEL_DOMAIN,
        :V_CONTROLLED_POLICY_ID,
        :V_CONTROLLED_POLICY_VERSION,
        :V_PRODUCTION_POLICY_ID,
        :V_PRODUCTION_POLICY_VERSION,
        :V_PRODUCTION_MODEL_NAME,
        :V_PRODUCTION_MODEL_VERSION,
        :V_PRODUCTION_FEATURE_SET_VERSION,
        ''ACTIVE'',
        TRIM(:P_LINK_REASON),
        TRIM(:P_REGISTERED_BY),
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Production-promotion link insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PRODUCTION_PROMOTION_LINK_REGISTERED'',
        TRIM(:P_PILOT_EXIT_REQUEST_ID), :V_EXIT_EVIDENCE_VERSION,
        NULL::VARCHAR, NULL::VARCHAR, TRIM(:P_PROMOTION_LINK_ID),
        :V_PILOT_PLAN_ID,
        TRIM(:P_PRODUCTION_DEPLOYMENT_REQUEST_ID),
        :V_MODEL_DOMAIN, ''ACTIVE'', TRIM(:P_LINK_REASON),
        TRIM(:P_REGISTERED_BY), CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''promotion_link_id'', P_PROMOTION_LINK_ID,
        ''production_deployment_request_id'', P_PRODUCTION_DEPLOYMENT_REQUEST_ID,
        ''production_evidence_version'', V_PRODUCTION_EVIDENCE_VERSION,
        ''pilot_exit_request_id'', P_PILOT_EXIT_REQUEST_ID,
        ''pilot_exit_evidence_version'', V_EXIT_EVIDENCE_VERSION,
        ''model_domain'', V_MODEL_DOMAIN,
        ''link_status'', ''ACTIVE'',
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PRODUCTION_ACTIVATION_READINESS_V1
AS
SELECT
    request.DEPLOYMENT_REQUEST_ID,
    request.MODEL_DOMAIN,
    request.TARGET_MODE,

    request.FROM_POLICY_ID,
    request.FROM_POLICY_VERSION,

    request.CANDIDATE_POLICY_ID,
    request.CANDIDATE_POLICY_VERSION,

    request.CANDIDATE_MODEL_NAME,
    request.CANDIDATE_MODEL_VERSION,
    request.CANDIDATE_FEATURE_SET_VERSION,

    request.REQUEST_STATUS,
    request.EVIDENCE_VERSION,

    phase12a.PHASE12A_READINESS_STATUS,
    phase12a.BACKTEST_STATUS,
    phase12a.ACTIVATION_ELIGIBLE_V2_FLAG,

    link.PROMOTION_LINK_ID,
    link.PILOT_EXIT_REQUEST_ID,
    link.PILOT_EXIT_EVIDENCE_VERSION,
    link.PILOT_PLAN_ID,

    exit_request.REQUEST_STATUS AS PILOT_EXIT_REQUEST_STATUS,
    exit_request.CLOSED_AT AS PILOT_EXIT_CLOSED_AT,

    IFF(
        link.PROMOTION_LINK_ID IS NOT NULL
        AND link.PRODUCTION_EVIDENCE_VERSION = request.EVIDENCE_VERSION
        AND link.MODEL_DOMAIN = request.MODEL_DOMAIN
        AND link.CONTROLLED_POLICY_ID = request.FROM_POLICY_ID
        AND link.CONTROLLED_POLICY_VERSION = request.FROM_POLICY_VERSION
        AND link.PRODUCTION_CANDIDATE_POLICY_ID = request.CANDIDATE_POLICY_ID
        AND link.PRODUCTION_CANDIDATE_POLICY_VERSION =
            request.CANDIDATE_POLICY_VERSION
        AND link.CANDIDATE_MODEL_NAME = request.CANDIDATE_MODEL_NAME
        AND link.CANDIDATE_MODEL_VERSION = request.CANDIDATE_MODEL_VERSION
        AND link.CANDIDATE_FEATURE_SET_VERSION =
            request.CANDIDATE_FEATURE_SET_VERSION
        AND exit_request.REQUEST_STATUS = 'CLOSED_PASS',
        TRUE,
        FALSE
    ) AS PILOT_EXIT_LINK_VALID_FLAG,

    IFF(
        request.TARGET_MODE = 'PRODUCTION'
        AND phase12a.ACTIVATION_ELIGIBLE_V2_FLAG = TRUE
        AND link.PROMOTION_LINK_ID IS NOT NULL
        AND link.PRODUCTION_EVIDENCE_VERSION = request.EVIDENCE_VERSION
        AND link.MODEL_DOMAIN = request.MODEL_DOMAIN
        AND link.CONTROLLED_POLICY_ID = request.FROM_POLICY_ID
        AND link.CONTROLLED_POLICY_VERSION = request.FROM_POLICY_VERSION
        AND link.PRODUCTION_CANDIDATE_POLICY_ID = request.CANDIDATE_POLICY_ID
        AND link.PRODUCTION_CANDIDATE_POLICY_VERSION =
            request.CANDIDATE_POLICY_VERSION
        AND link.CANDIDATE_MODEL_NAME = request.CANDIDATE_MODEL_NAME
        AND link.CANDIDATE_MODEL_VERSION = request.CANDIDATE_MODEL_VERSION
        AND link.CANDIDATE_FEATURE_SET_VERSION =
            request.CANDIDATE_FEATURE_SET_VERSION
        AND exit_request.REQUEST_STATUS = 'CLOSED_PASS',
        TRUE,
        FALSE
    ) AS PRODUCTION_ACTIVATION_ELIGIBLE_V3_FLAG,

    CASE
        WHEN request.TARGET_MODE <> 'PRODUCTION'
            THEN 'NOT_PRODUCTION'
        WHEN phase12a.ACTIVATION_ELIGIBLE_V2_FLAG <> TRUE
            THEN COALESCE(
                phase12a.PHASE12A_READINESS_STATUS,
                'PHASE12A_NOT_READY'
            )
        WHEN link.PROMOTION_LINK_ID IS NULL
            THEN 'PILOT_EXIT_LINK_MISSING'
        WHEN exit_request.REQUEST_STATUS <> 'CLOSED_PASS'
            THEN 'PILOT_EXIT_NOT_CLOSED'
        WHEN (
            link.PRODUCTION_EVIDENCE_VERSION <> request.EVIDENCE_VERSION
            OR link.MODEL_DOMAIN <> request.MODEL_DOMAIN
            OR link.CONTROLLED_POLICY_ID <> request.FROM_POLICY_ID
            OR link.CONTROLLED_POLICY_VERSION <> request.FROM_POLICY_VERSION
            OR link.PRODUCTION_CANDIDATE_POLICY_ID <> request.CANDIDATE_POLICY_ID
            OR link.PRODUCTION_CANDIDATE_POLICY_VERSION
                <> request.CANDIDATE_POLICY_VERSION
            OR link.CANDIDATE_MODEL_NAME <> request.CANDIDATE_MODEL_NAME
            OR link.CANDIDATE_MODEL_VERSION <> request.CANDIDATE_MODEL_VERSION
            OR link.CANDIDATE_FEATURE_SET_VERSION
                <> request.CANDIDATE_FEATURE_SET_VERSION
        )
            THEN 'PILOT_EXIT_LINK_MISMATCH'
        ELSE 'PRODUCTION_ACTIVATION_READY'
    END AS PHASE12C_ACTIVATION_STATUS

FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 request
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DEPLOYMENT_REQUEST_READINESS_V2 phase12a
  ON request.DEPLOYMENT_REQUEST_ID = phase12a.DEPLOYMENT_REQUEST_ID
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PRODUCTION_PROMOTION_LINK_CURRENT_V1 link
  ON request.DEPLOYMENT_REQUEST_ID = link.PRODUCTION_DEPLOYMENT_REQUEST_ID
 AND request.EVIDENCE_VERSION = link.PRODUCTION_EVIDENCE_VERSION
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 exit_request
  ON link.PILOT_EXIT_REQUEST_ID = exit_request.EXIT_REQUEST_ID
 AND link.PILOT_EXIT_EVIDENCE_VERSION = exit_request.EVIDENCE_VERSION
WHERE request.TARGET_MODE = 'PRODUCTION';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(
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
    V_READINESS_COUNT NUMBER DEFAULT 0;

    V_TARGET_MODE VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_MODEL_DOMAIN VARCHAR;

    V_PHASE12C_STATUS VARCHAR;
    V_PROMOTION_LINK_ID VARCHAR;
    V_PILOT_EXIT_REQUEST_ID VARCHAR;
    V_PILOT_PLAN_ID VARCHAR;
    V_PILOT_EXIT_CLOSED_AT TIMESTAMP_NTZ;

    V_PILOT_EXIT_LINK_VALID BOOLEAN;
    V_PRODUCTION_ELIGIBLE BOOLEAN;

    V_MAX_ASSIGNMENT_AT TIMESTAMP_NTZ;
    V_MAX_DECISION_AT TIMESTAMP_NTZ;
    V_MAX_INCIDENT_AT TIMESTAMP_NTZ;
    V_MAX_MONITORING_AT TIMESTAMP_NTZ;
    V_NEW_PILOT_DATA_FLAG BOOLEAN DEFAULT FALSE;

    V_V2_RESULT VARIANT;
    V_V2_STATUS VARCHAR;
BEGIN
    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
        OR P_ACTIVATED_BY IS NULL
        OR LENGTH(TRIM(P_ACTIVATED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Deployment request and activation actor are required.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(TARGET_MODE),
        MAX(EVIDENCE_VERSION),
        MAX(MODEL_DOMAIN)
    INTO
        :V_REQUEST_COUNT,
        :V_TARGET_MODE,
        :V_EVIDENCE_VERSION,
        :V_MODEL_DOMAIN
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one deployment request is required.''
        );
    END IF;

    IF (V_TARGET_MODE = ''CONTROLLED'') THEN
        CALL
            KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(
                :P_DEPLOYMENT_REQUEST_ID,
                :P_ACTIVATED_BY,
                :P_CONFIRMATION_PHRASE
            )
        INTO :V_V2_RESULT;

        SELECT COALESCE(
            GET(:V_V2_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        )
        INTO :V_V2_STATUS;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', V_V2_STATUS,
            ''phase'', ''PHASE_12C'',
            ''target_mode'', ''CONTROLLED'',
            ''deployment_request_id'', P_DEPLOYMENT_REQUEST_ID,
            ''phase12a_activation_result'', V_V2_RESULT
        );
    END IF;

    IF (V_TARGET_MODE <> ''PRODUCTION'') THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''Target mode must be CONTROLLED or PRODUCTION.'',
            ''target_mode'', V_TARGET_MODE
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(PHASE12C_ACTIVATION_STATUS),
        MAX(PROMOTION_LINK_ID),
        MAX(PILOT_EXIT_REQUEST_ID),
        MAX(PILOT_PLAN_ID),
        MAX(PILOT_EXIT_CLOSED_AT),
        MAX(PILOT_EXIT_LINK_VALID_FLAG),
        MAX(PRODUCTION_ACTIVATION_ELIGIBLE_V3_FLAG)
    INTO
        :V_READINESS_COUNT,
        :V_PHASE12C_STATUS,
        :V_PROMOTION_LINK_ID,
        :V_PILOT_EXIT_REQUEST_ID,
        :V_PILOT_PLAN_ID,
        :V_PILOT_EXIT_CLOSED_AT,
        :V_PILOT_EXIT_LINK_VALID,
        :V_PRODUCTION_ELIGIBLE
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1
    WHERE DEPLOYMENT_REQUEST_ID = :P_DEPLOYMENT_REQUEST_ID
      AND EVIDENCE_VERSION = :V_EVIDENCE_VERSION;

    IF (V_READINESS_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one Phase 12C production-readiness row is required.'',
            ''readiness_count'', V_READINESS_COUNT
        );
    END IF;

    IF (
        NOT COALESCE(V_PILOT_EXIT_LINK_VALID, FALSE)
        OR NOT COALESCE(V_PRODUCTION_ELIGIBLE, FALSE)
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''message'', ''Production activation is blocked by the Phase 12C pilot-exit gate.'',
            ''deployment_request_id'', P_DEPLOYMENT_REQUEST_ID,
            ''evidence_version'', V_EVIDENCE_VERSION,
            ''phase12c_activation_status'', V_PHASE12C_STATUS,
            ''promotion_link_id'', V_PROMOTION_LINK_ID,
            ''pilot_exit_request_id'', V_PILOT_EXIT_REQUEST_ID,
            ''pilot_exit_link_valid'', V_PILOT_EXIT_LINK_VALID,
            ''production_activation_eligible_v3'', FALSE
        );
    END IF;

    SELECT MAX(ASSIGNED_AT)
    INTO :V_MAX_ASSIGNMENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_DECISION_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(UPDATED_AT)
    INTO :V_MAX_INCIDENT_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    SELECT MAX(COMPLETED_AT)
    INTO :V_MAX_MONITORING_AT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1
    WHERE PILOT_PLAN_ID = :V_PILOT_PLAN_ID;

    V_NEW_PILOT_DATA_FLAG :=
        (
            V_MAX_ASSIGNMENT_AT IS NOT NULL
            AND V_MAX_ASSIGNMENT_AT > V_PILOT_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_DECISION_AT IS NOT NULL
            AND V_MAX_DECISION_AT > V_PILOT_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_INCIDENT_AT IS NOT NULL
            AND V_MAX_INCIDENT_AT > V_PILOT_EXIT_CLOSED_AT
        )
        OR (
            V_MAX_MONITORING_AT IS NOT NULL
            AND V_MAX_MONITORING_AT > V_PILOT_EXIT_CLOSED_AT
        );

    IF (V_NEW_PILOT_DATA_FLAG) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''message'', ''Pilot evidence changed after formal exit closure. Production activation is blocked.''
        );
    END IF;

    CALL
        KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(
            :P_DEPLOYMENT_REQUEST_ID,
            :P_ACTIVATED_BY,
            :P_CONFIRMATION_PHRASE
        )
    INTO :V_V2_RESULT;

    SELECT COALESCE(
        GET(:V_V2_RESULT, ''status'')::VARCHAR,
        ''UNKNOWN''
    )
    INTO :V_V2_STATUS;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_V2_STATUS,
        ''phase'', ''PHASE_12C'',
        ''target_mode'', ''PRODUCTION'',
        ''deployment_request_id'', P_DEPLOYMENT_REQUEST_ID,
        ''evidence_version'', V_EVIDENCE_VERSION,
        ''phase12c_activation_status'', V_PHASE12C_STATUS,
        ''promotion_link_id'', V_PROMOTION_LINK_ID,
        ''pilot_exit_request_id'', V_PILOT_EXIT_REQUEST_ID,
        ''pilot_exit_link_valid'', TRUE,
        ''production_activation_eligible_v3'', TRUE,
        ''phase12a_activation_result'', V_V2_RESULT
    );
END;
';

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_PILOT_EXIT_REQUEST_V1(
        P_EXIT_REQUEST_ID VARCHAR,
        P_CANCELLATION_REASON VARCHAR,
        P_CANCELLED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_LINK_COUNT NUMBER DEFAULT 0;

    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;
    V_PILOT_PLAN_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;

    V_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_EXIT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_EXIT_REQUEST_ID)) = 0
        OR P_CANCELLATION_REASON IS NULL
        OR LENGTH(TRIM(P_CANCELLATION_REASON)) = 0
        OR P_CANCELLED_BY IS NULL
        OR LENGTH(TRIM(P_CANCELLED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exit request, cancellation reason and actor are required.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),
        MAX(PILOT_PLAN_ID),
        MAX(MODEL_DOMAIN)
    INTO
        :V_REQUEST_COUNT,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,
        :V_PILOT_PLAN_ID,
        :V_MODEL_DOMAIN
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_REQUEST_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Exactly one pilot-exit request is required.''
        );
    END IF;

    IF (
        V_REQUEST_STATUS NOT IN (
            ''DRAFT'',
            ''ASSESSMENT_BLOCKED'',
            ''SIGNOFF_PENDING'',
            ''APPROVED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'', ''The request cannot be cancelled in its current status.'',
            ''request_status'', V_REQUEST_STATUS
        );
    END IF;

    SELECT COALESCE(COUNT_IF(LINK_STATUS = ''ACTIVE''), 0)::NUMBER
    INTO :V_LINK_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
    WHERE PILOT_EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID;

    IF (V_LINK_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Pilot exit cannot be cancelled while an ACTIVE production link exists.''
        );
    END IF;

    V_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
    SET
        REQUEST_STATUS = ''CANCELLED'',
        CANCELLED_BY = TRIM(:P_CANCELLED_BY),
        CANCELLED_AT = CURRENT_TIMESTAMP(),
        CANCELLATION_REASON = TRIM(:P_CANCELLATION_REASON),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE EXIT_REQUEST_ID = :P_EXIT_REQUEST_ID
      AND REQUEST_STATUS = :V_REQUEST_STATUS;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Cancellation did not update exactly one request.''
        );
    END IF;

    INSERT INTO KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 (
        EVENT_ID, EVENT_TYPE,
        EXIT_REQUEST_ID, EVIDENCE_VERSION,
        ASSESSMENT_ID, SIGNOFF_ID, PROMOTION_LINK_ID,
        PILOT_PLAN_ID, PRODUCTION_DEPLOYMENT_REQUEST_ID,
        MODEL_DOMAIN, EVENT_STATUS, EVENT_REASON,
        EVENT_ACTOR, EVENT_AT
    )
    SELECT
        :V_EVENT_ID, ''PILOT_EXIT_REQUEST_CANCELLED'',
        TRIM(:P_EXIT_REQUEST_ID), :V_EVIDENCE_VERSION,
        NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR,
        :V_PILOT_PLAN_ID, NULL::VARCHAR,
        :V_MODEL_DOMAIN, ''CANCELLED'',
        TRIM(:P_CANCELLATION_REASON),
        TRIM(:P_CANCELLED_BY), CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_12C'',
        ''exit_request_id'', P_EXIT_REQUEST_ID,
        ''prior_status'', V_REQUEST_STATUS,
        ''request_status'', ''CANCELLED'',
        ''event_id'', V_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_12C'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12C_PRODUCTION_READINESS_V1
AS
SELECT
    readiness.EXIT_REQUEST_ID,
    readiness.PILOT_PLAN_ID,
    readiness.MODEL_DOMAIN,

    readiness.CONTROLLED_DEPLOYMENT_REQUEST_ID,
    readiness.CONTROLLED_POLICY_ID,
    readiness.CONTROLLED_POLICY_VERSION,

    readiness.CANDIDATE_MODEL_NAME,
    readiness.CANDIDATE_MODEL_VERSION,
    readiness.CANDIDATE_FEATURE_SET_VERSION,

    readiness.REQUEST_STATUS,
    readiness.EVIDENCE_VERSION,

    readiness.ASSESSMENT_STATUS,
    readiness.ASSESSMENT_REASON,
    readiness.ASSESSMENT_COMPLETED_AT,

    readiness.PILOT_DURATION_DAYS,
    readiness.ASSIGNED_COUNT,
    readiness.CONTROLLED_DECISION_COUNT,
    readiness.FALLBACK_RATE_PCT,
    readiness.ACTUAL_OUTCOME_COUNT,

    readiness.CANDIDATE_MAE,
    readiness.CANDIDATE_ADVANTAGE_VS_RULE,
    readiness.BMCS_BRIER_SCORE,
    readiness.BMCS_ACCURACY_PCT,

    readiness.OPEN_INCIDENT_COUNT,
    readiness.OPEN_CRITICAL_INCIDENT_COUNT,
    readiness.TOTAL_CRITICAL_INCIDENT_COUNT,
    readiness.UNAUTHORISED_CONTROLLED_USE_COUNT,
    readiness.GUARDRAIL_VIOLATION_COUNT,
    readiness.OFFICIAL_COST_CHANGE_COUNT,
    readiness.BMCS_DIRECT_COST_IMPACT_COUNT,
    readiness.AUTO_PAUSE_EVENT_COUNT,
    readiness.MANUAL_PAUSE_EVENT_COUNT,

    readiness.LATEST_MONITORING_STATUS,

    readiness.REQUIRED_SIGNOFF_COUNT,
    readiness.APPROVED_SIGNOFF_COUNT,
    readiness.REJECTED_SIGNOFF_COUNT,

    readiness.ASSESSMENT_FRESH_FLAG,
    readiness.ALL_SIGNOFFS_COMPLETE_FLAG,
    readiness.APPROVALS_AFTER_ASSESSMENT_FLAG,

    readiness.EXIT_READINESS_STATUS,
    readiness.EXIT_CLOSURE_ELIGIBLE_FLAG,

    link.PROMOTION_LINK_ID,
    link.PRODUCTION_DEPLOYMENT_REQUEST_ID,
    link.PRODUCTION_EVIDENCE_VERSION,
    link.LINK_STATUS,
    link.REGISTERED_AT,

    readiness.REQUESTED_BY,
    readiness.REQUESTED_AT,
    readiness.CLOSED_BY,
    readiness.CLOSED_AT,
    readiness.UPDATED_AT

FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_READINESS_V1 readiness
LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PRODUCTION_PROMOTION_LINK_CURRENT_V1 link
  ON readiness.EXIT_REQUEST_ID = link.PILOT_EXIT_REQUEST_ID
 AND readiness.EVIDENCE_VERSION = link.PILOT_EXIT_EVIDENCE_VERSION;

-- ============================================================
-- PHASE 12C — VERIFICATION
-- No exit request, sign-off, production link, or activation is created.
-- ============================================================

SHOW PROCEDURES LIKE 'CREATE_ML_PILOT_EXIT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'REFRESH_ML_PILOT_EXIT_ASSESSMENT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'REVIEW_ML_PILOT_EXIT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'CLOSE_ML_PILOT_EXIT_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'REGISTER_ML_PRODUCTION_PROMOTION_LINK_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE 'CANCEL_ML_PILOT_EXIT_REQUEST_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SELECT COUNT(DISTINCT PROCEDURE_NAME) AS PHASE12C_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'CREATE_ML_PILOT_EXIT_REQUEST_V1',
      'REFRESH_ML_PILOT_EXIT_ASSESSMENT_V1',
      'REVIEW_ML_PILOT_EXIT_V1',
      'CLOSE_ML_PILOT_EXIT_V1',
      'REGISTER_ML_PRODUCTION_PROMOTION_LINK_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',
      'CANCEL_ML_PILOT_EXIT_REQUEST_V1'
  );

SELECT
    COUNT(*) AS ACTIVE_EXIT_POLICY_COUNT,
    COALESCE(
        COUNT_IF(
            MODEL_DOMAIN NOT IN ('CSS','FMIS','TDS','BMCS')
            OR MIN_PILOT_DURATION_DAYS <= 0
            OR MIN_ASSIGNED_COUNT <= 0
            OR MIN_CONTROLLED_DECISION_COUNT <= 0
            OR MIN_ACTUAL_OUTCOME_COUNT <= 0
            OR MAX_FALLBACK_RATE_PCT < 0
            OR MAX_FALLBACK_RATE_PCT > 100
            OR MAX_TOTAL_CRITICAL_INCIDENT_COUNT < 0
            OR MAX_AUTO_PAUSE_EVENT_COUNT < 0
            OR MAX_MANUAL_PAUSE_EVENT_COUNT < 0
            OR MAX_EXPOSURE_PCT <= 0
            OR MAX_EXPOSURE_PCT > 25
            OR (
                MODEL_DOMAIN IN ('CSS','FMIS','TDS')
                AND (
                    MAX_CANDIDATE_MAE IS NULL
                    OR MIN_CANDIDATE_ADVANTAGE_VS_RULE IS NULL
                )
            )
            OR (
                MODEL_DOMAIN = 'BMCS'
                AND (
                    MAX_BMCS_BRIER_SCORE IS NULL
                    OR MIN_BMCS_ACCURACY_PCT IS NULL
                )
            )
        ),
        0
    )::NUMBER AS INVALID_EXIT_POLICY_ROWS
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_POLICY_CURRENT_V1;

SELECT MODEL_DOMAIN, COUNT(*) AS DUPLICATE_POLICY_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_POLICY_CURRENT_V1
GROUP BY MODEL_DOMAIN
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS SIGNOFF_REQUIREMENT_COUNT,
    COALESCE(
        COUNT_IF(MODEL_DOMAIN IN ('CSS','FMIS','TDS')),
        0
    )::NUMBER AS COST_DOMAIN_REQUIREMENT_COUNT,
    COALESCE(
        COUNT_IF(MODEL_DOMAIN = 'BMCS'),
        0
    )::NUMBER AS BMCS_REQUIREMENT_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1;

SELECT MODEL_DOMAIN, SIGNOFF_STAGE, COUNT(*) AS DUPLICATE_REQUIREMENT_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
GROUP BY MODEL_DOMAIN, SIGNOFF_STAGE
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS EXIT_REQUEST_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1;

SELECT
    COUNT(*) AS PROMOTION_LINK_COUNT,
    COALESCE(COUNT_IF(LINK_STATUS = 'ACTIVE'), 0)::NUMBER
        AS ACTIVE_PROMOTION_LINK_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1;

SELECT
    EXIT_REQUEST_ID,
    EVIDENCE_VERSION,
    SIGNOFF_STAGE,
    COUNT(*) AS DUPLICATE_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1
GROUP BY EXIT_REQUEST_ID, EVIDENCE_VERSION, SIGNOFF_STAGE
HAVING COUNT(*) > 1;

SELECT
    PRODUCTION_DEPLOYMENT_REQUEST_ID,
    PRODUCTION_EVIDENCE_VERSION,
    COUNT(*) AS DUPLICATE_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
WHERE LINK_STATUS = 'ACTIVE'
GROUP BY
    PRODUCTION_DEPLOYMENT_REQUEST_ID,
    PRODUCTION_EVIDENCE_VERSION
HAVING COUNT(*) > 1;

SELECT assessment.ASSESSMENT_ID
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 assessment
LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 request
  ON assessment.EXIT_REQUEST_ID = request.EXIT_REQUEST_ID
WHERE request.EXIT_REQUEST_ID IS NULL;

SELECT signoff.SIGNOFF_ID
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 signoff
LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 request
  ON signoff.EXIT_REQUEST_ID = request.EXIT_REQUEST_ID
WHERE request.EXIT_REQUEST_ID IS NULL;

SELECT link.PROMOTION_LINK_ID
FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 link
LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 exit_request
  ON link.PILOT_EXIT_REQUEST_ID = exit_request.EXIT_REQUEST_ID
LEFT JOIN KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 production_request
  ON link.PRODUCTION_DEPLOYMENT_REQUEST_ID =
     production_request.DEPLOYMENT_REQUEST_ID
WHERE exit_request.EXIT_REQUEST_ID IS NULL
   OR production_request.DEPLOYMENT_REQUEST_ID IS NULL;

SELECT COALESCE(
    COUNT_IF(
        PRODUCTION_ACTIVATION_ELIGIBLE_V3_FLAG = TRUE
        AND (
            TARGET_MODE <> 'PRODUCTION'
            OR ACTIVATION_ELIGIBLE_V2_FLAG <> TRUE
            OR PILOT_EXIT_LINK_VALID_FLAG <> TRUE
            OR PILOT_EXIT_REQUEST_STATUS <> 'CLOSED_PASS'
            OR PHASE12C_ACTIVATION_STATUS <> 'PRODUCTION_ACTIVATION_READY'
        )
    ),
    0
)::NUMBER AS INVALID_PRODUCTION_ELIGIBLE_ROWS
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1;

-- Negative, non-writing test. Expected controlled ERROR.
CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .REFRESH_ML_PILOT_EXIT_ASSESSMENT_V1(
            'PHASE12C_NEGATIVE_ASSESSMENT',
            'NONEXISTENT_EXIT_REQUEST',
            'PHASE12C_VERIFICATION'
        );

SELECT
    COUNT(*) AS ACTIVE_POLICY_COUNT,
    COALESCE(COUNT_IF(DEPLOYMENT_MODE = 'SHADOW'), 0)::NUMBER
        AS SHADOW_POLICY_COUNT,
    COALESCE(
        COUNT_IF(
            AUTO_USE_ALLOWED_FLAG = TRUE
            OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
            OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
        ),
        0
    )::NUMBER AS AUTHORITY_ENABLED_COUNT
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1;

SELECT *
FROM KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12C_PRODUCTION_READINESS_V1
ORDER BY UPDATED_AT DESC;

SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1
ORDER BY DEPLOYMENT_REQUEST_ID;

WITH PROCEDURES AS (
    SELECT COUNT(DISTINCT PROCEDURE_NAME) AS PROCEDURE_COUNT
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'CREATE_ML_PILOT_EXIT_REQUEST_V1',
          'REFRESH_ML_PILOT_EXIT_ASSESSMENT_V1',
          'REVIEW_ML_PILOT_EXIT_V1',
          'CLOSE_ML_PILOT_EXIT_V1',
          'REGISTER_ML_PRODUCTION_PROMOTION_LINK_V1',
          'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',
          'CANCEL_ML_PILOT_EXIT_REQUEST_V1'
      )
),
EXIT_POLICIES AS (
    SELECT
        COUNT(*) AS POLICY_COUNT,
        COALESCE(
            COUNT_IF(
                MODEL_DOMAIN NOT IN ('CSS','FMIS','TDS','BMCS')
                OR MIN_PILOT_DURATION_DAYS <= 0
                OR MIN_ASSIGNED_COUNT <= 0
                OR MIN_CONTROLLED_DECISION_COUNT <= 0
                OR MIN_ACTUAL_OUTCOME_COUNT <= 0
                OR MAX_FALLBACK_RATE_PCT < 0
                OR MAX_FALLBACK_RATE_PCT > 100
                OR MAX_TOTAL_CRITICAL_INCIDENT_COUNT < 0
                OR MAX_AUTO_PAUSE_EVENT_COUNT < 0
                OR MAX_MANUAL_PAUSE_EVENT_COUNT < 0
                OR MAX_EXPOSURE_PCT <= 0
                OR MAX_EXPOSURE_PCT > 25
            ),
            0
        )::NUMBER AS INVALID_POLICY_ROWS
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_PILOT_EXIT_POLICY_CURRENT_V1
),
REQUIREMENTS AS (
    SELECT
        COUNT(*) AS REQUIREMENT_COUNT,
        COALESCE(
            COUNT_IF(MODEL_DOMAIN IN ('CSS','FMIS','TDS')),
            0
        )::NUMBER AS COST_REQUIREMENT_COUNT,
        COALESCE(
            COUNT_IF(MODEL_DOMAIN = 'BMCS'),
            0
        )::NUMBER AS BMCS_REQUIREMENT_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_CURRENT_V1
),
REQUESTS AS (
    SELECT COUNT(*) AS EXIT_REQUEST_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1
),
LINKS AS (
    SELECT
        COUNT(*) AS PROMOTION_LINK_COUNT,
        COALESCE(COUNT_IF(LINK_STATUS = 'ACTIVE'), 0)::NUMBER
            AS ACTIVE_PROMOTION_LINK_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
),
SIGNOFF_DUPLICATES AS (
    SELECT COUNT(*) AS DUPLICATE_KEY_COUNT
    FROM (
        SELECT EXIT_REQUEST_ID, EVIDENCE_VERSION, SIGNOFF_STAGE
        FROM
            KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1
        GROUP BY EXIT_REQUEST_ID, EVIDENCE_VERSION, SIGNOFF_STAGE
        HAVING COUNT(*) > 1
    )
),
LINK_DUPLICATES AS (
    SELECT COUNT(*) AS DUPLICATE_KEY_COUNT
    FROM (
        SELECT
            PRODUCTION_DEPLOYMENT_REQUEST_ID,
            PRODUCTION_EVIDENCE_VERSION
        FROM
            KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1
        WHERE LINK_STATUS = 'ACTIVE'
        GROUP BY
            PRODUCTION_DEPLOYMENT_REQUEST_ID,
            PRODUCTION_EVIDENCE_VERSION
        HAVING COUNT(*) > 1
    )
),
ORPHANS AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_EXIT_ASSESSMENT_V1 assessment
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_EXIT_REQUEST_V1 request
              ON assessment.EXIT_REQUEST_ID = request.EXIT_REQUEST_ID
            WHERE request.EXIT_REQUEST_ID IS NULL
        )
        +
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_EXIT_SIGNOFF_V1 signoff
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_EXIT_REQUEST_V1 request
              ON signoff.EXIT_REQUEST_ID = request.EXIT_REQUEST_ID
            WHERE request.EXIT_REQUEST_ID IS NULL
        )
        +
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PRODUCTION_PROMOTION_LINK_V1 link
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_PILOT_EXIT_REQUEST_V1 exit_request
              ON link.PILOT_EXIT_REQUEST_ID = exit_request.EXIT_REQUEST_ID
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_DEPLOYMENT_REQUEST_V1 production_request
              ON link.PRODUCTION_DEPLOYMENT_REQUEST_ID =
                 production_request.DEPLOYMENT_REQUEST_ID
            WHERE exit_request.EXIT_REQUEST_ID IS NULL
               OR production_request.DEPLOYMENT_REQUEST_ID IS NULL
        ) AS ORPHAN_ROW_COUNT
),
ACTIVATION_SAFETY AS (
    SELECT COALESCE(
        COUNT_IF(
            PRODUCTION_ACTIVATION_ELIGIBLE_V3_FLAG = TRUE
            AND (
                TARGET_MODE <> 'PRODUCTION'
                OR ACTIVATION_ELIGIBLE_V2_FLAG <> TRUE
                OR PILOT_EXIT_LINK_VALID_FLAG <> TRUE
                OR PILOT_EXIT_REQUEST_STATUS <> 'CLOSED_PASS'
                OR PHASE12C_ACTIVATION_STATUS
                    <> 'PRODUCTION_ACTIVATION_READY'
            )
        ),
        0
    )::NUMBER AS INVALID_ACTIVATION_ROWS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1
),
POLICIES AS (
    SELECT
        COUNT(*) AS ACTIVE_POLICY_COUNT,
        COALESCE(COUNT_IF(DEPLOYMENT_MODE = 'SHADOW'), 0)::NUMBER
            AS SHADOW_POLICY_COUNT,
        COALESCE(
            COUNT_IF(
                AUTO_USE_ALLOWED_FLAG = TRUE
                OR OFFICIAL_COST_IMPACT_ALLOWED_FLAG = TRUE
                OR BUSINESS_DECISION_ALLOWED_FLAG = TRUE
            ),
            0
        )::NUMBER AS AUTHORITY_ENABLED_COUNT
    FROM KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_POLICY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            procedures.PROCEDURE_COUNT = 7
            AND exit_policies.POLICY_COUNT = 4
            AND exit_policies.INVALID_POLICY_ROWS = 0
            AND requirements.REQUIREMENT_COUNT = 15
            AND requirements.COST_REQUIREMENT_COUNT = 12
            AND requirements.BMCS_REQUIREMENT_COUNT = 3
            AND requests.EXIT_REQUEST_COUNT = 0
            AND links.PROMOTION_LINK_COUNT = 0
            AND links.ACTIVE_PROMOTION_LINK_COUNT = 0
            AND signoff_duplicates.DUPLICATE_KEY_COUNT = 0
            AND link_duplicates.DUPLICATE_KEY_COUNT = 0
            AND orphans.ORPHAN_ROW_COUNT = 0
            AND activation_safety.INVALID_ACTIVATION_ROWS = 0
            AND policies.ACTIVE_POLICY_COUNT = 4
            AND policies.SHADOW_POLICY_COUNT = 4
            AND policies.AUTHORITY_ENABLED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_12C',
    'procedure_count', procedures.PROCEDURE_COUNT,
    'active_exit_policy_count', exit_policies.POLICY_COUNT,
    'invalid_exit_policy_rows', exit_policies.INVALID_POLICY_ROWS,
    'signoff_requirement_count', requirements.REQUIREMENT_COUNT,
    'cost_domain_signoff_requirement_count',
        requirements.COST_REQUIREMENT_COUNT,
    'bmcs_signoff_requirement_count',
        requirements.BMCS_REQUIREMENT_COUNT,
    'exit_request_count', requests.EXIT_REQUEST_COUNT,
    'promotion_link_count', links.PROMOTION_LINK_COUNT,
    'active_promotion_link_count', links.ACTIVE_PROMOTION_LINK_COUNT,
    'duplicate_signoff_keys', signoff_duplicates.DUPLICATE_KEY_COUNT,
    'duplicate_promotion_link_keys', link_duplicates.DUPLICATE_KEY_COUNT,
    'orphan_row_count', orphans.ORPHAN_ROW_COUNT,
    'invalid_production_eligible_rows',
        activation_safety.INVALID_ACTIVATION_ROWS,
    'active_policy_count', policies.ACTIVE_POLICY_COUNT,
    'shadow_policy_count', policies.SHADOW_POLICY_COUNT,
    'authority_enabled_count', policies.AUTHORITY_ENABLED_COUNT,
    'production_activation_entry_point',
        'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',
    'production_promotion_authority', 'INACTIVE_GATE_ONLY',
    'official_cost_changed', FALSE,
    'policy_activated', FALSE
) AS PHASE12C_RESULT
FROM PROCEDURES procedures
CROSS JOIN EXIT_POLICIES exit_policies
CROSS JOIN REQUIREMENTS requirements
CROSS JOIN REQUESTS requests
CROSS JOIN LINKS links
CROSS JOIN SIGNOFF_DUPLICATES signoff_duplicates
CROSS JOIN LINK_DUPLICATES link_duplicates
CROSS JOIN ORPHANS orphans
CROSS JOIN ACTIVATION_SAFETY activation_safety
CROSS JOIN POLICIES policies;