USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE STAGE CORE_INPUT.RFQ_DOC_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS SOURCE_STAGE_NAME VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS SOURCE_STAGE_RELATIVE_PATH VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS ORIGINAL_DOCUMENT_TEXT VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS PROCESSING_TEXT_EN VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS RFQ_SUMMARY VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS SOURCE_LANGUAGE_CODE VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS TARGET_LANGUAGE_CODE VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS TRANSLATION_METHOD VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS TEXT_EXTRACTION_METHOD VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS RFQ_COMPLEXITY_CATEGORY VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS RFQ_COMPLEXITY_REASON VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS CORTEX_PROCESSING_STATUS VARCHAR;

ALTER TABLE CORE_INPUT.RFQ_HEADER
ADD COLUMN IF NOT EXISTS CORTEX_PROCESSED_AT TIMESTAMP_NTZ;

CREATE TABLE IF NOT EXISTS CORE_INPUT.CORTEX_MODEL_CONFIG (
    CONFIG_KEY      VARCHAR,
    CONFIG_VALUE    VARCHAR,
    ACTIVE_FLAG     BOOLEAN,
    UPDATED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO CORE_INPUT.CORTEX_MODEL_CONFIG t
USING (
    SELECT
        'AI_COMPLETE_MODEL' AS CONFIG_KEY,
        'snowflake-arctic' AS CONFIG_VALUE,
        TRUE AS ACTIVE_FLAG
) s
ON t.CONFIG_KEY = s.CONFIG_KEY
WHEN MATCHED THEN UPDATE SET
    t.CONFIG_VALUE = s.CONFIG_VALUE,
    t.ACTIVE_FLAG = s.ACTIVE_FLAG,
    t.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    CONFIG_KEY,
    CONFIG_VALUE,
    ACTIVE_FLAG
)
VALUES (
    s.CONFIG_KEY,
    s.CONFIG_VALUE,
    s.ACTIVE_FLAG
);

SELECT *
FROM CORE_INPUT.CORTEX_MODEL_CONFIG;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_RFQ_INTAKE_PIPELINE(RFQ_ID STRING)
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
import base64


DB_NAME = "KMAT_COST_MODEL_DB"
RFQ_STAGE_NAME = "KMAT_COST_MODEL_DB.CORE_INPUT.RFQ_DOC_STAGE"


def sql_escape(value):
    if value is None:
        return ""
    return str(value).replace("'", "''")


def normalize_text(value):
    if value is None:
        return ""
    return str(value).strip().upper()


def normalize_id(value):
    cleaned = normalize_text(value)
    cleaned = re.sub(r"[^A-Z0-9_]+", "_", cleaned)
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")
    if cleaned == "":
        cleaned = "UNKNOWN"
    return cleaned[:60]


def parse_json_safe(value):
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


def get_nested(obj, key):
    if not isinstance(obj, dict):
        return None

    if key in obj:
        return obj[key]

    for k, v in obj.items():
        if str(k).upper() == str(key).upper():
            return v

    return None


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def map_to_allowed(characteristic_name, raw_value, allowed_values):
    raw = normalize_text(raw_value)

    if raw in allowed_values:
        return raw

    if characteristic_name == "ENGINE":
        if "V8" in raw:
            return "V8"
        if "HIGH" in raw or "POWER" in raw or "HEAVY" in raw or "DUTY" in raw:
            return "V8"
        if "V6" in raw:
            return "V6"
        if "STANDARD" in raw or "REGULAR" in raw or "BASIC" in raw:
            return "V6"

    if characteristic_name == "CAB":
        if "PREMIUM" in raw or "LUXURY" in raw or "ENHANCED" in raw:
            return "PREMIUM"
        if "STANDARD" in raw or "REGULAR" in raw or "BASIC" in raw:
            return "STANDARD"

    if characteristic_name == "WHEEL":
        if "OFFROAD" in raw or "OFF-ROAD" in raw or "TERRAIN" in raw or "ROUGH" in raw:
            return "OFFROAD"
        if "STANDARD" in raw or "REGULAR" in raw or "NORMAL" in raw:
            return "STANDARD"

    if characteristic_name == "COLOR":
        if "RED" in raw:
            return "RED"
        if "BLUE" in raw:
            return "BLUE"

    return "UNKNOWN"


def extract_text_from_stage_file(session, relative_path):
    response_format = {
        "RFQ_TEXT": (
            "Extract the complete readable customer RFQ/specification text from this document. "
            "Preserve technical requirements, configuration descriptions, colors, engine/cab/wheel references, and any customer notes. "
            "Do not summarize here. Return the readable text as one string."
        )
    }

    response_format_json = json.dumps(response_format)

    rows = session.sql(f"""
        SELECT TO_JSON(
            AI_EXTRACT(
                file => TO_FILE('@{RFQ_STAGE_NAME}', '{sql_escape(relative_path)}'),
                responseFormat => PARSE_JSON('{sql_escape(response_format_json)}'),
                scores => FALSE
            )
        ) AS DOC_TEXT_EXTRACTION_JSON
    """).collect()

    if len(rows) == 0:
        return "", {}

    raw_json = rows[0]["DOC_TEXT_EXTRACTION_JSON"]
    raw_obj = parse_json_safe(raw_json)
    response_obj = get_nested(raw_obj, "response")

    if response_obj is None:
        response_obj = raw_obj

    rfq_text = get_nested(response_obj, "RFQ_TEXT")
    if rfq_text is None:
        rfq_text = ""

    return str(rfq_text), raw_obj


def translate_to_english(session, source_text, source_language_code):
    source_lang = str(source_language_code or "").strip().lower()

    if source_lang in ("en", "english"):
        return source_text, "NOT_REQUIRED_ENGLISH_SOURCE", {}

    source_lang_sql = source_lang
    if source_lang in ("", "auto", "auto_detect", "detect"):
        source_lang_sql = ""

    rows = session.sql(f"""
        SELECT AI_TRANSLATE(
            '{sql_escape(source_text)}',
            '{sql_escape(source_lang_sql)}',
            'en'
        ) AS TRANSLATED_TEXT
    """).collect()

    if len(rows) == 0 or rows[0]["TRANSLATED_TEXT"] is None:
        return source_text, "TRANSLATION_FAILED_FALLBACK_TO_ORIGINAL", {}

    translated_text = rows[0]["TRANSLATED_TEXT"]

    return translated_text, "AI_TRANSLATE_TO_EN", {
        "source_language_code": source_language_code,
        "target_language_code": "en"
    }


def summarize_rfq(session, english_text):
    try:
        rows = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.SUMMARIZE('{sql_escape(english_text)}') AS RFQ_SUMMARY
        """).collect()

        if len(rows) == 0 or rows[0]["RFQ_SUMMARY"] is None:
            return ""

        return rows[0]["RFQ_SUMMARY"]

    except Exception as exc:
        return f"Summary generation failed: {str(exc)}"


def classify_rfq(session, english_text):
    try:
        rows = session.sql(f"""
            SELECT TO_JSON(
                AI_CLASSIFY(
                    '{sql_escape(english_text)}',
                    ARRAY_CONSTRUCT(
                        'STANDARD_CONFIGURATION',
                        'CUSTOM_CONFIGURATION',
                        'INCOMPLETE_REQUIREMENT',
                        'ENGINEERING_REVIEW_REQUIRED'
                    )
                )
            ) AS CLASSIFICATION_JSON
        """).collect()

        if len(rows) == 0:
            return "UNKNOWN", "AI_CLASSIFY returned no result.", {}

        raw_json = rows[0]["CLASSIFICATION_JSON"]
        obj = parse_json_safe(raw_json)

        label = "UNKNOWN"

        if isinstance(obj, dict):
            if "label" in obj:
                label = str(obj.get("label"))
            elif "labels" in obj and isinstance(obj.get("labels"), list) and len(obj.get("labels")) > 0:
                label = str(obj.get("labels")[0])
            elif "classification" in obj:
                label = str(obj.get("classification"))

        reason = f"Cortex classified the RFQ as {label}."
        return label, reason, obj

    except Exception as exc:
        return "UNKNOWN", f"AI_CLASSIFY failed: {str(exc)}", {}


def extract_kmat_configuration(session, english_text):
    response_format = {
        "ENGINE": (
            "Extract the best matching ENGINE option for KMAT_TRUCK_01. "
            "Allowed values are V6 and V8. "
            "Map high-output engine, powerful engine, heavy-duty engine, heavy-duty requirement, performance engine to V8. "
            "Map standard engine, regular engine, basic engine to V6. "
            "If engine cannot be determined, return UNKNOWN. "
            "Return only one value: V6, V8, or UNKNOWN."
        ),
        "CAB": (
            "Extract the best matching CAB option for KMAT_TRUCK_01. "
            "Allowed values are STANDARD and PREMIUM. "
            "Map premium cabin, premium cab, luxury cabin, enhanced cabin to PREMIUM. "
            "Map standard cabin, standard cab, basic cabin to STANDARD. "
            "If cab cannot be determined, return UNKNOWN. "
            "Return only one value: STANDARD, PREMIUM, or UNKNOWN."
        ),
        "WHEEL": (
            "Extract the best matching WHEEL option for KMAT_TRUCK_01. "
            "Allowed values are STANDARD and OFFROAD. "
            "Map enhanced terrain package, terrain package, offroad, off-road, rough site conditions, rough terrain to OFFROAD. "
            "Map standard wheels, regular transport, normal road usage to STANDARD. "
            "If wheel package cannot be determined, return UNKNOWN. "
            "Return only one value: STANDARD, OFFROAD, or UNKNOWN."
        ),
        "COLOR": (
            "Extract the best matching COLOR option for KMAT_TRUCK_01. "
            "Allowed values are RED and BLUE. "
            "If red is mentioned, return RED. If blue is mentioned, return BLUE. "
            "If color cannot be determined, return UNKNOWN. "
            "Return only one value: RED, BLUE, or UNKNOWN."
        )
    }

    response_format_json = json.dumps(response_format)

    rows = session.sql(f"""
        SELECT TO_JSON(
            AI_EXTRACT(
                text => '{sql_escape(english_text)}',
                responseFormat => PARSE_JSON('{sql_escape(response_format_json)}'),
                scores => TRUE
            )
        ) AS CONFIG_EXTRACTION_JSON
    """).collect()

    if len(rows) == 0:
        return {}, {}

    raw_json = rows[0]["CONFIG_EXTRACTION_JSON"]
    raw_obj = parse_json_safe(raw_json)
    response_obj = get_nested(raw_obj, "response")

    if response_obj is None:
        response_obj = raw_obj

    if not isinstance(response_obj, dict):
        response_obj = {}

    return response_obj, raw_obj


def generate_extraction_reasoning(session, model_name, english_text, normalized_config, rfq_summary, complexity_category):
    prompt = f"""
You are assisting a manufacturing KMAT cost model.

Explain why the following RFQ was mapped to the extracted KMAT configuration.
Do not invent new values.
Do not calculate cost.
Use simple business language.

RFQ summary:
{rfq_summary}

Extracted configuration:
{json.dumps(normalized_config)}

RFQ complexity category:
{complexity_category}

Original RFQ text:
{english_text[:4000]}
"""

    try:
        rows = session.sql(f"""
            SELECT AI_COMPLETE(
                '{sql_escape(model_name)}',
                '{sql_escape(prompt)}'
            ) AS EXTRACTION_REASONING
        """).collect()

        if len(rows) == 0 or rows[0]["EXTRACTION_REASONING"] is None:
            return "AI_COMPLETE returned no reasoning."

        return rows[0]["EXTRACTION_REASONING"]

    except Exception as exc:
        return f"AI_COMPLETE reasoning failed: {str(exc)}"


def run(session, RFQ_ID):
    rfq_id = sql_escape(RFQ_ID)

    # ------------------------------------------------------------
    # 1. Load RFQ header
    # ------------------------------------------------------------
    rfq_rows = session.sql(f"""
        SELECT
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
            SOURCE_LANGUAGE_CODE
        FROM {DB_NAME}.CORE_INPUT.RFQ_HEADER
        WHERE RFQ_ID = '{rfq_id}'
        LIMIT 1
    """).collect()

    if len(rfq_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"RFQ_ID {RFQ_ID} not found in CORE_INPUT.RFQ_HEADER"
        })

    rfq = rfq_rows[0]
    kmat_id = rfq["KMAT_ID"]

    source_document_text = rfq["SOURCE_DOCUMENT_TEXT"]
    source_stage_relative_path = rfq["SOURCE_STAGE_RELATIVE_PATH"]
    source_language_code = rfq["SOURCE_LANGUAGE_CODE"] or "en"

    document_text_extraction_raw = {}

    # ------------------------------------------------------------
    # 2. Get original RFQ text from pasted text or uploaded file
    # ------------------------------------------------------------
    if source_document_text is not None and str(source_document_text).strip() != "":
        original_text = str(source_document_text)
        text_extraction_method = "STREAMLIT_TEXT_INPUT_OR_PREEXTRACTED_TEXT"
    elif source_stage_relative_path is not None and str(source_stage_relative_path).strip() != "":
        original_text, document_text_extraction_raw = extract_text_from_stage_file(
            session=session,
            relative_path=source_stage_relative_path
        )
        text_extraction_method = "CORTEX_AI_EXTRACT_FROM_UPLOADED_FILE"
    else:
        return json.dumps({
            "status": "ERROR",
            "message": "No RFQ text or uploaded stage file found."
        })

    if original_text is None or str(original_text).strip() == "":
        return json.dumps({
            "status": "ERROR",
            "message": "RFQ text extraction produced empty text."
        })

    # ------------------------------------------------------------
    # 3. Translate to English if needed
    # ------------------------------------------------------------
    processing_text_en, translation_method, translation_raw = translate_to_english(
        session=session,
        source_text=original_text,
        source_language_code=source_language_code
    )

    # ------------------------------------------------------------
    # 4. Summarize and classify RFQ
    # ------------------------------------------------------------
    rfq_summary = summarize_rfq(session, processing_text_en)

    complexity_category, complexity_reason, complexity_raw = classify_rfq(
        session=session,
        english_text=processing_text_en
    )

    # ------------------------------------------------------------
    # 5. Extract KMAT configuration with AI_EXTRACT
    # ------------------------------------------------------------
    raw_config, config_extraction_raw = extract_kmat_configuration(
        session=session,
        english_text=processing_text_en
    )

    # ------------------------------------------------------------
    # 6. Load allowed values and normalize Cortex output
    # ------------------------------------------------------------
    allowed_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            ALLOWED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_MASTER
        WHERE KMAT_ID = '{sql_escape(kmat_id)}'
          AND ACTIVE_FLAG = TRUE
    """).collect()

    allowed_map = {}
    for row in allowed_rows:
        char_name = normalize_text(row["CHARACTERISTIC_NAME"])
        allowed_value = normalize_text(row["ALLOWED_VALUE"])
        if char_name not in allowed_map:
            allowed_map[char_name] = set()
        allowed_map[char_name].add(allowed_value)

    required_chars = ["ENGINE", "CAB", "WHEEL", "COLOR"]
    normalized_config = {}
    raw_cortex_values = {}

    for char_name in required_chars:
        raw_value = get_nested(raw_config, char_name)
        raw_cortex_values[char_name] = raw_value

        normalized_config[char_name] = map_to_allowed(
            characteristic_name=char_name,
            raw_value=raw_value,
            allowed_values=allowed_map.get(char_name, set())
        )

    unknown_count = sum(1 for v in normalized_config.values() if v == "UNKNOWN")
    valid_count = len(required_chars) - unknown_count

    if unknown_count == 0:
        cortex_processing_status = "CORTEX_EXTRACTION_COMPLETE"
    else:
        cortex_processing_status = "CORTEX_EXTRACTION_INCOMPLETE_REVIEW_REQUIRED"

    # ------------------------------------------------------------
    # 7. AI_COMPLETE reasoning
    # ------------------------------------------------------------
    model_name = get_ai_complete_model(session)

    extraction_reasoning = generate_extraction_reasoning(
        session=session,
        model_name=model_name,
        english_text=processing_text_en,
        normalized_config=normalized_config,
        rfq_summary=rfq_summary,
        complexity_category=complexity_category
    )

    # ------------------------------------------------------------
    # 8. Determine configuration version and simulation id
    # ------------------------------------------------------------
    existing_rows = session.sql(f"""
        SELECT
            COALESCE(MAX(CONFIGURATION_VERSION), 0) AS MAX_VERSION,
            MAX(SIMULATION_ID) AS EXISTING_SIMULATION_ID
        FROM {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION
        WHERE RFQ_ID = '{rfq_id}'
    """).collect()

    max_version = int(existing_rows[0]["MAX_VERSION"] or 0)
    new_version = max_version + 1

    existing_simulation_id = existing_rows[0]["EXISTING_SIMULATION_ID"]
    if existing_simulation_id is not None and str(existing_simulation_id).strip() != "":
        simulation_id = existing_simulation_id
    else:
        simulation_id = "SIM_" + normalize_id(RFQ_ID)

    # ------------------------------------------------------------
    # 9. Deactivate old RFQ configurations
    # ------------------------------------------------------------
    session.sql(f"""
        UPDATE {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION
        SET ACTIVE_FLAG = FALSE
        WHERE RFQ_ID = '{rfq_id}'
    """).collect()

    # ------------------------------------------------------------
    # 10. Insert new Cortex-extracted configuration
    # ------------------------------------------------------------
    extraction_raw_payload = {
        "document_text_extraction_raw": document_text_extraction_raw,
        "translation_raw": translation_raw,
        "rfq_summary": rfq_summary,
        "complexity_category": complexity_category,
        "complexity_reason": complexity_reason,
        "complexity_raw": complexity_raw,
        "config_extraction_raw": config_extraction_raw,
        "raw_cortex_values": raw_cortex_values,
        "normalized_configuration": normalized_config,
        "valid_characteristic_count": valid_count,
        "unknown_characteristic_count": unknown_count,
        "ai_complete_model": model_name,
        "extraction_reasoning": extraction_reasoning
    }

    normalized_config_json = json.dumps(normalized_config, ensure_ascii=False)
    raw_payload_json = json.dumps(extraction_raw_payload, ensure_ascii=False)

    normalized_config_b64 = base64.b64encode(
        normalized_config_json.encode("utf-8")
    ).decode("utf-8")

    raw_payload_b64 = base64.b64encode(
        raw_payload_json.encode("utf-8")
    ).decode("utf-8")

    session.sql(f"""
        INSERT INTO {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION
        (
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
        SELECT
            '{rfq_id}' AS RFQ_ID,
            '{sql_escape(simulation_id)}' AS SIMULATION_ID,
            '{sql_escape(kmat_id)}' AS KMAT_ID,
            {new_version} AS CONFIGURATION_VERSION,
            PARSE_JSON(BASE64_DECODE_STRING('{normalized_config_b64}')) AS EXTRACTED_CONFIGURATION_JSON,
            'CORTEX_PHASE_7A_PIPELINE' AS EXTRACTION_METHOD,
            'AI_TRANSLATE_SUMMARIZE_AI_EXTRACT_AI_CLASSIFY_AI_COMPLETE' AS EXTRACTION_MODEL_NAME,
            'RFQ_CORTEX_INTAKE_V1' AS EXTRACTION_PROMPT_VERSION,
            PARSE_JSON(BASE64_DECODE_STRING('{raw_payload_b64}')) AS EXTRACTION_RAW_RESPONSE,
            CURRENT_USER() AS CREATED_BY,
            TRUE AS ACTIVE_FLAG
    """).collect()

    # ------------------------------------------------------------
    # 11. Update RFQ header with processing results
    # ------------------------------------------------------------
    session.sql(f"""
        UPDATE {DB_NAME}.CORE_INPUT.RFQ_HEADER
        SET
            ORIGINAL_DOCUMENT_TEXT = '{sql_escape(original_text)}',
            SOURCE_DOCUMENT_TEXT = '{sql_escape(processing_text_en)}',
            PROCESSING_TEXT_EN = '{sql_escape(processing_text_en)}',
            RFQ_SUMMARY = '{sql_escape(rfq_summary)}',
            TARGET_LANGUAGE_CODE = 'en',
            TRANSLATION_METHOD = '{sql_escape(translation_method)}',
            TEXT_EXTRACTION_METHOD = '{sql_escape(text_extraction_method)}',
            RFQ_COMPLEXITY_CATEGORY = '{sql_escape(complexity_category)}',
            RFQ_COMPLEXITY_REASON = '{sql_escape(complexity_reason)}',
            CORTEX_PROCESSING_STATUS = '{sql_escape(cortex_processing_status)}',
            CORTEX_PROCESSED_AT = CURRENT_TIMESTAMP(),
            DOCUMENT_STATUS = '{sql_escape(cortex_processing_status)}',
            UPDATED_AT = CURRENT_TIMESTAMP()
        WHERE RFQ_ID = '{rfq_id}'
    """).collect()

    # ------------------------------------------------------------
    # 12. Run existing rule-based BMCS scorer on latest configuration
    # ------------------------------------------------------------
    bmcs_result = {}
    try:
        bmcs_rows = session.sql(f"""
            CALL {DB_NAME}.CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('{rfq_id}')
        """).collect()

        if len(bmcs_rows) > 0:
            bmcs_raw = bmcs_rows[0][0]
            try:
                bmcs_result = json.loads(bmcs_raw)
            except Exception:
                bmcs_result = {"raw_result": str(bmcs_raw)}

    except Exception as exc:
        bmcs_result = {
            "status": "BMCS_SCORING_FAILED",
            "error": str(exc)
        }

    return json.dumps({
        "status": "SUCCESS",
        "rfq_id": RFQ_ID,
        "simulation_id": simulation_id,
        "kmat_id": kmat_id,
        "configuration_version": new_version,
        "source_document_name": rfq["SOURCE_DOCUMENT_NAME"],
        "text_extraction_method": text_extraction_method,
        "translation_method": translation_method,
        "rfq_summary": rfq_summary,
        "rfq_complexity_category": complexity_category,
        "extracted_configuration_json": normalized_config,
        "raw_cortex_values": raw_cortex_values,
        "valid_characteristic_count": valid_count,
        "unknown_characteristic_count": unknown_count,
        "cortex_processing_status": cortex_processing_status,
        "extraction_reasoning": extraction_reasoning,
        "bmcs_result": bmcs_result
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

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
        EXTRACTION_RAW_RESPONSE,
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
    h.SOURCE_STAGE_NAME,
    h.SOURCE_STAGE_RELATIVE_PATH,
    h.SOURCE_DOCUMENT_TEXT,
    h.ORIGINAL_DOCUMENT_TEXT,
    h.PROCESSING_TEXT_EN,
    h.RFQ_SUMMARY,
    h.SOURCE_LANGUAGE_CODE,
    h.TARGET_LANGUAGE_CODE,
    h.TRANSLATION_METHOD,
    h.TEXT_EXTRACTION_METHOD,
    h.RFQ_COMPLEXITY_CATEGORY,
    h.RFQ_COMPLEXITY_REASON,
    h.CORTEX_PROCESSING_STATUS,
    h.CORTEX_PROCESSED_AT,
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
    c.EXTRACTION_RAW_RESPONSE:extraction_reasoning::STRING AS CORTEX_EXTRACTION_REASONING,
    c.EXTRACTION_RAW_RESPONSE:config_extraction_raw:scoring AS CORTEX_EXTRACTION_SCORES,

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
    SOURCE_DOCUMENT_NAME,
    CORTEX_PROCESSING_STATUS,
    EXTRACTION_METHOD,
    ENGINE,
    CAB,
    WHEEL,
    COLOR,
    RFQ_COMPLEXITY_CATEGORY,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    FINAL_TRUSTED_COST_ALLOWED_FLAG
FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
ORDER BY RFQ_ID;

CALL CORE_INTERNAL.RUN_CORTEX_RFQ_INTAKE_PIPELINE('RFQ_001');

SELECT
    RFQ_ID,
    SOURCE_DOCUMENT_NAME,
    TEXT_EXTRACTION_METHOD,
    TRANSLATION_METHOD,
    RFQ_SUMMARY,
    RFQ_COMPLEXITY_CATEGORY,
    ENGINE,
    CAB,
    WHEEL,
    COLOR,
    BOM_MATCH_CONFIDENCE_SCORE,
    REVIEW_STATUS,
    CORTEX_EXTRACTION_REASONING
FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
WHERE RFQ_ID = 'RFQ_001';

SHOW CORTEX BASE MODELS;
SELECT AI_COMPLETE(
    'llama3.3-70b',
    'Reply with exactly: MODEL_OK'
) AS TEST_RESULT;
UPDATE CORE_INPUT.CORTEX_MODEL_CONFIG
SET
    CONFIG_VALUE = 'llama3.3-70b',
    UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL';
SELECT *
FROM CORE_INPUT.CORTEX_MODEL_CONFIG
WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL';

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS RULE_BASED_BMCS_SCORE NUMBER(5,2);

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS CORTEX_BMCS_SCORE NUMBER(5,2);

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS CORTEX_BMCS_REVIEW_STATUS VARCHAR;

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS CORTEX_BMCS_REASONING VARCHAR;

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS CORTEX_BMCS_RAW_RESPONSE VARIANT;

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS CORTEX_BMCS_CLASSIFICATION_RAW VARIANT;

ALTER TABLE CORE_INPUT.BOM_MATCH_ASSESSMENT
ADD COLUMN IF NOT EXISTS FINAL_BMCS_METHOD VARCHAR;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_BMCS_ASSESSMENT(RFQ_ID STRING)
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
import base64


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
        pass

    try:
        text = str(value).replace("%", "").strip()
        match = re.search(r"-?\d+(\.\d+)?", text)
        if match:
            return float(match.group(0))
    except Exception:
        pass

    return default


def parse_json_object_safe(value):
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, list):
        return {"labels": value}

    text = str(value).strip()

    text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
    text = re.sub(r"^```", "", text).strip()
    text = re.sub(r"```$", "", text).strip()

    for _ in range(3):
        try:
            parsed = json.loads(text)

            if isinstance(parsed, dict):
                return parsed

            if isinstance(parsed, list):
                return {"labels": parsed}

            if isinstance(parsed, str):
                text = parsed.strip()
                continue

            return {"value": parsed}

        except Exception:
            break

    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        extracted = match.group(0).strip()

        for _ in range(2):
            try:
                parsed = json.loads(extracted)

                if isinstance(parsed, dict):
                    return parsed

                if isinstance(parsed, str):
                    extracted = parsed.strip()
                    continue

            except Exception:
                break

    return {
        "raw_text": text
    }


def get_key_ci(obj, key, default=None):
    if not isinstance(obj, dict):
        return default

    if key in obj:
        return obj[key]

    key_upper = str(key).upper()

    for k, v in obj.items():
        if str(k).upper() == key_upper:
            return v

    return default


def json_to_base64(value):
    text = json.dumps(value, ensure_ascii=False)
    return base64.b64encode(text.encode("utf-8")).decode("ascii")


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def clamp_score(value):
    score = to_float(value, 0.0)

    if score < 0:
        score = 0.0

    if score > 100:
        score = 100.0

    return round(score, 2)


def fallback_review_status(score):
    if score >= 90:
        return "AUTO_APPROVED"
    if score >= 70:
        return "REVIEW_RECOMMENDED"
    return "REVIEW_REQUIRED"


def review_status_from_score(session, score):
    rows = session.sql(f"""
        SELECT
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            BUSINESS_ACTION
        FROM {DB_NAME}.CORE_INPUT.BMCS_REVIEW_RULES
        WHERE {score} BETWEEN MIN_SCORE AND MAX_SCORE
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return {
            "review_status": "REVIEW_REQUIRED",
            "review_required_flag": True,
            "final_trusted_cost_allowed_flag": False,
            "business_action": "BMCS rule missing. Defaulted to review required."
        }

    row = rows[0]

    return {
        "review_status": row["REVIEW_STATUS"],
        "review_required_flag": bool(row["REVIEW_REQUIRED_FLAG"]),
        "final_trusted_cost_allowed_flag": bool(row["FINAL_TRUSTED_COST_ALLOWED_FLAG"]),
        "business_action": row["BUSINESS_ACTION"]
    }


def extract_classification_label(raw_obj, score):
    allowed = {
        "AUTO_APPROVED",
        "REVIEW_RECOMMENDED",
        "REVIEW_REQUIRED"
    }

    if isinstance(raw_obj, str):
        text = raw_obj.upper()
        for label in allowed:
            if label in text:
                return label
        return fallback_review_status(score)

    if isinstance(raw_obj, dict):
        for key in ["label", "classification", "result", "category", "value"]:
            value = raw_obj.get(key)
            if isinstance(value, str) and value.upper() in allowed:
                return value.upper()

        labels = raw_obj.get("labels")

        if isinstance(labels, list) and len(labels) > 0:
            first = labels[0]

            if isinstance(first, str) and first.upper() in allowed:
                return first.upper()

            if isinstance(first, dict):
                for key in ["label", "classification", "category", "value"]:
                    value = first.get(key)
                    if isinstance(value, str) and value.upper() in allowed:
                        return value.upper()

        raw_text = json.dumps(raw_obj).upper()
        for label in allowed:
            if label in raw_text:
                return label

    return fallback_review_status(score)


def run(session, RFQ_ID):
    rfq_id = sql_escape(RFQ_ID)

    try:
        session.sql(f"""
            CALL {DB_NAME}.CORE_INTERNAL.RUN_RULE_BASED_BMCS_SCORING('{rfq_id}')
        """).collect()
    except Exception as exc:
        return json.dumps({
            "status": "ERROR",
            "stage": "RULE_BASED_BMCS",
            "message": "Rule-based BMCS scoring failed before Cortex BMCS.",
            "error": str(exc),
            "rfq_id": RFQ_ID
        })

    rows = session.sql(f"""
        SELECT
            h.RFQ_ID,
            h.KMAT_ID,
            h.CUSTOMER_ID,
            h.CUSTOMER_NAME,
            h.SOURCE_DOCUMENT_NAME,
            COALESCE(h.PROCESSING_TEXT_EN, h.SOURCE_DOCUMENT_TEXT, h.ORIGINAL_DOCUMENT_TEXT) AS RFQ_TEXT,
            h.RFQ_SUMMARY,
            h.RFQ_COMPLEXITY_CATEGORY,
            h.RFQ_COMPLEXITY_REASON,

            c.SIMULATION_ID,
            c.CONFIGURATION_VERSION,
            TO_JSON(c.EXTRACTED_CONFIGURATION_JSON) AS EXTRACTED_CONFIGURATION_JSON_STR,
            c.EXTRACTION_METHOD,
            c.EXTRACTION_RAW_RESPONSE:extraction_reasoning::STRING AS CORTEX_EXTRACTION_REASONING,

            a.BOM_MATCH_CONFIDENCE_SCORE AS RULE_BASED_BMCS_SCORE,
            a.REVIEW_STATUS AS RULE_BASED_REVIEW_STATUS,
            a.ASSESSMENT_NOTES AS RULE_BASED_ASSESSMENT_NOTES
        FROM {DB_NAME}.CORE_INPUT.RFQ_HEADER h
        JOIN {DB_NAME}.CORE_INPUT.RFQ_CONFIGURATION c
            ON h.RFQ_ID = c.RFQ_ID
           AND h.KMAT_ID = c.KMAT_ID
           AND c.ACTIVE_FLAG = TRUE
        JOIN {DB_NAME}.CORE_INPUT.BOM_MATCH_ASSESSMENT a
            ON c.RFQ_ID = a.RFQ_ID
           AND c.SIMULATION_ID = a.SIMULATION_ID
           AND c.KMAT_ID = a.KMAT_ID
           AND c.CONFIGURATION_VERSION = a.CONFIGURATION_VERSION
        WHERE h.RFQ_ID = '{rfq_id}'
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY h.RFQ_ID
            ORDER BY c.CONFIGURATION_VERSION DESC, c.CREATED_AT DESC
        ) = 1
    """).collect()

    if len(rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "stage": "LOAD_RFQ_BMCS_DATA",
            "message": f"No active RFQ configuration and BMCS assessment found for RFQ_ID={RFQ_ID}"
        })

    row = rows[0]

    kmat_id = row["KMAT_ID"]
    simulation_id = row["SIMULATION_ID"]
    configuration_version = int(row["CONFIGURATION_VERSION"])
    rfq_text = row["RFQ_TEXT"] or ""
    rfq_summary = row["RFQ_SUMMARY"] or ""
    complexity_category = row["RFQ_COMPLEXITY_CATEGORY"] or "UNKNOWN"
    extracted_config = row["EXTRACTED_CONFIGURATION_JSON_STR"] or "{}"
    extraction_reasoning = row["CORTEX_EXTRACTION_REASONING"] or ""
    rule_score = clamp_score(row["RULE_BASED_BMCS_SCORE"])
    model_name = get_ai_complete_model(session)

    complete_prompt = f"""
You are validating a manufacturing KMAT RFQ extraction.

Return STRICT JSON only. No markdown. No extra text.

Task:
Compare the customer RFQ text with the extracted KMAT configuration.
Generate a BOM Match Confidence Score from 0 to 100.

Scoring meaning:
- 90 to 100: RFQ clearly supports all extracted KMAT values.
- 70 to 89: Mostly correct, but one or more values are inferred or unclear.
- Below 70: Missing, vague, contradictory, or risky mapping. Engineering review required.

Do not calculate cost.
Do not invent new configuration values.
Evaluate whether the extracted configuration is trustworthy.

Return this JSON shape:
{{
  "cortex_bmcs_score": 0,
  "cortex_review_status": "AUTO_APPROVED or REVIEW_RECOMMENDED or REVIEW_REQUIRED",
  "reasoning": "short explanation"
}}

RFQ summary:
{rfq_summary}

RFQ complexity category:
{complexity_category}

Extracted KMAT configuration:
{extracted_config}

Previous extraction reasoning:
{extraction_reasoning}

RFQ text:
{rfq_text[:5000]}
"""

    complete_rows = session.sql(f"""
        SELECT AI_COMPLETE(
            '{sql_escape(model_name)}',
            '{sql_escape(complete_prompt)}'
        ) AS CORTEX_BMCS_TEXT
    """).collect()

    cortex_complete_text = complete_rows[0]["CORTEX_BMCS_TEXT"] if complete_rows else ""
    cortex_complete_obj = parse_json_object_safe(cortex_complete_text)

    cortex_score_raw = get_key_ci(cortex_complete_obj, "cortex_bmcs_score", None)

    if cortex_score_raw is None:
        cortex_score = rule_score
    else:
        cortex_score = clamp_score(cortex_score_raw)

    cortex_complete_review_status = str(
        get_key_ci(
            cortex_complete_obj,
            "cortex_review_status",
            fallback_review_status(cortex_score)
        )
    ).upper()

    cortex_reasoning = str(
        get_key_ci(
            cortex_complete_obj,
            "reasoning",
            get_key_ci(cortex_complete_obj, "raw_text", cortex_complete_text)
        )
    )

    classification_input = f"""
RFQ summary: {rfq_summary}

Extracted configuration: {extracted_config}

Rule-based BMCS score: {rule_score}
Cortex BMCS score: {cortex_score}

Reasoning: {cortex_reasoning}

Classify into exactly one review category:
AUTO_APPROVED, REVIEW_RECOMMENDED, REVIEW_REQUIRED
"""

    try:
        classify_rows = session.sql(f"""
            SELECT TO_JSON(
                AI_CLASSIFY(
                    '{sql_escape(classification_input)}',
                    ARRAY_CONSTRUCT(
                        'AUTO_APPROVED',
                        'REVIEW_RECOMMENDED',
                        'REVIEW_REQUIRED'
                    )
                )
            ) AS CLASSIFICATION_JSON
        """).collect()

        classification_raw_text = classify_rows[0]["CLASSIFICATION_JSON"] if classify_rows else "{}"
        classification_raw_obj = parse_json_object_safe(classification_raw_text)
        cortex_classified_status = extract_classification_label(classification_raw_obj, cortex_score)

    except Exception as exc:
        classification_raw_obj = {
            "error": str(exc),
            "fallback_status": fallback_review_status(cortex_score)
        }
        cortex_classified_status = fallback_review_status(cortex_score)

    final_score = round((0.70 * rule_score) + (0.30 * cortex_score), 2)

    final_rule = review_status_from_score(session, final_score)

    final_review_status = final_rule["review_status"]
    final_review_required_flag = final_rule["review_required_flag"]
    final_cost_allowed_flag = final_rule["final_trusted_cost_allowed_flag"]
    business_action = final_rule["business_action"]

    notes = (
        f"Hybrid BMCS completed. "
        f"Rule-based BMCS={rule_score}. "
        f"Cortex BMCS={cortex_score}. "
        f"Final BMCS={final_score}. "
        f"Cortex complete review status={cortex_complete_review_status}. "
        f"Cortex classified status={cortex_classified_status}. "
        f"Threshold-applied final review status={final_review_status}. "
        f"Business action={business_action}. "
        f"Cortex reasoning={cortex_reasoning}"
    )

    cortex_raw_payload = {
        "ai_complete_model": model_name,
        "ai_complete_raw_text": cortex_complete_text,
        "ai_complete_parsed": cortex_complete_obj,
        "cortex_complete_review_status": cortex_complete_review_status,
        "hybrid_formula": "FINAL_BMCS = 0.70 * RULE_BASED_BMCS + 0.30 * CORTEX_BMCS"
    }

    cortex_raw_json_b64 = json_to_base64(cortex_raw_payload)
    classification_raw_json_b64 = json_to_base64(classification_raw_obj)

    session.sql(f"""
        UPDATE {DB_NAME}.CORE_INPUT.BOM_MATCH_ASSESSMENT
        SET
            RULE_BASED_BMCS_SCORE = {rule_score},
            CORTEX_BMCS_SCORE = {cortex_score},
            CORTEX_BMCS_REVIEW_STATUS = '{sql_escape(cortex_classified_status)}',
            CORTEX_BMCS_REASONING = '{sql_escape(cortex_reasoning)}',
            CORTEX_BMCS_RAW_RESPONSE = PARSE_JSON(BASE64_DECODE_STRING('{cortex_raw_json_b64}')),
            CORTEX_BMCS_CLASSIFICATION_RAW = PARSE_JSON(BASE64_DECODE_STRING('{classification_raw_json_b64}')),
            FINAL_BMCS_METHOD = 'HYBRID_RULE_70_CORTEX_30',

            BOM_MATCH_CONFIDENCE_SCORE = {final_score},
            REVIEW_STATUS = '{sql_escape(final_review_status)}',
            REVIEW_REQUIRED_FLAG = {'TRUE' if final_review_required_flag else 'FALSE'},
            FINAL_TRUSTED_COST_ALLOWED_FLAG = {'TRUE' if final_cost_allowed_flag else 'FALSE'},
            ASSESSMENT_METHOD = 'HYBRID_RULE_CORTEX_BMCS',
            ASSESSMENT_VERSION = 'BMCS_HYBRID_V1',
            ASSESSMENT_NOTES = '{sql_escape(notes)}',
            UPDATED_AT = CURRENT_TIMESTAMP()
        WHERE RFQ_ID = '{rfq_id}'
          AND SIMULATION_ID = '{sql_escape(simulation_id)}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
          AND CONFIGURATION_VERSION = {configuration_version}
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "rfq_id": RFQ_ID,
        "simulation_id": simulation_id,
        "kmat_id": kmat_id,
        "configuration_version": configuration_version,
        "rule_based_bmcs_score": rule_score,
        "cortex_bmcs_score": cortex_score,
        "final_bmcs_score": final_score,
        "cortex_complete_review_status": cortex_complete_review_status,
        "cortex_classified_status": cortex_classified_status,
        "final_review_status": final_review_status,
        "review_required_flag": final_review_required_flag,
        "final_trusted_cost_allowed_flag": final_cost_allowed_flag,
        "final_bmcs_method": "HYBRID_RULE_70_CORTEX_30",
        "cortex_reasoning": cortex_reasoning
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

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
        EXTRACTION_RAW_RESPONSE,
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
        RULE_BASED_BMCS_SCORE,
        CORTEX_BMCS_SCORE,
        CORTEX_BMCS_REVIEW_STATUS,
        CORTEX_BMCS_REASONING,
        CORTEX_BMCS_RAW_RESPONSE,
        CORTEX_BMCS_CLASSIFICATION_RAW,
        FINAL_BMCS_METHOD,
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
    h.SOURCE_STAGE_NAME,
    h.SOURCE_STAGE_RELATIVE_PATH,
    h.SOURCE_DOCUMENT_TEXT,
    h.ORIGINAL_DOCUMENT_TEXT,
    h.PROCESSING_TEXT_EN,
    h.RFQ_SUMMARY,
    h.SOURCE_LANGUAGE_CODE,
    h.TARGET_LANGUAGE_CODE,
    h.TRANSLATION_METHOD,
    h.TEXT_EXTRACTION_METHOD,
    h.RFQ_COMPLEXITY_CATEGORY,
    h.RFQ_COMPLEXITY_REASON,
    h.CORTEX_PROCESSING_STATUS,
    h.CORTEX_PROCESSED_AT,
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
    c.EXTRACTION_RAW_RESPONSE:extraction_reasoning::STRING AS CORTEX_EXTRACTION_REASONING,
    c.EXTRACTION_RAW_RESPONSE:config_extraction_raw:scoring AS CORTEX_EXTRACTION_SCORES,

    a.RULE_BASED_BMCS_SCORE,
    a.CORTEX_BMCS_SCORE,
    a.BOM_MATCH_CONFIDENCE_SCORE,
    a.CORTEX_BMCS_REVIEW_STATUS,
    a.REVIEW_STATUS,
    a.REVIEW_REQUIRED_FLAG,
    a.FINAL_TRUSTED_COST_ALLOWED_FLAG,
    a.FINAL_BMCS_METHOD,
    a.CORTEX_BMCS_REASONING,
    a.CORTEX_BMCS_RAW_RESPONSE,
    a.CORTEX_BMCS_CLASSIFICATION_RAW,
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

CALL CORE_INTERNAL.RUN_CORTEX_BMCS_ASSESSMENT('RFQ_001');

SELECT
    RFQ_ID,
    SIMULATION_ID,
    ENGINE,
    CAB,
    WHEEL,
    COLOR,

    RULE_BASED_BMCS_SCORE,
    CORTEX_BMCS_SCORE,
    BOM_MATCH_CONFIDENCE_SCORE AS FINAL_BMCS_SCORE,

    CORTEX_BMCS_REVIEW_STATUS,
    REVIEW_STATUS AS FINAL_REVIEW_STATUS,
    REVIEW_REQUIRED_FLAG,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    FINAL_BMCS_METHOD,
    ASSESSMENT_METHOD
FROM CORE_INPUT.VW_RFQ_BMCS_STATUS
WHERE RFQ_ID = 'RFQ_001';

-- Step 6: Create wrapper to run RFQ quote with hybrid BMCS preserved

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_RFQ_QUOTE_PIPELINE(RFQ_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS
$$
import json


DB_NAME = "KMAT_COST_MODEL_DB"


def sql_escape(value):
    if value is None:
        return ""
    return str(value).replace("'", "''")


def parse_json_safe(value):
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        try:
            return json.loads(value)
        except Exception:
            return {"raw_result": value}

    return {"raw_result": str(value)}


def quote_trust_status(review_status, review_required, final_allowed):
    if review_status == "AUTO_APPROVED" and final_allowed:
        return "TRUSTED_AUTO_APPROVED"
    if review_status == "REVIEW_RECOMMENDED" and final_allowed:
        return "TRUSTED_WITH_REVIEW_RECOMMENDED"
    if review_required or not final_allowed:
        return "PRELIMINARY_ENGINEERING_REVIEW_REQUIRED"
    return "BMCS_STATUS_CHECK_REQUIRED"


def run(session, RFQ_ID):
    rfq_id = sql_escape(RFQ_ID)

    # 1. Run hybrid Cortex BMCS before preparation
    bmcs_rows = session.sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_BMCS_ASSESSMENT('{rfq_id}')
    """).collect()

    bmcs_result = parse_json_safe(bmcs_rows[0][0] if bmcs_rows else "{}")

    if bmcs_result.get("status") != "SUCCESS":
        return json.dumps({
            "status": "ERROR",
            "stage": "CORTEX_BMCS_ASSESSMENT",
            "result": bmcs_result
        })

    # 2. Prepare normal simulation inputs
    prep_rows = session.sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.PREPARE_RFQ_SIMULATION_INPUTS('{rfq_id}')
    """).collect()

    prep_result = parse_json_safe(prep_rows[0][0] if prep_rows else "{}")

    if prep_result.get("status") != "SUCCESS":
        return json.dumps({
            "status": "ERROR",
            "stage": "PREPARE_RFQ_SIMULATION_INPUTS",
            "result": prep_result
        })

    simulation_id = prep_result.get("simulation_id")

    if not simulation_id:
        return json.dumps({
            "status": "ERROR",
            "stage": "PREPARE_RFQ_SIMULATION_INPUTS",
            "message": "Simulation ID missing from prepare result.",
            "result": prep_result
        })

    # 3. Run normal deterministic KMAT cost engine
    cost_rows = session.sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('{sql_escape(simulation_id)}')
    """).collect()

    cost_result = parse_json_safe(cost_rows[0][0] if cost_rows else "{}")

    if cost_result.get("status") != "SUCCESS":
        return json.dumps({
            "status": "ERROR",
            "stage": "RUN_KMAT_COST_SIMULATION",
            "result": cost_result
        })

    # 4. Re-run hybrid BMCS after cost engine, so assessment is restored as hybrid
    bmcs_rows_2 = session.sql(f"""
        CALL {DB_NAME}.CORE_INTERNAL.RUN_CORTEX_BMCS_ASSESSMENT('{rfq_id}')
    """).collect()

    bmcs_result_2 = parse_json_safe(bmcs_rows_2[0][0] if bmcs_rows_2 else "{}")

    # 5. Read latest hybrid BMCS assessment
    status_rows = session.sql(f"""
        SELECT
            RFQ_ID,
            SOURCE_DOCUMENT_NAME,
            CONFIGURATION_VERSION,
            BOM_MATCH_CONFIDENCE_SCORE,
            REVIEW_STATUS,
            REVIEW_REQUIRED_FLAG,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            ASSESSMENT_METHOD,
            ASSESSMENT_VERSION,
            ASSESSMENT_NOTES
        FROM {DB_NAME}.CORE_INPUT.VW_RFQ_BMCS_STATUS
        WHERE RFQ_ID = '{rfq_id}'
        LIMIT 1
    """).collect()

    if len(status_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "stage": "READ_FINAL_BMCS_STATUS",
            "message": "No BMCS status found after hybrid scoring."
        })

    s = status_rows[0]

    trust_status = quote_trust_status(
        s["REVIEW_STATUS"],
        bool(s["REVIEW_REQUIRED_FLAG"]),
        bool(s["FINAL_TRUSTED_COST_ALLOWED_FLAG"])
    )

    # 6. Patch output summary with final hybrid BMCS fields
    session.sql(f"""
        UPDATE {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        SET
            RFQ_ID = '{sql_escape(s["RFQ_ID"])}',
            SOURCE_DOCUMENT_NAME = '{sql_escape(s["SOURCE_DOCUMENT_NAME"])}',
            BMCS_CONFIGURATION_VERSION = {int(s["CONFIGURATION_VERSION"])},
            BOM_MATCH_CONFIDENCE_SCORE = {float(s["BOM_MATCH_CONFIDENCE_SCORE"])},
            BMCS_REVIEW_STATUS = '{sql_escape(s["REVIEW_STATUS"])}',
            BMCS_REVIEW_REQUIRED_FLAG = {'TRUE' if bool(s["REVIEW_REQUIRED_FLAG"]) else 'FALSE'},
            FINAL_TRUSTED_COST_ALLOWED_FLAG = {'TRUE' if bool(s["FINAL_TRUSTED_COST_ALLOWED_FLAG"]) else 'FALSE'},
            QUOTE_TRUST_STATUS = '{sql_escape(trust_status)}',
            BMCS_ASSESSMENT_METHOD = '{sql_escape(s["ASSESSMENT_METHOD"])}',
            BMCS_ASSESSMENT_VERSION = '{sql_escape(s["ASSESSMENT_VERSION"])}',
            BMCS_ASSESSMENT_NOTES = '{sql_escape(s["ASSESSMENT_NOTES"])}'
        WHERE SIMULATION_ID = '{sql_escape(simulation_id)}'
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "rfq_id": RFQ_ID,
        "simulation_id": simulation_id,
        "bmcs_result": bmcs_result_2,
        "cost_result": cost_result,
        "quote_trust_status": trust_status
    })
$$;

CALL CORE_INTERNAL.RUN_CORTEX_RFQ_QUOTE_PIPELINE('RFQ_001');
SELECT
    SIMULATION_ID,
    RFQ_ID,
    SOURCE_DOCUMENT_NAME,
    BOM_MATCH_CONFIDENCE_SCORE,
    BMCS_REVIEW_STATUS,
    FINAL_TRUSTED_COST_ALLOWED_FLAG,
    QUOTE_TRUST_STATUS,
    BMCS_ASSESSMENT_METHOD,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD,
    TOTAL_RISK_UPLIFT_PCT
FROM CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE RFQ_ID = 'RFQ_001';

-- Phase C - Cortex CSS 
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE TABLE IF NOT EXISTS CORE_INPUT.CORTEX_CSS_EXPLANATION_ASSIST (
    SIMULATION_ID                     VARCHAR,
    KMAT_ID                           VARCHAR,

    OFFICIAL_CSS_SCORE                 NUMBER(5,2),
    OFFICIAL_SCRAP_RATE_APPLIED        NUMBER(10,6),
    OFFICIAL_SCRAP_RISK_LEVEL          VARCHAR,

    CORTEX_SCRAP_RISK_BAND             VARCHAR,
    CORTEX_REASONING                   VARCHAR,
    CORTEX_ENGINEERING_REVIEW_NOTE      VARCHAR,

    CORTEX_CLASSIFICATION_RAW          VARIANT,
    CORTEX_REASONING_RAW               VARIANT,

    ASSIST_METHOD                      VARCHAR,
    OFFICIAL_COST_OVERRIDE_FLAG         BOOLEAN,
    ASSESSMENT_STATUS                  VARCHAR,
    ASSESSMENT_NOTES                   VARCHAR,

    CREATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DESC TABLE CORE_INPUT.CORTEX_CSS_EXPLANATION_ASSIST;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_CSS_EXPLANATION_ASSIST(SIMULATION_ID STRING)
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


def to_float(value, default=0.0):
    if value is None:
        return default
    try:
        return float(value)
    except Exception:
        return default


def normalize_text(value):
    if value is None:
        return ""
    return str(value).strip().upper()


def parse_json_safe(value):
    """
    Robust parser for Cortex text output.

    Handles:
    1. Proper JSON object
    2. JSON inside markdown fences
    3. Plain text explanation
    4. JSON string instead of JSON object
    """
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        text = value.strip()

        text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
        text = re.sub(r"^```", "", text).strip()
        text = re.sub(r"```$", "", text).strip()

        try:
            parsed = json.loads(text)

            if isinstance(parsed, dict):
                return parsed

            if isinstance(parsed, str):
                return {
                    "reasoning": parsed,
                    "engineering_review_note": "Use deterministic CSS output and review if required."
                }

            if isinstance(parsed, list):
                return {
                    "reasoning": json.dumps(parsed),
                    "engineering_review_note": "Use deterministic CSS output and review if required."
                }

        except Exception:
            pass

        match = re.search(r"\{.*\}", text, re.DOTALL)

        if match:
            try:
                parsed = json.loads(match.group(0))

                if isinstance(parsed, dict):
                    return parsed

            except Exception:
                pass

        return {
            "reasoning": text,
            "engineering_review_note": "Use deterministic CSS output and review if required."
        }

    return {
        "reasoning": str(value),
        "engineering_review_note": "Use deterministic CSS output and review if required."
    }


def json_text(value):
    """
    Converts any Python object into safe JSON text.
    Used before TRY_PARSE_JSON in Snowflake.
    """
    try:
        return json.dumps(value, ensure_ascii=False)
    except Exception:
        return json.dumps({"raw_value": str(value)}, ensure_ascii=False)


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def extract_classification_label(raw_obj, official_risk_level):
    allowed = {
        "LOW_SCRAP_RISK",
        "MEDIUM_SCRAP_RISK",
        "HIGH_SCRAP_RISK"
    }

    if isinstance(raw_obj, str):
        text = raw_obj.upper()

        for label in allowed:
            if label in text:
                return label

    if isinstance(raw_obj, dict):
        for key in ["label", "classification", "result", "category"]:
            value = raw_obj.get(key)

            if isinstance(value, str) and value.upper() in allowed:
                return value.upper()

        labels = raw_obj.get("labels")

        if isinstance(labels, list) and len(labels) > 0:
            first = labels[0]

            if isinstance(first, str) and first.upper() in allowed:
                return first.upper()

            if isinstance(first, dict):
                for key in ["label", "classification", "category"]:
                    value = first.get(key)

                    if isinstance(value, str) and value.upper() in allowed:
                        return value.upper()

        raw_text = json.dumps(raw_obj).upper()

        for label in allowed:
            if label in raw_text:
                return label

    official = normalize_text(official_risk_level)

    if official == "HIGH":
        return "HIGH_SCRAP_RISK"

    if official == "MEDIUM":
        return "MEDIUM_SCRAP_RISK"

    if official == "LOW":
        return "LOW_SCRAP_RISK"

    return "MEDIUM_SCRAP_RISK"


def run(session, SIMULATION_ID):
    sim_id = sql_escape(SIMULATION_ID)

    # ------------------------------------------------------------
    # 1. Read official deterministic cost summary
    # ------------------------------------------------------------
    summary_rows = session.sql(f"""
        SELECT
            SIMULATION_ID,
            KMAT_ID,
            CSS_SCORE,
            SCRAP_RATE_APPLIED,
            SCRAP_RISK_LEVEL,
            BASELINE_TOTAL_COST_USD,
            RISK_ADJUSTED_TOTAL_COST_USD,
            TOTAL_RISK_UPLIFT_USD,
            TOTAL_RISK_UPLIFT_PCT,
            RISK_CALCULATION_STATUS
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        WHERE SIMULATION_ID = '{sim_id}'
        LIMIT 1
    """).collect()

    if len(summary_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": "No cost summary found. Run RUN_KMAT_COST_SIMULATION first.",
            "simulation_id": SIMULATION_ID
        })

    summary = summary_rows[0]
    kmat_id = summary["KMAT_ID"]

    official_css_score = to_float(summary["CSS_SCORE"], 0.0)
    official_scrap_rate = to_float(summary["SCRAP_RATE_APPLIED"], 0.0)
    official_scrap_risk_level = summary["SCRAP_RISK_LEVEL"]

    # ------------------------------------------------------------
    # 2. Read selected KMAT configuration
    # ------------------------------------------------------------
    config_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            SELECTED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        WHERE SIMULATION_ID = '{sim_id}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
        ORDER BY CHARACTERISTIC_NAME
    """).collect()

    selected_config = {}

    for row in config_rows:
        selected_config[row["CHARACTERISTIC_NAME"]] = row["SELECTED_VALUE"]

    # ------------------------------------------------------------
    # 3. Read selected component risk details
    # ------------------------------------------------------------
    component_rows = session.sql(f"""
        SELECT
            COMPONENT_ID,
            COMPONENT_DESCRIPTION,
            COST_COMPONENT_GROUP,
            QUANTITY,
            SCRAP_APPLICABLE_FLAG,
            SCRAP_RATE_APPLIED,
            SCRAP_ADJUSTMENT_USD,
            ADJUSTED_LINE_MATERIAL_COST_USD,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
        WHERE SIMULATION_ID = '{sim_id}'
        ORDER BY COST_COMPONENT_GROUP, COMPONENT_ID
    """).collect()

    selected_components = []

    for row in component_rows:
        selected_components.append({
            "component_id": row["COMPONENT_ID"],
            "description": row["COMPONENT_DESCRIPTION"],
            "group": row["COST_COMPONENT_GROUP"],
            "quantity": to_float(row["QUANTITY"], 0.0),
            "scrap_applicable": bool(row["SCRAP_APPLICABLE_FLAG"]) if row["SCRAP_APPLICABLE_FLAG"] is not None else False,
            "scrap_rate_applied": to_float(row["SCRAP_RATE_APPLIED"], 0.0),
            "scrap_adjustment_usd": to_float(row["SCRAP_ADJUSTMENT_USD"], 0.0),
            "adjusted_line_material_cost_usd": to_float(row["ADJUSTED_LINE_MATERIAL_COST_USD"], 0.0)
        })

    # ------------------------------------------------------------
    # 4. Read production context
    # ------------------------------------------------------------
    context_rows = session.sql(f"""
        SELECT
            PLANT_ID,
            PRODUCTION_LINE_ID,
            TO_VARCHAR(PLANNED_PRODUCTION_DATE, 'YYYY-MM-DD') AS PLANNED_PRODUCTION_DATE,
            BATCH_QUANTITY
        FROM {DB_NAME}.CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
        WHERE SIMULATION_ID = '{sim_id}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
        LIMIT 1
    """).collect()

    if len(context_rows) > 0:
        production_context = {
            "plant_id": context_rows[0]["PLANT_ID"],
            "production_line_id": context_rows[0]["PRODUCTION_LINE_ID"],
            "planned_production_date": context_rows[0]["PLANNED_PRODUCTION_DATE"],
            "batch_quantity": to_float(context_rows[0]["BATCH_QUANTITY"], 0.0)
        }
    else:
        production_context = {
            "plant_id": "UNKNOWN",
            "production_line_id": "UNKNOWN",
            "planned_production_date": "UNKNOWN",
            "batch_quantity": 0.0
        }

    # ------------------------------------------------------------
    # 5. AI_CLASSIFY advisory scrap risk band
    # ------------------------------------------------------------
    classification_input = f"""
This is an advisory scrap-risk classification for a KMAT truck cost model.

Do not calculate cost.
Do not change the official CSS score.
Do not change the official scrap rate.
Use only qualitative reasoning.

Selected KMAT configuration:
{json.dumps(selected_config)}

Production context:
{json.dumps(production_context)}

Official deterministic CSS:
{official_css_score}

Official deterministic scrap rate:
{official_scrap_rate}

Official deterministic scrap risk level:
{official_scrap_risk_level}

Selected components:
{json.dumps(selected_components[:30])}

Classify into exactly one category:
LOW_SCRAP_RISK, MEDIUM_SCRAP_RISK, HIGH_SCRAP_RISK
"""

    try:
        classify_rows = session.sql(f"""
            SELECT TO_JSON(
                AI_CLASSIFY(
                    '{sql_escape(classification_input)}',
                    ARRAY_CONSTRUCT(
                        'LOW_SCRAP_RISK',
                        'MEDIUM_SCRAP_RISK',
                        'HIGH_SCRAP_RISK'
                    )
                )
            ) AS CLASSIFICATION_JSON
        """).collect()

        classification_raw_text = classify_rows[0]["CLASSIFICATION_JSON"] if classify_rows else "{}"
        classification_raw = parse_json_safe(classification_raw_text)

        cortex_scrap_risk_band = extract_classification_label(
            classification_raw,
            official_scrap_risk_level
        )

    except Exception as exc:
        classification_raw = {
            "error": str(exc),
            "fallback_used": True,
            "fallback_based_on_official_risk_level": official_scrap_risk_level
        }

        cortex_scrap_risk_band = extract_classification_label(
            classification_raw,
            official_scrap_risk_level
        )

    # ------------------------------------------------------------
    # 6. AI_COMPLETE advisory explanation
    # ------------------------------------------------------------
    model_name = get_ai_complete_model(session)

    reasoning_prompt = f"""
You are explaining scrap risk for a KMAT manufacturing cost model.

Return STRICT JSON only.
Do not use markdown.
Do not add text outside JSON.

Rules:
- Do not calculate official cost.
- Do not change CSS.
- Do not change scrap rate.
- Do not recommend overriding the cost engine.
- Explain only why the official CSS and scrap risk level make sense or need review.
- Keep the explanation useful for costing, manufacturing engineering, and review teams.

Return exactly this JSON shape:
{{
  "reasoning": "short business explanation",
  "engineering_review_note": "short review note"
}}

Selected KMAT configuration:
{json.dumps(selected_config)}

Production context:
{json.dumps(production_context)}

Official CSS score:
{official_css_score}

Official scrap rate:
{official_scrap_rate}

Official scrap risk level:
{official_scrap_risk_level}

Cortex advisory scrap risk band:
{cortex_scrap_risk_band}

Selected components:
{json.dumps(selected_components[:30])}
"""

    try:
        reasoning_rows = session.sql(f"""
            SELECT AI_COMPLETE(
                '{sql_escape(model_name)}',
                '{sql_escape(reasoning_prompt)}'
            ) AS REASONING_TEXT
        """).collect()

        reasoning_text = reasoning_rows[0]["REASONING_TEXT"] if reasoning_rows else ""

        reasoning_obj = parse_json_safe(reasoning_text)

        if not isinstance(reasoning_obj, dict):
            reasoning_obj = {
                "reasoning": str(reasoning_obj),
                "engineering_review_note": "Use deterministic CSS output and review if required."
            }

        cortex_reasoning = reasoning_obj.get("reasoning")

        if cortex_reasoning is None or str(cortex_reasoning).strip() == "":
            cortex_reasoning = str(reasoning_text)

        cortex_engineering_review_note = reasoning_obj.get("engineering_review_note")

        if cortex_engineering_review_note is None or str(cortex_engineering_review_note).strip() == "":
            cortex_engineering_review_note = (
                "Review official CSS drivers if configuration appears unusually complex "
                "or if historical scrap data is unavailable."
            )

        reasoning_raw = {
            "model": model_name,
            "prompt_version": "CSS_EXPLANATION_ASSIST_V3",
            "raw_text": reasoning_text,
            "parsed": reasoning_obj
        }

    except Exception as exc:
        cortex_reasoning = f"AI_COMPLETE block failed after function call or parsing: {str(exc)}"
        cortex_engineering_review_note = (
            "Cortex explanation parsing failed. Use deterministic CSS output and manual review if needed."
        )
        reasoning_raw = {
            "error": str(exc),
            "model": model_name,
            "prompt_version": "CSS_EXPLANATION_ASSIST_V3"
        }

    # ------------------------------------------------------------
    # 7. Store advisory-only result
    # ------------------------------------------------------------
    classification_raw_json = json_text(classification_raw)
    reasoning_raw_json = json_text(reasoning_raw)

    assessment_notes = (
        "Advisory-only Cortex CSS explanation. "
        "Official CSS, scrap rate, and risk-adjusted cost remain controlled by deterministic cost engine."
    )

    session.sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.CORTEX_CSS_EXPLANATION_ASSIST t
        USING (
            SELECT
                '{sim_id}' AS SIMULATION_ID,
                '{sql_escape(kmat_id)}' AS KMAT_ID
        ) s
        ON t.SIMULATION_ID = s.SIMULATION_ID
           AND t.KMAT_ID = s.KMAT_ID
        WHEN MATCHED THEN UPDATE SET
            t.OFFICIAL_CSS_SCORE = {official_css_score},
            t.OFFICIAL_SCRAP_RATE_APPLIED = {official_scrap_rate},
            t.OFFICIAL_SCRAP_RISK_LEVEL = '{sql_escape(official_scrap_risk_level)}',
            t.CORTEX_SCRAP_RISK_BAND = '{sql_escape(cortex_scrap_risk_band)}',
            t.CORTEX_REASONING = '{sql_escape(cortex_reasoning)}',
            t.CORTEX_ENGINEERING_REVIEW_NOTE = '{sql_escape(cortex_engineering_review_note)}',
            t.CORTEX_CLASSIFICATION_RAW = TRY_PARSE_JSON('{sql_escape(classification_raw_json)}'),
            t.CORTEX_REASONING_RAW = TRY_PARSE_JSON('{sql_escape(reasoning_raw_json)}'),
            t.ASSIST_METHOD = 'CORTEX_CSS_EXPLANATION_ASSIST_V3',
            t.OFFICIAL_COST_OVERRIDE_FLAG = FALSE,
            t.ASSESSMENT_STATUS = 'SUCCESS',
            t.ASSESSMENT_NOTES = '{sql_escape(assessment_notes)}',
            t.UPDATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            SIMULATION_ID,
            KMAT_ID,
            OFFICIAL_CSS_SCORE,
            OFFICIAL_SCRAP_RATE_APPLIED,
            OFFICIAL_SCRAP_RISK_LEVEL,
            CORTEX_SCRAP_RISK_BAND,
            CORTEX_REASONING,
            CORTEX_ENGINEERING_REVIEW_NOTE,
            CORTEX_CLASSIFICATION_RAW,
            CORTEX_REASONING_RAW,
            ASSIST_METHOD,
            OFFICIAL_COST_OVERRIDE_FLAG,
            ASSESSMENT_STATUS,
            ASSESSMENT_NOTES
        )
        VALUES (
            '{sim_id}',
            '{sql_escape(kmat_id)}',
            {official_css_score},
            {official_scrap_rate},
            '{sql_escape(official_scrap_risk_level)}',
            '{sql_escape(cortex_scrap_risk_band)}',
            '{sql_escape(cortex_reasoning)}',
            '{sql_escape(cortex_engineering_review_note)}',
            TRY_PARSE_JSON('{sql_escape(classification_raw_json)}'),
            TRY_PARSE_JSON('{sql_escape(reasoning_raw_json)}'),
            'CORTEX_CSS_EXPLANATION_ASSIST_V3',
            FALSE,
            'SUCCESS',
            '{sql_escape(assessment_notes)}'
        )
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "simulation_id": SIMULATION_ID,
        "kmat_id": kmat_id,
        "official_css_score": official_css_score,
        "official_scrap_rate_applied": official_scrap_rate,
        "official_scrap_risk_level": official_scrap_risk_level,
        "cortex_scrap_risk_band": cortex_scrap_risk_band,
        "cortex_reasoning": cortex_reasoning,
        "cortex_engineering_review_note": cortex_engineering_review_note,
        "official_cost_override_flag": False,
        "assist_method": "CORTEX_CSS_EXPLANATION_ASSIST_V3"
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE VIEW CORE_INPUT.VW_CORTEX_CSS_EXPLANATION_ASSIST AS
SELECT
    a.SIMULATION_ID,
    a.KMAT_ID,

    LISTAGG(cv.CHARACTERISTIC_NAME || '=' || cv.SELECTED_VALUE, ', ')
        WITHIN GROUP (ORDER BY cv.CHARACTERISTIC_NAME) AS CONFIGURATION,

    a.OFFICIAL_CSS_SCORE,
    a.OFFICIAL_SCRAP_RATE_APPLIED,
    a.OFFICIAL_SCRAP_RISK_LEVEL,

    a.CORTEX_SCRAP_RISK_BAND,
    a.CORTEX_REASONING,
    a.CORTEX_ENGINEERING_REVIEW_NOTE,

    a.ASSIST_METHOD,
    a.OFFICIAL_COST_OVERRIDE_FLAG,
    a.ASSESSMENT_STATUS,
    a.ASSESSMENT_NOTES,
    a.UPDATED_AT
FROM CORE_INPUT.CORTEX_CSS_EXPLANATION_ASSIST a
LEFT JOIN CORE_INPUT.CHARACTERISTIC_VALUES cv
    ON a.SIMULATION_ID = cv.SIMULATION_ID
   AND a.KMAT_ID = cv.KMAT_ID
GROUP BY
    a.SIMULATION_ID,
    a.KMAT_ID,
    a.OFFICIAL_CSS_SCORE,
    a.OFFICIAL_SCRAP_RATE_APPLIED,
    a.OFFICIAL_SCRAP_RISK_LEVEL,
    a.CORTEX_SCRAP_RISK_BAND,
    a.CORTEX_REASONING,
    a.CORTEX_ENGINEERING_REVIEW_NOTE,
    a.ASSIST_METHOD,
    a.OFFICIAL_COST_OVERRIDE_FLAG,
    a.ASSESSMENT_STATUS,
    a.ASSESSMENT_NOTES,
    a.UPDATED_AT;

CALL CORE_INTERNAL.RUN_CORTEX_CSS_EXPLANATION_ASSIST('SIM_RFQ_001');
CALL CORE_INTERNAL.RUN_CORTEX_CSS_EXPLANATION_ASSIST('SIM_001');

SELECT
    SIMULATION_ID,
    CONFIGURATION,
    OFFICIAL_CSS_SCORE,
    OFFICIAL_SCRAP_RATE_APPLIED,
    OFFICIAL_SCRAP_RISK_LEVEL,
    CORTEX_SCRAP_RISK_BAND,
    OFFICIAL_COST_OVERRIDE_FLAG,
    ASSIST_METHOD,
    CORTEX_REASONING,
    CORTEX_ENGINEERING_REVIEW_NOTE
FROM CORE_INPUT.VW_CORTEX_CSS_EXPLANATION_ASSIST
ORDER BY UPDATED_AT DESC;

SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', 'test');

--  FMIS
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE TABLE IF NOT EXISTS CORE_INPUT.COMMODITY_MARKET_NOTES (
    MARKET_NOTE_ID          VARCHAR,
    COMMODITY_GROUP         VARCHAR,
    SOURCE_NAME             VARCHAR,
    NOTE_TITLE              VARCHAR,
    NOTE_TEXT               VARCHAR,
    TARGET_FORECAST_MONTH   DATE,
    NOTE_STATUS             VARCHAR,
    ACTIVE_FLAG             BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS CORE_INPUT.CORTEX_FMIS_SIGNAL_ASSIST (
    MARKET_NOTE_ID                  VARCHAR,
    COMMODITY_GROUP                 VARCHAR,
    TARGET_FORECAST_MONTH           DATE,

    CORTEX_EXTRACTED_COMMODITY       VARCHAR,
    CORTEX_PRICE_DIRECTION           VARCHAR,
    CORTEX_RISK_LEVEL                VARCHAR,
    CORTEX_SIGNAL_TIME_HORIZON        VARCHAR,
    CORTEX_KEY_DRIVERS               VARCHAR,
    CORTEX_SUPPLIER_IMPACT           VARCHAR,

    CORTEX_MARKET_SUMMARY            VARCHAR,
    CORTEX_FMIS_EXPLANATION          VARCHAR,
    CORTEX_REVIEW_NOTE               VARCHAR,

    CORTEX_EXTRACTION_RAW            VARIANT,
    CORTEX_EXPLANATION_RAW           VARIANT,

    OFFICIAL_FMIS_OVERRIDE_FLAG       BOOLEAN,
    ASSIST_METHOD                    VARCHAR,
    ASSESSMENT_STATUS                VARCHAR,
    ASSESSMENT_NOTES                 VARCHAR,

    CREATED_AT                       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_FMIS_SIGNAL_ASSIST(MARKET_NOTE_ID STRING)
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


def parse_json_safe(value):
    """
    Always returns a dictionary.
    Prevents errors like:
    'str' object has no attribute 'get'
    """
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        text = value.strip()

        text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
        text = re.sub(r"^```", "", text).strip()
        text = re.sub(r"```$", "", text).strip()

        try:
            parsed = json.loads(text)

            if isinstance(parsed, dict):
                return parsed

            return {
                "raw_text": str(parsed)
            }

        except Exception:
            pass

        match = re.search(r"\{.*\}", text, re.DOTALL)

        if match:
            try:
                parsed = json.loads(match.group(0))

                if isinstance(parsed, dict):
                    return parsed

                return {
                    "raw_text": str(parsed)
                }

            except Exception:
                return {
                    "raw_text": text
                }

        return {
            "raw_text": text
        }

    try:
        parsed = dict(value)

        if isinstance(parsed, dict):
            return parsed

        return {
            "raw_text": str(parsed)
        }

    except Exception:
        return {
            "raw_text": str(value)
        }


def get_nested(obj, key):
    if not isinstance(obj, dict):
        return None

    if key in obj:
        return obj[key]

    for k, v in obj.items():
        if str(k).upper() == str(key).upper():
            return v

    return None


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def normalize_commodity(value):
    text = normalize_text(value)

    if "STEEL" in text:
        return "STEEL"

    if "ALUMINUM" in text or "ALUMINIUM" in text:
        return "ALUMINUM"

    if "RUBBER" in text:
        return "RUBBER"

    if "CHEMICAL" in text or "PAINT" in text or "RESIN" in text:
        return "CHEMICALS"

    if text in ("OTHER", "UNKNOWN"):
        return text

    return "UNKNOWN"


def normalize_direction(value):
    text = normalize_text(value)

    if text in ("UP", "DOWN", "STABLE", "UNKNOWN"):
        return text

    if "INCREASE" in text or "RISE" in text or "HIGHER" in text or "UPWARD" in text:
        return "UP"

    if "DECREASE" in text or "DROP" in text or "LOWER" in text or "DOWNWARD" in text:
        return "DOWN"

    if "STABLE" in text or "UNCHANGED" in text or "FLAT" in text:
        return "STABLE"

    return "UNKNOWN"


def normalize_risk(value):
    text = normalize_text(value)

    if text in ("LOW", "MEDIUM", "HIGH", "UNKNOWN"):
        return text

    if "HIGH" in text or "SEVERE" in text or "CRITICAL" in text:
        return "HIGH"

    if "MEDIUM" in text or "MODERATE" in text:
        return "MEDIUM"

    if "LOW" in text or "MINOR" in text:
        return "LOW"

    return "UNKNOWN"


def summarize_market_note(session, note_text):
    try:
        rows = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.SUMMARIZE('{sql_escape(note_text)}') AS MARKET_SUMMARY
        """).collect()

        if len(rows) == 0 or rows[0]["MARKET_SUMMARY"] is None:
            return ""

        return rows[0]["MARKET_SUMMARY"]

    except Exception as exc:
        return f"SUMMARIZE failed: {str(exc)}"


def run(session, MARKET_NOTE_ID):
    note_id = sql_escape(MARKET_NOTE_ID)

    # ------------------------------------------------------------
    # 1. Read supplier / market note
    # ------------------------------------------------------------
    note_rows = session.sql(f"""
        SELECT
            MARKET_NOTE_ID,
            COMMODITY_GROUP,
            SOURCE_NAME,
            NOTE_TITLE,
            NOTE_TEXT,
            TARGET_FORECAST_MONTH
        FROM {DB_NAME}.CORE_INPUT.COMMODITY_MARKET_NOTES
        WHERE MARKET_NOTE_ID = '{note_id}'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(note_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": f"MARKET_NOTE_ID {MARKET_NOTE_ID} not found."
        })

    note = note_rows[0]

    input_commodity_group = note["COMMODITY_GROUP"]
    note_text = note["NOTE_TEXT"]
    target_forecast_month = note["TARGET_FORECAST_MONTH"]

    if note_text is None or str(note_text).strip() == "":
        return json.dumps({
            "status": "ERROR",
            "message": "NOTE_TEXT is empty."
        })

    # ------------------------------------------------------------
    # 2. Summarize note
    # ------------------------------------------------------------
    market_summary = summarize_market_note(session, note_text)

    # ------------------------------------------------------------
    # 3. Extract market signal using AI_EXTRACT
    # ------------------------------------------------------------
    response_format = {
        "COMMODITY_GROUP": (
            "Extract the affected commodity group. Return exactly one of: "
            "STEEL, ALUMINUM, RUBBER, CHEMICALS, OTHER, UNKNOWN."
        ),
        "PRICE_DIRECTION": (
            "Extract the expected price direction. Return exactly one of: "
            "UP, DOWN, STABLE, UNKNOWN."
        ),
        "RISK_LEVEL": (
            "Extract the market risk level. Return exactly one of: "
            "LOW, MEDIUM, HIGH, UNKNOWN."
        ),
        "SIGNAL_TIME_HORIZON": (
            "Extract the time horizon or effective period mentioned in the note. "
            "Return a short phrase."
        ),
        "KEY_DRIVERS": (
            "Extract key drivers such as shortage, shipping delay, energy cost, supplier capacity, demand spike, or contract pressure. "
            "Return a short comma-separated phrase."
        ),
        "SUPPLIER_IMPACT": (
            "Extract the expected supplier or procurement impact. Return a short phrase."
        )
    }

    response_format_json = json.dumps(response_format)

    try:
        extract_rows = session.sql(f"""
            SELECT TO_JSON(
                AI_EXTRACT(
                    text => '{sql_escape(note_text)}',
                    responseFormat => PARSE_JSON('{sql_escape(response_format_json)}'),
                    scores => TRUE
                )
            ) AS EXTRACTION_JSON
        """).collect()

        extraction_raw_text = extract_rows[0]["EXTRACTION_JSON"] if extract_rows else "{}"
        extraction_raw = parse_json_safe(extraction_raw_text)

        response_obj = get_nested(extraction_raw, "response")

        if response_obj is None:
            response_obj = extraction_raw

        if not isinstance(response_obj, dict):
            response_obj = {}

    except Exception as exc:
        extraction_raw = {
            "error": str(exc)
        }
        response_obj = {}

    extracted_commodity = normalize_commodity(get_nested(response_obj, "COMMODITY_GROUP"))

    if extracted_commodity == "UNKNOWN":
        extracted_commodity = normalize_commodity(input_commodity_group)

    price_direction = normalize_direction(get_nested(response_obj, "PRICE_DIRECTION"))
    risk_level = normalize_risk(get_nested(response_obj, "RISK_LEVEL"))

    signal_time_horizon = str(get_nested(response_obj, "SIGNAL_TIME_HORIZON") or "")
    key_drivers = str(get_nested(response_obj, "KEY_DRIVERS") or "")
    supplier_impact = str(get_nested(response_obj, "SUPPLIER_IMPACT") or "")

    # ------------------------------------------------------------
    # 4. Explain FMIS signal using AI_COMPLETE
    # ------------------------------------------------------------
    model_name = get_ai_complete_model(session)

    explanation_prompt = f"""
You are assisting a KMAT manufacturing cost model.

Write STRICT JSON only. No markdown. No extra text.

Rules:
- Do not create or change the official FMIS multiplier.
- Do not update material cost.
- Do not calculate quote price.
- Explain the market signal and whether a human should review the official FMIS table.

Return this JSON shape:
{{
  "fmis_explanation": "short explanation of the commodity signal",
  "review_note": "short procurement/costing review note"
}}

Market note title:
{note["NOTE_TITLE"]}

Source:
{note["SOURCE_NAME"]}

Market summary:
{market_summary}

Extracted commodity:
{extracted_commodity}

Price direction:
{price_direction}

Risk level:
{risk_level}

Signal time horizon:
{signal_time_horizon}

Key drivers:
{key_drivers}

Supplier impact:
{supplier_impact}

Original note:
{str(note_text)[:4000]}
"""

    try:
        explanation_rows = session.sql(f"""
            SELECT AI_COMPLETE(
                '{sql_escape(model_name)}',
                '{sql_escape(explanation_prompt)}'
            ) AS EXPLANATION_TEXT
        """).collect()

        explanation_text = explanation_rows[0]["EXPLANATION_TEXT"] if explanation_rows else ""

        explanation_obj = parse_json_safe(explanation_text)

        if not isinstance(explanation_obj, dict):
            explanation_obj = {
                "raw_text": str(explanation_text)
            }

        fmis_explanation = explanation_obj.get("fmis_explanation")

        if fmis_explanation is None or str(fmis_explanation).strip() == "":
            fmis_explanation = explanation_obj.get("raw_text", str(explanation_text))

        review_note = explanation_obj.get("review_note")

        if review_note is None or str(review_note).strip() == "":
            review_note = "Review the official FMIS table if this signal affects the planned production month."

        explanation_raw = {
            "model": model_name,
            "prompt_version": "FMIS_SIGNAL_ASSIST_V1",
            "raw_text": str(explanation_text),
            "parsed": explanation_obj
        }

    except Exception as exc:
        fmis_explanation = f"AI_COMPLETE failed: {str(exc)}"
        review_note = "Cortex explanation failed. Use official FMIS table and manual review if needed."
        explanation_raw = {
            "error": str(exc),
            "model": model_name,
            "prompt_version": "FMIS_SIGNAL_ASSIST_V1"
        }

    # ------------------------------------------------------------
    # 5. Store advisory-only result
    # Important:
    # Raw Cortex JSON/text is stored using TO_VARIANT, not PARSE_JSON.
    # This avoids Snowflake JSON parse errors from braces/quotes inside model text.
    # ------------------------------------------------------------
    extraction_raw_json = json.dumps(extraction_raw)
    explanation_raw_json = json.dumps(explanation_raw)

    target_month_sql = "NULL"

    if target_forecast_month is not None:
        target_month_sql = f"TO_DATE('{str(target_forecast_month)}')"

    assessment_notes = (
        "Advisory-only Cortex FMIS signal assist. "
        "Official FMIS multiplier remains controlled by MATERIAL_INDEX_FORECASTS or future ML forecasting."
    )

    session.sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.CORTEX_FMIS_SIGNAL_ASSIST t
        USING (
            SELECT
                '{note_id}' AS MARKET_NOTE_ID
        ) s
        ON t.MARKET_NOTE_ID = s.MARKET_NOTE_ID

        WHEN MATCHED THEN UPDATE SET
            t.COMMODITY_GROUP = '{sql_escape(input_commodity_group)}',
            t.TARGET_FORECAST_MONTH = {target_month_sql},
            t.CORTEX_EXTRACTED_COMMODITY = '{sql_escape(extracted_commodity)}',
            t.CORTEX_PRICE_DIRECTION = '{sql_escape(price_direction)}',
            t.CORTEX_RISK_LEVEL = '{sql_escape(risk_level)}',
            t.CORTEX_SIGNAL_TIME_HORIZON = '{sql_escape(signal_time_horizon)}',
            t.CORTEX_KEY_DRIVERS = '{sql_escape(key_drivers)}',
            t.CORTEX_SUPPLIER_IMPACT = '{sql_escape(supplier_impact)}',
            t.CORTEX_MARKET_SUMMARY = '{sql_escape(market_summary)}',
            t.CORTEX_FMIS_EXPLANATION = '{sql_escape(fmis_explanation)}',
            t.CORTEX_REVIEW_NOTE = '{sql_escape(review_note)}',
            t.CORTEX_EXTRACTION_RAW = TO_VARIANT('{sql_escape(extraction_raw_json)}'),
            t.CORTEX_EXPLANATION_RAW = TO_VARIANT('{sql_escape(explanation_raw_json)}'),
            t.OFFICIAL_FMIS_OVERRIDE_FLAG = FALSE,
            t.ASSIST_METHOD = 'CORTEX_FMIS_SIGNAL_ASSIST_V1',
            t.ASSESSMENT_STATUS = 'SUCCESS',
            t.ASSESSMENT_NOTES = '{sql_escape(assessment_notes)}',
            t.UPDATED_AT = CURRENT_TIMESTAMP()

        WHEN NOT MATCHED THEN INSERT (
            MARKET_NOTE_ID,
            COMMODITY_GROUP,
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
            CORTEX_EXTRACTION_RAW,
            CORTEX_EXPLANATION_RAW,
            OFFICIAL_FMIS_OVERRIDE_FLAG,
            ASSIST_METHOD,
            ASSESSMENT_STATUS,
            ASSESSMENT_NOTES
        )
        VALUES (
            '{note_id}',
            '{sql_escape(input_commodity_group)}',
            {target_month_sql},
            '{sql_escape(extracted_commodity)}',
            '{sql_escape(price_direction)}',
            '{sql_escape(risk_level)}',
            '{sql_escape(signal_time_horizon)}',
            '{sql_escape(key_drivers)}',
            '{sql_escape(supplier_impact)}',
            '{sql_escape(market_summary)}',
            '{sql_escape(fmis_explanation)}',
            '{sql_escape(review_note)}',
            TO_VARIANT('{sql_escape(extraction_raw_json)}'),
            TO_VARIANT('{sql_escape(explanation_raw_json)}'),
            FALSE,
            'CORTEX_FMIS_SIGNAL_ASSIST_V1',
            'SUCCESS',
            '{sql_escape(assessment_notes)}'
        )
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "market_note_id": MARKET_NOTE_ID,
        "input_commodity_group": input_commodity_group,
        "target_forecast_month": str(target_forecast_month) if target_forecast_month is not None else None,
        "cortex_extracted_commodity": extracted_commodity,
        "cortex_price_direction": price_direction,
        "cortex_risk_level": risk_level,
        "cortex_signal_time_horizon": signal_time_horizon,
        "cortex_key_drivers": key_drivers,
        "cortex_supplier_impact": supplier_impact,
        "cortex_market_summary": market_summary,
        "cortex_fmis_explanation": fmis_explanation,
        "cortex_review_note": review_note,
        "official_fmis_override_flag": False,
        "assist_method": "CORTEX_FMIS_SIGNAL_ASSIST_V1"
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE VIEW CORE_INPUT.VW_CORTEX_FMIS_SIGNAL_ASSIST AS
SELECT
    n.MARKET_NOTE_ID,
    n.SOURCE_NAME,
    n.NOTE_TITLE,
    n.COMMODITY_GROUP AS INPUT_COMMODITY_GROUP,
    n.TARGET_FORECAST_MONTH,

    a.CORTEX_EXTRACTED_COMMODITY,
    a.CORTEX_PRICE_DIRECTION,
    a.CORTEX_RISK_LEVEL,
    a.CORTEX_SIGNAL_TIME_HORIZON,
    a.CORTEX_KEY_DRIVERS,
    a.CORTEX_SUPPLIER_IMPACT,

    a.CORTEX_MARKET_SUMMARY,
    a.CORTEX_FMIS_EXPLANATION,
    a.CORTEX_REVIEW_NOTE,

    a.OFFICIAL_FMIS_OVERRIDE_FLAG,
    a.ASSIST_METHOD,
    a.ASSESSMENT_STATUS,
    a.ASSESSMENT_NOTES,
    a.UPDATED_AT
FROM CORE_INPUT.COMMODITY_MARKET_NOTES n
LEFT JOIN CORE_INPUT.CORTEX_FMIS_SIGNAL_ASSIST a
    ON n.MARKET_NOTE_ID = a.MARKET_NOTE_ID
WHERE n.ACTIVE_FLAG = TRUE;

MERGE INTO CORE_INPUT.COMMODITY_MARKET_NOTES t
USING (
    SELECT
        'NOTE_STEEL_001' AS MARKET_NOTE_ID,
        'STEEL' AS COMMODITY_GROUP,
        'Supplier Market Update' AS SOURCE_NAME,
        'Steel price pressure for Q3 production' AS NOTE_TITLE,
        'Steel suppliers are warning of upward price pressure for the next quarter due to higher energy costs, port delays, and reduced mill capacity. Procurement expects higher landed cost risk for production scheduled in September.' AS NOTE_TEXT,
        TO_DATE('2026-09-01') AS TARGET_FORECAST_MONTH,
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
);

CALL CORE_INTERNAL.RUN_CORTEX_FMIS_SIGNAL_ASSIST('NOTE_STEEL_001');
SELECT
    MARKET_NOTE_ID,
    INPUT_COMMODITY_GROUP,
    TARGET_FORECAST_MONTH,
    CORTEX_EXTRACTED_COMMODITY,
    CORTEX_PRICE_DIRECTION,
    CORTEX_RISK_LEVEL,
    CORTEX_KEY_DRIVERS,
    OFFICIAL_FMIS_OVERRIDE_FLAG,
    ASSIST_METHOD,
    CORTEX_FMIS_EXPLANATION,
    CORTEX_REVIEW_NOTE
FROM CORE_INPUT.VW_CORTEX_FMIS_SIGNAL_ASSIST
WHERE MARKET_NOTE_ID = 'NOTE_STEEL_001';

-- PHASE 7E TDS
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE TABLE IF NOT EXISTS CORE_INPUT.TOOLING_MAINTENANCE_NOTES (
    MAINTENANCE_NOTE_ID     VARCHAR,
    SIMULATION_ID           VARCHAR,
    WORK_CENTER_ID          VARCHAR,
    SOURCE_NAME             VARCHAR,
    NOTE_TITLE              VARCHAR,
    NOTE_TEXT               VARCHAR,
    NOTE_STATUS             VARCHAR,
    ACTIVE_FLAG             BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS CORE_INPUT.CORTEX_TDS_EXPLANATION_ASSIST (
    SIMULATION_ID                     VARCHAR,
    KMAT_ID                           VARCHAR,
    MAINTENANCE_NOTE_ID               VARCHAR,

    OFFICIAL_MAX_TDS_FACTOR            NUMBER(10,4),
    OFFICIAL_TOOLING_ADJUSTMENT_USD    NUMBER(18,4),

    CORTEX_TOOLING_STRAIN_BAND         VARCHAR,
    CORTEX_EXTRACTED_WORK_CENTER       VARCHAR,
    CORTEX_EXTRACTED_STRAIN_SIGNAL     VARCHAR,
    CORTEX_EXTRACTED_SEVERITY          VARCHAR,
    CORTEX_EXTRACTED_RELATED_OPERATION VARCHAR,
    CORTEX_EXTRACTED_IMPACT            VARCHAR,

    CORTEX_REASONING                   VARCHAR,
    CORTEX_ENGINEERING_REVIEW_NOTE      VARCHAR,

    CORTEX_CLASSIFICATION_RAW          VARIANT,
    CORTEX_EXTRACTION_RAW              VARIANT,
    CORTEX_REASONING_RAW               VARIANT,

    ASSIST_METHOD                      VARCHAR,
    OFFICIAL_COST_OVERRIDE_FLAG         BOOLEAN,
    ASSESSMENT_STATUS                  VARCHAR,
    ASSESSMENT_NOTES                   VARCHAR,

    CREATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_TDS_EXPLANATION_ASSIST(
    SIMULATION_ID STRING,
    MAINTENANCE_NOTE_ID STRING
)
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


def to_float(value, default=0.0):
    if value is None:
        return default
    try:
        return float(value)
    except Exception:
        return default


def normalize_text(value):
    if value is None:
        return ""
    return str(value).strip().upper()


def parse_json_safe(value, depth=0):
    """
    Always returns a dictionary.
    Also handles nested JSON strings returned by AI_COMPLETE.
    Prevents:
    - 'str' object has no attribute 'get'
    - JSON-looking text being stored as the full reasoning value
    """
    if depth > 3:
        return {"raw_text": str(value)}

    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        text = value.strip()

        text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
        text = re.sub(r"^```", "", text).strip()
        text = re.sub(r"```$", "", text).strip()

        try:
            parsed = json.loads(text)

            if isinstance(parsed, dict):
                return parsed

            if isinstance(parsed, str):
                return parse_json_safe(parsed, depth + 1)

            return {"raw_text": str(parsed)}

        except Exception:
            pass

        match = re.search(r"\{.*\}", text, re.DOTALL)

        if match:
            try:
                parsed = json.loads(match.group(0))

                if isinstance(parsed, dict):
                    return parsed

                if isinstance(parsed, str):
                    return parse_json_safe(parsed, depth + 1)

                return {"raw_text": str(parsed)}

            except Exception:
                return {"raw_text": text}

        return {"raw_text": text}

    try:
        parsed = dict(value)

        if isinstance(parsed, dict):
            return parsed

        return {"raw_text": str(parsed)}

    except Exception:
        return {"raw_text": str(value)}


def unwrap_tds_reasoning_object(obj):
    """
    AI_COMPLETE can return:
    1. Direct JSON dict
    2. JSON string inside raw_text
    3. JSON string inside response/text/content/message/output
    This helper extracts the real TDS explanation JSON.
    """
    if not isinstance(obj, dict):
        return {"raw_text": str(obj)}

    if "reasoning" in obj or "engineering_review_note" in obj:
        return obj

    for key in ["raw_text", "response", "text", "content", "message", "output"]:
        value = obj.get(key)

        if isinstance(value, str):
            parsed = parse_json_safe(value)

            if isinstance(parsed, dict) and (
                "reasoning" in parsed or "engineering_review_note" in parsed
            ):
                return parsed

    return obj


def get_nested(obj, key):
    if not isinstance(obj, dict):
        return None

    if key in obj:
        return obj[key]

    for k, v in obj.items():
        if str(k).upper() == str(key).upper():
            return v

    return None


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def extract_classification_label(raw_obj, official_max_tds):
    allowed = {
        "LOW_TOOLING_STRAIN",
        "MEDIUM_TOOLING_STRAIN",
        "HIGH_TOOLING_STRAIN"
    }

    if isinstance(raw_obj, str):
        text = raw_obj.upper()
        for label in allowed:
            if label in text:
                return label

    if isinstance(raw_obj, dict):
        for key in ["label", "classification", "result", "category"]:
            value = raw_obj.get(key)
            if isinstance(value, str) and value.upper() in allowed:
                return value.upper()

        labels = raw_obj.get("labels")
        if isinstance(labels, list) and len(labels) > 0:
            first = labels[0]

            if isinstance(first, str) and first.upper() in allowed:
                return first.upper()

            if isinstance(first, dict):
                for key in ["label", "classification", "category"]:
                    value = first.get(key)
                    if isinstance(value, str) and value.upper() in allowed:
                        return value.upper()

        raw_text = json.dumps(raw_obj).upper()
        for label in allowed:
            if label in raw_text:
                return label

    if official_max_tds >= 1.40:
        return "HIGH_TOOLING_STRAIN"

    if official_max_tds >= 1.15:
        return "MEDIUM_TOOLING_STRAIN"

    return "LOW_TOOLING_STRAIN"


def normalize_severity(value):
    text = normalize_text(value)

    if text in ("LOW", "MEDIUM", "HIGH", "UNKNOWN"):
        return text

    if "HIGH" in text or "SEVERE" in text or "CRITICAL" in text:
        return "HIGH"

    if "MEDIUM" in text or "MODERATE" in text:
        return "MEDIUM"

    if "LOW" in text or "MINOR" in text:
        return "LOW"

    return "UNKNOWN"


def run(session, SIMULATION_ID, MAINTENANCE_NOTE_ID):
    sim_id = sql_escape(SIMULATION_ID)

    note_id_value = str(MAINTENANCE_NOTE_ID or "").strip()
    note_id_key = note_id_value if note_id_value else "NO_NOTE"
    note_id_sql = sql_escape(note_id_key)

    # ------------------------------------------------------------
    # 1. Read official deterministic cost summary
    # ------------------------------------------------------------
    summary_rows = session.sql(f"""
        SELECT
            SIMULATION_ID,
            KMAT_ID,
            MAX_TDS_FACTOR,
            TOOLING_ADJUSTMENT_USD,
            BASELINE_MACHINE_COST_USD,
            RISK_ADJUSTED_MACHINE_COST_USD
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        WHERE SIMULATION_ID = '{sim_id}'
        LIMIT 1
    """).collect()

    if len(summary_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": "No cost summary found. Run RUN_KMAT_COST_SIMULATION first.",
            "simulation_id": SIMULATION_ID
        })

    summary = summary_rows[0]
    kmat_id = summary["KMAT_ID"]

    official_max_tds = to_float(summary["MAX_TDS_FACTOR"], 1.0)
    official_tooling_adjustment = to_float(summary["TOOLING_ADJUSTMENT_USD"], 0.0)

    # ------------------------------------------------------------
    # 2. Read selected configuration
    # ------------------------------------------------------------
    config_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            SELECTED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        WHERE SIMULATION_ID = '{sim_id}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
        ORDER BY CHARACTERISTIC_NAME
    """).collect()

    selected_config = {}

    for row in config_rows:
        selected_config[row["CHARACTERISTIC_NAME"]] = row["SELECTED_VALUE"]

    # ------------------------------------------------------------
    # 3. Read official operation TDS details
    # ------------------------------------------------------------
    operation_rows = session.sql(f"""
        SELECT
            OPERATION_ID,
            OPERATION_DESCRIPTION,
            WORK_CENTER_ID,
            MACHINE_HOURS,
            BASE_MACHINE_COST_USD,
            TDS_FACTOR,
            ADJUSTED_MACHINE_RATE_USD_PER_HOUR,
            TOOLING_ADJUSTMENT_USD,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
        WHERE SIMULATION_ID = '{sim_id}'
        ORDER BY TDS_FACTOR DESC, OPERATION_ID
    """).collect()

    operations = []

    for row in operation_rows:
        operations.append({
            "operation_id": row["OPERATION_ID"],
            "description": row["OPERATION_DESCRIPTION"],
            "work_center_id": row["WORK_CENTER_ID"],
            "machine_hours": to_float(row["MACHINE_HOURS"], 0.0),
            "base_machine_cost_usd": to_float(row["BASE_MACHINE_COST_USD"], 0.0),
            "tds_factor": to_float(row["TDS_FACTOR"], 1.0),
            "tooling_adjustment_usd": to_float(row["TOOLING_ADJUSTMENT_USD"], 0.0),
            "risk_notes": row["RISK_ADJUSTMENT_NOTES"]
        })

    # ------------------------------------------------------------
    # 4. Read optional maintenance note
    # ------------------------------------------------------------
    note_text = ""
    note_title = ""
    note_source = ""
    note_work_center = ""

    if note_id_value:
        note_rows = session.sql(f"""
            SELECT
                MAINTENANCE_NOTE_ID,
                WORK_CENTER_ID,
                SOURCE_NAME,
                NOTE_TITLE,
                NOTE_TEXT
            FROM {DB_NAME}.CORE_INPUT.TOOLING_MAINTENANCE_NOTES
            WHERE MAINTENANCE_NOTE_ID = '{sql_escape(note_id_value)}'
              AND ACTIVE_FLAG = TRUE
            LIMIT 1
        """).collect()

        if len(note_rows) == 0:
            return json.dumps({
                "status": "ERROR",
                "message": f"MAINTENANCE_NOTE_ID {MAINTENANCE_NOTE_ID} not found."
            })

        note = note_rows[0]
        note_text = note["NOTE_TEXT"] or ""
        note_title = note["NOTE_TITLE"] or ""
        note_source = note["SOURCE_NAME"] or ""
        note_work_center = note["WORK_CENTER_ID"] or ""

    # ------------------------------------------------------------
    # 5. AI_EXTRACT maintenance/tooling signal if note exists
    # ------------------------------------------------------------
    extraction_raw = {}
    extracted_work_center = note_work_center or "UNKNOWN"
    extracted_strain_signal = "NO_NOTE_PROVIDED"
    extracted_severity = "UNKNOWN"
    extracted_related_operation = "UNKNOWN"
    extracted_impact = "No maintenance note was provided."

    if note_text.strip():
        response_format = {
            "WORK_CENTER_ID": (
                "Extract the work center or machine area mentioned. "
                "Return a short value such as WC_ASSEMBLY, WC_PAINT, WC_QA, or UNKNOWN."
            ),
            "STRAIN_SIGNAL": (
                "Extract the tooling or machine strain signal, such as abnormal vibration, die wear, fixture wear, overheating, repeated stoppage, calibration drift, or unknown."
            ),
            "SEVERITY": (
                "Extract severity. Return exactly one of: LOW, MEDIUM, HIGH, UNKNOWN."
            ),
            "RELATED_OPERATION": (
                "Extract the related operation or build type if mentioned. Return a short phrase."
            ),
            "MAINTENANCE_IMPACT": (
                "Extract expected maintenance/tooling impact. Return a short phrase."
            )
        }

        response_format_json = json.dumps(response_format)

        try:
            extract_rows = session.sql(f"""
                SELECT TO_JSON(
                    AI_EXTRACT(
                        text => '{sql_escape(note_text)}',
                        responseFormat => PARSE_JSON('{sql_escape(response_format_json)}'),
                        scores => TRUE
                    )
                ) AS EXTRACTION_JSON
            """).collect()

            extraction_raw_text = extract_rows[0]["EXTRACTION_JSON"] if extract_rows else "{}"
            extraction_raw = parse_json_safe(extraction_raw_text)

            response_obj = get_nested(extraction_raw, "response")

            if response_obj is None:
                response_obj = extraction_raw

            if not isinstance(response_obj, dict):
                response_obj = {}

            extracted_work_center = str(get_nested(response_obj, "WORK_CENTER_ID") or note_work_center or "UNKNOWN")
            extracted_strain_signal = str(get_nested(response_obj, "STRAIN_SIGNAL") or "UNKNOWN")
            extracted_severity = normalize_severity(get_nested(response_obj, "SEVERITY"))
            extracted_related_operation = str(get_nested(response_obj, "RELATED_OPERATION") or "UNKNOWN")
            extracted_impact = str(get_nested(response_obj, "MAINTENANCE_IMPACT") or "UNKNOWN")

        except Exception as exc:
            extraction_raw = {
                "error": str(exc)
            }
            extracted_strain_signal = "EXTRACTION_FAILED"
            extracted_impact = "AI_EXTRACT failed. Use manual maintenance review."

    # ------------------------------------------------------------
    # 6. AI_CLASSIFY advisory tooling strain band
    # ------------------------------------------------------------
    classification_input = f"""
This is an advisory tooling-strain classification for a KMAT manufacturing cost model.

Do not calculate official machine cost.
Do not change the official TDS factor.
Do not override the deterministic cost engine.

Selected KMAT configuration:
{json.dumps(selected_config)}

Official max TDS factor:
{official_max_tds}

Official tooling adjustment USD:
{official_tooling_adjustment}

Selected operations and official TDS:
{json.dumps(operations[:30])}

Maintenance note title:
{note_title}

Maintenance note source:
{note_source}

Extracted maintenance signal:
{extracted_strain_signal}

Extracted severity:
{extracted_severity}

Extracted impact:
{extracted_impact}

Classify into exactly one category:
LOW_TOOLING_STRAIN, MEDIUM_TOOLING_STRAIN, HIGH_TOOLING_STRAIN
"""

    try:
        classify_rows = session.sql(f"""
            SELECT TO_JSON(
                AI_CLASSIFY(
                    '{sql_escape(classification_input)}',
                    ARRAY_CONSTRUCT(
                        'LOW_TOOLING_STRAIN',
                        'MEDIUM_TOOLING_STRAIN',
                        'HIGH_TOOLING_STRAIN'
                    )
                )
            ) AS CLASSIFICATION_JSON
        """).collect()

        classification_raw_text = classify_rows[0]["CLASSIFICATION_JSON"] if classify_rows else "{}"
        classification_raw = parse_json_safe(classification_raw_text)
        cortex_tooling_strain_band = extract_classification_label(classification_raw, official_max_tds)

    except Exception as exc:
        classification_raw = {
            "error": str(exc),
            "fallback_based_on_official_tds": official_max_tds
        }
        cortex_tooling_strain_band = extract_classification_label(classification_raw, official_max_tds)

    # ------------------------------------------------------------
    # 7. AI_COMPLETE explanation
    # ------------------------------------------------------------
    model_name = get_ai_complete_model(session)

    reasoning_prompt = f"""
You are explaining tooling strain for a KMAT manufacturing cost model.

Write STRICT JSON only. No markdown. No extra text.

Rules:
- Do not calculate machine cost.
- Do not change the official TDS factor.
- Do not override the deterministic cost engine.
- Explain why the official TDS and tooling adjustment make sense or need engineering review.

Return this JSON shape:
{{
  "reasoning": "short business explanation",
  "engineering_review_note": "short engineering review note"
}}

Selected KMAT configuration:
{json.dumps(selected_config)}

Official max TDS factor:
{official_max_tds}

Official tooling adjustment USD:
{official_tooling_adjustment}

Selected operations and official TDS:
{json.dumps(operations[:30])}

Cortex advisory tooling strain band:
{cortex_tooling_strain_band}

Maintenance note:
{note_text[:4000]}
"""

    try:
        reasoning_rows = session.sql(f"""
            SELECT AI_COMPLETE(
                '{sql_escape(model_name)}',
                '{sql_escape(reasoning_prompt)}'
            ) AS REASONING_TEXT
        """).collect()

        reasoning_text = reasoning_rows[0]["REASONING_TEXT"] if reasoning_rows else ""

        reasoning_obj = parse_json_safe(reasoning_text)
        reasoning_obj = unwrap_tds_reasoning_object(reasoning_obj)

        if not isinstance(reasoning_obj, dict):
            reasoning_obj = {
                "raw_text": str(reasoning_text)
            }

        cortex_reasoning = reasoning_obj.get("reasoning")

        if cortex_reasoning is None or str(cortex_reasoning).strip() == "":
            cortex_reasoning = reasoning_obj.get("raw_text", str(reasoning_text))

        cortex_review_note = reasoning_obj.get("engineering_review_note")

        if cortex_review_note is None or str(cortex_review_note).strip() == "":
            cortex_review_note = "Review official TDS drivers if tooling strain appears unusual or maintenance history is incomplete."

        reasoning_raw = {
            "model": model_name,
            "prompt_version": "TDS_EXPLANATION_ASSIST_V1",
            "raw_text": str(reasoning_text),
            "parsed": reasoning_obj
        }

    except Exception as exc:
        cortex_reasoning = f"AI_COMPLETE failed: {str(exc)}"
        cortex_review_note = "Cortex explanation failed. Use deterministic TDS output and engineering review if needed."
        reasoning_raw = {
            "error": str(exc),
            "model": model_name,
            "prompt_version": "TDS_EXPLANATION_ASSIST_V1"
        }

    # ------------------------------------------------------------
    # 8. Store advisory-only result
    # Raw Cortex outputs are stored with TO_VARIANT, not PARSE_JSON.
    # This avoids JSON parse errors from braces/quotes in model text.
    # ------------------------------------------------------------
    classification_raw_json = json.dumps(classification_raw)
    extraction_raw_json = json.dumps(extraction_raw)
    reasoning_raw_json = json.dumps(reasoning_raw)

    assessment_notes = (
        "Advisory-only Cortex TDS explanation. "
        "Official TDS factor and machine cost remain controlled by deterministic cost engine."
    )

    session.sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.CORTEX_TDS_EXPLANATION_ASSIST t
        USING (
            SELECT
                '{sim_id}' AS SIMULATION_ID,
                '{sql_escape(kmat_id)}' AS KMAT_ID,
                '{note_id_sql}' AS MAINTENANCE_NOTE_ID
        ) s
        ON t.SIMULATION_ID = s.SIMULATION_ID
           AND t.KMAT_ID = s.KMAT_ID
           AND t.MAINTENANCE_NOTE_ID = s.MAINTENANCE_NOTE_ID

        WHEN MATCHED THEN UPDATE SET
            t.OFFICIAL_MAX_TDS_FACTOR = {official_max_tds},
            t.OFFICIAL_TOOLING_ADJUSTMENT_USD = {official_tooling_adjustment},
            t.CORTEX_TOOLING_STRAIN_BAND = '{sql_escape(cortex_tooling_strain_band)}',
            t.CORTEX_EXTRACTED_WORK_CENTER = '{sql_escape(extracted_work_center)}',
            t.CORTEX_EXTRACTED_STRAIN_SIGNAL = '{sql_escape(extracted_strain_signal)}',
            t.CORTEX_EXTRACTED_SEVERITY = '{sql_escape(extracted_severity)}',
            t.CORTEX_EXTRACTED_RELATED_OPERATION = '{sql_escape(extracted_related_operation)}',
            t.CORTEX_EXTRACTED_IMPACT = '{sql_escape(extracted_impact)}',
            t.CORTEX_REASONING = '{sql_escape(cortex_reasoning)}',
            t.CORTEX_ENGINEERING_REVIEW_NOTE = '{sql_escape(cortex_review_note)}',
            t.CORTEX_CLASSIFICATION_RAW = TO_VARIANT('{sql_escape(classification_raw_json)}'),
            t.CORTEX_EXTRACTION_RAW = TO_VARIANT('{sql_escape(extraction_raw_json)}'),
            t.CORTEX_REASONING_RAW = TO_VARIANT('{sql_escape(reasoning_raw_json)}'),
            t.ASSIST_METHOD = 'CORTEX_TDS_EXPLANATION_ASSIST_V1',
            t.OFFICIAL_COST_OVERRIDE_FLAG = FALSE,
            t.ASSESSMENT_STATUS = 'SUCCESS',
            t.ASSESSMENT_NOTES = '{sql_escape(assessment_notes)}',
            t.UPDATED_AT = CURRENT_TIMESTAMP()

        WHEN NOT MATCHED THEN INSERT (
            SIMULATION_ID,
            KMAT_ID,
            MAINTENANCE_NOTE_ID,
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
            CORTEX_CLASSIFICATION_RAW,
            CORTEX_EXTRACTION_RAW,
            CORTEX_REASONING_RAW,
            ASSIST_METHOD,
            OFFICIAL_COST_OVERRIDE_FLAG,
            ASSESSMENT_STATUS,
            ASSESSMENT_NOTES
        )
        VALUES (
            '{sim_id}',
            '{sql_escape(kmat_id)}',
            '{note_id_sql}',
            {official_max_tds},
            {official_tooling_adjustment},
            '{sql_escape(cortex_tooling_strain_band)}',
            '{sql_escape(extracted_work_center)}',
            '{sql_escape(extracted_strain_signal)}',
            '{sql_escape(extracted_severity)}',
            '{sql_escape(extracted_related_operation)}',
            '{sql_escape(extracted_impact)}',
            '{sql_escape(cortex_reasoning)}',
            '{sql_escape(cortex_review_note)}',
            TO_VARIANT('{sql_escape(classification_raw_json)}'),
            TO_VARIANT('{sql_escape(extraction_raw_json)}'),
            TO_VARIANT('{sql_escape(reasoning_raw_json)}'),
            'CORTEX_TDS_EXPLANATION_ASSIST_V1',
            FALSE,
            'SUCCESS',
            '{sql_escape(assessment_notes)}'
        )
    """).collect()

    return json.dumps({
        "status": "SUCCESS",
        "simulation_id": SIMULATION_ID,
        "kmat_id": kmat_id,
        "maintenance_note_id": note_id_key,
        "official_max_tds_factor": official_max_tds,
        "official_tooling_adjustment_usd": official_tooling_adjustment,
        "cortex_tooling_strain_band": cortex_tooling_strain_band,
        "cortex_extracted_work_center": extracted_work_center,
        "cortex_extracted_strain_signal": extracted_strain_signal,
        "cortex_extracted_severity": extracted_severity,
        "cortex_extracted_related_operation": extracted_related_operation,
        "cortex_extracted_impact": extracted_impact,
        "cortex_reasoning": cortex_reasoning,
        "cortex_engineering_review_note": cortex_review_note,
        "official_cost_override_flag": False,
        "assist_method": "CORTEX_TDS_EXPLANATION_ASSIST_V1"
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE VIEW CORE_INPUT.VW_CORTEX_TDS_EXPLANATION_ASSIST AS
SELECT
    a.SIMULATION_ID,
    a.KMAT_ID,
    a.MAINTENANCE_NOTE_ID,

    LISTAGG(cv.CHARACTERISTIC_NAME || '=' || cv.SELECTED_VALUE, ', ')
        WITHIN GROUP (ORDER BY cv.CHARACTERISTIC_NAME) AS CONFIGURATION,

    a.OFFICIAL_MAX_TDS_FACTOR,
    a.OFFICIAL_TOOLING_ADJUSTMENT_USD,

    a.CORTEX_TOOLING_STRAIN_BAND,
    a.CORTEX_EXTRACTED_WORK_CENTER,
    a.CORTEX_EXTRACTED_STRAIN_SIGNAL,
    a.CORTEX_EXTRACTED_SEVERITY,
    a.CORTEX_EXTRACTED_RELATED_OPERATION,
    a.CORTEX_EXTRACTED_IMPACT,

    a.CORTEX_REASONING,
    a.CORTEX_ENGINEERING_REVIEW_NOTE,

    a.ASSIST_METHOD,
    a.OFFICIAL_COST_OVERRIDE_FLAG,
    a.ASSESSMENT_STATUS,
    a.ASSESSMENT_NOTES,
    a.UPDATED_AT
FROM CORE_INPUT.CORTEX_TDS_EXPLANATION_ASSIST a
LEFT JOIN CORE_INPUT.CHARACTERISTIC_VALUES cv
    ON a.SIMULATION_ID = cv.SIMULATION_ID
   AND a.KMAT_ID = cv.KMAT_ID
GROUP BY
    a.SIMULATION_ID,
    a.KMAT_ID,
    a.MAINTENANCE_NOTE_ID,
    a.OFFICIAL_MAX_TDS_FACTOR,
    a.OFFICIAL_TOOLING_ADJUSTMENT_USD,
    a.CORTEX_TOOLING_STRAIN_BAND,
    a.CORTEX_EXTRACTED_WORK_CENTER,
    a.CORTEX_EXTRACTED_STRAIN_SIGNAL,
    a.CORTEX_EXTRACTED_SEVERITY,
    a.CORTEX_EXTRACTED_RELATED_OPERATION,
    a.CORTEX_EXTRACTED_IMPACT,
    a.CORTEX_REASONING,
    a.CORTEX_ENGINEERING_REVIEW_NOTE,
    a.ASSIST_METHOD,
    a.OFFICIAL_COST_OVERRIDE_FLAG,
    a.ASSESSMENT_STATUS,
    a.ASSESSMENT_NOTES,
    a.UPDATED_AT;

MERGE INTO CORE_INPUT.TOOLING_MAINTENANCE_NOTES t
USING (
    SELECT
        'NOTE_TDS_001' AS MAINTENANCE_NOTE_ID,
        'SIM_RFQ_001' AS SIMULATION_ID,
        'WC_ASSEMBLY' AS WORK_CENTER_ID,
        'Maintenance Log' AS SOURCE_NAME,
        'Assembly tooling strain on V8 offroad build' AS NOTE_TITLE,
        'Assembly fixture showed abnormal vibration during V8 offroad builds. Maintenance observed faster fixture wear after premium cab and offroad wheel batches. Engineering recommends monitoring clamp alignment and fixture wear before larger production runs.' AS NOTE_TEXT,
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
);

CALL CORE_INTERNAL.RUN_CORTEX_TDS_EXPLANATION_ASSIST('SIM_RFQ_001', 'NOTE_TDS_001');
CALL CORE_INTERNAL.RUN_CORTEX_TDS_EXPLANATION_ASSIST('SIM_RFQ_001', NULL);

SELECT
    SIMULATION_ID,
    CONFIGURATION,
    MAINTENANCE_NOTE_ID,
    OFFICIAL_MAX_TDS_FACTOR,
    OFFICIAL_TOOLING_ADJUSTMENT_USD,
    CORTEX_TOOLING_STRAIN_BAND,
    CORTEX_EXTRACTED_WORK_CENTER,
    CORTEX_EXTRACTED_STRAIN_SIGNAL,
    CORTEX_EXTRACTED_SEVERITY,
    OFFICIAL_COST_OVERRIDE_FLAG,
    ASSIST_METHOD,
    CORTEX_REASONING,
    CORTEX_ENGINEERING_REVIEW_NOTE
FROM CORE_INPUT.VW_CORTEX_TDS_EXPLANATION_ASSIST
ORDER BY UPDATED_AT DESC;

-- 7F 
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE TABLE IF NOT EXISTS CORE_INPUT.CORTEX_COST_EXPLANATION_SUMMARY (
    SIMULATION_ID                    VARCHAR,
    KMAT_ID                          VARCHAR,
    RFQ_ID                           VARCHAR,

    EXECUTIVE_SUMMARY                VARCHAR,
    COST_DRIVER_EXPLANATION          VARCHAR,
    RISK_UPLIFT_EXPLANATION          VARCHAR,
    BMCS_TRUST_EXPLANATION           VARCHAR,
    ENGINEERING_REVIEW_NOTE          VARCHAR,

    CORTEX_RAW_RESPONSE              VARIANT,
    ASSIST_METHOD                    VARCHAR,
    OFFICIAL_COST_OVERRIDE_FLAG      BOOLEAN,
    ASSESSMENT_STATUS                VARCHAR,
    ASSESSMENT_NOTES                 VARCHAR,

    CREATED_AT                       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

USE SCHEMA CORE_INTERNAL;

CREATE OR REPLACE PROCEDURE CORE_INTERNAL.RUN_CORTEX_COST_EXPLANATION(
    SIMULATION_ID STRING
)
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


def sql_literal(value):
    if value is None:
        return "NULL"
    return "'" + sql_escape(value) + "'"


def to_float(value, default=0.0):
    if value is None:
        return default
    try:
        return float(value)
    except Exception:
        return default


def parse_json_safe(value, depth=0):
    """
    Always returns a dictionary.
    Handles:
    - direct JSON object
    - JSON string
    - nested JSON string returned by AI_COMPLETE
    - markdown-wrapped JSON
    - plain text fallback
    """
    if depth > 3:
        return {"raw_text": str(value)}

    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        text = value.strip()

        text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
        text = re.sub(r"^```", "", text).strip()
        text = re.sub(r"```$", "", text).strip()

        try:
            parsed = json.loads(text)

            if isinstance(parsed, dict):
                return parsed

            if isinstance(parsed, str):
                return parse_json_safe(parsed, depth + 1)

            return {"raw_text": str(parsed)}

        except Exception:
            pass

        match = re.search(r"\{.*\}", text, re.DOTALL)

        if match:
            try:
                parsed = json.loads(match.group(0))

                if isinstance(parsed, dict):
                    return parsed

                if isinstance(parsed, str):
                    return parse_json_safe(parsed, depth + 1)

                return {"raw_text": str(parsed)}

            except Exception:
                return {"raw_text": text}

        return {"raw_text": text}

    try:
        parsed = dict(value)

        if isinstance(parsed, dict):
            return parsed

        return {"raw_text": str(parsed)}

    except Exception:
        return {"raw_text": str(value)}


def unwrap_cost_explanation_object(obj):
    """
    AI_COMPLETE can return the required JSON directly, or nested inside
    raw_text/response/text/content/message/output.
    """
    expected_keys = {
        "executive_summary",
        "cost_driver_explanation",
        "risk_uplift_explanation",
        "bmcs_trust_explanation",
        "engineering_review_note"
    }

    if not isinstance(obj, dict):
        return {"raw_text": str(obj)}

    if any(k in obj for k in expected_keys):
        return obj

    for key in ["raw_text", "response", "text", "content", "message", "output"]:
        value = obj.get(key)

        if isinstance(value, str):
            parsed = parse_json_safe(value)

            if isinstance(parsed, dict) and any(k in parsed for k in expected_keys):
                return parsed

    return obj


def get_string(obj, key, fallback=""):
    if not isinstance(obj, dict):
        return fallback

    value = obj.get(key)

    if value is None:
        return fallback

    value = str(value).strip()

    if value == "":
        return fallback

    return value


def get_ai_complete_model(session):
    rows = session.sql(f"""
        SELECT CONFIG_VALUE
        FROM {DB_NAME}.CORE_INPUT.CORTEX_MODEL_CONFIG
        WHERE CONFIG_KEY = 'AI_COMPLETE_MODEL'
          AND ACTIVE_FLAG = TRUE
        LIMIT 1
    """).collect()

    if len(rows) == 0:
        return "snowflake-arctic"

    return rows[0]["CONFIG_VALUE"]


def run(session, SIMULATION_ID):
    sim_id = sql_escape(SIMULATION_ID)

    # ------------------------------------------------------------
    # 1. Read official deterministic cost summary
    # ------------------------------------------------------------
    summary_rows = session.sql(f"""
        SELECT
            SIMULATION_ID,
            KMAT_ID,

            RFQ_ID,
            SOURCE_DOCUMENT_NAME,
            BOM_MATCH_CONFIDENCE_SCORE,
            BMCS_REVIEW_STATUS,
            FINAL_TRUSTED_COST_ALLOWED_FLAG,
            QUOTE_TRUST_STATUS,
            BMCS_ASSESSMENT_METHOD,

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
            RISK_CALCULATION_STATUS,
            RISK_CALCULATION_NOTES,

            FLOOR_PRICE_USD,
            TARGET_PRICE_USD,
            CEILING_PRICE_USD
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
        WHERE SIMULATION_ID = '{sim_id}'
        LIMIT 1
    """).collect()

    if len(summary_rows) == 0:
        return json.dumps({
            "status": "ERROR",
            "message": "No cost summary found. Run RUN_KMAT_COST_SIMULATION first.",
            "simulation_id": SIMULATION_ID
        })

    s = summary_rows[0]
    kmat_id = s["KMAT_ID"]
    rfq_id = s["RFQ_ID"]

    official_summary = {
        "simulation_id": s["SIMULATION_ID"],
        "kmat_id": s["KMAT_ID"],
        "rfq_id": s["RFQ_ID"],
        "source_document_name": s["SOURCE_DOCUMENT_NAME"],

        "baseline_material_cost_usd": to_float(s["BASELINE_MATERIAL_COST_USD"]),
        "baseline_labor_cost_usd": to_float(s["BASELINE_LABOR_COST_USD"]),
        "baseline_machine_cost_usd": to_float(s["BASELINE_MACHINE_COST_USD"]),
        "baseline_overhead_cost_usd": to_float(s["BASELINE_OVERHEAD_COST_USD"]),
        "baseline_total_cost_usd": to_float(s["BASELINE_TOTAL_COST_USD"]),

        "css_score": to_float(s["CSS_SCORE"]),
        "scrap_rate_applied": to_float(s["SCRAP_RATE_APPLIED"]),
        "scrap_risk_level": s["SCRAP_RISK_LEVEL"],
        "avg_weighted_fmis": to_float(s["AVG_WEIGHTED_FMIS"]),
        "max_tds_factor": to_float(s["MAX_TDS_FACTOR"]),

        "commodity_adjustment_usd": to_float(s["COMMODITY_ADJUSTMENT_USD"]),
        "scrap_adjustment_usd": to_float(s["SCRAP_ADJUSTMENT_USD"]),
        "tooling_adjustment_usd": to_float(s["TOOLING_ADJUSTMENT_USD"]),
        "overhead_adjustment_usd": to_float(s["OVERHEAD_ADJUSTMENT_USD"]),

        "risk_adjusted_material_cost_usd": to_float(s["RISK_ADJUSTED_MATERIAL_COST_USD"]),
        "risk_adjusted_labor_cost_usd": to_float(s["RISK_ADJUSTED_LABOR_COST_USD"]),
        "risk_adjusted_machine_cost_usd": to_float(s["RISK_ADJUSTED_MACHINE_COST_USD"]),
        "risk_adjusted_overhead_cost_usd": to_float(s["RISK_ADJUSTED_OVERHEAD_COST_USD"]),
        "risk_adjusted_total_cost_usd": to_float(s["RISK_ADJUSTED_TOTAL_COST_USD"]),

        "total_risk_uplift_usd": to_float(s["TOTAL_RISK_UPLIFT_USD"]),
        "total_risk_uplift_pct": to_float(s["TOTAL_RISK_UPLIFT_PCT"]),
        "risk_calculation_status": s["RISK_CALCULATION_STATUS"],

        "floor_price_usd": to_float(s["FLOOR_PRICE_USD"]),
        "target_price_usd": to_float(s["TARGET_PRICE_USD"]),
        "ceiling_price_usd": to_float(s["CEILING_PRICE_USD"]),

        "bmcs_score": to_float(s["BOM_MATCH_CONFIDENCE_SCORE"]),
        "bmcs_review_status": s["BMCS_REVIEW_STATUS"],
        "final_trusted_cost_allowed_flag": bool(s["FINAL_TRUSTED_COST_ALLOWED_FLAG"]) if s["FINAL_TRUSTED_COST_ALLOWED_FLAG"] is not None else None,
        "quote_trust_status": s["QUOTE_TRUST_STATUS"],
        "bmcs_assessment_method": s["BMCS_ASSESSMENT_METHOD"]
    }

    # ------------------------------------------------------------
    # 2. Read selected configuration
    # ------------------------------------------------------------
    config_rows = session.sql(f"""
        SELECT
            CHARACTERISTIC_NAME,
            SELECTED_VALUE
        FROM {DB_NAME}.CORE_INPUT.CHARACTERISTIC_VALUES
        WHERE SIMULATION_ID = '{sim_id}'
          AND KMAT_ID = '{sql_escape(kmat_id)}'
        ORDER BY CHARACTERISTIC_NAME
    """).collect()

    selected_config = {}

    for row in config_rows:
        selected_config[row["CHARACTERISTIC_NAME"]] = row["SELECTED_VALUE"]

    # ------------------------------------------------------------
    # 3. Read top material/component drivers
    # ------------------------------------------------------------
    component_rows = session.sql(f"""
        SELECT
            COMPONENT_ID,
            COMPONENT_DESCRIPTION,
            COST_COMPONENT_GROUP,
            BASE_LINE_MATERIAL_COST_USD,
            COMMODITY_ADJUSTMENT_USD,
            SCRAP_ADJUSTMENT_USD,
            ADJUSTED_LINE_MATERIAL_COST_USD,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
        WHERE SIMULATION_ID = '{sim_id}'
        ORDER BY ADJUSTED_LINE_MATERIAL_COST_USD DESC
        LIMIT 10
    """).collect()

    top_components = []

    for row in component_rows:
        top_components.append({
            "component_id": row["COMPONENT_ID"],
            "description": row["COMPONENT_DESCRIPTION"],
            "group": row["COST_COMPONENT_GROUP"],
            "base_line_material_cost_usd": to_float(row["BASE_LINE_MATERIAL_COST_USD"]),
            "commodity_adjustment_usd": to_float(row["COMMODITY_ADJUSTMENT_USD"]),
            "scrap_adjustment_usd": to_float(row["SCRAP_ADJUSTMENT_USD"]),
            "adjusted_line_material_cost_usd": to_float(row["ADJUSTED_LINE_MATERIAL_COST_USD"]),
            "risk_notes": row["RISK_ADJUSTMENT_NOTES"]
        })

    # ------------------------------------------------------------
    # 4. Read top operation / TDS drivers
    # ------------------------------------------------------------
    operation_rows = session.sql(f"""
        SELECT
            OPERATION_ID,
            OPERATION_DESCRIPTION,
            WORK_CENTER_ID,
            LABOR_COST_USD,
            BASE_MACHINE_COST_USD,
            TDS_FACTOR,
            TOOLING_ADJUSTMENT_USD,
            ADJUSTED_MACHINE_COST_USD,
            RISK_ADJUSTMENT_NOTES
        FROM {DB_NAME}.CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
        WHERE SIMULATION_ID = '{sim_id}'
        ORDER BY TOOLING_ADJUSTMENT_USD DESC, TDS_FACTOR DESC, OPERATION_ID
        LIMIT 10
    """).collect()

    top_operations = []

    for row in operation_rows:
        top_operations.append({
            "operation_id": row["OPERATION_ID"],
            "description": row["OPERATION_DESCRIPTION"],
            "work_center_id": row["WORK_CENTER_ID"],
            "labor_cost_usd": to_float(row["LABOR_COST_USD"]),
            "base_machine_cost_usd": to_float(row["BASE_MACHINE_COST_USD"]),
            "tds_factor": to_float(row["TDS_FACTOR"]),
            "tooling_adjustment_usd": to_float(row["TOOLING_ADJUSTMENT_USD"]),
            "adjusted_machine_cost_usd": to_float(row["ADJUSTED_MACHINE_COST_USD"]),
            "risk_notes": row["RISK_ADJUSTMENT_NOTES"]
        })

    # ------------------------------------------------------------
    # 5. Read optional Cortex assist outputs safely
    # ------------------------------------------------------------
    css_assist = {}

    try:
        css_rows = session.sql(f"""
            SELECT
                CORTEX_SCRAP_RISK_BAND,
                CORTEX_REASONING,
                CORTEX_ENGINEERING_REVIEW_NOTE
            FROM {DB_NAME}.CORE_INPUT.CORTEX_CSS_EXPLANATION_ASSIST
            WHERE SIMULATION_ID = '{sim_id}'
              AND KMAT_ID = '{sql_escape(kmat_id)}'
            ORDER BY UPDATED_AT DESC
            LIMIT 1
        """).collect()

        if len(css_rows) > 0:
            css_assist = {
                "cortex_scrap_risk_band": css_rows[0]["CORTEX_SCRAP_RISK_BAND"],
                "cortex_reasoning": css_rows[0]["CORTEX_REASONING"],
                "cortex_engineering_review_note": css_rows[0]["CORTEX_ENGINEERING_REVIEW_NOTE"]
            }

    except Exception as exc:
        css_assist = {
            "status": "NOT_AVAILABLE",
            "message": str(exc)
        }

    tds_assist = {}

    try:
        tds_rows = session.sql(f"""
            SELECT
                CORTEX_TOOLING_STRAIN_BAND,
                CORTEX_EXTRACTED_STRAIN_SIGNAL,
                CORTEX_EXTRACTED_SEVERITY,
                CORTEX_REASONING,
                CORTEX_ENGINEERING_REVIEW_NOTE
            FROM {DB_NAME}.CORE_INPUT.CORTEX_TDS_EXPLANATION_ASSIST
            WHERE SIMULATION_ID = '{sim_id}'
              AND KMAT_ID = '{sql_escape(kmat_id)}'
            ORDER BY UPDATED_AT DESC
            LIMIT 1
        """).collect()

        if len(tds_rows) > 0:
            tds_assist = {
                "cortex_tooling_strain_band": tds_rows[0]["CORTEX_TOOLING_STRAIN_BAND"],
                "cortex_extracted_strain_signal": tds_rows[0]["CORTEX_EXTRACTED_STRAIN_SIGNAL"],
                "cortex_extracted_severity": tds_rows[0]["CORTEX_EXTRACTED_SEVERITY"],
                "cortex_reasoning": tds_rows[0]["CORTEX_REASONING"],
                "cortex_engineering_review_note": tds_rows[0]["CORTEX_ENGINEERING_REVIEW_NOTE"]
            }

    except Exception as exc:
        tds_assist = {
            "status": "NOT_AVAILABLE",
            "message": str(exc)
        }

    # ------------------------------------------------------------
    # 6. AI_COMPLETE executive explanation
    # ------------------------------------------------------------
    model_name = get_ai_complete_model(session)

    prompt = f"""
You are generating an executive explanation for a KMAT manufacturing cost model.

Write STRICT JSON only. No markdown. No extra text.

Rules:
- Do not calculate or change cost.
- Use only the numbers provided.
- Do not invent missing values.
- Explain the deterministic cost output and risk drivers in business language.
- Keep it concise and suitable for finance, costing, manufacturing engineering, and leadership.

Return this JSON shape:
{{
  "executive_summary": "short summary of the quote/cost result",
  "cost_driver_explanation": "main baseline cost drivers",
  "risk_uplift_explanation": "why risk-adjusted cost differs from baseline",
  "bmcs_trust_explanation": "explain quote trust status and review implication",
  "engineering_review_note": "short review note if any"
}}

Selected KMAT configuration:
{json.dumps(selected_config)}

Official cost summary:
{json.dumps(official_summary)}

Top component/material drivers:
{json.dumps(top_components)}

Top operation/TDS drivers:
{json.dumps(top_operations)}

Cortex CSS assist, if available:
{json.dumps(css_assist)}

Cortex TDS assist, if available:
{json.dumps(tds_assist)}
"""

    try:
        rows = session.sql(f"""
            SELECT AI_COMPLETE(
                '{sql_escape(model_name)}',
                '{sql_escape(prompt)}'
            ) AS EXPLANATION_TEXT
        """).collect()

        explanation_text = rows[0]["EXPLANATION_TEXT"] if rows else ""

        explanation_obj = parse_json_safe(explanation_text)
        explanation_obj = unwrap_cost_explanation_object(explanation_obj)

        if not isinstance(explanation_obj, dict):
            explanation_obj = {
                "raw_text": str(explanation_text)
            }

        executive_summary = get_string(
            explanation_obj,
            "executive_summary",
            str(explanation_text)
        )

        cost_driver_explanation = get_string(
            explanation_obj,
            "cost_driver_explanation",
            "Cost drivers are based on the official material, labor, machine, and overhead cost summary."
        )

        risk_uplift_explanation = get_string(
            explanation_obj,
            "risk_uplift_explanation",
            "Risk uplift is based on official CSS, FMIS, TDS, and overhead adjustment outputs."
        )

        bmcs_trust_explanation = get_string(
            explanation_obj,
            "bmcs_trust_explanation",
            "BMCS trust status is based on the latest RFQ/BMCS assessment."
        )

        engineering_review_note = get_string(
            explanation_obj,
            "engineering_review_note",
            "Use official review flags and engineering judgement where required."
        )

        raw_response = {
            "model": model_name,
            "prompt_version": "COST_EXPLANATION_SUMMARY_V1",
            "raw_text": str(explanation_text),
            "parsed": explanation_obj
        }

        assessment_status = "SUCCESS"

    except Exception as exc:
        executive_summary = f"AI_COMPLETE failed: {str(exc)}"
        cost_driver_explanation = "Use official deterministic cost summary."
        risk_uplift_explanation = "Use official risk-adjusted cost summary."
        bmcs_trust_explanation = "Use official BMCS trust status."
        engineering_review_note = "Cortex explanation failed. Manual review may be required."
        raw_response = {
            "error": str(exc),
            "model": model_name,
            "prompt_version": "COST_EXPLANATION_SUMMARY_V1"
        }
        assessment_status = "FAILED"

    raw_response_json = json.dumps(raw_response)

    assessment_notes = (
        "Advisory-only Cortex explanation. "
        "Official costs remain controlled by deterministic KMAT cost engine."
    )

    # ------------------------------------------------------------
    # 7. Store explanation
    # Raw Cortex output is stored as TO_VARIANT text, not PARSE_JSON.
    # ------------------------------------------------------------
    session.sql(f"""
        MERGE INTO {DB_NAME}.CORE_INPUT.CORTEX_COST_EXPLANATION_SUMMARY t
        USING (
            SELECT
                '{sim_id}' AS SIMULATION_ID,
                '{sql_escape(kmat_id)}' AS KMAT_ID
        ) s
        ON t.SIMULATION_ID = s.SIMULATION_ID
           AND t.KMAT_ID = s.KMAT_ID

        WHEN MATCHED THEN UPDATE SET
            t.RFQ_ID = {sql_literal(rfq_id)},
            t.EXECUTIVE_SUMMARY = '{sql_escape(executive_summary)}',
            t.COST_DRIVER_EXPLANATION = '{sql_escape(cost_driver_explanation)}',
            t.RISK_UPLIFT_EXPLANATION = '{sql_escape(risk_uplift_explanation)}',
            t.BMCS_TRUST_EXPLANATION = '{sql_escape(bmcs_trust_explanation)}',
            t.ENGINEERING_REVIEW_NOTE = '{sql_escape(engineering_review_note)}',
            t.CORTEX_RAW_RESPONSE = TO_VARIANT('{sql_escape(raw_response_json)}'),
            t.ASSIST_METHOD = 'CORTEX_COST_EXPLANATION_SUMMARY_V1',
            t.OFFICIAL_COST_OVERRIDE_FLAG = FALSE,
            t.ASSESSMENT_STATUS = '{sql_escape(assessment_status)}',
            t.ASSESSMENT_NOTES = '{sql_escape(assessment_notes)}',
            t.UPDATED_AT = CURRENT_TIMESTAMP()

        WHEN NOT MATCHED THEN INSERT (
            SIMULATION_ID,
            KMAT_ID,
            RFQ_ID,
            EXECUTIVE_SUMMARY,
            COST_DRIVER_EXPLANATION,
            RISK_UPLIFT_EXPLANATION,
            BMCS_TRUST_EXPLANATION,
            ENGINEERING_REVIEW_NOTE,
            CORTEX_RAW_RESPONSE,
            ASSIST_METHOD,
            OFFICIAL_COST_OVERRIDE_FLAG,
            ASSESSMENT_STATUS,
            ASSESSMENT_NOTES
        )
        VALUES (
            '{sim_id}',
            '{sql_escape(kmat_id)}',
            {sql_literal(rfq_id)},
            '{sql_escape(executive_summary)}',
            '{sql_escape(cost_driver_explanation)}',
            '{sql_escape(risk_uplift_explanation)}',
            '{sql_escape(bmcs_trust_explanation)}',
            '{sql_escape(engineering_review_note)}',
            TO_VARIANT('{sql_escape(raw_response_json)}'),
            'CORTEX_COST_EXPLANATION_SUMMARY_V1',
            FALSE,
            '{sql_escape(assessment_status)}',
            '{sql_escape(assessment_notes)}'
        )
    """).collect()

    return json.dumps({
        "status": assessment_status,
        "simulation_id": SIMULATION_ID,
        "kmat_id": kmat_id,
        "rfq_id": rfq_id,
        "executive_summary": executive_summary,
        "cost_driver_explanation": cost_driver_explanation,
        "risk_uplift_explanation": risk_uplift_explanation,
        "bmcs_trust_explanation": bmcs_trust_explanation,
        "engineering_review_note": engineering_review_note,
        "official_cost_override_flag": False,
        "assist_method": "CORTEX_COST_EXPLANATION_SUMMARY_V1"
    })
$$;

USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE VIEW CORE_INPUT.VW_CORTEX_COST_EXPLANATION_SUMMARY AS
SELECT
    e.SIMULATION_ID,
    e.KMAT_ID,
    e.RFQ_ID,

    LISTAGG(cv.CHARACTERISTIC_NAME || '=' || cv.SELECTED_VALUE, ', ')
        WITHIN GROUP (ORDER BY cv.CHARACTERISTIC_NAME) AS CONFIGURATION,

    s.BASELINE_TOTAL_COST_USD,
    s.RISK_ADJUSTED_TOTAL_COST_USD,
    s.TOTAL_RISK_UPLIFT_USD,
    s.TOTAL_RISK_UPLIFT_PCT,
    s.CSS_SCORE,
    s.SCRAP_RISK_LEVEL,
    s.AVG_WEIGHTED_FMIS,
    s.MAX_TDS_FACTOR,
    s.BOM_MATCH_CONFIDENCE_SCORE,
    s.BMCS_REVIEW_STATUS,
    s.QUOTE_TRUST_STATUS,

    e.EXECUTIVE_SUMMARY,
    e.COST_DRIVER_EXPLANATION,
    e.RISK_UPLIFT_EXPLANATION,
    e.BMCS_TRUST_EXPLANATION,
    e.ENGINEERING_REVIEW_NOTE,

    e.ASSIST_METHOD,
    e.OFFICIAL_COST_OVERRIDE_FLAG,
    e.ASSESSMENT_STATUS,
    e.ASSESSMENT_NOTES,
    e.UPDATED_AT
FROM CORE_INPUT.CORTEX_COST_EXPLANATION_SUMMARY e
LEFT JOIN CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY s
    ON e.SIMULATION_ID = s.SIMULATION_ID
   AND e.KMAT_ID = s.KMAT_ID
LEFT JOIN CORE_INPUT.CHARACTERISTIC_VALUES cv
    ON e.SIMULATION_ID = cv.SIMULATION_ID
   AND e.KMAT_ID = cv.KMAT_ID
GROUP BY
    e.SIMULATION_ID,
    e.KMAT_ID,
    e.RFQ_ID,
    s.BASELINE_TOTAL_COST_USD,
    s.RISK_ADJUSTED_TOTAL_COST_USD,
    s.TOTAL_RISK_UPLIFT_USD,
    s.TOTAL_RISK_UPLIFT_PCT,
    s.CSS_SCORE,
    s.SCRAP_RISK_LEVEL,
    s.AVG_WEIGHTED_FMIS,
    s.MAX_TDS_FACTOR,
    s.BOM_MATCH_CONFIDENCE_SCORE,
    s.BMCS_REVIEW_STATUS,
    s.QUOTE_TRUST_STATUS,
    e.EXECUTIVE_SUMMARY,
    e.COST_DRIVER_EXPLANATION,
    e.RISK_UPLIFT_EXPLANATION,
    e.BMCS_TRUST_EXPLANATION,
    e.ENGINEERING_REVIEW_NOTE,
    e.ASSIST_METHOD,
    e.OFFICIAL_COST_OVERRIDE_FLAG,
    e.ASSESSMENT_STATUS,
    e.ASSESSMENT_NOTES,
    e.UPDATED_AT;

CALL CORE_INTERNAL.RUN_CORTEX_COST_EXPLANATION('SIM_RFQ_001');
CALL CORE_INTERNAL.RUN_CORTEX_COST_EXPLANATION('SIM_001');

SELECT
    SIMULATION_ID,
    CONFIGURATION,
    BASELINE_TOTAL_COST_USD,
    RISK_ADJUSTED_TOTAL_COST_USD,
    TOTAL_RISK_UPLIFT_PCT,
    QUOTE_TRUST_STATUS,
    EXECUTIVE_SUMMARY,
    COST_DRIVER_EXPLANATION,
    RISK_UPLIFT_EXPLANATION,
    BMCS_TRUST_EXPLANATION,
    ENGINEERING_REVIEW_NOTE,
    OFFICIAL_COST_OVERRIDE_FLAG,
    ASSIST_METHOD
FROM CORE_INPUT.VW_CORTEX_COST_EXPLANATION_SUMMARY
ORDER BY UPDATED_AT DESC;