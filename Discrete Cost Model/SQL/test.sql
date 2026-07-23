-- Simple test to verify Cortex AI functions are working
-- Co-authored with CoCo

-- Test COMPLETE function (text generation)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-8b',
    'Say hello in one sentence.'
) AS ai_response;

-- Test SENTIMENT function (returns -1 to 1)
SELECT SNOWFLAKE.CORTEX.SENTIMENT(
    'Snowflake is an amazing data platform!'
) AS sentiment_score;

-- Test SUMMARIZE function
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
    'Cortex AI provides built-in LLM functions in Snowflake. These include COMPLETE for text generation, SENTIMENT for sentiment analysis, SUMMARIZE for summarization, and TRANSLATE for translation. They run directly in your Snowflake account.'
) AS summary;

CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION
DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_MODEL
(
    INPUT_DATA => SYSTEM$REFERENCE(
        'TABLE',
        'DISCRETE_MFG_COST_MODEL.CORE_ML.CSS_SYNTHETIC_DATA'
    ),
    TARGET_COLNAME => 'HIGH_SCRAP',
    CONFIG_OBJECT => {
        'evaluate': TRUE,
        'on_error': 'SKIP'
    }
);