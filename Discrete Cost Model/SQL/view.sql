-- Discrete manufacturing cost model views
-- Co-authored with CoCo

-- =====================================================
-- COST BREAKDOWN
-- =====================================================

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN AS

WITH RECURSIVE BOM_EXPLOSION AS (

    SELECT
        PARENT_ID AS TOP_LEVEL_ITEM,
        PARENT_ID,
        REVISION,
        COMPONENT_ID,
        QUANTITY AS UNITS,
        PARENT_ID || '>' || COMPONENT_ID AS PATH

    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE

    WHERE CURRENT_DATE BETWEEN
          EFFECTIVE_FROM
      AND COALESCE(EFFECTIVE_TO,'9999-12-31')

    UNION ALL

    SELECT
        b.TOP_LEVEL_ITEM,
        c.PARENT_ID,
        b.REVISION,
        c.COMPONENT_ID,
        b.UNITS * c.QUANTITY AS UNITS,
        b.PATH || '>' || c.COMPONENT_ID AS PATH

    FROM BOM_EXPLOSION b

    JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE c
        ON b.COMPONENT_ID = c.PARENT_ID
        AND b.REVISION = c.REVISION

    WHERE POSITION(
        '>' || c.COMPONENT_ID || '>'
        IN
        '>' || b.PATH || '>'
    ) = 0

    AND CURRENT_DATE BETWEEN
            c.EFFECTIVE_FROM
        AND COALESCE(c.EFFECTIVE_TO,'9999-12-31')
)

SELECT

    b.TOP_LEVEL_ITEM,
    b.PARENT_ID,
    b.REVISION,
    b.COMPONENT_ID,
    b.UNITS,
    b.PATH,

    im.PREFERRED_SUPPLIER,

    sc.UNIT_COST AS SUPPLIER_COST,

    m.STANDARD_COST AS BASE_COST,

    COALESCE(
        sc.UNIT_COST,
        m.STANDARD_COST
    ) AS USED_COST,

    b.UNITS *
    COALESCE(
        sc.UNIT_COST,
        m.STANDARD_COST
    ) AS EXTENDED_COST

FROM BOM_EXPLOSION b

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER im

    ON b.COMPONENT_ID = im.ITEM_ID

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.SUPPLIER_COSTS sc

    ON sc.ITEM_ID = b.COMPONENT_ID

    AND sc.SUPPLIER_ID = im.PREFERRED_SUPPLIER

    AND CURRENT_DATE BETWEEN
        COALESCE(sc.EFFECTIVE_FROM,'1900-01-01')
        AND COALESCE(sc.EFFECTIVE_TO,'9999-12-31')

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.MATERIAL_COSTS m

    ON m.ITEM_ID = b.COMPONENT_ID

    AND CURRENT_DATE BETWEEN
        COALESCE(m.EFFECTIVE_FROM,'1900-01-01')
        AND COALESCE(m.EFFECTIVE_TO,'9999-12-31');


-- =====================================================
-- ROUTING COSTS
-- =====================================================

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.ROUTING_COSTS AS

SELECT

    ITEM_ID,

    SUM(
        (SETUP_HOURS + RUN_HOURS)
        * LABOR_RATE
    ) AS LABOR_COST,

    SUM(
        (SETUP_HOURS + RUN_HOURS)
        * MACHINE_RATE
    ) AS MACHINE_COST,

    SUM(
        (
            (SETUP_HOURS + RUN_HOURS)
            * LABOR_RATE
        )
        +
        (
            (SETUP_HOURS + RUN_HOURS)
            * MACHINE_RATE
        )
    ) AS ROUTING_COST

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ROUTING_OPERATIONS

GROUP BY ITEM_ID;



-- =====================================================
-- CALCULATED STANDARD COSTS
-- =====================================================

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.CALCULATED_STANDARD_COSTS AS

SELECT
    TOP_LEVEL_ITEM,
    REVISION,
    SUM(
        COALESCE(EXTENDED_COST,0)
    ) AS TOTAL_MATERIAL_COST
FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN

GROUP BY
    TOP_LEVEL_ITEM,
    REVISION;



-- =====================================================
-- ROUTING COST BREAKDOWN
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.ROUTING_COST_BREAKDOWN AS

WITH RECURSIVE BOM_EXPLOSION AS (

    SELECT
        PARENT_ID AS TOP_LEVEL_ITEM,
        PARENT_ID,
        REVISION,
        COMPONENT_ID,
        QUANTITY AS UNITS,
        PARENT_ID || '>' || COMPONENT_ID AS PATH

    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE

    WHERE CURRENT_DATE BETWEEN
          EFFECTIVE_FROM
      AND COALESCE(EFFECTIVE_TO,'9999-12-31')

    UNION ALL

    SELECT
        b.TOP_LEVEL_ITEM,
        c.PARENT_ID,
        b.REVISION,
        c.COMPONENT_ID,
        b.UNITS * c.QUANTITY,
        b.PATH || '>' || c.COMPONENT_ID

    FROM BOM_EXPLOSION b

    JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE c
        ON b.COMPONENT_ID = c.PARENT_ID
        AND b.REVISION = c.REVISION

    WHERE POSITION(
        '>' || c.COMPONENT_ID || '>'
        IN
        '>' || b.PATH || '>'
    ) = 0

    AND CURRENT_DATE BETWEEN
            c.EFFECTIVE_FROM
        AND COALESCE(c.EFFECTIVE_TO,'9999-12-31')
)

SELECT

    b.TOP_LEVEL_ITEM,
    b.PARENT_ID,
    b.REVISION,
    b.COMPONENT_ID,
    r.ITEM_ID,
    b.UNITS,

    b.UNITS * r.LABOR_COST
        AS EXTENDED_LABOR_COST,

    b.UNITS * r.MACHINE_COST
        AS EXTENDED_MACHINE_COST

FROM BOM_EXPLOSION b

JOIN DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.ROUTING_COSTS r
    ON b.COMPONENT_ID = r.ITEM_ID;


-- =====================================================
-- TOTAL PRODUCT COSTS
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TOTAL_PRODUCT_COSTS AS

WITH ROUTING_ROLLUP AS (

    SELECT
        TOP_LEVEL_ITEM,

        SUM(EXTENDED_LABOR_COST)
            AS CHILD_LABOR_COST,

        SUM(EXTENDED_MACHINE_COST)
            AS CHILD_MACHINE_COST

    FROM
    DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.ROUTING_COST_BREAKDOWN

    GROUP BY TOP_LEVEL_ITEM
),

PARENT_ROUTING AS (

    SELECT
        ITEM_ID AS TOP_LEVEL_ITEM,

        LABOR_COST AS PARENT_LABOR_COST,

        MACHINE_COST AS PARENT_MACHINE_COST

    FROM
    DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.ROUTING_COSTS
)

SELECT

    c.TOP_LEVEL_ITEM,

    c.REVISION,
    
    c.TOTAL_MATERIAL_COST,

    COALESCE(r.CHILD_LABOR_COST,0)
    +
    COALESCE(p.PARENT_LABOR_COST,0)
        AS LABOR_COST,

    COALESCE(r.CHILD_MACHINE_COST,0)
    +
    COALESCE(p.PARENT_MACHINE_COST,0)
        AS MACHINE_COST,

    c.TOTAL_MATERIAL_COST

    + COALESCE(r.CHILD_LABOR_COST,0)
    + COALESCE(r.CHILD_MACHINE_COST,0)

    + COALESCE(p.PARENT_LABOR_COST,0)
    + COALESCE(p.PARENT_MACHINE_COST,0)

    AS TOTAL_COST

FROM
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.CALCULATED_STANDARD_COSTS c

LEFT JOIN ROUTING_ROLLUP r
    ON c.TOP_LEVEL_ITEM = r.TOP_LEVEL_ITEM

LEFT JOIN PARENT_ROUTING p
    ON c.TOP_LEVEL_ITEM = p.TOP_LEVEL_ITEM;


-- =====================================================
-- QUALITY_FEATURES_V
-- This will primarily feed CSS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.QUALITY_FEATURES_V AS

SELECT

    ITEM_ID,

    COUNT(DISTINCT BATCH_ID) AS TOTAL_BATCHES,

    SUM(UNITS_PRODUCED) AS TOTAL_UNITS,

    SUM(UNITS_PASSED) AS TOTAL_PASSED,

    SUM(UNITS_REWORKED) AS TOTAL_REWORKED,

    SUM(UNITS_REJECTED) AS TOTAL_REJECTED,

    AVG(SCRAP_RATE) AS AVG_SCRAP_RATE,

    MAX(SCRAP_RATE) AS MAX_SCRAP_RATE,

    AVG(DEFECT_RATE) AS AVG_DEFECT_RATE,

    AVG(FIRST_PASS_YIELD) AS AVG_FIRST_PASS_YIELD,

    SUM(UNITS_REWORKED)
/ NULLIF(SUM(UNITS_PRODUCED),0)

        AS REWORK_RATIO,

    SUM(UNITS_REJECTED)
/ NULLIF(SUM(UNITS_PRODUCED),0)

        AS REJECT_RATIO

FROM
DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_HISTORY

GROUP BY ITEM_ID;

-- =====================================================
-- PRODUCTION_FEATURES_V
-- Feeds CSS and TDS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_PRODUCTION_FEATURES_V AS

SELECT

    ITEM_ID AS TOP_LEVEL_ITEM,

    AVG_RUNTIME AS WEIGHTED_RUNTIME,

    SCRAP_RATIO AS WEIGHTED_SCRAP_RATIO,

    YIELD_RATIO AS WEIGHTED_YIELD,

    TOTAL_PRODUCED AS TOTAL_PRODUCTION,

    TOTAL_RUNS

FROM
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCTION_FEATURES_V;


-- =====================================================
-- PRODUCT_MACHINE_FEATURES_V
-- Product-level machine health features for TDS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_MACHINE_FEATURES_V
AS

WITH PRODUCT_WORK_CENTERS AS (

    SELECT DISTINCT

        b.TOP_LEVEL_ITEM,

        r.WORK_CENTER

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN b

    JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ROUTING_OPERATIONS r

        ON b.COMPONENT_ID = r.ITEM_ID

)

SELECT

    p.TOP_LEVEL_ITEM,

    COUNT(DISTINCT p.WORK_CENTER)
        AS WORK_CENTER_COUNT,

    AVG(m.AVG_UTILIZATION)
        AS AVG_UTILIZATION,

    AVG(m.AVG_TEMPERATURE)
        AS AVG_TEMPERATURE,

    AVG(m.AVG_VIBRATION)
        AS AVG_VIBRATION,

    AVG(m.HEALTH_SCORE)
        AS AVG_MACHINE_HEALTH,

    AVG(m.BREAKDOWN_COUNT)
        AS AVG_BREAKDOWNS

FROM PRODUCT_WORK_CENTERS p

JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.MACHINE_FEATURES_V m

    ON p.WORK_CENTER = m.WORK_CENTER

GROUP BY
    p.TOP_LEVEL_ITEM;


-- =====================================================
-- PRODUCT_PRODUCTION_FEATURES_V
-- Product-level production history for TDS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_PRODUCTION_FEATURES_V
AS

WITH PRODUCT_COMPONENTS AS (

    SELECT DISTINCT

        TOP_LEVEL_ITEM,

        COMPONENT_ID,

        UNITS

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN

),

PRODUCTION_DATA AS (

    SELECT

        p.TOP_LEVEL_ITEM,

        p.UNITS,

        pr.AVG_RUNTIME,

        pr.SCRAP_RATIO,

        pr.YIELD_RATIO,

        pr.TOTAL_PRODUCED,

        pr.TOTAL_RUNS

    FROM PRODUCT_COMPONENTS p

    LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCTION_FEATURES_V pr

        ON p.COMPONENT_ID = pr.ITEM_ID

)

SELECT

    TOP_LEVEL_ITEM,

    SUM(UNITS)
        AS TOTAL_COMPONENT_UNITS,

    SUM(AVG_RUNTIME * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_RUNTIME,

    SUM(SCRAP_RATIO * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_SCRAP_RATIO,

    SUM(YIELD_RATIO * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_YIELD,

    SUM(TOTAL_PRODUCED)
        AS TOTAL_PRODUCTION,

    SUM(TOTAL_RUNS)
        AS TOTAL_RUNS

FROM PRODUCTION_DATA

GROUP BY
    TOP_LEVEL_ITEM;

-- =====================================================
-- SUPPLIER_FEATURES_V
-- Feeds CSS and FMIS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.SUPPLIER_FEATURES_V AS

SELECT

    SUPPLIER_ID,

    AVG(QUALITY_SCORE) AS QUALITY_SCORE,

    AVG(ON_TIME_PERCENT) AS ON_TIME_PERCENT,

    AVG(DEFECT_RATE) AS DEFECT_RATE,

    AVG(LOT_ACCEPTANCE_RATE) AS LOT_ACCEPTANCE,

    100 - AVG(QUALITY_SCORE)

        AS QUALITY_RISK

FROM
DISCRETE_MFG_COST_MODEL.CORE_INPUT.SUPPLIER_PERFORMANCE

GROUP BY SUPPLIER_ID;

-- =====================================================
-- ROUTING_FEATURES_V
-- Feeds TDS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ROUTING_FEATURES_V AS

SELECT

    ITEM_ID,

    COUNT(*) AS TOTAL_OPERATIONS,

    SUM(SETUP_HOURS) AS TOTAL_SETUP,

    SUM(RUN_HOURS) AS TOTAL_RUN,

    AVG(SETUP_HOURS) AS AVG_SETUP,

    AVG(RUN_HOURS) AS AVG_RUN,

    SUM(SETUP_HOURS + RUN_HOURS)

        AS TOTAL_PROCESS_TIME,

    AVG(LABOR_RATE) AS AVG_LABOR_RATE,

    AVG(MACHINE_RATE) AS AVG_MACHINE_RATE

FROM
DISCRETE_MFG_COST_MODEL.CORE_INPUT.ROUTING_OPERATIONS

GROUP BY ITEM_ID;

-- =====================================================
-- MACHINE_FEATURES_V
-- Feeds TDS.
-- =====================================================

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_FEATURES.MACHINE_FEATURES_V AS

SELECT

    WORK_CENTER,

    AVG(UTILIZATION_PERCENT) AS AVG_UTILIZATION,

    AVG(TEMPERATURE) AS AVG_TEMPERATURE,

    AVG(VIBRATION_LEVEL) AS AVG_VIBRATION,

    AVG(HEALTH_SCORE) AS HEALTH_SCORE,

    AVG(BREAKDOWN_COUNT) AS BREAKDOWN_COUNT

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.MACHINE_HEALTH

GROUP BY WORK_CENTER;

-- =====================================================
-- INVENTORY_FEATURES_V
-- Feeds FMIS.
-- =====================================================

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_FEATURES.INVENTORY_FEATURES_V AS

SELECT

    ITEM_ID,

    AVG(STOCK_QTY) AS AVG_STOCK,

    AVG(SAFETY_STOCK) AS AVG_SAFETY_STOCK,

    AVG(DAYS_OF_COVER) AS AVG_DAYS_OF_COVER,

    AVG(STOCK_QTY)
/ NULLIF(AVG(SAFETY_STOCK),0)

        AS STOCK_TO_SAFETY_RATIO,

    CASE

        WHEN AVG(STOCK_QTY)
             <
             AVG(SAFETY_STOCK)

        THEN 1

        ELSE 0

    END AS LOW_STOCK_FLAG

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.INVENTORY_HISTORY

GROUP BY ITEM_ID;

-- =====================================================
-- PRODUCT_INVENTORY_FEATURES_V
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_INVENTORY_FEATURES_V
AS

WITH PRODUCT_COMPONENTS AS (

    SELECT

        b.TOP_LEVEL_ITEM,

        b.COMPONENT_ID,

        b.UNITS

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN b

),

INVENTORY_DATA AS (

    SELECT

        p.TOP_LEVEL_ITEM,

        p.COMPONENT_ID,

        p.UNITS,

        i.STOCK_QTY,

        i.SAFETY_STOCK,

        i.DAYS_OF_COVER,

        CASE

            WHEN i.SAFETY_STOCK = 0 THEN 1

            ELSE i.STOCK_QTY / i.SAFETY_STOCK

        END AS STOCK_RATIO,

        CASE

            WHEN i.STOCK_QTY < i.SAFETY_STOCK THEN 1

            ELSE 0

        END AS LOW_STOCK_FLAG

    FROM PRODUCT_COMPONENTS p

    LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.INVENTORY_HISTORY i

        ON p.COMPONENT_ID = i.ITEM_ID

)

SELECT

    TOP_LEVEL_ITEM,

    COUNT(DISTINCT COMPONENT_ID)
        AS COMPONENT_COUNT,

    SUM(UNITS)
        AS TOTAL_COMPONENT_UNITS,

    -------------------------------------------------------
    -- Quantity weighted inventory
    -------------------------------------------------------

    SUM(STOCK_QTY * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_STOCK,

    SUM(SAFETY_STOCK * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_SAFETY_STOCK,

    SUM(DAYS_OF_COVER * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_DAYS_OF_COVER,

    SUM(STOCK_RATIO * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_STOCK_RATIO,

    -------------------------------------------------------
    -- Percentage of low stock components
    -------------------------------------------------------

    SUM(LOW_STOCK_FLAG * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS LOW_STOCK_RATIO

FROM INVENTORY_DATA

GROUP BY TOP_LEVEL_ITEM;

-- =====================================================
-- COMMODITY_FEATURES_V
-- Feeds FMIS.
-- ==========================================CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_FEATURES.INVENTORY_FEATURES_V AS

SELECT

    ITEM_ID,

    AVG(STOCK_QTY) AS AVG_STOCK,

    AVG(SAFETY_STOCK) AS AVG_SAFETY_STOCK,

    AVG(DAYS_OF_COVER) AS AVG_DAYS_OF_COVER,

    AVG(STOCK_QTY)
/ NULLIF(AVG(SAFETY_STOCK),0)

        AS STOCK_TO_SAFETY_RATIO,

    CASE

        WHEN AVG(STOCK_QTY)
             <
             AVG(SAFETY_STOCK)

        THEN 1

        ELSE 0

    END AS LOW_STOCK_FLAG

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.INVENTORY_HISTORY

GROUP BY ITEM_ID;

CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_FEATURES.COMMODITY_FEATURES_V AS

WITH PRICE_HISTORY AS (

    SELECT
        COMMODITY_GROUP,
        PRICE_DATE,
        MARKET_PRICE,

        ROW_NUMBER() OVER (
            PARTITION BY COMMODITY_GROUP
            ORDER BY PRICE_DATE ASC
        ) AS RN_ASC,

        ROW_NUMBER() OVER (
            PARTITION BY COMMODITY_GROUP
            ORDER BY PRICE_DATE DESC
        ) AS RN_DESC

    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.COMMODITY_PRICE_HISTORY
)

SELECT

    COMMODITY_GROUP,

    AVG(MARKET_PRICE) AS AVG_PRICE,

    MIN(MARKET_PRICE) AS MIN_PRICE,

    MAX(MARKET_PRICE) AS MAX_PRICE,

    STDDEV(MARKET_PRICE) AS PRICE_VOLATILITY,

    MAX(CASE WHEN RN_ASC = 1 THEN MARKET_PRICE END) AS EARLIEST_PRICE,

    MAX(CASE WHEN RN_DESC = 1 THEN MARKET_PRICE END) AS LATEST_PRICE,

    (
        (
            MAX(CASE WHEN RN_DESC = 1 THEN MARKET_PRICE END)
            -
            MAX(CASE WHEN RN_ASC = 1 THEN MARKET_PRICE END)
        )
        /
        NULLIF(
            MAX(CASE WHEN RN_ASC = 1 THEN MARKET_PRICE END),
            0
        )
    ) * 100 AS PRICE_CHANGE_PERCENT

FROM PRICE_HISTORY

GROUP BY COMMODITY_GROUP;

-- =====================================================
-- PRODUCT_COMMODITY_FEATURES_V
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_COMMODITY_FEATURES_V
AS

WITH PRODUCT_COMPONENTS AS (

    SELECT

        b.TOP_LEVEL_ITEM,

        b.COMPONENT_ID,

        b.UNITS,

        i.COMMODITY_GROUP

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN b

    JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER i

        ON b.COMPONENT_ID = i.ITEM_ID

),

COMMODITY_DATA AS (

    SELECT

        p.TOP_LEVEL_ITEM,

        p.COMPONENT_ID,

        p.UNITS,

        p.COMMODITY_GROUP,

        c.AVG_PRICE,

        c.PRICE_VOLATILITY,

        c.PRICE_CHANGE_PERCENT

    FROM PRODUCT_COMPONENTS p

    JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.COMMODITY_FEATURES_V c

        ON p.COMMODITY_GROUP = c.COMMODITY_GROUP

)

SELECT

    TOP_LEVEL_ITEM,

    COUNT(DISTINCT COMMODITY_GROUP)
        AS COMMODITY_COUNT,

    SUM(UNITS)
        AS TOTAL_COMMODITY_UNITS,

    --------------------------------------------------
    -- Quantity-weighted commodity price
    --------------------------------------------------

    SUM(AVG_PRICE * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_AVG_PRICE,

    --------------------------------------------------
    -- Quantity-weighted volatility
    --------------------------------------------------

    SUM(PRICE_VOLATILITY * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_PRICE_VOLATILITY,

    --------------------------------------------------
    -- Quantity-weighted market trend
    --------------------------------------------------

    SUM(PRICE_CHANGE_PERCENT * UNITS)
    /
    NULLIF(SUM(UNITS),0)

        AS WEIGHTED_PRICE_CHANGE,

    --------------------------------------------------
    -- Highest exposure
    --------------------------------------------------

    MAX(PRICE_CHANGE_PERCENT)
        AS MAX_PRICE_CHANGE,

    MAX(PRICE_VOLATILITY)
        AS MAX_PRICE_VOLATILITY

FROM COMMODITY_DATA

GROUP BY TOP_LEVEL_ITEM;

-- =====================================================
-- ENGINEERING_FEATURES_V
-- Engineering change features for BMCS.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ENGINEERING_FEATURES_V
AS

SELECT

    ITEM_ID,

    COUNT(*) AS CHANGE_COUNT,

    AVG(AFFECTED_COMPONENTS)
        AS AVG_AFFECTED_COMPONENTS,

    MAX(CHANGE_DATE)
        AS LAST_CHANGE_DATE,

    DATEDIFF(
        DAY,
        MAX(CHANGE_DATE),
        CURRENT_DATE
    ) AS DAYS_SINCE_LAST_CHANGE,

    CASE

        WHEN COUNT(*) <= 2
        THEN 100

        WHEN COUNT(*) <= 5
        THEN 75

        WHEN COUNT(*) <= 10
        THEN 50

        ELSE 25

    END AS ENGINEERING_STABILITY

FROM
DISCRETE_MFG_COST_MODEL.CORE_INPUT.ENGINEERING_CHANGE

GROUP BY ITEM_ID;

-- =====================================================
-- BOM_FEATURES_V
-- This is the bridge between your existing feature engineering and the new feature views.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BOM_FEATURES_V
AS

WITH BOM_BASE AS (

    SELECT

        TOP_LEVEL_ITEM,

        PARENT_ID,

        COMPONENT_ID,

        UNITS

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN

),

PARENT_STATS AS (

    SELECT

        TOP_LEVEL_ITEM,

        PARENT_ID,

        COUNT(*) AS CHILD_COUNT

    FROM BOM_BASE

    GROUP BY
        TOP_LEVEL_ITEM,
        PARENT_ID

)

SELECT

    b.TOP_LEVEL_ITEM,

    COUNT(DISTINCT b.COMPONENT_ID)
        AS COMPONENT_COUNT,

    COUNT(DISTINCT b.PARENT_ID)
        AS ASSEMBLY_COUNT,

    COUNT(*)
        AS BOM_RELATIONSHIPS,

    SUM(b.UNITS)
        AS TOTAL_COMPONENT_QTY,

    AVG(b.UNITS)
        AS AVG_COMPONENT_QTY,

    MAX(b.UNITS)
        AS MAX_COMPONENT_QTY,

    MIN(b.UNITS)
        AS MIN_COMPONENT_QTY,

    AVG(p.CHILD_COUNT)
        AS AVG_BRANCH_FACTOR,

    COUNT(*)
    /
    NULLIF(COUNT(DISTINCT b.PARENT_ID),0)

        AS ASSEMBLY_DENSITY

FROM BOM_BASE b

LEFT JOIN PARENT_STATS p

ON b.TOP_LEVEL_ITEM = p.TOP_LEVEL_ITEM
AND b.PARENT_ID = p.PARENT_ID

GROUP BY
    b.TOP_LEVEL_ITEM;

-- =====================================================
-- PRODUCT_SUPPLIER_FEATURES_V
-- Product-level supplier analytics.
-- Feeds Manufacturing Dimensions and AI Context.
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_SUPPLIER_FEATURES_V
AS

WITH PRODUCT_COMPONENTS AS (

    SELECT

        b.TOP_LEVEL_ITEM,

        b.COMPONENT_ID,

        b.UNITS,

        i.PREFERRED_SUPPLIER

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN b

    JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER i

        ON b.COMPONENT_ID = i.ITEM_ID

),

SUPPLIER_METRICS AS (

    SELECT

        p.TOP_LEVEL_ITEM,

        p.COMPONENT_ID,

        p.UNITS,

        p.PREFERRED_SUPPLIER,

        s.QUALITY_SCORE,

        s.ON_TIME_PERCENT,

        s.DEFECT_RATE,

        s.LOT_ACCEPTANCE

    FROM PRODUCT_COMPONENTS p

    LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.SUPPLIER_FEATURES_V s

        ON p.PREFERRED_SUPPLIER = s.SUPPLIER_ID

),

SUPPLIER_SPEND AS (

    SELECT

        TOP_LEVEL_ITEM,

        PREFERRED_SUPPLIER,

        SUM(UNITS) AS SUPPLIER_UNITS

    FROM SUPPLIER_METRICS

    GROUP BY
        TOP_LEVEL_ITEM,
        PREFERRED_SUPPLIER

),

SUPPLIER_CONCENTRATION AS (

    SELECT

        TOP_LEVEL_ITEM,

        MAX(SUPPLIER_UNITS)
        /
        NULLIF(SUM(SUPPLIER_UNITS),0)

        AS SUPPLIER_CONCENTRATION

    FROM SUPPLIER_SPEND

    GROUP BY TOP_LEVEL_ITEM

)

SELECT

    s.TOP_LEVEL_ITEM,

    COUNT(DISTINCT s.PREFERRED_SUPPLIER)
        AS SUPPLIER_COUNT,

    SUM(s.UNITS)
        AS TOTAL_COMPONENT_UNITS,

    SUM(s.QUALITY_SCORE * s.UNITS)
    /
    NULLIF(SUM(s.UNITS),0)

        AS AVG_SUPPLIER_QUALITY,

    SUM(s.ON_TIME_PERCENT * s.UNITS)
    /
    NULLIF(SUM(s.UNITS),0)

        AS AVG_ON_TIME_PERCENT,

    SUM(s.DEFECT_RATE * s.UNITS)
    /
    NULLIF(SUM(s.UNITS),0)

        AS AVG_DEFECT_RATE,

    SUM(s.LOT_ACCEPTANCE * s.UNITS)
    /
    NULLIF(SUM(s.UNITS),0)

        AS AVG_LOT_ACCEPTANCE,

    c.SUPPLIER_CONCENTRATION

FROM SUPPLIER_METRICS s

JOIN SUPPLIER_CONCENTRATION c

    ON s.TOP_LEVEL_ITEM = c.TOP_LEVEL_ITEM

GROUP BY

    s.TOP_LEVEL_ITEM,

    c.SUPPLIER_CONCENTRATION;

-- =====================================================
-- CSS_TRAINING_DATA_V
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.CSS_TRAINING_DATA_V
AS

WITH QUALITY_LABELS AS (

    SELECT

        ITEM_ID,

        AVG(SCRAP_RATE) AS AVG_SCRAP_RATE,

        AVG(DEFECT_RATE) AS AVG_DEFECT_RATE,

        AVG(FIRST_PASS_YIELD) AS AVG_FIRST_PASS_YIELD,

        CASE
            WHEN AVG(SCRAP_RATE) >= 3
              OR AVG(DEFECT_RATE) >= 5
            THEN 1
            ELSE 0
        END AS HIGH_SCRAP

    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_HISTORY

    GROUP BY ITEM_ID

)

SELECT

    ai.TOP_LEVEL_ITEM,

    ai.REVISION,

    ai.COMPONENT_COUNT,

    ai.ASSEMBLY_COUNT,

    ai.BOM_RELATIONSHIPS,

    ai.AVG_BRANCH_FACTOR,

    ai.ASSEMBLY_DENSITY,

    ai.TOTAL_MATERIAL_COST,

    ai.LABOR_COST,

    ai.MACHINE_COST,

    ai.TOTAL_COST,

    ai.SUPPLIER_COUNT,

    COALESCE(ai.AVG_SUPPLIER_QUALITY,100) AS AVG_SUPPLIER_QUALITY,

    COALESCE(ai.AVG_MACHINE_HEALTH,100) AS AVG_MACHINE_HEALTH,

    COALESCE(ai.AVG_UTILIZATION,0) AS AVG_UTILIZATION,

    COALESCE(ai.CHANGE_COUNT,0) AS CHANGE_COUNT,

    COALESCE(ai.ENGINEERING_STABILITY,100) AS ENGINEERING_STABILITY,

    ai.WEIGHTED_PRICE_VOLATILITY,

    ai.LOW_STOCK_RATIO,

    COALESCE(q.AVG_SCRAP_RATE,0) AS AVG_SCRAP_RATE,

    COALESCE(q.AVG_DEFECT_RATE,0) AS AVG_DEFECT_RATE,

    COALESCE(q.AVG_FIRST_PASS_YIELD,100) AS AVG_FIRST_PASS_YIELD,

    COALESCE(q.HIGH_SCRAP,0) AS HIGH_SCRAP

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FEATURE_CONTEXT_V ai

LEFT JOIN QUALITY_LABELS q

ON ai.TOP_LEVEL_ITEM = q.ITEM_ID;

// FEATURE_CONTEXT_V
CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FEATURE_CONTEXT_V AS

    WITH BASE_PRODUCT AS (

    SELECT

        t.TOP_LEVEL_ITEM,

        t.REVISION,

        i.ITEM_NAME,

        i.PRODUCT_FAMILY,

        i.STATUS,

        i.COMMODITY_GROUP,

        t.TOTAL_MATERIAL_COST,

        t.LABOR_COST,

        t.MACHINE_COST,

        t.TOTAL_COST

    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TOTAL_PRODUCT_COSTS t

    LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER i

        ON t.TOP_LEVEL_ITEM = i.ITEM_ID

),

FEATURE_CONTEXT AS (

SELECT

    -----------------------------------------------------
    -- Product
    -----------------------------------------------------

    p.TOP_LEVEL_ITEM,

    p.REVISION,

    p.ITEM_NAME,

    p.PRODUCT_FAMILY,

    p.STATUS,

    p.COMMODITY_GROUP,

    -----------------------------------------------------
    -- Standard Cost
    -----------------------------------------------------

    p.TOTAL_MATERIAL_COST,

    p.LABOR_COST,

    p.MACHINE_COST,

    p.TOTAL_COST,

    -----------------------------------------------------
    -- BOM
    -----------------------------------------------------

    bom.COMPONENT_COUNT,

    bom.ASSEMBLY_COUNT,

    bom.BOM_RELATIONSHIPS,

    bom.TOTAL_COMPONENT_QTY,

    bom.AVG_COMPONENT_QTY,

    bom.MAX_COMPONENT_QTY,

    bom.MIN_COMPONENT_QTY,

    bom.AVG_BRANCH_FACTOR,

    bom.ASSEMBLY_DENSITY,

    -----------------------------------------------------
    -- Routing
    -----------------------------------------------------

    route.TOTAL_OPERATIONS,

    route.TOTAL_SETUP,

    route.TOTAL_RUN,

    route.AVG_SETUP,

    route.AVG_RUN,

    route.TOTAL_PROCESS_TIME,

    route.AVG_LABOR_RATE,

    route.AVG_MACHINE_RATE,

    -----------------------------------------------------
    -- Supplier
    -----------------------------------------------------

    supplier.SUPPLIER_COUNT,

    supplier.AVG_SUPPLIER_QUALITY,

    supplier.AVG_ON_TIME_PERCENT,

    supplier.AVG_DEFECT_RATE,

    supplier.AVG_LOT_ACCEPTANCE,

    supplier.SUPPLIER_CONCENTRATION,

    -----------------------------------------------------
    -- Machine
    -----------------------------------------------------

    machine.WORK_CENTER_COUNT,

    machine.AVG_UTILIZATION,

    machine.AVG_TEMPERATURE,

    machine.AVG_VIBRATION,

    machine.AVG_MACHINE_HEALTH,

    machine.AVG_BREAKDOWNS,

    -----------------------------------------------------
    -- Production
    -----------------------------------------------------

    production.TOTAL_COMPONENT_UNITS,

    production.WEIGHTED_RUNTIME,

    production.WEIGHTED_SCRAP_RATIO,

    production.WEIGHTED_YIELD,

    production.TOTAL_PRODUCTION,

    production.TOTAL_RUNS,

    -----------------------------------------------------
    -- Inventory
    -----------------------------------------------------

    inventory.WEIGHTED_STOCK,

    inventory.WEIGHTED_SAFETY_STOCK,

    inventory.WEIGHTED_DAYS_OF_COVER,

    inventory.WEIGHTED_STOCK_RATIO,

    inventory.LOW_STOCK_RATIO,

    -----------------------------------------------------
    -- Commodity
    -----------------------------------------------------

    commodity.COMMODITY_COUNT,

    commodity.WEIGHTED_AVG_PRICE,

    commodity.WEIGHTED_PRICE_VOLATILITY,

    commodity.WEIGHTED_PRICE_CHANGE,

    commodity.MAX_PRICE_CHANGE,

    commodity.MAX_PRICE_VOLATILITY,

    -----------------------------------------------------
    -- Engineering
    -----------------------------------------------------

    engineering.CHANGE_COUNT,

    engineering.AVG_AFFECTED_COMPONENTS,

    engineering.DAYS_SINCE_LAST_CHANGE,

    engineering.ENGINEERING_STABILITY

FROM BASE_PRODUCT p

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BOM_FEATURES_V bom

ON p.TOP_LEVEL_ITEM = bom.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ROUTING_FEATURES_V route

ON p.TOP_LEVEL_ITEM = route.ITEM_ID

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_SUPPLIER_FEATURES_V supplier

ON p.TOP_LEVEL_ITEM = supplier.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_MACHINE_FEATURES_V machine

ON p.TOP_LEVEL_ITEM = machine.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_PRODUCTION_FEATURES_V production

ON p.TOP_LEVEL_ITEM = production.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_INVENTORY_FEATURES_V inventory

ON p.TOP_LEVEL_ITEM = inventory.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_COMMODITY_FEATURES_V commodity

ON p.TOP_LEVEL_ITEM = commodity.TOP_LEVEL_ITEM

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ENGINEERING_FEATURES_V engineering

ON p.TOP_LEVEL_ITEM = engineering.ITEM_ID

)
SELECT *
FROM FEATURE_CONTEXT;

-- =====================================================
-- AI_CONTEXT_V
-- Purpose:
-- Consolidated manufacturing context for Snowflake Cortex.
--
-- This view is the bridge between the deterministic
-- manufacturing cost engine and the AI optimization layer.
--
-- It aggregates engineered features, manufacturing
-- dimensions, AI predictive scores, and baseline cost
-- calculations into a single product-level record.
--
-- Cortex AI functions should consume this view instead
-- of querying multiple transactional tables.
--
-- Consumed By
-- • AI_COMPLETE
-- • AI_EXTRACT
-- • Executive Summary
-- • Manufacturing Advisor
-- • Scenario Comparison
-- • Explainable AI
-- • AI Copilot
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.AI_CONTEXT_V
AS

SELECT

    fc.*,

    ------------------------------------------------------
    -- COST DISTRIBUTION KPIs
    ------------------------------------------------------

    ROUND(
        (fc.TOTAL_MATERIAL_COST / NULLIF(fc.TOTAL_COST,0))*100,
        2
    ) AS MATERIAL_COST_PERCENT,

    ROUND(
        (fc.LABOR_COST / NULLIF(fc.TOTAL_COST,0))*100,
        2
    ) AS LABOR_COST_PERCENT,

    ROUND(
        (fc.MACHINE_COST / NULLIF(fc.TOTAL_COST,0))*100,
        2
    ) AS MACHINE_COST_PERCENT,

    ROUND(
        fc.LABOR_COST /
        NULLIF(fc.TOTAL_MATERIAL_COST,0),
        3
    ) AS LABOR_TO_MATERIAL_RATIO,

    ROUND(
        fc.MACHINE_COST /
        NULLIF(fc.TOTAL_MATERIAL_COST,0),
        3
    ) AS MACHINE_TO_MATERIAL_RATIO,

    ------------------------------------------------------
    -- BUSINESS METRICS
    ------------------------------------------------------

    ROUND(
        fc.TOTAL_COST /
        NULLIF(fc.COMPONENT_COUNT,0),
        2
    ) AS COST_PER_COMPONENT,

    ROUND(
        fc.LABOR_COST /
        NULLIF(fc.TOTAL_OPERATIONS,0),
        2
    ) AS LABOR_COST_PER_OPERATION,

    ROUND(
        fc.MACHINE_COST /
        NULLIF(fc.TOTAL_OPERATIONS,0),
        2
    ) AS MACHINE_COST_PER_OPERATION,

    ROUND(
        fc.TOTAL_MATERIAL_COST /
        NULLIF(fc.TOTAL_COMPONENT_QTY,0),
        2
    ) AS AVG_COMPONENT_COST,

    ROUND(
        1 - COALESCE(fc.SUPPLIER_CONCENTRATION,0),
        3
    ) AS SUPPLIER_DIVERSIFICATION_INDEX,

    ROUND(
        fc.WEIGHTED_YIELD *
        (1 - fc.WEIGHTED_SCRAP_RATIO),
        3
    ) AS PRODUCTION_EFFICIENCY,

    ------------------------------------------------------
    -- BUSINESS FLAGS
    ------------------------------------------------------

    CASE
        WHEN fc.AVG_BRANCH_FACTOR > 3
          OR fc.ASSEMBLY_DENSITY > 4
        THEN TRUE
        ELSE FALSE
    END AS HIGH_BOM_COMPLEXITY_FLAG,

    CASE
        WHEN fc.AVG_SUPPLIER_QUALITY < 80
          OR fc.SUPPLIER_CONCENTRATION > 0.70
        THEN TRUE
        ELSE FALSE
    END AS HIGH_SUPPLIER_RISK_FLAG,

    CASE
        WHEN fc.AVG_UTILIZATION > 85
          OR fc.AVG_MACHINE_HEALTH < 70
        THEN TRUE
        ELSE FALSE
    END AS HIGH_MACHINE_STRAIN_FLAG,

    CASE
        WHEN fc.LOW_STOCK_RATIO > 0.30
        THEN TRUE
        ELSE FALSE
    END AS LOW_INVENTORY_FLAG,

    CASE
        WHEN fc.WEIGHTED_PRICE_VOLATILITY > 15
        THEN TRUE
        ELSE FALSE
    END AS HIGH_COMMODITY_VOLATILITY_FLAG,

    CASE
        WHEN fc.ENGINEERING_STABILITY < 50
        THEN TRUE
        ELSE FALSE
    END AS ENGINEERING_CHANGE_RISK_FLAG,

    ------------------------------------------------------
    -- AI PLACEHOLDERS
    ------------------------------------------------------

    COALESCE(css.CSS,0) AS CSS,

    COALESCE(pf.FMIS_SCORE,0) AS FMIS,

    COALESCE(pf.FORECAST_MULTIPLIER,1.0) AS FORECAST_MULTIPLIER,

    COALESCE(tds.TDS,1.0) AS TDS,

    CAST(NULL AS FLOAT) AS BMCS,

    CAST(NULL AS STRING) AS AI_RISK_LEVEL,

    CAST(NULL AS NUMBER) AS AI_RECOMMENDATION_COUNT

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FEATURE_CONTEXT_V fc

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_RESULTS_V css
ON fc.TOP_LEVEL_ITEM = css.TOP_LEVEL_ITEM
AND fc.REVISION = css.REVISION

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TDS_RESULTS_V tds
ON fc.TOP_LEVEL_ITEM = tds.TOP_LEVEL_ITEM
AND fc.REVISION = tds.REVISION

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_FMIS_FEATURES_V pf
ON fc.TOP_LEVEL_ITEM = pf.TOP_LEVEL_ITEM;

-- =====================================================
-- CSS_RESULTS_V
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_RESULTS_V
AS

SELECT

    TOP_LEVEL_ITEM,

    REVISION,

    TOTAL_COST,

    COMPONENT_COUNT,

    AVG_SUPPLIER_QUALITY,

    AVG_MACHINE_HEALTH,

    AVG_UTILIZATION,

    CHANGE_COUNT,

    ENGINEERING_STABILITY,

    PREDICTION:class::INTEGER
        AS HIGH_SCRAP_PREDICTION,

    ROUND(
        PREDICTION:probability:"1"::FLOAT * 100,
        2
    ) AS CSS,

    CASE

        WHEN PREDICTION:probability:"1"::FLOAT < 0.30
            THEN 'LOW'

        WHEN PREDICTION:probability:"1"::FLOAT < 0.60
            THEN 'MEDIUM'

        WHEN PREDICTION:probability:"1"::FLOAT < 0.80
            THEN 'HIGH'

        ELSE 'CRITICAL'

    END AS RISK_LEVEL

FROM
DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_PREDICTIONS;

// CSS_PREDICTION_INPUT_V
CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_PREDICTION_INPUT_V AS

SELECT
TOP_LEVEL_ITEM,
REVISION,
TOTAL_COST,
COMPONENT_COUNT,
AVG_SUPPLIER_QUALITY,
AVG_MACHINE_HEALTH,
AVG_UTILIZATION,
CHANGE_COUNT,
ENGINEERING_STABILITY
FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FEATURE_CONTEXT_V;

-- =====================================================
-- FMIS_TRAINING_DATA_V
-- =====================================================

CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FMIS_TRAINING_DATA_V
AS

SELECT

    COMMODITY_GROUP,

    PRICE_DATE,

    MARKET_PRICE,

    CURRENCY,

    LAG(MARKET_PRICE,1)
        OVER(
            PARTITION BY COMMODITY_GROUP
            ORDER BY PRICE_DATE
        ) AS PREVIOUS_PRICE,

    MARKET_PRICE
    -
    LAG(MARKET_PRICE,1)
        OVER(
            PARTITION BY COMMODITY_GROUP
            ORDER BY PRICE_DATE
        ) AS PRICE_CHANGE,

    ROUND(

        (
            MARKET_PRICE
            -
            LAG(MARKET_PRICE,1)
            OVER(
                PARTITION BY COMMODITY_GROUP
                ORDER BY PRICE_DATE
            )

        )

        /

        NULLIF(

            LAG(MARKET_PRICE,1)
            OVER(
                PARTITION BY COMMODITY_GROUP
                ORDER BY PRICE_DATE
            ),

            0

        )

        *100

    ,2)

    AS DAILY_CHANGE_PERCENT

FROM
DISCRETE_MFG_COST_MODEL.CORE_INPUT.COMMODITY_PRICE_HISTORY;

// FORCAST VIEW
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FMIS_FORECAST_DATA_V
AS
SELECT
    COMMODITY_GROUP,
    PRICE_DATE,
    MARKET_PRICE
FROM DISCRETE_MFG_COST_MODEL.CORE_ML.FMIS_TRAINING_DATA;

//PRODUCT_FMIS_FEATURES_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_FMIS_FEATURES_V
AS

SELECT

    b.PARENT_ID AS TOP_LEVEL_ITEM,

    -------------------------------------------------------
    -- Weighted Forecast Multiplier
    -------------------------------------------------------

    ROUND(
        SUM(f.FORECAST_MULTIPLIER * b.QUANTITY)
        /
        NULLIF(SUM(b.QUANTITY),0),
        3
    ) AS FORECAST_MULTIPLIER,

    -------------------------------------------------------
    -- Weighted FMIS Score
    -------------------------------------------------------

    ROUND(
        SUM(f.FMIS_SCORE * b.QUANTITY)
        /
        NULLIF(SUM(b.QUANTITY),0),
        2
    ) AS FMIS_SCORE,

    -------------------------------------------------------
    -- Highest Material Outlook
    -------------------------------------------------------

    MAX(f.MATERIAL_OUTLOOK) AS MATERIAL_OUTLOOK

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE b

JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER i
ON b.COMPONENT_ID = i.ITEM_ID

JOIN DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.FMIS_RESULTS_V f
ON i.COMMODITY_GROUP = f.COMMODITY_GROUP

GROUP BY
b.PARENT_ID;

// FMIS_RESULTS_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.FMIS_RESULTS_V
AS
WITH CURRENT_PRICE AS (
SELECT
COMMODITY_GROUP,
MAX(PRICE_DATE) AS LAST_DATE
FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.COMMODITY_PRICE_HISTORY
GROUP BY COMMODITY_GROUP
),
LATEST AS (
SELECT
c.COMMODITY_GROUP,
p.MARKET_PRICE AS CURRENT_PRICE
FROM CURRENT_PRICE c
JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.COMMODITY_PRICE_HISTORY p
ON c.COMMODITY_GROUP = p.COMMODITY_GROUP
AND c.LAST_DATE = p.PRICE_DATE
),
FORECAST_30 AS (
SELECT
SERIES AS COMMODITY_GROUP,
MAX(TS) AS FORECAST_DATE,
MAX(FORECAST) AS FORECAST_PRICE
FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.FMIS_FORECAST
GROUP BY SERIES
)
SELECT
    f.COMMODITY_GROUP,

    l.CURRENT_PRICE,

    f.FORECAST_PRICE,

    ---------------------------------------------------------
    -- BUSINESS OUTPUT
    ---------------------------------------------------------

    ROUND(
        f.FORECAST_PRICE / l.CURRENT_PRICE,
        3
    ) AS FORECAST_MULTIPLIER,

    ---------------------------------------------------------
    -- AI SCORE (0-100)
    ---------------------------------------------------------

    ROUND(
        LEAST(
            ABS(
                (
                    (f.FORECAST_PRICE - l.CURRENT_PRICE)
                    / l.CURRENT_PRICE
                ) * 100
            ) * 5,
            100
        ),
        2
    ) AS FMIS_SCORE,

    ---------------------------------------------------------
    -- BUSINESS LABEL
    ---------------------------------------------------------

    CASE
        WHEN f.FORECAST_PRICE/l.CURRENT_PRICE <0.95
            THEN 'PRICE_DECREASE'

        WHEN f.FORECAST_PRICE/l.CURRENT_PRICE<=1.05
            THEN 'STABLE'

        WHEN f.FORECAST_PRICE/l.CURRENT_PRICE<=1.15
            THEN 'MODERATE_INCREASE'

        ELSE 'HIGH_INCREASE'
    END AS MATERIAL_OUTLOOK

FROM FORECAST_30 f

JOIN LATEST l
ON f.COMMODITY_GROUP=l.COMMODITY_GROUP;

// TDS_TRAINING_DATA_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.TDS_TRAINING_DATA_V AS

SELECT

    TOP_LEVEL_ITEM,

    REVISION,

    COMPONENT_COUNT,
    ASSEMBLY_COUNT,
    BOM_RELATIONSHIPS,
    AVG_BRANCH_FACTOR,
    ASSEMBLY_DENSITY,

    TOTAL_MATERIAL_COST,
    LABOR_COST,
    MACHINE_COST,
    TOTAL_COST,

    TOTAL_OPERATIONS,
    TOTAL_PROCESS_TIME,
    AVG_SETUP,
    AVG_RUN,

    AVG_MACHINE_HEALTH,
    AVG_UTILIZATION,
    AVG_BREAKDOWNS,
    WEIGHTED_RUNTIME,

    CHANGE_COUNT,
    ENGINEERING_STABILITY,

    WEIGHTED_SCRAP_RATIO,
    WEIGHTED_YIELD,

    WEIGHTED_PRICE_VOLATILITY,

    ROUND(

        LEAST(

            3.5,

            GREATEST(

                1.0,

                (

                    -------------------------------------------------
                    -- Machine Stress (40%)
                    -------------------------------------------------

                    (

                        (COALESCE(AVG_UTILIZATION,50) / 100) * 0.20

                        +

                        ((100 - COALESCE(AVG_MACHINE_HEALTH,80)) / 100) * 0.15

                        +

                        (LEAST(COALESCE(AVG_BREAKDOWNS,0),10) / 10) * 0.05

                    )

                    +

                    -------------------------------------------------
                    -- Manufacturing Complexity (25%)
                    -------------------------------------------------

                    (

                        (LEAST(COALESCE(ASSEMBLY_DENSITY,1),5) / 5) * 0.15

                        +

                        (LEAST(COALESCE(AVG_BRANCH_FACTOR,1),5) / 5) * 0.10

                    )

                    +

                    -------------------------------------------------
                    -- Production Load (15%)
                    -------------------------------------------------

                    (

                        (LEAST(COALESCE(WEIGHTED_RUNTIME,0),40) / 40) * 0.10

                        +

                        (LEAST(COALESCE(TOTAL_PROCESS_TIME,0),20) / 20) * 0.05

                    )

                    +

                    -------------------------------------------------
                    -- Engineering (10%)
                    -------------------------------------------------

                    (

                        ((100 - COALESCE(ENGINEERING_STABILITY,100)) / 100) * 0.10

                    )

                    +

                    -------------------------------------------------
                    -- Quality (10%)
                    -------------------------------------------------

                    (

                        COALESCE(WEIGHTED_SCRAP_RATIO,0) * 0.05

                        +

                        (1 - COALESCE(WEIGHTED_YIELD,1)) * 0.05

                    )

                )

                * 2.5

                + 1.0

            )

        )

    ,2)

    AS TARGET_TDS

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.FEATURE_CONTEXT_V;

// TDS_RESULT_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TDS_RESULTS_V AS

SELECT

TOP_LEVEL_ITEM,

REVISION,

ROUND(TDS,2) AS TDS,

TOOLING_RISK,

MODEL_CONFIDENCE,

CASE

WHEN TDS < 25 THEN
'Normal machine wear expected.'

WHEN TDS < 50 THEN
'Moderate tooling wear. Preventive maintenance recommended.'

WHEN TDS < 75 THEN
'High tooling stress. Schedule maintenance inspection.'

ELSE
'Critical tooling degradation. Immediate maintenance required.'

END AS TDS_EXPLANATION

FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TDS_RESULTS;

//BMCS_EXTRACT_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BMCS_EXTRACT_V
AS

SELECT

    RFQ_ID,

    ITEM_ID,

    REVISION,

    SNOWFLAKE.CORTEX.AI_EXTRACT(
        RFQ_TEXT,
        ARRAY_CONSTRUCT(
            'dimensions',
            'tolerance',
            'material',
            'weight',
            'surface_finish',
            'coating',
            'compliance',
            'certification',
            'manufacturing_process',
            'assembly',
            'packaging',
            'delivery'
        )
    ) AS EXTRACTED_REQUIREMENTS

FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.CUSTOMER_RFQ;

// BMCS_CONTEXT_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BMCS_CONTEXT_V
AS

SELECT

    e.RFQ_ID,
    e.ITEM_ID,
    e.REVISION,
    e.EXTRACTED_REQUIREMENTS,

    -------------------------------------------------------
    -- Product
    -------------------------------------------------------

    a.ITEM_NAME,
    a.PRODUCT_FAMILY,
    a.COMMODITY_GROUP,

    -------------------------------------------------------
    -- Cost
    -------------------------------------------------------

    a.TOTAL_MATERIAL_COST,
    a.LABOR_COST,
    a.MACHINE_COST,
    a.TOTAL_COST,

    -------------------------------------------------------
    -- BOM
    -------------------------------------------------------

    a.COMPONENT_COUNT,
    a.ASSEMBLY_COUNT,
    a.AVG_BRANCH_FACTOR,

    -------------------------------------------------------
    -- Supplier
    -------------------------------------------------------

    a.AVG_SUPPLIER_QUALITY,

    -------------------------------------------------------
    -- Machine
    -------------------------------------------------------

    a.AVG_MACHINE_HEALTH,
    a.AVG_UTILIZATION,

    -------------------------------------------------------
    -- Engineering
    -------------------------------------------------------

    a.ENGINEERING_STABILITY,

    -------------------------------------------------------
    -- AI Scores
    -------------------------------------------------------

    a.CSS,
    a.FMIS,
    a.TDS

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BMCS_EXTRACT_V e

JOIN DISCRETE_MFG_COST_MODEL.CORE_FEATURES.AI_CONTEXT_V a
ON e.ITEM_ID = a.TOP_LEVEL_ITEM
AND e.REVISION = a.REVISION;

//BMCS_AI_RESPONSE_V
CREATE OR REPLACE VIEW DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.BMCS_AI_RESPONSE_V AS

SELECT

    RFQ_ID,

    ITEM_ID,

    REVISION,

    SNOWFLAKE.CORTEX.AI_COMPLETE(
        'llama3.1-70b',
        CONCAT(

'You are a manufacturing engineer.

Return ONLY valid JSON.

{
"bmcs":0-100,
"match_status":"HIGH|MEDIUM|LOW",
"missing_requirements":"...",
"suggested_components":"...",
"review_required":true,
"summary":"..."
}

RFQ Requirements:
',

TO_JSON(EXTRACTED_REQUIREMENTS),

'

Item Name: ',
ITEM_NAME,

'

Product Family: ',
PRODUCT_FAMILY,

'

Commodity: ',
COMMODITY_GROUP,

'

Component Count: ',
TO_VARCHAR(COMPONENT_COUNT),

'

Assembly Count: ',
TO_VARCHAR(ASSEMBLY_COUNT),

'

Branch Factor: ',
TO_VARCHAR(AVG_BRANCH_FACTOR),

'

Material Cost: ',
TO_VARCHAR(TOTAL_MATERIAL_COST),

'

Labor Cost: ',
TO_VARCHAR(LABOR_COST),

'

Machine Cost: ',
TO_VARCHAR(MACHINE_COST),

'

Supplier Quality: ',
TO_VARCHAR(AVG_SUPPLIER_QUALITY),

'

Machine Health: ',
TO_VARCHAR(AVG_MACHINE_HEALTH),

'

Utilization: ',
TO_VARCHAR(AVG_UTILIZATION),

'

Engineering Stability: ',
TO_VARCHAR(ENGINEERING_STABILITY),

'

Tooling Degradation Score: ',
TO_VARCHAR(TDS)

)
    ) AS BMCS_RESPONSE

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.BMCS_CONTEXT_V;

//AI_DECISION_ENGINE_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.AI_DECISION_ENGINE_V
AS

SELECT

    c.TOP_LEVEL_ITEM,

    c.REVISION,

    c.ITEM_NAME,

    c.PRODUCT_FAMILY,

    c.TOTAL_COST,

    c.CSS,

    c.FMIS,

    c.TDS,

    b.RFQ_ID,

    b.BMCS,

    b.MATCH_STATUS,

    b.MISSING_REQUIREMENTS,

    b.SUGGESTED_COMPONENTS,

    b.REVIEW_REQUIRED,

    b.AI_SUMMARY,

    --------------------------------------------------
    -- OVERALL AI RISK SCORE
    --------------------------------------------------

    ROUND(

        (
            COALESCE(c.CSS,50) * 0.35 +

            COALESCE(c.FMIS,50) * 0.20 +

            COALESCE(c.TDS,50) * 0.20 +

            (100-COALESCE(b.BMCS,50)) * 0.25

        ),

        2

    ) AS AI_RISK_SCORE,

    --------------------------------------------------
    -- RISK LEVEL
    --------------------------------------------------

    CASE

        WHEN (

            COALESCE(c.CSS,50)*0.35+

            COALESCE(c.FMIS,50)*0.20+

            COALESCE(c.TDS,50) * 0.20+

            (100-COALESCE(b.BMCS,50))*0.25

        ) <40

        THEN 'LOW'

        WHEN (

            COALESCE(c.CSS,50)*0.35+

            COALESCE(c.FMIS,50)*0.20+

            COALESCE(c.TDS,50) * 0.20+

            (100-COALESCE(b.BMCS,50))*0.25

        ) <70

        THEN 'MEDIUM'

        ELSE 'HIGH'

    END AS AI_RISK_LEVEL,

    --------------------------------------------------
    -- RISK ADJUSTED QUOTE
    --------------------------------------------------

    ROUND(

        c.TOTAL_COST *

        (

            1+

            (

                (
                    COALESCE(c.CSS,50)*0.35+

                    COALESCE(c.FMIS,50)*0.20+

                    COALESCE(c.TDS,50) * 0.20+

                    (100-COALESCE(b.BMCS,50))*0.25

                )/100

            )*0.15

        ),

        2

    ) AS RECOMMENDED_QUOTE

FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.AI_CONTEXT_V c

LEFT JOIN DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.BMCS_RESULTS b
ON c.TOP_LEVEL_ITEM = b.ITEM_ID
AND c.REVISION = b.REVISION;

//AI_EXECUTIVE_SUMMARY_V
CREATE OR REPLACE VIEW
DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.AI_EXECUTIVE_SUMMARY_V
AS

SELECT

TOP_LEVEL_ITEM,

REVISION,

RFQ_ID,

TOTAL_COST,

RECOMMENDED_QUOTE,

AI_RISK_SCORE,

AI_RISK_LEVEL,

ROUND(
(
RECOMMENDED_QUOTE-TOTAL_COST)
/TOTAL_COST*100,
2
) AS QUOTE_INCREASE_PERCENT,

CASE

WHEN AI_RISK_SCORE<40
THEN 'APPROVE'

WHEN AI_RISK_SCORE<70
THEN 'PROCEED WITH CAUTION'

ELSE 'MANAGEMENT REVIEW'

END AS AI_DECISION

FROM
CORE_OUTPUT.AI_DECISION_ENGINE_V;

-- =====================================================
-- VALIDATION QUERIES
-- =====================================================

SELECT
TOP_LEVEL_ITEM,
REVISION,
CSS,
FMIS,
TDS,
BMCS,
AI_RISK_SCORE
FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.AI_DECISION_ENGINE_V;