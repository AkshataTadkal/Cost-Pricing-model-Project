import json
import re
import urllib.request
from datetime import datetime
import uuid
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session
import plotly.express as px
import plotly.graph_objects as go

session = get_active_session()

PRICING_DB                 = "KMAT_PRICING"
PRICING_CORE_INPUT_SCHEMA  = "CORE_INPUT"
PRICING_CORE_OUTPUT_SCHEMA = "CORE_OUTPUT"

PRICING_TABLES = {
    "CUSTOMER_MASTER":          "CORE_INPUT",
    "QUOTE_HISTORY":            "CORE_OUTPUT",
    "PRICE_BREAKDOWN":          "CORE_OUTPUT",
    "PRICE_SIMULATION_SUMMARY": "CORE_OUTPUT",
    "APPROVAL_WORKFLOW":        "CORE_OUTPUT",
    "REVENUE_SCENARIOS":        "CORE_OUTPUT",
    "EXECUTIVE_INSIGHTS":       "CORE_OUTPUT",
    "COPILOT_ACTION_LEDGER":    "CORE_OUTPUT",
    "COPILOT_RISK_SCORES":      "CORE_OUTPUT",
    "COPILOT_ANOMALY_LOG":      "CORE_OUTPUT",
    "COPILOT_CONVERSATION_LOG": "CORE_OUTPUT",
}

def fq_pricing(logical_name):
    """Resolves a table name against KMAT_PRICING — always, regardless of
    which Cost Model database the onboarding wizard connected to."""
    schema = (
        PRICING_CORE_INPUT_SCHEMA
        if PRICING_TABLES.get(logical_name) == "CORE_INPUT"
        else PRICING_CORE_OUTPUT_SCHEMA
    )
    return f"{PRICING_DB}.{schema}.{logical_name}"
st.set_page_config(
    page_title="KMAT · Intelligent Pricing Command Center",
    page_icon="⬡",
    layout="wide",
    initial_sidebar_state="expanded"
)
# KMAT_COST_MODEL_DB is READ-ONLY. Only Cost Model entities belong here.
LOGICAL_KMAT_TABLES = {

    "KMAT_PRODUCT_MASTER":             "CORE_INPUT",
    "CHARACTERISTIC_MASTER":           "CORE_INPUT",
    "CHARACTERISTIC_VALUES":           "CORE_INPUT",
    "SIMULATION_HEADER":               "CORE_INPUT",
    "SIMULATION_PARAMETERS":           "CORE_INPUT",

    "KMAT_CONFIGURED_COST_SUMMARY":    "CORE_OUTPUT",
    "KMAT_CONFIGURED_COMPONENT_COSTS": "CORE_OUTPUT",
    "KMAT_CONFIGURED_OPERATION_COSTS": "CORE_OUTPUT",
    "KMAT_CONFIGURED_OVERHEAD_COSTS":  "CORE_OUTPUT",
}


def fq(logical_name):

    db = st.session_state.get("SF_DB")

    table_map = st.session_state.get("TABLE_MAP", {})

    actual_table = table_map.get(logical_name, logical_name)

    if LOGICAL_KMAT_TABLES.get(logical_name) == "CORE_INPUT":

        schema = st.session_state.get("CORE_INPUT_SCHEMA")

    elif LOGICAL_KMAT_TABLES.get(logical_name) == "CORE_OUTPUT":

        schema = st.session_state.get("CORE_OUTPUT_SCHEMA")

    else:

        schema = st.session_state.get("SF_APP_SCHEMA", "PUBLIC")

    return f"{db}.{schema}.{actual_table}"
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600&display=swap');

html, body, [data-testid="stAppViewContainer"] {
    background:
        radial-gradient(circle at 8% 12%, rgba(99,230,255,0.22) 0%, transparent 28%),
        radial-gradient(circle at 88% 8%, rgba(177,151,252,0.18) 0%, transparent 30%),
        radial-gradient(circle at 72% 86%, rgba(56,189,248,0.12) 0%, transparent 25%),
        linear-gradient(135deg, #06101E 0%, #0D1628 48%, #111B2D 100%) !important;
    color: #EEF6FF !important;
    font-family: 'Inter', sans-serif !important;
}

[data-testid="stHeader"] { background: transparent !important; }

[data-testid="stSidebar"] {
    background: linear-gradient(180deg, rgba(12,22,38,0.97), rgba(8,16,30,0.99)) !important;
    border-right: 1px solid rgba(255,255,255,0.10) !important;
}
[data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p,
[data-testid="stSidebar"] label,
[data-testid="stSidebar"] span {
    color: rgba(248,251,255,0.88) !important;
}

.block-container {
    padding-top: 1.4rem !important;
    padding-bottom: 2.6rem !important;
    max-width: 1440px !important;
}

/* ── Hero Banner ───────────────────────────────────── */
.glass-hero {
    position: relative;
    padding: 30px 36px;
    border-radius: 24px;
    border: 1px solid rgba(255,255,255,0.16);
    background: linear-gradient(135deg, rgba(255,255,255,0.14), rgba(255,255,255,0.05));
    box-shadow: 0 24px 64px rgba(0,0,0,0.32), inset 0 1px 0 rgba(255,255,255,0.10);
    backdrop-filter: blur(20px);
    overflow: hidden;
    margin-bottom: 26px;
}
.glass-hero::before {
    content: '';
    position: absolute;
    top: -80px; right: -80px;
    width: 260px; height: 260px;
    background: radial-gradient(circle, rgba(99,230,255,0.22) 0%, transparent 70%);
    border-radius: 50%;
}
.glass-hero::after {
    content: '';
    position: absolute;
    bottom: -60px; left: -40px;
    width: 180px; height: 180px;
    background: radial-gradient(circle, rgba(177,151,252,0.16) 0%, transparent 70%);
    border-radius: 50%;
}
.hero-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    background: linear-gradient(90deg, #63E6FF, #7EF7C4);
    color: #06101E;
    padding: 6px 14px;
    border-radius: 999px;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    margin-bottom: 14px;
}
.hero-title {
    font-size: clamp(24px, 3.5vw, 38px);
    font-weight: 900;
    color: #FFFFFF;
    margin: 0 0 8px 0;
    letter-spacing: -0.045em;
    line-height: 1.08;
}
.hero-subtitle {
    font-size: 14px;
    color: rgba(238,246,255,0.72);
    margin: 0 0 18px 0;
    line-height: 1.65;
    max-width: 720px;
}
.hero-pills {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
}
.hero-pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 999px;
    background: rgba(255,255,255,0.09);
    border: 1px solid rgba(255,255,255,0.15);
    color: rgba(238,246,255,0.88);
    font-size: 12px;
    font-weight: 600;
}

/* ── Section title ─────────────────────────────────── */
.section-title {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 18px;
    font-weight: 800;
    letter-spacing: -0.025em;
    color: #FFFFFF;
    margin: 1.2rem 0 0.85rem 0;
}
.section-title .dot {
    width: 10px; height: 10px;
    border-radius: 50%;
    background: linear-gradient(135deg, #63E6FF, #B197FC);
    box-shadow: 0 0 16px rgba(99,230,255,0.8);
    flex-shrink: 0;
}
.section-title::after {
    content: '';
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, rgba(255,255,255,0.12), transparent);
}

/* ── KPI / metric cards ────────────────────────────── */
[data-testid="metric-container"] {
    background: linear-gradient(145deg, rgba(255,255,255,0.12), rgba(255,255,255,0.05)) !important;
    border: 1px solid rgba(255,255,255,0.13) !important;
    border-radius: 20px !important;
    padding: 20px 22px !important;
    box-shadow: 0 16px 40px rgba(0,0,0,0.22), inset 0 1px 0 rgba(255,255,255,0.10) !important;
    backdrop-filter: blur(14px) !important;
    min-height: 110px !important;
}
[data-testid="metric-container"] label {
    color: rgba(238,246,255,0.60) !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    text-transform: uppercase !important;
    letter-spacing: 0.08em !important;
}
[data-testid="stMetricValue"] {
    color: #67E8F9 !important;
    font-size: 22px !important;
    font-weight: 800 !important;
    font-family: 'JetBrains Mono', monospace !important;
}
[data-testid="stMetricDelta"] { font-size: 12px !important; }

/* custom kpi card for raw HTML */
.kpi-glass{

position:relative;

padding:24px;

min-height:170px;

border-radius:24px;

background:

linear-gradient(
145deg,
rgba(255,255,255,.10),
rgba(255,255,255,.04)
);

border:1px solid rgba(255,255,255,.10);

backdrop-filter:blur(20px);

box-shadow:

0 20px 45px rgba(0,0,0,.30),

inset 0 1px rgba(255,255,255,.08);

transition:.3s;

overflow:hidden;

}
.kpi-glass::before{

content:"";

position:absolute;

top:0;

left:0;

width:100%;

height:4px;

background:var(--kpi-top);

}
.kpi-glass .kpi-label{

font-size:12px;

text-transform:uppercase;

letter-spacing:1.5px;

color:#8FA7C5;

font-weight:700;

}
.kpi-glass .kpi-value{

margin-top:18px;

font-size:38px;

font-weight:800;

font-family:'JetBrains Mono',monospace;

color:white;

}
.kpi-glass .kpi-sub {
    font-size: 12px;
    color: rgba(238,246,255,0.52);
    margin-top: 6px;
}
.kpi-glass:hover{

transform:

translateY(-5px);

box-shadow:

0 25px 50px rgba(0,0,0,.40);

}

/* ── Tabs ──────────────────────────────────────────── */
.stTabs [data-baseweb="tab-list"] {
    background: rgba(255,255,255,0.07) !important;
    border-radius: 18px !important;
    padding: 7px !important;
    gap: 5px !important;
    border: 1px solid rgba(255,255,255,0.11) !important;
}
.stTabs [data-baseweb="tab"] {
    background: transparent !important;
    color: rgba(238,246,255,0.68) !important;
    border-radius: 999px !important;
    font-size: 13px !important;
    font-weight: 600 !important;
    padding: 9px 18px !important;
    border: none !important;
    transition: all 0.18s ease !important;
}
.stTabs [aria-selected="true"] {
    background: linear-gradient(135deg, #38BDF8, #8B5CF6) !important;
    color: #FFFFFF !important;
    box-shadow: 0 8px 24px rgba(56,189,248,0.28) !important;
}
.stTabs [data-baseweb="tab-highlight"],
.stTabs [data-baseweb="tab-border"] { display: none !important; }

/* ── Buttons ───────────────────────────────────────── */
.stButton > button {
    background: linear-gradient(135deg, #38BDF8 0%, #8B5CF6 100%) !important;
    color: #FFFFFF !important;
    border: none !important;
    border-radius: 13px !important;
    font-weight: 700 !important;
    font-size: 14px !important;
    padding: 11px 22px !important;
    box-shadow: 0 10px 28px rgba(56,189,248,0.22) !important;
    transition: all 0.18s ease !important;
    font-family: 'Inter', sans-serif !important;
}
.stButton > button:hover {
    transform: translateY(-1px) !important;
    box-shadow: 0 14px 36px rgba(56,189,248,0.32) !important;
}

/* ── Inputs / selects ──────────────────────────────── */
.stSelectbox > div > div,
.stTextInput > div > div > input,
.stNumberInput > div > div > input,
.stTextArea textarea {
    background: rgba(255,255,255,0.07) !important;
    border: 1px solid rgba(255,255,255,0.13) !important;
    border-radius: 12px !important;
    color: #EAF4FF !important;
    font-family: 'Inter', sans-serif !important;
}
.stSlider [data-baseweb="slider"] div[role="slider"] {
    background: #67E8F9 !important;
    border-color: #67E8F9 !important;
}

/* ── Data tables ───────────────────────────────────── */
.stDataFrame, [data-testid="stDataFrame"] {
    border: 1px solid rgba(255,255,255,0.12) !important;
    border-radius: 16px !important;
    overflow: hidden !important;
    box-shadow: 0 12px 32px rgba(0,0,0,0.18) !important;
}
[data-testid="stDataFrame"] th {
    background: rgba(255,255,255,0.06) !important;
    color: rgba(238,246,255,0.65) !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    text-transform: uppercase !important;
    letter-spacing: 0.07em !important;
}

/* ── Expanders ─────────────────────────────────────── */
[data-testid="stExpander"] {
    border: 1px solid rgba(255,255,255,0.12) !important;
    border-radius: 16px !important;
    background: rgba(255,255,255,0.05) !important;
}
.streamlit-expanderContent {
    background: rgba(255,255,255,0.03) !important;
}

/* ── Alerts ────────────────────────────────────────── */
.stSuccess > div { border-radius: 14px !important; }
.stWarning > div { border-radius: 14px !important; }
.stError > div   { border-radius: 14px !important; }
.stInfo > div    { border-radius: 14px !important; }

/* ── Custom note boxes ─────────────────────────────── */
.note-soft {
    padding: 14px 18px;
    border-radius: 16px;
    background: rgba(99,230,255,0.08);
    border: 1px solid rgba(99,230,255,0.20);
    color: rgba(238,246,255,0.84);
    font-size: 13px;
    line-height: 1.6;
    margin: 8px 0;
}
.note-warn {
    padding: 14px 18px;
    border-radius: 16px;
    background: rgba(255,209,102,0.09);
    border: 1px solid rgba(255,209,102,0.22);
    color: rgba(255,245,220,0.90);
    font-size: 13px;
    line-height: 1.6;
    margin: 8px 0;
}
.note-ok {
    padding: 14px 18px;
    border-radius: 16px;
    background: rgba(126,247,196,0.08);
    border: 1px solid rgba(126,247,196,0.22);
    color: rgba(220,255,242,0.90);
    font-size: 13px;
    line-height: 1.6;
    margin: 8px 0;
}
.note-danger {
    padding: 14px 18px;
    border-radius: 16px;
    background: rgba(255,100,100,0.09);
    border: 1px solid rgba(255,100,100,0.22);
    color: rgba(255,230,230,0.90);
    font-size: 13px;
    line-height: 1.6;
    margin: 8px 0;
}

/* ── Config chips ──────────────────────────────────── */
.config-chip {
    padding: 16px 18px;
    border-radius: 18px;
    border: 1px solid rgba(255,255,255,0.14);
    background: rgba(255,255,255,0.07);
    margin-bottom: 6px;
}
.config-chip .chip-label {
    color: rgba(238,246,255,0.52);
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
}
.config-chip .chip-value {
    color: #FFFFFF;
    font-size: 16px;
    font-weight: 800;
    font-family: 'JetBrains Mono', monospace;
    margin-top: 4px;
}

/* ── Misc ──────────────────────────────────────────── */
h1, h2, h3, h4 { color: #FFFFFF !important; }
p, li { color: rgba(238,246,255,0.80); }
hr { border-color: rgba(255,255,255,0.10) !important; }
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.16); border-radius: 999px; }
#MainMenu { visibility: hidden; }
footer { visibility: hidden; }

/* ── Approval / routing badges (keep existing) ─────── */
.routing-badge {
    display: inline-flex; align-items: center; gap: 5px;
    padding: 4px 12px; border-radius: 8px; font-size: 11px; font-weight: 700;
    border: 1px solid;
}
.routing-auto     { background: rgba(16,185,129,0.15); color: #34d399; border-color: rgba(16,185,129,0.35); }
.routing-manager  { background: rgba(59,130,246,0.15); color: #60a5fa; border-color: rgba(59,130,246,0.35); }
.routing-director { background: rgba(245,158,11,0.15); color: #fbbf24; border-color: rgba(245,158,11,0.35); }
.routing-ceo      { background: rgba(239,68,68,0.15);  color: #f87171; border-color: rgba(239,68,68,0.35); }

.badge { display:inline-block; padding:3px 10px; border-radius:20px; font-size:11px; font-weight:700; }
.badge.green { background:rgba(16,185,129,0.15); color:#34d399; border:1px solid rgba(16,185,129,0.35); }
.badge.amber { background:rgba(245,158,11,0.15); color:#fbbf24; border:1px solid rgba(245,158,11,0.35); }
.badge.red   { background:rgba(239,68,68,0.15);  color:#f87171; border:1px solid rgba(239,68,68,0.35); }

.dot  { display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:6px; }
.dot.green { background:#10b981; box-shadow:0 0 6px #10b981; }
.dot.red   { background:#ef4444; box-shadow:0 0 6px #ef4444; }
.dot.amber { background:#f59e0b; box-shadow:0 0 6px #f59e0b; }

.health-bar-wrap { background:rgba(255,255,255,0.10); border-radius:6px; height:8px; margin:8px 0; overflow:hidden; }
.health-bar-fill { height:100%; border-radius:6px; transition:width 0.4s ease; }
.mono { font-family:'JetBrains Mono',monospace; }

/* ===========================================
   EXECUTIVE DASHBOARD PREMIUM KPI CARDS
=========================================== */

.exec-kpi-card{

    position:relative;
    overflow:hidden;

    min-height:180px;

    padding:24px;

    border-radius:24px;

    background:
        linear-gradient(
            145deg,
            rgba(255,255,255,.10),
            rgba(255,255,255,.04)
        );

    backdrop-filter:blur(22px);

    -webkit-backdrop-filter:blur(22px);

    border:1px solid rgba(255,255,255,.12);

    box-shadow:
        0 15px 40px rgba(0,0,0,.35),
        inset 0 1px 0 rgba(255,255,255,.08);

    transition:.35s ease;

    cursor:pointer;

}


/* hover animation */

.exec-kpi-card:hover{

    transform:translateY(-6px);

    border-color:rgba(99,230,255,.40);

    box-shadow:

        0 25px 55px rgba(0,0,0,.45),

        0 0 35px rgba(56,189,248,.18);

}


/* glowing top line */

.exec-kpi-card::before{

    content:"";

    position:absolute;

    left:0;
    top:0;

    width:100%;
    height:4px;

    background:

        linear-gradient(
            90deg,
            #38BDF8,
            #8B5CF6,
            #67E8F9
        );

}


/* glowing icon */

.exec-kpi-card::after{

    content:attr(data-icon);

    position:absolute;

    right:22px;
    top:18px;

    width:58px;
    height:58px;

    border-radius:18px;

    display:flex;

    align-items:center;

    justify-content:center;

    font-size:28px;

    background:rgba(255,255,255,.05);

    border:1px solid rgba(255,255,255,.08);

    box-shadow:

        0 0 18px rgba(56,189,248,.25);

}


/* label */

.ek-label{

    font-size:12px;

    text-transform:uppercase;

    letter-spacing:1.5px;

    color:#8FA7C5;

    font-weight:700;

}


/* big number */

.ek-value{

    margin-top:18px;

    font-size:38px;

    font-weight:800;

    color:white;

    letter-spacing:-1px;

    line-height:1;

    font-family:'JetBrains Mono', monospace;

}


/* subtitle */

.ek-sub{

    margin-top:14px;

    color:#AFC3D8;

    font-size:13px;

}


/* trend badge */

.ek-trend{

    display:inline-block;

    margin-top:18px;

    padding:

        7px 14px;

    border-radius:999px;

    font-size:12px;

    font-weight:700;

}


/* positive */

.ek-trend.up{

    color:#4ADE80;

    background:rgba(74,222,128,.12);

    border:1px solid rgba(74,222,128,.30);

}


/* negative */

.ek-trend.down{

    color:#F87171;

    background:rgba(248,113,113,.12);

    border:1px solid rgba(248,113,113,.30);

}


/* neutral */

.ek-trend.flat{

    color:#60A5FA;

    background:rgba(96,165,250,.12);

    border:1px solid rgba(96,165,250,.30);

}
.kpi-grid{

display:grid;

grid-template-columns:repeat(4,minmax(220px,1fr));

gap:18px;

margin:18px 0 30px 0;

align-items:stretch;

}
</style>
""", unsafe_allow_html=True)

# ---------------------------------------------------
# APP HEADER
# ---------------------------------------------------
st.markdown("""
<div class="glass-hero">
    <div class="hero-eyebrow">⬡ KMAT Intelligent Pricing</div>
    <h1 class="hero-title">Price Model for KMAT Products</h1>
    <p class="hero-subtitle">
        Configure products, run cost simulations, compare scenarios, govern approvals,
        and surface AI-powered pricing intelligence — all in one workspace.
    </p>
    <div class="hero-pills">
        <span class="hero-pill">⚙️ Product Configuration</span>
        <span class="hero-pill">💰 Margin & Leakage Engine</span>
        <span class="hero-pill">🔬 Scenario Comparison</span>
        <span class="hero-pill">🤖 AI Pricing Copilot</span>
        <span class="hero-pill">✅ Approval Workflow</span>
        <span class="hero-pill">🧬 Digital Twin</span>
    </div>
</div>
""", unsafe_allow_html=True)

# ---------------------------------------------------
# SIDEBAR — PRICING POLICY
# ---------------------------------------------------
with st.sidebar:
    st.markdown("""
    <div style="padding:16px 0 10px;border-bottom:1px solid rgba(255,255,255,0.10);margin-bottom:14px;">
        <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;
                    color:rgba(238,246,255,0.45);margin-bottom:4px;">Workspace</div>
        <div style="font-size:16px;font-weight:800;color:#FFFFFF;letter-spacing:-0.02em;">
            ⚙️ Pricing Policy Studio
        </div>
    </div>
    """, unsafe_allow_html=True)
 

    target_margin_pct = st.slider("Target Margin %", min_value=5, max_value=60, value=30, step=1)
    target_margin = target_margin_pct / 100

    floor_buffer_pct = st.slider("Floor Buffer %", min_value=5, max_value=30, value=15, step=1)
    ceiling_buffer_pct = st.slider("Ceiling Buffer %", min_value=5, max_value=30, value=10, step=1)

    st.markdown("---")
    st.markdown("### 🎯 Risk Thresholds")

    healthy_threshold = st.slider("Healthy Leakage Ceiling %", min_value=1, max_value=10, value=5, step=1)
    warning_threshold = st.slider("Warning Leakage Ceiling %", min_value=5, max_value=30, value=15, step=1)

    st.markdown("---")
    st.markdown("### ✅ Approval Thresholds")
    auto_approve_score    = st.slider("Auto-Approve Score ≥", 70, 100, 85, 1,
                                      help="Quotes scoring at or above this are auto-approved")
    manager_approve_score = st.slider("Manager Review Score ≥", 40, 85, 60, 1,
                                      help="Quotes between this and auto-approve go to Manager")
    director_score_floor  = st.slider("Director Review Score ≥", 10, 60, 35, 1,
                                      help="Quotes between this and manager go to Director")
    # Below director_score_floor → CEO / escalate

    st.markdown("---")
    st.markdown("### 📦 Volume Discount Tiers")
    st.caption("Define break-points and discount % per tier.")

    if "vol_tiers" not in st.session_state:
        st.session_state["vol_tiers"] = [
            {"min_qty": 1,   "max_qty": 19,  "discount_pct": 0.0},
            {"min_qty": 20,  "max_qty": 49,  "discount_pct": 1.5},
            {"min_qty": 50,  "max_qty": 99,  "discount_pct": 3.0},
            {"min_qty": 100, "max_qty": 9999,"discount_pct": 5.0},
        ]

    tiers = st.session_state["vol_tiers"]

    add_tier_col, reset_col = st.columns(2)
    with add_tier_col:
        if st.button("➕ Add Tier", use_container_width=True):
            last = tiers[-1]
            new_min = last["max_qty"] + 1 if last["max_qty"] < 9999 else last["min_qty"] + 50
            tiers.append({"min_qty": new_min, "max_qty": new_min + 49, "discount_pct": 0.0})
    with reset_col:
        if st.button("↺ Reset", use_container_width=True):
            st.session_state["vol_tiers"] = [
                {"min_qty": 1,   "max_qty": 19,  "discount_pct": 0.0},
                {"min_qty": 20,  "max_qty": 49,  "discount_pct": 1.5},
                {"min_qty": 50,  "max_qty": 99,  "discount_pct": 3.0},
                {"min_qty": 100, "max_qty": 9999,"discount_pct": 5.0},
            ]
            tiers = st.session_state["vol_tiers"]

    remove_idx = None
    for idx, tier in enumerate(tiers):
        with st.expander(f"Tier {idx+1}: qty ≥ {tier['min_qty']}  →  {tier['discount_pct']:.1f}%", expanded=False):
            c1, c2 = st.columns(2)
            with c1:
                tiers[idx]["min_qty"] = st.number_input("Min Qty", value=tier["min_qty"], min_value=1, step=1, key=f"tier_min_{idx}")
            with c2:
                max_val = tier["max_qty"] if tier["max_qty"] < 9999 else 9999
                tiers[idx]["max_qty"] = st.number_input("Max Qty (9999=∞)", value=max_val, min_value=1, step=1, key=f"tier_max_{idx}")
            tiers[idx]["discount_pct"] = st.slider("Discount %", 0.0, 50.0, tier["discount_pct"], 0.5, key=f"tier_disc_{idx}")
            if len(tiers) > 1:
                if st.button("🗑 Remove this tier", key=f"tier_rm_{idx}"):
                    remove_idx = idx

    if remove_idx is not None:
        st.session_state["vol_tiers"].pop(remove_idx)
        st.rerun()

    st.markdown("---")
    st.markdown("### 🔖 Display")
    currency_symbol = st.selectbox("Currency", ["₹", "$", "€", "£"], index=0)
    show_cost_waterfall = st.toggle("Show Cost Waterfall", value=True)
    show_margin_gauge   = st.toggle("Show Margin Gauge",   value=True)
    show_ai_insights    = st.toggle("AI Pricing Insights", value=True)

    st.markdown("---")
    st.caption(f"""
    Floor  = Mfg Cost × {1 + floor_buffer_pct/100:.2f}
    Target = Mfg Cost × {1 + target_margin:.2f}
    Ceiling = Target × {1 + ceiling_buffer_pct/100:.2f}
    """)

# ---------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------
def load_file(f):
    if f.name.endswith(".csv"):   return pd.read_csv(f)
    if f.name.endswith(".xlsx"):  return pd.read_excel(f)
    return None

def validate_columns(df, required):
    return [c for c in required if c not in df.columns]

def write_table_to_snowflake(df, logical_name):
    db = st.session_state.get("SF_DB", "KMAT_COST_MODEL_DB")
    schema = (
        st.session_state.get("CORE_INPUT_SCHEMA", "CORE_INPUT")
        if LOGICAL_KMAT_TABLES.get(logical_name) == "CORE_INPUT"
        else st.session_state.get("CORE_OUTPUT_SCHEMA", "CORE_OUTPUT")
    )
    tmap   = st.session_state.get("TABLE_MAP", {})
    actual = tmap.get(logical_name, logical_name)
    try:
        session.write_pandas(df, actual, database=db, schema=schema,
                             auto_create_table=True, overwrite=True)
        return True
    except Exception as e:
        st.error(f"Failed to write {actual}: {e}")
        return False

def fmt_currency(val):
    return f"{currency_symbol}{val:,.0f}"

def format_currency(df, columns):
    d = df.copy()
    for col in columns:
        if col in d.columns:
            d[col] = d[col].apply(lambda x: f"{currency_symbol}{x:,.2f}")
    return d

def classify_risk(x):
    if x < healthy_threshold:  return ("🟢 Healthy",  "green")
    if x < warning_threshold:  return ("🟡 Warning",  "amber")
    return ("🔴 High Risk", "red")

def get_volume_discount_pct(qty: int) -> tuple[float, int]:
    tiers = st.session_state.get("vol_tiers", [])
    for idx, tier in enumerate(sorted(tiers, key=lambda t: t["min_qty"], reverse=True)):
        if qty >= tier["min_qty"]:
            return float(tier["discount_pct"]), idx
    return 0.0, -1

def render_tier_table_html(qty: int) -> str:
    tiers = sorted(st.session_state.get("vol_tiers", []), key=lambda t: t["min_qty"])
    rows = ""
    for tier in tiers:
        max_label = "∞" if tier["max_qty"] >= 9999 else str(tier["max_qty"])
        active = tier["min_qty"] <= qty <= tier["max_qty"]
        cls = "active-tier" if active else ""
        marker = " ◀ current" if active else ""
        rows += f'<tr class="{cls}"><td>{tier["min_qty"]} – {max_label}</td><td>{tier["discount_pct"]:.1f}%{marker}</td></tr>'
    return f'<table class="tier-table"><thead><tr><th>Qty Range</th><th>Discount</th></tr></thead><tbody>{rows}</tbody></table>'
def executive_dashboard_card(
        title,
        value,
        subtitle,
        icon,
        status,
        glow="#38BDF8"
):
    return f"""
    <div class="exec-card">

        <div class="exec-header">

            <div class="exec-icon"
                 style="box-shadow:0 0 20px {glow};">
                {icon}
            </div>

            <div>

                <div class="exec-title">
                    {title}
                </div>

                <div class="exec-value">
                    {value}
                </div>

                <div class="exec-sub">
                    {subtitle}
                </div>

            </div>

        </div>

        <div class="exec-status">
            {status}
        </div>

    </div>
    """
def get_cost_breakdown_df(product_names):
    missing = []
    df = pd.DataFrame({"PRODUCT_NAME": product_names})

    try:
        material = session.sql(f"""
            SELECT b.PRODUCT_NAME, SUM(b.QUANTITY * m.COST) AS MATERIAL_COST
            FROM {fq('SUPER_BOM')} b
            JOIN {fq('MATERIAL_COST')} m ON b.COMPONENT = m.COMPONENT
            GROUP BY b.PRODUCT_NAME
        """).to_pandas()
    except Exception:
        missing.append("Material Cost")
        material = pd.DataFrame(columns=["PRODUCT_NAME","MATERIAL_COST"])

    try:
        machine = session.sql(f"""
            SELECT PRODUCT_NAME, SUM(MACHINE_HOURS * MACHINE_RATE) AS MACHINE_COST
            FROM {fq('MACHINE_COST')} GROUP BY PRODUCT_NAME
        """).to_pandas()
    except Exception:
        missing.append("Machine Cost")
        machine = pd.DataFrame(columns=["PRODUCT_NAME","MACHINE_COST"])

    try:
        setup = session.sql(f"""
            SELECT PRODUCT_NAME,
                   SUM((SETUP_HOURS * SETUP_RATE) / NULLIF(BATCH_SIZE,0)) AS SETUP_COST
            FROM {fq('SETUP_COST')} GROUP BY PRODUCT_NAME
        """).to_pandas()
    except Exception:
        missing.append("Setup Cost")
        setup = pd.DataFrame(columns=["PRODUCT_NAME","SETUP_COST"])

    for cdf in (material, machine, setup):
        df = df.merge(cdf, on="PRODUCT_NAME", how="left")

    for col in ["MATERIAL_COST","MACHINE_COST","SETUP_COST"]:
        df[col] = df.get(col, 0.0).fillna(0.0)

    direct = df["MATERIAL_COST"] + df["MACHINE_COST"] + df["SETUP_COST"]

    try:
        overhead = session.sql(f"SELECT PRODUCT_NAME, OVERHEAD_PCT FROM {fq('OVERHEAD_RATES')}").to_pandas()
        default_row = overhead[overhead["PRODUCT_NAME"] == "DEFAULT"]
        default_pct = float(default_row["OVERHEAD_PCT"].iloc[0]) if not default_row.empty else 0.0
        product_specific = overhead[overhead["PRODUCT_NAME"] != "DEFAULT"]
        df = df.merge(product_specific, on="PRODUCT_NAME", how="left")
        df["OVERHEAD_PCT"] = df["OVERHEAD_PCT"].fillna(default_pct)
    except Exception:
        missing.append("Overhead Rates")
        df["OVERHEAD_PCT"] = 0.0

    df["OVERHEAD_COST"] = direct * (df["OVERHEAD_PCT"] / 100.0)
    df["TOTAL_MANUFACTURING_COST"] = direct + df["OVERHEAD_COST"]
    return df, missing
def get_material_breakdown(product):
    try:
        return session.sql(f"""
            SELECT b.COMPONENT, b.QUANTITY, m.COST AS UNIT_COST, b.QUANTITY * m.COST AS LINE_COST
            FROM {fq('SUPER_BOM')} b
            JOIN {fq('MATERIAL_COST')} m ON b.COMPONENT = m.COMPONENT
            WHERE b.PRODUCT_NAME = ?
        """, params=[product]).to_pandas()
    except Exception:
        return pd.DataFrame()

def get_machine_breakdown(product):
    try:
        return session.sql(f"""
            SELECT MACHINE_NAME, MACHINE_HOURS, MACHINE_RATE, MACHINE_HOURS * MACHINE_RATE AS LINE_COST
            FROM {fq('MACHINE_COST')} WHERE PRODUCT_NAME = ?
        """, params=[product]).to_pandas()
    except Exception:
        return pd.DataFrame()

def get_setup_breakdown(product):
    try:
        return session.sql(f"""
            SELECT SETUP_NAME, SETUP_HOURS, SETUP_RATE, BATCH_SIZE,
                   (SETUP_HOURS * SETUP_RATE) / NULLIF(BATCH_SIZE,0) AS LINE_COST
            FROM {fq('SETUP_COST')} WHERE PRODUCT_NAME = ?
        """, params=[product]).to_pandas()
    except Exception:
        return pd.DataFrame()

def render_kpi(label, value, color="blue", delta=None, delta_label=""):
    top_map = {
        "blue":   "linear-gradient(90deg, #38BDF8, #8B5CF6)",
        "green":  "linear-gradient(90deg, #10b981, #34d399)",
        "amber":  "linear-gradient(90deg, #f59e0b, #fbbf24)",
        "red":    "linear-gradient(90deg, #ef4444, #f87171)",
        "purple": "linear-gradient(90deg, #8B5CF6, #B197FC)",
    }
    top = top_map.get(color, top_map["blue"])
    delta_html = ""
    if delta is not None:
        arrow = "▲" if delta >= 0 else "▼"
        d_color = "#34d399" if delta >= 0 else "#f87171"
        delta_html = f'<div style="font-size:12px;color:{d_color};margin-top:4px">{arrow} {abs(delta):.1f}% {delta_label}</div>'
    return f'''
    <div class="kpi-glass" style="--kpi-top:{top}">
        <div class="kpi-label">{label}</div>
        <div class="kpi-value">{value}</div>
        {delta_html}
    </div>'''

def price_band_html(floor, target, ceiling, actual, competitors=None):
    lo, hi = floor * 0.85, ceiling * 1.15
    if competitors:
        all_prices = [c["price"] for c in competitors] + [lo, hi]
        lo = min(lo, min(all_prices) * 0.95)
        hi = max(hi, max(all_prices) * 1.05)
    span = hi - lo if hi != lo else 1

    def pct(v):
        return max(0, min(100, (v - lo) / span * 100))

    fp, tp, cp, ap = pct(floor), pct(target), pct(ceiling), pct(actual)
    color = "#10b981" if floor <= actual <= ceiling else "#ef4444"

    comp_svg = ""
    comp_colors = ["#f472b6", "#fb923c", "#a78bfa", "#34d399", "#facc15"]
    legend_items = []
    if competitors:
        for i, comp in enumerate(competitors):
            cc = comp_colors[i % len(comp_colors)]
            cx = 10 + pct(comp["price"]) * 3.8
            comp_svg += f'<line x1="{cx:.1f}" y1="16" x2="{cx:.1f}" y2="32" stroke="{cc}" stroke-width="1.5" stroke-dasharray="3,2"/><circle cx="{cx:.1f}" cy="14" r="4" fill="{cc}" opacity="0.9"/>'
            legend_items.append((comp["name"], cc, comp["price"]))

    legend_html = ""
    if legend_items:
        items_html = "".join(
            f'<div class="comp-legend-item"><div class="comp-dot" style="background:{c};"></div><span>{n} — {fmt_currency(p)}</span></div>'
            for n, c, p in legend_items
        )
        legend_html = f'<div class="comp-legend">{items_html}</div>'

    return f"""
    <div class="gauge-wrap">
      <div style="font-size:12px;font-weight:600;color:#94a3b8;margin-bottom:10px;">PRICE POSITION GAUGE</div>
      <svg width="100%" height="52" viewBox="0 0 400 52" xmlns="http://www.w3.org/2000/svg">
        <rect x="10" y="20" width="380" height="12" rx="6" fill="#1e293b"/>
        <rect x="{10 + fp*3.8:.1f}" y="20" width="{(tp-fp)*3.8:.1f}" height="12" rx="4" fill="#10b981" opacity="0.25"/>
        <rect x="{10 + tp*3.8:.1f}" y="20" width="{(cp-tp)*3.8:.1f}" height="12" rx="4" fill="#3b82f6" opacity="0.25"/>
        {comp_svg}
        <line x1="{10 + fp*3.8:.1f}" y1="16" x2="{10 + fp*3.8:.1f}" y2="36" stroke="#10b981" stroke-width="2"/>
        <line x1="{10 + tp*3.8:.1f}" y1="14" x2="{10 + tp*3.8:.1f}" y2="38" stroke="#3b82f6" stroke-width="2"/>
        <line x1="{10 + cp*3.8:.1f}" y1="16" x2="{10 + cp*3.8:.1f}" y2="36" stroke="#f59e0b" stroke-width="2"/>
        <rect x="{10 + ap*3.8 - 3:.1f}" y="14" width="6" height="24" rx="3" fill="{color}" filter="drop-shadow(0 0 4px {color})"/>
        <text x="{10 + fp*3.8:.1f}" y="11" fill="#10b981" font-size="9" text-anchor="middle">Floor</text>
        <text x="{10 + tp*3.8:.1f}" y="11" fill="#3b82f6" font-size="9" text-anchor="middle">Target</text>
        <text x="{10 + cp*3.8:.1f}" y="11" fill="#f59e0b" font-size="9" text-anchor="middle">Ceiling</text>
        <text x="{10 + ap*3.8:.1f}" y="52" fill="{color}" font-size="9" text-anchor="middle" font-weight="bold">Quoted</text>
      </svg>
      {legend_html}
    </div>
    """

def compute_elasticity(base_price, base_demand, elasticity_coef, new_price):
    price_change_pct = (new_price - base_price) / base_price * 100
    demand_change_pct = elasticity_coef * price_change_pct
    new_demand = max(0.0, base_demand * (1 + demand_change_pct / 100))
    base_revenue = base_price * base_demand
    new_revenue  = new_price  * new_demand
    delta_revenue = new_revenue - base_revenue
    delta_revenue_pct = delta_revenue / base_revenue * 100 if base_revenue else 0
    return {
        "price_change_pct": price_change_pct, "demand_change_pct": demand_change_pct,
        "new_demand": new_demand, "base_revenue": base_revenue, "new_revenue": new_revenue,
        "delta_revenue": delta_revenue, "delta_revenue_pct": delta_revenue_pct,
    }

# ───────────────────────────────────────────────────
# QUOTE HEALTH SCORING ENGINE
# ───────────────────────────────────────────────────
def compute_quote_health_score(
    achieved_margin, target_margin_pct,
    leakage_percent, healthy_threshold, warning_threshold,
    actual_price, floor_price, ceiling_price,
    volume_discount_pct, manual_discount_pct,
    competitor_data=None
) -> dict:
    """
    Returns a 0-100 health score with component breakdown and routing decision.
    """
    score = 0
    components = {}

    # 1. Margin component (40 pts)
    margin_ratio = achieved_margin / max(1, target_margin_pct)
    margin_pts = min(40, margin_ratio * 40)
    score += margin_pts
    components["Margin Achievement"] = round(margin_pts, 1)

    # 2. Leakage component (30 pts)
    if leakage_percent <= 0:
        leak_pts = 30
    elif leakage_percent < healthy_threshold:
        leak_pts = 30 * (1 - leakage_percent / healthy_threshold)
    elif leakage_percent < warning_threshold:
        leak_pts = 10 * (1 - (leakage_percent - healthy_threshold) / (warning_threshold - healthy_threshold))
    else:
        leak_pts = 0
    leak_pts = max(0, leak_pts)
    score += leak_pts
    components["Leakage Control"] = round(leak_pts, 1)

    # 3. Price band adherence (20 pts)
    if floor_price <= actual_price <= ceiling_price:
        band_pts = 20
    elif actual_price < floor_price:
        band_pts = 0
    else:
        overshoot = (actual_price - ceiling_price) / ceiling_price * 100
        band_pts = max(0, 20 - overshoot * 2)
    score += band_pts
    components["Price Band Adherence"] = round(band_pts, 1)

    # 4. Competitive positioning (10 pts)
    if competitor_data and len(competitor_data) > 0:
        avg_comp = sum(c["price"] for c in competitor_data) / len(competitor_data)
        vs_mkt = (actual_price - avg_comp) / avg_comp * 100
        if -10 <= vs_mkt <= 15:
            comp_pts = 10
        elif vs_mkt < -10:
            comp_pts = max(0, 10 + vs_mkt)
        else:
            comp_pts = max(0, 10 - (vs_mkt - 15) * 0.5)
        components["Competitive Position"] = round(comp_pts, 1)
    else:
        comp_pts = 5  # neutral when no data
        components["Competitive Position"] = 5.0

    score += comp_pts
    total_score = min(100, max(0, round(score, 1)))

    # Routing decision
    if total_score >= auto_approve_score:
        routing = "AUTO-APPROVE"
        routing_class = "routing-auto"
        routing_icon = "✅"
        routing_desc = "Meets all thresholds — auto-approved"
    elif total_score >= manager_approve_score:
        routing = "MANAGER REVIEW"
        routing_class = "routing-manager"
        routing_icon = "👤"
        routing_desc = "Requires Sales Manager sign-off"
    elif total_score >= director_score_floor:
        routing = "DIRECTOR REVIEW"
        routing_class = "routing-director"
        routing_icon = "🏢"
        routing_desc = "Requires Commercial Director approval"
    else:
        routing = "CEO / ESCALATE"
        routing_class = "routing-ceo"
        routing_icon = "🚨"
        routing_desc = "Critical — requires C-suite or deal committee"

    # Score color
    if total_score >= 70:
        score_cls = "score-green"
    elif total_score >= 40:
        score_cls = "score-amber"
    else:
        score_cls = "score-red"

    return {
        "total_score": total_score,
        "components": components,
        "routing": routing,
        "routing_class": routing_class,
        "routing_icon": routing_icon,
        "routing_desc": routing_desc,
        "score_cls": score_cls,
    }


# ---------------------------------------------------
# GEMINI INTEGRATION
# ---------------------------------------------------
import requests

def call_gemini(api_key: str, model: str, prompt: str) -> dict:
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{model}:generateContent?key={api_key}")
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 1200}
    }
    try:
        response = requests.post(url, headers={"Content-Type": "application/json"}, json=payload, timeout=30)
        if response.status_code != 200:
            return {"error": f"HTTP {response.status_code}\n{response.text}"}
        body = response.json()
        raw_text = body["candidates"][0]["content"]["parts"][0]["text"]
        match = re.search(r"\{.*\}", raw_text, re.DOTALL)
        parsed = json.loads(match.group(0)) if match else {}
        return {
            "recommended_price": parsed.get("recommended_price", "N/A"),
            "leakage_cause": parsed.get("leakage_cause", "N/A"),
            "margin_risk": parsed.get("margin_risk", "N/A"),
            "competitor_analysis": parsed.get("competitor_analysis", "N/A"),
            "executive_summary": parsed.get("executive_summary", "N/A"),
            "confidence": parsed.get("confidence", "Medium"),
            "raw_text": raw_text, "error": None,
            # exec dashboard fields
            "headline": parsed.get("headline",""),
            "critical_risk": parsed.get("critical_risk",""),
            "top_opportunity": parsed.get("top_opportunity",""),
            "margin_outlook": parsed.get("margin_outlook",""),
            "recommended_actions": parsed.get("recommended_actions",""),
            "portfolio_health_score": parsed.get("portfolio_health_score","N/A"),
            "health_label": parsed.get("health_label",""),
            # approval AI fields
            "approval_recommendation": parsed.get("approval_recommendation",""),
            "risk_factors": parsed.get("risk_factors",""),
            "negotiation_guidance": parsed.get("negotiation_guidance",""),
            "conditions": parsed.get("conditions",""),
        }
    except Exception as e:
        return {"error": str(e)}


def build_copilot_prompt(
    product, currency_symbol, material_cost, machine_cost, setup_cost, overhead_cost, total_mfg_cost,
    base_price, total_surcharge, floor_price, target_price, ceiling_price, actual_price,
    achieved_margin, target_margin_pct, leakage, leakage_percent, order_qty,
    volume_discount_pct, manual_discount_pct, competitor_data, selected_options,
    healthy_threshold, warning_threshold, floor_buffer_pct=15,
) -> str:
    comp_block = ""
    if competitor_data:
        comp_lines = "\n".join(f"  - {c['name']}: {currency_symbol}{c['price']:,.0f}" for c in competitor_data)
        avg_comp   = sum(c["price"] for c in competitor_data) / len(competitor_data)
        vs_market  = (actual_price - avg_comp) / avg_comp * 100
        comp_block = f"Competitor Prices:\n{comp_lines}\nMarket Average: {currency_symbol}{avg_comp:,.0f}\nOur price vs market: {vs_market:+.1f}%"
    else:
        comp_block = "Competitor Prices: Not provided."
    opts_block = ", ".join(f"{k}: {', '.join(v) if isinstance(v, list) else v}" for k, v in selected_options.items()) or "None"
    return f"""You are an expert B2B manufacturing pricing strategist. Analyse this quote and respond ONLY with a JSON object (no markdown, no text outside the JSON block).

=== QUOTE CONTEXT ===
Product: {product} | Currency: {currency_symbol} | Order Quantity: {order_qty} units | Selected Options: {opts_block}

=== COST STRUCTURE ===
Material: {currency_symbol}{material_cost:,.0f} | Machine: {currency_symbol}{machine_cost:,.0f} | Setup: {currency_symbol}{setup_cost:,.0f} | Overhead: {currency_symbol}{overhead_cost:,.0f} | Total Mfg: {currency_symbol}{total_mfg_cost:,.0f}

=== PRICING BANDS ===
Floor: {currency_symbol}{floor_price:,.0f} | Target: {currency_symbol}{target_price:,.0f} | Ceiling: {currency_symbol}{ceiling_price:,.0f} | Quoted: {currency_symbol}{actual_price:,.0f}

=== PERFORMANCE ===
Achieved Margin: {achieved_margin:.1f}% (target: {target_margin_pct}%) | Leakage: {currency_symbol}{leakage:,.0f} ({leakage_percent:.1f}%)
Volume Discount: {volume_discount_pct:.1f}% | Manual Discount: {manual_discount_pct:.1f}%
Leakage Thresholds: Healthy < {healthy_threshold}% | High Risk > {warning_threshold}%

=== MARKET DATA ===
{comp_block}

Respond ONLY with:
{{"recommended_price":"<symbol+number>","leakage_cause":"<2-3 sentences>","margin_risk":"<High/Medium/Low> — <explanation>","competitor_analysis":"<2-3 sentences>","executive_summary":"<4-5 sentences>","confidence":"<High/Medium/Low>"}}"""


def render_copilot_result(result: dict, currency_symbol: str):
    if result.get("error"):
        st.markdown(f'<div class="insight-box alert">🚨 Gemini API error: {result["error"]}</div>', unsafe_allow_html=True)
        return
    risk_level = result.get("margin_risk", "").split("—")[0].strip().lower()
    risk_class = "ai-risk-high" if "high" in risk_level else ("ai-risk-medium" if "medium" in risk_level else "ai-risk-low")
    risk_icon  = "🔴" if "high" in risk_level else ("🟡" if "medium" in risk_level else "🟢")
    ts = datetime.now().strftime("%H:%M:%S")
    st.markdown(f"""
    <div class="copilot-panel">
      <div class="copilot-header">
        <div class="copilot-icon">🤖</div>
        <div><div class="copilot-title">AI Pricing Copilot</div><div class="copilot-sub">AI Pricing Assistant · {result.get("confidence","High")} Confidence</div></div>
      </div>
      <div class="copilot-body">
        <div class="ai-section"><div class="ai-section-label">⭐ Recommended Price</div>
          <div class="ai-section-value"><span class="ai-price-highlight">{result['recommended_price']}</span></div></div>
        <div class="ai-section"><div class="ai-section-label">💧 Leakage Cause Analysis</div>
          <div class="ai-section-value">{result['leakage_cause']}</div></div>
        <div class="ai-section"><div class="ai-section-label">⚠️ Margin Risk</div>
          <div class="ai-section-value"><span class="{risk_class}">{risk_icon} {result['margin_risk']}</span></div></div>
        <div class="ai-section"><div class="ai-section-label">🏁 Competitor Analysis</div>
          <div class="ai-section-value">{result['competitor_analysis']}</div></div>
        <div class="ai-section" style="border-color:rgba(6,182,212,0.3);background:rgba(6,182,212,0.04);">
          <div class="ai-section-label" style="color:#34d399;">📋 Executive Summary</div>
          <div class="ai-section-value" style="line-height:1.75;">{result['executive_summary']}</div></div>
      </div>
      <div class="copilot-footer"><span>Generated at {ts}</span><div class="gemini-badge">✦ AI INSIGHTS</div></div>
    </div>
    """, unsafe_allow_html=True)

import random
import pandas as pd
from datetime import datetime, timedelta


def generate_demo_quotes(n_quotes=100):

    product_df = session.table(fq("KMAT_PRODUCT_MASTER")).to_pandas()

    sim_df = session.table(fq("SIMULATION_HEADER")).to_pandas()

    summary_df = session.table(
        fq("KMAT_CONFIGURED_COST_SUMMARY")
    ).to_pandas()

    quote_rows = []

    for _ in range(n_quotes):

        sim = sim_df.sample(1).iloc[0]

        summary = summary_df[
            summary_df["SIMULATION_ID"] == sim["SIMULATION_ID"]
        ].iloc[0]

        product = product_df[
            product_df["KMAT_ID"] == sim["KMAT_ID"]
        ].iloc[0]

        total_cost = float(summary["TOTAL_CONFIGURED_COST_USD"])

        target = float(summary["TARGET_PRICE_USD"])

        floor = float(summary["FLOOR_PRICE_USD"])

        ceiling = float(summary["CEILING_PRICE_USD"])

        actual = random.uniform(floor, ceiling)

        leakage = max(target - actual, 0)

        margin = ((actual - total_cost) / actual) * 100

        qty = random.randint(5, 500)

        approval = (
            "Auto Approval"
            if margin >= 20
            else "Manager Approval"
            if margin >= 12
            else "Finance Review"
        )

        quote_rows.append({

            "QUOTE_ID":
                f"Q{1000+_}",

            "QUOTE_DATE":
                datetime.now() - timedelta(days=random.randint(0,90)),

            "CUSTOMER_NAME":
                f"Customer {random.randint(1,20)}",

            "PRODUCT":
                product["DESCRIPTION"],

            "KMAT_ID":
                sim["KMAT_ID"],

            "SIMULATION_ID":
                sim["SIMULATION_ID"],

            "ORDER_QTY":
                qty,

            "TARGET_PRICE":
                round(target,2),

            "ACTUAL_PRICE":
                round(actual,2),

            "TOTAL_MANUFACTURING_COST":
                round(total_cost,2),

            "LEAKAGE":
                round(leakage,2),

            "MARGIN_PCT":
                round(margin,2),

            "HEALTH_SCORE":
                random.randint(70,100),

            "APPROVAL_STATUS":
                approval

        })

        df = pd.DataFrame(quote_rows)
        df = df.rename(columns={"QUOTE_DATE": "TIMESTAMP"})
    
        session.write_pandas(
            df,
            "QUOTE_HISTORY",
            database=PRICING_DB,
            schema=PRICING_CORE_OUTPUT_SCHEMA,
            overwrite=False,
            auto_create_table=True
        )
    
        st.success(f"{len(df)} demo quotes generated.")
# ---------------------------------------------------
# MAIN TABS
# ---------------------------------------------------
tab1, tab2, tab3, tab4, tab5, tab7,tab8= st.tabs([
    "⚙️  Customer Onboarding",
    "💰  Configure Quote",
    "📊  Analytics",
    "🔬  Scenario Comparison",
    "🏢  Executive Dashboard",
    "🌐  Digital Twin",
    "🤖  AI Pricing Copilot",
])
def upload_card(title, icon, description):

    st.markdown(f"""
    <div class="upload-card">

        <div class="upload-icon">{icon}</div>

        <div class="upload-title">
            {title}
        </div>

        <div class="upload-desc">
            {description}
        </div>

    </div>
    """, unsafe_allow_html=True)


# ===================================================
# TAB 1 — DATA SETUP
# ===================================================
with tab1:

    LOGICAL_ENTITIES = {

        "KMAT_PRODUCT_MASTER": [
            "KMAT_ID",
            "DESCRIPTION",
            "PRODUCT_FAMILY",
            "ACTIVE_FLAG"
        ],

        "CHARACTERISTIC_MASTER": [
            "KMAT_ID",
            "CHARACTERISTIC_NAME",
            "ALLOWED_VALUE",
            "DISPLAY_ORDER",
            "ACTIVE_FLAG"
        ],

        "CHARACTERISTIC_VALUES": [
            "SIMULATION_ID",
            "KMAT_ID",
            "CHARACTERISTIC_NAME",
            "SELECTED_VALUE"
        ],

        "SIMULATION_HEADER": [
            "SIMULATION_ID",
            "KMAT_ID",
            "CUSTOMER_ID",
            "SCENARIO_NAME"
        ],

        "SIMULATION_PARAMETERS": [
            "SIMULATION_ID",
            "TARGET_MARGIN_PCT",
            "FLOOR_MARKUP_PCT",
            "CEILING_MARKUP_PCT"
        ],

        "KMAT_CONFIGURED_COST_SUMMARY": [
            "SIMULATION_ID",
            "KMAT_ID",
            "TOTAL_CONFIGURED_COST_USD",
            "TARGET_PRICE_USD"
        ],

        "KMAT_CONFIGURED_COMPONENT_COSTS": [
            "SIMULATION_ID",
            "COMPONENT_ID",
            "LINE_MATERIAL_COST_USD"
        ],

        "KMAT_CONFIGURED_OPERATION_COSTS": [
            "SIMULATION_ID",
            "OPERATION_ID",
            "LABOR_COST_USD",
            "MACHINE_COST_USD"
        ],

        "KMAT_CONFIGURED_OVERHEAD_COSTS": [
            "SIMULATION_ID",
            "OVERHEAD_ID",
            "OVERHEAD_COST_USD"
        ]
    }

    # ── STANDALONE ENTITY DEFINITIONS (used only in Standalone Pricing mode) ──
    STANDALONE_ENTITIES = {

        "KMAT_PRODUCT_MASTER": {
            "label": "Product Master",
            "required": True,
            "cols": [
                "KMAT_ID",
                "PRODUCT_NAME",
                "PRODUCT_FAMILY"
            ]
        },

        "CHARACTERISTIC_MASTER": {
            "label": "Characteristic Master",
            "required": True,
            "cols": [
                "KMAT_ID",
                "CHARACTERISTIC_NAME",
                "ALLOWED_VALUE"
            ]
        },

        "CHARACTERISTIC_VALUES": {
            "label": "Characteristic Values",
            "required": True,
            "cols": [
                "SIMULATION_ID",
                "KMAT_ID",
                "CHARACTERISTIC_NAME",
                "SELECTED_VALUE"
            ]
        },

        "QUOTE_HISTORY": {
            "label": "Quote History",
            "required": False,
            "cols": [
                "QUOTE_ID"
            ]
        }

    }
    # ── STANDALONE SCHEMA ROLE MAP ──────────────────────────────────
    STANDALONE_ENTITY_SCHEMA_ROLE = {

        "KMAT_PRODUCT_MASTER": "input",

        "CHARACTERISTIC_MASTER": "input",

        "CHARACTERISTIC_VALUES": "input",

        "QUOTE_HISTORY": "output"

    }

    # ── AUTO-DETECTION ALIASES ────────────────────────────────────────
    ENTITY_ALIASES = {

        "KMAT_PRODUCT_MASTER":[
            "KMAT_PRODUCT_MASTER"
        ],

        "CHARACTERISTIC_MASTER":[
            "CHARACTERISTIC_MASTER"
        ],

        "CHARACTERISTIC_VALUES":[
            "CHARACTERISTIC_VALUES"
        ],

        "SIMULATION_HEADER":[
            "SIMULATION_HEADER"
        ],

        "SIMULATION_PARAMETERS":[
            "SIMULATION_PARAMETERS"
        ],

        "KMAT_CONFIGURED_COST_SUMMARY":[
            "KMAT_CONFIGURED_COST_SUMMARY",
            "VW_COST_SUMMARY"
        ],

        "KMAT_CONFIGURED_COMPONENT_COSTS":[
            "KMAT_CONFIGURED_COMPONENT_COSTS",
            "VW_COMPONENT_COSTS"
        ],

        "KMAT_CONFIGURED_OPERATION_COSTS":[
            "KMAT_CONFIGURED_OPERATION_COSTS",
            "VW_OPERATION_COSTS"
        ],

        "KMAT_CONFIGURED_OVERHEAD_COSTS":[
            "KMAT_CONFIGURED_OVERHEAD_COSTS",
            "VW_OVERHEAD_COSTS"
        ],

        # ── Standalone Pricing aliases ──
        "QUOTE_HISTORY":[
            "QUOTE_HISTORY"
        ]

    }



    SKIP_OPTION = "— None of these —"

    # ══════════════════════════════════════════════════════════════════
    # PREMIUM UI LAYER — styling + layout helpers only. No business logic,
    # query, or session_state key lives below. Every generated HTML
    # fragment is a SINGLE line (no internal newlines) — concatenating
    # multi-line indented HTML is what causes Streamlit's markdown
    # renderer to leak raw "<div>" tags onto the page.
    # Requires Streamlit >= 1.32 (st.container(key=...) + border=True).
    # ══════════════════════════════════════════════════════════════════
    st.markdown("""
    <style>
    .kmat-header{margin:6px 0 22px 0;}
    .kmat-header-top{display:flex;align-items:center;gap:10px;}
    .kmat-header-icon{font-size:22px;line-height:1;}
    .kmat-header-title{font-size:22px;font-weight:700;color:#f1f5f9;letter-spacing:.2px;}
    .kmat-header-sub{font-size:13px;color:#8b98ac;margin-top:2px;margin-left:32px;}
    .kmat-header-rule{height:2px;margin-top:14px;border-radius:2px;background:linear-gradient(90deg,#3b82f6 0%,#8b5cf6 45%,rgba(139,92,246,0) 100%);}
    .kmat-card-title{font-size:14.5px;font-weight:700;color:#e2e8f0;text-transform:uppercase;letter-spacing:.6px;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid rgba(148,163,184,0.14);}
    div[data-testid="stVerticalBlockBorderWrapper"]{border-radius:16px !important;transition:transform .18s ease, box-shadow .18s ease, border-color .18s ease;background:linear-gradient(180deg, rgba(30,41,59,0.55) 0%, rgba(17,24,39,0.55) 100%);backdrop-filter:blur(6px);border:1px solid rgba(148,163,184,0.14) !important;}
    div[data-testid="stVerticalBlockBorderWrapper"]:hover{transform:translateY(-2px);border-color:rgba(139,92,246,0.5) !important;box-shadow:0 10px 30px rgba(59,130,246,0.12), 0 0 0 1px rgba(139,92,246,0.15);}

    /* Hero */
    .st-key-hero_banner{border-radius:24px !important;padding:32px 30px !important;background:linear-gradient(135deg, rgba(59,130,246,0.16) 0%, rgba(139,92,246,0.14) 55%, rgba(16,185,129,0.06) 100%) !important;border:1px solid rgba(139,92,246,0.34) !important;margin-bottom:26px !important;}
    .st-key-hero_banner:hover{transform:none;}
    .kmat-hero-title{font-size:30px;font-weight:800;color:#f8fafc;letter-spacing:.2px;}
    .kmat-hero-sub{font-size:14px;color:#a8b3c4;margin-top:6px;margin-bottom:18px;}

    /* Mode / source selection cards */
    .kmat-select-icon{font-size:30px;}
    .kmat-select-title{font-size:16px;font-weight:700;color:#f1f5f9;margin-top:8px;}
    .kmat-select-tag{font-size:11px;color:#8b98ac;text-transform:uppercase;letter-spacing:.5px;margin-top:2px;}
    .kmat-select-desc{font-size:12.5px;color:#8b98ac;margin-top:10px;line-height:1.5;}
    .kmat-select-desc b{color:#cbd5e1;}

    /* Connection badge */
    .kmat-badge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:12px;font-weight:700;letter-spacing:.3px;}
    .kmat-badge.ok{background:rgba(16,185,129,0.16);color:#34d399;border:1px solid rgba(16,185,129,0.4);}

    /* Data readiness tiles */
    .kmat-readiness-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:4px;}
    @media (max-width:900px){.kmat-readiness-grid{grid-template-columns:repeat(1,1fr);}}
    .kmat-readiness-tile{background:rgba(15,23,42,0.55);border:1px solid rgba(148,163,184,0.16);border-radius:14px;padding:14px 16px;border-left:3px solid var(--tile-accent,#3b82f6);}
    .kmat-readiness-tile-top{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:700;color:#f1f5f9;}
    .kmat-readiness-tile-tag{font-size:10.5px;color:#8b98ac;text-transform:uppercase;letter-spacing:.5px;margin-top:4px;}
    .kmat-readiness-tile-detail{font-size:11.5px;color:#8b98ac;margin-top:6px;}

    /* Activate hero */
    .st-key-activate_hero{border-radius:22px !important;padding:30px !important;text-align:center;background:linear-gradient(135deg, rgba(16,185,129,0.14) 0%, rgba(59,130,246,0.10) 100%) !important;border:1px solid rgba(16,185,129,0.35) !important;}
    .st-key-activate_hero:hover{transform:none;}
    .kmat-activate-note{font-size:12.5px;color:#8b98ac;margin-top:10px;}
    </style>
    """, unsafe_allow_html=True)

    def kmat_header(icon, title, subtitle):
        st.markdown(
            f'<div class="kmat-header"><div class="kmat-header-top">'
            f'<span class="kmat-header-icon">{icon}</span>'
            f'<span class="kmat-header-title">{title}</span></div>'
            f'<div class="kmat-header-sub">{subtitle}</div>'
            f'<div class="kmat-header-rule"></div></div>',
            unsafe_allow_html=True
        )

    def kmat_card_title(icon, text):
        st.markdown(f'<div class="kmat-card-title">{(icon + " ") if icon else ""}{text}</div>', unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════
    # SHARED HELPERS  (unchanged logic — presentation lines only touched)
    # ══════════════════════════════════════════════════════════════════

    def _normalize_entities(entities):
        """Accepts either {name: [cols]} (legacy shape) or
        {name: {"cols","required","label"}} and returns the meta-dict shape."""
        normalized = {}
        for name, val in entities.items():
            if isinstance(val, dict):
                normalized[name] = {
                    "cols": val["cols"],
                    "required": val.get("required", True),
                    "label": val.get("label", name),
                }
            else:
                normalized[name] = {"cols": val, "required": True, "label": name}
        return normalized

    def snowflake_db_schema_selector(key_prefix):
        """
        Database / Schema Discovery

        Returns:
        (
            selected_db,
            core_input_schema,
            core_output_schema,
            input_tables,
            output_tables
        )
        """
        with st.container(border=True, key=f"sf_workspace_card_{key_prefix}"):
            kmat_card_title("🔌", "Snowflake Workspace")

            try:
                dbs = [
                    r[0]
                    for r in session.sql("""
                        SELECT DATABASE_NAME
                        FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
                        ORDER BY DATABASE_NAME
                    """).collect()
                ]
            except Exception as e:
                st.error(f"Cannot query Snowflake: {e}")
                st.stop()

            st.markdown('<span class="kmat-badge ok">🟢 Connected</span>', unsafe_allow_html=True)
            st.write("")

            # -----------------------------
            # Database Selection
            # -----------------------------
            selected_db = st.selectbox(
                "Database",
                dbs,
                key=f"sf_db_{key_prefix}"
            )

            # -----------------------------
            # Fetch Schemas
            # -----------------------------
            try:
                schemas = [
                    r[0]
                    for r in session.sql(f"""
                        SELECT SCHEMA_NAME
                        FROM {selected_db}.INFORMATION_SCHEMA.SCHEMATA
                        WHERE SCHEMA_NAME <> 'INFORMATION_SCHEMA'
                        ORDER BY SCHEMA_NAME
                    """).collect()
                ]
            except Exception:
                schemas = []

            col1, col2 = st.columns(2)

            with col1:

                default_input = (
                    schemas.index("CORE_INPUT")
                    if "CORE_INPUT" in schemas
                    else 0
                )

                core_input_schema = st.selectbox(
                    "Core Input Schema",
                    schemas,
                    index=default_input,
                    key=f"core_input_{key_prefix}"
                )

            with col2:

                default_output = (
                    schemas.index("CORE_OUTPUT")
                    if "CORE_OUTPUT" in schemas
                    else 0
                )

                core_output_schema = st.selectbox(
                    "Core Output Schema",
                    schemas,
                    index=default_output,
                    key=f"core_output_{key_prefix}"
                )

            # -----------------------------
            # Fetch Input Tables
            # -----------------------------
            try:
                input_tables = [
                    r[0]
                    for r in session.sql(f"""
                        SELECT TABLE_NAME
                        FROM {selected_db}.INFORMATION_SCHEMA.TABLES
                        WHERE TABLE_SCHEMA = '{core_input_schema}'
                        AND TABLE_TYPE='BASE TABLE'
                        ORDER BY TABLE_NAME
                    """).collect()
                ]
            except Exception:
                input_tables = []

            # -----------------------------
            # Fetch Output Tables
            # -----------------------------
            try:
                output_tables = [
                    r[0]
                    for r in session.sql(f"""
                        SELECT TABLE_NAME
                        FROM {selected_db}.INFORMATION_SCHEMA.TABLES
                        WHERE TABLE_SCHEMA = '{core_output_schema}'
                        AND TABLE_TYPE='BASE TABLE'
                        ORDER BY TABLE_NAME
                    """).collect()
                ]
            except Exception:
                output_tables = []

        return (
            selected_db,
            core_input_schema,
            core_output_schema,
            input_tables,
            output_tables,
        )

    def validate_snowflake_table_columns(selected_db, selected_schema, table_name, required_cols):
        """Returns (is_valid, missing_cols, error_msg_or_None)."""
        try:
            col_df = session.sql(
                f"SELECT COLUMN_NAME FROM {selected_db}.INFORMATION_SCHEMA.COLUMNS "
                f"WHERE TABLE_SCHEMA = '{selected_schema}' AND TABLE_NAME = '{table_name}'"
            ).to_pandas()
            actual_cols = col_df["COLUMN_NAME"].str.upper().tolist()
            missing = [c for c in required_cols if c not in actual_cols]
            return (len(missing) == 0, missing, None)
        except Exception as ex:
            return (False, [], str(ex))

    def _find_alias_matches(aliases, tables_in_schema):
        """Case-insensitive exact-or-substring match of alias tokens against table names."""
        matches = []
        for t in tables_in_schema:
            t_upper = t.upper()
            for alias in aliases:
                if t_upper == alias or alias in t_upper:
                    matches.append(t)
                    break
        seen = set()
        deduped = []
        for m in matches:
            if m not in seen:
                deduped.append(m)
                seen.add(m)
        return deduped

    def auto_detect_and_confirm_entities(entities, tables_in_schema, selected_db, selected_schema, key_prefix):
        """
        Scans tables_in_schema and auto-matches each logical entity using
        ENTITY_ALIASES — no manual mapping required. If a single match is found,
        it's used automatically. If multiple matches are found, the user is
        asked to confirm which one to use. If none is found, the entity is
        flagged missing (and blocks activation if required).

        Returns: (table_mapping, validation_results, all_required_valid, detection_meta)
        """
        entities = _normalize_entities(entities)
        table_mapping = {}
        validation_results = {}
        detection_meta = {}
        needs_confirmation = []

        # Pass 1: auto-detect
        for logical_name, meta in entities.items():
            aliases = ENTITY_ALIASES.get(logical_name, [logical_name])
            candidates = _find_alias_matches(aliases, tables_in_schema)

            if len(candidates) == 1:
                detection_meta[logical_name] = {
                    "status": "auto", "table": candidates[0],
                    "required": meta["required"], "label": meta["label"], "candidates": candidates
                }
            elif len(candidates) > 1:
                detection_meta[logical_name] = {
                    "status": "ambiguous", "table": None,
                    "required": meta["required"], "label": meta["label"], "candidates": candidates
                }
                needs_confirmation.append(logical_name)
            else:
                detection_meta[logical_name] = {
                    "status": "missing", "table": None,
                    "required": meta["required"], "label": meta["label"], "candidates": []
                }

        # Pass 2: ask user to confirm only the ambiguous ones
        if needs_confirmation:
            kmat_header("🔍", "Confirm Detected Tables", "Multiple matching tables were found — please confirm which one to use")
            for logical_name in needs_confirmation:
                meta = detection_meta[logical_name]
                options = [SKIP_OPTION] + meta["candidates"]
                chosen = st.selectbox(
                    f"{meta['label']}",
                    options=options,
                    index=1,
                    key=f"confirm_{key_prefix}_{logical_name}"
                )
                if chosen != SKIP_OPTION:
                    detection_meta[logical_name]["status"] = "confirmed"
                    detection_meta[logical_name]["table"] = chosen

        # Pass 3: validate columns for every resolved entity
        for logical_name, meta in detection_meta.items():
            table_name = meta["table"]
            if table_name is None:
                validation_results[logical_name] = not meta["required"]
                continue
            table_mapping[logical_name] = table_name
            ok, missing, err = validate_snowflake_table_columns(selected_db, selected_schema, table_name, entities[logical_name]["cols"])
            validation_results[logical_name] = ok
            detection_meta[logical_name]["missing_cols"] = missing
            detection_meta[logical_name]["error"] = err

        all_required_valid = all(
            validation_results[name] for name, meta in detection_meta.items() if meta["required"]
        )
        return table_mapping, validation_results, all_required_valid, detection_meta

    def render_data_readiness_summary(detection_meta, title="Data Readiness"):
        """Premium KPI-tile readiness dashboard, 3 per row. Reads the exact
        same detection_meta produced by auto_detect_and_confirm_entities —
        no detection/validation logic lives here, presentation only."""
        kmat_header("📋", title, "Live detection status for every required and optional table")

        tiles = []
        for logical_name, meta in detection_meta.items():
            label = meta["label"]
            req_tag = "Required" if meta["required"] else "Optional"

            if meta["status"] in ("auto", "confirmed") and meta.get("table") and not meta.get("missing_cols") and not meta.get("error"):
                icon, accent, detail = "✓", "#10b981", f"Detected as {meta['table']}"
            elif meta.get("table") and (meta.get("missing_cols") or meta.get("error")):
                accent = "#ef4444"; icon = "✗"
                detail = f"Missing columns: {', '.join(meta['missing_cols'])}" if meta.get("missing_cols") else str(meta.get("error"))
            elif meta["status"] == "ambiguous":
                icon, accent, detail = "⚠", "#f59e0b", "Multiple candidates — confirm above"
            else:
                icon = "—"
                accent = "#ef4444" if meta["required"] else "#f59e0b"
                detail = "Not found in schema"

            tiles.append(
                f'<div class="kmat-readiness-tile" style="--tile-accent:{accent};">'
                f'<div class="kmat-readiness-tile-top">{icon} {label}</div>'
                f'<div class="kmat-readiness-tile-tag">{req_tag}</div>'
                f'<div class="kmat-readiness-tile-detail">{detail}</div></div>'
            )

        st.markdown(f'<div class="kmat-readiness-grid">{"".join(tiles)}</div>', unsafe_allow_html=True)

    def load_and_store_snowflake_tables(
        entities,
        table_mapping,
        selected_db,
        core_input_schema,
        core_output_schema,
        entity_role_map=None,
    ):
        """
        Loads mapped Snowflake tables into st.session_state.

        Business/configuration tables are read from CORE_INPUT.
        Cost Model output tables are read from CORE_OUTPUT.

        entity_role_map: optional {logical_name: "input"|"output"} override.
        When None, falls back to the original Integrated-only KMAT sets
        below, so existing Integrated call sites behave exactly as before.
        """

        entities = _normalize_entities(entities)

        cards = []

        INPUT_TABLES = {
            "KMAT_PRODUCT_MASTER",
            "CHARACTERISTIC_MASTER",
            "CHARACTERISTIC_VALUES",
            "SIMULATION_HEADER",
            "SIMULATION_PARAMETERS",
        }

        OUTPUT_TABLES = {
            "KMAT_CONFIGURED_COST_SUMMARY",
            "KMAT_CONFIGURED_COMPONENT_COSTS",
            "KMAT_CONFIGURED_OPERATION_COSTS",
            "KMAT_CONFIGURED_OVERHEAD_COSTS",
        }

        for logical_name, chosen_table in table_mapping.items():

            if entity_role_map is not None:
                role = entity_role_map.get(logical_name)

                if role == "input":
                    schema = core_input_schema
                elif role == "output":
                    schema = core_output_schema
                else:
                    st.warning(f"Unknown logical entity: {logical_name}")
                    continue

            elif logical_name in INPUT_TABLES:
                schema = core_input_schema

            elif logical_name in OUTPUT_TABLES:
                schema = core_output_schema

            else:
                st.warning(f"Unknown logical entity: {logical_name}")
                continue

            fq_table = f"{selected_db}.{schema}.{chosen_table}"

            try:
                df = session.table(fq_table).to_pandas()

                # Store dataframe for other tabs
                st.session_state[logical_name] = df

                cards.append(
                    render_kpi(
                        logical_name.replace("_", " "),
                        f"{len(df)} Rows",
                        "green"
                    )
                )

            except Exception as e:
                st.error(f"Failed to load {fq_table}: {e}")

        return cards

    def load_demo_data():
        """
        Loads a complete demo dataset for the Integrated Pricing workflow.
        Mimics the KMAT Cost Model + Pricing Model integration.
        """

        # -------------------------------
        # KMAT PRODUCT MASTER
        # -------------------------------
        demo_product_master = pd.DataFrame({
            "KMAT_ID": ["TRUCK001"],
            "DESCRIPTION": ["Heavy Duty Truck"],
            "PRODUCT_FAMILY": ["Commercial Vehicles"],
            "ACTIVE_FLAG": [True]
        })

        # -------------------------------
        # CHARACTERISTIC MASTER
        # -------------------------------
        demo_characteristic_master = pd.DataFrame({
            "KMAT_ID": [
                "TRUCK001",
                "TRUCK001",
                "TRUCK001",
                "TRUCK001"
            ],
            "CHARACTERISTIC_NAME": [
                "ENGINE",
                "CAB",
                "COLOR",
                "WHEEL"
            ],
            "ALLOWED_VALUE": [
                "V8",
                "Premium",
                "Red",
                "Offroad"
            ],
            "DISPLAY_ORDER": [1, 2, 3, 4],
            "ACTIVE_FLAG": [True, True, True, True]
        })

        # -------------------------------
        # SIMULATION HEADER
        # -------------------------------
        demo_simulation_header = pd.DataFrame({
            "SIMULATION_ID": ["SIM001"],
            "KMAT_ID": ["TRUCK001"],
            "CUSTOMER_ID": ["CUST001"],
            "SCENARIO_NAME": ["Standard Quote"]
        })

        # -------------------------------
        # SIMULATION PARAMETERS
        # -------------------------------
        demo_simulation_parameters = pd.DataFrame({
            "SIMULATION_ID": ["SIM001"],
            "TARGET_MARGIN_PCT": [25],
            "FLOOR_MARKUP_PCT": [10],
            "CEILING_MARKUP_PCT": [40]
        })

        # -------------------------------
        # CHARACTERISTIC VALUES
        # -------------------------------
        demo_characteristic_values = pd.DataFrame({
            "SIMULATION_ID": [
                "SIM001",
                "SIM001",
                "SIM001",
                "SIM001"
            ],
            "KMAT_ID": [
                "TRUCK001",
                "TRUCK001",
                "TRUCK001",
                "TRUCK001"
            ],
            "CHARACTERISTIC_NAME": [
                "ENGINE",
                "CAB",
                "COLOR",
                "WHEEL"
            ],
            "SELECTED_VALUE": [
                "V8",
                "Premium",
                "Red",
                "Offroad"
            ]
        })

        # -------------------------------
        # COST SUMMARY VIEW
        # -------------------------------
        demo_cost_summary = pd.DataFrame({
            "SIMULATION_ID": ["SIM001"],
            "KMAT_ID": ["TRUCK001"],
            "MATERIAL_COST_USD": [25000],
            "LABOR_COST_USD": [4500],
            "MACHINE_COST_USD": [3200],
            "OVERHEAD_COST_USD": [1800],
            "TOTAL_CONFIGURED_COST_USD": [34500],
            "FLOOR_PRICE_USD": [37950],
            "TARGET_PRICE_USD": [43125],
            "CEILING_PRICE_USD": [48300]
        })

        # -------------------------------
        # COMPONENT COSTS VIEW
        # -------------------------------
        demo_component_costs = pd.DataFrame({
            "SIMULATION_ID": ["SIM001"] * 3,
            "COMPONENT_ID": ["ENG001", "CAB001", "WHL001"],
            "COMPONENT_DESCRIPTION": [
                "V8 Engine",
                "Premium Cabin",
                "Offroad Wheels"
            ],
            "LINE_MATERIAL_COST_USD": [
                12000,
                5000,
                2800
            ]
        })

        # -------------------------------
        # OPERATION COSTS VIEW
        # -------------------------------
        demo_operation_costs = pd.DataFrame({
            "SIMULATION_ID": ["SIM001"] * 3,
            "OPERATION_ID": [
                "OP01",
                "OP02",
                "OP03"
            ],
            "OPERATION_DESCRIPTION": [
                "Welding",
                "Painting",
                "Assembly"
            ],
            "LABOR_COST_USD": [
                1200,
                900,
                2400
            ],
            "MACHINE_COST_USD": [
                700,
                600,
                1900
            ]
        })

        # -------------------------------
        # OVERHEAD COSTS VIEW
        # -------------------------------
        demo_overhead_costs = pd.DataFrame({
            "SIMULATION_ID": [
                "SIM001",
                "SIM001"
            ],
            "OVERHEAD_ID": [
                "OH01",
                "OH02"
            ],
            "OVERHEAD_DESCRIPTION": [
                "Factory Overhead",
                "Utilities"
            ],
            "OVERHEAD_COST_USD": [
                1200,
                600
            ]
        })

        demo_data = {
            "KMAT_PRODUCT_MASTER": demo_product_master,
            "CHARACTERISTIC_MASTER": demo_characteristic_master,
            "CHARACTERISTIC_VALUES": demo_characteristic_values,
            "SIMULATION_HEADER": demo_simulation_header,
            "SIMULATION_PARAMETERS": demo_simulation_parameters,
            "KMAT_CONFIGURED_COST_SUMMARY": demo_cost_summary,
            "KMAT_CONFIGURED_COMPONENT_COSTS": demo_component_costs,
            "KMAT_CONFIGURED_OPERATION_COSTS": demo_operation_costs,
            "KMAT_CONFIGURED_OVERHEAD_COSTS": demo_overhead_costs,
        }

        cards = []

        for logical_name, df in demo_data.items():
            st.session_state[logical_name] = df
            cards.append(
                render_kpi(
                    logical_name.replace("_", " "),
                    f"{len(df)} Rows",
                    "green"
                )
            )

        return cards

    # ══════════════════════════════════════════════════════════════════
    # WIZARD START
    # ══════════════════════════════════════════════════════════════════

    # ── SECTION 1 — Enterprise Hero Banner ──────────────────────────────
    with st.container(key="hero_banner"):
        st.markdown(
            '<div class="kmat-hero-title">🚀 Intelligent Pricing Platform</div>'
            '<div class="kmat-hero-sub">Enterprise Manufacturing Cost &amp; AI Pricing</div>',
            unsafe_allow_html=True
        )
        hero_c1, hero_c2, hero_c3 = st.columns(3)
        with hero_c1:
            st.markdown(render_kpi("SNOWFLAKE CONNECTION", "Status : YES", "green", None, ""), unsafe_allow_html=True)
        with hero_c2:
            st.markdown(render_kpi("PRICING MODE", st.session_state.get("pricing_mode", "Not Selected"), "blue"), unsafe_allow_html=True)
        with hero_c3:
            st.markdown(render_kpi("AI ENGINE", "Ready", "purple"), unsafe_allow_html=True)

    # ── SECTION 2 — Platform Mode (premium selection cards) ─────────────
    kmat_header("🧭", "Platform Mode", "Choose how this workspace uses the KMAT pricing engine")

    if "onboarding_mode_choice" not in st.session_state:
        st.session_state["onboarding_mode_choice"] = "Manufacturing Cost + Pricing (Integrated)"

    _mode_sel = st.session_state["onboarding_mode_choice"]
    st.markdown(f"""
    <style>
    .st-key-mode_card_integrated{{{'border:1px solid rgba(59,130,246,0.7) !important;box-shadow:0 0 0 1px rgba(59,130,246,0.35), 0 8px 24px rgba(59,130,246,0.18) !important;' if _mode_sel.startswith('Manufacturing') else ''}}}
    .st-key-mode_card_standalone{{{'border:1px solid rgba(139,92,246,0.7) !important;box-shadow:0 0 0 1px rgba(139,92,246,0.35), 0 8px 24px rgba(139,92,246,0.18) !important;' if _mode_sel.startswith('Pricing Only') else ''}}}
    </style>
    """, unsafe_allow_html=True)

    mode_c1, mode_c2 = st.columns(2)
    with mode_c1:
        with st.container(border=True, key="mode_card_integrated"):
            st.markdown(
                '<div class="kmat-select-icon">🏭</div>'
                '<div class="kmat-select-title">Manufacturing Cost + Pricing</div>'
                '<div class="kmat-select-tag">Integrated</div>'
                '<div class="kmat-select-desc">Uses the <b>KMAT Cost Model</b> · Dynamic Costing · Manufacturing Analytics</div>',
                unsafe_allow_html=True
            )
            if st.button("Select Integrated" + (" ✓" if _mode_sel.startswith("Manufacturing") else ""),
                         key="select_integrated", use_container_width=True,
                         type="primary" if _mode_sel.startswith("Manufacturing") else "secondary"):
                st.session_state["onboarding_mode_choice"] = "Manufacturing Cost + Pricing (Integrated)"
                st.rerun()
    with mode_c2:
        with st.container(border=True, key="mode_card_standalone"):
            st.markdown(
                '<div class="kmat-select-icon">💰</div>'
                '<div class="kmat-select-title">Pricing Only</div>'
                '<div class="kmat-select-tag">Standalone</div>'
                '<div class="kmat-select-desc"><b>Pricing Engine</b> · Revenue Leakage · AI Pricing</div>',
                unsafe_allow_html=True
            )
            if st.button("Select Standalone" + (" ✓" if _mode_sel.startswith("Pricing Only") else ""),
                         key="select_standalone", use_container_width=True,
                         type="primary" if _mode_sel.startswith("Pricing Only") else "secondary"):
                st.session_state["onboarding_mode_choice"] = "Pricing Only (Standalone)"
                st.rerun()

    onboarding_mode = st.session_state["onboarding_mode_choice"]

    if onboarding_mode.startswith("Manufacturing"):
        st.session_state["pricing_mode"] = "Integrated Pricing"
    elif onboarding_mode.startswith("Pricing Only"):
        st.session_state["pricing_mode"] = "Standalone Pricing"


    pricing_mode = st.session_state["pricing_mode"]

    # ══════════════════════════════════════════════════════════════════
    # DEMO MODE — no data source step needed
    # ══════════════════════════════════════════════════════════════════
    if pricing_mode == "Demo Mode":
        kmat_header("⚡", "Try It Instantly", "Load a ready-made sample dataset to explore the full KMAT pricing experience — no Snowflake or file uploads required")

        if st.button("🚀 Load Demo Data", type="primary"):
            cards = load_demo_data()

            cols = st.columns(3)

            for i, (name, df) in enumerate(demo_data.items()):

                with cols[i % 3]:

                    st.metric(name.replace("_"," "), len(df))
            st.success("Demo data loaded. Explore the other tabs to see it in action!")
            st.toast("✅ Demo data loaded successfully.", icon="✅")

        if any(st.session_state.get(k) is not None for k in LOGICAL_ENTITIES):
            loaded_count = sum(1 for k in LOGICAL_ENTITIES if st.session_state.get(k) is not None)
            with st.container(border=True, key="demo_readiness_card"):
                kmat_card_title("✅", "Data Readiness (Demo)")
                rc1, rc2, rc3 = st.columns(3)
                with rc1: st.metric("Tables Available", f"{loaded_count}/{len(LOGICAL_ENTITIES)}")
                with rc2: st.metric("Sample Data", "Active")
                with rc3: st.metric("AI Pricing Engine", "Ready")

    # ══════════════════════════════════════════════════════════════════
    # INTEGRATED / STANDALONE — Step 2: data source
    # ══════════════════════════════════════════════════════════════════
    else:
        entities = LOGICAL_ENTITIES if pricing_mode == "Integrated Pricing" else STANDALONE_ENTITIES
        key_prefix = "integrated" if pricing_mode == "Integrated Pricing" else "standalone"

        # ── SECTION 3 — Data Source (premium selection cards) ───────────
        kmat_header("🗂️", "Data Source", "Where should the platform read your tables from?")

        _src_key = f"source_type_choice_{key_prefix}"
        if _src_key not in st.session_state:
            st.session_state[_src_key] = "Snowflake"
        _src_sel = st.session_state[_src_key]

        st.markdown(f"""
        <style>
        .st-key-src_card_sf_{key_prefix}{{{'border:1px solid rgba(59,130,246,0.7) !important;box-shadow:0 0 0 1px rgba(59,130,246,0.35), 0 8px 24px rgba(59,130,246,0.18) !important;' if _src_sel == 'Snowflake' else ''}}}
        .st-key-src_card_csv_{key_prefix}{{{'border:1px solid rgba(59,130,246,0.7) !important;box-shadow:0 0 0 1px rgba(59,130,246,0.35), 0 8px 24px rgba(59,130,246,0.18) !important;' if _src_sel != 'Snowflake' else ''}}}
        </style>
        """, unsafe_allow_html=True)

        src_c1, src_c2 = st.columns(2)
        with src_c1:
            with st.container(border=True, key=f"src_card_sf_{key_prefix}"):
                st.markdown(
                    '<div class="kmat-select-icon">☁️</div>'
                    '<div class="kmat-select-title">Snowflake</div>'
                    '<div class="kmat-select-desc">Auto-detected tables, live validation, zero uploads</div>',
                    unsafe_allow_html=True
                )
                if st.button("Use Snowflake" + (" ✓" if _src_sel == "Snowflake" else ""),
                             key=f"select_src_sf_{key_prefix}", use_container_width=True,
                             type="primary" if _src_sel == "Snowflake" else "secondary"):
                    st.session_state[_src_key] = "Snowflake"
                    st.rerun()
        with src_c2:
            with st.container(border=True, key=f"src_card_csv_{key_prefix}"):
                st.markdown(
                    '<div class="kmat-select-icon">📁</div>'
                    '<div class="kmat-select-title">CSV / Excel</div>'
                    '<div class="kmat-select-desc">Upload files directly for a quick offline setup</div>',
                    unsafe_allow_html=True
                )
                if st.button("Use CSV / Excel" + (" ✓" if _src_sel != "Snowflake" else ""),
                             key=f"select_src_csv_{key_prefix}", use_container_width=True,
                             type="primary" if _src_sel != "Snowflake" else "secondary"):
                    st.session_state[_src_key] = "CSV / Excel"
                    st.rerun()

        source_type = st.session_state[_src_key]

        # ── SNOWFLAKE PATH — fully automatic detection ────────────────
        if source_type == "Snowflake":

            (
                selected_db,
                core_input_schema,
                core_output_schema,
                input_tables,
                output_tables,
            ) = snowflake_db_schema_selector(key_prefix)

            if not input_tables:
                st.warning("No tables found in the Core Input schema.")
                st.stop()
            # Standalone Pricing has no Cost-Model-style output schema, so
            # only Integrated Pricing requires output tables to be present.
            if pricing_mode == "Integrated Pricing" and not output_tables:
                st.warning("No tables found in the Core Output schema.")
                st.stop()

            # -----------------------------
            # Split entities
            # -----------------------------
            if pricing_mode == "Integrated Pricing":
                input_entity_names = {
                    "KMAT_PRODUCT_MASTER",
                    "CHARACTERISTIC_MASTER",
                    "CHARACTERISTIC_VALUES",
                    "SIMULATION_HEADER",
                    "SIMULATION_PARAMETERS",
                }

                output_entity_names = {
                    "KMAT_CONFIGURED_COST_SUMMARY",
                    "KMAT_CONFIGURED_COMPONENT_COSTS",
                    "KMAT_CONFIGURED_OPERATION_COSTS",
                    "KMAT_CONFIGURED_OVERHEAD_COSTS",
                }

                input_entities = {
                    k: v
                    for k, v in entities.items()
                    if k in input_entity_names
                }

                output_entities = {
                    k: v
                    for k, v in entities.items()
                    if k in output_entity_names
                }

            else:  # Standalone Pricing
                input_entities = {
                    k: v
                    for k, v in entities.items()
                    if STANDALONE_ENTITY_SCHEMA_ROLE.get(k) == "input"
                }
                output_entities = {}

            # -----------------------------
            # Validate CORE_INPUT
            # -----------------------------
            (
                input_mapping,
                input_validation,
                input_valid,
                input_detection,
            ) = auto_detect_and_confirm_entities(
                input_entities,
                input_tables,
                selected_db,
                core_input_schema,
                key_prefix + "_input",
            )

            # -----------------------------
            # Validate CORE_OUTPUT
            # -----------------------------
            (
                output_mapping,
                output_validation,
                output_valid,
                output_detection,
            ) = auto_detect_and_confirm_entities(
                output_entities,
                output_tables,
                selected_db,
                core_output_schema,
                key_prefix + "_output",
            )

            # -----------------------------
            # Merge everything
            # -----------------------------
            table_mapping = {
                **input_mapping,
                **output_mapping,
            }

            validation_results = {
                **input_validation,
                **output_validation,
            }

            detection_meta = {
                **input_detection,
                **output_detection,
            }

            all_required_valid = input_valid and output_valid

            # ── SECTION 5 — Data Readiness ───────────────────────────
            render_data_readiness_summary(
                detection_meta,
                title="Data Readiness"
            )

            valid_count = sum(1 for ok in validation_results.values() if ok)
            total_count = len(validation_results)
            required_total = sum(1 for meta in detection_meta.values() if meta["required"])
            detected_total = sum(1 for meta in detection_meta.values() if meta.get("table"))

            # ── SECTION 6 — Platform Readiness ───────────────────────
            kmat_header("📈", "Platform Readiness", "Overall status before activation")
            with st.container(border=True, key="platform_readiness_card"):
                pr1, pr2, pr3, pr4 = st.columns(4)
                with pr1: st.metric("Required Tables", required_total)
                with pr2: st.metric("Detected Tables", detected_total)
                with pr3: st.metric("Status", "Ready" if all_required_valid else "Incomplete")
                with pr4: st.metric("Connection", "Healthy")

                if all_required_valid:
                    st.success(f"✓ {valid_count}/{total_count} tables validated for **{onboarding_mode}**. All required tables were detected and validated automatically.")
                else:
                    st.warning(f"⚠ {valid_count}/{total_count} tables validated. Some required tables are missing or invalid — resolve the issues above before activating.")

            # ── SECTION 7 — Activate Platform ────────────────────────
            with st.container(border=True, key="activate_hero"):
                st.markdown('<div class="kmat-select-title" style="font-size:18px;">🚀 Activate Platform</div>', unsafe_allow_html=True)
                act_l, act_c, act_r = st.columns([1, 2, 1])
                with act_c:
                    activate_clicked = st.button(
                        "✅ Activate",
                        type="primary",
                        disabled=not all_required_valid,
                        key=f"activate_{key_prefix}",
                        use_container_width=True,
                    )
                st.markdown('<div class="kmat-activate-note">All required data has been validated. The pricing platform is ready.</div>', unsafe_allow_html=True)

            if activate_clicked:

                # Standalone Pricing passes its own role map so the loader
                # doesn't fall back to the Integrated-only KMAT_* sets.
                _standalone_role_map = (
                    STANDALONE_ENTITY_SCHEMA_ROLE
                    if pricing_mode == "Standalone Pricing"
                    else None
                )

                # Load CORE_INPUT tables
                cards_input = load_and_store_snowflake_tables(
                    input_entities,
                    input_mapping,
                    selected_db,
                    core_input_schema,
                    core_output_schema,
                    entity_role_map=_standalone_role_map,
                )

                # Load CORE_OUTPUT tables
                cards_output = load_and_store_snowflake_tables(
                    output_entities,
                    output_mapping,
                    selected_db,
                    core_input_schema,
                    core_output_schema,
                    entity_role_map=_standalone_role_map,
                )

                st.success("✅ Platform Ready — all required tables have been loaded successfully. You can now continue to Configure Quote.")
                st.session_state["SF_DB"] = selected_db
                st.session_state["CORE_INPUT_SCHEMA"] = core_input_schema
                st.session_state["CORE_OUTPUT_SCHEMA"] = core_output_schema
                st.session_state["TABLE_MAP"] = table_mapping
                st.session_state["PLATFORM_READY"] = True

                st.rerun()

        # ── CSV / EXCEL PATH — existing upload flow, unchanged ─────────
        else:
            if key_prefix == "integrated":

                kmat_header("📦", "Product Configuration", "Upload the KMAT product and characteristic master files")

                c1, c2 = st.columns(2)

                with c1:
                    with st.container(border=True, key="upload_kmat_product"):
                        st.markdown("**KMAT Product Master**")
                        kmat_product_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="kmat_product",
                            label_visibility="collapsed"
                        )
                        st.caption("KMAT_ID · DESCRIPTION · PRODUCT_FAMILY · ACTIVE_FLAG")

                with c2:
                    with st.container(border=True, key="upload_char_master"):
                        st.markdown("**Characteristic Master**")
                        characteristic_master_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="characteristic_master",
                            label_visibility="collapsed"
                        )
                        st.caption("KMAT_ID · CHARACTERISTIC_NAME · ALLOWED_VALUE · DISPLAY_ORDER")



                c3, c4 = st.columns(2)

                with c3:
                    with st.container(border=True, key="upload_sim_header"):
                        st.markdown("**Simulation Header**")
                        simulation_header_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="simulation_header",
                            label_visibility="collapsed"
                        )
                        st.caption("SIMULATION_ID · KMAT_ID · CUSTOMER_ID · SCENARIO_NAME")

                with c4:
                    with st.container(border=True, key="upload_sim_params"):
                        st.markdown("**Simulation Parameters**")
                        simulation_parameter_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="simulation_parameter",
                            label_visibility="collapsed"
                        )
                        st.caption("SIMULATION_ID · TARGET_MARGIN_PCT · FLOOR_MARKUP_PCT · CEILING_MARKUP_PCT")



                kmat_header("🧬", "Simulation Configuration", "Characteristic selections baked into each simulation")

                with st.container(border=True, key="upload_char_values"):
                    characteristic_value_file = st.file_uploader(
                        "Characteristic Values",
                        type=["csv", "xlsx"],
                        key="characteristic_values"
                    )

                    st.caption(
                        "SIMULATION_ID · KMAT_ID · CHARACTERISTIC_NAME · SELECTED_VALUE"
                    )



                kmat_header("🏭", "Cost Model Outputs", "Configured cost detail produced by the upstream Cost Model")

                c5, c6 = st.columns(2)

                with c5:
                    with st.container(border=True, key="upload_cost_summary"):
                        st.markdown("**Configured Cost Summary**")
                        cost_summary_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="cost_summary",
                            label_visibility="collapsed"
                        )
                        st.caption(
                            "SIMULATION_ID · TOTAL_CONFIGURED_COST_USD · TARGET_PRICE_USD"
                        )

                with c6:
                    with st.container(border=True, key="upload_component_cost"):
                        st.markdown("**Configured Component Costs**")
                        component_cost_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="component_cost",
                            label_visibility="collapsed"
                        )
                        st.caption(
                            "SIMULATION_ID · COMPONENT_ID · LINE_MATERIAL_COST_USD"
                        )



                c7, c8 = st.columns(2)

                with c7:
                    with st.container(border=True, key="upload_operation_cost"):
                        st.markdown("**Configured Operation Costs**")
                        operation_cost_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="operation_cost",
                            label_visibility="collapsed"
                        )
                        st.caption(
                            "SIMULATION_ID · OPERATION_ID · LABOR_COST_USD · MACHINE_COST_USD"
                        )

                with c8:
                    with st.container(border=True, key="upload_overhead_cost"):
                        st.markdown("**Configured Overhead Costs**")
                        overhead_cost_file = st.file_uploader(
                            "",
                            type=["csv", "xlsx"],
                            key="overhead_cost",
                            label_visibility="collapsed"
                        )
                        st.caption(
                            "SIMULATION_ID · OVERHEAD_ID · OVERHEAD_COST_USD"
                        )



                if st.button("✅ Validate & Load", type="primary"):

                    loaded = []

                    specs = [

                        (
                            kmat_product_file,
                            "KMAT_PRODUCT_MASTER",
                            [
                                "KMAT_ID",
                                "DESCRIPTION",
                                "PRODUCT_FAMILY",
                                "ACTIVE_FLAG"
                            ]
                        ),

                        (
                            characteristic_master_file,
                            "CHARACTERISTIC_MASTER",
                            [
                                "KMAT_ID",
                                "CHARACTERISTIC_NAME",
                                "ALLOWED_VALUE"
                            ]
                        ),

                        (
                            simulation_header_file,
                            "SIMULATION_HEADER",
                            [
                                "SIMULATION_ID",
                                "KMAT_ID",
                                "CUSTOMER_ID",
                                "SCENARIO_NAME"
                            ]
                        ),

                        (
                            simulation_parameter_file,
                            "SIMULATION_PARAMETERS",
                            [
                                "SIMULATION_ID",
                                "TARGET_MARGIN_PCT",
                                "FLOOR_MARKUP_PCT",
                                "CEILING_MARKUP_PCT"
                            ]
                        ),

                        (
                            characteristic_value_file,
                            "CHARACTERISTIC_VALUES",
                            [
                                "SIMULATION_ID",
                                "KMAT_ID",
                                "CHARACTERISTIC_NAME",
                                "SELECTED_VALUE"
                            ]
                        ),

                        (
                            cost_summary_file,
                            "KMAT_CONFIGURED_COST_SUMMARY",
                            [
                                "SIMULATION_ID",
                                "KMAT_ID",
                                "TOTAL_CONFIGURED_COST_USD"
                            ]
                        ),

                        (
                            component_cost_file,
                            "KMAT_CONFIGURED_COMPONENT_COSTS",
                            [
                                "SIMULATION_ID",
                                "COMPONENT_ID",
                                "LINE_MATERIAL_COST_USD"
                            ]
                        ),

                        (
                            operation_cost_file,
                            "KMAT_CONFIGURED_OPERATION_COSTS",
                            [
                                "SIMULATION_ID",
                                "OPERATION_ID",
                                "LABOR_COST_USD",
                                "MACHINE_COST_USD"
                            ]
                        ),

                        (
                            overhead_cost_file,
                            "KMAT_CONFIGURED_OVERHEAD_COSTS",
                            [
                                "SIMULATION_ID",
                                "OVERHEAD_ID",
                                "OVERHEAD_COST_USD"
                            ]
                        )

                    ]


                    for file, table_name, required_cols in specs:

                        if file is None:
                            continue

                        df = load_file(file)

                        missing = validate_columns(df, required_cols)

                        if missing:
                            st.error(
                                f"**{table_name}** missing columns: {missing}"
                            )
                            continue

                        st.session_state[table_name] = df

                        if write_table_to_snowflake(df, table_name):

                            loaded.append((table_name, len(df)))

                            st.success(
                                f"✓ {table_name} loaded ({len(df)} rows)"
                            )

                    if loaded:
                        st.toast("✅ Integrated pricing data loaded successfully.", icon="✅")
                    else:
                        st.warning("No files uploaded.")

            else:
                kmat_header("📦", "Standalone Data Upload", "Product, characteristic, and quote history files")

                c1, c2 = st.columns(2)

                with c1:
                    with st.container(border=True, key="sa_upload_product"):
                        st.markdown("**Product Master** *(required)*")
                        product_master_file = st.file_uploader(
                            "", type=["csv", "xlsx"],
                            key="product_master",
                            label_visibility="collapsed"
                        )
                        st.caption(", ".join(STANDALONE_ENTITIES["KMAT_PRODUCT_MASTER"]["cols"]))

                with c2:
                    with st.container(border=True, key="sa_upload_char_master"):
                        st.markdown("**Characteristic Master** *(required)*")
                        characteristic_master_file = st.file_uploader(
                            "", type=["csv", "xlsx"],
                            key="characteristic_master",
                            label_visibility="collapsed"
                        )
                        st.caption(", ".join(STANDALONE_ENTITIES["CHARACTERISTIC_MASTER"]["cols"]))


                c3, c4 = st.columns(2)

                with c3:
                    with st.container(border=True, key="sa_upload_char_values"):
                        st.markdown("**Characteristic Values** *(required)*")
                        characteristic_values_file = st.file_uploader(
                            "", type=["csv", "xlsx"],
                            key="characteristic_values",
                            label_visibility="collapsed"
                        )
                        st.caption(", ".join(STANDALONE_ENTITIES["CHARACTERISTIC_VALUES"]["cols"]))

                with c4:
                    with st.container(border=True, key="sa_upload_quote_history"):
                        st.markdown("**Quote History** *(optional)*")
                        quote_history_file = st.file_uploader(
                            "", type=["csv", "xlsx"],
                            key="quote_history",
                            label_visibility="collapsed"
                        )
                        st.caption(", ".join(STANDALONE_ENTITIES["QUOTE_HISTORY"]["cols"]))

                if st.button("✅  Validate & Load Standalone Data", type="primary", key="sa_csv_load_btn"):
                    loaded = []
                    specs = [
                        (product_master_file, "KMAT_PRODUCT_MASTER"),
                        (characteristic_master_file, "CHARACTERISTIC_MASTER"),
                        (characteristic_values_file, "CHARACTERISTIC_VALUES"),
                        (quote_history_file, "QUOTE_HISTORY"),
                    ]
                    missing_required = []
                    for file, tname in specs:
                        meta = STANDALONE_ENTITIES[tname]
                        if file is None:
                            if meta["required"]:
                                missing_required.append(meta["label"])
                            continue
                        df = load_file(file)
                        missing_cols = validate_columns(df, meta["cols"])
                        if missing_cols:
                            st.error(f"**{meta['label']}** missing columns: `{missing_cols}`")
                            continue
                        st.session_state[tname] = df
                        loaded.append((meta["label"], len(df)))
                        st.success(f"✓  **{meta['label']}** — {len(df)} rows loaded")

                    if missing_required:
                        st.error(f"Missing required file(s): {', '.join(missing_required)}")
                    elif loaded:
                        st.toast("✅ Standalone pricing data loaded successfully.", icon="✅")
                    else:
                        st.warning("No files were uploaded.")

        # ── Bottom Readiness Banner (kept as before, per mode) ────────
        if key_prefix == "integrated":
            if st.session_state.get("TABLE_MAP") or any(
                st.session_state.get(k) is not None for k in LOGICAL_ENTITIES
            ):
                loaded_count = sum(1 for k in LOGICAL_ENTITIES if st.session_state.get(k) is not None)
                with st.container(border=True, key="bottom_readiness_integrated"):
                    kmat_card_title("✅", "Data Readiness")
                    br1, br2, br3, br4 = st.columns(4)
                    with br1: st.metric("Tables Available", f"{loaded_count}/{len(LOGICAL_ENTITIES)}")
                    with br2: st.metric("Schema", "Validated")
                    with br3: st.metric("AI Pricing Engine", "Ready")
                    with br4: st.metric("Mfg Cost Data", "Loaded")
        else:
            if any(st.session_state.get(k) is not None for k in STANDALONE_ENTITIES):
                loaded_count = sum(1 for k in STANDALONE_ENTITIES if st.session_state.get(k) is not None)
                required_ready = all(
                    st.session_state.get(k) is not None
                    for k, meta in STANDALONE_ENTITIES.items() if meta["required"]
                )
                with st.container(border=True, key="bottom_readiness_standalone"):
                    kmat_card_title("✅", "Data Readiness (Standalone)")
                    br1, br2, br3 = st.columns(3)
                    with br1: st.metric("Inputs Provided", f"{loaded_count}/{len(STANDALONE_ENTITIES)}")
                    with br2: st.metric("Required Data", "Complete" if required_ready else "Incomplete")
                    with br3: st.metric("Standalone Engine", "Ready" if required_ready else "Waiting")
# ===================================================
# TAB 2 — CONFIGURE QUOTE
# ===================================================
with tab2:
    if "TABLE_MAP" not in st.session_state:
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()
    pricing_mode = st.session_state.get("pricing_mode", "Integrated Pricing")

    # ══════════════════════════════════════════════════════════════════════
    # PREMIUM UI LAYER — styling + layout helpers only. No business logic,
    # no variables, no session_state, no queries are touched below.
    # Requires Streamlit >= 1.32 (st.container(key=...) + border=True).
    # ══════════════════════════════════════════════════════════════════════
    st.markdown("""
    <style>
    /* ---- Section headers (SAP/Salesforce/Fabric style banner) ---- */
    .kmat-header{margin:6px 0 22px 0;}
    .kmat-header-top{display:flex;align-items:center;gap:10px;}
    .kmat-header-icon{font-size:22px;line-height:1;}
    .kmat-header-title{font-size:22px;font-weight:700;color:#f1f5f9;letter-spacing:.2px;}
    .kmat-header-sub{font-size:13px;color:#8b98ac;margin-top:2px;margin-left:32px;}
    .kmat-header-rule{
        height:2px;margin-top:14px;border-radius:2px;
        background:linear-gradient(90deg,#3b82f6 0%,#8b5cf6 45%,rgba(139,92,246,0) 100%);
    }

    /* ---- Card title used inside bordered containers ---- */
    .kmat-card-title{
        font-size:14.5px;font-weight:700;color:#e2e8f0;
        text-transform:uppercase;letter-spacing:.6px;
        margin-bottom:14px;padding-bottom:10px;
        border-bottom:1px solid rgba(148,163,184,0.14);
    }

    /* ---- Generic hover/elevation + glass treatment for every card ---- */
    div[data-testid="stVerticalBlockBorderWrapper"]{
        border-radius:16px !important;
        transition:transform .18s ease, box-shadow .18s ease, border-color .18s ease;
        background:linear-gradient(180deg, rgba(30,41,59,0.55) 0%, rgba(17,24,39,0.55) 100%);
        backdrop-filter:blur(6px);
        border:1px solid rgba(148,163,184,0.14) !important;
    }
    div[data-testid="stVerticalBlockBorderWrapper"]:hover{
        transform:translateY(-2px);
        border-color:rgba(139,92,246,0.55) !important;
        box-shadow:0 10px 30px rgba(59,130,246,0.12), 0 0 0 1px rgba(139,92,246,0.15);
    }

    /* ---- Full-width AI Pricing Intelligence super-container ---- */
    .st-key-ai_intel_section{
        border-radius:22px !important;
        padding:26px 22px !important;
        background:linear-gradient(135deg, rgba(59,130,246,0.10) 0%, rgba(139,92,246,0.10) 55%, rgba(16,185,129,0.06) 100%) !important;
        border:1px solid rgba(139,92,246,0.28) !important;
        margin:8px 0 30px 0 !important;
    }
    .st-key-ai_intel_section:hover{ transform:none; }

    /* AI cards get a slightly stronger glass + gradient title bar */
    .st-key-elasticity_card, .st-key-discount_card{
        background:linear-gradient(180deg, rgba(30,41,59,0.75) 0%, rgba(15,23,42,0.75) 100%) !important;
        border:1px solid rgba(148,163,184,0.18) !important;
    }

    /* Buttons — subtle lift on hover */
    .stButton>button{transition:transform .15s ease, box-shadow .15s ease;}
    .stButton>button:hover{transform:translateY(-1px);box-shadow:0 6px 18px rgba(59,130,246,0.25);}
    </style>
    """, unsafe_allow_html=True)

    def kmat_header(icon, title, subtitle):
        st.markdown(f"""
        <div class="kmat-header">
            <div class="kmat-header-top">
                <span class="kmat-header-icon">{icon}</span>
                <span class="kmat-header-title">{title}</span>
            </div>
            <div class="kmat-header-sub">{subtitle}</div>
            <div class="kmat-header-rule"></div>
        </div>
        """, unsafe_allow_html=True)

    def kmat_card_title(icon, text):
        st.markdown(f'<div class="kmat-card-title">{(icon + " ") if icon else ""}{text}</div>', unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 1 — QUOTE CONFIGURATION
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🧩", "Quote Configuration", "Select a product, review its cost simulation, and configure the deal")

    if pricing_mode == "Standalone Pricing":
            # ═══════════════════════════════════════════════════════════
            # STANDALONE PRICING — uses SA_* tables loaded in Tab 1,
            # completely independent of the KMAT Cost Model.
            # ═══════════════════════════════════════════════════════════
            product_df = st.session_state.get("KMAT_PRODUCT_MASTER")
            characteristic_master_df = st.session_state.get("CHARACTERISTIC_MASTER")
            characteristic_values_df = st.session_state.get("CHARACTERISTIC_VALUES")
            quote_history_df = st.session_state.get("QUOTE_HISTORY")

            if product_df is None or product_df.empty:
                st.warning("No standalone product data found. Load it in Customer Onboarding first.")
                st.stop()

            top_l, top_r = st.columns([3, 2])
            with top_l:
                with st.container(border=True, key="product_select_card"):
                    kmat_card_title("📦", "Product Selection")
                    product_label_map = {
                        f"{r['PRODUCT_NAME']} ({r['KMAT_ID']})": r["KMAT_ID"]
                        for _, r in product_df.iterrows()
                    }
                    selected_label = st.selectbox(
                        "Product",
                        list(product_label_map.keys()),
                        label_visibility="collapsed"
                    )

                    kmat_id = product_label_map[selected_label]
                    prod_row = product_df[product_df["KMAT_ID"] == kmat_id].iloc[0]
                    product_name = prod_row["PRODUCT_NAME"]  # internal id, standalone has no KMAT_ID

            with top_r:
                with st.container(border=True, key="simulation_run_card"):
                    kmat_card_title("🧮", "Simulation Run")
                    st.caption("Standalone pricing has no cost simulation engine.")
                    simulation_id = "STANDALONE"

            missing_cost = []
            # ------------------------------------------------------------------
            # Standalone Pricing
            # Since no Cost Model is available, use default manufacturing costs
            # for demonstration purposes.
            # ------------------------------------------------------------------

            default_costs = {
                "TRUCK001": {
                    "material": 25000,
                    "labor": 4500,
                    "machine": 3200,
                    "overhead": 1800
                },
                "TRUCK002": {
                    "material": 22000,
                    "labor": 4000,
                    "machine": 3000,
                    "overhead": 1700
                },
                "TRUCK003": {
                    "material": 18000,
                    "labor": 3200,
                    "machine": 2500,
                    "overhead": 1400
                },
                "BUS001": {
                    "material": 35000,
                    "labor": 6500,
                    "machine": 4200,
                    "overhead": 2500
                }
            }

            cost = default_costs.get(kmat_id)

            if cost is None:
                st.error(f"No default pricing data configured for {kmat_id}.")
                st.stop()

            material_cost = cost["material"]
            labor_cost = cost["labor"]
            machine_cost = cost["machine"]
            overhead_cost = cost["overhead"]

            setup_cost = labor_cost

            total_mfg_cost = (
                material_cost
                + labor_cost
                + machine_cost
                + overhead_cost
            )

            # No cost-engine summary table in standalone mode — always fall
            # back to local calculation from the sidebar Pricing Policy.
            target_price  = total_mfg_cost * (1 + target_margin)
            floor_price   = total_mfg_cost * (1 + floor_buffer_pct / 100)
            ceiling_price = target_price   * (1 + ceiling_buffer_pct / 100)
            engine_target_price = None

            component_df = pd.DataFrame([
                {
                    "COMPONENT_ID": "MAT001",
                    "COMPONENT_DESCRIPTION": "Raw Materials",
                    "LINE_MATERIAL_COST_USD": material_cost
                }
            ])

            operation_df = pd.DataFrame([
                {
                    "OPERATION_ID": "LAB001",
                    "OPERATION_DESCRIPTION": "Labor",
                    "LABOR_COST_USD": labor_cost,
                    "MACHINE_COST_USD": machine_cost
                }
            ])

            overhead_df = pd.DataFrame([
                {
                    "OVERHEAD_ID": "OH001",
                    "OVERHEAD_DESCRIPTION": "Factory Overhead",
                    "OVERHEAD_COST_USD": overhead_cost
                }
            ])
            selected_options = {}

            selected_rows = characteristic_values_df[
                characteristic_values_df["KMAT_ID"] == kmat_id
            ]

            for _, row in selected_rows.iterrows():
                selected_options[row["CHARACTERISTIC_NAME"]] = row["SELECTED_VALUE"]

    else:
        # ═══════════════════════════════════════════════════════════
        # INTEGRATED PRICING — KMAT Cost Model (unchanged from before)
        # ═══════════════════════════════════════════════════════════

        # ── 1. Load Products from KMAT_PRODUCT_MASTER ──────────────────────
        try:
            kmat_master_df = session.sql(
                f"SELECT KMAT_ID, DESCRIPTION, PRODUCT_FAMILY, ACTIVE_FLAG FROM {fq('KMAT_PRODUCT_MASTER')}"
            ).to_pandas()
            if "ACTIVE_FLAG" in kmat_master_df.columns:
                kmat_master_df = kmat_master_df[kmat_master_df["ACTIVE_FLAG"].fillna(True).astype(bool)]
            if kmat_master_df.empty:
                st.warning("No KMAT products found. Load data in Customer Onboarding first.")
                st.stop()
        except Exception as e:
            st.error(f"Cannot load KMAT_PRODUCT_MASTER: {e}")
            st.stop()

        top_l, top_r = st.columns([3, 2])

        with top_l:
            with st.container(border=True, key="product_select_card"):
                kmat_card_title("📦", "Product Selection")
                kmat_label_map = {
                    f"{r['DESCRIPTION']}  ({r['KMAT_ID']})": r["KMAT_ID"]
                    for _, r in kmat_master_df.iterrows()
                }
                chosen_label = st.selectbox("Product", list(kmat_label_map.keys()), label_visibility="collapsed")
                kmat_id = kmat_label_map[chosen_label]
                product = kmat_master_df[kmat_master_df["KMAT_ID"] == kmat_id]["DESCRIPTION"].iloc[0]

        # ── 2. Load Simulations for this KMAT_ID ───────────────────────────
        try:
            sim_header_df = session.sql(
                f"SELECT SIMULATION_ID, KMAT_ID, CUSTOMER_ID, SCENARIO_NAME "
                f"FROM {fq('SIMULATION_HEADER')} WHERE KMAT_ID = '{kmat_id}'"
            ).to_pandas()
        except Exception as e:
            st.error(f"Cannot load SIMULATION_HEADER: {e}")
            st.stop()

        with top_r:
            with st.container(border=True, key="simulation_run_card"):
                kmat_card_title("🧮", "Simulation Run")

                sim_mode_options = ["Use existing simulation"]
                sim_proc_name = st.session_state.get("SIMULATION_PROC_NAME")  # set this if/when a proc exists
                if sim_proc_name:
                    sim_mode_options.append("Create new simulation")
                sim_mode = st.radio("Simulation source", sim_mode_options, horizontal=True,
                                     label_visibility="collapsed", key="sim_mode_radio")

                if sim_mode == "Create new simulation" and sim_proc_name:
                    # Optional path — only active if a Snowflake simulation
                    # procedure has been registered in session state.
                    try:
                        char_master_df = session.sql(
                            f"SELECT CHARACTERISTIC_NAME, ALLOWED_VALUE FROM {fq('CHARACTERISTIC_MASTER')} "
                            f"WHERE KMAT_ID = '{kmat_id}' AND ACTIVE_FLAG = TRUE"
                        ).to_pandas()
                    except Exception:
                        char_master_df = pd.DataFrame()

                    new_sim_choices = {}
                    if not char_master_df.empty:
                        for char_name in char_master_df["CHARACTERISTIC_NAME"].unique():
                            opts = char_master_df[char_master_df["CHARACTERISTIC_NAME"] == char_name]["ALLOWED_VALUE"].tolist()
                            new_sim_choices[char_name] = st.selectbox(char_name, opts, key=f"newsim_{char_name}")

                    if st.button("▶ Run New Simulation", key="run_new_sim"):
                        try:
                            result = session.sql(
                                f"CALL {sim_proc_name}('{kmat_id}', PARSE_JSON('{json.dumps(new_sim_choices)}'))"
                            ).collect()
                            st.success("New simulation created — refresh below to select it.")
                            st.rerun()
                        except Exception as e:
                            st.error(f"Simulation procedure failed: {e}")
                    st.stop()  # wait for the new run before continuing this render

                if sim_header_df.empty:
                    st.warning(f"No simulations found for **{product}**. Run a cost simulation upstream first.")
                    st.stop()

                sim_label_map = {
                    f"{r['SIMULATION_ID']} — {r.get('SCENARIO_NAME') or 'Scenario'} (Cust: {r.get('CUSTOMER_ID') or 'n/a'})": r["SIMULATION_ID"]
                    for _, r in sim_header_df.iterrows()
                }
                chosen_sim_label = st.selectbox("Simulation", list(sim_label_map.keys()), label_visibility="collapsed")
                simulation_id = sim_label_map[chosen_sim_label]

        missing_cost = []

        # ── 3. Cost Summary (KMAT_CONFIGURED_COST_SUMMARY) ──────────────────
        try:
            summary_df = session.sql(
                f"SELECT * FROM {fq('KMAT_CONFIGURED_COST_SUMMARY')} "
                f"WHERE SIMULATION_ID = '{simulation_id}' AND KMAT_ID = '{kmat_id}'"
            ).to_pandas()
        except Exception as e:
            st.error(f"Cannot load KMAT_CONFIGURED_COST_SUMMARY: {e}")
            st.stop()

        if summary_df.empty:
            st.error(f"No configured cost summary found for simulation **{simulation_id}**.")
            st.stop()

        summary_row = summary_df.iloc[0]

        # ── 4. Component Costs → Material ───────────────────────────────────
        try:
            component_df = session.sql(
                f"SELECT * FROM {fq('KMAT_CONFIGURED_COMPONENT_COSTS')} WHERE SIMULATION_ID = '{simulation_id}'"
            ).to_pandas()
            material_cost = float(component_df["LINE_MATERIAL_COST_USD"].sum()) if not component_df.empty else 0.0
        except Exception:
            missing_cost.append("Component Costs")
            component_df, material_cost = pd.DataFrame(), 0.0

        # ── 5. Operation Costs → Labor + Machine ────────────────────────────
        try:
            operation_df = session.sql(
                f"SELECT * FROM {fq('KMAT_CONFIGURED_OPERATION_COSTS')} WHERE SIMULATION_ID = '{simulation_id}'"
            ).to_pandas()
            labor_cost   = float(operation_df["LABOR_COST_USD"].sum())   if not operation_df.empty else 0.0
            machine_cost = float(operation_df["MACHINE_COST_USD"].sum()) if not operation_df.empty else 0.0
        except Exception:
            missing_cost.append("Operation Costs")
            operation_df, labor_cost, machine_cost = pd.DataFrame(), 0.0, 0.0

        # ── 6. Overhead Costs ────────────────────────────────────────────────
        try:
            overhead_df = session.sql(
                f"SELECT * FROM {fq('KMAT_CONFIGURED_OVERHEAD_COSTS')} WHERE SIMULATION_ID = '{simulation_id}'"
            ).to_pandas()
            overhead_cost = float(overhead_df["OVERHEAD_COST_USD"].sum()) if not overhead_df.empty else 0.0
        except Exception:
            missing_cost.append("Overhead Costs")
            overhead_df, overhead_cost = pd.DataFrame(), 0.0

        setup_cost = labor_cost

        if "TOTAL_CONFIGURED_COST_USD" in summary_row and pd.notna(summary_row["TOTAL_CONFIGURED_COST_USD"]):
            total_mfg_cost = float(summary_row["TOTAL_CONFIGURED_COST_USD"])
        else:
            total_mfg_cost = material_cost + labor_cost + machine_cost + overhead_cost

        if missing_cost:
            st.markdown(
                f'<div class="insight-box warn">⚠ Incomplete cost data: {", ".join(missing_cost)}.</div>',
                unsafe_allow_html=True
            )

        # Prefer the cost engine's own price band; fall back to sidebar
        # policy math only if the engine didn't populate these fields.
        def _engine_or_fallback(col, fallback):
            return float(summary_row[col]) if col in summary_row and pd.notna(summary_row[col]) else fallback

        _fallback_target  = total_mfg_cost * (1 + target_margin)
        _fallback_floor    = total_mfg_cost * (1 + floor_buffer_pct / 100)
        _fallback_ceiling  = _fallback_target * (1 + ceiling_buffer_pct / 100)

        target_price  = _engine_or_fallback("TARGET_PRICE_USD",  _fallback_target)
        floor_price   = _engine_or_fallback("FLOOR_PRICE_USD",   _fallback_floor)
        ceiling_price = _engine_or_fallback("CEILING_PRICE_USD", _fallback_ceiling)

        engine_target_price = (
            float(summary_row["TARGET_PRICE_USD"])
            if "TARGET_PRICE_USD" in summary_row and pd.notna(summary_row["TARGET_PRICE_USD"])
            else None
        )

        # ── 7. Characteristics baked into this simulation (read-only) ───────
        try:
            char_values_df = session.sql(
                f"SELECT CHARACTERISTIC_NAME, SELECTED_VALUE FROM {fq('CHARACTERISTIC_VALUES')} "
                f"WHERE SIMULATION_ID = '{simulation_id}' AND KMAT_ID = '{kmat_id}'"
            ).to_pandas()
            selected_options = (
                dict(zip(char_values_df["CHARACTERISTIC_NAME"], char_values_df["SELECTED_VALUE"]))
                if not char_values_df.empty else {}
            )
        except Exception:
            selected_options = {}

    # Kept for pipeline compatibility in both modes — surcharges don't
    # exist in either the KMAT Cost Model or the standalone schema.
    total_surcharge = 0.0

    config_col, summary_col = st.columns([3, 2])

    with config_col:
        with st.container(border=True, key="characteristics_card"):
            kmat_card_title("🧬", "Configured Characteristics (Read-only)")
            if pricing_mode == "Standalone Pricing":
                st.caption("Standalone pricing has no characteristic configuration step.")
            else:
                st.caption(f"These values were fixed when simulation **{simulation_id}** was run upstream and can't be edited here.")
            if selected_options:
                chip_html = "".join(
                    f'<div class="config-chip"><div class="chip-label">{k}</div><div class="chip-value">{v}</div></div>'
                    for k, v in selected_options.items()
                )
                st.markdown(chip_html, unsafe_allow_html=True)
            else:
                st.caption("No characteristic selections recorded for this simulation.")

            if engine_target_price is not None:
                st.markdown(
                    f'<div class="note-soft">📎 Cost engine reference target price: <strong>{fmt_currency(engine_target_price)}</strong> '
                    f'— shown for reference only. Pricing below is driven by the sidebar Pricing Policy.</div>',
                    unsafe_allow_html=True
                )

        with st.container(border=True, key="volume_discount_card"):
            kmat_card_title("📦", "Volume & Discount")
            order_qty = st.slider("Order Quantity (units)", 1, 500, 1, 1)
            volume_discount_pct, active_tier_idx = get_volume_discount_pct(order_qty)
            st.markdown(render_tier_table_html(order_qty), unsafe_allow_html=True)
            if volume_discount_pct > 0:
                st.markdown(f'<div class="insight-box ok" style="margin-top:10px;">Volume discount of <strong>{volume_discount_pct:.1f}%</strong> applied.</div>', unsafe_allow_html=True)
            manual_discount_pct = st.slider("Additional Discount %", 0.0, 20.0, 0.0, 0.5)
            total_discount_pct  = volume_discount_pct + manual_discount_pct

        with st.container(border=True, key="competitor_card"):
            kmat_card_title("🏁", "Competitor Benchmarking")
            competitor_data = []
            n_comps = st.number_input("Number of competitors", 0, 8, 2, 1, key="n_comps")
            comp_cols = st.columns(2) if n_comps > 0 else []
            for ci in range(int(n_comps)):
                with comp_cols[ci % 2]:
                    c_name  = st.text_input(f"Competitor {ci+1} name", value=f"Competitor {ci+1}", key=f"comp_name_{ci}")
                    c_price = st.number_input(f"Price ({currency_symbol})", value=float(target_price), min_value=0.0, step=100.0, key=f"comp_price_{ci}")
                    competitor_data.append({"name": c_name, "price": c_price})

            if competitor_data:
                avg_comp = sum(c["price"] for c in competitor_data) / len(competitor_data)
                min_comp = min(c["price"] for c in competitor_data)
                max_comp = max(c["price"] for c in competitor_data)
                st.markdown(f"""
                <div class="elast-card" style="margin-top:10px;">
                  <div class="elast-row"><span class="elast-label">Market Avg</span><span class="elast-val">{fmt_currency(avg_comp)}</span></div>
                  <div class="elast-row"><span class="elast-label">Market Low</span><span class="elast-val">{fmt_currency(min_comp)}</span></div>
                  <div class="elast-row"><span class="elast-label">Market High</span><span class="elast-val">{fmt_currency(max_comp)}</span></div>
                </div>""", unsafe_allow_html=True)

    with summary_col:
        with st.container(border=True, key="quote_summary_card"):
            kmat_card_title("🧾", "Quote Summary")
            st.markdown(f"<small style='color:#64748b'>Simulation:</small> **{simulation_id}**", unsafe_allow_html=True)
            st.markdown("---")

            suggested_actual = target_price * (1 - total_discount_pct / 100)
            actual_price = st.slider(
                "Quoted Price",
                min_value=float(floor_price * 0.8), max_value=float(ceiling_price * 1.2),
                value=float(suggested_actual),
                step=float(max(1.0, (ceiling_price - floor_price) / 200)),
                format=f"{currency_symbol}%.0f"
            )

            leakage         = target_price - actual_price
            leakage_percent = (leakage / target_price * 100) if target_price else 0
            achieved_margin = (actual_price - total_mfg_cost) / actual_price * 100 if actual_price else 0
            risk_label, risk_color = classify_risk(leakage_percent)

            health_result = compute_quote_health_score(
                achieved_margin, target_margin_pct,
                leakage_percent, healthy_threshold, warning_threshold,
                actual_price, floor_price, ceiling_price,
                volume_discount_pct, manual_discount_pct,
                competitor_data if competitor_data else None
            )

            st.markdown(f"""
            <div class="kpi-grid" style="grid-template-columns:1fr 1fr;gap:10px;margin-top:16px;">
                {render_kpi("Material Cost",   fmt_currency(material_cost))}
                {render_kpi("Labor Cost",      fmt_currency(labor_cost))}
                {render_kpi("Machine Cost",    fmt_currency(machine_cost))}
                {render_kpi("Overhead Cost",   fmt_currency(overhead_cost))}
                {render_kpi("Floor Price",     fmt_currency(floor_price),  "green")}
                {render_kpi("Target Price",    fmt_currency(target_price), "blue")}
                {render_kpi("Ceiling Price",   fmt_currency(ceiling_price),"amber")}
                {render_kpi("Actual Quoted",   fmt_currency(actual_price), risk_color)}
                {render_kpi("Margin Achieved", f"{achieved_margin:.1f}%",  "green" if achieved_margin >= target_margin_pct else "red")}
            </div>
            """, unsafe_allow_html=True)

        with st.container(border=True, key="quote_health_card"):
            kmat_card_title("🩺", "Quote Health & Market Position")

            st.markdown(f"""
            <div style="background:#111827;border:1px solid #1e2d47;border-radius:12px;padding:16px;">
                <div style="display:flex;justify-content:space-between;align-items:center;">
                    <span style="font-size:13px;color:#94a3b8;">Revenue Leakage</span>
                    <span class="badge {risk_color}">{risk_label}</span>
                </div>
                <div style="font-size:22px;font-weight:700;color:#f1f5f9;margin-top:6px;" class="mono">
                    {fmt_currency(leakage)} <span style="font-size:14px;color:#64748b;">({leakage_percent:.1f}%)</span>
                </div>
            </div>
            """, unsafe_allow_html=True)

            hs = health_result["total_score"]
            hs_color = "#10b981" if hs >= 70 else ("#f59e0b" if hs >= 40 else "#ef4444")
            st.markdown(f"""
            <div style="margin-top:10px;background:#111827;border:1px solid #1e2d47;border-radius:12px;padding:14px 16px;">
                <div style="display:flex;justify-content:space-between;align-items:center;">
                    <span style="font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:0.5px;">Quote Health Score</span>
                    <span class="routing-badge {health_result['routing_class']}">{health_result['routing_icon']} {health_result['routing']}</span>
                </div>
                <div style="font-size:30px;font-weight:700;color:{hs_color};font-family:'JetBrains Mono',monospace;margin-top:6px;">{hs}<span style="font-size:14px;color:#64748b;">/100</span></div>
                <div class="health-bar-wrap"><div class="health-bar-fill" style="width:{hs}%;background:{hs_color};"></div></div>
                <div style="font-size:11px;color:#64748b;margin-top:4px;">{health_result['routing_desc']}</div>
            </div>
            """, unsafe_allow_html=True)

            if show_margin_gauge:
                st.markdown(price_band_html(floor_price, target_price, ceiling_price, actual_price,
                                            competitors=competitor_data if competitor_data else None), unsafe_allow_html=True)

            if competitor_data and show_ai_insights:
                avg_comp = sum(c["price"] for c in competitor_data) / len(competitor_data)
                if actual_price < avg_comp * 0.9:
                    st.markdown(f'<div class="insight-box ok">💡 Your quote is <strong>{((avg_comp - actual_price)/avg_comp*100):.1f}% below</strong> market average ({fmt_currency(avg_comp)}). Room to increase price.</div>', unsafe_allow_html=True)
                elif actual_price > avg_comp * 1.1:
                    st.markdown(f'<div class="insight-box warn">⚠ Your quote is <strong>{((actual_price - avg_comp)/avg_comp*100):.1f}% above</strong> market average ({fmt_currency(avg_comp)}).</div>', unsafe_allow_html=True)
                else:
                    st.markdown(f'<div class="insight-box">📌 Quote broadly in line with market average ({fmt_currency(avg_comp)}).</div>', unsafe_allow_html=True)

            if show_ai_insights:
                if actual_price < floor_price:
                    st.markdown('<div class="insight-box alert">🚨 Quoted price is below the floor. This deal is loss-making.</div>', unsafe_allow_html=True)
                elif actual_price > ceiling_price:
                    st.markdown('<div class="insight-box warn">⚠ Quoted price exceeds ceiling. Verify market acceptance.</div>', unsafe_allow_html=True)
                elif leakage_percent >= warning_threshold:
                    st.markdown(f'<div class="insight-box alert">🔴 Leakage at {leakage_percent:.1f}%. Raise quoted price by at least {fmt_currency(leakage * 0.5)}.</div>', unsafe_allow_html=True)
                elif leakage_percent >= healthy_threshold:
                    st.markdown(f'<div class="insight-box warn">🟡 Moderate leakage ({leakage_percent:.1f}%). Tighten discount authority.</div>', unsafe_allow_html=True)
                else:
                    st.markdown('<div class="insight-box ok">🟢 Pricing within healthy parameters. Margin is protected.</div>', unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 2 — AI PRICING INTELLIGENCE  (flagship, full-width, glass)
    # Elasticity Modeler + Discount Optimizer moved here verbatim — no
    # calculation, variable, or session_state change, only presentation.
    # ══════════════════════════════════════════════════════════════════════
    with st.container(key="ai_intel_section"):
        kmat_header("🤖", "AI Pricing Intelligence", "AI-powered optimization and pricing recommendations")

        ai_left, ai_right = st.columns(2)

        # ── LEFT: Price Elasticity Modeler ──────────────────────────────
        with ai_left:
            with st.container(border=True, key="elasticity_card"):
                kmat_card_title("📈", "Price Elasticity Modeler")
                with st.expander("Model demand impact of price changes", expanded=True):
                    elas_c1, elas_c2 = st.columns(2)
                    with elas_c1:
                        base_demand    = st.number_input("Baseline demand (units/period)", value=100, min_value=1, step=10, key="elas_demand")
                        elasticity_coef = st.slider("Price Elasticity Coefficient", min_value=-5.0, max_value=-0.1, value=-1.2, step=0.1, key="elas_coef")
                    with elas_c2:
                        price_scenarios = [("−10%", actual_price*0.90),("−5%",actual_price*0.95),
                                           ("Current",actual_price),("+5%",actual_price*1.05),
                                           ("+10%",actual_price*1.10),("+15%",actual_price*1.15),("+20%",actual_price*1.20)]
                        rows_elas = []
                        for label, test_price in price_scenarios:
                            res = compute_elasticity(actual_price, base_demand, elasticity_coef, test_price)
                            rows_elas.append({"Δ Price": label,"Price": fmt_currency(test_price),
                                              "Demand (units)": f"{res['new_demand']:.0f}",
                                              "Revenue": fmt_currency(res["new_revenue"]),
                                              "Rev Δ": f"{res['delta_revenue_pct']:+.1f}%"})
                        st.dataframe(pd.DataFrame(rows_elas), use_container_width=True, hide_index=True)

                    price_range = [actual_price * (0.7 + i * 0.02) for i in range(31)]
                    revenues = [compute_elasticity(actual_price, base_demand, elasticity_coef, p)["new_revenue"] for p in price_range]
                    demands  = [compute_elasticity(actual_price, base_demand, elasticity_coef, p)["new_demand"]  for p in price_range]
                    optimal_idx     = revenues.index(max(revenues))
                    optimal_price   = price_range[optimal_idx]
                    optimal_revenue = revenues[optimal_idx]

                    fig_elas = go.Figure()
                    fig_elas.add_trace(go.Scatter(x=price_range, y=revenues, name="Revenue", line=dict(color="#3b82f6", width=2), mode="lines"))
                    fig_elas.add_trace(go.Scatter(x=price_range,
                        y=[d * (ceiling_price - floor_price) / max(demands) * max(revenues) / (ceiling_price - floor_price) for d in demands],
                        name="Demand (scaled)", line=dict(color="#8b5cf6", width=1.5, dash="dot"), mode="lines"))
                    cur_rev = compute_elasticity(actual_price, base_demand, elasticity_coef, actual_price)["new_revenue"]
                    fig_elas.add_trace(go.Scatter(x=[actual_price], y=[cur_rev], name="Current",
                        mode="markers", marker=dict(color="#10b981", size=10)))
                    fig_elas.add_trace(go.Scatter(x=[optimal_price], y=[optimal_revenue], name="Revenue-optimal",
                        mode="markers", marker=dict(color="#f59e0b", size=12, symbol="star")))
                    fig_elas.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                        font_color="#94a3b8", height=240, margin=dict(l=0,r=0,t=10,b=0),
                        legend=dict(bgcolor="rgba(0,0,0,0)"),
                        xaxis=dict(gridcolor="#1e293b",title="Price"), yaxis=dict(gridcolor="#1e293b",title="Revenue"))
                    st.plotly_chart(fig_elas, use_container_width=True)

                    opt_margin = (optimal_price - total_mfg_cost) / optimal_price * 100 if optimal_price else 0
                    st.markdown(f"""
                    <div class="elast-card">
                      <div class="elast-row"><span class="elast-label">⭐ Revenue-Optimal Price</span><span class="elast-val pos">{fmt_currency(optimal_price)}</span></div>
                      <div class="elast-row"><span class="elast-label">Max Estimated Revenue</span><span class="elast-val pos">{fmt_currency(optimal_revenue)}</span></div>
                      <div class="elast-row"><span class="elast-label">Margin at Optimal Price</span><span class="elast-val {'pos' if opt_margin >= target_margin_pct else 'neg'}">{opt_margin:.1f}%</span></div>
                      <div class="elast-row"><span class="elast-label">Revenue vs Current Quote</span><span class="elast-val {'pos' if optimal_revenue >= cur_rev else 'neg'}">{fmt_currency(optimal_revenue - cur_rev)} ({(optimal_revenue - cur_rev)/cur_rev*100:+.1f}%)</span></div>
                    </div>""", unsafe_allow_html=True)

        # ── RIGHT: Dynamic Discount Optimization Engine ─────────────────
        with ai_right:
            with st.container(border=True, key="discount_card"):
                kmat_card_title("💰", "AI Discount Optimization")
                with st.expander("Recommend optimal customer discount", expanded=True):
                    ddo_c1, ddo_c2, ddo_c3 = st.columns(3)
                    with ddo_c1:
                        customer_tier = st.selectbox("Customer Tier", ["Bronze", "Silver", "Gold", "Platinum"], key="ddo_tier")
                    with ddo_c2:
                        competitor_price_input = st.number_input(
                            f"Competitor Price ({currency_symbol}) — optional", min_value=0.0, value=0.0, step=100.0, key="ddo_comp_price"
                        )
                    with ddo_c3:
                        max_allowed_discount_pct = st.slider("Maximum Allowed Discount %", 0.0, 20.0, 20.0, 0.5, key="ddo_max_discount")

                    # ── Volume Discount ──
                    if order_qty <= 25:
                        ddo_volume_discount = 0.0
                    elif order_qty <= 50:
                        ddo_volume_discount = 2.0
                    elif order_qty <= 100:
                        ddo_volume_discount = 4.0
                    elif order_qty <= 250:
                        ddo_volume_discount = 6.0
                    else:
                        ddo_volume_discount = 8.0

                    # ── Customer Tier Discount ──
                    ddo_tier_discount_map = {"Bronze": 0.0, "Silver": 1.0, "Gold": 2.0, "Platinum": 3.0}
                    ddo_tier_discount = ddo_tier_discount_map[customer_tier]

                    # ── Competitor Adjustment ──
                    if competitor_price_input > 0 and competitor_price_input < target_price:
                        ddo_gap_pct = (target_price - competitor_price_input) / target_price * 100
                        ddo_competitor_adjustment = min(3.0, ddo_gap_pct)
                    else:
                        ddo_competitor_adjustment = 0.0

                    ddo_raw_discount = ddo_volume_discount + ddo_tier_discount + ddo_competitor_adjustment

                    # ── Margin Protection (never let final margin fall below 20%) ──
                    ddo_min_margin_pct = 20.0
                    ddo_min_price_for_margin = (
                        total_mfg_cost / (1 - ddo_min_margin_pct / 100) if total_mfg_cost > 0 else 0.0
                    )
                    ddo_price_at_raw_discount = target_price * (1 - ddo_raw_discount / 100)
                    ddo_margin_protection_cut = 0.0
                    if target_price > 0 and ddo_price_at_raw_discount < ddo_min_price_for_margin:
                        ddo_max_discount_for_margin = max(0.0, (1 - ddo_min_price_for_margin / target_price) * 100)
                        ddo_margin_protection_cut = ddo_raw_discount - ddo_max_discount_for_margin
                        ddo_raw_discount = ddo_max_discount_for_margin

                    # ── Cap using Maximum Allowed Discount ──
                    ddo_final_discount = min(ddo_raw_discount, max_allowed_discount_pct)

                    ddo_recommended_price = target_price * (1 - ddo_final_discount / 100)
                    ddo_expected_margin_pct = (
                        (ddo_recommended_price - total_mfg_cost) / ddo_recommended_price * 100
                        if ddo_recommended_price else 0.0
                    )
                    ddo_expected_revenue = ddo_recommended_price * order_qty

                    # ── Deal Health (reuses existing scoring function) ──
                    ddo_health_result = compute_quote_health_score(
                        ddo_expected_margin_pct, target_margin_pct,
                        ddo_final_discount, healthy_threshold, warning_threshold,
                        ddo_recommended_price, floor_price, ceiling_price,
                        ddo_volume_discount, ddo_tier_discount + ddo_competitor_adjustment,
                        competitor_data if competitor_data else None
                    )

                    # ── Output Cards ──
                    ddo_k1, ddo_k2, ddo_k3 = st.columns(3)
                    with ddo_k1:
                        st.metric("Recommended Discount", f"{ddo_final_discount:.1f}%")
                    with ddo_k2:
                        st.metric("Recommended Price", fmt_currency(ddo_recommended_price))
                    with ddo_k3:
                        st.metric("Expected Margin", f"{ddo_expected_margin_pct:.1f}%")
                    ddo_k4, ddo_k5 = st.columns(2)
                    with ddo_k4:
                        st.metric("Expected Revenue", fmt_currency(ddo_expected_revenue))
                    with ddo_k5:
                        st.markdown(f"""
                        <div style="padding-top:4px;">
                            <div style="font-size:14px;color:#94a3b8;">Deal Health</div>
                            <div style="font-size:1.6rem;font-weight:600;color:#f1f5f9;line-height:1.3;white-space:normal;overflow-wrap:break-word;">
                                {ddo_health_result['routing_icon']} {ddo_health_result['routing']}
                            </div>
                        </div>
                        """, unsafe_allow_html=True)

                    # ── Discount Breakdown ──
                    st.markdown('<div class="kmat-card-title" style="margin-top:14px;border:none;padding-bottom:0;">Discount Breakdown</div>', unsafe_allow_html=True)
                    st.markdown(f"""
                    <div class="elast-card">
                      <div class="elast-row"><span class="elast-label">✔ Volume Discount</span><span class="elast-val">{ddo_volume_discount:.1f}%</span></div>
                      <div class="elast-row"><span class="elast-label">✔ Customer Loyalty ({customer_tier})</span><span class="elast-val">{ddo_tier_discount:.1f}%</span></div>
                      <div class="elast-row"><span class="elast-label">✔ Competitor Adjustment</span><span class="elast-val">{ddo_competitor_adjustment:.1f}%</span></div>
                      <div class="elast-row"><span class="elast-label">✔ Margin Protection</span><span class="elast-val neg">-{ddo_margin_protection_cut:.1f}%</span></div>
                      <div class="elast-row" style="border-top:1px solid #1e2d47;margin-top:6px;padding-top:6px;">
                        <span class="elast-label" style="font-weight:700;">Final Recommended Discount</span>
                        <span class="elast-val pos" style="font-weight:700;">{ddo_final_discount:.1f}%</span>
                      </div>
                    </div>
                    """, unsafe_allow_html=True)

                    # ── Gauge ──
                    if ddo_final_discount <= 8:
                        ddo_gauge_color = "#10b981"
                    elif ddo_final_discount <= 15:
                        ddo_gauge_color = "#f59e0b"
                    else:
                        ddo_gauge_color = "#ef4444"

                    fig_ddo_gauge = go.Figure(go.Indicator(
                        mode="gauge+number",
                        value=ddo_final_discount,
                        number={"suffix": "%", "font": {"color": "#f1f5f9"}},
                        gauge={
                            "axis": {"range": [0, 20], "tickcolor": "#94a3b8"},
                            "bar": {"color": ddo_gauge_color},
                            "steps": [
                                {"range": [0, 8], "color": "rgba(16,185,129,0.2)"},
                                {"range": [8, 15], "color": "rgba(245,158,11,0.2)"},
                                {"range": [15, 20], "color": "rgba(239,68,68,0.2)"},
                            ],
                            "threshold": {
                                "line": {"color": ddo_gauge_color, "width": 3},
                                "thickness": 0.8,
                                "value": ddo_final_discount,
                            },
                        },
                    ))
                    fig_ddo_gauge.update_layout(
                        paper_bgcolor="rgba(0,0,0,0)", font_color="#94a3b8",
                        height=220, margin=dict(l=20, r=20, t=30, b=10),
                    )
                    st.plotly_chart(fig_ddo_gauge, use_container_width=True)

                    # Persist so the Save Quote block / downstream tabs can reference it
                    st.session_state["dynamic_discount_recommendation"] = {
                        "product": product_name, "kmat_id": kmat_id, "simulation_id": simulation_id,
                        "customer_tier": customer_tier, "competitor_price": competitor_price_input,
                        "volume_discount": ddo_volume_discount, "tier_discount": ddo_tier_discount,
                        "competitor_adjustment": ddo_competitor_adjustment,
                        "margin_protection_cut": ddo_margin_protection_cut,
                        "final_discount_pct": ddo_final_discount,
                        "recommended_price": ddo_recommended_price,
                        "expected_margin_pct": ddo_expected_margin_pct,
                        "expected_revenue": ddo_expected_revenue,
                        "deal_health": ddo_health_result["routing"],
                    }

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 3 — COST & QUOTE ANALYSIS
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("📊", "Cost & Quote Analysis", "Manufacturing cost breakdown, price waterfall, and order finalization")

    with st.container(border=True, key="mfg_cost_card"):
        kmat_card_title("🏭", "Manufacturing Cost Breakdown")

        cost_df = pd.DataFrame({
            "Cost Component": [
                "Material",
                "Labor",
                "Machine",
                "Overhead"
            ],
            "Cost": [
                material_cost,
                labor_cost,
                machine_cost,
                overhead_cost
            ]
        })

        fig_cost = px.bar(
            cost_df,
            x="Cost",
            y="Cost Component",
            orientation="h",
            text="Cost",
        )

        fig_cost.update_traces(
            texttemplate=f"{currency_symbol}%{{x:,.0f}}",
            textposition="outside"
        )

        fig_cost.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font_color="#94a3b8",
            height=320,
            showlegend=False,
            margin=dict(l=20, r=20, t=20, b=20),
            xaxis_title="Cost",
            yaxis_title=""
        )

        fig_cost.update_xaxes(
            gridcolor="#1e293b",
            zeroline=False
        )

        fig_cost.update_yaxes(
            categoryorder="total ascending"
        )

        st.plotly_chart(fig_cost, use_container_width=True)

        st.metric(
            "Total Manufacturing Cost",
            fmt_currency(total_mfg_cost)
        )

        det_c1, det_c2, det_c3, det_c4 = st.columns(4)
        with det_c1:
            with st.expander(f"Material  {fmt_currency(material_cost)}"):
                if component_df.empty:
                    st.caption("No data.")
                else:
                    cols = [c for c in ["COMPONENT_ID","COMPONENT_DESCRIPTION","LINE_MATERIAL_COST_USD"] if c in component_df.columns]
                    st.dataframe(format_currency(component_df[cols], ["LINE_MATERIAL_COST_USD"]), use_container_width=True)
        with det_c2:
            with st.expander(f"Labor  {fmt_currency(labor_cost)}"):
                if operation_df.empty:
                    st.caption("No data.")
                else:
                    cols = [c for c in ["OPERATION_ID","OPERATION_DESCRIPTION","LABOR_COST_USD"] if c in operation_df.columns]
                    st.dataframe(format_currency(operation_df[cols], ["LABOR_COST_USD"]), use_container_width=True)
        with det_c3:
            with st.expander(f"Machine  {fmt_currency(machine_cost)}"):
                if operation_df.empty:
                    st.caption("No data.")
                else:
                    cols = [c for c in ["OPERATION_ID","OPERATION_DESCRIPTION","MACHINE_COST_USD"] if c in operation_df.columns]
                    st.dataframe(format_currency(operation_df[cols], ["MACHINE_COST_USD"]), use_container_width=True)
        with det_c4:
            with st.expander(f"Overhead  {fmt_currency(overhead_cost)}"):
                if overhead_df.empty:
                    st.caption("No data.")
                else:
                    cols = [c for c in ["OVERHEAD_ID","OVERHEAD_DESCRIPTION","OVERHEAD_COST_USD"] if c in overhead_df.columns]
                    st.dataframe(format_currency(overhead_df[cols], ["OVERHEAD_COST_USD"]), use_container_width=True)

    with st.container(border=True, key="selling_price_card"):
        kmat_card_title("💵", "Selling Price Breakdown")
        bkdn = [{"Line Item": f"{product_name} — Configured Cost (Simulation {simulation_id})", "Amount": total_mfg_cost}]
        bkdn.append({"Line Item": f"Target Markup ({target_margin_pct}%)", "Amount": target_price - total_mfg_cost})
        if total_discount_pct:
            bkdn.append({"Line Item": f"Volume ({volume_discount_pct:.1f}%) + Manual ({manual_discount_pct:.1f}%) = {total_discount_pct:.1f}%",
                         "Amount": -target_price * total_discount_pct / 100})
        bkdn.append({"Line Item": "Final Quoted Price", "Amount": actual_price})
        st.dataframe(pd.DataFrame(bkdn), use_container_width=True)

        if order_qty > 1:
            st.markdown('<div class="kmat-card-title" style="margin-top:16px;border:none;padding-bottom:0;">Order Summary</div>', unsafe_allow_html=True)
            order_value   = actual_price * order_qty
            order_leakage = leakage * order_qty
            order_cost    = total_mfg_cost * order_qty
            order_margin  = order_value - order_cost
            ocols = st.columns(4)
            with ocols[0]: st.metric("Order Qty",    f"{order_qty} units")
            with ocols[1]: st.metric("Order Value",  fmt_currency(order_value))
            with ocols[2]: st.metric("Order Margin", fmt_currency(order_margin))
            with ocols[3]: st.metric("Total Leakage",fmt_currency(order_leakage))

    with st.container(border=True, key="customer_save_card"):
        kmat_card_title("🧾", "Customer & Quote Finalization")

        # Always define a default first — guarantees selected_customer exists
        # no matter which branch below runs, or whether it runs at all.
        selected_customer = ""

        customer_names = []
        try:
            customer_df = session.table(fq_pricing("CUSTOMER_MASTER")).to_pandas()
            customer_names = customer_df["CUSTOMER_NAME"].dropna().tolist()
        except Exception:
            customer_names = []

        if customer_names:
            selected_customer = st.selectbox("Customer", customer_names, key="cfg_customer_select")
        else:
            st.caption("Customer master not available — enter the customer name manually.")
            selected_customer = st.text_input("Customer Name", value="", key="cfg_customer_manual")

        # ── Save Quote ─────────────────────────────────────────────────────
        st.markdown("---")
        if st.button("💾  Save Quote", type="primary"):
            if not selected_customer:
                st.error("Please select or enter a customer name before saving.")
                st.stop()
            quote_df = pd.DataFrame([{
                        "QUOTE_ID": str(uuid.uuid4())[:8],

                        "TIMESTAMP": datetime.now(),

                        "CUSTOMER_NAME": selected_customer,
                        "PRODUCT": product_name,
                        "SIMULATION_ID": simulation_id,
                        "KMAT_ID": kmat_id,
                        "TARGET_PRICE": float(target_price),
                        "ACTUAL_PRICE": float(actual_price),
                        "LEAKAGE": float(leakage),
                        "MATERIAL_COST": float(material_cost),
                        "MACHINE_COST": float(machine_cost),
                        "SETUP_COST": float(setup_cost),          # = labor cost under the KMAT model
                        "OVERHEAD_COST": float(overhead_cost),
                        "TOTAL_MANUFACTURING_COST": float(total_mfg_cost),
                        "ACHIEVED_MARGIN_PCT": float(achieved_margin),
                        "ORDER_QTY": int(order_qty),
                        "HEALTH_SCORE": health_result["total_score"],
                        "APPROVAL_ROUTING": health_result["routing"],
                    }])
            try:
                # QUOTE_HISTORY belongs to the Pricing Model and always lives in
                # KMAT_PRICING — never in the Cost Model database.
                session.write_pandas(
                    quote_df,
                    "QUOTE_HISTORY",
                    database=PRICING_DB,
                    schema=PRICING_CORE_OUTPUT_SCHEMA,
                    auto_create_table=True, overwrite=False
                )
                st.success(f"✓ Quote saved to {PRICING_DB}.{PRICING_CORE_OUTPUT_SCHEMA}.QUOTE_HISTORY")
            except Exception as e:
                st.error(f"Save failed: {e}")

    st.session_state["quote"] = {
        "product": product_name, "kmat_id": kmat_id, "simulation_id": simulation_id,
        "selected_options": selected_options, "total_surcharge": float(total_surcharge),
        "target_price": float(target_price), "actual_price": float(actual_price),
        "leakage_percent": float(leakage_percent), "achieved_margin": float(achieved_margin),
        "health_score": health_result["total_score"], "routing": health_result["routing"],
        "material_cost": material_cost, "machine_cost": machine_cost,
        "setup_cost": setup_cost, "overhead_cost": overhead_cost,
        "total_mfg_cost": total_mfg_cost, "floor_price": float(floor_price),
        "ceiling_price": float(ceiling_price), "leakage": float(leakage),
        "order_qty": order_qty, "volume_discount_pct": volume_discount_pct,
        "manual_discount_pct": manual_discount_pct, "competitor_data": competitor_data,
    }
# ===================================================
# TAB 3 — ANALYTICS
# ===================================================
with tab3:
    if "TABLE_MAP" not in st.session_state:
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()
    try:
        quotes = session.sql(f"SELECT * FROM {fq_pricing('QUOTE_HISTORY')} ORDER BY TIMESTAMP DESC").to_pandas()
    except Exception:
        quotes = pd.DataFrame()

    required_cols = {"PRODUCT","TARGET_PRICE","ACTUAL_PRICE","LEAKAGE","TIMESTAMP",
                     "MATERIAL_COST","MACHINE_COST","SETUP_COST","OVERHEAD_COST","TOTAL_MANUFACTURING_COST"}

    if quotes.empty:
        st.markdown('<div class="insight-box">No quotes saved yet. Create and save a quote from the Configure Quote tab.</div>', unsafe_allow_html=True)
        st.stop()

    if not required_cols.issubset(set(quotes.columns)):
        st.error("QUOTE_HISTORY schema mismatch. Drop and recreate:")
        st.code(f"DROP TABLE IF EXISTS {fq_pricing('QUOTE_HISTORY')};", language="sql")
        st.stop()

    # ── Original derived columns — UNCHANGED formulas ──────────────────────
    quotes["LEAKAGE_PERCENT"] = (quotes["LEAKAGE"] / quotes["TARGET_PRICE"]) * 100
    quotes["RISK_LEVEL"] = quotes["LEAKAGE_PERCENT"].apply(lambda x: classify_risk(x)[0])
    quotes["RISK_COLOR"] = quotes["LEAKAGE_PERCENT"].apply(lambda x: classify_risk(x)[1])

    # ══════════════════════════════════════════════════════════════════════
    # PREMIUM UI LAYER — styling + layout helpers only. No calculation,
    # query, or session_state logic lives below; every number shown is
    # either an existing column or a plain aggregate (mean/sum/count/groupby)
    # of existing columns, computed the same way the rest of the app already
    # does it (see LEAKAGE_PERCENT / RISK_LEVEL / prod_leak above).
    # Requires Streamlit >= 1.32 for st.container(key=...).
    # ══════════════════════════════════════════════════════════════════════
    st.markdown("""
    <style>
    .kmat-header{margin:6px 0 22px 0;}
    .kmat-header-top{display:flex;align-items:center;gap:10px;}
    .kmat-header-icon{font-size:22px;line-height:1;}
    .kmat-header-title{font-size:22px;font-weight:700;color:#f1f5f9;letter-spacing:.2px;}
    .kmat-header-sub{font-size:13px;color:#8b98ac;margin-top:2px;margin-left:32px;}
    .kmat-header-rule{
        height:2px;margin-top:14px;border-radius:2px;
        background:linear-gradient(90deg,#3b82f6 0%,#8b5cf6 45%,rgba(139,92,246,0) 100%);
    }
    .kmat-card-title{
        font-size:14.5px;font-weight:700;color:#e2e8f0;
        text-transform:uppercase;letter-spacing:.6px;
        margin-bottom:14px;padding-bottom:10px;
        border-bottom:1px solid rgba(148,163,184,0.14);
    }
    div[data-testid="stVerticalBlockBorderWrapper"]{
        border-radius:16px !important;
        transition:transform .18s ease, box-shadow .18s ease, border-color .18s ease;
        background:linear-gradient(180deg, rgba(30,41,59,0.55) 0%, rgba(17,24,39,0.55) 100%);
        backdrop-filter:blur(6px);
        border:1px solid rgba(148,163,184,0.14) !important;
    }
    div[data-testid="stVerticalBlockBorderWrapper"]:hover{
        transform:translateY(-2px);
        border-color:rgba(139,92,246,0.5) !important;
        box-shadow:0 10px 30px rgba(59,130,246,0.12), 0 0 0 1px rgba(139,92,246,0.15);
    }

    /* Executive AI Insights — flagship glass band */
    .st-key-ai_insights_section{
        border-radius:22px !important;
        padding:26px 22px !important;
        background:linear-gradient(135deg, rgba(139,92,246,0.14) 0%, rgba(59,130,246,0.10) 55%, rgba(16,185,129,0.06) 100%) !important;
        border:1px solid rgba(139,92,246,0.32) !important;
        margin:8px 0 28px 0 !important;
    }
    .st-key-ai_insights_section:hover{ transform:none; }

    /* Filter ribbon */
    .st-key-filter_ribbon{padding:14px 18px 4px 18px !important;margin-bottom:24px !important;}

    /* KPI cards */
    .kmat-kpi-row{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:4px;}
    @media (max-width:900px){.kmat-kpi-row{grid-template-columns:repeat(2,1fr);}}
    .kmat-kpi-card{
        position:relative;background:linear-gradient(180deg, rgba(30,41,59,0.6) 0%, rgba(17,24,39,0.6) 100%);
        border:1px solid rgba(148,163,184,0.14);border-radius:14px;padding:16px 16px 14px 16px;
        border-top:3px solid var(--kpi-accent,#3b82f6);
        transition:transform .18s ease, box-shadow .18s ease;
    }
    .kmat-kpi-card:hover{transform:translateY(-3px);box-shadow:0 8px 22px rgba(59,130,246,0.15);}
    .kmat-kpi-label{font-size:11.5px;color:#8b98ac;text-transform:uppercase;letter-spacing:.5px;}
    .kmat-kpi-value{font-size:26px;font-weight:700;color:#f1f5f9;margin-top:6px;font-family:'JetBrains Mono',monospace;}
    .kmat-kpi-trend{font-size:12px;margin-top:6px;font-weight:600;}
    .kmat-kpi-trend.up{color:#10b981;} .kmat-kpi-trend.down{color:#ef4444;} .kmat-kpi-trend.flat{color:#8b98ac;}

    /* AI insight tiles */
    .kmat-ai-tiles{display:grid;grid-template-columns:repeat(5,1fr);gap:14px;margin-top:6px;}
    @media (max-width:1100px){.kmat-ai-tiles{grid-template-columns:repeat(2,1fr);}}
    .kmat-ai-tile{
        background:rgba(15,23,42,0.55);border:1px solid rgba(148,163,184,0.16);border-radius:14px;
        padding:16px 14px;text-align:left;
    }
    .kmat-ai-tile-icon{font-size:19px;}
    .kmat-ai-tile-label{font-size:11.5px;color:#8b98ac;text-transform:uppercase;letter-spacing:.4px;margin-top:8px;}
    .kmat-ai-tile-value{font-size:18px;font-weight:700;color:#f1f5f9;margin-top:4px;line-height:1.3;}

    /* Cost mix legend-as-labels */
    .kmat-mix-row{display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid rgba(148,163,184,0.10);}
    .kmat-mix-row:last-child{border-bottom:none;}
    .kmat-mix-name{font-size:13px;color:#e2e8f0;font-weight:600;}
    .kmat-mix-pct{font-size:13px;color:#8b98ac;}
    .kmat-mix-amt{font-size:13px;color:#f1f5f9;font-family:'JetBrains Mono',monospace;}

    /* Product performance cards */
    .kmat-product-card{
        background:rgba(15,23,42,0.55);border:1px solid rgba(148,163,184,0.16);border-radius:14px;
        padding:14px 16px;margin-bottom:10px;
    }
    .kmat-product-name{font-size:14px;font-weight:700;color:#f1f5f9;}
    .kmat-product-metrics{display:flex;gap:22px;margin-top:8px;flex-wrap:wrap;}
    .kmat-product-metric-label{font-size:10.5px;color:#8b98ac;text-transform:uppercase;letter-spacing:.4px;}
    .kmat-product-metric-value{font-size:14px;font-weight:600;color:#e2e8f0;margin-top:2px;}
    </style>
    """, unsafe_allow_html=True)

    def kmat_header(icon, title, subtitle):
        st.markdown(
            f'<div class="kmat-header"><div class="kmat-header-top">'
            f'<span class="kmat-header-icon">{icon}</span>'
            f'<span class="kmat-header-title">{title}</span></div>'
            f'<div class="kmat-header-sub">{subtitle}</div>'
            f'<div class="kmat-header-rule"></div></div>',
            unsafe_allow_html=True
        )

    def kmat_card_title(icon, text):
        st.markdown(f'<div class="kmat-card-title">{(icon + " ") if icon else ""}{text}</div>', unsafe_allow_html=True)

    def risk_badge(risk_level):
        m = {"Healthy": "🟢 Healthy", "Warning": "🟡 Warning", "High Risk": "🔴 High Risk"}
        return m.get(risk_level, risk_level)

    kmat_header("📈", "Analytics Dashboard", "Portfolio-wide pricing performance, risk, and AI recommendations")

    # ══════════════════════════════════════════════════════════════════════
    # FILTER RIBBON — subsets the same `quotes` dataframe used by every
    # section below (via `quotes_f`). No calculation formula changes;
    # this only changes which rows feed the existing formulas.
    # ══════════════════════════════════════════════════════════════════════
    with st.container(border=True, key="filter_ribbon"):
        kmat_card_title("🔎", "Filters")
        f1, f2, f3, f4, f5 = st.columns(5)

        with f1:
            product_opts = ["All"] + sorted(quotes["PRODUCT"].dropna().unique().tolist())
            sel_product = st.selectbox("Product", product_opts, key="dash_f_product")

        with f2:
            if "CUSTOMER_NAME" in quotes.columns:
                customer_opts = ["All"] + sorted(quotes["CUSTOMER_NAME"].dropna().unique().tolist())
                sel_customer = st.selectbox("Customer", customer_opts, key="dash_f_customer")
            else:
                sel_customer = "All"
                st.selectbox("Customer", ["All"], key="dash_f_customer_na", disabled=True)

        with f3:
            risk_opts = ["All"] + sorted(quotes["RISK_LEVEL"].dropna().unique().tolist())
            sel_risk = st.selectbox("Risk Level", risk_opts, key="dash_f_risk")

        with f4:
            if "APPROVAL_ROUTING" in quotes.columns:
                approval_opts = ["All"] + sorted(quotes["APPROVAL_ROUTING"].dropna().unique().tolist())
                sel_approval = st.selectbox("Approval Status", approval_opts, key="dash_f_approval")
            else:
                sel_approval = "All"
                st.selectbox("Approval Status", ["All"], key="dash_f_approval_na", disabled=True)

        with f5:
            min_ts = pd.to_datetime(quotes["TIMESTAMP"]).min()
            max_ts = pd.to_datetime(quotes["TIMESTAMP"]).max()
            date_range = st.date_input("Date Range", value=(min_ts.date(), max_ts.date()),
                                        min_value=min_ts.date(), max_value=max_ts.date(), key="dash_f_daterange")

    quotes_f = quotes.copy()
    if sel_product != "All":
        quotes_f = quotes_f[quotes_f["PRODUCT"] == sel_product]
    if "CUSTOMER_NAME" in quotes_f.columns and sel_customer != "All":
        quotes_f = quotes_f[quotes_f["CUSTOMER_NAME"] == sel_customer]
    if sel_risk != "All":
        quotes_f = quotes_f[quotes_f["RISK_LEVEL"] == sel_risk]
    if "APPROVAL_ROUTING" in quotes_f.columns and sel_approval != "All":
        quotes_f = quotes_f[quotes_f["APPROVAL_ROUTING"] == sel_approval]
    if isinstance(date_range, tuple) and len(date_range) == 2:
        start_d, end_d = date_range
        ts_dates = pd.to_datetime(quotes_f["TIMESTAMP"]).dt.date
        quotes_f = quotes_f[(ts_dates >= start_d) & (ts_dates <= end_d)]

    if quotes_f.empty:
        st.warning("No quotes match the selected filters. Adjust the filter ribbon above.")
        st.stop()

    # Per-row margin, reusing the exact formula used to save ACHIEVED_MARGIN_PCT
    # in the Configure Quote tab — falls back to it directly when present.
    if "ACHIEVED_MARGIN_PCT" in quotes_f.columns:
        quotes_f["_MARGIN_PCT"] = quotes_f["ACHIEVED_MARGIN_PCT"]
    else:
        quotes_f["_MARGIN_PCT"] = (quotes_f["ACTUAL_PRICE"] - quotes_f["TOTAL_MANUFACTURING_COST"]) / quotes_f["ACTUAL_PRICE"] * 100

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 1 — PERFORMANCE OVERVIEW
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("📊", "Performance Overview", "Portfolio KPIs at a glance")

    avg_margin_pct = ((quotes_f["ACTUAL_PRICE"] - quotes_f["TOTAL_MANUFACTURING_COST"]) / quotes_f["ACTUAL_PRICE"] * 100).mean()

    # Trend indicators — split the filtered set into an older/newer half by
    # TIMESTAMP and compare averages. Purely descriptive, computed only from
    # data already loaded above; hidden when there isn't enough history to
    # make a trend meaningful.
    sorted_q = quotes_f.sort_values("TIMESTAMP")
    half = len(sorted_q) // 2
    trend_ok = half >= 2

    def _trend_pct(col):
        if not trend_ok:
            return None
        o = sorted_q.iloc[:half][col].mean()
        n = sorted_q.iloc[half:][col].mean()
        if pd.isna(o) or o == 0:
            return None
        return (n - o) / abs(o) * 100

    trend_target  = _trend_pct("TARGET_PRICE")
    trend_actual  = _trend_pct("ACTUAL_PRICE")
    trend_leakage = _trend_pct("LEAKAGE")
    trend_margin  = None
    if trend_ok:
        o = sorted_q.iloc[:half]["_MARGIN_PCT"].mean()
        n = sorted_q.iloc[half:]["_MARGIN_PCT"].mean()
        trend_margin = None if pd.isna(o) else (n - o)  # percentage-point delta, not %-of-%

    # NOTE: every HTML fragment below is built as a SINGLE line (no
    # internal newlines). Streamlit's markdown renderer treats a blank or
    # whitespace-only line followed by indented text as a code block, which
    # silently turns concatenated multi-line HTML into literal text — this
    # is what causes raw "<div>" tags to show up on screen. Single-line
    # strings sidestep that entirely.
    def _kpi_card(label, value, accent="#3b82f6", trend=None, trend_is_points=False):
        trend_html = ""
        if trend is not None:
            direction = "up" if trend > 0 else ("down" if trend < 0 else "flat")
            arrow = "↑" if trend > 0 else ("↓" if trend < 0 else "→")
            suffix = " pts" if trend_is_points else "%"
            trend_html = f'<div class="kmat-kpi-trend {direction}">{arrow} {trend:+.1f}{suffix}</div>'
        return (f'<div class="kmat-kpi-card" style="--kpi-accent:{accent};">'
                f'<div class="kmat-kpi-label">{label}</div>'
                f'<div class="kmat-kpi-value">{value}</div>'
                f'{trend_html}</div>')

    kpi_html = '<div class="kmat-kpi-row">'
    kpi_html += _kpi_card("Total Quotes", str(len(quotes_f)), "#3b82f6")
    kpi_html += _kpi_card("Avg Target Price", fmt_currency(quotes_f["TARGET_PRICE"].mean()), "#3b82f6", trend_target)
    kpi_html += _kpi_card("Avg Actual Price", fmt_currency(quotes_f["ACTUAL_PRICE"].mean()), "#3b82f6", trend_actual)
    kpi_html += _kpi_card("Total Leakage", fmt_currency(quotes_f["LEAKAGE"].sum()), "#ef4444", trend_leakage)
    kpi_html += _kpi_card("Avg Achieved Margin", f"{avg_margin_pct:.1f}%",
                           "#10b981" if avg_margin_pct >= target_margin_pct else "#f59e0b",
                           trend_margin, trend_is_points=True)
    kpi_html += _kpi_card("High Risk Quotes", str(len(quotes_f[quotes_f["RISK_COLOR"] == "red"])), "#ef4444")
    kpi_html += _kpi_card("Warning Quotes", str(len(quotes_f[quotes_f["RISK_COLOR"] == "amber"])), "#f59e0b")
    kpi_html += _kpi_card("Healthy Quotes", str(len(quotes_f[quotes_f["RISK_COLOR"] == "green"])), "#10b981")
    kpi_html += '</div>'
    st.markdown(kpi_html, unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 2 — EXECUTIVE AI INSIGHTS  (full width glass band)
    # Every tile below is a plain aggregate (count/sum/groupby) of columns
    # already computed above/in Save Quote — no model call, no new logic.
    # ══════════════════════════════════════════════════════════════════════
    with st.container(key="ai_insights_section"):
        kmat_header("🤖", "Executive Pricing Insights", "AI-generated business summary")

        total_quotes = len(quotes_f)
        total_leakage = quotes_f["LEAKAGE"].sum()

        prod_leak_preview = (quotes_f.groupby("PRODUCT")["LEAKAGE"].sum()
                              .sort_values(ascending=False))
        highest_risk_product = prod_leak_preview.index[0] if len(prod_leak_preview) else "—"

        recoverable = quotes_f.loc[quotes_f["RISK_COLOR"] == "red", "LEAKAGE"].sum()

        high_risk_share = (quotes_f["RISK_COLOR"] == "red").mean() * 100
        if high_risk_share >= 25:
            recommendation = "Tighten discount authority — over a quarter of quotes are high risk."
        elif high_risk_share >= 10:
            recommendation = "Review discount guardrails on flagged deals to protect margin."
        elif avg_margin_pct >= target_margin_pct:
            recommendation = "Pricing is healthy — hold current policy and monitor."
        else:
            recommendation = "Average margin trails target — revisit floor pricing."

        tiles_html = (
            '<div class="kmat-ai-tiles">'
            '<div class="kmat-ai-tile"><div class="kmat-ai-tile-icon">✓</div>'
            '<div class="kmat-ai-tile-label">Total Quotes Generated</div>'
            f'<div class="kmat-ai-tile-value">{total_quotes}</div></div>'
            '<div class="kmat-ai-tile"><div class="kmat-ai-tile-icon">✓</div>'
            '<div class="kmat-ai-tile-label">Revenue Leakage Detected</div>'
            f'<div class="kmat-ai-tile-value">{fmt_currency(total_leakage)}</div></div>'
            '<div class="kmat-ai-tile"><div class="kmat-ai-tile-icon">✓</div>'
            '<div class="kmat-ai-tile-label">Highest Risk Product</div>'
            f'<div class="kmat-ai-tile-value">{highest_risk_product}</div></div>'
            '<div class="kmat-ai-tile"><div class="kmat-ai-tile-icon">✓</div>'
            '<div class="kmat-ai-tile-label">Potential Revenue Recovery</div>'
            f'<div class="kmat-ai-tile-value">{fmt_currency(recoverable)}</div></div>'
            '<div class="kmat-ai-tile"><div class="kmat-ai-tile-icon">✓</div>'
            '<div class="kmat-ai-tile-label">AI Recommendation</div>'
            f'<div class="kmat-ai-tile-value" style="font-size:14px;font-weight:600;">{recommendation}</div></div>'
            '</div>'
        )
        st.markdown(tiles_html, unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 3 — BUSINESS PERFORMANCE
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("💹", "Business Performance", "Revenue, pricing and manufacturing analytics")

    b1, b2 = st.columns(2)

    with b1:
        with st.container(border=True, key="quote_perf_card"):
            kmat_card_title("📐", "Quote Performance — Target vs Actual")
            perf_by_product = (
                quotes_f.groupby("PRODUCT")
                .agg(Avg_Target=("TARGET_PRICE", "mean"), Avg_Actual=("ACTUAL_PRICE", "mean"))
                .reset_index()
                .sort_values("Avg_Target", ascending=True)
            )
            fig_perf = go.Figure()
            fig_perf.add_trace(go.Bar(y=perf_by_product["PRODUCT"], x=perf_by_product["Avg_Target"],
                                       name="Target Price", orientation="h", marker_color="#3b82f6"))
            fig_perf.add_trace(go.Bar(y=perf_by_product["PRODUCT"], x=perf_by_product["Avg_Actual"],
                                       name="Actual Price", orientation="h", marker_color="#10b981"))
            fig_perf.update_layout(
                barmode="group", paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                font_color="#94a3b8", height=300, margin=dict(l=0, r=0, t=10, b=0),
                legend=dict(bgcolor="rgba(0,0,0,0)", orientation="h", y=1.08),
                xaxis=dict(gridcolor="#1e293b", title="Price"), yaxis=dict(gridcolor="#1e293b", title=""),
            )
            st.plotly_chart(fig_perf, use_container_width=True)

    with b2:
        with st.container(border=True, key="cost_mix_card"):
            kmat_card_title("🥧", "Cost Distribution")
            cost_mix = pd.DataFrame({
                "Component": ["Material", "Machine", "Setup", "Overhead"],
                "Amount": [quotes_f["MATERIAL_COST"].mean(), quotes_f["MACHINE_COST"].mean(),
                           quotes_f["SETUP_COST"].mean(), quotes_f["OVERHEAD_COST"].mean()]
            })
            total_mix = cost_mix["Amount"].sum()
            cost_mix["Pct"] = cost_mix["Amount"] / total_mix * 100 if total_mix else 0.0

            chart_col, label_col = st.columns([3, 2])
            with chart_col:
                fig_mix = px.pie(cost_mix, names="Component", values="Amount", hole=0.65,
                                 color_discrete_sequence=["#3b82f6", "#8b5cf6", "#f59e0b", "#10b981"])
                fig_mix.update_layout(paper_bgcolor="rgba(0,0,0,0)", font_color="#94a3b8",
                    height=280, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig_mix.update_traces(textfont_color="#f1f5f9", textinfo="none")
                st.plotly_chart(fig_mix, use_container_width=True)
            with label_col:
                rows_html = ""
                for _, r in cost_mix.iterrows():
                    rows_html += (
                        '<div class="kmat-mix-row">'
                        f'<div><div class="kmat-mix-name">{r["Component"]}</div>'
                        f'<div class="kmat-mix-pct">{r["Pct"]:.0f}%</div></div>'
                        f'<div class="kmat-mix-amt">{fmt_currency(r["Amount"])}</div>'
                        '</div>'
                    )
                st.markdown(f'<div style="margin-top:14px;">{rows_html}</div>', unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 4 — RISK ANALYTICS
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🚨", "Risk Analytics", "Leakage exposure and quote-level risk register")

    with st.container(border=True, key="risk_register_card"):
        kmat_card_title("📋", "Leakage Risk Register")
        fc1, fc2 = st.columns(2)
        with fc1:
            leakage_filter = st.slider("Show quotes with leakage % above", 0.0, 50.0, 0.0, 0.5)
        with fc2:
            price_min = float(quotes_f["ACTUAL_PRICE"].min() * 0.9)
            price_max = float(quotes_f["ACTUAL_PRICE"].max() * 1.1)
            if price_min >= price_max:
                price_max = price_min + 1.0
            price_filter = st.slider("Minimum actual price filter",
                price_min, price_max, price_min,
                step=float((price_max - price_min) / 100 or 1))

        register = quotes_f[(quotes_f["LEAKAGE_PERCENT"] >= leakage_filter) & (quotes_f["ACTUAL_PRICE"] >= price_filter)].copy()
        register["Risk"] = register["RISK_LEVEL"].apply(risk_badge)

        display_cols = ["PRODUCT", "TARGET_PRICE", "ACTUAL_PRICE", "LEAKAGE", "LEAKAGE_PERCENT", "Risk"]
        if "ORDER_QTY" in register.columns: display_cols.insert(1, "ORDER_QTY")
        if "HEALTH_SCORE" in register.columns: display_cols.append("HEALTH_SCORE")
        if "APPROVAL_ROUTING" in register.columns: display_cols.append("APPROVAL_ROUTING")

        column_config = {
            "TARGET_PRICE": st.column_config.NumberColumn("Target Price", format="%.0f"),
            "ACTUAL_PRICE": st.column_config.NumberColumn("Actual Price", format="%.0f"),
            "LEAKAGE": st.column_config.NumberColumn("Leakage", format="%.0f"),
            "LEAKAGE_PERCENT": st.column_config.NumberColumn("Leakage %", format="%.1f%%"),
        }
        if "HEALTH_SCORE" in register.columns:
            column_config["HEALTH_SCORE"] = st.column_config.ProgressColumn(
                "Health Score", min_value=0, max_value=100, format="%d"
            )

        st.dataframe(
            register[display_cols].sort_values("LEAKAGE_PERCENT", ascending=False),
            use_container_width=True, hide_index=True, column_config=column_config
        )

    with st.container(border=True, key="leakage_by_product_card"):
        kmat_card_title("📉", "Leakage by Product")
        prod_leak = (quotes_f.groupby("PRODUCT")
                     .agg(Total_Leakage=("LEAKAGE", "sum"), Quote_Count=("PRODUCT", "count"))
                     .reset_index().sort_values("Total_Leakage", ascending=False))
        fig_bar = px.bar(prod_leak.sort_values("Total_Leakage", ascending=True),
                         x="Total_Leakage", y="PRODUCT", orientation="h",
                         color="Total_Leakage", color_continuous_scale=["#10b981", "#f59e0b", "#ef4444"],
                         text="Total_Leakage")
        fig_bar.update_traces(texttemplate="%{text:,.0f}", textposition="outside", textfont_color="#f1f5f9")
        fig_bar.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            font_color="#94a3b8", height=280, margin=dict(l=0, r=0, t=10, b=0), coloraxis_showscale=False,
            xaxis=dict(gridcolor="#1e293b", title="Total Leakage"), yaxis=dict(gridcolor="#1e293b", title=""))
        st.plotly_chart(fig_bar, use_container_width=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 5 — BUSINESS ACTIVITY
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🗂️", "Business Activity", "Recent deals and top-performing products")

    act1, act2 = st.columns(2)

    with act1:
        with st.container(border=True, key="recent_quotes_card"):
            kmat_card_title("🕒", "Recent Quotes")

            recent_src = quotes_f.sort_values("TIMESTAMP", ascending=False)
            if len(recent_src) <= 5:
                st.caption(f"Showing all {len(recent_src)} quote(s) — need more than 5 saved quotes to enable the slider.")
                recent_view = recent_src
            else:
                n_recent = st.slider("Show last N quotes", 5, min(100, len(recent_src)), min(10, len(recent_src)), 5)
                recent_view = recent_src.head(n_recent)

            recent_display = pd.DataFrame({
                "Customer": recent_view["CUSTOMER_NAME"] if "CUSTOMER_NAME" in recent_view.columns else "—",
                "Product": recent_view["PRODUCT"],
                "Quoted Price": recent_view["ACTUAL_PRICE"].apply(fmt_currency),
                "Margin": recent_view["_MARGIN_PCT"].apply(lambda v: f"{v:.1f}%"),
                "Approval Status": recent_view["APPROVAL_ROUTING"] if "APPROVAL_ROUTING" in recent_view.columns else "—",
            })
            st.dataframe(recent_display, use_container_width=True, hide_index=True)

    with act2:
        with st.container(border=True, key="top_products_card"):
            kmat_card_title("🏆", "Top Performing Products")

            top_products = (
                quotes_f.groupby("PRODUCT")
                .agg(
                    Revenue=("ACTUAL_PRICE", "sum"),
                    Avg_Margin=("_MARGIN_PCT", "mean"),
                    Quotes=("PRODUCT", "count"),
                    Healthy_Count=("RISK_COLOR", lambda s: (s == "green").sum()),
                )
                .reset_index()
            )
            top_products["Healthy_Pct"] = top_products["Healthy_Count"] / top_products["Quotes"] * 100
            top_products = top_products.sort_values("Revenue", ascending=False).head(5)

            for _, r in top_products.iterrows():
                st.markdown(
                    '<div class="kmat-product-card">'
                    f'<div class="kmat-product-name">{r["PRODUCT"]}</div>'
                    '<div class="kmat-product-metrics">'
                    '<div><div class="kmat-product-metric-label">Revenue</div>'
                    f'<div class="kmat-product-metric-value">{fmt_currency(r["Revenue"])}</div></div>'
                    '<div><div class="kmat-product-metric-label">Avg Margin</div>'
                    f'<div class="kmat-product-metric-value">{r["Avg_Margin"]:.1f}%</div></div>'
                    '<div><div class="kmat-product-metric-label">Quotes</div>'
                    f'<div class="kmat-product-metric-value">{int(r["Quotes"])}</div></div>'
                    '<div><div class="kmat-product-metric-label">Healthy %</div>'
                    f'<div class="kmat-product-metric-value">{r["Healthy_Pct"]:.0f}%</div></div>'
                    '</div></div>',
                    unsafe_allow_html=True
                )
# ===================================================
# TAB 4 — MULTI-SCENARIO BOM COMPARISON ENGINE
# ===================================================
with tab4:
    if "TABLE_MAP" not in st.session_state:
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()

    # ══════════════════════════════════════════════════════════════════════
    # PREMIUM UI LAYER — styling + layout helpers only. No calculation,
    # query, or session_state logic lives below. Every generated HTML
    # fragment is a SINGLE line (no internal newlines): concatenating
    # multi-line indented HTML causes Streamlit's markdown renderer to drop
    # into a literal code block after the first blank/whitespace-only line,
    # which is what makes raw "<div>" tags show up on screen. Wherever a
    # comparison needs an up/down indicator, we use st.metric's native
    # delta arrows/colors instead of hand-rolled HTML.
    # Requires Streamlit >= 1.32 (st.container(key=...) + border=True).
    # ══════════════════════════════════════════════════════════════════════
    st.markdown("""
    <style>
    .kmat-header{margin:6px 0 22px 0;}
    .kmat-header-top{display:flex;align-items:center;gap:10px;}
    .kmat-header-icon{font-size:22px;line-height:1;}
    .kmat-header-title{font-size:22px;font-weight:700;color:#f1f5f9;letter-spacing:.2px;}
    .kmat-header-sub{font-size:13px;color:#8b98ac;margin-top:2px;margin-left:32px;}
    .kmat-header-rule{height:2px;margin-top:14px;border-radius:2px;background:linear-gradient(90deg,#3b82f6 0%,#8b5cf6 45%,rgba(139,92,246,0) 100%);}
    .kmat-card-title{font-size:14.5px;font-weight:700;color:#e2e8f0;text-transform:uppercase;letter-spacing:.6px;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid rgba(148,163,184,0.14);}
    div[data-testid="stVerticalBlockBorderWrapper"]{border-radius:16px !important;transition:transform .18s ease, box-shadow .18s ease, border-color .18s ease;background:linear-gradient(180deg, rgba(30,41,59,0.55) 0%, rgba(17,24,39,0.55) 100%);backdrop-filter:blur(6px);border:1px solid rgba(148,163,184,0.14) !important;}
    div[data-testid="stVerticalBlockBorderWrapper"]:hover{transform:translateY(-2px);border-color:rgba(139,92,246,0.5) !important;box-shadow:0 10px 30px rgba(59,130,246,0.12), 0 0 0 1px rgba(139,92,246,0.15);}
    .kmat-color-strip{height:4px;border-radius:4px;margin-bottom:12px;}
    .st-key-winner_banner{border-radius:22px !important;padding:0 !important;background:linear-gradient(135deg, rgba(16,185,129,0.16) 0%, rgba(5,150,105,0.10) 60%, rgba(16,185,129,0.05) 100%) !important;border:1px solid rgba(16,185,129,0.4) !important;margin:8px 0 28px 0 !important;}
    .st-key-winner_banner:hover{transform:none;}
    .kmat-winner-inner{display:flex;align-items:center;gap:20px;padding:26px 28px;flex-wrap:wrap;}
    .kmat-winner-icon{font-size:44px;filter:drop-shadow(0 0 12px rgba(16,185,129,0.5));}
    .kmat-winner-title{font-size:11px;font-weight:700;color:#34d399;text-transform:uppercase;letter-spacing:1px;}
    .kmat-winner-name{font-size:26px;font-weight:800;color:#f1f5f9;margin-top:4px;}
    .kmat-winner-reason{font-size:13px;color:#6ee7b7;margin-top:6px;}
    .kmat-winner-stats{display:flex;gap:26px;margin-left:auto;flex-wrap:wrap;}
    .kmat-winner-stat-label{font-size:10.5px;color:#8b98ac;text-transform:uppercase;letter-spacing:.5px;}
    .kmat-winner-stat-value{font-size:20px;font-weight:700;color:#f1f5f9;margin-top:3px;font-family:'JetBrains Mono',monospace;}
    </style>""", unsafe_allow_html=True)

    def kmat_header(icon, title, subtitle):
        st.markdown(
            f'<div class="kmat-header"><div class="kmat-header-top">'
            f'<span class="kmat-header-icon">{icon}</span>'
            f'<span class="kmat-header-title">{title}</span></div>'
            f'<div class="kmat-header-sub">{subtitle}</div>'
            f'<div class="kmat-header-rule"></div></div>',
            unsafe_allow_html=True
        )

    def kmat_card_title(icon, text):
        st.markdown(f'<div class="kmat-card-title">{(icon + " ") if icon else ""}{text}</div>', unsafe_allow_html=True)

    kmat_header("🧪", "Scenario Comparison", "What-if analysis and decision support across pricing scenarios")

    # ── Load KMAT products (Cost Model — read-only) ─────────────────────
    try:

        _prod_df = session.sql(
            f"SELECT * FROM {fq('KMAT_PRODUCT_MASTER')}"
        ).to_pandas()

        # Support both Integrated and Standalone schemas
        if "DESCRIPTION" in _prod_df.columns:
            product_col = "DESCRIPTION"

        elif "PRODUCT_NAME" in _prod_df.columns:
            product_col = "PRODUCT_NAME"

        else:
            st.error(
                "KMAT_PRODUCT_MASTER must contain either DESCRIPTION or PRODUCT_NAME."
            )
            st.stop()

        all_products = _prod_df[product_col].tolist()

    except Exception as e:
        st.error(f"Cannot load products: {e}")
        st.stop()
    if len(all_products) < 1:
        st.warning("No products found."); st.stop()

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 1 — SCENARIO BUILDER
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🧩", "Scenario Builder", "Configure each scenario's product, simulation, and cost overrides")

    with st.container(border=True, key="setup_card"):
        kmat_card_title("⚙️", "Comparison Engine Setup")
        setup_c1, setup_c2 = st.columns(2)
        with setup_c1:
            sc_count = st.slider("Number of scenarios to compare", 2, 4, 2, 1)
        with setup_c2:
            sim_order_qty = st.slider("Order Quantity (units) — applied to all scenarios", 1, 500, 1, 1)

    SCENARIO_COLORS  = ["#3b82f6", "#8b5cf6", "#10b981", "#f59e0b"]
    SCENARIO_LABELS  = ["A", "B", "C", "D"]
    SCENARIO_CSS_CLS = ["s0", "s1", "s2", "s3"]
    def _load_kmat_costs(kmat_id, simulation_id):
        """
        Load manufacturing costs from VW_COST_SUMMARY.
        """
    
        try:
            st.write(fq("KMAT_CONFIGURED_COMPONENT_COSTS"))
            df = session.sql(f"""
            SELECT
                MATERIAL_COST_USD,
                LABOR_COST_USD,
                MACHINE_COST_USD,
                OVERHEAD_COST_USD,
                TOTAL_CONFIGURED_COST_USD,
                FLOOR_PRICE_USD,
                TARGET_PRICE_USD,
                CEILING_PRICE_USD
            FROM KMAT_PRICING.CORE_INPUT.VW_COST_SUMMARY
            WHERE SIMULATION_ID = '{simulation_id}'
""").to_pandas()
    
            if df.empty:
                st.warning(
                    f"No cost summary found for Simulation {simulation_id}"
                )
                return None
    
            row = df.iloc[0]
    
            return {
                "material": float(row["MATERIAL_COST_USD"]),
                "labor": float(row["LABOR_COST_USD"]),
                "machine": float(row["MACHINE_COST_USD"]),
                "overhead": float(row["OVERHEAD_COST_USD"]),
                "total": float(row["TOTAL_CONFIGURED_COST_USD"]),
                "floor": float(row["FLOOR_PRICE_USD"]),
                "target": float(row["TARGET_PRICE_USD"]),
                "ceiling": float(row["CEILING_PRICE_USD"]),
            }
    
        except Exception as e:
    
            st.error(f"Cannot load cost summary: {e}")
    
            return None

    scenario_cols = st.columns(sc_count)
    scenarios = []
    for i in range(sc_count):
        col = scenario_cols[i]
        with col:
            with st.container(border=True, key=f"scenario_card_{i}"):
                st.markdown(f'<div class="kmat-color-strip" style="background:{SCENARIO_COLORS[i]};"></div>', unsafe_allow_html=True)
                kmat_card_title("⬡", f"Scenario {SCENARIO_LABELS[i]}")

                default_idx = min(i, len(all_products) - 1)
                selected_product = st.selectbox(
                    "Product",
                    all_products,
                    index=default_idx,
                    key=f"sc_{i}_product"
                )

                kmat_id = _prod_df[
                    _prod_df[product_col] == selected_product
                ]["KMAT_ID"].iloc[0]

                try:
                    sim_df = session.sql(
                        f"SELECT SIMULATION_ID, SCENARIO_NAME FROM {fq('SIMULATION_HEADER')} WHERE KMAT_ID = '{kmat_id}'"
                    ).to_pandas()
                except Exception:
                    sim_df = pd.DataFrame()

                if sim_df.empty:
                    st.warning(f"No simulations found for {selected_product}.")
                    continue

                sim_label_map = {
                    f"{r['SIMULATION_ID']} — {r.get('SCENARIO_NAME') or 'Scenario'}": r["SIMULATION_ID"]
                    for _, r in sim_df.iterrows()
                }
                chosen_sim_label = st.selectbox("Simulation", list(sim_label_map.keys()), key=f"sc_{i}_sim")
                simulation_id = sim_label_map[chosen_sim_label]

                raw_costs = _load_kmat_costs(kmat_id, simulation_id)

                if raw_costs is None:
                    st.error(
                        f"No pricing data found for {simulation_id} ({kmat_id})"
                    )
                    st.stop()

                discount_pct = st.slider("Discount Applied %", 0, 30, 0, 1, key=f"sc_{i}_disc")

                with st.expander("Cost Override", expanded=False):
                    mat_override  = st.slider("Material Cost Δ%",  -50, 100, 0, 5, key=f"sc_{i}_mat")
                    mach_override = st.slider("Machine Cost Δ%",   -50, 100, 0, 5, key=f"sc_{i}_mach")
                    setup_override= st.slider("Labor Cost Δ%",     -50, 100, 0, 5, key=f"sc_{i}_setup")
                    oh_override   = st.slider("Overhead Rate Δ%",  -50, 100, 0, 5, key=f"sc_{i}_oh")

                scenarios.append({
                    "label": f"Scenario {SCENARIO_LABELS[i]}", "color": SCENARIO_COLORS[i], "css": SCENARIO_CSS_CLS[i],
                    "product": selected_product, "kmat_id": kmat_id, "simulation_id": simulation_id,
                    "raw_material": raw_costs["material"], "raw_labor": raw_costs["labor"],
                    "raw_machine": raw_costs["machine"], "raw_overhead": raw_costs["overhead"],
                    "mat_delta": mat_override, "mach_delta": mach_override, "setup_delta": setup_override,
                    "oh_delta": oh_override, "discount_pct": discount_pct,
                })

    if not scenarios:
        st.warning("No scenarios could be configured — make sure at least one product has a simulation.")
        st.stop()

    def compute_scenario(sc):
        raw_mat, raw_mach = sc["raw_material"], sc["raw_machine"]
        raw_setup, raw_oh = sc["raw_labor"], sc["raw_overhead"]
        mat   = raw_mat   * (1 + sc["mat_delta"]   / 100)
        mach  = raw_mach  * (1 + sc["mach_delta"]  / 100)
        setup = raw_setup * (1 + sc["setup_delta"] / 100)
        oh    = raw_oh    * (1 + sc["oh_delta"]    / 100)
        total = mat + mach + setup + oh
        tgt_price = total * (1 + target_margin)
        floor_p   = total * (1 + floor_buffer_pct / 100)
        ceil_p    = tgt_price * (1 + ceiling_buffer_pct / 100)
        vol_disc_pct, _ = get_volume_discount_pct(sim_order_qty)
        total_disc = sc["discount_pct"] + vol_disc_pct
        actual_p = tgt_price * (1 - total_disc / 100)
        leakage = tgt_price - actual_p
        leak_pct = leakage / tgt_price * 100 if tgt_price else 0
        margin_pct = (actual_p - total) / actual_p * 100 if actual_p else 0
        profit_unit = actual_p - total
        order_val = actual_p * sim_order_qty
        order_prof = profit_unit * sim_order_qty
        roi = profit_unit / total * 100 if total else 0
        eff_score = max(0, margin_pct - leak_pct)
        return {
            "label": sc["label"], "color": sc["color"], "css": sc["css"],
            "product": sc["product"], "simulation_id": sc["simulation_id"],
            "base_price": total, "surcharge": 0.0,
            "mat": mat, "raw_mat": raw_mat, "mach": mach, "raw_mach": raw_mach,
            "setup": setup, "raw_setup": raw_setup, "oh": oh, "raw_oh": raw_oh,
            "total_mfg": total, "target_price": tgt_price, "floor_price": floor_p, "ceil_price": ceil_p,
            "actual_price": actual_p, "leakage": leakage, "leak_pct": leak_pct,
            "margin_pct": margin_pct, "profit_unit": profit_unit,
            "order_value": order_val, "order_profit": order_prof, "roi": roi,
            "eff_score": eff_score, "discount_pct": sc["discount_pct"], "vol_disc_pct": vol_disc_pct,
            "mat_delta": sc["mat_delta"], "mach_delta": sc["mach_delta"],
            "setup_delta": sc["setup_delta"], "oh_delta": sc["oh_delta"],
        }

    results = [compute_scenario(s) for s in scenarios]
    if not results:
        st.warning("No cost data found for selected products."); st.stop()

    best = max(results, key=lambda r: r["eff_score"])

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 2 — WINNER DASHBOARD  (hero card)
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🏆", "Winner Dashboard", "The recommended scenario, at a glance")

    reasons = []
    if best["margin_pct"] == max(r["margin_pct"] for r in results): reasons.append(f"highest margin at {best['margin_pct']:.1f}%")
    if best["leak_pct"]   == min(r["leak_pct"]   for r in results): reasons.append(f"lowest leakage at {best['leak_pct']:.1f}%")
    if best["order_profit"]== max(r["order_profit"] for r in results): reasons.append(f"greatest profit of {fmt_currency(best['order_profit'])}")
    if best["roi"] == max(r["roi"] for r in results): reasons.append(f"best ROI at {best['roi']:.1f}%")
    reason_str = " · ".join(reasons) if reasons else f"efficiency score {best['eff_score']:.1f}"

    with st.container(key="winner_banner"):
        st.markdown(
            '<div class="kmat-winner-inner">'
            '<div class="kmat-winner-icon">🏆</div>'
            '<div><div class="kmat-winner-title">Recommended Configuration</div>'
            f'<div class="kmat-winner-name">{best["label"]} — {best["product"]}</div>'
            f'<div class="kmat-winner-reason">{reason_str}</div></div>'
            '<div class="kmat-winner-stats">'
            '<div><div class="kmat-winner-stat-label">Efficiency Score</div>'
            f'<div class="kmat-winner-stat-value">{best["eff_score"]:.1f}</div></div>'
            '<div><div class="kmat-winner-stat-label">Margin</div>'
            f'<div class="kmat-winner-stat-value">{best["margin_pct"]:.1f}%</div></div>'
            '<div><div class="kmat-winner-stat-label">ROI</div>'
            f'<div class="kmat-winner-stat-value">{best["roi"]:.1f}%</div></div>'
            '<div><div class="kmat-winner-stat-label">Order Profit</div>'
            f'<div class="kmat-winner-stat-value">{fmt_currency(best["order_profit"])}</div></div>'
            '<div><div class="kmat-winner-stat-label">Revenue Leakage</div>'
            f'<div class="kmat-winner-stat-value">{best["leak_pct"]:.1f}%</div></div>'
            '</div></div>',
            unsafe_allow_html=True
        )

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 3 — EXECUTIVE KPI COMPARISON
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("📌", "Executive KPI Comparison", "Core pricing metrics side by side")

    kpi_cols = st.columns(len(results))
    for idx, r in enumerate(results):
        with kpi_cols[idx]:
            with st.container(border=True, key=f"kpi_card_{idx}"):
                st.markdown(f'<div class="kmat-color-strip" style="background:{r["color"]};"></div>', unsafe_allow_html=True)
                kmat_card_title("", r["label"] + (" 🏆" if r["label"] == best["label"] else ""))
                st.caption(r["product"])
                st.metric("Manufacturing Cost", fmt_currency(r["total_mfg"]))
                st.metric("Target Price", fmt_currency(r["target_price"]))
                st.metric("Actual Price", fmt_currency(r["actual_price"]))
                st.metric("Margin", f"{r['margin_pct']:.1f}%")
                st.metric("Revenue Leakage", f"{r['leak_pct']:.1f}%")
                st.metric("ROI", f"{r['roi']:.1f}%")
                st.metric("Efficiency Score", f"{r['eff_score']:.1f}")

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 4 — VISUAL ANALYTICS  (2x2 grid)
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("📊", "Visual Analytics", "Compare pricing, cost and profitability across scenarios")

    va1, va2 = st.columns(2)
    with va1:
        with st.container(border=True, key="viz_cost_stack_card"):
            kmat_card_title("🏭", "Manufacturing Cost Breakdown")
            cost_bar_data = []
            for r in results:
                for comp, val in [("Material",r["mat"]),("Machine",r["mach"]),("Labor",r["setup"]),("Overhead",r["oh"])]:
                    cost_bar_data.append({"Scenario":r["label"],"Component":comp,"Cost":val})
            fig_cost = px.bar(pd.DataFrame(cost_bar_data), x="Scenario", y="Cost", color="Component",
                              barmode="stack",
                              color_discrete_sequence=["#3b82f6","#8b5cf6","#f59e0b","#10b981"])
            fig_cost.update_layout(paper_bgcolor="rgba(0,0,0,0)",plot_bgcolor="rgba(0,0,0,0)",
                font_color="#94a3b8",height=360,margin=dict(l=0,r=0,t=10,b=0),
                legend=dict(bgcolor="rgba(0,0,0,0)", orientation="h", y=1.1, title=None),
                xaxis=dict(gridcolor="#1e293b"),yaxis=dict(gridcolor="#1e293b"))
            st.plotly_chart(fig_cost, use_container_width=True)

    with va2:
        with st.container(border=True, key="viz_price_grouped_card"):
            kmat_card_title("💵", "Target vs Actual vs Leakage")
            fig_price = go.Figure()
            for r in results:
                fig_price.add_trace(go.Bar(name=r["label"], x=["Mfg Cost","Target","Actual","Leakage"],
                    y=[r["total_mfg"],r["target_price"],r["actual_price"],r["leakage"]],
                    marker_color=r["color"], opacity=0.85))
            fig_price.update_layout(barmode="group",
                paper_bgcolor="rgba(0,0,0,0)",plot_bgcolor="rgba(0,0,0,0)",
                font_color="#94a3b8",height=360,margin=dict(l=0,r=0,t=10,b=0),
                legend=dict(bgcolor="rgba(0,0,0,0)", orientation="h", y=1.1, title=None),
                xaxis=dict(gridcolor="#1e293b"),yaxis=dict(gridcolor="#1e293b"))
            st.plotly_chart(fig_price, use_container_width=True)

    va3, va4 = st.columns(2)
    with va3:
        with st.container(border=True, key="viz_bubble_card"):
            kmat_card_title("🎯", "Margin vs Leakage")
            sc_df = pd.DataFrame([{"Scenario":r["label"],"Margin %":r["margin_pct"],"Leakage %":r["leak_pct"],
                                    "Order Profit":r["order_profit"],"color":r["color"]} for r in results])
            fig_scatter = px.scatter(sc_df, x="Leakage %", y="Margin %", size="Order Profit",
                color="Scenario", color_discrete_sequence=[r["color"] for r in results],
                text="Scenario", size_max=60)
            fig_scatter.update_traces(textposition="top center",textfont_color="#f1f5f9")
            fig_scatter.update_layout(paper_bgcolor="rgba(0,0,0,0)",plot_bgcolor="rgba(0,0,0,0)",
                font_color="#94a3b8",height=360,margin=dict(l=0,r=0,t=10,b=0),
                showlegend=False,
                xaxis=dict(gridcolor="#1e293b"),yaxis=dict(gridcolor="#1e293b"))
            st.plotly_chart(fig_scatter, use_container_width=True)

    with va4:
        with st.container(border=True, key="viz_radar_card"):
            kmat_card_title("🕸️", "Performance Radar")
            radar_dims = ["Margin %","ROI %","Eff. Score","Leakage Inv.","Profit/Unit Norm."]
            raw_radar = {"Margin %":[r["margin_pct"] for r in results],"ROI %":[r["roi"] for r in results],
                         "Eff. Score":[r["eff_score"] for r in results],"Leakage Inv.":[100-r["leak_pct"] for r in results],
                         "Profit/Unit Norm.":[r["profit_unit"] for r in results]}
            def normalise(vals):
                lo, hi = min(vals), max(vals)
                if hi == lo: return [50.0]*len(vals)
                return [(v-lo)/(hi-lo)*100 for v in vals]
            norm_radar = {k: normalise(v) for k,v in raw_radar.items()}
            fig_radar = go.Figure()
            for idx, r in enumerate(results):
                fig_radar.add_trace(go.Scatterpolar(
                    r=[norm_radar[d][idx] for d in radar_dims]+[norm_radar[radar_dims[0]][idx]],
                    theta=radar_dims+[radar_dims[0]], fill="toself", name=r["label"],
                    line_color=r["color"], fillcolor=r["color"], opacity=0.25))
            fig_radar.update_layout(
                polar=dict(bgcolor="#0d1526",
                    radialaxis=dict(visible=True,range=[0,100],gridcolor="#1e2d47",tickfont=dict(color="#64748b")),
                    angularaxis=dict(gridcolor="#1e2d47",tickfont=dict(color="#94a3b8"))),
                paper_bgcolor="rgba(0,0,0,0)",font_color="#94a3b8",height=360,
                margin=dict(l=20,r=20,t=10,b=20),legend=dict(bgcolor="rgba(0,0,0,0)", orientation="h", y=1.1, title=None))
            st.plotly_chart(fig_radar, use_container_width=True)

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 5 — SCENARIO DIFFERENCES  (expandable, vs Scenario A baseline)
    # ══════════════════════════════════════════════════════════════════════
    if len(results) > 1:
        kmat_header("🔀", "Scenario Differences", "Each scenario compared against Scenario A (baseline)")

        baseline = results[0]
        for r in results[1:]:
            with st.expander(f"{baseline['label']} vs {r['label']}", expanded=False):
                d1, d2, d3, d4 = st.columns(4)
                with d1:
                    st.metric("Manufacturing Cost", fmt_currency(r["total_mfg"]),
                               fmt_currency(r["total_mfg"] - baseline["total_mfg"]), delta_color="inverse")
                with d2:
                    st.metric("Actual Price", fmt_currency(r["actual_price"]),
                               fmt_currency(r["actual_price"] - baseline["actual_price"]))
                with d3:
                    st.metric("Order Profit", fmt_currency(r["order_profit"]),
                               fmt_currency(r["order_profit"] - baseline["order_profit"]))
                with d4:
                    st.metric("Revenue Leakage", fmt_currency(r["leakage"]),
                               fmt_currency(r["leakage"] - baseline["leakage"]), delta_color="inverse")

                total_diff   = r["total_mfg"] - baseline["total_mfg"]
                leakage_diff = r["leakage"]   - baseline["leakage"]
                if total_diff > 0: st.warning(f"Manufacturing cost increased by **{fmt_currency(total_diff)}** vs {baseline['label']}.")
                else:               st.success(f"Manufacturing cost reduced by **{fmt_currency(abs(total_diff))}** vs {baseline['label']}.")
                if leakage_diff < 0:   st.success(f"Revenue leakage reduced by **{fmt_currency(abs(leakage_diff))}**.")
                elif leakage_diff > 0: st.warning(f"Revenue leakage increased by **{fmt_currency(leakage_diff)}**.")
                else:                  st.info("Revenue leakage unchanged.")

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 6 — ORDER PROFIT SUMMARY
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("🧾", f"Order Profit Summary", f"Projected P&L at {sim_order_qty} units per scenario")

    op_cols = st.columns(len(results))
    for idx, r in enumerate(results):
        with op_cols[idx]:
            with st.container(border=True, key=f"order_pl_card_{idx}"):
                st.markdown(f'<div class="kmat-color-strip" style="background:{r["color"]};"></div>', unsafe_allow_html=True)
                kmat_card_title("", r["label"])
                st.metric("Revenue", fmt_currency(r["order_value"]))
                st.metric("Cost", fmt_currency(r["total_mfg"] * sim_order_qty))
                st.metric("Profit", fmt_currency(r["order_profit"]))
                st.metric("Margin", f"{r['margin_pct']:.1f}%")
                st.metric("ROI", f"{r['roi']:.1f}%")

    # ══════════════════════════════════════════════════════════════════════
    # SECTION 7 — DETAILED TABLES  (kept for technical users, collapsed)
    # ══════════════════════════════════════════════════════════════════════
    kmat_header("📚", "Detailed Tables", "Full comparison data for technical review")

    with st.expander("Manufacturing Cost Comparison", expanded=False):
        bom_rows = []
        for label, key in [("Material Cost","mat"),("Machine Cost","mach"),("Labor Cost","setup"),("Overhead Cost","oh"),("Total Mfg Cost","total_mfg")]:
            row = {"Component": label}
            for r in results:
                v = r[key]; raw_key = "raw_" + key; delta_str = ""
                if raw_key in r and r[raw_key] != 0:
                    delta = (v - r[raw_key]) / r[raw_key] * 100; delta_str = f" ({delta:+.1f}%)"
                row[r["label"]] = f"{fmt_currency(v)}{delta_str}"
            bom_rows.append(row)
        st.dataframe(pd.DataFrame(bom_rows).set_index("Component"), use_container_width=True)

    with st.expander("Financial Comparison", expanded=False):
        fin_metrics = [
            ("Total Mfg Cost","total_mfg",True,False),("Target Price","target_price",False,False),
            ("Volume Disc %","vol_disc_pct",True,True),("Manual Disc %","discount_pct",True,True),
            ("Actual Price","actual_price",False,False),("Revenue Leakage","leakage",True,False),
            ("Leakage %","leak_pct",True,True),("Margin %","margin_pct",False,True),
            ("Profit / Unit","profit_unit",False,False),("Order Value","order_value",False,False),
            ("Order Profit","order_profit",False,False),("ROI %","roi",False,True),("Efficiency Score","eff_score",False,True),
        ]
        fin_rows = []
        for label, key, lower_better, is_pct in fin_metrics:
            vals = [r[key] for r in results]; best_val = min(vals) if lower_better else max(vals)
            row = {"Metric": label}
            for r in results:
                v = r[key]; mark = " ✦" if v == best_val and len(set(vals)) > 1 else ""
                row[r["label"]] = f"{v:.1f}%{mark}" if is_pct else f"{fmt_currency(v)}{mark}"
            fin_rows.append(row)
        st.dataframe(pd.DataFrame(fin_rows).set_index("Metric"), use_container_width=True)
        st.caption("✦ Best value in row")

        pl_rows = []
        for r in results:
            pl_rows.append({"Scenario":r["label"],"Product":r["product"],
                "Unit Price":fmt_currency(r["actual_price"]),"Unit Cost":fmt_currency(r["total_mfg"]),
                "Unit Profit":fmt_currency(r["profit_unit"]),"Order Revenue":fmt_currency(r["order_value"]),
                "Order Cost":fmt_currency(r["total_mfg"]*sim_order_qty),"Order Profit":fmt_currency(r["order_profit"]),
                "Total Leakage":fmt_currency(r["leakage"]*sim_order_qty),
                "Margin %":f"{r['margin_pct']:.1f}%","ROI %":f"{r['roi']:.1f}%"})
        st.markdown("**Order P&L Detail**")
        st.dataframe(pd.DataFrame(pl_rows).set_index("Scenario"), use_container_width=True)

    if len(results) > 1:
        with st.expander("Delta Comparison (vs Scenario A)", expanded=False):
            baseline = results[0]
            delta_rows = []
            for r in results[1:]:
                delta_rows.append({"Scenario":r["label"],
                    "Mfg Cost Δ":    fmt_currency(r["total_mfg"]   - baseline["total_mfg"]),
                    "Target Δ":      fmt_currency(r["target_price"] - baseline["target_price"]),
                    "Actual Δ":      fmt_currency(r["actual_price"] - baseline["actual_price"]),
                    "Leakage Δ":     fmt_currency(r["leakage"]      - baseline["leakage"]),
                    "Margin Δ":      f"{r['margin_pct'] - baseline['margin_pct']:+.1f}%",
                    "Order Profit Δ":fmt_currency(r["order_profit"] - baseline["order_profit"]),
                    "Eff. Score Δ":  f"{r['eff_score']  - baseline['eff_score']:+.1f}"})
            st.dataframe(pd.DataFrame(delta_rows).set_index("Scenario"), use_container_width=True)

    st.markdown("---")
# ===================================================
# TAB 5 — EXECUTIVE DASHBOARD
# ===================================================
with tab5:
    if "TABLE_MAP" not in st.session_state:
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()
    st.markdown('<div class="section-header">📈 Organization-Wide Intelligence</div>', unsafe_allow_html=True)
    try:
        all_quotes = session.sql(f"SELECT * FROM {fq_pricing('QUOTE_HISTORY')} ORDER BY TIMESTAMP DESC").to_pandas()
        has_quotes = not all_quotes.empty
    except Exception:
        all_quotes = pd.DataFrame(); has_quotes = False
    try:
        approval_history = session.sql(f"SELECT * FROM {fq_pricing('APPROVAL_WORKFLOW')} ORDER BY SUBMITTED_AT DESC").to_pandas()
        has_approvals = not approval_history.empty
    except Exception:
        approval_history = pd.DataFrame(); has_approvals = False

    if not has_quotes:
        st.markdown('<div class="insight-box">📭 No quotes found yet. Save quotes from the Configure Quote tab to populate the Executive Dashboard.</div>', unsafe_allow_html=True)
    else:
        total_quotes   = len(all_quotes)
        total_revenue  = all_quotes["ACTUAL_PRICE"].sum()   if "ACTUAL_PRICE" in all_quotes.columns else 0
        total_leakage  = all_quotes["LEAKAGE"].sum()        if "LEAKAGE"       in all_quotes.columns else 0
        avg_margin     = ((all_quotes["ACTUAL_PRICE"] - all_quotes["TOTAL_MANUFACTURING_COST"]) / all_quotes["ACTUAL_PRICE"] * 100).mean() if "ACTUAL_PRICE" in all_quotes.columns else 0
        leakage_rate   = (total_leakage / all_quotes["TARGET_PRICE"].sum() * 100) if "TARGET_PRICE" in all_quotes.columns and all_quotes["TARGET_PRICE"].sum() > 0 else 0

        if "LEAKAGE_PERCENT" not in all_quotes.columns and "LEAKAGE" in all_quotes.columns:
            all_quotes["LEAKAGE_PERCENT"] = (all_quotes["LEAKAGE"] / all_quotes["TARGET_PRICE"] * 100)

        high_risk_count = int((all_quotes["LEAKAGE_PERCENT"] >= warning_threshold).sum()) if "LEAKAGE_PERCENT" in all_quotes.columns else 0
        healthy_count   = int((all_quotes["LEAKAGE_PERCENT"] < healthy_threshold).sum())  if "LEAKAGE_PERCENT" in all_quotes.columns else 0
        win_rate        = (healthy_count / total_quotes * 100) if total_quotes > 0 else 0

        avg_health_score = all_quotes["HEALTH_SCORE"].mean() if "HEALTH_SCORE" in all_quotes.columns else None

        pending_approvals = 0; approved_count = 0; rejected_count = 0
        if has_approvals and "STATUS" in approval_history.columns:
            pending_approvals = int((approval_history["STATUS"] == "PENDING").sum())
            approved_count    = int((approval_history["STATUS"] == "APPROVED").sum())
            rejected_count    = int((approval_history["STATUS"] == "REJECTED").sum())
        approval_rate = (approved_count / max(1, approved_count + rejected_count) * 100)
        
        # ── KPI Row 1 ──────────────────────────────────────────────────────
        k1, k2, k3, k4 = st.columns(4)
        with k1:
            st.markdown(f"""<div class="exec-kpi-card" data-icon="📋">
              <div class="ek-label">Total Quotes</div><div class="ek-value">{total_quotes}</div>
              <div class="ek-sub">lifetime pipeline</div><div class="ek-trend flat">─ All time</div>
            </div>""", unsafe_allow_html=True)
        with k2:
            st.markdown(f"""<div class="exec-kpi-card" data-icon="💰">
              <div class="ek-label">Total Quoted Revenue</div><div class="ek-value">{fmt_currency(total_revenue)}</div>
              <div class="ek-sub">across all quotes</div>
              <div class="ek-trend up">▲ Active pipeline</div>
            </div>""", unsafe_allow_html=True)
        with k3:
            leak_cls = "down" if leakage_rate > warning_threshold else "up"
            leak_msg = "🔴 Above threshold" if leakage_rate > warning_threshold else "🟢 Within control"
            st.markdown(f"""<div class="exec-kpi-card" data-icon="⚠️">
              <div class="ek-label">Total Revenue Leakage</div><div class="ek-value">{fmt_currency(total_leakage)}</div>
              <div class="ek-sub">{leakage_rate:.1f}% of target revenue</div>
              <div class="ek-trend {leak_cls}">{leak_msg}</div>
            </div>""", unsafe_allow_html=True)
        with k4:
            m_cls = "up" if avg_margin >= target_margin_pct else "down"
            m_msg = "▲ On target" if avg_margin >= target_margin_pct else "▼ Below target"
            st.markdown(f"""<div class="exec-kpi-card" data-icon="📊">
              <div class="ek-label">Avg Achieved Margin</div><div class="ek-value">{avg_margin:.1f}%</div>
              <div class="ek-sub">target: {target_margin_pct}%</div><div class="ek-trend {m_cls}">{m_msg}</div>
            </div>""", unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── KPI Row 2 ──────────────────────────────────────────────────────
        k5, k6, k7, k8 = st.columns(4)
        with k5:
            st.markdown(f"""<div class="exec-kpi-card" data-icon="🟢">
              <div class="ek-label">Healthy Quotes</div><div class="ek-value">{healthy_count}</div>
              <div class="ek-sub">{win_rate:.0f}% of all quotes</div>
              <div class="ek-trend up">▲ Leakage &lt; {healthy_threshold}%</div>
            </div>""", unsafe_allow_html=True)
        with k6:
            hr_cls = "down" if high_risk_count > 0 else "up"
            hr_msg = "▼ Needs intervention" if high_risk_count > 0 else "▲ None — clean"
            st.markdown(f"""<div class="exec-kpi-card" data-icon="🔴">
              <div class="ek-label">High-Risk Quotes</div><div class="ek-value">{high_risk_count}</div>
              <div class="ek-sub">{(high_risk_count/total_quotes*100 if total_quotes else 0):.0f}% of all quotes</div>
              <div class="ek-trend {hr_cls}">{hr_msg}</div>
            </div>""", unsafe_allow_html=True)
        with k7:
            pend_cls = "down" if pending_approvals > 3 else "flat"
            pend_msg = "▼ Queue building" if pending_approvals > 3 else "─ Under control"
            st.markdown(f"""<div class="exec-kpi-card" data-icon="⏳">
              <div class="ek-label">Pending Approvals</div><div class="ek-value">{pending_approvals}</div>
              <div class="ek-sub">{approved_count} approved · {rejected_count} rejected</div>
              <div class="ek-trend {pend_cls}">{pend_msg}</div>
            </div>""", unsafe_allow_html=True)
        with k8:
            avg_hs_str = f"{avg_health_score:.0f}" if avg_health_score is not None else "N/A"
            hs_trend   = "up" if avg_health_score and avg_health_score >= 65 else "down"
            st.markdown(f"""<div class="exec-kpi-card" data-icon="✅">
              <div class="ek-label">Avg Quote Health Score</div><div class="ek-value">{avg_hs_str}</div>
              <div class="ek-sub">Approval rate: {approval_rate:.0f}%</div>
              <div class="ek-trend {hs_trend}">{"▲ Healthy" if avg_health_score and avg_health_score >= 65 else "▼ Needs improvement"}</div>
            </div>""", unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Charts Row ─────────────────────────────────────────────────────
        ch_left, ch_right = st.columns(2)
        with ch_left:
            st.markdown('<div class="section-header">Revenue vs Leakage Over Time</div>', unsafe_allow_html=True)
            if "TIMESTAMP" in all_quotes.columns:
                time_df = all_quotes.sort_values("TIMESTAMP").copy()
                time_df["TIMESTAMP"] = pd.to_datetime(time_df["TIMESTAMP"])
                fig_exec_trend = go.Figure()
                fig_exec_trend.add_trace(go.Scatter(x=time_df["TIMESTAMP"], y=time_df["ACTUAL_PRICE"],
                    name="Quoted Revenue", mode="lines+markers", line=dict(color="#3b82f6", width=2),
                    fill="tozeroy", fillcolor="rgba(59,130,246,0.08)"))
                fig_exec_trend.add_trace(go.Scatter(x=time_df["TIMESTAMP"], y=time_df["LEAKAGE"],
                    name="Leakage", mode="lines+markers", line=dict(color="#ef4444", width=1.5, dash="dot"),
                    fill="tozeroy", fillcolor="rgba(239,68,68,0.06)"))
                fig_exec_trend.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                    font_color="#94a3b8", height=280, margin=dict(l=0,r=0,t=10,b=0),
                    legend=dict(bgcolor="rgba(0,0,0,0)"),
                    xaxis=dict(gridcolor="#1e293b"), yaxis=dict(gridcolor="#1e293b"))
                st.plotly_chart(fig_exec_trend, use_container_width=True)

        with ch_right:
            st.markdown('<div class="section-header">Risk Distribution</div>', unsafe_allow_html=True)
            if "LEAKAGE_PERCENT" in all_quotes.columns:
                risk_counts = pd.DataFrame({"Risk":["🟢 Healthy","🟡 Warning","🔴 High Risk"],"Count":[
                    int((all_quotes["LEAKAGE_PERCENT"] < healthy_threshold).sum()),
                    int(((all_quotes["LEAKAGE_PERCENT"] >= healthy_threshold) & (all_quotes["LEAKAGE_PERCENT"] < warning_threshold)).sum()),
                    int((all_quotes["LEAKAGE_PERCENT"] >= warning_threshold).sum()),
                ]})
                fig_donut = px.pie(risk_counts, names="Risk", values="Count", hole=0.6,
                                   color_discrete_sequence=["#10b981","#f59e0b","#ef4444"])
                fig_donut.update_layout(paper_bgcolor="rgba(0,0,0,0)", font_color="#94a3b8",
                    height=280, margin=dict(l=0,r=0,t=10,b=0), legend=dict(bgcolor="rgba(0,0,0,0)"))
                fig_donut.update_traces(textfont_color="#f1f5f9")
                st.plotly_chart(fig_donut, use_container_width=True)

        # ── Health Score distribution ──────────────────────────────────────
        if "HEALTH_SCORE" in all_quotes.columns:
            st.markdown('<div class="section-header">Quote Health Score Distribution</div>', unsafe_allow_html=True)
            ch_hs1, ch_hs2 = st.columns(2)
            with ch_hs1:
                fig_hs = px.histogram(all_quotes, x="HEALTH_SCORE", nbins=20, color_discrete_sequence=["#3b82f6"])
                fig_hs.add_vline(x=auto_approve_score,    line_color="#10b981", line_dash="dash", annotation_text="Auto-Approve", annotation_font_color="#10b981")
                fig_hs.add_vline(x=manager_approve_score, line_color="#f59e0b", line_dash="dash", annotation_text="Manager",      annotation_font_color="#f59e0b")
                fig_hs.add_vline(x=director_score_floor,  line_color="#ef4444", line_dash="dash", annotation_text="Director",     annotation_font_color="#ef4444")
                fig_hs.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                    font_color="#94a3b8", height=260, margin=dict(l=0,r=0,t=10,b=0),
                    xaxis=dict(gridcolor="#1e293b",title="Health Score"), yaxis=dict(gridcolor="#1e293b",title="# Quotes"))
                st.plotly_chart(fig_hs, use_container_width=True)
            with ch_hs2:
                if "APPROVAL_ROUTING" in all_quotes.columns:
                    routing_counts = all_quotes["APPROVAL_ROUTING"].value_counts().reset_index()
                    routing_counts.columns = ["Routing","Count"]
                    fig_routing = px.bar(routing_counts, x="Routing", y="Count",
                                         color_discrete_sequence=["#8b5cf6"], text_auto=True)
                    fig_routing.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                        font_color="#94a3b8", height=260, margin=dict(l=0,r=0,t=10,b=0),
                        xaxis=dict(gridcolor="#1e293b"), yaxis=dict(gridcolor="#1e293b"))
                    fig_routing.update_traces(textfont_color="#f1f5f9")
                    st.plotly_chart(fig_routing, use_container_width=True)

        # ── Product performance table ──────────────────────────────────────
        st.markdown('<div class="section-header">Product Performance Summary</div>', unsafe_allow_html=True)
        if "PRODUCT" in all_quotes.columns:
            agg_dict = {"Quotes": ("PRODUCT","count"),
                        "Total_Revenue": ("ACTUAL_PRICE","sum"),
                        "Total_Leakage": ("LEAKAGE","sum"),
                        "Avg_Price": ("ACTUAL_PRICE","mean")}
            if "HEALTH_SCORE" in all_quotes.columns:
                agg_dict["Avg_Health"] = ("HEALTH_SCORE","mean")
            prod_perf = all_quotes.groupby("PRODUCT").agg(**agg_dict).reset_index()
            prod_perf["Leakage Rate %"] = (prod_perf["Total_Leakage"] / prod_perf["Total_Revenue"] * 100).round(1)
            prod_perf["Total_Revenue"]  = prod_perf["Total_Revenue"].apply(fmt_currency)
            prod_perf["Total_Leakage"]  = prod_perf["Total_Leakage"].apply(fmt_currency)
            prod_perf["Avg_Price"]       = prod_perf["Avg_Price"].apply(fmt_currency)
            st.dataframe(prod_perf, use_container_width=True, hide_index=True)

        # ── Margin trend ───────────────────────────────────────────────────
        if "ACHIEVED_MARGIN_PCT" in all_quotes.columns and "TIMESTAMP" in all_quotes.columns:
            st.markdown('<div class="section-header">Margin Achievement Trend</div>', unsafe_allow_html=True)
            marg_df = all_quotes.sort_values("TIMESTAMP").copy()
            fig_marg = go.Figure()
            fig_marg.add_hline(y=target_margin_pct, line_dash="dash", line_color="#3b82f6",
                               annotation_text=f"Target {target_margin_pct}%", annotation_font_color="#3b82f6")
            fig_marg.add_trace(go.Scatter(x=marg_df["TIMESTAMP"], y=marg_df["ACHIEVED_MARGIN_PCT"],
                mode="lines+markers", name="Achieved Margin %", line=dict(color="#10b981", width=2)))
            fig_marg.update_layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                font_color="#94a3b8", height=260, margin=dict(l=0,r=0,t=10,b=0),
                showlegend=False, xaxis=dict(gridcolor="#1e293b"), yaxis=dict(gridcolor="#1e293b",title="Margin %"))
            st.plotly_chart(fig_marg, use_container_width=True)


           
# ===================================================
# TAB 6 — QUOTE HEALTH & APPROVAL WORKFLOW
# ===================================================

# ===================================================
# TAB 7 — DIGITAL TWIN / LIVE SIMULATION
# ===================================================
with tab7:
    if "TABLE_MAP" not in st.session_state:
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()
    st.markdown('<div class="section-header">🧬 Digital Twin — Live Pricing Simulation</div>', unsafe_allow_html=True)
    st.caption("Every slider updates cost, margin, leakage, competitor position, and approval routing in real time.")

    # ── Simulation Inputs ─────────────────────────────────────────────────
    sim_col, live_col = st.columns([5, 4], gap="large")

    with sim_col:
        st.markdown('<div class="section-header">Cost Structure</div>', unsafe_allow_html=True)
        c1, c2 = st.columns(2)
        with c1:
            sim_material = st.slider("Material Cost", 10000, 200000, 60000, 1000,
                                     format=f"{currency_symbol}%d", key="sim_mat")
            sim_machine  = st.slider("Machine Cost",   5000, 100000, 25000,  500,
                                     format=f"{currency_symbol}%d", key="sim_mach")
        with c2:
            sim_setup    = st.slider("Setup Cost",     1000,  50000, 10000,  500,
                                     format=f"{currency_symbol}%d", key="sim_setup")
            sim_oh_pct   = st.slider("Overhead %",        0,     50,    20,    1, key="sim_oh")

        st.markdown('<div class="section-header">Pricing Policy</div>', unsafe_allow_html=True)
        c3, c4 = st.columns(2)
        with c3:
            sim_target_margin = st.slider("Target Margin %", 5, 60, 30, 1, key="sim_tm")
            sim_floor_buf     = st.slider("Floor Buffer %",  5, 30, 15, 1, key="sim_fb")
        with c4:
            sim_ceil_buf  = st.slider("Ceiling Buffer %", 5, 30, 10, 1, key="sim_cb")
            sim_qty       = st.slider("Order Quantity",   1, 500, 50,  1, key="sim_qty")

        st.markdown('<div class="section-header">Discounts</div>', unsafe_allow_html=True)
        c5, c6 = st.columns(2)
        with c5:
            sim_vol_disc = st.slider("Volume Discount %",  0.0, 20.0, 3.0, 0.5, key="sim_vd")
        with c6:
            sim_man_disc = st.slider("Manual Discount %",  0.0, 25.0, 0.0, 0.5, key="sim_md")
        sim_elast = st.slider("Price Elasticity Coefficient", -5.0, -0.1, -1.2, 0.1, key="sim_el")

        st.markdown('<div class="section-header">Competitor Prices</div>', unsafe_allow_html=True)
        cc1, cc2, cc3 = st.columns(3)
        with cc1:
            sim_comp_a = st.number_input("Competitor A", value=160000, step=5000, key="sim_ca")
        with cc2:
            sim_comp_b = st.number_input("Competitor B", value=140000, step=5000, key="sim_cb2")
        with cc3:
            sim_comp_c = st.number_input("Competitor C", value=175000, step=5000, key="sim_cc")

    # ── Live Engine ────────────────────────────────────────────────────────
    direct_cost   = sim_material + sim_machine + sim_setup
    sim_oh        = direct_cost * (sim_oh_pct / 100)
    sim_total_mfg = direct_cost + sim_oh

    sim_target_price = sim_total_mfg * (1 + sim_target_margin / 100)
    sim_floor_price  = sim_total_mfg * (1 + sim_floor_buf   / 100)
    sim_ceil_price   = sim_target_price * (1 + sim_ceil_buf  / 100)
    sim_total_disc   = sim_vol_disc + sim_man_disc
    sim_quoted       = sim_target_price * (1 - sim_total_disc / 100)
    sim_leakage      = sim_target_price - sim_quoted
    sim_leak_pct     = (sim_leakage / sim_target_price * 100) if sim_target_price else 0
    sim_ach_margin   = ((sim_quoted - sim_total_mfg) / sim_quoted * 100) if sim_quoted else 0
    sim_order_val    = sim_quoted * sim_qty
    sim_order_profit = (sim_quoted - sim_total_mfg) * sim_qty
    sim_order_leakage= sim_leakage * sim_qty
    sim_avg_comp     = (sim_comp_a + sim_comp_b + sim_comp_c) / 3
    sim_vs_mkt       = ((sim_quoted - sim_avg_comp) / sim_avg_comp * 100) if sim_avg_comp else 0

    # Health Score
    sim_health = compute_quote_health_score(
        sim_ach_margin, sim_target_margin,
        sim_leak_pct, healthy_threshold, warning_threshold,
        sim_quoted, sim_floor_price, sim_ceil_price,
        sim_vol_disc, sim_man_disc,
        [{"name":"A","price":sim_comp_a},{"name":"B","price":sim_comp_b},{"name":"C","price":sim_comp_c}]
    )

    with live_col:
        st.markdown('<div class="section-header">Live Output</div>', unsafe_allow_html=True)

        # KPI Grid
        st.markdown(f"""
        <div class="kpi-grid" style="grid-template-columns:1fr 1fr;gap:10px;">
            {render_kpi("Quoted Price",    fmt_currency(sim_quoted),         "blue")}
            {render_kpi("Mfg Cost",        fmt_currency(sim_total_mfg),      "blue")}
            {render_kpi("Achieved Margin", f"{sim_ach_margin:.1f}%",         "green" if sim_ach_margin >= sim_target_margin else "red")}
            {render_kpi("Leakage",         fmt_currency(sim_leakage),        "green" if sim_leak_pct < healthy_threshold else "red")}
            {render_kpi("Order Value",     fmt_currency(sim_order_val),      "blue")}
            {render_kpi("Order Profit",    fmt_currency(sim_order_profit),   "green" if sim_order_profit > 0 else "red")}
            {render_kpi("Leakage %",       f"{sim_leak_pct:.1f}%",           "green" if sim_leak_pct < healthy_threshold else "red")}
            {render_kpi("vs Market",       f"{sim_vs_mkt:+.1f}%",            "green" if -10 <= sim_vs_mkt <= 15 else "amber")}
        </div>
        """, unsafe_allow_html=True)

        # Price Band Gauge
        st.markdown(price_band_html(
            sim_floor_price, sim_target_price, sim_ceil_price, sim_quoted,
            competitors=[
                {"name":"Comp A","price":sim_comp_a},
                {"name":"Comp B","price":sim_comp_b},
                {"name":"Comp C","price":sim_comp_c},
            ]
        ), unsafe_allow_html=True)

        # Health Score + Routing
        hs = sim_health["total_score"]
        hs_color = "#10b981" if hs >= 70 else ("#f59e0b" if hs >= 40 else "#ef4444")
        st.markdown(f"""
        <div style="margin-top:10px;background:#111827;border:1px solid #1e2d47;border-radius:12px;padding:16px;">
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <span style="font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:0.5px;">Quote Health Score</span>
            <span class="routing-badge {sim_health['routing_class']}">{sim_health['routing_icon']} {sim_health['routing']}</span>
          </div>
          <div style="font-size:34px;font-weight:700;color:{hs_color};font-family:'JetBrains Mono',monospace;margin-top:6px;">
            {hs}<span style="font-size:14px;color:#64748b;">/100</span>
          </div>
          <div class="health-bar-wrap"><div class="health-bar-fill" style="width:{hs}%;background:{hs_color};"></div></div>
          <div style="font-size:11px;color:#64748b;margin-top:6px;">{sim_health['routing_desc']}</div>
        </div>
        """, unsafe_allow_html=True)

        # Alerts
        if sim_quoted < sim_floor_price:
            st.markdown('<div class="insight-box alert">🚨 Below floor price — this deal is loss-making.</div>', unsafe_allow_html=True)
        elif sim_leak_pct >= warning_threshold:
            st.markdown(f'<div class="insight-box alert">🔴 Leakage at {sim_leak_pct:.1f}% — high risk.</div>', unsafe_allow_html=True)
        elif sim_leak_pct >= healthy_threshold:
            st.markdown(f'<div class="insight-box warn">🟡 Moderate leakage ({sim_leak_pct:.1f}%).</div>', unsafe_allow_html=True)
        else:
            st.markdown('<div class="insight-box ok">🟢 Healthy — margin is protected.</div>', unsafe_allow_html=True)

    # ── Waterfall ──────────────────────────────────────────────────────────
    st.markdown('<div class="section-header">Cost → Price Waterfall</div>', unsafe_allow_html=True)
    wf_data = [("Material", sim_material), ("Machine", sim_machine),
               ("Setup", sim_setup), ("Overhead", sim_oh), ("Total Mfg", sim_total_mfg)]
    wf_df = pd.DataFrame(wf_data, columns=["Component", "Amount"])
    fig_sim_wf = go.Figure(go.Waterfall(
        name="Cost build-up", orientation="v",
        measure=["relative","relative","relative","relative","total"],
        x=wf_df["Component"], y=wf_df["Amount"],
        connector={"line": {"color": "#1e293b"}},
        increasing={"marker": {"color": "#3b82f6"}},
        totals={"marker": {"color": "#8b5cf6"}},
        texttemplate=f"{currency_symbol}%{{y:,.0f}}", textposition="outside",
    ))
    fig_sim_wf.update_layout(
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        font_color="#94a3b8", height=320, margin=dict(l=0,r=0,t=20,b=0),
        showlegend=False, yaxis=dict(gridcolor="#1e293b", zerolinecolor="#1e293b"))
    st.plotly_chart(fig_sim_wf, use_container_width=True)

    # ── Elasticity Model ───────────────────────────────────────────────────
    st.markdown('<div class="section-header">Elasticity — Demand & Revenue at Price Variants</div>', unsafe_allow_html=True)
    base_demand = 100
    price_scenarios = [
        ("−20%", sim_quoted*0.80), ("−10%", sim_quoted*0.90), ("−5%", sim_quoted*0.95),
        ("Current", sim_quoted), ("+5%", sim_quoted*1.05), ("+10%", sim_quoted*1.10), ("+20%", sim_quoted*1.20)
    ]
    elas_rows = []
    for label, test_price in price_scenarios:
        res = compute_elasticity(sim_quoted, base_demand, sim_elast, test_price)
        elas_rows.append({
            "Scenario": label,
            "Price": fmt_currency(test_price),
            "Demand (units)": f"{res['new_demand']:.0f}",
            "Revenue": fmt_currency(res["new_revenue"]),
            "Rev Δ": f"{res['delta_revenue_pct']:+.1f}%",
            "Margin %": f"{((test_price - sim_total_mfg)/test_price*100) if test_price else 0:.1f}%",
        })
    st.dataframe(pd.DataFrame(elas_rows), use_container_width=True, hide_index=True)

    # ── Margin Heatmap ─────────────────────────────────────────────────────
    st.markdown('<div class="section-header">Margin Heatmap — Discount % × Order Quantity</div>', unsafe_allow_html=True)
    hm_qtys  = [1, 10, 25, 50, 100, 200, 500]
    hm_discs = [0, 2, 5, 8, 12, 16, 20]
    hm_data = []
    for disc in hm_discs:
        row = {}
        for q in hm_qtys:
            vol_extra = 2 if q >= 100 else (1 if q >= 50 else 0)
            tot_disc = disc + vol_extra
            tp = sim_total_mfg * (1 + sim_target_margin/100)
            qp = tp * (1 - tot_disc/100)
            margin = (qp - sim_total_mfg) / qp * 100 if qp else 0
            row[f"{q}u"] = round(margin, 1)
        hm_data.append(row)
    hm_df = pd.DataFrame(hm_data, index=[f"{d}% disc" for d in hm_discs])
    fig_hm = go.Figure(go.Heatmap(
        z=hm_df.values.tolist(), x=hm_df.columns.tolist(), y=hm_df.index.tolist(),
        colorscale=[[0,"#ef4444"],[0.5,"#f59e0b"],[1,"#10b981"]],
        text=[[f"{v:.1f}%" for v in row] for row in hm_df.values.tolist()],
        texttemplate="%{text}", showscale=True,
    ))
    fig_hm.update_layout(
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        font_color="#94a3b8", height=320, margin=dict(l=0,r=0,t=10,b=0))
    st.plotly_chart(fig_hm, use_container_width=True)

    # ── Competitor Position ────────────────────────────────────────────────
    st.markdown('<div class="section-header">Competitor Market Position</div>', unsafe_allow_html=True)
    comp_pos_data = pd.DataFrame([
        {"Name": "Your quote", "Price": sim_quoted,   "Type": "You"},
        {"Name": "Competitor A", "Price": sim_comp_a, "Type": "Competitor"},
        {"Name": "Competitor B", "Price": sim_comp_b, "Type": "Competitor"},
        {"Name": "Competitor C", "Price": sim_comp_c, "Type": "Competitor"},
        {"Name": "Target price", "Price": sim_target_price, "Type": "Target"},
        {"Name": "Market avg",   "Price": sim_avg_comp,     "Type": "Market"},
    ]).sort_values("Price")
    fig_comp = px.bar(
        comp_pos_data, y="Name", x="Price", orientation="h",
        color="Type",
        color_discrete_map={"You":"#3b82f6","Competitor":"#8b5cf6","Target":"#10b981","Market":"#f59e0b"},
        text="Price"
    )
    fig_comp.update_traces(texttemplate=f"{currency_symbol}%{{x:,.0f}}", textposition="outside")
    fig_comp.update_layout(
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        font_color="#94a3b8", height=300, margin=dict(l=0,r=20,t=10,b=0),
        legend=dict(bgcolor="rgba(0,0,0,0)"),
        xaxis=dict(gridcolor="#1e293b"), yaxis=dict(gridcolor="#1e293b"),
        showlegend=True
    )
    fig_comp.update_traces(textfont_color="#f1f5f9")
    st.plotly_chart(fig_comp, use_container_width=True)

    # ── Save simulation snapshot ────────────────────────────────────────────
    if st.button("💾 Save Simulation Snapshot", type="primary"):
            snap_df = pd.DataFrame([{
                "QUOTE_ID": str(uuid.uuid4())[:8],
                "TIMESTAMP": datetime.now(),
                "CUSTOMER_NAME": "Digital Twin Simulation",
                "PRODUCT": "Simulated Product",
                "TARGET_PRICE": float(sim_target_price),
                "ACTUAL_PRICE": float(sim_quoted),
                "LEAKAGE": float(sim_leakage),
                "MATERIAL_COST": float(sim_material),
                "MACHINE_COST": float(sim_machine),
                "SETUP_COST": float(sim_setup),
                "OVERHEAD_COST": float(sim_oh),
                "TOTAL_MANUFACTURING_COST": float(sim_total_mfg),
                "ACHIEVED_MARGIN_PCT": float(sim_ach_margin),
                "ORDER_QTY": int(sim_qty),
                "HEALTH_SCORE": sim_health["total_score"],
                "APPROVAL_ROUTING": sim_health["routing"],
            }])
            try:
                session.write_pandas(snap_df,
                    "QUOTE_HISTORY",
                    database=PRICING_DB,
                    schema=PRICING_CORE_OUTPUT_SCHEMA,
                    auto_create_table=True, overwrite=False)
                st.success("✓ Snapshot saved to QUOTE_HISTORY.")
            except Exception as e:
                st.error(f"Save failed: {e}")


# ===================================================
# TAB 9 — 🤖 AI PRICING COPILOT
# Insert at the very end of the file, right after the `with tab8:` block.
# ===================================================

with tab8:
    if "TABLE_MAP" not in st.session_state and st.session_state.get("pricing_mode") != "Demo Mode":
        st.info("👈 Go to **Customer Onboarding** and load your tables first.")
        st.stop()

    _copilot_key_ok = bool(GEMINI_API_KEY and len(GEMINI_API_KEY.strip()) > 20)

    st.markdown('<div class="section-header">🤖 AI Pricing Copilot</div>', unsafe_allow_html=True)
    st.caption("Cross-module decision support — reads across Quotes, Approvals, and Cost data.")

    # ── Context Strip ────────────────────────────────────────────────────
    q = st.session_state.get("quote", {})
    ctx_cols = st.columns(4)
    with ctx_cols[0]:
        st.metric("Active Product", q.get("product", "—"))
    with ctx_cols[1]:
        st.metric("Active Simulation", q.get("simulation_id", "—"))
    with ctx_cols[2]:
        st.metric("Pricing Mode", st.session_state.get("pricing_mode", "—"))
    with ctx_cols[3]:
        st.metric("Gemini Status", "🟢 Configured" if _copilot_key_ok else "🔴 Not configured")
    st.markdown("---")

    # ── Command Bar / Conversational Console ────────────────────────────
    st.markdown('<div class="section-header">💬 Ask the Copilot</div>', unsafe_allow_html=True)

    if "copilot_chat_history" not in st.session_state:
        st.session_state["copilot_chat_history"] = []

    for turn in st.session_state["copilot_chat_history"]:
        with st.chat_message(turn["role"]):
            st.markdown(turn["content"])

    copilot_question = st.chat_input("Ask about quotes, margins, approvals, or pricing trends…")

    if copilot_question:
        st.session_state["copilot_chat_history"].append({"role": "user", "content": copilot_question})
        with st.chat_message("user"):
            st.markdown(copilot_question)

        if not _copilot_key_ok:
            answer = "AI Copilot needs a valid Gemini API key configured to answer questions."
        else:
            try:
                q_hist = session.sql(
                    f"SELECT * FROM {fq_pricing('QUOTE_HISTORY')} ORDER BY TIMESTAMP DESC LIMIT 30"
                ).to_pandas()
            except Exception:
                q_hist = pd.DataFrame()

            grounding_prompt = f"""You are a pricing analytics assistant for a B2B manufacturing company.
Answer the question below using the quote data provided. Be concise. If the data doesn't
support a confident answer, say so rather than guessing.

QUOTE DATA (most recent 30):
{q_hist.to_csv(index=False) if not q_hist.empty else "No quote data available."}

QUESTION: {copilot_question}
"""
            result = call_gemini(GEMINI_API_KEY, GEMINI_MODEL, grounding_prompt)
            answer = result.get("raw_text") or result.get("error") or "No response."

        with st.chat_message("assistant"):
            st.markdown(answer)
        st.session_state["copilot_chat_history"].append({"role": "assistant", "content": answer})
        log_copilot_action("Conversational Console", answer, "shown")

    st.markdown("---")

    # ── Daily Intelligence Brief ─────────────────────────────────────────
    st.markdown('<div class="section-header">📋 Daily Intelligence Brief</div>', unsafe_allow_html=True)
    with st.expander("Today's Brief", expanded=True):
        if not _copilot_key_ok:
            st.markdown(
                '<div class="insight-box warn">⚙️ Configure a Gemini API key to enable the Daily Brief.</div>',
                unsafe_allow_html=True,
            )
        else:
            if st.button("🔄 Generate / Refresh Brief", key="copilot_brief_btn"):
                with st.spinner("Generating brief…"):
                    brief_text = generate_copilot_brief()
                    st.session_state["copilot_brief_text"] = brief_text
                    log_copilot_action("Daily Intelligence Brief", brief_text, "shown")
            st.markdown(st.session_state.get("copilot_brief_text", "Click above to generate today's brief."))

    st.markdown("---")

    # ── Deal Risk Panel ──────────────────────────────────────────────────
    st.markdown('<div class="section-header">⚠️ Deal Risk — Active Quote</div>', unsafe_allow_html=True)
    if not q:
        st.caption("Configure a quote in **Configure Quote** to see its risk profile here.")
    elif not _copilot_key_ok:
        st.markdown(
            '<div class="insight-box warn">⚙️ Configure a Gemini API key to enable risk scoring.</div>',
            unsafe_allow_html=True,
        )
    else:
        if st.button("Score this quote's risk", key="copilot_risk_btn"):
            with st.spinner("Scoring deal risk…"):
                risk_result = score_deal_risk_for_quote(q)
                st.session_state["copilot_risk_result"] = risk_result

        risk_result = st.session_state.get("copilot_risk_result")
        if risk_result and risk_result.get("risk_score") is not None:
            rs = risk_result["risk_score"]
            rs_color = "#10b981" if rs < 35 else ("#f59e0b" if rs < 65 else "#ef4444")
            st.markdown(
                f'<div style="font-size:32px;font-weight:700;color:{rs_color};'
                f'font-family:\'JetBrains Mono\',monospace;">{rs}/100</div>',
                unsafe_allow_html=True,
            )
            for factor in risk_result.get("top_factors", []):
                st.write(f"- {factor}")
            if risk_result.get("suggested_action"):
                st.success(f"Suggested action: {risk_result['suggested_action']}")
                if st.button("Accept suggestion", key="copilot_accept_risk"):
                    log_copilot_action(
                        "Deal Risk Panel", risk_result["suggested_action"], "accepted",
                        quote_id=q.get("kmat_id"),
                    )
                    st.toast("Logged to Action Ledger.")
        elif risk_result:
            st.warning("Could not parse a risk score from the AI response.")
            st.caption(risk_result.get("top_factors", [""])[0])

    st.markdown("---")

    # ── Margin Anomaly Detector ──────────────────────────────────────────
    st.markdown('<div class="section-header">🔍 Margin Anomaly Detector</div>', unsafe_allow_html=True)
    z_thresh = st.slider("Sensitivity (z-score threshold)", 1.0, 3.0, 1.5, 0.1, key="copilot_z")

    if st.button("Scan quote history for anomalies", key="copilot_scan_btn"):
        with st.spinner("Scanning…"):
            anomalies = detect_margin_anomalies(z_thresh)
            st.session_state["copilot_anomalies"] = anomalies

    anomalies = st.session_state.get("copilot_anomalies")
    if anomalies is not None and not anomalies.empty:
        show_cols = [c for c in ["QUOTE_ID", "PRODUCT", "ACHIEVED_MARGIN_PCT", "mean", "Z_SCORE", "TIMESTAMP"]
                     if c in anomalies.columns]
        st.dataframe(
            anomalies[show_cols].rename(columns={"mean": "PRODUCT_AVG_MARGIN"}),
            use_container_width=True,
        )
        if st.button("Flag top anomaly for review", key="copilot_flag_btn"):
            top = anomalies.iloc[0]
            note = (
                f"{top.get('PRODUCT')} quote {top.get('QUOTE_ID')} margin "
                f"{top.get('ACHIEVED_MARGIN_PCT'):.1f}% vs product avg {top.get('mean'):.1f}% "
                f"(z={top.get('Z_SCORE'):.2f})"
            )
            log_copilot_action("Margin Anomaly Detector", note, "flagged", quote_id=top.get("QUOTE_ID"))
            st.toast("Flagged and logged.")
    elif anomalies is not None:
        st.success("No margin anomalies found at this sensitivity.")
    else:
        st.caption("Run a scan to check saved quotes for margin outliers.")

    st.markdown("---")

    # ── Action Ledger ────────────────────────────────────────────────────
    st.markdown('<div class="section-header">🧾 Action Ledger</div>', unsafe_allow_html=True)
    try:
        ledger = session.sql(
            f"SELECT * FROM {fq_pricing('COPILOT_ACTION_LEDGER')} ORDER BY TIMESTAMP DESC LIMIT 100"
        ).to_pandas()
        if ledger.empty:
            st.caption("No Copilot actions logged yet.")
        else:
            feature_filter = st.multiselect(
                "Filter by feature",
                options=sorted(ledger["FEATURE_NAME"].unique()),
                key="copilot_ledger_filter",
            )
            display_ledger = ledger[ledger["FEATURE_NAME"].isin(feature_filter)] if feature_filter else ledger
            st.dataframe(display_ledger, use_container_width=True)
    except Exception:
        st.caption("No Copilot actions logged yet — the table is created on first write.") 

