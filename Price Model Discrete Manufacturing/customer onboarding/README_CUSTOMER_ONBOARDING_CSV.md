# Customer Onboarding CSV Pack

## Purpose

This pack supports the governed Customer Onboarding pipeline in the Pricing Intelligence Platform:

```text
Customer Onboarding
        |
        v
Choose Platform Mode
        |
  +-----+------------+
  |                  |
  v                  v
Integrated       Standalone
  |                  |
Receive Data      Upload CSV/XLSX
  |                  |
  +--------+---------+
           |
           v
 Data Validation Engine
           |
           v
 AI Data Quality Review
           |
           v
 Column Mapping
           |
           v
 Snowflake Staging Tables
           |
           v
 Production Promotion
           |
           v
 Ready for Pricing Engine
```

This README explains every CSV in the pack, how to load it, how to verify each pipeline stage, and how to troubleshoot common failures.

---

## Important Data Warning

Files containing `demo` in the filename contain **synthetic test data only**.

Do not use demo values for:

- Production pricing decisions
- Customer quotations
- Margin analysis
- Contract decisions
- Financial reporting
- Executive recommendations

For production use, copy `02_standalone_pricing_inputs_template.csv`, add approved real source data, and retain the required column structure.

---

## Pack Contents

### 1. `01_standalone_pricing_inputs_demo.csv`

**Purpose:** Directly loadable functional-test file using canonical target headers.

**Use it to test:**

- CSV upload
- Data preview
- Automatic one-to-one column mapping
- Deterministic validation
- AI data-quality review
- Snowflake staging
- Production promotion
- Workspace readiness
- Pricing Engine handoff

**Important:** The file uses IDs such as `CUST-DEMO-001` and `SKU-DEMO-001`. Those values may not exist in your current `CUSTOMER_AGREEMENTS` and `CALCULATED_STANDARD_COSTS` tables. Upload and promotion can succeed, but automatic Price Engine preselection may display a warning.

---

### 2. `02_standalone_pricing_inputs_template.csv`

**Purpose:** Header-only template for approved real customer data.

**Use it for:**

- Production preparation
- End-to-end Price Engine testing with existing Snowflake customer and SKU values
- Controlled onboarding of customer-product pricing inputs

**Before upload:**

1. Add at least one data row.
2. Use real `CUSTOMER_ID` values from `CORE_INPUT.CUSTOMER_AGREEMENTS`.
3. Use real `SKU` values from `CORE_INPUT.CALCULATED_STANDARD_COSTS`.
4. Use an approved real product cost.
5. Confirm the currency and effective date.

An empty template is intentionally rejected by the uploader.

---

### 3. `03_alias_column_mapping_demo.csv`

**Purpose:** Tests automatic and manual mapping when source headers differ from platform target fields.

Expected mappings:

| Source Column | Target Column |
|---|---|
| `CustomerCode` | `CUSTOMER_ID` |
| `CustomerName` | `CUSTOMER_NAME` |
| `MaterialNumber` | `SKU` |
| `Description` | `PRODUCT_NAME` |
| `Category` | `PRODUCT_CATEGORY` |
| `PlantName` | `PLANT` |
| `StandardCost` | `PRODUCT_COST` |
| `NetPrice` | `SELLING_PRICE` |
| `MarginPct` | `TARGET_MARGIN` |
| `DiscountPct` | `DISCOUNT_PERCENT` |
| `FreightCost` | `FREIGHT` |
| `PackagingCost` | `PACKAGING` |
| `TaxPct` | `TAX_PERCENT` |
| `Surcharge` | `OTHER_CHARGES` |
| `CurrencyCode` | `CURRENCY` |
| `CustomerGroup` | `CUSTOMER_SEGMENT` |
| `Channel` | `SALES_CHANNEL` |
| `EffectiveFrom` | `EFFECTIVE_DATE` |

Use this file to verify that mapping suggestions remain advisory and require user confirmation.

---

### 4. `04_customer_master_reference_demo.csv`

**Purpose:** Reference/preparation file for customer master attributes.

It contains:

```text
CUSTOMER_ID
CUSTOMER_NAME
CUSTOMER_SEGMENT
CURRENCY
SALES_CHANNEL
```

The current combined onboarding pipeline does **not** independently promote a customer-only file. Use this file as a preparation reference, or merge its fields into the combined canonical pricing-input template.

Do not upload it through the current combined pipeline unless you extend the application with entity-specific routing for customer-master batches.

---

### 5. `05_product_master_reference_demo.csv`

**Purpose:** Reference/preparation file for product information.

It contains:

```text
SKU
PRODUCT_NAME
PRODUCT_CATEGORY
PLANT
PRODUCT_COST
CURRENCY
```

The current combined onboarding pipeline does **not** independently promote a product-only file. Merge these fields into the canonical pricing-input template for the current implementation.

Do not upload it through the current combined pipeline unless you add a separate product-master ingestion route.

---

### 6. `06_onboarding_data_dictionary.csv`

**Purpose:** Defines the supported target fields, required status, expected formats, and business notes.

Use it during:

- Source-system preparation
- Mapping review
- Validation troubleshooting
- Business-user training
- Integration-team handoff

---

## Canonical Combined File Structure

The current pipeline expects one combined customer-product pricing file.

| Column | Required | Expected value |
|---|---:|---|
| `CUSTOMER_ID` | Yes | Text identifier |
| `CUSTOMER_NAME` | No | Customer display name |
| `SKU` | Yes | Text product identifier |
| `PRODUCT_NAME` | No | Product description |
| `PRODUCT_CATEGORY` | No | Product family/category |
| `PLANT` | No | Plant identifier or name |
| `PRODUCT_COST` | Yes | Number greater than or equal to zero |
| `SELLING_PRICE` | No | Number greater than or equal to zero |
| `TARGET_MARGIN` | No | Percentage from 0 to 100 |
| `DISCOUNT_PERCENT` | No | Percentage from 0 to 100 |
| `FREIGHT` | No | Number greater than or equal to zero |
| `PACKAGING` | No | Number greater than or equal to zero |
| `TAX_PERCENT` | No | Percentage from 0 to 100 |
| `OTHER_CHARGES` | No | Number greater than or equal to zero |
| `CURRENCY` | Yes | `INR`, `USD`, `EUR`, `GBP`, or `JPY` |
| `CUSTOMER_SEGMENT` | No | Business segment |
| `SALES_CHANNEL` | No | Direct, Distributor, OEM, Online, etc. |
| `EFFECTIVE_DATE` | No | ISO date: `YYYY-MM-DD` |

---

# Prerequisites

## Application prerequisites

Confirm the application contains:

- Customer Onboarding as the first navigation tab
- Standalone CSV/XLSX uploader
- Column Mapping view
- Deterministic Data Validation view
- AI Data Quality view
- Snowflake Staging view
- Production Promotion view
- Workspace Summary
- Governed Price Engine handoff

## Python package prerequisite

CSV upload uses pandas directly.

XLSX upload additionally requires:

```text
openpyxl
```

## Snowflake object prerequisites

The following objects must exist:

```text
PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
PRICING_ENGINE_DB.CORE_INTERNAL.DATA_VALIDATION_RESULTS
PRICING_ENGINE_DB.CORE_INTERNAL.COLUMN_MAPPING_CONFIG
PRICING_ENGINE_DB.CORE_INTERNAL.DATA_PROMOTION_LOG
PRICING_ENGINE_DB.CORE_STAGING.STG_ONBOARDING_RAW
PRICING_ENGINE_DB.CORE_STAGING.STG_PRICING_INPUTS
PRICING_ENGINE_DB.CORE_INPUT.ONBOARDED_PRICING_INPUTS
```

The application role must have the required `SELECT`, `INSERT`, and `UPDATE` permissions. `DELETE` is also required by the supplied mapping and validation refresh implementation.

## Verify object availability

Run:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME
FROM PRICING_ENGINE_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('CORE_INTERNAL', 'CORE_STAGING', 'CORE_INPUT')
  AND TABLE_NAME IN (
      'ONBOARDING_BATCHES',
      'DATA_VALIDATION_RESULTS',
      'COLUMN_MAPPING_CONFIG',
      'DATA_PROMOTION_LOG',
      'STG_ONBOARDING_RAW',
      'STG_PRICING_INPUTS',
      'ONBOARDED_PRICING_INPUTS'
  )
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

Expected result: one row for every required object listed above.

---

# End-to-End Loading Steps

## Step 1: Select Customer Onboarding

Open:

```text
🏢 Customer Onboarding
```

## Step 2: Select Standalone Mode

Choose:

```text
Standalone Pricing Platform
```

Then click:

```text
Continue with Standalone Mode
```

The CSV files in this pack are intended for Standalone Mode.

Integrated Mode must receive a real external Cost Model payload or shared object. Do not upload demo manufacturing costs as a substitute for an unavailable integration.

## Step 3: Capture Customer Information

Open:

```text
🧾 Customer Info
```

Complete the customer and workspace fields. At minimum, provide:

```text
Customer Name
Customer ID
Currency
Workspace Name
```

The customer information identifies the governed workspace. For the cleanest test, align the selected workspace customer with the customer in the uploaded file.

## Step 4: Initialize Workspace

Open:

```text
🗂️ Workspace
```

Click:

```text
🚀 Initialize Workspace
```

Verify the UI shows:

```text
Workspace Status: INITIALIZED
Workspace ID: WS-...
Mode: STANDALONE
```

Do not continue without a Workspace ID.

### Snowflake verification

```sql
SELECT *
FROM PRICING_ENGINE_DB.CORE_INTERNAL.CUSTOMER_WORKSPACES
WHERE WORKSPACE_ID = '<workspace id>';
```

Expected:

- One workspace row
- `ONBOARDING_MODE = 'STANDALONE'`
- `WORKSPACE_STATUS = 'INITIALIZED'`
- Correct `CREATED_BY`

## Step 5: Validate Snowflake Connectivity

Open:

```text
❄️ Snowflake Validation
```

Verify the required customer, product, pricing, workspace, staging, and production objects are reachable.

Cortex may show a warning if unavailable. AI unavailability must not prevent deterministic validation, staging, or promotion.

## Step 6: Upload the CSV

Open:

```text
📥 Data Source
```

Recommended first test:

```text
01_standalone_pricing_inputs_demo.csv
```

Select the file and click:

```text
Load File for Review
```

Expected UI results:

- File name displayed
- Source type `CSV`
- Row count displayed
- Column count displayed
- Generated Batch ID such as `BAT-...`

### Batch verification

```sql
SELECT
    BATCH_ID,
    WORKSPACE_ID,
    SOURCE_MODE,
    SOURCE_TYPE,
    SOURCE_NAME,
    SOURCE_HASH,
    ROW_COUNT,
    COLUMN_COUNT,
    BATCH_STATUS,
    CREATED_BY,
    CREATED_AT
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE BATCH_ID = '<batch id>';
```

Expected:

```text
SOURCE_MODE = STANDALONE
SOURCE_TYPE = CSV
BATCH_STATUS = UPLOADED
```

## Step 7: Review Data Preview

Open:

```text
👁️ Data Preview
```

Verify:

- Header row is correct
- The first data row is not used as a header
- Numeric fields are readable
- Dates use `YYYY-MM-DD`
- Currency values are expected
- No unexpected blank columns exist

Expand `Detected Columns` to review inferred data types, null counts, and non-null counts.

## Step 8: Confirm Column Mapping

Open:

```text
🔀 Column Mapping
```

For the canonical demo or production template, map each column to the same-named target.

The required targets are:

```text
CUSTOMER_ID
SKU
PRODUCT_COST
CURRENCY
```

Map unsupported or intentionally ignored source fields to:

```text
DO_NOT_IMPORT
```

Click:

```text
Confirm Column Mapping
```

### Mapping verification

```sql
SELECT
    SOURCE_COLUMN,
    TARGET_COLUMN,
    SOURCE_DATA_TYPE,
    TARGET_DATA_TYPE,
    IS_REQUIRED,
    MAPPING_STATUS,
    CREATED_BY
FROM PRICING_ENGINE_DB.CORE_INTERNAL.COLUMN_MAPPING_CONFIG
WHERE BATCH_ID = '<batch id>'
ORDER BY SOURCE_COLUMN;
```

Expected:

```text
MAPPING_STATUS = CONFIRMED
```

Verify that every required target appears once. No target should be mapped from multiple source fields unless the application explicitly supports it.

## Step 9: Run Deterministic Validation

Open:

```text
🛡️ Data Validation
```

Click:

```text
Run Deterministic Validation
```

Review:

```text
Total Rows
Valid Rows
Invalid Rows
Warning Rows
Validation Score
```

Eligible statuses:

```text
VALID
VALID_WITH_WARNINGS
```

Blocking status:

```text
INVALID
```

Production promotion requires:

```text
Invalid Rows = 0
```

### Validation verification

```sql
SELECT
    SEVERITY,
    RULE_CODE,
    COUNT(*) AS FINDING_COUNT
FROM PRICING_ENGINE_DB.CORE_INTERNAL.DATA_VALIDATION_RESULTS
WHERE BATCH_ID = '<batch id>'
GROUP BY SEVERITY, RULE_CODE
ORDER BY SEVERITY, RULE_CODE;
```

Check batch summary:

```sql
SELECT
    BATCH_STATUS,
    VALID_ROWS,
    INVALID_ROWS,
    WARNING_ROWS,
    VALIDATION_SCORE
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE BATCH_ID = '<batch id>';
```

Expected for a clean file:

```text
BATCH_STATUS = VALIDATED
INVALID_ROWS = 0
```

Typical blocking errors:

- Required mapping missing
- Required value missing
- Negative cost or charge
- Percentage outside 0 to 100
- Multiple input columns mapped to one target

Typical warnings:

- Unsupported currency
- Potential duplicate business record

## Step 10: Run AI Data Quality Review

Open:

```text
🧠 AI Data Quality
```

Click:

```text
Run AI Data Quality Review
```

AI may identify:

- Unusual price-cost relationships
- Potential unit mismatch
- Currency concerns
- Suspicious distributions
- Mapping concerns
- Missing information
- Suggested operator questions

AI is advisory only. It does not modify rows, mappings, validation status, staging data, or production data.

### AI status verification

```sql
SELECT AI_REVIEW_STATUS
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE BATCH_ID = '<batch id>';
```

Expected when Cortex responds:

```text
COMPLETED
```

Expected when Cortex is unavailable:

```text
UNAVAILABLE
```

An unavailable result must not block an otherwise valid deterministic workflow.

## Step 11: Write to Snowflake Staging

Open:

```text
❄️ Snowflake Staging
```

Click:

```text
Write Valid Rows to Snowflake Staging
```

Only rows with these statuses are eligible:

```text
VALID
VALID_WITH_WARNINGS
```

### Staging verification

```sql
SELECT
    BATCH_ID,
    WORKSPACE_ID,
    CUSTOMER_ID,
    SKU,
    PRODUCT_COST,
    CURRENCY,
    VALIDATION_STATUS,
    SOURCE_ROW_NUMBER,
    CREATED_BY,
    CREATED_AT
FROM PRICING_ENGINE_DB.CORE_STAGING.STG_PRICING_INPUTS
WHERE BATCH_ID = '<batch id>'
ORDER BY SOURCE_ROW_NUMBER;
```

Compare staged count with valid count:

```sql
SELECT
    b.VALID_ROWS,
    COUNT(s.STAGING_ID) AS STAGED_ROWS
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES b
LEFT JOIN PRICING_ENGINE_DB.CORE_STAGING.STG_PRICING_INPUTS s
  ON b.BATCH_ID = s.BATCH_ID
WHERE b.BATCH_ID = '<batch id>'
GROUP BY b.VALID_ROWS;
```

Expected:

```text
STAGED_ROWS = VALID_ROWS
```

Check batch status:

```sql
SELECT BATCH_STATUS, STAGING_STATUS
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE BATCH_ID = '<batch id>';
```

Expected:

```text
BATCH_STATUS = STAGED
STAGING_STATUS = COMPLETED
```

## Step 12: Promote to Production

Open:

```text
🚀 Production Promotion
```

Verify every prerequisite displays:

```text
✅ Ready
```

Click:

```text
Promote Staged Data to Production
```

The operation must complete as a Snowflake transaction. The app must not display success if the transaction fails.

### Production verification

```sql
SELECT
    PRICING_INPUT_ID,
    WORKSPACE_ID,
    BATCH_ID,
    CUSTOMER_ID,
    SKU,
    PRODUCT_COST,
    SELLING_PRICE,
    TARGET_MARGIN,
    DISCOUNT_PERCENT,
    CURRENCY,
    SOURCE_MODE,
    SOURCE_SYSTEM,
    IS_ACTIVE,
    CREATED_BY,
    CREATED_AT
FROM PRICING_ENGINE_DB.CORE_INPUT.ONBOARDED_PRICING_INPUTS
WHERE BATCH_ID = '<batch id>'
ORDER BY CUSTOMER_ID, SKU;
```

Expected:

- One production row for each staged valid row
- `IS_ACTIVE = TRUE`
- Correct workspace and batch IDs
- `SOURCE_MODE = STANDALONE`

### Promotion-log verification

```sql
SELECT
    PROMOTION_ID,
    PROMOTION_STATUS,
    PROMOTED_ROWS,
    REJECTED_ROWS,
    PROMOTED_BY,
    STARTED_AT,
    COMPLETED_AT,
    ERROR_MESSAGE
FROM PRICING_ENGINE_DB.CORE_INTERNAL.DATA_PROMOTION_LOG
WHERE BATCH_ID = '<batch id>'
ORDER BY STARTED_AT DESC;
```

Expected:

```text
PROMOTION_STATUS = COMPLETED
PROMOTED_ROWS = staged valid rows
REJECTED_ROWS = 0
ERROR_MESSAGE = NULL
```

### Batch final-state verification

```sql
SELECT
    BATCH_STATUS,
    PROMOTION_STATUS,
    PROMOTED_AT,
    ERROR_MESSAGE
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE BATCH_ID = '<batch id>';
```

Expected:

```text
BATCH_STATUS = PROMOTED
PROMOTION_STATUS = COMPLETED
```

### Workspace final-state verification

```sql
SELECT
    WORKSPACE_ID,
    WORKSPACE_STATUS,
    READINESS_SCORE,
    UPDATED_AT
FROM PRICING_ENGINE_DB.CORE_INTERNAL.CUSTOMER_WORKSPACES
WHERE WORKSPACE_ID = '<workspace id>';
```

Expected:

```text
WORKSPACE_STATUS = READY_FOR_PRICING
READINESS_SCORE = 100
```

## Step 13: Verify Workspace Summary

Open:

```text
✅ Workspace Summary
```

Expected UI state:

```text
Validation: VALID or VALID_WITH_WARNINGS
Production: Promoted
Readiness: 100%
Status: Ready for Pricing
```

Click:

```text
➡️ Proceed to Pricing Engine
```

## Step 14: Verify Price Engine Handoff

The application should navigate to:

```text
💰 Price Engine
```

Expected banner:

```text
Governed onboarding workspace <workspace id> loaded
Batch <batch id>
Customer <customer id>
SKU <sku>
```

The promoted onboarding input should be visible in the read-only expander.

### Customer and SKU preselection

Automatic preselection works only when:

- Uploaded `SKU` exists in `CORE_INPUT.CALCULATED_STANDARD_COSTS`
- Uploaded `CUSTOMER_ID` exists in `CORE_INPUT.CUSTOMER_AGREEMENTS`

Verify valid source values before creating a production CSV:

```sql
SELECT SKU, TOTAL_COST
FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
ORDER BY SKU;
```

```sql
SELECT DISTINCT CUSTOMER_ID
FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
WHERE CUSTOMER_ID IS NOT NULL
ORDER BY CUSTOMER_ID;
```

If demo identifiers are not present, the app should warn rather than force an invalid Streamlit selectbox value.

---

# How to Use Each CSV

## Test A: Canonical happy-path test

Use:

```text
01_standalone_pricing_inputs_demo.csv
```

Expected behavior:

1. Upload succeeds.
2. Canonical fields map directly.
3. Deterministic validation runs.
4. Valid records can be staged.
5. Production promotion can complete.
6. Price Engine may warn that demo customer/SKU values do not exist in the existing operational tables.

## Test B: Real end-to-end Price Engine test

Use:

```text
02_standalone_pricing_inputs_template.csv
```

Procedure:

1. Copy the template.
2. Add real rows.
3. Use an existing Snowflake `CUSTOMER_ID`.
4. Use an existing Snowflake `SKU`.
5. Enter approved production values.
6. Upload the completed copy.
7. Complete mapping, validation, staging, and promotion.
8. Proceed to Price Engine.
9. Verify customer and SKU are preselected.

## Test C: Mapping test

Use:

```text
03_alias_column_mapping_demo.csv
```

Expected behavior:

1. Upload succeeds.
2. Alias-based suggestions appear.
3. User confirms mappings.
4. Required fields are recognized.
5. Normalized validation uses canonical fields.

## Test D: Customer reference preparation

Use:

```text
04_customer_master_reference_demo.csv
```

Do not load it through the combined production pipeline. Use it as a preparation reference or merge its customer fields into the combined template.

## Test E: Product reference preparation

Use:

```text
05_product_master_reference_demo.csv
```

Do not load it through the combined production pipeline. Use it as a preparation reference or merge its product fields into the combined template.

## Test F: Schema and mapping reference

Use:

```text
06_onboarding_data_dictionary.csv
```

Use it to verify required columns, formats, and business expectations before preparing a source file.

---

# Post-Load Reconciliation Queries

## Single-query batch reconciliation

```sql
SELECT
    b.BATCH_ID,
    b.WORKSPACE_ID,
    b.ROW_COUNT AS SOURCE_ROWS,
    b.VALID_ROWS,
    b.INVALID_ROWS,
    b.WARNING_ROWS,
    COUNT(DISTINCT s.STAGING_ID) AS STAGED_ROWS,
    COUNT(DISTINCT p.PRICING_INPUT_ID) AS PRODUCTION_ROWS,
    b.BATCH_STATUS,
    b.STAGING_STATUS,
    b.PROMOTION_STATUS
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES b
LEFT JOIN PRICING_ENGINE_DB.CORE_STAGING.STG_PRICING_INPUTS s
  ON b.BATCH_ID = s.BATCH_ID
LEFT JOIN PRICING_ENGINE_DB.CORE_INPUT.ONBOARDED_PRICING_INPUTS p
  ON b.BATCH_ID = p.BATCH_ID
WHERE b.BATCH_ID = '<batch id>'
GROUP BY
    b.BATCH_ID,
    b.WORKSPACE_ID,
    b.ROW_COUNT,
    b.VALID_ROWS,
    b.INVALID_ROWS,
    b.WARNING_ROWS,
    b.BATCH_STATUS,
    b.STAGING_STATUS,
    b.PROMOTION_STATUS;
```

Expected for a clean promoted batch:

```text
SOURCE_ROWS = VALID_ROWS
INVALID_ROWS = 0
STAGED_ROWS = VALID_ROWS
PRODUCTION_ROWS = STAGED_ROWS
BATCH_STATUS = PROMOTED
STAGING_STATUS = COMPLETED
PROMOTION_STATUS = COMPLETED
```

## Audit verification

```sql
SELECT
    EVENT_TYPE,
    EVENT_DETAIL,
    ACTOR,
    CREATED_AT
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_LOG
WHERE WORKSPACE_ID = '<workspace id>'
ORDER BY CREATED_AT;
```

Expected events may include:

```text
WORKSPACE_INIT
DATA_BATCH_CREATED
STAGING_COMPLETED
PRODUCTION_PROMOTION_COMPLETED
READY_FOR_PRICING
```

---

# Negative Tests

Run these with a copy of the template, not approved production data.

## Missing required Customer ID

Leave `CUSTOMER_ID` blank.

Expected:

```text
REQUIRED_VALUE_MISSING
Severity: ERROR
Promotion blocked
```

## Negative product cost

Set:

```text
PRODUCT_COST = -1
```

Expected:

```text
NEGATIVE_VALUE
Severity: ERROR
Promotion blocked
```

## Invalid percentage

Set:

```text
DISCOUNT_PERCENT = 150
```

Expected:

```text
PERCENT_OUT_OF_RANGE
Severity: ERROR
Promotion blocked
```

## Unsupported currency

Set:

```text
CURRENCY = ABC
```

Expected under the supplied validator:

```text
UNSUPPORTED_CURRENCY
Severity: WARNING
```

Review whether your organization wants unsupported currency to remain a warning or become a blocking error.

## Duplicate business row

Duplicate the same customer, SKU, and effective date.

Expected:

```text
POTENTIAL_DUPLICATE
Severity: WARNING
```

## Repeat promotion

Try promoting the same batch twice.

Expected:

```text
This onboarding batch has already been promoted.
Refresh to view the current workspace status.
```

---

# Troubleshooting

## File uploader rejects the template

Cause: the header-only template contains no data rows.

Fix: add at least one approved real row before uploading.

## XLSX cannot be read

Cause: `openpyxl` is missing from the Streamlit-in-Snowflake environment.

Fix: add the package to the application environment and redeploy.

## Confirm Mapping button is disabled

Cause: one or more required target fields are not mapped.

Required targets:

```text
CUSTOMER_ID
SKU
PRODUCT_COST
CURRENCY
```

## Validation is INVALID

Review `DATA_VALIDATION_RESULTS` and correct the source file or mapping. Do not bypass blocking validation errors.

## Staging button does not complete

Verify:

- Mapping is confirmed
- Validation status is `VALID` or `VALID_WITH_WARNINGS`
- Invalid row count is zero
- The app role can write to `CORE_STAGING.STG_PRICING_INPUTS`
- The batch was not already staged

## Promotion fails

Check:

```sql
SELECT *
FROM PRICING_ENGINE_DB.CORE_INTERNAL.DATA_PROMOTION_LOG
WHERE BATCH_ID = '<batch id>'
ORDER BY STARTED_AT DESC;
```

Also verify privileges on:

```text
CORE_INPUT.ONBOARDED_PRICING_INPUTS
CORE_INTERNAL.ONBOARDING_BATCHES
CORE_INTERNAL.CUSTOMER_WORKSPACES
CORE_INTERNAL.DATA_PROMOTION_LOG
```

The supplied function rolls back a failed transaction and must not show a false success message.

## Price Engine does not preselect the uploaded SKU

Cause: the uploaded SKU is absent from `CALCULATED_STANDARD_COSTS`.

Verify:

```sql
SELECT SKU
FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
WHERE SKU = '<uploaded sku>';
```

Use a real existing SKU in the production template, or extend the governed product-master onboarding flow before expecting new SKUs to appear in the existing Price Engine.

## Price Engine does not preselect the customer

Cause: the uploaded Customer ID is absent from `CUSTOMER_AGREEMENTS`.

Verify:

```sql
SELECT CUSTOMER_ID
FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
WHERE CUSTOMER_ID = '<uploaded customer id>';
```

Use an existing customer for the current handoff, or add a separately governed customer-master onboarding route.

## AI Data Quality Review is unavailable

The deterministic workflow remains usable. Check Cortex diagnostics, model availability, and role permissions. AI must never control promotion eligibility.

---

# Production Checklist

Before using a file for business pricing, confirm:

- [ ] Demo data has been removed.
- [ ] Customer IDs are approved and valid.
- [ ] SKUs are approved and valid.
- [ ] Product costs come from an authorized source.
- [ ] Currency is confirmed.
- [ ] Effective dates are confirmed.
- [ ] Required columns are mapped once.
- [ ] Invalid row count is zero.
- [ ] Warnings have been reviewed.
- [ ] AI review is treated as advisory only.
- [ ] Staged row count equals valid row count.
- [ ] Production row count equals staged row count.
- [ ] Promotion log status is `COMPLETED`.
- [ ] Workspace status is `READY_FOR_PRICING`.
- [ ] Price Engine displays the correct customer and SKU.
- [ ] Cost source is visible and approved.

---

# Cleanup of Demo Data

Only perform cleanup in a dedicated test environment and only for demo batches/workspaces you own.

First identify demo records:

```sql
SELECT BATCH_ID, WORKSPACE_ID, SOURCE_NAME, BATCH_STATUS
FROM PRICING_ENGINE_DB.CORE_INTERNAL.ONBOARDING_BATCHES
WHERE SOURCE_NAME ILIKE '%demo%';
```

The application intentionally does not expose a general-purpose delete action for promoted production data. Use your organization's governed data-retention and rollback process rather than deleting audit records or production history from the UI.
