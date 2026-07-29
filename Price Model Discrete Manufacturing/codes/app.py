# import streamlit as st
# from snowflake.snowpark.context import get_active_session
# import pandas as pd
# import json
# import hashlib

# # ──────────────────────────────────────────────
# # PAGE CONFIG
# # ──────────────────────────────────────────────

# st.set_page_config(
#     page_title="Pricing Intelligence Platform",
#     page_icon="💎",
#     layout="wide",
#     initial_sidebar_state="collapsed"
# )

# # ──────────────────────────────────────────────
# # GLOBAL STYLES  (UNCHANGED — do not modify)
# # ──────────────────────────────────────────────

# st.markdown("""
# <style>
# @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@400;600;700&display=swap');

# :root{
#     --bg0:#050814;
#     --bg1:#07111f;
#     --glass:rgba(255,255,255,0.075);
#     --glass-strong:rgba(255,255,255,0.13);
#     --stroke:rgba(255,255,255,0.16);
#     --stroke-strong:rgba(125,211,252,0.32);
#     --text:#f8fbff;
#     --muted:rgba(226,232,240,0.70);
#     --cyan:#67e8f9;
#     --blue:#38bdf8;
#     --violet:#a78bfa;
#     --pink:#f0abfc;
#     --green:#7dd3a8;
#     --amber:#ffd166;
#     --red:#fb7185;
# }

# html, body, [data-testid="stAppViewContainer"]{
#     font-family:'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
#     color:var(--text) !important;
# }

# .stApp{
#     background:
#         radial-gradient(circle at 8% 8%, rgba(103,232,249,0.22) 0, rgba(103,232,249,0.035) 33%, transparent 44%),
#         radial-gradient(circle at 92% 10%, rgba(167,139,250,0.25) 0, rgba(167,139,250,0.04) 32%, transparent 46%),
#         radial-gradient(circle at 52% 96%, rgba(125,211,168,0.13) 0, transparent 42%),
#         linear-gradient(145deg, #050814 0%, #07111f 46%, #101827 100%) !important;
# }

# .block-container{
#     padding-top:1.25rem !important;
#     padding-bottom:3rem !important;
#     max-width:1440px !important;
# }

# [data-testid="stHeader"]{background:transparent !important;}

# [data-testid="stSidebar"]{
#     background:linear-gradient(180deg, rgba(8,16,30,0.96), rgba(10,18,32,0.94)) !important;
#     border-right:1px solid rgba(255,255,255,0.13) !important;
#     box-shadow:18px 0 70px rgba(0,0,0,0.25) !important;
# }

# /* Hero */
# .hero-banner{
#     position:relative;overflow:hidden;
#     padding:34px 38px 32px 38px;margin:0 0 26px 0;
#     border-radius:30px;border:1px solid rgba(255,255,255,0.18);
#     background:
#         linear-gradient(135deg, rgba(255,255,255,0.145), rgba(255,255,255,0.055)),
#         radial-gradient(circle at 88% 20%, rgba(103,232,249,0.26), transparent 34%),
#         radial-gradient(circle at 10% 90%, rgba(167,139,250,0.20), transparent 36%);
#     box-shadow:0 26px 85px rgba(0,0,0,0.34), inset 0 1px 0 rgba(255,255,255,0.18);
#     backdrop-filter:blur(18px);
# }
# .hero-banner:before{
#     content:"";position:absolute;inset:-2px;
#     background:linear-gradient(110deg, rgba(103,232,249,0.18), rgba(167,139,250,0.14), rgba(240,171,252,0.08), transparent 66%);
#     pointer-events:none;
# }
# .hero-inner{position:relative;z-index:1;}
# .hero-badge{
#     display:inline-flex;align-items:center;gap:8px;
#     padding:8px 13px;border-radius:999px;
#     background:rgba(103,232,249,0.12);border:1px solid rgba(103,232,249,0.30);
#     color:#bdf6ff;font-size:0.76rem;font-weight:800;letter-spacing:0.07em;text-transform:uppercase;margin-bottom:14px;
# }
# .hero-title{margin:0;color:#ffffff;font-weight:900;font-size:clamp(2.15rem,4vw,4.2rem);line-height:0.95;letter-spacing:-0.075em;}
# .hero-title span{
#     background:linear-gradient(90deg,#67e8f9 0%,#93c5fd 35%,#a78bfa 68%,#f0abfc 100%);
#     -webkit-background-clip:text;-webkit-text-fill-color:transparent;
# }
# .hero-sub{margin:14px 0 0 0;color:rgba(226,232,240,0.74);font-size:1.02rem;line-height:1.65;max-width:980px;}
# .hero-pills{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px;}
# .hero-pill{
#     display:inline-flex;align-items:center;gap:8px;padding:9px 12px;border-radius:999px;
#     background:rgba(255,255,255,0.09);border:1px solid rgba(255,255,255,0.16);
#     color:rgba(248,251,255,0.90);font-size:0.84rem;font-weight:700;
# }
# .hero-pill strong{color:#ffffff;}

# /* Tabs */
# .stTabs [data-baseweb="tab-list"]{
#     background:rgba(255,255,255,0.07) !important;border:1px solid rgba(255,255,255,0.13) !important;
#     border-radius:999px !important;padding:6px !important;gap:6px !important;
#     box-shadow:0 16px 45px rgba(0,0,0,0.22),inset 0 1px 0 rgba(255,255,255,0.12) !important;
#     backdrop-filter:blur(14px) !important;
# }
# .stTabs [data-baseweb="tab"]{
#     background:transparent !important;color:rgba(226,232,240,0.70) !important;
#     border-radius:999px !important;font-size:13px !important;font-weight:800 !important;
#     padding:10px 18px !important;border:none !important;transition:all 0.20s ease !important;
# }
# .stTabs [data-baseweb="tab"]:hover{color:#ffffff !important;background:rgba(255,255,255,0.07) !important;}
# .stTabs [aria-selected="true"]{
#     background:linear-gradient(90deg,rgba(56,189,248,0.95),rgba(139,92,246,0.95)) !important;
#     color:white !important;box-shadow:0 12px 26px rgba(56,189,248,0.28) !important;
# }
# .stTabs [data-baseweb="tab-highlight"],.stTabs [data-baseweb="tab-border"]{display:none !important;}

# /* Metric cards */
# [data-testid="metric-container"]{
#     position:relative;overflow:hidden;
#     background:linear-gradient(145deg,rgba(255,255,255,0.125),rgba(255,255,255,0.055)) !important;
#     border:1px solid rgba(255,255,255,0.15) !important;border-radius:22px !important;
#     padding:19px 21px !important;
#     box-shadow:0 18px 48px rgba(0,0,0,0.24),inset 0 1px 0 rgba(255,255,255,0.16) !important;
#     backdrop-filter:blur(14px) !important;
# }
# [data-testid="metric-container"]:after{
#     content:"";position:absolute;top:-42px;right:-38px;width:105px;height:105px;
#     border-radius:999px;background:radial-gradient(circle,rgba(103,232,249,0.25),transparent 64%);
# }
# [data-testid="metric-container"] label{
#     color:rgba(226,232,240,0.66) !important;font-size:11px !important;font-weight:850 !important;
#     text-transform:uppercase !important;letter-spacing:0.09em !important;
# }
# [data-testid="stMetricValue"]{
#     color:#ffffff !important;font-size:clamp(1.3rem,1.9vw,2rem) !important;
#     font-weight:900 !important;letter-spacing:-0.045em !important;
#     font-family:'JetBrains Mono',monospace !important;
# }
# [data-testid="stMetricDelta"]{font-size:12px !important;}

# /* Section headers */
# .section-header{display:flex;align-items:center;gap:12px;margin:26px 0 16px 0;}
# .section-header .icon{
#     width:38px;height:38px;border-radius:14px;display:flex;align-items:center;justify-content:center;
#     background:linear-gradient(135deg,rgba(103,232,249,0.16),rgba(167,139,250,0.13));
#     border:1px solid rgba(255,255,255,0.16);box-shadow:inset 0 1px 0 rgba(255,255,255,0.15);font-size:18px;
# }
# .section-header h3{color:#f8fbff;font-size:1.05rem;font-weight:850;margin:0;letter-spacing:-0.035em;}
# .section-divider{border:none;height:1px;background:linear-gradient(90deg,transparent,rgba(255,255,255,0.16),transparent);margin:26px 0;}

# /* Buttons */
# .stButton > button{
#     min-height:3rem !important;
#     background:linear-gradient(90deg,#22d3ee 0%,#6366f1 50%,#a855f7 100%) !important;
#     color:#ffffff !important;border:1px solid rgba(255,255,255,0.16) !important;
#     border-radius:16px !important;font-weight:850 !important;font-size:14px !important;
#     padding:10px 24px !important;
#     box-shadow:0 14px 32px rgba(56,189,248,0.22),inset 0 1px 0 rgba(255,255,255,0.20) !important;
#     transition:all 0.20s ease !important;
# }
# .stButton > button:hover{
#     transform:translateY(-2px) !important;
#     box-shadow:0 18px 42px rgba(139,92,246,0.32) !important;filter:saturate(1.10) !important;
# }

# /* Inputs */
# .stSelectbox > div > div,
# .stTextInput > div > div > input,
# .stNumberInput > div > div > input,
# .stTextArea textarea{
#     background:rgba(255,255,255,0.075) !important;border:1px solid rgba(255,255,255,0.16) !important;
#     border-radius:14px !important;color:#f8fbff !important;font-size:13px !important;
#     box-shadow:inset 0 1px 0 rgba(255,255,255,0.08) !important;
# }
# .stTextArea textarea{font-family:'JetBrains Mono',monospace !important;line-height:1.65 !important;}
# label[data-testid="stWidgetLabel"] p{color:rgba(226,232,240,0.78) !important;font-weight:800 !important;}
# .stSlider [data-baseweb="slider"] div[role="slider"]{
#     background:#67e8f9 !important;border-color:#67e8f9 !important;
#     box-shadow:0 0 0 6px rgba(103,232,249,0.12) !important;
# }

# /* Dataframe and charts */
# [data-testid="stDataFrame"]{
#     border:1px solid rgba(255,255,255,0.14) !important;border-radius:20px !important;
#     overflow:hidden !important;box-shadow:0 18px 45px rgba(0,0,0,0.24) !important;
# }
# [data-testid="stDataFrame"] th{
#     background:rgba(15,23,42,0.92) !important;color:rgba(226,232,240,0.75) !important;
#     font-size:11px !important;font-weight:850 !important;text-transform:uppercase !important;letter-spacing:0.07em !important;
# }
# .stBarChart,.stLineChart,[data-testid="stVegaLiteChart"]{
#     background:linear-gradient(145deg,rgba(255,255,255,0.105),rgba(255,255,255,0.045)) !important;
#     border:1px solid rgba(255,255,255,0.14) !important;border-radius:20px !important;
#     padding:14px !important;box-shadow:0 16px 42px rgba(0,0,0,0.22) !important;
# }

# /* Alerts */
# .stSuccess > div,.stInfo > div,.stWarning > div,.stError > div{
#     border-radius:18px !important;border:1px solid rgba(255,255,255,0.14) !important;
#     background:rgba(255,255,255,0.08) !important;box-shadow:0 14px 34px rgba(0,0,0,0.16) !important;
#     backdrop-filter:blur(12px) !important;
# }
# .stSuccess > div{color:#a7f3d0 !important;}
# .stInfo > div{color:#bae6fd !important;}
# .stWarning > div{color:#fde68a !important;}
# .stError > div{color:#fecdd3 !important;}

# /* Expander & chat */
# .streamlit-expanderHeader{background:rgba(255,255,255,0.07) !important;border-radius:16px !important;color:#f8fbff !important;}
# [data-testid="stChatMessage"]{
#     background:rgba(255,255,255,0.075) !important;border:1px solid rgba(255,255,255,0.13) !important;border-radius:18px !important;
# }

# /* Health score bar */
# .health-bar-wrap{
#     background:linear-gradient(145deg,rgba(255,255,255,0.105),rgba(255,255,255,0.045));
#     border:1px solid rgba(255,255,255,0.14);border-radius:20px;
#     padding:22px 24px;margin:12px 0;box-shadow:0 16px 42px rgba(0,0,0,0.22);
# }
# .health-bar-track{background:rgba(15,23,42,0.90);border-radius:999px;height:12px;margin-top:10px;overflow:hidden;}
# .health-bar-fill{height:100%;border-radius:999px;transition:width 0.6s ease;}

# /* Competitor gauge card */
# .gauge-card{
#     background:linear-gradient(145deg,rgba(255,255,255,0.10),rgba(255,255,255,0.04));
#     border:1px solid rgba(255,255,255,0.14);border-radius:20px;
#     padding:20px 22px;margin:8px 0;box-shadow:0 16px 40px rgba(0,0,0,0.22);
# }
# .price-tag{
#     display:inline-block;padding:4px 12px;border-radius:999px;
#     font-size:11px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;
# }
# .alert-chip{
#     display:inline-flex;align-items:center;gap:6px;
#     padding:7px 14px;border-radius:999px;
#     background:rgba(239,68,68,0.12);border:1px solid rgba(239,68,68,0.28);
#     color:#fca5a5;font-size:12px;font-weight:700;margin:4px 4px 4px 0;
# }
# .opportunity-chip{
#     display:inline-flex;align-items:center;gap:6px;
#     padding:7px 14px;border-radius:999px;
#     background:rgba(0,199,178,0.12);border:1px solid rgba(0,199,178,0.30);
#     color:#5eead4;font-size:12px;font-weight:700;margin:4px 4px 4px 0;
# }

# ::-webkit-scrollbar{width:7px;height:7px;}
# ::-webkit-scrollbar-track{background:#050814;}
# ::-webkit-scrollbar-thumb{background:linear-gradient(180deg,#38bdf8,#8b5cf6);border-radius:999px;}

# #MainMenu{visibility:hidden;}
# footer{visibility:hidden;}

# @media(max-width:900px){
#     .hero-banner{padding:26px 22px;border-radius:24px;}
#     .hero-title{font-size:2.35rem;}
#     .hero-pills{gap:8px;}
# }
# </style>
# """, unsafe_allow_html=True)


# # ──────────────────────────────────────────────
# # SESSION STATE INITIALIZATION
# # Key fix: persist all computation results in session_state so
# # widget interactions (sliders, selects) don't wipe the output.
# # ──────────────────────────────────────────────

# def _init_state(key, default):
#     if key not in st.session_state:
#         st.session_state[key] = default

# _init_state("opt_results",       None)   # Tab 2 optimization
# _init_state("opt_sku",           None)
# _init_state("opt_cost",          None)   # Tab 2 — must be initialised to avoid KeyError on first load
# _init_state("opt_best",          None)   # Tab 2 — same
# _init_state("sim_results",       None)   # Tab 3 simulation
# _init_state("cp_result",         None)   # Tab 2 customer lookup
# _init_state("dt_results",        None)   # Tab 4 digital twin
# _init_state("contract_results",  None)   # Tab 6 contract
# _init_state("comp_results",      None)   # Tab 7 competitor
# _init_state("sc_result",         None)   # Tab 3 pre-defined scenario
# _init_state("psi_results",       None)   # Tab 2 PSI analysis
# _init_state("ai_cache",          {})     # NEW — memoizes every Cortex AI call this session


# # ──────────────────────────────────────────────
# # SNOWFLAKE SESSION
# # ──────────────────────────────────────────────

# session = get_active_session()


# # ──────────────────────────────────────────────
# # HELPERS  (unchanged — do not modify)
# # ──────────────────────────────────────────────

# def section(icon, title):
#     st.markdown(f"""
#     <div class="section-header">
#         <div class="icon">{icon}</div>
#         <h3>{title}</h3>
#     </div>""", unsafe_allow_html=True)

# def divider():
#     st.markdown('<hr class="section-divider">', unsafe_allow_html=True)

# def safe_pct_change(new_val, base_val):
#     if base_val == 0:
#         return 0.0
#     return ((new_val - base_val) / abs(base_val)) * 100

# def health_bar_html(score, color, status):
#     return f"""
#     <div class="health-bar-wrap">
#         <div style="display:flex;justify-content:space-between;align-items:center;">
#             <div style="color:#C8D8E8;font-size:28px;font-weight:700;font-family:'JetBrains Mono',monospace;">
#                 {score}<span style="font-size:14px;color:#6B8BAF;font-weight:400;"> /100</span>
#             </div>
#             <div style="color:{color};font-size:13px;font-weight:600;">{status}</div>
#         </div>
#         <div class="health-bar-track">
#             <div class="health-bar-fill" style="width:{score}%;background:linear-gradient(90deg,{color}88,{color});"></div>
#         </div>
#     </div>
#     """


# def get_capacity_modifier(utilization):
#     """Returns (modifier_decimal, status_label, status_color) based on plant utilization %.
#     NOTE: kept deterministic on purpose — this modifier feeds directly into the
#     selling-price calculation, and per the AI-integration brief, mathematical /
#     financial calculations must remain deterministic. Only the narrative business
#     interpretation built on top of this (see ai_capacity_recommendation below)
#     is generated dynamically by Cortex."""
#     if utilization < 50:
#         return -0.05, "🟢 Under Utilized", "green"
#     elif utilization < 70:
#         return 0.00, "🟢 Normal", "green"
#     elif utilization <= 85:
#         return 0.05, "🟡 Busy", "orange"
#     else:
#         return 0.10, "🔴 Near Capacity", "red"

# def get_capacity_recommendation(utilization):
#     """Deterministic fallback text — used only if Cortex AI is unavailable."""
#     if utilization < 50:
#         return "Reduce price slightly to attract orders and improve plant utilization."
#     elif utilization < 70:
#         return "Maintain current pricing — plant is operating at a healthy utilization level."
#     elif utilization <= 85:
#         return "Protect capacity and avoid unnecessary discounts as the plant is running busy."
#     else:
#         return "Increase selling price and prioritize high-margin orders — plant is near capacity."


# # ──────────────────────────────────────────────
# # CORTEX AI HELPERS   (NEW)
# # Every Snowflake Cortex AI Function call in this app is centralized here.
# #
# # Design principles (per the AI-integration brief):
# #  • Deterministic math (revenue, cost, margin, simulations) is NEVER touched.
# #  • Business interpretation — recommendations, explanations, summaries,
# #    classifications, alerts, decision support — is generated dynamically.
# #  • Every helper is defensive: on any failure (Cortex unavailable, malformed
# #    output, network hiccup) it returns None so the caller falls back to the
# #    original deterministic rule-based text. Nothing can crash because of
# #    an AI outage.
# #  • Results are memoized in st.session_state["ai_cache"] keyed by a hash of
# #    the inputs, so the same insight is never regenerated twice in a
# #    session — this avoids unnecessary/duplicate Cortex calls.
# # ──────────────────────────────────────────────

# def _ai_cache_key(*parts) -> str:
#     raw = "||".join(str(p) for p in parts)
#     return hashlib.md5(raw.encode("utf-8")).hexdigest()

# def _sql_escape(text) -> str:
#     return str(text).replace("\\", "\\\\").replace("'", "''")

# _init_state("ai_last_error", None)
# _init_state("ai_last_raw", {})   # last raw Cortex response per function, for diagnostics
# _init_state("ai_call_stats", {"ok": 0, "fail": 0})

# def _record_ai_error(fn_name: str, err: Exception):
#     st.session_state["ai_last_error"] = f"[{fn_name}] {type(err).__name__}: {err}"
#     st.session_state["ai_call_stats"]["fail"] += 1

# def _record_ai_ok(fn_name: str, raw):
#     st.session_state["ai_last_raw"][fn_name] = raw
#     st.session_state["ai_call_stats"]["ok"] += 1

# def ai_complete(prompt: str, model: str = None, cache_key: str = None):
#     """Snowflake Cortex AI_COMPLETE — free-text generation used for every
#     recommendation, business-impact explanation, and executive narrative
#     in this app. Returns None on failure (error captured in
#     st.session_state["ai_last_error"] for diagnostics — see the
#     Cortex AI Diagnostics panel). Uses the model chosen in the Cortex AI
#     Diagnostics panel if set, else defaults to llama3.1-70b."""
#     model = model or st.session_state.get("ai_model_override") or "llama3.1-70b"
#     key = cache_key or _ai_cache_key("complete", model, prompt)
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]
#     try:
#         safe_prompt = _sql_escape(prompt)
#         row = session.sql(f"SELECT AI_COMPLETE('{model}', '{safe_prompt}') AS RESP").collect()
#         result = row[0]["RESP"] if row else None
#         if result is not None:
#             st.session_state["ai_cache"][key] = result  # never cache None so a failed/empty response gets retried next time
#         _record_ai_ok("ai_complete", result)
#         return result
#     except Exception as e:
#         _record_ai_error("ai_complete", e)
#         return None

# def ai_classify(text: str, categories: list, cache_key: str = None):
#     """Snowflake Cortex AI_CLASSIFY — used to replace fixed if/elif
#     classification thresholds (risk tiers, customer segments, health
#     status labels, etc). Returns the chosen label, or None on failure."""
#     key = cache_key or _ai_cache_key("classify", text, tuple(categories))
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]
#     try:
#         safe_text = _sql_escape(text)
#         cat_list  = ", ".join(f"'{_sql_escape(c)}'" for c in categories)
#         row = session.sql(f"""
#             SELECT AI_CLASSIFY('{safe_text}', [{cat_list}]):labels[0]::STRING AS LABEL
#         """).collect()
#         result = row[0]["LABEL"] if row else None
#         if result is not None:
#             st.session_state["ai_cache"][key] = result
#         _record_ai_ok("ai_classify", result)
#         return result
#     except Exception as e:
#         _record_ai_error("ai_classify", e)
#         return None

# def ai_filter(text: str, cache_key: str = None):
#     """Snowflake Cortex AI_FILTER — decides whether a raw signal is
#     significant enough to surface as an executive alert. Returns None on
#     failure (callers fail-open, i.e. show the alert, rather than hide
#     potentially important information)."""
#     key = cache_key or _ai_cache_key("filter", text)
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]
#     try:
#         safe_text = _sql_escape(text)
#         row = session.sql(f"SELECT AI_FILTER('{safe_text}') AS FLAG").collect()
#         result = bool(row[0]["FLAG"]) if row else None
#         if result is not None:
#             st.session_state["ai_cache"][key] = result
#         _record_ai_ok("ai_filter", result)
#         return result
#     except Exception as e:
#         _record_ai_error("ai_filter", e)
#         return None

# def ai_summarize(text: str, cache_key: str = None):
#     """SNOWFLAKE.CORTEX.SUMMARIZE — condenses a larger block of business
#     data (rendered as text) into an executive-ready narrative summary."""
#     key = cache_key or _ai_cache_key("summarize", text)
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]
#     try:
#         safe_text = _sql_escape(text)
#         row = session.sql(f"SELECT SNOWFLAKE.CORTEX.SUMMARIZE('{safe_text}') AS SUMMARY").collect()
#         result = row[0]["SUMMARY"] if row else None
#         if result is not None:
#             st.session_state["ai_cache"][key] = result
#         _record_ai_ok("ai_summarize", result)
#         return result
#     except Exception as e:
#         _record_ai_error("ai_summarize", e)
#         return None

# def ai_agg_over_rows(row_texts: list, question: str, cache_key: str = None):
#     """AI_AGG — aggregate reasoning across many rows in ONE Cortex call
#     (used instead of firing one AI_COMPLETE per row), e.g. summarizing
#     competitor behavior or market trends across several data points."""
#     if not row_texts:
#         return None
#     key = cache_key or _ai_cache_key("agg", question, tuple(row_texts))
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]
#     try:
#         values_sql = ", ".join(f"('{_sql_escape(t)}')" for t in row_texts[:50])
#         safe_q = _sql_escape(question)
#         row = session.sql(f"""
#             SELECT AI_AGG(COL, '{safe_q}') AS RESULT
#             FROM (SELECT COLUMN1 AS COL FROM VALUES {values_sql})
#         """).collect()
#         result = row[0]["RESULT"] if row else None
#         if result is not None:
#             st.session_state["ai_cache"][key] = result
#         _record_ai_ok("ai_agg_over_rows", result)
#         return result
#     except Exception as e:
#         _record_ai_error("ai_agg_over_rows", e)
#         return None

# import re

# def parse_ai_json(raw_text):
#     """Best-effort, LENIENT JSON parse of an AI_COMPLETE response.
#     Handles: markdown fences, leading/trailing prose, trailing commas,
#     AND double/triple-JSON-encoded strings (Cortex sometimes returns the
#     JSON payload wrapped as a quoted string literal)."""
#     if not raw_text:
#         return None

#     def _try(text):
#         try:
#             return json.loads(text)
#         except Exception:
#             return None

#     def _unwrap(value, depth=0):
#         # Keep unwrapping while json.loads() keeps handing back another
#         # string that itself looks like JSON (dict/list), up to a small
#         # depth cap to avoid infinite loops on pathological input.
#         if depth > 3:
#             return value
#         if isinstance(value, str):
#             stripped = value.strip()
#             if stripped.startswith("{") or stripped.startswith("["):
#                 inner = _try(stripped)
#                 if inner is not None:
#                     return _unwrap(inner, depth + 1)
#         return value

#     candidates = [raw_text.strip()]

#     fenced = raw_text.strip()
#     if fenced.startswith("```"):
#         fenced = fenced.strip("`")
#         if fenced.lower().startswith("json"):
#             fenced = fenced[4:]
#         candidates.append(fenced.strip())

#     obj_match = re.search(r"\{.*\}", raw_text, re.DOTALL)
#     if obj_match:
#         candidates.append(obj_match.group(0))
#     arr_match = re.search(r"\[.*\]", raw_text, re.DOTALL)
#     if arr_match:
#         candidates.append(arr_match.group(0))

#     for cand in candidates:
#         result = _try(cand)
#         if result is not None:
#             return _unwrap(result)
#         fixed = re.sub(r",\s*([\]}])", r"\1", cand)
#         result = _try(fixed)
#         if result is not None:
#             return _unwrap(result)

#     return None

# def ai_or_fallback(ai_result, fallback):
#     """Small convenience: use the AI-generated text if present, else the
#     deterministic rule-based fallback string."""
#     return ai_result if ai_result else fallback


# # ──────────────────────────────────────────────
# # AI MEMORY LAYER   (NEW — v2)
# # Every AI scoring/decision call is logged so future calls in this session
# # (and, best-effort, future sessions via a Snowflake table) can be given
# # historical context — "Retrieve Historical Context" in the reasoning
# # pipeline below. Snowflake writes are best-effort: if the table doesn't
# # exist yet this silently falls back to in-session memory only, and the
# # app keeps working.
# # ──────────────────────────────────────────────

# _init_state("ai_memory", [])  # in-session list of {module, decision_type, summary, result}

# def ai_memory_log(module: str, decision_type: str, context_summary: str, result: dict):
#     """Persist an AI decision to memory (session + best-effort Snowflake)."""
#     entry = {
#         "module": module,
#         "decision_type": decision_type,
#         "summary": context_summary[:500],
#         "result_summary": json.dumps(result)[:800] if isinstance(result, dict) else str(result)[:800],
#     }
#     st.session_state["ai_memory"].append(entry)
#     st.session_state["ai_memory"] = st.session_state["ai_memory"][-200:]
#     try:
#         session.sql(f"""
#             INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG
#                 (MODULE, DECISION_TYPE, CONTEXT_SUMMARY, RESULT_SUMMARY, CREATED_AT)
#             VALUES (
#                 '{_sql_escape(module)}', '{_sql_escape(decision_type)}',
#                 '{_sql_escape(entry["summary"])}', '{_sql_escape(entry["result_summary"])}',
#                 CURRENT_TIMESTAMP()
#             )
#         """).collect()
#     except Exception:
#         pass

# def get_ai_memory_context(module: str, decision_type: str = None, limit: int = 3) -> str:
#     """Retrieve recent memory entries for this module (in-session first,
#     falling back to Snowflake) to give the AI historical context."""
#     matches = [
#         e for e in reversed(st.session_state["ai_memory"])
#         if e["module"] == module and (decision_type is None or e["decision_type"] == decision_type)
#     ][:limit]
#     if matches:
#         return "\n".join(f"- Prior decision: {m['summary']} -> {m['result_summary']}" for m in matches)
#     try:
#         where_dt = f"AND DECISION_TYPE = '{_sql_escape(decision_type)}'" if decision_type else ""
#         rows = session.sql(f"""
#             SELECT CONTEXT_SUMMARY, RESULT_SUMMARY FROM PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG
#             WHERE MODULE = '{_sql_escape(module)}' {where_dt}
#             ORDER BY CREATED_AT DESC LIMIT {limit}
#         """).collect()
#         if rows:
#             return "\n".join(f"- Prior decision: {r['CONTEXT_SUMMARY']} -> {r['RESULT_SUMMARY']}" for r in rows)
#     except Exception:
#         pass
#     return "No prior decisions on record for this module yet."


# # ──────────────────────────────────────────────
# # CENTRAL AI REASONING SERVICE   (NEW — v2)
# # This is the single entry point every scoring / classification / decision
# # module in the app now calls. It implements the full reasoning pipeline
# # requested:  Build Context -> Retrieve Historical Context -> AI_REASON ->
# # AI_DECIDE/AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE -> (retry once if invalid).
# #
# # No manual weights, averages, or formulas are used to produce the score --
# # AI_COMPLETE is instructed to reason over the full context and return the
# # score itself. The Python code below only (a) assembles context,
# # (b) parses/validates the JSON shape, and (c) retries once on invalid
# # output. If AI is unavailable or still invalid after a retry, a clearly
# # labeled neutral/unscored result is returned -- never a hardcoded business
# # score standing in for the AI's judgment, and never a crash.
# # ──────────────────────────────────────────────

# REQUIRED_SCORE_FIELDS = ["score", "label", "confidence", "reasoning", "risks", "opportunities", "recommended_actions"]

# def _coerce_score_payload(payload):
#     """LENIENT coercion instead of strict validation. A model deviating on
#     one field (wrong type, missing key, score as '85' or '85%', a string
#     instead of a list) should NOT nuke the entire response — only a
#     genuinely unusable payload (no parseable score at all) is rejected.
#     Returns a fully-populated payload dict, or None if truly unusable."""
#     if not isinstance(payload, dict):
#         return None

#     # score is the only field that MUST be present and numeric — everything
#     # else gets a sensible default if missing or malformed.
#     raw_score = payload.get("score")
#     if raw_score is None:
#         return None
#     try:
#         if isinstance(raw_score, str):
#             raw_score = raw_score.strip().rstrip("%")
#         score = float(raw_score)
#     except Exception:
#         return None
#     score = max(0.0, min(100.0, score))

#     def _num(val, default):
#         try:
#             if isinstance(val, str):
#                 val = val.strip().rstrip("%")
#             n = float(val)
#             return max(0.0, min(100.0, n))
#         except Exception:
#             return default

#     def _list_of_str(val):
#         if isinstance(val, list):
#             return [str(x) for x in val if str(x).strip()]
#         if isinstance(val, str) and val.strip():
#             return [val.strip()]
#         return []

#     coerced = {
#         "score": score,
#         "label": str(payload.get("label") or "Unlabeled"),
#         "confidence": _num(payload.get("confidence"), 50.0),
#         "reasoning": str(payload.get("reasoning") or "No detailed reasoning provided."),
#         "risks": _list_of_str(payload.get("risks")),
#         "opportunities": _list_of_str(payload.get("opportunities")),
#         "recommended_actions": _list_of_str(payload.get("recommended_actions")),
#     }
#     # carry through any extra numeric_fields the caller asked for verbatim
#     for k, v in payload.items():
#         if k not in coerced:
#             coerced[k] = v
#     return coerced

# def _neutral_score_payload(reason: str) -> dict:
#     """Explicitly-labeled 'AI unavailable' result -- not a hardcoded
#     business score, just a safe, honest placeholder so the UI never
#     crashes and never silently pretends a fixed rule is an AI judgment."""
#     return {
#         "score": None, "label": "AI Unavailable", "confidence": 0,
#         "reasoning": reason, "risks": [], "opportunities": [], "recommended_actions": [],
#         "ai_generated": False,
#     }

# def ai_reason_score(module: str, decision_type: str, context_facts: str,
#                      extra_instruction: str = "", numeric_fields: dict = None,
#                      cache_key: str = None):
#     """
#     Core AI_REASON -> AI_DECIDE -> AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE pipeline.

#     context_facts   : the raw business data this decision is about (deterministic
#                        arithmetic facts only -- revenue, cost, margin numbers, etc.)
#     numeric_fields   : optional dict of {field_name: description} the AI should
#                        ALSO return in addition to the standard score fields (e.g.
#                        {"margin_pct": "recommended margin percent, 0-100"} for PSI,
#                        so that number can be used in the one deterministic
#                        multiplication that turns it into a price).
#     Returns a dict with at least: score, label, confidence, reasoning, risks,
#     opportunities, recommended_actions, ai_generated (bool), plus any
#     numeric_fields requested. Never raises.

#     Validation here is LENIENT (see _coerce_score_payload): only a response
#     with no parseable score at all is treated as a failure. A missing risks
#     list, a score sent as "85%", or an extra field no longer discards the
#     whole result — this is what made near-every card show "AI Unavailable"
#     in earlier versions even though Cortex was actually responding.
#     """
#     key = cache_key or _ai_cache_key("reason_score", module, decision_type, context_facts, extra_instruction)
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]

#     history = get_ai_memory_context(module, decision_type)
#     extra_field_lines = ""
#     if numeric_fields:
#         extra_field_lines = "\n".join(f'  "{f}": <{desc}>,' for f, desc in numeric_fields.items())

#     base_prompt = (
#         f"You are an expert enterprise pricing analyst embedded in a manufacturing "
#         f"Pricing Intelligence Platform. Module: {module}. Decision type: {decision_type}.\n\n"
#         f"Relevant prior decisions (for consistency, not binding):\n{history}\n\n"
#         f"Current facts (all numbers below are deterministic, already computed -- "
#         f"do not recompute them, just reason over them):\n{context_facts}\n\n"
#         f"{extra_instruction}\n\n"
#         f"Respond with ONLY a single JSON object (no markdown fences, no text before or "
#         f"after the JSON) with this shape (numbers as plain numbers, not strings or "
#         f"percentages):\n"
#         "{\n"
#         '  "score": <number 0-100, your own judgment -- do not use a fixed formula>,\n'
#         '  "label": "<short status label>",\n'
#         '  "confidence": <number 0-100>,\n'
#         '  "reasoning": "<2-3 sentence plain-business-language explanation>",\n'
#         '  "risks": ["<short risk>", "..."],\n'
#         '  "opportunities": ["<short opportunity>", "..."],\n'
#         '  "recommended_actions": ["<short action>", "..."]'
#         + ("," if numeric_fields else "") + "\n"
#         + (extra_field_lines + "\n" if numeric_fields else "")
#         + "}"
#     )

#     def _attempt(prompt):
#         raw = ai_complete(prompt, cache_key=_ai_cache_key("reason_score_raw", module, decision_type, prompt))
#         return raw, parse_ai_json(raw)

#     raw1, parsed1 = _attempt(base_prompt)
#     payload = _coerce_score_payload(parsed1)

#     if payload is None:
#         repair_prompt = (
#             base_prompt + "\n\nRespond again. Output ONLY the JSON object above, "
#             "starting with { and ending with } — no explanation, no markdown."
#         )
#         raw2, parsed2 = _attempt(repair_prompt)
#         payload = _coerce_score_payload(parsed2)
#         if payload is None:
#             debug_raw = raw2 or raw1 or "(no response from AI_COMPLETE — check Cortex AI Diagnostics)"
#             payload = _neutral_score_payload(
#                 "Cortex AI response could not be parsed as JSON. Raw response (truncated): "
#                 + str(debug_raw)[:300]
#             )
#         else:
#             payload["ai_generated"] = True
#     else:
#         payload["ai_generated"] = True

#     if payload.get("ai_generated") and numeric_fields:
#         for f in numeric_fields:
#             if f in payload:
#                 try:
#                     v = payload[f]
#                     if isinstance(v, str):
#                         v = v.strip().rstrip("%")
#                     payload[f] = float(v)
#                 except Exception:
#                     payload.pop(f, None)

#     # Only cache successful results. A failed/neutral payload is NEVER
#     # cached — otherwise a card that failed once (e.g. while a model was
#     # temporarily broken) would keep replaying that stale failure forever,
#     # even after Cortex starts working again.
#     if payload.get("ai_generated"):
#         st.session_state["ai_cache"][key] = payload
#     ai_memory_log(module, decision_type, context_facts[:300], payload)
#     return payload

# def ai_reason_score_batch(module: str, decision_type: str, items_context: list,
#                            extra_instruction: str = "", cache_key: str = None):
#     """Batched variant of ai_reason_score for many similar items in ONE
#     Cortex call (e.g. a price sweep, or many customers/products at once) --
#     keeps AI-driven scoring performant instead of one call per item.
#     items_context: list of short fact strings, one per item.
#     Returns a list of payload dicts (same shape as ai_reason_score), same
#     length/order as items_context; falls back to neutral payloads per item
#     on failure."""
#     if not items_context:
#         return []
#     key = cache_key or _ai_cache_key("reason_batch", module, decision_type, tuple(items_context))
#     if key in st.session_state["ai_cache"]:
#         return st.session_state["ai_cache"][key]

#     numbered = "\n".join(f"{i+1}. {c}" for i, c in enumerate(items_context))
#     prompt = (
#         f"You are an expert enterprise pricing analyst. Module: {module}. Decision type: "
#         f"{decision_type}. For EACH numbered item below, reason independently and produce "
#         f"a score (0-100, your own judgment, no fixed formula), a short label, a confidence "
#         f"(0-100), and a one-sentence reasoning. {extra_instruction}\n\nItems:\n{numbered}\n\n"
#         f"Respond with ONLY a JSON array (no markdown), same length and order as the items, "
#         f"each object shaped exactly as:\n"
#         '{"score": <0-100>, "label": "<short label>", "confidence": <0-100>, "reasoning": "<1 sentence>"}'
#     )
#     raw = ai_complete(prompt, cache_key=_ai_cache_key("reason_batch_raw", module, decision_type, prompt))
#     parsed = parse_ai_json(raw)

#     results = []
#     for i in range(len(items_context)):
#         if isinstance(parsed, list) and i < len(parsed) and isinstance(parsed[i], dict) \
#            and "score" in parsed[i]:
#             try:
#                 s = float(parsed[i]["score"])
#                 c = float(parsed[i].get("confidence", 50))
#                 results.append({
#                     "score": max(0, min(100, s)),
#                     "label": parsed[i].get("label", "N/A"),
#                     "confidence": max(0, min(100, c)),
#                     "reasoning": parsed[i].get("reasoning", ""),
#                     "ai_generated": True,
#                 })
#                 continue
#             except Exception:
#                 pass
#         results.append({"score": None, "label": "AI Unavailable", "confidence": 0,
#                          "reasoning": "No valid AI response for this item.", "ai_generated": False})

#     # Only cache if at least one item actually got a real AI response —
#     # a fully-failed batch is never cached, so it retries on the next run.
#     if any(r.get("ai_generated") for r in results):
#         st.session_state["ai_cache"][key] = results
#     ai_memory_log(module, decision_type, f"{len(items_context)} batched items", {"count": len(results)})
#     return results


# def render_ai_score_card(payload: dict, title_prefix: str = "AI Score"):
#     """Reusable renderer for any ai_reason_score() payload — used across
#     every module (Executive Health, PSI, Capacity, Win Probability,
#     Contract Risk, Margin Leakage, Advisor, Competitor) so the scoring UI
#     is consistent and not duplicated per-module."""
#     if not payload.get("ai_generated"):
#         st.warning(f"⚠️ {title_prefix}: AI service unavailable — {payload.get('reasoning', 'no response from Cortex AI.')}")
#         with st.expander("🔧 Why did this fail? (Cortex AI Diagnostics)"):
#             st.write("Last Cortex error captured this session:")
#             st.code(st.session_state.get("ai_last_error") or "No error captured yet — Cortex may be returning empty/malformed text rather than erroring.")
#             st.write("Last raw AI_COMPLETE response seen this session:")
#             st.code(str(st.session_state.get("ai_last_raw", {}).get("ai_complete", ""))[:800] or "(none yet)")
#             st.caption(
#                 "Common causes: the model name 'llama3.1-70b' isn't enabled for your "
#                 "Snowflake account/region (try changing the `model` default in ai_complete()), "
#                 "the role running this app lacks USAGE on SNOWFLAKE.CORTEX functions, or "
#                 "AI_COMPLETE/AI_CLASSIFY/AI_FILTER aren't available in your Snowflake edition/region yet."
#             )
#         return

#     score = payload["score"]
#     label = payload["label"]
#     confidence = payload["confidence"]

#     bar_color = "#00C7B2" if score >= 75 else "#38BDF8" if score >= 55 else "#F59E0B" if score >= 35 else "#EF4444"
#     st.markdown(health_bar_html(int(round(score)), bar_color, f"{label}  ·  {confidence:.0f}% confidence"), unsafe_allow_html=True)
#     st.write(payload["reasoning"])

#     c1, c2, c3 = st.columns(3)
#     with c1:
#         st.markdown("**⚠️ Risks**")
#         if payload["risks"]:
#             for x in payload["risks"]:
#                 st.write(f"• {x}")
#         else:
#             st.caption("None identified")
#     with c2:
#         st.markdown("**🎯 Opportunities**")
#         if payload["opportunities"]:
#             for x in payload["opportunities"]:
#                 st.write(f"• {x}")
#         else:
#             st.caption("None identified")
#     with c3:
#         st.markdown("**✅ Recommended Actions**")
#         if payload["recommended_actions"]:
#             for x in payload["recommended_actions"]:
#                 st.write(f"• {x}")
#         else:
#             st.caption("None identified")


# # Best-effort one-time setup of the AI memory table. If the role running
# # this app lacks CREATE TABLE privileges, this no-ops (the app keeps
# # working on in-session memory only — see get_ai_memory_context above) but
# # the error is still recorded for the diagnostics panel rather than hidden.
# if "ai_memory_table_checked" not in st.session_state:
#     try:
#         session.sql("""
#             CREATE TABLE IF NOT EXISTS PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG (
#                 MODULE VARCHAR, DECISION_TYPE VARCHAR, CONTEXT_SUMMARY VARCHAR,
#                 RESULT_SUMMARY VARCHAR, CREATED_AT TIMESTAMP_NTZ
#             )
#         """).collect()
#     except Exception as e:
#         _record_ai_error("ai_memory_table_setup", e)
#         pass
#     st.session_state["ai_memory_table_checked"] = True


# # ──────────────────────────────────────────────
# # PSI HELPERS  (Price Sensitivity Index)
# # The PSI → margin mapping below remains a deterministic lookup because it
# # feeds directly into the actual selling-price calculation (a financial
# # number, not a narrative). What IS now AI-generated is the accompanying
# # business explanation / recommendation shown to the user — see
# # ai_psi_recommendation() further below, used at the point of display.
# # ──────────────────────────────────────────────

# def get_psi_margin(psi: float) -> tuple[float, str]:
#     """
#     Return (margin_pct_as_decimal, recommendation_label) based on PSI value.
#     These are the only margin rules used in the Pricing Engine — never hardcode 35%.
#     """
#     if psi >= 0.80:
#         return 0.08, "Highly Price Sensitive"
#     elif psi >= 0.60:
#         return 0.15, "Competitive Pricing"
#     elif psi >= 0.40:
#         return 0.22, "Balanced Pricing"
#     elif psi >= 0.20:
#         return 0.30, "Premium Pricing"
#     else:
#         return 0.40, "Maximum Margin"


# def get_psi_recommendation(psi: float) -> str:
#     """Deterministic fallback text — used only if Cortex AI is unavailable."""
#     if psi >= 0.80:
#         return "Highly price-sensitive customer. Reduce margin to improve probability of winning the order."
#     elif psi >= 0.60:
#         return "Customer is price conscious. Maintain competitive pricing."
#     elif psi >= 0.40:
#         return "Balanced pricing strategy recommended."
#     elif psi >= 0.20:
#         return "Customer accepts premium pricing. Higher margins can be maintained."
#     else:
#         return "Very low price sensitivity. Maximum margin opportunity."


# def get_psi_score(psi: float) -> int:
#     """
#     Pricing Sensitivity Score = 100 - (PSI × 100).
#     Higher score = more margin opportunity.
#     """
#     return max(0, min(100, int(100 - (psi * 100))))


# def get_psi_score_label(score: int) -> tuple[str, str]:
#     """Return (status_label, hex_color) for a PSI score."""
#     if score >= 80:
#         return "🟢 Maximum Margin Opportunity", "#00C7B2"
#     elif score >= 60:
#         return "🔵 Premium Opportunity", "#38BDF8"
#     elif score >= 40:
#         return "🟡 Balanced", "#F59E0B"
#     elif score >= 20:
#         return "🟠 Sensitive", "#F97316"
#     else:
#         return "🔴 Very Sensitive", "#EF4444"


# def ai_psi_recommendation(psi_val, segment, margin_pct, margin_label, customer):
#     """AI_COMPLETE-generated PSI pricing recommendation (replaces the fixed
#     get_psi_recommendation() string at the point of display). Falls back
#     to the deterministic text if Cortex is unavailable."""
#     prompt = (
#         f"You are a B2B manufacturing pricing strategist. Customer '{customer}' "
#         f"belongs to segment '{segment}' with a Price Sensitivity Index of {psi_val:.2f} "
#         f"(0=insensitive, 1=highly sensitive). Recommended margin tier is {margin_pct:.0f}% "
#         f"({margin_label}). In 1-2 sentences, explain the pricing strategy and why, "
#         f"in plain business language for an executive."
#     )
#     ai_text = ai_complete(prompt, cache_key=_ai_cache_key("psi_rec", customer, psi_val, margin_pct))
#     return ai_or_fallback(ai_text, get_psi_recommendation(psi_val))


# def ai_capacity_recommendation(utilization, plant_name, modifier_pct, status_label):
#     """AI_COMPLETE-generated Capacity Utilization business impact +
#     recommendation (replaces the fixed get_capacity_recommendation() string
#     at the point of display)."""
#     prompt = (
#         f"Plant '{plant_name}' is running at {utilization:.1f}% utilization "
#         f"({status_label}), triggering a {modifier_pct:+.0f}% capacity pricing modifier. "
#         f"In 1-2 sentences, explain the business impact and recommend a production/pricing "
#         f"action for an operations executive."
#     )
#     ai_text = ai_complete(prompt, cache_key=_ai_cache_key("cap_rec", plant_name, utilization))
#     return ai_or_fallback(ai_text, get_capacity_recommendation(utilization))


# def ai_win_probability_explanation(win_probability, customer, sku, psi, discount_pct,
#                                     capacity_mod_pct, competitor_avg, final_price, gap_pct):
#     """AI_COMPLETE-generated explanation of the predicted Win Probability
#     and recommended action (replaces the fixed if/elif recommendation
#     string in the Win Probability Predictor)."""
#     market_line = (
#         f"priced {gap_pct:+.1f}% vs a competitor market average of ₹{competitor_avg:,.2f}"
#         if competitor_avg is not None else "no competitor market data available"
#     )
#     prompt = (
#         f"A deal for customer '{customer}' on product '{sku}' has a predicted win "
#         f"probability of {win_probability:.0f}%. Inputs: Price Sensitivity Index {psi:.2f}, "
#         f"customer discount {discount_pct:.1f}%, capacity pricing modifier {capacity_mod_pct:+.0f}%, "
#         f"final price ₹{final_price:,.2f}, {market_line}. "
#         f"In 2 short sentences, explain why the win probability is at this level and "
#         f"recommend one concrete action to a sales/pricing manager."
#     )
#     ai_text = ai_complete(prompt, cache_key=_ai_cache_key("wp_rec", customer, sku, round(win_probability)))
#     fallback = (
#         "Maintain current pricing. Excellent winning probability." if win_probability > 85
#         else "Slight price adjustment may improve competitiveness." if win_probability >= 60
#         else "High deal risk. Consider increasing discount or reviewing pricing."
#     )
#     return ai_or_fallback(ai_text, fallback)


# def ai_discount_justification(customer, sku, current_discount, recommended_discount,
#                                current_profit, recommended_profit, recommended_win_prob):
#     """AI_COMPLETE-generated business justification for the Smart Discount
#     Optimizer's recommended discount level (replaces the fixed string
#     concatenation logic)."""
#     prompt = (
#         f"Customer '{customer}', product '{sku}'. Current discount {current_discount:.1f}% "
#         f"(profit ₹{current_profit if current_profit is not None else 0:,.2f}). "
#         f"Recommended discount {recommended_discount:.0f}% (profit ₹"
#         f"{recommended_profit if recommended_profit is not None else 0:,.2f}, "
#         f"win probability {recommended_win_prob:.0f}%). "
#         f"In 1-2 sentences, justify this discount recommendation to a deal desk manager."
#     )
#     ai_text = ai_complete(prompt, cache_key=_ai_cache_key("disc_just", customer, sku, recommended_discount))
#     fallback = (
#         f"Recommended discount {recommended_discount:.0f}% balances profit and win probability "
#         f"({recommended_win_prob:.0f}%)."
#     )
#     return ai_or_fallback(ai_text, fallback)


# # ──────────────────────────────────────────────
# # HERO BANNER
# # ──────────────────────────────────────────────

# st.markdown("""
# <div class="hero-banner">
#     <div class="hero-inner">
#         <div class="hero-badge">✦ Snowflake Native · Cortex AI · Deal Desk Ready</div>
#         <div class="hero-title">Pricing <span>Intelligence</span> Platform</div>
#         <div class="hero-sub">
#             A premium discrete-manufacturing pricing workspace for cost-to-price simulation,
#             demand elasticity, customer agreements, digital-twin analysis, contract review,
#             and AI-guided pricing strategy.
#         </div>
#         <div class="hero-pills">
#             <div class="hero-pill">💰 <strong>Cost-to-Price</strong> Engine</div>
#             <div class="hero-pill">📈 <strong>Demand</strong> Elasticity</div>
#             <div class="hero-pill">🧾 <strong>Customer</strong> Agreements</div>
#             <div class="hero-pill">🧠 <strong>AI</strong> Strategy Advisor</div>
#         </div>
#     </div>
# </div>
# """, unsafe_allow_html=True)


# # ──────────────────────────────────────────────
# # CORTEX AI DIAGNOSTICS   (NEW — fixes silent "AI not working everywhere")
# # A one-click connectivity test so failures are visible instead of every
# # card just quietly showing "AI Unavailable". Also lets you override the
# # model name in-session without editing code — the single most common
# # reason every AI call fails at once is that the default model
# # ("llama3.1-70b") isn't enabled for a given Snowflake account/region.
# # ──────────────────────────────────────────────

# _init_state("ai_model_override", None)

# with st.expander("🔧 Cortex AI Diagnostics — click if AI cards show 'AI Unavailable'", expanded=False):
#     dcol1, dcol2, dcol3 = st.columns([2, 1, 1])
#     with dcol1:
#         model_choice = st.selectbox(
#             "AI_COMPLETE model to use",
#             # NOTE: mistral-large (v1) was deprecated July 8, 2026 — removed from this
#             # list. mistral-large2 is the current replacement.
#             ["llama3.1-70b", "llama3.1-8b", "llama3.3-70b", "mistral-large2",
#              "snowflake-arctic", "reka-flash", "claude-3-5-sonnet"],
#             index=0,
#             help="If every AI card fails, the model above is most likely not enabled "
#                  "for your Snowflake account/region, or has been deprecated. Pick a "
#                  "different one and re-test."
#         )
#         if model_choice != (st.session_state["ai_model_override"] or "llama3.1-70b"):
#             st.session_state["ai_model_override"] = model_choice
#             st.session_state["ai_cache"] = {}  # clear cache so the new model actually gets used
#     with dcol2:
#         run_test = st.button("▶️ Test Connection", use_container_width=True)
#     with dcol3:
#         if st.button("🗑️ Clear AI Cache", use_container_width=True,
#                       help="Forces every AI card to re-ask Cortex on the next interaction, "
#                            "instead of reusing a cached result from earlier in this session."):
#             st.session_state["ai_cache"] = {}
#             st.session_state["ai_last_error"] = None
#             st.success("AI cache cleared — cards will re-query Cortex on next interaction.")

#     if run_test:
#         test_model = st.session_state["ai_model_override"] or "llama3.1-70b"
#         try:
#             test_row = session.sql(
#                 f"SELECT AI_COMPLETE('{test_model}', 'Reply with exactly the word: OK') AS RESP"
#             ).collect()
#             test_resp = test_row[0]["RESP"] if test_row else None
#             if test_resp:
#                 st.success(f"✅ AI_COMPLETE responded using model '{test_model}': {test_resp!r}")
#             else:
#                 st.warning(f"⚠️ AI_COMPLETE ran but returned an empty response using model '{test_model}'.")
#         except Exception as e:
#             st.error(f"❌ AI_COMPLETE failed with model '{test_model}': {type(e).__name__}: {e}")
#             st.info(
#                 "Typical fixes: (1) try a different model from the dropdown above — model "
#                 "availability and deprecation vary by Snowflake account/region/edition; "
#                 "(2) confirm your role has USAGE on Cortex AI functions "
#                 "(`GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_role>;`); "
#                 "(3) confirm Cortex AI functions are enabled for your account region "
#                 "(some regions require cross-region inference to be enabled)."
#             )

#     stats = st.session_state.get("ai_call_stats", {"ok": 0, "fail": 0})
#     st.caption(
#         f"This session: {stats['ok']} successful Cortex calls · {stats['fail']} failed calls. "
#         f"Failed AI calls are never cached, so cards automatically retry once the "
#         f"underlying issue (e.g. wrong model, permissions) is fixed — you generally "
#         f"don't need to hit 'Clear AI Cache' unless you want an immediate re-check."
#     )
#     if st.session_state.get("ai_last_error"):
#         st.code(st.session_state["ai_last_error"])


# # ──────────────────────────────────────────────
# # TABS
# # ──────────────────────────────────────────────

# # ──────────────────────────────────────────────
# # NAVIGATION — single-render (kills the tab flicker permanently).
# # st.tabs() paints EVERY tab body on every rerun and only hides the
# # inactive ones via CSS afterwards, so a heavy 9-tab app flashes all
# # content on each switch. Rendering only the selected tab removes the
# # flash completely AND stops every tab's Cortex calls firing each rerun.
# # ──────────────────────────────────────────────
# _TAB_LABELS = [
#     "🏠 Overview",
#     "🏢 Executive Decision Center",
#     "💰 Price Engine",
#     "⚙️ Simulation Hub",
#     "🌍 Digital Twin",
#     "🧠 AI Advisor",
#     "📄 Contract Analyzer",
#     "🏆 Competitor Pricing",
#     "📈 AI Demand Forecasting",
# ]
# _active_tab = st.radio(
#     "Navigate", _TAB_LABELS, horizontal=True,
#     label_visibility="collapsed", key="main_nav_tab")
# divider()


# st.markdown("""
# <style>
# div[role="radiogroup"] { gap:.35rem; flex-wrap:wrap; }
# div[role="radiogroup"] > label {
#     background:rgba(255,255,255,.04);
#     border:1px solid rgba(255,255,255,.08);
#     border-radius:10px; padding:8px 14px; margin:0 !important;
#     cursor:pointer; transition:all .15s ease;
# }
# div[role="radiogroup"] > label:hover { background:rgba(56,189,248,.12); }
# div[role="radiogroup"] > label > div:first-child { display:none; } /* hide radio dot */
# </style>
# """, unsafe_allow_html=True)

# # ════════════════════════════════════════════
# # TAB 1 — EXECUTIVE OVERVIEW  (unchanged — pure KPIs/charts, no business rules)
# # ════════════════════════════════════════════

# if _active_tab == "🏠 Overview":

#     section("📊", "Business KPIs")

#     try:
#         pricing_df = session.sql("""
#             SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING
#         """).to_pandas()

#         total_products = pricing_df["SKU"].nunique()
#         avg_cost       = pricing_df["TOTAL_COST"].mean()
#         avg_target     = pricing_df["TARGET_PRICE"].mean()
#         avg_customer   = pricing_df["DISCOUNTED_PRICE"].mean()

#         c1, c2, c3, c4 = st.columns(4)
#         c1.metric("Products Tracked",   f"{total_products}")
#         c2.metric("Avg Cost",           f"₹{avg_cost:,.0f}")
#         c3.metric("Avg Target Price",   f"₹{avg_target:,.0f}")
#         c4.metric("Avg Customer Price", f"₹{avg_customer:,.0f}")

#     except Exception as e:
#         st.info(f"KPI data unavailable: {e}")
#         pricing_df = pd.DataFrame()

#     divider()

#     col_l, col_r = st.columns(2)

#     with col_l:
#         section("📈", "Target Price by Product")
#         if not pricing_df.empty:
#             price_chart = pricing_df[["SKU","TARGET_PRICE"]].drop_duplicates()
#             st.bar_chart(price_chart.set_index("SKU"), height=220)
#         else:
#             st.info("No data.")

#     with col_r:
#         section("🎯", "Customer Discount Analysis")
#         try:
#             discount_df = session.sql("""
#                 SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
#             """).to_pandas()
#             num_cols = discount_df.select_dtypes("number").columns.tolist()
#             if num_cols:
#                 st.bar_chart(discount_df.set_index("CUSTOMER_ID")[num_cols], height=220)
#         except Exception as e:
#             st.info(f"Discount data unavailable: {e}")

#     divider()
#     section("💹", "Profit Analysis")

#     if not pricing_df.empty:
#         profit_df = pricing_df.copy()
#         profit_df["PROFIT"]   = profit_df["DISCOUNTED_PRICE"] - profit_df["TOTAL_COST"]
#         profit_df["MARGIN %"] = (profit_df["PROFIT"] / profit_df["TOTAL_COST"] * 100).round(1)

#         col_t, col_c = st.columns([2, 1])
#         with col_t:
#             st.dataframe(
#                 profit_df[["SKU","CUSTOMER_ID","TOTAL_COST","DISCOUNTED_PRICE","PROFIT","MARGIN %"]],
#                 use_container_width=True, hide_index=True
#             )
#         with col_c:
#             section("🏆", "Most Profitable Products")
#             top = (
#                 profit_df.groupby("SKU")["PROFIT"]
#                 .mean().reset_index()
#                 .sort_values("PROFIT", ascending=False)
#                 .rename(columns={"PROFIT": "Avg Profit"})
#             )
#             st.dataframe(top, use_container_width=True, hide_index=True)

#     divider()
#     section("📜", "Recent Simulations")

#     try:
#         history_df = session.sql("""
#             SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
#             ORDER BY CREATED_AT DESC LIMIT 20
#         """).to_pandas()
#         st.dataframe(history_df, use_container_width=True, hide_index=True)
#     except Exception:
#         st.info("No simulation history yet. Run a simulation in the Simulation Hub tab.")



# # ============================================================================
# # 🏢 EXECUTIVE DECISION CENTER   — AI-integrated
# #============================================================================

# if _active_tab == "🏢 Executive Decision Center":
#     # ------------------------------------------------------------------
#     # Load core tables once, safely. Every downstream block checks
#     # `.empty` / column existence before using these, so a missing table
#     # degrades gracefully instead of crashing the whole tab.
#     # ------------------------------------------------------------------
#     def _safe_load(query: str) -> pd.DataFrame:
#         try:
#             return session.sql(query).to_pandas()
#         except Exception:
#             return pd.DataFrame()

#     pricing_df   = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING")
#     matrix_df    = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX")
#     psi_df       = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.PRICE_SENSITIVITY")
#     capacity_df  = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY")
#     agreements_df = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS")
#     surcharge_df = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.DYNAMIC_SURCHARGES")

#     # Derive PROFIT / MARGIN % on the base pricing table once, reused everywhere below.
#     if not pricing_df.empty and {"DISCOUNTED_PRICE", "TOTAL_COST"}.issubset(pricing_df.columns):
#         pricing_df["PROFIT"]   = pricing_df["DISCOUNTED_PRICE"] - pricing_df["TOTAL_COST"]
#         pricing_df["MARGIN_PCT"] = (pricing_df["PROFIT"] / pricing_df["TOTAL_COST"] * 100).round(1)
#     else:
#         pricing_df["PROFIT"] = pd.Series(dtype=float)
#         pricing_df["MARGIN_PCT"] = pd.Series(dtype=float)

#     # ASSUMPTION: OPTIMIZED_PRICING_MATRIX carries WIN_PROBABILITY per SKU/customer
#     win_col = "WIN_PROBABILITY" if "WIN_PROBABILITY" in matrix_df.columns else None

#     # ASSUMPTION: PRICE_SENSITIVITY carries a PSI_SCORE (0-1 or 0-100) per SKU
#     psi_col = "PSI_SCORE" if "PSI_SCORE" in psi_df.columns else None

#     # ASSUMPTION: PLANT_CAPACITY carries a UTILIZATION_PCT per plant
#     util_col = "UTILIZATION_PCT" if "UTILIZATION_PCT" in capacity_df.columns else None

#     # ASSUMPTION: CUSTOMER_AGREEMENTS carries DISCOUNT_PCT and CONTRACT_ID per customer
#     discount_col = "DISCOUNT_PCT" if "DISCOUNT_PCT" in agreements_df.columns else None
#     contract_col = "CONTRACT_ID" if "CONTRACT_ID" in agreements_df.columns else None

#     # ========================================================================
#     # 1. EXECUTIVE KPI CARDS  (deterministic — unchanged)
#     # ========================================================================
#     section("🏢", "Executive Decision Center")
#     st.caption("CEO / CFO level summary — consolidates every pricing module, now with Cortex AI-generated insight.")
#     divider()

#     section("📊", "Executive KPI Cards")
#     try:
#         total_revenue = pricing_df["DISCOUNTED_PRICE"].sum() if "DISCOUNTED_PRICE" in pricing_df.columns else 0
#         gross_profit  = pricing_df["PROFIT"].sum() if "PROFIT" in pricing_df.columns else 0
#         avg_margin    = pricing_df["MARGIN_PCT"].mean() if "MARGIN_PCT" in pricing_df.columns else 0
#         avg_win_prob  = matrix_df[win_col].mean() if win_col else None
#         active_customers = pricing_df["CUSTOMER_ID"].nunique() if "CUSTOMER_ID" in pricing_df.columns else 0

#         # Pricing Health Score is computed in full in Section 10; a light
#         # version is shown here so the top KPI row is complete on its own.
#         health_score_preview = None
#         health_inputs = []
#         if psi_col:
#             health_inputs.append(psi_df[psi_col].mean())
#         if not pd.isna(avg_margin):
#             health_inputs.append(min(avg_margin, 100))
#         if avg_win_prob is not None:
#             health_inputs.append(avg_win_prob * 100 if avg_win_prob <= 1 else avg_win_prob)
#         if health_inputs:
#             health_score_preview = sum(health_inputs) / len(health_inputs)

#         k1, k2, k3, k4, k5, k6 = st.columns(6)
#         k1.metric("Total Revenue",  f"₹{total_revenue:,.0f}")
#         k2.metric("Gross Profit",   f"₹{gross_profit:,.0f}")
#         k3.metric("Avg Margin",     f"{avg_margin:,.1f}%" if not pd.isna(avg_margin) else "N/A")
#         k4.metric("Pricing Health", f"{health_score_preview:,.0f}/100" if health_score_preview is not None else "N/A")
#         k5.metric("Avg Win Prob.",  f"{avg_win_prob:,.1f}%" if avg_win_prob is not None else "N/A")
#         k6.metric("Active Customers", f"{active_customers}")
#     except Exception as e:
#         st.info(f"Executive KPI data unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 2. BUSINESS SNAPSHOT  (deterministic — unchanged)
#     # ========================================================================
#     section("📸", "Business Snapshot")
#     try:
#         total_customers = pricing_df["CUSTOMER_ID"].nunique() if "CUSTOMER_ID" in pricing_df.columns else 0
#         total_products   = pricing_df["SKU"].nunique() if "SKU" in pricing_df.columns else 0
#         avg_selling_price = pricing_df["DISCOUNTED_PRICE"].mean() if "DISCOUNTED_PRICE" in pricing_df.columns else 0
#         avg_cost           = pricing_df["TOTAL_COST"].mean() if "TOTAL_COST" in pricing_df.columns else 0
#         total_contracts     = agreements_df[contract_col].nunique() if contract_col else agreements_df.shape[0]

#         s1, s2, s3, s4, s5 = st.columns(5)
#         s1.metric("Total Customers",     f"{total_customers}")
#         s2.metric("Total Products",      f"{total_products}")
#         s3.metric("Avg Selling Price",   f"₹{avg_selling_price:,.0f}")
#         s4.metric("Avg Cost",            f"₹{avg_cost:,.0f}")
#         s5.metric("Total Contracts",     f"{total_contracts}")
#     except Exception as e:
#         st.info(f"Business snapshot unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 3. EXECUTIVE ALERTS  — AI_FILTER (significance gate) + AI_COMPLETE (text)
#     #    Replaces the old bare "if count > 0" thresholds-only logic.
#     # ========================================================================
#     section("🚨", "Executive Alerts")
#     alerts = []
#     try:
#         alert_candidates = []  # (level, kind, raw_signal) — raw numeric detection stays deterministic

#         if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
#             leak_count = (pricing_df["MARGIN_PCT"] < 5).sum()
#             if leak_count > 0:
#                 alert_candidates.append(("error", "margin_leakage",
#                     f"{leak_count} SKU/customer combinations are operating below 5% margin."))

#         if util_col and not capacity_df.empty:
#             near_max = (capacity_df[util_col] >= 90).sum()
#             if near_max > 0:
#                 alert_candidates.append(("warning", "capacity",
#                     f"{near_max} plant(s) are running at 90%+ utilization."))

#         if win_col and not matrix_df.empty:
#             low_win = (matrix_df[win_col] < 0.4).sum() if matrix_df[win_col].max() <= 1 else (matrix_df[win_col] < 40).sum()
#             if low_win > 0:
#                 alert_candidates.append(("warning", "win_probability",
#                     f"{low_win} deals are below 40% likelihood to win."))

#         if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
#             high_profit = (pricing_df["MARGIN_PCT"] > 30).sum()
#             if high_profit > 0:
#                 alert_candidates.append(("success", "high_profit",
#                     f"{high_profit} combinations are above 30% margin."))

#         for level, kind, raw_signal in alert_candidates:
#             # AI_FILTER decides whether this signal is significant enough for
#             # an executive alert (replaces the previous "count > 0" gate).
#             is_significant = ai_filter(
#                 f"Is this business signal significant enough to raise as an executive "
#                 f"pricing alert? Signal: {raw_signal}",
#                 cache_key=_ai_cache_key("alert_filter", kind, raw_signal)
#             )
#             if is_significant is False:
#                 continue  # AI judged it not significant; fail-open (show) if AI unavailable

#             ai_msg = ai_complete(
#                 f"Write one short executive alert sentence (max 25 words) for a "
#                 f"manufacturing pricing dashboard about this signal: {raw_signal} "
#                 f"Category: {kind}. Be direct and actionable.",
#                 cache_key=_ai_cache_key("alert_text", kind, raw_signal)
#             )
#             icon = "🔴" if level == "error" else "🟡" if level == "warning" else "🟢"
#             msg  = f"{icon} {ai_msg}" if ai_msg else f"{icon} {raw_signal}"
#             alerts.append((level, msg))

#         if alerts:
#             for level, msg in alerts:
#                 getattr(st, level)(msg)
#         else:
#             st.info("No alerts triggered — all monitored metrics are within normal thresholds.")
#     except Exception as e:
#         st.info(f"Executive alerts unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 4. TOP OPPORTUNITIES — AI-generated suggested action + expected benefit
#     #    Replaces the hardcoded _suggest_action() if/elif rule. One batched
#     #    AI_COMPLETE call covers the whole table (not one call per row).
#     # ========================================================================
#     section("🚀", "Top Opportunities")
#     top_opps = pd.DataFrame()
#     try:
#         if not pricing_df.empty and {"CUSTOMER_ID", "SKU", "MARGIN_PCT"}.issubset(pricing_df.columns):
#             top_candidates = pricing_df.sort_values("MARGIN_PCT", ascending=False).head(10).reset_index(drop=True)

#             rows_text = "\n".join(
#                 f"{i+1}. Customer={row['CUSTOMER_ID']}, Product={row['SKU']}, Margin={row['MARGIN_PCT']:.1f}%"
#                 for i, row in top_candidates.iterrows()
#             )
#             ai_json = parse_ai_json(ai_complete(
#                 f"For each pricing opportunity row below, suggest one short action "
#                 f"(2-4 words, e.g. 'Increase Price', 'Reduce Discount', 'Increase Production') "
#                 f"and one short expected benefit (2-4 words, e.g. 'Higher Profit'). "
#                 f"Return ONLY a JSON array (no markdown), one object per row in the same order, "
#                 f"each object having keys 'suggested_action' and 'expected_benefit'.\nRows:\n{rows_text}",
#                 cache_key=_ai_cache_key("top_opps", rows_text)
#             ))

#             def _fallback_action(row):
#                 if row["MARGIN_PCT"] > 30:
#                     return "Increase Price", "Higher Profit"
#                 elif row["MARGIN_PCT"] > 20:
#                     return "Premium Pricing", "Revenue Growth"
#                 elif discount_col and row["CUSTOMER_ID"] in agreements_df.get("CUSTOMER_ID", pd.Series()).values:
#                     return "Reduce Discount", "Better Margin"
#                 else:
#                     return "Increase Production", "Volume Growth"

#             actions, benefits = [], []
#             for i, row in top_candidates.iterrows():
#                 if ai_json and i < len(ai_json) and isinstance(ai_json[i], dict):
#                     actions.append(ai_json[i].get("suggested_action", "N/A"))
#                     benefits.append(ai_json[i].get("expected_benefit", "N/A"))
#                 else:
#                     a, b = _fallback_action(row)
#                     actions.append(a); benefits.append(b)

#             top_opps = top_candidates.copy()
#             top_opps["SUGGESTED_ACTION"] = actions
#             top_opps["EXPECTED_BENEFIT"] = benefits
#             top_opps = top_opps[["CUSTOMER_ID", "SKU", "SUGGESTED_ACTION", "EXPECTED_BENEFIT"]].rename(
#                 columns={"CUSTOMER_ID": "Customer", "SKU": "Product"}
#             )
#             st.dataframe(top_opps, use_container_width=True, hide_index=True)
#         else:
#             st.info("Not enough data to compute top opportunities.")
#     except Exception as e:
#         st.info(f"Top opportunities unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 5. TOP RISKS — AI_CLASSIFY for severity (replaces hardcoded "High"/"Medium")
#     # ========================================================================
#     section("⚠️", "Top Risks")
#     risk_rows = []
#     try:
#         def _ai_severity(risk_type, detail, fallback):
#             label = ai_classify(
#                 f"Risk type: {risk_type}. Detail: {detail}. Classify the severity of this "
#                 f"manufacturing pricing/business risk for an executive risk register.",
#                 ["Critical", "High", "Medium", "Low"],
#                 cache_key=_ai_cache_key("risk_sev", risk_type, detail)
#             )
#             return label if label else fallback

#         if not pricing_df.empty and {"CUSTOMER_ID", "MARGIN_PCT"}.issubset(pricing_df.columns):
#             leakage = pricing_df[pricing_df["MARGIN_PCT"] < 5]
#             for _, row in leakage.head(5).iterrows():
#                 detail = f"Customer {row['CUSTOMER_ID']} margin at {row['MARGIN_PCT']:.1f}%"
#                 risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Margin Leakage",
#                                    "Severity": _ai_severity("Margin Leakage", detail, "High")})

#         if not agreements_df.empty and contract_col and "CUSTOMER_ID" in agreements_df.columns:
#             if "MARGIN_PCT" in agreements_df.columns:
#                 risky_contracts = agreements_df[agreements_df["MARGIN_PCT"] < 0]
#                 for _, row in risky_contracts.head(5).iterrows():
#                     detail = f"Customer {row['CUSTOMER_ID']} contract margin negative"
#                     risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Contract Risk",
#                                        "Severity": _ai_severity("Contract Risk", detail, "Medium")})

#         if util_col and not capacity_df.empty:
#             over_cap = capacity_df[capacity_df[util_col] >= 90]
#             for _, row in over_cap.head(5).iterrows():
#                 plant_label = row.get("PLANT_ID", "Plant")
#                 detail = f"Plant {plant_label} utilization {row[util_col]:.1f}%"
#                 risk_rows.append({"Customer": plant_label, "Risk Type": "Capacity Risk",
#                                    "Severity": _ai_severity("Capacity Risk", detail, "High")})

#         if win_col and not matrix_df.empty and "CUSTOMER_ID" in matrix_df.columns:
#             threshold = 0.4 if matrix_df[win_col].max() <= 1 else 40
#             low_win_rows = matrix_df[matrix_df[win_col] < threshold]
#             for _, row in low_win_rows.head(5).iterrows():
#                 detail = f"Customer {row['CUSTOMER_ID']} win probability {row[win_col]}"
#                 risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Low Win Probability",
#                                    "Severity": _ai_severity("Low Win Probability", detail, "Medium")})

#         if risk_rows:
#             st.dataframe(pd.DataFrame(risk_rows), use_container_width=True, hide_index=True)
#         else:
#             st.info("No significant risks detected in current data.")
#     except Exception as e:
#         st.info(f"Top risks unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 6. REVENUE DASHBOARD (native charts — SiS has no Plotly)  — unchanged
#     # ========================================================================
#     section("💰", "Revenue Dashboard")
#     try:
#         if not pricing_df.empty and "DISCOUNTED_PRICE" in pricing_df.columns:
#             rev_c1, rev_c2 = st.columns(2)
#             with rev_c1:
#                 st.caption("Revenue by Customer")
#                 rev_by_customer = pricing_df.groupby("CUSTOMER_ID")["DISCOUNTED_PRICE"].sum().sort_values(ascending=False)
#                 st.bar_chart(rev_by_customer, height=260)
#             with rev_c2:
#                 st.caption("Revenue by Product")
#                 rev_by_product = pricing_df.groupby("SKU")["DISCOUNTED_PRICE"].sum().sort_values(ascending=False)
#                 st.bar_chart(rev_by_product, height=260)

#             st.caption("Revenue Distribution")
#             st.bar_chart(pricing_df["DISCOUNTED_PRICE"].sort_values(ascending=False).reset_index(drop=True), height=220)
#         else:
#             st.info("Revenue data unavailable.")
#     except Exception as e:
#         st.info(f"Revenue dashboard unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 7. MARGIN DASHBOARD  — unchanged
#     # ========================================================================
#     section("📉", "Margin Dashboard")
#     try:
#         if not pricing_df.empty and "MARGIN_PCT" in pricing_df.columns:
#             st.caption("Margin Distribution")
#             st.bar_chart(pricing_df["MARGIN_PCT"].sort_values(ascending=False).reset_index(drop=True), height=220)

#             margin_by_product = pricing_df.groupby("SKU")["MARGIN_PCT"].mean().sort_values(ascending=False)
#             mg_c1, mg_c2 = st.columns(2)
#             with mg_c1:
#                 st.caption("Top 10 Profitable Products")
#                 st.bar_chart(margin_by_product.head(10), height=240)
#             with mg_c2:
#                 st.caption("Bottom 10 Products")
#                 st.bar_chart(margin_by_product.tail(10), height=240)
#         else:
#             st.info("Margin data unavailable.")
#     except Exception as e:
#         st.info(f"Margin dashboard unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 8. CUSTOMER INSIGHTS — AI_CLASSIFY segmentation added
#     #    (Strategic / Premium / Growth / Enterprise / Price Sensitive / At Risk)
#     # ========================================================================
#     section("👥", "Customer Insights")
#     try:
#         if not pricing_df.empty and {"CUSTOMER_ID", "DISCOUNTED_PRICE", "PROFIT"}.issubset(pricing_df.columns):
#             cust_agg = pricing_df.groupby("CUSTOMER_ID").agg(
#                 REVENUE=("DISCOUNTED_PRICE", "sum"),
#                 PROFIT=("PROFIT", "sum"),
#             ).reset_index()

#             highest_revenue_cust = cust_agg.loc[cust_agg["REVENUE"].idxmax(), "CUSTOMER_ID"]
#             highest_profit_cust  = cust_agg.loc[cust_agg["PROFIT"].idxmax(), "CUSTOMER_ID"]

#             highest_discount_cust = "N/A"
#             if discount_col and "CUSTOMER_ID" in agreements_df.columns and not agreements_df.empty:
#                 highest_discount_cust = agreements_df.loc[agreements_df[discount_col].idxmax(), "CUSTOMER_ID"]

#             highest_win_cust = "N/A"
#             if win_col and "CUSTOMER_ID" in matrix_df.columns and not matrix_df.empty:
#                 highest_win_cust = matrix_df.loc[matrix_df[win_col].idxmax(), "CUSTOMER_ID"]

#             ci1, ci2, ci3, ci4 = st.columns(4)
#             ci1.metric("Highest Revenue Customer", f"{highest_revenue_cust}")
#             ci2.metric("Highest Profit Customer",  f"{highest_profit_cust}")
#             ci3.metric("Highest Discount Customer", f"{highest_discount_cust}")
#             ci4.metric("Highest Win Prob. Customer", f"{highest_win_cust}")

#             st.caption("Profit vs Revenue")
#             st.scatter_chart(cust_agg, x="REVENUE", y="PROFIT", size=None, height=280)

#             # ── AI Customer Segmentation (NEW) — replaces any hardcoded segmentation rule ──
#             top_customers = cust_agg.sort_values("REVENUE", ascending=False).head(8).reset_index(drop=True)
#             seg_rows_text = "\n".join(
#                 f"{i+1}. Customer={row['CUSTOMER_ID']}, Revenue=₹{row['REVENUE']:,.0f}, Profit=₹{row['PROFIT']:,.0f}"
#                 for i, row in top_customers.iterrows()
#             )
#             seg_json = parse_ai_json(ai_complete(
#                 "Classify each customer below into exactly one segment from this list: "
#                 "Strategic, Premium, Growth, Enterprise, Price Sensitive, At Risk. "
#                 "Base the classification on relative revenue and profit. "
#                 "Return ONLY a JSON array (no markdown), one object per row in the same order, "
#                 "each with key 'segment'.\nRows:\n" + seg_rows_text,
#                 cache_key=_ai_cache_key("cust_seg", seg_rows_text)
#             ))
#             if seg_json:
#                 seg_df = top_customers.copy()
#                 seg_df["AI_SEGMENT"] = [
#                     seg_json[i].get("segment", "N/A") if i < len(seg_json) and isinstance(seg_json[i], dict) else "N/A"
#                     for i in range(len(seg_df))
#                 ]
#                 section("🧭", "AI Customer Segmentation")
#                 st.dataframe(
#                     seg_df.rename(columns={"CUSTOMER_ID": "Customer", "REVENUE": "Revenue", "PROFIT": "Profit", "AI_SEGMENT": "Segment"}),
#                     use_container_width=True, hide_index=True
#                 )
#         else:
#             st.info("Customer insight data unavailable.")
#     except Exception as e:
#         st.info(f"Customer insights unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 9. PRODUCT INSIGHTS — AI product classification added
#     # ========================================================================
#     section("📦", "Product Insights")
#     try:
#         if not pricing_df.empty and {"SKU", "DISCOUNTED_PRICE", "MARGIN_PCT"}.issubset(pricing_df.columns):
#             prod_agg = pricing_df.groupby("SKU").agg(
#                 REVENUE=("DISCOUNTED_PRICE", "sum"),
#                 AVG_MARGIN=("MARGIN_PCT", "mean"),
#             ).reset_index()

#             best_product         = prod_agg.loc[prod_agg["AVG_MARGIN"].idxmax(), "SKU"]
#             worst_product        = prod_agg.loc[prod_agg["AVG_MARGIN"].idxmin(), "SKU"]
#             highest_revenue_prod = prod_agg.loc[prod_agg["REVENUE"].idxmax(), "SKU"]
#             highest_margin_prod  = best_product  # same metric, kept separate per spec for clarity

#             p1, p2, p3, p4 = st.columns(4)
#             p1.metric("Best Product",           f"{best_product}")
#             p2.metric("Worst Product",          f"{worst_product}")
#             p3.metric("Highest Revenue Product", f"{highest_revenue_prod}")
#             p4.metric("Highest Margin Product",  f"{highest_margin_prod}")

#             # ── AI Product Classification (NEW) — replaces fixed business-rule tiers ──
#             top_products = prod_agg.sort_values("REVENUE", ascending=False).head(8).reset_index(drop=True)
#             prod_rows_text = "\n".join(
#                 f"{i+1}. Product={row['SKU']}, Revenue=₹{row['REVENUE']:,.0f}, AvgMargin={row['AVG_MARGIN']:.1f}%"
#                 for i, row in top_products.iterrows()
#             )
#             prod_json = parse_ai_json(ai_complete(
#                 "Classify each product below into exactly one category from this list: "
#                 "Star, Core, Niche, Underperformer. Base the classification on relative "
#                 "revenue and margin. Return ONLY a JSON array (no markdown), one object per "
#                 "row in the same order, each with key 'category'.\nRows:\n" + prod_rows_text,
#                 cache_key=_ai_cache_key("prod_class", prod_rows_text)
#             ))
#             if prod_json:
#                 pcl_df = top_products.copy()
#                 pcl_df["AI_CATEGORY"] = [
#                     prod_json[i].get("category", "N/A") if i < len(prod_json) and isinstance(prod_json[i], dict) else "N/A"
#                     for i in range(len(pcl_df))
#                 ]
#                 section("🧭", "AI Product Classification")
#                 st.dataframe(
#                     pcl_df.rename(columns={"SKU": "Product", "REVENUE": "Revenue", "AVG_MARGIN": "Avg Margin %", "AI_CATEGORY": "Category"}),
#                     use_container_width=True, hide_index=True
#                 )
#         else:
#             st.info("Product insight data unavailable.")
#     except Exception as e:
#         st.info(f"Product insights unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 10. PRICING HEALTH SCORE  — v2: FULLY AI-DRIVEN.
#     #     No weighted average, no manual component weights. All facts below
#     #     are deterministic arithmetic (means, counts, percentages already
#     #     computed from live tables); the SCORE, LABEL, CONFIDENCE, and
#     #     narrative are entirely Cortex AI's own judgment via the central
#     #     ai_reason_score() pipeline (Build Context -> Historical Context ->
#     #     AI_REASON -> AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE, with retry).
#     # ========================================================================
#     section("🩺", "Pricing Health Score (AI-Generated)")
#     try:
#         fact_lines = []
#         if psi_col and not psi_df.empty:
#             fact_lines.append(f"Average Price Sensitivity Index: {psi_df[psi_col].mean():.2f}")
#         if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
#             fact_lines.append(f"Average margin across all SKU/customer combos: {pricing_df['MARGIN_PCT'].mean():.1f}%")
#             fact_lines.append(f"Share of combos below 5% margin (leakage): {(pricing_df['MARGIN_PCT'] < 5).mean()*100:.1f}%")
#         if win_col and not matrix_df.empty:
#             wv = matrix_df[win_col].mean()
#             fact_lines.append(f"Average win probability: {(wv*100 if wv <= 1 else wv):.1f}%")
#         if util_col and not capacity_df.empty:
#             fact_lines.append(f"Average plant utilization: {capacity_df[util_col].mean():.1f}%")
#         if contract_col and "MARGIN_PCT" in agreements_df.columns and not agreements_df.empty:
#             fact_lines.append(f"Share of contracts with negative margin: {(agreements_df['MARGIN_PCT'] < 0).mean()*100:.1f}%")

#         if fact_lines:
#             health_payload = ai_reason_score(
#                 module="executive_health",
#                 decision_type="pricing_health_score",
#                 context_facts="\n".join(fact_lines),
#                 extra_instruction=(
#                     "Weigh these factors however you judge appropriate for this business — "
#                     "do not use a fixed formula or equal weighting. Consider which factors "
#                     "matter most given their current values."
#                 ),
#                 cache_key=_ai_cache_key("exec_health_v2", "|".join(fact_lines)),
#             )
#             render_ai_score_card(health_payload, title_prefix="Pricing Health")
#             health_score = health_payload.get("score")
#             status = health_payload.get("label", "N/A")
#         else:
#             st.info("Not enough data to compute a Pricing Health Score.")
#             health_score, status = None, "N/A"
#     except Exception as e:
#         st.info(f"Pricing Health Score unavailable: {e}")
#         health_score, status = None, "N/A"

#     divider()

#     # ========================================================================
#     # 11. EXECUTIVE RECOMMENDATIONS — AI_COMPLETE-generated, replaces the
#     #     fixed if/elif recommendation strings entirely.
#     # ========================================================================
#     section("💡", "Executive Recommendations")
#     try:
#         signal_lines = []

#         if not pricing_df.empty and {"SKU", "MARGIN_PCT"}.issubset(pricing_df.columns):
#             underpriced = pricing_df[pricing_df["MARGIN_PCT"] > 30].sort_values("MARGIN_PCT", ascending=False).head(3)
#             for _, row in underpriced.iterrows():
#                 signal_lines.append(f"Product {row['SKU']} margin is {row['MARGIN_PCT']:.1f}% — well above target, room to raise price.")

#         if discount_col and "CUSTOMER_ID" in agreements_df.columns and not agreements_df.empty:
#             high_discount = agreements_df.sort_values(discount_col, ascending=False).head(2)
#             for _, row in high_discount.iterrows():
#                 signal_lines.append(f"Customer {row['CUSTOMER_ID']} currently receives a {row[discount_col]:.1f}% discount — among the highest.")

#         if util_col and not capacity_df.empty:
#             over_cap = capacity_df[capacity_df[util_col] >= 90]
#             if not over_cap.empty:
#                 signal_lines.append(f"{over_cap.shape[0]} plant(s) exceed 90% capacity utilization.")

#         if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
#             low_margin = pricing_df[pricing_df["MARGIN_PCT"] < 5]
#             if not low_margin.empty:
#                 signal_lines.append(f"{low_margin.shape[0]} SKU/customer combinations are below 5% margin.")

#         if "MARGIN_PCT" in agreements_df.columns and not agreements_df.empty:
#             neg_contracts = agreements_df[agreements_df["MARGIN_PCT"] < 0]
#             if not neg_contracts.empty:
#                 signal_lines.append(f"{neg_contracts.shape[0]} contract(s) have negative margin.")

#         if signal_lines:
#             signals_text = "\n".join(f"- {s}" for s in signal_lines)
#             ai_recs_json = parse_ai_json(ai_complete(
#                 "You are a pricing strategy advisor for a discrete manufacturing company. "
#                 "Given the business signals below, write up to 5 short, specific executive "
#                 "recommendations (each under 25 words). Return ONLY a JSON array (no markdown) "
#                 "of objects, each with keys 'text' and 'severity' (one of Critical, Warning, Positive).\n"
#                 f"Signals:\n{signals_text}",
#                 cache_key=_ai_cache_key("exec_recs", signals_text)
#             ))
#             if ai_recs_json:
#                 for rec in ai_recs_json:
#                     if not isinstance(rec, dict):
#                         continue
#                     txt = rec.get("text", "")
#                     sev = str(rec.get("severity", "Warning")).lower()
#                     if "critical" in sev:
#                         st.error(txt)
#                     elif "positive" in sev:
#                         st.success(txt)
#                     else:
#                         st.warning(txt)
#             else:
#                 # Fallback: original deterministic messages
#                 for s in signal_lines:
#                     st.warning(s)
#         else:
#             st.info("No specific recommendations triggered — current pricing is within healthy thresholds.")
#     except Exception as e:
#         st.info(f"Executive recommendations unavailable: {e}")

#     divider()

#     # ========================================================================
#     # 12. EXECUTIVE SUMMARY — AI_COMPLETE-generated narrative, replaces the
#     #     manually assembled markdown bullet list.
#     # ========================================================================
#     section("📝", "Executive Summary")
#     try:
#         summary_business_health = status if "status" in dir() else "N/A"
#         summary_revenue = f"₹{total_revenue:,.0f}" if "total_revenue" in dir() else "N/A"
#         summary_profit  = f"₹{gross_profit:,.0f}" if "gross_profit" in dir() else "N/A"

#         summary_top_opportunity = "N/A"
#         if not top_opps.empty:
#             summary_top_opportunity = f"{top_opps.iloc[0]['Customer']} — {top_opps.iloc[0]['SUGGESTED_ACTION']}"

#         summary_highest_risk = "N/A"
#         if risk_rows:
#             summary_highest_risk = f"{risk_rows[0]['Customer']} — {risk_rows[0]['Risk Type']}"

#         summary_best_product  = best_product if "best_product" in dir() else "N/A"
#         summary_best_customer = highest_profit_cust if "highest_profit_cust" in dir() else "N/A"

#         summary_key_recommendation = "Maintain current pricing strategy."
#         if "underpriced" in dir() and not underpriced.empty:
#             summary_key_recommendation = f"Increase {underpriced.iloc[0]['SKU']} price to capture available margin."

#         facts_block = (
#             f"Business Health: {summary_business_health}\n"
#             f"Revenue: {summary_revenue}\n"
#             f"Profit: {summary_profit}\n"
#             f"Top Opportunity: {summary_top_opportunity}\n"
#             f"Highest Risk: {summary_highest_risk}\n"
#             f"Best Product: {summary_best_product}\n"
#             f"Best Customer: {summary_best_customer}\n"
#             f"Key Recommendation: {summary_key_recommendation}"
#         )

#         ai_narrative = ai_complete(
#             "Turn the following pricing facts into a concise 3-4 sentence executive "
#             "narrative summary suitable for a CEO/CFO briefing. Do not invent numbers "
#             "beyond what's given.\n" + facts_block,
#             cache_key=_ai_cache_key("exec_summary_narrative", facts_block)
#         )

#         if ai_narrative:
#             st.write(ai_narrative)
#             with st.expander("View underlying facts"):
#                 st.markdown(f"""
# - **Business Health:** {summary_business_health}
# - **Revenue:** {summary_revenue}
# - **Profit:** {summary_profit}
# - **Top Opportunity:** {summary_top_opportunity}
# - **Highest Risk:** {summary_highest_risk}
# - **Best Product:** {summary_best_product}
# - **Best Customer:** {summary_best_customer}
# - **Key Recommendation:** {summary_key_recommendation}
# """)
#         else:
#             # Fallback: original deterministic markdown summary
#             st.markdown(f"""
# - **Business Health:** {summary_business_health}
# - **Revenue:** {summary_revenue}
# - **Profit:** {summary_profit}
# - **Top Opportunity:** {summary_top_opportunity}
# - **Highest Risk:** {summary_highest_risk}
# - **Best Product:** {summary_best_product}
# - **Best Customer:** {summary_best_customer}
# - **Key Recommendation:** {summary_key_recommendation}
# """)
#     except Exception as e:
#         st.info(f"Executive summary unavailable: {e}")

# # ════════════════════════════════════════════
# # TAB 2 — PRICE OPTIMIZATION ENGINE  (PSI / CUM / Win Probability / Smart Discount)
# # AI-integrated: recommendation text at every stage is now Cortex-generated,
# # with the original rule-based text kept as a safety-net fallback.
# # ════════════════════════════════════════════
# if _active_tab == "💰 Price Engine":
#     section("🔍", "Price Optimization Engine")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'Find the most profitable selling price using demand elasticity modelling, '
#         'Price Sensitivity Index (PSI), and Cortex AI-generated pricing guidance.</p>',
#         unsafe_allow_html=True
#     )

#     # ── Load product list ──
#     try:
#         sku_df = session.sql("""
#             SELECT SKU, TOTAL_COST
#             FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
#             ORDER BY SKU
#         """).to_pandas()
#     except Exception as e:
#         st.error(f"Failed to load product list: {e}")
#         sku_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

#     col1, col2 = st.columns([1.2, 1])
#     with col1:
#         selected_sku_pe = st.selectbox("Select Product SKU", sku_df["SKU"].tolist(), key="pe_sku")
#     with col2:
#         base_demand_pe = st.number_input(
#             "Expected Monthly Demand (units)", value=1000, step=100, min_value=100, key="pe_demand"
#         )

#     # ── Customer Price Lookup ──
#     divider()
#     section("🧾", "Customer Price Lookup")

#     col_a, col_b = st.columns(2)
#     try:
#         customer_df = session.sql("""
#             SELECT DISTINCT CUSTOMER_ID
#             FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
#             ORDER BY CUSTOMER_ID
#         """).to_pandas()

#         with col_a:
#             selected_sku_cp = st.selectbox("Product SKU", sku_df["SKU"].tolist(), key="cp_sku")
#         with col_b:
#             selected_cust = st.selectbox(
#                 "Customer", customer_df["CUSTOMER_ID"].tolist(), key="cp_cust"
#             )

#         if st.button("🔎 Lookup Customer Price", key="cp_btn"):
#             try:
#                 result_df = session.sql(f"""
#                     SELECT p.SKU, p.PRODUCT_FAMILY, p.TOTAL_COST,
#                            p.FLOOR_PRICE, p.TARGET_PRICE, p.CEILING_PRICE,
#                            c.CUSTOMER_ID, c.DISCOUNTED_PRICE
#                     FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING c
#                     JOIN PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX p ON c.SKU = p.SKU
#                     WHERE p.SKU = '{selected_sku_cp}' AND c.CUSTOMER_ID = '{selected_cust}'
#                     LIMIT 1
#                 """).to_pandas()
#                 st.session_state["cp_result"] = result_df
#             except Exception as e:
#                 st.session_state["cp_result"] = None
#                 st.error(f"Lookup failed: {e}")

#         # Render persisted customer lookup result
#         if st.session_state["cp_result"] is not None:
#             result_df = st.session_state["cp_result"]
#             if result_df.empty:
#                 st.error("No pricing data found for this SKU + Customer combination.")
#             else:
#                 row = result_df.iloc[0]
#                 st.success("✅ Pricing found")
#                 m1,m2,m3,m4,m5 = st.columns(5)
#                 m1.metric("Cost",             f"₹{row['TOTAL_COST']:,.2f}")
#                 m2.metric("Floor Price",      f"₹{row['FLOOR_PRICE']:,.2f}")
#                 m3.metric("Target Price",     f"₹{row['TARGET_PRICE']:,.2f}")
#                 m4.metric("Ceiling Price",    f"₹{row['CEILING_PRICE']:,.2f}")
#                 m5.metric("Discounted Price", f"₹{row['DISCOUNTED_PRICE']:,.2f}")
#                 st.dataframe(result_df, use_container_width=True, hide_index=True)

#     except Exception as e:
#         st.warning(f"Customer lookup unavailable: {e}")

#     # ════════════════════════════════════════════════════════════════════════
#     # PSI — PRICE SENSITIVITY INDEX SECTION
#     # Reads from PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
#     # Uses the customer selected in the Customer Price Lookup above.
#     # Margin tiering stays deterministic (drives the real price calculation);
#     # the recommendation text is now Cortex AI_COMPLETE-generated.
#     # ════════════════════════════════════════════════════════════════════════

#     divider()
#     section("🧠", "Price Sensitivity Analysis")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'PSI-driven margin adjustment — margin tier is derived from the customer\'s '
#         'price sensitivity, and the pricing recommendation is generated by Cortex AI.</p>',
#         unsafe_allow_html=True
#     )

#     # Determine which customer to use for PSI lookup.
#     # Use the customer selected in the Customer Price Lookup widget above.
#     psi_customer = selected_cust if "cp_cust" in st.session_state else None

#     if psi_customer is None:
#         st.info("Select a customer in the Customer Price Lookup section above to load PSI data.")
#     else:
#         # ── Load PSI from Snowflake ──
#         try:
#             psi_df = session.sql(f"""
#                 SELECT
#                     CUSTOMER_ID,
#                     CUSTOMER_SEGMENT,
#                     PRICE_SENSITIVITY_INDEX
#                 FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
#                 WHERE CUSTOMER_ID = '{psi_customer}'
#                 LIMIT 1
#             """).to_pandas()
#         except Exception as e:
#             st.error(f"Could not load PSI data: {e}")
#             psi_df = pd.DataFrame()

#         if psi_df.empty:
#             st.warning(
#                 f"No PSI record found for customer **{psi_customer}**. "
#                 "Ensure the PRICE_SENSITIVITY table contains this customer."
#             )
#         else:
#             psi_row       = psi_df.iloc[0]
#             psi_val       = float(psi_row["PRICE_SENSITIVITY_INDEX"])
#             psi_segment   = str(psi_row["CUSTOMER_SEGMENT"])

#             # ── PSI-derived values — v2: FULLY AI-DRIVEN ──
#             # No PSI>=0.8 lookup table. Cortex AI reasons over the PSI value,
#             # segment, and prior decisions for this customer, and returns its
#             # own recommended margin (a number, used in ONE deterministic
#             # multiplication below to get a price) plus a full score/label/
#             # confidence/reasoning/risks/opportunities/actions payload.
#             psi_payload = ai_reason_score(
#                 module="price_sensitivity",
#                 decision_type="psi_margin_strategy",
#                 context_facts=(
#                     f"Customer: {psi_customer}\nSegment: {psi_segment}\n"
#                     f"Price Sensitivity Index: {psi_val:.2f} (0 = insensitive, 1 = highly sensitive)"
#                 ),
#                 extra_instruction=(
#                     "Determine price sensitivity, elasticity, negotiation difficulty, "
#                     "willingness to pay, margin opportunity, and pricing strategy for this "
#                     "customer. The 'score' field should represent pricing/margin opportunity "
#                     "(higher = more margin room). Also return 'margin_pct', the margin percent "
#                     "(0-100) you recommend charging this customer on top of cost."
#                 ),
#                 numeric_fields={"margin_pct": "recommended margin percent, a number 0-100"},
#                 cache_key=_ai_cache_key("psi_v2", psi_customer, psi_val, psi_segment),
#             )

#             if psi_payload.get("ai_generated") and "margin_pct" in psi_payload:
#                 psi_margin_pct = psi_payload["margin_pct"]
#                 psi_margin_dec = psi_margin_pct / 100.0
#                 psi_margin_label = psi_payload["label"]
#                 psi_score = int(round(psi_payload["score"]))
#                 psi_score_status = psi_payload["label"]
#                 psi_score_color = ("#00C7B2" if psi_score >= 75 else "#38BDF8" if psi_score >= 55
#                                     else "#F59E0B" if psi_score >= 35 else "#EF4444")
#                 psi_recommendation = psi_payload["reasoning"]
#             else:
#                 # AI service unavailable — use a neutral, clearly-labeled state
#                 # rather than silently reintroducing a hardcoded margin table.
#                 st.warning("⚠️ Cortex AI pricing strategy service unavailable — using last-known safe default (10% margin) until AI responds.")
#                 psi_margin_pct, psi_margin_dec = 10.0, 0.10
#                 psi_margin_label = "AI Unavailable"
#                 psi_score, psi_score_status, psi_score_color = 0, "AI Unavailable", "#6B8BAF"
#                 psi_recommendation = "Cortex AI did not return a pricing strategy for this customer."

#             # ── Derive optimized price from cost + PSI margin (deterministic) ──
#             psi_cost = None
#             psi_optimized_price  = None
#             psi_final_price      = None
#             psi_discount_pct     = 0.0

#             if not sku_df.empty and selected_sku_pe in sku_df["SKU"].values:
#                 psi_cost = float(
#                     sku_df[sku_df["SKU"] == selected_sku_pe]["TOTAL_COST"].iloc[0]
#                 )
#                 # Price = Cost × (1 + PSI Margin)
#                 psi_optimized_price = psi_cost * (1 + psi_margin_dec)

#                 # Apply existing customer discount if a lookup result exists
#                 if (
#                     st.session_state["cp_result"] is not None
#                     and not st.session_state["cp_result"].empty
#                 ):
#                     cp_row       = st.session_state["cp_result"].iloc[0]
#                     cp_target    = float(cp_row["TARGET_PRICE"])
#                     cp_discounted= float(cp_row["DISCOUNTED_PRICE"])
#                     # Back-calculate the discount % from the existing customer record
#                     if cp_target > 0:
#                         psi_discount_pct = ((cp_target - cp_discounted) / cp_target) * 100
#                     psi_final_price = psi_optimized_price * (1 - psi_discount_pct / 100)
#                 else:
#                     # No customer lookup done yet — show optimized price without discount
#                     psi_final_price  = psi_optimized_price
#                     psi_discount_pct = 0.0

#             # ── KPI Cards ──
#             kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)
#             kpi1.metric("Price Sensitivity Index", f"{psi_val:.2f}")
#             kpi2.metric("PSI Margin",              f"{psi_margin_pct:.0f}%")
#             if psi_optimized_price is not None:
#                 kpi3.metric("Optimized Price",     f"₹{psi_optimized_price:,.2f}")
#                 kpi4.metric("Final Selling Price", f"₹{psi_final_price:,.2f}")
#             else:
#                 kpi3.metric("Optimized Price",     "Select SKU above")
#                 kpi4.metric("Final Selling Price", "Select SKU above")
#             kpi5.metric("Pricing Score",           f"{psi_score}/100")

#             divider()

#             # ── Pricing Sensitivity Score bar (reuses existing health_bar_html) ──
#             section("📊", "Pricing Sensitivity Score")
#             st.markdown(
#                 health_bar_html(psi_score, psi_score_color, psi_score_status),
#                 unsafe_allow_html=True
#             )

#             divider()

#             # ── PSI Detail cards — left / right ──
#             col_psi_l, col_psi_r = st.columns(2)

#             with col_psi_l:
#                 section("🔍", "Sensitivity Analysis")
#                 st.write(f"• **Customer:** {psi_customer}")
#                 st.write(f"• **Customer Segment:** {psi_segment}")
#                 st.write(f"• **Price Sensitivity Index:** {psi_val:.2f}")
#                 st.write(f"• **Recommended Margin:** {psi_margin_pct:.0f}%  —  {psi_margin_label}")
#                 if psi_optimized_price is not None:
#                     st.write(f"• **Optimized Price:** ₹{psi_optimized_price:,.2f}")
#                     st.write(f"• **Customer Discount:** {psi_discount_pct:.1f}%")
#                     st.write(f"• **Final Selling Price:** ₹{psi_final_price:,.2f}")

#             with col_psi_r:
#                 section("💡", "Pricing Recommendation (Cortex AI)")
#                 # Show appropriately styled banner based on PSI, with AI-generated text
#                 if psi_val >= 0.80:
#                     st.error(f"🔴 {psi_recommendation}")
#                 elif psi_val >= 0.60:
#                     st.warning(f"🟡 {psi_recommendation}")
#                 elif psi_val >= 0.40:
#                     st.info(f"🔵 {psi_recommendation}")
#                 elif psi_val >= 0.20:
#                     st.success(f"🟢 {psi_recommendation}")
#                 else:
#                     st.success(f"🟢 {psi_recommendation}")

#                 # Margin tier reference table
#                 st.markdown(
#                     '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
#                     'Margin Tier Reference</p>',
#                     unsafe_allow_html=True
#                 )
#                 tier_df = pd.DataFrame({
#                     "PSI Range":   ["≥ 0.80", "0.60 – 0.79", "0.40 – 0.59", "0.20 – 0.39", "< 0.20"],
#                     "Margin":      ["8%",      "15%",          "22%",          "30%",          "40%"],
#                     "Strategy":    [
#                         "Highly Price Sensitive",
#                         "Competitive Pricing",
#                         "Balanced Pricing",
#                         "Premium Pricing",
#                         "Maximum Margin",
#                     ],
#                 })
#                 st.dataframe(tier_df, use_container_width=True, hide_index=True)

#             # ── Save PSI results to session state ──
#             st.session_state["psi_results"] = {
#                 "customer":          psi_customer,
#                 "segment":           psi_segment,
#                 "psi":               psi_val,
#                 "margin_pct":        psi_margin_pct,
#                 "margin_label":      psi_margin_label,
#                 "optimized_price":   psi_optimized_price,
#                 "discount_pct":      psi_discount_pct,
#                 "final_price":       psi_final_price,
#                 "score":             psi_score,
#                 "score_status":      psi_score_status,
#                 "recommendation":    psi_recommendation,
#                 "sku":               selected_sku_pe,
#                 "cost":              psi_cost,
#             }

#             divider()

#             # ── Executive Summary ──
#             section("📋", "Executive Summary")

#             exec_lines = [
#                 f"Customer            : {psi_customer}",
#                 f"Customer Segment    : {psi_segment}",
#                 f"Product SKU         : {selected_sku_pe}",
#                 f"Price Sensitivity   : {psi_val:.2f}",
#                 f"Recommended Margin  : {psi_margin_pct:.0f}%  ({psi_margin_label})",
#             ]
#             if psi_cost is not None:
#                 exec_lines += [
#                     f"Original Cost       : ₹{psi_cost:,.2f}",
#                     f"Optimized Price     : ₹{psi_optimized_price:,.2f}",
#                     f"Customer Discount   : {psi_discount_pct:.1f}%",
#                     f"Final Selling Price : ₹{psi_final_price:,.2f}",
#                 ]
#             exec_lines += [
#                 f"Pricing Score       : {psi_score}/100  ({psi_score_status})",
#                 "",
#                 "Recommendation (Cortex AI)",
#                 "-" * 40,
#                 psi_recommendation,
#             ]

#             st.text_area(
#                 "",
#                 "\n".join(exec_lines),
#                 height=280,
#                 key="psi_exec_summary"
#             )

#     # ════════════════════════════════════════════════════════════════════════
#     # END PSI SECTION
#     # ════════════════════════════════════════════════════════════════════════

#     # ════════════════════════════════════════════════════════════════════════
#     # 🏭 PLANT CAPACITY ANALYSIS — Capacity Utilization Modifier (CUM)
#     # Modifier % stays deterministic (feeds the price calculation); the
#     # business impact / recommendation text is now Cortex AI-generated.
#     # ════════════════════════════════════════════════════════════════════════

#     divider()
#     section("🏭", "Plant Capacity Analysis")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'Capacity Utilization Modifier (CUM) — adjusts the PSI-optimized price '
#         'based on how busy the selected plant currently is; the business impact '
#         'narrative is generated by Cortex AI.</p>',
#         unsafe_allow_html=True
#     )

#     if st.session_state["psi_results"] is None:
#         st.info("Complete the Price Sensitivity Analysis above to calculate the Capacity Utilization Modifier.")
#     else:
#         pr = st.session_state["psi_results"]

#         if pr["optimized_price"] is None:
#             st.info("Optimized Price not available yet — select a valid SKU above.")
#         else:
#             # ── Load plant capacity data from Snowflake ──
#             try:
#                 plant_df = session.sql("""
#                     SELECT
#                         PLANT_ID,
#                         PLANT_NAME,
#                         CURRENT_UTILIZATION,
#                         MAX_CAPACITY,
#                         AVAILABLE_CAPACITY
#                     FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY
#                     ORDER BY PLANT_NAME
#                 """).to_pandas()
#             except Exception as e:
#                 st.error(f"Could not load plant capacity data: {e}")
#                 plant_df = pd.DataFrame()

#             if plant_df.empty:
#                 st.warning("No plant capacity data found in PLANT_CAPACITY.")
#             else:
#                 selected_plant_name = st.selectbox(
#                     "Select Plant", plant_df["PLANT_NAME"].tolist(), key="cum_plant"
#                 )
#                 plant_row = plant_df[plant_df["PLANT_NAME"] == selected_plant_name].iloc[0]
#                 plant_utilization   = float(plant_row["CURRENT_UTILIZATION"])
#                 plant_available_cap = float(plant_row["AVAILABLE_CAPACITY"])

#                 # ── Capacity Utilization Modifier — v2: FULLY AI-DRIVEN ──
#                 # No <50/70/85% lookup table. Cortex AI judges production risk,
#                 # capacity health, supply-chain risk, and manufacturing
#                 # flexibility, and returns its own recommended price modifier
#                 # (used in ONE deterministic multiplication below).
#                 cum_payload = ai_reason_score(
#                     module="capacity",
#                     decision_type="capacity_modifier",
#                     context_facts=(
#                         f"Plant: {selected_plant_name}\n"
#                         f"Current utilization: {plant_utilization:.1f}%\n"
#                         f"Available capacity: {plant_available_cap:,.0f} units"
#                     ),
#                     extra_instruction=(
#                         "Determine production risk, capacity health, supply chain risk, and "
#                         "manufacturing flexibility. The 'score' field should represent overall "
#                         "capacity health (higher = healthier). Also return 'modifier_pct', the "
#                         "price adjustment percent you recommend applying to the selling price "
#                         "given this utilization level — can be negative (discount to attract "
#                         "volume) or positive (premium to protect a constrained plant)."
#                     ),
#                     numeric_fields={"modifier_pct": "recommended price modifier percent, a number from -20 to 20"},
#                     cache_key=_ai_cache_key("cum_v2", selected_plant_name, round(plant_utilization, 1)),
#                 )

#                 if cum_payload.get("ai_generated") and "modifier_pct" in cum_payload:
#                     capacity_modifier_dec = cum_payload["modifier_pct"] / 100.0
#                     capacity_status_label = cum_payload["label"]
#                     capacity_health_score = cum_payload["score"]
#                     capacity_status_color = ("green" if capacity_health_score >= 60
#                                               else "orange" if capacity_health_score >= 35 else "red")
#                     capacity_recommendation = cum_payload["reasoning"]
#                 else:
#                     st.warning("⚠️ Cortex AI capacity service unavailable — using a neutral 0% modifier until AI responds.")
#                     capacity_modifier_dec = 0.0
#                     capacity_status_label = "AI Unavailable"
#                     capacity_health_score = 0
#                     capacity_status_color = "orange"
#                     capacity_recommendation = "Cortex AI did not return a capacity assessment for this plant."

#                 # ── Apply CUM to the PSI-optimized price (the one deterministic multiplication) ──
#                 capacity_adjusted_price = pr["optimized_price"] * (1 + capacity_modifier_dec)

#                 # ── Re-apply the SAME customer discount % that PSI already calculated ──
#                 cum_discount_pct = pr["discount_pct"]
#                 cum_final_price  = capacity_adjusted_price * (1 - cum_discount_pct / 100)

#                 # ── KPI Cards ──
#                 cap1, cap2, cap3, cap4 = st.columns(4)
#                 cap1.metric("Current Utilization", f"{plant_utilization:.1f}%")
#                 cap2.metric("Capacity Modifier",   f"{capacity_modifier_dec * 100:+.0f}%")
#                 cap3.metric("Available Capacity",  f"{plant_available_cap:,.0f} units")
#                 cap4.metric("Capacity Status",     capacity_status_label)

#                 cap5, cap6 = st.columns(2)
#                 cap5.metric("Capacity Adjusted Price", f"₹{capacity_adjusted_price:,.2f}")
#                 cap6.metric("Final Selling Price",     f"₹{cum_final_price:,.2f}")

#                 divider()

#                 # ── Capacity Health Score bar (reuses existing health_bar_html) ──
#                 section("📊", "Capacity Health Score")
#                 st.markdown(
#                     health_bar_html(capacity_health_score, capacity_status_color, capacity_status_label),
#                     unsafe_allow_html=True
#                 )

#                 divider()

#                 cum_col_l, cum_col_r = st.columns(2)
#                 with cum_col_l:
#                     section("🔍", "Capacity Details")
#                     st.write(f"• **Plant:** {selected_plant_name}")
#                     st.write(f"• **Current Utilization:** {plant_utilization:.1f}%")
#                     st.write(f"• **Capacity Modifier:** {capacity_modifier_dec * 100:+.0f}%")
#                     st.write(f"• **Available Capacity:** {plant_available_cap:,.0f} units")
#                     st.write(f"• **Status:** {capacity_status_label}")
#                     st.write(f"• **Optimized Price (from PSI):** ₹{pr['optimized_price']:,.2f}")
#                     st.write(f"• **Capacity Adjusted Price:** ₹{capacity_adjusted_price:,.2f}")
#                     st.write(f"• **Customer Discount:** {cum_discount_pct:.1f}%")
#                     st.write(f"• **Final Selling Price:** ₹{cum_final_price:,.2f}")

#                 with cum_col_r:
#                     section("💡", "Capacity Recommendation (Cortex AI)")
#                     if capacity_modifier_dec >= 0.10:
#                         st.error(f"🔴 {capacity_recommendation}")
#                     elif capacity_modifier_dec >= 0.05:
#                         st.warning(f"🟡 {capacity_recommendation}")
#                     else:
#                         st.success(f"🟢 {capacity_recommendation}")

#                     st.markdown(
#                         '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
#                         'Capacity Modifier Reference</p>',
#                         unsafe_allow_html=True
#                     )
#                     cum_tier_df = pd.DataFrame({
#                         "Utilization": ["< 50%", "50 – 70%", "70 – 85%", "> 85%"],
#                         "Modifier":    ["-5%", "0%", "+5%", "+10%"],
#                         "Status":      ["🟢 Under Utilized", "🟢 Normal", "🟡 Busy", "🔴 Near Capacity"],
#                     })
#                     st.dataframe(cum_tier_df, use_container_width=True, hide_index=True)

#                 # ── Save CUM results to session state ──
#                 st.session_state["cum_results"] = {
#                     "plant_name":              selected_plant_name,
#                     "plant_utilization":       plant_utilization,
#                     "available_capacity":      plant_available_cap,
#                     "capacity_modifier_pct":   capacity_modifier_dec * 100,
#                     "capacity_status_label":   capacity_status_label,
#                     "capacity_health_score":   capacity_health_score,
#                     "capacity_recommendation": capacity_recommendation,
#                     "optimized_price":         pr["optimized_price"],
#                     "capacity_adjusted_price": capacity_adjusted_price,
#                     "discount_pct":            cum_discount_pct,
#                     "final_price":             cum_final_price,
#                 }

#                 divider()

#                 # ── Executive Summary (CUM-aware) ──
#                 section("📋", "Executive Summary")

#                 cum_exec_lines = [
#                     f"Plant Name          : {selected_plant_name}",
#                     f"Current Utilization : {plant_utilization:.1f}%",
#                     f"Capacity Modifier   : {capacity_modifier_dec * 100:+.0f}%  ({capacity_status_label})",
#                     f"Optimized Price     : ₹{pr['optimized_price']:,.2f}",
#                     f"Capacity Adj. Price : ₹{capacity_adjusted_price:,.2f}",
#                     f"Customer Discount   : {cum_discount_pct:.1f}%",
#                     f"Final Selling Price : ₹{cum_final_price:,.2f}",
#                     "",
#                     "Recommendation (Cortex AI)",
#                     "-" * 40,
#                     capacity_recommendation,
#                 ]

#                 st.text_area(
#                     "",
#                     "\n".join(cum_exec_lines),
#                     height=260,
#                     key="cum_exec_summary"
#                 )

#     # ════════════════════════════════════════════════════════════════════════
#     # END CUM SECTION
#     # ════════════════════════════════════════════════════════════════════════

#     # ════════════════════════════════════════════════════════════════════════
#     # 🎯 WIN PROBABILITY PREDICTOR
#     # Sits after CUM in the pipeline:
#     # Cost → Price Matrix → PSI → CUM → Win Probability → Customer Discount → Final Price
#     # The win-probability SCORE stays a deterministic business-rule formula
#     # (a real predictive calculation); the EXPLANATION of that score and the
#     # recommended action are now Cortex AI-generated.
#     #
#     # ⚠️ ASSUMPTION: competitor average price is read from
#     #    PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING (SKU, COMPETITOR_AVG_PRICE).
#     # ════════════════════════════════════════════════════════════════════════

#     divider()
#     section("🎯", "Win Probability Predictor")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'Estimates the probability of winning this order using PSI, capacity '
#         'utilization, discount depth, and market position — the explanation and '
#         'recommended action are generated by Cortex AI.</p>',
#         unsafe_allow_html=True
#     )

#     def win_probability_gauge_html(value, color_hex, status_label):
#         """Semi-circle SVG gauge — no external chart library required."""
#         import math
#         angle    = max(min(value, 100), 0) / 100 * 180
#         radius   = 80
#         cx, cy   = 100, 100
#         end_x    = cx - radius * math.cos(math.radians(angle))
#         end_y    = cy - radius * math.sin(math.radians(angle))
#         large_arc = 1 if angle > 180 else 0
#         return f"""
#         <div style="text-align:center;padding-top:6px;">
#             <svg width="220" height="130" viewBox="0 0 200 110">
#                 <path d="M 20 100 A 80 80 0 0 1 180 100"
#                       fill="none" stroke="#1E2A3A" stroke-width="14" stroke-linecap="round"/>
#                 <path d="M 20 100 A 80 80 0 {large_arc} 1 {end_x:.1f} {end_y:.1f}"
#                       fill="none" stroke="{color_hex}" stroke-width="14" stroke-linecap="round"/>
#                 <text x="100" y="88" text-anchor="middle" font-size="30" font-weight="700"
#                       fill="#E8EEF7">{value:.0f}%</text>
#             </svg>
#             <p style="color:#6B8BAF;font-size:13px;margin-top:-6px;">{status_label}</p>
#         </div>
#         """

#     def compute_win_probability(price, psi, discount_pct, capacity_mod_pct, competitor_avg):
#         """
#         v2 NOTE: The headline Win Probability shown to the user comes from
#         the AI-driven ai_reason_score() call above (module="win_probability").
#         This formula is kept ONLY as a fast, lightweight estimator to drive
#         the interactive price-sweep chart further down (9+ points, redrawn
#         on every rerun) — running a live Cortex call per sweep point per
#         rerun would be slow and wasteful. It is intentionally NOT used for
#         any number presented as "the" AI decision.
#         """
#         base_score = 50.0
#         psi_impact = (0.5 - psi) * 20.0

#         gap_pct = None
#         if competitor_avg and competitor_avg > 0:
#             try:
#                 gap_pct = safe_pct_change(competitor_avg, price)
#             except Exception:
#                 gap_pct = ((price - competitor_avg) / competitor_avg) * 100.0
#             competitor_impact = max(min(-gap_pct * 0.6, 20.0), -20.0)
#         else:
#             competitor_impact = 0.0

#         discount_impact = max(min(discount_pct * 0.4, 15.0), 0.0)
#         capacity_impact = -(capacity_mod_pct) * 0.5

#         raw_score = base_score + psi_impact + competitor_impact + discount_impact + capacity_impact
#         clamped   = max(min(raw_score, 100.0), 0.0)
#         return clamped, gap_pct

#     if st.session_state["psi_results"] is None:
#         st.info("Complete the Price Sensitivity Analysis above to calculate Win Probability.")
#     elif st.session_state["psi_results"]["optimized_price"] is None:
#         st.info("Optimized Price not available yet — select a valid SKU above.")
#     else:
#         pr = st.session_state["psi_results"]
#         cr = st.session_state.get("cum_results")  # may be None if plant not selected yet

#         wp_customer   = pr["customer"]
#         wp_segment    = pr["segment"]
#         wp_sku        = pr["sku"]
#         wp_psi        = pr["psi"]
#         wp_cost       = pr["cost"]

#         if cr is not None:
#             wp_base_price        = cr["capacity_adjusted_price"]
#             wp_final_price       = cr["final_price"]
#             wp_discount_pct      = cr["discount_pct"]
#             wp_capacity_mod_pct  = cr["capacity_modifier_pct"]
#             wp_plant_util        = cr["plant_utilization"]
#             wp_plant_name        = cr["plant_name"]
#         else:
#             wp_base_price        = pr["optimized_price"]
#             wp_final_price       = pr["final_price"]
#             wp_discount_pct      = pr["discount_pct"]
#             wp_capacity_mod_pct  = 0.0
#             wp_plant_util        = None
#             wp_plant_name        = None

#         # ── Competitor Market Average ──
#         competitor_avg_price = None
#         try:
#             comp_df = session.sql(f"""
#                 SELECT AVG(COMPETITOR_AVG_PRICE) AS AVG_PRICE
#                 FROM PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING
#                 WHERE SKU = '{wp_sku}'
#             """).to_pandas()
#             if not comp_df.empty and pd.notna(comp_df.iloc[0]["AVG_PRICE"]):
#                 competitor_avg_price = float(comp_df.iloc[0]["AVG_PRICE"])
#         except Exception:
#             competitor_avg_price = None

#         # ── Win Probability — v2: FULLY AI-DRIVEN for the headline decision ──
#         # No "base 50 + PSI impact + competitor impact..." formula for the
#         # number shown to the user. Cortex AI reasons over price, PSI,
#         # discount, capacity posture, and market gap, and returns its own
#         # win-probability judgment plus full reasoning. (The lightweight
#         # deterministic estimator below — see compute_win_probability — is
#         # retained ONLY to drive the fast interactive price-sweep chart
#         # further down, where recomputing via a live Cortex call for every
#         # point on every rerun would be both slow and wasteful; the batched
#         # AI sweep call further down is the AI-generated version of that
#         # chart.)
#         market_gap_pct = (
#             safe_pct_change(competitor_avg_price, wp_final_price) if competitor_avg_price else None
#         )
#         wp_payload = ai_reason_score(
#             module="win_probability",
#             decision_type="deal_win_probability",
#             context_facts=(
#                 f"Customer: {wp_customer} ({wp_segment})\nSKU: {wp_sku}\n"
#                 f"Price Sensitivity Index: {wp_psi:.2f}\nFinal selling price: ₹{wp_final_price:,.2f}\n"
#                 f"Customer discount: {wp_discount_pct:.1f}%\nCapacity price modifier: {wp_capacity_mod_pct:+.0f}%\n"
#                 + (f"Competitor market average: ₹{competitor_avg_price:,.2f} (gap {market_gap_pct:+.1f}%)"
#                    if competitor_avg_price is not None else "No competitor market data available.")
#             ),
#             extra_instruction=(
#                 "Estimate the probability (0-100) that this deal is won. The 'score' field IS "
#                 "the win probability itself."
#             ),
#             cache_key=_ai_cache_key("wp_v2", wp_customer, wp_sku, round(wp_final_price, 2)),
#         )

#         if wp_payload.get("ai_generated"):
#             win_probability = wp_payload["score"]
#             wp_recommendation = wp_payload["reasoning"]
#         else:
#             st.warning("⚠️ Cortex AI win-probability service unavailable — showing a neutral 50% placeholder until AI responds.")
#             win_probability = 50.0
#             wp_recommendation = "Cortex AI did not return a win-probability assessment for this deal."

#         win_probability_dec = win_probability / 100.0

#         expected_revenue = wp_final_price * base_demand_pe * win_probability_dec
#         expected_profit  = (
#             (wp_final_price - wp_cost) * base_demand_pe * win_probability_dec
#             if wp_cost is not None else None
#         )

#         if win_probability > 85:
#             deal_status_label, deal_status_color, deal_status_hex = "🟢 Excellent", "green", "#3DDC97"
#         elif win_probability >= 70:
#             deal_status_label, deal_status_color, deal_status_hex = "🟡 High", "orange", "#FFD84C"
#         elif win_probability >= 50:
#             deal_status_label, deal_status_color, deal_status_hex = "🟠 Moderate", "orange", "#FFB84C"
#         else:
#             deal_status_label, deal_status_color, deal_status_hex = "🔴 High Risk", "red", "#E05C5C"

#         # ── KPI Cards ──
#         wp1, wp2, wp3, wp4 = st.columns(4)
#         wp1.metric("Win Probability",  f"{win_probability:.0f}%")
#         wp2.metric("Expected Revenue", f"₹{expected_revenue:,.2f}")
#         wp3.metric(
#             "Expected Profit",
#             f"₹{expected_profit:,.2f}" if expected_profit is not None else "N/A"
#         )
#         wp4.metric("Deal Status", deal_status_label)

#         divider()

#         gauge_col, detail_col = st.columns([1, 1.2])

#         with gauge_col:
#             section("📈", "Win Probability Gauge")
#             st.markdown(
#                 win_probability_gauge_html(win_probability, deal_status_hex, deal_status_label),
#                 unsafe_allow_html=True
#             )

#         with detail_col:
#             section("🔍", "Market Position")
#             st.write(f"• **Customer:** {wp_customer}  ({wp_segment})")
#             st.write(f"• **SKU:** {wp_sku}")
#             st.write(f"• **PSI:** {wp_psi:.2f}")
#             if wp_plant_util is not None:
#                 st.write(f"• **Plant:** {wp_plant_name}  ({wp_plant_util:.1f}% utilized)")
#             st.write(f"• **Final Selling Price:** ₹{wp_final_price:,.2f}")
#             if competitor_avg_price is not None:
#                 st.write(f"• **Competitor Market Average:** ₹{competitor_avg_price:,.2f}")
#                 st.write(f"• **Market Price Gap:** {market_gap_pct:+.1f}%")
#             else:
#                 st.write("• **Competitor Market Average:** N/A (no competitor data found for this SKU)")
#             st.write(f"• **Customer Discount:** {wp_discount_pct:.1f}%")
#             st.write(f"• **Capacity Modifier:** {wp_capacity_mod_pct:+.0f}%")

#             st.markdown(
#                 health_bar_html(win_probability, deal_status_color, deal_status_label),
#                 unsafe_allow_html=True
#             )

#         divider()

#         section("💡", "Win Probability Recommendation (Cortex AI)")
#         if win_probability > 85:
#             st.success(f"🟢 {wp_recommendation}")
#         elif win_probability >= 60:
#             st.warning(f"🟡 {wp_recommendation}")
#         else:
#             st.error(f"🔴 {wp_recommendation}")

#         divider()

#         section("📊", "Price Sensitivity Simulation")
#         st.markdown(
#             '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#             'How Win Probability, Profit, and Revenue shift as the selling price moves '
#             'around the current final price (discount % held constant).</p>',
#             unsafe_allow_html=True
#         )

#         sim_rows = []
#         for pct_move in range(-20, 21, 5):
#             sim_price = wp_final_price * (1 + pct_move / 100)
#             sim_wp, _ = compute_win_probability(
#                 sim_price, wp_psi, wp_discount_pct, wp_capacity_mod_pct, competitor_avg_price
#             )
#             sim_wp_dec = sim_wp / 100.0
#             sim_revenue = sim_price * base_demand_pe * sim_wp_dec
#             sim_profit  = (
#                 (sim_price - wp_cost) * base_demand_pe * sim_wp_dec
#                 if wp_cost is not None else None
#             )
#             sim_rows.append({
#                 "PRICE_MOVE_%":     pct_move,
#                 "PRICE":            round(sim_price, 2),
#                 "WIN_PROBABILITY":  round(sim_wp, 1),
#                 "EXPECTED_REVENUE": round(sim_revenue, 2),
#                 "EXPECTED_PROFIT":  round(sim_profit, 2) if sim_profit is not None else None,
#             })
#         sim_df = pd.DataFrame(sim_rows)

#         sim_col1, sim_col2 = st.columns(2)

#         with sim_col1:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Price vs Win Probability</p>', unsafe_allow_html=True
#             )
#             st.line_chart(sim_df.set_index("PRICE")[["WIN_PROBABILITY"]], height=240)

#         with sim_col2:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Price vs Expected Revenue</p>', unsafe_allow_html=True
#             )
#             st.line_chart(sim_df.set_index("PRICE")[["EXPECTED_REVENUE"]], height=240)

#         if wp_cost is not None:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Price vs Expected Profit</p>', unsafe_allow_html=True
#             )
#             st.line_chart(sim_df.set_index("PRICE")[["EXPECTED_PROFIT"]], height=240)

#         section("📋", "Simulation Data")
#         st.dataframe(sim_df, use_container_width=True, hide_index=True)

#         st.session_state["win_probability_results"] = {
#             "customer":             wp_customer,
#             "segment":              wp_segment,
#             "sku":                  wp_sku,
#             "psi":                  wp_psi,
#             "plant_name":           wp_plant_name,
#             "plant_utilization":    wp_plant_util,
#             "final_price":          wp_final_price,
#             "base_price":           wp_base_price,
#             "competitor_avg_price": competitor_avg_price,
#             "market_gap_pct":       market_gap_pct,
#             "discount_pct":         wp_discount_pct,
#             "capacity_modifier_pct":wp_capacity_mod_pct,
#             "win_probability":      win_probability,
#             "deal_status":          deal_status_label,
#             "expected_revenue":     expected_revenue,
#             "expected_profit":      expected_profit,
#             "recommendation":       wp_recommendation,
#         }

#         divider()

#         section("📋", "Executive Summary")

#         wp_exec_lines = [
#             f"Customer            : {wp_customer}",
#             f"Product SKU         : {wp_sku}",
#             f"Price Sensitivity   : {wp_psi:.2f}",
#             f"Capacity Utilization: {wp_plant_util:.1f}%" if wp_plant_util is not None else "Capacity Utilization: N/A",
#             (
#                 f"Market Position     : ₹{wp_final_price:,.2f} vs competitor avg "
#                 f"₹{competitor_avg_price:,.2f}  ({market_gap_pct:+.1f}%)"
#                 if competitor_avg_price is not None
#                 else "Market Position     : N/A (no competitor data found)"
#             ),
#             f"Win Probability     : {win_probability:.0f}%  ({deal_status_label})",
#             f"Expected Revenue    : ₹{expected_revenue:,.2f}",
#             f"Expected Profit     : ₹{expected_profit:,.2f}" if expected_profit is not None else "Expected Profit     : N/A",
#             "",
#             "Recommendation (Cortex AI)",
#             "-" * 40,
#             wp_recommendation,
#         ]

#         st.text_area(
#             "",
#             "\n".join(wp_exec_lines),
#             height=280,
#             key="wp_exec_summary"
#         )

#     # ════════════════════════════════════════════════════════════════════════
#     # END WIN PROBABILITY PREDICTOR SECTION
#     # ════════════════════════════════════════════════════════════════════════

#     # ════════════════════════════════════════════════════════════════════════
#     # ⭐ SMART DISCOUNT OPTIMIZER
#     # Discount simulation math stays deterministic; the business
#     # justification for the recommended discount is now Cortex AI-generated.
#     # ════════════════════════════════════════════════════════════════════════

#     divider()
#     section("⭐", "Smart Discount Optimizer")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'Simulates multiple discount levels on top of the PSI + Capacity-adjusted '
#         'price and recommends the discount that maximizes profit while keeping '
#         'Win Probability above 80% — with a Cortex AI-generated justification.</p>',
#         unsafe_allow_html=True
#     )

#     if st.session_state.get("win_probability_results") is None:
#         st.info("Complete the Win Probability Predictor above to run the Smart Discount Optimizer.")
#     else:
#         pr = st.session_state["psi_results"]
#         cr = st.session_state.get("cum_results")
#         wr = st.session_state["win_probability_results"]

#         sdo_customer         = wr["customer"]
#         sdo_segment          = wr["segment"]
#         sdo_sku              = wr["sku"]
#         sdo_psi              = wr["psi"]
#         sdo_cost             = pr["cost"]
#         sdo_capacity_mod_pct = wr["capacity_modifier_pct"]
#         sdo_competitor_avg   = wr["competitor_avg_price"]
#         sdo_current_discount = wr["discount_pct"]

#         sdo_base_price = cr["capacity_adjusted_price"] if cr is not None else pr["optimized_price"]

#         sdo_current_price       = wr["final_price"]
#         sdo_current_win_prob    = wr["win_probability"]
#         sdo_current_revenue     = wr["expected_revenue"]
#         sdo_current_profit      = wr["expected_profit"]

#         # ── v2: FULLY AI-DRIVEN scenario scoring + selection ──
#         # Win probability per discount level comes from ONE batched Cortex
#         # call (not a formula, not 5 separate calls). Revenue/profit per
#         # level stay deterministic multiplication once win probability is
#         # known. Which scenario is "best" is then also an AI judgment
#         # (module="discount_optimizer", decision_type="scenario_selection")
#         # reasoning over the whole simulation table — not a fixed
#         # "win>=80 then max profit" rule.
#         discount_levels = [0, 2, 5, 8, 10]
#         level_contexts = [
#             f"Discount {d}%: price would be ₹{sdo_base_price * (1 - d/100):,.2f}, "
#             f"PSI {sdo_psi:.2f}, capacity modifier {sdo_capacity_mod_pct:+.0f}%"
#             + (f", competitor avg ₹{sdo_competitor_avg:,.2f}" if sdo_competitor_avg else "")
#             for d in discount_levels
#         ]
#         wp_batch = ai_reason_score_batch(
#             module="discount_optimizer", decision_type="win_probability_per_discount",
#             items_context=level_contexts,
#             extra_instruction="The 'score' field IS the estimated win probability (0-100) at that discount level.",
#             cache_key=_ai_cache_key("sdo_wp_batch", sdo_customer, sdo_sku, round(sdo_base_price, 2)),
#         )

#         sdo_rows = []
#         for d, wp_item in zip(discount_levels, wp_batch):
#             sim_final_price = sdo_base_price * (1 - d / 100)
#             sim_win_prob = wp_item["score"] if wp_item["ai_generated"] else 50.0
#             sim_win_prob_dec = sim_win_prob / 100.0
#             sim_revenue = sim_final_price * base_demand_pe * sim_win_prob_dec
#             sim_profit  = (
#                 (sim_final_price - sdo_cost) * base_demand_pe * sim_win_prob_dec
#                 if sdo_cost is not None else None
#             )
#             sdo_rows.append({
#                 "DISCOUNT_%":        d,
#                 "FINAL_PRICE":       round(sim_final_price, 2),
#                 "EXPECTED_REVENUE":  round(sim_revenue, 2),
#                 "EXPECTED_PROFIT":   round(sim_profit, 2) if sim_profit is not None else None,
#                 "WIN_PROBABILITY":   round(sim_win_prob, 1),
#             })
#         sdo_df = pd.DataFrame(sdo_rows)

#         # AI scenario selection — reasons over the full table, not a fixed rule.
#         scenario_table_text = "\n".join(
#             f"Discount {row['DISCOUNT_%']}%: price ₹{row['FINAL_PRICE']:,.2f}, "
#             f"win probability {row['WIN_PROBABILITY']:.0f}%, expected revenue ₹{row['EXPECTED_REVENUE']:,.0f}, "
#             f"expected profit {'₹' + format(row['EXPECTED_PROFIT'], ',.0f') if row['EXPECTED_PROFIT'] is not None else 'N/A'}"
#             for _, row in sdo_df.iterrows()
#         )
#         selection_payload = ai_reason_score(
#             module="discount_optimizer", decision_type="scenario_selection",
#             context_facts=scenario_table_text,
#             extra_instruction=(
#                 "Pick the single best discount scenario from the table above, considering "
#                 "profit, revenue, and win probability together (use your judgment on the "
#                 "tradeoff — do not just pick the highest profit or a fixed win-probability "
#                 "cutoff). The 'score' field should represent how strong this recommendation "
#                 "is (0-100). Also return 'recommended_discount_pct', the exact discount percent "
#                 "you are recommending — it MUST be one of the values in the table."
#             ),
#             numeric_fields={"recommended_discount_pct": "the chosen discount percent, must match one of the table rows exactly"},
#             cache_key=_ai_cache_key("sdo_selection", scenario_table_text),
#         )

#         if selection_payload.get("ai_generated") and "recommended_discount_pct" in selection_payload:
#             chosen_d = min(discount_levels, key=lambda d: abs(d - selection_payload["recommended_discount_pct"]))
#             sdo_best = sdo_df[sdo_df["DISCOUNT_%"] == chosen_d].iloc[0]
#             ai_selection_reasoning = selection_payload["reasoning"]
#         else:
#             # AI unavailable — fall back to the scenario with the highest win
#             # probability (a neutral, non-business-rule tiebreak) rather than
#             # silently reinstating a hardcoded margin/profit rule.
#             sdo_best = sdo_df.loc[sdo_df["WIN_PROBABILITY"].idxmax()]
#             ai_selection_reasoning = "Cortex AI scenario-selection service unavailable; showing the highest win-probability scenario."

#         recommended_discount   = float(sdo_best["DISCOUNT_%"])
#         recommended_price      = float(sdo_best["FINAL_PRICE"])
#         recommended_revenue    = float(sdo_best["EXPECTED_REVENUE"])
#         recommended_profit     = sdo_best["EXPECTED_PROFIT"]
#         recommended_win_prob   = float(sdo_best["WIN_PROBABILITY"])

#         if recommended_profit is not None and sdo_current_profit is not None:
#             profit_improvement = recommended_profit - sdo_current_profit
#             try:
#                 profit_improvement_pct = safe_pct_change(sdo_current_profit, recommended_profit)
#             except Exception:
#                 profit_improvement_pct = (
#                     ((recommended_profit - sdo_current_profit) / abs(sdo_current_profit)) * 100
#                     if sdo_current_profit else None
#                 )
#         else:
#             profit_improvement     = None
#             profit_improvement_pct = None

#         # AI-generated justification, combined with the AI's own scenario-selection reasoning
#         sdo_recommendation = ai_discount_justification(
#             sdo_customer, sdo_sku, sdo_current_discount, recommended_discount,
#             sdo_current_profit, recommended_profit, recommended_win_prob
#         )
#         if ai_selection_reasoning:
#             sdo_recommendation = f"{sdo_recommendation} {ai_selection_reasoning}"

#         # ── KPI Cards ──
#         sdo1, sdo2, sdo3, sdo4 = st.columns(4)
#         sdo1.metric("Recommended Discount", f"{recommended_discount:.0f}%")
#         sdo2.metric("Current Discount",     f"{sdo_current_discount:.1f}%")
#         sdo3.metric(
#             "Profit Improvement",
#             f"₹{profit_improvement:,.2f}" if profit_improvement is not None else "N/A",
#             f"{profit_improvement_pct:+.1f}%" if profit_improvement_pct is not None else None
#         )
#         sdo4.metric("Win Probability", f"{recommended_win_prob:.0f}%")

#         divider()

#         section("📊", "Discount Simulation")
#         sdo_chart_df = sdo_df.set_index("DISCOUNT_%")

#         sdo_c1, sdo_c2, sdo_c3 = st.columns(3)
#         with sdo_c1:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Discount vs Profit</p>', unsafe_allow_html=True
#             )
#             st.bar_chart(sdo_chart_df[["EXPECTED_PROFIT"]], height=220)
#         with sdo_c2:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Discount vs Revenue</p>', unsafe_allow_html=True
#             )
#             st.bar_chart(sdo_chart_df[["EXPECTED_REVENUE"]], height=220)
#         with sdo_c3:
#             st.markdown(
#                 '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
#                 'Discount vs Win Probability</p>', unsafe_allow_html=True
#             )
#             st.line_chart(sdo_chart_df[["WIN_PROBABILITY"]], height=220)

#         divider()

#         section("💡", "Discount Recommendation (Cortex AI)")
#         rec_col_l, rec_col_r = st.columns([1, 1.4])
#         with rec_col_l:
#             st.markdown(
#                 f"""
#                 <div style="text-align:center;padding-top:6px;">
#                     <p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">Recommended Discount</p>
#                     <p style="font-size:44px;font-weight:700;margin:0;color:#E8EEF7;">
#                         {recommended_discount:.0f}%
#                     </p>
#                 </div>
#                 """,
#                 unsafe_allow_html=True
#             )
#         with rec_col_r:
#             if recommended_win_prob >= 80 and abs(recommended_discount - sdo_current_discount) < 1e-9:
#                 st.success(f"🟢 {sdo_recommendation}")
#             elif recommended_win_prob >= 80:
#                 st.info(f"🔵 {sdo_recommendation}")
#             else:
#                 st.warning(f"🟡 {sdo_recommendation}")

#         section("🔍", "Simulation Details")
#         st.write(f"• **Customer:** {sdo_customer}  ({sdo_segment})")
#         st.write(f"• **SKU:** {sdo_sku}")
#         st.write(f"• **Pre-Discount Base Price:** ₹{sdo_base_price:,.2f}")
#         st.write(f"• **Current Discount:** {sdo_current_discount:.1f}%  →  ₹{sdo_current_price:,.2f}")
#         st.write(f"• **Recommended Discount:** {recommended_discount:.0f}%  →  ₹{recommended_price:,.2f}")
#         st.write(f"• **Recommended Win Probability:** {recommended_win_prob:.0f}%")

#         st.markdown(
#             '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
#             'Discount Simulation Matrix</p>',
#             unsafe_allow_html=True
#         )
#         st.dataframe(sdo_df, use_container_width=True, hide_index=True)

#         st.session_state["smart_discount_results"] = {
#             "customer":               sdo_customer,
#             "segment":                sdo_segment,
#             "sku":                    sdo_sku,
#             "base_price":             sdo_base_price,
#             "current_discount_pct":   sdo_current_discount,
#             "current_price":          sdo_current_price,
#             "current_profit":         sdo_current_profit,
#             "current_win_probability":sdo_current_win_prob,
#             "recommended_discount_pct": recommended_discount,
#             "recommended_price":      recommended_price,
#             "recommended_revenue":    recommended_revenue,
#             "recommended_profit":     recommended_profit,
#             "recommended_win_probability": recommended_win_prob,
#             "profit_improvement":     profit_improvement,
#             "profit_improvement_pct": profit_improvement_pct,
#             "recommendation":         sdo_recommendation,
#             "simulation_matrix":      sdo_df,
#         }

#         divider()

#         section("📋", "Executive Summary")

#         sdo_exec_df = pd.DataFrame([{
#             "Customer":            sdo_customer,
#             "Product":             sdo_sku,
#             "Current Discount":    f"{sdo_current_discount:.1f}%",
#             "Recommended Discount":f"{recommended_discount:.0f}%",
#             "Current Profit":      f"₹{sdo_current_profit:,.2f}" if sdo_current_profit is not None else "N/A",
#             "Optimized Profit":    f"₹{recommended_profit:,.2f}" if recommended_profit is not None else "N/A",
#             "Profit Improvement":  f"₹{profit_improvement:,.2f}" if profit_improvement is not None else "N/A",
#             "Win Probability":     f"{recommended_win_prob:.0f}%",
#             "Recommendation":      sdo_recommendation,
#         }])
#         st.dataframe(sdo_exec_df, use_container_width=True, hide_index=True)

#     # ════════════════════════════════════════════════════════════════════════
#     # END SMART DISCOUNT OPTIMIZER SECTION
#     # ════════════════════════════════════════════════════════════════════════

#     divider()

#     # ── Run Price Optimization ──
#     if st.button("🚀 Run Price Optimization", key="opt_btn", use_container_width=True):
#         if sku_df.empty:
#             st.error("No product data available.")
#         else:
#             cost = float(sku_df[sku_df["SKU"] == selected_sku_pe]["TOTAL_COST"].iloc[0])
#             if cost <= 0:
#                 st.error("Invalid cost value.")
#             else:
#                 results = []
#                 for margin in range(20, 55, 5):
#                     target_price    = cost * (1 + margin / 100)
#                     demand_factor   = 1 - ((margin - 20) * 0.02)
#                     expected_demand = max(int(base_demand_pe * demand_factor), 1)
#                     revenue = target_price * expected_demand
#                     profit  = (target_price - cost) * expected_demand
#                     results.append({
#                         "MARGIN_%":        margin,
#                         "TARGET_PRICE":    round(target_price, 2),
#                         "EXPECTED_DEMAND": expected_demand,
#                         "REVENUE":         round(revenue, 2),
#                         "PROFIT":          round(profit, 2)
#                     })
#                 opt_df = pd.DataFrame(results)
#                 best   = opt_df.loc[opt_df["PROFIT"].idxmax()]
#                 st.session_state["opt_results"] = opt_df
#                 st.session_state["opt_sku"]     = selected_sku_pe
#                 st.session_state["opt_cost"]    = cost
#                 st.session_state["opt_best"]    = best

#                 try:
#                     save_df = opt_df.copy()
#                     save_df.insert(0, "SKU",  selected_sku_pe)
#                     save_df.insert(1, "COST", cost)
#                     save_df["CREATED_AT"] = pd.Timestamp.utcnow()
#                     snow_df = session.create_dataframe(save_df)
#                     snow_df.write.mode("append").save_as_table(
#                         "PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZATION_RESULTS"
#                     )
#                     st.success("✅ Results saved to Snowflake")
#                 except Exception as e:
#                     st.warning(f"Save skipped: {e}")

#     # Render persisted optimization results
#     if st.session_state["opt_results"] is not None:
#         opt_df = st.session_state["opt_results"]
#         best   = st.session_state["opt_best"]

#         st.success("✅ Optimization Complete")
#         section("🏆", "Recommended Price Point")
#         r1,r2,r3,r4 = st.columns(4)
#         r1.metric("Best Margin",       f"{best['MARGIN_%']}%")
#         r2.metric("Recommended Price", f"₹{best['TARGET_PRICE']:,.2f}")
#         r3.metric("Expected Demand",   f"{int(best['EXPECTED_DEMAND'])} units")
#         r4.metric("Expected Profit",   f"₹{best['PROFIT']:,.2f}")

#         psi_note = ""
#         if st.session_state["psi_results"] is not None:
#             pr = st.session_state["psi_results"]
#             psi_note = (
#                 f"\n\n**PSI Context:** Customer **{pr['customer']}** has PSI "
#                 f"`{pr['psi']:.2f}` → recommended margin **{pr['margin_pct']:.0f}%** "
#                 f"({pr['margin_label']}). "
#                 f"PSI-optimized final price = **₹{pr['final_price']:,.2f}**."
#             )

#         st.info(f"""
# **Recommended Margin:** {best['MARGIN_%']}% · **Price:** ₹{best['TARGET_PRICE']:,.2f} · **Demand:** {int(best['EXPECTED_DEMAND'])} units

# Elasticity model: each 5% margin increase reduces demand by ~2%. This price maximises profit after demand dilution.{psi_note}
# """)
#         divider()

#         col_p, col_d = st.columns(2)
#         with col_p:
#             section("📊", "Profit by Margin %")
#             st.bar_chart(opt_df.set_index("MARGIN_%")[["PROFIT"]], height=220)
#         with col_d:
#             section("📉", "Demand vs Margin %")
#             st.line_chart(opt_df.set_index("MARGIN_%")[["EXPECTED_DEMAND"]], height=220)

#         section("📋", "Full Optimization Results")
#         st.dataframe(opt_df, use_container_width=True, hide_index=True)

# # ════════════════════════════════════════════
# # TAB 3 — SIMULATION HUB  (unchanged — deterministic simulation math only)
# # ════════════════════════════════════════════

# if _active_tab == "⚙️ Simulation Hub":
#     section("⚙️", "Simulation Control Center")
#     st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Run custom cost-price scenarios and track simulation history.</p>', unsafe_allow_html=True)

#     try:
#         sku_cost_df = session.sql("""
#             SELECT DISTINCT SKU, TOTAL_COST
#             FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
#         """).to_pandas()
#     except Exception:
#         sku_cost_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

#     with st.container():
#         st.markdown("""
#         <div style="background:#0D1829;border:1px solid #1B3050;border-radius:14px;padding:22px 24px;margin-bottom:20px;">
#             <div style="color:#C8D8E8;font-size:14px;font-weight:600;margin-bottom:16px;">📝 Create New Scenario</div>
#         """, unsafe_allow_html=True)

#         col1, col2 = st.columns(2)
#         with col1:
#             scenario_name  = st.text_input("Scenario Name", "Custom Scenario", key="sim_name")
#             selected_sku_s = st.selectbox("Select Product", sku_cost_df["SKU"].tolist(), key="sim_sku")
#         with col2:
#             target_margin     = st.slider("Target Margin %",    0, 100, 35, key="sim_margin")
#             customer_discount = st.slider("Customer Discount %", 0, 50,  10, key="sim_disc")

#         steel_surcharge = st.slider("Steel Surcharge %", 0, 50, 5, key="sim_steel")
#         fuel_surcharge  = st.slider("Fuel Surcharge %",  0, 20, 2, key="sim_fuel")

#         st.markdown("</div>", unsafe_allow_html=True)

#     if st.button("🚀 Run Simulation", key="sim_run", use_container_width=True):
#         if not sku_cost_df.empty and selected_sku_s in sku_cost_df["SKU"].values:
#             cost = float(sku_cost_df[sku_cost_df["SKU"] == selected_sku_s]["TOTAL_COST"].iloc[0])

#             adjusted_cost  = cost * (1 + steel_surcharge/100 + fuel_surcharge/100)
#             target_price   = adjusted_cost * (1 + target_margin/100)
#             customer_price = target_price  * (1 - customer_discount/100)
#             profit         = customer_price - cost

#             st.session_state["sim_results"] = {
#                 "cost": cost, "adjusted_cost": adjusted_cost,
#                 "target_price": target_price, "customer_price": customer_price,
#                 "profit": profit, "scenario_name": scenario_name, "sku": selected_sku_s,
#                 "target_margin": target_margin, "customer_discount": customer_discount,
#                 "steel_surcharge": steel_surcharge, "fuel_surcharge": fuel_surcharge
#             }

#             try:
#                 session.sql(f"""
#                     INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
#                     VALUES (
#                         '{scenario_name}', '{selected_sku_s}',
#                         {cost}, {target_margin}, {customer_discount},
#                         {steel_surcharge}, {fuel_surcharge},
#                         {target_price}, {customer_price}, CURRENT_TIMESTAMP()
#                     )
#                 """).collect()
#             except Exception as e:
#                 st.warning(f"Save skipped: {e}")

#     if st.session_state["sim_results"] is not None:
#         r = st.session_state["sim_results"]
#         st.success("✅ Simulation Completed")
#         s1,s2,s3,s4,s5 = st.columns(5)
#         s1.metric("Base Cost",      f"₹{r['cost']:,.2f}")
#         s2.metric("Adjusted Cost",  f"₹{r['adjusted_cost']:,.2f}")
#         s3.metric("Target Price",   f"₹{r['target_price']:,.2f}")
#         s4.metric("Customer Price", f"₹{r['customer_price']:,.2f}")
#         s5.metric("Gross Profit",   f"₹{r['profit']:,.2f}")

#     divider()

#     section("📊", "Compare Pre-Defined Scenarios")

#     try:
#         scenario_df = session.sql("""
#             SELECT DISTINCT SCENARIO_ID, SCENARIO_NAME
#             FROM PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS
#             ORDER BY SCENARIO_NAME
#         """).to_pandas()

#         col_a, col_b = st.columns(2)
#         with col_a:
#             sel_sku_sc = st.selectbox("Product", sku_cost_df["SKU"].tolist(), key="sc_sku")
#         with col_b:
#             sel_sc = st.selectbox("Scenario", scenario_df["SCENARIO_ID"].tolist(), key="sc_id")

#         if st.button("▶️ Run Pre-Defined Scenario", key="sc_btn"):
#             sc_result = session.sql(f"""
#                 SELECT SKU, SCENARIO_ID, SCENARIO_NAME, TOTAL_COST,
#                        TARGET_MARGIN_PCT, CUSTOMER_DISCOUNT_PCT,
#                        SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
#                 FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING
#                 WHERE SKU = '{sel_sku_sc}' AND SCENARIO_ID = '{sel_sc}'
#             """).to_pandas()
#             st.session_state["sc_result"] = sc_result

#         if st.session_state["sc_result"] is not None:
#             sc_result = st.session_state["sc_result"]
#             if not sc_result.empty:
#                 row = sc_result.iloc[0]
#                 st.success("✅ Scenario loaded")
#                 m1,m2,m3,m4 = st.columns(4)
#                 m1.metric("Cost",           f"₹{row['TOTAL_COST']:,.2f}")
#                 m2.metric("Target Price",   f"₹{row['SIMULATED_TARGET_PRICE']:,.2f}")
#                 m3.metric("Customer Price", f"₹{row['SIMULATED_CUSTOMER_PRICE']:,.2f}")
#                 m4.metric("Margin %",       f"{row['TARGET_MARGIN_PCT']}%")
#                 st.dataframe(sc_result, use_container_width=True, hide_index=True)

#     except Exception as e:
#         st.info(f"Pre-defined scenarios not available: {e}")

#     divider()

#     try:
#         comparison_df = session.sql("""
#             SELECT SCENARIO_NAME, SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
#             FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING
#             ORDER BY SCENARIO_NAME
#         """).to_pandas()

#         if not comparison_df.empty:
#             section("📉", "Scenario Comparison")
#             col_l, col_r = st.columns(2)
#             with col_l:
#                 st.markdown('<p style="color:#6B8BAF;font-size:12px;">Target Price by Scenario</p>', unsafe_allow_html=True)
#                 st.bar_chart(comparison_df.set_index("SCENARIO_NAME")[["SIMULATED_TARGET_PRICE"]], height=200)
#             with col_r:
#                 st.markdown('<p style="color:#6B8BAF;font-size:12px;">Customer Price by Scenario</p>', unsafe_allow_html=True)
#                 st.bar_chart(comparison_df.set_index("SCENARIO_NAME")[["SIMULATED_CUSTOMER_PRICE"]], height=200)
#     except Exception:
#         pass

#     divider()
#     section("📜", "Simulation History")

#     try:
#         hist = session.sql("""
#             SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
#             ORDER BY CREATED_AT DESC
#         """).to_pandas()
#         st.dataframe(hist, use_container_width=True, hide_index=True)
#     except Exception:
#         st.info("No simulation history yet.")


# # ════════════════════════════════════════════
# # TAB 4 — DIGITAL TWIN  — Margin Leakage AI integration
# # ════════════════════════════════════════════

# if _active_tab == "🌍 Digital Twin":
#     section("🌍", "Pricing Digital Twin")
#     st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Model future market shocks before they hit your bottom line.</p>', unsafe_allow_html=True)

#     try:
#         sku_dt_df = session.sql("""
#             SELECT SKU, TOTAL_COST
#             FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
#             ORDER BY SKU
#         """).to_pandas()
#     except Exception:
#         sku_dt_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

#     col1, col2 = st.columns(2)
#     with col1:
#         sel_sku_dt  = st.selectbox("Product", sku_dt_df["SKU"].tolist(), key="dt_sku")
#         scenario_dt = st.text_input("Scenario Name", "Market Shock Scenario", key="dt_name")
#     with col2:
#         base_demand_dt = st.number_input("Current Monthly Demand (units)", value=2000, min_value=1, step=100, key="dt_demand")

#     divider()
#     section("🌡️", "Future Market Conditions")

#     col_s1, col_s2, col_s3 = st.columns(3)
#     with col_s1:
#         steel_change  = st.slider("Steel Cost Change %",      -20, 50, 10,  key="dt_steel")
#     with col_s2:
#         fuel_change   = st.slider("Fuel / Logistics Change %", -20, 50, 5,   key="dt_fuel")
#     with col_s3:
#         demand_change = st.slider("Market Demand Change %",   -50, 50, -15, key="dt_demand_ch")

#     if st.button("▶️ Run Digital Twin", key="dt_run", use_container_width=True):
#         if not sku_dt_df.empty and sel_sku_dt in sku_dt_df["SKU"].values:
#             cost = float(sku_dt_df[sku_dt_df["SKU"] == sel_sku_dt]["TOTAL_COST"].iloc[0])
#             if cost <= 0:
#                 st.error("Invalid cost.")
#             else:
#                 BASE_MARGIN  = 1.35
#                 base_price   = cost * BASE_MARGIN
#                 base_revenue = base_price * base_demand_dt
#                 base_profit  = (base_price - cost) * base_demand_dt

#                 new_cost    = cost * (1 + steel_change/100) * (1 + fuel_change/100)
#                 new_price   = new_cost * BASE_MARGIN
#                 new_demand  = max(int(base_demand_dt * (1 + demand_change/100)), 1)
#                 new_revenue = new_price * new_demand
#                 new_profit  = (new_price - new_cost) * new_demand

#                 st.session_state["dt_results"] = {
#                     "cost": cost, "new_cost": new_cost,
#                     "base_price": base_price, "new_price": new_price,
#                     "base_demand": base_demand_dt, "new_demand": new_demand,
#                     "base_revenue": base_revenue, "new_revenue": new_revenue,
#                     "base_profit": base_profit, "new_profit": new_profit,
#                     "sku": sel_sku_dt, "scenario": scenario_dt
#                 }

#                 try:
#                     session.sql(f"""
#                         INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.DIGITAL_TWIN_RESULTS
#                         VALUES (
#                             '{scenario_dt}', '{sel_sku_dt}',
#                             {cost}, {new_cost},
#                             {base_price}, {new_price},
#                             {base_demand_dt}, {new_demand},
#                             {base_revenue}, {new_revenue},
#                             {base_profit}, {new_profit},
#                             CURRENT_TIMESTAMP()
#                         )
#                     """).collect()
#                     st.success("✅ Scenario saved to Snowflake")
#                 except Exception as e:
#                     st.warning(f"Save skipped: {e}")

#     if st.session_state["dt_results"] is not None:
#         d = st.session_state["dt_results"]
#         cost         = d["cost"];        new_cost     = d["new_cost"]
#         base_price   = d["base_price"];  new_price    = d["new_price"]
#         base_demand  = d["base_demand"]; new_demand   = d["new_demand"]
#         base_revenue = d["base_revenue"];new_revenue  = d["new_revenue"]
#         base_profit  = d["base_profit"]; new_profit   = d["new_profit"]

#         st.success("✅ Digital Twin Simulation Complete")

#         section("📊", "Current vs Future State")
#         c1,c2,c3,c4 = st.columns(4)
#         c1.metric("Cost",           f"₹{cost:,.2f}",         f"₹{new_cost - cost:+,.2f}",            delta_color="inverse")
#         c2.metric("Selling Price",  f"₹{base_price:,.2f}",   f"₹{new_price - base_price:+,.2f}")
#         c3.metric("Revenue Impact", f"₹{base_revenue:,.2f}", f"₹{new_revenue - base_revenue:+,.2f}")
#         c4.metric("Profit Impact",  f"₹{base_profit:,.2f}",  f"₹{new_profit - base_profit:+,.2f}")

#         comparison = pd.DataFrame({
#             "Metric":  ["Cost","Selling Price","Demand","Revenue","Profit"],
#             "Current": [cost, base_price, base_demand, base_revenue, base_profit],
#             "Future":  [new_cost, new_price, new_demand, new_revenue, new_profit],
#         })
#         comparison["Δ Change"]   = comparison["Future"] - comparison["Current"]
#         comparison["Δ Change %"] = ((comparison["Δ Change"] / comparison["Current"]) * 100).round(2)
#         st.dataframe(comparison, use_container_width=True, hide_index=True)

#         divider()
#         section("🚨", "Future Margin Leakage Analysis")

#         future_margin = ((new_price - new_cost) / new_price) * 100 if new_price > 0 else 0

#         # ── Margin Leakage — v2: FULLY AI-DRIVEN (no future_margin*4 score
#         # formula, no 5/10/15% thresholds). One ai_reason_score call returns
#         # the health score, status label, causes, business impact, and
#         # corrective actions together.
#         leakage_context = (
#             f"Product {d['sku']}, scenario '{d['scenario']}'.\n"
#             f"Cost rises from ₹{cost:,.2f} to ₹{new_cost:,.2f} (steel {steel_change:+d}%, fuel {fuel_change:+d}%).\n"
#             f"Demand moves from {base_demand} to {new_demand} units ({demand_change:+d}%).\n"
#             f"Margin falls from {((base_price-cost)/base_price*100 if base_price else 0):.1f}% to {future_margin:.1f}%.\n"
#             f"Profit impact ₹{abs(new_profit-base_profit):,.0f}."
#         )
#         leakage_payload = ai_reason_score(
#             module="digital_twin", decision_type="margin_leakage",
#             context_facts=leakage_context,
#             extra_instruction=(
#                 "Identify the most likely causes of this margin leakage, the business impact, "
#                 "and corrective actions. The 'score' field should represent overall margin "
#                 "health under this future scenario (higher = healthier)."
#             ),
#             cache_key=_ai_cache_key("leakage_v2", d["sku"], d["scenario"], round(future_margin, 1)),
#         )

#         if leakage_payload.get("ai_generated"):
#             health_score = int(round(leakage_payload["score"]))
#             leakage_status = leakage_payload["label"]
#             leakage_color = "#00C7B2" if health_score >= 65 else "#F59E0B" if health_score >= 35 else "#EF4444"
#         else:
#             health_score, leakage_status, leakage_color = 0, "AI Unavailable", "#6B8BAF"

#         m1,m2,m3,m4 = st.columns(4)
#         m1.metric("Future Margin %", f"{future_margin:.2f}%")
#         m2.metric("Health Score",    f"{health_score}/100")
#         m3.metric("Leakage Status",  leakage_status)
#         m4.metric("Profit At Risk",  f"₹{abs(new_profit-base_profit):,.0f}")

#         st.markdown(health_bar_html(health_score, leakage_color, leakage_status), unsafe_allow_html=True)

#         divider()
#         section("🔍", "Leakage Findings (Cortex AI)")
#         if leakage_payload.get("ai_generated"):
#             st.write(leakage_payload["reasoning"])
#             st.write(f"• Profit impact = ₹{abs(new_profit-base_profit):,.0f}")
#             st.write(f"• Demand changes from {base_demand} to {new_demand}")
#         else:
#             st.info("Cortex AI margin-leakage service unavailable — no findings generated.")

#         section("💡", "Executive Recommendation (Cortex AI)")
#         render_ai_score_card(leakage_payload, title_prefix="Margin Leakage")


# # ════════════════════════════════════════════
# # TAB 5 — AI ADVISOR  — fully AI-driven recommendations
# # ════════════════════════════════════════════

# if _active_tab == "🧠 AI Advisor":
#     section("🧠", "AI Pricing Strategy Advisor")
#     st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Cortex AI-generated strategic analysis from the latest Digital Twin simulation.</p>', unsafe_allow_html=True)

#     try:
#         dt_df = session.sql("""
#             SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.DIGITAL_TWIN_RESULTS
#             ORDER BY CREATED_AT DESC LIMIT 1
#         """).to_pandas()
#     except Exception as e:
#         st.error(f"Could not load simulation data: {e}")
#         dt_df = pd.DataFrame()

#     if dt_df.empty:
#         st.warning("⚠️ No Digital Twin data found. Run a simulation in the **Digital Twin** tab first.")
#     else:
#         row = dt_df.iloc[0]

#         base_profit  = float(row["BASE_PROFIT"])
#         new_profit   = float(row["NEW_PROFIT"])
#         base_revenue = float(row["BASE_REVENUE"])
#         new_revenue  = float(row["NEW_REVENUE"])

#         profit_change  = safe_pct_change(new_profit,  base_profit)
#         revenue_change = safe_pct_change(new_revenue, base_revenue)

#         sku_label      = row.get("SKU",           "N/A")
#         scenario_label = row.get("SCENARIO_NAME", "Latest Simulation")

#         c1,c2,c3,c4 = st.columns(4)
#         c1.metric("Scenario",         scenario_label)
#         c2.metric("Product SKU",      sku_label)
#         c3.metric("Profit Change %",  f"{profit_change:+.2f}%")
#         c4.metric("Revenue Change %", f"{revenue_change:+.2f}%")

#         divider()

#         # ── Advisor Score — v2: FULLY AI-DRIVEN (no +25/+10/-15/-25 point
#         # formula). Cortex AI reasons over the profit/revenue change
#         # together and returns its own risk score and status.
#         advisor_payload = ai_reason_score(
#             module="advisor", decision_type="scenario_health",
#             context_facts=(
#                 f"Scenario: {scenario_label}\nProduct SKU: {sku_label}\n"
#                 f"Profit change: {profit_change:+.1f}%\nRevenue change: {revenue_change:+.1f}%"
#             ),
#             extra_instruction=(
#                 "Assess overall pricing health/risk for this scenario. The 'score' field "
#                 "should represent overall health (higher = healthier)."
#             ),
#             cache_key=_ai_cache_key("advisor_v2", scenario_label, sku_label, round(profit_change, 1), round(revenue_change, 1)),
#         )

#         if advisor_payload.get("ai_generated"):
#             score = advisor_payload["score"]
#             status = advisor_payload["label"]
#         else:
#             score, status = 0, "AI Unavailable"

#         bar_color = "#00C7B2" if score >= 65 else "#F59E0B" if score >= 35 else "#EF4444"
#         status_emoji = "🟢" if score >= 65 else "🟡" if score >= 35 else "🔴"
#         status_display = f"{status_emoji} {status}"

#         section("📈", "Pricing Health Score")
#         st.markdown(health_bar_html(score, bar_color, status_display), unsafe_allow_html=True)

#         if score >= 65:   st.success(f"Current Status: {status_display}")
#         elif score >= 35: st.warning(f"Current Status: {status_display}")
#         else:             st.error(f"Current Status: {status_display}")

#         divider()

#         col_left, col_right = st.columns(2)

#         with col_left:
#             section("🔍", "Key Findings")
#             st.write(f"• Profit {'increased' if profit_change >= 0 else 'decreased'} by {abs(profit_change):.1f}%")
#             st.write(f"• Revenue {'increased' if revenue_change >= 0 else 'decreased'} by {abs(revenue_change):.1f}%")

#         with col_right:
#             section("✅", "Recommended Actions (Cortex AI)")
#             # AI_COMPLETE replaces the fixed recs[] if/elif lists entirely.
#             recs_prompt = (
#                 f"Scenario '{scenario_label}' for product {sku_label}: profit change "
#                 f"{profit_change:+.1f}%, revenue change {revenue_change:+.1f}%, pricing "
#                 f"health status '{status}'. Suggest up to 4 short, specific pricing "
#                 f"recommendations for a manufacturing pricing manager (each under 15 words). "
#                 f"Return ONLY a JSON array of strings (no markdown)."
#             )
#             ai_recs = parse_ai_json(ai_complete(recs_prompt, cache_key=_ai_cache_key("advisor_recs", scenario_label, sku_label, round(score))))

#             if ai_recs and isinstance(ai_recs, list) and all(isinstance(x, str) for x in ai_recs):
#                 recs = ai_recs
#             else:
#                 if profit_change < -10:
#                     recs = [
#                         "Increase selling price by 5–8% to recover margin",
#                         "Reduce or eliminate customer discounts temporarily",
#                         "Audit and negotiate raw material costs",
#                         "Identify cost reduction opportunities in logistics"
#                     ]
#                 elif profit_change < 0:
#                     recs = [
#                         "Monitor pricing performance weekly",
#                         "Evaluate cost structure for efficiency gains",
#                         "Consider small price adjustments (2–3%) to offset cost rise"
#                     ]
#                 else:
#                     recs = [
#                         "Maintain current pricing strategy — performing well",
#                         "Explore opportunity to expand sales volume",
#                         "Consider reinvesting margin gains into customer acquisition"
#                     ]

#             for i, rec in enumerate(recs, 1):
#                 st.success(f"{i}. {rec}")

#         divider()
#         section("📋", "Executive Summary (Cortex AI)")

#         summary_facts = (
#             f"Scenario: {scenario_label}\nProduct SKU: {sku_label}\n"
#             f"Revenue change: {revenue_change:+.1f}%\nProfit change: {profit_change:+.1f}%\n"
#             f"Pricing Health Score: {score}/100 ({status})\nTop recommendation: {recs[0]}"
#         )
#         ai_summary_text = ai_summarize(summary_facts, cache_key=_ai_cache_key("advisor_summary", summary_facts))

#         summary = ai_or_fallback(
#             ai_summary_text,
#             f"""Scenario: {scenario_label}
# Product SKU: {sku_label}

# The latest Digital Twin simulation shows:
#   • Revenue change:  {revenue_change:+.1f}%
#   • Profit change:   {profit_change:+.1f}%

# Pricing Health Score: {score} / 100  —  {status_display}

# Primary Recommended Action:
# → {recs[0]}""".strip()
#         )

#         st.text_area(label="", value=summary, height=220)


# # ════════════════════════════════════════════
# # TAB 6 — CONTRACT ANALYZER  — AI_CLASSIFY risk + AI_COMPLETE explanations
# # ════════════════════════════════════════════

# if _active_tab == "📄 Contract Analyzer":
#     section("📄", "Contract Impact Analyzer")
#     st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Analyze contract profitability under future cost increases, with Cortex AI risk classification.</p>', unsafe_allow_html=True)

#     try:
#         contract_df = session.sql("""
#             SELECT CUSTOMER_ID, SKU, TOTAL_COST, DISCOUNTED_PRICE
#             FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING
#         """).to_pandas()
#     except Exception as e:
#         st.error(f"Could not load contract data: {e}")
#         contract_df = pd.DataFrame(columns=["CUSTOMER_ID","SKU","TOTAL_COST","DISCOUNTED_PRICE"])

#     col1, col2 = st.columns(2)
#     with col1:
#         selected_customer = st.selectbox("Customer", sorted(contract_df["CUSTOMER_ID"].unique()) if not contract_df.empty else [], key="ca_cust")
#     with col2:
#         selected_sku_ca   = st.selectbox("Product SKU", sorted(contract_df["SKU"].unique()) if not contract_df.empty else [], key="ca_sku")

#     steel_change_ca = st.slider("Steel Cost Increase %", -20, 50, 10, key="ca_steel")
#     fuel_change_ca  = st.slider("Fuel Cost Increase %",  -20, 50,  5, key="ca_fuel")

#     if st.button("🔍 Analyze Contract", key="ca_btn", use_container_width=True):
#         try:
#             row_ca = contract_df[
#                 (contract_df["CUSTOMER_ID"] == selected_customer) &
#                 (contract_df["SKU"] == selected_sku_ca)
#             ].iloc[0]

#             cost_ca         = float(row_ca["TOTAL_COST"])
#             selling_price   = float(row_ca["DISCOUNTED_PRICE"])
#             current_margin  = ((selling_price - cost_ca) / selling_price) * 100 if selling_price > 0 else 0
#             future_cost_ca  = cost_ca * (1 + steel_change_ca/100) * (1 + fuel_change_ca/100)
#             future_margin   = ((selling_price - future_cost_ca) / selling_price) * 100 if selling_price > 0 else 0
#             margin_loss     = current_margin - future_margin

#             st.session_state["contract_results"] = {
#                 "current_margin": current_margin, "future_margin": future_margin,
#                 "margin_loss": margin_loss, "customer": selected_customer,
#                 "sku": selected_sku_ca, "cost": cost_ca,
#                 "selling_price": selling_price, "future_cost": future_cost_ca
#             }
#         except (IndexError, KeyError):
#             st.error("No pricing data found for this Customer + SKU combination.")

#     if st.session_state["contract_results"] is not None:
#         cr = st.session_state["contract_results"]
#         current_margin = cr["current_margin"]
#         future_margin  = cr["future_margin"]
#         margin_loss    = cr["margin_loss"]

#         # ── Contract Risk — v2: FULLY AI-DRIVEN (no future_margin*4 formula,
#         # no fixed 20%/10% thresholds). AI determines contract quality,
#         # profitability, legal/renegotiation risk, and pricing flexibility.
#         contract_payload = ai_reason_score(
#             module="contract", decision_type="contract_risk",
#             context_facts=(
#                 f"Customer: {cr['customer']}\nSKU: {cr['sku']}\n"
#                 f"Current margin: {current_margin:.1f}%\nProjected future margin: {future_margin:.1f}%\n"
#                 f"Margin loss: {margin_loss:.1f} points (driven by rising raw material costs)"
#             ),
#             extra_instruction=(
#                 "Determine contract quality, profitability trajectory, renegotiation risk, "
#                 "and pricing flexibility. The 'score' field should represent overall contract "
#                 "health (higher = healthier, lower = riskier)."
#             ),
#             cache_key=_ai_cache_key("contract_v2", cr["customer"], cr["sku"], round(future_margin, 1)),
#         )

#         if contract_payload.get("ai_generated"):
#             score_ca = int(round(contract_payload["score"]))
#             risk = contract_payload["label"]
#             color_ca = "#00C7B2" if score_ca >= 65 else "#F59E0B" if score_ca >= 35 else "#EF4444"
#         else:
#             score_ca, risk, color_ca = 0, "AI Unavailable", "#6B8BAF"

#         divider()
#         c1,c2,c3,c4 = st.columns(4)
#         c1.metric("Current Margin", f"{current_margin:.1f}%")
#         c2.metric("Future Margin",  f"{future_margin:.1f}%")
#         c3.metric("Margin Loss",    f"{margin_loss:.1f}%")
#         c4.metric("Contract Risk",  risk)

#         divider()
#         st.markdown(health_bar_html(score_ca, color_ca, risk), unsafe_allow_html=True)
#         if contract_payload.get("ai_generated"):
#             st.caption(f"💡 {contract_payload['reasoning']}  (confidence {contract_payload['confidence']:.0f}%)")

#         divider()
#         left, right = st.columns(2)

#         with left:
#             section("🔍", "Key Findings")
#             st.write(f"• Current margin is {current_margin:.1f}%")
#             st.write(f"• Future margin drops to {future_margin:.1f}%")
#             st.write(f"• Margin loss is {margin_loss:.1f}%")

#         with right:
#             section("✅", "Recommended Actions (Cortex AI)")
#             # AI_COMPLETE explains the identified risk and recommends actions
#             # (replaces the fixed recs_ca[] if/elif lists).
#             ca_prompt = (
#                 f"Contract for customer {cr['customer']}, product {cr['sku']}. Current margin "
#                 f"{current_margin:.1f}%, projected future margin {future_margin:.1f}% "
#                 f"({risk}), a loss of {margin_loss:.1f} points due to rising raw material "
#                 f"costs. Suggest up to 4 short, specific contract actions for a deal desk "
#                 f"manager (each under 15 words). Return ONLY a JSON array of strings (no markdown)."
#             )
#             ai_recs_ca = parse_ai_json(ai_complete(ca_prompt, cache_key=_ai_cache_key("contract_recs", cr["customer"], cr["sku"], round(future_margin, 1))))

#             if ai_recs_ca and isinstance(ai_recs_ca, list) and all(isinstance(x, str) for x in ai_recs_ca):
#                 recs_ca = ai_recs_ca
#             else:
#                 if future_margin < 10:
#                     recs_ca = ["Renegotiate contract pricing", "Reduce customer discount",
#                                "Review raw material costs", "Protect profitability immediately"]
#                 elif future_margin < 20:
#                     recs_ca = ["Monitor contract performance", "Review contract periodically",
#                                "Track future cost changes"]
#                 else:
#                     recs_ca = ["Contract remains healthy", "No pricing action required", "Continue monitoring"]

#             for i, rec in enumerate(recs_ca, 1):
#                 st.success(f"{i}. {rec}")

#         divider()
#         section("📋", "Executive Summary")

#         summary_ca = f"""Customer: {cr['customer']}
# SKU: {cr['sku']}

# Current Margin:  {current_margin:.1f}%
# Future Margin:   {future_margin:.1f}%
# Margin Loss:     {margin_loss:.1f}%
# Risk Level:      {risk}

# Recommended Action:
# {recs_ca[0]}"""

#         st.text_area("", summary_ca, height=220, key="ca_summary")


# # ════════════════════════════════════════════
# # TAB 7 — COMPETITOR PRICING  — AI-integrated
# # ════════════════════════════════════════════

# if _active_tab == "🏆 Competitor Pricing":

#     # ── Helper: safe percentage change ──────────────────────────────────────
#     def safe_pct(a, b):
#         return 0.0 if b == 0 else ((a - b) / b) * 100

#     # ── Helper: deterministic position label + color (fallback only) ───────
#     def get_position_fallback(gap):
#         if gap > 10:
#             return "🔴 Expensive", "#EF4444"
#         elif gap > 3:
#             return "🟡 Premium", "#F59E0B"
#         elif gap > -3:
#             return "🟢 Competitive", "#00C7B2"
#         else:
#             return "🔵 Discount", "#3B82F6"

#     def get_position(gap):
#         """AI_CLASSIFY-driven market position label (replaces the fixed
#         if/elif gap-threshold logic). Falls back to the deterministic
#         version above if Cortex is unavailable."""
#         ai_label = ai_classify(
#             f"Our product is priced {gap:+.1f}% versus the competitor market average.",
#             ["Expensive", "Premium", "Competitive", "Discount"],
#             cache_key=_ai_cache_key("mkt_position", round(gap, 1))
#         )
#         color_map = {"Expensive": "#EF4444", "Premium": "#F59E0B", "Competitive": "#00C7B2", "Discount": "#3B82F6"}
#         icon_map  = {"Expensive": "🔴", "Premium": "🟡", "Competitive": "🟢", "Discount": "🔵"}
#         if ai_label and ai_label in color_map:
#             return f"{icon_map[ai_label]} {ai_label}", color_map[ai_label]
#         return get_position_fallback(gap)

#     # ── Helper: health score (deterministic — real formula, unchanged) ─────
#     def health_score(gap):
#         return max(0, min(100, int(100 - abs(gap * 5))))

#     # ── Helper: health bar HTML ─────────────────────────────────────────────
#     def health_bar(score, color, label):
#         return f"""
#         <div style="background:rgba(255,255,255,0.05);border-radius:8px;
#                     height:28px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);
#                     position:relative;margin:6px 0 12px;">
#           <div style="width:{score}%;height:100%;background:{color};border-radius:8px;
#                       transition:width .5s ease;"></div>
#           <div style="position:absolute;right:12px;top:50%;transform:translateY(-50%);
#                       font-size:12px;font-weight:600;color:#E2E8F0;">
#             {label} &nbsp;{score}/100
#           </div>
#         </div>"""

#     # ── Helper: chip HTML ───────────────────────────────────────────────────
#     def alert_chip(text):
#         return (f'<div style="padding:6px 10px;border-radius:6px;font-size:12px;'
#                 f'background:rgba(239,68,68,0.12);border:1px solid rgba(239,68,68,0.3);'
#                 f'color:#FCA5A5;margin-bottom:6px;">'
#                 f'⚠️ {text}</div>')

#     def opp_chip(text):
#         return (f'<div style="padding:6px 10px;border-radius:6px;font-size:12px;'
#                 f'background:rgba(0,199,178,0.12);border:1px solid rgba(0,199,178,0.3);'
#                 f'color:#5EEAD4;margin-bottom:6px;">'
#                 f'💡 {text}</div>')

#     section("🏆", "Competitor Pricing Intelligence")
#     st.markdown(
#         '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
#         'Real-time market positioning · price war simulation · historical trend analysis '
#         '· Cortex AI-generated market commentary'
#         '</p>',
#         unsafe_allow_html=True
#     )
#     divider()

#     try:
#         pricing_df = session.sql("""
#             SELECT SKU, PRODUCT_FAMILY, TARGET_PRICE
#             FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX
#             ORDER BY SKU
#         """).to_pandas()
#     except Exception as e:
#         st.error(f"Could not load pricing data: {e}")
#         pricing_df = pd.DataFrame(columns=["SKU", "PRODUCT_FAMILY", "TARGET_PRICE"])

#     col_i1, col_i2 = st.columns([1.5, 1])
#     with col_i1:
#         selected_sku = st.selectbox(
#             "Product SKU",
#             sorted(pricing_df["SKU"].unique()) if not pricing_df.empty else [],
#             key="comp_sku"
#         )
#     with col_i2:
#         monthly_vol = st.number_input(
#             "Monthly Sales Volume (units)",
#             value=1000, min_value=1, step=100,
#             key="comp_vol"
#         )

#     divider()
#     section("🏢", "Competitor Prices")

#     cc1, cc2, cc3, cc4 = st.columns(4)
#     with cc1:
#         name_a = st.text_input("Competitor A Name", "Competitor A", key="comp_a_name")
#         price_a = st.number_input("Price (₹)", value=1300, min_value=1, key="comp_a_price")
#     with cc2:
#         name_b = st.text_input("Competitor B Name", "Competitor B", key="comp_b_name")
#         price_b = st.number_input("Price (₹)", value=1250, min_value=1, key="comp_b_price")
#     with cc3:
#         name_c = st.text_input("Competitor C Name", "Competitor C", key="comp_c_name")
#         price_c = st.number_input("Price (₹)", value=1400, min_value=1, key="comp_c_price")
#     with cc4:
#         name_d = st.text_input("Competitor D Name", "Competitor D", key="comp_d_name")
#         price_d = st.number_input("Price (₹)", value=1350, min_value=1, key="comp_d_price")

#     divider()

#     if st.button("⚡ Analyze Market Position", key="comp_analyze_btn", use_container_width=True):
#         if pricing_df.empty:
#             st.error("No pricing data available.")
#         else:
#             row = pricing_df[pricing_df["SKU"] == selected_sku].iloc[0]
#             our_price = float(row["TARGET_PRICE"])

#             comp_map = {name_a: price_a, name_b: price_b, name_c: price_c, name_d: price_d}
#             comp_vals = list(comp_map.values())
#             market_avg = sum(comp_vals) / len(comp_vals)
#             market_min = min(comp_vals)
#             market_max = max(comp_vals)
#             price_gap  = safe_pct(our_price, market_avg)

#             # v2: FULLY AI-DRIVEN competitive health score (no 100-abs(gap*5)
#             # formula) for this button-triggered analysis. AI evaluates market
#             # position, competitive strength, and pricing confidence rather
#             # than a fixed function of the price gap alone. (The formula-based
#             # health_score()/get_position() helpers above are retained ONLY
#             # for the real-time Price War Simulator slider further down,
#             # where a live Cortex call per drag-frame would be impractical.)
#             comp_analysis_payload = ai_reason_score(
#                 module="competitor", decision_type="market_position",
#                 context_facts=(
#                     f"SKU: {selected_sku}\nOur price: ₹{our_price:,.2f}\n"
#                     f"Competitor prices: {', '.join(f'{n}=₹{v:,.0f}' for n, v in comp_map.items())}\n"
#                     f"Market average: ₹{market_avg:,.2f} (our gap {price_gap:+.1f}%)\n"
#                     f"Market range: ₹{market_min:,.0f} - ₹{market_max:,.0f}"
#                 ),
#                 extra_instruction=(
#                     "Evaluate market position, competitive strength, pricing aggressiveness, "
#                     "and pricing confidence. The 'score' field should represent overall "
#                     "competitive health (higher = stronger position)."
#                 ),
#                 cache_key=_ai_cache_key("comp_v2", selected_sku, round(our_price, 2), round(market_avg, 2)),
#             )
#             if comp_analysis_payload.get("ai_generated"):
#                 score = int(round(comp_analysis_payload["score"]))
#                 position = comp_analysis_payload["label"]
#                 pos_color = "#00C7B2" if score >= 65 else "#F59E0B" if score >= 35 else "#EF4444"
#             else:
#                 score, position, pos_color = 0, "AI Unavailable", "#6B8BAF"

#             cheapest_name  = min(comp_map, key=comp_map.get)
#             cheapest_price = comp_map[cheapest_name]
#             prem_cheapest  = safe_pct(our_price, cheapest_price)

#             all_sorted = sorted(comp_vals + [our_price])
#             our_rank   = all_sorted.index(our_price) + 1
#             total_p    = len(all_sorted)

#             rev_our   = our_price * monthly_vol
#             rev_avg   = market_avg * monthly_vol
#             rev_delta = rev_our - rev_avg

#             # ── AI_FILTER + AI_COMPLETE generate alerts/opportunities instead
#             # of the fixed threshold-only checks. Raw candidate signals stay
#             # deterministic; AI decides significance and writes the text.
#             candidate_signals = []
#             if price_gap > 10:
#                 candidate_signals.append(("alert", f"Price is {price_gap:.1f}% above market average — risk of losing deals."))
#             if prem_cheapest > 15:
#                 candidate_signals.append(("alert", f"{prem_cheapest:.1f}% premium over cheapest competitor ({cheapest_name})."))
#             if score < 60:
#                 candidate_signals.append(("alert", f"Competitive health score is {score}/100 — below the healthy range."))
#             if our_price < market_min:
#                 candidate_signals.append(("alert", "Price is below all competitors — possible margin under-capture."))
#             if our_price < market_avg:
#                 candidate_signals.append(("opportunity", f"₹{market_avg - our_price:,.0f} headroom to reach market average."))
#             if our_price < market_max:
#                 candidate_signals.append(("opportunity", f"₹{market_max - our_price:,.0f} headroom vs the most expensive competitor."))

#             alerts, opps = [], []
#             for kind, raw in candidate_signals:
#                 sig = ai_filter(
#                     f"Is this competitive pricing signal significant enough to surface to "
#                     f"an executive? Signal: {raw}",
#                     cache_key=_ai_cache_key("comp_sig_filter", kind, raw)
#                 )
#                 if sig is False:
#                     continue
#                 text_out = ai_complete(
#                     f"Rewrite this competitive pricing signal as one short executive-ready "
#                     f"sentence (max 20 words): {raw}",
#                     cache_key=_ai_cache_key("comp_sig_text", kind, raw)
#                 )
#                 final_text = text_out if text_out else raw
#                 (alerts if kind == "alert" else opps).append(final_text)
#             if not opps:
#                 opps.append("Maintain current price — already at or above market average")
#             if not alerts:
#                 pass  # handled below with a neutral message

#             # AI-generated recommendations (replaces the fixed if/elif recs[])
#             recs_prompt = (
#                 f"Our product {selected_sku} is priced ₹{our_price:,.0f}, {price_gap:+.1f}% vs a "
#                 f"market average of ₹{market_avg:,.0f} (rank #{our_rank} of {total_p}). "
#                 f"Suggest up to 4 short, specific competitive pricing recommendations for a "
#                 f"manufacturing pricing manager (each under 15 words). Return ONLY a JSON "
#                 f"array of strings (no markdown)."
#             )
#             ai_recs = parse_ai_json(ai_complete(recs_prompt, cache_key=_ai_cache_key("comp_recs", selected_sku, round(price_gap, 1))))
#             if ai_recs and isinstance(ai_recs, list) and all(isinstance(x, str) for x in ai_recs):
#                 recs = ai_recs
#             else:
#                 if price_gap > 10:
#                     recs = ["Review selling price immediately","Risk of losing deals to competitors",
#                             "Consider strategic discounting","Monitor competitors weekly"]
#                 elif price_gap > 3:
#                     recs = ["Maintain premium positioning with value justification",
#                             "Highlight product differentiation to customers",
#                             "Monitor competitor price movements closely"]
#                 elif price_gap > -3:
#                     recs = ["Maintain current pricing strategy — fully competitive",
#                             "Explore small uplift to improve margin","Continue monitoring market"]
#                 else:
#                     recs = ["Opportunity to increase price — below market",
#                             "Potential to capture additional margin",
#                             "Gradual price increase recommended"]

#             st.session_state["comp_results"] = {
#                 "sku": selected_sku, "our_price": our_price,
#                 "market_avg": market_avg, "market_min": market_min, "market_max": market_max,
#                 "price_gap": price_gap, "score": score, "position": position,
#                 "pos_color": pos_color, "monthly_vol": monthly_vol,
#                 "rev_our": rev_our, "rev_delta": rev_delta,
#                 "our_rank": our_rank, "total_p": total_p,
#                 "alerts": alerts, "opps": opps, "recs": recs,
#                 "comp_map": comp_map, "cheapest_name": cheapest_name,
#                 "cheapest_price": cheapest_price, "prem_cheapest": prem_cheapest,
#             }

#     if st.session_state.get("comp_results") is not None:
#         r = st.session_state["comp_results"]

#         divider()
#         k1, k2, k3, k4, k5 = st.columns(5)
#         k1.metric("Our Price",      f"₹{r['our_price']:,.0f}")
#         k2.metric("Market Average", f"₹{r['market_avg']:,.0f}")
#         k3.metric("Price Gap",      f"{r['price_gap']:+.1f}%")
#         k4.metric("Market Rank",    f"#{r['our_rank']} of {r['total_p']}")
#         k5.metric("Health Score",   f"{r['score']}/100")

#         divider()
#         active_tab = st.radio(
#             "View",
#             ["📊 Overview", "📈 Historical Trends", "⚔️ Price War Sim", "📋 Executive Summary"],
#             horizontal=True, key="comp_tab_nav", label_visibility="collapsed"
#         )
#         divider()

#         if active_tab == "📊 Overview":
#             section("📈", "Competitive Health Score")
#             st.markdown(health_bar(r["score"], r["pos_color"], r["position"]), unsafe_allow_html=True)
#             divider()

#             section("📋", "Market Price Breakdown")
#             all_players = {"Our Price": r["our_price"]}
#             all_players.update(r["comp_map"])
#             comp_rows = []
#             for name, price in all_players.items():
#                 vs_avg = safe_pct(price, r["market_avg"])
#                 vs_our = "—" if name == "Our Price" else f"{safe_pct(price, r['our_price']):+.1f}%"
#                 pos_label, _ = get_position_fallback(vs_avg)  # deterministic label for the fast table render
#                 comp_rows.append({"Company": name, "Price (₹)": round(price,2),
#                                    "vs Market Avg": f"{vs_avg:+.1f}%",
#                                    "vs Our Price": vs_our, "Position": pos_label})
#             st.dataframe(pd.DataFrame(comp_rows), use_container_width=True, hide_index=True)

#             divider()
#             section("📊", "Price Distribution")
#             chart_df = pd.DataFrame({"Company": list(all_players.keys()),
#                                      "Price": list(all_players.values())}).set_index("Company")
#             st.bar_chart(chart_df["Price"], height=220)

#             divider()
#             section("💸", "Revenue & Margin Impact")
#             ri1, ri2, ri3 = st.columns(3)
#             ri1.metric("Monthly Revenue @ Our Price", f"₹{r['rev_our']:,.0f}")
#             ri2.metric("vs Market-Avg Revenue", f"₹{r['rev_delta']:+,.0f}",
#                        delta=f"{safe_pct(r['rev_our'], r['rev_our'] - r['rev_delta']):+.1f}%")
#             ri3.metric(f"Premium over {r['cheapest_name']}", f"{r['prem_cheapest']:+.1f}%")

#             divider()
#             col_al, col_op = st.columns(2)
#             with col_al:
#                 section("🚨", "Executive Alerts (Cortex AI)")
#                 if r["alerts"]:
#                     for a in r["alerts"]: st.markdown(alert_chip(a), unsafe_allow_html=True)
#                 else:
#                     st.markdown(opp_chip("No critical threats detected"), unsafe_allow_html=True)
#             with col_op:
#                 section("🎯", "Market Opportunities (Cortex AI)")
#                 for o in r["opps"]: st.markdown(opp_chip(o), unsafe_allow_html=True)

#             divider()
#             col_f, col_r = st.columns(2)
#             with col_f:
#                 section("🔍", "Key Findings")
#                 st.write(f"• Market average: ₹{r['market_avg']:,.0f}")
#                 st.write(f"• Price gap: {r['price_gap']:+.1f}%")
#                 st.write(f"• Rank: #{r['our_rank']} of {r['total_p']} players")
#                 st.write(f"• Health score: {r['score']}/100")
#                 st.write(f"• Cheapest: {r['cheapest_name']} @ ₹{r['cheapest_price']:,.0f}")
#             with col_r:
#                 section("✅", "Recommended Actions (Cortex AI)")
#                 for i, rec in enumerate(r["recs"], 1): st.success(f"{i}. {rec}")

#             divider()
#             section("🎯", "Market Position Matrix")
#             # Position scores are now derived deterministically from each
#             # competitor's own gap-to-market-average via the same
#             # health_score() formula used for our own score (replaces the
#             # previously hardcoded placeholder values [92, 76, 65, 85]).
#             comp_names_list = list(r["comp_map"].keys())
#             comp_scores = [health_score(safe_pct(v, r["market_avg"])) for v in r["comp_map"].values()]
#             matrix_df = pd.DataFrame({
#                 "Company": ["Our", *comp_names_list],
#                 "Price":   [r["our_price"], *r["comp_map"].values()],
#                 "Position Score": [r["score"], *comp_scores],
#             })
#             st.scatter_chart(matrix_df, x="Price", y="Position Score", height=260)

#         elif active_tab == "📈 Historical Trends":
#             months = ["Jan","Feb","Mar","Apr","May","Jun"]
#             our_p  = r["our_price"]
#             comp_keys = list(r["comp_map"].keys())
#             comp_vals_list = list(r["comp_map"].values())
#             na_, nb_, nc_, nd_ = comp_keys
#             pa, pb, pc, pd_ = comp_vals_list

#             trend_df = pd.DataFrame({
#                 "Month":  months,
#                 "Our Price": [our_p*m for m in [.92,.95,.97,.99,1.01,1]],
#                 na_: [pa*m for m in [.90,.93,.95,.97,.99,1]],
#                 nb_: [pb*m for m in [.91,.94,.96,.98,1.00,1]],
#                 nc_: [pc*m for m in [.93,.95,.97,.99,1.01,1]],
#                 nd_: [pd_*m for m in [.92,.94,.96,.98,.99,1]],
#             })

#             section("📈", "6-Month Competitor Price Trends")
#             st.line_chart(trend_df.set_index("Month"), height=260)

#             divider()
#             section("📊", "Our Price vs Market Average")
#             trend_df["Market Average"] = trend_df[[na_, nb_, nc_, nd_]].mean(axis=1)
#             st.line_chart(trend_df[["Month","Our Price","Market Average"]].set_index("Month"), height=200)

#             divider()
#             section("📉", "Price Gap Trend (%)")
#             trend_df["Gap %"] = ((trend_df["Our Price"] - trend_df["Market Average"])
#                                  / trend_df["Market Average"]) * 100
#             st.line_chart(trend_df[["Month","Gap %"]].set_index("Month"), height=160)

#             divider()
#             section("📋", "Trend Summary")
#             st.dataframe(pd.DataFrame({
#                 "Metric": ["Current Price","Average Market Price","Highest Competitor",
#                            "Lowest Competitor","Price Gap %"],
#                 "Value":  [round(r["our_price"],2), round(r["market_avg"],2),
#                            round(r["market_max"],2), round(r["market_min"],2),
#                            round(r["price_gap"],2)],
#             }), use_container_width=True, hide_index=True)

#             divider()
#             section("🔍", "Trend Insights (Cortex AI)")
#             # AI_AGG summarizes the trend across all players in one Cortex call
#             # (replaces the fixed if/elif trend-insight text).
#             trend_row_texts = [
#                 f"{col}: prices moved from {trend_df[col].iloc[0]:.0f} to {trend_df[col].iloc[-1]:.0f} over 6 months"
#                 for col in [na_, nb_, nc_, nd_, "Our Price"]
#             ]
#             trend_insight = ai_agg_over_rows(
#                 trend_row_texts,
#                 "Summarize the competitive pricing trend across these players in 2 sentences "
#                 "and state whether our price is becoming more or less competitive.",
#                 cache_key=_ai_cache_key("trend_insight", tuple(trend_row_texts))
#             )
#             if trend_insight:
#                 st.info(trend_insight)
#             elif r["price_gap"] > 5:
#                 st.warning("Our product is priced noticeably above the market. Sales volume may reduce if competitors maintain lower prices.")
#             elif r["price_gap"] < -5:
#                 st.success("Our product is cheaper than competitors. There may be room to increase the selling price.")
#             else:
#                 st.info("Our pricing is closely aligned with the market. Current strategy appears competitive.")

#             divider()
#             section("📌", "Executive Trend Summary")
#             trend_summary = (
#                 f"Current Product : {r['sku']}\n"
#                 f"Our Price       : ₹{r['our_price']:,.2f}\n"
#                 f"Market Average  : ₹{r['market_avg']:,.2f}\n"
#                 f"Highest Comp.   : ₹{r['market_max']:,.2f}\n"
#                 f"Lowest Comp.    : ₹{r['market_min']:,.2f}\n"
#                 f"Price Gap       : {r['price_gap']:.2f}%\n"
#                 f"Market Rank     : #{r['our_rank']} of {r['total_p']}\n\n"
#                 f"Recommendation  : "
#                 + ("Increase price — opportunity exists." if r['price_gap'] < -5
#                    else "Monitor competitors closely." if r['price_gap'] > 5
#                    else "Maintain current pricing.")
#             )
#             st.text_area("", trend_summary, height=220, key="comp_trend_summary_out")

#         elif active_tab == "⚔️ Price War Sim":
#             section("⚔️", "Price War Simulator")
#             st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Simulate competitor price cuts and see the impact on your market position.</p>', unsafe_allow_html=True)

#             pw1, pw2 = st.columns([3, 1])
#             with pw1:
#                 comp_drop = st.slider("Competitor Price Change %", -40, 40, -15, key="comp_drop_slider")
#             with pw2:
#                 st.markdown(
#                     f"<br><div style='font-size:22px;font-weight:700;"
#                     f"color:{'#EF4444' if comp_drop < 0 else '#00C7B2'};text-align:center'>"
#                     f"{comp_drop:+d}%</div>", unsafe_allow_html=True
#                 )

#             sim_prices = {k: v*(1+comp_drop/100) for k,v in r["comp_map"].items()}
#             sim_avg    = sum(sim_prices.values())/len(sim_prices)
#             sim_gap    = safe_pct(r["our_price"], sim_avg)
#             sim_score  = health_score(sim_gap)
#             sim_pos, sim_color = get_position_fallback(sim_gap)  # deterministic for real-time slider interaction
#             rev_risk   = abs(r["our_price"] - sim_avg) * r["monthly_vol"]

#             divider()
#             pw_c1,pw_c2,pw_c3,pw_c4 = st.columns(4)
#             pw_c1.metric("Current Market Avg",   f"₹{r['market_avg']:,.0f}")
#             pw_c2.metric("Simulated Market Avg", f"₹{sim_avg:,.0f}", delta=f"{comp_drop:+d}% change")
#             pw_c3.metric("New Gap vs Market",    f"{sim_gap:+.1f}%")
#             pw_c4.metric("Simulated Position",   sim_pos)

#             divider()
#             col_bh, col_ah = st.columns(2)
#             with col_bh:
#                 st.markdown("**Current position**")
#                 st.markdown(health_bar(r["score"], r["pos_color"], r["position"]), unsafe_allow_html=True)
#             with col_ah:
#                 st.markdown("**After competitor price change**")
#                 st.markdown(health_bar(sim_score, sim_color, sim_pos), unsafe_allow_html=True)

#             divider()
#             st.metric("Revenue At Risk from Price Gap", f"₹{rev_risk:,.0f}")

#             divider()
#             section("📋", "Simulated Market Prices")
#             sim_rows = [{"Company": "Our Price (unchanged)",
#                          "Original (₹)": round(r["our_price"],2),
#                          "Simulated (₹)": round(r["our_price"],2), "Change": "—"}]
#             for name, orig in r["comp_map"].items():
#                 sim_rows.append({"Company": name, "Original (₹)": round(orig,2),
#                                   "Simulated (₹)": round(sim_prices[name],2), "Change": f"{comp_drop:+d}%"})
#             st.dataframe(pd.DataFrame(sim_rows), use_container_width=True, hide_index=True)

#         elif active_tab == "📋 Executive Summary":
#             section("📋", "Executive Summary Report")

#             # AI_SUMMARIZE_AGG-style narrative — condenses the full competitive
#             # picture (alerts + opportunities + recs) into an executive narrative.
#             exec_facts = (
#                 f"SKU {r['sku']}, our price ₹{r['our_price']:,.2f} vs market average "
#                 f"₹{r['market_avg']:,.2f} (gap {r['price_gap']:+.1f}%), rank #{r['our_rank']} "
#                 f"of {r['total_p']}, health score {r['score']}/100, position {r['position']}. "
#                 f"Alerts: {'; '.join(r['alerts']) if r['alerts'] else 'none'}. "
#                 f"Opportunities: {'; '.join(r['opps'])}."
#             )
#             ai_exec_narrative = ai_summarize(exec_facts, cache_key=_ai_cache_key("comp_exec_narrative", exec_facts))

#             exec_summary = (
#                 f"SKU                 : {r['sku']}\n"
#                 f"Our Price           : ₹{r['our_price']:,.2f}\n"
#                 f"Market Average      : ₹{r['market_avg']:,.2f}\n"
#                 f"Lowest Competitor   : {r['cheapest_name']} @ ₹{r['cheapest_price']:,.2f}\n"
#                 f"Highest Competitor  : ₹{r['market_max']:,.2f}\n"
#                 f"Price Gap           : {r['price_gap']:+.2f}%\n"
#                 f"Market Rank         : #{r['our_rank']} of {r['total_p']}\n"
#                 f"Health Score        : {r['score']}/100\n"
#                 f"Position            : {r['position']}\n"
#                 f"Monthly Volume      : {r['monthly_vol']:,} units\n"
#                 f"Monthly Revenue     : ₹{r['rev_our']:,.0f}\n"
#                 f"Revenue vs Avg      : ₹{r['rev_delta']:+,.0f}\n"
#                 f"Premium vs Cheapest : {r['prem_cheapest']:+.1f}%\n\n"
#                 + (f"AI Narrative\n------------\n{ai_exec_narrative}\n\n" if ai_exec_narrative else "")
#                 + f"Key Alerts\n----------\n"
#                 + (("\n".join("• " + a for a in r["alerts"])) if r["alerts"] else "• No critical alerts")
#                 + f"\n\nMarket Opportunities\n--------------------\n"
#                 + "\n".join("• " + o for o in r["opps"])
#                 + f"\n\nRecommended Actions\n-------------------\n"
#                 + "\n".join(f"{i+1}. {rec}" for i, rec in enumerate(r["recs"]))
#             )
#             st.text_area("", exec_summary, height=360, key="comp_exec_out")

#             divider()
#             col_al2, col_op2 = st.columns(2)
#             with col_al2:
#                 section("🚨", "Alerts Recap")
#                 if r["alerts"]:
#                     for a in r["alerts"]: st.markdown(alert_chip(a), unsafe_allow_html=True)
#                 else:
#                     st.markdown(opp_chip("No critical alerts"), unsafe_allow_html=True)
#             with col_op2:
#                 section("🎯", "Opportunities Recap")
#                 for o in r["opps"]: st.markdown(opp_chip(o), unsafe_allow_html=True)

#             divider()
#             section("💡", "Executive Recommendation (Cortex AI)")
#             final_rec_ai = ai_complete(
#                 f"In one direct executive sentence, recommend whether to raise, hold, or lower "
#                 f"price for SKU {r['sku']} given a {r['price_gap']:+.1f}% gap to market average "
#                 f"and health score {r['score']}/100.",
#                 cache_key=_ai_cache_key("comp_final_rec", r["sku"], round(r["price_gap"], 1))
#             )
#             if final_rec_ai:
#                 if r["price_gap"] > 10:
#                     st.error(f"⚠️ {final_rec_ai}")
#                 elif r["price_gap"] < -5:
#                     st.success(f"✅ {final_rec_ai}")
#                 else:
#                     st.info(f"ℹ️ {final_rec_ai}")
#             else:
#                 if r["price_gap"] > 10:
#                     st.error("⚠️ Highest priced in market. High risk of losing customers. Review price immediately.")
#                 elif r["price_gap"] < -5:
#                     st.success("✅ Lowest or near-lowest price in market. Opportunity to increase price and capture additional margin.")
#                 else:
#                     st.info("ℹ️ Product is competitively positioned. Continue monitoring market and maintain current strategy.")


# # ════════════════════════════════════════════════════════════════════════
# # TAB 9 — 📈 AI DEMAND FORECASTING & DYNAMIC MARKET INTELLIGENCE
# # Reuses: session, section(), divider(), health_bar_html(), safe_pct_change(),
# # _ai_cache_key(), _sql_escape(), ai_complete/ai_classify/ai_filter/
# # ai_agg_over_rows/ai_summarize, parse_ai_json, ai_or_fallback,
# # ai_reason_score, ai_reason_score_batch, render_ai_score_card, AI memory + cache.
# # NO FAKE DATA: forecasts come ONLY from real rows in CORE_INPUT.DEMAND_HISTORY.
# # Deterministic math for numbers; Cortex AI for interpretation only.
# # ════════════════════════════════════════════════════════════════════════
# if _active_tab == "📈 AI Demand Forecasting":    
#     import numpy as np

#     # ── Optional Plotly (matches your dark theme). Falls back to native SiS
#     #    charts if Plotly is unavailable, so the tab never crashes. ──
#     try:
#         import plotly.graph_objects as go
#         _PLOTLY_OK = True
#     except Exception:
#         _PLOTLY_OK = False

#     _NDM_LAYOUT = dict(
#         paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
#         font=dict(color="#E6EDF3", size=12),
#         margin=dict(l=10, r=10, t=34, b=10),
#         legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
#         xaxis=dict(gridcolor="rgba(255,255,255,0.08)"),
#         yaxis=dict(gridcolor="rgba(255,255,255,0.08)"),
#     )
#     _C_TEAL, _C_BLUE, _C_AMBER, _C_RED, _C_PURPLE = (
#         "#00C7B2", "#38BDF8", "#F59E0B", "#EF4444", "#A78BFA")

#     # ── Safe loaders (own copies; tab2's _safe_load is out of scope here) ──
#     def _ndm_load(query: str) -> pd.DataFrame:
#         try:
#             return session.sql(query).to_pandas()
#         except Exception:
#             return pd.DataFrame()

#     def _ndm_table_exists(fqtn: str) -> bool:
#         try:
#             session.sql(f"SELECT 1 FROM {fqtn} LIMIT 1").collect()
#             return True
#         except Exception:
#             return False

#     # ── Chart helpers (Plotly first, native fallback) ──
    
#     def _ndm_line(df, x, series: dict, title, height=300):
#         # series: {col_name: color}
#         st.caption(title)
#         if df is None or df.empty:

#             st.info("No data to plot.")
#             return
#         if _PLOTLY_OK:
#             fig = go.Figure()
#             for col, color in series.items():
#                 if col in df.columns:
#                     fig.add_trace(go.Scatter(
#                         x=df[x], y=df[col], name=col, mode="lines+markers",
#                         line=dict(color=color, width=2)))
#             fig.update_layout(**_NDM_LAYOUT, height=height)
#             st.plotly_chart(fig, use_container_width=True)
#         else:
#             st.line_chart(df.set_index(x)[[c for c in series if c in df.columns]], height=height)

#     def _ndm_forecast_plot(hist_df, fc_df, qty_col, title, height=340):
#         st.caption(title)
#         if _PLOTLY_OK:
#             fig = go.Figure()
#             # confidence band
#             fig.add_trace(go.Scatter(
#                 x=list(fc_df["PERIOD"]) + list(fc_df["PERIOD"][::-1]),
#                 y=list(fc_df["UPPER"]) + list(fc_df["LOWER"][::-1]),
#                 fill="toself", fillcolor="rgba(56,189,248,0.15)",
#                 line=dict(color="rgba(0,0,0,0)"), name="Confidence Range",
#                 hoverinfo="skip"))
#             fig.add_trace(go.Scatter(
#                 x=hist_df["PERIOD"], y=hist_df[qty_col], name="Historical Demand",
#                 mode="lines+markers", line=dict(color=_C_TEAL, width=2)))
#             fig.add_trace(go.Scatter(
#                 x=fc_df["PERIOD"], y=fc_df["FORECAST"], name="Forecast",
#                 mode="lines+markers", line=dict(color=_C_BLUE, width=2, dash="dash")))
#             fig.update_layout(**_NDM_LAYOUT, height=height)
#             st.plotly_chart(fig, use_container_width=True)
#         else:
#             h = hist_df.rename(columns={qty_col: "Historical"})[["PERIOD", "Historical"]]
#             f = fc_df.rename(columns={"FORECAST": "Forecast"})[["PERIOD", "Forecast", "LOWER", "UPPER"]]
#             merged = pd.concat([h, f], ignore_index=True).set_index("PERIOD")
#             st.line_chart(merged, height=height)

#     # ── Deterministic forecast engine (linear trend + residual CI band) ──
#     def _ndm_forecast(series_df, date_col, qty_col, periods_ahead, min_points=4):
#         """Returns dict with history(agg), forecast(df), confidence(0-100 from R²),
#         slope, n. All numbers traceable to real rows — no AI, no fabrication."""
#         if series_df is None or series_df.empty:
#             return None
#         df = series_df[[date_col, qty_col]].copy()
#         df[date_col] = pd.to_datetime(df[date_col], errors="coerce")
#         df = df.dropna(subset=[date_col, qty_col])
#         if df.empty:
#             return None
#         df["PERIOD"] = df[date_col].dt.to_period("M").dt.to_timestamp()
#         agg = df.groupby("PERIOD")[qty_col].sum().reset_index().sort_values("PERIOD")
#         agg = agg.rename(columns={qty_col: "QTY"})
#         n = len(agg)
#         if n < min_points:
#             return {"insufficient": True, "history": agg, "n": n}
#         x = np.arange(n, dtype=float)
#         y = agg["QTY"].values.astype(float)
#         slope, intercept = np.polyfit(x, y, 1)
#         fitted = slope * x + intercept
#         resid = y - fitted
#         ss_res = float(np.sum(resid ** 2))
#         ss_tot = float(np.sum((y - y.mean()) ** 2))
#         r2 = (1 - ss_res / ss_tot) if ss_tot > 0 else 0.0
#         resid_std = float(np.std(resid, ddof=1)) if n > 2 else float(np.std(resid))
#         agg["MOVING_AVG"] = agg["QTY"].rolling(window=min(3, n), min_periods=1).mean()
#         fx = np.arange(n, n + periods_ahead, dtype=float)
#         fy = np.clip(slope * fx + intercept, 0, None)
#         z = 1.645  # ~90% band
#         lower = np.clip(fy - z * resid_std, 0, None)
#         upper = fy + z * resid_std
#         step = agg["PERIOD"].diff().median()
#         if pd.isna(step) or step == pd.Timedelta(0):
#             step = pd.Timedelta(days=30)
#         last = agg["PERIOD"].iloc[-1]
#         fut = [last + step * (i + 1) for i in range(periods_ahead)]
#         fc = pd.DataFrame({"PERIOD": fut, "FORECAST": fy, "LOWER": lower, "UPPER": upper})
#         return {"insufficient": False, "history": agg, "forecast": fc,
#                 "confidence": max(0.0, min(100.0, r2 * 100)), "r2": r2,
#                 "slope": float(slope), "n": n, "resid_std": resid_std,
#                 "recent": float(y[-1]), "fc_avg": float(np.mean(fy)),
#                 "fc_total": float(np.sum(fy))}

#     # ── HEADER ──
#     section("📈", "AI Demand Forecasting & Dynamic Market Intelligence")
#     st.markdown(
#         '<div style="opacity:.75;margin-top:-6px">Forecasts future demand from real '
#         'order history, then fuses pricing, PSI, capacity and competitor signals into '
#         'Cortex AI-driven market intelligence.</div>',
#         unsafe_allow_html=True)
#     divider()

#     # ── Load reusable snapshot tables (never crash if one is missing) ──
#     costs_df = _ndm_load("SELECT SKU, TOTAL_COST FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS")
#     matrix_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX")
#     pricing_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING")
#     psi_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY")
#     cap_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY")
#     comp_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING")

#     DEMAND_TBL = "PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY"
#     has_demand_tbl = _ndm_table_exists(DEMAND_TBL)
#     demand_df = _ndm_load(f"SELECT * FROM {DEMAND_TBL}") if has_demand_tbl else pd.DataFrame()
#     has_demand = has_demand_tbl and not demand_df.empty and "QUANTITY" in demand_df.columns \
#         and "DEMAND_DATE" in demand_df.columns

#     if not has_demand:
#         st.warning(
#             "⚠️ **Historical demand data required.** No usable rows found in "
#             f"`{DEMAND_TBL}`. Create/load that table (SQL provided with this feature) "
#             "with **real ERP/order history** to unlock forecasting. "
#             "All snapshot-based intelligence below (pricing, PSI, capacity, competitor) "
#             "still works now; demand/forecast/revenue-forecast sections activate "
#             "automatically once real data exists.")

#     # Representative selling price per SKU (deterministic, from real snapshot)
#     def _ndm_price_for_sku(sku):
#         try:
#             if not pricing_df9.empty and {"SKU", "DISCOUNTED_PRICE"}.issubset(pricing_df9.columns):
#                 s = pricing_df9[pricing_df9["SKU"] == sku]["DISCOUNTED_PRICE"]
#                 if not s.empty:
#                     return float(s.mean())
#             if not matrix_df9.empty and {"SKU", "TARGET_PRICE"}.issubset(matrix_df9.columns):
#                 s = matrix_df9[matrix_df9["SKU"] == sku]["TARGET_PRICE"]
#                 if not s.empty:
#                     return float(s.mean())
#         except Exception:
#             pass
#         return None

#     # ── 6. FILTERS ──
#     section("🎛️", "Filters")
#     HORIZON_MAP = {"30 Days": 1, "90 Days": 3, "6 Months": 6, "12 Months": 12}
#     fc1, fc2, fc3, fc4 = st.columns(4)

#     prod_opts = ["All Products"]
#     cust_opts = ["All Customers"]
#     region_opts = ["All Regions"]
#     if has_demand:
#         prod_opts += sorted(demand_df["SKU"].dropna().unique().tolist()) if "SKU" in demand_df.columns else []
#         if "CUSTOMER_ID" in demand_df.columns:
#             cust_opts += sorted(demand_df["CUSTOMER_ID"].dropna().unique().tolist())
#         if "REGION" in demand_df.columns and demand_df["REGION"].notna().any():
#             region_opts += sorted(demand_df["REGION"].dropna().unique().tolist())
#     else:
#         if not costs_df.empty:
#             prod_opts += sorted(costs_df["SKU"].dropna().unique().tolist())

#     with fc1:
#         f_product = st.selectbox("Product", prod_opts, key="ndm_product")
#     with fc2:
#         f_customer = st.selectbox("Customer", cust_opts, key="ndm_customer")
#     with fc3:
#         f_horizon = st.selectbox("Forecast Horizon", list(HORIZON_MAP.keys()), index=2, key="ndm_horizon")
#     with fc4:
#         f_region = st.selectbox("Region", region_opts, key="ndm_region")
#     periods = HORIZON_MAP[f_horizon]

#     # Build the filtered demand slice (real rows only)
#     scope = demand_df.copy() if has_demand else pd.DataFrame()
#     if has_demand:
#         if f_product != "All Products" and "SKU" in scope.columns:
#             scope = scope[scope["SKU"] == f_product]
#         if f_customer != "All Customers" and "CUSTOMER_ID" in scope.columns:
#             scope = scope[scope["CUSTOMER_ID"] == f_customer]
#         if f_region != "All Regions" and "REGION" in scope.columns:
#             scope = scope[scope["REGION"] == f_region]

#     # Master forecast for current scope
#     scope_fc = _ndm_forecast(scope, "DEMAND_DATE", "QUANTITY", periods) if has_demand else None
#     divider()

#     # ── 7. DEMAND KPI CARDS ──
#     section("📊", "Demand KPIs")
#     if scope_fc and not scope_fc.get("insufficient"):
#         rep_price = None
#         if f_product != "All Products":
#             rep_price = _ndm_price_for_sku(f_product)
#         if rep_price is None and "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
#             rep_price = float(scope["SELLING_PRICE"].mean())
#         cur_demand = scope_fc["recent"]
#         fc_demand = scope_fc["fc_total"]
#         change_pct = safe_pct_change(scope_fc["fc_avg"], cur_demand)
#         fc_rev = fc_demand * rep_price if rep_price else None
#         conf = scope_fc["confidence"]

#         risk_payload = ai_reason_score(
#             module="demand_forecast", decision_type="demand_risk",
#             context_facts=(
#                 f"Scope: product={f_product}, customer={f_customer}, region={f_region}.\n"
#                 f"Recent monthly demand: {cur_demand:,.0f} units.\n"
#                 f"Avg forecast monthly demand ({f_horizon}): {scope_fc['fc_avg']:,.0f} units.\n"
#                 f"Trend slope: {scope_fc['slope']:+.1f} units/month over {scope_fc['n']} months.\n"
#                 f"Forecast confidence (fit R²): {conf:.0f}%."),
#             extra_instruction=("Assess demand risk. 'score' = demand health (higher=healthier). "
#                                "Consider volatility, trend direction and forecast confidence."),
#             cache_key=_ai_cache_key("ndm_risk", f_product, f_customer, f_region, f_horizon,
#                                     round(cur_demand), round(scope_fc['fc_avg'])))
#         risk_label = risk_payload["label"] if risk_payload.get("ai_generated") else "AI Unavailable"

#         k1, k2, k3, k4, k5, k6 = st.columns(6)
#         k1.metric("Current Demand", f"{cur_demand:,.0f}")
#         k2.metric("Forecast Demand", f"{fc_demand:,.0f}")
#         k3.metric("Expected Change", f"{change_pct:+.1f}%")
#         k4.metric("Forecast Revenue", f"₹{fc_rev:,.0f}" if fc_rev is not None else "N/A")
#         k5.metric("Forecast Confidence", f"{conf:.0f}%")
#         k6.metric("Demand Risk", risk_label)
#     elif scope_fc and scope_fc.get("insufficient"):
#         st.info(f"Only {scope_fc['n']} month(s) of history in the current scope — need ≥ 4 to forecast. "
#                 "Widen the filters or load more history.")
#     else:
#         c1, c2, c3, c4, c5, c6 = st.columns(6)
#         for c, lbl in zip([c1, c2, c3, c4, c5, c6],
#                            ["Current Demand", "Forecast Demand", "Expected Change",
#                             "Forecast Revenue", "Forecast Confidence", "Demand Risk"]):
#             c.metric(lbl, "N/A")
#         st.caption("KPIs populate once real demand history is available.")
#     divider()

#     # ── 8. HISTORICAL DEMAND ──
#     section("📊", "Historical Demand")
#     if has_demand and scope_fc and not scope_fc.get("insufficient"):
#         hist = scope_fc["history"]
#         _ndm_line(hist, "PERIOD",
#                   {"QTY": _C_TEAL, "MOVING_AVG": _C_AMBER},
#                   "Actual Demand vs 3-Month Moving Average (units)")
#         if "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
#             price_hist = scope.copy()
#             price_hist["PERIOD"] = pd.to_datetime(price_hist["DEMAND_DATE"], errors="coerce") \
#                 .dt.to_period("M").dt.to_timestamp()
#             price_series = price_hist.groupby("PERIOD")["SELLING_PRICE"].mean().reset_index()
#             _ndm_line(price_series, "PERIOD", {"SELLING_PRICE": _C_BLUE},
#                       "Historical Average Selling Price (₹)")
#     else:
#         st.info("Historical demand chart requires real rows in DEMAND_HISTORY.")
#     divider()

#     # ── 9. AI DEMAND FORECAST ──
#     section("🔮", "AI Demand Forecast")
#     if scope_fc and not scope_fc.get("insufficient"):
#         _ndm_forecast_plot(scope_fc["history"], scope_fc["forecast"], "QTY",
#                            f"Demand Forecast — next {f_horizon} (90% confidence band)")
#         show = scope_fc["forecast"].copy()
#         show["PERIOD"] = show["PERIOD"].dt.strftime("%Y-%m")
#         show = show.rename(columns={"PERIOD": "Forecast Date", "FORECAST": "Forecast Demand",
#                                     "LOWER": "Lower Bound", "UPPER": "Upper Bound"})
#         show["Confidence"] = f"{scope_fc['confidence']:.0f}%"
#         for c in ["Forecast Demand", "Lower Bound", "Upper Bound"]:
#             show[c] = show[c].round(0)
#         st.dataframe(show, use_container_width=True, hide_index=True)
#         st.caption("Forecast = deterministic linear trend on real monthly demand; "
#                    "band = ±1.645·residual σ; confidence = fit R². No values are AI-invented.")
#     else:
#         st.info("Forecast activates once ≥ 4 months of real demand exist in the current scope.")
#     divider()
# # ── 9b. SAVE FORECAST TO SNOWFLAKE (mirrors OPTIMIZATION_RESULTS pattern) ──
#     if scope_fc and not scope_fc.get("insufficient"):
#         if st.button("💾 Save Forecast to Snowflake", key="ndm_save_fc",
#                      use_container_width=True):
#             try:
#                 # Representative price for revenue (same logic as KPI/Revenue sections)
#                 _rp = None
#                 if f_product != "All Products":
#                     _rp = _ndm_price_for_sku(f_product)
#                 if _rp is None and "SELLING_PRICE" in scope.columns \
#                         and scope["SELLING_PRICE"].notna().any():
#                     _rp = float(scope["SELLING_PRICE"].mean())

#                 run_id = _ai_cache_key("fc_run", f_product, f_customer, f_region,
#                                        f_horizon, str(pd.Timestamp.utcnow()))
#                 save_fc = scope_fc["forecast"].copy()
#                 save_df = pd.DataFrame({
#                     "RUN_ID": run_id,
#                     "SCOPE_PRODUCT": f_product,
#                     "SCOPE_CUSTOMER": f_customer,
#                     "SCOPE_REGION": f_region,
#                     "HORIZON": f_horizon,
#                     "FORECAST_DATE": pd.to_datetime(save_fc["PERIOD"]).dt.date,
#                     "FORECAST_DEMAND": save_fc["FORECAST"].round(2),
#                     "LOWER_BOUND": save_fc["LOWER"].round(2),
#                     "UPPER_BOUND": save_fc["UPPER"].round(2),
#                     "CONFIDENCE_PCT": round(scope_fc["confidence"], 2),
#                     "TREND_SLOPE": round(scope_fc["slope"], 4),
#                     "REP_PRICE": (round(_rp, 2) if _rp is not None else None),
#                     "FORECAST_REVENUE": (
#                         (save_fc["FORECAST"] * _rp).round(2) if _rp is not None else None),
#                     "CREATED_AT": pd.Timestamp.utcnow(),
#                 })
#                 snow_df = session.create_dataframe(save_df)
#                 snow_df.write.mode("append").save_as_table(
#                     "PRICING_ENGINE_DB.CORE_OUTPUT.DEMAND_FORECAST_RESULTS")
#                 st.success(f"✅ Saved {len(save_df)} forecast row(s) to "
#                            f"CORE_OUTPUT.DEMAND_FORECAST_RESULTS (run {run_id[:8]}).")
#             except Exception as e:
#                 st.warning(f"Save skipped: {e}")
#     divider()
#     # ── 10. DEMAND TREND INTELLIGENCE (Cortex interprets, no fixed rules) ──
#     section("🧭", "Demand Trend Intelligence")
#     if scope_fc and not scope_fc.get("insufficient"):
#         trend_label = ai_classify(
#             f"Monthly demand over {scope_fc['n']} months has trend slope "
#             f"{scope_fc['slope']:+.1f} units/month, fit R² {scope_fc['r2']:.2f}, "
#             f"recent value {scope_fc['recent']:,.0f}. Classify the demand pattern.",
#             ["Growth", "Stable", "Declining", "Volatile", "Seasonal", "Uncertain"],
#             cache_key=_ai_cache_key("ndm_trend_cls", f_product, f_customer, f_region,
#                                     round(scope_fc['slope'], 1), round(scope_fc['r2'], 2)))
#         trend_payload = ai_reason_score(
#             module="demand_forecast", decision_type="trend_intelligence",
#             context_facts=(
#                 f"Scope product={f_product}, customer={f_customer}.\n"
#                 f"Trend slope {scope_fc['slope']:+.1f} units/month, R² {scope_fc['r2']:.2f}, "
#                 f"{scope_fc['n']} months, recent {scope_fc['recent']:,.0f}, "
#                 f"forecast avg {scope_fc['fc_avg']:,.0f} for {f_horizon}."),
#             extra_instruction=("'score' = demand outlook strength (higher=better). Provide key "
#                                "drivers as opportunities and risk factors as risks."),
#             cache_key=_ai_cache_key("ndm_trend", f_product, f_customer, f_region, f_horizon,
#                                     round(scope_fc['slope'], 1)))
#         tc1, tc2 = st.columns([1, 1.4])
#         with tc1:
#             st.metric("Demand Trend", trend_label or "AI Unavailable")
#             st.metric("AI Confidence",
#                       f"{trend_payload['confidence']:.0f}%" if trend_payload.get("ai_generated") else "N/A")
#         with tc2:
#             render_ai_score_card(trend_payload, title_prefix="Demand Outlook")
#     else:
#         st.info("Trend intelligence requires a valid forecast in the current scope.")
#     divider()

#     # ── 11. PRODUCT DEMAND INTELLIGENCE (batched Cortex classification) ──
#     section("📦", "Product Demand Intelligence")
#     if has_demand and "SKU" in demand_df.columns:
#         prod_rows, prod_ctx = [], []
#         top_skus = (demand_df.groupby("SKU")["QUANTITY"].sum()
#                     .sort_values(ascending=False).head(12).index.tolist())
#         for sku in top_skus:
#             sdf = demand_df[demand_df["SKU"] == sku]
#             f = _ndm_forecast(sdf, "DEMAND_DATE", "QUANTITY", periods)
#             if not f or f.get("insufficient"):
#                 continue
#             price = _ndm_price_for_sku(sku)
#             chg = safe_pct_change(f["fc_avg"], f["recent"])
#             rev_opp = (f["fc_total"] * price) if price else None
#             prod_rows.append({
#                 "Product": sku, "Current Demand": round(f["recent"]),
#                 "Forecast Demand": round(f["fc_total"]), "Expected Change": f"{chg:+.1f}%",
#                 "Revenue Opportunity": (f"₹{rev_opp:,.0f}" if rev_opp is not None else "N/A"),
#                 "_slope": f["slope"], "_r2": f["r2"]})
#             prod_ctx.append(f"Product {sku}: recent {f['recent']:,.0f} units, forecast avg "
#                             f"{f['fc_avg']:,.0f}, change {chg:+.1f}%, slope {f['slope']:+.1f}, R² {f['r2']:.2f}")
#         if prod_rows:
#             cls = ai_reason_score_batch(
#                 module="demand_forecast", decision_type="product_demand_class",
#                 items_context=prod_ctx,
#                 extra_instruction=("Classify each product's demand as one of High Growth, Stable, "
#                                    "Declining, Volatile, Strategic, At Risk. 'label' = that class; "
#                                    "'reasoning' = one-line AI recommendation."),
#                 cache_key=_ai_cache_key("ndm_prod_intel", f_horizon, tuple(prod_ctx)))
#             out = pd.DataFrame(prod_rows).drop(columns=["_slope", "_r2"])
#             out["Demand Classification"] = [c["label"] if c.get("ai_generated") else "AI Unavailable" for c in cls]
#             out["Risk"] = [f"{100 - c['score']:.0f}/100" if c.get("ai_generated") and c["score"] is not None
#                            else "N/A" for c in cls]
#             out["AI Recommendation"] = [c["reasoning"] if c.get("ai_generated") else "—" for c in cls]
#             st.dataframe(out, use_container_width=True, hide_index=True)
#         else:
#             st.info("Not enough per-product history yet to classify demand.")
#     else:
#         st.info("Product demand intelligence requires real DEMAND_HISTORY rows.")
#     divider()

#     # ── 12. CUSTOMER DEMAND INTELLIGENCE ──
#     section("👥", "Customer Demand Intelligence")
#     if has_demand and "CUSTOMER_ID" in demand_df.columns and demand_df["CUSTOMER_ID"].notna().any():
#         cust_rows, cust_ctx = [], []
#         top_custs = (demand_df.groupby("CUSTOMER_ID")["QUANTITY"].sum()
#                      .sort_values(ascending=False).head(12).index.tolist())
#         seg_map = {}
#         if not psi_df9.empty and {"CUSTOMER_ID", "CUSTOMER_SEGMENT"}.issubset(psi_df9.columns):
#             seg_map = dict(zip(psi_df9["CUSTOMER_ID"], psi_df9["CUSTOMER_SEGMENT"]))
#         for cust in top_custs:
#             cdf = demand_df[demand_df["CUSTOMER_ID"] == cust]
#             f = _ndm_forecast(cdf, "DEMAND_DATE", "QUANTITY", periods)
#             if not f or f.get("insufficient"):
#                 continue
#             price = None
#             if "SELLING_PRICE" in cdf.columns and cdf["SELLING_PRICE"].notna().any():
#                 price = float(cdf["SELLING_PRICE"].mean())
#             chg = safe_pct_change(f["fc_avg"], f["recent"])
#             rev_pot = (f["fc_total"] * price) if price else None
#             seg = seg_map.get(cust, "N/A")
#             cust_rows.append({
#                 "Customer": cust, "Segment": seg, "Historical Volume": round(f["history"]["QTY"].sum()),
#                 "Forecast Volume": round(f["fc_total"]), "Expected Change": f"{chg:+.1f}%",
#                 "Revenue Potential": (f"₹{rev_pot:,.0f}" if rev_pot is not None else "N/A")})
#             cust_ctx.append(f"Customer {cust} (segment {seg}): recent {f['recent']:,.0f}, "
#                             f"forecast avg {f['fc_avg']:,.0f}, change {chg:+.1f}%, slope {f['slope']:+.1f}")
#         if cust_rows:
#             cls = ai_reason_score_batch(
#                 module="demand_forecast", decision_type="customer_demand_class",
#                 items_context=cust_ctx,
#                 extra_instruction=("Classify each account as one of Growing, Stable, Declining, "
#                                    "Potential Expansion, At Risk. 'label' = that class; 'reasoning' "
#                                    "= one-line AI recommendation."),
#                 cache_key=_ai_cache_key("ndm_cust_intel", f_horizon, tuple(cust_ctx)))
#             out = pd.DataFrame(cust_rows)
#             out["Customer Demand Outlook"] = [c["label"] if c.get("ai_generated") else "AI Unavailable" for c in cls]
#             out["AI Recommendation"] = [c["reasoning"] if c.get("ai_generated") else "—" for c in cls]
#             st.dataframe(out, use_container_width=True, hide_index=True)
#         else:
#             st.info("Not enough per-customer history yet to classify accounts.")
#     else:
#         st.info("Customer demand intelligence requires DEMAND_HISTORY with CUSTOMER_ID.")
#     divider()

#     # ── 13. PRICE vs DEMAND INTELLIGENCE ──
#     section("💰", "Price vs Demand Intelligence")
#     if has_demand and {"SELLING_PRICE", "QUANTITY"}.issubset(scope.columns) \
#             and scope["SELLING_PRICE"].notna().any():
#         pv = scope.dropna(subset=["SELLING_PRICE", "QUANTITY"]).copy()
#         if _PLOTLY_OK and not pv.empty:
#             fig = go.Figure(go.Scatter(
#                 x=pv["SELLING_PRICE"], y=pv["QUANTITY"], mode="markers",
#                 marker=dict(color=_C_PURPLE, size=8, opacity=0.7), name="Orders"))
#             fig.update_layout(**_NDM_LAYOUT, height=320,
#                               xaxis_title="Selling Price (₹)", yaxis_title="Quantity (units)")
#             st.caption("Selling Price vs Order Quantity")
#             st.plotly_chart(fig, use_container_width=True)
#         elif not pv.empty:
#             st.caption("Selling Price vs Order Quantity")
#             st.scatter_chart(pv, x="SELLING_PRICE", y="QUANTITY", height=320)
#         try:
#             corr = float(pv["SELLING_PRICE"].corr(pv["QUANTITY"]))
#         except Exception:
#             corr = None
#         psi_line = ""
#         if f_customer != "All Customers" and not psi_df9.empty \
#                 and "PRICE_SENSITIVITY_INDEX" in psi_df9.columns:
#             prow = psi_df9[psi_df9["CUSTOMER_ID"] == f_customer]
#             if not prow.empty:
#                 psi_line = f" Customer PSI={float(prow['PRICE_SENSITIVITY_INDEX'].iloc[0]):.2f}."
#         pd_interp = ai_complete(
#             f"Observed price-vs-demand correlation is {corr:.2f} (scope {f_product}/{f_customer})."
#             f"{psi_line} In 2 sentences, interpret how pricing appears to affect demand and one action.",
#             cache_key=_ai_cache_key("ndm_price_demand", f_product, f_customer,
#                                     round(corr, 2) if corr is not None else "na"))
#         if pd_interp:
#             st.info(pd_interp)
#         else:
#             st.caption("AI interpretation unavailable — showing correlation only: "
#                        f"{corr:.2f}" if corr is not None else "AI interpretation unavailable.")
#     else:
#         st.info("Price-vs-demand analysis requires SELLING_PRICE and QUANTITY in DEMAND_HISTORY.")
#     divider()

#     # ── 14. DYNAMIC MARKET INTELLIGENCE (reuses competitor snapshot) ──
#     section("🏆", "Dynamic Market Intelligence")
#     if f_product != "All Products" and not comp_df9.empty \
#             and {"SKU", "COMPETITOR_AVG_PRICE"}.issubset(comp_df9.columns):
#         crow = comp_df9[comp_df9["SKU"] == f_product]
#         our_price = _ndm_price_for_sku(f_product)
#         comp_avg = float(crow["COMPETITOR_AVG_PRICE"].mean()) if not crow.empty else None
#         gap = safe_pct_change(our_price, comp_avg) if (our_price and comp_avg) else None
#         win = None
#         if not matrix_df9.empty and "WIN_PROBABILITY" in matrix_df9.columns:
#             wr = matrix_df9[matrix_df9["SKU"] == f_product]["WIN_PROBABILITY"]
#             if not wr.empty:
#                 win = float(wr.mean())
#                 win = win * 100 if win <= 1 else win
#         demand_dir = (f"forecast trend {scope_fc['slope']:+.1f} units/mo"
#                       if scope_fc and not scope_fc.get("insufficient") else "no demand forecast yet")
#         mi_payload = ai_reason_score(
#             module="market_intelligence", decision_type="dynamic_market",
#             context_facts=(
#                 f"SKU {f_product}: our price ₹{our_price:,.2f} vs competitor avg "
#                 f"{('₹%.2f' % comp_avg) if comp_avg else 'N/A'} "
#                 f"(gap {('%+.1f%%' % gap) if gap is not None else 'N/A'}).\n"
#                 f"Win probability {('%.0f%%' % win) if win is not None else 'N/A'}. Demand: {demand_dir}."),
#             extra_instruction=("Assess market pressure, competitive threat, pricing opportunity and "
#                                "demand risk. 'score' = market position strength (higher=stronger). "
#                                "Give recommended market response in recommended_actions."),
#             cache_key=_ai_cache_key("ndm_market", f_product,
#                                     round(our_price or 0, 2), round(comp_avg or 0, 2)))
#         mm1, mm2, mm3 = st.columns(3)
#         mm1.metric("Our Price", f"₹{our_price:,.0f}" if our_price else "N/A")
#         mm2.metric("Competitor Avg", f"₹{comp_avg:,.0f}" if comp_avg else "N/A")
#         mm3.metric("Price Gap", f"{gap:+.1f}%" if gap is not None else "N/A")
#         render_ai_score_card(mi_payload, title_prefix="Market Position")
#     else:
#         st.info("Select a single Product with competitor data to run Dynamic Market Intelligence.")
#     divider()

#     # ── 15. DEMAND vs CAPACITY (deterministic arithmetic + AI interpretation) ──
#     section("🏭", "Demand vs Capacity")
#     if scope_fc and not scope_fc.get("insufficient") and not cap_df9.empty:
#         avail_col = "AVAILABLE_CAPACITY" if "AVAILABLE_CAPACITY" in cap_df9.columns else None
#         util_col9 = "CURRENT_UTILIZATION" if "CURRENT_UTILIZATION" in cap_df9.columns else None
#         total_avail = float(cap_df9[avail_col].sum()) if avail_col else None
#         avg_util = float(cap_df9[util_col9].mean()) if util_col9 else None
#         # forecast demand per month vs monthly available capacity (aggregate assumption noted)
#         fc_month = scope_fc["fc_avg"]
#         gap_units = (total_avail - fc_month) if total_avail is not None else None
#         cc1, cc2, cc3 = st.columns(3)
#         cc1.metric("Forecast Demand / mo", f"{fc_month:,.0f}")
#         cc2.metric("Available Capacity", f"{total_avail:,.0f}" if total_avail is not None else "N/A")
#         cc3.metric("Current Utilization", f"{avg_util:.1f}%" if avg_util is not None else "N/A")
#         cap_payload = ai_reason_score(
#             module="market_intelligence", decision_type="demand_vs_capacity",
#             context_facts=(
#                 f"Forecast avg monthly demand {fc_month:,.0f} units. Total available capacity "
#                 f"{('%.0f' % total_avail) if total_avail is not None else 'N/A'} units. "
#                 f"Avg utilization {('%.1f%%' % avg_util) if avg_util is not None else 'N/A'}. "
#                 f"Headroom {('%.0f units' % gap_units) if gap_units is not None else 'N/A'}."),
#             extra_instruction=("Identify capacity shortage, excess capacity or imbalance and a "
#                                "production opportunity. 'score' = capacity readiness (higher=better). "
#                                "Note: capacity is aggregated across plants; not SKU-specific."),
#             cache_key=_ai_cache_key("ndm_cap", f_product, f_customer, round(fc_month),
#                                     round(total_avail or 0)))
#         render_ai_score_card(cap_payload, title_prefix="Capacity Readiness")
#         st.caption("Comparison uses total available capacity vs total forecast demand for the scope "
#                    "(plant capacity is not SKU-specific in your schema).")
#     else:
#         st.info("Demand-vs-capacity needs a valid forecast and PLANT_CAPACITY data.")
#     divider()

#     # ── 16. REVENUE FORECAST ──
#     section("💵", "Revenue Forecast")
#     if scope_fc and not scope_fc.get("insufficient"):
#         rep_price = None
#         if f_product != "All Products":
#             rep_price = _ndm_price_for_sku(f_product)
#         if rep_price is None and "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
#             rep_price = float(scope["SELLING_PRICE"].mean())
#         if rep_price:
#             rev_fc = scope_fc["forecast"].copy()
#             rev_fc["Expected"] = rev_fc["FORECAST"] * rep_price
#             rev_fc["Worst"] = rev_fc["LOWER"] * rep_price
#             rev_fc["Best"] = rev_fc["UPPER"] * rep_price
#             rev_fc["PERIOD_LBL"] = rev_fc["PERIOD"].dt.strftime("%Y-%m")
#             cur_rev = scope_fc["recent"] * rep_price
#             tot_exp = float(rev_fc["Expected"].sum())
#             rc1, rc2, rc3 = st.columns(3)
#             rc1.metric("Recent Monthly Revenue", f"₹{cur_rev:,.0f}")
#             rc2.metric(f"Forecast Revenue ({f_horizon})", f"₹{tot_exp:,.0f}")
#             rc3.metric("Expected Change",
#                        f"{safe_pct_change(rev_fc['Expected'].mean(), cur_rev):+.1f}%")
#             _ndm_line(rev_fc, "PERIOD_LBL",
#                       {"Worst": _C_RED, "Expected": _C_TEAL, "Best": _C_BLUE},
#                       "Revenue Forecast — Worst / Expected / Best (₹)")
#             st.caption(f"Revenue = forecast demand × representative price ₹{rep_price:,.2f} "
#                        "(from CUSTOMER_PRICING / OPTIMIZED_PRICING_MATRIX). Range = demand CI × price.")
#         else:
#             st.info("No representative selling price available for this scope to compute revenue.")
#     else:
#         st.info("Revenue forecast activates once a valid demand forecast exists.")
#     divider()

#     # ── 17. AI MARKET OPPORTUNITY DETECTOR ──
#     section("💡", "AI Market Opportunity Detector")
#     opp_signals = []
#     if scope_fc and not scope_fc.get("insufficient") and scope_fc["slope"] > 0:
#         opp_signals.append(f"Demand trending up {scope_fc['slope']:+.1f} units/mo for scope "
#                            f"{f_product}/{f_customer}.")
#     if f_product != "All Products" and not comp_df9.empty and {"SKU", "COMPETITOR_AVG_PRICE"}.issubset(comp_df9.columns):
#         cr = comp_df9[comp_df9["SKU"] == f_product]
#         op = _ndm_price_for_sku(f_product)
#         if not cr.empty and op:
#             g = safe_pct_change(op, float(cr["COMPETITOR_AVG_PRICE"].mean()))
#             if g < -3:
#                 opp_signals.append(f"Priced {g:+.1f}% below competitor average — room to raise price.")
#     if not cap_df9.empty and "AVAILABLE_CAPACITY" in cap_df9.columns and float(cap_df9["AVAILABLE_CAPACITY"].sum()) > 0:
#         opp_signals.append(f"{cap_df9['AVAILABLE_CAPACITY'].sum():,.0f} units of spare capacity to fill.")
#     if not psi_df9.empty and "PRICE_SENSITIVITY_INDEX" in psi_df9.columns:
#         low_sens = psi_df9[psi_df9["PRICE_SENSITIVITY_INDEX"] < 0.4]
#         if not low_sens.empty:
#             opp_signals.append(f"{low_sens.shape[0]} low-price-sensitivity customer(s) — premium-pricing potential.")
#     if opp_signals:
#         opp_rows = []
#         for raw in opp_signals:
#             sig = ai_filter(f"Is this a significant market opportunity worth executive attention? {raw}",
#                             cache_key=_ai_cache_key("ndm_opp_filter", raw))
#             if sig is False:
#                 continue
#             txt = ai_complete(
#                 f"Turn this signal into a JSON object with keys opportunity, target, reason, "
#                 f"impact, confidence (0-100), action. Signal: {raw}",
#                 cache_key=_ai_cache_key("ndm_opp_text", raw))
#             obj = parse_ai_json(txt) if txt else None
#             if isinstance(obj, dict):
#                 opp_rows.append({
#                     "Opportunity": obj.get("opportunity", "Opportunity"),
#                     "Product/Customer": obj.get("target", f_product),
#                     "Business Reason": obj.get("reason", raw),
#                     "Potential Impact": obj.get("impact", "—"),
#                     "Confidence": f"{obj.get('confidence', 60)}%",
#                     "Recommended Action": obj.get("action", "—")})
#             else:
#                 opp_rows.append({"Opportunity": "Opportunity", "Product/Customer": f_product,
#                                  "Business Reason": raw, "Potential Impact": "—",
#                                  "Confidence": "—", "Recommended Action": "—"})
#         if opp_rows:
#             st.dataframe(pd.DataFrame(opp_rows), use_container_width=True, hide_index=True)
#         else:
#             st.info("No opportunities cleared the significance filter for this scope.")
#     else:
#         st.info("No opportunity signals detected from current data/scope.")
#     divider()

#     # ── 18. MARKET RISK DETECTOR ──
#     section("⚠️", "Market Risk Intelligence")
#     risk_signals = []
#     if scope_fc and not scope_fc.get("insufficient"):
#         if scope_fc["slope"] < 0:
#             risk_signals.append(("Demand Decline", f_product,
#                                  f"Demand trending down {scope_fc['slope']:+.1f} units/mo."))
#         if scope_fc["r2"] < 0.3:
#             risk_signals.append(("Demand Volatility", f_product,
#                                  f"Low forecast fit (R² {scope_fc['r2']:.2f}) — unstable demand."))
#     if has_demand and "CUSTOMER_ID" in demand_df.columns and demand_df["CUSTOMER_ID"].notna().any():
#         share = demand_df.groupby("CUSTOMER_ID")["QUANTITY"].sum()
#         if share.sum() > 0:
#             top_share = share.max() / share.sum() * 100
#             if top_share > 30:
#                 risk_signals.append(("Customer Dependency", share.idxmax(),
#                                      f"Top customer is {top_share:.0f}% of total demand."))
#     if not cap_df9.empty and "CURRENT_UTILIZATION" in cap_df9.columns:
#         hot = cap_df9[cap_df9["CURRENT_UTILIZATION"] >= 90]
#         if not hot.empty:
#             risk_signals.append(("Capacity Constraint", "Plant",
#                                  f"{hot.shape[0]} plant(s) at ≥90% utilization vs rising demand."))
#     if risk_signals:
#         risk_rows9 = []
#         for rtype, target, detail in risk_signals:
#             sev = ai_classify(
#                 f"Risk type {rtype}. Detail: {detail}. Classify severity.",
#                 ["Critical", "High", "Medium", "Low"],
#                 cache_key=_ai_cache_key("ndm_risk_sev", rtype, detail))
#             act = ai_complete(
#                 f"One short recommended action (<15 words) for this market risk: {rtype}. {detail}",
#                 cache_key=_ai_cache_key("ndm_risk_act", rtype, detail))
#             risk_rows9.append({
#                 "Risk": rtype, "Affected Product/Customer": target, "Severity": sev or "Medium",
#                 "Business Impact": detail, "Confidence": "AI", "Recommended Action": act or "Review"})
#         st.dataframe(pd.DataFrame(risk_rows9), use_container_width=True, hide_index=True)
#     else:
#         st.info("No material market risks detected in the current scope.")
#     divider()

#     # ── 19. AI MARKET INTELLIGENCE BRIEF ──
#     section("🧠", "AI Market Intelligence Brief")
#     brief_facts = [
#         f"Scope: product={f_product}, customer={f_customer}, region={f_region}, horizon={f_horizon}."]
#     if scope_fc and not scope_fc.get("insufficient"):
#         brief_facts += [
#             f"Recent demand {scope_fc['recent']:,.0f}/mo, forecast avg {scope_fc['fc_avg']:,.0f}/mo, "
#             f"trend slope {scope_fc['slope']:+.1f}, confidence {scope_fc['confidence']:.0f}%."]
#     else:
#         brief_facts.append("No demand forecast available (historical demand data not yet loaded).")
#     if not cap_df9.empty and "AVAILABLE_CAPACITY" in cap_df9.columns:
#         brief_facts.append(f"Spare capacity {cap_df9['AVAILABLE_CAPACITY'].sum():,.0f} units.")
#     brief = ai_complete(
#         "You are a senior pricing/market analyst. Write a concise market briefing (5-7 sentences) "
#         "covering current demand situation, future outlook, revenue outlook, top growth and at-risk "
#         "areas, competitive threat, capacity concern and pricing opportunity. Use ONLY these facts; "
#         "do not invent numbers:\n" + "\n".join(brief_facts),
#         cache_key=_ai_cache_key("ndm_brief", tuple(brief_facts)))
#     if brief:
#         # Unwrap accidental JSON-string / escaped-newline responses
#         _b = brief.strip()
#         if _b.startswith('"') and _b.endswith('"'):
#             try:
#                 _b = json.loads(_b)
#             except Exception:
#                 _b = _b.strip('"')
#         st.write(_b.replace("\\n", "\n"))
#     else:
#         st.info("AI market brief unavailable — Cortex did not respond. See Cortex AI Diagnostics.")
#     divider()

# # ── 20. EXECUTIVE RECOMMENDATIONS ──
#     section("✅", "Executive Recommendations")
#     import re as _re

#     _rec_raw = ai_complete(
#         "Based on the facts below, produce 3-5 prioritized recommendations. Return ONLY a JSON array "
#         "of objects with keys: priority (High/Medium/Low), category, action, reason, impact, "
#         "confidence (0-100). No preamble, no markdown.\nFacts:\n" + "\n".join(brief_facts),
#         cache_key=_ai_cache_key("ndm_recs_v2", tuple(brief_facts)))   # NOTE: new cache key

#     # Parse: try helper, then extract the first [...] array from any prose.
#     rec_json = parse_ai_json(_rec_raw)
#     if not (isinstance(rec_json, list) and rec_json) and _rec_raw:
#         m = _re.search(r"\[\s*\{.*\}\s*\]", _rec_raw, _re.DOTALL)
#         if m:
#             try:
#                 rec_json = json.loads(m.group(0))
#             except Exception:
#                 rec_json = None

#     rec_tbl = []
#     if isinstance(rec_json, list):
#         for r in rec_json:
#             if isinstance(r, dict):
#                 try:
#                     conf = float(str(r.get("confidence", 60)).strip().rstrip("%"))
#                 except Exception:
#                     conf = 60.0
#                 rec_tbl.append({
#                     "priority": str(r.get("priority", "Medium")).strip(),
#                     "category": str(r.get("category", "—")).strip(),
#                     "action": str(r.get("action") or r.get("recommendation") or "—").strip(),
#                     "reason": str(r.get("reason", "—")).strip(),
#                     "impact": str(r.get("impact", "—")).strip(),
#                     "confidence": max(0.0, min(100.0, conf)),
#                 })

#     if rec_tbl:
#         _order = {"high": 0, "medium": 1, "low": 2}
#         rec_tbl.sort(key=lambda x: _order.get(x["priority"].lower(), 1))
#         _sty = {"high": ("#EF4444", "🔴", "rgba(239,68,68,0.10)"),
#                 "medium": ("#F59E0B", "🟡", "rgba(245,158,11,0.10)"),
#                 "low": ("#38BDF8", "🔵", "rgba(56,189,248,0.10)")}
#         for r in rec_tbl:
#             color, icon, bg = _sty.get(r["priority"].lower(), _sty["medium"])
#             st.markdown(f"""
# <div style="border:1px solid rgba(255,255,255,0.08); border-left:4px solid {color};
#             background:{bg}; border-radius:10px; padding:14px 16px; margin-bottom:10px;">
#   <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
#     <span style="font-weight:600; color:#E6EDF3;">{icon} {r['action']}</span>
#     <span style="font-size:12px; color:{color}; border:1px solid {color};
#                  border-radius:20px; padding:2px 10px;">{r['priority'].upper()} · {r['category']}</span>
#   </div>
#   <div style="color:#9FB3C8; font-size:13px; margin-bottom:4px;"><b>Why:</b> {r['reason']}</div>
#   <div style="color:#9FB3C8; font-size:13px; margin-bottom:8px;"><b>Impact:</b> {r['impact']}</div>
#   <div style="background:rgba(255,255,255,0.06); border-radius:6px; height:6px; overflow:hidden;">
#     <div style="width:{r['confidence']:.0f}%; height:6px; background:{color};"></div>
#   </div>
#   <div style="text-align:right; font-size:11px; color:#9FB3C8; margin-top:3px;">
#     {r['confidence']:.0f}% confidence</div>
# </div>
# """, unsafe_allow_html=True)
#     else:
#         st.info("Could not parse structured recommendations.")
#         with st.expander("🔧 Debug: raw Cortex response"):
#             st.code(_rec_raw or "(empty)")
#     divider()



#     # ── 21. EXECUTIVE SUMMARY ──
#     section("📋", "Executive Summary")
#     summ = ai_summarize("\n".join(brief_facts),
#                         cache_key=_ai_cache_key("ndm_exec_summary", tuple(brief_facts)))
#     st.text_area(" ", ai_or_fallback(
#         summ,
#         "Demand Health: " + ("forecast available" if scope_fc and not scope_fc.get("insufficient")
#                              else "awaiting real demand history") + "\n" + "\n".join(brief_facts)),
#         height=220, key="ndm_exec_summary_box")
# # ── 22. SAVED FORECAST HISTORY ──
#     divider()
#     section("📜", "Saved Forecast History")
#     hist_fc = _ndm_load(
#         "SELECT RUN_ID, SCOPE_PRODUCT, SCOPE_CUSTOMER, HORIZON, FORECAST_DATE, "
#         "FORECAST_DEMAND, CONFIDENCE_PCT, FORECAST_REVENUE, CREATED_AT "
#         "FROM PRICING_ENGINE_DB.CORE_OUTPUT.DEMAND_FORECAST_RESULTS "
#         "ORDER BY CREATED_AT DESC LIMIT 100")
#     if hist_fc is not None and not hist_fc.empty:
#         st.dataframe(hist_fc, use_container_width=True, hide_index=True)
#     else:
#         st.info("No saved forecasts yet. Use 💾 Save Forecast to Snowflake above.")



# # ──────────────────────────────────────────────
# # FOOTER
# # ──────────────────────────────────────────────

# st.markdown("""
# <div style="text-align:center;padding:32px 0 12px 0;color:#2A3A4A;font-size:11px;letter-spacing:0.5px;">
#     PRICING INTELLIGENCE PLATFORM · POWERED BY SNOWFLAKE CORTEX AI · STREAMLIT-IN-SNOWFLAKE
# </div>
# """, unsafe_allow_html=True)




import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd
import json
import hashlib

# ──────────────────────────────────────────────
# PAGE CONFIG
# ──────────────────────────────────────────────

st.set_page_config(
    page_title="Pricing Intelligence Platform",
    page_icon="💎",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ──────────────────────────────────────────────
# GLOBAL STYLES  (UNCHANGED — do not modify)
# ──────────────────────────────────────────────

st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@400;600;700&display=swap');

:root{
    --bg0:#050814;
    --bg1:#07111f;
    --glass:rgba(255,255,255,0.075);
    --glass-strong:rgba(255,255,255,0.13);
    --stroke:rgba(255,255,255,0.16);
    --stroke-strong:rgba(125,211,252,0.32);
    --text:#f8fbff;
    --muted:rgba(226,232,240,0.70);
    --cyan:#67e8f9;
    --blue:#38bdf8;
    --violet:#a78bfa;
    --pink:#f0abfc;
    --green:#7dd3a8;
    --amber:#ffd166;
    --red:#fb7185;
}

html, body, [data-testid="stAppViewContainer"]{
    font-family:'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
    color:var(--text) !important;
}

.stApp{
    background:
        radial-gradient(circle at 8% 8%, rgba(103,232,249,0.22) 0, rgba(103,232,249,0.035) 33%, transparent 44%),
        radial-gradient(circle at 92% 10%, rgba(167,139,250,0.25) 0, rgba(167,139,250,0.04) 32%, transparent 46%),
        radial-gradient(circle at 52% 96%, rgba(125,211,168,0.13) 0, transparent 42%),
        linear-gradient(145deg, #050814 0%, #07111f 46%, #101827 100%) !important;
}

.block-container{
    padding-top:1.25rem !important;
    padding-bottom:3rem !important;
    max-width:1440px !important;
}

[data-testid="stHeader"]{background:transparent !important;}

[data-testid="stSidebar"]{
    background:linear-gradient(180deg, rgba(8,16,30,0.96), rgba(10,18,32,0.94)) !important;
    border-right:1px solid rgba(255,255,255,0.13) !important;
    box-shadow:18px 0 70px rgba(0,0,0,0.25) !important;
}

/* Hero */
.hero-banner{
    position:relative;overflow:hidden;
    padding:34px 38px 32px 38px;margin:0 0 26px 0;
    border-radius:30px;border:1px solid rgba(255,255,255,0.18);
    background:
        linear-gradient(135deg, rgba(255,255,255,0.145), rgba(255,255,255,0.055)),
        radial-gradient(circle at 88% 20%, rgba(103,232,249,0.26), transparent 34%),
        radial-gradient(circle at 10% 90%, rgba(167,139,250,0.20), transparent 36%);
    box-shadow:0 26px 85px rgba(0,0,0,0.34), inset 0 1px 0 rgba(255,255,255,0.18);
    backdrop-filter:blur(18px);
}
.hero-banner:before{
    content:"";position:absolute;inset:-2px;
    background:linear-gradient(110deg, rgba(103,232,249,0.18), rgba(167,139,250,0.14), rgba(240,171,252,0.08), transparent 66%);
    pointer-events:none;
}
.hero-inner{position:relative;z-index:1;}
.hero-badge{
    display:inline-flex;align-items:center;gap:8px;
    padding:8px 13px;border-radius:999px;
    background:rgba(103,232,249,0.12);border:1px solid rgba(103,232,249,0.30);
    color:#bdf6ff;font-size:0.76rem;font-weight:800;letter-spacing:0.07em;text-transform:uppercase;margin-bottom:14px;
}
.hero-title{margin:0;color:#ffffff;font-weight:900;font-size:clamp(2.15rem,4vw,4.2rem);line-height:0.95;letter-spacing:-0.075em;}
.hero-title span{
    background:linear-gradient(90deg,#67e8f9 0%,#93c5fd 35%,#a78bfa 68%,#f0abfc 100%);
    -webkit-background-clip:text;-webkit-text-fill-color:transparent;
}
.hero-sub{margin:14px 0 0 0;color:rgba(226,232,240,0.74);font-size:1.02rem;line-height:1.65;max-width:980px;}
.hero-pills{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px;}
.hero-pill{
    display:inline-flex;align-items:center;gap:8px;padding:9px 12px;border-radius:999px;
    background:rgba(255,255,255,0.09);border:1px solid rgba(255,255,255,0.16);
    color:rgba(248,251,255,0.90);font-size:0.84rem;font-weight:700;
}
.hero-pill strong{color:#ffffff;}

/* Tabs */
.stTabs [data-baseweb="tab-list"]{
    background:rgba(255,255,255,0.07) !important;border:1px solid rgba(255,255,255,0.13) !important;
    border-radius:999px !important;padding:6px !important;gap:6px !important;
    box-shadow:0 16px 45px rgba(0,0,0,0.22),inset 0 1px 0 rgba(255,255,255,0.12) !important;
    backdrop-filter:blur(14px) !important;
}
.stTabs [data-baseweb="tab"]{
    background:transparent !important;color:rgba(226,232,240,0.70) !important;
    border-radius:999px !important;font-size:13px !important;font-weight:800 !important;
    padding:10px 18px !important;border:none !important;transition:all 0.20s ease !important;
}
.stTabs [data-baseweb="tab"]:hover{color:#ffffff !important;background:rgba(255,255,255,0.07) !important;}
.stTabs [aria-selected="true"]{
    background:linear-gradient(90deg,rgba(56,189,248,0.95),rgba(139,92,246,0.95)) !important;
    color:white !important;box-shadow:0 12px 26px rgba(56,189,248,0.28) !important;
}
.stTabs [data-baseweb="tab-highlight"],.stTabs [data-baseweb="tab-border"]{display:none !important;}

/* Metric cards */
[data-testid="metric-container"]{
    position:relative;overflow:hidden;
    background:linear-gradient(145deg,rgba(255,255,255,0.125),rgba(255,255,255,0.055)) !important;
    border:1px solid rgba(255,255,255,0.15) !important;border-radius:22px !important;
    padding:19px 21px !important;
    box-shadow:0 18px 48px rgba(0,0,0,0.24),inset 0 1px 0 rgba(255,255,255,0.16) !important;
    backdrop-filter:blur(14px) !important;
}
[data-testid="metric-container"]:after{
    content:"";position:absolute;top:-42px;right:-38px;width:105px;height:105px;
    border-radius:999px;background:radial-gradient(circle,rgba(103,232,249,0.25),transparent 64%);
}
[data-testid="metric-container"] label{
    color:rgba(226,232,240,0.66) !important;font-size:11px !important;font-weight:850 !important;
    text-transform:uppercase !important;letter-spacing:0.09em !important;
}
[data-testid="stMetricValue"]{
    color:#ffffff !important;font-size:clamp(1.3rem,1.9vw,2rem) !important;
    font-weight:900 !important;letter-spacing:-0.045em !important;
    font-family:'JetBrains Mono',monospace !important;
}
[data-testid="stMetricDelta"]{font-size:12px !important;}

/* Section headers */
.section-header{display:flex;align-items:center;gap:12px;margin:26px 0 16px 0;}
.section-header .icon{
    width:38px;height:38px;border-radius:14px;display:flex;align-items:center;justify-content:center;
    background:linear-gradient(135deg,rgba(103,232,249,0.16),rgba(167,139,250,0.13));
    border:1px solid rgba(255,255,255,0.16);box-shadow:inset 0 1px 0 rgba(255,255,255,0.15);font-size:18px;
}
.section-header h3{color:#f8fbff;font-size:1.05rem;font-weight:850;margin:0;letter-spacing:-0.035em;}
.section-divider{border:none;height:1px;background:linear-gradient(90deg,transparent,rgba(255,255,255,0.16),transparent);margin:26px 0;}

/* Buttons */
.stButton > button{
    min-height:3rem !important;
    background:linear-gradient(90deg,#22d3ee 0%,#6366f1 50%,#a855f7 100%) !important;
    color:#ffffff !important;border:1px solid rgba(255,255,255,0.16) !important;
    border-radius:16px !important;font-weight:850 !important;font-size:14px !important;
    padding:10px 24px !important;
    box-shadow:0 14px 32px rgba(56,189,248,0.22),inset 0 1px 0 rgba(255,255,255,0.20) !important;
    transition:all 0.20s ease !important;
}
.stButton > button:hover{
    transform:translateY(-2px) !important;
    box-shadow:0 18px 42px rgba(139,92,246,0.32) !important;filter:saturate(1.10) !important;
}

/* Inputs */
.stSelectbox > div > div,
.stTextInput > div > div > input,
.stNumberInput > div > div > input,
.stTextArea textarea{
    background:rgba(255,255,255,0.075) !important;border:1px solid rgba(255,255,255,0.16) !important;
    border-radius:14px !important;color:#f8fbff !important;font-size:13px !important;
    box-shadow:inset 0 1px 0 rgba(255,255,255,0.08) !important;
}
.stTextArea textarea{font-family:'JetBrains Mono',monospace !important;line-height:1.65 !important;}
label[data-testid="stWidgetLabel"] p{color:rgba(226,232,240,0.78) !important;font-weight:800 !important;}
.stSlider [data-baseweb="slider"] div[role="slider"]{
    background:#67e8f9 !important;border-color:#67e8f9 !important;
    box-shadow:0 0 0 6px rgba(103,232,249,0.12) !important;
}

/* Dataframe and charts */
[data-testid="stDataFrame"]{
    border:1px solid rgba(255,255,255,0.14) !important;border-radius:20px !important;
    overflow:hidden !important;box-shadow:0 18px 45px rgba(0,0,0,0.24) !important;
}
[data-testid="stDataFrame"] th{
    background:rgba(15,23,42,0.92) !important;color:rgba(226,232,240,0.75) !important;
    font-size:11px !important;font-weight:850 !important;text-transform:uppercase !important;letter-spacing:0.07em !important;
}
.stBarChart,.stLineChart,[data-testid="stVegaLiteChart"]{
    background:linear-gradient(145deg,rgba(255,255,255,0.105),rgba(255,255,255,0.045)) !important;
    border:1px solid rgba(255,255,255,0.14) !important;border-radius:20px !important;
    padding:14px !important;box-shadow:0 16px 42px rgba(0,0,0,0.22) !important;
}

/* Alerts */
.stSuccess > div,.stInfo > div,.stWarning > div,.stError > div{
    border-radius:18px !important;border:1px solid rgba(255,255,255,0.14) !important;
    background:rgba(255,255,255,0.08) !important;box-shadow:0 14px 34px rgba(0,0,0,0.16) !important;
    backdrop-filter:blur(12px) !important;
}
.stSuccess > div{color:#a7f3d0 !important;}
.stInfo > div{color:#bae6fd !important;}
.stWarning > div{color:#fde68a !important;}
.stError > div{color:#fecdd3 !important;}

/* Expander & chat */
.streamlit-expanderHeader{background:rgba(255,255,255,0.07) !important;border-radius:16px !important;color:#f8fbff !important;}
[data-testid="stChatMessage"]{
    background:rgba(255,255,255,0.075) !important;border:1px solid rgba(255,255,255,0.13) !important;border-radius:18px !important;
}

/* Health score bar */
.health-bar-wrap{
    background:linear-gradient(145deg,rgba(255,255,255,0.105),rgba(255,255,255,0.045));
    border:1px solid rgba(255,255,255,0.14);border-radius:20px;
    padding:22px 24px;margin:12px 0;box-shadow:0 16px 42px rgba(0,0,0,0.22);
}
.health-bar-track{background:rgba(15,23,42,0.90);border-radius:999px;height:12px;margin-top:10px;overflow:hidden;}
.health-bar-fill{height:100%;border-radius:999px;transition:width 0.6s ease;}

/* Competitor gauge card */
.gauge-card{
    background:linear-gradient(145deg,rgba(255,255,255,0.10),rgba(255,255,255,0.04));
    border:1px solid rgba(255,255,255,0.14);border-radius:20px;
    padding:20px 22px;margin:8px 0;box-shadow:0 16px 40px rgba(0,0,0,0.22);
}
.price-tag{
    display:inline-block;padding:4px 12px;border-radius:999px;
    font-size:11px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;
}
.alert-chip{
    display:inline-flex;align-items:center;gap:6px;
    padding:7px 14px;border-radius:999px;
    background:rgba(239,68,68,0.12);border:1px solid rgba(239,68,68,0.28);
    color:#fca5a5;font-size:12px;font-weight:700;margin:4px 4px 4px 0;
}
.opportunity-chip{
    display:inline-flex;align-items:center;gap:6px;
    padding:7px 14px;border-radius:999px;
    background:rgba(0,199,178,0.12);border:1px solid rgba(0,199,178,0.30);
    color:#5eead4;font-size:12px;font-weight:700;margin:4px 4px 4px 0;
}

::-webkit-scrollbar{width:7px;height:7px;}
::-webkit-scrollbar-track{background:#050814;}
::-webkit-scrollbar-thumb{background:linear-gradient(180deg,#38bdf8,#8b5cf6);border-radius:999px;}

#MainMenu{visibility:hidden;}
footer{visibility:hidden;}

@media(max-width:900px){
    .hero-banner{padding:26px 22px;border-radius:24px;}
    .hero-title{font-size:2.35rem;}
    .hero-pills{gap:8px;}
}
</style>
""", unsafe_allow_html=True)


# ──────────────────────────────────────────────
# SESSION STATE INITIALIZATION
# Key fix: persist all computation results in session_state so
# widget interactions (sliders, selects) don't wipe the output.
# ──────────────────────────────────────────────

def _init_state(key, default):
    if key not in st.session_state:
        st.session_state[key] = default

_init_state("opt_results",       None)   # Tab 2 optimization
_init_state("opt_sku",           None)
_init_state("opt_cost",          None)   # Tab 2 — must be initialised to avoid KeyError on first load
_init_state("opt_best",          None)   # Tab 2 — same
_init_state("sim_results",       None)   # Tab 3 simulation
_init_state("cp_result",         None)   # Tab 2 customer lookup
_init_state("dt_results",        None)   # Tab 4 digital twin
_init_state("contract_results",  None)   # Tab 6 contract
_init_state("comp_results",      None)   # Tab 7 competitor
_init_state("sc_result",         None)   # Tab 3 pre-defined scenario
_init_state("psi_results",       None)   # Tab 2 PSI analysis
_init_state("ai_cache",          {})     # NEW — memoizes every Cortex AI call this session


# ──────────────────────────────────────────────
# SNOWFLAKE SESSION
# ──────────────────────────────────────────────

session = get_active_session()


# ──────────────────────────────────────────────
# HELPERS  (unchanged — do not modify)
# ──────────────────────────────────────────────

def section(icon, title):
    st.markdown(f"""
    <div class="section-header">
        <div class="icon">{icon}</div>
        <h3>{title}</h3>
    </div>""", unsafe_allow_html=True)

def divider():
    st.markdown('<hr class="section-divider">', unsafe_allow_html=True)

def safe_pct_change(new_val, base_val):
    if base_val == 0:
        return 0.0
    return ((new_val - base_val) / abs(base_val)) * 100

def health_bar_html(score, color, status):
    return f"""
    <div class="health-bar-wrap">
        <div style="display:flex;justify-content:space-between;align-items:center;">
            <div style="color:#C8D8E8;font-size:28px;font-weight:700;font-family:'JetBrains Mono',monospace;">
                {score}<span style="font-size:14px;color:#6B8BAF;font-weight:400;"> /100</span>
            </div>
            <div style="color:{color};font-size:13px;font-weight:600;">{status}</div>
        </div>
        <div class="health-bar-track">
            <div class="health-bar-fill" style="width:{score}%;background:linear-gradient(90deg,{color}88,{color});"></div>
        </div>
    </div>
    """


def get_capacity_modifier(utilization):
    """Returns (modifier_decimal, status_label, status_color) based on plant utilization %.
    NOTE: kept deterministic on purpose — this modifier feeds directly into the
    selling-price calculation, and per the AI-integration brief, mathematical /
    financial calculations must remain deterministic. Only the narrative business
    interpretation built on top of this (see ai_capacity_recommendation below)
    is generated dynamically by Cortex."""
    if utilization < 50:
        return -0.05, "🟢 Under Utilized", "green"
    elif utilization < 70:
        return 0.00, "🟢 Normal", "green"
    elif utilization <= 85:
        return 0.05, "🟡 Busy", "orange"
    else:
        return 0.10, "🔴 Near Capacity", "red"

def get_capacity_recommendation(utilization):
    """Deterministic fallback text — used only if Cortex AI is unavailable."""
    if utilization < 50:
        return "Reduce price slightly to attract orders and improve plant utilization."
    elif utilization < 70:
        return "Maintain current pricing — plant is operating at a healthy utilization level."
    elif utilization <= 85:
        return "Protect capacity and avoid unnecessary discounts as the plant is running busy."
    else:
        return "Increase selling price and prioritize high-margin orders — plant is near capacity."


# ──────────────────────────────────────────────
# CORTEX AI HELPERS   (NEW)
# Every Snowflake Cortex AI Function call in this app is centralized here.
#
# Design principles (per the AI-integration brief):
#  • Deterministic math (revenue, cost, margin, simulations) is NEVER touched.
#  • Business interpretation — recommendations, explanations, summaries,
#    classifications, alerts, decision support — is generated dynamically.
#  • Every helper is defensive: on any failure (Cortex unavailable, malformed
#    output, network hiccup) it returns None so the caller falls back to the
#    original deterministic rule-based text. Nothing can crash because of
#    an AI outage.
#  • Results are memoized in st.session_state["ai_cache"] keyed by a hash of
#    the inputs, so the same insight is never regenerated twice in a
#    session — this avoids unnecessary/duplicate Cortex calls.
# ──────────────────────────────────────────────

def _ai_cache_key(*parts) -> str:
    raw = "||".join(str(p) for p in parts)
    return hashlib.md5(raw.encode("utf-8")).hexdigest()

def _sql_escape(text) -> str:
    return str(text).replace("\\", "\\\\").replace("'", "''")

_init_state("ai_last_error", None)
_init_state("ai_last_raw", {})   # last raw Cortex response per function, for diagnostics
_init_state("ai_call_stats", {"ok": 0, "fail": 0})

def _record_ai_error(fn_name: str, err: Exception):
    st.session_state["ai_last_error"] = f"[{fn_name}] {type(err).__name__}: {err}"
    st.session_state["ai_call_stats"]["fail"] += 1

def _record_ai_ok(fn_name: str, raw):
    st.session_state["ai_last_raw"][fn_name] = raw
    st.session_state["ai_call_stats"]["ok"] += 1

def ai_complete(prompt: str, model: str = None, cache_key: str = None):
    """Snowflake Cortex AI_COMPLETE — free-text generation used for every
    recommendation, business-impact explanation, and executive narrative
    in this app. Returns None on failure (error captured in
    st.session_state["ai_last_error"] for diagnostics — see the
    Cortex AI Diagnostics panel). Uses the model chosen in the Cortex AI
    Diagnostics panel if set, else defaults to llama3.1-70b."""
    model = model or st.session_state.get("ai_model_override") or "llama3.1-70b"
    key = cache_key or _ai_cache_key("complete", model, prompt)
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]
    try:
        safe_prompt = _sql_escape(prompt)
        row = session.sql(f"SELECT AI_COMPLETE('{model}', '{safe_prompt}') AS RESP").collect()
        result = row[0]["RESP"] if row else None
        if result is not None:
            st.session_state["ai_cache"][key] = result  # never cache None so a failed/empty response gets retried next time
        _record_ai_ok("ai_complete", result)
        return result
    except Exception as e:
        _record_ai_error("ai_complete", e)
        return None

def ai_classify(text: str, categories: list, cache_key: str = None):
    """Snowflake Cortex AI_CLASSIFY — used to replace fixed if/elif
    classification thresholds (risk tiers, customer segments, health
    status labels, etc). Returns the chosen label, or None on failure."""
    key = cache_key or _ai_cache_key("classify", text, tuple(categories))
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]
    try:
        safe_text = _sql_escape(text)
        cat_list  = ", ".join(f"'{_sql_escape(c)}'" for c in categories)
        row = session.sql(f"""
            SELECT AI_CLASSIFY('{safe_text}', [{cat_list}]):labels[0]::STRING AS LABEL
        """).collect()
        result = row[0]["LABEL"] if row else None
        if result is not None:
            st.session_state["ai_cache"][key] = result
        _record_ai_ok("ai_classify", result)
        return result
    except Exception as e:
        _record_ai_error("ai_classify", e)
        return None

def ai_filter(text: str, cache_key: str = None):
    """Snowflake Cortex AI_FILTER — decides whether a raw signal is
    significant enough to surface as an executive alert. Returns None on
    failure (callers fail-open, i.e. show the alert, rather than hide
    potentially important information)."""
    key = cache_key or _ai_cache_key("filter", text)
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]
    try:
        safe_text = _sql_escape(text)
        row = session.sql(f"SELECT AI_FILTER('{safe_text}') AS FLAG").collect()
        result = bool(row[0]["FLAG"]) if row else None
        if result is not None:
            st.session_state["ai_cache"][key] = result
        _record_ai_ok("ai_filter", result)
        return result
    except Exception as e:
        _record_ai_error("ai_filter", e)
        return None

def ai_summarize(text: str, cache_key: str = None):
    """SNOWFLAKE.CORTEX.SUMMARIZE — condenses a larger block of business
    data (rendered as text) into an executive-ready narrative summary."""
    key = cache_key or _ai_cache_key("summarize", text)
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]
    try:
        safe_text = _sql_escape(text)
        row = session.sql(f"SELECT SNOWFLAKE.CORTEX.SUMMARIZE('{safe_text}') AS SUMMARY").collect()
        result = row[0]["SUMMARY"] if row else None
        if result is not None:
            st.session_state["ai_cache"][key] = result
        _record_ai_ok("ai_summarize", result)
        return result
    except Exception as e:
        _record_ai_error("ai_summarize", e)
        return None

def ai_agg_over_rows(row_texts: list, question: str, cache_key: str = None):
    """AI_AGG — aggregate reasoning across many rows in ONE Cortex call
    (used instead of firing one AI_COMPLETE per row), e.g. summarizing
    competitor behavior or market trends across several data points."""
    if not row_texts:
        return None
    key = cache_key or _ai_cache_key("agg", question, tuple(row_texts))
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]
    try:
        values_sql = ", ".join(f"('{_sql_escape(t)}')" for t in row_texts[:50])
        safe_q = _sql_escape(question)
        row = session.sql(f"""
            SELECT AI_AGG(COL, '{safe_q}') AS RESULT
            FROM (SELECT COLUMN1 AS COL FROM VALUES {values_sql})
        """).collect()
        result = row[0]["RESULT"] if row else None
        if result is not None:
            st.session_state["ai_cache"][key] = result
        _record_ai_ok("ai_agg_over_rows", result)
        return result
    except Exception as e:
        _record_ai_error("ai_agg_over_rows", e)
        return None

import re

def parse_ai_json(raw_text):
    """Best-effort, LENIENT JSON parse of an AI_COMPLETE response.
    Handles: markdown fences, leading/trailing prose, trailing commas,
    AND double/triple-JSON-encoded strings (Cortex sometimes returns the
    JSON payload wrapped as a quoted string literal)."""
    if not raw_text:
        return None

    def _try(text):
        try:
            return json.loads(text)
        except Exception:
            return None

    def _unwrap(value, depth=0):
        # Keep unwrapping while json.loads() keeps handing back another
        # string that itself looks like JSON (dict/list), up to a small
        # depth cap to avoid infinite loops on pathological input.
        if depth > 3:
            return value
        if isinstance(value, str):
            stripped = value.strip()
            if stripped.startswith("{") or stripped.startswith("["):
                inner = _try(stripped)
                if inner is not None:
                    return _unwrap(inner, depth + 1)
        return value

    candidates = [raw_text.strip()]

    fenced = raw_text.strip()
    if fenced.startswith("```"):
        fenced = fenced.strip("`")
        if fenced.lower().startswith("json"):
            fenced = fenced[4:]
        candidates.append(fenced.strip())

    obj_match = re.search(r"\{.*\}", raw_text, re.DOTALL)
    if obj_match:
        candidates.append(obj_match.group(0))
    arr_match = re.search(r"\[.*\]", raw_text, re.DOTALL)
    if arr_match:
        candidates.append(arr_match.group(0))

    for cand in candidates:
        result = _try(cand)
        if result is not None:
            return _unwrap(result)
        fixed = re.sub(r",\s*([\]}])", r"\1", cand)
        result = _try(fixed)
        if result is not None:
            return _unwrap(result)

    return None

def ai_or_fallback(ai_result, fallback):
    """Small convenience: use the AI-generated text if present, else the
    deterministic rule-based fallback string."""
    return ai_result if ai_result else fallback


# ──────────────────────────────────────────────
# AI MEMORY LAYER   (NEW — v2)
# Every AI scoring/decision call is logged so future calls in this session
# (and, best-effort, future sessions via a Snowflake table) can be given
# historical context — "Retrieve Historical Context" in the reasoning
# pipeline below. Snowflake writes are best-effort: if the table doesn't
# exist yet this silently falls back to in-session memory only, and the
# app keeps working.
# ──────────────────────────────────────────────

_init_state("ai_memory", [])  # in-session list of {module, decision_type, summary, result}

def ai_memory_log(module: str, decision_type: str, context_summary: str, result: dict):
    """Persist an AI decision to memory (session + best-effort Snowflake)."""
    entry = {
        "module": module,
        "decision_type": decision_type,
        "summary": context_summary[:500],
        "result_summary": json.dumps(result)[:800] if isinstance(result, dict) else str(result)[:800],
    }
    st.session_state["ai_memory"].append(entry)
    st.session_state["ai_memory"] = st.session_state["ai_memory"][-200:]
    try:
        session.sql(f"""
            INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG
                (MODULE, DECISION_TYPE, CONTEXT_SUMMARY, RESULT_SUMMARY, CREATED_AT)
            VALUES (
                '{_sql_escape(module)}', '{_sql_escape(decision_type)}',
                '{_sql_escape(entry["summary"])}', '{_sql_escape(entry["result_summary"])}',
                CURRENT_TIMESTAMP()
            )
        """).collect()
    except Exception:
        pass

def get_ai_memory_context(module: str, decision_type: str = None, limit: int = 3) -> str:
    """Retrieve recent memory entries for this module (in-session first,
    falling back to Snowflake) to give the AI historical context."""
    matches = [
        e for e in reversed(st.session_state["ai_memory"])
        if e["module"] == module and (decision_type is None or e["decision_type"] == decision_type)
    ][:limit]
    if matches:
        return "\n".join(f"- Prior decision: {m['summary']} -> {m['result_summary']}" for m in matches)
    try:
        where_dt = f"AND DECISION_TYPE = '{_sql_escape(decision_type)}'" if decision_type else ""
        rows = session.sql(f"""
            SELECT CONTEXT_SUMMARY, RESULT_SUMMARY FROM PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG
            WHERE MODULE = '{_sql_escape(module)}' {where_dt}
            ORDER BY CREATED_AT DESC LIMIT {limit}
        """).collect()
        if rows:
            return "\n".join(f"- Prior decision: {r['CONTEXT_SUMMARY']} -> {r['RESULT_SUMMARY']}" for r in rows)
    except Exception:
        pass
    return "No prior decisions on record for this module yet."


# ──────────────────────────────────────────────
# CENTRAL AI REASONING SERVICE   (NEW — v2)
# This is the single entry point every scoring / classification / decision
# module in the app now calls. It implements the full reasoning pipeline
# requested:  Build Context -> Retrieve Historical Context -> AI_REASON ->
# AI_DECIDE/AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE -> (retry once if invalid).
#
# No manual weights, averages, or formulas are used to produce the score --
# AI_COMPLETE is instructed to reason over the full context and return the
# score itself. The Python code below only (a) assembles context,
# (b) parses/validates the JSON shape, and (c) retries once on invalid
# output. If AI is unavailable or still invalid after a retry, a clearly
# labeled neutral/unscored result is returned -- never a hardcoded business
# score standing in for the AI's judgment, and never a crash.
# ──────────────────────────────────────────────

REQUIRED_SCORE_FIELDS = ["score", "label", "confidence", "reasoning", "risks", "opportunities", "recommended_actions"]

def _coerce_score_payload(payload):
    """LENIENT coercion instead of strict validation. A model deviating on
    one field (wrong type, missing key, score as '85' or '85%', a string
    instead of a list) should NOT nuke the entire response — only a
    genuinely unusable payload (no parseable score at all) is rejected.
    Returns a fully-populated payload dict, or None if truly unusable."""
    if not isinstance(payload, dict):
        return None

    # score is the only field that MUST be present and numeric — everything
    # else gets a sensible default if missing or malformed.
    raw_score = payload.get("score")
    if raw_score is None:
        return None
    try:
        if isinstance(raw_score, str):
            raw_score = raw_score.strip().rstrip("%")
        score = float(raw_score)
    except Exception:
        return None
    score = max(0.0, min(100.0, score))

    def _num(val, default):
        try:
            if isinstance(val, str):
                val = val.strip().rstrip("%")
            n = float(val)
            return max(0.0, min(100.0, n))
        except Exception:
            return default

    def _list_of_str(val):
        if isinstance(val, list):
            return [str(x) for x in val if str(x).strip()]
        if isinstance(val, str) and val.strip():
            return [val.strip()]
        return []

    coerced = {
        "score": score,
        "label": str(payload.get("label") or "Unlabeled"),
        "confidence": _num(payload.get("confidence"), 50.0),
        "reasoning": str(payload.get("reasoning") or "No detailed reasoning provided."),
        "risks": _list_of_str(payload.get("risks")),
        "opportunities": _list_of_str(payload.get("opportunities")),
        "recommended_actions": _list_of_str(payload.get("recommended_actions")),
    }
    # carry through any extra numeric_fields the caller asked for verbatim
    for k, v in payload.items():
        if k not in coerced:
            coerced[k] = v
    return coerced

def _neutral_score_payload(reason: str) -> dict:
    """Explicitly-labeled 'AI unavailable' result -- not a hardcoded
    business score, just a safe, honest placeholder so the UI never
    crashes and never silently pretends a fixed rule is an AI judgment."""
    return {
        "score": None, "label": "AI Unavailable", "confidence": 0,
        "reasoning": reason, "risks": [], "opportunities": [], "recommended_actions": [],
        "ai_generated": False,
    }

def ai_reason_score(module: str, decision_type: str, context_facts: str,
                     extra_instruction: str = "", numeric_fields: dict = None,
                     cache_key: str = None):
    """
    Core AI_REASON -> AI_DECIDE -> AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE pipeline.

    context_facts   : the raw business data this decision is about (deterministic
                       arithmetic facts only -- revenue, cost, margin numbers, etc.)
    numeric_fields   : optional dict of {field_name: description} the AI should
                       ALSO return in addition to the standard score fields (e.g.
                       {"margin_pct": "recommended margin percent, 0-100"} for PSI,
                       so that number can be used in the one deterministic
                       multiplication that turns it into a price).
    Returns a dict with at least: score, label, confidence, reasoning, risks,
    opportunities, recommended_actions, ai_generated (bool), plus any
    numeric_fields requested. Never raises.

    Validation here is LENIENT (see _coerce_score_payload): only a response
    with no parseable score at all is treated as a failure. A missing risks
    list, a score sent as "85%", or an extra field no longer discards the
    whole result — this is what made near-every card show "AI Unavailable"
    in earlier versions even though Cortex was actually responding.
    """
    key = cache_key or _ai_cache_key("reason_score", module, decision_type, context_facts, extra_instruction)
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]

    history = get_ai_memory_context(module, decision_type)
    extra_field_lines = ""
    if numeric_fields:
        extra_field_lines = "\n".join(f'  "{f}": <{desc}>,' for f, desc in numeric_fields.items())

    base_prompt = (
        f"You are an expert enterprise pricing analyst embedded in a manufacturing "
        f"Pricing Intelligence Platform. Module: {module}. Decision type: {decision_type}.\n\n"
        f"Relevant prior decisions (for consistency, not binding):\n{history}\n\n"
        f"Current facts (all numbers below are deterministic, already computed -- "
        f"do not recompute them, just reason over them):\n{context_facts}\n\n"
        f"{extra_instruction}\n\n"
        f"Respond with ONLY a single JSON object (no markdown fences, no text before or "
        f"after the JSON) with this shape (numbers as plain numbers, not strings or "
        f"percentages):\n"
        "{\n"
        '  "score": <number 0-100, your own judgment -- do not use a fixed formula>,\n'
        '  "label": "<short status label>",\n'
        '  "confidence": <number 0-100>,\n'
        '  "reasoning": "<2-3 sentence plain-business-language explanation>",\n'
        '  "risks": ["<short risk>", "..."],\n'
        '  "opportunities": ["<short opportunity>", "..."],\n'
        '  "recommended_actions": ["<short action>", "..."]'
        + ("," if numeric_fields else "") + "\n"
        + (extra_field_lines + "\n" if numeric_fields else "")
        + "}"
    )

    def _attempt(prompt):
        raw = ai_complete(prompt, cache_key=_ai_cache_key("reason_score_raw", module, decision_type, prompt))
        return raw, parse_ai_json(raw)

    raw1, parsed1 = _attempt(base_prompt)
    payload = _coerce_score_payload(parsed1)

    if payload is None:
        repair_prompt = (
            base_prompt + "\n\nRespond again. Output ONLY the JSON object above, "
            "starting with { and ending with } — no explanation, no markdown."
        )
        raw2, parsed2 = _attempt(repair_prompt)
        payload = _coerce_score_payload(parsed2)
        if payload is None:
            debug_raw = raw2 or raw1 or "(no response from AI_COMPLETE — check Cortex AI Diagnostics)"
            payload = _neutral_score_payload(
                "Cortex AI response could not be parsed as JSON. Raw response (truncated): "
                + str(debug_raw)[:300]
            )
        else:
            payload["ai_generated"] = True
    else:
        payload["ai_generated"] = True

    if payload.get("ai_generated") and numeric_fields:
        for f in numeric_fields:
            if f in payload:
                try:
                    v = payload[f]
                    if isinstance(v, str):
                        v = v.strip().rstrip("%")
                    payload[f] = float(v)
                except Exception:
                    payload.pop(f, None)

    # Only cache successful results. A failed/neutral payload is NEVER
    # cached — otherwise a card that failed once (e.g. while a model was
    # temporarily broken) would keep replaying that stale failure forever,
    # even after Cortex starts working again.
    if payload.get("ai_generated"):
        st.session_state["ai_cache"][key] = payload
    ai_memory_log(module, decision_type, context_facts[:300], payload)
    return payload

def ai_reason_score_batch(module: str, decision_type: str, items_context: list,
                           extra_instruction: str = "", cache_key: str = None):
    """Batched variant of ai_reason_score for many similar items in ONE
    Cortex call (e.g. a price sweep, or many customers/products at once) --
    keeps AI-driven scoring performant instead of one call per item.
    items_context: list of short fact strings, one per item.
    Returns a list of payload dicts (same shape as ai_reason_score), same
    length/order as items_context; falls back to neutral payloads per item
    on failure."""
    if not items_context:
        return []
    key = cache_key or _ai_cache_key("reason_batch", module, decision_type, tuple(items_context))
    if key in st.session_state["ai_cache"]:
        return st.session_state["ai_cache"][key]

    numbered = "\n".join(f"{i+1}. {c}" for i, c in enumerate(items_context))
    prompt = (
        f"You are an expert enterprise pricing analyst. Module: {module}. Decision type: "
        f"{decision_type}. For EACH numbered item below, reason independently and produce "
        f"a score (0-100, your own judgment, no fixed formula), a short label, a confidence "
        f"(0-100), and a one-sentence reasoning. {extra_instruction}\n\nItems:\n{numbered}\n\n"
        f"Respond with ONLY a JSON array (no markdown), same length and order as the items, "
        f"each object shaped exactly as:\n"
        '{"score": <0-100>, "label": "<short label>", "confidence": <0-100>, "reasoning": "<1 sentence>"}'
    )
    raw = ai_complete(prompt, cache_key=_ai_cache_key("reason_batch_raw", module, decision_type, prompt))
    parsed = parse_ai_json(raw)

    results = []
    for i in range(len(items_context)):
        if isinstance(parsed, list) and i < len(parsed) and isinstance(parsed[i], dict) \
           and "score" in parsed[i]:
            try:
                s = float(parsed[i]["score"])
                c = float(parsed[i].get("confidence", 50))
                results.append({
                    "score": max(0, min(100, s)),
                    "label": parsed[i].get("label", "N/A"),
                    "confidence": max(0, min(100, c)),
                    "reasoning": parsed[i].get("reasoning", ""),
                    "ai_generated": True,
                })
                continue
            except Exception:
                pass
        results.append({"score": None, "label": "AI Unavailable", "confidence": 0,
                         "reasoning": "No valid AI response for this item.", "ai_generated": False})

    # Only cache if at least one item actually got a real AI response —
    # a fully-failed batch is never cached, so it retries on the next run.
    if any(r.get("ai_generated") for r in results):
        st.session_state["ai_cache"][key] = results
    ai_memory_log(module, decision_type, f"{len(items_context)} batched items", {"count": len(results)})
    return results


def render_ai_score_card(payload: dict, title_prefix: str = "AI Score"):
    """Reusable renderer for any ai_reason_score() payload — used across
    every module (Executive Health, PSI, Capacity, Win Probability,
    Contract Risk, Margin Leakage, Advisor, Competitor) so the scoring UI
    is consistent and not duplicated per-module."""
    if not payload.get("ai_generated"):
        st.warning(f"⚠️ {title_prefix}: AI service unavailable — {payload.get('reasoning', 'no response from Cortex AI.')}")
        with st.expander("🔧 Why did this fail? (Cortex AI Diagnostics)"):
            st.write("Last Cortex error captured this session:")
            st.code(st.session_state.get("ai_last_error") or "No error captured yet — Cortex may be returning empty/malformed text rather than erroring.")
            st.write("Last raw AI_COMPLETE response seen this session:")
            st.code(str(st.session_state.get("ai_last_raw", {}).get("ai_complete", ""))[:800] or "(none yet)")
            st.caption(
                "Common causes: the model name 'llama3.1-70b' isn't enabled for your "
                "Snowflake account/region (try changing the `model` default in ai_complete()), "
                "the role running this app lacks USAGE on SNOWFLAKE.CORTEX functions, or "
                "AI_COMPLETE/AI_CLASSIFY/AI_FILTER aren't available in your Snowflake edition/region yet."
            )
        return

    score = payload["score"]
    label = payload["label"]
    confidence = payload["confidence"]

    bar_color = "#00C7B2" if score >= 75 else "#38BDF8" if score >= 55 else "#F59E0B" if score >= 35 else "#EF4444"
    st.markdown(health_bar_html(int(round(score)), bar_color, f"{label}  ·  {confidence:.0f}% confidence"), unsafe_allow_html=True)
    st.write(payload["reasoning"])

    c1, c2, c3 = st.columns(3)
    with c1:
        st.markdown("**⚠️ Risks**")
        if payload["risks"]:
            for x in payload["risks"]:
                st.write(f"• {x}")
        else:
            st.caption("None identified")
    with c2:
        st.markdown("**🎯 Opportunities**")
        if payload["opportunities"]:
            for x in payload["opportunities"]:
                st.write(f"• {x}")
        else:
            st.caption("None identified")
    with c3:
        st.markdown("**✅ Recommended Actions**")
        if payload["recommended_actions"]:
            for x in payload["recommended_actions"]:
                st.write(f"• {x}")
        else:
            st.caption("None identified")


# Best-effort one-time setup of the AI memory table. If the role running
# this app lacks CREATE TABLE privileges, this no-ops (the app keeps
# working on in-session memory only — see get_ai_memory_context above) but
# the error is still recorded for the diagnostics panel rather than hidden.
if "ai_memory_table_checked" not in st.session_state:
    try:
        session.sql("""
            CREATE TABLE IF NOT EXISTS PRICING_ENGINE_DB.CORE_OUTPUT.AI_MEMORY_LOG (
                MODULE VARCHAR, DECISION_TYPE VARCHAR, CONTEXT_SUMMARY VARCHAR,
                RESULT_SUMMARY VARCHAR, CREATED_AT TIMESTAMP_NTZ
            )
        """).collect()
    except Exception as e:
        _record_ai_error("ai_memory_table_setup", e)
        pass
    st.session_state["ai_memory_table_checked"] = True



# ══════════════════════════════════════════════════════════════════════
# ENTERPRISE WORKFLOW & APPROVAL ENGINE
# Layers: Data Access → RBAC → Routing → State Machine → Audit →
#         Notifications → Signature Adapter → AI (advisory only).
# Reuses session, _sql_escape, _ai_cache_key, ai_* helpers, _init_state.
# Financial calcs elsewhere are untouched; nothing here recomputes pricing.
# ══════════════════════════════════════════════════════════════════════
import uuid as _uuid

_WF = "PRICING_ENGINE_DB.CORE_INTERNAL"

# session-state additions (only new keys)
_init_state("workflow_selected_request", None)
_init_state("workflow_filter_status", "All")
_init_state("workflow_submission_result", None)
_init_state("workflow_role_cache", None)
_init_state("workflow_prefill", None)          # set by Price/Contract/DT integrations

# ── Notification & signature configuration (read from Snowflake secrets /
#    external access at deploy time; NEVER hardcode here). If unset, channels
#    are recorded as NOT_CONFIGURED and the workflow still succeeds. ──
_WF_NOTIFY_CONFIG = {"EMAIL": False, "TEAMS": False, "SLACK": False}
_WF_SIGNATURE_PROVIDER = None   # e.g. "DOCUSIGN" once an integration is wired in

def _wf_now_sql():
    return "CURRENT_TIMESTAMP()"

def _wf_id(prefix):
    return f"{prefix}-{_uuid.uuid4().hex[:12].upper()}"

def _wf_exec(sql):
    """Run a write/DDL statement; returns (ok, error)."""
    try:
        session.sql(sql).collect()
        return True, None
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"

def _wf_df(sql):
    try:
        return session.sql(sql).to_pandas()
    except Exception:
        return pd.DataFrame()

# ── One-time defensive DDL check (mirrors your AI_MEMORY_LOG pattern) ──
if "wf_tables_checked" not in st.session_state:
    # Tables are created by the provided SQL; this only verifies reachability.
    st.session_state["wf_tables_checked"] = _wf_table_ok = True

# ─────────────────────────── RBAC ──────────────────────────────────────
def get_current_user() -> str:
    """Identity from the Snowflake session — never from session_state."""
    try:
        row = session.sql("SELECT CURRENT_USER() AS U").collect()
        return row[0]["U"] if row else "UNKNOWN"
    except Exception:
        return "UNKNOWN"

def get_user_role(user: str = None) -> str:
    """Load application role from USER_ROLES for the real Snowflake user."""
    user = user or get_current_user()
    df = _wf_df(f"""
        SELECT ROLE_NAME FROM {_WF}.USER_ROLES
        WHERE UPPER(USER_NAME) = UPPER('{_sql_escape(user)}') AND IS_ACTIVE = TRUE
        LIMIT 1
    """)
    return df.iloc[0]["ROLE_NAME"] if not df.empty else "UNASSIGNED"

_WF_PERMISSIONS = {
    "PRICING_ANALYST":  {"create", "view_own", "comment"},
    "SALES_MANAGER":    {"create", "view_own", "comment", "approve"},
    "PRICING_MANAGER":  {"create", "view_own", "comment", "approve"},
    "FINANCE_MANAGER":  {"create", "view_own", "comment", "approve"},
    "FINANCE_DIRECTOR": {"create", "view_own", "comment", "approve"},
    "LEGAL":            {"view_own", "comment", "approve"},
    "CFO":              {"create", "view_own", "comment", "approve", "view_all"},
    "ADMIN":            {"create", "view_own", "comment", "approve", "view_all", "admin"},
}

def has_permission(role: str, perm: str) -> bool:
    return perm in _WF_PERMISSIONS.get(role, set())

def can_admin_workflows(role: str) -> bool:
    return has_permission(role, "admin")

def can_approve_request(role: str, request: dict) -> bool:
    """Server-side check: role must (a) have approve rights AND
    (b) match the role assigned to the request's CURRENT stage."""
    if not has_permission(role, "approve"):
        return False
    if role == "ADMIN":
        return True
    return str(request.get("CURRENT_APPROVER", "")).upper() == str(role).upper()

# ─────────────────────────── DATA ACCESS ───────────────────────────────
def wf_load_stages(request_type: str) -> pd.DataFrame:
    return _wf_df(f"""
        SELECT * FROM {_WF}.WORKFLOW_STAGES
        WHERE REQUEST_TYPE = '{_sql_escape(request_type)}' AND IS_ACTIVE = TRUE
        ORDER BY STAGE_NUMBER
    """)

def wf_load_request(request_id: str) -> dict:
    df = _wf_df(f"SELECT * FROM {_WF}.WORKFLOW_REQUESTS WHERE REQUEST_ID='{_sql_escape(request_id)}' LIMIT 1")
    return df.iloc[0].to_dict() if not df.empty else None

def wf_load_requests(where: str = "") -> pd.DataFrame:
    return _wf_df(f"SELECT * FROM {_WF}.WORKFLOW_REQUESTS {where} ORDER BY SUBMITTED_AT DESC NULLS LAST")

def wf_load_actions(request_id: str = None) -> pd.DataFrame:
    w = f"WHERE REQUEST_ID='{_sql_escape(request_id)}'" if request_id else ""
    return _wf_df(f"SELECT * FROM {_WF}.WORKFLOW_ACTIONS {w} ORDER BY ACTION_TIMESTAMP DESC")

def wf_load_comments(request_id: str) -> pd.DataFrame:
    return _wf_df(f"SELECT * FROM {_WF}.WORKFLOW_COMMENTS WHERE REQUEST_ID='{_sql_escape(request_id)}' ORDER BY CREATED_AT")

# ─────────────────────────── ROUTING ENGINE ────────────────────────────
def determine_approval_route(request: dict) -> list:
    """Build the ordered list of required stages for a request from
    WORKFLOW_STAGES config (thresholds live in Snowflake, not in code)."""
    stages = wf_load_stages(request.get("REQUEST_TYPE", "MANUAL_REQUEST"))
    if stages.empty:
        return []
    amount   = abs(float(request.get("FINANCIAL_IMPACT") or 0))
    discount = float(request.get("DISCOUNT_PERCENT") or 0)
    margin   = float(request.get("MARGIN_PERCENT") or 0)
    route = []
    for _, s in stages.iterrows():
        include = True
        # A stage applies only if the request falls in its configured band.
        if pd.notna(s["MIN_AMOUNT"])   and amount   < float(s["MIN_AMOUNT"]):   include = False
        if pd.notna(s["MAX_AMOUNT"])   and amount   > float(s["MAX_AMOUNT"]):   include = False
        if pd.notna(s["MIN_DISCOUNT"]) and discount < float(s["MIN_DISCOUNT"]): include = False
        if pd.notna(s["MAX_DISCOUNT"]) and discount > float(s["MAX_DISCOUNT"]): include = False
        if pd.notna(s["MIN_MARGIN"])   and margin   < float(s["MIN_MARGIN"]):   include = False
        if pd.notna(s["MAX_MARGIN"])   and margin   > float(s["MAX_MARGIN"]):   include = False
        # Stage 1 (or any IS_REQUIRED with no bands) is always kept.
        if int(s["STAGE_NUMBER"]) == 1:
            include = True
        if include:
            route.append({"stage_number": int(s["STAGE_NUMBER"]),
                          "stage_name": s["STAGE_NAME"],
                          "approver_role": s["APPROVER_ROLE"],
                          "sla_hours": int(s["SLA_HOURS"]) if pd.notna(s["SLA_HOURS"]) else 24})
    # Renumber sequentially so stage indices are contiguous
    for i, st_ in enumerate(route, start=1):
        st_["seq"] = i
    return route

# ─────────────────────────── AUDIT LOGGER ──────────────────────────────
def wf_log_action(request_id, stage_number, action_type, actor, actor_role,
                  comments, prev_status, new_status, metadata=None):
    aid = _wf_id("ACT")
    sess = f"session:{get_current_user()}"
    meta = _sql_escape(json.dumps(metadata or {}))
    ok, err = _wf_exec(f"""
        INSERT INTO {_WF}.WORKFLOW_ACTIONS
        (ACTION_ID, REQUEST_ID, STAGE_NUMBER, ACTION_TYPE, ACTOR, ACTOR_ROLE,
         COMMENTS, PREVIOUS_STATUS, NEW_STATUS, ACTION_TIMESTAMP, IP_OR_SESSION_INFO, METADATA_JSON)
        VALUES ('{aid}','{_sql_escape(request_id)}',{int(stage_number)},
                '{_sql_escape(action_type)}','{_sql_escape(actor)}','{_sql_escape(actor_role)}',
                '{_sql_escape(comments or "")}','{_sql_escape(prev_status or "")}',
                '{_sql_escape(new_status or "")}',{_wf_now_sql()},'{_sql_escape(sess)}','{meta}')
    """)
    return ok, err

def wf_add_comment(request_id, user, role, text):
    cid = _wf_id("CMT")
    return _wf_exec(f"""
        INSERT INTO {_WF}.WORKFLOW_COMMENTS
        (COMMENT_ID, REQUEST_ID, USER_NAME, USER_ROLE, COMMENT_TEXT, CREATED_AT)
        VALUES ('{cid}','{_sql_escape(request_id)}','{_sql_escape(user)}',
                '{_sql_escape(role)}','{_sql_escape(text)}',{_wf_now_sql()})
    """)

# ─────────────────────────── NOTIFICATION SERVICE ──────────────────────
def _wf_record_notification(request_id, recipient, channel, event, subject, message, status, error=None):
    nid = _wf_id("NTF")
    _wf_exec(f"""
        INSERT INTO {_WF}.WORKFLOW_NOTIFICATIONS
        (NOTIFICATION_ID, REQUEST_ID, RECIPIENT, CHANNEL, EVENT_TYPE, SUBJECT, MESSAGE,
         STATUS, CREATED_AT, SENT_AT, ERROR_MESSAGE, RETRY_COUNT)
        VALUES ('{nid}','{_sql_escape(request_id)}','{_sql_escape(recipient or "")}',
                '{_sql_escape(channel)}','{_sql_escape(event)}','{_sql_escape(subject)}',
                '{_sql_escape(message)}','{_sql_escape(status)}',{_wf_now_sql()},
                {'NULL' if status!='SENT' else _wf_now_sql()},
                {'NULL' if not error else "'"+_sql_escape(error)+"'"},0)
    """)

def send_email_notification(request_id, recipient, subject, message):
    if not _WF_NOTIFY_CONFIG["EMAIL"]:
        _wf_record_notification(request_id, recipient, "EMAIL", "APPROVAL", subject, message, "NOT_CONFIGURED")
        return "NOT_CONFIGURED"
    # Real send would go through a Snowflake External Access Integration here.
    _wf_record_notification(request_id, recipient, "EMAIL", "APPROVAL", subject, message, "PENDING")
    return "PENDING"

def send_teams_notification(request_id, recipient, subject, message):
    if not _WF_NOTIFY_CONFIG["TEAMS"]:
        _wf_record_notification(request_id, recipient, "TEAMS", "APPROVAL", subject, message, "NOT_CONFIGURED")
        return "NOT_CONFIGURED"
    _wf_record_notification(request_id, recipient, "TEAMS", "APPROVAL", subject, message, "PENDING")
    return "PENDING"

def send_slack_notification(request_id, recipient, subject, message):
    if not _WF_NOTIFY_CONFIG["SLACK"]:
        _wf_record_notification(request_id, recipient, "SLACK", "APPROVAL", subject, message, "NOT_CONFIGURED")
        return "NOT_CONFIGURED"
    _wf_record_notification(request_id, recipient, "SLACK", "APPROVAL", subject, message, "PENDING")
    return "PENDING"

def send_notification(request_id, event, subject, message, recipient_role=None):
    """Channel-agnostic entry point. Always records IN_APP; external channels
    record PENDING/NOT_CONFIGURED. NEVER blocks the workflow."""
    _wf_record_notification(request_id, recipient_role, "IN_APP", event, subject, message, "SENT")
    send_email_notification(request_id, recipient_role, subject, message)
    send_teams_notification(request_id, recipient_role, subject, message)
    send_slack_notification(request_id, recipient_role, subject, message)

# ─────────────────────────── SIGNATURE ADAPTER ─────────────────────────
def request_signature(request_id, signer, signer_role):
    sid = _wf_id("SIG")
    status = "PENDING" if _WF_SIGNATURE_PROVIDER else "NOT_CONFIGURED"
    provider = _WF_SIGNATURE_PROVIDER or "NONE"
    _wf_exec(f"""
        INSERT INTO {_WF}.DIGITAL_SIGNATURES
        (SIGNATURE_ID, REQUEST_ID, SIGNER, SIGNER_ROLE, SIGNATURE_PROVIDER,
         EXTERNAL_ENVELOPE_ID, SIGNATURE_STATUS, SIGNED_AT, DOCUMENT_HASH, CREATED_AT)
        VALUES ('{sid}','{_sql_escape(request_id)}','{_sql_escape(signer)}',
                '{_sql_escape(signer_role)}','{provider}',NULL,'{status}',NULL,
                '{_sql_escape(hashlib.sha256(request_id.encode()).hexdigest())}',{_wf_now_sql()})
    """)
    return status

def check_signature_status(request_id):
    df = _wf_df(f"SELECT SIGNATURE_STATUS FROM {_WF}.DIGITAL_SIGNATURES WHERE REQUEST_ID='{_sql_escape(request_id)}' ORDER BY CREATED_AT DESC LIMIT 1")
    return df.iloc[0]["SIGNATURE_STATUS"] if not df.empty else "NOT_REQUIRED"

# ─────────────────────────── SLA / ESCALATION ──────────────────────────
def wf_sla_status(sla_due_at):
    """Returns (label, color, text) — never color-only."""
    if sla_due_at is None or pd.isna(sla_due_at):
        return ("No SLA", "#6B8BAF", "No SLA set")
    try:
        due = pd.to_datetime(sla_due_at)
        now = pd.Timestamp.utcnow().tz_localize(None)
        hrs = (due - now).total_seconds() / 3600.0
        if hrs < 0:
            return ("🔴 Overdue", "#EF4444", f"Overdue by {abs(hrs):.0f}h")
        if hrs < 8:
            return ("🟡 Due Soon", "#F59E0B", f"{hrs:.0f}h remaining")
        return ("🟢 On Track", "#00C7B2", f"{hrs:.0f}h remaining")
    except Exception:
        return ("No SLA", "#6B8BAF", "No SLA set")

def wf_escalate(request_id, from_role, to_role, reason, actor, actor_role):
    eid = _wf_id("ESC")
    _wf_exec(f"""
        INSERT INTO {_WF}.WORKFLOW_ESCALATIONS
        (ESCALATION_ID, REQUEST_ID, FROM_APPROVER, TO_APPROVER, REASON,
         ESCALATED_AT, RESOLVED_AT, STATUS)
        VALUES ('{eid}','{_sql_escape(request_id)}','{_sql_escape(from_role or "")}',
                '{_sql_escape(to_role or "")}','{_sql_escape(reason)}',{_wf_now_sql()},NULL,'OPEN')
    """)
    wf_log_action(request_id, 0, "ESCALATED", actor, actor_role, reason, None, "ESCALATED")

# ─────────────────────────── STATE MACHINE ─────────────────────────────
_WF_ALLOWED = {
    "DRAFT":     {"SUBMITTED", "CANCELLED"},
    "SUBMITTED": {"IN_REVIEW", "CANCELLED"},
    "IN_REVIEW": {"APPROVED", "REJECTED", "RETURNED", "ESCALATED", "CANCELLED"},
    "RETURNED":  {"SUBMITTED", "CANCELLED"},
    "ESCALATED": {"IN_REVIEW", "APPROVED", "REJECTED", "CANCELLED"},
    "APPROVED":  set(),
    "REJECTED":  set(),
    "CANCELLED": set(),
}
_WF_ACTION_TARGET = {
    "SUBMIT": "SUBMITTED", "APPROVE_STAGE": "IN_REVIEW", "APPROVE_FINAL": "APPROVED",
    "REJECT": "REJECTED", "RETURN": "RETURNED", "ESCALATE": "ESCALATED", "CANCEL": "CANCELLED",
}

def transition_request(request_id, action, user, role, comment="", metadata=None):
    """Centralized, concurrency-safe transition. Returns (ok, message).
    Order: reload → validate state → validate RBAC → transition → audit →
    next approver → notify → timestamps. AI can never call this path to
    change status (no AI code invokes transition_request)."""
    req = wf_load_request(request_id)               # RELOAD from Snowflake
    if not req:
        return False, "Request not found."
    cur_status = str(req.get("STATUS", ""))
    cur_stage  = int(req.get("CURRENT_STAGE") or 1)

    # Determine route/stage context
    route = determine_approval_route(req)
    total_stages = len(route) if route else 1

    # RBAC — server-side, from persisted role (not session_state)
    if action in ("APPROVE_STAGE", "APPROVE_FINAL", "REJECT", "RETURN", "ESCALATE"):
        if not can_approve_request(role, req):
            return False, "You are not authorized to action this request at its current stage."
    if action == "CANCEL" and req.get("REQUESTER") != user and role != "ADMIN":
        return False, "Only the requester or an admin can cancel this request."

    # Decide the concrete APPROVE sub-action (stage vs final)
    if action == "APPROVE_STAGE":
        action = "APPROVE_FINAL" if cur_stage >= total_stages else "APPROVE_STAGE"

    target = _WF_ACTION_TARGET.get(action)
    if target is None:
        return False, "Unknown action."

    # Validate transition
    if target not in _WF_ALLOWED.get(cur_status, set()) and not (
        # allow same-status stage advance (IN_REVIEW → IN_REVIEW as stage++)
        action == "APPROVE_STAGE" and cur_status in ("SUBMITTED", "IN_REVIEW", "ESCALATED")):
        return False, (f"Invalid transition {cur_status} → {target}. "
                       "This request may have already been updated — refresh to see the latest status.")

    # Mandatory comment gate
    if action in ("REJECT", "RETURN", "ESCALATE") and not (comment or "").strip():
        return False, "A comment/justification is mandatory for Reject / Return / Escalate."

    # Compute next stage + approver + SLA
    new_stage = cur_stage
    new_approver = req.get("CURRENT_APPROVER")
    sla_clause = ""
    if action == "APPROVE_STAGE":
        new_stage = cur_stage + 1
        nxt = next((r for r in route if r["seq"] == new_stage), None)
        new_approver = nxt["approver_role"] if nxt else new_approver
        if nxt:
            sla_clause = f", SLA_DUE_AT = DATEADD('hour',{nxt['sla_hours']},CURRENT_TIMESTAMP())"
    ts_cols = ""
    if target == "APPROVED":  ts_cols = ", APPROVED_AT = CURRENT_TIMESTAMP()"
    if target == "REJECTED":  ts_cols = ", REJECTED_AT = CURRENT_TIMESTAMP()"
    if target == "CANCELLED": ts_cols = ", CANCELLED_AT = CURRENT_TIMESTAMP()"

    # Concurrency-guarded UPDATE: only if status+stage still match what we read
    ok, err = _wf_exec(f"""
        UPDATE {_WF}.WORKFLOW_REQUESTS
        SET STATUS='{target}', CURRENT_STAGE={new_stage},
            CURRENT_APPROVER='{_sql_escape(new_approver or "")}',
            UPDATED_AT=CURRENT_TIMESTAMP(){ts_cols}{sla_clause}
        WHERE REQUEST_ID='{_sql_escape(request_id)}'
          AND STATUS='{_sql_escape(cur_status)}'
          AND CURRENT_STAGE={cur_stage}
    """)
    if not ok:
        return False, f"Update failed (no fake success): {err}"

    # Verify exactly one row changed (double-approval protection)
    after = wf_load_request(request_id)
    if after and str(after.get("STATUS")) != target:
        return False, "This request has already been updated by another user. Refresh to see the latest status."

    # Immutable audit + notification (post-commit; failures don't roll back approval)
    wf_log_action(request_id, cur_stage,
                  {"APPROVE_STAGE":"APPROVED","APPROVE_FINAL":"APPROVED","REJECT":"REJECTED",
                   "RETURN":"RETURNED","ESCALATE":"ESCALATED","SUBMIT":"SUBMITTED",
                   "CANCEL":"CANCELLED"}[action],
                  user, role, comment, cur_status, target, metadata)
    send_notification(request_id, target,
                      subject=f"[{req.get('REQUEST_TYPE')}] {req.get('TITLE')} → {target}",
                      message=comment or f"Request {request_id} moved to {target}.",
                      recipient_role=new_approver)
    return True, f"Request {request_id} → {target}."

def wf_submit_new_request(payload: dict, user: str, role: str):
    """Create a DRAFT then move it to SUBMITTED/IN_REVIEW at stage 1."""
    if not has_permission(role, "create"):
        return False, "You are not authorized to create requests.", None
    rid = _wf_id("REQ")
    route = determine_approval_route({**payload})
    if not route:
        return False, "No active workflow configured for this request type.", None
    stage1 = route[0]
    meta = _sql_escape(json.dumps(payload.get("metadata", {})))
    ok, err = _wf_exec(f"""
        INSERT INTO {_WF}.WORKFLOW_REQUESTS
        (REQUEST_ID, REQUEST_TYPE, REFERENCE_ID, TITLE, DESCRIPTION, REQUESTER, REQUESTER_ROLE,
         CUSTOMER_ID, SKU, CONTRACT_ID, ORIGINAL_VALUE, PROPOSED_VALUE, FINANCIAL_IMPACT,
         MARGIN_PERCENT, DISCOUNT_PERCENT, RISK_LEVEL, CURRENT_STAGE, CURRENT_APPROVER,
         STATUS, PRIORITY, SUBMITTED_AT, UPDATED_AT, SLA_DUE_AT,
         AI_RISK_SUMMARY, AI_RECOMMENDATION, METADATA_JSON)
        VALUES ('{rid}','{_sql_escape(payload.get("REQUEST_TYPE"))}',
                '{_sql_escape(payload.get("REFERENCE_ID",""))}','{_sql_escape(payload.get("TITLE",""))}',
                '{_sql_escape(payload.get("DESCRIPTION",""))}','{_sql_escape(user)}','{_sql_escape(role)}',
                '{_sql_escape(payload.get("CUSTOMER_ID",""))}','{_sql_escape(payload.get("SKU",""))}',
                '{_sql_escape(payload.get("CONTRACT_ID",""))}',
                {float(payload.get("ORIGINAL_VALUE") or 0)},{float(payload.get("PROPOSED_VALUE") or 0)},
                {float(payload.get("FINANCIAL_IMPACT") or 0)},{float(payload.get("MARGIN_PERCENT") or 0)},
                {float(payload.get("DISCOUNT_PERCENT") or 0)},'{_sql_escape(payload.get("RISK_LEVEL","MEDIUM"))}',
                1,'{_sql_escape(stage1["approver_role"])}','SUBMITTED',
                '{_sql_escape(payload.get("PRIORITY","NORMAL"))}',
                CURRENT_TIMESTAMP(),CURRENT_TIMESTAMP(),
                DATEADD('hour',{stage1["sla_hours"]},CURRENT_TIMESTAMP()),
                '{_sql_escape(payload.get("AI_RISK_SUMMARY",""))}',
                '{_sql_escape(payload.get("AI_RECOMMENDATION",""))}','{meta}')
    """)
    if not ok:
        return False, f"Could not create request: {err}", None
    wf_log_action(rid, 1, "SUBMITTED", user, role, payload.get("DESCRIPTION",""), "DRAFT", "SUBMITTED")
    send_notification(rid, "SUBMITTED",
                      subject=f"New {payload.get('REQUEST_TYPE')} submitted: {payload.get('TITLE')}",
                      message="A new approval request requires your review.",
                      recipient_role=stage1["approver_role"])
    return True, rid, route

# ─────────────────────────── AI (ADVISORY ONLY) ────────────────────────
def wf_ai_risk_classify(request: dict) -> str:
    """Cortex risk tier — advisory. Falls back to stored RISK_LEVEL / MEDIUM."""
    label = ai_classify(
        f"Pricing/contract approval request. Type {request.get('REQUEST_TYPE')}, "
        f"financial impact ₹{request.get('FINANCIAL_IMPACT')}, margin {request.get('MARGIN_PERCENT')}%, "
        f"discount {request.get('DISCOUNT_PERCENT')}%. Classify approval risk.",
        ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
        cache_key=_ai_cache_key("wf_risk", request.get("REQUEST_ID")))
    return label or request.get("RISK_LEVEL") or "MEDIUM"

def wf_ai_approval_brief(request: dict) -> str:
    """Advisory approval brief. Never changes status."""
    facts = (f"Request {request.get('REQUEST_ID')} ({request.get('REQUEST_TYPE')}). "
             f"Customer {request.get('CUSTOMER_ID')}, SKU {request.get('SKU')}. "
             f"Original ₹{request.get('ORIGINAL_VALUE')} → Proposed ₹{request.get('PROPOSED_VALUE')}. "
             f"Financial impact ₹{request.get('FINANCIAL_IMPACT')}, margin {request.get('MARGIN_PERCENT')}%, "
             f"discount {request.get('DISCOUNT_PERCENT')}%. Justification: {request.get('DESCRIPTION')}")
    return ai_complete(
        "You are a pricing governance analyst. Summarize this approval request for an approver: "
        "business context, financial & margin impact, customer impact, risk factors, potential "
        "concerns, and 2 suggested questions. End with 'AI Recommendation: APPROVE / REVIEW "
        "CAREFULLY / REJECT-RENEGOTIATE' and one sentence why.\n" + facts,
        cache_key=_ai_cache_key("wf_brief", request.get("REQUEST_ID")))





# ──────────────────────────────────────────────
# PSI HELPERS  (Price Sensitivity Index)
# The PSI → margin mapping below remains a deterministic lookup because it
# feeds directly into the actual selling-price calculation (a financial
# number, not a narrative). What IS now AI-generated is the accompanying
# business explanation / recommendation shown to the user — see
# ai_psi_recommendation() further below, used at the point of display.
# ──────────────────────────────────────────────

def get_psi_margin(psi: float) -> tuple[float, str]:
    """
    Return (margin_pct_as_decimal, recommendation_label) based on PSI value.
    These are the only margin rules used in the Pricing Engine — never hardcode 35%.
    """
    if psi >= 0.80:
        return 0.08, "Highly Price Sensitive"
    elif psi >= 0.60:
        return 0.15, "Competitive Pricing"
    elif psi >= 0.40:
        return 0.22, "Balanced Pricing"
    elif psi >= 0.20:
        return 0.30, "Premium Pricing"
    else:
        return 0.40, "Maximum Margin"


def get_psi_recommendation(psi: float) -> str:
    """Deterministic fallback text — used only if Cortex AI is unavailable."""
    if psi >= 0.80:
        return "Highly price-sensitive customer. Reduce margin to improve probability of winning the order."
    elif psi >= 0.60:
        return "Customer is price conscious. Maintain competitive pricing."
    elif psi >= 0.40:
        return "Balanced pricing strategy recommended."
    elif psi >= 0.20:
        return "Customer accepts premium pricing. Higher margins can be maintained."
    else:
        return "Very low price sensitivity. Maximum margin opportunity."


def get_psi_score(psi: float) -> int:
    """
    Pricing Sensitivity Score = 100 - (PSI × 100).
    Higher score = more margin opportunity.
    """
    return max(0, min(100, int(100 - (psi * 100))))


def get_psi_score_label(score: int) -> tuple[str, str]:
    """Return (status_label, hex_color) for a PSI score."""
    if score >= 80:
        return "🟢 Maximum Margin Opportunity", "#00C7B2"
    elif score >= 60:
        return "🔵 Premium Opportunity", "#38BDF8"
    elif score >= 40:
        return "🟡 Balanced", "#F59E0B"
    elif score >= 20:
        return "🟠 Sensitive", "#F97316"
    else:
        return "🔴 Very Sensitive", "#EF4444"


def ai_psi_recommendation(psi_val, segment, margin_pct, margin_label, customer):
    """AI_COMPLETE-generated PSI pricing recommendation (replaces the fixed
    get_psi_recommendation() string at the point of display). Falls back
    to the deterministic text if Cortex is unavailable."""
    prompt = (
        f"You are a B2B manufacturing pricing strategist. Customer '{customer}' "
        f"belongs to segment '{segment}' with a Price Sensitivity Index of {psi_val:.2f} "
        f"(0=insensitive, 1=highly sensitive). Recommended margin tier is {margin_pct:.0f}% "
        f"({margin_label}). In 1-2 sentences, explain the pricing strategy and why, "
        f"in plain business language for an executive."
    )
    ai_text = ai_complete(prompt, cache_key=_ai_cache_key("psi_rec", customer, psi_val, margin_pct))
    return ai_or_fallback(ai_text, get_psi_recommendation(psi_val))


def ai_capacity_recommendation(utilization, plant_name, modifier_pct, status_label):
    """AI_COMPLETE-generated Capacity Utilization business impact +
    recommendation (replaces the fixed get_capacity_recommendation() string
    at the point of display)."""
    prompt = (
        f"Plant '{plant_name}' is running at {utilization:.1f}% utilization "
        f"({status_label}), triggering a {modifier_pct:+.0f}% capacity pricing modifier. "
        f"In 1-2 sentences, explain the business impact and recommend a production/pricing "
        f"action for an operations executive."
    )
    ai_text = ai_complete(prompt, cache_key=_ai_cache_key("cap_rec", plant_name, utilization))
    return ai_or_fallback(ai_text, get_capacity_recommendation(utilization))


def ai_win_probability_explanation(win_probability, customer, sku, psi, discount_pct,
                                    capacity_mod_pct, competitor_avg, final_price, gap_pct):
    """AI_COMPLETE-generated explanation of the predicted Win Probability
    and recommended action (replaces the fixed if/elif recommendation
    string in the Win Probability Predictor)."""
    market_line = (
        f"priced {gap_pct:+.1f}% vs a competitor market average of ₹{competitor_avg:,.2f}"
        if competitor_avg is not None else "no competitor market data available"
    )
    prompt = (
        f"A deal for customer '{customer}' on product '{sku}' has a predicted win "
        f"probability of {win_probability:.0f}%. Inputs: Price Sensitivity Index {psi:.2f}, "
        f"customer discount {discount_pct:.1f}%, capacity pricing modifier {capacity_mod_pct:+.0f}%, "
        f"final price ₹{final_price:,.2f}, {market_line}. "
        f"In 2 short sentences, explain why the win probability is at this level and "
        f"recommend one concrete action to a sales/pricing manager."
    )
    ai_text = ai_complete(prompt, cache_key=_ai_cache_key("wp_rec", customer, sku, round(win_probability)))
    fallback = (
        "Maintain current pricing. Excellent winning probability." if win_probability > 85
        else "Slight price adjustment may improve competitiveness." if win_probability >= 60
        else "High deal risk. Consider increasing discount or reviewing pricing."
    )
    return ai_or_fallback(ai_text, fallback)


def ai_discount_justification(customer, sku, current_discount, recommended_discount,
                               current_profit, recommended_profit, recommended_win_prob):
    """AI_COMPLETE-generated business justification for the Smart Discount
    Optimizer's recommended discount level (replaces the fixed string
    concatenation logic)."""
    prompt = (
        f"Customer '{customer}', product '{sku}'. Current discount {current_discount:.1f}% "
        f"(profit ₹{current_profit if current_profit is not None else 0:,.2f}). "
        f"Recommended discount {recommended_discount:.0f}% (profit ₹"
        f"{recommended_profit if recommended_profit is not None else 0:,.2f}, "
        f"win probability {recommended_win_prob:.0f}%). "
        f"In 1-2 sentences, justify this discount recommendation to a deal desk manager."
    )
    ai_text = ai_complete(prompt, cache_key=_ai_cache_key("disc_just", customer, sku, recommended_discount))
    fallback = (
        f"Recommended discount {recommended_discount:.0f}% balances profit and win probability "
        f"({recommended_win_prob:.0f}%)."
    )
    return ai_or_fallback(ai_text, fallback)


# ──────────────────────────────────────────────
# HERO BANNER
# ──────────────────────────────────────────────

st.markdown("""
<div class="hero-banner">
    <div class="hero-inner">
        <div class="hero-badge">✦ Snowflake Native · Cortex AI · Deal Desk Ready</div>
        <div class="hero-title">Pricing <span>Intelligence</span> Platform</div>
        <div class="hero-sub">
            A premium discrete-manufacturing pricing workspace for cost-to-price simulation,
            demand elasticity, customer agreements, digital-twin analysis, contract review,
            and AI-guided pricing strategy.
        </div>
        <div class="hero-pills">
            <div class="hero-pill">💰 <strong>Cost-to-Price</strong> Engine</div>
            <div class="hero-pill">📈 <strong>Demand</strong> Elasticity</div>
            <div class="hero-pill">🧾 <strong>Customer</strong> Agreements</div>
            <div class="hero-pill">🧠 <strong>AI</strong> Strategy Advisor</div>
        </div>
    </div>
</div>
""", unsafe_allow_html=True)


# ──────────────────────────────────────────────
# CORTEX AI DIAGNOSTICS   (NEW — fixes silent "AI not working everywhere")
# A one-click connectivity test so failures are visible instead of every
# card just quietly showing "AI Unavailable". Also lets you override the
# model name in-session without editing code — the single most common
# reason every AI call fails at once is that the default model
# ("llama3.1-70b") isn't enabled for a given Snowflake account/region.
# ──────────────────────────────────────────────

_init_state("ai_model_override", None)

with st.expander("🔧 Cortex AI Diagnostics — click if AI cards show 'AI Unavailable'", expanded=False):
    dcol1, dcol2, dcol3 = st.columns([2, 1, 1])
    with dcol1:
        model_choice = st.selectbox(
            "AI_COMPLETE model to use",
            # NOTE: mistral-large (v1) was deprecated July 8, 2026 — removed from this
            # list. mistral-large2 is the current replacement.
            ["llama3.1-70b", "llama3.1-8b", "llama3.3-70b", "mistral-large2",
             "snowflake-arctic", "reka-flash", "claude-3-5-sonnet"],
            index=0,
            help="If every AI card fails, the model above is most likely not enabled "
                 "for your Snowflake account/region, or has been deprecated. Pick a "
                 "different one and re-test."
        )
        if model_choice != (st.session_state["ai_model_override"] or "llama3.1-70b"):
            st.session_state["ai_model_override"] = model_choice
            st.session_state["ai_cache"] = {}  # clear cache so the new model actually gets used
    with dcol2:
        run_test = st.button("▶️ Test Connection", use_container_width=True)
    with dcol3:
        if st.button("🗑️ Clear AI Cache", use_container_width=True,
                      help="Forces every AI card to re-ask Cortex on the next interaction, "
                           "instead of reusing a cached result from earlier in this session."):
            st.session_state["ai_cache"] = {}
            st.session_state["ai_last_error"] = None
            st.success("AI cache cleared — cards will re-query Cortex on next interaction.")

    if run_test:
        test_model = st.session_state["ai_model_override"] or "llama3.1-70b"
        try:
            test_row = session.sql(
                f"SELECT AI_COMPLETE('{test_model}', 'Reply with exactly the word: OK') AS RESP"
            ).collect()
            test_resp = test_row[0]["RESP"] if test_row else None
            if test_resp:
                st.success(f"✅ AI_COMPLETE responded using model '{test_model}': {test_resp!r}")
            else:
                st.warning(f"⚠️ AI_COMPLETE ran but returned an empty response using model '{test_model}'.")
        except Exception as e:
            st.error(f"❌ AI_COMPLETE failed with model '{test_model}': {type(e).__name__}: {e}")
            st.info(
                "Typical fixes: (1) try a different model from the dropdown above — model "
                "availability and deprecation vary by Snowflake account/region/edition; "
                "(2) confirm your role has USAGE on Cortex AI functions "
                "(`GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_role>;`); "
                "(3) confirm Cortex AI functions are enabled for your account region "
                "(some regions require cross-region inference to be enabled)."
            )

    stats = st.session_state.get("ai_call_stats", {"ok": 0, "fail": 0})
    st.caption(
        f"This session: {stats['ok']} successful Cortex calls · {stats['fail']} failed calls. "
        f"Failed AI calls are never cached, so cards automatically retry once the "
        f"underlying issue (e.g. wrong model, permissions) is fixed — you generally "
        f"don't need to hit 'Clear AI Cache' unless you want an immediate re-check."
    )
    if st.session_state.get("ai_last_error"):
        st.code(st.session_state["ai_last_error"])


# ──────────────────────────────────────────────
# TABS
# ──────────────────────────────────────────────

# ──────────────────────────────────────────────
# NAVIGATION — single-render (kills the tab flicker permanently).
# st.tabs() paints EVERY tab body on every rerun and only hides the
# inactive ones via CSS afterwards, so a heavy 9-tab app flashes all
# content on each switch. Rendering only the selected tab removes the
# flash completely AND stops every tab's Cortex calls firing each rerun.
# ──────────────────────────────────────────────
_TAB_LABELS = [
    "🏠 Overview",
    "🏢 Executive Decision Center",
    "💰 Price Engine",
    "⚙️ Simulation Hub",
    "🌍 Digital Twin",
    "🧠 AI Advisor",
    "📄 Contract Analyzer",
    "🏆 Competitor Pricing",
    "📈 AI Demand Forecasting",
    "🏛️ Workflow & Approvals",
]
_active_tab = st.radio(
    "Navigate", _TAB_LABELS, horizontal=True,
    label_visibility="collapsed", key="main_nav_tab")
divider()


st.markdown("""
<style>
div[role="radiogroup"] { gap:.35rem; flex-wrap:wrap; }
div[role="radiogroup"] > label {
    background:rgba(255,255,255,.04);
    border:1px solid rgba(255,255,255,.08);
    border-radius:10px; padding:8px 14px; margin:0 !important;
    cursor:pointer; transition:all .15s ease;
}
div[role="radiogroup"] > label:hover { background:rgba(56,189,248,.12); }
div[role="radiogroup"] > label > div:first-child { display:none; } /* hide radio dot */
</style>
""", unsafe_allow_html=True)

# ════════════════════════════════════════════
# TAB 1 — EXECUTIVE OVERVIEW  (unchanged — pure KPIs/charts, no business rules)
# ════════════════════════════════════════════

if _active_tab == "🏠 Overview":

    section("📊", "Business KPIs")

    try:
        pricing_df = session.sql("""
            SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING
        """).to_pandas()

        total_products = pricing_df["SKU"].nunique()
        avg_cost       = pricing_df["TOTAL_COST"].mean()
        avg_target     = pricing_df["TARGET_PRICE"].mean()
        avg_customer   = pricing_df["DISCOUNTED_PRICE"].mean()

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Products Tracked",   f"{total_products}")
        c2.metric("Avg Cost",           f"₹{avg_cost:,.0f}")
        c3.metric("Avg Target Price",   f"₹{avg_target:,.0f}")
        c4.metric("Avg Customer Price", f"₹{avg_customer:,.0f}")

    except Exception as e:
        st.info(f"KPI data unavailable: {e}")
        pricing_df = pd.DataFrame()

    divider()

    col_l, col_r = st.columns(2)

    with col_l:
        section("📈", "Target Price by Product")
        if not pricing_df.empty:
            price_chart = pricing_df[["SKU","TARGET_PRICE"]].drop_duplicates()
            st.bar_chart(price_chart.set_index("SKU"), height=220)
        else:
            st.info("No data.")

    with col_r:
        section("🎯", "Customer Discount Analysis")
        try:
            discount_df = session.sql("""
                SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
            """).to_pandas()
            num_cols = discount_df.select_dtypes("number").columns.tolist()
            if num_cols:
                st.bar_chart(discount_df.set_index("CUSTOMER_ID")[num_cols], height=220)
        except Exception as e:
            st.info(f"Discount data unavailable: {e}")

    divider()
    section("💹", "Profit Analysis")

    if not pricing_df.empty:
        profit_df = pricing_df.copy()
        profit_df["PROFIT"]   = profit_df["DISCOUNTED_PRICE"] - profit_df["TOTAL_COST"]
        profit_df["MARGIN %"] = (profit_df["PROFIT"] / profit_df["TOTAL_COST"] * 100).round(1)

        col_t, col_c = st.columns([2, 1])
        with col_t:
            st.dataframe(
                profit_df[["SKU","CUSTOMER_ID","TOTAL_COST","DISCOUNTED_PRICE","PROFIT","MARGIN %"]],
                use_container_width=True, hide_index=True
            )
        with col_c:
            section("🏆", "Most Profitable Products")
            top = (
                profit_df.groupby("SKU")["PROFIT"]
                .mean().reset_index()
                .sort_values("PROFIT", ascending=False)
                .rename(columns={"PROFIT": "Avg Profit"})
            )
            st.dataframe(top, use_container_width=True, hide_index=True)

    divider()
    section("📜", "Recent Simulations")

    try:
        history_df = session.sql("""
            SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
            ORDER BY CREATED_AT DESC LIMIT 20
        """).to_pandas()
        st.dataframe(history_df, use_container_width=True, hide_index=True)
    except Exception:
        st.info("No simulation history yet. Run a simulation in the Simulation Hub tab.")



# ============================================================================
# 🏢 EXECUTIVE DECISION CENTER   — AI-integrated
#============================================================================

if _active_tab == "🏢 Executive Decision Center":
    # ------------------------------------------------------------------
    # Load core tables once, safely. Every downstream block checks
    # `.empty` / column existence before using these, so a missing table
    # degrades gracefully instead of crashing the whole tab.
    # ------------------------------------------------------------------
    def _safe_load(query: str) -> pd.DataFrame:
        try:
            return session.sql(query).to_pandas()
        except Exception:
            return pd.DataFrame()

    pricing_df   = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING")
    matrix_df    = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX")
    psi_df       = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.PRICE_SENSITIVITY")
    capacity_df  = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY")
    agreements_df = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS")
    surcharge_df = _safe_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.DYNAMIC_SURCHARGES")

    # Derive PROFIT / MARGIN % on the base pricing table once, reused everywhere below.
    if not pricing_df.empty and {"DISCOUNTED_PRICE", "TOTAL_COST"}.issubset(pricing_df.columns):
        pricing_df["PROFIT"]   = pricing_df["DISCOUNTED_PRICE"] - pricing_df["TOTAL_COST"]
        pricing_df["MARGIN_PCT"] = (pricing_df["PROFIT"] / pricing_df["TOTAL_COST"] * 100).round(1)
    else:
        pricing_df["PROFIT"] = pd.Series(dtype=float)
        pricing_df["MARGIN_PCT"] = pd.Series(dtype=float)

    # ASSUMPTION: OPTIMIZED_PRICING_MATRIX carries WIN_PROBABILITY per SKU/customer
    win_col = "WIN_PROBABILITY" if "WIN_PROBABILITY" in matrix_df.columns else None

    # ASSUMPTION: PRICE_SENSITIVITY carries a PSI_SCORE (0-1 or 0-100) per SKU
    psi_col = "PSI_SCORE" if "PSI_SCORE" in psi_df.columns else None

    # ASSUMPTION: PLANT_CAPACITY carries a UTILIZATION_PCT per plant
    util_col = "UTILIZATION_PCT" if "UTILIZATION_PCT" in capacity_df.columns else None

    # ASSUMPTION: CUSTOMER_AGREEMENTS carries DISCOUNT_PCT and CONTRACT_ID per customer
    discount_col = "DISCOUNT_PCT" if "DISCOUNT_PCT" in agreements_df.columns else None
    contract_col = "CONTRACT_ID" if "CONTRACT_ID" in agreements_df.columns else None

    # ========================================================================
    # 1. EXECUTIVE KPI CARDS  (deterministic — unchanged)
    # ========================================================================
    section("🏢", "Executive Decision Center")
    st.caption("CEO / CFO level summary — consolidates every pricing module, now with Cortex AI-generated insight.")
    divider()

    section("📊", "Executive KPI Cards")
    try:
        total_revenue = pricing_df["DISCOUNTED_PRICE"].sum() if "DISCOUNTED_PRICE" in pricing_df.columns else 0
        gross_profit  = pricing_df["PROFIT"].sum() if "PROFIT" in pricing_df.columns else 0
        avg_margin    = pricing_df["MARGIN_PCT"].mean() if "MARGIN_PCT" in pricing_df.columns else 0
        avg_win_prob  = matrix_df[win_col].mean() if win_col else None
        active_customers = pricing_df["CUSTOMER_ID"].nunique() if "CUSTOMER_ID" in pricing_df.columns else 0

        # Pricing Health Score is computed in full in Section 10; a light
        # version is shown here so the top KPI row is complete on its own.
        health_score_preview = None
        health_inputs = []
        if psi_col:
            health_inputs.append(psi_df[psi_col].mean())
        if not pd.isna(avg_margin):
            health_inputs.append(min(avg_margin, 100))
        if avg_win_prob is not None:
            health_inputs.append(avg_win_prob * 100 if avg_win_prob <= 1 else avg_win_prob)
        if health_inputs:
            health_score_preview = sum(health_inputs) / len(health_inputs)

        k1, k2, k3, k4, k5, k6 = st.columns(6)
        k1.metric("Total Revenue",  f"₹{total_revenue:,.0f}")
        k2.metric("Gross Profit",   f"₹{gross_profit:,.0f}")
        k3.metric("Avg Margin",     f"{avg_margin:,.1f}%" if not pd.isna(avg_margin) else "N/A")
        k4.metric("Pricing Health", f"{health_score_preview:,.0f}/100" if health_score_preview is not None else "N/A")
        k5.metric("Avg Win Prob.",  f"{avg_win_prob:,.1f}%" if avg_win_prob is not None else "N/A")
        k6.metric("Active Customers", f"{active_customers}")
    except Exception as e:
        st.info(f"Executive KPI data unavailable: {e}")

    divider()

    # ========================================================================
    # 2. BUSINESS SNAPSHOT  (deterministic — unchanged)
    # ========================================================================
    section("📸", "Business Snapshot")
    try:
        total_customers = pricing_df["CUSTOMER_ID"].nunique() if "CUSTOMER_ID" in pricing_df.columns else 0
        total_products   = pricing_df["SKU"].nunique() if "SKU" in pricing_df.columns else 0
        avg_selling_price = pricing_df["DISCOUNTED_PRICE"].mean() if "DISCOUNTED_PRICE" in pricing_df.columns else 0
        avg_cost           = pricing_df["TOTAL_COST"].mean() if "TOTAL_COST" in pricing_df.columns else 0
        total_contracts     = agreements_df[contract_col].nunique() if contract_col else agreements_df.shape[0]

        s1, s2, s3, s4, s5 = st.columns(5)
        s1.metric("Total Customers",     f"{total_customers}")
        s2.metric("Total Products",      f"{total_products}")
        s3.metric("Avg Selling Price",   f"₹{avg_selling_price:,.0f}")
        s4.metric("Avg Cost",            f"₹{avg_cost:,.0f}")
        s5.metric("Total Contracts",     f"{total_contracts}")
    except Exception as e:
        st.info(f"Business snapshot unavailable: {e}")

    divider()

    # ========================================================================
    # 3. EXECUTIVE ALERTS  — AI_FILTER (significance gate) + AI_COMPLETE (text)
    #    Replaces the old bare "if count > 0" thresholds-only logic.
    # ========================================================================
    section("🚨", "Executive Alerts")
    alerts = []
    try:
        alert_candidates = []  # (level, kind, raw_signal) — raw numeric detection stays deterministic

        if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
            leak_count = (pricing_df["MARGIN_PCT"] < 5).sum()
            if leak_count > 0:
                alert_candidates.append(("error", "margin_leakage",
                    f"{leak_count} SKU/customer combinations are operating below 5% margin."))

        if util_col and not capacity_df.empty:
            near_max = (capacity_df[util_col] >= 90).sum()
            if near_max > 0:
                alert_candidates.append(("warning", "capacity",
                    f"{near_max} plant(s) are running at 90%+ utilization."))

        if win_col and not matrix_df.empty:
            low_win = (matrix_df[win_col] < 0.4).sum() if matrix_df[win_col].max() <= 1 else (matrix_df[win_col] < 40).sum()
            if low_win > 0:
                alert_candidates.append(("warning", "win_probability",
                    f"{low_win} deals are below 40% likelihood to win."))

        if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
            high_profit = (pricing_df["MARGIN_PCT"] > 30).sum()
            if high_profit > 0:
                alert_candidates.append(("success", "high_profit",
                    f"{high_profit} combinations are above 30% margin."))

        for level, kind, raw_signal in alert_candidates:
            # AI_FILTER decides whether this signal is significant enough for
            # an executive alert (replaces the previous "count > 0" gate).
            is_significant = ai_filter(
                f"Is this business signal significant enough to raise as an executive "
                f"pricing alert? Signal: {raw_signal}",
                cache_key=_ai_cache_key("alert_filter", kind, raw_signal)
            )
            if is_significant is False:
                continue  # AI judged it not significant; fail-open (show) if AI unavailable

            ai_msg = ai_complete(
                f"Write one short executive alert sentence (max 25 words) for a "
                f"manufacturing pricing dashboard about this signal: {raw_signal} "
                f"Category: {kind}. Be direct and actionable.",
                cache_key=_ai_cache_key("alert_text", kind, raw_signal)
            )
            icon = "🔴" if level == "error" else "🟡" if level == "warning" else "🟢"
            msg  = f"{icon} {ai_msg}" if ai_msg else f"{icon} {raw_signal}"
            alerts.append((level, msg))

        if alerts:
            for level, msg in alerts:
                getattr(st, level)(msg)
        else:
            st.info("No alerts triggered — all monitored metrics are within normal thresholds.")
    except Exception as e:
        st.info(f"Executive alerts unavailable: {e}")

    divider()

    # ========================================================================
    # 4. TOP OPPORTUNITIES — AI-generated suggested action + expected benefit
    #    Replaces the hardcoded _suggest_action() if/elif rule. One batched
    #    AI_COMPLETE call covers the whole table (not one call per row).
    # ========================================================================
    section("🚀", "Top Opportunities")
    top_opps = pd.DataFrame()
    try:
        if not pricing_df.empty and {"CUSTOMER_ID", "SKU", "MARGIN_PCT"}.issubset(pricing_df.columns):
            top_candidates = pricing_df.sort_values("MARGIN_PCT", ascending=False).head(10).reset_index(drop=True)

            rows_text = "\n".join(
                f"{i+1}. Customer={row['CUSTOMER_ID']}, Product={row['SKU']}, Margin={row['MARGIN_PCT']:.1f}%"
                for i, row in top_candidates.iterrows()
            )
            ai_json = parse_ai_json(ai_complete(
                f"For each pricing opportunity row below, suggest one short action "
                f"(2-4 words, e.g. 'Increase Price', 'Reduce Discount', 'Increase Production') "
                f"and one short expected benefit (2-4 words, e.g. 'Higher Profit'). "
                f"Return ONLY a JSON array (no markdown), one object per row in the same order, "
                f"each object having keys 'suggested_action' and 'expected_benefit'.\nRows:\n{rows_text}",
                cache_key=_ai_cache_key("top_opps", rows_text)
            ))

            def _fallback_action(row):
                if row["MARGIN_PCT"] > 30:
                    return "Increase Price", "Higher Profit"
                elif row["MARGIN_PCT"] > 20:
                    return "Premium Pricing", "Revenue Growth"
                elif discount_col and row["CUSTOMER_ID"] in agreements_df.get("CUSTOMER_ID", pd.Series()).values:
                    return "Reduce Discount", "Better Margin"
                else:
                    return "Increase Production", "Volume Growth"

            actions, benefits = [], []
            for i, row in top_candidates.iterrows():
                if ai_json and i < len(ai_json) and isinstance(ai_json[i], dict):
                    actions.append(ai_json[i].get("suggested_action", "N/A"))
                    benefits.append(ai_json[i].get("expected_benefit", "N/A"))
                else:
                    a, b = _fallback_action(row)
                    actions.append(a); benefits.append(b)

            top_opps = top_candidates.copy()
            top_opps["SUGGESTED_ACTION"] = actions
            top_opps["EXPECTED_BENEFIT"] = benefits
            top_opps = top_opps[["CUSTOMER_ID", "SKU", "SUGGESTED_ACTION", "EXPECTED_BENEFIT"]].rename(
                columns={"CUSTOMER_ID": "Customer", "SKU": "Product"}
            )
            st.dataframe(top_opps, use_container_width=True, hide_index=True)
        else:
            st.info("Not enough data to compute top opportunities.")
    except Exception as e:
        st.info(f"Top opportunities unavailable: {e}")

    divider()

    # ========================================================================
    # 5. TOP RISKS — AI_CLASSIFY for severity (replaces hardcoded "High"/"Medium")
    # ========================================================================
    section("⚠️", "Top Risks")
    risk_rows = []
    try:
        def _ai_severity(risk_type, detail, fallback):
            label = ai_classify(
                f"Risk type: {risk_type}. Detail: {detail}. Classify the severity of this "
                f"manufacturing pricing/business risk for an executive risk register.",
                ["Critical", "High", "Medium", "Low"],
                cache_key=_ai_cache_key("risk_sev", risk_type, detail)
            )
            return label if label else fallback

        if not pricing_df.empty and {"CUSTOMER_ID", "MARGIN_PCT"}.issubset(pricing_df.columns):
            leakage = pricing_df[pricing_df["MARGIN_PCT"] < 5]
            for _, row in leakage.head(5).iterrows():
                detail = f"Customer {row['CUSTOMER_ID']} margin at {row['MARGIN_PCT']:.1f}%"
                risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Margin Leakage",
                                   "Severity": _ai_severity("Margin Leakage", detail, "High")})

        if not agreements_df.empty and contract_col and "CUSTOMER_ID" in agreements_df.columns:
            if "MARGIN_PCT" in agreements_df.columns:
                risky_contracts = agreements_df[agreements_df["MARGIN_PCT"] < 0]
                for _, row in risky_contracts.head(5).iterrows():
                    detail = f"Customer {row['CUSTOMER_ID']} contract margin negative"
                    risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Contract Risk",
                                       "Severity": _ai_severity("Contract Risk", detail, "Medium")})

        if util_col and not capacity_df.empty:
            over_cap = capacity_df[capacity_df[util_col] >= 90]
            for _, row in over_cap.head(5).iterrows():
                plant_label = row.get("PLANT_ID", "Plant")
                detail = f"Plant {plant_label} utilization {row[util_col]:.1f}%"
                risk_rows.append({"Customer": plant_label, "Risk Type": "Capacity Risk",
                                   "Severity": _ai_severity("Capacity Risk", detail, "High")})

        if win_col and not matrix_df.empty and "CUSTOMER_ID" in matrix_df.columns:
            threshold = 0.4 if matrix_df[win_col].max() <= 1 else 40
            low_win_rows = matrix_df[matrix_df[win_col] < threshold]
            for _, row in low_win_rows.head(5).iterrows():
                detail = f"Customer {row['CUSTOMER_ID']} win probability {row[win_col]}"
                risk_rows.append({"Customer": row["CUSTOMER_ID"], "Risk Type": "Low Win Probability",
                                   "Severity": _ai_severity("Low Win Probability", detail, "Medium")})

        if risk_rows:
            st.dataframe(pd.DataFrame(risk_rows), use_container_width=True, hide_index=True)
        else:
            st.info("No significant risks detected in current data.")
    except Exception as e:
        st.info(f"Top risks unavailable: {e}")

    divider()

    # ========================================================================
    # 6. REVENUE DASHBOARD (native charts — SiS has no Plotly)  — unchanged
    # ========================================================================
    section("💰", "Revenue Dashboard")
    try:
        if not pricing_df.empty and "DISCOUNTED_PRICE" in pricing_df.columns:
            rev_c1, rev_c2 = st.columns(2)
            with rev_c1:
                st.caption("Revenue by Customer")
                rev_by_customer = pricing_df.groupby("CUSTOMER_ID")["DISCOUNTED_PRICE"].sum().sort_values(ascending=False)
                st.bar_chart(rev_by_customer, height=260)
            with rev_c2:
                st.caption("Revenue by Product")
                rev_by_product = pricing_df.groupby("SKU")["DISCOUNTED_PRICE"].sum().sort_values(ascending=False)
                st.bar_chart(rev_by_product, height=260)

            st.caption("Revenue Distribution")
            st.bar_chart(pricing_df["DISCOUNTED_PRICE"].sort_values(ascending=False).reset_index(drop=True), height=220)
        else:
            st.info("Revenue data unavailable.")
    except Exception as e:
        st.info(f"Revenue dashboard unavailable: {e}")

    divider()

    # ========================================================================
    # 7. MARGIN DASHBOARD  — unchanged
    # ========================================================================
    section("📉", "Margin Dashboard")
    try:
        if not pricing_df.empty and "MARGIN_PCT" in pricing_df.columns:
            st.caption("Margin Distribution")
            st.bar_chart(pricing_df["MARGIN_PCT"].sort_values(ascending=False).reset_index(drop=True), height=220)

            margin_by_product = pricing_df.groupby("SKU")["MARGIN_PCT"].mean().sort_values(ascending=False)
            mg_c1, mg_c2 = st.columns(2)
            with mg_c1:
                st.caption("Top 10 Profitable Products")
                st.bar_chart(margin_by_product.head(10), height=240)
            with mg_c2:
                st.caption("Bottom 10 Products")
                st.bar_chart(margin_by_product.tail(10), height=240)
        else:
            st.info("Margin data unavailable.")
    except Exception as e:
        st.info(f"Margin dashboard unavailable: {e}")

    divider()

    # ========================================================================
    # 8. CUSTOMER INSIGHTS — AI_CLASSIFY segmentation added
    #    (Strategic / Premium / Growth / Enterprise / Price Sensitive / At Risk)
    # ========================================================================
    section("👥", "Customer Insights")
    try:
        if not pricing_df.empty and {"CUSTOMER_ID", "DISCOUNTED_PRICE", "PROFIT"}.issubset(pricing_df.columns):
            cust_agg = pricing_df.groupby("CUSTOMER_ID").agg(
                REVENUE=("DISCOUNTED_PRICE", "sum"),
                PROFIT=("PROFIT", "sum"),
            ).reset_index()

            highest_revenue_cust = cust_agg.loc[cust_agg["REVENUE"].idxmax(), "CUSTOMER_ID"]
            highest_profit_cust  = cust_agg.loc[cust_agg["PROFIT"].idxmax(), "CUSTOMER_ID"]

            highest_discount_cust = "N/A"
            if discount_col and "CUSTOMER_ID" in agreements_df.columns and not agreements_df.empty:
                highest_discount_cust = agreements_df.loc[agreements_df[discount_col].idxmax(), "CUSTOMER_ID"]

            highest_win_cust = "N/A"
            if win_col and "CUSTOMER_ID" in matrix_df.columns and not matrix_df.empty:
                highest_win_cust = matrix_df.loc[matrix_df[win_col].idxmax(), "CUSTOMER_ID"]

            ci1, ci2, ci3, ci4 = st.columns(4)
            ci1.metric("Highest Revenue Customer", f"{highest_revenue_cust}")
            ci2.metric("Highest Profit Customer",  f"{highest_profit_cust}")
            ci3.metric("Highest Discount Customer", f"{highest_discount_cust}")
            ci4.metric("Highest Win Prob. Customer", f"{highest_win_cust}")

            st.caption("Profit vs Revenue")
            st.scatter_chart(cust_agg, x="REVENUE", y="PROFIT", size=None, height=280)

            # ── AI Customer Segmentation (NEW) — replaces any hardcoded segmentation rule ──
            top_customers = cust_agg.sort_values("REVENUE", ascending=False).head(8).reset_index(drop=True)
            seg_rows_text = "\n".join(
                f"{i+1}. Customer={row['CUSTOMER_ID']}, Revenue=₹{row['REVENUE']:,.0f}, Profit=₹{row['PROFIT']:,.0f}"
                for i, row in top_customers.iterrows()
            )
            seg_json = parse_ai_json(ai_complete(
                "Classify each customer below into exactly one segment from this list: "
                "Strategic, Premium, Growth, Enterprise, Price Sensitive, At Risk. "
                "Base the classification on relative revenue and profit. "
                "Return ONLY a JSON array (no markdown), one object per row in the same order, "
                "each with key 'segment'.\nRows:\n" + seg_rows_text,
                cache_key=_ai_cache_key("cust_seg", seg_rows_text)
            ))
            if seg_json:
                seg_df = top_customers.copy()
                seg_df["AI_SEGMENT"] = [
                    seg_json[i].get("segment", "N/A") if i < len(seg_json) and isinstance(seg_json[i], dict) else "N/A"
                    for i in range(len(seg_df))
                ]
                section("🧭", "AI Customer Segmentation")
                st.dataframe(
                    seg_df.rename(columns={"CUSTOMER_ID": "Customer", "REVENUE": "Revenue", "PROFIT": "Profit", "AI_SEGMENT": "Segment"}),
                    use_container_width=True, hide_index=True
                )
        else:
            st.info("Customer insight data unavailable.")
    except Exception as e:
        st.info(f"Customer insights unavailable: {e}")

    divider()

    # ========================================================================
    # 9. PRODUCT INSIGHTS — AI product classification added
    # ========================================================================
    section("📦", "Product Insights")
    try:
        if not pricing_df.empty and {"SKU", "DISCOUNTED_PRICE", "MARGIN_PCT"}.issubset(pricing_df.columns):
            prod_agg = pricing_df.groupby("SKU").agg(
                REVENUE=("DISCOUNTED_PRICE", "sum"),
                AVG_MARGIN=("MARGIN_PCT", "mean"),
            ).reset_index()

            best_product         = prod_agg.loc[prod_agg["AVG_MARGIN"].idxmax(), "SKU"]
            worst_product        = prod_agg.loc[prod_agg["AVG_MARGIN"].idxmin(), "SKU"]
            highest_revenue_prod = prod_agg.loc[prod_agg["REVENUE"].idxmax(), "SKU"]
            highest_margin_prod  = best_product  # same metric, kept separate per spec for clarity

            p1, p2, p3, p4 = st.columns(4)
            p1.metric("Best Product",           f"{best_product}")
            p2.metric("Worst Product",          f"{worst_product}")
            p3.metric("Highest Revenue Product", f"{highest_revenue_prod}")
            p4.metric("Highest Margin Product",  f"{highest_margin_prod}")

            # ── AI Product Classification (NEW) — replaces fixed business-rule tiers ──
            top_products = prod_agg.sort_values("REVENUE", ascending=False).head(8).reset_index(drop=True)
            prod_rows_text = "\n".join(
                f"{i+1}. Product={row['SKU']}, Revenue=₹{row['REVENUE']:,.0f}, AvgMargin={row['AVG_MARGIN']:.1f}%"
                for i, row in top_products.iterrows()
            )
            prod_json = parse_ai_json(ai_complete(
                "Classify each product below into exactly one category from this list: "
                "Star, Core, Niche, Underperformer. Base the classification on relative "
                "revenue and margin. Return ONLY a JSON array (no markdown), one object per "
                "row in the same order, each with key 'category'.\nRows:\n" + prod_rows_text,
                cache_key=_ai_cache_key("prod_class", prod_rows_text)
            ))
            if prod_json:
                pcl_df = top_products.copy()
                pcl_df["AI_CATEGORY"] = [
                    prod_json[i].get("category", "N/A") if i < len(prod_json) and isinstance(prod_json[i], dict) else "N/A"
                    for i in range(len(pcl_df))
                ]
                section("🧭", "AI Product Classification")
                st.dataframe(
                    pcl_df.rename(columns={"SKU": "Product", "REVENUE": "Revenue", "AVG_MARGIN": "Avg Margin %", "AI_CATEGORY": "Category"}),
                    use_container_width=True, hide_index=True
                )
        else:
            st.info("Product insight data unavailable.")
    except Exception as e:
        st.info(f"Product insights unavailable: {e}")

    divider()

    # ========================================================================
    # 10. PRICING HEALTH SCORE  — v2: FULLY AI-DRIVEN.
    #     No weighted average, no manual component weights. All facts below
    #     are deterministic arithmetic (means, counts, percentages already
    #     computed from live tables); the SCORE, LABEL, CONFIDENCE, and
    #     narrative are entirely Cortex AI's own judgment via the central
    #     ai_reason_score() pipeline (Build Context -> Historical Context ->
    #     AI_REASON -> AI_SCORE -> AI_EXPLAIN -> AI_VALIDATE, with retry).
    # ========================================================================
    section("🩺", "Pricing Health Score (AI-Generated)")
    try:
        fact_lines = []
        if psi_col and not psi_df.empty:
            fact_lines.append(f"Average Price Sensitivity Index: {psi_df[psi_col].mean():.2f}")
        if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
            fact_lines.append(f"Average margin across all SKU/customer combos: {pricing_df['MARGIN_PCT'].mean():.1f}%")
            fact_lines.append(f"Share of combos below 5% margin (leakage): {(pricing_df['MARGIN_PCT'] < 5).mean()*100:.1f}%")
        if win_col and not matrix_df.empty:
            wv = matrix_df[win_col].mean()
            fact_lines.append(f"Average win probability: {(wv*100 if wv <= 1 else wv):.1f}%")
        if util_col and not capacity_df.empty:
            fact_lines.append(f"Average plant utilization: {capacity_df[util_col].mean():.1f}%")
        if contract_col and "MARGIN_PCT" in agreements_df.columns and not agreements_df.empty:
            fact_lines.append(f"Share of contracts with negative margin: {(agreements_df['MARGIN_PCT'] < 0).mean()*100:.1f}%")

        if fact_lines:
            health_payload = ai_reason_score(
                module="executive_health",
                decision_type="pricing_health_score",
                context_facts="\n".join(fact_lines),
                extra_instruction=(
                    "Weigh these factors however you judge appropriate for this business — "
                    "do not use a fixed formula or equal weighting. Consider which factors "
                    "matter most given their current values."
                ),
                cache_key=_ai_cache_key("exec_health_v2", "|".join(fact_lines)),
            )
            render_ai_score_card(health_payload, title_prefix="Pricing Health")
            health_score = health_payload.get("score")
            status = health_payload.get("label", "N/A")
        else:
            st.info("Not enough data to compute a Pricing Health Score.")
            health_score, status = None, "N/A"
    except Exception as e:
        st.info(f"Pricing Health Score unavailable: {e}")
        health_score, status = None, "N/A"

    divider()

    # ========================================================================
    # 11. EXECUTIVE RECOMMENDATIONS — AI_COMPLETE-generated, replaces the
    #     fixed if/elif recommendation strings entirely.
    # ========================================================================
    section("💡", "Executive Recommendations")
    try:
        signal_lines = []

        if not pricing_df.empty and {"SKU", "MARGIN_PCT"}.issubset(pricing_df.columns):
            underpriced = pricing_df[pricing_df["MARGIN_PCT"] > 30].sort_values("MARGIN_PCT", ascending=False).head(3)
            for _, row in underpriced.iterrows():
                signal_lines.append(f"Product {row['SKU']} margin is {row['MARGIN_PCT']:.1f}% — well above target, room to raise price.")

        if discount_col and "CUSTOMER_ID" in agreements_df.columns and not agreements_df.empty:
            high_discount = agreements_df.sort_values(discount_col, ascending=False).head(2)
            for _, row in high_discount.iterrows():
                signal_lines.append(f"Customer {row['CUSTOMER_ID']} currently receives a {row[discount_col]:.1f}% discount — among the highest.")

        if util_col and not capacity_df.empty:
            over_cap = capacity_df[capacity_df[util_col] >= 90]
            if not over_cap.empty:
                signal_lines.append(f"{over_cap.shape[0]} plant(s) exceed 90% capacity utilization.")

        if "MARGIN_PCT" in pricing_df.columns and not pricing_df.empty:
            low_margin = pricing_df[pricing_df["MARGIN_PCT"] < 5]
            if not low_margin.empty:
                signal_lines.append(f"{low_margin.shape[0]} SKU/customer combinations are below 5% margin.")

        if "MARGIN_PCT" in agreements_df.columns and not agreements_df.empty:
            neg_contracts = agreements_df[agreements_df["MARGIN_PCT"] < 0]
            if not neg_contracts.empty:
                signal_lines.append(f"{neg_contracts.shape[0]} contract(s) have negative margin.")

        if signal_lines:
            signals_text = "\n".join(f"- {s}" for s in signal_lines)
            ai_recs_json = parse_ai_json(ai_complete(
                "You are a pricing strategy advisor for a discrete manufacturing company. "
                "Given the business signals below, write up to 5 short, specific executive "
                "recommendations (each under 25 words). Return ONLY a JSON array (no markdown) "
                "of objects, each with keys 'text' and 'severity' (one of Critical, Warning, Positive).\n"
                f"Signals:\n{signals_text}",
                cache_key=_ai_cache_key("exec_recs", signals_text)
            ))
            if ai_recs_json:
                for rec in ai_recs_json:
                    if not isinstance(rec, dict):
                        continue
                    txt = rec.get("text", "")
                    sev = str(rec.get("severity", "Warning")).lower()
                    if "critical" in sev:
                        st.error(txt)
                    elif "positive" in sev:
                        st.success(txt)
                    else:
                        st.warning(txt)
            else:
                # Fallback: original deterministic messages
                for s in signal_lines:
                    st.warning(s)
        else:
            st.info("No specific recommendations triggered — current pricing is within healthy thresholds.")
    except Exception as e:
        st.info(f"Executive recommendations unavailable: {e}")

    divider()

    # ========================================================================
    # 12. EXECUTIVE SUMMARY — AI_COMPLETE-generated narrative, replaces the
    #     manually assembled markdown bullet list.
    # ========================================================================
    section("📝", "Executive Summary")
    try:
        summary_business_health = status if "status" in dir() else "N/A"
        summary_revenue = f"₹{total_revenue:,.0f}" if "total_revenue" in dir() else "N/A"
        summary_profit  = f"₹{gross_profit:,.0f}" if "gross_profit" in dir() else "N/A"

        summary_top_opportunity = "N/A"
        if not top_opps.empty:
            summary_top_opportunity = f"{top_opps.iloc[0]['Customer']} — {top_opps.iloc[0]['SUGGESTED_ACTION']}"

        summary_highest_risk = "N/A"
        if risk_rows:
            summary_highest_risk = f"{risk_rows[0]['Customer']} — {risk_rows[0]['Risk Type']}"

        summary_best_product  = best_product if "best_product" in dir() else "N/A"
        summary_best_customer = highest_profit_cust if "highest_profit_cust" in dir() else "N/A"

        summary_key_recommendation = "Maintain current pricing strategy."
        if "underpriced" in dir() and not underpriced.empty:
            summary_key_recommendation = f"Increase {underpriced.iloc[0]['SKU']} price to capture available margin."

        facts_block = (
            f"Business Health: {summary_business_health}\n"
            f"Revenue: {summary_revenue}\n"
            f"Profit: {summary_profit}\n"
            f"Top Opportunity: {summary_top_opportunity}\n"
            f"Highest Risk: {summary_highest_risk}\n"
            f"Best Product: {summary_best_product}\n"
            f"Best Customer: {summary_best_customer}\n"
            f"Key Recommendation: {summary_key_recommendation}"
        )

        ai_narrative = ai_complete(
            "Turn the following pricing facts into a concise 3-4 sentence executive "
            "narrative summary suitable for a CEO/CFO briefing. Do not invent numbers "
            "beyond what's given.\n" + facts_block,
            cache_key=_ai_cache_key("exec_summary_narrative", facts_block)
        )

        if ai_narrative:
            st.write(ai_narrative)
            with st.expander("View underlying facts"):
                st.markdown(f"""
- **Business Health:** {summary_business_health}
- **Revenue:** {summary_revenue}
- **Profit:** {summary_profit}
- **Top Opportunity:** {summary_top_opportunity}
- **Highest Risk:** {summary_highest_risk}
- **Best Product:** {summary_best_product}
- **Best Customer:** {summary_best_customer}
- **Key Recommendation:** {summary_key_recommendation}
""")
        else:
            # Fallback: original deterministic markdown summary
            st.markdown(f"""
- **Business Health:** {summary_business_health}
- **Revenue:** {summary_revenue}
- **Profit:** {summary_profit}
- **Top Opportunity:** {summary_top_opportunity}
- **Highest Risk:** {summary_highest_risk}
- **Best Product:** {summary_best_product}
- **Best Customer:** {summary_best_customer}
- **Key Recommendation:** {summary_key_recommendation}
""")
    except Exception as e:
        st.info(f"Executive summary unavailable: {e}")

# ════════════════════════════════════════════
# TAB 2 — PRICE OPTIMIZATION ENGINE  (PSI / CUM / Win Probability / Smart Discount)
# AI-integrated: recommendation text at every stage is now Cortex-generated,
# with the original rule-based text kept as a safety-net fallback.
# ════════════════════════════════════════════
if _active_tab == "💰 Price Engine":
    section("🔍", "Price Optimization Engine")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'Find the most profitable selling price using demand elasticity modelling, '
        'Price Sensitivity Index (PSI), and Cortex AI-generated pricing guidance.</p>',
        unsafe_allow_html=True
    )

    # ── Load product list ──
    try:
        sku_df = session.sql("""
            SELECT SKU, TOTAL_COST
            FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
            ORDER BY SKU
        """).to_pandas()
    except Exception as e:
        st.error(f"Failed to load product list: {e}")
        sku_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

    col1, col2 = st.columns([1.2, 1])
    with col1:
        selected_sku_pe = st.selectbox("Select Product SKU", sku_df["SKU"].tolist(), key="pe_sku")
    with col2:
        base_demand_pe = st.number_input(
            "Expected Monthly Demand (units)", value=1000, step=100, min_value=100, key="pe_demand"
        )

    # ── Customer Price Lookup ──
    divider()
    section("🧾", "Customer Price Lookup")

    col_a, col_b = st.columns(2)
    try:
        customer_df = session.sql("""
            SELECT DISTINCT CUSTOMER_ID
            FROM PRICING_ENGINE_DB.CORE_INPUT.CUSTOMER_AGREEMENTS
            ORDER BY CUSTOMER_ID
        """).to_pandas()

        with col_a:
            selected_sku_cp = st.selectbox("Product SKU", sku_df["SKU"].tolist(), key="cp_sku")
        with col_b:
            selected_cust = st.selectbox(
                "Customer", customer_df["CUSTOMER_ID"].tolist(), key="cp_cust"
            )

        if st.button("🔎 Lookup Customer Price", key="cp_btn"):
            try:
                result_df = session.sql(f"""
                    SELECT p.SKU, p.PRODUCT_FAMILY, p.TOTAL_COST,
                           p.FLOOR_PRICE, p.TARGET_PRICE, p.CEILING_PRICE,
                           c.CUSTOMER_ID, c.DISCOUNTED_PRICE
                    FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING c
                    JOIN PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX p ON c.SKU = p.SKU
                    WHERE p.SKU = '{selected_sku_cp}' AND c.CUSTOMER_ID = '{selected_cust}'
                    LIMIT 1
                """).to_pandas()
                st.session_state["cp_result"] = result_df
            except Exception as e:
                st.session_state["cp_result"] = None
                st.error(f"Lookup failed: {e}")

        # Render persisted customer lookup result
        if st.session_state["cp_result"] is not None:
            result_df = st.session_state["cp_result"]
            if result_df.empty:
                st.error("No pricing data found for this SKU + Customer combination.")
            else:
                row = result_df.iloc[0]
                st.success("✅ Pricing found")
                m1,m2,m3,m4,m5 = st.columns(5)
                m1.metric("Cost",             f"₹{row['TOTAL_COST']:,.2f}")
                m2.metric("Floor Price",      f"₹{row['FLOOR_PRICE']:,.2f}")
                m3.metric("Target Price",     f"₹{row['TARGET_PRICE']:,.2f}")
                m4.metric("Ceiling Price",    f"₹{row['CEILING_PRICE']:,.2f}")
                m5.metric("Discounted Price", f"₹{row['DISCOUNTED_PRICE']:,.2f}")
                st.dataframe(result_df, use_container_width=True, hide_index=True)

    except Exception as e:
        st.warning(f"Customer lookup unavailable: {e}")

    # ════════════════════════════════════════════════════════════════════════
    # PSI — PRICE SENSITIVITY INDEX SECTION
    # Reads from PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
    # Uses the customer selected in the Customer Price Lookup above.
    # Margin tiering stays deterministic (drives the real price calculation);
    # the recommendation text is now Cortex AI_COMPLETE-generated.
    # ════════════════════════════════════════════════════════════════════════

    divider()
    section("🧠", "Price Sensitivity Analysis")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'PSI-driven margin adjustment — margin tier is derived from the customer\'s '
        'price sensitivity, and the pricing recommendation is generated by Cortex AI.</p>',
        unsafe_allow_html=True
    )

    # Determine which customer to use for PSI lookup.
    # Use the customer selected in the Customer Price Lookup widget above.
    psi_customer = selected_cust if "cp_cust" in st.session_state else None

    if psi_customer is None:
        st.info("Select a customer in the Customer Price Lookup section above to load PSI data.")
    else:
        # ── Load PSI from Snowflake ──
        try:
            psi_df = session.sql(f"""
                SELECT
                    CUSTOMER_ID,
                    CUSTOMER_SEGMENT,
                    PRICE_SENSITIVITY_INDEX
                FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY
                WHERE CUSTOMER_ID = '{psi_customer}'
                LIMIT 1
            """).to_pandas()
        except Exception as e:
            st.error(f"Could not load PSI data: {e}")
            psi_df = pd.DataFrame()

        if psi_df.empty:
            st.warning(
                f"No PSI record found for customer **{psi_customer}**. "
                "Ensure the PRICE_SENSITIVITY table contains this customer."
            )
        else:
            psi_row       = psi_df.iloc[0]
            psi_val       = float(psi_row["PRICE_SENSITIVITY_INDEX"])
            psi_segment   = str(psi_row["CUSTOMER_SEGMENT"])

            # ── PSI-derived values — v2: FULLY AI-DRIVEN ──
            # No PSI>=0.8 lookup table. Cortex AI reasons over the PSI value,
            # segment, and prior decisions for this customer, and returns its
            # own recommended margin (a number, used in ONE deterministic
            # multiplication below to get a price) plus a full score/label/
            # confidence/reasoning/risks/opportunities/actions payload.
            psi_payload = ai_reason_score(
                module="price_sensitivity",
                decision_type="psi_margin_strategy",
                context_facts=(
                    f"Customer: {psi_customer}\nSegment: {psi_segment}\n"
                    f"Price Sensitivity Index: {psi_val:.2f} (0 = insensitive, 1 = highly sensitive)"
                ),
                extra_instruction=(
                    "Determine price sensitivity, elasticity, negotiation difficulty, "
                    "willingness to pay, margin opportunity, and pricing strategy for this "
                    "customer. The 'score' field should represent pricing/margin opportunity "
                    "(higher = more margin room). Also return 'margin_pct', the margin percent "
                    "(0-100) you recommend charging this customer on top of cost."
                ),
                numeric_fields={"margin_pct": "recommended margin percent, a number 0-100"},
                cache_key=_ai_cache_key("psi_v2", psi_customer, psi_val, psi_segment),
            )

            if psi_payload.get("ai_generated") and "margin_pct" in psi_payload:
                psi_margin_pct = psi_payload["margin_pct"]
                psi_margin_dec = psi_margin_pct / 100.0
                psi_margin_label = psi_payload["label"]
                psi_score = int(round(psi_payload["score"]))
                psi_score_status = psi_payload["label"]
                psi_score_color = ("#00C7B2" if psi_score >= 75 else "#38BDF8" if psi_score >= 55
                                    else "#F59E0B" if psi_score >= 35 else "#EF4444")
                psi_recommendation = psi_payload["reasoning"]
            else:
                # AI service unavailable — use a neutral, clearly-labeled state
                # rather than silently reintroducing a hardcoded margin table.
                st.warning("⚠️ Cortex AI pricing strategy service unavailable — using last-known safe default (10% margin) until AI responds.")
                psi_margin_pct, psi_margin_dec = 10.0, 0.10
                psi_margin_label = "AI Unavailable"
                psi_score, psi_score_status, psi_score_color = 0, "AI Unavailable", "#6B8BAF"
                psi_recommendation = "Cortex AI did not return a pricing strategy for this customer."

            # ── Derive optimized price from cost + PSI margin (deterministic) ──
            psi_cost = None
            psi_optimized_price  = None
            psi_final_price      = None
            psi_discount_pct     = 0.0

            if not sku_df.empty and selected_sku_pe in sku_df["SKU"].values:
                psi_cost = float(
                    sku_df[sku_df["SKU"] == selected_sku_pe]["TOTAL_COST"].iloc[0]
                )
                # Price = Cost × (1 + PSI Margin)
                psi_optimized_price = psi_cost * (1 + psi_margin_dec)

                # Apply existing customer discount if a lookup result exists
                if (
                    st.session_state["cp_result"] is not None
                    and not st.session_state["cp_result"].empty
                ):
                    cp_row       = st.session_state["cp_result"].iloc[0]
                    cp_target    = float(cp_row["TARGET_PRICE"])
                    cp_discounted= float(cp_row["DISCOUNTED_PRICE"])
                    # Back-calculate the discount % from the existing customer record
                    if cp_target > 0:
                        psi_discount_pct = ((cp_target - cp_discounted) / cp_target) * 100
                    psi_final_price = psi_optimized_price * (1 - psi_discount_pct / 100)
                else:
                    # No customer lookup done yet — show optimized price without discount
                    psi_final_price  = psi_optimized_price
                    psi_discount_pct = 0.0

            # ── KPI Cards ──
            kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)
            kpi1.metric("Price Sensitivity Index", f"{psi_val:.2f}")
            kpi2.metric("PSI Margin",              f"{psi_margin_pct:.0f}%")
            if psi_optimized_price is not None:
                kpi3.metric("Optimized Price",     f"₹{psi_optimized_price:,.2f}")
                kpi4.metric("Final Selling Price", f"₹{psi_final_price:,.2f}")
            else:
                kpi3.metric("Optimized Price",     "Select SKU above")
                kpi4.metric("Final Selling Price", "Select SKU above")
            kpi5.metric("Pricing Score",           f"{psi_score}/100")

            divider()

            # ── Pricing Sensitivity Score bar (reuses existing health_bar_html) ──
            section("📊", "Pricing Sensitivity Score")
            st.markdown(
                health_bar_html(psi_score, psi_score_color, psi_score_status),
                unsafe_allow_html=True
            )

            divider()

            # ── PSI Detail cards — left / right ──
            col_psi_l, col_psi_r = st.columns(2)

            with col_psi_l:
                section("🔍", "Sensitivity Analysis")
                st.write(f"• **Customer:** {psi_customer}")
                st.write(f"• **Customer Segment:** {psi_segment}")
                st.write(f"• **Price Sensitivity Index:** {psi_val:.2f}")
                st.write(f"• **Recommended Margin:** {psi_margin_pct:.0f}%  —  {psi_margin_label}")
                if psi_optimized_price is not None:
                    st.write(f"• **Optimized Price:** ₹{psi_optimized_price:,.2f}")
                    st.write(f"• **Customer Discount:** {psi_discount_pct:.1f}%")
                    st.write(f"• **Final Selling Price:** ₹{psi_final_price:,.2f}")

            with col_psi_r:
                section("💡", "Pricing Recommendation (Cortex AI)")
                # Show appropriately styled banner based on PSI, with AI-generated text
                if psi_val >= 0.80:
                    st.error(f"🔴 {psi_recommendation}")
                elif psi_val >= 0.60:
                    st.warning(f"🟡 {psi_recommendation}")
                elif psi_val >= 0.40:
                    st.info(f"🔵 {psi_recommendation}")
                elif psi_val >= 0.20:
                    st.success(f"🟢 {psi_recommendation}")
                else:
                    st.success(f"🟢 {psi_recommendation}")

                # Margin tier reference table
                st.markdown(
                    '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
                    'Margin Tier Reference</p>',
                    unsafe_allow_html=True
                )
                tier_df = pd.DataFrame({
                    "PSI Range":   ["≥ 0.80", "0.60 – 0.79", "0.40 – 0.59", "0.20 – 0.39", "< 0.20"],
                    "Margin":      ["8%",      "15%",          "22%",          "30%",          "40%"],
                    "Strategy":    [
                        "Highly Price Sensitive",
                        "Competitive Pricing",
                        "Balanced Pricing",
                        "Premium Pricing",
                        "Maximum Margin",
                    ],
                })
                st.dataframe(tier_df, use_container_width=True, hide_index=True)

            # ── Save PSI results to session state ──
            st.session_state["psi_results"] = {
                "customer":          psi_customer,
                "segment":           psi_segment,
                "psi":               psi_val,
                "margin_pct":        psi_margin_pct,
                "margin_label":      psi_margin_label,
                "optimized_price":   psi_optimized_price,
                "discount_pct":      psi_discount_pct,
                "final_price":       psi_final_price,
                "score":             psi_score,
                "score_status":      psi_score_status,
                "recommendation":    psi_recommendation,
                "sku":               selected_sku_pe,
                "cost":              psi_cost,
            }

            divider()

            # ── Executive Summary ──
            section("📋", "Executive Summary")

            exec_lines = [
                f"Customer            : {psi_customer}",
                f"Customer Segment    : {psi_segment}",
                f"Product SKU         : {selected_sku_pe}",
                f"Price Sensitivity   : {psi_val:.2f}",
                f"Recommended Margin  : {psi_margin_pct:.0f}%  ({psi_margin_label})",
            ]
            if psi_cost is not None:
                exec_lines += [
                    f"Original Cost       : ₹{psi_cost:,.2f}",
                    f"Optimized Price     : ₹{psi_optimized_price:,.2f}",
                    f"Customer Discount   : {psi_discount_pct:.1f}%",
                    f"Final Selling Price : ₹{psi_final_price:,.2f}",
                ]
            exec_lines += [
                f"Pricing Score       : {psi_score}/100  ({psi_score_status})",
                "",
                "Recommendation (Cortex AI)",
                "-" * 40,
                psi_recommendation,
            ]

            st.text_area(
                "",
                "\n".join(exec_lines),
                height=280,
                key="psi_exec_summary"
            )

    # ════════════════════════════════════════════════════════════════════════
    # END PSI SECTION
    # ════════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════════
    # 🏭 PLANT CAPACITY ANALYSIS — Capacity Utilization Modifier (CUM)
    # Modifier % stays deterministic (feeds the price calculation); the
    # business impact / recommendation text is now Cortex AI-generated.
    # ════════════════════════════════════════════════════════════════════════

    divider()
    section("🏭", "Plant Capacity Analysis")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'Capacity Utilization Modifier (CUM) — adjusts the PSI-optimized price '
        'based on how busy the selected plant currently is; the business impact '
        'narrative is generated by Cortex AI.</p>',
        unsafe_allow_html=True
    )

    if st.session_state["psi_results"] is None:
        st.info("Complete the Price Sensitivity Analysis above to calculate the Capacity Utilization Modifier.")
    else:
        pr = st.session_state["psi_results"]

        if pr["optimized_price"] is None:
            st.info("Optimized Price not available yet — select a valid SKU above.")
        else:
            # ── Load plant capacity data from Snowflake ──
            try:
                plant_df = session.sql("""
                    SELECT
                        PLANT_ID,
                        PLANT_NAME,
                        CURRENT_UTILIZATION,
                        MAX_CAPACITY,
                        AVAILABLE_CAPACITY
                    FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY
                    ORDER BY PLANT_NAME
                """).to_pandas()
            except Exception as e:
                st.error(f"Could not load plant capacity data: {e}")
                plant_df = pd.DataFrame()

            if plant_df.empty:
                st.warning("No plant capacity data found in PLANT_CAPACITY.")
            else:
                selected_plant_name = st.selectbox(
                    "Select Plant", plant_df["PLANT_NAME"].tolist(), key="cum_plant"
                )
                plant_row = plant_df[plant_df["PLANT_NAME"] == selected_plant_name].iloc[0]
                plant_utilization   = float(plant_row["CURRENT_UTILIZATION"])
                plant_available_cap = float(plant_row["AVAILABLE_CAPACITY"])

                # ── Capacity Utilization Modifier — v2: FULLY AI-DRIVEN ──
                # No <50/70/85% lookup table. Cortex AI judges production risk,
                # capacity health, supply-chain risk, and manufacturing
                # flexibility, and returns its own recommended price modifier
                # (used in ONE deterministic multiplication below).
                cum_payload = ai_reason_score(
                    module="capacity",
                    decision_type="capacity_modifier",
                    context_facts=(
                        f"Plant: {selected_plant_name}\n"
                        f"Current utilization: {plant_utilization:.1f}%\n"
                        f"Available capacity: {plant_available_cap:,.0f} units"
                    ),
                    extra_instruction=(
                        "Determine production risk, capacity health, supply chain risk, and "
                        "manufacturing flexibility. The 'score' field should represent overall "
                        "capacity health (higher = healthier). Also return 'modifier_pct', the "
                        "price adjustment percent you recommend applying to the selling price "
                        "given this utilization level — can be negative (discount to attract "
                        "volume) or positive (premium to protect a constrained plant)."
                    ),
                    numeric_fields={"modifier_pct": "recommended price modifier percent, a number from -20 to 20"},
                    cache_key=_ai_cache_key("cum_v2", selected_plant_name, round(plant_utilization, 1)),
                )

                if cum_payload.get("ai_generated") and "modifier_pct" in cum_payload:
                    capacity_modifier_dec = cum_payload["modifier_pct"] / 100.0
                    capacity_status_label = cum_payload["label"]
                    capacity_health_score = cum_payload["score"]
                    capacity_status_color = ("green" if capacity_health_score >= 60
                                              else "orange" if capacity_health_score >= 35 else "red")
                    capacity_recommendation = cum_payload["reasoning"]
                else:
                    st.warning("⚠️ Cortex AI capacity service unavailable — using a neutral 0% modifier until AI responds.")
                    capacity_modifier_dec = 0.0
                    capacity_status_label = "AI Unavailable"
                    capacity_health_score = 0
                    capacity_status_color = "orange"
                    capacity_recommendation = "Cortex AI did not return a capacity assessment for this plant."

                # ── Apply CUM to the PSI-optimized price (the one deterministic multiplication) ──
                capacity_adjusted_price = pr["optimized_price"] * (1 + capacity_modifier_dec)

                # ── Re-apply the SAME customer discount % that PSI already calculated ──
                cum_discount_pct = pr["discount_pct"]
                cum_final_price  = capacity_adjusted_price * (1 - cum_discount_pct / 100)

                # ── KPI Cards ──
                cap1, cap2, cap3, cap4 = st.columns(4)
                cap1.metric("Current Utilization", f"{plant_utilization:.1f}%")
                cap2.metric("Capacity Modifier",   f"{capacity_modifier_dec * 100:+.0f}%")
                cap3.metric("Available Capacity",  f"{plant_available_cap:,.0f} units")
                cap4.metric("Capacity Status",     capacity_status_label)

                cap5, cap6 = st.columns(2)
                cap5.metric("Capacity Adjusted Price", f"₹{capacity_adjusted_price:,.2f}")
                cap6.metric("Final Selling Price",     f"₹{cum_final_price:,.2f}")

                divider()

                # ── Capacity Health Score bar (reuses existing health_bar_html) ──
                section("📊", "Capacity Health Score")
                st.markdown(
                    health_bar_html(capacity_health_score, capacity_status_color, capacity_status_label),
                    unsafe_allow_html=True
                )

                divider()

                cum_col_l, cum_col_r = st.columns(2)
                with cum_col_l:
                    section("🔍", "Capacity Details")
                    st.write(f"• **Plant:** {selected_plant_name}")
                    st.write(f"• **Current Utilization:** {plant_utilization:.1f}%")
                    st.write(f"• **Capacity Modifier:** {capacity_modifier_dec * 100:+.0f}%")
                    st.write(f"• **Available Capacity:** {plant_available_cap:,.0f} units")
                    st.write(f"• **Status:** {capacity_status_label}")
                    st.write(f"• **Optimized Price (from PSI):** ₹{pr['optimized_price']:,.2f}")
                    st.write(f"• **Capacity Adjusted Price:** ₹{capacity_adjusted_price:,.2f}")
                    st.write(f"• **Customer Discount:** {cum_discount_pct:.1f}%")
                    st.write(f"• **Final Selling Price:** ₹{cum_final_price:,.2f}")

                with cum_col_r:
                    section("💡", "Capacity Recommendation (Cortex AI)")
                    if capacity_modifier_dec >= 0.10:
                        st.error(f"🔴 {capacity_recommendation}")
                    elif capacity_modifier_dec >= 0.05:
                        st.warning(f"🟡 {capacity_recommendation}")
                    else:
                        st.success(f"🟢 {capacity_recommendation}")

                    st.markdown(
                        '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
                        'Capacity Modifier Reference</p>',
                        unsafe_allow_html=True
                    )
                    cum_tier_df = pd.DataFrame({
                        "Utilization": ["< 50%", "50 – 70%", "70 – 85%", "> 85%"],
                        "Modifier":    ["-5%", "0%", "+5%", "+10%"],
                        "Status":      ["🟢 Under Utilized", "🟢 Normal", "🟡 Busy", "🔴 Near Capacity"],
                    })
                    st.dataframe(cum_tier_df, use_container_width=True, hide_index=True)

                # ── Save CUM results to session state ──
                st.session_state["cum_results"] = {
                    "plant_name":              selected_plant_name,
                    "plant_utilization":       plant_utilization,
                    "available_capacity":      plant_available_cap,
                    "capacity_modifier_pct":   capacity_modifier_dec * 100,
                    "capacity_status_label":   capacity_status_label,
                    "capacity_health_score":   capacity_health_score,
                    "capacity_recommendation": capacity_recommendation,
                    "optimized_price":         pr["optimized_price"],
                    "capacity_adjusted_price": capacity_adjusted_price,
                    "discount_pct":            cum_discount_pct,
                    "final_price":             cum_final_price,
                }

                divider()

                # ── Executive Summary (CUM-aware) ──
                section("📋", "Executive Summary")

                cum_exec_lines = [
                    f"Plant Name          : {selected_plant_name}",
                    f"Current Utilization : {plant_utilization:.1f}%",
                    f"Capacity Modifier   : {capacity_modifier_dec * 100:+.0f}%  ({capacity_status_label})",
                    f"Optimized Price     : ₹{pr['optimized_price']:,.2f}",
                    f"Capacity Adj. Price : ₹{capacity_adjusted_price:,.2f}",
                    f"Customer Discount   : {cum_discount_pct:.1f}%",
                    f"Final Selling Price : ₹{cum_final_price:,.2f}",
                    "",
                    "Recommendation (Cortex AI)",
                    "-" * 40,
                    capacity_recommendation,
                ]

                st.text_area(
                    "",
                    "\n".join(cum_exec_lines),
                    height=260,
                    key="cum_exec_summary"
                )

    # ════════════════════════════════════════════════════════════════════════
    # END CUM SECTION
    # ════════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════════
    # 🎯 WIN PROBABILITY PREDICTOR
    # Sits after CUM in the pipeline:
    # Cost → Price Matrix → PSI → CUM → Win Probability → Customer Discount → Final Price
    # The win-probability SCORE stays a deterministic business-rule formula
    # (a real predictive calculation); the EXPLANATION of that score and the
    # recommended action are now Cortex AI-generated.
    #
    # ⚠️ ASSUMPTION: competitor average price is read from
    #    PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING (SKU, COMPETITOR_AVG_PRICE).
    # ════════════════════════════════════════════════════════════════════════

    divider()
    section("🎯", "Win Probability Predictor")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'Estimates the probability of winning this order using PSI, capacity '
        'utilization, discount depth, and market position — the explanation and '
        'recommended action are generated by Cortex AI.</p>',
        unsafe_allow_html=True
    )

    def win_probability_gauge_html(value, color_hex, status_label):
        """Semi-circle SVG gauge — no external chart library required."""
        import math
        angle    = max(min(value, 100), 0) / 100 * 180
        radius   = 80
        cx, cy   = 100, 100
        end_x    = cx - radius * math.cos(math.radians(angle))
        end_y    = cy - radius * math.sin(math.radians(angle))
        large_arc = 1 if angle > 180 else 0
        return f"""
        <div style="text-align:center;padding-top:6px;">
            <svg width="220" height="130" viewBox="0 0 200 110">
                <path d="M 20 100 A 80 80 0 0 1 180 100"
                      fill="none" stroke="#1E2A3A" stroke-width="14" stroke-linecap="round"/>
                <path d="M 20 100 A 80 80 0 {large_arc} 1 {end_x:.1f} {end_y:.1f}"
                      fill="none" stroke="{color_hex}" stroke-width="14" stroke-linecap="round"/>
                <text x="100" y="88" text-anchor="middle" font-size="30" font-weight="700"
                      fill="#E8EEF7">{value:.0f}%</text>
            </svg>
            <p style="color:#6B8BAF;font-size:13px;margin-top:-6px;">{status_label}</p>
        </div>
        """

    def compute_win_probability(price, psi, discount_pct, capacity_mod_pct, competitor_avg):
        """
        v2 NOTE: The headline Win Probability shown to the user comes from
        the AI-driven ai_reason_score() call above (module="win_probability").
        This formula is kept ONLY as a fast, lightweight estimator to drive
        the interactive price-sweep chart further down (9+ points, redrawn
        on every rerun) — running a live Cortex call per sweep point per
        rerun would be slow and wasteful. It is intentionally NOT used for
        any number presented as "the" AI decision.
        """
        base_score = 50.0
        psi_impact = (0.5 - psi) * 20.0

        gap_pct = None
        if competitor_avg and competitor_avg > 0:
            try:
                gap_pct = safe_pct_change(competitor_avg, price)
            except Exception:
                gap_pct = ((price - competitor_avg) / competitor_avg) * 100.0
            competitor_impact = max(min(-gap_pct * 0.6, 20.0), -20.0)
        else:
            competitor_impact = 0.0

        discount_impact = max(min(discount_pct * 0.4, 15.0), 0.0)
        capacity_impact = -(capacity_mod_pct) * 0.5

        raw_score = base_score + psi_impact + competitor_impact + discount_impact + capacity_impact
        clamped   = max(min(raw_score, 100.0), 0.0)
        return clamped, gap_pct

    if st.session_state["psi_results"] is None:
        st.info("Complete the Price Sensitivity Analysis above to calculate Win Probability.")
    elif st.session_state["psi_results"]["optimized_price"] is None:
        st.info("Optimized Price not available yet — select a valid SKU above.")
    else:
        pr = st.session_state["psi_results"]
        cr = st.session_state.get("cum_results")  # may be None if plant not selected yet

        wp_customer   = pr["customer"]
        wp_segment    = pr["segment"]
        wp_sku        = pr["sku"]
        wp_psi        = pr["psi"]
        wp_cost       = pr["cost"]

        if cr is not None:
            wp_base_price        = cr["capacity_adjusted_price"]
            wp_final_price       = cr["final_price"]
            wp_discount_pct      = cr["discount_pct"]
            wp_capacity_mod_pct  = cr["capacity_modifier_pct"]
            wp_plant_util        = cr["plant_utilization"]
            wp_plant_name        = cr["plant_name"]
        else:
            wp_base_price        = pr["optimized_price"]
            wp_final_price       = pr["final_price"]
            wp_discount_pct      = pr["discount_pct"]
            wp_capacity_mod_pct  = 0.0
            wp_plant_util        = None
            wp_plant_name        = None

        # ── Competitor Market Average ──
        competitor_avg_price = None
        try:
            comp_df = session.sql(f"""
                SELECT AVG(COMPETITOR_AVG_PRICE) AS AVG_PRICE
                FROM PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING
                WHERE SKU = '{wp_sku}'
            """).to_pandas()
            if not comp_df.empty and pd.notna(comp_df.iloc[0]["AVG_PRICE"]):
                competitor_avg_price = float(comp_df.iloc[0]["AVG_PRICE"])
        except Exception:
            competitor_avg_price = None

        # ── Win Probability — v2: FULLY AI-DRIVEN for the headline decision ──
        # No "base 50 + PSI impact + competitor impact..." formula for the
        # number shown to the user. Cortex AI reasons over price, PSI,
        # discount, capacity posture, and market gap, and returns its own
        # win-probability judgment plus full reasoning. (The lightweight
        # deterministic estimator below — see compute_win_probability — is
        # retained ONLY to drive the fast interactive price-sweep chart
        # further down, where recomputing via a live Cortex call for every
        # point on every rerun would be both slow and wasteful; the batched
        # AI sweep call further down is the AI-generated version of that
        # chart.)
        market_gap_pct = (
            safe_pct_change(competitor_avg_price, wp_final_price) if competitor_avg_price else None
        )
        wp_payload = ai_reason_score(
            module="win_probability",
            decision_type="deal_win_probability",
            context_facts=(
                f"Customer: {wp_customer} ({wp_segment})\nSKU: {wp_sku}\n"
                f"Price Sensitivity Index: {wp_psi:.2f}\nFinal selling price: ₹{wp_final_price:,.2f}\n"
                f"Customer discount: {wp_discount_pct:.1f}%\nCapacity price modifier: {wp_capacity_mod_pct:+.0f}%\n"
                + (f"Competitor market average: ₹{competitor_avg_price:,.2f} (gap {market_gap_pct:+.1f}%)"
                   if competitor_avg_price is not None else "No competitor market data available.")
            ),
            extra_instruction=(
                "Estimate the probability (0-100) that this deal is won. The 'score' field IS "
                "the win probability itself."
            ),
            cache_key=_ai_cache_key("wp_v2", wp_customer, wp_sku, round(wp_final_price, 2)),
        )

        if wp_payload.get("ai_generated"):
            win_probability = wp_payload["score"]
            wp_recommendation = wp_payload["reasoning"]
        else:
            st.warning("⚠️ Cortex AI win-probability service unavailable — showing a neutral 50% placeholder until AI responds.")
            win_probability = 50.0
            wp_recommendation = "Cortex AI did not return a win-probability assessment for this deal."

        win_probability_dec = win_probability / 100.0

        expected_revenue = wp_final_price * base_demand_pe * win_probability_dec
        expected_profit  = (
            (wp_final_price - wp_cost) * base_demand_pe * win_probability_dec
            if wp_cost is not None else None
        )

        if win_probability > 85:
            deal_status_label, deal_status_color, deal_status_hex = "🟢 Excellent", "green", "#3DDC97"
        elif win_probability >= 70:
            deal_status_label, deal_status_color, deal_status_hex = "🟡 High", "orange", "#FFD84C"
        elif win_probability >= 50:
            deal_status_label, deal_status_color, deal_status_hex = "🟠 Moderate", "orange", "#FFB84C"
        else:
            deal_status_label, deal_status_color, deal_status_hex = "🔴 High Risk", "red", "#E05C5C"

        # ── KPI Cards ──
        wp1, wp2, wp3, wp4 = st.columns(4)
        wp1.metric("Win Probability",  f"{win_probability:.0f}%")
        wp2.metric("Expected Revenue", f"₹{expected_revenue:,.2f}")
        wp3.metric(
            "Expected Profit",
            f"₹{expected_profit:,.2f}" if expected_profit is not None else "N/A"
        )
        wp4.metric("Deal Status", deal_status_label)

        divider()

        gauge_col, detail_col = st.columns([1, 1.2])

        with gauge_col:
            section("📈", "Win Probability Gauge")
            st.markdown(
                win_probability_gauge_html(win_probability, deal_status_hex, deal_status_label),
                unsafe_allow_html=True
            )

        with detail_col:
            section("🔍", "Market Position")
            st.write(f"• **Customer:** {wp_customer}  ({wp_segment})")
            st.write(f"• **SKU:** {wp_sku}")
            st.write(f"• **PSI:** {wp_psi:.2f}")
            if wp_plant_util is not None:
                st.write(f"• **Plant:** {wp_plant_name}  ({wp_plant_util:.1f}% utilized)")
            st.write(f"• **Final Selling Price:** ₹{wp_final_price:,.2f}")
            if competitor_avg_price is not None:
                st.write(f"• **Competitor Market Average:** ₹{competitor_avg_price:,.2f}")
                st.write(f"• **Market Price Gap:** {market_gap_pct:+.1f}%")
            else:
                st.write("• **Competitor Market Average:** N/A (no competitor data found for this SKU)")
            st.write(f"• **Customer Discount:** {wp_discount_pct:.1f}%")
            st.write(f"• **Capacity Modifier:** {wp_capacity_mod_pct:+.0f}%")

            st.markdown(
                health_bar_html(win_probability, deal_status_color, deal_status_label),
                unsafe_allow_html=True
            )

        divider()

        section("💡", "Win Probability Recommendation (Cortex AI)")
        if win_probability > 85:
            st.success(f"🟢 {wp_recommendation}")
        elif win_probability >= 60:
            st.warning(f"🟡 {wp_recommendation}")
        else:
            st.error(f"🔴 {wp_recommendation}")

        divider()

        section("📊", "Price Sensitivity Simulation")
        st.markdown(
            '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
            'How Win Probability, Profit, and Revenue shift as the selling price moves '
            'around the current final price (discount % held constant).</p>',
            unsafe_allow_html=True
        )

        sim_rows = []
        for pct_move in range(-20, 21, 5):
            sim_price = wp_final_price * (1 + pct_move / 100)
            sim_wp, _ = compute_win_probability(
                sim_price, wp_psi, wp_discount_pct, wp_capacity_mod_pct, competitor_avg_price
            )
            sim_wp_dec = sim_wp / 100.0
            sim_revenue = sim_price * base_demand_pe * sim_wp_dec
            sim_profit  = (
                (sim_price - wp_cost) * base_demand_pe * sim_wp_dec
                if wp_cost is not None else None
            )
            sim_rows.append({
                "PRICE_MOVE_%":     pct_move,
                "PRICE":            round(sim_price, 2),
                "WIN_PROBABILITY":  round(sim_wp, 1),
                "EXPECTED_REVENUE": round(sim_revenue, 2),
                "EXPECTED_PROFIT":  round(sim_profit, 2) if sim_profit is not None else None,
            })
        sim_df = pd.DataFrame(sim_rows)

        sim_col1, sim_col2 = st.columns(2)

        with sim_col1:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Price vs Win Probability</p>', unsafe_allow_html=True
            )
            st.line_chart(sim_df.set_index("PRICE")[["WIN_PROBABILITY"]], height=240)

        with sim_col2:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Price vs Expected Revenue</p>', unsafe_allow_html=True
            )
            st.line_chart(sim_df.set_index("PRICE")[["EXPECTED_REVENUE"]], height=240)

        if wp_cost is not None:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Price vs Expected Profit</p>', unsafe_allow_html=True
            )
            st.line_chart(sim_df.set_index("PRICE")[["EXPECTED_PROFIT"]], height=240)

        section("📋", "Simulation Data")
        st.dataframe(sim_df, use_container_width=True, hide_index=True)

        st.session_state["win_probability_results"] = {
            "customer":             wp_customer,
            "segment":              wp_segment,
            "sku":                  wp_sku,
            "psi":                  wp_psi,
            "plant_name":           wp_plant_name,
            "plant_utilization":    wp_plant_util,
            "final_price":          wp_final_price,
            "base_price":           wp_base_price,
            "competitor_avg_price": competitor_avg_price,
            "market_gap_pct":       market_gap_pct,
            "discount_pct":         wp_discount_pct,
            "capacity_modifier_pct":wp_capacity_mod_pct,
            "win_probability":      win_probability,
            "deal_status":          deal_status_label,
            "expected_revenue":     expected_revenue,
            "expected_profit":      expected_profit,
            "recommendation":       wp_recommendation,
        }

        divider()

        section("📋", "Executive Summary")

        wp_exec_lines = [
            f"Customer            : {wp_customer}",
            f"Product SKU         : {wp_sku}",
            f"Price Sensitivity   : {wp_psi:.2f}",
            f"Capacity Utilization: {wp_plant_util:.1f}%" if wp_plant_util is not None else "Capacity Utilization: N/A",
            (
                f"Market Position     : ₹{wp_final_price:,.2f} vs competitor avg "
                f"₹{competitor_avg_price:,.2f}  ({market_gap_pct:+.1f}%)"
                if competitor_avg_price is not None
                else "Market Position     : N/A (no competitor data found)"
            ),
            f"Win Probability     : {win_probability:.0f}%  ({deal_status_label})",
            f"Expected Revenue    : ₹{expected_revenue:,.2f}",
            f"Expected Profit     : ₹{expected_profit:,.2f}" if expected_profit is not None else "Expected Profit     : N/A",
            "",
            "Recommendation (Cortex AI)",
            "-" * 40,
            wp_recommendation,
        ]

        st.text_area(
            "",
            "\n".join(wp_exec_lines),
            height=280,
            key="wp_exec_summary"
        )

    # ════════════════════════════════════════════════════════════════════════
    # END WIN PROBABILITY PREDICTOR SECTION
    # ════════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════════
    # ⭐ SMART DISCOUNT OPTIMIZER
    # Discount simulation math stays deterministic; the business
    # justification for the recommended discount is now Cortex AI-generated.
    # ════════════════════════════════════════════════════════════════════════

    divider()
    section("⭐", "Smart Discount Optimizer")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'Simulates multiple discount levels on top of the PSI + Capacity-adjusted '
        'price and recommends the discount that maximizes profit while keeping '
        'Win Probability above 80% — with a Cortex AI-generated justification.</p>',
        unsafe_allow_html=True
    )

    if st.session_state.get("win_probability_results") is None:
        st.info("Complete the Win Probability Predictor above to run the Smart Discount Optimizer.")
    else:
        pr = st.session_state["psi_results"]
        cr = st.session_state.get("cum_results")
        wr = st.session_state["win_probability_results"]

        sdo_customer         = wr["customer"]
        sdo_segment          = wr["segment"]
        sdo_sku              = wr["sku"]
        sdo_psi              = wr["psi"]
        sdo_cost             = pr["cost"]
        sdo_capacity_mod_pct = wr["capacity_modifier_pct"]
        sdo_competitor_avg   = wr["competitor_avg_price"]
        sdo_current_discount = wr["discount_pct"]

        sdo_base_price = cr["capacity_adjusted_price"] if cr is not None else pr["optimized_price"]

        sdo_current_price       = wr["final_price"]
        sdo_current_win_prob    = wr["win_probability"]
        sdo_current_revenue     = wr["expected_revenue"]
        sdo_current_profit      = wr["expected_profit"]

        # ── v2: FULLY AI-DRIVEN scenario scoring + selection ──
        # Win probability per discount level comes from ONE batched Cortex
        # call (not a formula, not 5 separate calls). Revenue/profit per
        # level stay deterministic multiplication once win probability is
        # known. Which scenario is "best" is then also an AI judgment
        # (module="discount_optimizer", decision_type="scenario_selection")
        # reasoning over the whole simulation table — not a fixed
        # "win>=80 then max profit" rule.
        discount_levels = [0, 2, 5, 8, 10]
        level_contexts = [
            f"Discount {d}%: price would be ₹{sdo_base_price * (1 - d/100):,.2f}, "
            f"PSI {sdo_psi:.2f}, capacity modifier {sdo_capacity_mod_pct:+.0f}%"
            + (f", competitor avg ₹{sdo_competitor_avg:,.2f}" if sdo_competitor_avg else "")
            for d in discount_levels
        ]
        wp_batch = ai_reason_score_batch(
            module="discount_optimizer", decision_type="win_probability_per_discount",
            items_context=level_contexts,
            extra_instruction="The 'score' field IS the estimated win probability (0-100) at that discount level.",
            cache_key=_ai_cache_key("sdo_wp_batch", sdo_customer, sdo_sku, round(sdo_base_price, 2)),
        )

        sdo_rows = []
        for d, wp_item in zip(discount_levels, wp_batch):
            sim_final_price = sdo_base_price * (1 - d / 100)
            sim_win_prob = wp_item["score"] if wp_item["ai_generated"] else 50.0
            sim_win_prob_dec = sim_win_prob / 100.0
            sim_revenue = sim_final_price * base_demand_pe * sim_win_prob_dec
            sim_profit  = (
                (sim_final_price - sdo_cost) * base_demand_pe * sim_win_prob_dec
                if sdo_cost is not None else None
            )
            sdo_rows.append({
                "DISCOUNT_%":        d,
                "FINAL_PRICE":       round(sim_final_price, 2),
                "EXPECTED_REVENUE":  round(sim_revenue, 2),
                "EXPECTED_PROFIT":   round(sim_profit, 2) if sim_profit is not None else None,
                "WIN_PROBABILITY":   round(sim_win_prob, 1),
            })
        sdo_df = pd.DataFrame(sdo_rows)

        # AI scenario selection — reasons over the full table, not a fixed rule.
        scenario_table_text = "\n".join(
            f"Discount {row['DISCOUNT_%']}%: price ₹{row['FINAL_PRICE']:,.2f}, "
            f"win probability {row['WIN_PROBABILITY']:.0f}%, expected revenue ₹{row['EXPECTED_REVENUE']:,.0f}, "
            f"expected profit {'₹' + format(row['EXPECTED_PROFIT'], ',.0f') if row['EXPECTED_PROFIT'] is not None else 'N/A'}"
            for _, row in sdo_df.iterrows()
        )
        selection_payload = ai_reason_score(
            module="discount_optimizer", decision_type="scenario_selection",
            context_facts=scenario_table_text,
            extra_instruction=(
                "Pick the single best discount scenario from the table above, considering "
                "profit, revenue, and win probability together (use your judgment on the "
                "tradeoff — do not just pick the highest profit or a fixed win-probability "
                "cutoff). The 'score' field should represent how strong this recommendation "
                "is (0-100). Also return 'recommended_discount_pct', the exact discount percent "
                "you are recommending — it MUST be one of the values in the table."
            ),
            numeric_fields={"recommended_discount_pct": "the chosen discount percent, must match one of the table rows exactly"},
            cache_key=_ai_cache_key("sdo_selection", scenario_table_text),
        )

        if selection_payload.get("ai_generated") and "recommended_discount_pct" in selection_payload:
            chosen_d = min(discount_levels, key=lambda d: abs(d - selection_payload["recommended_discount_pct"]))
            sdo_best = sdo_df[sdo_df["DISCOUNT_%"] == chosen_d].iloc[0]
            ai_selection_reasoning = selection_payload["reasoning"]
        else:
            # AI unavailable — fall back to the scenario with the highest win
            # probability (a neutral, non-business-rule tiebreak) rather than
            # silently reinstating a hardcoded margin/profit rule.
            sdo_best = sdo_df.loc[sdo_df["WIN_PROBABILITY"].idxmax()]
            ai_selection_reasoning = "Cortex AI scenario-selection service unavailable; showing the highest win-probability scenario."

        recommended_discount   = float(sdo_best["DISCOUNT_%"])
        recommended_price      = float(sdo_best["FINAL_PRICE"])
        recommended_revenue    = float(sdo_best["EXPECTED_REVENUE"])
        recommended_profit     = sdo_best["EXPECTED_PROFIT"]
        recommended_win_prob   = float(sdo_best["WIN_PROBABILITY"])

        if recommended_profit is not None and sdo_current_profit is not None:
            profit_improvement = recommended_profit - sdo_current_profit
            try:
                profit_improvement_pct = safe_pct_change(sdo_current_profit, recommended_profit)
            except Exception:
                profit_improvement_pct = (
                    ((recommended_profit - sdo_current_profit) / abs(sdo_current_profit)) * 100
                    if sdo_current_profit else None
                )
        else:
            profit_improvement     = None
            profit_improvement_pct = None

        # AI-generated justification, combined with the AI's own scenario-selection reasoning
        sdo_recommendation = ai_discount_justification(
            sdo_customer, sdo_sku, sdo_current_discount, recommended_discount,
            sdo_current_profit, recommended_profit, recommended_win_prob
        )
        if ai_selection_reasoning:
            sdo_recommendation = f"{sdo_recommendation} {ai_selection_reasoning}"

        # ── KPI Cards ──
        sdo1, sdo2, sdo3, sdo4 = st.columns(4)
        sdo1.metric("Recommended Discount", f"{recommended_discount:.0f}%")
        sdo2.metric("Current Discount",     f"{sdo_current_discount:.1f}%")
        sdo3.metric(
            "Profit Improvement",
            f"₹{profit_improvement:,.2f}" if profit_improvement is not None else "N/A",
            f"{profit_improvement_pct:+.1f}%" if profit_improvement_pct is not None else None
        )
        sdo4.metric("Win Probability", f"{recommended_win_prob:.0f}%")

        divider()

        section("📊", "Discount Simulation")
        sdo_chart_df = sdo_df.set_index("DISCOUNT_%")

        sdo_c1, sdo_c2, sdo_c3 = st.columns(3)
        with sdo_c1:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Discount vs Profit</p>', unsafe_allow_html=True
            )
            st.bar_chart(sdo_chart_df[["EXPECTED_PROFIT"]], height=220)
        with sdo_c2:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Discount vs Revenue</p>', unsafe_allow_html=True
            )
            st.bar_chart(sdo_chart_df[["EXPECTED_REVENUE"]], height=220)
        with sdo_c3:
            st.markdown(
                '<p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">'
                'Discount vs Win Probability</p>', unsafe_allow_html=True
            )
            st.line_chart(sdo_chart_df[["WIN_PROBABILITY"]], height=220)

        divider()

        section("💡", "Discount Recommendation (Cortex AI)")
        rec_col_l, rec_col_r = st.columns([1, 1.4])
        with rec_col_l:
            st.markdown(
                f"""
                <div style="text-align:center;padding-top:6px;">
                    <p style="color:#6B8BAF;font-size:12px;margin-bottom:2px;">Recommended Discount</p>
                    <p style="font-size:44px;font-weight:700;margin:0;color:#E8EEF7;">
                        {recommended_discount:.0f}%
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )
        with rec_col_r:
            if recommended_win_prob >= 80 and abs(recommended_discount - sdo_current_discount) < 1e-9:
                st.success(f"🟢 {sdo_recommendation}")
            elif recommended_win_prob >= 80:
                st.info(f"🔵 {sdo_recommendation}")
            else:
                st.warning(f"🟡 {sdo_recommendation}")

        section("🔍", "Simulation Details")
        st.write(f"• **Customer:** {sdo_customer}  ({sdo_segment})")
        st.write(f"• **SKU:** {sdo_sku}")
        st.write(f"• **Pre-Discount Base Price:** ₹{sdo_base_price:,.2f}")
        st.write(f"• **Current Discount:** {sdo_current_discount:.1f}%  →  ₹{sdo_current_price:,.2f}")
        st.write(f"• **Recommended Discount:** {recommended_discount:.0f}%  →  ₹{recommended_price:,.2f}")
        st.write(f"• **Recommended Win Probability:** {recommended_win_prob:.0f}%")

        st.markdown(
            '<p style="color:#6B8BAF;font-size:11px;margin-top:16px;margin-bottom:6px;">'
            'Discount Simulation Matrix</p>',
            unsafe_allow_html=True
        )
        st.dataframe(sdo_df, use_container_width=True, hide_index=True)

        st.session_state["smart_discount_results"] = {
            "customer":               sdo_customer,
            "segment":                sdo_segment,
            "sku":                    sdo_sku,
            "base_price":             sdo_base_price,
            "current_discount_pct":   sdo_current_discount,
            "current_price":          sdo_current_price,
            "current_profit":         sdo_current_profit,
            "current_win_probability":sdo_current_win_prob,
            "recommended_discount_pct": recommended_discount,
            "recommended_price":      recommended_price,
            "recommended_revenue":    recommended_revenue,
            "recommended_profit":     recommended_profit,
            "recommended_win_probability": recommended_win_prob,
            "profit_improvement":     profit_improvement,
            "profit_improvement_pct": profit_improvement_pct,
            "recommendation":         sdo_recommendation,
            "simulation_matrix":      sdo_df,
        }

        divider()

        section("📋", "Executive Summary")

        sdo_exec_df = pd.DataFrame([{
            "Customer":            sdo_customer,
            "Product":             sdo_sku,
            "Current Discount":    f"{sdo_current_discount:.1f}%",
            "Recommended Discount":f"{recommended_discount:.0f}%",
            "Current Profit":      f"₹{sdo_current_profit:,.2f}" if sdo_current_profit is not None else "N/A",
            "Optimized Profit":    f"₹{recommended_profit:,.2f}" if recommended_profit is not None else "N/A",
            "Profit Improvement":  f"₹{profit_improvement:,.2f}" if profit_improvement is not None else "N/A",
            "Win Probability":     f"{recommended_win_prob:.0f}%",
            "Recommendation":      sdo_recommendation,
        }])
        st.dataframe(sdo_exec_df, use_container_width=True, hide_index=True)
        divider()
        section("🏛️", "Governance")
        if st.button("🏛️ Submit for Approval", key="wf_submit_price", use_container_width=True):
            sd = st.session_state.get("smart_discount_results", {})
            st.session_state["workflow_prefill"] = {
                "REQUEST_TYPE": "DISCOUNT_EXCEPTION",
                "TITLE": f"Discount for {sd.get('customer')} / {sd.get('sku')}",
                "DESCRIPTION": sd.get("recommendation", "Price Engine recommendation"),
                "CUSTOMER_ID": sd.get("customer"), "SKU": sd.get("sku"),
                "ORIGINAL_VALUE": sd.get("current_price"), "PROPOSED_VALUE": sd.get("recommended_price"),
                "DISCOUNT_PERCENT": sd.get("recommended_discount_pct"),
                "REFERENCE_ID": "PRICE_ENGINE", "metadata": {"source": "price_engine"}}
            st.success("Prefilled. Open **🏛️ Workflow & Approvals → ➕ Submit Request** to review & submit.")



    # ════════════════════════════════════════════════════════════════════════
    # END SMART DISCOUNT OPTIMIZER SECTION
    # ════════════════════════════════════════════════════════════════════════

    divider()

    # ── Run Price Optimization ──
    if st.button("🚀 Run Price Optimization", key="opt_btn", use_container_width=True):
        if sku_df.empty:
            st.error("No product data available.")
        else:
            cost = float(sku_df[sku_df["SKU"] == selected_sku_pe]["TOTAL_COST"].iloc[0])
            if cost <= 0:
                st.error("Invalid cost value.")
            else:
                results = []
                for margin in range(20, 55, 5):
                    target_price    = cost * (1 + margin / 100)
                    demand_factor   = 1 - ((margin - 20) * 0.02)
                    expected_demand = max(int(base_demand_pe * demand_factor), 1)
                    revenue = target_price * expected_demand
                    profit  = (target_price - cost) * expected_demand
                    results.append({
                        "MARGIN_%":        margin,
                        "TARGET_PRICE":    round(target_price, 2),
                        "EXPECTED_DEMAND": expected_demand,
                        "REVENUE":         round(revenue, 2),
                        "PROFIT":          round(profit, 2)
                    })
                opt_df = pd.DataFrame(results)
                best   = opt_df.loc[opt_df["PROFIT"].idxmax()]
                st.session_state["opt_results"] = opt_df
                st.session_state["opt_sku"]     = selected_sku_pe
                st.session_state["opt_cost"]    = cost
                st.session_state["opt_best"]    = best

                try:
                    save_df = opt_df.copy()
                    save_df.insert(0, "SKU",  selected_sku_pe)
                    save_df.insert(1, "COST", cost)
                    save_df["CREATED_AT"] = pd.Timestamp.utcnow()
                    snow_df = session.create_dataframe(save_df)
                    snow_df.write.mode("append").save_as_table(
                        "PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZATION_RESULTS"
                    )
                    st.success("✅ Results saved to Snowflake")
                except Exception as e:
                    st.warning(f"Save skipped: {e}")

    # Render persisted optimization results
    if st.session_state["opt_results"] is not None:
        opt_df = st.session_state["opt_results"]
        best   = st.session_state["opt_best"]

        st.success("✅ Optimization Complete")
        section("🏆", "Recommended Price Point")
        r1,r2,r3,r4 = st.columns(4)
        r1.metric("Best Margin",       f"{best['MARGIN_%']}%")
        r2.metric("Recommended Price", f"₹{best['TARGET_PRICE']:,.2f}")
        r3.metric("Expected Demand",   f"{int(best['EXPECTED_DEMAND'])} units")
        r4.metric("Expected Profit",   f"₹{best['PROFIT']:,.2f}")

        psi_note = ""
        if st.session_state["psi_results"] is not None:
            pr = st.session_state["psi_results"]
            psi_note = (
                f"\n\n**PSI Context:** Customer **{pr['customer']}** has PSI "
                f"`{pr['psi']:.2f}` → recommended margin **{pr['margin_pct']:.0f}%** "
                f"({pr['margin_label']}). "
                f"PSI-optimized final price = **₹{pr['final_price']:,.2f}**."
            )

        st.info(f"""
**Recommended Margin:** {best['MARGIN_%']}% · **Price:** ₹{best['TARGET_PRICE']:,.2f} · **Demand:** {int(best['EXPECTED_DEMAND'])} units

Elasticity model: each 5% margin increase reduces demand by ~2%. This price maximises profit after demand dilution.{psi_note}
""")
        divider()

        col_p, col_d = st.columns(2)
        with col_p:
            section("📊", "Profit by Margin %")
            st.bar_chart(opt_df.set_index("MARGIN_%")[["PROFIT"]], height=220)
        with col_d:
            section("📉", "Demand vs Margin %")
            st.line_chart(opt_df.set_index("MARGIN_%")[["EXPECTED_DEMAND"]], height=220)

        section("📋", "Full Optimization Results")
        st.dataframe(opt_df, use_container_width=True, hide_index=True)

# ════════════════════════════════════════════
# TAB 3 — SIMULATION HUB  (unchanged — deterministic simulation math only)
# ════════════════════════════════════════════

if _active_tab == "⚙️ Simulation Hub":
    section("⚙️", "Simulation Control Center")
    st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Run custom cost-price scenarios and track simulation history.</p>', unsafe_allow_html=True)

    try:
        sku_cost_df = session.sql("""
            SELECT DISTINCT SKU, TOTAL_COST
            FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
        """).to_pandas()
    except Exception:
        sku_cost_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

    with st.container():
        st.markdown("""
        <div style="background:#0D1829;border:1px solid #1B3050;border-radius:14px;padding:22px 24px;margin-bottom:20px;">
            <div style="color:#C8D8E8;font-size:14px;font-weight:600;margin-bottom:16px;">📝 Create New Scenario</div>
        """, unsafe_allow_html=True)

        col1, col2 = st.columns(2)
        with col1:
            scenario_name  = st.text_input("Scenario Name", "Custom Scenario", key="sim_name")
            selected_sku_s = st.selectbox("Select Product", sku_cost_df["SKU"].tolist(), key="sim_sku")
        with col2:
            target_margin     = st.slider("Target Margin %",    0, 100, 35, key="sim_margin")
            customer_discount = st.slider("Customer Discount %", 0, 50,  10, key="sim_disc")

        steel_surcharge = st.slider("Steel Surcharge %", 0, 50, 5, key="sim_steel")
        fuel_surcharge  = st.slider("Fuel Surcharge %",  0, 20, 2, key="sim_fuel")

        st.markdown("</div>", unsafe_allow_html=True)

    if st.button("🚀 Run Simulation", key="sim_run", use_container_width=True):
        if not sku_cost_df.empty and selected_sku_s in sku_cost_df["SKU"].values:
            cost = float(sku_cost_df[sku_cost_df["SKU"] == selected_sku_s]["TOTAL_COST"].iloc[0])

            adjusted_cost  = cost * (1 + steel_surcharge/100 + fuel_surcharge/100)
            target_price   = adjusted_cost * (1 + target_margin/100)
            customer_price = target_price  * (1 - customer_discount/100)
            profit         = customer_price - cost

            st.session_state["sim_results"] = {
                "cost": cost, "adjusted_cost": adjusted_cost,
                "target_price": target_price, "customer_price": customer_price,
                "profit": profit, "scenario_name": scenario_name, "sku": selected_sku_s,
                "target_margin": target_margin, "customer_discount": customer_discount,
                "steel_surcharge": steel_surcharge, "fuel_surcharge": fuel_surcharge
            }

            try:
                session.sql(f"""
                    INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
                    VALUES (
                        '{scenario_name}', '{selected_sku_s}',
                        {cost}, {target_margin}, {customer_discount},
                        {steel_surcharge}, {fuel_surcharge},
                        {target_price}, {customer_price}, CURRENT_TIMESTAMP()
                    )
                """).collect()
            except Exception as e:
                st.warning(f"Save skipped: {e}")

    if st.session_state["sim_results"] is not None:
        r = st.session_state["sim_results"]
        st.success("✅ Simulation Completed")
        s1,s2,s3,s4,s5 = st.columns(5)
        s1.metric("Base Cost",      f"₹{r['cost']:,.2f}")
        s2.metric("Adjusted Cost",  f"₹{r['adjusted_cost']:,.2f}")
        s3.metric("Target Price",   f"₹{r['target_price']:,.2f}")
        s4.metric("Customer Price", f"₹{r['customer_price']:,.2f}")
        s5.metric("Gross Profit",   f"₹{r['profit']:,.2f}")

    divider()

    section("📊", "Compare Pre-Defined Scenarios")

    try:
        scenario_df = session.sql("""
            SELECT DISTINCT SCENARIO_ID, SCENARIO_NAME
            FROM PRICING_ENGINE_DB.CORE_INTERNAL.SIMULATION_SCENARIOS
            ORDER BY SCENARIO_NAME
        """).to_pandas()

        col_a, col_b = st.columns(2)
        with col_a:
            sel_sku_sc = st.selectbox("Product", sku_cost_df["SKU"].tolist(), key="sc_sku")
        with col_b:
            sel_sc = st.selectbox("Scenario", scenario_df["SCENARIO_ID"].tolist(), key="sc_id")

        if st.button("▶️ Run Pre-Defined Scenario", key="sc_btn"):
            sc_result = session.sql(f"""
                SELECT SKU, SCENARIO_ID, SCENARIO_NAME, TOTAL_COST,
                       TARGET_MARGIN_PCT, CUSTOMER_DISCOUNT_PCT,
                       SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
                FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING
                WHERE SKU = '{sel_sku_sc}' AND SCENARIO_ID = '{sel_sc}'
            """).to_pandas()
            st.session_state["sc_result"] = sc_result

        if st.session_state["sc_result"] is not None:
            sc_result = st.session_state["sc_result"]
            if not sc_result.empty:
                row = sc_result.iloc[0]
                st.success("✅ Scenario loaded")
                m1,m2,m3,m4 = st.columns(4)
                m1.metric("Cost",           f"₹{row['TOTAL_COST']:,.2f}")
                m2.metric("Target Price",   f"₹{row['SIMULATED_TARGET_PRICE']:,.2f}")
                m3.metric("Customer Price", f"₹{row['SIMULATED_CUSTOMER_PRICE']:,.2f}")
                m4.metric("Margin %",       f"{row['TARGET_MARGIN_PCT']}%")
                st.dataframe(sc_result, use_container_width=True, hide_index=True)

    except Exception as e:
        st.info(f"Pre-defined scenarios not available: {e}")

    divider()

    try:
        comparison_df = session.sql("""
            SELECT SCENARIO_NAME, SIMULATED_TARGET_PRICE, SIMULATED_CUSTOMER_PRICE
            FROM PRICING_ENGINE_DB.CORE_OUTPUT.SIMULATED_PRICING
            ORDER BY SCENARIO_NAME
        """).to_pandas()

        if not comparison_df.empty:
            section("📉", "Scenario Comparison")
            col_l, col_r = st.columns(2)
            with col_l:
                st.markdown('<p style="color:#6B8BAF;font-size:12px;">Target Price by Scenario</p>', unsafe_allow_html=True)
                st.bar_chart(comparison_df.set_index("SCENARIO_NAME")[["SIMULATED_TARGET_PRICE"]], height=200)
            with col_r:
                st.markdown('<p style="color:#6B8BAF;font-size:12px;">Customer Price by Scenario</p>', unsafe_allow_html=True)
                st.bar_chart(comparison_df.set_index("SCENARIO_NAME")[["SIMULATED_CUSTOMER_PRICE"]], height=200)
    except Exception:
        pass

    divider()
    section("📜", "Simulation History")

    try:
        hist = session.sql("""
            SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.USER_SIMULATION_RESULTS
            ORDER BY CREATED_AT DESC
        """).to_pandas()
        st.dataframe(hist, use_container_width=True, hide_index=True)
    except Exception:
        st.info("No simulation history yet.")


# ════════════════════════════════════════════
# TAB 4 — DIGITAL TWIN  — Margin Leakage AI integration
# ════════════════════════════════════════════

if _active_tab == "🌍 Digital Twin":
    section("🌍", "Pricing Digital Twin")
    st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Model future market shocks before they hit your bottom line.</p>', unsafe_allow_html=True)

    try:
        sku_dt_df = session.sql("""
            SELECT SKU, TOTAL_COST
            FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS
            ORDER BY SKU
        """).to_pandas()
    except Exception:
        sku_dt_df = pd.DataFrame(columns=["SKU","TOTAL_COST"])

    col1, col2 = st.columns(2)
    with col1:
        sel_sku_dt  = st.selectbox("Product", sku_dt_df["SKU"].tolist(), key="dt_sku")
        scenario_dt = st.text_input("Scenario Name", "Market Shock Scenario", key="dt_name")
    with col2:
        base_demand_dt = st.number_input("Current Monthly Demand (units)", value=2000, min_value=1, step=100, key="dt_demand")

    divider()
    section("🌡️", "Future Market Conditions")

    col_s1, col_s2, col_s3 = st.columns(3)
    with col_s1:
        steel_change  = st.slider("Steel Cost Change %",      -20, 50, 10,  key="dt_steel")
    with col_s2:
        fuel_change   = st.slider("Fuel / Logistics Change %", -20, 50, 5,   key="dt_fuel")
    with col_s3:
        demand_change = st.slider("Market Demand Change %",   -50, 50, -15, key="dt_demand_ch")

    if st.button("▶️ Run Digital Twin", key="dt_run", use_container_width=True):
        if not sku_dt_df.empty and sel_sku_dt in sku_dt_df["SKU"].values:
            cost = float(sku_dt_df[sku_dt_df["SKU"] == sel_sku_dt]["TOTAL_COST"].iloc[0])
            if cost <= 0:
                st.error("Invalid cost.")
            else:
                BASE_MARGIN  = 1.35
                base_price   = cost * BASE_MARGIN
                base_revenue = base_price * base_demand_dt
                base_profit  = (base_price - cost) * base_demand_dt

                new_cost    = cost * (1 + steel_change/100) * (1 + fuel_change/100)
                new_price   = new_cost * BASE_MARGIN
                new_demand  = max(int(base_demand_dt * (1 + demand_change/100)), 1)
                new_revenue = new_price * new_demand
                new_profit  = (new_price - new_cost) * new_demand

                st.session_state["dt_results"] = {
                    "cost": cost, "new_cost": new_cost,
                    "base_price": base_price, "new_price": new_price,
                    "base_demand": base_demand_dt, "new_demand": new_demand,
                    "base_revenue": base_revenue, "new_revenue": new_revenue,
                    "base_profit": base_profit, "new_profit": new_profit,
                    "sku": sel_sku_dt, "scenario": scenario_dt
                }

                try:
                    session.sql(f"""
                        INSERT INTO PRICING_ENGINE_DB.CORE_OUTPUT.DIGITAL_TWIN_RESULTS
                        VALUES (
                            '{scenario_dt}', '{sel_sku_dt}',
                            {cost}, {new_cost},
                            {base_price}, {new_price},
                            {base_demand_dt}, {new_demand},
                            {base_revenue}, {new_revenue},
                            {base_profit}, {new_profit},
                            CURRENT_TIMESTAMP()
                        )
                    """).collect()
                    st.success("✅ Scenario saved to Snowflake")
                except Exception as e:
                    st.warning(f"Save skipped: {e}")

    if st.session_state["dt_results"] is not None:
        d = st.session_state["dt_results"]
        cost         = d["cost"];        new_cost     = d["new_cost"]
        base_price   = d["base_price"];  new_price    = d["new_price"]
        base_demand  = d["base_demand"]; new_demand   = d["new_demand"]
        base_revenue = d["base_revenue"];new_revenue  = d["new_revenue"]
        base_profit  = d["base_profit"]; new_profit   = d["new_profit"]

        st.success("✅ Digital Twin Simulation Complete")

        section("📊", "Current vs Future State")
        c1,c2,c3,c4 = st.columns(4)
        c1.metric("Cost",           f"₹{cost:,.2f}",         f"₹{new_cost - cost:+,.2f}",            delta_color="inverse")
        c2.metric("Selling Price",  f"₹{base_price:,.2f}",   f"₹{new_price - base_price:+,.2f}")
        c3.metric("Revenue Impact", f"₹{base_revenue:,.2f}", f"₹{new_revenue - base_revenue:+,.2f}")
        c4.metric("Profit Impact",  f"₹{base_profit:,.2f}",  f"₹{new_profit - base_profit:+,.2f}")

        comparison = pd.DataFrame({
            "Metric":  ["Cost","Selling Price","Demand","Revenue","Profit"],
            "Current": [cost, base_price, base_demand, base_revenue, base_profit],
            "Future":  [new_cost, new_price, new_demand, new_revenue, new_profit],
        })
        comparison["Δ Change"]   = comparison["Future"] - comparison["Current"]
        comparison["Δ Change %"] = ((comparison["Δ Change"] / comparison["Current"]) * 100).round(2)
        st.dataframe(comparison, use_container_width=True, hide_index=True)

        divider()
        section("🚨", "Future Margin Leakage Analysis")

        future_margin = ((new_price - new_cost) / new_price) * 100 if new_price > 0 else 0

        # ── Margin Leakage — v2: FULLY AI-DRIVEN (no future_margin*4 score
        # formula, no 5/10/15% thresholds). One ai_reason_score call returns
        # the health score, status label, causes, business impact, and
        # corrective actions together.
        leakage_context = (
            f"Product {d['sku']}, scenario '{d['scenario']}'.\n"
            f"Cost rises from ₹{cost:,.2f} to ₹{new_cost:,.2f} (steel {steel_change:+d}%, fuel {fuel_change:+d}%).\n"
            f"Demand moves from {base_demand} to {new_demand} units ({demand_change:+d}%).\n"
            f"Margin falls from {((base_price-cost)/base_price*100 if base_price else 0):.1f}% to {future_margin:.1f}%.\n"
            f"Profit impact ₹{abs(new_profit-base_profit):,.0f}."
        )
        leakage_payload = ai_reason_score(
            module="digital_twin", decision_type="margin_leakage",
            context_facts=leakage_context,
            extra_instruction=(
                "Identify the most likely causes of this margin leakage, the business impact, "
                "and corrective actions. The 'score' field should represent overall margin "
                "health under this future scenario (higher = healthier)."
            ),
            cache_key=_ai_cache_key("leakage_v2", d["sku"], d["scenario"], round(future_margin, 1)),
        )

        if leakage_payload.get("ai_generated"):
            health_score = int(round(leakage_payload["score"]))
            leakage_status = leakage_payload["label"]
            leakage_color = "#00C7B2" if health_score >= 65 else "#F59E0B" if health_score >= 35 else "#EF4444"
        else:
            health_score, leakage_status, leakage_color = 0, "AI Unavailable", "#6B8BAF"

        m1,m2,m3,m4 = st.columns(4)
        m1.metric("Future Margin %", f"{future_margin:.2f}%")
        m2.metric("Health Score",    f"{health_score}/100")
        m3.metric("Leakage Status",  leakage_status)
        m4.metric("Profit At Risk",  f"₹{abs(new_profit-base_profit):,.0f}")

        st.markdown(health_bar_html(health_score, leakage_color, leakage_status), unsafe_allow_html=True)

        divider()
        section("🔍", "Leakage Findings (Cortex AI)")
        if leakage_payload.get("ai_generated"):
            st.write(leakage_payload["reasoning"])
            st.write(f"• Profit impact = ₹{abs(new_profit-base_profit):,.0f}")
            st.write(f"• Demand changes from {base_demand} to {new_demand}")
        else:
            st.info("Cortex AI margin-leakage service unavailable — no findings generated.")

        section("💡", "Executive Recommendation (Cortex AI)")
        render_ai_score_card(leakage_payload, title_prefix="Margin Leakage")
        divider()
        section("🏛️", "Governance")
        if st.button("🏛️ Submit Scenario for Approval", key="wf_submit_dt", use_container_width=True):
            st.session_state["workflow_prefill"] = {
                "REQUEST_TYPE": "SIMULATION_RECOMMENDATION",
                "TITLE": f"Scenario '{d['scenario']}' — {d['sku']}",
                "DESCRIPTION": leakage_payload.get("reasoning", "Digital Twin scenario"),
                "SKU": d["sku"],
                "ORIGINAL_VALUE": d["base_price"], "PROPOSED_VALUE": d["new_price"],
                "FINANCIAL_IMPACT": d["new_profit"] - d["base_profit"],
                "MARGIN_PERCENT": future_margin,
                "REFERENCE_ID": "DIGITAL_TWIN", "metadata": {"source": "digital_twin"}}
            st.success("Prefilled. Open **🏛️ Workflow & Approvals → ➕ Submit Request** to review & submit.")


# ════════════════════════════════════════════
# TAB 5 — AI ADVISOR  — fully AI-driven recommendations
# ════════════════════════════════════════════

if _active_tab == "🧠 AI Advisor":
    section("🧠", "AI Pricing Strategy Advisor")
    st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Cortex AI-generated strategic analysis from the latest Digital Twin simulation.</p>', unsafe_allow_html=True)

    try:
        dt_df = session.sql("""
            SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.DIGITAL_TWIN_RESULTS
            ORDER BY CREATED_AT DESC LIMIT 1
        """).to_pandas()
    except Exception as e:
        st.error(f"Could not load simulation data: {e}")
        dt_df = pd.DataFrame()

    if dt_df.empty:
        st.warning("⚠️ No Digital Twin data found. Run a simulation in the **Digital Twin** tab first.")
    else:
        row = dt_df.iloc[0]

        base_profit  = float(row["BASE_PROFIT"])
        new_profit   = float(row["NEW_PROFIT"])
        base_revenue = float(row["BASE_REVENUE"])
        new_revenue  = float(row["NEW_REVENUE"])

        profit_change  = safe_pct_change(new_profit,  base_profit)
        revenue_change = safe_pct_change(new_revenue, base_revenue)

        sku_label      = row.get("SKU",           "N/A")
        scenario_label = row.get("SCENARIO_NAME", "Latest Simulation")

        c1,c2,c3,c4 = st.columns(4)
        c1.metric("Scenario",         scenario_label)
        c2.metric("Product SKU",      sku_label)
        c3.metric("Profit Change %",  f"{profit_change:+.2f}%")
        c4.metric("Revenue Change %", f"{revenue_change:+.2f}%")

        divider()

        # ── Advisor Score — v2: FULLY AI-DRIVEN (no +25/+10/-15/-25 point
        # formula). Cortex AI reasons over the profit/revenue change
        # together and returns its own risk score and status.
        advisor_payload = ai_reason_score(
            module="advisor", decision_type="scenario_health",
            context_facts=(
                f"Scenario: {scenario_label}\nProduct SKU: {sku_label}\n"
                f"Profit change: {profit_change:+.1f}%\nRevenue change: {revenue_change:+.1f}%"
            ),
            extra_instruction=(
                "Assess overall pricing health/risk for this scenario. The 'score' field "
                "should represent overall health (higher = healthier)."
            ),
            cache_key=_ai_cache_key("advisor_v2", scenario_label, sku_label, round(profit_change, 1), round(revenue_change, 1)),
        )

        if advisor_payload.get("ai_generated"):
            score = advisor_payload["score"]
            status = advisor_payload["label"]
        else:
            score, status = 0, "AI Unavailable"

        bar_color = "#00C7B2" if score >= 65 else "#F59E0B" if score >= 35 else "#EF4444"
        status_emoji = "🟢" if score >= 65 else "🟡" if score >= 35 else "🔴"
        status_display = f"{status_emoji} {status}"

        section("📈", "Pricing Health Score")
        st.markdown(health_bar_html(score, bar_color, status_display), unsafe_allow_html=True)

        if score >= 65:   st.success(f"Current Status: {status_display}")
        elif score >= 35: st.warning(f"Current Status: {status_display}")
        else:             st.error(f"Current Status: {status_display}")

        divider()

        col_left, col_right = st.columns(2)

        with col_left:
            section("🔍", "Key Findings")
            st.write(f"• Profit {'increased' if profit_change >= 0 else 'decreased'} by {abs(profit_change):.1f}%")
            st.write(f"• Revenue {'increased' if revenue_change >= 0 else 'decreased'} by {abs(revenue_change):.1f}%")

        with col_right:
            section("✅", "Recommended Actions (Cortex AI)")
            # AI_COMPLETE replaces the fixed recs[] if/elif lists entirely.
            recs_prompt = (
                f"Scenario '{scenario_label}' for product {sku_label}: profit change "
                f"{profit_change:+.1f}%, revenue change {revenue_change:+.1f}%, pricing "
                f"health status '{status}'. Suggest up to 4 short, specific pricing "
                f"recommendations for a manufacturing pricing manager (each under 15 words). "
                f"Return ONLY a JSON array of strings (no markdown)."
            )
            ai_recs = parse_ai_json(ai_complete(recs_prompt, cache_key=_ai_cache_key("advisor_recs", scenario_label, sku_label, round(score))))

            if ai_recs and isinstance(ai_recs, list) and all(isinstance(x, str) for x in ai_recs):
                recs = ai_recs
            else:
                if profit_change < -10:
                    recs = [
                        "Increase selling price by 5–8% to recover margin",
                        "Reduce or eliminate customer discounts temporarily",
                        "Audit and negotiate raw material costs",
                        "Identify cost reduction opportunities in logistics"
                    ]
                elif profit_change < 0:
                    recs = [
                        "Monitor pricing performance weekly",
                        "Evaluate cost structure for efficiency gains",
                        "Consider small price adjustments (2–3%) to offset cost rise"
                    ]
                else:
                    recs = [
                        "Maintain current pricing strategy — performing well",
                        "Explore opportunity to expand sales volume",
                        "Consider reinvesting margin gains into customer acquisition"
                    ]

            for i, rec in enumerate(recs, 1):
                st.success(f"{i}. {rec}")

        divider()
        section("📋", "Executive Summary (Cortex AI)")

        summary_facts = (
            f"Scenario: {scenario_label}\nProduct SKU: {sku_label}\n"
            f"Revenue change: {revenue_change:+.1f}%\nProfit change: {profit_change:+.1f}%\n"
            f"Pricing Health Score: {score}/100 ({status})\nTop recommendation: {recs[0]}"
        )
        ai_summary_text = ai_summarize(summary_facts, cache_key=_ai_cache_key("advisor_summary", summary_facts))

        summary = ai_or_fallback(
            ai_summary_text,
            f"""Scenario: {scenario_label}
Product SKU: {sku_label}

The latest Digital Twin simulation shows:
  • Revenue change:  {revenue_change:+.1f}%
  • Profit change:   {profit_change:+.1f}%

Pricing Health Score: {score} / 100  —  {status_display}

Primary Recommended Action:
→ {recs[0]}""".strip()
        )

        st.text_area(label="", value=summary, height=220)


# ════════════════════════════════════════════
# TAB 6 — CONTRACT ANALYZER  — AI_CLASSIFY risk + AI_COMPLETE explanations
# ════════════════════════════════════════════

if _active_tab == "📄 Contract Analyzer":
    section("📄", "Contract Impact Analyzer")
    st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Analyze contract profitability under future cost increases, with Cortex AI risk classification.</p>', unsafe_allow_html=True)

    try:
        contract_df = session.sql("""
            SELECT CUSTOMER_ID, SKU, TOTAL_COST, DISCOUNTED_PRICE
            FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING
        """).to_pandas()
    except Exception as e:
        st.error(f"Could not load contract data: {e}")
        contract_df = pd.DataFrame(columns=["CUSTOMER_ID","SKU","TOTAL_COST","DISCOUNTED_PRICE"])

    col1, col2 = st.columns(2)
    with col1:
        selected_customer = st.selectbox("Customer", sorted(contract_df["CUSTOMER_ID"].unique()) if not contract_df.empty else [], key="ca_cust")
    with col2:
        selected_sku_ca   = st.selectbox("Product SKU", sorted(contract_df["SKU"].unique()) if not contract_df.empty else [], key="ca_sku")

    steel_change_ca = st.slider("Steel Cost Increase %", -20, 50, 10, key="ca_steel")
    fuel_change_ca  = st.slider("Fuel Cost Increase %",  -20, 50,  5, key="ca_fuel")

    if st.button("🔍 Analyze Contract", key="ca_btn", use_container_width=True):
        try:
            row_ca = contract_df[
                (contract_df["CUSTOMER_ID"] == selected_customer) &
                (contract_df["SKU"] == selected_sku_ca)
            ].iloc[0]

            cost_ca         = float(row_ca["TOTAL_COST"])
            selling_price   = float(row_ca["DISCOUNTED_PRICE"])
            current_margin  = ((selling_price - cost_ca) / selling_price) * 100 if selling_price > 0 else 0
            future_cost_ca  = cost_ca * (1 + steel_change_ca/100) * (1 + fuel_change_ca/100)
            future_margin   = ((selling_price - future_cost_ca) / selling_price) * 100 if selling_price > 0 else 0
            margin_loss     = current_margin - future_margin

            st.session_state["contract_results"] = {
                "current_margin": current_margin, "future_margin": future_margin,
                "margin_loss": margin_loss, "customer": selected_customer,
                "sku": selected_sku_ca, "cost": cost_ca,
                "selling_price": selling_price, "future_cost": future_cost_ca
            }
        except (IndexError, KeyError):
            st.error("No pricing data found for this Customer + SKU combination.")

    if st.session_state["contract_results"] is not None:
        cr = st.session_state["contract_results"]
        current_margin = cr["current_margin"]
        future_margin  = cr["future_margin"]
        margin_loss    = cr["margin_loss"]

        # ── Contract Risk — v2: FULLY AI-DRIVEN (no future_margin*4 formula,
        # no fixed 20%/10% thresholds). AI determines contract quality,
        # profitability, legal/renegotiation risk, and pricing flexibility.
        contract_payload = ai_reason_score(
            module="contract", decision_type="contract_risk",
            context_facts=(
                f"Customer: {cr['customer']}\nSKU: {cr['sku']}\n"
                f"Current margin: {current_margin:.1f}%\nProjected future margin: {future_margin:.1f}%\n"
                f"Margin loss: {margin_loss:.1f} points (driven by rising raw material costs)"
            ),
            extra_instruction=(
                "Determine contract quality, profitability trajectory, renegotiation risk, "
                "and pricing flexibility. The 'score' field should represent overall contract "
                "health (higher = healthier, lower = riskier)."
            ),
            cache_key=_ai_cache_key("contract_v2", cr["customer"], cr["sku"], round(future_margin, 1)),
        )

        if contract_payload.get("ai_generated"):
            score_ca = int(round(contract_payload["score"]))
            risk = contract_payload["label"]
            color_ca = "#00C7B2" if score_ca >= 65 else "#F59E0B" if score_ca >= 35 else "#EF4444"
        else:
            score_ca, risk, color_ca = 0, "AI Unavailable", "#6B8BAF"

        divider()
        c1,c2,c3,c4 = st.columns(4)
        c1.metric("Current Margin", f"{current_margin:.1f}%")
        c2.metric("Future Margin",  f"{future_margin:.1f}%")
        c3.metric("Margin Loss",    f"{margin_loss:.1f}%")
        c4.metric("Contract Risk",  risk)

        divider()
        st.markdown(health_bar_html(score_ca, color_ca, risk), unsafe_allow_html=True)
        if contract_payload.get("ai_generated"):
            st.caption(f"💡 {contract_payload['reasoning']}  (confidence {contract_payload['confidence']:.0f}%)")

        divider()
        left, right = st.columns(2)

        with left:
            section("🔍", "Key Findings")
            st.write(f"• Current margin is {current_margin:.1f}%")
            st.write(f"• Future margin drops to {future_margin:.1f}%")
            st.write(f"• Margin loss is {margin_loss:.1f}%")

        with right:
            section("✅", "Recommended Actions (Cortex AI)")
            # AI_COMPLETE explains the identified risk and recommends actions
            # (replaces the fixed recs_ca[] if/elif lists).
            ca_prompt = (
                f"Contract for customer {cr['customer']}, product {cr['sku']}. Current margin "
                f"{current_margin:.1f}%, projected future margin {future_margin:.1f}% "
                f"({risk}), a loss of {margin_loss:.1f} points due to rising raw material "
                f"costs. Suggest up to 4 short, specific contract actions for a deal desk "
                f"manager (each under 15 words). Return ONLY a JSON array of strings (no markdown)."
            )
            ai_recs_ca = parse_ai_json(ai_complete(ca_prompt, cache_key=_ai_cache_key("contract_recs", cr["customer"], cr["sku"], round(future_margin, 1))))

            if ai_recs_ca and isinstance(ai_recs_ca, list) and all(isinstance(x, str) for x in ai_recs_ca):
                recs_ca = ai_recs_ca
            else:
                if future_margin < 10:
                    recs_ca = ["Renegotiate contract pricing", "Reduce customer discount",
                               "Review raw material costs", "Protect profitability immediately"]
                elif future_margin < 20:
                    recs_ca = ["Monitor contract performance", "Review contract periodically",
                               "Track future cost changes"]
                else:
                    recs_ca = ["Contract remains healthy", "No pricing action required", "Continue monitoring"]

            for i, rec in enumerate(recs_ca, 1):
                st.success(f"{i}. {rec}")

        divider()
        section("📋", "Executive Summary")

        summary_ca = f"""Customer: {cr['customer']}
SKU: {cr['sku']}

Current Margin:  {current_margin:.1f}%
Future Margin:   {future_margin:.1f}%
Margin Loss:     {margin_loss:.1f}%
Risk Level:      {risk}

Recommended Action:
{recs_ca[0]}"""

        st.text_area("", summary_ca, height=220, key="ca_summary")
        divider()
        section("🏛️", "Governance")
        if st.button("🏛️ Submit Contract for Approval", key="wf_submit_contract", use_container_width=True):
            st.session_state["workflow_prefill"] = {
                "REQUEST_TYPE": "CONTRACT_APPROVAL",
                "TITLE": f"Contract review — {cr['customer']} / {cr['sku']}",
                "DESCRIPTION": f"Current margin {cr['current_margin']:.1f}% → future {cr['future_margin']:.1f}% ({risk}).",
                "CUSTOMER_ID": cr["customer"], "SKU": cr["sku"],
                "ORIGINAL_VALUE": cr["selling_price"], "PROPOSED_VALUE": cr["selling_price"],
                "MARGIN_PERCENT": cr["future_margin"],
                "REFERENCE_ID": "CONTRACT_ANALYZER", "metadata": {"source": "contract_analyzer"}}
            st.success("Prefilled. Open **🏛️ Workflow & Approvals → ➕ Submit Request** to review & submit.")

# ════════════════════════════════════════════
# TAB 7 — COMPETITOR PRICING  — AI-integrated
# ════════════════════════════════════════════

if _active_tab == "🏆 Competitor Pricing":

    # ── Helper: safe percentage change ──────────────────────────────────────
    def safe_pct(a, b):
        return 0.0 if b == 0 else ((a - b) / b) * 100

    # ── Helper: deterministic position label + color (fallback only) ───────
    def get_position_fallback(gap):
        if gap > 10:
            return "🔴 Expensive", "#EF4444"
        elif gap > 3:
            return "🟡 Premium", "#F59E0B"
        elif gap > -3:
            return "🟢 Competitive", "#00C7B2"
        else:
            return "🔵 Discount", "#3B82F6"

    def get_position(gap):
        """AI_CLASSIFY-driven market position label (replaces the fixed
        if/elif gap-threshold logic). Falls back to the deterministic
        version above if Cortex is unavailable."""
        ai_label = ai_classify(
            f"Our product is priced {gap:+.1f}% versus the competitor market average.",
            ["Expensive", "Premium", "Competitive", "Discount"],
            cache_key=_ai_cache_key("mkt_position", round(gap, 1))
        )
        color_map = {"Expensive": "#EF4444", "Premium": "#F59E0B", "Competitive": "#00C7B2", "Discount": "#3B82F6"}
        icon_map  = {"Expensive": "🔴", "Premium": "🟡", "Competitive": "🟢", "Discount": "🔵"}
        if ai_label and ai_label in color_map:
            return f"{icon_map[ai_label]} {ai_label}", color_map[ai_label]
        return get_position_fallback(gap)

    # ── Helper: health score (deterministic — real formula, unchanged) ─────
    def health_score(gap):
        return max(0, min(100, int(100 - abs(gap * 5))))

    # ── Helper: health bar HTML ─────────────────────────────────────────────
    def health_bar(score, color, label):
        return f"""
        <div style="background:rgba(255,255,255,0.05);border-radius:8px;
                    height:28px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);
                    position:relative;margin:6px 0 12px;">
          <div style="width:{score}%;height:100%;background:{color};border-radius:8px;
                      transition:width .5s ease;"></div>
          <div style="position:absolute;right:12px;top:50%;transform:translateY(-50%);
                      font-size:12px;font-weight:600;color:#E2E8F0;">
            {label} &nbsp;{score}/100
          </div>
        </div>"""

    # ── Helper: chip HTML ───────────────────────────────────────────────────
    def alert_chip(text):
        return (f'<div style="padding:6px 10px;border-radius:6px;font-size:12px;'
                f'background:rgba(239,68,68,0.12);border:1px solid rgba(239,68,68,0.3);'
                f'color:#FCA5A5;margin-bottom:6px;">'
                f'⚠️ {text}</div>')

    def opp_chip(text):
        return (f'<div style="padding:6px 10px;border-radius:6px;font-size:12px;'
                f'background:rgba(0,199,178,0.12);border:1px solid rgba(0,199,178,0.3);'
                f'color:#5EEAD4;margin-bottom:6px;">'
                f'💡 {text}</div>')

    section("🏆", "Competitor Pricing Intelligence")
    st.markdown(
        '<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">'
        'Real-time market positioning · price war simulation · historical trend analysis '
        '· Cortex AI-generated market commentary'
        '</p>',
        unsafe_allow_html=True
    )
    divider()

    try:
        pricing_df = session.sql("""
            SELECT SKU, PRODUCT_FAMILY, TARGET_PRICE
            FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX
            ORDER BY SKU
        """).to_pandas()
    except Exception as e:
        st.error(f"Could not load pricing data: {e}")
        pricing_df = pd.DataFrame(columns=["SKU", "PRODUCT_FAMILY", "TARGET_PRICE"])

    col_i1, col_i2 = st.columns([1.5, 1])
    with col_i1:
        selected_sku = st.selectbox(
            "Product SKU",
            sorted(pricing_df["SKU"].unique()) if not pricing_df.empty else [],
            key="comp_sku"
        )
    with col_i2:
        monthly_vol = st.number_input(
            "Monthly Sales Volume (units)",
            value=1000, min_value=1, step=100,
            key="comp_vol"
        )

    divider()
    section("🏢", "Competitor Prices")

    cc1, cc2, cc3, cc4 = st.columns(4)
    with cc1:
        name_a = st.text_input("Competitor A Name", "Competitor A", key="comp_a_name")
        price_a = st.number_input("Price (₹)", value=1300, min_value=1, key="comp_a_price")
    with cc2:
        name_b = st.text_input("Competitor B Name", "Competitor B", key="comp_b_name")
        price_b = st.number_input("Price (₹)", value=1250, min_value=1, key="comp_b_price")
    with cc3:
        name_c = st.text_input("Competitor C Name", "Competitor C", key="comp_c_name")
        price_c = st.number_input("Price (₹)", value=1400, min_value=1, key="comp_c_price")
    with cc4:
        name_d = st.text_input("Competitor D Name", "Competitor D", key="comp_d_name")
        price_d = st.number_input("Price (₹)", value=1350, min_value=1, key="comp_d_price")

    divider()

    if st.button("⚡ Analyze Market Position", key="comp_analyze_btn", use_container_width=True):
        if pricing_df.empty:
            st.error("No pricing data available.")
        else:
            row = pricing_df[pricing_df["SKU"] == selected_sku].iloc[0]
            our_price = float(row["TARGET_PRICE"])

            comp_map = {name_a: price_a, name_b: price_b, name_c: price_c, name_d: price_d}
            comp_vals = list(comp_map.values())
            market_avg = sum(comp_vals) / len(comp_vals)
            market_min = min(comp_vals)
            market_max = max(comp_vals)
            price_gap  = safe_pct(our_price, market_avg)

            # v2: FULLY AI-DRIVEN competitive health score (no 100-abs(gap*5)
            # formula) for this button-triggered analysis. AI evaluates market
            # position, competitive strength, and pricing confidence rather
            # than a fixed function of the price gap alone. (The formula-based
            # health_score()/get_position() helpers above are retained ONLY
            # for the real-time Price War Simulator slider further down,
            # where a live Cortex call per drag-frame would be impractical.)
            comp_analysis_payload = ai_reason_score(
                module="competitor", decision_type="market_position",
                context_facts=(
                    f"SKU: {selected_sku}\nOur price: ₹{our_price:,.2f}\n"
                    f"Competitor prices: {', '.join(f'{n}=₹{v:,.0f}' for n, v in comp_map.items())}\n"
                    f"Market average: ₹{market_avg:,.2f} (our gap {price_gap:+.1f}%)\n"
                    f"Market range: ₹{market_min:,.0f} - ₹{market_max:,.0f}"
                ),
                extra_instruction=(
                    "Evaluate market position, competitive strength, pricing aggressiveness, "
                    "and pricing confidence. The 'score' field should represent overall "
                    "competitive health (higher = stronger position)."
                ),
                cache_key=_ai_cache_key("comp_v2", selected_sku, round(our_price, 2), round(market_avg, 2)),
            )
            if comp_analysis_payload.get("ai_generated"):
                score = int(round(comp_analysis_payload["score"]))
                position = comp_analysis_payload["label"]
                pos_color = "#00C7B2" if score >= 65 else "#F59E0B" if score >= 35 else "#EF4444"
            else:
                score, position, pos_color = 0, "AI Unavailable", "#6B8BAF"

            cheapest_name  = min(comp_map, key=comp_map.get)
            cheapest_price = comp_map[cheapest_name]
            prem_cheapest  = safe_pct(our_price, cheapest_price)

            all_sorted = sorted(comp_vals + [our_price])
            our_rank   = all_sorted.index(our_price) + 1
            total_p    = len(all_sorted)

            rev_our   = our_price * monthly_vol
            rev_avg   = market_avg * monthly_vol
            rev_delta = rev_our - rev_avg

            # ── AI_FILTER + AI_COMPLETE generate alerts/opportunities instead
            # of the fixed threshold-only checks. Raw candidate signals stay
            # deterministic; AI decides significance and writes the text.
            candidate_signals = []
            if price_gap > 10:
                candidate_signals.append(("alert", f"Price is {price_gap:.1f}% above market average — risk of losing deals."))
            if prem_cheapest > 15:
                candidate_signals.append(("alert", f"{prem_cheapest:.1f}% premium over cheapest competitor ({cheapest_name})."))
            if score < 60:
                candidate_signals.append(("alert", f"Competitive health score is {score}/100 — below the healthy range."))
            if our_price < market_min:
                candidate_signals.append(("alert", "Price is below all competitors — possible margin under-capture."))
            if our_price < market_avg:
                candidate_signals.append(("opportunity", f"₹{market_avg - our_price:,.0f} headroom to reach market average."))
            if our_price < market_max:
                candidate_signals.append(("opportunity", f"₹{market_max - our_price:,.0f} headroom vs the most expensive competitor."))

            alerts, opps = [], []
            for kind, raw in candidate_signals:
                sig = ai_filter(
                    f"Is this competitive pricing signal significant enough to surface to "
                    f"an executive? Signal: {raw}",
                    cache_key=_ai_cache_key("comp_sig_filter", kind, raw)
                )
                if sig is False:
                    continue
                text_out = ai_complete(
                    f"Rewrite this competitive pricing signal as one short executive-ready "
                    f"sentence (max 20 words): {raw}",
                    cache_key=_ai_cache_key("comp_sig_text", kind, raw)
                )
                final_text = text_out if text_out else raw
                (alerts if kind == "alert" else opps).append(final_text)
            if not opps:
                opps.append("Maintain current price — already at or above market average")
            if not alerts:
                pass  # handled below with a neutral message

            # AI-generated recommendations (replaces the fixed if/elif recs[])
            recs_prompt = (
                f"Our product {selected_sku} is priced ₹{our_price:,.0f}, {price_gap:+.1f}% vs a "
                f"market average of ₹{market_avg:,.0f} (rank #{our_rank} of {total_p}). "
                f"Suggest up to 4 short, specific competitive pricing recommendations for a "
                f"manufacturing pricing manager (each under 15 words). Return ONLY a JSON "
                f"array of strings (no markdown)."
            )
            ai_recs = parse_ai_json(ai_complete(recs_prompt, cache_key=_ai_cache_key("comp_recs", selected_sku, round(price_gap, 1))))
            if ai_recs and isinstance(ai_recs, list) and all(isinstance(x, str) for x in ai_recs):
                recs = ai_recs
            else:
                if price_gap > 10:
                    recs = ["Review selling price immediately","Risk of losing deals to competitors",
                            "Consider strategic discounting","Monitor competitors weekly"]
                elif price_gap > 3:
                    recs = ["Maintain premium positioning with value justification",
                            "Highlight product differentiation to customers",
                            "Monitor competitor price movements closely"]
                elif price_gap > -3:
                    recs = ["Maintain current pricing strategy — fully competitive",
                            "Explore small uplift to improve margin","Continue monitoring market"]
                else:
                    recs = ["Opportunity to increase price — below market",
                            "Potential to capture additional margin",
                            "Gradual price increase recommended"]

            st.session_state["comp_results"] = {
                "sku": selected_sku, "our_price": our_price,
                "market_avg": market_avg, "market_min": market_min, "market_max": market_max,
                "price_gap": price_gap, "score": score, "position": position,
                "pos_color": pos_color, "monthly_vol": monthly_vol,
                "rev_our": rev_our, "rev_delta": rev_delta,
                "our_rank": our_rank, "total_p": total_p,
                "alerts": alerts, "opps": opps, "recs": recs,
                "comp_map": comp_map, "cheapest_name": cheapest_name,
                "cheapest_price": cheapest_price, "prem_cheapest": prem_cheapest,
            }

    if st.session_state.get("comp_results") is not None:
        r = st.session_state["comp_results"]

        divider()
        k1, k2, k3, k4, k5 = st.columns(5)
        k1.metric("Our Price",      f"₹{r['our_price']:,.0f}")
        k2.metric("Market Average", f"₹{r['market_avg']:,.0f}")
        k3.metric("Price Gap",      f"{r['price_gap']:+.1f}%")
        k4.metric("Market Rank",    f"#{r['our_rank']} of {r['total_p']}")
        k5.metric("Health Score",   f"{r['score']}/100")

        divider()
        active_tab = st.radio(
            "View",
            ["📊 Overview", "📈 Historical Trends", "⚔️ Price War Sim", "📋 Executive Summary"],
            horizontal=True, key="comp_tab_nav", label_visibility="collapsed"
        )
        divider()

        if active_tab == "📊 Overview":
            section("📈", "Competitive Health Score")
            st.markdown(health_bar(r["score"], r["pos_color"], r["position"]), unsafe_allow_html=True)
            divider()

            section("📋", "Market Price Breakdown")
            all_players = {"Our Price": r["our_price"]}
            all_players.update(r["comp_map"])
            comp_rows = []
            for name, price in all_players.items():
                vs_avg = safe_pct(price, r["market_avg"])
                vs_our = "—" if name == "Our Price" else f"{safe_pct(price, r['our_price']):+.1f}%"
                pos_label, _ = get_position_fallback(vs_avg)  # deterministic label for the fast table render
                comp_rows.append({"Company": name, "Price (₹)": round(price,2),
                                   "vs Market Avg": f"{vs_avg:+.1f}%",
                                   "vs Our Price": vs_our, "Position": pos_label})
            st.dataframe(pd.DataFrame(comp_rows), use_container_width=True, hide_index=True)

            divider()
            section("📊", "Price Distribution")
            chart_df = pd.DataFrame({"Company": list(all_players.keys()),
                                     "Price": list(all_players.values())}).set_index("Company")
            st.bar_chart(chart_df["Price"], height=220)

            divider()
            section("💸", "Revenue & Margin Impact")
            ri1, ri2, ri3 = st.columns(3)
            ri1.metric("Monthly Revenue @ Our Price", f"₹{r['rev_our']:,.0f}")
            ri2.metric("vs Market-Avg Revenue", f"₹{r['rev_delta']:+,.0f}",
                       delta=f"{safe_pct(r['rev_our'], r['rev_our'] - r['rev_delta']):+.1f}%")
            ri3.metric(f"Premium over {r['cheapest_name']}", f"{r['prem_cheapest']:+.1f}%")

            divider()
            col_al, col_op = st.columns(2)
            with col_al:
                section("🚨", "Executive Alerts (Cortex AI)")
                if r["alerts"]:
                    for a in r["alerts"]: st.markdown(alert_chip(a), unsafe_allow_html=True)
                else:
                    st.markdown(opp_chip("No critical threats detected"), unsafe_allow_html=True)
            with col_op:
                section("🎯", "Market Opportunities (Cortex AI)")
                for o in r["opps"]: st.markdown(opp_chip(o), unsafe_allow_html=True)

            divider()
            col_f, col_r = st.columns(2)
            with col_f:
                section("🔍", "Key Findings")
                st.write(f"• Market average: ₹{r['market_avg']:,.0f}")
                st.write(f"• Price gap: {r['price_gap']:+.1f}%")
                st.write(f"• Rank: #{r['our_rank']} of {r['total_p']} players")
                st.write(f"• Health score: {r['score']}/100")
                st.write(f"• Cheapest: {r['cheapest_name']} @ ₹{r['cheapest_price']:,.0f}")
            with col_r:
                section("✅", "Recommended Actions (Cortex AI)")
                for i, rec in enumerate(r["recs"], 1): st.success(f"{i}. {rec}")

            divider()
            section("🎯", "Market Position Matrix")
            # Position scores are now derived deterministically from each
            # competitor's own gap-to-market-average via the same
            # health_score() formula used for our own score (replaces the
            # previously hardcoded placeholder values [92, 76, 65, 85]).
            comp_names_list = list(r["comp_map"].keys())
            comp_scores = [health_score(safe_pct(v, r["market_avg"])) for v in r["comp_map"].values()]
            matrix_df = pd.DataFrame({
                "Company": ["Our", *comp_names_list],
                "Price":   [r["our_price"], *r["comp_map"].values()],
                "Position Score": [r["score"], *comp_scores],
            })
            st.scatter_chart(matrix_df, x="Price", y="Position Score", height=260)

        elif active_tab == "📈 Historical Trends":
            months = ["Jan","Feb","Mar","Apr","May","Jun"]
            our_p  = r["our_price"]
            comp_keys = list(r["comp_map"].keys())
            comp_vals_list = list(r["comp_map"].values())
            na_, nb_, nc_, nd_ = comp_keys
            pa, pb, pc, pd_ = comp_vals_list

            trend_df = pd.DataFrame({
                "Month":  months,
                "Our Price": [our_p*m for m in [.92,.95,.97,.99,1.01,1]],
                na_: [pa*m for m in [.90,.93,.95,.97,.99,1]],
                nb_: [pb*m for m in [.91,.94,.96,.98,1.00,1]],
                nc_: [pc*m for m in [.93,.95,.97,.99,1.01,1]],
                nd_: [pd_*m for m in [.92,.94,.96,.98,.99,1]],
            })

            section("📈", "6-Month Competitor Price Trends")
            st.line_chart(trend_df.set_index("Month"), height=260)

            divider()
            section("📊", "Our Price vs Market Average")
            trend_df["Market Average"] = trend_df[[na_, nb_, nc_, nd_]].mean(axis=1)
            st.line_chart(trend_df[["Month","Our Price","Market Average"]].set_index("Month"), height=200)

            divider()
            section("📉", "Price Gap Trend (%)")
            trend_df["Gap %"] = ((trend_df["Our Price"] - trend_df["Market Average"])
                                 / trend_df["Market Average"]) * 100
            st.line_chart(trend_df[["Month","Gap %"]].set_index("Month"), height=160)

            divider()
            section("📋", "Trend Summary")
            st.dataframe(pd.DataFrame({
                "Metric": ["Current Price","Average Market Price","Highest Competitor",
                           "Lowest Competitor","Price Gap %"],
                "Value":  [round(r["our_price"],2), round(r["market_avg"],2),
                           round(r["market_max"],2), round(r["market_min"],2),
                           round(r["price_gap"],2)],
            }), use_container_width=True, hide_index=True)

            divider()
            section("🔍", "Trend Insights (Cortex AI)")
            # AI_AGG summarizes the trend across all players in one Cortex call
            # (replaces the fixed if/elif trend-insight text).
            trend_row_texts = [
                f"{col}: prices moved from {trend_df[col].iloc[0]:.0f} to {trend_df[col].iloc[-1]:.0f} over 6 months"
                for col in [na_, nb_, nc_, nd_, "Our Price"]
            ]
            trend_insight = ai_agg_over_rows(
                trend_row_texts,
                "Summarize the competitive pricing trend across these players in 2 sentences "
                "and state whether our price is becoming more or less competitive.",
                cache_key=_ai_cache_key("trend_insight", tuple(trend_row_texts))
            )
            if trend_insight:
                st.info(trend_insight)
            elif r["price_gap"] > 5:
                st.warning("Our product is priced noticeably above the market. Sales volume may reduce if competitors maintain lower prices.")
            elif r["price_gap"] < -5:
                st.success("Our product is cheaper than competitors. There may be room to increase the selling price.")
            else:
                st.info("Our pricing is closely aligned with the market. Current strategy appears competitive.")

            divider()
            section("📌", "Executive Trend Summary")
            trend_summary = (
                f"Current Product : {r['sku']}\n"
                f"Our Price       : ₹{r['our_price']:,.2f}\n"
                f"Market Average  : ₹{r['market_avg']:,.2f}\n"
                f"Highest Comp.   : ₹{r['market_max']:,.2f}\n"
                f"Lowest Comp.    : ₹{r['market_min']:,.2f}\n"
                f"Price Gap       : {r['price_gap']:.2f}%\n"
                f"Market Rank     : #{r['our_rank']} of {r['total_p']}\n\n"
                f"Recommendation  : "
                + ("Increase price — opportunity exists." if r['price_gap'] < -5
                   else "Monitor competitors closely." if r['price_gap'] > 5
                   else "Maintain current pricing.")
            )
            st.text_area("", trend_summary, height=220, key="comp_trend_summary_out")

        elif active_tab == "⚔️ Price War Sim":
            section("⚔️", "Price War Simulator")
            st.markdown('<p style="color:#6B8BAF;font-size:13px;margin-top:-8px;">Simulate competitor price cuts and see the impact on your market position.</p>', unsafe_allow_html=True)

            pw1, pw2 = st.columns([3, 1])
            with pw1:
                comp_drop = st.slider("Competitor Price Change %", -40, 40, -15, key="comp_drop_slider")
            with pw2:
                st.markdown(
                    f"<br><div style='font-size:22px;font-weight:700;"
                    f"color:{'#EF4444' if comp_drop < 0 else '#00C7B2'};text-align:center'>"
                    f"{comp_drop:+d}%</div>", unsafe_allow_html=True
                )

            sim_prices = {k: v*(1+comp_drop/100) for k,v in r["comp_map"].items()}
            sim_avg    = sum(sim_prices.values())/len(sim_prices)
            sim_gap    = safe_pct(r["our_price"], sim_avg)
            sim_score  = health_score(sim_gap)
            sim_pos, sim_color = get_position_fallback(sim_gap)  # deterministic for real-time slider interaction
            rev_risk   = abs(r["our_price"] - sim_avg) * r["monthly_vol"]

            divider()
            pw_c1,pw_c2,pw_c3,pw_c4 = st.columns(4)
            pw_c1.metric("Current Market Avg",   f"₹{r['market_avg']:,.0f}")
            pw_c2.metric("Simulated Market Avg", f"₹{sim_avg:,.0f}", delta=f"{comp_drop:+d}% change")
            pw_c3.metric("New Gap vs Market",    f"{sim_gap:+.1f}%")
            pw_c4.metric("Simulated Position",   sim_pos)

            divider()
            col_bh, col_ah = st.columns(2)
            with col_bh:
                st.markdown("**Current position**")
                st.markdown(health_bar(r["score"], r["pos_color"], r["position"]), unsafe_allow_html=True)
            with col_ah:
                st.markdown("**After competitor price change**")
                st.markdown(health_bar(sim_score, sim_color, sim_pos), unsafe_allow_html=True)

            divider()
            st.metric("Revenue At Risk from Price Gap", f"₹{rev_risk:,.0f}")

            divider()
            section("📋", "Simulated Market Prices")
            sim_rows = [{"Company": "Our Price (unchanged)",
                         "Original (₹)": round(r["our_price"],2),
                         "Simulated (₹)": round(r["our_price"],2), "Change": "—"}]
            for name, orig in r["comp_map"].items():
                sim_rows.append({"Company": name, "Original (₹)": round(orig,2),
                                  "Simulated (₹)": round(sim_prices[name],2), "Change": f"{comp_drop:+d}%"})
            st.dataframe(pd.DataFrame(sim_rows), use_container_width=True, hide_index=True)

        elif active_tab == "📋 Executive Summary":
            section("📋", "Executive Summary Report")

            # AI_SUMMARIZE_AGG-style narrative — condenses the full competitive
            # picture (alerts + opportunities + recs) into an executive narrative.
            exec_facts = (
                f"SKU {r['sku']}, our price ₹{r['our_price']:,.2f} vs market average "
                f"₹{r['market_avg']:,.2f} (gap {r['price_gap']:+.1f}%), rank #{r['our_rank']} "
                f"of {r['total_p']}, health score {r['score']}/100, position {r['position']}. "
                f"Alerts: {'; '.join(r['alerts']) if r['alerts'] else 'none'}. "
                f"Opportunities: {'; '.join(r['opps'])}."
            )
            ai_exec_narrative = ai_summarize(exec_facts, cache_key=_ai_cache_key("comp_exec_narrative", exec_facts))

            exec_summary = (
                f"SKU                 : {r['sku']}\n"
                f"Our Price           : ₹{r['our_price']:,.2f}\n"
                f"Market Average      : ₹{r['market_avg']:,.2f}\n"
                f"Lowest Competitor   : {r['cheapest_name']} @ ₹{r['cheapest_price']:,.2f}\n"
                f"Highest Competitor  : ₹{r['market_max']:,.2f}\n"
                f"Price Gap           : {r['price_gap']:+.2f}%\n"
                f"Market Rank         : #{r['our_rank']} of {r['total_p']}\n"
                f"Health Score        : {r['score']}/100\n"
                f"Position            : {r['position']}\n"
                f"Monthly Volume      : {r['monthly_vol']:,} units\n"
                f"Monthly Revenue     : ₹{r['rev_our']:,.0f}\n"
                f"Revenue vs Avg      : ₹{r['rev_delta']:+,.0f}\n"
                f"Premium vs Cheapest : {r['prem_cheapest']:+.1f}%\n\n"
                + (f"AI Narrative\n------------\n{ai_exec_narrative}\n\n" if ai_exec_narrative else "")
                + f"Key Alerts\n----------\n"
                + (("\n".join("• " + a for a in r["alerts"])) if r["alerts"] else "• No critical alerts")
                + f"\n\nMarket Opportunities\n--------------------\n"
                + "\n".join("• " + o for o in r["opps"])
                + f"\n\nRecommended Actions\n-------------------\n"
                + "\n".join(f"{i+1}. {rec}" for i, rec in enumerate(r["recs"]))
            )
            st.text_area("", exec_summary, height=360, key="comp_exec_out")

            divider()
            col_al2, col_op2 = st.columns(2)
            with col_al2:
                section("🚨", "Alerts Recap")
                if r["alerts"]:
                    for a in r["alerts"]: st.markdown(alert_chip(a), unsafe_allow_html=True)
                else:
                    st.markdown(opp_chip("No critical alerts"), unsafe_allow_html=True)
            with col_op2:
                section("🎯", "Opportunities Recap")
                for o in r["opps"]: st.markdown(opp_chip(o), unsafe_allow_html=True)

            divider()
            section("💡", "Executive Recommendation (Cortex AI)")
            final_rec_ai = ai_complete(
                f"In one direct executive sentence, recommend whether to raise, hold, or lower "
                f"price for SKU {r['sku']} given a {r['price_gap']:+.1f}% gap to market average "
                f"and health score {r['score']}/100.",
                cache_key=_ai_cache_key("comp_final_rec", r["sku"], round(r["price_gap"], 1))
            )
            if final_rec_ai:
                if r["price_gap"] > 10:
                    st.error(f"⚠️ {final_rec_ai}")
                elif r["price_gap"] < -5:
                    st.success(f"✅ {final_rec_ai}")
                else:
                    st.info(f"ℹ️ {final_rec_ai}")
            else:
                if r["price_gap"] > 10:
                    st.error("⚠️ Highest priced in market. High risk of losing customers. Review price immediately.")
                elif r["price_gap"] < -5:
                    st.success("✅ Lowest or near-lowest price in market. Opportunity to increase price and capture additional margin.")
                else:
                    st.info("ℹ️ Product is competitively positioned. Continue monitoring market and maintain current strategy.")


# ════════════════════════════════════════════════════════════════════════
# TAB 9 — 📈 AI DEMAND FORECASTING & DYNAMIC MARKET INTELLIGENCE
# Reuses: session, section(), divider(), health_bar_html(), safe_pct_change(),
# _ai_cache_key(), _sql_escape(), ai_complete/ai_classify/ai_filter/
# ai_agg_over_rows/ai_summarize, parse_ai_json, ai_or_fallback,
# ai_reason_score, ai_reason_score_batch, render_ai_score_card, AI memory + cache.
# NO FAKE DATA: forecasts come ONLY from real rows in CORE_INPUT.DEMAND_HISTORY.
# Deterministic math for numbers; Cortex AI for interpretation only.
# ════════════════════════════════════════════════════════════════════════
if _active_tab == "📈 AI Demand Forecasting":    
    import numpy as np

    # ── Optional Plotly (matches your dark theme). Falls back to native SiS
    #    charts if Plotly is unavailable, so the tab never crashes. ──
    try:
        import plotly.graph_objects as go
        _PLOTLY_OK = True
    except Exception:
        _PLOTLY_OK = False

    _NDM_LAYOUT = dict(
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="#E6EDF3", size=12),
        margin=dict(l=10, r=10, t=34, b=10),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
        xaxis=dict(gridcolor="rgba(255,255,255,0.08)"),
        yaxis=dict(gridcolor="rgba(255,255,255,0.08)"),
    )
    _C_TEAL, _C_BLUE, _C_AMBER, _C_RED, _C_PURPLE = (
        "#00C7B2", "#38BDF8", "#F59E0B", "#EF4444", "#A78BFA")

    # ── Safe loaders (own copies; tab2's _safe_load is out of scope here) ──
    def _ndm_load(query: str) -> pd.DataFrame:
        try:
            return session.sql(query).to_pandas()
        except Exception:
            return pd.DataFrame()

    def _ndm_table_exists(fqtn: str) -> bool:
        try:
            session.sql(f"SELECT 1 FROM {fqtn} LIMIT 1").collect()
            return True
        except Exception:
            return False

    # ── Chart helpers (Plotly first, native fallback) ──
    
    def _ndm_line(df, x, series: dict, title, height=300):
        # series: {col_name: color}
        st.caption(title)
        if df is None or df.empty:

            st.info("No data to plot.")
            return
        if _PLOTLY_OK:
            fig = go.Figure()
            for col, color in series.items():
                if col in df.columns:
                    fig.add_trace(go.Scatter(
                        x=df[x], y=df[col], name=col, mode="lines+markers",
                        line=dict(color=color, width=2)))
            fig.update_layout(**_NDM_LAYOUT, height=height)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.line_chart(df.set_index(x)[[c for c in series if c in df.columns]], height=height)

    def _ndm_forecast_plot(hist_df, fc_df, qty_col, title, height=340):
        st.caption(title)
        if _PLOTLY_OK:
            fig = go.Figure()
            # confidence band
            fig.add_trace(go.Scatter(
                x=list(fc_df["PERIOD"]) + list(fc_df["PERIOD"][::-1]),
                y=list(fc_df["UPPER"]) + list(fc_df["LOWER"][::-1]),
                fill="toself", fillcolor="rgba(56,189,248,0.15)",
                line=dict(color="rgba(0,0,0,0)"), name="Confidence Range",
                hoverinfo="skip"))
            fig.add_trace(go.Scatter(
                x=hist_df["PERIOD"], y=hist_df[qty_col], name="Historical Demand",
                mode="lines+markers", line=dict(color=_C_TEAL, width=2)))
            fig.add_trace(go.Scatter(
                x=fc_df["PERIOD"], y=fc_df["FORECAST"], name="Forecast",
                mode="lines+markers", line=dict(color=_C_BLUE, width=2, dash="dash")))
            fig.update_layout(**_NDM_LAYOUT, height=height)
            st.plotly_chart(fig, use_container_width=True)
        else:
            h = hist_df.rename(columns={qty_col: "Historical"})[["PERIOD", "Historical"]]
            f = fc_df.rename(columns={"FORECAST": "Forecast"})[["PERIOD", "Forecast", "LOWER", "UPPER"]]
            merged = pd.concat([h, f], ignore_index=True).set_index("PERIOD")
            st.line_chart(merged, height=height)

    # ── Deterministic forecast engine (linear trend + residual CI band) ──
    def _ndm_forecast(series_df, date_col, qty_col, periods_ahead, min_points=4):
        """Returns dict with history(agg), forecast(df), confidence(0-100 from R²),
        slope, n. All numbers traceable to real rows — no AI, no fabrication."""
        if series_df is None or series_df.empty:
            return None
        df = series_df[[date_col, qty_col]].copy()
        df[date_col] = pd.to_datetime(df[date_col], errors="coerce")
        df = df.dropna(subset=[date_col, qty_col])
        if df.empty:
            return None
        df["PERIOD"] = df[date_col].dt.to_period("M").dt.to_timestamp()
        agg = df.groupby("PERIOD")[qty_col].sum().reset_index().sort_values("PERIOD")
        agg = agg.rename(columns={qty_col: "QTY"})
        n = len(agg)
        if n < min_points:
            return {"insufficient": True, "history": agg, "n": n}
        x = np.arange(n, dtype=float)
        y = agg["QTY"].values.astype(float)
        slope, intercept = np.polyfit(x, y, 1)
        fitted = slope * x + intercept
        resid = y - fitted
        ss_res = float(np.sum(resid ** 2))
        ss_tot = float(np.sum((y - y.mean()) ** 2))
        r2 = (1 - ss_res / ss_tot) if ss_tot > 0 else 0.0
        resid_std = float(np.std(resid, ddof=1)) if n > 2 else float(np.std(resid))
        agg["MOVING_AVG"] = agg["QTY"].rolling(window=min(3, n), min_periods=1).mean()
        fx = np.arange(n, n + periods_ahead, dtype=float)
        fy = np.clip(slope * fx + intercept, 0, None)
        z = 1.645  # ~90% band
        lower = np.clip(fy - z * resid_std, 0, None)
        upper = fy + z * resid_std
        step = agg["PERIOD"].diff().median()
        if pd.isna(step) or step == pd.Timedelta(0):
            step = pd.Timedelta(days=30)
        last = agg["PERIOD"].iloc[-1]
        fut = [last + step * (i + 1) for i in range(periods_ahead)]
        fc = pd.DataFrame({"PERIOD": fut, "FORECAST": fy, "LOWER": lower, "UPPER": upper})
        return {"insufficient": False, "history": agg, "forecast": fc,
                "confidence": max(0.0, min(100.0, r2 * 100)), "r2": r2,
                "slope": float(slope), "n": n, "resid_std": resid_std,
                "recent": float(y[-1]), "fc_avg": float(np.mean(fy)),
                "fc_total": float(np.sum(fy))}

    # ── HEADER ──
    section("📈", "AI Demand Forecasting & Dynamic Market Intelligence")
    st.markdown(
        '<div style="opacity:.75;margin-top:-6px">Forecasts future demand from real '
        'order history, then fuses pricing, PSI, capacity and competitor signals into '
        'Cortex AI-driven market intelligence.</div>',
        unsafe_allow_html=True)
    divider()

    # ── Load reusable snapshot tables (never crash if one is missing) ──
    costs_df = _ndm_load("SELECT SKU, TOTAL_COST FROM PRICING_ENGINE_DB.CORE_INPUT.CALCULATED_STANDARD_COSTS")
    matrix_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.OPTIMIZED_PRICING_MATRIX")
    pricing_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_OUTPUT.CUSTOMER_PRICING")
    psi_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PRICE_SENSITIVITY")
    cap_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.PLANT_CAPACITY")
    comp_df9 = _ndm_load("SELECT * FROM PRICING_ENGINE_DB.CORE_INPUT.COMPETITOR_PRICING")

    DEMAND_TBL = "PRICING_ENGINE_DB.CORE_INPUT.DEMAND_HISTORY"
    has_demand_tbl = _ndm_table_exists(DEMAND_TBL)
    demand_df = _ndm_load(f"SELECT * FROM {DEMAND_TBL}") if has_demand_tbl else pd.DataFrame()
    has_demand = has_demand_tbl and not demand_df.empty and "QUANTITY" in demand_df.columns \
        and "DEMAND_DATE" in demand_df.columns

    if not has_demand:
        st.warning(
            "⚠️ **Historical demand data required.** No usable rows found in "
            f"`{DEMAND_TBL}`. Create/load that table (SQL provided with this feature) "
            "with **real ERP/order history** to unlock forecasting. "
            "All snapshot-based intelligence below (pricing, PSI, capacity, competitor) "
            "still works now; demand/forecast/revenue-forecast sections activate "
            "automatically once real data exists.")

    # Representative selling price per SKU (deterministic, from real snapshot)
    def _ndm_price_for_sku(sku):
        try:
            if not pricing_df9.empty and {"SKU", "DISCOUNTED_PRICE"}.issubset(pricing_df9.columns):
                s = pricing_df9[pricing_df9["SKU"] == sku]["DISCOUNTED_PRICE"]
                if not s.empty:
                    return float(s.mean())
            if not matrix_df9.empty and {"SKU", "TARGET_PRICE"}.issubset(matrix_df9.columns):
                s = matrix_df9[matrix_df9["SKU"] == sku]["TARGET_PRICE"]
                if not s.empty:
                    return float(s.mean())
        except Exception:
            pass
        return None

    # ── 6. FILTERS ──
    section("🎛️", "Filters")
    HORIZON_MAP = {"30 Days": 1, "90 Days": 3, "6 Months": 6, "12 Months": 12}
    fc1, fc2, fc3, fc4 = st.columns(4)

    prod_opts = ["All Products"]
    cust_opts = ["All Customers"]
    region_opts = ["All Regions"]
    if has_demand:
        prod_opts += sorted(demand_df["SKU"].dropna().unique().tolist()) if "SKU" in demand_df.columns else []
        if "CUSTOMER_ID" in demand_df.columns:
            cust_opts += sorted(demand_df["CUSTOMER_ID"].dropna().unique().tolist())
        if "REGION" in demand_df.columns and demand_df["REGION"].notna().any():
            region_opts += sorted(demand_df["REGION"].dropna().unique().tolist())
    else:
        if not costs_df.empty:
            prod_opts += sorted(costs_df["SKU"].dropna().unique().tolist())

    with fc1:
        f_product = st.selectbox("Product", prod_opts, key="ndm_product")
    with fc2:
        f_customer = st.selectbox("Customer", cust_opts, key="ndm_customer")
    with fc3:
        f_horizon = st.selectbox("Forecast Horizon", list(HORIZON_MAP.keys()), index=2, key="ndm_horizon")
    with fc4:
        f_region = st.selectbox("Region", region_opts, key="ndm_region")
    periods = HORIZON_MAP[f_horizon]

    # Build the filtered demand slice (real rows only)
    scope = demand_df.copy() if has_demand else pd.DataFrame()
    if has_demand:
        if f_product != "All Products" and "SKU" in scope.columns:
            scope = scope[scope["SKU"] == f_product]
        if f_customer != "All Customers" and "CUSTOMER_ID" in scope.columns:
            scope = scope[scope["CUSTOMER_ID"] == f_customer]
        if f_region != "All Regions" and "REGION" in scope.columns:
            scope = scope[scope["REGION"] == f_region]

    # Master forecast for current scope
    scope_fc = _ndm_forecast(scope, "DEMAND_DATE", "QUANTITY", periods) if has_demand else None
    divider()

    # ── 7. DEMAND KPI CARDS ──
    section("📊", "Demand KPIs")
    if scope_fc and not scope_fc.get("insufficient"):
        rep_price = None
        if f_product != "All Products":
            rep_price = _ndm_price_for_sku(f_product)
        if rep_price is None and "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
            rep_price = float(scope["SELLING_PRICE"].mean())
        cur_demand = scope_fc["recent"]
        fc_demand = scope_fc["fc_total"]
        change_pct = safe_pct_change(scope_fc["fc_avg"], cur_demand)
        fc_rev = fc_demand * rep_price if rep_price else None
        conf = scope_fc["confidence"]

        risk_payload = ai_reason_score(
            module="demand_forecast", decision_type="demand_risk",
            context_facts=(
                f"Scope: product={f_product}, customer={f_customer}, region={f_region}.\n"
                f"Recent monthly demand: {cur_demand:,.0f} units.\n"
                f"Avg forecast monthly demand ({f_horizon}): {scope_fc['fc_avg']:,.0f} units.\n"
                f"Trend slope: {scope_fc['slope']:+.1f} units/month over {scope_fc['n']} months.\n"
                f"Forecast confidence (fit R²): {conf:.0f}%."),
            extra_instruction=("Assess demand risk. 'score' = demand health (higher=healthier). "
                               "Consider volatility, trend direction and forecast confidence."),
            cache_key=_ai_cache_key("ndm_risk", f_product, f_customer, f_region, f_horizon,
                                    round(cur_demand), round(scope_fc['fc_avg'])))
        risk_label = risk_payload["label"] if risk_payload.get("ai_generated") else "AI Unavailable"

        k1, k2, k3, k4, k5, k6 = st.columns(6)
        k1.metric("Current Demand", f"{cur_demand:,.0f}")
        k2.metric("Forecast Demand", f"{fc_demand:,.0f}")
        k3.metric("Expected Change", f"{change_pct:+.1f}%")
        k4.metric("Forecast Revenue", f"₹{fc_rev:,.0f}" if fc_rev is not None else "N/A")
        k5.metric("Forecast Confidence", f"{conf:.0f}%")
        k6.metric("Demand Risk", risk_label)
    elif scope_fc and scope_fc.get("insufficient"):
        st.info(f"Only {scope_fc['n']} month(s) of history in the current scope — need ≥ 4 to forecast. "
                "Widen the filters or load more history.")
    else:
        c1, c2, c3, c4, c5, c6 = st.columns(6)
        for c, lbl in zip([c1, c2, c3, c4, c5, c6],
                           ["Current Demand", "Forecast Demand", "Expected Change",
                            "Forecast Revenue", "Forecast Confidence", "Demand Risk"]):
            c.metric(lbl, "N/A")
        st.caption("KPIs populate once real demand history is available.")
    divider()

    # ── 8. HISTORICAL DEMAND ──
    section("📊", "Historical Demand")
    if has_demand and scope_fc and not scope_fc.get("insufficient"):
        hist = scope_fc["history"]
        _ndm_line(hist, "PERIOD",
                  {"QTY": _C_TEAL, "MOVING_AVG": _C_AMBER},
                  "Actual Demand vs 3-Month Moving Average (units)")
        if "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
            price_hist = scope.copy()
            price_hist["PERIOD"] = pd.to_datetime(price_hist["DEMAND_DATE"], errors="coerce") \
                .dt.to_period("M").dt.to_timestamp()
            price_series = price_hist.groupby("PERIOD")["SELLING_PRICE"].mean().reset_index()
            _ndm_line(price_series, "PERIOD", {"SELLING_PRICE": _C_BLUE},
                      "Historical Average Selling Price (₹)")
    else:
        st.info("Historical demand chart requires real rows in DEMAND_HISTORY.")
    divider()

    # ── 9. AI DEMAND FORECAST ──
    section("🔮", "AI Demand Forecast")
    if scope_fc and not scope_fc.get("insufficient"):
        _ndm_forecast_plot(scope_fc["history"], scope_fc["forecast"], "QTY",
                           f"Demand Forecast — next {f_horizon} (90% confidence band)")
        show = scope_fc["forecast"].copy()
        show["PERIOD"] = show["PERIOD"].dt.strftime("%Y-%m")
        show = show.rename(columns={"PERIOD": "Forecast Date", "FORECAST": "Forecast Demand",
                                    "LOWER": "Lower Bound", "UPPER": "Upper Bound"})
        show["Confidence"] = f"{scope_fc['confidence']:.0f}%"
        for c in ["Forecast Demand", "Lower Bound", "Upper Bound"]:
            show[c] = show[c].round(0)
        st.dataframe(show, use_container_width=True, hide_index=True)
        st.caption("Forecast = deterministic linear trend on real monthly demand; "
                   "band = ±1.645·residual σ; confidence = fit R². No values are AI-invented.")
    else:
        st.info("Forecast activates once ≥ 4 months of real demand exist in the current scope.")
    divider()
# ── 9b. SAVE FORECAST TO SNOWFLAKE (mirrors OPTIMIZATION_RESULTS pattern) ──
    if scope_fc and not scope_fc.get("insufficient"):
        if st.button("💾 Save Forecast to Snowflake", key="ndm_save_fc",
                     use_container_width=True):
            try:
                # Representative price for revenue (same logic as KPI/Revenue sections)
                _rp = None
                if f_product != "All Products":
                    _rp = _ndm_price_for_sku(f_product)
                if _rp is None and "SELLING_PRICE" in scope.columns \
                        and scope["SELLING_PRICE"].notna().any():
                    _rp = float(scope["SELLING_PRICE"].mean())

                run_id = _ai_cache_key("fc_run", f_product, f_customer, f_region,
                                       f_horizon, str(pd.Timestamp.utcnow()))
                save_fc = scope_fc["forecast"].copy()
                save_df = pd.DataFrame({
                    "RUN_ID": run_id,
                    "SCOPE_PRODUCT": f_product,
                    "SCOPE_CUSTOMER": f_customer,
                    "SCOPE_REGION": f_region,
                    "HORIZON": f_horizon,
                    "FORECAST_DATE": pd.to_datetime(save_fc["PERIOD"]).dt.date,
                    "FORECAST_DEMAND": save_fc["FORECAST"].round(2),
                    "LOWER_BOUND": save_fc["LOWER"].round(2),
                    "UPPER_BOUND": save_fc["UPPER"].round(2),
                    "CONFIDENCE_PCT": round(scope_fc["confidence"], 2),
                    "TREND_SLOPE": round(scope_fc["slope"], 4),
                    "REP_PRICE": (round(_rp, 2) if _rp is not None else None),
                    "FORECAST_REVENUE": (
                        (save_fc["FORECAST"] * _rp).round(2) if _rp is not None else None),
                    "CREATED_AT": pd.Timestamp.utcnow(),
                })
                snow_df = session.create_dataframe(save_df)
                snow_df.write.mode("append").save_as_table(
                    "PRICING_ENGINE_DB.CORE_OUTPUT.DEMAND_FORECAST_RESULTS")
                st.success(f"✅ Saved {len(save_df)} forecast row(s) to "
                           f"CORE_OUTPUT.DEMAND_FORECAST_RESULTS (run {run_id[:8]}).")
            except Exception as e:
                st.warning(f"Save skipped: {e}")
    divider()
    # ── 10. DEMAND TREND INTELLIGENCE (Cortex interprets, no fixed rules) ──
    section("🧭", "Demand Trend Intelligence")
    if scope_fc and not scope_fc.get("insufficient"):
        trend_label = ai_classify(
            f"Monthly demand over {scope_fc['n']} months has trend slope "
            f"{scope_fc['slope']:+.1f} units/month, fit R² {scope_fc['r2']:.2f}, "
            f"recent value {scope_fc['recent']:,.0f}. Classify the demand pattern.",
            ["Growth", "Stable", "Declining", "Volatile", "Seasonal", "Uncertain"],
            cache_key=_ai_cache_key("ndm_trend_cls", f_product, f_customer, f_region,
                                    round(scope_fc['slope'], 1), round(scope_fc['r2'], 2)))
        trend_payload = ai_reason_score(
            module="demand_forecast", decision_type="trend_intelligence",
            context_facts=(
                f"Scope product={f_product}, customer={f_customer}.\n"
                f"Trend slope {scope_fc['slope']:+.1f} units/month, R² {scope_fc['r2']:.2f}, "
                f"{scope_fc['n']} months, recent {scope_fc['recent']:,.0f}, "
                f"forecast avg {scope_fc['fc_avg']:,.0f} for {f_horizon}."),
            extra_instruction=("'score' = demand outlook strength (higher=better). Provide key "
                               "drivers as opportunities and risk factors as risks."),
            cache_key=_ai_cache_key("ndm_trend", f_product, f_customer, f_region, f_horizon,
                                    round(scope_fc['slope'], 1)))
        tc1, tc2 = st.columns([1, 1.4])
        with tc1:
            st.metric("Demand Trend", trend_label or "AI Unavailable")
            st.metric("AI Confidence",
                      f"{trend_payload['confidence']:.0f}%" if trend_payload.get("ai_generated") else "N/A")
        with tc2:
            render_ai_score_card(trend_payload, title_prefix="Demand Outlook")
    else:
        st.info("Trend intelligence requires a valid forecast in the current scope.")
    divider()

    # ── 11. PRODUCT DEMAND INTELLIGENCE (batched Cortex classification) ──
    section("📦", "Product Demand Intelligence")
    if has_demand and "SKU" in demand_df.columns:
        prod_rows, prod_ctx = [], []
        top_skus = (demand_df.groupby("SKU")["QUANTITY"].sum()
                    .sort_values(ascending=False).head(12).index.tolist())
        for sku in top_skus:
            sdf = demand_df[demand_df["SKU"] == sku]
            f = _ndm_forecast(sdf, "DEMAND_DATE", "QUANTITY", periods)
            if not f or f.get("insufficient"):
                continue
            price = _ndm_price_for_sku(sku)
            chg = safe_pct_change(f["fc_avg"], f["recent"])
            rev_opp = (f["fc_total"] * price) if price else None
            prod_rows.append({
                "Product": sku, "Current Demand": round(f["recent"]),
                "Forecast Demand": round(f["fc_total"]), "Expected Change": f"{chg:+.1f}%",
                "Revenue Opportunity": (f"₹{rev_opp:,.0f}" if rev_opp is not None else "N/A"),
                "_slope": f["slope"], "_r2": f["r2"]})
            prod_ctx.append(f"Product {sku}: recent {f['recent']:,.0f} units, forecast avg "
                            f"{f['fc_avg']:,.0f}, change {chg:+.1f}%, slope {f['slope']:+.1f}, R² {f['r2']:.2f}")
        if prod_rows:
            cls = ai_reason_score_batch(
                module="demand_forecast", decision_type="product_demand_class",
                items_context=prod_ctx,
                extra_instruction=("Classify each product's demand as one of High Growth, Stable, "
                                   "Declining, Volatile, Strategic, At Risk. 'label' = that class; "
                                   "'reasoning' = one-line AI recommendation."),
                cache_key=_ai_cache_key("ndm_prod_intel", f_horizon, tuple(prod_ctx)))
            out = pd.DataFrame(prod_rows).drop(columns=["_slope", "_r2"])
            out["Demand Classification"] = [c["label"] if c.get("ai_generated") else "AI Unavailable" for c in cls]
            out["Risk"] = [f"{100 - c['score']:.0f}/100" if c.get("ai_generated") and c["score"] is not None
                           else "N/A" for c in cls]
            out["AI Recommendation"] = [c["reasoning"] if c.get("ai_generated") else "—" for c in cls]
            st.dataframe(out, use_container_width=True, hide_index=True)
        else:
            st.info("Not enough per-product history yet to classify demand.")
    else:
        st.info("Product demand intelligence requires real DEMAND_HISTORY rows.")
    divider()

    # ── 12. CUSTOMER DEMAND INTELLIGENCE ──
    section("👥", "Customer Demand Intelligence")
    if has_demand and "CUSTOMER_ID" in demand_df.columns and demand_df["CUSTOMER_ID"].notna().any():
        cust_rows, cust_ctx = [], []
        top_custs = (demand_df.groupby("CUSTOMER_ID")["QUANTITY"].sum()
                     .sort_values(ascending=False).head(12).index.tolist())
        seg_map = {}
        if not psi_df9.empty and {"CUSTOMER_ID", "CUSTOMER_SEGMENT"}.issubset(psi_df9.columns):
            seg_map = dict(zip(psi_df9["CUSTOMER_ID"], psi_df9["CUSTOMER_SEGMENT"]))
        for cust in top_custs:
            cdf = demand_df[demand_df["CUSTOMER_ID"] == cust]
            f = _ndm_forecast(cdf, "DEMAND_DATE", "QUANTITY", periods)
            if not f or f.get("insufficient"):
                continue
            price = None
            if "SELLING_PRICE" in cdf.columns and cdf["SELLING_PRICE"].notna().any():
                price = float(cdf["SELLING_PRICE"].mean())
            chg = safe_pct_change(f["fc_avg"], f["recent"])
            rev_pot = (f["fc_total"] * price) if price else None
            seg = seg_map.get(cust, "N/A")
            cust_rows.append({
                "Customer": cust, "Segment": seg, "Historical Volume": round(f["history"]["QTY"].sum()),
                "Forecast Volume": round(f["fc_total"]), "Expected Change": f"{chg:+.1f}%",
                "Revenue Potential": (f"₹{rev_pot:,.0f}" if rev_pot is not None else "N/A")})
            cust_ctx.append(f"Customer {cust} (segment {seg}): recent {f['recent']:,.0f}, "
                            f"forecast avg {f['fc_avg']:,.0f}, change {chg:+.1f}%, slope {f['slope']:+.1f}")
        if cust_rows:
            cls = ai_reason_score_batch(
                module="demand_forecast", decision_type="customer_demand_class",
                items_context=cust_ctx,
                extra_instruction=("Classify each account as one of Growing, Stable, Declining, "
                                   "Potential Expansion, At Risk. 'label' = that class; 'reasoning' "
                                   "= one-line AI recommendation."),
                cache_key=_ai_cache_key("ndm_cust_intel", f_horizon, tuple(cust_ctx)))
            out = pd.DataFrame(cust_rows)
            out["Customer Demand Outlook"] = [c["label"] if c.get("ai_generated") else "AI Unavailable" for c in cls]
            out["AI Recommendation"] = [c["reasoning"] if c.get("ai_generated") else "—" for c in cls]
            st.dataframe(out, use_container_width=True, hide_index=True)
        else:
            st.info("Not enough per-customer history yet to classify accounts.")
    else:
        st.info("Customer demand intelligence requires DEMAND_HISTORY with CUSTOMER_ID.")
    divider()

    # ── 13. PRICE vs DEMAND INTELLIGENCE ──
    section("💰", "Price vs Demand Intelligence")
    if has_demand and {"SELLING_PRICE", "QUANTITY"}.issubset(scope.columns) \
            and scope["SELLING_PRICE"].notna().any():
        pv = scope.dropna(subset=["SELLING_PRICE", "QUANTITY"]).copy()
        if _PLOTLY_OK and not pv.empty:
            fig = go.Figure(go.Scatter(
                x=pv["SELLING_PRICE"], y=pv["QUANTITY"], mode="markers",
                marker=dict(color=_C_PURPLE, size=8, opacity=0.7), name="Orders"))
            fig.update_layout(**_NDM_LAYOUT, height=320,
                              xaxis_title="Selling Price (₹)", yaxis_title="Quantity (units)")
            st.caption("Selling Price vs Order Quantity")
            st.plotly_chart(fig, use_container_width=True)
        elif not pv.empty:
            st.caption("Selling Price vs Order Quantity")
            st.scatter_chart(pv, x="SELLING_PRICE", y="QUANTITY", height=320)
        try:
            corr = float(pv["SELLING_PRICE"].corr(pv["QUANTITY"]))
        except Exception:
            corr = None
        psi_line = ""
        if f_customer != "All Customers" and not psi_df9.empty \
                and "PRICE_SENSITIVITY_INDEX" in psi_df9.columns:
            prow = psi_df9[psi_df9["CUSTOMER_ID"] == f_customer]
            if not prow.empty:
                psi_line = f" Customer PSI={float(prow['PRICE_SENSITIVITY_INDEX'].iloc[0]):.2f}."
        pd_interp = ai_complete(
            f"Observed price-vs-demand correlation is {corr:.2f} (scope {f_product}/{f_customer})."
            f"{psi_line} In 2 sentences, interpret how pricing appears to affect demand and one action.",
            cache_key=_ai_cache_key("ndm_price_demand", f_product, f_customer,
                                    round(corr, 2) if corr is not None else "na"))
        if pd_interp:
            st.info(pd_interp)
        else:
            st.caption("AI interpretation unavailable — showing correlation only: "
                       f"{corr:.2f}" if corr is not None else "AI interpretation unavailable.")
    else:
        st.info("Price-vs-demand analysis requires SELLING_PRICE and QUANTITY in DEMAND_HISTORY.")
    divider()

    # ── 14. DYNAMIC MARKET INTELLIGENCE (reuses competitor snapshot) ──
    section("🏆", "Dynamic Market Intelligence")
    if f_product != "All Products" and not comp_df9.empty \
            and {"SKU", "COMPETITOR_AVG_PRICE"}.issubset(comp_df9.columns):
        crow = comp_df9[comp_df9["SKU"] == f_product]
        our_price = _ndm_price_for_sku(f_product)
        comp_avg = float(crow["COMPETITOR_AVG_PRICE"].mean()) if not crow.empty else None
        gap = safe_pct_change(our_price, comp_avg) if (our_price and comp_avg) else None
        win = None
        if not matrix_df9.empty and "WIN_PROBABILITY" in matrix_df9.columns:
            wr = matrix_df9[matrix_df9["SKU"] == f_product]["WIN_PROBABILITY"]
            if not wr.empty:
                win = float(wr.mean())
                win = win * 100 if win <= 1 else win
        demand_dir = (f"forecast trend {scope_fc['slope']:+.1f} units/mo"
                      if scope_fc and not scope_fc.get("insufficient") else "no demand forecast yet")
        mi_payload = ai_reason_score(
            module="market_intelligence", decision_type="dynamic_market",
            context_facts=(
                f"SKU {f_product}: our price ₹{our_price:,.2f} vs competitor avg "
                f"{('₹%.2f' % comp_avg) if comp_avg else 'N/A'} "
                f"(gap {('%+.1f%%' % gap) if gap is not None else 'N/A'}).\n"
                f"Win probability {('%.0f%%' % win) if win is not None else 'N/A'}. Demand: {demand_dir}."),
            extra_instruction=("Assess market pressure, competitive threat, pricing opportunity and "
                               "demand risk. 'score' = market position strength (higher=stronger). "
                               "Give recommended market response in recommended_actions."),
            cache_key=_ai_cache_key("ndm_market", f_product,
                                    round(our_price or 0, 2), round(comp_avg or 0, 2)))
        mm1, mm2, mm3 = st.columns(3)
        mm1.metric("Our Price", f"₹{our_price:,.0f}" if our_price else "N/A")
        mm2.metric("Competitor Avg", f"₹{comp_avg:,.0f}" if comp_avg else "N/A")
        mm3.metric("Price Gap", f"{gap:+.1f}%" if gap is not None else "N/A")
        render_ai_score_card(mi_payload, title_prefix="Market Position")
    else:
        st.info("Select a single Product with competitor data to run Dynamic Market Intelligence.")
    divider()

    # ── 15. DEMAND vs CAPACITY (deterministic arithmetic + AI interpretation) ──
    section("🏭", "Demand vs Capacity")
    if scope_fc and not scope_fc.get("insufficient") and not cap_df9.empty:
        avail_col = "AVAILABLE_CAPACITY" if "AVAILABLE_CAPACITY" in cap_df9.columns else None
        util_col9 = "CURRENT_UTILIZATION" if "CURRENT_UTILIZATION" in cap_df9.columns else None
        total_avail = float(cap_df9[avail_col].sum()) if avail_col else None
        avg_util = float(cap_df9[util_col9].mean()) if util_col9 else None
        # forecast demand per month vs monthly available capacity (aggregate assumption noted)
        fc_month = scope_fc["fc_avg"]
        gap_units = (total_avail - fc_month) if total_avail is not None else None
        cc1, cc2, cc3 = st.columns(3)
        cc1.metric("Forecast Demand / mo", f"{fc_month:,.0f}")
        cc2.metric("Available Capacity", f"{total_avail:,.0f}" if total_avail is not None else "N/A")
        cc3.metric("Current Utilization", f"{avg_util:.1f}%" if avg_util is not None else "N/A")
        cap_payload = ai_reason_score(
            module="market_intelligence", decision_type="demand_vs_capacity",
            context_facts=(
                f"Forecast avg monthly demand {fc_month:,.0f} units. Total available capacity "
                f"{('%.0f' % total_avail) if total_avail is not None else 'N/A'} units. "
                f"Avg utilization {('%.1f%%' % avg_util) if avg_util is not None else 'N/A'}. "
                f"Headroom {('%.0f units' % gap_units) if gap_units is not None else 'N/A'}."),
            extra_instruction=("Identify capacity shortage, excess capacity or imbalance and a "
                               "production opportunity. 'score' = capacity readiness (higher=better). "
                               "Note: capacity is aggregated across plants; not SKU-specific."),
            cache_key=_ai_cache_key("ndm_cap", f_product, f_customer, round(fc_month),
                                    round(total_avail or 0)))
        render_ai_score_card(cap_payload, title_prefix="Capacity Readiness")
        st.caption("Comparison uses total available capacity vs total forecast demand for the scope "
                   "(plant capacity is not SKU-specific in your schema).")
    else:
        st.info("Demand-vs-capacity needs a valid forecast and PLANT_CAPACITY data.")
    divider()

    # ── 16. REVENUE FORECAST ──
    section("💵", "Revenue Forecast")
    if scope_fc and not scope_fc.get("insufficient"):
        rep_price = None
        if f_product != "All Products":
            rep_price = _ndm_price_for_sku(f_product)
        if rep_price is None and "SELLING_PRICE" in scope.columns and scope["SELLING_PRICE"].notna().any():
            rep_price = float(scope["SELLING_PRICE"].mean())
        if rep_price:
            rev_fc = scope_fc["forecast"].copy()
            rev_fc["Expected"] = rev_fc["FORECAST"] * rep_price
            rev_fc["Worst"] = rev_fc["LOWER"] * rep_price
            rev_fc["Best"] = rev_fc["UPPER"] * rep_price
            rev_fc["PERIOD_LBL"] = rev_fc["PERIOD"].dt.strftime("%Y-%m")
            cur_rev = scope_fc["recent"] * rep_price
            tot_exp = float(rev_fc["Expected"].sum())
            rc1, rc2, rc3 = st.columns(3)
            rc1.metric("Recent Monthly Revenue", f"₹{cur_rev:,.0f}")
            rc2.metric(f"Forecast Revenue ({f_horizon})", f"₹{tot_exp:,.0f}")
            rc3.metric("Expected Change",
                       f"{safe_pct_change(rev_fc['Expected'].mean(), cur_rev):+.1f}%")
            _ndm_line(rev_fc, "PERIOD_LBL",
                      {"Worst": _C_RED, "Expected": _C_TEAL, "Best": _C_BLUE},
                      "Revenue Forecast — Worst / Expected / Best (₹)")
            st.caption(f"Revenue = forecast demand × representative price ₹{rep_price:,.2f} "
                       "(from CUSTOMER_PRICING / OPTIMIZED_PRICING_MATRIX). Range = demand CI × price.")
        else:
            st.info("No representative selling price available for this scope to compute revenue.")
    else:
        st.info("Revenue forecast activates once a valid demand forecast exists.")
    divider()

    # ── 17. AI MARKET OPPORTUNITY DETECTOR ──
    section("💡", "AI Market Opportunity Detector")
    opp_signals = []
    if scope_fc and not scope_fc.get("insufficient") and scope_fc["slope"] > 0:
        opp_signals.append(f"Demand trending up {scope_fc['slope']:+.1f} units/mo for scope "
                           f"{f_product}/{f_customer}.")
    if f_product != "All Products" and not comp_df9.empty and {"SKU", "COMPETITOR_AVG_PRICE"}.issubset(comp_df9.columns):
        cr = comp_df9[comp_df9["SKU"] == f_product]
        op = _ndm_price_for_sku(f_product)
        if not cr.empty and op:
            g = safe_pct_change(op, float(cr["COMPETITOR_AVG_PRICE"].mean()))
            if g < -3:
                opp_signals.append(f"Priced {g:+.1f}% below competitor average — room to raise price.")
    if not cap_df9.empty and "AVAILABLE_CAPACITY" in cap_df9.columns and float(cap_df9["AVAILABLE_CAPACITY"].sum()) > 0:
        opp_signals.append(f"{cap_df9['AVAILABLE_CAPACITY'].sum():,.0f} units of spare capacity to fill.")
    if not psi_df9.empty and "PRICE_SENSITIVITY_INDEX" in psi_df9.columns:
        low_sens = psi_df9[psi_df9["PRICE_SENSITIVITY_INDEX"] < 0.4]
        if not low_sens.empty:
            opp_signals.append(f"{low_sens.shape[0]} low-price-sensitivity customer(s) — premium-pricing potential.")
    if opp_signals:
        opp_rows = []
        for raw in opp_signals:
            sig = ai_filter(f"Is this a significant market opportunity worth executive attention? {raw}",
                            cache_key=_ai_cache_key("ndm_opp_filter", raw))
            if sig is False:
                continue
            txt = ai_complete(
                f"Turn this signal into a JSON object with keys opportunity, target, reason, "
                f"impact, confidence (0-100), action. Signal: {raw}",
                cache_key=_ai_cache_key("ndm_opp_text", raw))
            obj = parse_ai_json(txt) if txt else None
            if isinstance(obj, dict):
                opp_rows.append({
                    "Opportunity": obj.get("opportunity", "Opportunity"),
                    "Product/Customer": obj.get("target", f_product),
                    "Business Reason": obj.get("reason", raw),
                    "Potential Impact": obj.get("impact", "—"),
                    "Confidence": f"{obj.get('confidence', 60)}%",
                    "Recommended Action": obj.get("action", "—")})
            else:
                opp_rows.append({"Opportunity": "Opportunity", "Product/Customer": f_product,
                                 "Business Reason": raw, "Potential Impact": "—",
                                 "Confidence": "—", "Recommended Action": "—"})
        if opp_rows:
            st.dataframe(pd.DataFrame(opp_rows), use_container_width=True, hide_index=True)
        else:
            st.info("No opportunities cleared the significance filter for this scope.")
    else:
        st.info("No opportunity signals detected from current data/scope.")
    divider()

    # ── 18. MARKET RISK DETECTOR ──
    section("⚠️", "Market Risk Intelligence")
    risk_signals = []
    if scope_fc and not scope_fc.get("insufficient"):
        if scope_fc["slope"] < 0:
            risk_signals.append(("Demand Decline", f_product,
                                 f"Demand trending down {scope_fc['slope']:+.1f} units/mo."))
        if scope_fc["r2"] < 0.3:
            risk_signals.append(("Demand Volatility", f_product,
                                 f"Low forecast fit (R² {scope_fc['r2']:.2f}) — unstable demand."))
    if has_demand and "CUSTOMER_ID" in demand_df.columns and demand_df["CUSTOMER_ID"].notna().any():
        share = demand_df.groupby("CUSTOMER_ID")["QUANTITY"].sum()
        if share.sum() > 0:
            top_share = share.max() / share.sum() * 100
            if top_share > 30:
                risk_signals.append(("Customer Dependency", share.idxmax(),
                                     f"Top customer is {top_share:.0f}% of total demand."))
    if not cap_df9.empty and "CURRENT_UTILIZATION" in cap_df9.columns:
        hot = cap_df9[cap_df9["CURRENT_UTILIZATION"] >= 90]
        if not hot.empty:
            risk_signals.append(("Capacity Constraint", "Plant",
                                 f"{hot.shape[0]} plant(s) at ≥90% utilization vs rising demand."))
    if risk_signals:
        risk_rows9 = []
        for rtype, target, detail in risk_signals:
            sev = ai_classify(
                f"Risk type {rtype}. Detail: {detail}. Classify severity.",
                ["Critical", "High", "Medium", "Low"],
                cache_key=_ai_cache_key("ndm_risk_sev", rtype, detail))
            act = ai_complete(
                f"One short recommended action (<15 words) for this market risk: {rtype}. {detail}",
                cache_key=_ai_cache_key("ndm_risk_act", rtype, detail))
            risk_rows9.append({
                "Risk": rtype, "Affected Product/Customer": target, "Severity": sev or "Medium",
                "Business Impact": detail, "Confidence": "AI", "Recommended Action": act or "Review"})
        st.dataframe(pd.DataFrame(risk_rows9), use_container_width=True, hide_index=True)
    else:
        st.info("No material market risks detected in the current scope.")
    divider()

    # ── 19. AI MARKET INTELLIGENCE BRIEF ──
    section("🧠", "AI Market Intelligence Brief")
    brief_facts = [
        f"Scope: product={f_product}, customer={f_customer}, region={f_region}, horizon={f_horizon}."]
    if scope_fc and not scope_fc.get("insufficient"):
        brief_facts += [
            f"Recent demand {scope_fc['recent']:,.0f}/mo, forecast avg {scope_fc['fc_avg']:,.0f}/mo, "
            f"trend slope {scope_fc['slope']:+.1f}, confidence {scope_fc['confidence']:.0f}%."]
    else:
        brief_facts.append("No demand forecast available (historical demand data not yet loaded).")
    if not cap_df9.empty and "AVAILABLE_CAPACITY" in cap_df9.columns:
        brief_facts.append(f"Spare capacity {cap_df9['AVAILABLE_CAPACITY'].sum():,.0f} units.")
    brief = ai_complete(
        "You are a senior pricing/market analyst. Write a concise market briefing (5-7 sentences) "
        "covering current demand situation, future outlook, revenue outlook, top growth and at-risk "
        "areas, competitive threat, capacity concern and pricing opportunity. Use ONLY these facts; "
        "do not invent numbers:\n" + "\n".join(brief_facts),
        cache_key=_ai_cache_key("ndm_brief", tuple(brief_facts)))
    if brief:
        # Unwrap accidental JSON-string / escaped-newline responses
        _b = brief.strip()
        if _b.startswith('"') and _b.endswith('"'):
            try:
                _b = json.loads(_b)
            except Exception:
                _b = _b.strip('"')
        st.write(_b.replace("\\n", "\n"))
    else:
        st.info("AI market brief unavailable — Cortex did not respond. See Cortex AI Diagnostics.")
    divider()

# ── 20. EXECUTIVE RECOMMENDATIONS ──
    section("✅", "Executive Recommendations")
    import re as _re

    _rec_raw = ai_complete(
        "Based on the facts below, produce 3-5 prioritized recommendations. Return ONLY a JSON array "
        "of objects with keys: priority (High/Medium/Low), category, action, reason, impact, "
        "confidence (0-100). No preamble, no markdown.\nFacts:\n" + "\n".join(brief_facts),
        cache_key=_ai_cache_key("ndm_recs_v2", tuple(brief_facts)))   # NOTE: new cache key

    # Parse: try helper, then extract the first [...] array from any prose.
    rec_json = parse_ai_json(_rec_raw)
    if not (isinstance(rec_json, list) and rec_json) and _rec_raw:
        m = _re.search(r"\[\s*\{.*\}\s*\]", _rec_raw, _re.DOTALL)
        if m:
            try:
                rec_json = json.loads(m.group(0))
            except Exception:
                rec_json = None

    rec_tbl = []
    if isinstance(rec_json, list):
        for r in rec_json:
            if isinstance(r, dict):
                try:
                    conf = float(str(r.get("confidence", 60)).strip().rstrip("%"))
                except Exception:
                    conf = 60.0
                rec_tbl.append({
                    "priority": str(r.get("priority", "Medium")).strip(),
                    "category": str(r.get("category", "—")).strip(),
                    "action": str(r.get("action") or r.get("recommendation") or "—").strip(),
                    "reason": str(r.get("reason", "—")).strip(),
                    "impact": str(r.get("impact", "—")).strip(),
                    "confidence": max(0.0, min(100.0, conf)),
                })

    if rec_tbl:
        _order = {"high": 0, "medium": 1, "low": 2}
        rec_tbl.sort(key=lambda x: _order.get(x["priority"].lower(), 1))
        _sty = {"high": ("#EF4444", "🔴", "rgba(239,68,68,0.10)"),
                "medium": ("#F59E0B", "🟡", "rgba(245,158,11,0.10)"),
                "low": ("#38BDF8", "🔵", "rgba(56,189,248,0.10)")}
        for r in rec_tbl:
            color, icon, bg = _sty.get(r["priority"].lower(), _sty["medium"])
            st.markdown(f"""
<div style="border:1px solid rgba(255,255,255,0.08); border-left:4px solid {color};
            background:{bg}; border-radius:10px; padding:14px 16px; margin-bottom:10px;">
  <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
    <span style="font-weight:600; color:#E6EDF3;">{icon} {r['action']}</span>
    <span style="font-size:12px; color:{color}; border:1px solid {color};
                 border-radius:20px; padding:2px 10px;">{r['priority'].upper()} · {r['category']}</span>
  </div>
  <div style="color:#9FB3C8; font-size:13px; margin-bottom:4px;"><b>Why:</b> {r['reason']}</div>
  <div style="color:#9FB3C8; font-size:13px; margin-bottom:8px;"><b>Impact:</b> {r['impact']}</div>
  <div style="background:rgba(255,255,255,0.06); border-radius:6px; height:6px; overflow:hidden;">
    <div style="width:{r['confidence']:.0f}%; height:6px; background:{color};"></div>
  </div>
  <div style="text-align:right; font-size:11px; color:#9FB3C8; margin-top:3px;">
    {r['confidence']:.0f}% confidence</div>
</div>
""", unsafe_allow_html=True)
    else:
        st.info("Could not parse structured recommendations.")
        with st.expander("🔧 Debug: raw Cortex response"):
            st.code(_rec_raw or "(empty)")
    divider()



    # ── 21. EXECUTIVE SUMMARY ──
    section("📋", "Executive Summary")
    summ = ai_summarize("\n".join(brief_facts),
                        cache_key=_ai_cache_key("ndm_exec_summary", tuple(brief_facts)))
    st.text_area(" ", ai_or_fallback(
        summ,
        "Demand Health: " + ("forecast available" if scope_fc and not scope_fc.get("insufficient")
                             else "awaiting real demand history") + "\n" + "\n".join(brief_facts)),
        height=220, key="ndm_exec_summary_box")
# ── 22. SAVED FORECAST HISTORY ──
    divider()
    section("📜", "Saved Forecast History")
    hist_fc = _ndm_load(
        "SELECT RUN_ID, SCOPE_PRODUCT, SCOPE_CUSTOMER, HORIZON, FORECAST_DATE, "
        "FORECAST_DEMAND, CONFIDENCE_PCT, FORECAST_REVENUE, CREATED_AT "
        "FROM PRICING_ENGINE_DB.CORE_OUTPUT.DEMAND_FORECAST_RESULTS "
        "ORDER BY CREATED_AT DESC LIMIT 100")
    if hist_fc is not None and not hist_fc.empty:
        st.dataframe(hist_fc, use_container_width=True, hide_index=True)
    else:
        st.info("No saved forecasts yet. Use 💾 Save Forecast to Snowflake above.")



# ══════════════════════════════════════════════════════════════════════
# TAB 10 — 🏛️ WORKFLOW & APPROVALS
# ══════════════════════════════════════════════════════════════════════
if _active_tab == "🏛️ Workflow & Approvals":
    section("🏛️", "Enterprise Workflow & Approval Engine")
    st.markdown('<div style="opacity:.75;margin-top:-6px">Governed, role-based, '
                'auditable multi-level approval lifecycle for every pricing and '
                'contract decision.</div>', unsafe_allow_html=True)

    _cu = get_current_user()
    _cr = get_user_role(_cu)
    st.caption(f"Signed in as **{_cu}** · application role **{_cr}**")
    if _cr == "UNASSIGNED":
        st.warning("Your Snowflake user has no active application role in "
                   "`CORE_INTERNAL.USER_ROLES`. Ask an ADMIN to assign one. "
                   "You can view public dashboards but cannot create or approve.")
    divider()

    _views = ["📊 Approval Dashboard", "📥 My Approval Queue", "➕ Submit Request",
              "🔍 Request Details", "📜 Audit Trail"]
    if can_admin_workflows(_cr):
        _views.append("⚙️ Workflow Administration")
    _wf_view = st.radio("Workflow view", _views, horizontal=True,
                        label_visibility="collapsed", key="wf_view_nav")
    divider()

    # ───────────────────────── 📊 DASHBOARD ─────────────────────────
    if _wf_view == "📊 Approval Dashboard":
        section("📊", "Approval Dashboard")
        allr = wf_load_requests()
        if allr.empty:
            st.info("No approval requests have been submitted yet.")
        else:
            pend   = allr[allr["STATUS"].isin(["SUBMITTED", "IN_REVIEW", "ESCALATED"])]
            today  = pd.Timestamp.utcnow().tz_localize(None).normalize()
            appr_t = allr[(allr["STATUS"] == "APPROVED") &
                          (pd.to_datetime(allr["APPROVED_AT"], errors="coerce") >= today)]
            rej_t  = allr[(allr["STATUS"] == "REJECTED") &
                          (pd.to_datetime(allr["REJECTED_AT"], errors="coerce") >= today)]
            overdue = pend[pd.to_datetime(pend["SLA_DUE_AT"], errors="coerce") <
                           pd.Timestamp.utcnow().tz_localize(None)]
            hi_pend = pend[pend["RISK_LEVEL"].isin(["HIGH", "CRITICAL"])]
            esc     = allr[allr["STATUS"] == "ESCALATED"]
            done    = allr[allr["STATUS"].isin(["APPROVED", "REJECTED"])]
            appr_rate = (len(allr[allr["STATUS"] == "APPROVED"]) / len(done) * 100) if len(done) else 0
            # Avg approval time (submitted → approved)
            appd = allr[allr["STATUS"] == "APPROVED"].copy()
            if not appd.empty:
                appd["_h"] = (pd.to_datetime(appd["APPROVED_AT"], errors="coerce") -
                              pd.to_datetime(appd["SUBMITTED_AT"], errors="coerce")).dt.total_seconds()/3600
                avg_h = appd["_h"].mean()
            else:
                avg_h = None

            k1,k2,k3,k4 = st.columns(4)
            k1.metric("Pending Approvals", f"{len(pend)}")
            k2.metric("Approved Today", f"{len(appr_t)}")
            k3.metric("Rejected Today", f"{len(rej_t)}")
            k4.metric("Overdue Requests", f"{len(overdue)}")
            k5,k6,k7,k8 = st.columns(4)
            k5.metric("Avg Approval Time", f"{avg_h:.0f}h" if avg_h is not None else "N/A")
            k6.metric("High-Risk Pending", f"{len(hi_pend)}")
            k7.metric("Escalated", f"{len(esc)}")
            k8.metric("Approval Rate", f"{appr_rate:.0f}%")
            divider()
            c1,c2 = st.columns(2)
            with c1:
                st.caption("Requests by Status")
                st.bar_chart(allr["STATUS"].value_counts(), height=240)
            with c2:
                st.caption("Requests by Type")
                st.bar_chart(allr["REQUEST_TYPE"].value_counts(), height=240)
            st.caption("Approvals by Role (from action history)")
            acts = wf_load_actions()
            if not acts.empty:
                appr_by_role = acts[acts["ACTION_TYPE"] == "APPROVED"]["ACTOR_ROLE"].value_counts()
                if not appr_by_role.empty:
                    st.bar_chart(appr_by_role, height=220)
            if not hi_pend.empty:
                st.caption("High-Risk Pending Requests")
                st.dataframe(hi_pend[["REQUEST_ID","REQUEST_TYPE","CUSTOMER_ID","FINANCIAL_IMPACT",
                                      "RISK_LEVEL","CURRENT_APPROVER"]],
                             use_container_width=True, hide_index=True)

    # ───────────────────────── 📥 MY QUEUE ─────────────────────────
    elif _wf_view == "📥 My Approval Queue":
        section("📥", "My Approval Queue")
        allr = wf_load_requests("WHERE STATUS IN ('SUBMITTED','IN_REVIEW','ESCALATED')")
        # Only requests this role is assigned to approve (ADMIN sees all)
        if _cr != "ADMIN":
            allr = allr[allr["CURRENT_APPROVER"].str.upper() == _cr.upper()] if not allr.empty else allr
        # Filters
        f1,f2,f3 = st.columns(3)
        with f1:
            tf = st.multiselect("Type", sorted(allr["REQUEST_TYPE"].unique()) if not allr.empty else [])
        with f2:
            pf = st.multiselect("Priority", ["URGENT","HIGH","NORMAL","LOW"])
        with f3:
            rf = st.multiselect("Risk", ["CRITICAL","HIGH","MEDIUM","LOW"])
        view = allr.copy()
        if tf: view = view[view["REQUEST_TYPE"].isin(tf)]
        if pf: view = view[view["PRIORITY"].isin(pf)]
        if rf: view = view[view["RISK_LEVEL"].isin(rf)]
        if view.empty:
            st.info("You currently have no requests awaiting your approval.")
        else:
            view = view.copy()
            view["SLA"] = view["SLA_DUE_AT"].apply(lambda d: wf_sla_status(d)[0])
            st.dataframe(
                view[["REQUEST_ID","REQUEST_TYPE","REQUESTER","CUSTOMER_ID","SKU",
                      "FINANCIAL_IMPACT","RISK_LEVEL","CURRENT_STAGE","SUBMITTED_AT",
                      "SLA","PRIORITY","STATUS"]],
                use_container_width=True, hide_index=True)
            pick = st.selectbox("Open a request", view["REQUEST_ID"].tolist(), key="wf_queue_pick")
            if st.button("🔍 Open in Request Details", use_container_width=True):
                st.session_state["workflow_selected_request"] = pick
                st.info(f"Selected {pick}. Switch to '🔍 Request Details'.")

    # ───────────────────────── ➕ SUBMIT ─────────────────────────
    elif _wf_view == "➕ Submit Request":
        section("➕", "Submit Approval Request")
        if not has_permission(_cr, "create"):
            st.error("Your role is not permitted to create approval requests.")
        else:
            pre = st.session_state.get("workflow_prefill") or {}
            types = ["PRICE_CHANGE","DISCOUNT_EXCEPTION","MARGIN_EXCEPTION","CONTRACT_APPROVAL",
                     "CONTRACT_RENEWAL","SIMULATION_RECOMMENDATION","MANUAL_REQUEST"]
            rtype = st.selectbox("Request Type", types,
                                 index=types.index(pre["REQUEST_TYPE"]) if pre.get("REQUEST_TYPE") in types else 0,
                                 key="wf_new_type")
            c1,c2 = st.columns(2)
            with c1:
                title = st.text_input("Title", pre.get("TITLE",""), key="wf_new_title")
                customer = st.text_input("Customer", pre.get("CUSTOMER_ID",""), key="wf_new_cust")
                sku = st.text_input("SKU", pre.get("SKU",""), key="wf_new_sku")
                contract = st.text_input("Contract ID (if any)", pre.get("CONTRACT_ID",""), key="wf_new_contract")
                priority = st.selectbox("Priority", ["NORMAL","HIGH","URGENT","LOW"], key="wf_new_prio")
            with c2:
                orig = st.number_input("Current / Original Value (₹)", value=float(pre.get("ORIGINAL_VALUE",0) or 0), key="wf_new_orig")
                prop = st.number_input("Proposed Value (₹)", value=float(pre.get("PROPOSED_VALUE",0) or 0), key="wf_new_prop")
                margin = st.number_input("Proposed Margin %", value=float(pre.get("MARGIN_PERCENT",0) or 0), key="wf_new_margin")
                discount = st.number_input("Discount %", value=float(pre.get("DISCOUNT_PERCENT",0) or 0), key="wf_new_disc")
            justification = st.text_area("Business Justification",
                                         pre.get("DESCRIPTION",""), key="wf_new_just", height=120)
            fin_impact = (prop - orig)
            payload = {"REQUEST_TYPE": rtype, "TITLE": title, "DESCRIPTION": justification,
                       "CUSTOMER_ID": customer, "SKU": sku, "CONTRACT_ID": contract,
                       "ORIGINAL_VALUE": orig, "PROPOSED_VALUE": prop, "FINANCIAL_IMPACT": fin_impact,
                       "MARGIN_PERCENT": margin, "DISCOUNT_PERCENT": discount, "PRIORITY": priority,
                       "REFERENCE_ID": pre.get("REFERENCE_ID",""), "metadata": pre.get("metadata", {})}
            # Pre-submit preview
            payload["RISK_LEVEL"] = wf_ai_risk_classify({**payload, "REQUEST_ID": "PREVIEW"})
            route = determine_approval_route(payload)
            divider()
            section("🧭", "Pre-Submission Review")
            pc1,pc2,pc3,pc4 = st.columns(4)
            pc1.metric("Financial Impact", f"₹{fin_impact:,.0f}")
            pc2.metric("Margin", f"{margin:.1f}%")
            pc3.metric("Discount", f"{discount:.1f}%")
            pc4.metric("AI Risk (advisory)", payload["RISK_LEVEL"])
            st.caption("Required approval route: " +
                       (" → ".join(f"{r['stage_name']} ({r['approver_role']})" for r in route)
                        if route else "No active workflow configured for this type."))
            st.info("AI recommendation is advisory only. Final approval requires an authorized human approver.")
            if st.button("🚀 Submit for Approval", use_container_width=True, key="wf_submit_btn"):
                ok, rid, _rt = wf_submit_new_request(payload, _cu, _cr)
                if ok:
                    st.session_state["workflow_submission_result"] = rid
                    st.session_state["workflow_selected_request"] = rid
                    st.session_state["workflow_prefill"] = None
                    st.success(f"✅ Submitted. Request ID **{rid}** routed to "
                               f"{route[0]['approver_role']}.")
                else:
                    st.error(f"Submission failed: {rid}")

    # ───────────────────────── 🔍 DETAILS ─────────────────────────
    elif _wf_view == "🔍 Request Details":
        section("🔍", "Request Details")
        allr = wf_load_requests()
        if allr.empty:
            st.info("No approval requests have been submitted yet.")
        else:
            sel = st.selectbox("Request", allr["REQUEST_ID"].tolist(),
                               index=(allr["REQUEST_ID"].tolist().index(st.session_state["workflow_selected_request"])
                                      if st.session_state.get("workflow_selected_request") in allr["REQUEST_ID"].tolist() else 0),
                               key="wf_detail_pick")
            req = wf_load_request(sel)
            if req:
                h1,h2,h3,h4 = st.columns(4)
                h1.metric("Status", req.get("STATUS"))
                h2.metric("Priority", req.get("PRIORITY"))
                h3.metric("Stage", f"{int(req.get('CURRENT_STAGE') or 1)}")
                h4.metric("Current Approver", req.get("CURRENT_APPROVER") or "—")
                sla_lbl, sla_col, sla_txt = wf_sla_status(req.get("SLA_DUE_AT"))
                st.markdown(health_bar_html(0 if "Overdue" in sla_lbl else 100,
                                            sla_col, f"SLA: {sla_lbl} · {sla_txt}"),
                            unsafe_allow_html=True)
                divider()
                section("📦", "Business Context")
                b1,b2,b3 = st.columns(3)
                b1.metric("Original Value", f"₹{float(req.get('ORIGINAL_VALUE') or 0):,.0f}")
                b2.metric("Proposed Value", f"₹{float(req.get('PROPOSED_VALUE') or 0):,.0f}")
                b3.metric("Financial Impact", f"₹{float(req.get('FINANCIAL_IMPACT') or 0):,.0f}")
                b4,b5,b6 = st.columns(3)
                b4.metric("Margin", f"{float(req.get('MARGIN_PERCENT') or 0):.1f}%")
                b5.metric("Discount", f"{float(req.get('DISCOUNT_PERCENT') or 0):.1f}%")
                b6.metric("Risk", req.get("RISK_LEVEL") or "—")
                st.write(f"**Customer:** {req.get('CUSTOMER_ID') or '—'}  ·  **SKU:** {req.get('SKU') or '—'}")
                st.write(f"**Justification:** {req.get('DESCRIPTION') or '—'}")
                divider()
                # Approval route visual
                section("🧭", "Approval Route")
                route = determine_approval_route(req)
                cur_stage = int(req.get("CURRENT_STAGE") or 1)
                marks = []
                for r in route:
                    if req.get("STATUS") == "APPROVED" or r["seq"] < cur_stage:
                        marks.append(f"✓ {r['stage_name']} ({r['approver_role']})")
                    elif r["seq"] == cur_stage and req.get("STATUS") in ("SUBMITTED","IN_REVIEW","ESCALATED"):
                        marks.append(f"● {r['stage_name']} ({r['approver_role']})")
                    else:
                        marks.append(f"○ {r['stage_name']} ({r['approver_role']})")
                st.write("  →  ".join(marks) if marks else "No configured route.")
                divider()
                # AI Approval Brief (advisory)
                section("🧠", "AI Approval Brief (advisory only)")
                brief = wf_ai_approval_brief(req)
                if brief:
                    st.write(brief)
                else:
                    st.info("AI Analysis Unavailable — approval can still proceed.")
                st.caption("⚠️ AI recommendation is advisory only. Final approval requires an authorized human approver.")
                divider()
                # Comments
                section("💬", "Comments & Decision History")
                cmts = wf_load_comments(sel)
                if not cmts.empty:
                    for _, c in cmts.iterrows():
                        st.markdown(f"**{c['USER_NAME']}** ({c['USER_ROLE']}) · {c['CREATED_AT']}<br>{c['COMMENT_TEXT']}",
                                    unsafe_allow_html=True)
                else:
                    st.caption("No comments yet.")
                divider()
                # Approver actions (server-side RBAC enforced in transition_request)
                section("🛠️", "Actions")
                if req.get("STATUS") in ("APPROVED","REJECTED","CANCELLED"):
                    st.info(f"This request is {req.get('STATUS')} — no further actions.")
                else:
                    comment = st.text_area("Comment / Justification", key="wf_action_comment")
                    a1,a2,a3,a4,a5 = st.columns(5)
                    def _do(action):
                        ok, msg = transition_request(sel, action, _cu, _cr, comment)
                        (st.success if ok else st.error)(msg)
                    with a1:
                        if st.button("✅ Approve", use_container_width=True):
                            _do("APPROVE_STAGE")
                    with a2:
                        if st.button("❌ Reject", use_container_width=True):
                            _do("REJECT")
                    with a3:
                        if st.button("↩ Return", use_container_width=True):
                            _do("RETURN")
                    with a4:
                        if st.button("⬆ Escalate", use_container_width=True):
                            if comment.strip():
                                wf_escalate(sel, _cr, "FINANCE_DIRECTOR", comment, _cu, _cr)
                                transition_request(sel, "ESCALATE", _cu, _cr, comment)
                                st.success("Escalated.")
                            else:
                                st.error("Escalation requires a comment.")
                    with a5:
                        if st.button("💬 Comment", use_container_width=True):
                            if comment.strip() and has_permission(_cr, "comment"):
                                wf_add_comment(sel, _cu, _cr, comment)
                                wf_log_action(sel, int(req.get("CURRENT_STAGE") or 1),
                                              "COMMENTED", _cu, _cr, comment,
                                              req.get("STATUS"), req.get("STATUS"))
                                st.success("Comment added.")
                            else:
                                st.error("Enter a comment first.")
                    # Digital signature (contracts, after final approval)
                    if req.get("REQUEST_TYPE") in ("CONTRACT_APPROVAL","CONTRACT_RENEWAL"):
                        divider()
                        section("✍️", "Digital Signature")
                        sig = check_signature_status(sel)
                        st.write(f"Signature status: **{sig}**")
                        if _WF_SIGNATURE_PROVIDER is None:
                            st.warning("Digital Signature Provider Not Configured — "
                                       "internal approval remains fully valid.")
                        if st.button("Request Signature", use_container_width=True):
                            s = request_signature(sel, _cu, _cr)
                            st.info(f"Signature request recorded: {s}")

    # ───────────────────────── 📜 AUDIT ─────────────────────────
    elif _wf_view == "📜 Audit Trail":
        section("📜", "Audit Trail")
        acts = wf_load_actions()
        if acts.empty:
            st.info("No workflow activity available.")
        else:
            f1,f2,f3 = st.columns(3)
            with f1:
                rid_f = st.text_input("Filter by Request ID", key="wf_audit_rid")
            with f2:
                act_f = st.multiselect("Action", sorted(acts["ACTION_TYPE"].unique()))
            with f3:
                usr_f = st.multiselect("User", sorted(acts["ACTOR"].unique()))
            view = acts.copy()
            if rid_f: view = view[view["REQUEST_ID"].str.contains(rid_f, case=False, na=False)]
            if act_f: view = view[view["ACTION_TYPE"].isin(act_f)]
            if usr_f: view = view[view["ACTOR"].isin(usr_f)]
            st.dataframe(view[["ACTION_TIMESTAMP","REQUEST_ID","STAGE_NUMBER","ACTION_TYPE",
                               "ACTOR","ACTOR_ROLE","PREVIOUS_STATUS","NEW_STATUS","COMMENTS"]],
                         use_container_width=True, hide_index=True)
            st.caption("Audit records are append-only and never modified or deleted.")

    # ───────────────────────── ⚙️ ADMIN ─────────────────────────
    elif _wf_view == "⚙️ Workflow Administration":
        if not can_admin_workflows(_cr):
            st.error("Administration is restricted to ADMIN users.")
        else:
            section("⚙️", "Workflow Administration")
            section("🧭", "Stage Configuration (read-only view)")
            st.dataframe(_wf_df(f"SELECT * FROM {_WF}.WORKFLOW_STAGES ORDER BY REQUEST_TYPE, STAGE_NUMBER"),
                         use_container_width=True, hide_index=True)
            st.caption("Edit routing by updating CORE_INTERNAL.WORKFLOW_STAGES. "
                       "Toggle a stage safely below (audited).")
            c1,c2,c3 = st.columns(3)
            with c1:
                wid = st.text_input("WORKFLOW_ID", key="wf_admin_wid")
            with c2:
                snum = st.number_input("STAGE_NUMBER", min_value=1, step=1, key="wf_admin_snum")
            with c3:
                active = st.selectbox("IS_ACTIVE", ["TRUE","FALSE"], key="wf_admin_active")
            if st.button("Apply stage toggle", use_container_width=True):
                ok, err = _wf_exec(f"""
                    UPDATE {_WF}.WORKFLOW_STAGES SET IS_ACTIVE={active}
                    WHERE WORKFLOW_ID='{_sql_escape(wid)}' AND STAGE_NUMBER={int(snum)}
                """)
                if ok:
                    wf_log_action("CONFIG", int(snum), "REASSIGNED", _cu, _cr,
                                  f"Set {wid} stage {int(snum)} IS_ACTIVE={active}", None, "CONFIG_CHANGE")
                    st.success("Stage updated and change audited.")
                else:
                    st.error(f"Update failed: {err}")
            divider()
            section("👥", "User–Role Mapping")
            st.dataframe(_wf_df(f"SELECT USER_NAME, ROLE_NAME, IS_ACTIVE FROM {_WF}.USER_ROLES ORDER BY USER_NAME"),
                         use_container_width=True, hide_index=True)
            u1,u2,u3 = st.columns(3)
            with u1: nu = st.text_input("User name", key="wf_admin_user")
            with u2: nr = st.selectbox("Role", list(_WF_PERMISSIONS.keys()), key="wf_admin_role")
            with u3: na = st.selectbox("Active", ["TRUE","FALSE"], key="wf_admin_uactive")
            if st.button("Upsert user role", use_container_width=True):
                _wf_exec(f"DELETE FROM {_WF}.USER_ROLES WHERE UPPER(USER_NAME)=UPPER('{_sql_escape(nu)}')")
                ok, err = _wf_exec(f"""
                    INSERT INTO {_WF}.USER_ROLES
                    (USER_NAME,ROLE_NAME,DISPLAY_NAME,EMAIL,IS_ACTIVE,CREATED_AT,UPDATED_AT)
                    VALUES ('{_sql_escape(nu)}','{_sql_escape(nr)}','{_sql_escape(nu)}',
                            NULL,{na},CURRENT_TIMESTAMP(),CURRENT_TIMESTAMP())
                """)
                if ok:
                    wf_log_action("CONFIG", 0, "REASSIGNED", _cu, _cr,
                                  f"Set {nu} → {nr} (active={na})", None, "ROLE_CHANGE")
                    st.success("Role mapping updated and audited.")
                else:
                    st.error(f"Failed: {err}")


# ──────────────────────────────────────────────
# FOOTER
# ──────────────────────────────────────────────

st.markdown("""
<div style="text-align:center;padding:32px 0 12px 0;color:#2A3A4A;font-size:11px;letter-spacing:0.5px;">
    PRICING INTELLIGENCE PLATFORM · POWERED BY SNOWFLAKE CORTEX AI · STREAMLIT-IN-SNOWFLAKE
</div>
""", unsafe_allow_html=True)