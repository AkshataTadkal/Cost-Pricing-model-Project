USE DATABASE PRICING_ENGINE_DB;

CREATE SCHEMA IF NOT EXISTS CORE_INTERNAL;
CREATE SCHEMA IF NOT EXISTS CORE_STAGING;

-- ============================================================
-- One record for every file or integrated payload
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_INTERNAL.ONBOARDING_BATCHES (
    BATCH_ID              VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    SOURCE_MODE           VARCHAR NOT NULL,   -- INTEGRATED / STANDALONE
    SOURCE_TYPE           VARCHAR NOT NULL,   -- COST_MODEL / CSV / XLSX
    SOURCE_NAME           VARCHAR,
    SOURCE_HASH           VARCHAR,
    SHEET_NAME            VARCHAR,
    ROW_COUNT             NUMBER,
    COLUMN_COUNT          NUMBER,
    BATCH_STATUS          VARCHAR,            -- UPLOADED / VALIDATED / MAPPED /
                                               -- STAGED / PROMOTED / BLOCKED / FAILED
    VALID_ROWS            NUMBER,
    INVALID_ROWS          NUMBER,
    WARNING_ROWS          NUMBER,
    VALIDATION_SCORE      NUMBER(5,2),
    AI_REVIEW_STATUS      VARCHAR,
    MAPPING_STATUS        VARCHAR,
    STAGING_STATUS        VARCHAR,
    PROMOTION_STATUS      VARCHAR,
    CREATED_BY            VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ,
    UPDATED_AT            TIMESTAMP_NTZ,
    PROMOTED_AT           TIMESTAMP_NTZ,
    ERROR_MESSAGE         VARCHAR,
    METADATA_JSON         VARIANT
);

-- ============================================================
-- Immutable deterministic validation findings
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_INTERNAL.DATA_VALIDATION_RESULTS (
    VALIDATION_ID         VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    ROW_NUMBER            NUMBER,
    COLUMN_NAME           VARCHAR,
    RULE_CODE             VARCHAR,
    SEVERITY              VARCHAR,       -- ERROR / WARNING / INFO
    VALIDATION_MESSAGE    VARCHAR,
    INVALID_VALUE         VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ
);

-- ============================================================
-- Confirmed source-to-target mappings
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_INTERNAL.COLUMN_MAPPING_CONFIG (
    MAPPING_ID            VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    SOURCE_NAME           VARCHAR,
    SOURCE_COLUMN         VARCHAR NOT NULL,
    TARGET_COLUMN         VARCHAR NOT NULL,
    SOURCE_DATA_TYPE      VARCHAR,
    TARGET_DATA_TYPE      VARCHAR,
    IS_REQUIRED           BOOLEAN,
    MAPPING_STATUS        VARCHAR,       -- SUGGESTED / CONFIRMED
    MAPPING_CONFIDENCE    NUMBER(5,2),
    CREATED_BY            VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ,
    UPDATED_AT            TIMESTAMP_NTZ
);

-- ============================================================
-- Generic raw upload snapshot for lineage
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_STAGING.STG_ONBOARDING_RAW (
    STAGING_ID            VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER     NUMBER,
    SOURCE_RECORD         VARIANT,
    ROW_HASH              VARCHAR,
    VALIDATION_STATUS     VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ
);

-- ============================================================
-- Canonical normalized pricing input
-- No arbitrary SQL or user-selected table names
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_STAGING.STG_PRICING_INPUTS (
    STAGING_ID            VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    CUSTOMER_ID           VARCHAR,
    CUSTOMER_NAME         VARCHAR,
    SKU                   VARCHAR,
    PRODUCT_NAME          VARCHAR,
    PRODUCT_CATEGORY      VARCHAR,
    PLANT                 VARCHAR,
    PRODUCT_COST          NUMBER(18,4),
    SELLING_PRICE         NUMBER(18,4),
    TARGET_MARGIN         NUMBER(9,4),
    DISCOUNT_PERCENT      NUMBER(9,4),
    FREIGHT               NUMBER(18,4),
    PACKAGING             NUMBER(18,4),
    TAX_PERCENT           NUMBER(9,4),
    OTHER_CHARGES         NUMBER(18,4),
    CURRENCY              VARCHAR,
    CUSTOMER_SEGMENT      VARCHAR,
    SALES_CHANNEL         VARCHAR,
    EFFECTIVE_DATE        DATE,
    SOURCE_SYSTEM         VARCHAR,
    SOURCE_ROW_NUMBER     NUMBER,
    ROW_HASH              VARCHAR,
    VALIDATION_STATUS     VARCHAR,
    CREATED_BY            VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ
);

-- ============================================================
-- Governed production onboarding inputs
-- The existing Price Engine can read the latest active row
-- without replacing its existing pricing calculations.
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_INPUT.ONBOARDED_PRICING_INPUTS (
    PRICING_INPUT_ID      VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    CUSTOMER_ID           VARCHAR,
    CUSTOMER_NAME         VARCHAR,
    SKU                   VARCHAR,
    PRODUCT_NAME          VARCHAR,
    PRODUCT_CATEGORY      VARCHAR,
    PLANT                 VARCHAR,
    PRODUCT_COST          NUMBER(18,4),
    SELLING_PRICE         NUMBER(18,4),
    TARGET_MARGIN         NUMBER(9,4),
    DISCOUNT_PERCENT      NUMBER(9,4),
    FREIGHT               NUMBER(18,4),
    PACKAGING             NUMBER(18,4),
    TAX_PERCENT           NUMBER(9,4),
    OTHER_CHARGES         NUMBER(18,4),
    CURRENCY              VARCHAR,
    CUSTOMER_SEGMENT      VARCHAR,
    SALES_CHANNEL         VARCHAR,
    EFFECTIVE_DATE        DATE,
    SOURCE_MODE           VARCHAR,
    SOURCE_SYSTEM         VARCHAR,
    IS_ACTIVE             BOOLEAN,
    CREATED_BY            VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ,
    UPDATED_AT            TIMESTAMP_NTZ
)
CLUSTER BY (WORKSPACE_ID, CUSTOMER_ID, SKU);

-- ============================================================
-- Immutable promotion history
-- ============================================================
CREATE TABLE IF NOT EXISTS CORE_INTERNAL.DATA_PROMOTION_LOG (
    PROMOTION_ID          VARCHAR NOT NULL,
    BATCH_ID              VARCHAR NOT NULL,
    WORKSPACE_ID          VARCHAR NOT NULL,
    SOURCE_TABLE          VARCHAR,
    TARGET_TABLE          VARCHAR,
    PROMOTED_ROWS         NUMBER,
    REJECTED_ROWS         NUMBER,
    PROMOTION_STATUS      VARCHAR,   -- STARTED / COMPLETED / FAILED
    PROMOTED_BY           VARCHAR,
    STARTED_AT            TIMESTAMP_NTZ,
    COMPLETED_AT          TIMESTAMP_NTZ,
    ERROR_MESSAGE         VARCHAR,
    METADATA_JSON         VARIANT
);