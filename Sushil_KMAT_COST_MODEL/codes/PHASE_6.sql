USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE TABLE CORE_INPUT.RFQ_HEADER (
    RFQ_ID                  VARCHAR,
    KMAT_ID                 VARCHAR,
    CUSTOMER_ID             VARCHAR,
    CUSTOMER_NAME           VARCHAR,
    SOURCE_DOCUMENT_NAME    VARCHAR,
    SOURCE_DOCUMENT_TYPE    VARCHAR,
    SOURCE_DOCUMENT_TEXT    VARCHAR,
    DOCUMENT_STATUS         VARCHAR,
    RFQ_RECEIVED_AT         TIMESTAMP_NTZ,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
DESC TABLE CORE_INPUT.RFQ_HEADER;

CREATE TABLE IF NOT EXISTS CORE_INPUT.RFQ_CONFIGURATION (
    RFQ_ID                         VARCHAR,
    SIMULATION_ID                  VARCHAR,
    KMAT_ID                        VARCHAR,
    CONFIGURATION_VERSION          NUMBER(10,0),
    EXTRACTED_CONFIGURATION_JSON   VARIANT,
    EXTRACTION_METHOD              VARCHAR,
    EXTRACTION_MODEL_NAME          VARCHAR,
    EXTRACTION_PROMPT_VERSION      VARCHAR,
    EXTRACTION_RAW_RESPONSE        VARIANT,
    CREATED_BY                     VARCHAR,
    ACTIVE_FLAG                    BOOLEAN,
    CREATED_AT                     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS CORE_INPUT.BMCS_REVIEW_RULES (
    BMCS_RULE_ID                       VARCHAR,
    MIN_SCORE                          NUMBER(5,2),
    MAX_SCORE                          NUMBER(5,2),
    REVIEW_STATUS                      VARCHAR,
    REVIEW_REQUIRED_FLAG               BOOLEAN,
    FINAL_TRUSTED_COST_ALLOWED_FLAG    BOOLEAN,
    BUSINESS_ACTION                    VARCHAR,
    ACTIVE_FLAG                        BOOLEAN,
    CREATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
ALTER TABLE CORE_INPUT.BMCS_REVIEW_RULES
ADD COLUMN IF NOT EXISTS UPDATED_AT TIMESTAMP_NTZ;

CREATE TABLE IF NOT EXISTS CORE_INPUT.BOM_MATCH_ASSESSMENT (
    RFQ_ID                              VARCHAR,
    SIMULATION_ID                       VARCHAR,
    KMAT_ID                             VARCHAR,
    CONFIGURATION_VERSION               NUMBER(10,0),
    BOM_MATCH_CONFIDENCE_SCORE          NUMBER(5,2),
    REVIEW_STATUS                       VARCHAR,
    REVIEW_REQUIRED_FLAG                BOOLEAN,
    FINAL_TRUSTED_COST_ALLOWED_FLAG     BOOLEAN,
    REVIEWED_BY                         VARCHAR,
    REVIEWED_AT                         TIMESTAMP_NTZ,
    ASSESSMENT_METHOD                   VARCHAR,
    ASSESSMENT_VERSION                  VARCHAR,
    ASSESSMENT_NOTES                    VARCHAR,
    CREATED_AT                          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO CORE_INPUT.BMCS_REVIEW_RULES t
USING (
    SELECT
        'BMCS_AUTO_APPROVED' AS BMCS_RULE_ID,
        90.00 AS MIN_SCORE,
        100.00 AS MAX_SCORE,
        'AUTO_APPROVED' AS REVIEW_STATUS,
        FALSE AS REVIEW_REQUIRED_FLAG,
        TRUE AS FINAL_TRUSTED_COST_ALLOWED_FLAG,
        'High confidence mapping. Configuration can proceed automatically to costing.' AS BUSINESS_ACTION,
        TRUE AS ACTIVE_FLAG

    UNION ALL

    SELECT
        'BMCS_REVIEW_RECOMMENDED',
        70.00,
        89.99,
        'REVIEW_RECOMMENDED',
        FALSE,
        TRUE,
        'Medium confidence mapping. Costing can proceed, but engineering review is recommended.',
        TRUE

    UNION ALL

    SELECT
        'BMCS_REVIEW_REQUIRED',
        0.00,
        69.99,
        'REVIEW_REQUIRED',
        TRUE,
        FALSE,
        'Low confidence mapping. Mandatory engineering review required before final trusted costing.',
        TRUE
) s
ON t.BMCS_RULE_ID = s.BMCS_RULE_ID
WHEN MATCHED THEN UPDATE SET
    t.MIN_SCORE = s.MIN_SCORE,
    t.MAX_SCORE = s.MAX_SCORE,
    t.REVIEW_STATUS = s.REVIEW_STATUS,
    t.REVIEW_REQUIRED_FLAG = s.REVIEW_REQUIRED_FLAG,
    t.FINAL_TRUSTED_COST_ALLOWED_FLAG = s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    t.BUSINESS_ACTION = s.BUSINESS_ACTION,
    t.ACTIVE_FLAG = s.ACTIVE_FLAG,
    t.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    BMCS_RULE_ID,
    MIN_SCORE,
    MAX_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    BUSINESS_ACTION,
    ACTIVE_FLAG
)
VALUES (
    s.BMCS_RULE_ID,
    s.MIN_SCORE,
    s.MAX_SCORE,
    s.REVIEW_STATUS,
    s.REVIEW_REQUIRED_FLAG,
    s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    s.BUSINESS_ACTION,
    s.ACTIVE_FLAG
);
SELECT *
FROM CORE_INPUT.BMCS_REVIEW_RULES
ORDER BY MIN_SCORE DESC;

MERGE INTO CORE_INPUT.RFQ_HEADER t
USING (
    SELECT
        'RFQ_001' AS RFQ_ID,
        'KMAT_TRUCK_01' AS KMAT_ID,
        'CUST_RFQ_001' AS CUSTOMER_ID,
        'Apex Logistics' AS CUSTOMER_NAME,
        'RFQ_001_heavy_duty_red_truck.pdf' AS SOURCE_DOCUMENT_NAME,
        'PDF' AS SOURCE_DOCUMENT_TYPE,
        'Heavy-duty red truck with premium cabin, enhanced terrain package, and high-output engine.' AS SOURCE_DOCUMENT_TEXT,
        'RECEIVED' AS DOCUMENT_STATUS,
        CURRENT_TIMESTAMP() AS RFQ_RECEIVED_AT

    UNION ALL

    SELECT
        'RFQ_002',
        'KMAT_TRUCK_01',
        'CUST_RFQ_002',
        'Northline Construction',
        'RFQ_002_construction_truck_email.txt',
        'EMAIL',
        'Need a premium truck for rough site conditions. Prefer red color. Engine requirement is not fully specified.',
        'RECEIVED',
        CURRENT_TIMESTAMP()

    UNION ALL

    SELECT
        'RFQ_003',
        'KMAT_TRUCK_01',
        'CUST_RFQ_003',
        'GreenRoute Transport',
        'RFQ_003_general_transport_request.docx',
        'DOCX',
        'Looking for a reliable truck for regular transport. Some customization may be required. Final specs not confirmed.',
        'RECEIVED',
        CURRENT_TIMESTAMP()
) s
ON t.RFQ_ID = s.RFQ_ID
WHEN MATCHED THEN UPDATE SET
    t.KMAT_ID = s.KMAT_ID,
    t.CUSTOMER_ID = s.CUSTOMER_ID,
    t.CUSTOMER_NAME = s.CUSTOMER_NAME,
    t.SOURCE_DOCUMENT_NAME = s.SOURCE_DOCUMENT_NAME,
    t.SOURCE_DOCUMENT_TYPE = s.SOURCE_DOCUMENT_TYPE,
    t.SOURCE_DOCUMENT_TEXT = s.SOURCE_DOCUMENT_TEXT,
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
    s.DOCUMENT_STATUS,
    s.RFQ_RECEIVED_AT
);

SELECT
    RFQ_ID,
    CUSTOMER_ID,
    CUSTOMER_NAME,
    KMAT_ID,
    SOURCE_DOCUMENT_NAME,
    SOURCE_DOCUMENT_TYPE,
    DOCUMENT_STATUS
FROM CORE_INPUT.RFQ_HEADER
ORDER BY RFQ_ID;

MERGE INTO CORE_INPUT.RFQ_CONFIGURATION t
USING (
    SELECT
        'RFQ_001' AS RFQ_ID,
        'SIM_RFQ_001' AS SIMULATION_ID,
        'KMAT_TRUCK_01' AS KMAT_ID,
        1 AS CONFIGURATION_VERSION,
        PARSE_JSON('{
            "ENGINE": "V8",
            "CAB": "PREMIUM",
            "WHEEL": "OFFROAD",
            "COLOR": "RED"
        }') AS EXTRACTED_CONFIGURATION_JSON,
        'MANUAL_SAMPLE' AS EXTRACTION_METHOD,
        'FUTURE_CORTEX_AI' AS EXTRACTION_MODEL_NAME,
        'PROMPT_V0_MANUAL_PLACEHOLDER' AS EXTRACTION_PROMPT_VERSION,
        PARSE_JSON('{
            "note": "Manual sample record. Cortex AI can replace this extraction later.",
            "source": "Phase 6A sample data"
        }') AS EXTRACTION_RAW_RESPONSE,
        'SYSTEM' AS CREATED_BY,
        TRUE AS ACTIVE_FLAG

    UNION ALL

    SELECT
        'RFQ_002',
        'SIM_RFQ_002',
        'KMAT_TRUCK_01',
        1,
        PARSE_JSON('{
            "ENGINE": "V8",
            "CAB": "PREMIUM",
            "WHEEL": "OFFROAD",
            "COLOR": "RED"
        }'),
        'MANUAL_SAMPLE',
        'FUTURE_CORTEX_AI',
        'PROMPT_V0_MANUAL_PLACEHOLDER',
        PARSE_JSON('{
            "note": "Engine was inferred from high-output requirement but customer wording was not fully explicit.",
            "source": "Phase 6A sample data"
        }'),
        'SYSTEM',
        TRUE

    UNION ALL

    SELECT
        'RFQ_003',
        'SIM_RFQ_003',
        'KMAT_TRUCK_01',
        1,
        PARSE_JSON('{
            "ENGINE": "V6",
            "CAB": "STANDARD",
            "WHEEL": "STANDARD",
            "COLOR": "BLUE"
        }'),
        'MANUAL_SAMPLE',
        'FUTURE_CORTEX_AI',
        'PROMPT_V0_MANUAL_PLACEHOLDER',
        PARSE_JSON('{
            "note": "Several configuration values are assumptions because RFQ text is vague.",
            "source": "Phase 6A sample data"
        }'),
        'SYSTEM',
        TRUE
) s
ON t.RFQ_ID = s.RFQ_ID
AND t.CONFIGURATION_VERSION = s.CONFIGURATION_VERSION
WHEN MATCHED THEN UPDATE SET
    t.SIMULATION_ID = s.SIMULATION_ID,
    t.KMAT_ID = s.KMAT_ID,
    t.EXTRACTED_CONFIGURATION_JSON = s.EXTRACTED_CONFIGURATION_JSON,
    t.EXTRACTION_METHOD = s.EXTRACTION_METHOD,
    t.EXTRACTION_MODEL_NAME = s.EXTRACTION_MODEL_NAME,
    t.EXTRACTION_PROMPT_VERSION = s.EXTRACTION_PROMPT_VERSION,
    t.EXTRACTION_RAW_RESPONSE = s.EXTRACTION_RAW_RESPONSE,
    t.CREATED_BY = s.CREATED_BY,
    t.ACTIVE_FLAG = s.ACTIVE_FLAG
WHEN NOT MATCHED THEN INSERT (
    RFQ_ID,
    SIMULATION_ID,
    KMAT_ID,
    CONFIGURATION_VERSION,
    EXTRACTED_CONFIGURATION_JSON,
    EXTRACTION_METHOD,
    EXTRACTION_MODEL_NAME,
    EXTRACTION_PROMPT_VERSION,
    EXTRACTION_RAW_RESPONSE,
    CREATED_BY,
    ACTIVE_FLAG
)
VALUES (
    s.RFQ_ID,
    s.SIMULATION_ID,
    s.KMAT_ID,
    s.CONFIGURATION_VERSION,
    s.EXTRACTED_CONFIGURATION_JSON,
    s.EXTRACTION_METHOD,
    s.EXTRACTION_MODEL_NAME,
    s.EXTRACTION_PROMPT_VERSION,
    s.EXTRACTION_RAW_RESPONSE,
    s.CREATED_BY,
    s.ACTIVE_FLAG
);

SELECT
    RFQ_ID,
    SIMULATION_ID,
    KMAT_ID,
    CONFIGURATION_VERSION,
    EXTRACTED_CONFIGURATION_JSON,
    EXTRACTED_CONFIGURATION_JSON:ENGINE::STRING AS ENGINE,
    EXTRACTED_CONFIGURATION_JSON:CAB::STRING AS CAB,
    EXTRACTED_CONFIGURATION_JSON:WHEEL::STRING AS WHEEL,
    EXTRACTED_CONFIGURATION_JSON:COLOR::STRING AS COLOR,
    EXTRACTION_METHOD,
    EXTRACTION_MODEL_NAME,
    ACTIVE_FLAG
FROM CORE_INPUT.RFQ_CONFIGURATION
ORDER BY RFQ_ID;

MERGE INTO CORE_INPUT.BOM_MATCH_ASSESSMENT t
USING (
    SELECT
        c.RFQ_ID,
        c.SIMULATION_ID,
        c.KMAT_ID,
        c.CONFIGURATION_VERSION,
        96.00 AS BOM_MATCH_CONFIDENCE_SCORE,
        r.REVIEW_STATUS,
        r.REVIEW_REQUIRED_FLAG,
        r.FINAL_TRUSTED_COST_ALLOWED_FLAG,
        NULL::VARCHAR AS REVIEWED_BY,
        NULL::TIMESTAMP_NTZ AS REVIEWED_AT,
        'MANUAL_SAMPLE_SCORE' AS ASSESSMENT_METHOD,
        'BMCS_RULES_V1' AS ASSESSMENT_VERSION,
        'High confidence match. RFQ clearly mentions heavy-duty red truck, premium cabin, terrain package, and high-output engine.' AS ASSESSMENT_NOTES
    FROM CORE_INPUT.RFQ_CONFIGURATION c
    JOIN CORE_INPUT.BMCS_REVIEW_RULES r
        ON 96.00 BETWEEN r.MIN_SCORE AND r.MAX_SCORE
       AND r.ACTIVE_FLAG = TRUE
    WHERE c.RFQ_ID = 'RFQ_001'
      AND c.CONFIGURATION_VERSION = 1

    UNION ALL

    SELECT
        c.RFQ_ID,
        c.SIMULATION_ID,
        c.KMAT_ID,
        c.CONFIGURATION_VERSION,
        78.00 AS BOM_MATCH_CONFIDENCE_SCORE,
        r.REVIEW_STATUS,
        r.REVIEW_REQUIRED_FLAG,
        r.FINAL_TRUSTED_COST_ALLOWED_FLAG,
        NULL::VARCHAR AS REVIEWED_BY,
        NULL::TIMESTAMP_NTZ AS REVIEWED_AT,
        'MANUAL_SAMPLE_SCORE' AS ASSESSMENT_METHOD,
        'BMCS_RULES_V1' AS ASSESSMENT_VERSION,
        'Medium confidence match. Premium and terrain requirements are clear, but engine requirement is inferred rather than explicitly stated.' AS ASSESSMENT_NOTES
    FROM CORE_INPUT.RFQ_CONFIGURATION c
    JOIN CORE_INPUT.BMCS_REVIEW_RULES r
        ON 78.00 BETWEEN r.MIN_SCORE AND r.MAX_SCORE
       AND r.ACTIVE_FLAG = TRUE
    WHERE c.RFQ_ID = 'RFQ_002'
      AND c.CONFIGURATION_VERSION = 1

    UNION ALL

    SELECT
        c.RFQ_ID,
        c.SIMULATION_ID,
        c.KMAT_ID,
        c.CONFIGURATION_VERSION,
        55.00 AS BOM_MATCH_CONFIDENCE_SCORE,
        r.REVIEW_STATUS,
        r.REVIEW_REQUIRED_FLAG,
        r.FINAL_TRUSTED_COST_ALLOWED_FLAG,
        NULL::VARCHAR AS REVIEWED_BY,
        NULL::TIMESTAMP_NTZ AS REVIEWED_AT,
        'MANUAL_SAMPLE_SCORE' AS ASSESSMENT_METHOD,
        'BMCS_RULES_V1' AS ASSESSMENT_VERSION,
        'Low confidence match. RFQ text is vague and several selected configuration values are assumptions.' AS ASSESSMENT_NOTES
    FROM CORE_INPUT.RFQ_CONFIGURATION c
    JOIN CORE_INPUT.BMCS_REVIEW_RULES r
        ON 55.00 BETWEEN r.MIN_SCORE AND r.MAX_SCORE
       AND r.ACTIVE_FLAG = TRUE
    WHERE c.RFQ_ID = 'RFQ_003'
      AND c.CONFIGURATION_VERSION = 1
) s
ON t.RFQ_ID = s.RFQ_ID
AND t.CONFIGURATION_VERSION = s.CONFIGURATION_VERSION
WHEN MATCHED THEN UPDATE SET
    t.SIMULATION_ID = s.SIMULATION_ID,
    t.KMAT_ID = s.KMAT_ID,
    t.BOM_MATCH_CONFIDENCE_SCORE = s.BOM_MATCH_CONFIDENCE_SCORE,
    t.REVIEW_STATUS = s.REVIEW_STATUS,
    t.REVIEW_REQUIRED_FLAG = s.REVIEW_REQUIRED_FLAG,
    t.FINAL_TRUSTED_COST_ALLOWED_FLAG = s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    t.REVIEWED_BY = s.REVIEWED_BY,
    t.REVIEWED_AT = s.REVIEWED_AT,
    t.ASSESSMENT_METHOD = s.ASSESSMENT_METHOD,
    t.ASSESSMENT_VERSION = s.ASSESSMENT_VERSION,
    t.ASSESSMENT_NOTES = s.ASSESSMENT_NOTES,
    t.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    RFQ_ID,
    SIMULATION_ID,
    KMAT_ID,
    CONFIGURATION_VERSION,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    REVIEWED_BY,
    REVIEWED_AT,
    ASSESSMENT_METHOD,
    ASSESSMENT_VERSION,
    ASSESSMENT_NOTES
)
VALUES (
    s.RFQ_ID,
    s.SIMULATION_ID,
    s.KMAT_ID,
    s.CONFIGURATION_VERSION,
    s.BOM_MATCH_CONFIDENCE_SCORE,
    s.REVIEW_STATUS,
    s.REVIEW_REQUIRED_FLAG,
    s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    s.REVIEWED_BY,
    s.REVIEWED_AT,
    s.ASSESSMENT_METHOD,
    s.ASSESSMENT_VERSION,
    s.ASSESSMENT_NOTES
);

SELECT
    RFQ_ID,
    SIMULATION_ID,
    KMAT_ID,
    CONFIGURATION_VERSION,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    ASSESSMENT_METHOD,
    ASSESSMENT_VERSION
FROM CORE_INPUT.BOM_MATCH_ASSESSMENT
ORDER BY RFQ_ID;

CREATE OR REPLACE VIEW CORE_INPUT.VW_RFQ_BMCS_STATUS AS
WITH LATEST_CONFIGURATION AS (
    SELECT
        RFQ_ID,
        SIMULATION_ID,
        KMAT_ID,
        CONFIGURATION_VERSION,
        EXTRACTED_CONFIGURATION_JSON,
        EXTRACTION_METHOD,
        EXTRACTION_MODEL_NAME,
        EXTRACTION_PROMPT_VERSION,
        CREATED_BY,
        ACTIVE_FLAG,
        CREATED_AT
    FROM CORE_INPUT.RFQ_CONFIGURATION
    WHERE ACTIVE_FLAG = TRUE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY RFQ_ID
        ORDER BY CONFIGURATION_VERSION DESC, CREATED_AT DESC
    ) = 1
),
LATEST_ASSESSMENT AS (
    SELECT
        RFQ_ID,
        SIMULATION_ID,
        KMAT_ID,
        CONFIGURATION_VERSION,
        BOM_MATCH_CONFIDENCE_SCORE,
        REVIEW_STATUS,
        REVIEW_REQUIRED_FLAG,
        FINAL_TRUSTED_COST_ALLOWED_FLAG,
        REVIEWED_BY,
        REVIEWED_AT,
        ASSESSMENT_METHOD,
        ASSESSMENT_VERSION,
        ASSESSMENT_NOTES,
        CREATED_AT,
        UPDATED_AT
    FROM CORE_INPUT.BOM_MATCH_ASSESSMENT
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY RFQ_ID
        ORDER BY CONFIGURATION_VERSION DESC, CREATED_AT DESC
    ) = 1
)
SELECT
    h.RFQ_ID,
    h.KMAT_ID,
    h.CUSTOMER_ID,
    h.CUSTOMER_NAME,
    h.SOURCE_DOCUMENT_NAME,
    h.SOURCE_DOCUMENT_TYPE,
    h.SOURCE_DOCUMENT_TEXT,
    h.DOCUMENT_STATUS,

    c.SIMULATION_ID,
    c.CONFIGURATION_VERSION,
    c.EXTRACTED_CONFIGURATION_JSON,
    c.EXTRACTED_CONFIGURATION_JSON:ENGINE::STRING AS ENGINE,
    c.EXTRACTED_CONFIGURATION_JSON:CAB::STRING AS CAB,
    c.EXTRACTED_CONFIGURATION_JSON:WHEEL::STRING AS WHEEL,
    c.EXTRACTED_CONFIGURATION_JSON:COLOR::STRING AS COLOR,
    c.EXTRACTION_METHOD,
    c.EXTRACTION_MODEL_NAME,
    c.EXTRACTION_PROMPT_VERSION,

    a.BOM_MATCH_CONFIDENCE_SCORE,
    a.REVIEW_STATUS,
    a.REVIEW_REQUIRED_FLAG,
    a.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    a.REVIEWED_BY,
    a.REVIEWED_AT,
    a.ASSESSMENT_METHOD,
    a.ASSESSMENT_VERSION,
    a.ASSESSMENT_NOTES,

    CASE
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 90 THEN 'AUTO_APPROVED'
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 70 THEN 'REVIEW_RECOMMENDED'
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE < 70 THEN 'REVIEW_REQUIRED'
        ELSE 'MISSING_ASSESSMENT'
    END AS EXPECTED_REVIEW_STATUS,

    CASE
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 90 THEN 'LOW_PROCESS_RISK'
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 70 THEN 'MEDIUM_PROCESS_RISK'
        WHEN a.BOM_MATCH_CONFIDENCE_SCORE < 70 THEN 'HIGH_PROCESS_RISK'
        ELSE 'UNKNOWN_PROCESS_RISK'
    END AS BMCS_RISK_LEVEL,

    CASE
        WHEN a.REVIEW_STATUS =
            CASE
                WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 90 THEN 'AUTO_APPROVED'
                WHEN a.BOM_MATCH_CONFIDENCE_SCORE >= 70 THEN 'REVIEW_RECOMMENDED'
                WHEN a.BOM_MATCH_CONFIDENCE_SCORE < 70 THEN 'REVIEW_REQUIRED'
                ELSE 'MISSING_ASSESSMENT'
            END
        THEN 'PASS'
        ELSE 'CHECK'
    END AS RULE_VALIDATION_STATUS

FROM CORE_INPUT.RFQ_HEADER h
LEFT JOIN LATEST_CONFIGURATION c
    ON h.RFQ_ID = c.RFQ_ID
   AND h.KMAT_ID = c.KMAT_ID
LEFT JOIN LATEST_ASSESSMENT a
    ON c.RFQ_ID = a.RFQ_ID
   AND c.SIMULATION_ID = a.SIMULATION_ID
   AND c.KMAT_ID = a.KMAT_ID
   AND c.CONFIGURATION_VERSION = a.CONFIGURATION_VERSION;

SELECT
    RFQ_ID,
    CUSTOMER_NAME,
    SOURCE_DOCUMENT_NAME,
    SIMULATION_ID,
    ENGINE,
    CAB,
    WHEEL,
    COLOR,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    BMCS_RISK_LEVEL,
    RULE_VALIDATION_STATUS
FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
ORDER BY RFQ_ID;

WITH EXTRACTED_CONFIG AS (
    SELECT
        c.RFQ_ID,
        c.SIMULATION_ID,
        c.KMAT_ID,
        f.KEY::STRING AS CHARACTERISTIC_NAME,
        f.VALUE::STRING AS SELECTED_VALUE
    FROM CORE_INPUT.RFQ_CONFIGURATION c,
         LATERAL FLATTEN(INPUT => c.EXTRACTED_CONFIGURATION_JSON) f
    WHERE c.ACTIVE_FLAG = TRUE
),
VALIDATION AS (
    SELECT
        e.RFQ_ID,
        e.SIMULATION_ID,
        e.KMAT_ID,
        e.CHARACTERISTIC_NAME,
        e.SELECTED_VALUE,
        cm.ALLOWED_VALUE,
        CASE
            WHEN cm.ALLOWED_VALUE IS NOT NULL THEN 'VALID'
            ELSE 'INVALID'
        END AS VALIDATION_STATUS
    FROM EXTRACTED_CONFIG e
    LEFT JOIN CORE_INPUT.CHARACTERISTIC_MASTER cm
        ON e.KMAT_ID = cm.KMAT_ID
       AND UPPER(e.CHARACTERISTIC_NAME) = UPPER(cm.CHARACTERISTIC_NAME)
       AND UPPER(e.SELECTED_VALUE) = UPPER(cm.ALLOWED_VALUE)
       AND cm.ACTIVE_FLAG = TRUE
)
SELECT *
FROM VALIDATION
ORDER BY RFQ_ID, CHARACTERISTIC_NAME;

SELECT
    a.RFQ_ID,
    a.SIMULATION_ID,
    a.BOM_MATCH_CONFIDENCE_SCORE,

    a.REVIEW_STATUS AS STORED_REVIEW_STATUS,
    r.REVIEW_STATUS AS EXPECTED_REVIEW_STATUS,

    a.REVIEW_REQUIRED_FLAG AS STORED_REVIEW_REQUIRED_FLAG,
    r.REVIEW_REQUIRED_FLAG AS EXPECTED_REVIEW_REQUIRED_FLAG,

    a.FINAL_TRUSTED_COST_ALLOWED_FLAG AS STORED_FINAL_COST_ALLOWED_FLAG,
    r.FINAL_TRUSTED_COST_ALLOWED_FLAG AS EXPECTED_FINAL_COST_ALLOWED_FLAG,

    CASE
        WHEN a.REVIEW_STATUS = r.REVIEW_STATUS
         AND a.REVIEW_REQUIRED_FLAG = r.REVIEW_REQUIRED_FLAG
         AND a.FINAL_TRUSTED_COST_ALLOWED_FLAG = r.FINAL_TRUSTED_COST_ALLOWED_FLAG
        THEN 'PASS'
        ELSE 'CHECK'
    END AS VALIDATION_STATUS

FROM CORE_INPUT.BOM_MATCH_ASSESSMENT a
JOIN CORE_INPUT.BMCS_REVIEW_RULES r
    ON a.BOM_MATCH_CONFIDENCE_SCORE BETWEEN r.MIN_SCORE AND r.MAX_SCORE
   AND r.ACTIVE_FLAG = TRUE
ORDER BY a.RFQ_ID;

SELECT
    a.RFQ_ID,
    a.SIMULATION_ID,
    a.BOM_MATCH_CONFIDENCE_SCORE,

    a.REVIEW_STATUS AS STORED_REVIEW_STATUS,
    r.REVIEW_STATUS AS EXPECTED_REVIEW_STATUS,

    a.REVIEW_REQUIRED_FLAG AS STORED_REVIEW_REQUIRED_FLAG,
    r.REVIEW_REQUIRED_FLAG AS EXPECTED_REVIEW_REQUIRED_FLAG,

    a.FINAL_TRUSTED_COST_ALLOWED_FLAG AS STORED_FINAL_COST_ALLOWED_FLAG,
    r.FINAL_TRUSTED_COST_ALLOWED_FLAG AS EXPECTED_FINAL_COST_ALLOWED_FLAG,

    CASE
        WHEN a.REVIEW_STATUS = r.REVIEW_STATUS
         AND a.REVIEW_REQUIRED_FLAG = r.REVIEW_REQUIRED_FLAG
         AND a.FINAL_TRUSTED_COST_ALLOWED_FLAG = r.FINAL_TRUSTED_COST_ALLOWED_FLAG
        THEN 'PASS'
        ELSE 'CHECK'
    END AS VALIDATION_STATUS

FROM CORE_INPUT.BOM_MATCH_ASSESSMENT a
JOIN CORE_INPUT.BMCS_REVIEW_RULES r
    ON a.BOM_MATCH_CONFIDENCE_SCORE BETWEEN r.MIN_SCORE AND r.MAX_SCORE
   AND r.ACTIVE_FLAG = TRUE
ORDER BY a.RFQ_ID;

SELECT
    RFQ_ID,
    CUSTOMER_NAME,
    SOURCE_DOCUMENT_NAME,

    EXTRACTED_CONFIGURATION_JSON,

    ENGINE,
    CAB,
    WHEEL,
    COLOR,

    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    BMCS_RISK_LEVEL,

    CASE
        WHEN REVIEW_STATUS = 'AUTO_APPROVED'
            THEN 'Configuration can automatically proceed to costing.'
        WHEN REVIEW_STATUS = 'REVIEW_RECOMMENDED'
            THEN 'Costing can proceed, but engineering review is recommended.'
        WHEN REVIEW_STATUS = 'REVIEW_REQUIRED'
            THEN 'Do not present final trusted cost until engineering review is completed.'
        ELSE 'BMCS assessment missing.'
    END AS BUSINESS_DECISION

FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
ORDER BY RFQ_ID;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE TABLE IF NOT EXISTS CORE_INPUT.BMCS_TEXT_SIGNAL_RULES (
    SIGNAL_RULE_ID          VARCHAR,
    KMAT_ID                 VARCHAR,
    CHARACTERISTIC_NAME     VARCHAR,
    CHARACTERISTIC_VALUE    VARCHAR,
    SIGNAL_PHRASE           VARCHAR,
    SIGNAL_WEIGHT           NUMBER(18,4),
    ACTIVE_FLAG             BOOLEAN,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO CORE_INPUT.BMCS_TEXT_SIGNAL_RULES t
USING (
    SELECT 'SIG_ENGINE_V8_001' AS SIGNAL_RULE_ID, 'KMAT_TRUCK_01' AS KMAT_ID, 'ENGINE' AS CHARACTERISTIC_NAME, 'V8' AS CHARACTERISTIC_VALUE, 'high-output engine' AS SIGNAL_PHRASE, 1.00 AS SIGNAL_WEIGHT, TRUE AS ACTIVE_FLAG
    UNION ALL SELECT 'SIG_ENGINE_V8_002', 'KMAT_TRUCK_01', 'ENGINE', 'V8', 'high output engine', 1.00, TRUE
    UNION ALL SELECT 'SIG_ENGINE_V8_003', 'KMAT_TRUCK_01', 'ENGINE', 'V8', 'heavy-duty', 0.90, TRUE
    UNION ALL SELECT 'SIG_ENGINE_V8_004', 'KMAT_TRUCK_01', 'ENGINE', 'V8', 'heavy duty', 0.90, TRUE
    UNION ALL SELECT 'SIG_ENGINE_V8_005', 'KMAT_TRUCK_01', 'ENGINE', 'V8', 'powerful engine', 0.80, TRUE

    UNION ALL SELECT 'SIG_ENGINE_V6_001', 'KMAT_TRUCK_01', 'ENGINE', 'V6', 'standard engine', 1.00, TRUE
    UNION ALL SELECT 'SIG_ENGINE_V6_002', 'KMAT_TRUCK_01', 'ENGINE', 'V6', 'regular engine', 0.80, TRUE
    UNION ALL SELECT 'SIG_ENGINE_V6_003', 'KMAT_TRUCK_01', 'ENGINE', 'V6', 'basic engine', 0.80, TRUE

    UNION ALL SELECT 'SIG_CAB_PREMIUM_001', 'KMAT_TRUCK_01', 'CAB', 'PREMIUM', 'premium cabin', 1.00, TRUE
    UNION ALL SELECT 'SIG_CAB_PREMIUM_002', 'KMAT_TRUCK_01', 'CAB', 'PREMIUM', 'premium cab', 1.00, TRUE
    UNION ALL SELECT 'SIG_CAB_PREMIUM_003', 'KMAT_TRUCK_01', 'CAB', 'PREMIUM', 'premium truck', 0.70, TRUE
    UNION ALL SELECT 'SIG_CAB_PREMIUM_004', 'KMAT_TRUCK_01', 'CAB', 'PREMIUM', 'luxury cabin', 0.90, TRUE

    UNION ALL SELECT 'SIG_CAB_STANDARD_001', 'KMAT_TRUCK_01', 'CAB', 'STANDARD', 'standard cabin', 1.00, TRUE
    UNION ALL SELECT 'SIG_CAB_STANDARD_002', 'KMAT_TRUCK_01', 'CAB', 'STANDARD', 'standard cab', 1.00, TRUE
    UNION ALL SELECT 'SIG_CAB_STANDARD_003', 'KMAT_TRUCK_01', 'CAB', 'STANDARD', 'basic cabin', 0.80, TRUE

    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_001', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'enhanced terrain package', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_002', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'terrain package', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_003', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'offroad', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_004', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'off-road', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_005', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'rough site conditions', 0.90, TRUE
    UNION ALL SELECT 'SIG_WHEEL_OFFROAD_006', 'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 'rough terrain', 0.90, TRUE

    UNION ALL SELECT 'SIG_WHEEL_STANDARD_001', 'KMAT_TRUCK_01', 'WHEEL', 'STANDARD', 'standard wheel', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_STANDARD_002', 'KMAT_TRUCK_01', 'WHEEL', 'STANDARD', 'standard wheels', 1.00, TRUE
    UNION ALL SELECT 'SIG_WHEEL_STANDARD_003', 'KMAT_TRUCK_01', 'WHEEL', 'STANDARD', 'regular transport', 0.60, TRUE

    UNION ALL SELECT 'SIG_COLOR_RED_001', 'KMAT_TRUCK_01', 'COLOR', 'RED', 'red', 1.00, TRUE
    UNION ALL SELECT 'SIG_COLOR_RED_002', 'KMAT_TRUCK_01', 'COLOR', 'RED', 'red color', 1.00, TRUE
    UNION ALL SELECT 'SIG_COLOR_RED_003', 'KMAT_TRUCK_01', 'COLOR', 'RED', 'red truck', 1.00, TRUE

    UNION ALL SELECT 'SIG_COLOR_BLUE_001', 'KMAT_TRUCK_01', 'COLOR', 'BLUE', 'blue', 1.00, TRUE
    UNION ALL SELECT 'SIG_COLOR_BLUE_002', 'KMAT_TRUCK_01', 'COLOR', 'BLUE', 'blue color', 1.00, TRUE
    UNION ALL SELECT 'SIG_COLOR_BLUE_003', 'KMAT_TRUCK_01', 'COLOR', 'BLUE', 'blue truck', 1.00, TRUE
) s
ON t.SIGNAL_RULE_ID = s.SIGNAL_RULE_ID
WHEN MATCHED THEN UPDATE SET
    t.KMAT_ID = s.KMAT_ID,
    t.CHARACTERISTIC_NAME = s.CHARACTERISTIC_NAME,
    t.CHARACTERISTIC_VALUE = s.CHARACTERISTIC_VALUE,
    t.SIGNAL_PHRASE = s.SIGNAL_PHRASE,
    t.SIGNAL_WEIGHT = s.SIGNAL_WEIGHT,
    t.ACTIVE_FLAG = s.ACTIVE_FLAG,
    t.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    SIGNAL_RULE_ID,
    KMAT_ID,
    CHARACTERISTIC_NAME,
    CHARACTERISTIC_VALUE,
    SIGNAL_PHRASE,
    SIGNAL_WEIGHT,
    ACTIVE_FLAG
)
VALUES (
    s.SIGNAL_RULE_ID,
    s.KMAT_ID,
    s.CHARACTERISTIC_NAME,
    s.CHARACTERISTIC_VALUE,
    s.SIGNAL_PHRASE,
    s.SIGNAL_WEIGHT,
    s.ACTIVE_FLAG
);

SELECT
    KMAT_ID,
    CHARACTERISTIC_NAME,
    CHARACTERISTIC_VALUE,
    SIGNAL_PHRASE,
    SIGNAL_WEIGHT
FROM CORE_INPUT.BMCS_TEXT_SIGNAL_RULES
WHERE ACTIVE_FLAG = TRUE
ORDER BY CHARACTERISTIC_NAME, CHARACTERISTIC_VALUE, SIGNAL_PHRASE;

CREATE TABLE IF NOT EXISTS CORE_INPUT.BMCS_SCORING_DETAIL (
    RFQ_ID                       VARCHAR,
    SIMULATION_ID                VARCHAR,
    KMAT_ID                      VARCHAR,
    CONFIGURATION_VERSION        NUMBER(10,0),
    CHARACTERISTIC_NAME          VARCHAR,
    EXTRACTED_VALUE              VARCHAR,
    VALID_VALUE_FLAG             BOOLEAN,
    MATCHED_SIGNAL_FLAG          BOOLEAN,
    MATCHED_SIGNAL_PHRASES       VARCHAR,
    CHARACTERISTIC_SCORE_NOTES   VARCHAR,
    CREATED_AT                   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
DESC TABLE CORE_INPUT.BMCS_SCORING_DETAIL;


CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING(RFQ_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS
$$
import json
import re
from datetime import datetime


DB_NAME = "KMAT_COST_MODEL_DB"


def sql_escape(value):
    if value is None:
        return ""
    return str(value).replace("'", "''")


def normalize_text(value):
    if value is None:
        return ""
    return str(value).strip().upper()


def normalize_for_matching(value):
    if value is None:
        return ""
    text = str(value).lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def parse_variant(value):
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        try:
            return json.loads(value)
        except Exception:
            return {}

    try:
        return dict(value)
    except Exception:
        return {}


def bool_to_sql(value):
    return "TRUE" if value else "FALSE"


def insert_detail_row(
    session,
    rfq_id,
    simulation_id,
    kmat_id,
    configuration_version,
    characteristic_name,
    extracted_value,
    valid_value_flag,
    matched_signal_flag,
    matched_signal_phrases,
    notes
):
    session.sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.BMCS_SCORING_DETAIL
        (
            RFQ_ID,
            SIMULATION_ID,
            KMAT_ID,
            CONFIGURATION_VERSION,
            CHARACTERISTIC_NAME,
            EXTRACTED_VALUE,
            VALID_VALUE_FLAG,
            MATCHED_SIGNAL_FLAG,
            MATCHED_SIGNAL_PHRASES,
            CHARACTERISTIC_SCORE_NOTES
        )
        VALUES
        (
            '{sql_escape(rfq_id)}',
            '{sql_escape(simulation_id)}',
            '{sql_escape(kmat_id)}',
            {int(configuration_version)},
            '{sql_escape(characteristic_name)}',
            '{sql_escape(extracted_value)}',
            {bool_to_sql(valid_value_flag)},
            {bool_to_sql(matched_signal_flag)},
            '{sql_escape(matched_signal_phrases)}',
            '{sql_escape(notes)}'
        )
    """).collect()


def run(session, RFQ_ID):
    rfq_id = sql_escape(RFQ_ID)
    now = datetime.utcnow()

    # ------------------------------------------------------------
    # 1. Load RFQ + active extracted configuration
    # ------------------------------------------------------------
    rows = session.sql(f"""
        SELECT
            h.RFQ_ID,
            h.KMAT_ID,
            h.CUSTOMER_ID,
            h.CUSTOMER_NAME,
            h.SOURCE_DOCUMENT_NAME,
            h.SOURCE_DOCUMENT_TEXT,
            c.SIMULATION_ID,
            c.CONFIGURATION_VERSION,
            TO_JSON(c.EXTRACTED_CONFIGURATION_JSON) AS EXTRACTED_CONFIGURATION_JSON_STR
        FROM {DB_NAME}.CORE_INPUT.RFQ_HEADER h
        JOIN {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION c
            ON h.RFQ_ID = c.RFQ_ID
           AND h.KMAT_ID = c.KMAT_ID
        WHERE h.RFQ_ID = '{rfq_id}'
          AND c.ACTIVE_FLAG = TRUE
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY h.RFQ_ID
            ORDER BY c.CONFIGURATION_VERSION DESC, c.CREATED_AT DESC
        ) = 1
    """).collect()

    if len(rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"No active RFQ configuration found for RFQ_ID={RFQ_ID}"
        })

    row = rows[0]

    kmat_id = row["KMAT_ID"]
    simulation_id = row["SIMULATION_ID"]
    configuration_version = int(row["CONFIGURATION_VERSION"])
    source_text = row["SOURCE_DOCUMENT_TEXT"] or ""
    source_text_normalized = normalize_for_matching(source_text)
    extracted_config = parse_variant(row["EXTRACTED_CONFIGURATION_JSON_STR"])

    # ------------------------------------------------------------
    # 2. Load required KMAT characteristics and allowed values
    # ------------------------------------------------------------
    allowed_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            ALLOWED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_MASTER
        WHERE KMAT_ID = '{sql_escape(kmat_id)}'
          AND ACTIVE_FLAG = TRUE
        ORDER BY DISPLAY_ORDER, CHARACTERISTIC_NAME, ALLOWED_VALUE
    """).collect()

    allowed_map = {}
    for r in allowed_rows:
        characteristic_name = normalize_text(r["CHARACTERISTIC_NAME"])
        allowed_value = normalize_text(r["ALLOWED_VALUE"])

        if characteristic_name not in allowed_map:
            allowed_map[characteristic_name] = set()

        allowed_map[characteristic_name].add(allowed_value)

    required_characteristics = list(allowed_map.keys())
    required_count = len(required_characteristics)

    if required_count == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"No active KMAT characteristics found for KMAT_ID={kmat_id}"
        })

    # ------------------------------------------------------------
    # 3. Load active signal rules
    # ------------------------------------------------------------
    signal_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            CHARACTERISTIC_VALUE,
            SIGNAL_PHRASE,
            SIGNAL_WEIGHT
        FROM {DB_NAME}.CORE_INPUT.BMCS_TEXT_SIGNAL_RULES
        WHERE KMAT_ID = '{sql_escape(kmat_id)}'
          AND ACTIVE_FLAG = TRUE
    """).collect()

    signal_rules = []
    for r in signal_rows:
        signal_rules.append({
            "characteristic_name": normalize_text(r["CHARACTERISTIC_NAME"]),
            "characteristic_value": normalize_text(r["CHARACTERISTIC_VALUE"]),
            "signal_phrase_original": str(r["SIGNAL_PHRASE"]),
            "signal_phrase_normalized": normalize_for_matching(r["SIGNAL_PHRASE"]),
            "signal_weight": float(r["SIGNAL_WEIGHT"] or 0)
        })

    # ------------------------------------------------------------
    # 4. Remove previous detail rows for this RFQ/config version
    # ------------------------------------------------------------
    session.sql(f"""
        DELETE FROM {DB_NAME}.CORE_INPUT.BMCS_SCORING_DETAIL
        WHERE RFQ_ID = '{rfq_id}'
          AND CONFIGURATION_VERSION = {configuration_version}
    """).collect()

    # ------------------------------------------------------------
    # 5. Score characteristic validity and text evidence
    # ------------------------------------------------------------
    valid_count = 0
    evidence_count = 0

    detail_results = []

    for characteristic_name in required_characteristics:
        extracted_value = normalize_text(extracted_config.get(characteristic_name))

        valid_value_flag = (
            extracted_value != ""
            and extracted_value in allowed_map.get(characteristic_name, set())
        )

        matched_phrases = []

        if valid_value_flag:
            valid_count += 1

            for rule in signal_rules:
                if (
                    rule["characteristic_name"] == characteristic_name
                    and rule["characteristic_value"] == extracted_value
                    and rule["signal_phrase_normalized"] != ""
                    and rule["signal_phrase_normalized"] in source_text_normalized
                ):
                    matched_phrases.append(rule["signal_phrase_original"])

        matched_signal_flag = len(matched_phrases) > 0

        if matched_signal_flag:
            evidence_count += 1
            notes = "Extracted value is valid and supported by RFQ text."
        elif valid_value_flag:
            notes = "Extracted value is valid, but direct text evidence was not found. Treated as inferred."
        else:
            notes = "Extracted value is missing or invalid for this KMAT characteristic."

        matched_signal_phrases = ", ".join(sorted(set(matched_phrases)))

        insert_detail_row(
            session=session,
            rfq_id=RFQ_ID,
            simulation_id=simulation_id,
            kmat_id=kmat_id,
            configuration_version=configuration_version,
            characteristic_name=characteristic_name,
            extracted_value=extracted_value,
            valid_value_flag=valid_value_flag,
            matched_signal_flag=matched_signal_flag,
            matched_signal_phrases=matched_signal_phrases,
            notes=notes
        )

        detail_results.append({
            "characteristic_name": characteristic_name,
            "extracted_value": extracted_value,
            "valid_value_flag": valid_value_flag,
            "matched_signal_flag": matched_signal_flag,
            "matched_signal_phrases": matched_signal_phrases
        })

    # ------------------------------------------------------------
    # 6. Calculate BMCS
    # ------------------------------------------------------------
    valid_ratio = valid_count / required_count
    evidence_ratio = evidence_count / required_count

    validity_component = valid_ratio * 55.00
    evidence_component = evidence_ratio * 41.00

    ambiguity_penalty = 0.00
    ambiguity_terms = [
        "not fully specified",
        "not specified",
        "unclear",
        "not clear",
        "unknown",
        "not confirmed"
    ]

    matched_ambiguity_terms = []
    for term in ambiguity_terms:
        if normalize_for_matching(term) in source_text_normalized:
            matched_ambiguity_terms.append(term)

    if len(matched_ambiguity_terms) > 0:
        ambiguity_penalty = 7.75

    bmcs_score = validity_component + evidence_component - ambiguity_penalty
    bmcs_score = max(0.00, min(100.00, bmcs_score))
    bmcs_score = round(bmcs_score, 2)

    # ------------------------------------------------------------
    # 7. Apply BMCS review rule
    # ------------------------------------------------------------
    review_rows = session.sql(f"""
        SELECT
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            BUSINESS_ACTION
        FROM {DB_NAME}.CORE_INPUT.BMCS_REVIEW_RULES
        WHERE {bmcs_score} BETWEEN MIN_SCORE AND MAX_SCORE
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(review_rows) == 0:
        review_status = "REVIEW_REQUIRED"
        review_required_flag = True
        final_trusted_cost_allowed_flag = False
        business_action = "BMCS review rule missing. Defaulted to engineering review required."
    else:
        review_status = review_rows[0]["REVIEW_STATUS"]
        review_required_flag = bool(review_rows[0]["REVIEW_REQUIRED_FLAG"])
        final_trusted_cost_allowed_flag = bool(review_rows[0]["FINAL_TRUSTED_COST_ALLOWED_FLAG"])
        business_action = review_rows[0]["BUSINESS_ACTION"]

    assessment_notes = (
        f"Rule-based BMCS scoring completed. "
        f"Required characteristics={required_count}; "
        f"Valid extracted values={valid_count}; "
        f"Text-supported values={evidence_count}; "
        f"Validity component={round(validity_component, 2)}; "
        f"Evidence component={round(evidence_component, 2)}; "
        f"Ambiguity penalty={round(ambiguity_penalty, 2)}; "
        f"Matched ambiguity terms={', '.join(matched_ambiguity_terms) if matched_ambiguity_terms else 'None'}; "
        f"Business action={business_action}"
    )

    # ------------------------------------------------------------
    # 8. Upsert into BOM_MATCH_ASSESSMENT
    # ------------------------------------------------------------
    session.sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.BOM_MATCH_ASSESSMENT t
        USING (
            SELECT
                '{sql_escape(RFQ_ID)}' AS RFQ_ID,
                '{sql_escape(simulation_id)}' AS SIMULATION_ID,
                '{sql_escape(kmat_id)}' AS KMAT_ID,
                {configuration_version} AS CONFIGURATION_VERSION,
                {bmcs_score} AS BOM_MATCH_CONFIDENCE_SCORE,
                '{sql_escape(review_status)}' AS REVIEW_STATUS,
                {bool_to_sql(review_required_flag)} AS REVIEW_REQUIRED_FLAG,
                {bool_to_sql(final_trusted_cost_allowed_flag)} AS FINAL_TRUSTED_COST_ALLOWED_FLAG,
                NULL::VARCHAR AS REVIEWED_BY,
                NULL::TIMESTAMP_NTZ AS REVIEWED_AT,
                'RULE_BASED_TEXT_MATCH' AS ASSESSMENT_METHOD,
                'BMCS_RULE_ENGINE_V1' AS ASSESSMENT_VERSION,
                '{sql_escape(assessment_notes)}' AS ASSESSMENT_NOTES
        ) s
        ON t.RFQ_ID = s.RFQ_ID
           AND t.CONFIGURATION_VERSION = s.CONFIGURATION_VERSION
        WHEN MATCHED THEN UPDATE SET
            t.SIMULATION_ID = s.SIMULATION_ID,
            t.KMAT_ID = s.KMAT_ID,
            t.BOM_MATCH_CONFIDENCE_SCORE = s.BOM_MATCH_CONFIDENCE_SCORE,
            t.REVIEW_STATUS = s.REVIEW_STATUS,
            t.REVIEW_REQUIRED_FLAG = s.REVIEW_REQUIRED_FLAG,
            t.FINAL_TRUSTED_COST_ALLOWED_FLAG = s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
            t.REVIEWED_BY = s.REVIEWED_BY,
            t.REVIEWED_AT = s.REVIEWED_AT,
            t.ASSESSMENT_METHOD = s.ASSESSMENT_METHOD,
            t.ASSESSMENT_VERSION = s.ASSESSMENT_VERSION,
            t.ASSESSMENT_NOTES = s.ASSESSMENT_NOTES,
            t.UPDATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            RFQ_ID,
            SIMULATION_ID,
            KMAT_ID,
            CONFIGURATION_VERSION,
            BOM_MATCH_CONFIDENCE_SCORE,
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            REVIEWED_BY,
            REVIEWED_AT,
            ASSESSMENT_METHOD,
            ASSESSMENT_VERSION,
            ASSESSMENT_NOTES
        )
        VALUES (
            s.RFQ_ID,
            s.SIMULATION_ID,
            s.KMAT_ID,
            s.CONFIGURATION_VERSION,
            s.BOM_MATCH_CONFIDENCE_SCORE,
            s.REVIEW_STATUS,
            s.REVIEW_REQUIRED_FLAG,
            s.FINAL_TRUSTED_COST_ALLOWED_FLAG,
            s.REVIEWED_BY,
            s.REVIEWED_AT,
            s.ASSESSMENT_METHOD,
            s.ASSESSMENT_VERSION,
            s.ASSESSMENT_NOTES
        )
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "rfq_id": RFQ_ID,
        "simulation_id": simulation_id,
        "kmat_id": kmat_id,
        "configuration_version": configuration_version,
        "required_characteristics": required_count,
        "valid_extracted_values": valid_count,
        "text_supported_values": evidence_count,
        "validity_component": round(validity_component, 2),
        "evidence_component": round(evidence_component, 2),
        "ambiguity_penalty": round(ambiguity_penalty, 2),
        "matched_ambiguity_terms": matched_ambiguity_terms,
        "bom_match_confidence_score": bmcs_score,
        "review_status": review_status,
        "review_required_flag": review_required_flag,
        "final_trusted_cost_allowed_flag": final_trusted_cost_allowed_flag
    })
$$;
SHOW PROCEDURES LIKE 'RUN_RULE_BASED_BMCS_SCORING'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_INTERNAL;

CALL CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('RFQ_001');

CALL CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('RFQ_002');

CALL CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('RFQ_003');

SELECT
    RFQ_ID,
    SIMULATION_ID,
    KMAT_ID,
    ENGINE,
    CAB,
    WHEEL,
    COLOR,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    BMCS_RISK_LEVEL,
    RULE_VALIDATION_STATUS
FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
ORDER BY RFQ_ID;

SELECT
    RFQ_ID,
    SIMULATION_ID,
    CHARACTERISTIC_NAME,
    EXTRACTED_VALUE,
    VALID_VALUE_FLAG,
    MATCHED_SIGNAL_FLAG,
    MATCHED_SIGNAL_PHRASES,
    CHARACTERISTIC_SCORE_NOTES
FROM CORE_INPUT.BMCS_SCORING_DETAIL
ORDER BY RFQ_ID, CHARACTERISTIC_NAME;

-- Step 10: Validate assessment notes
SELECT
    RFQ_ID,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    ASSESSMENT_METHOD,
    ASSESSMENT_VERSION,
    ASSESSMENT_NOTES
FROM CORE_INPUT.BOM_MATCH_ASSESSMENT
ORDER BY RFQ_ID;

-- PHASE C
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_OUTPUT;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RFQ_ID VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SOURCE_DOCUMENT_NAME VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_CONFIGURATION_VERSION NUMBER(10,0);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BOM_MATCH_CONFIDENCE_SCORE NUMBER(5,2);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_REVIEW_STATUS VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_REVIEW_REQUIRED_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS FINAL_TRUSTED_COST_ALLOWED_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS QUOTE_TRUST_STATUS VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_ASSESSMENT_METHOD VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_ASSESSMENT_VERSION VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BMCS_ASSESSMENT_NOTES VARCHAR;

DESC TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;
CREATE OR REPLACE PROCEDURE CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS(RFQ_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS
$$
import json
import re


DB_NAME = "KMAT_COST_MODEL_DB"


def sql_escape(value):
    if value is None:
        return ""
    return str(value).replace("'", "''")


def normalize_text(value):
    if value is None:
        return ""
    return str(value).strip().upper()


def parse_json(value):
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        try:
            return json.loads(value)
        except Exception:
            return {}

    try:
        return dict(value)
    except Exception:
        return {}


def run(session, RFQ_ID):
    rfq_id = sql_escape(RFQ_ID)

    rows = session.sql(f"""
        SELECT
            h.RFQ_ID,
            h.KMAT_ID,
            h.CUSTOMER_ID,
            h.CUSTOMER_NAME,
            h.SOURCE_DOCUMENT_NAME,
            c.SIMULATION_ID,
            c.CONFIGURATION_VERSION,
            TO_JSON(c.EXTRACTED_CONFIGURATION_JSON) AS CONFIG_JSON_STR
        FROM {DB_NAME}.CORE_INPUT.RFQ_HEADER h
        JOIN {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION c
            ON h.RFQ_ID = c.RFQ_ID
           AND h.KMAT_ID = c.KMAT_ID
        WHERE h.RFQ_ID = '{rfq_id}'
          AND c.ACTIVE_FLAG = TRUE
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY h.RFQ_ID
            ORDER BY c.CONFIGURATION_VERSION DESC, c.CREATED_AT DESC
        ) = 1
    """).collect()

    if len(rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"No active RFQ configuration found for RFQ_ID={RFQ_ID}"
        })

    row = rows[0]

    kmat_id = row["KMAT_ID"]
    simulation_id = row["SIMULATION_ID"]
    customer_id = row["CUSTOMER_ID"]
    source_document_name = row["SOURCE_DOCUMENT_NAME"]
    config_json = parse_json(row["CONFIG_JSON_STR"])

    if not config_json:
        return json.dumps({
            "status": "ERROR",
            "message": f"Extracted configuration JSON is empty for RFQ_ID={RFQ_ID}"
        })

    allowed_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            ALLOWED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_MASTER
        WHERE KMAT_ID = '{sql_escape(kmat_id)}'
          AND ACTIVE_FLAG = TRUE
    """).collect()

    allowed_map = {}
    for r in allowed_rows:
        char_name = normalize_text(r["CHARACTERISTIC_NAME"])
        allowed_value = normalize_text(r["ALLOWED_VALUE"])

        if char_name not in allowed_map:
            allowed_map[char_name] = set()

        allowed_map[char_name].add(allowed_value)

    selected_values = {}

    for char_name in allowed_map.keys():
        extracted_value = normalize_text(config_json.get(char_name))

        if extracted_value == "":
            return json.dumps({
                "status": "ERROR",
                "message": f"Missing extracted value for required characteristic {char_name}",
                "rfq_id": RFQ_ID,
                "simulation_id": simulation_id
            })

        if extracted_value not in allowed_map[char_name]:
            return json.dumps({
                "status": "ERROR",
                "message": f"Invalid extracted value {extracted_value} for characteristic {char_name}",
                "rfq_id": RFQ_ID,
                "simulation_id": simulation_id
            })

        selected_values[char_name] = extracted_value

    sim_lit = "'" + sql_escape(simulation_id) + "'"

    session.sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES WHERE SIMULATION_ID = {sim_lit}").collect()
    session.sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_PARAMETERS WHERE SIMULATION_ID = {sim_lit}").collect()
    session.sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT WHERE SIMULATION_ID = {sim_lit}").collect()
    session.sql(f"DELETE FROM {DB_NAME}.CORE_INPUT.SIMULATION_HEADER WHERE SIMULATION_ID = {sim_lit}").collect()

    scenario_name = f"RFQ Cost Simulation - {RFQ_ID} - {source_document_name}"

    session.sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.SIMULATION_HEADER
        (
            SIMULATION_ID,
            KMAT_ID,
            CUSTOMER_ID,
            SCENARIO_NAME
        )
        VALUES
        (
            '{sql_escape(simulation_id)}',
            '{sql_escape(kmat_id)}',
            '{sql_escape(customer_id)}',
            '{sql_escape(scenario_name)}'
        )
    """).collect()

    value_rows = []
    for char_name, selected_value in selected_values.items():
        value_rows.append(
            f"('{sql_escape(simulation_id)}', '{sql_escape(kmat_id)}', '{sql_escape(char_name)}', '{sql_escape(selected_value)}')"
        )

    session.sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        (
            SIMULATION_ID,
            KMAT_ID,
            CHARACTERISTIC_NAME,
            SELECTED_VALUE
        )
        VALUES
        {", ".join(value_rows)}
    """).collect()

    session.sql(f"""
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
            '{sql_escape(simulation_id)}',
            1.00,
            1.00,
            1.00,
            1.00,
            0.35,
            0.10,
            0.60
        )
    """).collect()

    session.sql(f"""
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
            '{sql_escape(simulation_id)}',
            '{sql_escape(kmat_id)}',
            'PLANT_US_01',
            'TRUCK_LINE_01',
            '2026-09-15',
            10
        )
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "rfq_id": RFQ_ID,
        "simulation_id": simulation_id,
        "kmat_id": kmat_id,
        "selected_values": selected_values,
        "message": "RFQ extracted configuration copied into normal simulation input tables."
    })
$$;

-- COST_SIMULATION
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
    if value is None:
        return ""
    return str(value).replace("'", "''")


def to_float(value, default=0.0):
    if value is None:
        return default
    try:
        return float(value)
    except Exception:
        return default


def parse_rule(rule_obj):
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
    if value is None:
        return ""
    return str(value).strip().upper()


def evaluate_rule(rule_obj, selections):
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
    if not rows:
        return

    df = session.create_dataframe(rows, schema=schema)
    df.write.mode("append").save_as_table(table_name_parts, column_order="name")


def load_bmcs_status(session, sim_id):
    """
    BMCS is optional for manual simulations.
    If a simulation is linked to RFQ_CONFIGURATION, the procedure tries to refresh BMCS first.
    """
    rfq_rows = session.sql(f"""
        SELECT
            RFQ_ID
        FROM {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION
        WHERE SIMULATION_ID = '{sql_escape(sim_id)}'
          AND ACTIVE_FLAG = TRUE
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY SIMULATION_ID
            ORDER BY CONFIGURATION_VERSION DESC, CREATED_AT DESC
        ) = 1
    """).collect()

    if len(rfq_rows) > 0:
        linked_rfq_id = rfq_rows[0]["RFQ_ID"]

        try:
            session.sql(f"""
                CALL {DB_NAME}.CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('{sql_escape(linked_rfq_id)}')
            """).collect()
        except Exception:
            pass

    rows = session.sql(f"""
        SELECT
            a.RFQ_ID,
            h.SOURCE_DOCUMENT_NAME,
            a.CONFIGURATION_VERSION,
            a.BOM_MATCH_CONFIDENCE_SCORE,
            a.REVIEW_STATUS,
            a.REVIEW_REQUIRED_FLAG,
            a.FINAL_TRUSTED_COST_ALLOWED_FLAG,
            a.ASSESSMENT_METHOD,
            a.ASSESSMENT_VERSION,
            a.ASSESSMENT_NOTES
        FROM {DB_NAME}.CORE_INPUT.BOM_MATCH_ASSESSMENT a
        LEFT JOIN {DB_NAME}.CORE_INPUT.RFQ_HEADER h
            ON a.RFQ_ID = h.RFQ_ID
           AND a.KMAT_ID = h.KMAT_ID
        WHERE a.SIMULATION_ID = '{sql_escape(sim_id)}'
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY a.SIMULATION_ID
            ORDER BY a.CONFIGURATION_VERSION DESC, a.CREATED_AT DESC
        ) = 1
    """).collect()

    if len(rows) == 0:
        return {
            "rfq_id": None,
            "source_document_name": None,
            "configuration_version": None,
            "bmcs_score": None,
            "review_status": "NOT_APPLICABLE",
            "review_required_flag": False,
            "final_trusted_cost_allowed_flag": True,
            "quote_trust_status": "TRUSTED_MANUAL_CONFIGURATION",
            "assessment_method": "NOT_APPLICABLE",
            "assessment_version": "NOT_APPLICABLE",
            "assessment_notes": "No RFQ/BMCS assessment linked to this simulation. Treated as manually configured trusted simulation."
        }

    row = rows[0]

    review_status = row["REVIEW_STATUS"]
    review_required_flag = bool(row["REVIEW_REQUIRED_FLAG"])
    final_allowed = bool(row["FINAL_TRUSTED_COST_ALLOWED_FLAG"])
    bmcs_score = to_float(row["BOM_MATCH_CONFIDENCE_SCORE"], 0.0)

    if review_status == "AUTO_APPROVED" and final_allowed:
        quote_trust_status = "TRUSTED_AUTO_APPROVED"
    elif review_status == "REVIEW_RECOMMENDED" and final_allowed:
        quote_trust_status = "TRUSTED_WITH_REVIEW_RECOMMENDED"
    elif review_required_flag or not final_allowed:
        quote_trust_status = "PRELIMINARY_ENGINEERING_REVIEW_REQUIRED"
    else:
        quote_trust_status = "BMCS_STATUS_CHECK_REQUIRED"

    return {
        "rfq_id": row["RFQ_ID"],
        "source_document_name": row["SOURCE_DOCUMENT_NAME"],
        "configuration_version": row["CONFIGURATION_VERSION"],
        "bmcs_score": bmcs_score,
        "review_status": review_status,
        "review_required_flag": review_required_flag,
        "final_trusted_cost_allowed_flag": final_allowed,
        "quote_trust_status": quote_trust_status,
        "assessment_method": row["ASSESSMENT_METHOD"],
        "assessment_version": row["ASSESSMENT_VERSION"],
        "assessment_notes": row["ASSESSMENT_NOTES"]
    }


def calculate_css(session, sim_id, kmat_id, selections):
    scrap_rule_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            CHARACTERISTIC_VALUE,
            SCORE_POINTS
        FROM {DB_NAME}.CORE_INPUT.SCRAP_SCORE_RULES
        WHERE KMAT_ID = '{sql_escape(kmat_id)}'
          AND ACTIVE_FLAG = TRUE
    """).collect()

    css_score = 0.0

    for row in scrap_rule_rows:
        characteristic = normalize_text(row["CHARACTERISTIC_NAME"])
        value = normalize_text(row["CHARACTERISTIC_VALUE"])
        points = to_float(row["SCORE_POINTS"], 0.0)

        if characteristic == "BASE" and value == "BASE":
            css_score += points
        elif selections.get(characteristic) == value:
            css_score += points

    css_score = min(css_score, 100.0)

    band_rows = session.sql(f"""
        SELECT
            SCRAP_RATE,
            RISK_LEVEL
        FROM {DB_NAME}.CORE_INPUT.SCRAP_SCORE_BANDS
        WHERE {css_score} BETWEEN MIN_SCORE AND MAX_SCORE
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(band_rows) == 0:
        return css_score, 0.0, "UNKNOWN"

    scrap_rate = to_float(band_rows[0]["SCRAP_RATE"], 0.0)
    risk_level = band_rows[0]["RISK_LEVEL"]

    return css_score, scrap_rate, risk_level


def load_production_context(session, sim_id):
    rows = session.sql(f"""
        SELECT
            TO_VARCHAR(DATE_TRUNC('MONTH', PLANNED_PRODUCTION_DATE), 'YYYY-MM-DD') AS FORECAST_MONTH_STR
        FROM {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
        WHERE SIMULATION_ID = '{sql_escape(sim_id)}'
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return None

    return rows[0]["FORECAST_MONTH_STR"]


def load_forecast_map(session, forecast_month_str):
    if forecast_month_str is None:
        return {}

    rows = session.sql(f"""
        SELECT
            COMMODITY_GROUP,
            FORWARD_MATERIAL_INDEX
        FROM {DB_NAME}.CORE_INPUT.MATERIAL_INDEX_FORECASTS
        WHERE FORECAST_MONTH = TO_DATE('{sql_escape(forecast_month_str)}')
    """).collect()

    result = {}
    for row in rows:
        result[normalize_text(row["COMMODITY_GROUP"])] = to_float(row["FORWARD_MATERIAL_INDEX"], 1.0)

    return result


def load_component_attributes(session):
    rows = session.sql(f"""
        SELECT
            COMPONENT_ID,
            SCRAP_APPLICABLE_FLAG,
            COMMODITY_SENSITIVE_FLAG,
            DEFAULT_COMMODITY_GROUP
        FROM {DB_NAME}.CORE_INPUT.COMPONENT_COST_ATTRIBUTES
    """).collect()

    result = {}
    for row in rows:
        component_id = row["COMPONENT_ID"]
        result[component_id] = {
            "scrap_applicable": bool(row["SCRAP_APPLICABLE_FLAG"]),
            "commodity_sensitive": bool(row["COMMODITY_SENSITIVE_FLAG"]),
            "default_commodity": normalize_text(row["DEFAULT_COMMODITY_GROUP"])
        }

    return result


def load_commodity_exposure(session):
    rows = session.sql(f"""
        SELECT
            COMPONENT_ID,
            COMMODITY_GROUP,
            EXPOSURE_PERCENT
        FROM {DB_NAME}.CORE_INPUT.COMPONENT_COMMODITY_EXPOSURE
    """).collect()

    result = {}
    for row in rows:
        component_id = row["COMPONENT_ID"]
        if component_id not in result:
            result[component_id] = []

        result[component_id].append({
            "commodity_group": normalize_text(row["COMMODITY_GROUP"]),
            "exposure_percent": to_float(row["EXPOSURE_PERCENT"], 0.0)
        })

    return result


def get_weighted_fmis(component_id, attr, exposure_map, forecast_map, forecast_month_str):
    if attr is not None and attr.get("commodity_sensitive") is False:
        return 1.0, False

    exposures = exposure_map.get(component_id, [])

    if not exposures:
        default_commodity = ""
        if attr is not None:
            default_commodity = attr.get("default_commodity", "")

        if default_commodity != "" and default_commodity in forecast_map:
            return forecast_map.get(default_commodity, 1.0), False

        return 1.0, True

    weighted_fmis = 0.0
    fallback_used = False

    for exposure in exposures:
        commodity = exposure["commodity_group"]
        exposure_percent = exposure["exposure_percent"]

        if forecast_month_str is None or commodity not in forecast_map:
            fmis = 1.0
            fallback_used = True
        else:
            fmis = forecast_map.get(commodity, 1.0)

        weighted_fmis += exposure_percent * fmis

    if weighted_fmis <= 0:
        return 1.0, True

    return weighted_fmis, fallback_used


def load_work_center_breakdown(session):
    rows = session.sql(f"""
        SELECT
            WORK_CENTER_ID,
            OPERATING_RATE_USD_PER_HOUR,
            MAINTENANCE_RATE_USD_PER_HOUR
        FROM {DB_NAME}.CORE_INPUT.WORK_CENTER_COST_BREAKDOWN
    """).collect()

    result = {}
    for row in rows:
        result[row["WORK_CENTER_ID"]] = {
            "operating_rate": to_float(row["OPERATING_RATE_USD_PER_HOUR"], 0.0),
            "maintenance_rate": to_float(row["MAINTENANCE_RATE_USD_PER_HOUR"], 0.0)
        }

    return result


def load_tds_map(session):
    rows = session.sql(f"""
        SELECT
            OPERATION_ID,
            TDS_FACTOR
        FROM {DB_NAME}.CORE_INPUT.OPERATION_TDS_RULES
        WHERE ACTIVE_FLAG = TRUE
    """).collect()

    result = {}
    for row in rows:
        result[row["OPERATION_ID"]] = to_float(row["TDS_FACTOR"], 1.0)

    return result


def run(session, SIMULATION_ID):
    sim_id = sql_escape(SIMULATION_ID)
    calculated_at = datetime.utcnow()

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

    bmcs = load_bmcs_status(session, SIMULATION_ID)

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

    css_score, scrap_rate_applied, scrap_risk_level = calculate_css(
        session,
        SIMULATION_ID,
        kmat_id,
        selections
    )

    forecast_month_str = load_production_context(session, SIMULATION_ID)
    forecast_map = load_forecast_map(session, forecast_month_str)
    component_attr_map = load_component_attributes(session)
    exposure_map = load_commodity_exposure(session)
    work_center_breakdown = load_work_center_breakdown(session)
    tds_map = load_tds_map(session)

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

    baseline_material_total = 0.0
    risk_adjusted_material_total = 0.0
    commodity_adjustment_total = 0.0
    scrap_adjustment_total = 0.0

    selected_component_count = 0
    missing_material_cost_count = 0
    fmis_weighted_sum = 0.0

    for row in bom_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_component_count += 1

            component_id = row["COMPONENT_ID"]
            attr = component_attr_map.get(component_id)

            if attr is None:
                scrap_applicable = False
                risk_notes = "Component attributes missing; scrap disabled; FMIS fallback may apply."
            else:
                scrap_applicable = bool(attr.get("scrap_applicable", False))
                risk_notes = "Risk inputs applied from Phase 5A tables."

            quantity = to_float(row["QUANTITY"], 0.0)

            cost_missing = row["COST_ITEM_ID"] is None or row["STANDARD_COST_USD"] is None
            if cost_missing:
                missing_material_cost_count += 1

            standard_cost = to_float(row["STANDARD_COST_USD"], 0.0)

            weighted_fmis, fmis_fallback_flag = get_weighted_fmis(
                component_id,
                attr,
                exposure_map,
                forecast_map,
                forecast_month_str
            )

            component_scrap_rate = scrap_rate_applied if scrap_applicable else 0.0

            base_quantity = quantity
            scrap_adjusted_quantity = quantity * (1.0 + component_scrap_rate)

            base_standard_cost = standard_cost

            base_line_material_cost = quantity * standard_cost * material_multiplier
            forward_unit_cost = standard_cost * material_multiplier * weighted_fmis
            fmis_adjusted_line_cost = base_line_material_cost * weighted_fmis
            commodity_adjustment = fmis_adjusted_line_cost - base_line_material_cost

            adjusted_line_material_cost = fmis_adjusted_line_cost * (1.0 + component_scrap_rate)
            scrap_adjustment = adjusted_line_material_cost - fmis_adjusted_line_cost

            baseline_material_total += base_line_material_cost
            risk_adjusted_material_total += adjusted_line_material_cost
            commodity_adjustment_total += commodity_adjustment
            scrap_adjustment_total += scrap_adjustment

            if base_line_material_cost > 0:
                fmis_weighted_sum += base_line_material_cost * weighted_fmis

            full_notes = (
                f"CSS={round(css_score, 4)}, "
                f"Risk={scrap_risk_level}, "
                f"ScrapApplicable={scrap_applicable}, "
                f"FMIS={round(weighted_fmis, 6)}, "
                f"FMISFallback={fmis_fallback_flag}. "
                f"{risk_notes}"
            )

            component_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                component_id,
                row["COMPONENT_DESCRIPTION"],
                quantity,
                row["UOM"],
                row["RULE_ID"],
                bool(row["IS_BULK_MATERIAL"]),
                row["COST_COMPONENT_GROUP"],
                standard_cost,
                base_line_material_cost,
                bool(cost_missing),
                calculated_at,

                base_quantity,
                bool(scrap_applicable),
                css_score,
                component_scrap_rate,
                scrap_adjusted_quantity,
                base_standard_cost,
                weighted_fmis,
                forward_unit_cost,
                base_line_material_cost,
                commodity_adjustment,
                scrap_adjustment,
                adjusted_line_material_cost,
                bool(fmis_fallback_flag),
                full_notes
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
            "CALCULATED_AT",

            "BASE_QUANTITY",
            "SCRAP_APPLICABLE_FLAG",
            "CSS_SCORE",
            "SCRAP_RATE_APPLIED",
            "SCRAP_ADJUSTED_QUANTITY",
            "BASE_STANDARD_COST_USD",
            "WEIGHTED_FMIS",
            "FORWARD_UNIT_COST_USD",
            "BASE_LINE_MATERIAL_COST_USD",
            "COMMODITY_ADJUSTMENT_USD",
            "SCRAP_ADJUSTMENT_USD",
            "ADJUSTED_LINE_MATERIAL_COST_USD",
            "FMIS_FALLBACK_FLAG",
            "RISK_ADJUSTMENT_NOTES"
        ]
    )

    avg_weighted_fmis = 1.0
    if baseline_material_total > 0:
        avg_weighted_fmis = fmis_weighted_sum / baseline_material_total

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

    baseline_labor_total = 0.0
    baseline_machine_total = 0.0
    risk_adjusted_machine_total = 0.0
    tooling_adjustment_total = 0.0

    selected_operation_count = 0
    max_tds_factor = 1.0

    for row in routing_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_operation_count += 1

            operation_id = row["OPERATION_ID"]
            work_center_id = row["WORK_CENTER_ID"]

            labor_hours = to_float(row["LABOR_HOURS"], 0.0)
            machine_hours = to_float(row["MACHINE_HOURS"], 0.0)

            labor_rate = to_float(row["LABOR_RATE_USD_PER_HOUR"], 0.0)
            base_machine_rate = to_float(row["MACHINE_RATE_USD_PER_HOUR"], 0.0)

            labor_cost = labor_hours * labor_rate * labor_multiplier
            base_machine_cost = machine_hours * base_machine_rate * machine_multiplier

            if work_center_id in work_center_breakdown:
                operating_rate = work_center_breakdown[work_center_id]["operating_rate"]
                maintenance_rate = work_center_breakdown[work_center_id]["maintenance_rate"]
                breakdown_fallback = False
            else:
                operating_rate = base_machine_rate
                maintenance_rate = 0.0
                breakdown_fallback = True

            if operation_id in tds_map:
                tds_factor = tds_map[operation_id]
                tds_fallback_flag = False
            else:
                tds_factor = 1.0
                tds_fallback_flag = True

            adjusted_machine_rate = operating_rate + (maintenance_rate * tds_factor)
            adjusted_machine_cost = machine_hours * adjusted_machine_rate * machine_multiplier
            tooling_adjustment = adjusted_machine_cost - base_machine_cost

            baseline_labor_total += labor_cost
            baseline_machine_total += base_machine_cost
            risk_adjusted_machine_total += adjusted_machine_cost
            tooling_adjustment_total += tooling_adjustment

            max_tds_factor = max(max_tds_factor, tds_factor)

            notes = (
                f"TDS={round(tds_factor, 6)}, "
                f"BreakdownFallback={breakdown_fallback}, "
                f"TDSFallback={tds_fallback_flag}."
            )

            operation_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                operation_id,
                row["OPERATION_DESCRIPTION"],
                work_center_id,
                labor_hours,
                machine_hours,
                labor_rate,
                base_machine_rate,
                labor_cost,
                base_machine_cost,
                row["RULE_ID"],
                calculated_at,

                base_machine_rate,
                operating_rate,
                maintenance_rate,
                tds_factor,
                base_machine_cost,
                adjusted_machine_rate,
                tooling_adjustment,
                adjusted_machine_cost,
                bool(tds_fallback_flag),
                notes
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
            "CALCULATED_AT",

            "BASE_MACHINE_RATE_USD_PER_HOUR",
            "OPERATING_RATE_USD_PER_HOUR",
            "MAINTENANCE_RATE_USD_PER_HOUR",
            "TDS_FACTOR",
            "BASE_MACHINE_COST_USD",
            "ADJUSTED_MACHINE_RATE_USD_PER_HOUR",
            "TOOLING_ADJUSTMENT_USD",
            "ADJUSTED_MACHINE_COST_USD",
            "TDS_FALLBACK_FLAG",
            "RISK_ADJUSTMENT_NOTES"
        ]
    )

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

    baseline_overhead_total = 0.0
    risk_adjusted_overhead_total = 0.0
    overhead_adjustment_total = 0.0

    selected_overhead_count = 0

    for row in overhead_rows:
        rule_json = row["RULE_JSON"]

        if evaluate_rule(rule_json, selections):
            selected_overhead_count += 1

            basis = normalize_text(row["BASIS"])
            rate_value = to_float(row["RATE_VALUE"], 0.0)

            if basis == "MATERIAL_PERCENT":
                base_basis_cost = baseline_material_total
                adjusted_basis_cost = risk_adjusted_material_total
                base_overhead_cost = base_basis_cost * rate_value
                adjusted_overhead_cost = adjusted_basis_cost * rate_value

            elif basis == "LABOR_PERCENT":
                base_basis_cost = baseline_labor_total
                adjusted_basis_cost = baseline_labor_total
                base_overhead_cost = base_basis_cost * rate_value
                adjusted_overhead_cost = adjusted_basis_cost * rate_value

            elif basis == "MACHINE_PERCENT":
                base_basis_cost = baseline_machine_total
                adjusted_basis_cost = risk_adjusted_machine_total
                base_overhead_cost = base_basis_cost * rate_value
                adjusted_overhead_cost = adjusted_basis_cost * rate_value

            elif basis == "TOTAL_COST_PERCENT":
                base_basis_cost = baseline_material_total + baseline_labor_total + baseline_machine_total
                adjusted_basis_cost = risk_adjusted_material_total + baseline_labor_total + risk_adjusted_machine_total
                base_overhead_cost = base_basis_cost * rate_value
                adjusted_overhead_cost = adjusted_basis_cost * rate_value

            elif basis == "FIXED":
                base_basis_cost = rate_value
                adjusted_basis_cost = rate_value
                base_overhead_cost = rate_value
                adjusted_overhead_cost = rate_value

            else:
                base_basis_cost = 0.0
                adjusted_basis_cost = 0.0
                base_overhead_cost = 0.0
                adjusted_overhead_cost = 0.0

            base_overhead_cost = base_overhead_cost * overhead_multiplier
            adjusted_overhead_cost = adjusted_overhead_cost * overhead_multiplier

            overhead_adjustment = adjusted_overhead_cost - base_overhead_cost

            baseline_overhead_total += base_overhead_cost
            risk_adjusted_overhead_total += adjusted_overhead_cost
            overhead_adjustment_total += overhead_adjustment

            notes = (
                f"Basis={basis}, "
                f"BaseBasis={round(base_basis_cost, 4)}, "
                f"AdjustedBasis={round(adjusted_basis_cost, 4)}."
            )

            overhead_output_rows.append((
                SIMULATION_ID,
                row["KMAT_ID"],
                row["OVERHEAD_ID"],
                row["OVERHEAD_DESCRIPTION"],
                row["BASIS"],
                rate_value,
                base_overhead_cost,
                row["RULE_ID"],
                calculated_at,

                base_overhead_cost,
                adjusted_basis_cost,
                adjusted_overhead_cost,
                overhead_adjustment,
                True,
                notes
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
            "CALCULATED_AT",

            "BASE_OVERHEAD_COST_USD",
            "OVERHEAD_CALCULATION_BASIS_COST_USD",
            "ADJUSTED_OVERHEAD_COST_USD",
            "OVERHEAD_ADJUSTMENT_USD",
            "RISK_ADJUSTED_FLAG",
            "RISK_ADJUSTMENT_NOTES"
        ]
    )

    baseline_total_cost = (
        baseline_material_total
        + baseline_labor_total
        + baseline_machine_total
        + baseline_overhead_total
    )

    risk_adjusted_total_cost = (
        risk_adjusted_material_total
        + baseline_labor_total
        + risk_adjusted_machine_total
        + risk_adjusted_overhead_total
    )

    total_risk_uplift = risk_adjusted_total_cost - baseline_total_cost

    if baseline_total_cost == 0:
        total_risk_uplift_pct = 0.0
    else:
        total_risk_uplift_pct = (total_risk_uplift / baseline_total_cost) * 100.0

    floor_price = baseline_total_cost * (1.0 + floor_markup_pct)
    target_price = baseline_total_cost * (1.0 + target_margin_pct)
    ceiling_price = baseline_total_cost * (1.0 + ceiling_markup_pct)

    summary_notes = (
        f"Phase 6C BMCS + Phase 5C CSS/FMIS/TDS enabled. "
        f"QuoteTrustStatus={bmcs['quote_trust_status']}; "
        f"BMCS={bmcs['bmcs_score']}; "
        f"BMCSReviewStatus={bmcs['review_status']}; "
        f"FinalTrustedCostAllowed={bmcs['final_trusted_cost_allowed_flag']}; "
        f"ForecastMonth={forecast_month_str if forecast_month_str is not None else 'MISSING_CONTEXT'}; "
        f"CSS={round(css_score, 4)}; "
        f"ScrapRate={round(scrap_rate_applied, 6)}; "
        f"RiskLevel={scrap_risk_level}; "
        f"AvgFMIS={round(avg_weighted_fmis, 6)}; "
        f"MaxTDS={round(max_tds_factor, 6)}."
    )

    summary_rows = [(
        SIMULATION_ID,
        kmat_id,
        baseline_material_total,
        baseline_labor_total,
        baseline_machine_total,
        baseline_overhead_total,
        baseline_total_cost,
        floor_price,
        target_price,
        ceiling_price,
        calculated_at,

        baseline_material_total,
        baseline_labor_total,
        baseline_machine_total,
        baseline_overhead_total,
        baseline_total_cost,
        css_score,
        scrap_rate_applied,
        scrap_risk_level,
        avg_weighted_fmis,
        max_tds_factor,
        commodity_adjustment_total,
        scrap_adjustment_total,
        tooling_adjustment_total,
        overhead_adjustment_total,
        risk_adjusted_material_total,
        baseline_labor_total,
        risk_adjusted_machine_total,
        risk_adjusted_overhead_total,
        risk_adjusted_total_cost,
        total_risk_uplift,
        total_risk_uplift_pct,
        "CSS_FMIS_TDS_BMCS_RULE_BASED_V1",
        "SUCCESS",
        summary_notes,

        bmcs["rfq_id"],
        bmcs["source_document_name"],
        bmcs["configuration_version"],
        bmcs["bmcs_score"],
        bmcs["review_status"],
        bmcs["review_required_flag"],
        bmcs["final_trusted_cost_allowed_flag"],
        bmcs["quote_trust_status"],
        bmcs["assessment_method"],
        bmcs["assessment_version"],
        bmcs["assessment_notes"]
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
            "CALCULATED_AT",

            "BASELINE_MATERIAL_COST_USD",
            "BASELINE_LABOR_COST_USD",
            "BASELINE_MACHINE_COST_USD",
            "BASELINE_OVERHEAD_COST_USD",
            "BASELINE_TOTAL_COST_USD",
            "CSS_SCORE",
            "SCRAP_RATE_APPLIED",
            "SCRAP_RISK_LEVEL",
            "AVG_WEIGHTED_FMIS",
            "MAX_TDS_FACTOR",
            "COMMODITY_ADJUSTMENT_USD",
            "SCRAP_ADJUSTMENT_USD",
            "TOOLING_ADJUSTMENT_USD",
            "OVERHEAD_ADJUSTMENT_USD",
            "RISK_ADJUSTED_MATERIAL_COST_USD",
            "RISK_ADJUSTED_LABOR_COST_USD",
            "RISK_ADJUSTED_MACHINE_COST_USD",
            "RISK_ADJUSTED_OVERHEAD_COST_USD",
            "RISK_ADJUSTED_TOTAL_COST_USD",
            "TOTAL_RISK_UPLIFT_USD",
            "TOTAL_RISK_UPLIFT_PCT",
            "RISK_MODEL_VERSION",
            "RISK_CALCULATION_STATUS",
            "RISK_CALCULATION_NOTES",

            "RFQ_ID",
            "SOURCE_DOCUMENT_NAME",
            "BMCS_CONFIGURATION_VERSION",
            "BOM_MATCH_CONFIDENCE_SCORE",
            "BMCS_REVIEW_STATUS",
            "BMCS_REVIEW_REQUIRED_FLAG",
            "FINAL_TRUSTED_COST_ALLOWED_FLAG",
            "QUOTE_TRUST_STATUS",
            "BMCS_ASSESSMENT_METHOD",
            "BMCS_ASSESSMENT_VERSION",
            "BMCS_ASSESSMENT_NOTES"
        ]
    )

    return json.dumps({
        "status": "SUCCESS",
        "simulation_id": SIMULATION_ID,
        "kmat_id": kmat_id,

        "rfq_id": bmcs["rfq_id"],
        "bom_match_confidence_score": bmcs["bmcs_score"],
        "bmcs_review_status": bmcs["review_status"],
        "bmcs_review_required_flag": bmcs["review_required_flag"],
        "final_trusted_cost_allowed_flag": bmcs["final_trusted_cost_allowed_flag"],
        "quote_trust_status": bmcs["quote_trust_status"],

        "selected_components": selected_component_count,
        "selected_operations": selected_operation_count,
        "selected_overheads": selected_overhead_count,
        "missing_material_cost_count": missing_material_cost_count,

        "baseline_total_cost_usd": round(baseline_total_cost, 4),
        "risk_adjusted_total_cost_usd": round(risk_adjusted_total_cost, 4),
        "total_risk_uplift_usd": round(total_risk_uplift, 4),
        "total_risk_uplift_pct": round(total_risk_uplift_pct, 4),

        "css_score": round(css_score, 4),
        "scrap_rate_applied": round(scrap_rate_applied, 6),
        "scrap_risk_level": scrap_risk_level,
        "avg_weighted_fmis": round(avg_weighted_fmis, 6),
        "max_tds_factor": round(max_tds_factor, 6)
    })
$$;

CALL CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS('RFQ_001');

CALL CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('SIM_RFQ_001');

SELECT
    SIMULATION_ID,
    RFQ_ID,
    SOURCE_DOCUMENT_NAME,
    BOM_MATCH_CONFIDENCE_SCORE,
    BMCS_REVIEW_STATUS,
    BMCS_REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    QUOTE_TRUST_STATUS,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD,
    TOTAL_RISK_UPLIFT_USD,
    TOTAL_RISK_UPLIFT_PCT
FROM CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID = 'SIM_RFQ_001';

CALL CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS('RFQ_002');
CALL CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('SIM_RFQ_002');
SELECT
    SIMULATION_ID,
    RFQ_ID,
    BOM_MATCH_CONFIDENCE_SCORE,
    BMCS_REVIEW_STATUS,
    BMCS_REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    QUOTE_TRUST_STATUS,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD
FROM CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID = 'SIM_RFQ_002';

CALL CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS('RFQ_003');
CALL CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('SIM_RFQ_003');
SELECT
    SIMULATION_ID,
    RFQ_ID,
    BOM_MATCH_CONFIDENCE_SCORE,
    BMCS_REVIEW_STATUS,
    BMCS_REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    QUOTE_TRUST_STATUS,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD
FROM CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID = 'SIM_RFQ_003';

SELECT
    SIMULATION_ID,
    RFQ_ID,
    BOM_MATCH_CONFIDENCE_SCORE,
    BMCS_REVIEW_STATUS,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    QUOTE_TRUST_STATUS,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD,
    TOTAL_RISK_UPLIFT_PCT
FROM CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID IN ('SIM_RFQ_001', 'SIM_RFQ_002', 'SIM_RFQ_003')
ORDER BY SIMULATION_ID;