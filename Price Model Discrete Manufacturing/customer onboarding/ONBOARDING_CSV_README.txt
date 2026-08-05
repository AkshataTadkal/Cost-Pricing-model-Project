CUSTOMER ONBOARDING CSV PACK

IMPORTANT
- Files containing DEMO in the name contain synthetic test data only.
- Do not use demo values for pricing or production decisions.
- Replace demo customer, SKU, cost and price values with approved source data.

LOADABLE FILES
1. 01_standalone_pricing_inputs_demo.csv: directly loadable for functional testing.
2. 02_standalone_pricing_inputs_template.csv: header-only production template; add real rows before upload.
3. 03_alias_column_mapping_demo.csv: directly loadable to test manual/automatic column mapping.

REFERENCE FILES
4. 04_customer_master_reference_demo.csv: customer preparation reference; current combined onboarding pipeline does not load it independently.
5. 05_product_master_reference_demo.csv: product preparation reference; current combined onboarding pipeline does not load it independently.
6. 06_onboarding_data_dictionary.csv: required fields and formats.
