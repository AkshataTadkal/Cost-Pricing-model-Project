-- =============================================================================
-- PRICING INTELLIGENCE PLATFORM — COMPLETE SNOWFLAKE SETUP
-- Generated from: Streamlit source code (all 7 tabs) + original DDL PDF
-- Run this file top-to-bottom in a Snowflake worksheet.
-- Every table, view, dynamic table, and sample data row is included.
-- =============================================================================


-- =============================================================================
-- STEP 1 — DATABASE & SCHEMAS
-- =============================================================================

CREATE DATABASE IF NOT EXISTS PRICING_ENGINE_DB;

CREATE SCHEMA IF NOT EXISTS PRICING_ENGINE_DB.CORE_INPUT;
CREATE SCHEMA IF NOT EXISTS PRICING_ENGINE_DB.CORE_OUTPUT;
CREATE SCHEMA IF NOT EXISTS PRICING_ENGINE_DB.CORE_INTERNAL;

USE DATABASE PRICING_ENGINE_DB;


-- =============================================================================
-- STEP 2 — CORE INPUT TABLES
-- (source-of-truth data read by every tab)
-- =============================================================================

-- ── Products + standard costs (Tab 2, 3, 4) ──────────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS (
    SKU            VARCHAR,
    PRODUCT_FAMILY VARCHAR,
    TOTAL_COST     NUMBER(10,2)
);

-- ── Margin bands per product family (used by OPTIMIZED_PRICING_MATRIX view) ──
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.PRICE_MATRICES (
    PRODUCT_FAMILY VARCHAR,
    FLOOR_MARGIN   FLOAT,   -- e.g. 0.10 = 10%
    TARGET_MARGIN  FLOAT,   -- e.g. 0.30 = 30%
    CEILING_MARGIN FLOAT    -- e.g. 0.50 = 50%
);

-- ── Customer discount agreements (Tab 1, 2, 6) ───────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS (
    CUSTOMER_ID      VARCHAR,
    DISCOUNT_PERCENT FLOAT    -- e.g. 10 = 10%
);

-- ── Dynamic surcharges (steel, fuel, etc.) ───────────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.DYNAMIC_SURCHARGES (
    SURCHARGE_TYPE    VARCHAR,
    SURCHARGE_PERCENT FLOAT
);

-- ── Price Sensitivity Index per customer (Tab 2 — PSI section) ───────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY (
    CUSTOMER_ID             VARCHAR,
    CUSTOMER_SEGMENT        VARCHAR,
    PRICE_SENSITIVITY_INDEX FLOAT    -- 0.00 – 1.00  (higher = more sensitive)
);

-- ── Plant capacity data (Tab 2 — CUM section, if integrated) ─────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY (
    PLANT_ID             VARCHAR,
    PLANT_NAME           VARCHAR,
    CURRENT_UTILIZATION  FLOAT,      -- % e.g. 72.5
    MAX_CAPACITY         NUMBER(10,0),
    AVAILABLE_CAPACITY   NUMBER(10,0)
);


-- =============================================================================
-- STEP 3 — CORE INTERNAL TABLES
-- (scenario library used by Simulation Hub — Tab 3)
-- =============================================================================

CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS (
    SCENARIO_ID           VARCHAR,
    SCENARIO_NAME         VARCHAR,
    STEEL_SURCHARGE_PCT   FLOAT,
    FUEL_SURCHARGE_PCT    FLOAT,
    TARGET_MARGIN_PCT     FLOAT,
    CUSTOMER_DISCOUNT_PCT FLOAT
);


-- =============================================================================
-- STEP 4 — CORE OUTPUT TABLES
-- (written to by the Streamlit app at runtime)
-- =============================================================================

-- ── Price optimisation results saved by Tab 2 ────────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZATION_RESULTS (
    SKU            VARCHAR,
    COST           FLOAT,
    MARGIN_PCT     FLOAT,
    TARGET_PRICE   FLOAT,
    EXPECTED_DEMAND NUMBER(10,0),
    REVENUE        FLOAT,
    PROFIT         FLOAT,
    CREATED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ── User simulation history saved by Tab 3 ───────────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS (
    SCENARIO_NAME     VARCHAR,
    SKU               VARCHAR,
    TOTAL_COST        FLOAT,
    TARGET_MARGIN_PCT FLOAT,
    CUSTOMER_DISCOUNT_PCT FLOAT,
    STEEL_SURCHARGE_PCT   FLOAT,
    FUEL_SURCHARGE_PCT    FLOAT,
    SIMULATED_TARGET_PRICE   FLOAT,
    SIMULATED_CUSTOMER_PRICE FLOAT,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ── Digital Twin scenario results saved by Tab 4 ─────────────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_OUTPUT.DIGITAL_TWIN_RESULTS (
    SCENARIO_NAME  VARCHAR,
    SKU            VARCHAR,
    BASE_COST      FLOAT,
    NEW_COST       FLOAT,
    BASE_PRICE     FLOAT,
    NEW_PRICE      FLOAT,
    BASE_DEMAND    NUMBER(10,0),
    NEW_DEMAND     NUMBER(10,0),
    BASE_REVENUE   FLOAT,
    NEW_REVENUE    FLOAT,
    BASE_PROFIT    FLOAT,
    NEW_PROFIT     FLOAT,
    CREATED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ── Legacy simulation results table (from original DDL) ──────────────────────
CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATION_RESULTS (
    REQUEST_ID               VARCHAR,
    SKU                      VARCHAR,
    SCENARIO_ID              VARCHAR,
    SIMULATED_TARGET_PRICE   FLOAT,
    SIMULATED_CUSTOMER_PRICE FLOAT,
    CREATED_AT               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- =============================================================================
-- STEP 5 — CORE OUTPUT VIEWS
-- Creation order matters: OPTIMIZED_PRICING_MATRIX must come before views
-- that reference it.
-- =============================================================================

-- ── 5a. OPTIMIZED_PRICING_MATRIX — base pricing view ─────────────────────────
--    Used by: Tab 1, 2, 3, 7 and downstream views
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX (
    SKU, PRODUCT_FAMILY, TOTAL_COST,
    FLOOR_PRICE, TARGET_PRICE, CEILING_PRICE
) AS
SELECT
    c.SKU,
    c.PRODUCT_FAMILY,
    c.TOTAL_COST,
    ROUND(c.TOTAL_COST * (1 + p.FLOOR_MARGIN),   2) AS FLOOR_PRICE,
    ROUND(c.TOTAL_COST * (1 + p.TARGET_MARGIN),  2) AS TARGET_PRICE,
    ROUND(c.TOTAL_COST * (1 + p.CEILING_MARGIN), 2) AS CEILING_PRICE
FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS c
JOIN PRICING_ENGINE_DB.CORE_INPUT.PRICE_MATRICES p
    ON c.PRODUCT_FAMILY = p.PRODUCT_FAMILY;


-- ── 5b. CUSTOMER_PRICING — pricing + per-customer discount ───────────────────
--    Used by: Tab 1 (overview KPIs, profit analysis), Tab 6 (contract analyzer)
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING (
    SKU, PRODUCT_FAMILY, TOTAL_COST,
    FLOOR_PRICE, TARGET_PRICE, CEILING_PRICE,
    CUSTOMER_ID, DISCOUNTED_PRICE
) AS
SELECT
    o.SKU,
    o.PRODUCT_FAMILY,
    o.TOTAL_COST,
    o.FLOOR_PRICE,
    o.TARGET_PRICE,
    o.CEILING_PRICE,
    a.CUSTOMER_ID,
    ROUND(o.TARGET_PRICE * (1 - a.DISCOUNT_PERCENT / 100), 2) AS DISCOUNTED_PRICE
FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX o
JOIN PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS a;


-- ── 5c. PRICING_ASSISTANT_VIEW — full matrix left-joined with customer ────────
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.PRICING_ASSISTANT_VIEW (
    SKU, PRODUCT_FAMILY, TOTAL_COST,
    FLOOR_PRICE, TARGET_PRICE, CEILING_PRICE,
    CUSTOMER_ID, DISCOUNTED_PRICE
) AS
SELECT
    o.SKU,
    o.PRODUCT_FAMILY,
    o.TOTAL_COST,
    o.FLOOR_PRICE,
    o.TARGET_PRICE,
    o.CEILING_PRICE,
    c.CUSTOMER_ID,
    c.DISCOUNTED_PRICE
FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX o
LEFT JOIN PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING c
    ON o.SKU = c.SKU;


-- ── 5d. PRICING_WITH_SURCHARGE ────────────────────────────────────────────────
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.PRICING_WITH_SURCHARGE (
    SKU, PRODUCT_FAMILY, TOTAL_COST,
    FLOOR_PRICE, TARGET_PRICE, CEILING_PRICE,
    SURCHARGE_TYPE, SURCHARGED_PRICE
) AS
SELECT
    o.SKU,
    o.PRODUCT_FAMILY,
    o.TOTAL_COST,
    o.FLOOR_PRICE,
    o.TARGET_PRICE,
    o.CEILING_PRICE,
    s.SURCHARGE_TYPE,
    ROUND(o.TARGET_PRICE * (1 + s.SURCHARGE_PERCENT / 100), 2) AS SURCHARGED_PRICE
FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX o
CROSS JOIN PRICING_ENGINE_DB.CORE_INPUT.DYNAMIC_SURCHARGES s;


-- ── 5e. SIMULATED_PRICING — cross-join products × pre-defined scenarios ───────
--    Used by: Tab 3 (scenario comparison charts + pre-defined scenario runner)
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING (
    SCENARIO_ID, SCENARIO_NAME, SKU, PRODUCT_FAMILY, TOTAL_COST,
    STEEL_SURCHARGE_PCT, FUEL_SURCHARGE_PCT,
    TARGET_MARGIN_PCT, CUSTOMER_DISCOUNT_PCT,
    SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
) AS
SELECT
    s.SCENARIO_ID,
    s.SCENARIO_NAME,
    p.SKU,
    p.PRODUCT_FAMILY,
    p.TOTAL_COST,
    s.STEEL_SURCHARGE_PCT,
    s.FUEL_SURCHARGE_PCT,
    s.TARGET_MARGIN_PCT,
    s.CUSTOMER_DISCOUNT_PCT,
    ROUND(p.TOTAL_COST * (1 + s.TARGET_MARGIN_PCT / 100), 2)
        AS SIMULATED_TARGET_PRICE,
    ROUND(
        p.TOTAL_COST * (1 + s.TARGET_MARGIN_PCT / 100)
        * (1 - s.CUSTOMER_DISCOUNT_PCT / 100),
        2
    ) AS SIMULATED_CUSTOMER_PRICE
FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX p
CROSS JOIN PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS s;


-- ── 5f. SCENARIO_COMPARISON — feeds the bar charts in Tab 3 ──────────────────
--    (reads from DT_SIMULATED_PRICING dynamic table created in step 6)
--    Created AFTER dynamic tables — see below.


-- =============================================================================
-- STEP 6 — DYNAMIC TABLES
-- Require a warehouse. Change COMPUTE_WH to your actual warehouse name if
-- different. target_lag = '1 minute' keeps them near-real-time.
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE PRICING_ENGINE_DB.CORE_OUTPUT.DT_PRICING (
    SKU, PRODUCT_FAMILY, TOTAL_COST,
    FLOOR_PRICE, TARGET_PRICE, CEILING_PRICE,
    CUSTOMER_ID, DISCOUNTED_PRICE
)
TARGET_LAG = '1 minute'
REFRESH_MODE = AUTO
INITIALIZE = ON_CREATE
WAREHOUSE = COMPUTE_WH
AS
SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING;


CREATE OR REPLACE DYNAMIC TABLE PRICING_ENGINE_DB.CORE_OUTPUT.DT_SIMULATED_PRICING (
    SCENARIO_ID, SCENARIO_NAME, SKU, PRODUCT_FAMILY, TOTAL_COST,
    STEEL_SURCHARGE_PCT, FUEL_SURCHARGE_PCT,
    TARGET_MARGIN_PCT, CUSTOMER_DISCOUNT_PCT,
    SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
)
TARGET_LAG = '1 minute'
REFRESH_MODE = AUTO
INITIALIZE = ON_CREATE
WAREHOUSE = COMPUTE_WH
AS
SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING;


-- ── 5f. SCENARIO_COMPARISON — now safe to create (DT_SIMULATED_PRICING exists)
CREATE OR REPLACE VIEW PRICING_ENGINE_DB.CORE_OUTPUT.SCENARIO_COMPARISON (
    SKU, SCENARIO_NAME,
    SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
) AS
SELECT
    SKU,
    SCENARIO_NAME,
    SIMULATED_TARGET_PRICE,
    SIMULATED_CUSTOMER_PRICE
FROM PRICING_ENGINE_DB.CORE_OUTPUT.DT_SIMULATED_PRICING;


-- =============================================================================
-- STEP 7 — SAMPLE DATA
-- Enough rows to make every tab functional immediately after running this file.
-- Replace / extend with your real data as needed.
-- =============================================================================

-- ── 7a. Products + costs ──────────────────────────────────────────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
    (SKU, PRODUCT_FAMILY, TOTAL_COST)
VALUES
    ('SKU-PUMP-001',  'Pumps',    950.00),
    ('SKU-PUMP-002',  'Pumps',    1120.00),
    ('SKU-PUMP-003',  'Pumps',    780.00),
    ('SKU-VALVE-001', 'Valves',   430.00),
    ('SKU-VALVE-002', 'Valves',   610.00),
    ('SKU-VALVE-003', 'Valves',   390.00),
    ('SKU-MOTOR-001', 'Motors',   2100.00),
    ('SKU-MOTOR-002', 'Motors',   1850.00),
    ('SKU-MOTOR-003', 'Motors',   2450.00),
    ('SKU-GEAR-001',  'Gearboxes',3100.00),
    ('SKU-GEAR-002',  'Gearboxes',2700.00),
    ('SKU-BEAR-001',  'Bearings', 560.00),
    ('SKU-BEAR-002',  'Bearings', 480.00),
    ('SKU-BEAR-003',  'Bearings', 720.00);


-- ── 7b. Margin bands per product family ──────────────────────────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.PRICE_MATRICES
    (PRODUCT_FAMILY, FLOOR_MARGIN, TARGET_MARGIN, CEILING_MARGIN)
VALUES
    ('Pumps',      0.10, 0.30, 0.50),
    ('Valves',     0.12, 0.28, 0.48),
    ('Motors',     0.08, 0.25, 0.45),
    ('Gearboxes',  0.10, 0.32, 0.52),
    ('Bearings',   0.15, 0.35, 0.55);


-- ── 7c. Customer agreements ───────────────────────────────────────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
    (CUSTOMER_ID, DISCOUNT_PERCENT)
VALUES
    ('CUST-001', 5.0),
    ('CUST-002', 8.0),
    ('CUST-003', 12.0),
    ('CUST-004', 3.0),
    ('CUST-005', 10.0),
    ('CUST-006', 6.5),
    ('CUST-007', 15.0),
    ('CUST-008', 4.0);


-- ── 7d. Dynamic surcharges ────────────────────────────────────────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.DYNAMIC_SURCHARGES
    (SURCHARGE_TYPE, SURCHARGE_PERCENT)
VALUES
    ('Steel',     5.0),
    ('Fuel',      2.5),
    ('Logistics', 1.5);


-- ── 7e. Price Sensitivity Index (PSI) ────────────────────────────────────────
--    Covers all 8 customers in CUSTOMER_AGREEMENTS
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
    (CUSTOMER_ID, CUSTOMER_SEGMENT, PRICE_SENSITIVITY_INDEX)
VALUES
    ('CUST-001', 'Enterprise',    0.25),   -- Premium
    ('CUST-002', 'Mid-Market',    0.55),   -- Balanced
    ('CUST-003', 'SME',           0.82),   -- Highly Sensitive
    ('CUST-004', 'Enterprise',    0.15),   -- Maximum Margin
    ('CUST-005', 'Distribution',  0.68),   -- Competitive
    ('CUST-006', 'Mid-Market',    0.42),   -- Balanced
    ('CUST-007', 'SME',           0.88),   -- Highly Sensitive
    ('CUST-008', 'Enterprise',    0.18);   -- Maximum Margin


-- ── 7f. Plant capacity (CUM — Capacity Utilization Modifier) ─────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY
    (PLANT_ID, PLANT_NAME, CURRENT_UTILIZATION, MAX_CAPACITY, AVAILABLE_CAPACITY)
VALUES
    ('PLANT-MUM', 'Mumbai Plant',    72.5, 10000, 2750),
    ('PLANT-PUN', 'Pune Plant',      45.0, 8000,  4400),
    ('PLANT-CHN', 'Chennai Plant',   88.0, 12000, 1440),
    ('PLANT-HYD', 'Hyderabad Plant', 61.0, 6000,  2340),
    ('PLANT-DEL', 'Delhi Plant',     35.0, 9000,  5850);


-- ── 7g. Pre-defined simulation scenarios (CORE_INTERNAL) ─────────────────────
INSERT INTO PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS
    (SCENARIO_ID, SCENARIO_NAME, STEEL_SURCHARGE_PCT, FUEL_SURCHARGE_PCT,
     TARGET_MARGIN_PCT, CUSTOMER_DISCOUNT_PCT)
VALUES
    ('SC-BASE',       'Base Case',              0.0,  0.0,  30.0, 10.0),
    ('SC-STEEL-HI',   'High Steel Cost',        15.0, 2.0,  32.0, 10.0),
    ('SC-FUEL-HI',    'High Fuel Cost',          3.0, 12.0, 31.0, 10.0),
    ('SC-RECESSION',  'Market Recession',        0.0,  0.0,  22.0, 15.0),
    ('SC-PREMIUM',    'Premium Positioning',     5.0,  3.0,  40.0,  5.0),
    ('SC-AGGRESSIVE', 'Aggressive Discounting',  0.0,  0.0,  25.0, 20.0);


-- =============================================================================
-- STEP 8 — VERIFY SETUP
-- Run these SELECT statements to confirm everything is working.
-- All should return rows; no errors should appear.
-- =============================================================================

-- Core input tables
SELECT 'CALCULATED_STANDARD_COSTS' AS tbl, COUNT(*) AS row_count FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
UNION ALL SELECT 'PRICE_MATRICES',       COUNT(*) FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_MATRICES
UNION ALL SELECT 'CUSTOMER_AGREEMENTS',  COUNT(*) FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
UNION ALL SELECT 'DYNAMIC_SURCHARGES',   COUNT(*) FROM PRICING_ENGINE_DB.CORE_INPUT.DYNAMIC_SURCHARGES
UNION ALL SELECT 'PRICE_SENSITIVITY',    COUNT(*) FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
UNION ALL SELECT 'PLANT_CAPACITY',       COUNT(*) FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY
UNION ALL SELECT 'SIMULATION_SCENARIOS', COUNT(*) FROM PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS
-- Output views
UNION ALL SELECT 'OPTIMIZED_PRICING_MATRIX', COUNT(*) FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX
UNION ALL SELECT 'CUSTOMER_PRICING',         COUNT(*) FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING
UNION ALL SELECT 'SIMULATED_PRICING',        COUNT(*) FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING
ORDER BY tbl;




CREATE OR REPLACE TABLE PRICING_ENGINE_DB.CORE_INPUT.WIN_PROBABILITY_CONFIG
(
    CUSTOMER_SEGMENT STRING,
    BASE_WIN_RATE FLOAT,
    PRICE_WEIGHT FLOAT,
    PSI_WEIGHT FLOAT,
    COMPETITOR_WEIGHT FLOAT,
    CAPACITY_WEIGHT FLOAT
);

INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.WIN_PROBABILITY_CONFIG
VALUES
('Enterprise',0.88,0.45,0.25,0.20,0.10),

('SMB',0.82,0.50,0.20,0.20,0.10),

('Retail',0.76,0.55,0.20,0.15,0.10),

('Government',0.92,0.35,0.20,0.25,0.20);