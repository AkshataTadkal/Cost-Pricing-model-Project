-- Phase 13 governance RBAC, secure wrappers, and deployment workflow enforcement
-- Co-authored with CoCo
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- ============================================================
-- PHASE 13A — PREFLIGHT
--
-- Exact execution context:
--   ROLE      = SYSADMIN
--   WAREHOUSE = KMAT_WH
--   DATABASE  = KMAT_COST_MODEL_DB
--   SCHEMA    = CORE_ML
--
-- Every dependency is fully qualified.
-- ============================================================

SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;


-- Exact prerequisite procedure inventory.
SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_PILOT_MONITORING_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- Required objects. Expected: zero rows.
WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        ('CORE_ML','ML_DECISION_POLICY_V1'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1'),
        ('CORE_ML','VW_ML_DEPLOYMENT_REQUEST_READINESS_V2'),
        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1')
    AS required(
        SCHEMA_NAME,
        OBJECT_NAME
    )
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
ORDER BY
    required.SCHEMA_NAME,
    required.OBJECT_NAME;


-- Required columns. Expected: zero rows.
WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','MODEL_DOMAIN'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','POLICY_ID'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','POLICY_VERSION'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','DEPLOYMENT_MODE'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','AUTO_USE_ALLOWED_FLAG'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','OFFICIAL_COST_IMPACT_ALLOWED_FLAG'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','BUSINESS_DECISION_ALLOWED_FLAG'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','FINAL_VALUE_MIN'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','FINAL_VALUE_MAX'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','MAX_ABS_DEVIATION_FROM_RULE'),
        ('CORE_ML','VW_ML_DECISION_POLICY_CURRENT_V1','MAX_PCT_DEVIATION_FROM_RULE'),

        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','MODEL_DOMAIN'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','TARGET_MODE'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_ID'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','CANDIDATE_POLICY_VERSION'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','REQUEST_STATUS'),
        ('CORE_ML','ML_DEPLOYMENT_REQUEST_V1','EVIDENCE_VERSION'),

        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1','DEPLOYMENT_REQUEST_ID'),
        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1','EVIDENCE_VERSION'),
        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1','PRODUCTION_ACTIVATION_ELIGIBLE_V3_FLAG'),
        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1','PILOT_EXIT_LINK_VALID_FLAG'),
        ('CORE_ML','VW_ML_PRODUCTION_ACTIVATION_READINESS_V1','PILOT_EXIT_REQUEST_STATUS'),

        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','SIMULATION_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','KMAT_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','RFQ_ID'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','SAFETY_GATE_PASS_FLAG'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','COST_ENGINE_CONSUMPTION_ALLOWED_FLAG'),
        ('CORE_ML','VW_KMAT_PHASE10B_HIERARCHY_V1','OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG'),

        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','SIMULATION_ID'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','MODEL_DOMAIN'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','OUTCOME_AVAILABLE_FLAG'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_NUMERIC_VALUE'),
        ('CORE_ML','VW_KMAT_MODEL_FEEDBACK_DETAIL_V1','ACTUAL_MAPPING_CORRECT_FLAG')
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


-- Expected: 3.
SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE13A_REQUIRED_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',
      'RUN_ML_PILOT_MONITORING_V1'
  );


-- Current policy safety.
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

-- ============================================================
-- PHASE 13A — PRODUCTION HARDENING AND RUNTIME AUTHORITY
--
-- Exact deployment schema:
--   KMAT_COST_MODEL_DB.CORE_ML
--
-- Deployment safety:
--   * no runtime authority is created;
--   * global switch is OPEN;
--   * all four domain switches are BLOCKED;
--   * no policy is activated;
--   * no official cost is changed.
--
-- OBJECT_AGG calls: 0
-- VARIANT scripting variables in VALUES: 0
-- ============================================================


-- ============================================================
-- 1. RUNTIME SAFETY POLICY
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_POLICY_V1 (
            RUNTIME_SAFETY_POLICY_ID VARCHAR NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            AUTHORITY_MODE VARCHAR NOT NULL,
            POLICY_VERSION VARCHAR NOT NULL,

            POLICY_STATUS VARCHAR NOT NULL,

            MIN_MONITORING_DECISION_COUNT NUMBER NOT NULL,

            MAX_FALLBACK_RATE_PCT FLOAT NOT NULL,

            MAX_CANDIDATE_MAE FLOAT,
            MAX_BMCS_BRIER_SCORE FLOAT,
            MIN_BMCS_ACCURACY_PCT FLOAT,

            MAX_GUARDRAIL_VIOLATION_COUNT NUMBER NOT NULL,
            MAX_UNAUTHORISED_USE_COUNT NUMBER NOT NULL,
            MAX_OFFICIAL_COST_MUTATION_COUNT NUMBER NOT NULL,
            MAX_BMCS_DIRECT_COST_IMPACT_COUNT NUMBER NOT NULL,

            DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS NUMBER NOT NULL,
            DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS NUMBER NOT NULL,

            REQUIRE_ENGINEER_APPROVAL_FLAG BOOLEAN NOT NULL,
            AUTO_SUSPEND_ON_ATTENTION_FLAG BOOLEAN NOT NULL,

            EFFECTIVE_FROM TIMESTAMP_NTZ NOT NULL,
            EFFECTIVE_TO TIMESTAMP_NTZ,

            CREATED_BY VARCHAR NOT NULL,
            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),

            UPDATED_BY VARCHAR NOT NULL,
            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),

            COMMENTS VARCHAR
        );


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_POLICY_V1 target
USING (
    SELECT *
    FROM VALUES
        (
            'RUNTIME_CSS_CONTROLLED_V1',
            'CSS',
            'CONTROLLED',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            5,
            20.0,
            0.03,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            25,
            100,
            TRUE,
            TRUE,
            'Controlled CSS runtime thresholds.'
        ),
        (
            'RUNTIME_CSS_PRODUCTION_V1',
            'CSS',
            'PRODUCTION',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            20,
            10.0,
            0.02,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            500,
            10000,
            FALSE,
            TRUE,
            'Production CSS runtime thresholds.'
        ),
        (
            'RUNTIME_FMIS_CONTROLLED_V1',
            'FMIS',
            'CONTROLLED',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            5,
            20.0,
            0.03,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            25,
            100,
            TRUE,
            TRUE,
            'Controlled FMIS runtime thresholds.'
        ),
        (
            'RUNTIME_FMIS_PRODUCTION_V1',
            'FMIS',
            'PRODUCTION',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            20,
            10.0,
            0.02,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            500,
            10000,
            FALSE,
            TRUE,
            'Production FMIS runtime thresholds.'
        ),
        (
            'RUNTIME_TDS_CONTROLLED_V1',
            'TDS',
            'CONTROLLED',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            5,
            20.0,
            0.15,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            25,
            100,
            TRUE,
            TRUE,
            'Controlled TDS runtime thresholds.'
        ),
        (
            'RUNTIME_TDS_PRODUCTION_V1',
            'TDS',
            'PRODUCTION',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            20,
            10.0,
            0.10,
            NULL::FLOAT,
            NULL::FLOAT,
            0,
            0,
            0,
            0,
            500,
            10000,
            FALSE,
            TRUE,
            'Production TDS runtime thresholds.'
        ),
        (
            'RUNTIME_BMCS_CONTROLLED_V1',
            'BMCS',
            'CONTROLLED',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            10,
            20.0,
            NULL::FLOAT,
            0.15,
            80.0,
            0,
            0,
            0,
            0,
            25,
            100,
            TRUE,
            TRUE,
            'Controlled BMCS runtime thresholds.'
        ),
        (
            'RUNTIME_BMCS_PRODUCTION_V1',
            'BMCS',
            'PRODUCTION',
            'PHASE13A_RUNTIME_V1',
            'ACTIVE',
            30,
            10.0,
            NULL::FLOAT,
            0.10,
            90.0,
            0,
            0,
            0,
            0,
            500,
            10000,
            FALSE,
            TRUE,
            'Production BMCS runtime thresholds.'
        )
    AS seed(
        RUNTIME_SAFETY_POLICY_ID,
        MODEL_DOMAIN,
        AUTHORITY_MODE,
        POLICY_VERSION,
        POLICY_STATUS,
        MIN_MONITORING_DECISION_COUNT,
        MAX_FALLBACK_RATE_PCT,
        MAX_CANDIDATE_MAE,
        MAX_BMCS_BRIER_SCORE,
        MIN_BMCS_ACCURACY_PCT,
        MAX_GUARDRAIL_VIOLATION_COUNT,
        MAX_UNAUTHORISED_USE_COUNT,
        MAX_OFFICIAL_COST_MUTATION_COUNT,
        MAX_BMCS_DIRECT_COST_IMPACT_COUNT,
        DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS,
        DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS,
        REQUIRE_ENGINEER_APPROVAL_FLAG,
        AUTO_SUSPEND_ON_ATTENTION_FLAG,
        COMMENTS
    )
) source
ON target.RUNTIME_SAFETY_POLICY_ID =
   source.RUNTIME_SAFETY_POLICY_ID
WHEN NOT MATCHED THEN INSERT (
    RUNTIME_SAFETY_POLICY_ID,

    MODEL_DOMAIN,
    AUTHORITY_MODE,
    POLICY_VERSION,

    POLICY_STATUS,

    MIN_MONITORING_DECISION_COUNT,

    MAX_FALLBACK_RATE_PCT,

    MAX_CANDIDATE_MAE,
    MAX_BMCS_BRIER_SCORE,
    MIN_BMCS_ACCURACY_PCT,

    MAX_GUARDRAIL_VIOLATION_COUNT,
    MAX_UNAUTHORISED_USE_COUNT,
    MAX_OFFICIAL_COST_MUTATION_COUNT,
    MAX_BMCS_DIRECT_COST_IMPACT_COUNT,

    DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS,
    DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS,

    REQUIRE_ENGINEER_APPROVAL_FLAG,
    AUTO_SUSPEND_ON_ATTENTION_FLAG,

    EFFECTIVE_FROM,
    EFFECTIVE_TO,

    CREATED_BY,
    CREATED_AT,

    UPDATED_BY,
    UPDATED_AT,

    COMMENTS
)
VALUES (
    source.RUNTIME_SAFETY_POLICY_ID,

    source.MODEL_DOMAIN,
    source.AUTHORITY_MODE,
    source.POLICY_VERSION,

    source.POLICY_STATUS,

    source.MIN_MONITORING_DECISION_COUNT,

    source.MAX_FALLBACK_RATE_PCT,

    source.MAX_CANDIDATE_MAE,
    source.MAX_BMCS_BRIER_SCORE,
    source.MIN_BMCS_ACCURACY_PCT,

    source.MAX_GUARDRAIL_VIOLATION_COUNT,
    source.MAX_UNAUTHORISED_USE_COUNT,
    source.MAX_OFFICIAL_COST_MUTATION_COUNT,
    source.MAX_BMCS_DIRECT_COST_IMPACT_COUNT,

    source.DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS,
    source.DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS,

    source.REQUIRE_ENGINEER_APPROVAL_FLAG,
    source.AUTO_SUSPEND_ON_ATTENTION_FLAG,

    CURRENT_TIMESTAMP(),
    NULL::TIMESTAMP_NTZ,

    CURRENT_USER(),
    CURRENT_TIMESTAMP(),

    CURRENT_USER(),
    CURRENT_TIMESTAMP(),

    source.COMMENTS
);


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_POLICY_V1
WHERE POLICY_STATUS = 'ACTIVE'
  AND EFFECTIVE_FROM <= CURRENT_TIMESTAMP()
  AND (
      EFFECTIVE_TO IS NULL
      OR EFFECTIVE_TO > CURRENT_TIMESTAMP()
  )
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        MODEL_DOMAIN,
        AUTHORITY_MODE
    ORDER BY
        EFFECTIVE_FROM DESC,
        UPDATED_AT DESC,
        RUNTIME_SAFETY_POLICY_ID DESC
) = 1;


-- ============================================================
-- 2. ACTIVE POLICY FINGERPRINT
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
AS
SELECT
    MODEL_DOMAIN,
    POLICY_ID,
    POLICY_VERSION,
    DEPLOYMENT_MODE,

    AUTO_USE_ALLOWED_FLAG,
    OFFICIAL_COST_IMPACT_ALLOWED_FLAG,
    BUSINESS_DECISION_ALLOWED_FLAG,

    FINAL_VALUE_MIN,
    FINAL_VALUE_MAX,
    MAX_ABS_DEVIATION_FROM_RULE,
    MAX_PCT_DEVIATION_FROM_RULE,

    SHA2_HEX(
        COALESCE(MODEL_DOMAIN, '<NULL>')
        || '|'
        || COALESCE(POLICY_ID, '<NULL>')
        || '|'
        || COALESCE(POLICY_VERSION, '<NULL>')
        || '|'
        || COALESCE(DEPLOYMENT_MODE, '<NULL>')
        || '|'
        || COALESCE(
            AUTO_USE_ALLOWED_FLAG::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            OFFICIAL_COST_IMPACT_ALLOWED_FLAG::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            BUSINESS_DECISION_ALLOWED_FLAG::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            FINAL_VALUE_MIN::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            FINAL_VALUE_MAX::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            MAX_ABS_DEVIATION_FROM_RULE::VARCHAR,
            '<NULL>'
        )
        || '|'
        || COALESCE(
            MAX_PCT_DEVIATION_FROM_RULE::VARCHAR,
            '<NULL>'
        ),
        256
    ) AS POLICY_FINGERPRINT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_POLICY_CURRENT_V1;


-- ============================================================
-- 3. RUNTIME AUTHORITY, SWITCH, COUNTER AND DECISION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_REGISTRY_V1 (
            RUNTIME_AUTHORITY_ID VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            REQUEST_EVIDENCE_VERSION NUMBER NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            AUTHORITY_MODE VARCHAR NOT NULL,

            POLICY_ID VARCHAR NOT NULL,
            POLICY_VERSION VARCHAR NOT NULL,
            POLICY_FINGERPRINT VARCHAR NOT NULL,

            RUNTIME_SAFETY_POLICY_ID VARCHAR NOT NULL,
            RUNTIME_SAFETY_POLICY_VERSION VARCHAR NOT NULL,

            AUTHORITY_STATUS VARCHAR NOT NULL,
            AUTHORITY_STATUS_REASON VARCHAR NOT NULL,

            ALLOW_CANDIDATE_RUNTIME_FLAG BOOLEAN NOT NULL,
            ALLOW_OFFICIAL_COST_IMPACT_FLAG BOOLEAN NOT NULL,
            ALLOW_BUSINESS_DECISION_FLAG BOOLEAN NOT NULL,

            REQUIRE_ENGINEER_APPROVAL_FLAG BOOLEAN NOT NULL,

            MAX_DAILY_AUTHORISED_DECISIONS NUMBER NOT NULL,
            MAX_TOTAL_AUTHORISED_DECISIONS NUMBER NOT NULL,

            IS_ACTIVE BOOLEAN NOT NULL,

            REGISTERED_BY VARCHAR NOT NULL,
            REGISTERED_AT TIMESTAMP_NTZ NOT NULL,

            ENABLED_BY VARCHAR,
            ENABLED_AT TIMESTAMP_NTZ,

            SUSPENDED_BY VARCHAR,
            SUSPENDED_AT TIMESTAMP_NTZ,

            REVOKED_BY VARCHAR,
            REVOKED_AT TIMESTAMP_NTZ,

            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_KILL_SWITCH_V1 (
            SWITCH_EVENT_ID VARCHAR NOT NULL,

            SWITCH_SCOPE VARCHAR NOT NULL,
            SWITCH_STATUS VARCHAR NOT NULL,

            SWITCH_REASON VARCHAR NOT NULL,

            CHANGED_BY VARCHAR NOT NULL,
            CHANGED_AT TIMESTAMP_NTZ NOT NULL
        );


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_KILL_SWITCH_V1 target
USING (
    SELECT *
    FROM VALUES
        (
            'PHASE13A_GLOBAL_INITIAL',
            'GLOBAL',
            'OPEN',
            'Global runtime control plane installed.',
            'PHASE13A_DEPLOYMENT'
        ),
        (
            'PHASE13A_CSS_INITIAL',
            'CSS',
            'BLOCKED',
            'CSS runtime authority is disabled until explicit enablement.',
            'PHASE13A_DEPLOYMENT'
        ),
        (
            'PHASE13A_FMIS_INITIAL',
            'FMIS',
            'BLOCKED',
            'FMIS runtime authority is disabled until explicit enablement.',
            'PHASE13A_DEPLOYMENT'
        ),
        (
            'PHASE13A_TDS_INITIAL',
            'TDS',
            'BLOCKED',
            'TDS runtime authority is disabled until explicit enablement.',
            'PHASE13A_DEPLOYMENT'
        ),
        (
            'PHASE13A_BMCS_INITIAL',
            'BMCS',
            'BLOCKED',
            'BMCS runtime authority is disabled until explicit enablement.',
            'PHASE13A_DEPLOYMENT'
        )
    AS seed(
        SWITCH_EVENT_ID,
        SWITCH_SCOPE,
        SWITCH_STATUS,
        SWITCH_REASON,
        CHANGED_BY
    )
) source
ON target.SWITCH_EVENT_ID =
   source.SWITCH_EVENT_ID
WHEN NOT MATCHED THEN INSERT (
    SWITCH_EVENT_ID,

    SWITCH_SCOPE,
    SWITCH_STATUS,

    SWITCH_REASON,

    CHANGED_BY,
    CHANGED_AT
)
VALUES (
    source.SWITCH_EVENT_ID,

    source.SWITCH_SCOPE,
    source.SWITCH_STATUS,

    source.SWITCH_REASON,

    source.CHANGED_BY,
    CURRENT_TIMESTAMP()
);


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_COUNTER_V1 (
            COUNTER_ID VARCHAR NOT NULL,

            RUNTIME_AUTHORITY_ID VARCHAR NOT NULL,

            COUNTER_TYPE VARCHAR NOT NULL,
            COUNTER_DATE DATE,

            AUTHORISED_COUNT NUMBER NOT NULL,

            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),
            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_DECISION_V1 (
            RUNTIME_DECISION_ID VARCHAR NOT NULL,

            RUNTIME_AUTHORITY_ID VARCHAR,

            DEPLOYMENT_REQUEST_ID VARCHAR,
            REQUEST_EVIDENCE_VERSION NUMBER,

            MODEL_DOMAIN VARCHAR NOT NULL,
            AUTHORITY_MODE VARCHAR,

            POLICY_ID VARCHAR,
            POLICY_VERSION VARCHAR,
            EXPECTED_POLICY_FINGERPRINT VARCHAR,
            CURRENT_POLICY_FINGERPRINT VARCHAR,

            SIMULATION_ID VARCHAR NOT NULL,
            KMAT_ID VARCHAR,
            RFQ_ID VARCHAR,

            RULE_VALUE FLOAT,
            CANDIDATE_VALUE FLOAT,
            FINAL_RUNTIME_VALUE FLOAT,

            GLOBAL_SWITCH_OPEN_FLAG BOOLEAN NOT NULL,
            DOMAIN_SWITCH_OPEN_FLAG BOOLEAN NOT NULL,

            AUTHORITY_ENABLED_FLAG BOOLEAN NOT NULL,
            REQUEST_FRESH_FLAG BOOLEAN NOT NULL,
            POLICY_MATCH_FLAG BOOLEAN NOT NULL,
            POLICY_FINGERPRINT_MATCH_FLAG BOOLEAN NOT NULL,
            PRODUCTION_EXIT_GATE_PASS_FLAG BOOLEAN NOT NULL,

            SAFETY_GATE_PASS_FLAG BOOLEAN NOT NULL,
            COST_CONSUMPTION_ALLOWED_FLAG BOOLEAN NOT NULL,
            RECALCULATION_NOT_REQUIRED_FLAG BOOLEAN NOT NULL,

            QUALITY_PASS_FLAG BOOLEAN NOT NULL,
            OOD_FLAG BOOLEAN NOT NULL,

            BOUNDS_PASS_FLAG BOOLEAN NOT NULL,
            ABS_DEVIATION_PASS_FLAG BOOLEAN NOT NULL,
            PCT_DEVIATION_PASS_FLAG BOOLEAN NOT NULL,
            OVERALL_GUARDRAIL_PASS_FLAG BOOLEAN NOT NULL,

            ENGINEER_APPROVED_FLAG BOOLEAN NOT NULL,
            ENGINEER_APPROVAL_REFERENCE VARCHAR,

            CAPACITY_RESERVED_FLAG BOOLEAN NOT NULL,

            RUNTIME_AUTHORISED_FLAG BOOLEAN NOT NULL,

            OFFICIAL_COST_IMPACT_AUTHORISED_FLAG BOOLEAN NOT NULL,
            BUSINESS_DECISION_AUTHORISED_FLAG BOOLEAN NOT NULL,

            BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG BOOLEAN NOT NULL,
            OFFICIAL_COST_MUTATION_EXECUTED_FLAG BOOLEAN NOT NULL,

            FINAL_RUNTIME_SOURCE VARCHAR NOT NULL,
            DECISION_STATUS VARCHAR NOT NULL,
            DECISION_REASON VARCHAR NOT NULL,

            REQUESTED_BY VARCHAR NOT NULL,
            DECIDED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_MONITOR_RUN_V1 (
            MONITOR_RUN_ID VARCHAR NOT NULL,

            RUNTIME_AUTHORITY_ID VARCHAR NOT NULL,
            MODEL_DOMAIN VARCHAR NOT NULL,
            AUTHORITY_MODE VARCHAR NOT NULL,

            PRIOR_AUTHORITY_STATUS VARCHAR NOT NULL,
            RESULTING_AUTHORITY_STATUS VARCHAR NOT NULL,

            MONITORING_STATUS VARCHAR NOT NULL,
            MONITORING_REASON VARCHAR NOT NULL,

            DECISION_COUNT NUMBER NOT NULL,
            AUTHORISED_DECISION_COUNT NUMBER NOT NULL,
            FALLBACK_DECISION_COUNT NUMBER NOT NULL,
            FALLBACK_RATE_PCT FLOAT,

            ACTUAL_OUTCOME_COUNT NUMBER NOT NULL,

            CANDIDATE_MAE FLOAT,
            BMCS_BRIER_SCORE FLOAT,
            BMCS_ACCURACY_PCT FLOAT,

            GUARDRAIL_VIOLATION_COUNT NUMBER NOT NULL,
            UNAUTHORISED_USE_COUNT NUMBER NOT NULL,
            OFFICIAL_COST_MUTATION_COUNT NUMBER NOT NULL,
            BMCS_DIRECT_COST_IMPACT_COUNT NUMBER NOT NULL,

            GLOBAL_SWITCH_STATUS VARCHAR,
            DOMAIN_SWITCH_STATUS VARCHAR,

            AUTO_SUSPEND_TRIGGERED_FLAG BOOLEAN NOT NULL,

            RUN_BY VARCHAR NOT NULL,
            STARTED_AT TIMESTAMP_NTZ NOT NULL,
            COMPLETED_AT TIMESTAMP_NTZ NOT NULL,

            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
            EVENT_ID VARCHAR NOT NULL,
            EVENT_TYPE VARCHAR NOT NULL,

            RUNTIME_AUTHORITY_ID VARCHAR,
            RUNTIME_DECISION_ID VARCHAR,
            MONITOR_RUN_ID VARCHAR,

            DEPLOYMENT_REQUEST_ID VARCHAR,
            REQUEST_EVIDENCE_VERSION NUMBER,

            MODEL_DOMAIN VARCHAR,
            AUTHORITY_MODE VARCHAR,

            EVENT_STATUS VARCHAR NOT NULL,
            EVENT_REASON VARCHAR NOT NULL,

            EVENT_ACTOR VARCHAR NOT NULL,
            EVENT_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 4. CURRENT RUNTIME VIEWS
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_REGISTRY_V1
WHERE IS_ACTIVE = TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY MODEL_DOMAIN
    ORDER BY
        UPDATED_AT DESC,
        REGISTERED_AT DESC,
        RUNTIME_AUTHORITY_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_KILL_SWITCH_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY SWITCH_SCOPE
    ORDER BY
        CHANGED_AT DESC,
        SWITCH_EVENT_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_DECISION_CURRENT_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_DECISION_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY RUNTIME_DECISION_ID
    ORDER BY
        DECIDED_AT DESC,
        RUNTIME_DECISION_ID DESC
) = 1;


CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_SAFETY_MONITOR_LATEST_V1
AS
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY RUNTIME_AUTHORITY_ID
    ORDER BY
        COMPLETED_AT DESC,
        CREATED_AT DESC,
        MONITOR_RUN_ID DESC
) = 1;

-- ============================================================
-- 5. V4 ACTIVATION WRAPPER
--
-- V4 blocks the domain before delegating to V3.
-- A successful activation creates PENDING_ENABLE runtime
-- authority. Runtime use remains blocked until the separate
-- enable procedure succeeds.
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(
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
    V_EXISTING_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_ACTIVE_POLICY_COUNT NUMBER DEFAULT 0;
    V_SAFETY_POLICY_COUNT NUMBER DEFAULT 0;

    V_MODEL_DOMAIN VARCHAR;
    V_TARGET_MODE VARCHAR;
    V_REQUEST_STATUS VARCHAR;
    V_EVIDENCE_VERSION NUMBER;

    V_CANDIDATE_POLICY_ID VARCHAR;
    V_CANDIDATE_POLICY_VERSION VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_DEPLOYMENT_MODE VARCHAR;

    V_POLICY_FINGERPRINT VARCHAR;

    V_ALLOW_RUNTIME BOOLEAN;
    V_ALLOW_COST_IMPACT BOOLEAN;
    V_ALLOW_BUSINESS_DECISION BOOLEAN;

    V_RUNTIME_SAFETY_POLICY_ID VARCHAR;
    V_RUNTIME_SAFETY_POLICY_VERSION VARCHAR;

    V_REQUIRE_ENGINEER_APPROVAL BOOLEAN;
    V_MAX_DAILY NUMBER;
    V_MAX_TOTAL NUMBER;

    V_RUNTIME_AUTHORITY_ID VARCHAR;

    V_PREBLOCK_EVENT_ID VARCHAR;
    V_REGISTER_EVENT_ID VARCHAR;

    V_V3_RESULT VARIANT;
    V_V3_STATUS VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
        OR P_ACTIVATED_BY IS NULL
        OR LENGTH(TRIM(P_ACTIVATED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Deployment request and activation actor are required.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(MODEL_DOMAIN),
        MAX(TARGET_MODE),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION),

        MAX(CANDIDATE_POLICY_ID),
        MAX(CANDIDATE_POLICY_VERSION)

    INTO
        :V_REQUEST_COUNT,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,
        :V_REQUEST_STATUS,
        :V_EVIDENCE_VERSION,

        :V_CANDIDATE_POLICY_ID,
        :V_CANDIDATE_POLICY_VERSION

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
        V_TARGET_MODE NOT IN (
            ''CONTROLLED'',
            ''PRODUCTION''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''V4 activation supports CONTROLLED or PRODUCTION requests only.'',
            ''target_mode'', V_TARGET_MODE
        );
    END IF;

    SELECT
        COUNT(*)
    INTO :V_EXISTING_AUTHORITY_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :P_DEPLOYMENT_REQUEST_ID
      AND REQUEST_EVIDENCE_VERSION =
          :V_EVIDENCE_VERSION
      AND IS_ACTIVE = TRUE;

    IF (V_EXISTING_AUTHORITY_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_13A'',

                ''deployment_request_id'',
                    DEPLOYMENT_REQUEST_ID,
                ''request_evidence_version'',
                    REQUEST_EVIDENCE_VERSION,

                ''runtime_authority_id'',
                    RUNTIME_AUTHORITY_ID,
                ''model_domain'', MODEL_DOMAIN,
                ''authority_mode'', AUTHORITY_MODE,
                ''authority_status'', AUTHORITY_STATUS,

                ''runtime_enabled'',
                    AUTHORITY_STATUS = ''ENABLED''
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_AUTHORITY_REGISTRY_V1
            WHERE DEPLOYMENT_REQUEST_ID =
                  :P_DEPLOYMENT_REQUEST_ID
              AND REQUEST_EVIDENCE_VERSION =
                  :V_EVIDENCE_VERSION
              AND IS_ACTIVE = TRUE
        );
    END IF;

    IF (V_EXISTING_AUTHORITY_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Active runtime authority is not unique for the request evidence version.''
        );
    END IF;

    V_PREBLOCK_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    SET
        AUTHORITY_STATUS = ''SUSPENDED'',
        AUTHORITY_STATUS_REASON =
            ''Pre-activation runtime block for deployment request ''
            || TRIM(:P_DEPLOYMENT_REQUEST_ID),

        SUSPENDED_BY =
            TRIM(:P_ACTIVATED_BY),
        SUSPENDED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND IS_ACTIVE = TRUE
      AND AUTHORITY_STATUS =
          ''ENABLED'';

    V_UPDATED_ROWS := SQLROWCOUNT;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_KILL_SWITCH_V1 (
                SWITCH_EVENT_ID,

                SWITCH_SCOPE,
                SWITCH_STATUS,

                SWITCH_REASON,

                CHANGED_BY,
                CHANGED_AT
            )
    SELECT
        :V_PREBLOCK_EVENT_ID,

        :V_MODEL_DOMAIN,
        ''BLOCKED'',

        ''Pre-activation block for deployment request ''
        || TRIM(:P_DEPLOYMENT_REQUEST_ID),

        TRIM(:P_ACTIVATED_BY),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        UUID_STRING(),
        ''RUNTIME_PRE_ACTIVATION_BLOCK'',

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        ''BLOCKED'',
        ''Domain runtime blocked before V3 activation.'',

        TRIM(:P_ACTIVATED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(
                :P_DEPLOYMENT_REQUEST_ID,
                :P_ACTIVATED_BY,
                :P_CONFIRMATION_PHRASE
            )
    INTO :V_V3_RESULT;

    SELECT COALESCE(
        GET(:V_V3_RESULT, ''status'')::VARCHAR,
        ''UNKNOWN''
    )
    INTO :V_V3_STATUS;

    IF (V_V3_STATUS <> ''SUCCESS'') THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',

            ''message'',
            ''V3 activation did not succeed. The domain remains runtime-blocked.'',

            ''deployment_request_id'',
                P_DEPLOYMENT_REQUEST_ID,
            ''model_domain'', V_MODEL_DOMAIN,

            ''domain_runtime_switch'',
                ''BLOCKED'',

            ''phase12c_activation_result'',
                V_V3_RESULT
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(DEPLOYMENT_MODE),

        MAX(POLICY_FINGERPRINT),

        MAX(AUTO_USE_ALLOWED_FLAG),
        MAX(OFFICIAL_COST_IMPACT_ALLOWED_FLAG),
        MAX(BUSINESS_DECISION_ALLOWED_FLAG)

    INTO
        :V_ACTIVE_POLICY_COUNT,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_DEPLOYMENT_MODE,

        :V_POLICY_FINGERPRINT,

        :V_ALLOW_RUNTIME,
        :V_ALLOW_COST_IMPACT,
        :V_ALLOW_BUSINESS_DECISION

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1

    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_ID =
          :V_CANDIDATE_POLICY_ID
      AND POLICY_VERSION =
          :V_CANDIDATE_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          :V_TARGET_MODE;

    IF (V_ACTIVE_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',

            ''message'',
            ''V3 activated the request, but the exact active policy fingerprint could not be resolved. Runtime remains blocked.'',

            ''model_domain'', V_MODEL_DOMAIN,
            ''candidate_policy_id'',
                V_CANDIDATE_POLICY_ID,
            ''candidate_policy_version'',
                V_CANDIDATE_POLICY_VERSION,
            ''active_policy_count'',
                V_ACTIVE_POLICY_COUNT
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(RUNTIME_SAFETY_POLICY_ID),
        MAX(POLICY_VERSION),

        MAX(REQUIRE_ENGINEER_APPROVAL_FLAG),
        MAX(DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS),
        MAX(DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS)

    INTO
        :V_SAFETY_POLICY_COUNT,

        :V_RUNTIME_SAFETY_POLICY_ID,
        :V_RUNTIME_SAFETY_POLICY_VERSION,

        :V_REQUIRE_ENGINEER_APPROVAL,
        :V_MAX_DAILY,
        :V_MAX_TOTAL

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1

    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND AUTHORITY_MODE =
          :V_TARGET_MODE;

    IF (V_SAFETY_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',

            ''message'',
            ''V3 activated the request, but one runtime safety policy was not found. Runtime remains blocked.'',

            ''model_domain'', V_MODEL_DOMAIN,
            ''authority_mode'', V_TARGET_MODE,
            ''runtime_safety_policy_count'',
                V_SAFETY_POLICY_COUNT
        );
    END IF;

    V_RUNTIME_AUTHORITY_ID :=
        TRIM(P_DEPLOYMENT_REQUEST_ID)
        || ''::''
        || V_EVIDENCE_VERSION::VARCHAR
        || ''::RUNTIME'';

    V_REGISTER_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    SET
        IS_ACTIVE = FALSE,

        AUTHORITY_STATUS =
            IFF(
                AUTHORITY_STATUS = ''REVOKED'',
                ''REVOKED'',
                ''SUPERSEDED''
            ),

        AUTHORITY_STATUS_REASON =
            ''Superseded by runtime authority ''
            || :V_RUNTIME_AUTHORITY_ID,

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND IS_ACTIVE = TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1 (
                RUNTIME_AUTHORITY_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                POLICY_ID,
                POLICY_VERSION,
                POLICY_FINGERPRINT,

                RUNTIME_SAFETY_POLICY_ID,
                RUNTIME_SAFETY_POLICY_VERSION,

                AUTHORITY_STATUS,
                AUTHORITY_STATUS_REASON,

                ALLOW_CANDIDATE_RUNTIME_FLAG,
                ALLOW_OFFICIAL_COST_IMPACT_FLAG,
                ALLOW_BUSINESS_DECISION_FLAG,

                REQUIRE_ENGINEER_APPROVAL_FLAG,

                MAX_DAILY_AUTHORISED_DECISIONS,
                MAX_TOTAL_AUTHORISED_DECISIONS,

                IS_ACTIVE,

                REGISTERED_BY,
                REGISTERED_AT,

                ENABLED_BY,
                ENABLED_AT,

                SUSPENDED_BY,
                SUSPENDED_AT,

                REVOKED_BY,
                REVOKED_AT,

                UPDATED_AT
            )
    SELECT
        :V_RUNTIME_AUTHORITY_ID,

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_POLICY_FINGERPRINT,

        :V_RUNTIME_SAFETY_POLICY_ID,
        :V_RUNTIME_SAFETY_POLICY_VERSION,

        ''PENDING_ENABLE'',
        ''V3 activation succeeded. Explicit runtime enablement is still required.'',

        COALESCE(
            :V_ALLOW_RUNTIME,
            FALSE
        ),

        IFF(
            :V_MODEL_DOMAIN = ''BMCS'',
            FALSE,
            COALESCE(
                :V_ALLOW_COST_IMPACT,
                FALSE
            )
        ),

        COALESCE(
            :V_ALLOW_BUSINESS_DECISION,
            FALSE
        ),

        :V_REQUIRE_ENGINEER_APPROVAL,

        :V_MAX_DAILY,
        :V_MAX_TOTAL,

        TRUE,

        TRIM(:P_ACTIVATED_BY),
        CURRENT_TIMESTAMP(),

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,

        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',

            ''message'',
            ''V3 activation succeeded, but runtime authority registration failed. The domain remains blocked.'',

            ''runtime_authority_id'',
                V_RUNTIME_AUTHORITY_ID
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_COUNTER_V1 (
                COUNTER_ID,

                RUNTIME_AUTHORITY_ID,

                COUNTER_TYPE,
                COUNTER_DATE,

                AUTHORISED_COUNT,

                CREATED_AT,
                UPDATED_AT
            )
    SELECT
        :V_RUNTIME_AUTHORITY_ID
        || ''::TOTAL'',

        :V_RUNTIME_AUTHORITY_ID,

        ''TOTAL'',
        NULL::DATE,

        0,

        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_REGISTER_EVENT_ID,
        ''RUNTIME_AUTHORITY_REGISTERED'',

        :V_RUNTIME_AUTHORITY_ID,
        NULL::VARCHAR,
        NULL::VARCHAR,

        TRIM(:P_DEPLOYMENT_REQUEST_ID),
        :V_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_TARGET_MODE,

        ''PENDING_ENABLE'',
        ''Runtime authority registered after successful V3 activation. Domain remains blocked.'',

        TRIM(:P_ACTIVATED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_13A'',

        ''deployment_request_id'',
            P_DEPLOYMENT_REQUEST_ID,
        ''request_evidence_version'',
            V_EVIDENCE_VERSION,

        ''runtime_authority_id'',
            V_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''authority_mode'', V_TARGET_MODE,

        ''authority_status'',
            ''PENDING_ENABLE'',
        ''domain_runtime_switch'',
            ''BLOCKED'',

        ''policy_id'', V_POLICY_ID,
        ''policy_version'', V_POLICY_VERSION,
        ''policy_fingerprint'',
            V_POLICY_FINGERPRINT,

        ''runtime_enablement_required'',
            TRUE,

        ''phase12c_activation_result'',
            V_V3_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',

            ''message'',
            ''Phase 13A activation wrapper failed. The domain should remain blocked.'',

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

-- ============================================================
-- 6. EXPLICIT RUNTIME ENABLEMENT
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ENABLE_ML_RUNTIME_AUTHORITY_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_ENABLED_BY VARCHAR,
            P_ENABLE_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_POLICY_COUNT NUMBER DEFAULT 0;
    V_GLOBAL_SWITCH_COUNT NUMBER DEFAULT 0;
    V_PRODUCTION_READINESS_COUNT NUMBER DEFAULT 0;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_MODEL_DOMAIN VARCHAR;
    V_AUTHORITY_MODE VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_EXPECTED_FINGERPRINT VARCHAR;
    V_CURRENT_FINGERPRINT VARCHAR;

    V_AUTHORITY_STATUS VARCHAR;
    V_ALLOW_RUNTIME BOOLEAN;

    V_REQUEST_STATUS VARCHAR;
    V_CURRENT_REQUEST_EVIDENCE_VERSION NUMBER;

    V_GLOBAL_SWITCH_STATUS VARCHAR;

    V_PRODUCTION_LINK_VALID BOOLEAN;
    V_PILOT_EXIT_REQUEST_STATUS VARCHAR;

    V_LATEST_MONITOR_STATUS VARCHAR;

    V_SWITCH_EVENT_ID VARCHAR;
    V_AUDIT_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
    V_COUNTER_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_RUNTIME_AUTHORITY_ID IS NULL
        OR LENGTH(TRIM(P_RUNTIME_AUTHORITY_ID)) = 0
        OR P_ENABLED_BY IS NULL
        OR LENGTH(TRIM(P_ENABLED_BY)) = 0
        OR P_ENABLE_REASON IS NULL
        OR LENGTH(TRIM(P_ENABLE_REASON)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime authority, enable actor and reason are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> ''ENABLE_RUNTIME::''
               || P_RUNTIME_AUTHORITY_ID
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Confirmation must equal ENABLE_RUNTIME::<RUNTIME_AUTHORITY_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(MODEL_DOMAIN),
        MAX(AUTHORITY_MODE),

        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(POLICY_FINGERPRINT),

        MAX(AUTHORITY_STATUS),
        MAX(ALLOW_CANDIDATE_RUNTIME_FLAG)

    INTO
        :V_AUTHORITY_COUNT,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_EXPECTED_FINGERPRINT,

        :V_AUTHORITY_STATUS,
        :V_ALLOW_RUNTIME

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE;

    IF (V_AUTHORITY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one active runtime authority is required.'',
            ''authority_count'', V_AUTHORITY_COUNT
        );
    END IF;

    IF (
        V_AUTHORITY_STATUS NOT IN (
            ''PENDING_ENABLE'',
            ''SUSPENDED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Only PENDING_ENABLE or SUSPENDED authority can be enabled.'',
            ''authority_status'', V_AUTHORITY_STATUS
        );
    END IF;

    IF (NOT COALESCE(V_ALLOW_RUNTIME, FALSE)) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''The activated policy does not allow candidate runtime use.''
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_COUNT,
        :V_REQUEST_STATUS,
        :V_CURRENT_REQUEST_EVIDENCE_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :V_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND TARGET_MODE =
          :V_AUTHORITY_MODE
      AND CANDIDATE_POLICY_ID =
          :V_POLICY_ID
      AND CANDIDATE_POLICY_VERSION =
          :V_POLICY_VERSION;

    IF (
        V_REQUEST_COUNT <> 1
        OR V_REQUEST_STATUS <> ''ACTIVATED''
        OR V_CURRENT_REQUEST_EVIDENCE_VERSION
            <> V_REQUEST_EVIDENCE_VERSION
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''The exact deployment request must remain ACTIVATED and evidence-fresh.'',
            ''request_count'', V_REQUEST_COUNT,
            ''request_status'', V_REQUEST_STATUS,
            ''expected_evidence_version'',
                V_REQUEST_EVIDENCE_VERSION,
            ''current_evidence_version'',
                V_CURRENT_REQUEST_EVIDENCE_VERSION
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(POLICY_FINGERPRINT)
    INTO
        :V_POLICY_COUNT,
        :V_CURRENT_FINGERPRINT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND POLICY_ID =
          :V_POLICY_ID
      AND POLICY_VERSION =
          :V_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          :V_AUTHORITY_MODE;

    IF (
        V_POLICY_COUNT <> 1
        OR V_CURRENT_FINGERPRINT
            <> V_EXPECTED_FINGERPRINT
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Active policy identity or fingerprint no longer matches the registered authority.'',
            ''policy_count'', V_POLICY_COUNT,
            ''expected_policy_fingerprint'',
                V_EXPECTED_FINGERPRINT,
            ''current_policy_fingerprint'',
                V_CURRENT_FINGERPRINT
        );
    END IF;

    SELECT MAX(MONITORING_STATUS)
    INTO :V_LATEST_MONITOR_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_SAFETY_MONITOR_LATEST_V1
    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID;

    IF (
        V_AUTHORITY_STATUS = ''SUSPENDED''
        AND V_LATEST_MONITOR_STATUS =
            ''ATTENTION_REQUIRED''
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''A runtime authority suspended by an attention-required monitor cannot be re-enabled. A new governed deployment authority is required.''
        );
    END IF;

    IF (V_AUTHORITY_MODE = ''PRODUCTION'') THEN
        SELECT
            COUNT(*),

            MAX(PILOT_EXIT_LINK_VALID_FLAG),
            MAX(PILOT_EXIT_REQUEST_STATUS)

        INTO
            :V_PRODUCTION_READINESS_COUNT,

            :V_PRODUCTION_LINK_VALID,
            :V_PILOT_EXIT_REQUEST_STATUS

        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1

        WHERE DEPLOYMENT_REQUEST_ID =
              :V_DEPLOYMENT_REQUEST_ID
          AND EVIDENCE_VERSION =
              :V_REQUEST_EVIDENCE_VERSION;

        IF (
            V_PRODUCTION_READINESS_COUNT <> 1
            OR NOT COALESCE(
                V_PRODUCTION_LINK_VALID,
                FALSE
            )
            OR V_PILOT_EXIT_REQUEST_STATUS
                <> ''CLOSED_PASS''
        ) THEN
            RETURN OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''ERROR'',
                ''message'',
                ''Production runtime requires a valid CLOSED_PASS Phase 12C pilot-exit link.'',
                ''readiness_count'',
                    V_PRODUCTION_READINESS_COUNT,
                ''pilot_exit_link_valid'',
                    V_PRODUCTION_LINK_VALID,
                ''pilot_exit_request_status'',
                    V_PILOT_EXIT_REQUEST_STATUS
            );
        END IF;
    END IF;

    SELECT
        COUNT(*),
        MAX(SWITCH_STATUS)
    INTO
        :V_GLOBAL_SWITCH_COUNT,
        :V_GLOBAL_SWITCH_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE = ''GLOBAL'';

    IF (
        V_GLOBAL_SWITCH_COUNT <> 1
        OR V_GLOBAL_SWITCH_STATUS <> ''OPEN''
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Global runtime kill switch must be OPEN before domain enablement.'',
            ''global_switch_count'',
                V_GLOBAL_SWITCH_COUNT,
            ''global_switch_status'',
                V_GLOBAL_SWITCH_STATUS
        );
    END IF;

    V_SWITCH_EVENT_ID := UUID_STRING();
    V_AUDIT_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    SET
        AUTHORITY_STATUS =
            ''ENABLED'',
        AUTHORITY_STATUS_REASON =
            TRIM(:P_ENABLE_REASON),

        ENABLED_BY =
            TRIM(:P_ENABLED_BY),
        ENABLED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE
      AND AUTHORITY_STATUS =
          :V_AUTHORITY_STATUS;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime authority enablement did not update exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_COUNTER_V1 (
                COUNTER_ID,

                RUNTIME_AUTHORITY_ID,

                COUNTER_TYPE,
                COUNTER_DATE,

                AUTHORISED_COUNT,

                CREATED_AT,
                UPDATED_AT
            )
    SELECT
        TRIM(:P_RUNTIME_AUTHORITY_ID)
        || ''::TOTAL'',

        TRIM(:P_RUNTIME_AUTHORITY_ID),

        ''TOTAL'',
        NULL::DATE,

        0,

        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()

    WHERE NOT EXISTS (
        SELECT 1
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_COUNTER_V1
        WHERE COUNTER_ID =
              TRIM(:P_RUNTIME_AUTHORITY_ID)
              || ''::TOTAL''
    );

    V_COUNTER_INSERTED_ROWS := SQLROWCOUNT;

    IF (
        V_COUNTER_INSERTED_ROWS NOT IN (
            0,
            1
        )
    ) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Unexpected total runtime-counter insert count.'',
            ''inserted_rows'',
                V_COUNTER_INSERTED_ROWS
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_KILL_SWITCH_V1 (
                SWITCH_EVENT_ID,

                SWITCH_SCOPE,
                SWITCH_STATUS,

                SWITCH_REASON,

                CHANGED_BY,
                CHANGED_AT
            )
    SELECT
        :V_SWITCH_EVENT_ID,

        :V_MODEL_DOMAIN,
        ''OPEN'',

        TRIM(:P_ENABLE_REASON),

        TRIM(:P_ENABLED_BY),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_AUTHORITY_ENABLED'',

        TRIM(:P_RUNTIME_AUTHORITY_ID),
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        ''ENABLED'',
        TRIM(:P_ENABLE_REASON),

        TRIM(:P_ENABLED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13A'',

        ''runtime_authority_id'',
            P_RUNTIME_AUTHORITY_ID,

        ''deployment_request_id'',
            V_DEPLOYMENT_REQUEST_ID,
        ''request_evidence_version'',
            V_REQUEST_EVIDENCE_VERSION,

        ''model_domain'', V_MODEL_DOMAIN,
        ''authority_mode'', V_AUTHORITY_MODE,

        ''authority_status'', ''ENABLED'',
        ''domain_runtime_switch'', ''OPEN'',

        ''policy_fingerprint_match'',
            TRUE,
        ''request_evidence_fresh'',
            TRUE,

        ''official_cost_changed'', FALSE,
        ''switch_event_id'',
            V_SWITCH_EVENT_ID,
        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


-- ============================================================
-- 7. GLOBAL OR DOMAIN KILL SWITCH
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SET_ML_RUNTIME_KILL_SWITCH_V1(
            P_SWITCH_SCOPE VARCHAR,
            P_SWITCH_STATUS VARCHAR,
            P_SWITCH_REASON VARCHAR,
            P_CHANGED_BY VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_SCOPE VARCHAR;
    V_STATUS VARCHAR;
    V_REQUIRED_CONFIRMATION VARCHAR;

    V_ENABLED_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_SUSPENDED_AUTHORITY_COUNT NUMBER DEFAULT 0;

    V_SWITCH_EVENT_ID VARCHAR;
    V_AUDIT_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    V_SCOPE := UPPER(TRIM(P_SWITCH_SCOPE));
    V_STATUS := UPPER(TRIM(P_SWITCH_STATUS));

    IF (
        P_SWITCH_SCOPE IS NULL
        OR V_SCOPE NOT IN (
            ''GLOBAL'',
            ''CSS'',
            ''FMIS'',
            ''TDS'',
            ''BMCS''
        )
        OR P_SWITCH_STATUS IS NULL
        OR V_STATUS NOT IN (
            ''OPEN'',
            ''BLOCKED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Switch scope or status is invalid.''
        );
    END IF;

    IF (
        P_SWITCH_REASON IS NULL
        OR LENGTH(TRIM(P_SWITCH_REASON)) = 0
        OR P_CHANGED_BY IS NULL
        OR LENGTH(TRIM(P_CHANGED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Switch reason and actor are required.''
        );
    END IF;

    V_REQUIRED_CONFIRMATION :=
        IFF(
            V_STATUS = ''OPEN'',
            ''OPEN::'' || V_SCOPE,
            ''BLOCK::'' || V_SCOPE
        );

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> V_REQUIRED_CONFIRMATION
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Invalid kill-switch confirmation phrase.'',
            ''required_confirmation'',
                V_REQUIRED_CONFIRMATION
        );
    END IF;

    IF (
        V_STATUS = ''OPEN''
        AND V_SCOPE <> ''GLOBAL''
    ) THEN
        SELECT
            COALESCE(
                COUNT_IF(
                    AUTHORITY_STATUS = ''ENABLED''
                ),
                0
            )::NUMBER
        INTO :V_ENABLED_AUTHORITY_COUNT
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1
        WHERE MODEL_DOMAIN =
              :V_SCOPE;

        IF (V_ENABLED_AUTHORITY_COUNT <> 1) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''A domain switch can be opened only when exactly one ENABLED runtime authority exists.'',
                ''enabled_authority_count'',
                    V_ENABLED_AUTHORITY_COUNT
            );
        END IF;
    END IF;

    V_SWITCH_EVENT_ID := UUID_STRING();
    V_AUDIT_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    IF (V_STATUS = ''BLOCKED'') THEN
        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_REGISTRY_V1
        SET
            AUTHORITY_STATUS =
                ''SUSPENDED'',
            AUTHORITY_STATUS_REASON =
                ''Kill switch blocked: ''
                || TRIM(:P_SWITCH_REASON),

            SUSPENDED_BY =
                TRIM(:P_CHANGED_BY),
            SUSPENDED_AT =
                CURRENT_TIMESTAMP(),

            UPDATED_AT =
                CURRENT_TIMESTAMP()

        WHERE IS_ACTIVE = TRUE
          AND AUTHORITY_STATUS =
              ''ENABLED''
          AND (
              :V_SCOPE = ''GLOBAL''
              OR MODEL_DOMAIN =
                 :V_SCOPE
          );

        V_SUSPENDED_AUTHORITY_COUNT := SQLROWCOUNT;
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_KILL_SWITCH_V1 (
                SWITCH_EVENT_ID,

                SWITCH_SCOPE,
                SWITCH_STATUS,

                SWITCH_REASON,

                CHANGED_BY,
                CHANGED_AT
            )
    SELECT
        :V_SWITCH_EVENT_ID,

        :V_SCOPE,
        :V_STATUS,

        TRIM(:P_SWITCH_REASON),

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_KILL_SWITCH_CHANGED'',

        NULL::VARCHAR,
        NULL::VARCHAR,
        NULL::VARCHAR,

        NULL::VARCHAR,
        NULL::NUMBER,

        IFF(
            :V_SCOPE = ''GLOBAL'',
            NULL::VARCHAR,
            :V_SCOPE
        ),

        NULL::VARCHAR,

        :V_STATUS,
        TRIM(:P_SWITCH_REASON),

        TRIM(:P_CHANGED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13A'',

        ''switch_scope'', V_SCOPE,
        ''switch_status'', V_STATUS,

        ''suspended_authority_count'',
            V_SUSPENDED_AUTHORITY_COUNT,

        ''switch_event_id'',
            V_SWITCH_EVENT_ID,
        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

-- ============================================================
-- 8. DECISION-LEVEL RUNTIME AUTHORITY RESOLVER
--
-- This procedure authorises or blocks candidate runtime use.
-- It never mutates official cost itself.
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RESOLVE_ML_RUNTIME_AUTHORITY_V1(
            P_RUNTIME_DECISION_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_SIMULATION_ID VARCHAR,

            P_RULE_VALUE FLOAT,
            P_CANDIDATE_VALUE FLOAT,

            P_QUALITY_PASS_FLAG BOOLEAN,
            P_OOD_FLAG BOOLEAN,

            P_ENGINEER_APPROVED_FLAG BOOLEAN,
            P_ENGINEER_APPROVAL_REFERENCE VARCHAR,

            P_REQUESTED_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_DOMAIN VARCHAR;

    V_EXISTING_DECISION_COUNT NUMBER DEFAULT 0;
    V_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_GLOBAL_SWITCH_COUNT NUMBER DEFAULT 0;
    V_DOMAIN_SWITCH_COUNT NUMBER DEFAULT 0;
    V_REQUEST_COUNT NUMBER DEFAULT 0;
    V_POLICY_COUNT NUMBER DEFAULT 0;
    V_PRODUCTION_READINESS_COUNT NUMBER DEFAULT 0;
    V_HIERARCHY_COUNT NUMBER DEFAULT 0;

    V_RUNTIME_AUTHORITY_ID VARCHAR;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_AUTHORITY_MODE VARCHAR;
    V_AUTHORITY_STATUS VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_EXPECTED_FINGERPRINT VARCHAR;
    V_CURRENT_FINGERPRINT VARCHAR;

    V_ALLOW_RUNTIME BOOLEAN;
    V_ALLOW_COST_IMPACT BOOLEAN;
    V_ALLOW_BUSINESS_DECISION BOOLEAN;

    V_REQUIRE_ENGINEER_APPROVAL BOOLEAN;

    V_MAX_DAILY NUMBER;
    V_MAX_TOTAL NUMBER;

    V_GLOBAL_SWITCH_STATUS VARCHAR;
    V_DOMAIN_SWITCH_STATUS VARCHAR;

    V_REQUEST_STATUS VARCHAR;
    V_CURRENT_REQUEST_EVIDENCE_VERSION NUMBER;

    V_FINAL_MIN FLOAT;
    V_FINAL_MAX FLOAT;
    V_MAX_ABS_DEVIATION FLOAT;
    V_MAX_PCT_DEVIATION FLOAT;

    V_POLICY_AUTO_USE BOOLEAN;
    V_POLICY_COST_IMPACT BOOLEAN;
    V_POLICY_BUSINESS_DECISION BOOLEAN;

    V_PRODUCTION_LINK_VALID BOOLEAN;
    V_PILOT_EXIT_REQUEST_STATUS VARCHAR;

    V_KMAT_ID VARCHAR;
    V_RFQ_ID VARCHAR;

    V_SAFETY_GATE_PASS BOOLEAN;
    V_COST_CONSUMPTION_ALLOWED BOOLEAN;
    V_RECALC_REQUIRED BOOLEAN;

    V_GLOBAL_SWITCH_OPEN BOOLEAN DEFAULT FALSE;
    V_DOMAIN_SWITCH_OPEN BOOLEAN DEFAULT FALSE;

    V_AUTHORITY_ENABLED BOOLEAN DEFAULT FALSE;
    V_REQUEST_FRESH BOOLEAN DEFAULT FALSE;
    V_POLICY_MATCH BOOLEAN DEFAULT FALSE;
    V_POLICY_FINGERPRINT_MATCH BOOLEAN DEFAULT FALSE;
    V_PRODUCTION_EXIT_PASS BOOLEAN DEFAULT FALSE;

    V_SAFETY_PASS BOOLEAN DEFAULT FALSE;
    V_CONSUMPTION_PASS BOOLEAN DEFAULT FALSE;
    V_RECALC_NOT_REQUIRED BOOLEAN DEFAULT FALSE;

    V_BOUNDS_PASS BOOLEAN DEFAULT FALSE;
    V_ABS_PASS BOOLEAN DEFAULT FALSE;
    V_PCT_PASS BOOLEAN DEFAULT FALSE;
    V_GUARDRAIL_PASS BOOLEAN DEFAULT FALSE;

    V_ENGINEER_APPROVAL_PASS BOOLEAN DEFAULT FALSE;

    V_PRE_CAPACITY_AUTHORISED BOOLEAN DEFAULT FALSE;
    V_CAPACITY_RESERVED BOOLEAN DEFAULT FALSE;
    V_RUNTIME_AUTHORISED BOOLEAN DEFAULT FALSE;

    V_OFFICIAL_COST_IMPACT_AUTHORISED BOOLEAN DEFAULT FALSE;
    V_BUSINESS_DECISION_AUTHORISED BOOLEAN DEFAULT FALSE;

    V_FINAL_VALUE FLOAT;
    V_FINAL_SOURCE VARCHAR;

    V_DECISION_STATUS VARCHAR;
    V_DECISION_REASON VARCHAR;

    V_DAILY_COUNTER_MERGE_ROWS NUMBER DEFAULT 0;
    V_TOTAL_RESERVED_ROWS NUMBER DEFAULT 0;
    V_DAILY_RESERVED_ROWS NUMBER DEFAULT 0;

    V_DECISION_INSERTED_ROWS NUMBER DEFAULT 0;

    V_AUDIT_EVENT_ID VARCHAR;
    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    V_DOMAIN := UPPER(TRIM(P_MODEL_DOMAIN));

    IF (
        P_RUNTIME_DECISION_ID IS NULL
        OR LENGTH(TRIM(P_RUNTIME_DECISION_ID)) = 0
        OR P_MODEL_DOMAIN IS NULL
        OR V_DOMAIN NOT IN (
            ''CSS'',
            ''FMIS'',
            ''TDS'',
            ''BMCS''
        )
        OR P_SIMULATION_ID IS NULL
        OR LENGTH(TRIM(P_SIMULATION_ID)) = 0
        OR P_QUALITY_PASS_FLAG IS NULL
        OR P_OOD_FLAG IS NULL
        OR P_ENGINEER_APPROVED_FLAG IS NULL
        OR P_REQUESTED_BY IS NULL
        OR LENGTH(TRIM(P_REQUESTED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime decision ID, domain, simulation, flags and requester are required.''
        );
    END IF;

    IF (
        P_CANDIDATE_VALUE IS NULL
        AND P_QUALITY_PASS_FLAG
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''A quality-passing candidate requires P_CANDIDATE_VALUE.''
        );
    END IF;

    IF (
        P_ENGINEER_APPROVED_FLAG
        AND (
            P_ENGINEER_APPROVAL_REFERENCE IS NULL
            OR LENGTH(
                TRIM(
                    P_ENGINEER_APPROVAL_REFERENCE
                )
            ) = 0
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Engineer-approved runtime decisions require an approval reference.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_DECISION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_DECISION_V1
    WHERE RUNTIME_DECISION_ID =
          :P_RUNTIME_DECISION_ID;

    IF (V_EXISTING_DECISION_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_13A'',

                ''runtime_decision_id'',
                    RUNTIME_DECISION_ID,
                ''runtime_authority_id'',
                    RUNTIME_AUTHORITY_ID,

                ''model_domain'', MODEL_DOMAIN,
                ''authority_mode'', AUTHORITY_MODE,

                ''simulation_id'', SIMULATION_ID,

                ''runtime_authorised'',
                    RUNTIME_AUTHORISED_FLAG,

                ''official_cost_impact_authorised'',
                    OFFICIAL_COST_IMPACT_AUTHORISED_FLAG,

                ''business_decision_authorised'',
                    BUSINESS_DECISION_AUTHORISED_FLAG,

                ''final_runtime_source'',
                    FINAL_RUNTIME_SOURCE,
                ''final_runtime_value'',
                    FINAL_RUNTIME_VALUE,

                ''decision_status'',
                    DECISION_STATUS,
                ''decision_reason'',
                    DECISION_REASON,

                ''official_cost_mutation_executed'',
                    OFFICIAL_COST_MUTATION_EXECUTED_FLAG
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_AUTHORITY_DECISION_V1
            WHERE RUNTIME_DECISION_ID =
                  :P_RUNTIME_DECISION_ID
        );
    END IF;

    IF (V_EXISTING_DECISION_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''RUNTIME_DECISION_ID is not unique.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(RUNTIME_AUTHORITY_ID),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(AUTHORITY_MODE),
        MAX(AUTHORITY_STATUS),

        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(POLICY_FINGERPRINT),

        MAX(ALLOW_CANDIDATE_RUNTIME_FLAG),
        MAX(ALLOW_OFFICIAL_COST_IMPACT_FLAG),
        MAX(ALLOW_BUSINESS_DECISION_FLAG),

        MAX(REQUIRE_ENGINEER_APPROVAL_FLAG),

        MAX(MAX_DAILY_AUTHORISED_DECISIONS),
        MAX(MAX_TOTAL_AUTHORISED_DECISIONS)

    INTO
        :V_AUTHORITY_COUNT,

        :V_RUNTIME_AUTHORITY_ID,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_AUTHORITY_MODE,
        :V_AUTHORITY_STATUS,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_EXPECTED_FINGERPRINT,

        :V_ALLOW_RUNTIME,
        :V_ALLOW_COST_IMPACT,
        :V_ALLOW_BUSINESS_DECISION,

        :V_REQUIRE_ENGINEER_APPROVAL,

        :V_MAX_DAILY,
        :V_MAX_TOTAL

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1

    WHERE MODEL_DOMAIN =
          :V_DOMAIN;

    V_AUTHORITY_ENABLED :=
        V_AUTHORITY_COUNT = 1
        AND V_AUTHORITY_STATUS = ''ENABLED''
        AND COALESCE(
            V_ALLOW_RUNTIME,
            FALSE
        );

    SELECT
        COUNT(*),
        MAX(SWITCH_STATUS)
    INTO
        :V_GLOBAL_SWITCH_COUNT,
        :V_GLOBAL_SWITCH_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE = ''GLOBAL'';

    V_GLOBAL_SWITCH_OPEN :=
        V_GLOBAL_SWITCH_COUNT = 1
        AND V_GLOBAL_SWITCH_STATUS = ''OPEN'';

    SELECT
        COUNT(*),
        MAX(SWITCH_STATUS)
    INTO
        :V_DOMAIN_SWITCH_COUNT,
        :V_DOMAIN_SWITCH_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE =
          :V_DOMAIN;

    V_DOMAIN_SWITCH_OPEN :=
        V_DOMAIN_SWITCH_COUNT = 1
        AND V_DOMAIN_SWITCH_STATUS = ''OPEN'';

    SELECT
        COUNT(*),

        MAX(KMAT_ID),
        MAX(RFQ_ID),

        MAX(SAFETY_GATE_PASS_FLAG),
        MAX(COST_ENGINE_CONSUMPTION_ALLOWED_FLAG),
        MAX(OFFICIAL_COST_RECALCULATION_REQUIRED_FLAG)

    INTO
        :V_HIERARCHY_COUNT,

        :V_KMAT_ID,
        :V_RFQ_ID,

        :V_SAFETY_GATE_PASS,
        :V_COST_CONSUMPTION_ALLOWED,
        :V_RECALC_REQUIRED

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE10B_HIERARCHY_V1

    WHERE SIMULATION_ID =
          :P_SIMULATION_ID;

    V_SAFETY_PASS :=
        V_HIERARCHY_COUNT = 1
        AND COALESCE(
            V_SAFETY_GATE_PASS,
            FALSE
        );

    V_CONSUMPTION_PASS :=
        V_HIERARCHY_COUNT = 1
        AND COALESCE(
            V_COST_CONSUMPTION_ALLOWED,
            FALSE
        );

    V_RECALC_NOT_REQUIRED :=
        V_HIERARCHY_COUNT = 1
        AND NOT COALESCE(
            V_RECALC_REQUIRED,
            TRUE
        );

    IF (V_AUTHORITY_COUNT = 1) THEN
        SELECT
            COUNT(*),

            MAX(REQUEST_STATUS),
            MAX(EVIDENCE_VERSION)

        INTO
            :V_REQUEST_COUNT,

            :V_REQUEST_STATUS,
            :V_CURRENT_REQUEST_EVIDENCE_VERSION

        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_DEPLOYMENT_REQUEST_V1

        WHERE DEPLOYMENT_REQUEST_ID =
              :V_DEPLOYMENT_REQUEST_ID
          AND MODEL_DOMAIN =
              :V_DOMAIN
          AND TARGET_MODE =
              :V_AUTHORITY_MODE
          AND CANDIDATE_POLICY_ID =
              :V_POLICY_ID
          AND CANDIDATE_POLICY_VERSION =
              :V_POLICY_VERSION;

        V_REQUEST_FRESH :=
            V_REQUEST_COUNT = 1
            AND V_REQUEST_STATUS = ''ACTIVATED''
            AND V_CURRENT_REQUEST_EVIDENCE_VERSION
                = V_REQUEST_EVIDENCE_VERSION;

        SELECT
            COUNT(*),

            MAX(POLICY_FINGERPRINT),

            MAX(FINAL_VALUE_MIN::FLOAT),
            MAX(FINAL_VALUE_MAX::FLOAT),

            MAX(
                MAX_ABS_DEVIATION_FROM_RULE::FLOAT
            ),
            MAX(
                MAX_PCT_DEVIATION_FROM_RULE::FLOAT
            ),

            MAX(AUTO_USE_ALLOWED_FLAG),
            MAX(OFFICIAL_COST_IMPACT_ALLOWED_FLAG),
            MAX(BUSINESS_DECISION_ALLOWED_FLAG)

        INTO
            :V_POLICY_COUNT,

            :V_CURRENT_FINGERPRINT,

            :V_FINAL_MIN,
            :V_FINAL_MAX,

            :V_MAX_ABS_DEVIATION,
            :V_MAX_PCT_DEVIATION,

            :V_POLICY_AUTO_USE,
            :V_POLICY_COST_IMPACT,
            :V_POLICY_BUSINESS_DECISION

        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1

        WHERE MODEL_DOMAIN =
              :V_DOMAIN
          AND POLICY_ID =
              :V_POLICY_ID
          AND POLICY_VERSION =
              :V_POLICY_VERSION
          AND DEPLOYMENT_MODE =
              :V_AUTHORITY_MODE;

        V_POLICY_MATCH :=
            V_POLICY_COUNT = 1;

        V_POLICY_FINGERPRINT_MATCH :=
            V_POLICY_MATCH
            AND V_CURRENT_FINGERPRINT
                = V_EXPECTED_FINGERPRINT;

        IF (V_AUTHORITY_MODE = ''PRODUCTION'') THEN
            SELECT
                COUNT(*),

                MAX(PILOT_EXIT_LINK_VALID_FLAG),
                MAX(PILOT_EXIT_REQUEST_STATUS)

            INTO
                :V_PRODUCTION_READINESS_COUNT,

                :V_PRODUCTION_LINK_VALID,
                :V_PILOT_EXIT_REQUEST_STATUS

            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1

            WHERE DEPLOYMENT_REQUEST_ID =
                  :V_DEPLOYMENT_REQUEST_ID
              AND EVIDENCE_VERSION =
                  :V_REQUEST_EVIDENCE_VERSION;

            V_PRODUCTION_EXIT_PASS :=
                V_PRODUCTION_READINESS_COUNT = 1
                AND COALESCE(
                    V_PRODUCTION_LINK_VALID,
                    FALSE
                )
                AND V_PILOT_EXIT_REQUEST_STATUS =
                    ''CLOSED_PASS'';
        ELSE
            V_PRODUCTION_EXIT_PASS :=
                V_AUTHORITY_MODE = ''CONTROLLED'';
        END IF;
    END IF;

    V_BOUNDS_PASS :=
        P_CANDIDATE_VALUE IS NOT NULL
        AND (
            V_FINAL_MIN IS NULL
            OR P_CANDIDATE_VALUE >= V_FINAL_MIN
        )
        AND (
            V_FINAL_MAX IS NULL
            OR P_CANDIDATE_VALUE <= V_FINAL_MAX
        );

    V_ABS_PASS :=
        P_CANDIDATE_VALUE IS NOT NULL
        AND (
            V_MAX_ABS_DEVIATION IS NULL
            OR P_RULE_VALUE IS NULL
            OR ABS(
                P_CANDIDATE_VALUE
                - P_RULE_VALUE
            ) <= V_MAX_ABS_DEVIATION
        );

    V_PCT_PASS :=
        P_CANDIDATE_VALUE IS NOT NULL
        AND (
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
                <= V_MAX_PCT_DEVIATION
        );

    V_GUARDRAIL_PASS :=
        P_QUALITY_PASS_FLAG
        AND NOT P_OOD_FLAG
        AND P_CANDIDATE_VALUE IS NOT NULL
        AND (
            V_DOMAIN = ''BMCS''
            OR P_RULE_VALUE IS NOT NULL
        )
        AND V_BOUNDS_PASS
        AND V_ABS_PASS
        AND V_PCT_PASS;

    V_ENGINEER_APPROVAL_PASS :=
        NOT COALESCE(
            V_REQUIRE_ENGINEER_APPROVAL,
            TRUE
        )
        OR (
            P_ENGINEER_APPROVED_FLAG
            AND P_ENGINEER_APPROVAL_REFERENCE
                IS NOT NULL
            AND LENGTH(
                TRIM(
                    P_ENGINEER_APPROVAL_REFERENCE
                )
            ) > 0
        );

    V_PRE_CAPACITY_AUTHORISED :=
        V_AUTHORITY_ENABLED
        AND V_GLOBAL_SWITCH_OPEN
        AND V_DOMAIN_SWITCH_OPEN
        AND V_REQUEST_FRESH
        AND V_POLICY_MATCH
        AND V_POLICY_FINGERPRINT_MATCH
        AND V_PRODUCTION_EXIT_PASS
        AND V_SAFETY_PASS
        AND V_CONSUMPTION_PASS
        AND V_RECALC_NOT_REQUIRED
        AND V_GUARDRAIL_PASS
        AND V_ENGINEER_APPROVAL_PASS
        AND COALESCE(
            V_POLICY_AUTO_USE,
            FALSE
        );

    IF (V_PRE_CAPACITY_AUTHORISED) THEN
        BEGIN TRANSACTION;
        V_TRANSACTION_STARTED := TRUE;

        MERGE INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_COUNTER_V1 target
        USING (
            SELECT
                :V_RUNTIME_AUTHORITY_ID
                || ''::DAILY::''
                || CURRENT_DATE()::VARCHAR
                    AS COUNTER_ID
        ) source
        ON target.COUNTER_ID =
           source.COUNTER_ID
        WHEN NOT MATCHED THEN INSERT (
            COUNTER_ID,

            RUNTIME_AUTHORITY_ID,

            COUNTER_TYPE,
            COUNTER_DATE,

            AUTHORISED_COUNT,

            CREATED_AT,
            UPDATED_AT
        )
        VALUES (
            source.COUNTER_ID,

            :V_RUNTIME_AUTHORITY_ID,

            ''DAILY'',
            CURRENT_DATE(),

            0,

            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );

        V_DAILY_COUNTER_MERGE_ROWS := SQLROWCOUNT;

        IF (
            V_DAILY_COUNTER_MERGE_ROWS NOT IN (
                0,
                1
            )
        ) THEN
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Unexpected daily runtime-counter MERGE count.'',
                ''affected_rows'',
                    V_DAILY_COUNTER_MERGE_ROWS
            );
        END IF;

        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_COUNTER_V1
        SET
            AUTHORISED_COUNT =
                AUTHORISED_COUNT + 1,
            UPDATED_AT =
                CURRENT_TIMESTAMP()
        WHERE COUNTER_ID =
              :V_RUNTIME_AUTHORITY_ID
              || ''::TOTAL''
          AND AUTHORISED_COUNT <
              :V_MAX_TOTAL;

        V_TOTAL_RESERVED_ROWS := SQLROWCOUNT;

        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_COUNTER_V1
        SET
            AUTHORISED_COUNT =
                AUTHORISED_COUNT + 1,
            UPDATED_AT =
                CURRENT_TIMESTAMP()
        WHERE COUNTER_ID =
              :V_RUNTIME_AUTHORITY_ID
              || ''::DAILY::''
              || CURRENT_DATE()::VARCHAR
          AND AUTHORISED_COUNT <
              :V_MAX_DAILY;

        V_DAILY_RESERVED_ROWS := SQLROWCOUNT;

        IF (
            V_TOTAL_RESERVED_ROWS = 1
            AND V_DAILY_RESERVED_ROWS = 1
        ) THEN
            V_CAPACITY_RESERVED := TRUE;
            V_RUNTIME_AUTHORISED := TRUE;
        ELSE
            ROLLBACK;
            V_TRANSACTION_STARTED := FALSE;

            V_CAPACITY_RESERVED := FALSE;
            V_RUNTIME_AUTHORISED := FALSE;
        END IF;
    END IF;

    V_OFFICIAL_COST_IMPACT_AUTHORISED :=
        V_RUNTIME_AUTHORISED
        AND V_DOMAIN <> ''BMCS''
        AND COALESCE(
            V_ALLOW_COST_IMPACT,
            FALSE
        )
        AND COALESCE(
            V_POLICY_COST_IMPACT,
            FALSE
        );

    V_BUSINESS_DECISION_AUTHORISED :=
        V_RUNTIME_AUTHORISED
        AND COALESCE(
            V_ALLOW_BUSINESS_DECISION,
            FALSE
        )
        AND COALESCE(
            V_POLICY_BUSINESS_DECISION,
            FALSE
        );

    IF (V_RUNTIME_AUTHORISED) THEN
        V_FINAL_VALUE :=
            P_CANDIDATE_VALUE;

        V_FINAL_SOURCE :=
            IFF(
                V_AUTHORITY_MODE = ''PRODUCTION'',
                ''CANDIDATE_PRODUCTION'',
                ''CANDIDATE_CONTROLLED''
            );

        V_DECISION_STATUS :=
            ''RUNTIME_AUTHORISED'';

        V_DECISION_REASON :=
            ''Runtime authority, switches, evidence, policy fingerprint, safety, guardrail, approval and capacity checks passed.'';

    ELSE
        V_FINAL_VALUE :=
            P_RULE_VALUE;

        V_FINAL_SOURCE :=
            ''DETERMINISTIC_FALLBACK'';

        V_DECISION_STATUS :=
            ''RUNTIME_BLOCKED'';

        V_DECISION_REASON :=
            CASE
                WHEN V_AUTHORITY_COUNT <> 1
                    THEN ''No unique active runtime authority exists for the model domain.''
                WHEN NOT V_AUTHORITY_ENABLED
                    THEN ''Runtime authority is not ENABLED.''
                WHEN NOT V_GLOBAL_SWITCH_OPEN
                    THEN ''Global runtime kill switch is BLOCKED or missing.''
                WHEN NOT V_DOMAIN_SWITCH_OPEN
                    THEN ''Domain runtime kill switch is BLOCKED or missing.''
                WHEN NOT V_REQUEST_FRESH
                    THEN ''Deployment request is not ACTIVATED or evidence-fresh.''
                WHEN NOT V_POLICY_MATCH
                    THEN ''The exact active policy no longer matches the authority.''
                WHEN NOT V_POLICY_FINGERPRINT_MATCH
                    THEN ''The active policy fingerprint changed after registration.''
                WHEN NOT V_PRODUCTION_EXIT_PASS
                    THEN ''Production pilot-exit gate is not valid.''
                WHEN NOT V_SAFETY_PASS
                    THEN ''Phase 10B safety gate did not pass.''
                WHEN NOT V_CONSUMPTION_PASS
                    THEN ''Cost-engine consumption is not allowed.''
                WHEN NOT V_RECALC_NOT_REQUIRED
                    THEN ''Official cost recalculation is required.''
                WHEN NOT V_GUARDRAIL_PASS
                    THEN ''Quality, OOD, bounds or deviation guardrail failed.''
                WHEN NOT V_ENGINEER_APPROVAL_PASS
                    THEN ''Required engineer approval is missing.''
                WHEN V_PRE_CAPACITY_AUTHORISED
                 AND NOT V_CAPACITY_RESERVED
                    THEN ''Runtime daily or total capacity is exhausted.''
                ELSE ''Runtime candidate use is not authorised.''
            END;
    END IF;

    V_AUDIT_EVENT_ID := UUID_STRING();

    IF (NOT V_TRANSACTION_STARTED) THEN
        BEGIN TRANSACTION;
        V_TRANSACTION_STARTED := TRUE;
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_DECISION_V1 (
                RUNTIME_DECISION_ID,

                RUNTIME_AUTHORITY_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                POLICY_ID,
                POLICY_VERSION,
                EXPECTED_POLICY_FINGERPRINT,
                CURRENT_POLICY_FINGERPRINT,

                SIMULATION_ID,
                KMAT_ID,
                RFQ_ID,

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

                SAFETY_GATE_PASS_FLAG,
                COST_CONSUMPTION_ALLOWED_FLAG,
                RECALCULATION_NOT_REQUIRED_FLAG,

                QUALITY_PASS_FLAG,
                OOD_FLAG,

                BOUNDS_PASS_FLAG,
                ABS_DEVIATION_PASS_FLAG,
                PCT_DEVIATION_PASS_FLAG,
                OVERALL_GUARDRAIL_PASS_FLAG,

                ENGINEER_APPROVED_FLAG,
                ENGINEER_APPROVAL_REFERENCE,

                CAPACITY_RESERVED_FLAG,

                RUNTIME_AUTHORISED_FLAG,

                OFFICIAL_COST_IMPACT_AUTHORISED_FLAG,
                BUSINESS_DECISION_AUTHORISED_FLAG,

                BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG,
                OFFICIAL_COST_MUTATION_EXECUTED_FLAG,

                FINAL_RUNTIME_SOURCE,
                DECISION_STATUS,
                DECISION_REASON,

                REQUESTED_BY,
                DECIDED_AT
            )
    SELECT
        TRIM(:P_RUNTIME_DECISION_ID),

        :V_RUNTIME_AUTHORITY_ID,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_EXPECTED_FINGERPRINT,
        :V_CURRENT_FINGERPRINT,

        TRIM(:P_SIMULATION_ID),
        :V_KMAT_ID,
        :V_RFQ_ID,

        :P_RULE_VALUE,
        :P_CANDIDATE_VALUE,
        :V_FINAL_VALUE,

        :V_GLOBAL_SWITCH_OPEN,
        :V_DOMAIN_SWITCH_OPEN,

        :V_AUTHORITY_ENABLED,
        :V_REQUEST_FRESH,
        :V_POLICY_MATCH,
        :V_POLICY_FINGERPRINT_MATCH,
        :V_PRODUCTION_EXIT_PASS,

        :V_SAFETY_PASS,
        :V_CONSUMPTION_PASS,
        :V_RECALC_NOT_REQUIRED,

        :P_QUALITY_PASS_FLAG,
        :P_OOD_FLAG,

        :V_BOUNDS_PASS,
        :V_ABS_PASS,
        :V_PCT_PASS,
        :V_GUARDRAIL_PASS,

        :P_ENGINEER_APPROVED_FLAG,
        :P_ENGINEER_APPROVAL_REFERENCE,

        :V_CAPACITY_RESERVED,

        :V_RUNTIME_AUTHORISED,

        :V_OFFICIAL_COST_IMPACT_AUTHORISED,
        :V_BUSINESS_DECISION_AUTHORISED,

        FALSE,
        FALSE,

        :V_FINAL_SOURCE,
        :V_DECISION_STATUS,
        :V_DECISION_REASON,

        TRIM(:P_REQUESTED_BY),
        CURRENT_TIMESTAMP();

    V_DECISION_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_DECISION_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime decision insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_AUTHORITY_DECISION'',

        :V_RUNTIME_AUTHORITY_ID,
        TRIM(:P_RUNTIME_DECISION_ID),
        NULL::VARCHAR,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_DECISION_STATUS,
        :V_DECISION_REASON,

        TRIM(:P_REQUESTED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_13A'',

        ''runtime_decision_id'',
            P_RUNTIME_DECISION_ID,
        ''runtime_authority_id'',
            V_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_DOMAIN,
        ''authority_mode'', V_AUTHORITY_MODE,

        ''simulation_id'', P_SIMULATION_ID,

        ''runtime_authorised'',
            V_RUNTIME_AUTHORISED,

        ''official_cost_impact_authorised'',
            V_OFFICIAL_COST_IMPACT_AUTHORISED,

        ''business_decision_authorised'',
            V_BUSINESS_DECISION_AUTHORISED,

        ''bmcs_direct_cost_impact_allowed'',
            FALSE,

        ''final_runtime_source'',
            V_FINAL_SOURCE,
        ''final_runtime_value'',
            V_FINAL_VALUE,

        ''decision_status'',
            V_DECISION_STATUS,
        ''decision_reason'',
            V_DECISION_REASON,

        ''policy_fingerprint_match'',
            V_POLICY_FINGERPRINT_MATCH,
        ''request_evidence_fresh'',
            V_REQUEST_FRESH,

        ''capacity_reserved'',
            V_CAPACITY_RESERVED,

        ''official_cost_mutation_executed'',
            FALSE,

        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

-- ============================================================
-- 9. RUNTIME OUTCOME DETAIL
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_OUTCOME_DETAIL_V1
AS
SELECT
    decision.RUNTIME_DECISION_ID,
    decision.RUNTIME_AUTHORITY_ID,

    decision.DEPLOYMENT_REQUEST_ID,
    decision.REQUEST_EVIDENCE_VERSION,

    decision.MODEL_DOMAIN,
    decision.AUTHORITY_MODE,

    decision.POLICY_ID,
    decision.POLICY_VERSION,

    decision.SIMULATION_ID,
    decision.KMAT_ID,
    decision.RFQ_ID,

    decision.RULE_VALUE,
    decision.CANDIDATE_VALUE,
    decision.FINAL_RUNTIME_VALUE,

    decision.RUNTIME_AUTHORISED_FLAG,
    decision.FINAL_RUNTIME_SOURCE,

    decision.QUALITY_PASS_FLAG,
    decision.OOD_FLAG,
    decision.OVERALL_GUARDRAIL_PASS_FLAG,

    IFF(
        decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        TRUE,
        FALSE
    ) AS CANDIDATE_EVALUATION_ELIGIBLE_FLAG,

    feedback.OUTCOME_AVAILABLE_FLAG,

    IFF(
        decision.MODEL_DOMAIN = 'BMCS',
        IFF(
            feedback.ACTUAL_MAPPING_CORRECT_FLAG,
            1.0,
            0.0
        )::FLOAT,
        feedback.ACTUAL_NUMERIC_VALUE::FLOAT
    ) AS ACTUAL_VALUE,

    IFF(
        decision.MODEL_DOMAIN <> 'BMCS'
        AND feedback.OUTCOME_AVAILABLE_FLAG = TRUE
        AND feedback.ACTUAL_NUMERIC_VALUE
            IS NOT NULL
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        ABS(
            decision.CANDIDATE_VALUE
            - feedback.ACTUAL_NUMERIC_VALUE
        ),
        NULL::FLOAT
    ) AS CANDIDATE_ABS_ERROR,

    IFF(
        decision.MODEL_DOMAIN = 'BMCS'
        AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        POWER(
            decision.CANDIDATE_VALUE
            - IFF(
                feedback.ACTUAL_MAPPING_CORRECT_FLAG,
                1.0,
                0.0
            ),
            2
        ),
        NULL::FLOAT
    ) AS BMCS_BRIER_SCORE,

    IFF(
        decision.MODEL_DOMAIN = 'BMCS'
        AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
            IS NOT NULL
        AND decision.CANDIDATE_VALUE IS NOT NULL
        AND decision.QUALITY_PASS_FLAG = TRUE
        AND decision.OOD_FLAG = FALSE
        AND decision.OVERALL_GUARDRAIL_PASS_FLAG = TRUE,
        IFF(
            (
                decision.CANDIDATE_VALUE >= 0.5
                AND feedback.ACTUAL_MAPPING_CORRECT_FLAG
            )
            OR
            (
                decision.CANDIDATE_VALUE < 0.5
                AND NOT feedback.ACTUAL_MAPPING_CORRECT_FLAG
            ),
            TRUE,
            FALSE
        ),
        NULL::BOOLEAN
    ) AS BMCS_CLASSIFICATION_CORRECT_FLAG,

    decision.DECIDED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_DECISION_V1
        decision

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_MODEL_FEEDBACK_DETAIL_V1
        feedback

    ON decision.SIMULATION_ID =
       feedback.SIMULATION_ID

   AND decision.MODEL_DOMAIN =
       feedback.MODEL_DOMAIN;




-- ============================================================
-- 10. POST-ACTIVATION SAFETY MONITOR
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_RUNTIME_SAFETY_MONITOR_V1(
            P_MONITOR_RUN_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_RUN_BY VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_DOMAIN VARCHAR;

    V_EXISTING_RUN_COUNT NUMBER DEFAULT 0;
    V_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_SAFETY_POLICY_COUNT NUMBER DEFAULT 0;

    V_RUNTIME_AUTHORITY_ID VARCHAR;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_AUTHORITY_MODE VARCHAR;
    V_PRIOR_AUTHORITY_STATUS VARCHAR;
    V_RESULTING_AUTHORITY_STATUS VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_EXPECTED_FINGERPRINT VARCHAR;
    V_CURRENT_FINGERPRINT VARCHAR;

    V_REQUEST_STATUS VARCHAR;
    V_CURRENT_REQUEST_EVIDENCE_VERSION NUMBER;

    V_PRODUCTION_READINESS_COUNT NUMBER DEFAULT 0;
    V_PRODUCTION_LINK_VALID BOOLEAN DEFAULT FALSE;
    V_PILOT_EXIT_REQUEST_STATUS VARCHAR;
    V_PRODUCTION_EXIT_GATE_PASS BOOLEAN DEFAULT FALSE;

    V_GLOBAL_SWITCH_STATUS VARCHAR;
    V_DOMAIN_SWITCH_STATUS VARCHAR;

    V_POLICY_FINGERPRINT_MATCH BOOLEAN DEFAULT FALSE;
    V_REQUEST_FRESH BOOLEAN DEFAULT FALSE;

    V_RUNTIME_SAFETY_POLICY_ID VARCHAR;

    V_MIN_DECISION_COUNT NUMBER;
    V_MAX_FALLBACK_RATE FLOAT;

    V_MAX_CANDIDATE_MAE FLOAT;
    V_MAX_BRIER FLOAT;
    V_MIN_BMCS_ACCURACY FLOAT;

    V_MAX_GUARDRAIL_COUNT NUMBER;
    V_MAX_UNAUTHORISED_COUNT NUMBER;
    V_MAX_COST_MUTATION_COUNT NUMBER;
    V_MAX_BMCS_COST_COUNT NUMBER;

    V_AUTO_SUSPEND BOOLEAN;

    V_DECISION_COUNT NUMBER DEFAULT 0;
    V_AUTHORISED_COUNT NUMBER DEFAULT 0;
    V_FALLBACK_COUNT NUMBER DEFAULT 0;
    V_FALLBACK_RATE FLOAT;

    V_OUTCOME_COUNT NUMBER DEFAULT 0;

    V_CANDIDATE_MAE FLOAT;
    V_BRIER FLOAT;
    V_BMCS_ACCURACY FLOAT;

    V_GUARDRAIL_COUNT NUMBER DEFAULT 0;
    V_UNAUTHORISED_COUNT NUMBER DEFAULT 0;
    V_COST_MUTATION_COUNT NUMBER DEFAULT 0;
    V_BMCS_COST_COUNT NUMBER DEFAULT 0;

    V_MONITORING_STATUS VARCHAR;
    V_MONITORING_REASON VARCHAR;

    V_AUTO_SUSPEND_TRIGGERED BOOLEAN DEFAULT FALSE;

    V_STARTED_AT TIMESTAMP_NTZ;
    V_COMPLETED_AT TIMESTAMP_NTZ;

    V_SWITCH_EVENT_ID VARCHAR;
    V_AUDIT_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    V_DOMAIN := UPPER(TRIM(P_MODEL_DOMAIN));

    IF (
        P_MONITOR_RUN_ID IS NULL
        OR LENGTH(TRIM(P_MONITOR_RUN_ID)) = 0
        OR P_MODEL_DOMAIN IS NULL
        OR V_DOMAIN NOT IN (
            ''CSS'',
            ''FMIS'',
            ''TDS'',
            ''BMCS''
        )
        OR P_RUN_BY IS NULL
        OR LENGTH(TRIM(P_RUN_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Monitor run, valid model domain and actor are required.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_EXISTING_RUN_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
    WHERE MONITOR_RUN_ID =
          :P_MONITOR_RUN_ID;

    IF (V_EXISTING_RUN_COUNT = 1) THEN
        RETURN (
            SELECT OBJECT_CONSTRUCT_KEEP_NULL(
                ''status'', ''SUCCESS'',
                ''idempotent_replay'', TRUE,
                ''phase'', ''PHASE_13A'',

                ''monitor_run_id'', MONITOR_RUN_ID,
                ''runtime_authority_id'',
                    RUNTIME_AUTHORITY_ID,

                ''model_domain'', MODEL_DOMAIN,
                ''authority_mode'', AUTHORITY_MODE,

                ''monitoring_status'',
                    MONITORING_STATUS,
                ''monitoring_reason'',
                    MONITORING_REASON,

                ''prior_authority_status'',
                    PRIOR_AUTHORITY_STATUS,
                ''resulting_authority_status'',
                    RESULTING_AUTHORITY_STATUS,

                ''auto_suspend_triggered'',
                    AUTO_SUSPEND_TRIGGERED_FLAG,

                ''completed_at'', COMPLETED_AT
            )
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
            WHERE MONITOR_RUN_ID =
                  :P_MONITOR_RUN_ID
        );
    END IF;

    IF (V_EXISTING_RUN_COUNT > 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''MONITOR_RUN_ID is not unique.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(RUNTIME_AUTHORITY_ID),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(AUTHORITY_MODE),
        MAX(AUTHORITY_STATUS),

        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(POLICY_FINGERPRINT),

        MAX(RUNTIME_SAFETY_POLICY_ID)

    INTO
        :V_AUTHORITY_COUNT,

        :V_RUNTIME_AUTHORITY_ID,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_AUTHORITY_MODE,
        :V_PRIOR_AUTHORITY_STATUS,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_EXPECTED_FINGERPRINT,

        :V_RUNTIME_SAFETY_POLICY_ID

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1

    WHERE MODEL_DOMAIN =
          :V_DOMAIN;

    IF (V_AUTHORITY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one active runtime authority is required before monitoring.'',
            ''authority_count'', V_AUTHORITY_COUNT
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(MIN_MONITORING_DECISION_COUNT),
        MAX(MAX_FALLBACK_RATE_PCT),

        MAX(MAX_CANDIDATE_MAE),
        MAX(MAX_BMCS_BRIER_SCORE),
        MAX(MIN_BMCS_ACCURACY_PCT),

        MAX(MAX_GUARDRAIL_VIOLATION_COUNT),
        MAX(MAX_UNAUTHORISED_USE_COUNT),
        MAX(MAX_OFFICIAL_COST_MUTATION_COUNT),
        MAX(MAX_BMCS_DIRECT_COST_IMPACT_COUNT),

        MAX(AUTO_SUSPEND_ON_ATTENTION_FLAG)

    INTO
        :V_SAFETY_POLICY_COUNT,

        :V_MIN_DECISION_COUNT,
        :V_MAX_FALLBACK_RATE,

        :V_MAX_CANDIDATE_MAE,
        :V_MAX_BRIER,
        :V_MIN_BMCS_ACCURACY,

        :V_MAX_GUARDRAIL_COUNT,
        :V_MAX_UNAUTHORISED_COUNT,
        :V_MAX_COST_MUTATION_COUNT,
        :V_MAX_BMCS_COST_COUNT,

        :V_AUTO_SUSPEND

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1

    WHERE RUNTIME_SAFETY_POLICY_ID =
          :V_RUNTIME_SAFETY_POLICY_ID
      AND MODEL_DOMAIN =
          :V_DOMAIN
      AND AUTHORITY_MODE =
          :V_AUTHORITY_MODE;

    IF (V_SAFETY_POLICY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one matching runtime safety policy is required.'',
            ''safety_policy_count'',
                V_SAFETY_POLICY_COUNT
        );
    END IF;

    SELECT
        MAX(POLICY_FINGERPRINT)
    INTO :V_CURRENT_FINGERPRINT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
    WHERE MODEL_DOMAIN =
          :V_DOMAIN
      AND POLICY_ID =
          :V_POLICY_ID
      AND POLICY_VERSION =
          :V_POLICY_VERSION
      AND DEPLOYMENT_MODE =
          :V_AUTHORITY_MODE;

    V_POLICY_FINGERPRINT_MATCH :=
        V_CURRENT_FINGERPRINT IS NOT NULL
        AND V_CURRENT_FINGERPRINT =
            V_EXPECTED_FINGERPRINT;

    SELECT
        MAX(REQUEST_STATUS),
        MAX(EVIDENCE_VERSION)
    INTO
        :V_REQUEST_STATUS,
        :V_CURRENT_REQUEST_EVIDENCE_VERSION
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DEPLOYMENT_REQUEST_V1
    WHERE DEPLOYMENT_REQUEST_ID =
          :V_DEPLOYMENT_REQUEST_ID
      AND MODEL_DOMAIN =
          :V_DOMAIN
      AND TARGET_MODE =
          :V_AUTHORITY_MODE
      AND CANDIDATE_POLICY_ID =
          :V_POLICY_ID
      AND CANDIDATE_POLICY_VERSION =
          :V_POLICY_VERSION;

    V_REQUEST_FRESH :=
        V_REQUEST_STATUS = ''ACTIVATED''
        AND V_CURRENT_REQUEST_EVIDENCE_VERSION
            = V_REQUEST_EVIDENCE_VERSION;

    IF (V_AUTHORITY_MODE = ''PRODUCTION'') THEN
        SELECT
            COUNT(*),

            MAX(PILOT_EXIT_LINK_VALID_FLAG),
            MAX(PILOT_EXIT_REQUEST_STATUS)

        INTO
            :V_PRODUCTION_READINESS_COUNT,

            :V_PRODUCTION_LINK_VALID,
            :V_PILOT_EXIT_REQUEST_STATUS

        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .VW_ML_PRODUCTION_ACTIVATION_READINESS_V1

        WHERE DEPLOYMENT_REQUEST_ID =
              :V_DEPLOYMENT_REQUEST_ID
          AND EVIDENCE_VERSION =
              :V_REQUEST_EVIDENCE_VERSION;

        V_PRODUCTION_EXIT_GATE_PASS :=
            V_PRODUCTION_READINESS_COUNT = 1
            AND COALESCE(
                V_PRODUCTION_LINK_VALID,
                FALSE
            )
            AND V_PILOT_EXIT_REQUEST_STATUS =
                ''CLOSED_PASS'';
    ELSE
        V_PRODUCTION_EXIT_GATE_PASS :=
            V_AUTHORITY_MODE = ''CONTROLLED'';
    END IF;

    SELECT MAX(SWITCH_STATUS)
    INTO :V_GLOBAL_SWITCH_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE = ''GLOBAL'';

    SELECT MAX(SWITCH_STATUS)
    INTO :V_DOMAIN_SWITCH_STATUS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE =
          :V_DOMAIN;

    V_STARTED_AT := CURRENT_TIMESTAMP();

    SELECT
        COUNT(*)::NUMBER,

        COALESCE(
            COUNT_IF(
                RUNTIME_AUTHORISED_FLAG = TRUE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_RUNTIME_SOURCE =
                    ''DETERMINISTIC_FALLBACK''
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_RUNTIME_SOURCE IN (
                    ''CANDIDATE_CONTROLLED'',
                    ''CANDIDATE_PRODUCTION''
                )
                AND OVERALL_GUARDRAIL_PASS_FLAG =
                    FALSE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                FINAL_RUNTIME_SOURCE IN (
                    ''CANDIDATE_CONTROLLED'',
                    ''CANDIDATE_PRODUCTION''
                )
                AND RUNTIME_AUTHORISED_FLAG =
                    FALSE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                OFFICIAL_COST_MUTATION_EXECUTED_FLAG =
                    TRUE
            ),
            0
        )::NUMBER,

        COALESCE(
            COUNT_IF(
                BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG =
                    TRUE
            ),
            0
        )::NUMBER

    INTO
        :V_DECISION_COUNT,
        :V_AUTHORISED_COUNT,
        :V_FALLBACK_COUNT,

        :V_GUARDRAIL_COUNT,
        :V_UNAUTHORISED_COUNT,
        :V_COST_MUTATION_COUNT,
        :V_BMCS_COST_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_DECISION_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :V_RUNTIME_AUTHORITY_ID;

    V_FALLBACK_RATE :=
        IFF(
            V_DECISION_COUNT = 0,
            NULL::FLOAT,
            (
                V_FALLBACK_COUNT
                /
                V_DECISION_COUNT
            ) * 100.0
        );

    SELECT
        COALESCE(
            COUNT_IF(
                OUTCOME_AVAILABLE_FLAG = TRUE
                AND CANDIDATE_EVALUATION_ELIGIBLE_FLAG =
                    TRUE
            ),
            0
        )::NUMBER,

        AVG(CANDIDATE_ABS_ERROR)::FLOAT,

        AVG(BMCS_BRIER_SCORE)::FLOAT,

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
                        BMCS_CLASSIFICATION_CORRECT_FLAG =
                            TRUE
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
        )::FLOAT

    INTO
        :V_OUTCOME_COUNT,
        :V_CANDIDATE_MAE,
        :V_BRIER,
        :V_BMCS_ACCURACY

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_OUTCOME_DETAIL_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :V_RUNTIME_AUTHORITY_ID;

    IF (
        NOT V_POLICY_FINGERPRINT_MATCH
        OR NOT V_REQUEST_FRESH
        OR NOT V_PRODUCTION_EXIT_GATE_PASS
        OR V_GLOBAL_SWITCH_STATUS <> ''OPEN''
        OR V_DOMAIN_SWITCH_STATUS <> ''OPEN''
        OR V_GUARDRAIL_COUNT >
            V_MAX_GUARDRAIL_COUNT
        OR V_UNAUTHORISED_COUNT >
            V_MAX_UNAUTHORISED_COUNT
        OR V_COST_MUTATION_COUNT >
            V_MAX_COST_MUTATION_COUNT
        OR V_BMCS_COST_COUNT >
            V_MAX_BMCS_COST_COUNT
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';

        V_MONITORING_REASON :=
            ''Runtime identity, evidence, kill-switch or zero-tolerance control failed.'';

    ELSEIF (
        V_DECISION_COUNT <
            V_MIN_DECISION_COUNT
        OR V_OUTCOME_COUNT <
            V_MIN_DECISION_COUNT
    ) THEN
        V_MONITORING_STATUS :=
            ''INSUFFICIENT_DATA'';

        V_MONITORING_REASON :=
            ''Runtime decisions or verified outcomes are below the monitoring minimum.'';

    ELSEIF (
        V_FALLBACK_RATE IS NULL
        OR V_FALLBACK_RATE >
            V_MAX_FALLBACK_RATE
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';

        V_MONITORING_REASON :=
            ''Runtime fallback rate exceeded the configured threshold.'';

    ELSEIF (
        V_DOMAIN = ''BMCS''
        AND (
            V_BRIER IS NULL
            OR V_BRIER > V_MAX_BRIER
            OR V_BMCS_ACCURACY IS NULL
            OR V_BMCS_ACCURACY <
                V_MIN_BMCS_ACCURACY
        )
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';

        V_MONITORING_REASON :=
            ''BMCS runtime Brier score or diagnostic accuracy failed.'';

    ELSEIF (
        V_DOMAIN <> ''BMCS''
        AND (
            V_CANDIDATE_MAE IS NULL
            OR V_CANDIDATE_MAE >
                V_MAX_CANDIDATE_MAE
        )
    ) THEN
        V_MONITORING_STATUS :=
            ''ATTENTION_REQUIRED'';

        V_MONITORING_REASON :=
            ''Runtime candidate MAE exceeded the configured threshold.'';

    ELSE
        V_MONITORING_STATUS :=
            ''HEALTHY'';

        V_MONITORING_REASON :=
            ''Runtime identity, safety, fallback and performance checks passed.'';
    END IF;

    V_RESULTING_AUTHORITY_STATUS :=
        V_PRIOR_AUTHORITY_STATUS;

    IF (
        V_MONITORING_STATUS =
            ''ATTENTION_REQUIRED''
        AND COALESCE(
            V_AUTO_SUSPEND,
            FALSE
        )
        AND V_PRIOR_AUTHORITY_STATUS =
            ''ENABLED''
    ) THEN
        V_RESULTING_AUTHORITY_STATUS :=
            ''SUSPENDED'';

        V_AUTO_SUSPEND_TRIGGERED :=
            TRUE;
    END IF;

    V_COMPLETED_AT := CURRENT_TIMESTAMP();
    V_SWITCH_EVENT_ID := UUID_STRING();
    V_AUDIT_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    IF (V_AUTO_SUSPEND_TRIGGERED) THEN
        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_REGISTRY_V1
        SET
            AUTHORITY_STATUS =
                ''SUSPENDED'',

            AUTHORITY_STATUS_REASON =
                ''Automatically suspended by monitor ''
                || TRIM(:P_MONITOR_RUN_ID),

            SUSPENDED_BY =
                TRIM(:P_RUN_BY),
            SUSPENDED_AT =
                CURRENT_TIMESTAMP(),

            UPDATED_AT =
                CURRENT_TIMESTAMP()

        WHERE RUNTIME_AUTHORITY_ID =
              :V_RUNTIME_AUTHORITY_ID
          AND IS_ACTIVE = TRUE
          AND AUTHORITY_STATUS =
              ''ENABLED'';

        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_KILL_SWITCH_V1 (
                    SWITCH_EVENT_ID,

                    SWITCH_SCOPE,
                    SWITCH_STATUS,

                    SWITCH_REASON,

                    CHANGED_BY,
                    CHANGED_AT
                )
        SELECT
            :V_SWITCH_EVENT_ID,

            :V_DOMAIN,
            ''BLOCKED'',

            ''Automatic runtime suspension by monitor ''
            || TRIM(:P_MONITOR_RUN_ID),

            TRIM(:P_RUN_BY),
            CURRENT_TIMESTAMP();
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_SAFETY_MONITOR_RUN_V1 (
                MONITOR_RUN_ID,

                RUNTIME_AUTHORITY_ID,
                MODEL_DOMAIN,
                AUTHORITY_MODE,

                PRIOR_AUTHORITY_STATUS,
                RESULTING_AUTHORITY_STATUS,

                MONITORING_STATUS,
                MONITORING_REASON,

                DECISION_COUNT,
                AUTHORISED_DECISION_COUNT,
                FALLBACK_DECISION_COUNT,
                FALLBACK_RATE_PCT,

                ACTUAL_OUTCOME_COUNT,

                CANDIDATE_MAE,
                BMCS_BRIER_SCORE,
                BMCS_ACCURACY_PCT,

                GUARDRAIL_VIOLATION_COUNT,
                UNAUTHORISED_USE_COUNT,
                OFFICIAL_COST_MUTATION_COUNT,
                BMCS_DIRECT_COST_IMPACT_COUNT,

                GLOBAL_SWITCH_STATUS,
                DOMAIN_SWITCH_STATUS,

                AUTO_SUSPEND_TRIGGERED_FLAG,

                RUN_BY,
                STARTED_AT,
                COMPLETED_AT,

                CREATED_AT
            )
    SELECT
        TRIM(:P_MONITOR_RUN_ID),

        :V_RUNTIME_AUTHORITY_ID,
        :V_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_PRIOR_AUTHORITY_STATUS,
        :V_RESULTING_AUTHORITY_STATUS,

        :V_MONITORING_STATUS,
        :V_MONITORING_REASON,

        :V_DECISION_COUNT,
        :V_AUTHORISED_COUNT,
        :V_FALLBACK_COUNT,
        :V_FALLBACK_RATE,

        :V_OUTCOME_COUNT,

        :V_CANDIDATE_MAE,
        :V_BRIER,
        :V_BMCS_ACCURACY,

        :V_GUARDRAIL_COUNT,
        :V_UNAUTHORISED_COUNT,
        :V_COST_MUTATION_COUNT,
        :V_BMCS_COST_COUNT,

        :V_GLOBAL_SWITCH_STATUS,
        :V_DOMAIN_SWITCH_STATUS,

        :V_AUTO_SUSPEND_TRIGGERED,

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
            ''Runtime monitor insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_SAFETY_MONITOR_COMPLETED'',

        :V_RUNTIME_AUTHORITY_ID,
        NULL::VARCHAR,
        TRIM(:P_MONITOR_RUN_ID),

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_MONITORING_STATUS,
        :V_MONITORING_REASON,

        TRIM(:P_RUN_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_13A'',

        ''monitor_run_id'', P_MONITOR_RUN_ID,
        ''runtime_authority_id'',
            V_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_DOMAIN,
        ''authority_mode'', V_AUTHORITY_MODE,

        ''monitoring_status'',
            V_MONITORING_STATUS,
        ''monitoring_reason'',
            V_MONITORING_REASON,

        ''prior_authority_status'',
            V_PRIOR_AUTHORITY_STATUS,
        ''resulting_authority_status'',
            V_RESULTING_AUTHORITY_STATUS,

        ''decision_count'', V_DECISION_COUNT,
        ''authorised_decision_count'',
            V_AUTHORISED_COUNT,
        ''fallback_rate_pct'',
            V_FALLBACK_RATE,

        ''actual_outcome_count'',
            V_OUTCOME_COUNT,

        ''candidate_mae'',
            V_CANDIDATE_MAE,
        ''bmcs_brier_score'', V_BRIER,
        ''bmcs_accuracy_pct'',
            V_BMCS_ACCURACY,

        ''policy_fingerprint_match'',
            V_POLICY_FINGERPRINT_MATCH,
        ''request_evidence_fresh'',
            V_REQUEST_FRESH,
        ''production_exit_gate_pass'',
            V_PRODUCTION_EXIT_GATE_PASS,

        ''auto_suspend_triggered'',
            V_AUTO_SUSPEND_TRIGGERED,

        ''official_cost_changed'', FALSE,
        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

-- ============================================================
-- 11. MANUAL SUSPENSION
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SUSPEND_ML_RUNTIME_AUTHORITY_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_SUSPEND_REASON VARCHAR,
            P_SUSPENDED_BY VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_AUTHORITY_COUNT NUMBER DEFAULT 0;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_MODEL_DOMAIN VARCHAR;
    V_AUTHORITY_MODE VARCHAR;
    V_AUTHORITY_STATUS VARCHAR;

    V_SWITCH_EVENT_ID VARCHAR;
    V_AUDIT_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_RUNTIME_AUTHORITY_ID IS NULL
        OR LENGTH(TRIM(P_RUNTIME_AUTHORITY_ID)) = 0
        OR P_SUSPEND_REASON IS NULL
        OR LENGTH(TRIM(P_SUSPEND_REASON)) = 0
        OR P_SUSPENDED_BY IS NULL
        OR LENGTH(TRIM(P_SUSPENDED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime authority, suspension reason and actor are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> ''SUSPEND_RUNTIME::''
               || P_RUNTIME_AUTHORITY_ID
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Confirmation must equal SUSPEND_RUNTIME::<RUNTIME_AUTHORITY_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(MODEL_DOMAIN),
        MAX(AUTHORITY_MODE),
        MAX(AUTHORITY_STATUS)

    INTO
        :V_AUTHORITY_COUNT,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,
        :V_AUTHORITY_STATUS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE;

    IF (V_AUTHORITY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one active runtime authority is required.''
        );
    END IF;

    IF (V_AUTHORITY_STATUS = ''SUSPENDED'') THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''SUCCESS'',
            ''idempotent_replay'', TRUE,
            ''phase'', ''PHASE_13A'',

            ''runtime_authority_id'',
                P_RUNTIME_AUTHORITY_ID,
            ''model_domain'', V_MODEL_DOMAIN,
            ''authority_status'', ''SUSPENDED'',
            ''domain_runtime_switch'',
                ''BLOCKED''
        );
    END IF;

    IF (
        V_AUTHORITY_STATUS NOT IN (
            ''PENDING_ENABLE'',
            ''ENABLED''
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''message'',
            ''Only PENDING_ENABLE or ENABLED authority can be suspended.'',
            ''authority_status'', V_AUTHORITY_STATUS
        );
    END IF;

    V_SWITCH_EVENT_ID := UUID_STRING();
    V_AUDIT_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    SET
        AUTHORITY_STATUS =
            ''SUSPENDED'',
        AUTHORITY_STATUS_REASON =
            TRIM(:P_SUSPEND_REASON),

        SUSPENDED_BY =
            TRIM(:P_SUSPENDED_BY),
        SUSPENDED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE
      AND AUTHORITY_STATUS =
          :V_AUTHORITY_STATUS;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime suspension did not update exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_KILL_SWITCH_V1 (
                SWITCH_EVENT_ID,

                SWITCH_SCOPE,
                SWITCH_STATUS,

                SWITCH_REASON,

                CHANGED_BY,
                CHANGED_AT
            )
    SELECT
        :V_SWITCH_EVENT_ID,

        :V_MODEL_DOMAIN,
        ''BLOCKED'',

        TRIM(:P_SUSPEND_REASON),

        TRIM(:P_SUSPENDED_BY),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_AUTHORITY_SUSPENDED'',

        TRIM(:P_RUNTIME_AUTHORITY_ID),
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        ''SUSPENDED'',
        TRIM(:P_SUSPEND_REASON),

        TRIM(:P_SUSPENDED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''idempotent_replay'', FALSE,
        ''phase'', ''PHASE_13A'',

        ''runtime_authority_id'',
            P_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''authority_mode'', V_AUTHORITY_MODE,

        ''prior_authority_status'',
            V_AUTHORITY_STATUS,
        ''authority_status'', ''SUSPENDED'',

        ''domain_runtime_switch'',
            ''BLOCKED'',

        ''switch_event_id'',
            V_SWITCH_EVENT_ID,
        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


-- ============================================================
-- 12. PERMANENT RUNTIME REVOCATION
-- ============================================================

CREATE OR REPLACE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .REVOKE_ML_RUNTIME_AUTHORITY_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_REVOKE_REASON VARCHAR,
            P_REVOKED_BY VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_AUTHORITY_COUNT NUMBER DEFAULT 0;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_MODEL_DOMAIN VARCHAR;
    V_AUTHORITY_MODE VARCHAR;
    V_AUTHORITY_STATUS VARCHAR;

    V_SWITCH_EVENT_ID VARCHAR;
    V_AUDIT_EVENT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_UPDATED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_RUNTIME_AUTHORITY_ID IS NULL
        OR LENGTH(TRIM(P_RUNTIME_AUTHORITY_ID)) = 0
        OR P_REVOKE_REASON IS NULL
        OR LENGTH(TRIM(P_REVOKE_REASON)) = 0
        OR P_REVOKED_BY IS NULL
        OR LENGTH(TRIM(P_REVOKED_BY)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime authority, revocation reason and actor are required.''
        );
    END IF;

    IF (
        P_CONFIRMATION_PHRASE IS NULL
        OR P_CONFIRMATION_PHRASE
            <> ''REVOKE_RUNTIME::''
               || P_RUNTIME_AUTHORITY_ID
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Confirmation must equal REVOKE_RUNTIME::<RUNTIME_AUTHORITY_ID>.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(MODEL_DOMAIN),
        MAX(AUTHORITY_MODE),
        MAX(AUTHORITY_STATUS)

    INTO
        :V_AUTHORITY_COUNT,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,
        :V_AUTHORITY_STATUS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE;

    IF (V_AUTHORITY_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one active runtime authority is required.''
        );
    END IF;

    V_SWITCH_EVENT_ID := UUID_STRING();
    V_AUDIT_EVENT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
    SET
        AUTHORITY_STATUS =
            ''REVOKED'',
        AUTHORITY_STATUS_REASON =
            TRIM(:P_REVOKE_REASON),

        IS_ACTIVE = FALSE,

        REVOKED_BY =
            TRIM(:P_REVOKED_BY),
        REVOKED_AT =
            CURRENT_TIMESTAMP(),

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE RUNTIME_AUTHORITY_ID =
          :P_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE;

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Runtime revocation did not update exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_KILL_SWITCH_V1 (
                SWITCH_EVENT_ID,

                SWITCH_SCOPE,
                SWITCH_STATUS,

                SWITCH_REASON,

                CHANGED_BY,
                CHANGED_AT
            )
    SELECT
        :V_SWITCH_EVENT_ID,

        :V_MODEL_DOMAIN,
        ''BLOCKED'',

        TRIM(:P_REVOKE_REASON),

        TRIM(:P_REVOKED_BY),
        CURRENT_TIMESTAMP();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 (
                EVENT_ID,
                EVENT_TYPE,

                RUNTIME_AUTHORITY_ID,
                RUNTIME_DECISION_ID,
                MONITOR_RUN_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,

                MODEL_DOMAIN,
                AUTHORITY_MODE,

                EVENT_STATUS,
                EVENT_REASON,

                EVENT_ACTOR,
                EVENT_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''RUNTIME_AUTHORITY_REVOKED'',

        TRIM(:P_RUNTIME_AUTHORITY_ID),
        NULL::VARCHAR,
        NULL::VARCHAR,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        ''REVOKED'',
        TRIM(:P_REVOKE_REASON),

        TRIM(:P_REVOKED_BY),
        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13A'',

        ''runtime_authority_id'',
            P_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''authority_mode'', V_AUTHORITY_MODE,

        ''prior_authority_status'',
            V_AUTHORITY_STATUS,
        ''authority_status'', ''REVOKED'',
        ''is_active'', FALSE,

        ''domain_runtime_switch'',
            ''BLOCKED'',

        ''switch_event_id'',
            V_SWITCH_EVENT_ID,
        ''audit_event_id'',
            V_AUDIT_EVENT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13A'',
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';


-- ============================================================
-- 13. RUNTIME AUTHORITY DASHBOARD
-- ============================================================

CREATE OR REPLACE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1
AS
WITH DOMAINS AS (
    SELECT COLUMN1::VARCHAR AS MODEL_DOMAIN
    FROM VALUES
        ('CSS'),
        ('FMIS'),
        ('TDS'),
        ('BMCS')
),
GLOBAL_SWITCH AS (
    SELECT
        SWITCH_STATUS
            AS GLOBAL_SWITCH_STATUS,
        SWITCH_REASON
            AS GLOBAL_SWITCH_REASON,
        CHANGED_AT
            AS GLOBAL_SWITCH_CHANGED_AT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE = 'GLOBAL'
),
DOMAIN_SWITCH AS (
    SELECT
        SWITCH_SCOPE AS MODEL_DOMAIN,
        SWITCH_STATUS
            AS DOMAIN_SWITCH_STATUS,
        SWITCH_REASON
            AS DOMAIN_SWITCH_REASON,
        CHANGED_AT
            AS DOMAIN_SWITCH_CHANGED_AT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
    WHERE SWITCH_SCOPE IN (
        'CSS',
        'FMIS',
        'TDS',
        'BMCS'
    )
),
COUNTERS AS (
    SELECT
        RUNTIME_AUTHORITY_ID,

        MAX(
            IFF(
                COUNTER_TYPE = 'TOTAL',
                AUTHORISED_COUNT,
                NULL::NUMBER
            )
        ) AS TOTAL_AUTHORISED_COUNT,

        MAX(
            IFF(
                COUNTER_TYPE = 'DAILY'
                AND COUNTER_DATE = CURRENT_DATE(),
                AUTHORISED_COUNT,
                NULL::NUMBER
            )
        ) AS TODAY_AUTHORISED_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_COUNTER_V1

    GROUP BY RUNTIME_AUTHORITY_ID
)
SELECT
    domains.MODEL_DOMAIN,

    policy.POLICY_ID
        AS ACTIVE_POLICY_ID,
    policy.POLICY_VERSION
        AS ACTIVE_POLICY_VERSION,
    policy.DEPLOYMENT_MODE
        AS ACTIVE_DEPLOYMENT_MODE,
    policy.POLICY_FINGERPRINT
        AS CURRENT_POLICY_FINGERPRINT,

    authority.RUNTIME_AUTHORITY_ID,

    authority.DEPLOYMENT_REQUEST_ID,
    authority.REQUEST_EVIDENCE_VERSION,

    authority.AUTHORITY_MODE,
    authority.AUTHORITY_STATUS,
    authority.AUTHORITY_STATUS_REASON,

    authority.POLICY_ID
        AS REGISTERED_POLICY_ID,
    authority.POLICY_VERSION
        AS REGISTERED_POLICY_VERSION,
    authority.POLICY_FINGERPRINT
        AS REGISTERED_POLICY_FINGERPRINT,

    IFF(
        authority.RUNTIME_AUTHORITY_ID IS NOT NULL
        AND authority.POLICY_FINGERPRINT =
            policy.POLICY_FINGERPRINT,
        TRUE,
        FALSE
    ) AS POLICY_FINGERPRINT_MATCH_FLAG,

    authority.ALLOW_CANDIDATE_RUNTIME_FLAG,
    authority.ALLOW_OFFICIAL_COST_IMPACT_FLAG,
    authority.ALLOW_BUSINESS_DECISION_FLAG,

    authority.REQUIRE_ENGINEER_APPROVAL_FLAG,

    authority.MAX_DAILY_AUTHORISED_DECISIONS,
    authority.MAX_TOTAL_AUTHORISED_DECISIONS,

    COALESCE(
        counters.TODAY_AUTHORISED_COUNT,
        0
    )::NUMBER AS TODAY_AUTHORISED_COUNT,

    COALESCE(
        counters.TOTAL_AUTHORISED_COUNT,
        0
    )::NUMBER AS TOTAL_AUTHORISED_COUNT,

    global_switch.GLOBAL_SWITCH_STATUS,
    global_switch.GLOBAL_SWITCH_REASON,
    global_switch.GLOBAL_SWITCH_CHANGED_AT,

    domain_switch.DOMAIN_SWITCH_STATUS,
    domain_switch.DOMAIN_SWITCH_REASON,
    domain_switch.DOMAIN_SWITCH_CHANGED_AT,

    monitor.MONITOR_RUN_ID
        AS LATEST_MONITOR_RUN_ID,
    monitor.MONITORING_STATUS
        AS LATEST_MONITORING_STATUS,
    monitor.MONITORING_REASON
        AS LATEST_MONITORING_REASON,

    monitor.FALLBACK_RATE_PCT,
    monitor.ACTUAL_OUTCOME_COUNT,
    monitor.CANDIDATE_MAE,
    monitor.BMCS_BRIER_SCORE,
    monitor.BMCS_ACCURACY_PCT,

    monitor.AUTO_SUSPEND_TRIGGERED_FLAG,
    monitor.COMPLETED_AT
        AS LAST_MONITORED_AT,

    IFF(
        authority.AUTHORITY_STATUS = 'ENABLED'
        AND global_switch.GLOBAL_SWITCH_STATUS =
            'OPEN'
        AND domain_switch.DOMAIN_SWITCH_STATUS =
            'OPEN'
        AND authority.POLICY_FINGERPRINT =
            policy.POLICY_FINGERPRINT,
        TRUE,
        FALSE
    ) AS RUNTIME_CANDIDATE_PATH_OPEN_FLAG,

    FALSE AS OFFICIAL_COST_MUTATION_EXECUTED_FLAG

FROM DOMAINS domains

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
        policy
    ON domains.MODEL_DOMAIN =
       policy.MODEL_DOMAIN

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1
        authority
    ON domains.MODEL_DOMAIN =
       authority.MODEL_DOMAIN

CROSS JOIN GLOBAL_SWITCH global_switch

LEFT JOIN DOMAIN_SWITCH domain_switch
    ON domains.MODEL_DOMAIN =
       domain_switch.MODEL_DOMAIN

LEFT JOIN COUNTERS counters
    ON authority.RUNTIME_AUTHORITY_ID =
       counters.RUNTIME_AUTHORITY_ID

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_SAFETY_MONITOR_LATEST_V1
        monitor
    ON authority.RUNTIME_AUTHORITY_ID =
       monitor.RUNTIME_AUTHORITY_ID;


-- ============================================================
-- PHASE 13A — VERIFICATION
--
-- This verification creates no runtime authority, decision,
-- monitor record, activation, policy change or official cost.
-- ============================================================


-- ------------------------------------------------------------
-- 1. PROCEDURE INVENTORY
-- ------------------------------------------------------------

SHOW PROCEDURES LIKE
    'ACTIVATE_APPROVED_ML_DEPLOYMENT_V4'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'ENABLE_ML_RUNTIME_AUTHORITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'SET_ML_RUNTIME_KILL_SWITCH_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RESOLVE_ML_RUNTIME_AUTHORITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'RUN_ML_RUNTIME_SAFETY_MONITOR_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'SUSPEND_ML_RUNTIME_AUTHORITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SHOW PROCEDURES LIKE
    'REVOKE_ML_RUNTIME_AUTHORITY_V1'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;


-- Expected: 7.
SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE13A_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V4',
      'ENABLE_ML_RUNTIME_AUTHORITY_V1',
      'SET_ML_RUNTIME_KILL_SWITCH_V1',
      'RESOLVE_ML_RUNTIME_AUTHORITY_V1',
      'RUN_ML_RUNTIME_SAFETY_MONITOR_V1',
      'SUSPEND_ML_RUNTIME_AUTHORITY_V1',
      'REVOKE_ML_RUNTIME_AUTHORITY_V1'
  );


-- ------------------------------------------------------------
-- 2. RUNTIME SAFETY POLICY
--
-- Expected:
--   ACTIVE_RUNTIME_SAFETY_POLICY_COUNT = 8
--   INVALID_RUNTIME_SAFETY_POLICY_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ACTIVE_RUNTIME_SAFETY_POLICY_COUNT,

    COALESCE(
        COUNT_IF(
            MODEL_DOMAIN NOT IN (
                'CSS',
                'FMIS',
                'TDS',
                'BMCS'
            )
            OR AUTHORITY_MODE NOT IN (
                'CONTROLLED',
                'PRODUCTION'
            )
            OR MIN_MONITORING_DECISION_COUNT <= 0
            OR MAX_FALLBACK_RATE_PCT < 0
            OR MAX_FALLBACK_RATE_PCT > 100
            OR DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS <= 0
            OR DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS <= 0
            OR DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS
                > DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS
            OR (
                MODEL_DOMAIN IN (
                    'CSS',
                    'FMIS',
                    'TDS'
                )
                AND MAX_CANDIDATE_MAE IS NULL
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
    )::NUMBER AS INVALID_RUNTIME_SAFETY_POLICY_ROWS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1;


-- Expected: zero rows.
SELECT
    MODEL_DOMAIN,
    AUTHORITY_MODE,
    COUNT(*) AS DUPLICATE_POLICY_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1
GROUP BY
    MODEL_DOMAIN,
    AUTHORITY_MODE
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 3. ACTIVE POLICY FINGERPRINT
--
-- Expected:
--   CURRENT_POLICY_FINGERPRINT_COUNT = 4
--   NULL_POLICY_FINGERPRINT_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS CURRENT_POLICY_FINGERPRINT_COUNT,

    COALESCE(
        COUNT_IF(
            POLICY_FINGERPRINT IS NULL
            OR LENGTH(POLICY_FINGERPRINT) = 0
        ),
        0
    )::NUMBER AS NULL_POLICY_FINGERPRINT_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1;


-- Expected: zero rows.
SELECT
    MODEL_DOMAIN,
    COUNT(*) AS DUPLICATE_ACTIVE_POLICY_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
GROUP BY MODEL_DOMAIN
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 4. INITIAL KILL-SWITCH STATE
--
-- Expected:
--   CURRENT_SWITCH_SCOPE_COUNT = 5
--   GLOBAL_OPEN_SWITCH_COUNT = 1
--   DOMAIN_BLOCKED_SWITCH_COUNT = 4
--   INVALID_SWITCH_ROWS = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS CURRENT_SWITCH_SCOPE_COUNT,

    COALESCE(
        COUNT_IF(
            SWITCH_SCOPE = 'GLOBAL'
            AND SWITCH_STATUS = 'OPEN'
        ),
        0
    )::NUMBER AS GLOBAL_OPEN_SWITCH_COUNT,

    COALESCE(
        COUNT_IF(
            SWITCH_SCOPE IN (
                'CSS',
                'FMIS',
                'TDS',
                'BMCS'
            )
            AND SWITCH_STATUS = 'BLOCKED'
        ),
        0
    )::NUMBER AS DOMAIN_BLOCKED_SWITCH_COUNT,

    COALESCE(
        COUNT_IF(
            SWITCH_SCOPE NOT IN (
                'GLOBAL',
                'CSS',
                'FMIS',
                'TDS',
                'BMCS'
            )
            OR SWITCH_STATUS NOT IN (
                'OPEN',
                'BLOCKED'
            )
        ),
        0
    )::NUMBER AS INVALID_SWITCH_ROWS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1;


-- Expected: zero rows.
SELECT
    SWITCH_SCOPE,
    COUNT(*) AS DUPLICATE_SWITCH_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
GROUP BY SWITCH_SCOPE
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 5. EMPTY RUNTIME AUTHORITY STATE
--
-- Expected all values = 0.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS RUNTIME_AUTHORITY_ROW_COUNT,

    COALESCE(
        COUNT_IF(
            IS_ACTIVE = TRUE
        ),
        0
    )::NUMBER AS ACTIVE_RUNTIME_AUTHORITY_COUNT,

    COALESCE(
        COUNT_IF(
            IS_ACTIVE = TRUE
            AND AUTHORITY_STATUS = 'ENABLED'
        ),
        0
    )::NUMBER AS ENABLED_RUNTIME_AUTHORITY_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_REGISTRY_V1;


SELECT
    COUNT(*) AS RUNTIME_DECISION_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_DECISION_V1;


SELECT
    COUNT(*) AS RUNTIME_MONITOR_RUN_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_SAFETY_MONITOR_RUN_V1;


-- Expected: zero rows.
SELECT
    MODEL_DOMAIN,
    COUNT(*) AS DUPLICATE_CURRENT_AUTHORITY_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1
GROUP BY MODEL_DOMAIN
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 6. DECISION SAFETY AND ORPHAN INTEGRITY
--
-- Expected:
--   INVALID_RUNTIME_AUTHORISED_ROWS = 0
--   ORPHAN_RUNTIME_ROW_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COALESCE(
        COUNT_IF(
            RUNTIME_AUTHORISED_FLAG = TRUE
            AND (
                AUTHORITY_ENABLED_FLAG = FALSE
                OR GLOBAL_SWITCH_OPEN_FLAG = FALSE
                OR DOMAIN_SWITCH_OPEN_FLAG = FALSE
                OR REQUEST_FRESH_FLAG = FALSE
                OR POLICY_MATCH_FLAG = FALSE
                OR POLICY_FINGERPRINT_MATCH_FLAG = FALSE
                OR PRODUCTION_EXIT_GATE_PASS_FLAG = FALSE
                OR SAFETY_GATE_PASS_FLAG = FALSE
                OR COST_CONSUMPTION_ALLOWED_FLAG = FALSE
                OR RECALCULATION_NOT_REQUIRED_FLAG = FALSE
                OR OVERALL_GUARDRAIL_PASS_FLAG = FALSE
                OR CAPACITY_RESERVED_FLAG = FALSE
                OR FINAL_RUNTIME_SOURCE NOT IN (
                    'CANDIDATE_CONTROLLED',
                    'CANDIDATE_PRODUCTION'
                )
                OR BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG = TRUE
                OR OFFICIAL_COST_MUTATION_EXECUTED_FLAG = TRUE
            )
        ),
        0
    )::NUMBER AS INVALID_RUNTIME_AUTHORISED_ROWS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_RUNTIME_AUTHORITY_DECISION_V1;


SELECT
    (
        SELECT COUNT(*)
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_DECISION_V1
                decision
        LEFT JOIN
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_REGISTRY_V1
                authority
            ON decision.RUNTIME_AUTHORITY_ID =
               authority.RUNTIME_AUTHORITY_ID
        WHERE decision.RUNTIME_AUTHORITY_ID IS NOT NULL
          AND authority.RUNTIME_AUTHORITY_ID IS NULL
    )
    +
    (
        SELECT COUNT(*)
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
                monitor
        LEFT JOIN
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_RUNTIME_AUTHORITY_REGISTRY_V1
                authority
            ON monitor.RUNTIME_AUTHORITY_ID =
               authority.RUNTIME_AUTHORITY_ID
        WHERE authority.RUNTIME_AUTHORITY_ID IS NULL
    )
    AS ORPHAN_RUNTIME_ROW_COUNT;


-- ------------------------------------------------------------
-- 7. NEGATIVE NON-WRITING TEST
--
-- Expected: controlled status ERROR because no authority exists.
-- ------------------------------------------------------------

CALL
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_RUNTIME_SAFETY_MONITOR_V1(
            'PHASE13A_NEGATIVE_MONITOR',
            'CSS',
            'PHASE13A_VERIFICATION'
        );


-- ------------------------------------------------------------
-- 8. DASHBOARD
--
-- Expected:
--   DASHBOARD_DOMAIN_COUNT = 4
--   OPEN_RUNTIME_PATH_COUNT = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS DASHBOARD_DOMAIN_COUNT,

    COALESCE(
        COUNT_IF(
            RUNTIME_CANDIDATE_PATH_OPEN_FLAG = TRUE
        ),
        0
    )::NUMBER AS OPEN_RUNTIME_PATH_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1;


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1
ORDER BY MODEL_DOMAIN;


-- ------------------------------------------------------------
-- 9. ACTIVE POLICY SAFETY
--
-- Expected:
--   ACTIVE_POLICY_COUNT = 4
--   SHADOW_POLICY_COUNT = 4
--   AUTHORITY_ENABLED_COUNT = 0
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- 10. FINAL CLOSURE
-- ------------------------------------------------------------

WITH PROCEDURES AS (
    SELECT
        COUNT(DISTINCT PROCEDURE_NAME)
            AS PROCEDURE_COUNT
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'ACTIVATE_APPROVED_ML_DEPLOYMENT_V4',
          'ENABLE_ML_RUNTIME_AUTHORITY_V1',
          'SET_ML_RUNTIME_KILL_SWITCH_V1',
          'RESOLVE_ML_RUNTIME_AUTHORITY_V1',
          'RUN_ML_RUNTIME_SAFETY_MONITOR_V1',
          'SUSPEND_ML_RUNTIME_AUTHORITY_V1',
          'REVOKE_ML_RUNTIME_AUTHORITY_V1'
      )
),
SAFETY_POLICIES AS (
    SELECT
        COUNT(*) AS POLICY_COUNT,

        COALESCE(
            COUNT_IF(
                MODEL_DOMAIN NOT IN (
                    'CSS',
                    'FMIS',
                    'TDS',
                    'BMCS'
                )
                OR AUTHORITY_MODE NOT IN (
                    'CONTROLLED',
                    'PRODUCTION'
                )
                OR MIN_MONITORING_DECISION_COUNT <= 0
                OR MAX_FALLBACK_RATE_PCT < 0
                OR MAX_FALLBACK_RATE_PCT > 100
                OR DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS <= 0
                OR DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS <= 0
                OR DEFAULT_MAX_DAILY_AUTHORISED_DECISIONS
                    > DEFAULT_MAX_TOTAL_AUTHORISED_DECISIONS
            ),
            0
        )::NUMBER AS INVALID_POLICY_ROWS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_SAFETY_POLICY_CURRENT_V1
),
FINGERPRINTS AS (
    SELECT
        COUNT(*) AS FINGERPRINT_COUNT,

        COALESCE(
            COUNT_IF(
                POLICY_FINGERPRINT IS NULL
                OR LENGTH(POLICY_FINGERPRINT) = 0
            ),
            0
        )::NUMBER AS NULL_FINGERPRINT_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
),
SWITCHES AS (
    SELECT
        COUNT(*) AS SWITCH_SCOPE_COUNT,

        COALESCE(
            COUNT_IF(
                SWITCH_SCOPE = 'GLOBAL'
                AND SWITCH_STATUS = 'OPEN'
            ),
            0
        )::NUMBER AS GLOBAL_OPEN_COUNT,

        COALESCE(
            COUNT_IF(
                SWITCH_SCOPE IN (
                    'CSS',
                    'FMIS',
                    'TDS',
                    'BMCS'
                )
                AND SWITCH_STATUS = 'BLOCKED'
            ),
            0
        )::NUMBER AS DOMAIN_BLOCKED_COUNT,

        COALESCE(
            COUNT_IF(
                SWITCH_SCOPE NOT IN (
                    'GLOBAL',
                    'CSS',
                    'FMIS',
                    'TDS',
                    'BMCS'
                )
                OR SWITCH_STATUS NOT IN (
                    'OPEN',
                    'BLOCKED'
                )
            ),
            0
        )::NUMBER AS INVALID_SWITCH_ROWS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_KILL_SWITCH_CURRENT_V1
),
AUTHORITIES AS (
    SELECT
        COUNT(*) AS AUTHORITY_ROW_COUNT,

        COALESCE(
            COUNT_IF(
                IS_ACTIVE = TRUE
            ),
            0
        )::NUMBER AS ACTIVE_AUTHORITY_COUNT,

        COALESCE(
            COUNT_IF(
                IS_ACTIVE = TRUE
                AND AUTHORITY_STATUS = 'ENABLED'
            ),
            0
        )::NUMBER AS ENABLED_AUTHORITY_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1
),
DECISIONS AS (
    SELECT
        COUNT(*) AS DECISION_COUNT,

        COALESCE(
            COUNT_IF(
                RUNTIME_AUTHORISED_FLAG = TRUE
                AND (
                    AUTHORITY_ENABLED_FLAG = FALSE
                    OR GLOBAL_SWITCH_OPEN_FLAG = FALSE
                    OR DOMAIN_SWITCH_OPEN_FLAG = FALSE
                    OR REQUEST_FRESH_FLAG = FALSE
                    OR POLICY_MATCH_FLAG = FALSE
                    OR POLICY_FINGERPRINT_MATCH_FLAG = FALSE
                    OR PRODUCTION_EXIT_GATE_PASS_FLAG = FALSE
                    OR SAFETY_GATE_PASS_FLAG = FALSE
                    OR COST_CONSUMPTION_ALLOWED_FLAG = FALSE
                    OR RECALCULATION_NOT_REQUIRED_FLAG = FALSE
                    OR OVERALL_GUARDRAIL_PASS_FLAG = FALSE
                    OR CAPACITY_RESERVED_FLAG = FALSE
                    OR BMCS_DIRECT_COST_IMPACT_ALLOWED_FLAG = TRUE
                    OR OFFICIAL_COST_MUTATION_EXECUTED_FLAG = TRUE
                )
            ),
            0
        )::NUMBER AS INVALID_AUTHORISED_ROWS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_DECISION_V1
),
MONITORS AS (
    SELECT COUNT(*) AS MONITOR_RUN_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
),
ORPHANS AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_AUTHORITY_DECISION_V1
                    decision
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_AUTHORITY_REGISTRY_V1
                    authority
                ON decision.RUNTIME_AUTHORITY_ID =
                   authority.RUNTIME_AUTHORITY_ID
            WHERE decision.RUNTIME_AUTHORITY_ID IS NOT NULL
              AND authority.RUNTIME_AUTHORITY_ID IS NULL
        )
        +
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_SAFETY_MONITOR_RUN_V1
                    monitor
            LEFT JOIN
                KMAT_COST_MODEL_DB.CORE_ML
                    .ML_RUNTIME_AUTHORITY_REGISTRY_V1
                    authority
                ON monitor.RUNTIME_AUTHORITY_ID =
                   authority.RUNTIME_AUTHORITY_ID
            WHERE authority.RUNTIME_AUTHORITY_ID IS NULL
        )
        AS ORPHAN_ROW_COUNT
),
DASHBOARD AS (
    SELECT
        COUNT(*) AS DOMAIN_COUNT,

        COALESCE(
            COUNT_IF(
                RUNTIME_CANDIDATE_PATH_OPEN_FLAG = TRUE
            ),
            0
        )::NUMBER AS OPEN_RUNTIME_PATH_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1
),
ACTIVE_POLICIES AS (
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
            procedures.PROCEDURE_COUNT = 7
            AND safety_policies.POLICY_COUNT = 8
            AND safety_policies.INVALID_POLICY_ROWS = 0
            AND fingerprints.FINGERPRINT_COUNT = 4
            AND fingerprints.NULL_FINGERPRINT_COUNT = 0
            AND switches.SWITCH_SCOPE_COUNT = 5
            AND switches.GLOBAL_OPEN_COUNT = 1
            AND switches.DOMAIN_BLOCKED_COUNT = 4
            AND switches.INVALID_SWITCH_ROWS = 0
            AND authorities.AUTHORITY_ROW_COUNT = 0
            AND authorities.ACTIVE_AUTHORITY_COUNT = 0
            AND authorities.ENABLED_AUTHORITY_COUNT = 0
            AND decisions.DECISION_COUNT = 0
            AND decisions.INVALID_AUTHORISED_ROWS = 0
            AND monitors.MONITOR_RUN_COUNT = 0
            AND orphans.ORPHAN_ROW_COUNT = 0
            AND dashboard.DOMAIN_COUNT = 4
            AND dashboard.OPEN_RUNTIME_PATH_COUNT = 0
            AND active_policies.ACTIVE_POLICY_COUNT = 4
            AND active_policies.SHADOW_POLICY_COUNT = 4
            AND active_policies.AUTHORITY_ENABLED_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_13A',

    'procedure_count',
        procedures.PROCEDURE_COUNT,

    'active_runtime_safety_policy_count',
        safety_policies.POLICY_COUNT,

    'invalid_runtime_safety_policy_rows',
        safety_policies.INVALID_POLICY_ROWS,

    'current_policy_fingerprint_count',
        fingerprints.FINGERPRINT_COUNT,

    'null_policy_fingerprint_count',
        fingerprints.NULL_FINGERPRINT_COUNT,

    'current_switch_scope_count',
        switches.SWITCH_SCOPE_COUNT,

    'global_open_switch_count',
        switches.GLOBAL_OPEN_COUNT,

    'domain_blocked_switch_count',
        switches.DOMAIN_BLOCKED_COUNT,

    'invalid_switch_rows',
        switches.INVALID_SWITCH_ROWS,

    'runtime_authority_row_count',
        authorities.AUTHORITY_ROW_COUNT,

    'active_runtime_authority_count',
        authorities.ACTIVE_AUTHORITY_COUNT,

    'enabled_runtime_authority_count',
        authorities.ENABLED_AUTHORITY_COUNT,

    'runtime_decision_count',
        decisions.DECISION_COUNT,

    'invalid_runtime_authorised_rows',
        decisions.INVALID_AUTHORISED_ROWS,

    'runtime_monitor_run_count',
        monitors.MONITOR_RUN_COUNT,

    'orphan_runtime_row_count',
        orphans.ORPHAN_ROW_COUNT,

    'dashboard_domain_count',
        dashboard.DOMAIN_COUNT,

    'open_runtime_path_count',
        dashboard.OPEN_RUNTIME_PATH_COUNT,

    'active_policy_count',
        active_policies.ACTIVE_POLICY_COUNT,

    'shadow_policy_count',
        active_policies.SHADOW_POLICY_COUNT,

    'authority_enabled_count',
        active_policies.AUTHORITY_ENABLED_COUNT,

    'activation_entry_point',
        'ACTIVATE_APPROVED_ML_DEPLOYMENT_V4',

    'runtime_authority_state',
        'ALL_DOMAINS_BLOCKED',

    'official_cost_changed',
        FALSE,

    'policy_activated',
        FALSE
) AS PHASE13A_RESULT

FROM PROCEDURES procedures
CROSS JOIN SAFETY_POLICIES safety_policies
CROSS JOIN FINGERPRINTS fingerprints
CROSS JOIN SWITCHES switches
CROSS JOIN AUTHORITIES authorities
CROSS JOIN DECISIONS decisions
CROSS JOIN MONITORS monitors
CROSS JOIN ORPHANS orphans
CROSS JOIN DASHBOARD dashboard
CROSS JOIN ACTIVE_POLICIES active_policies;

-- ============================================================
-- PHASE 13B — PREFLIGHT
--
-- Exact object schema:
--   KMAT_COST_MODEL_DB.CORE_ML
--
-- This preflight performs no grants, revocations, ownership
-- transfers, policy activation, runtime enablement, or DML.
-- ============================================================

SELECT
    CURRENT_ROLE() AS CURRENT_ROLE,
    CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE() AS CURRENT_DATABASE,
    CURRENT_SCHEMA() AS CURRENT_SCHEMA;


-- ------------------------------------------------------------
-- 1. REQUIRED OBJECT INVENTORY
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_OBJECTS AS (
    SELECT * FROM VALUES
        ('TABLE','ML_DECISION_POLICY_V1'),
        ('TABLE','ML_DECISION_RESULT_V1'),
        ('TABLE','ML_DECISION_OVERRIDE_V1'),
        ('TABLE','ML_DECISION_AUDIT_V1'),
        ('TABLE','ML_DEPLOYMENT_CAPABILITY_V1'),
        ('TABLE','ML_DEPLOYMENT_GATE_POLICY_V1'),
        ('TABLE','ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1'),
        ('TABLE','ML_DEPLOYMENT_REQUEST_V1'),
        ('TABLE','ML_DEPLOYMENT_APPROVAL_V1'),
        ('TABLE','ML_DEPLOYMENT_EVENT_AUDIT_V1'),
        ('TABLE','ML_CANDIDATE_PREDICTION_V1'),
        ('TABLE','ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1'),
        ('TABLE','ML_CANDIDATE_BACKTEST_DETAIL_V1'),
        ('TABLE','ML_CANDIDATE_BACKTEST_RUN_V1'),
        ('TABLE','ML_PILOT_PLAN_V1'),
        ('TABLE','ML_PILOT_SCOPE_V1'),
        ('TABLE','ML_PILOT_CAPACITY_COUNTER_V1'),
        ('TABLE','ML_PILOT_ASSIGNMENT_V1'),
        ('TABLE','ML_PILOT_DECISION_V1'),
        ('TABLE','ML_PILOT_INCIDENT_V1'),
        ('TABLE','ML_PILOT_MONITORING_RUN_V1'),
        ('TABLE','ML_PILOT_EVENT_AUDIT_V1'),
        ('TABLE','ML_PILOT_EXIT_POLICY_V1'),
        ('TABLE','ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1'),
        ('TABLE','ML_PILOT_EXIT_REQUEST_V1'),
        ('TABLE','ML_PILOT_EXIT_ASSESSMENT_V1'),
        ('TABLE','ML_PILOT_EXIT_SIGNOFF_V1'),
        ('TABLE','ML_PRODUCTION_PROMOTION_LINK_V1'),
        ('TABLE','ML_PILOT_EXIT_EVENT_AUDIT_V1'),
        ('TABLE','ML_RUNTIME_SAFETY_POLICY_V1'),
        ('TABLE','ML_RUNTIME_AUTHORITY_REGISTRY_V1'),
        ('TABLE','ML_RUNTIME_KILL_SWITCH_V1'),
        ('TABLE','ML_RUNTIME_AUTHORITY_COUNTER_V1'),
        ('TABLE','ML_RUNTIME_AUTHORITY_DECISION_V1'),
        ('TABLE','ML_RUNTIME_SAFETY_MONITOR_RUN_V1'),
        ('TABLE','ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1'),
        ('TABLE','KMAT_ACTUAL_OUTCOME_AUDIT_V1'),
        ('TABLE','KMAT_GOVERNED_COST_INPUT_AUDIT_V2'),
        ('TABLE','KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1'),
        ('VIEW','VW_ML_DECISION_POLICY_CURRENT_V1'),
        ('VIEW','VW_ML_POLICY_RUNTIME_FINGERPRINT_V1'),
        ('VIEW','VW_ML_RUNTIME_AUTHORITY_CURRENT_V1'),
        ('VIEW','VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1')
    AS required(
        OBJECT_TYPE,
        OBJECT_NAME
    )
),
FOUND_OBJECTS AS (
    SELECT
        'TABLE' AS OBJECT_TYPE,
        TABLE_NAME AS OBJECT_NAME
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'CORE_ML'
      AND TABLE_TYPE = 'BASE TABLE'

    UNION ALL

    SELECT
        'VIEW' AS OBJECT_TYPE,
        TABLE_NAME AS OBJECT_NAME
    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'CORE_ML'
)
SELECT
    required.OBJECT_TYPE,
    required.OBJECT_NAME
FROM REQUIRED_OBJECTS required
LEFT JOIN FOUND_OBJECTS found
    ON required.OBJECT_TYPE = found.OBJECT_TYPE
   AND required.OBJECT_NAME = found.OBJECT_NAME
WHERE found.OBJECT_NAME IS NULL
ORDER BY
    required.OBJECT_TYPE,
    required.OBJECT_NAME;


-- ------------------------------------------------------------
-- 2. REQUIRED COLUMN INVENTORY
-- Expected: zero rows.
-- ------------------------------------------------------------

WITH REQUIRED_COLUMNS AS (
    SELECT * FROM VALUES
        ('ML_DECISION_POLICY_V1','POLICY_ID'),
        ('ML_DECISION_POLICY_V1','MODEL_DOMAIN'),
        ('ML_DECISION_POLICY_V1','POLICY_VERSION'),
        ('ML_DECISION_POLICY_V1','POLICY_STATUS'),
        ('ML_DECISION_POLICY_V1','DEPLOYMENT_MODE'),
        ('ML_DECISION_POLICY_V1','FINAL_VALUE_MIN'),
        ('ML_DECISION_POLICY_V1','FINAL_VALUE_MAX'),

        ('ML_DECISION_RESULT_V1','DECISION_ID'),
        ('ML_DECISION_RESULT_V1','ENTITY_ID'),
        ('ML_DECISION_RESULT_V1','MODEL_DOMAIN'),
        ('ML_DECISION_RESULT_V1','POLICY_ID'),
        ('ML_DECISION_RESULT_V1','POLICY_VERSION'),
        ('ML_DECISION_RESULT_V1','FINAL_NUMERIC_VALUE'),
        ('ML_DECISION_RESULT_V1','FINAL_TEXT_STATUS'),

        ('ML_DECISION_OVERRIDE_V1','OVERRIDE_ID'),
        ('ML_DECISION_OVERRIDE_V1','DECISION_ID'),
        ('ML_DECISION_OVERRIDE_V1','OVERRIDE_STATUS'),
        ('ML_DECISION_OVERRIDE_V1','REQUESTED_BY'),
        ('ML_DECISION_OVERRIDE_V1','REQUESTED_AT'),
        ('ML_DECISION_OVERRIDE_V1','REVIEWED_BY'),
        ('ML_DECISION_OVERRIDE_V1','REVIEWED_AT'),
        ('ML_DECISION_OVERRIDE_V1','UPDATED_AT'),

        ('ML_DEPLOYMENT_REQUEST_V1','DEPLOYMENT_REQUEST_ID'),
        ('ML_DEPLOYMENT_REQUEST_V1','EVIDENCE_VERSION'),
        ('ML_DEPLOYMENT_REQUEST_V1','REQUEST_STATUS'),

        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','RUNTIME_AUTHORITY_ID'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','DEPLOYMENT_REQUEST_ID'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','REQUEST_EVIDENCE_VERSION'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','MODEL_DOMAIN'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','AUTHORITY_MODE'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','POLICY_ID'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','POLICY_VERSION'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','POLICY_FINGERPRINT'),
        ('ML_RUNTIME_AUTHORITY_REGISTRY_V1','IS_ACTIVE'),

        ('VW_ML_POLICY_RUNTIME_FINGERPRINT_V1','MODEL_DOMAIN'),
        ('VW_ML_POLICY_RUNTIME_FINGERPRINT_V1','POLICY_ID'),
        ('VW_ML_POLICY_RUNTIME_FINGERPRINT_V1','POLICY_VERSION'),
        ('VW_ML_POLICY_RUNTIME_FINGERPRINT_V1','DEPLOYMENT_MODE'),
        ('VW_ML_POLICY_RUNTIME_FINGERPRINT_V1','POLICY_FINGERPRINT')
    AS required(
        OBJECT_NAME,
        COLUMN_NAME
    )
)
SELECT
    required.OBJECT_NAME,
    required.COLUMN_NAME
FROM REQUIRED_COLUMNS required
LEFT JOIN KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.COLUMNS found
    ON found.TABLE_SCHEMA = 'CORE_ML'
   AND found.TABLE_NAME = required.OBJECT_NAME
   AND found.COLUMN_NAME = required.COLUMN_NAME
WHERE found.COLUMN_NAME IS NULL
ORDER BY
    required.OBJECT_NAME,
    required.COLUMN_NAME;


-- ------------------------------------------------------------
-- 3. REQUIRED PROCEDURE INVENTORY
--
-- Expected:
--   PHASE13B_REQUIRED_PROCEDURE_COUNT = 23
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT PROCEDURE_NAME)
        AS PHASE13B_REQUIRED_PROCEDURE_COUNT
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CORE_ML'
  AND PROCEDURE_NAME IN (
      'SET_ML_DEPLOYMENT_CAPABILITY_V1',
      'SUBMIT_ML_DEPLOYMENT_REQUEST_V1',
      'REFRESH_ML_DEPLOYMENT_REQUEST_V1',
      'REVIEW_ML_DEPLOYMENT_REQUEST_V1',
      'ROLLBACK_ML_DEPLOYMENT_V1',
      'CREATE_ML_POLICY_CANDIDATE_V1',
      'CANCEL_ML_DEPLOYMENT_REQUEST_V1',

      'RECORD_ML_CANDIDATE_PREDICTION_V1',
      'RUN_ML_CANDIDATE_BACKTEST_V1',

      'ACTIVATE_ML_DECISION_POLICY_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_V4',

      'ENABLE_ML_RUNTIME_AUTHORITY_V1',
      'SET_ML_RUNTIME_KILL_SWITCH_V1',
      'RESOLVE_ML_RUNTIME_AUTHORITY_V1',
      'RUN_ML_RUNTIME_SAFETY_MONITOR_V1',
      'SUSPEND_ML_RUNTIME_AUTHORITY_V1',
      'REVOKE_ML_RUNTIME_AUTHORITY_V1',

      'CAPTURE_ML_DECISION_AUDIT_V1',
      'SUBMIT_ML_DECISION_OVERRIDE_V1',
      'REVIEW_ML_DECISION_OVERRIDE_V1'
  );


-- ------------------------------------------------------------
-- 4. CURRENT SAFETY BASELINE
-- ------------------------------------------------------------

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


SELECT
    COUNT(*) AS ACTIVE_RUNTIME_AUTHORITY_COUNT,

    COALESCE(
        COUNT_IF(
            AUTHORITY_STATUS = 'ENABLED'
        ),
        0
    )::NUMBER AS ENABLED_RUNTIME_AUTHORITY_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1;

-- ============================================================
-- PHASE 13B — OBJECT DEPLOYMENT
--
-- This file creates security metadata, secure entry procedures,
-- policy seals, corrected override precedence and audit views.
--
-- It does not create roles or change grants. Role creation,
-- ownership transfers, revocations and grants are performed by
-- phase13b_roles_and_grants_securityadmin.sql.
--
-- OBJECT_AGG calls: 0
-- VARIANT scripting variables in VALUES: 0
-- ============================================================


-- ============================================================
-- 1. SECURITY ROLE POLICY
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_ROLE_POLICY_V1 (
            ROLE_NAME VARCHAR NOT NULL,
            ROLE_CLASS VARCHAR NOT NULL,

            LOGIN_ASSIGNMENT_ALLOWED_FLAG BOOLEAN NOT NULL,
            DIRECT_TABLE_DML_ALLOWED_FLAG BOOLEAN NOT NULL,

            POLICY_STATUS VARCHAR NOT NULL,
            ROLE_PURPOSE VARCHAR NOT NULL,

            CREATED_BY VARCHAR NOT NULL,
            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),

            UPDATED_BY VARCHAR NOT NULL,
            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_ROLE_POLICY_V1 target
USING (
    SELECT *
    FROM VALUES
        (
            'KMAT_GOVERNANCE_DATA_OWNER_ROLE',
            'NON_LOGIN_OWNER',
            FALSE,
            TRUE,
            'ACTIVE',
            'Owns protected governance tables and views. Not assigned to application users.'
        ),
        (
            'KMAT_GOVERNANCE_EXECUTOR_ROLE',
            'NON_LOGIN_EXECUTOR',
            FALSE,
            TRUE,
            'ACTIVE',
            'Owns secure procedures and receives only the underlying privileges required by those procedures.'
        ),
        (
            'KMAT_GOVERNANCE_ADMIN_ROLE',
            'FUNCTIONAL_ADMIN',
            TRUE,
            FALSE,
            'ACTIVE',
            'Runs secure deployment, activation, runtime enablement and emergency-control entry points.'
        ),
        (
            'KMAT_RUNTIME_OPERATOR_ROLE',
            'FUNCTIONAL_OPERATOR',
            TRUE,
            FALSE,
            'ACTIVE',
            'Runs secure runtime resolution, safety monitoring and suspension entry points.'
        ),
        (
            'KMAT_APPLICATION_RUNTIME_ROLE',
            'APPLICATION_EXECUTOR',
            TRUE,
            FALSE,
            'ACTIVE',
            'Calls only the secure runtime decision resolver and reads approved runtime status views.'
        ),
        (
            'KMAT_OVERRIDE_REQUESTER_ROLE',
            'FUNCTIONAL_REQUESTER',
            TRUE,
            FALSE,
            'ACTIVE',
            'Submits governed override requests through the V2 secure procedure.'
        ),
        (
            'KMAT_OVERRIDE_REVIEWER_ROLE',
            'FUNCTIONAL_REVIEWER',
            TRUE,
            FALSE,
            'ACTIVE',
            'Reviews governed override requests through the V2 secure procedure.'
        ),
        (
            'KMAT_AUDIT_READER_ROLE',
            'READ_ONLY_AUDITOR',
            TRUE,
            FALSE,
            'ACTIVE',
            'Reads security, override, runtime and governance dashboards without direct table DML.'
        )
    AS seed(
        ROLE_NAME,
        ROLE_CLASS,
        LOGIN_ASSIGNMENT_ALLOWED_FLAG,
        DIRECT_TABLE_DML_ALLOWED_FLAG,
        POLICY_STATUS,
        ROLE_PURPOSE
    )
) source
ON target.ROLE_NAME =
   source.ROLE_NAME
WHEN NOT MATCHED THEN INSERT (
    ROLE_NAME,
    ROLE_CLASS,

    LOGIN_ASSIGNMENT_ALLOWED_FLAG,
    DIRECT_TABLE_DML_ALLOWED_FLAG,

    POLICY_STATUS,
    ROLE_PURPOSE,

    CREATED_BY,
    CREATED_AT,

    UPDATED_BY,
    UPDATED_AT
)
VALUES (
    source.ROLE_NAME,
    source.ROLE_CLASS,

    source.LOGIN_ASSIGNMENT_ALLOWED_FLAG,
    source.DIRECT_TABLE_DML_ALLOWED_FLAG,

    source.POLICY_STATUS,
    source.ROLE_PURPOSE,

    CURRENT_USER(),
    CURRENT_TIMESTAMP(),

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


-- ============================================================
-- 2. EXPECTED GRANTS AND SENSITIVE-OBJECT POLICY
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_EXPECTED_GRANT_V1 (
            EXPECTATION_ID VARCHAR NOT NULL,

            GRANTEE_ROLE VARCHAR NOT NULL,

            GRANTED_ON VARCHAR NOT NULL,
            OBJECT_NAME VARCHAR NOT NULL,
            PRIVILEGE VARCHAR NOT NULL,

            REQUIRED_FLAG BOOLEAN NOT NULL,
            POLICY_STATUS VARCHAR NOT NULL,

            COMMENTS VARCHAR,

            CREATED_BY VARCHAR NOT NULL,
            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_SENSITIVE_OBJECT_V1 (
            POLICY_ROW_ID VARCHAR NOT NULL,

            GRANTED_ON VARCHAR NOT NULL,
            OBJECT_NAME VARCHAR NOT NULL,
            PRIVILEGE VARCHAR NOT NULL,

            ALLOWED_GRANTEE_ROLE VARCHAR NOT NULL,
            ACCESS_CLASS VARCHAR NOT NULL,

            POLICY_STATUS VARCHAR NOT NULL,
            COMMENTS VARCHAR,

            CREATED_BY VARCHAR NOT NULL,
            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_APPEND_ONLY_OBJECT_POLICY_V1 (
            POLICY_ROW_ID VARCHAR NOT NULL,

            OBJECT_NAME VARCHAR NOT NULL,

            ALLOWED_INSERT_ROLE VARCHAR NOT NULL,
            ALLOWED_OWNER_ROLE VARCHAR NOT NULL,

            POLICY_STATUS VARCHAR NOT NULL,
            COMMENTS VARCHAR,

            CREATED_BY VARCHAR NOT NULL,
            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 3. IMMEDIATE GRANT SNAPSHOT
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID VARCHAR NOT NULL,
            CAPTURED_AT TIMESTAMP_NTZ NOT NULL,

            CAPTURE_SCOPE VARCHAR NOT NULL,

            GRANTED_ON VARCHAR,
            OBJECT_NAME VARCHAR,
            PRIVILEGE VARCHAR,

            GRANTED_TO VARCHAR,
            GRANTEE_NAME VARCHAR,

            GRANT_OPTION BOOLEAN,
            GRANTED_BY VARCHAR,

            SOURCE_COMMAND VARCHAR NOT NULL
        );


-- ============================================================
-- 4. POLICY VERSION SEAL
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_POLICY_VERSION_SEAL_V1 (
            POLICY_SEAL_ID VARCHAR NOT NULL,

            DEPLOYMENT_REQUEST_ID VARCHAR NOT NULL,
            REQUEST_EVIDENCE_VERSION NUMBER NOT NULL,
            RUNTIME_AUTHORITY_ID VARCHAR NOT NULL,

            MODEL_DOMAIN VARCHAR NOT NULL,
            DEPLOYMENT_MODE VARCHAR NOT NULL,

            POLICY_ID VARCHAR NOT NULL,
            POLICY_VERSION VARCHAR NOT NULL,
            POLICY_FINGERPRINT VARCHAR NOT NULL,

            SEAL_STATUS VARCHAR NOT NULL,
            IS_ACTIVE BOOLEAN NOT NULL,

            SEALED_BY VARCHAR NOT NULL,
            SEALED_AT TIMESTAMP_NTZ NOT NULL,

            SUPERSEDED_BY_POLICY_SEAL_ID VARCHAR,

            CREATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP(),
            UPDATED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 5. ACTUAL CALLER AUDIT
-- ============================================================

CREATE TABLE IF NOT EXISTS
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_CALL_AUDIT_V1 (
            SECURITY_AUDIT_ID VARCHAR NOT NULL,

            OPERATION_NAME VARCHAR NOT NULL,
            TARGET_OBJECT_ID VARCHAR,

            ACTUAL_USER VARCHAR NOT NULL,
            SESSION_ID NUMBER,

            RESULT_STATUS VARCHAR NOT NULL,
            RESULT_MESSAGE VARCHAR,

            RECORDED_AT TIMESTAMP_NTZ
                DEFAULT CURRENT_TIMESTAMP()
        );


-- ============================================================
-- 6. LATEST GRANT SNAPSHOT
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
AS
WITH LATEST_SNAPSHOT AS (
    SELECT SNAPSHOT_ID
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_GRANT_SNAPSHOT_V1
    GROUP BY SNAPSHOT_ID
    QUALIFY ROW_NUMBER() OVER (
        ORDER BY
            MAX(CAPTURED_AT) DESC,
            SNAPSHOT_ID DESC
    ) = 1
)
SELECT snapshot.*
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1
        snapshot
INNER JOIN LATEST_SNAPSHOT latest
    ON snapshot.SNAPSHOT_ID =
       latest.SNAPSHOT_ID;


-- ============================================================
-- 7. CORRECTED APPROVED-OVERRIDE PRECEDENCE
--
-- A newer PENDING or REJECTED request does not hide a still
-- approved override. A prior approved override is superseded
-- only when a replacement is actually approved by V2 review.
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2
AS
WITH LATEST_OVERRIDE_ANY AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY DECISION_ID
        ORDER BY
            UPDATED_AT DESC,
            CREATED_AT DESC,
            OVERRIDE_ID DESC
    ) = 1
),
LATEST_APPROVED_OVERRIDE AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    WHERE OVERRIDE_STATUS =
          'APPROVED_NOT_APPLIED'
      AND COALESCE(
          OVERRIDE_APPLIED_TO_OFFICIAL_FLAG,
          FALSE
      ) = FALSE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY DECISION_ID
        ORDER BY
            REVIEWED_AT DESC NULLS LAST,
            UPDATED_AT DESC,
            CREATED_AT DESC,
            OVERRIDE_ID DESC
    ) = 1
)
SELECT
    decision.DECISION_ID,
    decision.ENTITY_ID,
    decision.RFQ_ID,
    decision.SIMULATION_ID,
    decision.MODEL_DOMAIN,

    decision.POLICY_ID,
    decision.POLICY_VERSION,
    decision.DEPLOYMENT_MODE,

    decision.MODEL_NAME,
    decision.MODEL_VERSION,
    decision.FEATURE_SET_VERSION,

    decision.RULE_VALUE,
    decision.RAW_ML_VALUE,
    decision.RECOMMENDED_ML_VALUE,

    decision.FINAL_NUMERIC_VALUE
        AS OFFICIAL_FINAL_NUMERIC_VALUE,

    decision.FINAL_TEXT_STATUS
        AS OFFICIAL_FINAL_TEXT_STATUS,

    latest_any.OVERRIDE_ID
        AS LATEST_OVERRIDE_ID,
    latest_any.OVERRIDE_STATUS
        AS LATEST_OVERRIDE_STATUS,
    latest_any.OVERRIDE_REASON
        AS LATEST_OVERRIDE_REASON,
    latest_any.REQUESTED_BY
        AS LATEST_OVERRIDE_REQUESTED_BY,
    latest_any.REQUESTED_AT
        AS LATEST_OVERRIDE_REQUESTED_AT,
    latest_any.REVIEWED_BY
        AS LATEST_OVERRIDE_REVIEWED_BY,
    latest_any.REVIEWED_AT
        AS LATEST_OVERRIDE_REVIEWED_AT,
    latest_any.REVIEW_NOTE
        AS LATEST_OVERRIDE_REVIEW_NOTE,

    approved.OVERRIDE_ID
        AS EFFECTIVE_APPROVED_OVERRIDE_ID,
    approved.OVERRIDE_NUMERIC_VALUE
        AS APPROVED_SHADOW_OVERRIDE_NUMERIC_VALUE,
    approved.OVERRIDE_TEXT_STATUS
        AS APPROVED_SHADOW_OVERRIDE_TEXT_STATUS,
    approved.OVERRIDE_REASON
        AS APPROVED_OVERRIDE_REASON,
    approved.REQUESTED_BY
        AS APPROVED_OVERRIDE_REQUESTED_BY,
    approved.REVIEWED_BY
        AS APPROVED_OVERRIDE_REVIEWED_BY,
    approved.REVIEWED_AT
        AS APPROVED_OVERRIDE_REVIEWED_AT,

    COALESCE(
        approved.OVERRIDE_NUMERIC_VALUE::FLOAT,
        decision.FINAL_NUMERIC_VALUE::FLOAT
    ) AS SHADOW_COMPARISON_NUMERIC_VALUE,

    COALESCE(
        approved.OVERRIDE_TEXT_STATUS::VARCHAR,
        decision.FINAL_TEXT_STATUS::VARCHAR
    ) AS SHADOW_COMPARISON_TEXT_STATUS,

    IFF(
        approved.OVERRIDE_ID IS NOT NULL
        AND (
            latest_any.OVERRIDE_ID IS NULL
            OR latest_any.OVERRIDE_ID
                <> approved.OVERRIDE_ID
        ),
        TRUE,
        FALSE
    ) AS APPROVED_OVERRIDE_PRESERVED_UNDER_NEWER_REQUEST_FLAG,

    FALSE AS OVERRIDE_APPLIED_TO_OFFICIAL_FLAG,

    decision.ML_VALUE_ACCEPTED_FLAG,
    decision.EFFECTIVE_COST_IMPACT_ALLOWED_FLAG,
    decision.EFFECTIVE_BUSINESS_DECISION_ALLOWED_FLAG,

    decision.CREATED_AT
        AS DECISION_CREATED_AT,
    decision.UPDATED_AT
        AS DECISION_UPDATED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_DECISION_RESULT_V1
        decision

LEFT JOIN LATEST_OVERRIDE_ANY latest_any
    ON decision.DECISION_ID =
       latest_any.DECISION_ID

LEFT JOIN LATEST_APPROVED_OVERRIDE approved
    ON decision.DECISION_ID =
       approved.DECISION_ID;


-- ============================================================
-- 8. POLICY SEAL INTEGRITY
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1
AS
WITH ACTIVE_SEAL AS (
    SELECT *
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_POLICY_VERSION_SEAL_V1
    WHERE IS_ACTIVE = TRUE
      AND SEAL_STATUS = 'SEALED'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MODEL_DOMAIN
        ORDER BY
            SEALED_AT DESC,
            POLICY_SEAL_ID DESC
    ) = 1
)
SELECT
    fingerprint.MODEL_DOMAIN,

    fingerprint.POLICY_ID
        AS CURRENT_POLICY_ID,
    fingerprint.POLICY_VERSION
        AS CURRENT_POLICY_VERSION,
    fingerprint.DEPLOYMENT_MODE
        AS CURRENT_DEPLOYMENT_MODE,
    fingerprint.POLICY_FINGERPRINT
        AS CURRENT_POLICY_FINGERPRINT,

    seal.POLICY_SEAL_ID,
    seal.DEPLOYMENT_REQUEST_ID,
    seal.REQUEST_EVIDENCE_VERSION,
    seal.RUNTIME_AUTHORITY_ID,

    seal.POLICY_ID
        AS SEALED_POLICY_ID,
    seal.POLICY_VERSION
        AS SEALED_POLICY_VERSION,
    seal.DEPLOYMENT_MODE
        AS SEALED_DEPLOYMENT_MODE,
    seal.POLICY_FINGERPRINT
        AS SEALED_POLICY_FINGERPRINT,

    seal.SEALED_BY,
    seal.SEALED_AT,

    IFF(
        seal.POLICY_SEAL_ID IS NULL,
        FALSE,
        TRUE
    ) AS ACTIVE_SEAL_PRESENT_FLAG,

    IFF(
        seal.POLICY_SEAL_ID IS NOT NULL
        AND seal.POLICY_ID =
            fingerprint.POLICY_ID
        AND seal.POLICY_VERSION =
            fingerprint.POLICY_VERSION
        AND seal.DEPLOYMENT_MODE =
            fingerprint.DEPLOYMENT_MODE
        AND seal.POLICY_FINGERPRINT =
            fingerprint.POLICY_FINGERPRINT,
        TRUE,
        FALSE
    ) AS POLICY_SEAL_MATCH_FLAG,

    CASE
        WHEN seal.POLICY_SEAL_ID IS NULL
            THEN 'NO_ACTIVE_SEAL'
        WHEN seal.POLICY_ID
            <> fingerprint.POLICY_ID
            THEN 'POLICY_ID_MISMATCH'
        WHEN seal.POLICY_VERSION
            <> fingerprint.POLICY_VERSION
            THEN 'POLICY_VERSION_MISMATCH'
        WHEN seal.DEPLOYMENT_MODE
            <> fingerprint.DEPLOYMENT_MODE
            THEN 'DEPLOYMENT_MODE_MISMATCH'
        WHEN seal.POLICY_FINGERPRINT
            <> fingerprint.POLICY_FINGERPRINT
            THEN 'POLICY_FINGERPRINT_MISMATCH'
        ELSE 'SEALED_MATCH'
    END AS POLICY_SEAL_STATUS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
        fingerprint

LEFT JOIN ACTIVE_SEAL seal
    ON fingerprint.MODEL_DOMAIN =
       seal.MODEL_DOMAIN;

-- ============================================================
-- 9. SECURITY POLICY SEEDS
-- ============================================================

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_EXPECTED_GRANT_V1 target
USING (
    SELECT *
    FROM VALUES
        ('DB_USAGE::KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_APPLICATION_RUNTIME_ROLE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_APPLICATION_RUNTIME_ROLE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_OVERRIDE_REQUESTER_ROLE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_OVERRIDE_REQUESTER_ROLE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_OVERRIDE_REVIEWER_ROLE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_OVERRIDE_REVIEWER_ROLE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('DB_USAGE::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'DATABASE', 'KMAT_COST_MODEL_DB', 'USAGE', TRUE, 'ACTIVE', 'Database access required by the role.'),
        ('SCHEMA_USAGE::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'SCHEMA', 'KMAT_COST_MODEL_DB.CORE_ML', 'USAGE', TRUE, 'ACTIVE', 'Schema access required by the role.'),
        ('WAREHOUSE_USAGE::KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_APPLICATION_RUNTIME_ROLE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_OVERRIDE_REQUESTER_ROLE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_OVERRIDE_REVIEWER_ROLE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('WAREHOUSE_USAGE::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'WAREHOUSE', 'KMAT_WH', 'USAGE', TRUE, 'ACTIVE', 'Warehouse access required to call procedures or query views.'),
        ('PROC_USAGE::SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::CREATE_ML_POLICY_CANDIDATE_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::ROLLBACK_ML_DEPLOYMENT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::RUN_ML_CANDIDATE_BACKTEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::CAPTURE_ML_DECISION_AUDIT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Governance administrator secure procedure access.'),
        ('PROC_USAGE::RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('PROC_USAGE::RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('PROC_USAGE::SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('PROC_USAGE::RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_APPLICATION_RUNTIME_ROLE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('PROC_USAGE::SUBMIT_ML_DECISION_OVERRIDE_V2::KMAT_OVERRIDE_REQUESTER_ROLE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('PROC_USAGE::REVIEW_ML_DECISION_OVERRIDE_V2::KMAT_OVERRIDE_REVIEWER_ROLE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Functional secure procedure access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1::KMAT_APPLICATION_RUNTIME_ROLE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2::KMAT_OVERRIDE_REQUESTER_ROLE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2::KMAT_OVERRIDE_REVIEWER_ROLE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE12C_PRODUCTION_READINESS_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12C_PRODUCTION_READINESS_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE12B_PILOT_DASHBOARD_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12B_PILOT_DASHBOARD_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.'),
        ('VIEW_SELECT::VW_KMAT_PHASE11A_MONITORING_DASHBOARD_V1::KMAT_AUDIT_READER_ROLE', 'KMAT_AUDIT_READER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE11A_MONITORING_DASHBOARD_V1', 'SELECT', TRUE, 'ACTIVE', 'Approved read-only view access.')
    AS seed(
        EXPECTATION_ID,
        GRANTEE_ROLE,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        REQUIRED_FLAG,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.EXPECTATION_ID =
   source.EXPECTATION_ID
WHEN NOT MATCHED THEN INSERT (
    EXPECTATION_ID,

    GRANTEE_ROLE,

    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,

    REQUIRED_FLAG,
    POLICY_STATUS,

    COMMENTS,

    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.EXPECTATION_ID,

    source.GRANTEE_ROLE,

    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,

    source.REQUIRED_FLAG,
    source.POLICY_STATUS,

    source.COMMENTS,

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_SENSITIVE_OBJECT_V1 target
USING (
    SELECT *
    FROM VALUES
        ('UNDERLYING::SET_ML_DEPLOYMENT_CAPABILITY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::CREATE_ML_POLICY_CANDIDATE_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::SUBMIT_ML_DEPLOYMENT_REQUEST_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::REFRESH_ML_DEPLOYMENT_REQUEST_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::REVIEW_ML_DEPLOYMENT_REQUEST_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::ROLLBACK_ML_DEPLOYMENT_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::CANCEL_ML_DEPLOYMENT_REQUEST_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::RECORD_ML_CANDIDATE_PREDICTION_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::RUN_ML_CANDIDATE_BACKTEST_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::ACTIVATE_APPROVED_ML_DEPLOYMENT_V4', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::ENABLE_ML_RUNTIME_AUTHORITY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::SET_ML_RUNTIME_KILL_SWITCH_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::RESOLVE_ML_RUNTIME_AUTHORITY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::RUN_ML_RUNTIME_SAFETY_MONITOR_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::SUSPEND_ML_RUNTIME_AUTHORITY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::REVOKE_ML_RUNTIME_AUTHORITY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('UNDERLYING::CAPTURE_ML_DECISION_AUDIT_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'UNDERLYING_ENTRY_POINT', 'ACTIVE', 'Only the non-login executor role may call this actor-parameter or internal procedure directly.'),
        ('FORBIDDEN::ACTIVATE_ML_DECISION_POLICY_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('FORBIDDEN::ACTIVATE_APPROVED_ML_DEPLOYMENT_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('FORBIDDEN::ACTIVATE_APPROVED_ML_DEPLOYMENT_V2', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('FORBIDDEN::ACTIVATE_APPROVED_ML_DEPLOYMENT_V3', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('FORBIDDEN::SUBMIT_ML_DECISION_OVERRIDE_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('FORBIDDEN::REVIEW_ML_DECISION_OVERRIDE_V1', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', '__NO_DIRECT_GRANTEE__', 'FORBIDDEN_BYPASS_ENTRY_POINT', 'ACTIVE', 'No functional role receives direct USAGE; access must flow through the secure Phase 13B entry point.'),
        ('SECURE::SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::CREATE_ML_POLICY_CANDIDATE_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::ROLLBACK_ML_DEPLOYMENT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RUN_ML_CANDIDATE_BACKTEST_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_APPLICATION_RUNTIME_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR)', 'USAGE', 'KMAT_APPLICATION_RUNTIME_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR)', 'USAGE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR)', 'USAGE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_RUNTIME_OPERATOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_RUNTIME_OPERATOR_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::CAPTURE_ML_DECISION_AUDIT_SECURE_V1::KMAT_GOVERNANCE_ADMIN_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_GOVERNANCE_ADMIN_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::SUBMIT_ML_DECISION_OVERRIDE_V2::KMAT_OVERRIDE_REQUESTER_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_OVERRIDE_REQUESTER_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.'),
        ('SECURE::REVIEW_ML_DECISION_OVERRIDE_V2::KMAT_OVERRIDE_REVIEWER_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', 'KMAT_OVERRIDE_REVIEWER_ROLE', 'SECURE_ENTRY_POINT', 'ACTIVE', 'Explicit Phase 13B secure procedure grant.')
    AS seed(
        POLICY_ROW_ID,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        ALLOWED_GRANTEE_ROLE,
        ACCESS_CLASS,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.POLICY_ROW_ID =
   source.POLICY_ROW_ID
WHEN NOT MATCHED THEN INSERT (
    POLICY_ROW_ID,

    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,

    ALLOWED_GRANTEE_ROLE,
    ACCESS_CLASS,

    POLICY_STATUS,
    COMMENTS,

    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.POLICY_ROW_ID,

    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,

    source.ALLOWED_GRANTEE_ROLE,
    source.ACCESS_CLASS,

    source.POLICY_STATUS,
    source.COMMENTS,

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_APPEND_ONLY_OBJECT_POLICY_V1 target
USING (
    SELECT *
    FROM VALUES
        ('APPEND_ONLY::ML_DECISION_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_DEPLOYMENT_EVENT_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_PILOT_EVENT_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_PILOT_EXIT_EVENT_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.'),
        ('APPEND_ONLY::ML_SECURITY_CALL_AUDIT_V1', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'ACTIVE', 'Operational roles receive no UPDATE, DELETE or TRUNCATE privilege on this audit table.')
    AS seed(
        POLICY_ROW_ID,
        OBJECT_NAME,
        ALLOWED_INSERT_ROLE,
        ALLOWED_OWNER_ROLE,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.POLICY_ROW_ID =
   source.POLICY_ROW_ID
WHEN NOT MATCHED THEN INSERT (
    POLICY_ROW_ID,

    OBJECT_NAME,

    ALLOWED_INSERT_ROLE,
    ALLOWED_OWNER_ROLE,

    POLICY_STATUS,
    COMMENTS,

    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.POLICY_ROW_ID,

    source.OBJECT_NAME,

    source.ALLOWED_INSERT_ROLE,
    source.ALLOWED_OWNER_ROLE,

    source.POLICY_STATUS,
    source.COMMENTS,

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);

-- ============================================================
-- 10. SECURE ACTUAL-USER ENTRY PROCEDURES
-- ============================================================

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(
            P_CAPABILITY_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_CAPABILITY_KEY VARCHAR,
            P_CAPABILITY_VERSION VARCHAR,
            P_READY_FLAG BOOLEAN,
            P_EVIDENCE_REFERENCE VARCHAR,
            P_APPROVAL_REASON VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .SET_ML_DEPLOYMENT_CAPABILITY_V1(
                    :P_CAPABILITY_ID,
                    :P_MODEL_DOMAIN,
                    :P_CAPABILITY_KEY,
                    :P_CAPABILITY_VERSION,
                    :P_READY_FLAG,
                    :P_EVIDENCE_REFERENCE,
                    :P_APPROVAL_REASON,
                    :V_ACTUAL_USER
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1'',
        :P_CAPABILITY_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .CREATE_ML_POLICY_CANDIDATE_SECURE_V1(
            P_POLICY_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_POLICY_VERSION VARCHAR,
            P_TARGET_MODE VARCHAR,
            P_CANDIDATE_MODEL_NAME VARCHAR,
            P_CANDIDATE_MODEL_VERSION VARCHAR,
            P_FEATURE_SET_VERSION VARCHAR,
            P_AUTO_USE_ALLOWED_FLAG BOOLEAN,
            P_OFFICIAL_COST_IMPACT_ALLOWED_FLAG BOOLEAN,
            P_BUSINESS_DECISION_ALLOWED_FLAG BOOLEAN,
            P_MAX_ABS_DEVIATION_FROM_RULE FLOAT,
            P_MAX_PCT_DEVIATION_FROM_RULE FLOAT,
            P_MAX_ESTIMATED_COST_IMPACT_PCT FLOAT,
            P_COMMENTS VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .CREATE_ML_POLICY_CANDIDATE_V1(
                    :P_POLICY_ID,
                    :P_MODEL_DOMAIN,
                    :P_POLICY_VERSION,
                    :P_TARGET_MODE,
                    :P_CANDIDATE_MODEL_NAME,
                    :P_CANDIDATE_MODEL_VERSION,
                    :P_FEATURE_SET_VERSION,
                    :P_AUTO_USE_ALLOWED_FLAG,
                    :P_OFFICIAL_COST_IMPACT_ALLOWED_FLAG,
                    :P_BUSINESS_DECISION_ALLOWED_FLAG,
                    :P_MAX_ABS_DEVIATION_FROM_RULE,
                    :P_MAX_PCT_DEVIATION_FROM_RULE,
                    :P_MAX_ESTIMATED_COST_IMPACT_PCT,
                    :V_ACTUAL_USER,
                    :P_COMMENTS
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''CREATE_ML_POLICY_CANDIDATE_SECURE_V1'',
        :P_POLICY_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''CREATE_ML_POLICY_CANDIDATE_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''CREATE_ML_POLICY_CANDIDATE_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_CANDIDATE_POLICY_VERSION VARCHAR,
            P_BUSINESS_JUSTIFICATION VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .SUBMIT_ML_DEPLOYMENT_REQUEST_V1(
                    :P_DEPLOYMENT_REQUEST_ID,
                    :P_MODEL_DOMAIN,
                    :P_CANDIDATE_POLICY_VERSION,
                    :V_ACTUAL_USER,
                    :P_BUSINESS_JUSTIFICATION
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1'',
        :P_DEPLOYMENT_REQUEST_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_REFRESH_REASON VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .REFRESH_ML_DEPLOYMENT_REQUEST_V1(
                    :P_DEPLOYMENT_REQUEST_ID,
                    :V_ACTUAL_USER,
                    :P_REFRESH_REASON
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1'',
        :P_DEPLOYMENT_REQUEST_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(
            P_APPROVAL_ID VARCHAR,
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_APPROVAL_STAGE VARCHAR,
            P_REVIEW_ACTION VARCHAR,
            P_REVIEW_NOTE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .REVIEW_ML_DEPLOYMENT_REQUEST_V1(
                    :P_APPROVAL_ID,
                    :P_DEPLOYMENT_REQUEST_ID,
                    :P_APPROVAL_STAGE,
                    :P_REVIEW_ACTION,
                    :V_ACTUAL_USER,
                    :P_REVIEW_NOTE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1'',
        :P_DEPLOYMENT_REQUEST_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ROLLBACK_ML_DEPLOYMENT_SECURE_V1(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_ROLLBACK_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .ROLLBACK_ML_DEPLOYMENT_V1(
                    :P_DEPLOYMENT_REQUEST_ID,
                    :V_ACTUAL_USER,
                    :P_ROLLBACK_REASON,
                    :P_CONFIRMATION_PHRASE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''ROLLBACK_ML_DEPLOYMENT_SECURE_V1'',
        :P_DEPLOYMENT_REQUEST_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''ROLLBACK_ML_DEPLOYMENT_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''ROLLBACK_ML_DEPLOYMENT_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_CANCELLATION_REASON VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .CANCEL_ML_DEPLOYMENT_REQUEST_V1(
                    :P_DEPLOYMENT_REQUEST_ID,
                    :V_ACTUAL_USER,
                    :P_CANCELLATION_REASON
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1'',
        :P_DEPLOYMENT_REQUEST_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(
            P_PREDICTION_ID VARCHAR,
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_SIMULATION_ID VARCHAR,
            P_PREDICTION_SET_VERSION VARCHAR,
            P_PREDICTED_NUMERIC_VALUE FLOAT,
            P_QUALITY_PASS_FLAG BOOLEAN,
            P_OOD_FLAG BOOLEAN,
            P_PREDICTION_SOURCE VARCHAR,
            P_SOURCE_REFERENCE VARCHAR,
            P_NOTES VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .RECORD_ML_CANDIDATE_PREDICTION_V1(
                    :P_PREDICTION_ID,
                    :P_DEPLOYMENT_REQUEST_ID,
                    :P_SIMULATION_ID,
                    :P_PREDICTION_SET_VERSION,
                    :P_PREDICTED_NUMERIC_VALUE,
                    :P_QUALITY_PASS_FLAG,
                    :P_OOD_FLAG,
                    :P_PREDICTION_SOURCE,
                    :P_SOURCE_REFERENCE,
                    :P_NOTES,
                    :V_ACTUAL_USER
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1'',
        :P_PREDICTION_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(
            P_BACKTEST_RUN_ID VARCHAR,
            P_DEPLOYMENT_REQUEST_ID VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .RUN_ML_CANDIDATE_BACKTEST_V1(
                    :P_BACKTEST_RUN_ID,
                    :P_DEPLOYMENT_REQUEST_ID,
                    :V_ACTUAL_USER
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''RUN_ML_CANDIDATE_BACKTEST_SECURE_V1'',
        :P_BACKTEST_RUN_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''RUN_ML_CANDIDATE_BACKTEST_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''RUN_ML_CANDIDATE_BACKTEST_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_ENABLE_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .ENABLE_ML_RUNTIME_AUTHORITY_V1(
                    :P_RUNTIME_AUTHORITY_ID,
                    :V_ACTUAL_USER,
                    :P_ENABLE_REASON,
                    :P_CONFIRMATION_PHRASE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1'',
        :P_RUNTIME_AUTHORITY_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(
            P_SWITCH_SCOPE VARCHAR,
            P_SWITCH_STATUS VARCHAR,
            P_SWITCH_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .SET_ML_RUNTIME_KILL_SWITCH_V1(
                    :P_SWITCH_SCOPE,
                    :P_SWITCH_STATUS,
                    :P_SWITCH_REASON,
                    :V_ACTUAL_USER,
                    :P_CONFIRMATION_PHRASE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1'',
        :P_SWITCH_SCOPE,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(
            P_RUNTIME_DECISION_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR,
            P_SIMULATION_ID VARCHAR,
            P_RULE_VALUE FLOAT,
            P_CANDIDATE_VALUE FLOAT,
            P_QUALITY_PASS_FLAG BOOLEAN,
            P_OOD_FLAG BOOLEAN,
            P_ENGINEER_APPROVED_FLAG BOOLEAN,
            P_ENGINEER_APPROVAL_REFERENCE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .RESOLVE_ML_RUNTIME_AUTHORITY_V1(
                    :P_RUNTIME_DECISION_ID,
                    :P_MODEL_DOMAIN,
                    :P_SIMULATION_ID,
                    :P_RULE_VALUE,
                    :P_CANDIDATE_VALUE,
                    :P_QUALITY_PASS_FLAG,
                    :P_OOD_FLAG,
                    :P_ENGINEER_APPROVED_FLAG,
                    :P_ENGINEER_APPROVAL_REFERENCE,
                    :V_ACTUAL_USER
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1'',
        :P_RUNTIME_DECISION_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(
            P_MONITOR_RUN_ID VARCHAR,
            P_MODEL_DOMAIN VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .RUN_ML_RUNTIME_SAFETY_MONITOR_V1(
                    :P_MONITOR_RUN_ID,
                    :P_MODEL_DOMAIN,
                    :V_ACTUAL_USER
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1'',
        :P_MONITOR_RUN_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_SUSPEND_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .SUSPEND_ML_RUNTIME_AUTHORITY_V1(
                    :P_RUNTIME_AUTHORITY_ID,
                    :P_SUSPEND_REASON,
                    :V_ACTUAL_USER,
                    :P_CONFIRMATION_PHRASE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1'',
        :P_RUNTIME_AUTHORITY_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(
            P_RUNTIME_AUTHORITY_ID VARCHAR,
            P_REVOKE_REASON VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .REVOKE_ML_RUNTIME_AUTHORITY_V1(
                    :P_RUNTIME_AUTHORITY_ID,
                    :P_REVOKE_REASON,
                    :V_ACTUAL_USER,
                    :P_CONFIRMATION_PHRASE
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1'',
        :P_RUNTIME_AUTHORITY_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .CAPTURE_ML_DECISION_AUDIT_SECURE_V1(
            P_DECISION_ID VARCHAR,
            P_EVENT_TYPE VARCHAR,
            P_EVENT_REASON VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
    V_ACTUAL_USER VARCHAR;
    V_RESULT VARIANT;

    V_RESULT_STATUS VARCHAR;
    V_RESULT_MESSAGE VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .CAPTURE_ML_DECISION_AUDIT_V1(
                    :P_DECISION_ID,
                    :P_EVENT_TYPE,
                    :V_ACTUAL_USER,
                    :P_EVENT_REASON
                )
    INTO :V_RESULT;

    SELECT
        COALESCE(
            GET(:V_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),

        COALESCE(
            GET(:V_RESULT, ''message'')::VARCHAR,
            GET(:V_RESULT, ''sqlerrm'')::VARCHAR
        )

    INTO
        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''CAPTURE_ML_DECISION_AUDIT_SECURE_V1'',
        :P_DECISION_ID,

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        :V_RESULT_STATUS,
        :V_RESULT_MESSAGE,

        CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', V_RESULT_STATUS,
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''CAPTURE_ML_DECISION_AUDIT_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''underlying_result'', V_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''CAPTURE_ML_DECISION_AUDIT_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;
';

-- ============================================================
-- 11. SECURE V4 ACTIVATION AND POLICY SEAL
-- ============================================================

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(
            P_DEPLOYMENT_REQUEST_ID VARCHAR,
            P_CONFIRMATION_PHRASE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '

DECLARE
    V_ACTUAL_USER VARCHAR;

    V_V4_RESULT VARIANT;
    V_V4_STATUS VARCHAR;
    V_V4_MESSAGE VARCHAR;

    V_AUTHORITY_COUNT NUMBER DEFAULT 0;
    V_EXISTING_SEAL_COUNT NUMBER DEFAULT 0;

    V_RUNTIME_AUTHORITY_ID VARCHAR;

    V_DEPLOYMENT_REQUEST_ID VARCHAR;
    V_REQUEST_EVIDENCE_VERSION NUMBER;

    V_MODEL_DOMAIN VARCHAR;
    V_AUTHORITY_MODE VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_POLICY_FINGERPRINT VARCHAR;

    V_POLICY_SEAL_ID VARCHAR;
    V_EXISTING_SEAL_FINGERPRINT VARCHAR;

    V_SECURITY_AUDIT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    IF (
        P_DEPLOYMENT_REQUEST_ID IS NULL
        OR LENGTH(TRIM(P_DEPLOYMENT_REQUEST_ID)) = 0
        OR P_CONFIRMATION_PHRASE IS NULL
        OR LENGTH(TRIM(P_CONFIRMATION_PHRASE)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Deployment request and confirmation phrase are required.''
        );
    END IF;

    V_ACTUAL_USER := CURRENT_USER();

    CALL
        KMAT_COST_MODEL_DB.CORE_ML
            .ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(
                :P_DEPLOYMENT_REQUEST_ID,
                :V_ACTUAL_USER,
                :P_CONFIRMATION_PHRASE
            )
    INTO :V_V4_RESULT;

    SELECT
        COALESCE(
            GET(:V_V4_RESULT, ''status'')::VARCHAR,
            ''UNKNOWN''
        ),
        COALESCE(
            GET(:V_V4_RESULT, ''message'')::VARCHAR,
            GET(:V_V4_RESULT, ''sqlerrm'')::VARCHAR
        ),
        GET(
            :V_V4_RESULT,
            ''runtime_authority_id''
        )::VARCHAR
    INTO
        :V_V4_STATUS,
        :V_V4_MESSAGE,
        :V_RUNTIME_AUTHORITY_ID;

    V_SECURITY_AUDIT_ID := UUID_STRING();

    IF (V_V4_STATUS <> ''SUCCESS'') THEN
        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_SECURITY_CALL_AUDIT_V1 (
                    SECURITY_AUDIT_ID,

                    OPERATION_NAME,
                    TARGET_OBJECT_ID,

                    ACTUAL_USER,
                    SESSION_ID,

                    RESULT_STATUS,
                    RESULT_MESSAGE,

                    RECORDED_AT
                )
        SELECT
            :V_SECURITY_AUDIT_ID,

            ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',
            TRIM(:P_DEPLOYMENT_REQUEST_ID),

            :V_ACTUAL_USER,
            CURRENT_SESSION(),

            :V_V4_STATUS,
            :V_V4_MESSAGE,

            CURRENT_TIMESTAMP();

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', V_V4_STATUS,
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',

            ''actual_user'', V_ACTUAL_USER,
            ''security_audit_id'',
                V_SECURITY_AUDIT_ID,

            ''underlying_result'',
                V_V4_RESULT
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DEPLOYMENT_REQUEST_ID),
        MAX(REQUEST_EVIDENCE_VERSION),

        MAX(MODEL_DOMAIN),
        MAX(AUTHORITY_MODE),

        MAX(POLICY_ID),
        MAX(POLICY_VERSION),
        MAX(POLICY_FINGERPRINT)

    INTO
        :V_AUTHORITY_COUNT,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_POLICY_FINGERPRINT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_RUNTIME_AUTHORITY_REGISTRY_V1

    WHERE RUNTIME_AUTHORITY_ID =
          :V_RUNTIME_AUTHORITY_ID
      AND IS_ACTIVE = TRUE;

    IF (V_AUTHORITY_COUNT <> 1) THEN
        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_SECURITY_CALL_AUDIT_V1 (
                    SECURITY_AUDIT_ID,

                    OPERATION_NAME,
                    TARGET_OBJECT_ID,

                    ACTUAL_USER,
                    SESSION_ID,

                    RESULT_STATUS,
                    RESULT_MESSAGE,

                    RECORDED_AT
                )
        SELECT
            :V_SECURITY_AUDIT_ID,

            ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',
            TRIM(:P_DEPLOYMENT_REQUEST_ID),

            :V_ACTUAL_USER,
            CURRENT_SESSION(),

            ''ERROR'',
            ''V4 succeeded but exactly one active runtime authority could not be resolved.'',

            CURRENT_TIMESTAMP();

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''message'',
            ''V4 succeeded but exactly one active runtime authority could not be resolved.'',

            ''runtime_authority_id'',
                V_RUNTIME_AUTHORITY_ID,
            ''authority_count'',
                V_AUTHORITY_COUNT,

            ''actual_user'', V_ACTUAL_USER,
            ''security_audit_id'',
                V_SECURITY_AUDIT_ID,

            ''underlying_result'',
                V_V4_RESULT
        );
    END IF;

    V_POLICY_SEAL_ID :=
        V_RUNTIME_AUTHORITY_ID
        || ''::POLICY_SEAL'';

    SELECT
        COUNT(*),
        MAX(POLICY_FINGERPRINT)
    INTO
        :V_EXISTING_SEAL_COUNT,
        :V_EXISTING_SEAL_FINGERPRINT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_POLICY_VERSION_SEAL_V1
    WHERE POLICY_SEAL_ID =
          :V_POLICY_SEAL_ID;

    IF (
        V_EXISTING_SEAL_COUNT > 0
        AND V_EXISTING_SEAL_FINGERPRINT
            <> V_POLICY_FINGERPRINT
    ) THEN
        INSERT INTO
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_SECURITY_CALL_AUDIT_V1 (
                    SECURITY_AUDIT_ID,

                    OPERATION_NAME,
                    TARGET_OBJECT_ID,

                    ACTUAL_USER,
                    SESSION_ID,

                    RESULT_STATUS,
                    RESULT_MESSAGE,

                    RECORDED_AT
                )
        SELECT
            :V_SECURITY_AUDIT_ID,

            ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',
            TRIM(:P_DEPLOYMENT_REQUEST_ID),

            :V_ACTUAL_USER,
            CURRENT_SESSION(),

            ''ERROR'',
            ''Existing policy seal fingerprint conflicts with the activated runtime authority.'',

            CURRENT_TIMESTAMP();

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''message'',
            ''Existing policy seal fingerprint conflicts with the activated runtime authority.'',

            ''policy_seal_id'',
                V_POLICY_SEAL_ID,
            ''existing_policy_fingerprint'',
                V_EXISTING_SEAL_FINGERPRINT,
            ''activated_policy_fingerprint'',
                V_POLICY_FINGERPRINT,

            ''actual_user'', V_ACTUAL_USER,
            ''security_audit_id'',
                V_SECURITY_AUDIT_ID
        );
    END IF;

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_POLICY_VERSION_SEAL_V1
    SET
        SEAL_STATUS =
            ''SUPERSEDED'',
        IS_ACTIVE =
            FALSE,
        SUPERSEDED_BY_POLICY_SEAL_ID =
            :V_POLICY_SEAL_ID,
        UPDATED_AT =
            CURRENT_TIMESTAMP()
    WHERE MODEL_DOMAIN =
          :V_MODEL_DOMAIN
      AND IS_ACTIVE = TRUE
      AND POLICY_SEAL_ID
          <> :V_POLICY_SEAL_ID;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_POLICY_VERSION_SEAL_V1 (
                POLICY_SEAL_ID,

                DEPLOYMENT_REQUEST_ID,
                REQUEST_EVIDENCE_VERSION,
                RUNTIME_AUTHORITY_ID,

                MODEL_DOMAIN,
                DEPLOYMENT_MODE,

                POLICY_ID,
                POLICY_VERSION,
                POLICY_FINGERPRINT,

                SEAL_STATUS,
                IS_ACTIVE,

                SEALED_BY,
                SEALED_AT,

                SUPERSEDED_BY_POLICY_SEAL_ID,

                CREATED_AT,
                UPDATED_AT
            )
    SELECT
        :V_POLICY_SEAL_ID,

        :V_DEPLOYMENT_REQUEST_ID,
        :V_REQUEST_EVIDENCE_VERSION,
        :V_RUNTIME_AUTHORITY_ID,

        :V_MODEL_DOMAIN,
        :V_AUTHORITY_MODE,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_POLICY_FINGERPRINT,

        ''SEALED'',
        TRUE,

        :V_ACTUAL_USER,
        CURRENT_TIMESTAMP(),

        NULL::VARCHAR,

        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()

    WHERE NOT EXISTS (
        SELECT 1
        FROM
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_POLICY_VERSION_SEAL_V1
        WHERE POLICY_SEAL_ID =
              :V_POLICY_SEAL_ID
    );

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS NOT IN (0, 1)) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Unexpected policy-seal insert count.'',
            ''inserted_rows'',
                V_INSERTED_ROWS
        );
    END IF;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_POLICY_VERSION_SEAL_V1
    SET
        SEAL_STATUS =
            ''SEALED'',
        IS_ACTIVE =
            TRUE,
        SUPERSEDED_BY_POLICY_SEAL_ID =
            NULL,
        UPDATED_AT =
            CURRENT_TIMESTAMP()
    WHERE POLICY_SEAL_ID =
          :V_POLICY_SEAL_ID
      AND POLICY_FINGERPRINT =
          :V_POLICY_FINGERPRINT;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',
        TRIM(:P_DEPLOYMENT_REQUEST_ID),

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        ''SUCCESS'',
        ''V4 activation completed and the activated policy version was sealed.'',

        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13B'',

        ''secure_entry_point'',
            ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',

        ''actual_user'', V_ACTUAL_USER,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID,

        ''deployment_request_id'',
            V_DEPLOYMENT_REQUEST_ID,
        ''request_evidence_version'',
            V_REQUEST_EVIDENCE_VERSION,

        ''runtime_authority_id'',
            V_RUNTIME_AUTHORITY_ID,

        ''model_domain'', V_MODEL_DOMAIN,
        ''deployment_mode'', V_AUTHORITY_MODE,

        ''policy_id'', V_POLICY_ID,
        ''policy_version'', V_POLICY_VERSION,
        ''policy_fingerprint'',
            V_POLICY_FINGERPRINT,

        ''policy_seal_id'',
            V_POLICY_SEAL_ID,
        ''policy_seal_status'',
            ''SEALED'',

        ''underlying_result'',
            V_V4_RESULT
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',

            ''secure_entry_point'',
                ''ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1'',

            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),

            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;

';

-- ============================================================
-- 12. CORRECTED TWO-PERSON OVERRIDE WORKFLOW
-- ============================================================

CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .SUBMIT_ML_DECISION_OVERRIDE_V2(
            P_OVERRIDE_ID VARCHAR,
            P_DECISION_ID VARCHAR,
            P_OVERRIDE_NUMERIC_VALUE FLOAT,
            P_OVERRIDE_TEXT_STATUS VARCHAR,
            P_OVERRIDE_REASON VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '

DECLARE
    V_ACTUAL_USER VARCHAR;

    V_OVERRIDE_COUNT NUMBER DEFAULT 0;
    V_DECISION_COUNT NUMBER DEFAULT 0;
    V_PENDING_COUNT NUMBER DEFAULT 0;

    V_ENTITY_ID VARCHAR;
    V_RFQ_ID VARCHAR;
    V_SIMULATION_ID VARCHAR;
    V_MODEL_DOMAIN VARCHAR;

    V_POLICY_ID VARCHAR;
    V_POLICY_VERSION VARCHAR;
    V_DEPLOYMENT_MODE VARCHAR;

    V_RULE_VALUE FLOAT;
    V_RECOMMENDED_ML_VALUE FLOAT;
    V_FINAL_NUMERIC_VALUE FLOAT;
    V_FINAL_TEXT_STATUS VARCHAR;

    V_FINAL_VALUE_MIN FLOAT;
    V_FINAL_VALUE_MAX FLOAT;

    V_AUDIT_EVENT_ID VARCHAR;
    V_SECURITY_AUDIT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
    V_INSERTED_ROWS NUMBER DEFAULT 0;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    IF (
        P_OVERRIDE_ID IS NULL
        OR LENGTH(TRIM(P_OVERRIDE_ID)) = 0
        OR P_DECISION_ID IS NULL
        OR LENGTH(TRIM(P_DECISION_ID)) = 0
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Override ID and decision ID are required.''
        );
    END IF;

    IF (
        P_OVERRIDE_REASON IS NULL
        OR LENGTH(TRIM(P_OVERRIDE_REASON)) < 10
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Override reason must contain at least 10 characters.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_OVERRIDE_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    WHERE OVERRIDE_ID =
          :P_OVERRIDE_ID;

    IF (V_OVERRIDE_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'', ''Override ID already exists.''
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_DECISION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_RESULT_V1
    WHERE DECISION_ID =
          :P_DECISION_ID;

    IF (V_DECISION_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one governed decision must exist.'',
            ''decision_count'', V_DECISION_COUNT
        );
    END IF;

    SELECT
        decision.ENTITY_ID,
        decision.RFQ_ID,
        decision.SIMULATION_ID,
        decision.MODEL_DOMAIN,

        decision.POLICY_ID,
        decision.POLICY_VERSION,
        decision.DEPLOYMENT_MODE,

        decision.RULE_VALUE::FLOAT,
        decision.RECOMMENDED_ML_VALUE::FLOAT,
        decision.FINAL_NUMERIC_VALUE::FLOAT,
        decision.FINAL_TEXT_STATUS,

        policy.FINAL_VALUE_MIN::FLOAT,
        policy.FINAL_VALUE_MAX::FLOAT

    INTO
        :V_ENTITY_ID,
        :V_RFQ_ID,
        :V_SIMULATION_ID,
        :V_MODEL_DOMAIN,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_DEPLOYMENT_MODE,

        :V_RULE_VALUE,
        :V_RECOMMENDED_ML_VALUE,
        :V_FINAL_NUMERIC_VALUE,
        :V_FINAL_TEXT_STATUS,

        :V_FINAL_VALUE_MIN,
        :V_FINAL_VALUE_MAX

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_RESULT_V1
            decision

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_POLICY_V1
            policy

        ON decision.POLICY_ID =
           policy.POLICY_ID

       AND decision.POLICY_VERSION =
           policy.POLICY_VERSION

    WHERE decision.DECISION_ID =
          :P_DECISION_ID;

    SELECT
        COALESCE(
            COUNT_IF(
                OVERRIDE_STATUS =
                    ''PENDING_REVIEW''
            ),
            0
        )::NUMBER
    INTO :V_PENDING_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    WHERE DECISION_ID =
          :P_DECISION_ID;

    IF (V_PENDING_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''A pending override already exists for this decision.''
        );
    END IF;

    IF (V_MODEL_DOMAIN = ''BMCS'') THEN
        IF (
            P_OVERRIDE_TEXT_STATUS IS NULL
            OR UPPER(TRIM(P_OVERRIDE_TEXT_STATUS))
               NOT IN (
                   ''AUTO_APPROVED'',
                   ''REVIEW_RECOMMENDED'',
                   ''REVIEW_REQUIRED''
               )
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''BMCS requires an allowed text review status.''
            );
        END IF;
    ELSE
        IF (P_OVERRIDE_NUMERIC_VALUE IS NULL) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Numeric override value is required for CSS, FMIS and TDS.''
            );
        END IF;

        IF (
            V_FINAL_VALUE_MIN IS NOT NULL
            AND P_OVERRIDE_NUMERIC_VALUE
                < V_FINAL_VALUE_MIN
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Override value is below the policy minimum.'',
                ''policy_minimum'',
                    V_FINAL_VALUE_MIN
            );
        END IF;

        IF (
            V_FINAL_VALUE_MAX IS NOT NULL
            AND P_OVERRIDE_NUMERIC_VALUE
                > V_FINAL_VALUE_MAX
        ) THEN
            RETURN OBJECT_CONSTRUCT(
                ''status'', ''ERROR'',
                ''message'',
                ''Override value is above the policy maximum.'',
                ''policy_maximum'',
                    V_FINAL_VALUE_MAX
            );
        END IF;
    END IF;

    V_AUDIT_EVENT_ID := UUID_STRING();
    V_SECURITY_AUDIT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1 (
                OVERRIDE_ID,
                DECISION_ID,

                ENTITY_ID,
                RFQ_ID,
                SIMULATION_ID,
                MODEL_DOMAIN,

                POLICY_ID,
                POLICY_VERSION,
                DEPLOYMENT_MODE,

                ORIGINAL_RULE_VALUE,
                ORIGINAL_RECOMMENDED_ML_VALUE,
                ORIGINAL_FINAL_NUMERIC_VALUE,
                ORIGINAL_FINAL_TEXT_STATUS,

                OVERRIDE_NUMERIC_VALUE,
                OVERRIDE_TEXT_STATUS,
                OVERRIDE_REASON,

                OVERRIDE_STATUS,
                REQUESTED_BY,
                REQUESTED_AT,

                REVIEWED_BY,
                REVIEWED_AT,
                REVIEW_ACTION,
                REVIEW_NOTE,

                OVERRIDE_APPLIED_TO_OFFICIAL_FLAG,

                CREATED_AT,
                UPDATED_AT
            )
    SELECT
        TRIM(:P_OVERRIDE_ID),
        TRIM(:P_DECISION_ID),

        :V_ENTITY_ID,
        :V_RFQ_ID,
        :V_SIMULATION_ID,
        :V_MODEL_DOMAIN,

        :V_POLICY_ID,
        :V_POLICY_VERSION,
        :V_DEPLOYMENT_MODE,

        :V_RULE_VALUE,
        :V_RECOMMENDED_ML_VALUE,
        :V_FINAL_NUMERIC_VALUE,
        :V_FINAL_TEXT_STATUS,

        :P_OVERRIDE_NUMERIC_VALUE,
        UPPER(TRIM(:P_OVERRIDE_TEXT_STATUS)),
        TRIM(:P_OVERRIDE_REASON),

        ''PENDING_REVIEW'',
        :V_ACTUAL_USER,
        CURRENT_TIMESTAMP(),

        NULL::VARCHAR,
        NULL::TIMESTAMP_NTZ,
        NULL::VARCHAR,
        NULL::VARCHAR,

        FALSE,

        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP();

    V_INSERTED_ROWS := SQLROWCOUNT;

    IF (V_INSERTED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Override request insert did not affect exactly one row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_AUDIT_V1 (
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,
                AUDIT_EVENT_ACTOR,
                AUDIT_EVENT_REASON,

                DECISION_ID,
                ENTITY_ID,
                RFQ_ID,
                SIMULATION_ID,
                MODEL_DOMAIN,

                POLICY_ID,
                POLICY_VERSION,
                DEPLOYMENT_MODE,
                DECISION_TYPE,

                MODEL_NAME,
                MODEL_VERSION,
                FEATURE_SET_VERSION,

                RULE_VALUE,
                RAW_ML_VALUE,
                RECOMMENDED_ML_VALUE,
                FINAL_NUMERIC_VALUE,

                OFFICIAL_TEXT_STATUS,
                FINAL_TEXT_STATUS,

                FEATURE_QUALITY_PASS_FLAG,
                MODEL_OOD_FLAG,
                MODEL_INFERENCE_SUCCESS_FLAG,
                ENGINEER_APPROVAL_FLAG,
                ESTIMATED_COST_IMPACT_PCT,

                ML_INPUT_STATUS,
                DECISION_STATUS,
                DECISION_SOURCE,
                FALLBACK_REASON,

                ML_VALUE_ACCEPTED_FLAG,
                EFFECTIVE_COST_IMPACT_ALLOWED_FLAG,
                EFFECTIVE_BUSINESS_DECISION_ALLOWED_FLAG,

                OVERRIDE_ID,
                OVERRIDE_NUMERIC_VALUE,
                OVERRIDE_TEXT_STATUS,
                OVERRIDE_STATUS,

                SOURCE_DECISION_CREATED_AT,
                SOURCE_DECISION_UPDATED_AT,
                AUDITED_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        ''OVERRIDE_REQUESTED_V2'',
        :V_ACTUAL_USER,
        TRIM(:P_OVERRIDE_REASON),

        decision.DECISION_ID,
        decision.ENTITY_ID,
        decision.RFQ_ID,
        decision.SIMULATION_ID,
        decision.MODEL_DOMAIN,

        decision.POLICY_ID,
        decision.POLICY_VERSION,
        decision.DEPLOYMENT_MODE,
        decision.DECISION_TYPE,

        decision.MODEL_NAME,
        decision.MODEL_VERSION,
        decision.FEATURE_SET_VERSION,

        decision.RULE_VALUE::FLOAT,
        decision.RAW_ML_VALUE::FLOAT,
        decision.RECOMMENDED_ML_VALUE::FLOAT,
        decision.FINAL_NUMERIC_VALUE::FLOAT,

        decision.OFFICIAL_TEXT_STATUS,
        decision.FINAL_TEXT_STATUS,

        decision.FEATURE_QUALITY_PASS_FLAG,
        decision.MODEL_OOD_FLAG,
        decision.MODEL_INFERENCE_SUCCESS_FLAG,
        decision.ENGINEER_APPROVAL_FLAG,
        decision.ESTIMATED_COST_IMPACT_PCT::FLOAT,

        decision.ML_INPUT_STATUS,
        decision.DECISION_STATUS,
        decision.DECISION_SOURCE,
        decision.FALLBACK_REASON,

        decision.ML_VALUE_ACCEPTED_FLAG,
        decision.EFFECTIVE_COST_IMPACT_ALLOWED_FLAG,
        decision.EFFECTIVE_BUSINESS_DECISION_ALLOWED_FLAG,

        TRIM(:P_OVERRIDE_ID),
        :P_OVERRIDE_NUMERIC_VALUE,
        UPPER(TRIM(:P_OVERRIDE_TEXT_STATUS)),
        ''PENDING_REVIEW'',

        decision.CREATED_AT,
        decision.UPDATED_AT,
        CURRENT_TIMESTAMP()

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_RESULT_V1
            decision

    WHERE decision.DECISION_ID =
          :P_DECISION_ID;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''SUBMIT_ML_DECISION_OVERRIDE_V2'',
        TRIM(:P_OVERRIDE_ID),

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        ''SUCCESS'',
        ''Override request recorded without superseding the current approved override.'',

        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13B'',

        ''override_id'', P_OVERRIDE_ID,
        ''decision_id'', P_DECISION_ID,
        ''model_domain'', V_MODEL_DOMAIN,

        ''override_status'',
            ''PENDING_REVIEW'',

        ''actual_requester'',
            V_ACTUAL_USER,

        ''approved_override_preserved'',
            TRUE,

        ''official_value_changed'',
            FALSE,

        ''audit_event_id'',
            V_AUDIT_EVENT_ID,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',
            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;

';


CREATE OR REPLACE SECURE PROCEDURE
    KMAT_COST_MODEL_DB.CORE_ML
        .REVIEW_ML_DECISION_OVERRIDE_V2(
            P_OVERRIDE_ID VARCHAR,
            P_REVIEW_ACTION VARCHAR,
            P_REVIEW_NOTE VARCHAR
        )
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS '

DECLARE
    V_ACTUAL_USER VARCHAR;

    V_OVERRIDE_COUNT NUMBER DEFAULT 0;

    V_DECISION_ID VARCHAR;
    V_REQUESTED_BY VARCHAR;

    V_OVERRIDE_NUMERIC_VALUE FLOAT;
    V_OVERRIDE_TEXT_STATUS VARCHAR;

    V_REVIEW_ACTION VARCHAR;
    V_NEW_STATUS VARCHAR;
    V_AUDIT_EVENT_TYPE VARCHAR;

    V_SUPERSEDED_APPROVED_COUNT NUMBER DEFAULT 0;
    V_UPDATED_ROWS NUMBER DEFAULT 0;

    V_AUDIT_EVENT_ID VARCHAR;
    V_SECURITY_AUDIT_ID VARCHAR;

    V_TRANSACTION_STARTED BOOLEAN DEFAULT FALSE;
BEGIN
    V_ACTUAL_USER := CURRENT_USER();

    IF (
        P_OVERRIDE_ID IS NULL
        OR LENGTH(TRIM(P_OVERRIDE_ID)) = 0
        OR P_REVIEW_ACTION IS NULL
        OR UPPER(TRIM(P_REVIEW_ACTION))
            NOT IN (
                ''APPROVE'',
                ''REJECT''
            )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Override ID and APPROVE or REJECT action are required.''
        );
    END IF;

    IF (
        P_REVIEW_NOTE IS NULL
        OR LENGTH(TRIM(P_REVIEW_NOTE)) < 5
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Review note must contain at least 5 characters.''
        );
    END IF;

    SELECT
        COUNT(*),

        MAX(DECISION_ID),
        MAX(REQUESTED_BY),

        MAX(OVERRIDE_NUMERIC_VALUE::FLOAT),
        MAX(OVERRIDE_TEXT_STATUS)

    INTO
        :V_OVERRIDE_COUNT,

        :V_DECISION_ID,
        :V_REQUESTED_BY,

        :V_OVERRIDE_NUMERIC_VALUE,
        :V_OVERRIDE_TEXT_STATUS

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1

    WHERE OVERRIDE_ID =
          :P_OVERRIDE_ID
      AND OVERRIDE_STATUS =
          ''PENDING_REVIEW'';

    IF (V_OVERRIDE_COUNT <> 1) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Exactly one pending override must exist.'',
            ''override_count'',
                V_OVERRIDE_COUNT
        );
    END IF;

    IF (
        UPPER(TRIM(V_ACTUAL_USER))
        = UPPER(TRIM(V_REQUESTED_BY))
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Requester and reviewer must be different Snowflake users.''
        );
    END IF;

    V_REVIEW_ACTION :=
        UPPER(TRIM(P_REVIEW_ACTION));

    IF (V_REVIEW_ACTION = ''APPROVE'') THEN
        V_NEW_STATUS :=
            ''APPROVED_NOT_APPLIED'';
        V_AUDIT_EVENT_TYPE :=
            ''OVERRIDE_APPROVED_V2'';
    ELSE
        V_NEW_STATUS :=
            ''REJECTED'';
        V_AUDIT_EVENT_TYPE :=
            ''OVERRIDE_REJECTED_V2'';
    END IF;

    V_AUDIT_EVENT_ID := UUID_STRING();
    V_SECURITY_AUDIT_ID := UUID_STRING();

    BEGIN TRANSACTION;
    V_TRANSACTION_STARTED := TRUE;

    IF (V_REVIEW_ACTION = ''APPROVE'') THEN
        UPDATE
            KMAT_COST_MODEL_DB.CORE_ML
                .ML_DECISION_OVERRIDE_V1
        SET
            OVERRIDE_STATUS =
                ''SUPERSEDED'',
            UPDATED_AT =
                CURRENT_TIMESTAMP()
        WHERE DECISION_ID =
              :V_DECISION_ID
          AND OVERRIDE_ID
              <> :P_OVERRIDE_ID
          AND OVERRIDE_STATUS =
              ''APPROVED_NOT_APPLIED'';

        V_SUPERSEDED_APPROVED_COUNT :=
            SQLROWCOUNT;
    END IF;

    UPDATE
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    SET
        OVERRIDE_STATUS =
            :V_NEW_STATUS,

        REVIEWED_BY =
            :V_ACTUAL_USER,
        REVIEWED_AT =
            CURRENT_TIMESTAMP(),

        REVIEW_ACTION =
            :V_REVIEW_ACTION,
        REVIEW_NOTE =
            TRIM(:P_REVIEW_NOTE),

        OVERRIDE_APPLIED_TO_OFFICIAL_FLAG =
            FALSE,

        UPDATED_AT =
            CURRENT_TIMESTAMP()

    WHERE OVERRIDE_ID =
          :P_OVERRIDE_ID
      AND OVERRIDE_STATUS =
          ''PENDING_REVIEW'';

    V_UPDATED_ROWS := SQLROWCOUNT;

    IF (V_UPDATED_ROWS <> 1) THEN
        ROLLBACK;
        V_TRANSACTION_STARTED := FALSE;

        RETURN OBJECT_CONSTRUCT(
            ''status'', ''ERROR'',
            ''message'',
            ''Override review did not update exactly one pending row.''
        );
    END IF;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_AUDIT_V1 (
                AUDIT_EVENT_ID,
                AUDIT_EVENT_TYPE,
                AUDIT_EVENT_ACTOR,
                AUDIT_EVENT_REASON,

                DECISION_ID,
                ENTITY_ID,
                RFQ_ID,
                SIMULATION_ID,
                MODEL_DOMAIN,

                POLICY_ID,
                POLICY_VERSION,
                DEPLOYMENT_MODE,
                DECISION_TYPE,

                MODEL_NAME,
                MODEL_VERSION,
                FEATURE_SET_VERSION,

                RULE_VALUE,
                RAW_ML_VALUE,
                RECOMMENDED_ML_VALUE,
                FINAL_NUMERIC_VALUE,

                OFFICIAL_TEXT_STATUS,
                FINAL_TEXT_STATUS,

                FEATURE_QUALITY_PASS_FLAG,
                MODEL_OOD_FLAG,
                MODEL_INFERENCE_SUCCESS_FLAG,
                ENGINEER_APPROVAL_FLAG,
                ESTIMATED_COST_IMPACT_PCT,

                ML_INPUT_STATUS,
                DECISION_STATUS,
                DECISION_SOURCE,
                FALLBACK_REASON,

                ML_VALUE_ACCEPTED_FLAG,
                EFFECTIVE_COST_IMPACT_ALLOWED_FLAG,
                EFFECTIVE_BUSINESS_DECISION_ALLOWED_FLAG,

                OVERRIDE_ID,
                OVERRIDE_NUMERIC_VALUE,
                OVERRIDE_TEXT_STATUS,
                OVERRIDE_STATUS,

                SOURCE_DECISION_CREATED_AT,
                SOURCE_DECISION_UPDATED_AT,
                AUDITED_AT
            )
    SELECT
        :V_AUDIT_EVENT_ID,
        :V_AUDIT_EVENT_TYPE,
        :V_ACTUAL_USER,
        TRIM(:P_REVIEW_NOTE),

        decision.DECISION_ID,
        decision.ENTITY_ID,
        decision.RFQ_ID,
        decision.SIMULATION_ID,
        decision.MODEL_DOMAIN,

        decision.POLICY_ID,
        decision.POLICY_VERSION,
        decision.DEPLOYMENT_MODE,
        decision.DECISION_TYPE,

        decision.MODEL_NAME,
        decision.MODEL_VERSION,
        decision.FEATURE_SET_VERSION,

        decision.RULE_VALUE::FLOAT,
        decision.RAW_ML_VALUE::FLOAT,
        decision.RECOMMENDED_ML_VALUE::FLOAT,
        decision.FINAL_NUMERIC_VALUE::FLOAT,

        decision.OFFICIAL_TEXT_STATUS,
        decision.FINAL_TEXT_STATUS,

        decision.FEATURE_QUALITY_PASS_FLAG,
        decision.MODEL_OOD_FLAG,
        decision.MODEL_INFERENCE_SUCCESS_FLAG,
        decision.ENGINEER_APPROVAL_FLAG,
        decision.ESTIMATED_COST_IMPACT_PCT::FLOAT,

        decision.ML_INPUT_STATUS,
        decision.DECISION_STATUS,
        decision.DECISION_SOURCE,
        decision.FALLBACK_REASON,

        decision.ML_VALUE_ACCEPTED_FLAG,
        decision.EFFECTIVE_COST_IMPACT_ALLOWED_FLAG,
        decision.EFFECTIVE_BUSINESS_DECISION_ALLOWED_FLAG,

        override_record.OVERRIDE_ID,
        override_record.OVERRIDE_NUMERIC_VALUE::FLOAT,
        override_record.OVERRIDE_TEXT_STATUS,
        :V_NEW_STATUS,

        decision.CREATED_AT,
        decision.UPDATED_AT,
        CURRENT_TIMESTAMP()

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_RESULT_V1
            decision

    INNER JOIN
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
            override_record

        ON decision.DECISION_ID =
           override_record.DECISION_ID

    WHERE override_record.OVERRIDE_ID =
          :P_OVERRIDE_ID;

    INSERT INTO
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_CALL_AUDIT_V1 (
                SECURITY_AUDIT_ID,

                OPERATION_NAME,
                TARGET_OBJECT_ID,

                ACTUAL_USER,
                SESSION_ID,

                RESULT_STATUS,
                RESULT_MESSAGE,

                RECORDED_AT
            )
    SELECT
        :V_SECURITY_AUDIT_ID,

        ''REVIEW_ML_DECISION_OVERRIDE_V2'',
        TRIM(:P_OVERRIDE_ID),

        :V_ACTUAL_USER,
        CURRENT_SESSION(),

        ''SUCCESS'',
        IFF(
            :V_REVIEW_ACTION = ''APPROVE'',
            ''Replacement override approved and the prior approved override was superseded atomically.'',
            ''Override rejected; any prior approved override remains effective.''
        ),

        CURRENT_TIMESTAMP();

    COMMIT;
    V_TRANSACTION_STARTED := FALSE;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        ''status'', ''SUCCESS'',
        ''phase'', ''PHASE_13B'',

        ''override_id'', P_OVERRIDE_ID,
        ''decision_id'', V_DECISION_ID,

        ''review_action'',
            V_REVIEW_ACTION,
        ''override_status'',
            V_NEW_STATUS,

        ''actual_reviewer'',
            V_ACTUAL_USER,

        ''superseded_prior_approved_count'',
            V_SUPERSEDED_APPROVED_COUNT,

        ''override_numeric_value'',
            V_OVERRIDE_NUMERIC_VALUE,
        ''override_text_status'',
            V_OVERRIDE_TEXT_STATUS,

        ''official_value_changed'',
            FALSE,
        ''override_applied_to_official'',
            FALSE,

        ''audit_event_id'',
            V_AUDIT_EVENT_ID,
        ''security_audit_id'',
            V_SECURITY_AUDIT_ID
    );

EXCEPTION
    WHEN OTHER THEN
        IF (V_TRANSACTION_STARTED) THEN
            ROLLBACK;
        END IF;

        RETURN OBJECT_CONSTRUCT_KEEP_NULL(
            ''status'', ''ERROR'',
            ''phase'', ''PHASE_13B'',
            ''actual_user'',
                COALESCE(
                    V_ACTUAL_USER,
                    CURRENT_USER()
                ),
            ''sqlcode'', SQLCODE,
            ''sqlerrm'', SQLERRM,
            ''sqlstate'', SQLSTATE
        );
END;

';

-- ============================================================
-- 13. GRANT COMPLIANCE AND BYPASS-DETECTION VIEWS
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_EXPECTED_GRANT_STATUS_V1
AS
SELECT
    expected.EXPECTATION_ID,

    expected.GRANTEE_ROLE,

    expected.GRANTED_ON,
    expected.OBJECT_NAME,
    expected.PRIVILEGE,

    expected.REQUIRED_FLAG,
    expected.COMMENTS,

    snapshot.SNAPSHOT_ID,
    snapshot.CAPTURED_AT,

    IFF(
        snapshot.GRANTEE_NAME IS NOT NULL,
        TRUE,
        FALSE
    ) AS GRANT_PRESENT_FLAG,

    IFF(
        expected.REQUIRED_FLAG = TRUE
        AND snapshot.GRANTEE_NAME IS NULL,
        TRUE,
        FALSE
    ) AS MISSING_REQUIRED_GRANT_FLAG

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_EXPECTED_GRANT_V1
        expected

LEFT JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
        snapshot

    ON expected.GRANTEE_ROLE =
       snapshot.GRANTEE_NAME

   AND expected.GRANTED_ON =
       snapshot.GRANTED_ON

   AND expected.OBJECT_NAME =
       snapshot.OBJECT_NAME

   AND expected.PRIVILEGE =
       snapshot.PRIVILEGE

WHERE expected.POLICY_STATUS = 'ACTIVE';


CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_BYPASS_GRANT_VIOLATION_V1
AS
WITH SENSITIVE_KEY AS (
    SELECT DISTINCT
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        ACCESS_CLASS
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_SENSITIVE_OBJECT_V1
    WHERE POLICY_STATUS = 'ACTIVE'
),
ALLOWED AS (
    SELECT DISTINCT
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        ALLOWED_GRANTEE_ROLE
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_SENSITIVE_OBJECT_V1
    WHERE POLICY_STATUS = 'ACTIVE'
      AND ALLOWED_GRANTEE_ROLE
          <> '__NO_DIRECT_GRANTEE__'
)
SELECT
    snapshot.SNAPSHOT_ID,
    snapshot.CAPTURED_AT,

    sensitive.ACCESS_CLASS,

    snapshot.GRANTED_ON,
    snapshot.OBJECT_NAME,
    snapshot.PRIVILEGE,

    snapshot.GRANTEE_NAME,
    snapshot.GRANT_OPTION,
    snapshot.GRANTED_BY,

    'GRANTEE_NOT_ALLOWED_FOR_SENSITIVE_OBJECT'
        AS VIOLATION_REASON

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
        snapshot

INNER JOIN SENSITIVE_KEY sensitive
    ON snapshot.GRANTED_ON =
       sensitive.GRANTED_ON

   AND snapshot.OBJECT_NAME =
       sensitive.OBJECT_NAME

   AND snapshot.PRIVILEGE =
       sensitive.PRIVILEGE

LEFT JOIN ALLOWED allowed
    ON snapshot.GRANTED_ON =
       allowed.GRANTED_ON

   AND snapshot.OBJECT_NAME =
       allowed.OBJECT_NAME

   AND snapshot.PRIVILEGE =
       allowed.PRIVILEGE

   AND snapshot.GRANTEE_NAME =
       allowed.ALLOWED_GRANTEE_ROLE

WHERE allowed.ALLOWED_GRANTEE_ROLE IS NULL;


CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_FUNCTIONAL_ROLE_DML_VIOLATION_V1
AS
SELECT
    snapshot.SNAPSHOT_ID,
    snapshot.CAPTURED_AT,

    snapshot.GRANTEE_NAME,
    role_policy.ROLE_CLASS,

    snapshot.GRANTED_ON,
    snapshot.OBJECT_NAME,
    snapshot.PRIVILEGE,

    snapshot.GRANTED_BY,

    'FUNCTIONAL_ROLE_HAS_DIRECT_TABLE_DML'
        AS VIOLATION_REASON

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
        snapshot

INNER JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_ROLE_POLICY_V1
        role_policy

    ON snapshot.GRANTEE_NAME =
       role_policy.ROLE_NAME

WHERE role_policy.POLICY_STATUS = 'ACTIVE'
  AND role_policy.DIRECT_TABLE_DML_ALLOWED_FLAG =
      FALSE
  AND snapshot.GRANTED_ON = 'TABLE'
  AND snapshot.PRIVILEGE IN (
      'INSERT',
      'UPDATE',
      'DELETE',
      'TRUNCATE'
  );


CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_APPEND_ONLY_VIOLATION_V1
AS
SELECT
    snapshot.SNAPSHOT_ID,
    snapshot.CAPTURED_AT,

    snapshot.OBJECT_NAME,
    snapshot.PRIVILEGE,
    snapshot.GRANTEE_NAME,
    snapshot.GRANTED_BY,

    CASE
        WHEN snapshot.PRIVILEGE IN (
            'UPDATE',
            'DELETE',
            'TRUNCATE'
        )
            THEN 'APPEND_ONLY_TABLE_HAS_MUTATION_GRANT'

        WHEN snapshot.PRIVILEGE = 'INSERT'
         AND snapshot.GRANTEE_NAME
             <> policy.ALLOWED_INSERT_ROLE
            THEN 'APPEND_ONLY_INSERT_GRANTED_TO_UNAPPROVED_ROLE'

        ELSE 'APPEND_ONLY_GRANT_VIOLATION'
    END AS VIOLATION_REASON

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
        snapshot

INNER JOIN
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_APPEND_ONLY_OBJECT_POLICY_V1
        policy

    ON snapshot.OBJECT_NAME =
       policy.OBJECT_NAME

WHERE policy.POLICY_STATUS = 'ACTIVE'
  AND snapshot.GRANTED_ON = 'TABLE'
  AND (
      snapshot.PRIVILEGE IN (
          'UPDATE',
          'DELETE',
          'TRUNCATE'
      )
      OR (
          snapshot.PRIVILEGE = 'INSERT'
          AND snapshot.GRANTEE_NAME
              <> policy.ALLOWED_INSERT_ROLE
      )
  );


-- ============================================================
-- 14. OVERRIDE AND POLICY-INTEGRITY DIAGNOSTICS
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_OVERRIDE_PRECEDENCE_INTEGRITY_V1
AS
WITH APPROVED_COUNT AS (
    SELECT
        DECISION_ID,
        COUNT(*)::NUMBER
            AS APPROVED_OVERRIDE_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_DECISION_OVERRIDE_V1
    WHERE OVERRIDE_STATUS =
          'APPROVED_NOT_APPLIED'
      AND COALESCE(
          OVERRIDE_APPLIED_TO_OFFICIAL_FLAG,
          FALSE
      ) = FALSE
    GROUP BY DECISION_ID
)
SELECT
    decision.DECISION_ID,

    COALESCE(
        approved_count.APPROVED_OVERRIDE_COUNT,
        0
    )::NUMBER AS APPROVED_OVERRIDE_COUNT,

    decision.EFFECTIVE_APPROVED_OVERRIDE_ID,

    decision.LATEST_OVERRIDE_ID,
    decision.LATEST_OVERRIDE_STATUS,

    decision
        .APPROVED_OVERRIDE_PRESERVED_UNDER_NEWER_REQUEST_FLAG,

    IFF(
        COALESCE(
            approved_count.APPROVED_OVERRIDE_COUNT,
            0
        ) > 1,
        TRUE,
        FALSE
    ) AS DUPLICATE_APPROVED_OVERRIDE_FLAG,

    IFF(
        COALESCE(
            approved_count.APPROVED_OVERRIDE_COUNT,
            0
        ) = 1
        AND decision.EFFECTIVE_APPROVED_OVERRIDE_ID
            IS NULL,
        TRUE,
        FALSE
    ) AS APPROVED_OVERRIDE_HIDDEN_FLAG,

    IFF(
        COALESCE(
            approved_count.APPROVED_OVERRIDE_COUNT,
            0
        ) <= 1
        AND NOT (
            COALESCE(
                approved_count.APPROVED_OVERRIDE_COUNT,
                0
            ) = 1
            AND decision.EFFECTIVE_APPROVED_OVERRIDE_ID
                IS NULL
        ),
        'PASS',
        'FAILED'
    ) AS PRECEDENCE_INTEGRITY_STATUS

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2
        decision

LEFT JOIN APPROVED_COUNT approved_count
    ON decision.DECISION_ID =
       approved_count.DECISION_ID;


-- ============================================================
-- 15. PHASE 13B SECURITY DASHBOARD
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1
AS
WITH SNAPSHOT AS (
    SELECT
        MAX(SNAPSHOT_ID) AS SNAPSHOT_ID,
        MAX(CAPTURED_AT) AS SNAPSHOT_CAPTURED_AT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
),
EXPECTED AS (
    SELECT
        COUNT(*)::NUMBER
            AS EXPECTED_GRANT_COUNT,

        COALESCE(
            COUNT_IF(
                MISSING_REQUIRED_GRANT_FLAG = TRUE
            ),
            0
        )::NUMBER AS MISSING_REQUIRED_GRANT_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_EXPECTED_GRANT_STATUS_V1
),
BYPASS AS (
    SELECT COUNT(*)::NUMBER
        AS BYPASS_GRANT_VIOLATION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_BYPASS_GRANT_VIOLATION_V1
),
FUNCTIONAL_DML AS (
    SELECT COUNT(*)::NUMBER
        AS FUNCTIONAL_ROLE_DML_VIOLATION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_FUNCTIONAL_ROLE_DML_VIOLATION_V1
),
APPEND_ONLY AS (
    SELECT COUNT(*)::NUMBER
        AS APPEND_ONLY_VIOLATION_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_APPEND_ONLY_VIOLATION_V1
),
SEALS AS (
    SELECT
        COALESCE(
            COUNT_IF(
                ACTIVE_SEAL_PRESENT_FLAG = TRUE
            ),
            0
        )::NUMBER AS ACTIVE_POLICY_SEAL_COUNT,

        COALESCE(
            COUNT_IF(
                ACTIVE_SEAL_PRESENT_FLAG = TRUE
                AND POLICY_SEAL_MATCH_FLAG = FALSE
            ),
            0
        )::NUMBER AS POLICY_SEAL_MISMATCH_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1
),
OVERRIDES AS (
    SELECT
        COALESCE(
            COUNT_IF(
                DUPLICATE_APPROVED_OVERRIDE_FLAG = TRUE
                OR APPROVED_OVERRIDE_HIDDEN_FLAG = TRUE
            ),
            0
        )::NUMBER AS OVERRIDE_PRECEDENCE_VIOLATION_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_OVERRIDE_PRECEDENCE_INTEGRITY_V1
),
ROLES AS (
    SELECT
        COUNT(*)::NUMBER
            AS GOVERNED_ROLE_POLICY_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_ROLE_POLICY_V1
    WHERE POLICY_STATUS = 'ACTIVE'
)
SELECT
    snapshot.SNAPSHOT_ID,
    snapshot.SNAPSHOT_CAPTURED_AT,

    roles.GOVERNED_ROLE_POLICY_COUNT,

    expected.EXPECTED_GRANT_COUNT,
    expected.MISSING_REQUIRED_GRANT_COUNT,

    bypass.BYPASS_GRANT_VIOLATION_COUNT,
    functional_dml
        .FUNCTIONAL_ROLE_DML_VIOLATION_COUNT,
    append_only.APPEND_ONLY_VIOLATION_COUNT,

    seals.ACTIVE_POLICY_SEAL_COUNT,
    seals.POLICY_SEAL_MISMATCH_COUNT,

    overrides
        .OVERRIDE_PRECEDENCE_VIOLATION_COUNT,

    CASE
        WHEN snapshot.SNAPSHOT_ID IS NULL
            THEN 'PENDING_GRANT_SNAPSHOT'

        WHEN expected.MISSING_REQUIRED_GRANT_COUNT > 0
          OR bypass.BYPASS_GRANT_VIOLATION_COUNT > 0
          OR functional_dml
                .FUNCTIONAL_ROLE_DML_VIOLATION_COUNT > 0
          OR append_only.APPEND_ONLY_VIOLATION_COUNT > 0
          OR seals.POLICY_SEAL_MISMATCH_COUNT > 0
          OR overrides
                .OVERRIDE_PRECEDENCE_VIOLATION_COUNT > 0
            THEN 'ATTENTION_REQUIRED'

        ELSE 'COMPLIANT'
    END AS SECURITY_CONTROL_STATUS,

    FALSE AS OFFICIAL_COST_CHANGED_FLAG,
    FALSE AS POLICY_ACTIVATED_FLAG

FROM SNAPSHOT snapshot
CROSS JOIN EXPECTED expected
CROSS JOIN BYPASS bypass
CROSS JOIN FUNCTIONAL_DML functional_dml
CROSS JOIN APPEND_ONLY append_only
CROSS JOIN SEALS seals
CROSS JOIN OVERRIDES overrides
CROSS JOIN ROLES roles;


-- ============================================================
-- 16. PROTECTED-TABLE DML ALLOW-LIST
-- ============================================================

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_SENSITIVE_OBJECT_V1 target
USING (
    SELECT *
    FROM VALUES
        ('TABLE_DML::ML_DECISION_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_OVERRIDE_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_DECISION_OVERRIDE_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'UPDATE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_DECISION_OVERRIDE_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_OVERRIDE_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_DECISION_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DECISION_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_CAPABILITY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_CAPABILITY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_CAPABILITY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_CAPABILITY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_GATE_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_GATE_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_GATE_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_GATE_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_REQUEST_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_REQUEST_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_REQUEST_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_REQUEST_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_APPROVAL_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_EVENT_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_EVENT_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_EVENT_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_DEPLOYMENT_EVENT_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_PREDICTION_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_PREDICTION_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_PREDICTION_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_PREDICTION_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_DETAIL_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_DETAIL_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_DETAIL_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_DETAIL_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_RUN_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_RUN_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_RUN_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_CANDIDATE_BACKTEST_RUN_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_PLAN_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_PLAN_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_PLAN_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_PLAN_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_SCOPE_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_SCOPE_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_SCOPE_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_SCOPE_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_CAPACITY_COUNTER_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_CAPACITY_COUNTER_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_CAPACITY_COUNTER_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_CAPACITY_COUNTER_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_ASSIGNMENT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_ASSIGNMENT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_ASSIGNMENT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_ASSIGNMENT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_DECISION_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_DECISION_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_DECISION_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_DECISION_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_INCIDENT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_INCIDENT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_INCIDENT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_INCIDENT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_MONITORING_RUN_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_MONITORING_RUN_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_MONITORING_RUN_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_MONITORING_RUN_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EVENT_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EVENT_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EVENT_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EVENT_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_REQUEST_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_REQUEST_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_REQUEST_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_REQUEST_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_ASSESSMENT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_ASSESSMENT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_ASSESSMENT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_ASSESSMENT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_SIGNOFF_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PRODUCTION_PROMOTION_LINK_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PRODUCTION_PROMOTION_LINK_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PRODUCTION_PROMOTION_LINK_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PRODUCTION_PROMOTION_LINK_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_EVENT_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_EVENT_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_EVENT_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_PILOT_EXIT_EVENT_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_REGISTRY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_REGISTRY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_REGISTRY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_REGISTRY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_KILL_SWITCH_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_KILL_SWITCH_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_KILL_SWITCH_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_KILL_SWITCH_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_COUNTER_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_COUNTER_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_COUNTER_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_COUNTER_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_DECISION_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_DECISION_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_DECISION_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_DECISION_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_MONITOR_RUN_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_MONITOR_RUN_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_MONITOR_RUN_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_SAFETY_MONITOR_RUN_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_ACTUAL_OUTCOME_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_ACTUAL_OUTCOME_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_ACTUAL_OUTCOME_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_ACTUAL_OUTCOME_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_GOVERNED_COST_INPUT_AUDIT_V2::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_GOVERNED_COST_INPUT_AUDIT_V2::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_GOVERNED_COST_INPUT_AUDIT_V2::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_GOVERNED_COST_INPUT_AUDIT_V2::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_ROLE_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_ROLE_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_ROLE_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_ROLE_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_EXPECTED_GRANT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_EXPECTED_GRANT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_EXPECTED_GRANT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_EXPECTED_GRANT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_SENSITIVE_OBJECT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_SENSITIVE_OBJECT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_SENSITIVE_OBJECT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_SENSITIVE_OBJECT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_APPEND_ONLY_OBJECT_POLICY_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_APPEND_ONLY_OBJECT_POLICY_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_APPEND_ONLY_OBJECT_POLICY_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_APPEND_ONLY_OBJECT_POLICY_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_GRANT_SNAPSHOT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1', 'INSERT', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_GRANT_SNAPSHOT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_GRANT_SNAPSHOT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_GRANT_SNAPSHOT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_POLICY_VERSION_SEAL_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_POLICY_VERSION_SEAL_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'UPDATE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_POLICY_VERSION_SEAL_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_POLICY_VERSION_SEAL_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_CALL_AUDIT_V1::INSERT', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROTECTED_TABLE_DML', 'ACTIVE', 'Only the non-login executor may receive this specific DML privilege.'),
        ('TABLE_DML::ML_SECURITY_CALL_AUDIT_V1::UPDATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'UPDATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_CALL_AUDIT_V1::DELETE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'DELETE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.'),
        ('TABLE_DML::ML_SECURITY_CALL_AUDIT_V1::TRUNCATE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'TRUNCATE', '__NO_DIRECT_GRANTEE__', 'PROTECTED_TABLE_DML', 'ACTIVE', 'No direct grant is allowed for this DML privilege.')
    AS seed(
        POLICY_ROW_ID,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        ALLOWED_GRANTEE_ROLE,
        ACCESS_CLASS,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.POLICY_ROW_ID =
   source.POLICY_ROW_ID
WHEN NOT MATCHED THEN INSERT (
    POLICY_ROW_ID,

    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,

    ALLOWED_GRANTEE_ROLE,
    ACCESS_CLASS,

    POLICY_STATUS,
    COMMENTS,

    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.POLICY_ROW_ID,

    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,

    source.ALLOWED_GRANTEE_ROLE,
    source.ACCESS_CLASS,

    source.POLICY_STATUS,
    source.COMMENTS,

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


-- ============================================================
-- 17. EXECUTOR AND VIEW-OWNER REQUIRED GRANTS
-- ============================================================

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_EXPECTED_GRANT_V1 target
USING (
    SELECT *
    FROM VALUES
        ('EXECUTOR_PROC_USAGE::SET_ML_DEPLOYMENT_CAPABILITY_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::CREATE_ML_POLICY_CANDIDATE_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::SUBMIT_ML_DEPLOYMENT_REQUEST_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::REFRESH_ML_DEPLOYMENT_REQUEST_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::REVIEW_ML_DEPLOYMENT_REQUEST_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::ROLLBACK_ML_DEPLOYMENT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::CANCEL_ML_DEPLOYMENT_REQUEST_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::RECORD_ML_CANDIDATE_PREDICTION_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::RUN_ML_CANDIDATE_BACKTEST_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::ACTIVATE_APPROVED_ML_DEPLOYMENT_V4', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::ENABLE_ML_RUNTIME_AUTHORITY_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::SET_ML_RUNTIME_KILL_SWITCH_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::RESOLVE_ML_RUNTIME_AUTHORITY_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::RUN_ML_RUNTIME_SAFETY_MONITOR_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::SUSPEND_ML_RUNTIME_AUTHORITY_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::REVOKE_ML_RUNTIME_AUTHORITY_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_PROC_USAGE::CAPTURE_ML_DECISION_AUDIT_V1', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'PROCEDURE', 'KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR)', 'USAGE', TRUE, 'ACTIVE', 'Required underlying procedure access for a secure owner-rights wrapper.'),
        ('EXECUTOR_TABLE::ML_DECISION_POLICY_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_RESULT_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_RESULT_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_OVERRIDE_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_OVERRIDE_V1::INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'INSERT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_OVERRIDE_V1::UPDATE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1', 'UPDATE', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_AUDIT_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_DECISION_AUDIT_V1::INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1', 'INSERT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_RUNTIME_AUTHORITY_REGISTRY_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_POLICY_VERSION_SEAL_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_POLICY_VERSION_SEAL_V1::INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'INSERT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_POLICY_VERSION_SEAL_V1::UPDATE', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1', 'UPDATE', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_SECURITY_CALL_AUDIT_V1::SELECT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'SELECT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('EXECUTOR_TABLE::ML_SECURITY_CALL_AUDIT_V1::INSERT', 'KMAT_GOVERNANCE_EXECUTOR_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1', 'INSERT', TRUE, 'ACTIVE', 'Minimum direct object privilege required by the non-login secure procedure owner.'),
        ('DATA_OWNER_SELECT::ML_DECISION_RESULT_V1', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'TABLE', 'KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_RESULT_V1', 'SELECT', TRUE, 'ACTIVE', 'Required by the secure approved-override view.'),
        ('DATA_OWNER_SELECT::VW_ML_POLICY_RUNTIME_FINGERPRINT_V1', 'KMAT_GOVERNANCE_DATA_OWNER_ROLE', 'VIEW', 'KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_RUNTIME_FINGERPRINT_V1', 'SELECT', TRUE, 'ACTIVE', 'Required by the secure policy-seal integrity view.')
    AS seed(
        EXPECTATION_ID,
        GRANTEE_ROLE,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        REQUIRED_FLAG,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.EXPECTATION_ID =
   source.EXPECTATION_ID
WHEN NOT MATCHED THEN INSERT (
    EXPECTATION_ID,

    GRANTEE_ROLE,

    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,

    REQUIRED_FLAG,
    POLICY_STATUS,

    COMMENTS,

    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.EXPECTATION_ID,

    source.GRANTEE_ROLE,

    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,

    source.REQUIRED_FLAG,
    source.POLICY_STATUS,

    source.COMMENTS,

    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


-- ============================================================
-- 18. SECURITYADMIN SNAPSHOT-CAPTURE EXCEPTION
-- ============================================================

MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_EXPECTED_GRANT_V1 target
USING (
    SELECT *
    FROM VALUES
        (
            'SECURITYADMIN_SNAPSHOT_SELECT',
            'SECURITYADMIN',
            'TABLE',
            'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1',
            'SELECT',
            TRUE,
            'ACTIVE',
            'Required only to capture and verify immediate SHOW GRANTS snapshots.'
        ),
        (
            'SECURITYADMIN_SNAPSHOT_INSERT',
            'SECURITYADMIN',
            'TABLE',
            'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1',
            'INSERT',
            TRUE,
            'ACTIVE',
            'Required only to capture immediate SHOW GRANTS snapshots.'
        ),
        (
            'SECURITYADMIN_SNAPSHOT_DELETE',
            'SECURITYADMIN',
            'TABLE',
            'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1',
            'DELETE',
            TRUE,
            'ACTIVE',
            'Required only to replace the named verification snapshot.'
        )
    AS seed(
        EXPECTATION_ID,
        GRANTEE_ROLE,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        REQUIRED_FLAG,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.EXPECTATION_ID =
   source.EXPECTATION_ID
WHEN NOT MATCHED THEN INSERT (
    EXPECTATION_ID,
    GRANTEE_ROLE,
    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,
    REQUIRED_FLAG,
    POLICY_STATUS,
    COMMENTS,
    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.EXPECTATION_ID,
    source.GRANTEE_ROLE,
    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,
    source.REQUIRED_FLAG,
    source.POLICY_STATUS,
    source.COMMENTS,
    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);


MERGE INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_SENSITIVE_OBJECT_V1 target
USING (
    SELECT *
    FROM VALUES
        (
            'SNAPSHOT_CAPTURE_INSERT_SECURITYADMIN',
            'TABLE',
            'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1',
            'INSERT',
            'SECURITYADMIN',
            'SNAPSHOT_CAPTURE_EXCEPTION',
            'ACTIVE',
            'Security administrator may insert the named immediate grant snapshot.'
        ),
        (
            'SNAPSHOT_CAPTURE_DELETE_SECURITYADMIN',
            'TABLE',
            'KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1',
            'DELETE',
            'SECURITYADMIN',
            'SNAPSHOT_CAPTURE_EXCEPTION',
            'ACTIVE',
            'Security administrator may replace the named immediate grant snapshot.'
        )
    AS seed(
        POLICY_ROW_ID,
        GRANTED_ON,
        OBJECT_NAME,
        PRIVILEGE,
        ALLOWED_GRANTEE_ROLE,
        ACCESS_CLASS,
        POLICY_STATUS,
        COMMENTS
    )
) source
ON target.POLICY_ROW_ID =
   source.POLICY_ROW_ID
WHEN NOT MATCHED THEN INSERT (
    POLICY_ROW_ID,
    GRANTED_ON,
    OBJECT_NAME,
    PRIVILEGE,
    ALLOWED_GRANTEE_ROLE,
    ACCESS_CLASS,
    POLICY_STATUS,
    COMMENTS,
    CREATED_BY,
    CREATED_AT
)
VALUES (
    source.POLICY_ROW_ID,
    source.GRANTED_ON,
    source.OBJECT_NAME,
    source.PRIVILEGE,
    source.ALLOWED_GRANTEE_ROLE,
    source.ACCESS_CLASS,
    source.POLICY_STATUS,
    source.COMMENTS,
    CURRENT_USER(),
    CURRENT_TIMESTAMP()
);

USE ROLE SECURITYADMIN;


-- 1. CREATE ACCOUNT ROLES


CREATE ROLE IF NOT EXISTS KMAT_GOVERNANCE_DATA_OWNER_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_GOVERNANCE_EXECUTOR_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_GOVERNANCE_ADMIN_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_GOVERNANCE_ADMIN_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_RUNTIME_OPERATOR_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_RUNTIME_OPERATOR_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_APPLICATION_RUNTIME_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_APPLICATION_RUNTIME_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_OVERRIDE_REQUESTER_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_OVERRIDE_REQUESTER_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_OVERRIDE_REVIEWER_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_OVERRIDE_REVIEWER_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS KMAT_AUDIT_READER_ROLE
    COMMENT = 'KMAT Phase 13B governed role';

GRANT ROLE KMAT_AUDIT_READER_ROLE TO ROLE SYSADMIN;


-- 2. PARENT OBJECT ACCESS


GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT USAGE ON WAREHOUSE KMAT_WH TO ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE KMAT_COST_MODEL_DB TO ROLE SECURITYADMIN;

GRANT USAGE ON SCHEMA KMAT_COST_MODEL_DB.CORE_ML TO ROLE SECURITYADMIN;


-- 3. TRANSFER PROTECTED TABLE OWNERSHIP


GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;



GRANT SELECT ON TABLE
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_DECISION_RESULT_V1
TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;

GRANT SELECT ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_RUNTIME_FINGERPRINT_V1
TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;

-- 4. TRANSFER PHASE 13B VIEW OWNERSHIP


GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_SECURITY_EXPECTED_GRANT_STATUS_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_SECURITY_BYPASS_GRANT_VIOLATION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_SECURITY_FUNCTIONAL_ROLE_DML_VIOLATION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_SECURITY_APPEND_ONLY_VIOLATION_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_OVERRIDE_PRECEDENCE_INTEGRITY_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1 TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE COPY CURRENT GRANTS;


-- 5. TRANSFER SECURE PROCEDURE OWNERSHIP


GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;

GRANT OWNERSHIP ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE COPY CURRENT GRANTS;


-- 6. EXECUTOR PRIVILEGES


GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_RESULT_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT, INSERT, UPDATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT, INSERT ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT, INSERT, UPDATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT, INSERT ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT SELECT, INSERT, DELETE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 TO ROLE SECURITYADMIN;


-- 7. REMOVE DIRECT BYPASS ACCESS


REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE PUBLIC;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) FROM ROLE KMAT_AUDIT_READER_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;


-- 8. REMOVE FUNCTIONAL-ROLE TABLE DML


REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1 FROM ROLE PUBLIC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_RUNTIME_OPERATOR_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_APPLICATION_RUNTIME_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE KMAT_AUDIT_READER_ROLE;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1 FROM ROLE PUBLIC;


-- 9. GRANT SECURE ENTRY POINTS


GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR) TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR) TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR) TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR) TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

GRANT USAGE ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR) TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;


-- 10. GRANT READ-ONLY VIEWS


GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1 TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1 TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2 TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1 TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1 TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1 TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1 TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2 TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2 TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_ML_DECISION_WITH_APPROVED_OVERRIDE_V2 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE13A_RUNTIME_AUTHORITY_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12C_PRODUCTION_READINESS_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE12B_PILOT_DASHBOARD_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

GRANT SELECT ON VIEW KMAT_COST_MODEL_DB.CORE_ML.VW_KMAT_PHASE11A_MONITORING_DASHBOARD_V1 TO ROLE KMAT_AUDIT_READER_ROLE;

-- 11. FINAL SECURITY CONTEXT
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

USE ROLE SECURITYADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

DELETE FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1
WHERE SNAPSHOT_ID =
      'PHASE13B_POST_DEPLOYMENT';

SHOW GRANTS TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_GOVERNANCE_DATA_OWNER_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_GOVERNANCE_EXECUTOR_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_GOVERNANCE_EXECUTOR_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_GOVERNANCE_ADMIN_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_RUNTIME_OPERATOR_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_APPLICATION_RUNTIME_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_OVERRIDE_REQUESTER_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_OVERRIDE_REQUESTER_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_OVERRIDE_REVIEWER_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_OVERRIDE_REVIEWER_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS TO ROLE KMAT_AUDIT_READER_ROLE;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'ROLE::KMAT_AUDIT_READER_ROLE',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS TO ROLE KMAT_AUDIT_READER_ROLE;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SET_ML_DEPLOYMENT_CAPABILITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CREATE_ML_POLICY_CANDIDATE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUBMIT_ML_DEPLOYMENT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REFRESH_ML_DEPLOYMENT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVIEW_ML_DEPLOYMENT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ROLLBACK_ML_DEPLOYMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CANCEL_ML_DEPLOYMENT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RECORD_ML_CANDIDATE_PREDICTION_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RUN_ML_CANDIDATE_BACKTEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_V4',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V4(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ENABLE_ML_RUNTIME_AUTHORITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SET_ML_RUNTIME_KILL_SWITCH_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RESOLVE_ML_RUNTIME_AUTHORITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RUN_ML_RUNTIME_SAFETY_MONITOR_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUSPEND_ML_RUNTIME_AUTHORITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVOKE_ML_RUNTIME_AUTHORITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CAPTURE_ML_DECISION_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_ML_DECISION_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_ML_DECISION_POLICY_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_V2',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V2(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_V3',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_V3(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUBMIT_ML_DECISION_OVERRIDE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVIEW_ML_DECISION_OVERRIDE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CREATE_ML_POLICY_CANDIDATE_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CREATE_ML_POLICY_CANDIDATE_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BOOLEAN,BOOLEAN,BOOLEAN,FLOAT,FLOAT,FLOAT,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ROLLBACK_ML_DEPLOYMENT_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ROLLBACK_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1(VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR,FLOAT,BOOLEAN,BOOLEAN,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RUN_ML_CANDIDATE_BACKTEST_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_CANDIDATE_BACKTEST_SECURE_V1(VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1(VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR,FLOAT,FLOAT,BOOLEAN,BOOLEAN,BOOLEAN,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1(VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::CAPTURE_ML_DECISION_AUDIT_SECURE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.CAPTURE_ML_DECISION_AUDIT_SECURE_V1(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::SUBMIT_ML_DECISION_OVERRIDE_V2',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.SUBMIT_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,FLOAT,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR);

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'PROCEDURE::REVIEW_ML_DECISION_OVERRIDE_V2',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON PROCEDURE KMAT_COST_MODEL_DB.CORE_ML.REVIEW_ML_DECISION_OVERRIDE_V2(VARCHAR,VARCHAR,VARCHAR);'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DECISION_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DECISION_OVERRIDE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_OVERRIDE_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DECISION_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DECISION_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_CAPABILITY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_CAPABILITY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_GATE_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_GATE_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_REQUIREMENT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_REQUEST_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_APPROVAL_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_APPROVAL_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_DEPLOYMENT_EVENT_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_DEPLOYMENT_EVENT_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_CANDIDATE_PREDICTION_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_PREDICTION_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_EVENT_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_CANDIDATE_BACKTEST_DETAIL_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_DETAIL_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_CANDIDATE_BACKTEST_RUN_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_CANDIDATE_BACKTEST_RUN_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_PLAN_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_PLAN_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_SCOPE_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_SCOPE_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_CAPACITY_COUNTER_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_CAPACITY_COUNTER_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_ASSIGNMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_ASSIGNMENT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_DECISION_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_DECISION_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_INCIDENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_INCIDENT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_MONITORING_RUN_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_MONITORING_RUN_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EVENT_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EVENT_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_REQUIREMENT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_REQUEST_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_REQUEST_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_ASSESSMENT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_ASSESSMENT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_SIGNOFF_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_SIGNOFF_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PRODUCTION_PROMOTION_LINK_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PRODUCTION_PROMOTION_LINK_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_PILOT_EXIT_EVENT_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_PILOT_EXIT_EVENT_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_SAFETY_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_AUTHORITY_REGISTRY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_REGISTRY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_KILL_SWITCH_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_KILL_SWITCH_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_AUTHORITY_COUNTER_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_COUNTER_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_AUTHORITY_DECISION_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_DECISION_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_SAFETY_MONITOR_RUN_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_SAFETY_MONITOR_RUN_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_RUNTIME_AUTHORITY_EVENT_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::KMAT_ACTUAL_OUTCOME_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_ACTUAL_OUTCOME_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::KMAT_GOVERNED_COST_INPUT_AUDIT_V2',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_GOVERNED_COST_INPUT_AUDIT_V2;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.KMAT_COST_FACTOR_RESOLUTION_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_SECURITY_ROLE_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_ROLE_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_SECURITY_EXPECTED_GRANT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_EXPECTED_GRANT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_SECURITY_SENSITIVE_OBJECT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_SENSITIVE_OBJECT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_APPEND_ONLY_OBJECT_POLICY_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_APPEND_ONLY_OBJECT_POLICY_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_SECURITY_GRANT_SNAPSHOT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_GRANT_SNAPSHOT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_POLICY_VERSION_SEAL_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_POLICY_VERSION_SEAL_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1;

INSERT INTO
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1 (
            SNAPSHOT_ID,
            CAPTURED_AT,

            CAPTURE_SCOPE,

            GRANTED_ON,
            OBJECT_NAME,
            PRIVILEGE,

            GRANTED_TO,
            GRANTEE_NAME,

            GRANT_OPTION,
            GRANTED_BY,

            SOURCE_COMMAND
        )
SELECT
    'PHASE13B_POST_DEPLOYMENT',
    CURRENT_TIMESTAMP(),

    'TABLE::ML_SECURITY_CALL_AUDIT_V1',

    UPPER("granted_on"),
    REGEXP_REPLACE(
        UPPER("name"),
        '[[:space:]]+',
        ''
    ),
    UPPER("privilege"),

    UPPER("granted_to"),
    UPPER("grantee_name"),

    "grant_option"::BOOLEAN,
    UPPER("granted_by"),

    'SHOW GRANTS ON TABLE KMAT_COST_MODEL_DB.CORE_ML.ML_SECURITY_CALL_AUDIT_V1;'
FROM TABLE(
    RESULT_SCAN(
        LAST_QUERY_ID()
    )
);

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

SELECT
    SNAPSHOT_ID,
    COUNT(*) AS SNAPSHOT_ROW_COUNT,
    MAX(CAPTURED_AT) AS CAPTURED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_GRANT_SNAPSHOT_V1
WHERE SNAPSHOT_ID =
      'PHASE13B_POST_DEPLOYMENT'
GROUP BY SNAPSHOT_ID;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- ============================================================
-- PHASE 13B — VERIFICATION
-- ============================================================


-- Expected:
--   SECURE_PROCEDURE_COUNT = 19
--   NON_SECURE_PROCEDURE_COUNT = 0
SHOW PROCEDURES IN SCHEMA KMAT_COST_MODEL_DB.CORE_ML;

SELECT
    COUNT_IF("is_secure" = 'Y') AS SECURE_PROCEDURE_COUNT,
    COUNT_IF("is_secure" <> 'Y') AS NON_SECURE_PROCEDURE_COUNT
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN (
      'SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1',
      'CREATE_ML_POLICY_CANDIDATE_SECURE_V1',
      'SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1',
      'REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1',
      'REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1',
      'ROLLBACK_ML_DEPLOYMENT_SECURE_V1',
      'CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1',
      'RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1',
      'RUN_ML_CANDIDATE_BACKTEST_SECURE_V1',
      'ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1',
      'ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1',
      'SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1',
      'RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1',
      'RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1',
      'SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1',
      'REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1',
      'CAPTURE_ML_DECISION_AUDIT_SECURE_V1',
      'SUBMIT_ML_DECISION_OVERRIDE_V2',
      'REVIEW_ML_DECISION_OVERRIDE_V2'
  );


-- Expected:
--   GOVERNED_ROLE_POLICY_COUNT = 8
SELECT
    COUNT(*) AS GOVERNED_ROLE_POLICY_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_ROLE_POLICY_V1
WHERE POLICY_STATUS = 'ACTIVE';

-- Expected: one non-empty latest snapshot.
SELECT
    COUNT(*) AS GOVERNED_ROLE_POLICY_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_SECURITY_ROLE_POLICY_V1
WHERE POLICY_STATUS = 'ACTIVE';


-- Expected: one non-empty latest snapshot.
SELECT
    SNAPSHOT_ID,
    COUNT(*) AS SNAPSHOT_ROW_COUNT,
    MAX(CAPTURED_AT) AS CAPTURED_AT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
GROUP BY SNAPSHOT_ID;


-- Expected:
--   MISSING_REQUIRED_GRANT_COUNT = 0
SELECT
    COUNT(*) AS EXPECTED_GRANT_COUNT,

    COALESCE(
        COUNT_IF(
            MISSING_REQUIRED_GRANT_FLAG = TRUE
        ),
        0
    )::NUMBER AS MISSING_REQUIRED_GRANT_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_EXPECTED_GRANT_STATUS_V1;


-- Expected: zero rows.
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_BYPASS_GRANT_VIOLATION_V1
ORDER BY
    ACCESS_CLASS,
    OBJECT_NAME,
    GRANTEE_NAME;


-- Expected: zero rows.
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_FUNCTIONAL_ROLE_DML_VIOLATION_V1
ORDER BY
    GRANTEE_NAME,
    OBJECT_NAME,
    PRIVILEGE;


-- Expected: zero rows.
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_APPEND_ONLY_VIOLATION_V1
ORDER BY
    OBJECT_NAME,
    PRIVILEGE,
    GRANTEE_NAME;


-- Expected: zero rows with FAILED status.
SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_OVERRIDE_PRECEDENCE_INTEGRITY_V1
WHERE PRECEDENCE_INTEGRITY_STATUS =
      'FAILED';


-- Initial deployment expectation:
--   ACTIVE_POLICY_SEAL_COUNT = 0
--   POLICY_SEAL_MISMATCH_COUNT = 0
SELECT
    COALESCE(
        COUNT_IF(
            ACTIVE_SEAL_PRESENT_FLAG = TRUE
        ),
        0
    )::NUMBER AS ACTIVE_POLICY_SEAL_COUNT,

    COALESCE(
        COUNT_IF(
            ACTIVE_SEAL_PRESENT_FLAG = TRUE
            AND POLICY_SEAL_MATCH_FLAG = FALSE
        ),
        0
    )::NUMBER AS POLICY_SEAL_MISMATCH_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1;


-- Expected:
--   PROTECTED_TABLE_OWNER_COUNT = 45
--   SECURE_PROCEDURE_OWNER_COUNT = 19
SELECT
    COALESCE(
        COUNT_IF(
            GRANTED_ON = 'TABLE'
            AND PRIVILEGE = 'OWNERSHIP'
            AND GRANTEE_NAME =
                'KMAT_GOVERNANCE_DATA_OWNER_ROLE'
            AND CAPTURE_SCOPE LIKE 'TABLE::%'
        ),
        0
    )::NUMBER AS PROTECTED_TABLE_OWNER_COUNT,

    COUNT(
        DISTINCT IFF(
            GRANTED_ON = 'PROCEDURE'
            AND PRIVILEGE = 'OWNERSHIP'
            AND GRANTEE_NAME =
                'KMAT_GOVERNANCE_EXECUTOR_ROLE'
            AND CAPTURE_SCOPE LIKE 'PROCEDURE::%'
            AND (
                OBJECT_NAME LIKE '%SECURE%'
                OR OBJECT_NAME LIKE
                    '%SUBMIT_ML_DECISION_OVERRIDE_V2%'
                OR OBJECT_NAME LIKE
                    '%REVIEW_ML_DECISION_OVERRIDE_V2%'
            ),
            OBJECT_NAME,
            NULL
        )
    )::NUMBER AS SECURE_PROCEDURE_OWNER_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1;


SELECT *
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_PHASE13B_SECURITY_DASHBOARD_V1;


-- Existing policy and runtime safety must remain unchanged.
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


SELECT
    COUNT(*) AS ACTIVE_RUNTIME_AUTHORITY_COUNT,

    COALESCE(
        COUNT_IF(
            AUTHORITY_STATUS = 'ENABLED'
        ),
        0
    )::NUMBER AS ENABLED_RUNTIME_AUTHORITY_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1;


WITH PROCEDURES AS (
    SELECT
        COUNT(*) AS PROCEDURE_COUNT,
        0::NUMBER AS NON_SECURE_PROCEDURE_COUNT

    FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'CORE_ML'
      AND PROCEDURE_NAME IN (
          'SET_ML_DEPLOYMENT_CAPABILITY_SECURE_V1',
          'CREATE_ML_POLICY_CANDIDATE_SECURE_V1',
          'SUBMIT_ML_DEPLOYMENT_REQUEST_SECURE_V1',
          'REFRESH_ML_DEPLOYMENT_REQUEST_SECURE_V1',
          'REVIEW_ML_DEPLOYMENT_REQUEST_SECURE_V1',
          'ROLLBACK_ML_DEPLOYMENT_SECURE_V1',
          'CANCEL_ML_DEPLOYMENT_REQUEST_SECURE_V1',
          'RECORD_ML_CANDIDATE_PREDICTION_SECURE_V1',
          'RUN_ML_CANDIDATE_BACKTEST_SECURE_V1',
          'ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1',
          'ENABLE_ML_RUNTIME_AUTHORITY_SECURE_V1',
          'SET_ML_RUNTIME_KILL_SWITCH_SECURE_V1',
          'RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1',
          'RUN_ML_RUNTIME_SAFETY_MONITOR_SECURE_V1',
          'SUSPEND_ML_RUNTIME_AUTHORITY_SECURE_V1',
          'REVOKE_ML_RUNTIME_AUTHORITY_SECURE_V1',
          'CAPTURE_ML_DECISION_AUDIT_SECURE_V1',
          'SUBMIT_ML_DECISION_OVERRIDE_V2',
          'REVIEW_ML_DECISION_OVERRIDE_V2'
      )
),
ROLE_POLICY AS (
    SELECT COUNT(*) AS ROLE_POLICY_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .ML_SECURITY_ROLE_POLICY_V1
    WHERE POLICY_STATUS = 'ACTIVE'
),
SNAPSHOT AS (
    SELECT
        MAX(SNAPSHOT_ID) AS SNAPSHOT_ID,
        COUNT(*) AS SNAPSHOT_ROW_COUNT
    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
),
EXPECTED AS (
    SELECT
        COUNT(*) AS EXPECTED_GRANT_COUNT,

        COALESCE(
            COUNT_IF(
                MISSING_REQUIRED_GRANT_FLAG = TRUE
            ),
            0
        )::NUMBER AS MISSING_REQUIRED_GRANT_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_EXPECTED_GRANT_STATUS_V1
),
VIOLATIONS AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_SECURITY_BYPASS_GRANT_VIOLATION_V1
        )
        AS BYPASS_GRANT_VIOLATION_COUNT,

        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_SECURITY_FUNCTIONAL_ROLE_DML_VIOLATION_V1
        )
        AS FUNCTIONAL_ROLE_DML_VIOLATION_COUNT,

        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_SECURITY_APPEND_ONLY_VIOLATION_V1
        )
        AS APPEND_ONLY_VIOLATION_COUNT,

        (
            SELECT COUNT(*)
            FROM
                KMAT_COST_MODEL_DB.CORE_ML
                    .VW_ML_OVERRIDE_PRECEDENCE_INTEGRITY_V1
            WHERE PRECEDENCE_INTEGRITY_STATUS =
                  'FAILED'
        )
        AS OVERRIDE_PRECEDENCE_VIOLATION_COUNT
),
SEALS AS (
    SELECT
        COALESCE(
            COUNT_IF(
                ACTIVE_SEAL_PRESENT_FLAG = TRUE
            ),
            0
        )::NUMBER AS ACTIVE_POLICY_SEAL_COUNT,

        COALESCE(
            COUNT_IF(
                ACTIVE_SEAL_PRESENT_FLAG = TRUE
                AND POLICY_SEAL_MATCH_FLAG = FALSE
            ),
            0
        )::NUMBER AS POLICY_SEAL_MISMATCH_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_POLICY_VERSION_SEAL_INTEGRITY_V1
),
OWNERSHIP AS (
    SELECT
        COALESCE(
            COUNT_IF(
                GRANTED_ON = 'TABLE'
                AND PRIVILEGE = 'OWNERSHIP'
                AND GRANTEE_NAME =
                    'KMAT_GOVERNANCE_DATA_OWNER_ROLE'
                AND CAPTURE_SCOPE LIKE 'TABLE::%'
            ),
            0
        )::NUMBER AS PROTECTED_TABLE_OWNER_COUNT,

        COUNT(
            DISTINCT IFF(
                GRANTED_ON = 'PROCEDURE'
                AND PRIVILEGE = 'OWNERSHIP'
                AND GRANTEE_NAME =
                    'KMAT_GOVERNANCE_EXECUTOR_ROLE'
                AND CAPTURE_SCOPE LIKE 'PROCEDURE::%'
                AND (
                    OBJECT_NAME LIKE '%SECURE%'
                    OR OBJECT_NAME LIKE
                        '%SUBMIT_ML_DECISION_OVERRIDE_V2%'
                    OR OBJECT_NAME LIKE
                        '%REVIEW_ML_DECISION_OVERRIDE_V2%'
                ),
                OBJECT_NAME,
                NULL
            )
        )::NUMBER AS SECURE_PROCEDURE_OWNER_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_SECURITY_GRANT_SNAPSHOT_LATEST_V1
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
),
RUNTIME AS (
    SELECT
        COUNT(*) AS ACTIVE_RUNTIME_AUTHORITY_COUNT,

        COALESCE(
            COUNT_IF(
                AUTHORITY_STATUS = 'ENABLED'
            ),
            0
        )::NUMBER AS ENABLED_RUNTIME_AUTHORITY_COUNT

    FROM
        KMAT_COST_MODEL_DB.CORE_ML
            .VW_ML_RUNTIME_AUTHORITY_CURRENT_V1
)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            procedures.PROCEDURE_COUNT = 19
            AND procedures.NON_SECURE_PROCEDURE_COUNT = 0
            AND role_policy.ROLE_POLICY_COUNT = 8
            AND snapshot.SNAPSHOT_ID IS NOT NULL
            AND snapshot.SNAPSHOT_ROW_COUNT > 0
            AND expected.MISSING_REQUIRED_GRANT_COUNT = 0
            AND violations.BYPASS_GRANT_VIOLATION_COUNT = 0
            AND violations.FUNCTIONAL_ROLE_DML_VIOLATION_COUNT = 0
            AND violations.APPEND_ONLY_VIOLATION_COUNT = 0
            AND violations.OVERRIDE_PRECEDENCE_VIOLATION_COUNT = 0
            AND seals.POLICY_SEAL_MISMATCH_COUNT = 0
            AND ownership.PROTECTED_TABLE_OWNER_COUNT = 45
            AND ownership.SECURE_PROCEDURE_OWNER_COUNT = 19
            AND policies.ACTIVE_POLICY_COUNT = 4
            AND policies.SHADOW_POLICY_COUNT = 4
            AND policies.AUTHORITY_ENABLED_COUNT = 0
            AND runtime.ACTIVE_RUNTIME_AUTHORITY_COUNT = 0
            AND runtime.ENABLED_RUNTIME_AUTHORITY_COUNT = 0,
            'SUCCESS',
            'FAILED'
        ),

    'phase', 'PHASE_13B',

    'secure_procedure_count',
        procedures.PROCEDURE_COUNT,

    'non_secure_procedure_count',
        procedures.NON_SECURE_PROCEDURE_COUNT,

    'governed_role_policy_count',
        role_policy.ROLE_POLICY_COUNT,

    'grant_snapshot_id',
        snapshot.SNAPSHOT_ID,

    'grant_snapshot_row_count',
        snapshot.SNAPSHOT_ROW_COUNT,

    'expected_grant_count',
        expected.EXPECTED_GRANT_COUNT,

    'missing_required_grant_count',
        expected.MISSING_REQUIRED_GRANT_COUNT,

    'bypass_grant_violation_count',
        violations.BYPASS_GRANT_VIOLATION_COUNT,

    'functional_role_dml_violation_count',
        violations.FUNCTIONAL_ROLE_DML_VIOLATION_COUNT,

    'append_only_violation_count',
        violations.APPEND_ONLY_VIOLATION_COUNT,

    'override_precedence_violation_count',
        violations.OVERRIDE_PRECEDENCE_VIOLATION_COUNT,

    'active_policy_seal_count',
        seals.ACTIVE_POLICY_SEAL_COUNT,

    'policy_seal_mismatch_count',
        seals.POLICY_SEAL_MISMATCH_COUNT,

    'protected_table_owner_count',
        ownership.PROTECTED_TABLE_OWNER_COUNT,

    'secure_procedure_owner_count',
        ownership.SECURE_PROCEDURE_OWNER_COUNT,

    'active_policy_count',
        policies.ACTIVE_POLICY_COUNT,

    'shadow_policy_count',
        policies.SHADOW_POLICY_COUNT,

    'authority_enabled_count',
        policies.AUTHORITY_ENABLED_COUNT,

    'active_runtime_authority_count',
        runtime.ACTIVE_RUNTIME_AUTHORITY_COUNT,

    'enabled_runtime_authority_count',
        runtime.ENABLED_RUNTIME_AUTHORITY_COUNT,

    'official_activation_entry_point',
        'ACTIVATE_APPROVED_ML_DEPLOYMENT_SECURE_V1',

    'override_entry_point',
        'SUBMIT_ML_DECISION_OVERRIDE_V2 / REVIEW_ML_DECISION_OVERRIDE_V2',

    'security_control_state',
        'HARDENED_NO_RUNTIME_AUTHORITY',

    'official_cost_changed',
        FALSE,

    'policy_activated',
        FALSE,

    'users_assigned_new_roles',
        FALSE
) AS PHASE13B_RESULT

FROM PROCEDURES procedures
CROSS JOIN ROLE_POLICY role_policy
CROSS JOIN SNAPSHOT snapshot
CROSS JOIN EXPECTED expected
CROSS JOIN VIOLATIONS violations
CROSS JOIN SEALS seals
CROSS JOIN OWNERSHIP ownership
CROSS JOIN POLICIES policies
CROSS JOIN RUNTIME runtime;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

-- ============================================================
-- FINAL STREAMLIT INTEGRATION OBJECT
--
-- Purpose:
--   Expose the exact latest governed model-decision inputs
--   required by RESOLVE_ML_RUNTIME_AUTHORITY_SECURE_V1.
--
-- Safety:
--   * read-only secure view;
--   * no policy activation;
--   * no runtime enablement;
--   * no official cost change;
--   * BMCS exposes raw probability, never a direct cost value.
-- ============================================================

CREATE OR REPLACE SECURE VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
AS
SELECT
    DECISION_ID,
    ENTITY_ID,
    RFQ_ID,
    SIMULATION_ID,
    MODEL_DOMAIN,

    POLICY_ID,
    POLICY_VERSION,
    DEPLOYMENT_MODE,

    MODEL_NAME,
    MODEL_VERSION,
    FEATURE_SET_VERSION,

    RULE_VALUE,
    RAW_ML_VALUE,
    RECOMMENDED_ML_VALUE,

    IFF(
        MODEL_DOMAIN = 'BMCS',
        NULL::FLOAT,
        RULE_VALUE::FLOAT
    ) AS RUNTIME_RULE_VALUE,

    IFF(
        MODEL_DOMAIN = 'BMCS',
        RAW_ML_VALUE::FLOAT,
        RECOMMENDED_ML_VALUE::FLOAT
    ) AS RUNTIME_CANDIDATE_VALUE,

    FEATURE_QUALITY_PASS_FLAG,
    MODEL_OOD_FLAG,
    MODEL_INFERENCE_SUCCESS_FLAG,
    ENGINEER_APPROVAL_FLAG,
    ESTIMATED_COST_IMPACT_PCT,

    ML_INPUT_STATUS,
    DECISION_STATUS,
    DECISION_SOURCE,
    FALLBACK_REASON,

    IFF(
        MODEL_INFERENCE_SUCCESS_FLAG = TRUE
        AND FEATURE_QUALITY_PASS_FLAG IS NOT NULL
        AND MODEL_OOD_FLAG IS NOT NULL
        AND (
            (
                MODEL_DOMAIN = 'BMCS'
                AND RAW_ML_VALUE IS NOT NULL
                AND RAW_ML_VALUE BETWEEN 0.0 AND 1.0
            )
            OR
            (
                MODEL_DOMAIN IN (
                    'CSS',
                    'FMIS',
                    'TDS'
                )
                AND RULE_VALUE IS NOT NULL
                AND RECOMMENDED_ML_VALUE IS NOT NULL
            )
        ),
        TRUE,
        FALSE
    ) AS RUNTIME_INPUT_READY_FLAG,

    CASE
        WHEN COALESCE(
            MODEL_INFERENCE_SUCCESS_FLAG,
            FALSE
        ) <> TRUE
            THEN 'MODEL_INFERENCE_NOT_SUCCESSFUL'

        WHEN FEATURE_QUALITY_PASS_FLAG IS NULL
            THEN 'QUALITY_FLAG_MISSING'

        WHEN MODEL_OOD_FLAG IS NULL
            THEN 'OOD_FLAG_MISSING'

        WHEN MODEL_DOMAIN = 'BMCS'
         AND (
             RAW_ML_VALUE IS NULL
             OR RAW_ML_VALUE < 0.0
             OR RAW_ML_VALUE > 1.0
         )
            THEN 'BMCS_PROBABILITY_INVALID'

        WHEN MODEL_DOMAIN IN (
            'CSS',
            'FMIS',
            'TDS'
        )
         AND RULE_VALUE IS NULL
            THEN 'RULE_VALUE_MISSING'

        WHEN MODEL_DOMAIN IN (
            'CSS',
            'FMIS',
            'TDS'
        )
         AND RECOMMENDED_ML_VALUE IS NULL
            THEN 'CANDIDATE_VALUE_MISSING'

        ELSE 'READY'
    END AS RUNTIME_INPUT_STATUS,

    CREATED_AT,
    UPDATED_AT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .ML_DECISION_RESULT_V1

WHERE MODEL_DOMAIN IN (
    'CSS',
    'FMIS',
    'TDS',
    'BMCS'
)

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        SIMULATION_ID,
        MODEL_DOMAIN
    ORDER BY
        UPDATED_AT DESC,
        CREATED_AT DESC,
        DECISION_ID DESC
) = 1;


-- Ownership and least-privilege read grants.
USE ROLE SECURITYADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

GRANT OWNERSHIP ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
TO ROLE KMAT_GOVERNANCE_DATA_OWNER_ROLE
COPY CURRENT GRANTS;

GRANT SELECT ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
TO ROLE KMAT_GOVERNANCE_ADMIN_ROLE;

GRANT SELECT ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
TO ROLE KMAT_RUNTIME_OPERATOR_ROLE;

GRANT SELECT ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
TO ROLE KMAT_APPLICATION_RUNTIME_ROLE;

GRANT SELECT ON VIEW
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
TO ROLE KMAT_AUDIT_READER_ROLE;


-- Verification.
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_ML;

SELECT
    COUNT(*) AS RUNTIME_INPUT_ROW_COUNT,

    COALESCE(
        COUNT_IF(
            RUNTIME_INPUT_READY_FLAG = TRUE
        ),
        0
    )::NUMBER AS READY_RUNTIME_INPUT_COUNT,

    COALESCE(
        COUNT_IF(
            MODEL_DOMAIN = 'BMCS'
            AND RUNTIME_CANDIDATE_VALUE
                NOT BETWEEN 0.0 AND 1.0
        ),
        0
    )::NUMBER AS INVALID_BMCS_PROBABILITY_COUNT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1;


-- Expected: zero rows.
SELECT
    SIMULATION_ID,
    MODEL_DOMAIN,
    COUNT(*) AS DUPLICATE_RUNTIME_INPUT_COUNT
FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1
GROUP BY
    SIMULATION_ID,
    MODEL_DOMAIN
HAVING COUNT(*) > 1;


SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'status',
        IFF(
            COALESCE(
                COUNT_IF(
                    MODEL_DOMAIN = 'BMCS'
                    AND RUNTIME_CANDIDATE_VALUE
                        NOT BETWEEN 0.0 AND 1.0
                ),
                0
            ) = 0,
            'SUCCESS',
            'FAILED'
        ),

    'integration_object',
        'VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1',

    'runtime_input_row_count',
        COUNT(*),

    'ready_runtime_input_count',
        COALESCE(
            COUNT_IF(
                RUNTIME_INPUT_READY_FLAG = TRUE
            ),
            0
        )::NUMBER,

    'invalid_bmcs_probability_count',
        COALESCE(
            COUNT_IF(
                MODEL_DOMAIN = 'BMCS'
                AND RUNTIME_CANDIDATE_VALUE
                    NOT BETWEEN 0.0 AND 1.0
            ),
            0
        )::NUMBER,

    'official_cost_changed',
        FALSE,

    'policy_activated',
        FALSE,

    'runtime_authority_enabled',
        FALSE
) AS STREAMLIT_RUNTIME_INPUT_RESULT

FROM
    KMAT_COST_MODEL_DB.CORE_ML
        .VW_KMAT_STREAMLIT_RUNTIME_INPUT_V1;


