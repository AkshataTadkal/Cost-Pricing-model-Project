USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INPUT;

CREATE OR REPLACE TABLE CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT (
    SIMULATION_ID              VARCHAR,
    KMAT_ID                    VARCHAR,
    PLANT_ID                   VARCHAR,
    PRODUCTION_LINE_ID         VARCHAR,
    PLANNED_PRODUCTION_DATE    DATE,
    BATCH_QUANTITY             NUMBER(18,4),
    CREATED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
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
    'SIM_001',
    'KMAT_TRUCK_01',
    'PLANT_US_01',
    'TRUCK_LINE_01',
    '2026-09-15',
    10
);

SELECT *
FROM CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
WHERE SIMULATION_ID = 'SIM_001';

CREATE OR REPLACE TABLE CORE_INPUT.SCRAP_SCORE_RULES (
    SCRAP_RULE_ID          VARCHAR,
    KMAT_ID                VARCHAR,
    CHARACTERISTIC_NAME    VARCHAR,
    CHARACTERISTIC_VALUE   VARCHAR,
    SCORE_POINTS           NUMBER(18,4),
    RULE_DESCRIPTION       VARCHAR,
    ACTIVE_FLAG            BOOLEAN,
    CREATED_AT             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
INSERT INTO CORE_INPUT.SCRAP_SCORE_RULES
(
    SCRAP_RULE_ID,
    KMAT_ID,
    CHARACTERISTIC_NAME,
    CHARACTERISTIC_VALUE,
    SCORE_POINTS,
    RULE_DESCRIPTION,
    ACTIVE_FLAG
)
VALUES
('CSS_BASE', 'KMAT_TRUCK_01', 'BASE',   'BASE',     20, 'Base manufacturing scrap risk for truck configuration', TRUE),

('CSS_ENG_V6', 'KMAT_TRUCK_01', 'ENGINE', 'V6',       0, 'V6 engine is standard complexity', TRUE),
('CSS_ENG_V8', 'KMAT_TRUCK_01', 'ENGINE', 'V8',      25, 'V8 engine increases installation and test complexity', TRUE),

('CSS_CAB_STANDARD', 'KMAT_TRUCK_01', 'CAB', 'STANDARD', 0, 'Standard cab has normal fitting risk', TRUE),
('CSS_CAB_PREMIUM',  'KMAT_TRUCK_01', 'CAB', 'PREMIUM', 20, 'Premium cab has extra fitting and finishing risk', TRUE),

('CSS_WHEEL_STANDARD', 'KMAT_TRUCK_01', 'WHEEL', 'STANDARD', 0, 'Standard wheels have normal fitting risk', TRUE),
('CSS_WHEEL_OFFROAD',  'KMAT_TRUCK_01', 'WHEEL', 'OFFROAD', 15, 'Offroad wheels add handling and fitting complexity', TRUE),

('CSS_COLOR_BLUE', 'KMAT_TRUCK_01', 'COLOR', 'BLUE', 0, 'Blue paint follows standard paint process', TRUE),
('CSS_COLOR_RED',  'KMAT_TRUCK_01', 'COLOR', 'RED',  5, 'Red paint package adds minor finishing risk', TRUE);

SELECT * FROM CORE_INPUT.SCRAP_SCORE_RULES
WHERE KMAT_ID = 'KMAT_TRUCK_01'
ORDER BY CHARACTERISTIC_NAME, CHARACTERISTIC_VALUE;


CREATE OR REPLACE TABLE CORE_INPUT.SCRAP_SCORE_BANDS (
    BAND_ID             VARCHAR,
    MIN_SCORE           NUMBER(18,4),
    MAX_SCORE           NUMBER(18,4),
    SCRAP_RATE          NUMBER(18,6),
    RISK_LEVEL          VARCHAR,
    BAND_DESCRIPTION    VARCHAR,
    ACTIVE_FLAG         BOOLEAN
);

INSERT INTO CORE_INPUT.SCRAP_SCORE_BANDS
(
    BAND_ID,
    MIN_SCORE,
    MAX_SCORE,
    SCRAP_RATE,
    RISK_LEVEL,
    BAND_DESCRIPTION,
    ACTIVE_FLAG
)
VALUES
('CSS_LOW',    0,  40, 0.015, 'LOW',    'Low configuration scrap risk; apply 1.5 percent material buffer', TRUE),
('CSS_MEDIUM', 41, 75, 0.030, 'MEDIUM', 'Medium configuration scrap risk; apply 3 percent material buffer', TRUE),
('CSS_HIGH',   76, 100, 0.060, 'HIGH',  'High configuration scrap risk; apply 6 percent material buffer', TRUE);

SELECT * FROM CORE_INPUT.SCRAP_SCORE_BANDS
ORDER BY MIN_SCORE; 

CREATE OR REPLACE TABLE CORE_INPUT.COMPONENT_COST_ATTRIBUTES (
    COMPONENT_ID                  VARCHAR,
    SCRAP_APPLICABLE_FLAG          BOOLEAN,
    COMMODITY_SENSITIVE_FLAG       BOOLEAN,
    DEFAULT_COMMODITY_GROUP        VARCHAR,
    ATTRIBUTE_DESCRIPTION          VARCHAR,
    CREATED_AT                     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.COMPONENT_COST_ATTRIBUTES
(
    COMPONENT_ID,
    SCRAP_APPLICABLE_FLAG,
    COMMODITY_SENSITIVE_FLAG,
    DEFAULT_COMMODITY_GROUP,
    ATTRIBUTE_DESCRIPTION
)
VALUES
('PART_ENG_V6',        FALSE, TRUE,  'MIXED_ENGINE', 'V6 engine is commodity sensitive but not scrap-adjusted as a whole unit'),
('PART_ENG_V8',        FALSE, TRUE,  'MIXED_ENGINE', 'V8 engine is commodity sensitive but not scrap-adjusted as a whole unit'),

('CAB_STANDARD',       TRUE,  TRUE,  'STEEL',        'Standard cab can have fitting and material scrap exposure'),
('CAB_PREMIUM',        TRUE,  TRUE,  'STEEL',        'Premium cab has higher fitting and finishing scrap exposure'),

('WHEEL_STANDARD',     FALSE, TRUE,  'RUBBER_STEEL', 'Wheel assembly is commodity sensitive but not scrap-adjusted as a whole unit'),
('WHEEL_OFFROAD',      FALSE, TRUE,  'RUBBER_STEEL', 'Offroad wheel assembly is commodity sensitive but not scrap-adjusted as a whole unit'),

('PAINT_RED',          TRUE,  TRUE,  'CHEMICALS',    'Paint package has direct material waste/scrap exposure'),
('PAINT_BLUE',         TRUE,  TRUE,  'CHEMICALS',    'Paint package has direct material waste/scrap exposure'),

('BULK_FASTENER_KIT',  TRUE,  TRUE,  'STEEL',        'Bulk fasteners are included and may receive scrap buffer'),
('SHOP_SUPPLIES_BULK', TRUE,  FALSE, 'OTHER',        'Bulk shop supplies are included but cost may be missing');

SELECT * FROM CORE_INPUT.COMPONENT_COST_ATTRIBUTES
ORDER BY COMPONENT_ID;


CREATE OR REPLACE TABLE CORE_INPUT.COMPONENT_COMMODITY_EXPOSURE (
    COMPONENT_ID          VARCHAR,
    COMMODITY_GROUP       VARCHAR,
    EXPOSURE_PERCENT      NUMBER(18,6),
    EXPOSURE_DESCRIPTION  VARCHAR,
    CREATED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.COMPONENT_COMMODITY_EXPOSURE
(
    COMPONENT_ID,
    COMMODITY_GROUP,
    EXPOSURE_PERCENT,
    EXPOSURE_DESCRIPTION
)
VALUES
-- Engines: mixed material exposure
('PART_ENG_V6', 'STEEL',    0.50, 'V6 engine steel exposure'),
('PART_ENG_V6', 'ALUMINUM', 0.30, 'V6 engine aluminum exposure'),
('PART_ENG_V6', 'OTHER',    0.20, 'V6 engine other material exposure'),

('PART_ENG_V8', 'STEEL',    0.45, 'V8 engine steel exposure'),
('PART_ENG_V8', 'ALUMINUM', 0.35, 'V8 engine aluminum exposure'),
('PART_ENG_V8', 'OTHER',    0.20, 'V8 engine other material exposure'),

-- Cab assemblies
('CAB_STANDARD', 'STEEL', 0.80, 'Standard cab steel exposure'),
('CAB_STANDARD', 'OTHER', 0.20, 'Standard cab other material exposure'),

('CAB_PREMIUM', 'STEEL', 0.70, 'Premium cab steel exposure'),
('CAB_PREMIUM', 'OTHER', 0.30, 'Premium cab other material exposure'),

-- Wheels
('WHEEL_STANDARD', 'RUBBER', 0.70, 'Standard wheel rubber exposure'),
('WHEEL_STANDARD', 'STEEL',  0.30, 'Standard wheel steel exposure'),

('WHEEL_OFFROAD', 'RUBBER', 0.70, 'Offroad wheel rubber exposure'),
('WHEEL_OFFROAD', 'STEEL',  0.30, 'Offroad wheel steel exposure'),

-- Paint
('PAINT_RED',  'CHEMICALS', 1.00, 'Red paint chemical exposure'),
('PAINT_BLUE', 'CHEMICALS', 1.00, 'Blue paint chemical exposure'),

-- Bulk materials
('BULK_FASTENER_KIT',  'STEEL', 1.00, 'Bulk fasteners steel exposure'),
('SHOP_SUPPLIES_BULK', 'OTHER', 1.00, 'Shop supplies general exposure');

SELECT
    COMPONENT_ID,
    SUM(EXPOSURE_PERCENT) AS TOTAL_EXPOSURE
FROM CORE_INPUT.COMPONENT_COMMODITY_EXPOSURE
GROUP BY COMPONENT_ID
ORDER BY COMPONENT_ID;


CREATE OR REPLACE TABLE CORE_INPUT.MATERIAL_INDEX_FORECASTS (
    FORECAST_MONTH             DATE,
    COMMODITY_GROUP            VARCHAR,
    FORWARD_MATERIAL_INDEX     NUMBER(18,6),
    FORECAST_SOURCE            VARCHAR,
    FORECAST_VERSION           VARCHAR,
    CREATED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.MATERIAL_INDEX_FORECASTS
(
    FORECAST_MONTH,
    COMMODITY_GROUP,
    FORWARD_MATERIAL_INDEX,
    FORECAST_SOURCE,
    FORECAST_VERSION
)
VALUES
('2026-09-01', 'STEEL',     1.080000, 'SAMPLE_FORECAST', 'V1'),
('2026-09-01', 'ALUMINUM',  1.040000, 'SAMPLE_FORECAST', 'V1'),
('2026-09-01', 'RUBBER',    1.060000, 'SAMPLE_FORECAST', 'V1'),
('2026-09-01', 'CHEMICALS', 1.030000, 'SAMPLE_FORECAST', 'V1'),
('2026-09-01', 'OTHER',     1.000000, 'SAMPLE_FORECAST', 'V1');

SELECT * FROM CORE_INPUT.MATERIAL_INDEX_FORECASTS
ORDER BY FORECAST_MONTH, COMMODITY_GROUP;


--STEP 7
CREATE OR REPLACE TABLE CORE_INPUT.WORK_CENTER_COST_BREAKDOWN (
    WORK_CENTER_ID                    VARCHAR,
    OPERATING_RATE_USD_PER_HOUR        NUMBER(18,4),
    MAINTENANCE_RATE_USD_PER_HOUR      NUMBER(18,4),
    BREAKDOWN_DESCRIPTION              VARCHAR,
    CREATED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.WORK_CENTER_COST_BREAKDOWN
(
    WORK_CENTER_ID,
    OPERATING_RATE_USD_PER_HOUR,
    MAINTENANCE_RATE_USD_PER_HOUR,
    BREAKDOWN_DESCRIPTION
)
VALUES
('WC_ASSEMBLY', 25, 15, 'Assembly machine rate split: 25 operating + 15 maintenance = 40 total'),
('WC_PAINT',    35, 20, 'Paint booth machine rate split: 35 operating + 20 maintenance = 55 total'),
('WC_QA',       15,  5, 'QA machine rate split: 15 operating + 5 maintenance = 20 total');
--VALIDATING STEP
SELECT
    w.WORK_CENTER_ID,
    w.MACHINE_RATE_USD_PER_HOUR AS EXISTING_MACHINE_RATE,
    b.OPERATING_RATE_USD_PER_HOUR,
    b.MAINTENANCE_RATE_USD_PER_HOUR,
    b.OPERATING_RATE_USD_PER_HOUR + b.MAINTENANCE_RATE_USD_PER_HOUR AS BREAKDOWN_TOTAL,
    w.MACHINE_RATE_USD_PER_HOUR
      - (b.OPERATING_RATE_USD_PER_HOUR + b.MAINTENANCE_RATE_USD_PER_HOUR) AS DIFFERENCE
FROM CORE_INPUT.WORK_CENTER_RATES w
JOIN CORE_INPUT.WORK_CENTER_COST_BREAKDOWN b
    ON w.WORK_CENTER_ID = b.WORK_CENTER_ID
ORDER BY w.WORK_CENTER_ID;

--STEP 9
CREATE OR REPLACE TABLE CORE_INPUT.OPERATION_TDS_RULES (
    OPERATION_ID        VARCHAR,
    TDS_FACTOR          NUMBER(18,6),
    TDS_REASON          VARCHAR,
    ACTIVE_FLAG         BOOLEAN,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORE_INPUT.OPERATION_TDS_RULES
(
    OPERATION_ID,
    TDS_FACTOR,
    TDS_REASON,
    ACTIVE_FLAG
)
VALUES
('OP_BASE_ASSEMBLY',      1.000000, 'Base assembly has normal machine strain', TRUE),
('OP_BASE_QA',            1.000000, 'Base QA has normal machine strain', TRUE),

('OP_V6_ENGINE_INSTALL',  1.050000, 'V6 install creates slight additional handling strain', TRUE),
('OP_V8_ENGINE_INSTALL',  1.400000, 'V8 install creates higher machine/tooling strain', TRUE),

('OP_STANDARD_CAB_FIT',   1.000000, 'Standard cab fitting has normal strain', TRUE),
('OP_PREMIUM_CAB_FIT',    1.250000, 'Premium cab fitting creates additional fixture/tooling strain', TRUE),

('OP_OFFROAD_WHEEL_FIT',  1.200000, 'Offroad wheel fitting creates higher handling/tooling strain', TRUE),

('OP_RED_PAINT',          1.100000, 'Red paint process creates slightly higher paint booth strain', TRUE),
('OP_BLUE_PAINT',         1.050000, 'Blue paint process creates slight paint booth strain', TRUE);

SELECT * FROM CORE_INPUT.OPERATION_TDS_RULES
ORDER BY OPERATION_ID;


--STEP 9 
WITH CONFIG_RULE_POINTS AS (
    SELECT
        cv.SIMULATION_ID,
        cv.KMAT_ID,
        sr.SCORE_POINTS
    FROM CORE_INPUT.CHARACTERISTIC_VALUES cv
    JOIN CORE_INPUT.SCRAP_SCORE_RULES sr
        ON cv.KMAT_ID = sr.KMAT_ID
       AND cv.CHARACTERISTIC_NAME = sr.CHARACTERISTIC_NAME
       AND cv.SELECTED_VALUE = sr.CHARACTERISTIC_VALUE
       AND sr.ACTIVE_FLAG = TRUE
    WHERE cv.SIMULATION_ID = 'SIM_001'

    UNION ALL

    SELECT
        h.SIMULATION_ID,
        h.KMAT_ID,
        sr.SCORE_POINTS
    FROM CORE_INPUT.SIMULATION_HEADER h
    JOIN CORE_INPUT.SCRAP_SCORE_RULES sr
        ON h.KMAT_ID = sr.KMAT_ID
       AND sr.CHARACTERISTIC_NAME = 'BASE'
       AND sr.CHARACTERISTIC_VALUE = 'BASE'
       AND sr.ACTIVE_FLAG = TRUE
    WHERE h.SIMULATION_ID = 'SIM_001'
),
CSS_TOTAL AS (
    SELECT
        SIMULATION_ID,
        KMAT_ID,
        LEAST(SUM(SCORE_POINTS), 100) AS CSS_SCORE
    FROM CONFIG_RULE_POINTS
    GROUP BY SIMULATION_ID, KMAT_ID
)
SELECT
    c.SIMULATION_ID,
    c.KMAT_ID,
    c.CSS_SCORE,
    b.RISK_LEVEL,
    b.SCRAP_RATE
FROM CSS_TOTAL c
JOIN CORE_INPUT.SCRAP_SCORE_BANDS b
    ON c.CSS_SCORE BETWEEN b.MIN_SCORE AND b.MAX_SCORE
   AND b.ACTIVE_FLAG = TRUE;

--STEP 10
WITH SELECTED_COMPONENTS AS (
    SELECT
        c.SIMULATION_ID,
        c.KMAT_ID,
        c.COMPONENT_ID,
        c.COMPONENT_DESCRIPTION
    FROM CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS c
    WHERE c.SIMULATION_ID = 'SIM_001'
),
FORECAST_CONTEXT AS (
    SELECT
        SIMULATION_ID,
        DATE_TRUNC('MONTH', PLANNED_PRODUCTION_DATE) AS FORECAST_MONTH
    FROM CORE_INPUT.SIMULATION_PRODUCTION_CONTEXT
    WHERE SIMULATION_ID = 'SIM_001'
),
COMPONENT_FMIS AS (
    SELECT
        sc.SIMULATION_ID,
        sc.COMPONENT_ID,
        SUM(
            e.EXPOSURE_PERCENT
            * COALESCE(f.FORWARD_MATERIAL_INDEX, 1.000000)
        ) AS WEIGHTED_FMIS
    FROM SELECTED_COMPONENTS sc
    JOIN CORE_INPUT.COMPONENT_COMMODITY_EXPOSURE e
        ON sc.COMPONENT_ID = e.COMPONENT_ID
    JOIN FORECAST_CONTEXT fc
        ON sc.SIMULATION_ID = fc.SIMULATION_ID
    LEFT JOIN CORE_INPUT.MATERIAL_INDEX_FORECASTS f
        ON fc.FORECAST_MONTH = f.FORECAST_MONTH
       AND e.COMMODITY_GROUP = f.COMMODITY_GROUP
    GROUP BY sc.SIMULATION_ID, sc.COMPONENT_ID
)
SELECT *
FROM COMPONENT_FMIS
ORDER BY COMPONENT_ID;

--STEP 11
SELECT
    o.SIMULATION_ID,
    o.KMAT_ID,
    o.OPERATION_ID,
    o.OPERATION_DESCRIPTION,
    o.WORK_CENTER_ID,
    o.MACHINE_HOURS,
    o.MACHINE_RATE_USD_PER_HOUR AS BASE_MACHINE_RATE,
    b.OPERATING_RATE_USD_PER_HOUR,
    b.MAINTENANCE_RATE_USD_PER_HOUR,
    COALESCE(t.TDS_FACTOR, 1.000000) AS TDS_FACTOR,
    o.MACHINE_HOURS * o.MACHINE_RATE_USD_PER_HOUR AS BASE_MACHINE_COST,
    o.MACHINE_HOURS
        * (
            b.OPERATING_RATE_USD_PER_HOUR
            + b.MAINTENANCE_RATE_USD_PER_HOUR * COALESCE(t.TDS_FACTOR, 1.000000)
          ) AS TDS_ADJUSTED_MACHINE_COST
FROM CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS o
JOIN CORE_INPUT.WORK_CENTER_COST_BREAKDOWN b
    ON o.WORK_CENTER_ID = b.WORK_CENTER_ID
LEFT JOIN CORE_INPUT.OPERATION_TDS_RULES t
    ON o.OPERATION_ID = t.OPERATION_ID
   AND t.ACTIVE_FLAG = TRUE
WHERE o.SIMULATION_ID = 'SIM_001'
ORDER BY o.OPERATION_ID;

--Alter existing output tables
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_OUTPUT;

--STEP 1 ALTER COMPONENT COST TABLE
ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS BASE_QUANTITY NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS SCRAP_APPLICABLE_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS CSS_SCORE NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS SCRAP_RATE_APPLIED NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS SCRAP_ADJUSTED_QUANTITY NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS BASE_STANDARD_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS WEIGHTED_FMIS NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS FORWARD_UNIT_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS BASE_LINE_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS COMMODITY_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS SCRAP_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_LINE_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS FMIS_FALLBACK_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS
ADD COLUMN IF NOT EXISTS RISK_ADJUSTMENT_NOTES VARCHAR;

--STEP 2 Alter operation cost output table
ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS BASE_MACHINE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS OPERATING_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS MAINTENANCE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TDS_FACTOR NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS BASE_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_MACHINE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TOOLING_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TDS_FALLBACK_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS RISK_ADJUSTMENT_NOTES VARCHAR;


--STEP 3 ALTER OPERATION COST TABLE
ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS BASE_MACHINE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS OPERATING_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS MAINTENANCE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TDS_FACTOR NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS BASE_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_MACHINE_RATE_USD_PER_HOUR NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TOOLING_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS TDS_FALLBACK_FLAG BOOLEAN;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS
ADD COLUMN IF NOT EXISTS RISK_ADJUSTMENT_NOTES VARCHAR;


--STEP 4 ALTER SUMMARY TABLE
ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_LABOR_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_TOTAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS CSS_SCORE NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_RATE_APPLIED NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_RISK_LEVEL VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS AVG_WEIGHTED_FMIS NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS MAX_TDS_FACTOR NUMBER(18,6);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS COMMODITY_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOOLING_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS OVERHEAD_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_LABOR_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_TOTAL_COST_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOTAL_RISK_UPLIFT_USD NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOTAL_RISK_UPLIFT_PCT NUMBER(18,4);

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_MODEL_VERSION VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_CALCULATION_STATUS VARCHAR;

ALTER TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_CALCULATION_NOTES VARCHAR;

--REPAIR
ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_LABOR_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS BASELINE_TOTAL_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS CSS_SCORE NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_RATE_APPLIED NUMBER(18,6);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_RISK_LEVEL VARCHAR;

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS AVG_WEIGHTED_FMIS NUMBER(18,6);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS MAX_TDS_FACTOR NUMBER(18,6);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS COMMODITY_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS SCRAP_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOOLING_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS OVERHEAD_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_MATERIAL_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_LABOR_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_MACHINE_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_TOTAL_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOTAL_RISK_UPLIFT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS TOTAL_RISK_UPLIFT_PCT NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_MODEL_VERSION VARCHAR;

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_CALCULATION_STATUS VARCHAR;

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
ADD COLUMN IF NOT EXISTS RISK_CALCULATION_NOTES VARCHAR;

--OVERHEAD TABLES
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_OUTPUT;

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS BASE_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS OVERHEAD_CALCULATION_BASIS_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS ADJUSTED_OVERHEAD_COST_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS OVERHEAD_ADJUSTMENT_USD NUMBER(18,4);

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS RISK_ADJUSTED_FLAG BOOLEAN;

ALTER TABLE KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS
ADD COLUMN IF NOT EXISTS RISK_ADJUSTMENT_NOTES VARCHAR;

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CORE_OUTPUT'
  AND TABLE_NAME = 'KMAT_CONFIGURED_OVERHEAD_COSTS'
ORDER BY ORDINAL_POSITION;

--STEP 5 VALIDATE OUTPUT TABLES
DESC TABLE CORE_OUTPUT.KMAT_CONFIGURED_COMPONENT_COSTS;
DESC TABLE CORE_OUTPUT.KMAT_CONFIGURED_OPERATION_COSTS;
DESC TABLE CORE_OUTPUT.KMAT_CONFIGURED_OVERHEAD_COSTS;
DESC TABLE CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY;

--STEP 6 QUICK INFORMATIONAL SCHEMA
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM KMAT_COST_MODEL_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CORE_OUTPUT'
  AND TABLE_NAME IN (
      'KMAT_CONFIGURED_COMPONENT_COSTS',
      'KMAT_CONFIGURED_OPERATION_COSTS',
      'KMAT_CONFIGURED_OVERHEAD_COSTS',
      'KMAT_CONFIGURED_COST_SUMMARY'
  )
  AND (
      COLUMN_NAME ILIKE '%SCRAP%'
      OR COLUMN_NAME ILIKE '%FMIS%'
      OR COLUMN_NAME ILIKE '%TDS%'
      OR COLUMN_NAME ILIKE '%RISK%'
      OR COLUMN_NAME ILIKE '%TOOLING%'
      OR COLUMN_NAME ILIKE '%ADJUSTED%'
      OR COLUMN_NAME ILIKE '%BASELINE%'
      OR COLUMN_NAME ILIKE '%COMMODITY%'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;

--PHASE C
USE ROLE SYSADMIN;
USE WAREHOUSE KMAT_WH;
USE DATABASE KMAT_COST_MODEL_DB;
USE SCHEMA CORE_INTERNAL;

SELECT GET_DDL(
    'PROCEDURE',
    'KMAT_COST_MODEL_DB.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION(STRING)'
);

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
    """
    Supported rule examples:
    {"type":"DEFAULT"}
    {"characteristic":"ENGINE","operator":"=","value":"V8"}
    {"characteristic":"ENGINE","operator":"!=","value":"V6"}
    {"characteristic":"ENGINE","operator":"IN","value":["V6","V8"]}
    {"all":[rule1, rule2]}
    {"any":[rule1, rule2]}
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


def sql_value(value):
    """
    Convert Python values into safe Snowflake SQL literals.
    This avoids Snowpark DataFrame column-order and quoted-identifier issues.
    """
    if value is None:
        return "NULL"

    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"

    if isinstance(value, int) or isinstance(value, float):
        return str(value)

    if isinstance(value, datetime):
        ts = value.strftime("%Y-%m-%d %H:%M:%S.%f")
        return f"TO_TIMESTAMP_NTZ('{ts}')"

    escaped = str(value).replace("'", "''")
    return f"'{escaped}'"


def quote_identifier(identifier):
    """
    Always quote column names so Snowflake matches the exact output table columns.
    """
    escaped = str(identifier).replace('"', '""')
    return f'"{escaped}"'


def append_rows(session, table_name_parts, rows, schema):
    """
    Append rows using explicit quoted column names.

    This avoids both problems:
    1. column_order='name' quoted identifier error
    2. positional insert mismatch error
    """
    if not rows:
        return

    table_name = ".".join(table_name_parts)

    column_list = ", ".join(quote_identifier(col_name) for col_name in schema)

    for row in rows:
        value_list = ", ".join(sql_value(value) for value in row)

        insert_sql = f"""
            INSERT INTO {table_name}
            ({column_list})
            VALUES
            ({value_list})
        """

        session.sql(insert_sql).collect()


def calculate_css(session, sim_id, kmat_id, selections):
    """
    CSS = Configuration Scrap Score.
    Rule-based MVP:
    Base score + selected characteristic score points.
    """
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
    """
    Weighted FMIS = sum(exposure_percent * commodity forecast index)
    Fallback = 1.00 when forecast/exposure is missing.
    """
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
    # 3. Read selected characteristics
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
    # 4. Calculate CSS and load risk input maps
    # ------------------------------------------------------------
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

    # ------------------------------------------------------------
    # 5. Clear existing output for same simulation
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
    # 6. Evaluate Super BOM component rules
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

    # ------------------------------------------------------------
    # 7. Evaluate Super Routing operation rules
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

    # ------------------------------------------------------------
    # 8. Evaluate overhead rules
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

    # ------------------------------------------------------------
    # 9. Summary and baseline pricing
    # ------------------------------------------------------------
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
        f"Phase 5C CSS/FMIS/TDS enabled. "
        f"ForecastMonth={forecast_month_str if forecast_month_str is not None else 'MISSING_CONTEXT'}, "
        f"CSS={round(css_score, 4)}, "
        f"ScrapRate={round(scrap_rate_applied, 6)}, "
        f"RiskLevel={scrap_risk_level}, "
        f"AvgFMIS={round(avg_weighted_fmis, 6)}, "
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
        "CSS_FMIS_TDS_RULE_BASED_V1",
        "SUCCESS",
        summary_notes
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
            "RISK_CALCULATION_NOTES"
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

        "baseline_material_cost_usd": round(baseline_material_total, 4),
        "baseline_labor_cost_usd": round(baseline_labor_total, 4),
        "baseline_machine_cost_usd": round(baseline_machine_total, 4),
        "baseline_overhead_cost_usd": round(baseline_overhead_total, 4),
        "baseline_total_cost_usd": round(baseline_total_cost, 4),

        "css_score": round(css_score, 4),
        "scrap_rate_applied": round(scrap_rate_applied, 6),
        "scrap_risk_level": scrap_risk_level,
        "avg_weighted_fmis": round(avg_weighted_fmis, 6),
        "max_tds_factor": round(max_tds_factor, 6),

        "commodity_adjustment_usd": round(commodity_adjustment_total, 4),
        "scrap_adjustment_usd": round(scrap_adjustment_total, 4),
        "tooling_adjustment_usd": round(tooling_adjustment_total, 4),
        "overhead_adjustment_usd": round(overhead_adjustment_total, 4),

        "risk_adjusted_material_cost_usd": round(risk_adjusted_material_total, 4),
        "risk_adjusted_labor_cost_usd": round(baseline_labor_total, 4),
        "risk_adjusted_machine_cost_usd": round(risk_adjusted_machine_total, 4),
        "risk_adjusted_overhead_cost_usd": round(risk_adjusted_overhead_total, 4),
        "risk_adjusted_total_cost_usd": round(risk_adjusted_total_cost, 4),
        "total_risk_uplift_usd": round(total_risk_uplift, 4),
        "total_risk_uplift_pct": round(total_risk_uplift_pct, 4)
    })
$$;

SHOW PROCEDURES LIKE 'RUN_KMAT_COST_SIMULATION'
IN SCHEMA KMAT_COST_MODEL_DB.CORE_INTERNAL;

SELECT
    IFF(
        GET_DDL(
            'PROCEDURE',
            'KMAT_COST_MODEL_DB.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION(STRING)'
        ) ILIKE '%column_order="name"%',
        'OLD CODE STILL DEPLOYED',
        'UPDATED CODE DEPLOYED'
    ) AS PROCEDURE_STATUS;

CALL KMAT_COST_MODEL_DB.CORE_INTERNAL.RUN_KMAT_COST_SIMULATION('SIM_001');

SELECT
    SIMULATION_ID,
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
    RISK_ADJUSTED_TOTAL_COST_USD,
    TOTAL_RISK_UPLIFT_USD,
    TOTAL_RISK_UPLIFT_PCT,
    RISK_CALCULATION_STATUS
FROM KMAT_COST_MODEL_DB.CORE_OUTPUT.KMAT_CONFIGURED_COST_SUMMARY
WHERE SIMULATION_ID = 'SIM_001';
