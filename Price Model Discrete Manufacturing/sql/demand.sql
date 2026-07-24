-- ════════════════════════════════════════════════════════════════════
-- REAL DEMAND / ORDER HISTORY  (required for the Demand Forecasting tab)
-- Keyed on SKU + CUSTOMER_ID so it joins to CALCULATED_STANDARD_COSTS,
-- OPTIMIZED_PRICING_MATRIX, CUSTOMER_PRICING, PRICE_SENSITIVITY, etc.
-- IMPORTANT: DO NOT hand-populate. Load ONLY real ERP / order-history data.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY (
    DEMAND_DATE    DATE          NOT NULL,   -- order / shipment / invoice date from ERP
    SKU            VARCHAR       NOT NULL,   -- product key (matches existing SKU everywhere)
    CUSTOMER_ID    VARCHAR,                  -- matches PRICE_SENSITIVITY / CUSTOMER_AGREEMENTS
    QUANTITY       NUMBER(18,2)  NOT NULL,   -- units ordered / shipped
    REVENUE        NUMBER(18,2),             -- net line revenue (optional; else QUANTITY*SELLING_PRICE)
    SELLING_PRICE  NUMBER(18,2),             -- realized unit price
    REGION         VARCHAR,                  -- optional geography
    CHANNEL        VARCHAR                   -- optional sales channel
);

-- ▼▼▼ LOAD REAL DATA HERE (example — adapt to your ERP export / stage) ▼▼▼
-- COPY INTO PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY
--   (DEMAND_DATE, SKU, CUSTOMER_ID, QUANTITY, REVENUE, SELLING_PRICE, REGION, CHANNEL)
-- FROM @PRICING_ENGINE_DB.CORE_INPUT.ERP_STAGE/order_history/
-- FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');
-- ▲▲▲ Never insert fabricated production data. ▲▲▲


-- ════════════════════════════════════════════════════════════════════
-- PERSISTED DEMAND FORECASTS  (written by the Demand Forecasting tab)
-- Mirrors the CORE_OUTPUT.OPTIMIZATION_RESULTS pattern. Append-only.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS PRICING_ENGINE_DB.CORE_OUTPUT.DEMAND_FORECAST_RESULTS (
    RUN_ID             VARCHAR,        -- one id per Save click (groups the horizon rows)
    SCOPE_PRODUCT      VARCHAR,        -- filter used ("All Products" or a SKU)
    SCOPE_CUSTOMER     VARCHAR,
    SCOPE_REGION       VARCHAR,
    HORIZON            VARCHAR,        -- "30 Days" / "90 Days" / "6 Months" / "12 Months"
    FORECAST_DATE      DATE,           -- forecasted period
    FORECAST_DEMAND    NUMBER(18,2),
    LOWER_BOUND        NUMBER(18,2),
    UPPER_BOUND        NUMBER(18,2),
    CONFIDENCE_PCT     NUMBER(9,2),    -- fit R² × 100
    TREND_SLOPE        NUMBER(18,4),   -- units/month
    REP_PRICE          NUMBER(18,2),   -- representative price used for revenue (nullable)
    FORECAST_REVENUE   NUMBER(18,2),   -- FORECAST_DEMAND × REP_PRICE (nullable)
    CREATED_AT         TIMESTAMP_NTZ
);




-- ════════════════════════════════════════════════════════════════════
-- ⚠️ SYNTHETIC / DEMO DATA ONLY — NOT REAL ORDER HISTORY.
-- Generates 24 months of monthly demand for real SKUs × real customers
-- so the Demand Forecasting tab renders end-to-end. Includes trend +
-- seasonality + noise so forecasts, trend classification and charts work.
-- >>> TRUNCATE this table and load real ERP data before production use <<<
-- ════════════════════════════════════════════════════════════════════

-- Safety: start clean so re-runs don't stack duplicate demo rows
TRUNCATE TABLE IF EXISTS PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY;

INSERT INTO PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY
    (DEMAND_DATE, SKU, CUSTOMER_ID, QUANTITY, REVENUE, SELLING_PRICE, REGION, CHANNEL)
WITH
-- 24 monthly periods ending at the current month
months AS (
    SELECT
        DATEADD('month', -SEQ4(), DATE_TRUNC('month', CURRENT_DATE())) AS DEMAND_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 24))
),
month_idx AS (   -- 0 = oldest month ... 23 = newest (for trend math)
    SELECT DEMAND_DATE,
           ROW_NUMBER() OVER (ORDER BY DEMAND_DATE) - 1 AS M
    FROM months
),
-- Real products (cap to keep row count sane)
skus AS (
    SELECT SKU, TOTAL_COST
    FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
    ORDER BY SKU
    LIMIT 15
),
-- Representative price per SKU from your existing pricing tables
sku_price AS (
    SELECT s.SKU,
           s.TOTAL_COST,
           COALESCE(
               (SELECT AVG(m.TARGET_PRICE)
                  FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX m
                 WHERE m.SKU = s.SKU),
               s.TOTAL_COST * 1.35
           ) AS SELLING_PRICE
    FROM skus s
),
-- Real customers (cap similarly)
custs AS (
    SELECT CUSTOMER_ID
    FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
    ORDER BY CUSTOMER_ID
    LIMIT 10
),
-- Region/channel pools for optional dimensions
dims AS (
    SELECT ARRAY_CONSTRUCT('North','South','East','West') AS REGIONS,
           ARRAY_CONSTRUCT('Direct','Distributor','OEM')  AS CHANNELS
)
SELECT
    mi.DEMAND_DATE,
    sp.SKU,
    c.CUSTOMER_ID,
    -- QUANTITY = base × (1 + per-SKU trend·month) × seasonality × noise, floored at 1
    GREATEST(
        1,
        ROUND(
            ( (ABS(HASH(sp.SKU)) % 300) + 80 )                                   -- per-SKU base 80–380
            * (1 + (((ABS(HASH(sp.SKU)) % 5) - 2) * 0.015) * mi.M)               -- trend ±3%/mo
            * (1 + 0.20 * SIN(2 * 3.14159 * (MONTH(mi.DEMAND_DATE)) / 12))       -- yearly seasonality
            * (0.85 + UNIFORM(0, 30, RANDOM()) / 100.0)                          -- ±15% noise
            * (1 + (ABS(HASH(c.CUSTOMER_ID)) % 4) * 0.1)                         -- per-customer scale
        )
    ) AS QUANTITY,
    ROUND(QUANTITY * sp.SELLING_PRICE, 2) AS REVENUE,
    ROUND(sp.SELLING_PRICE, 2)            AS SELLING_PRICE,
    GET(d.REGIONS,  ABS(HASH(c.CUSTOMER_ID)) % 4) :: STRING AS REGION,
    GET(d.CHANNELS, ABS(HASH(sp.SKU))        % 3) :: STRING AS CHANNEL
FROM month_idx mi
CROSS JOIN sku_price sp
CROSS JOIN custs c
CROSS JOIN dims d;



SELECT COUNT(*) rows, MIN(DEMAND_DATE) first_m, MAX(DEMAND_DATE) last_m,
       COUNT(DISTINCT SKU) skus, COUNT(DISTINCT CUSTOMER_ID) custs
FROM PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY;