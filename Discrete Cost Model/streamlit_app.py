# Discrete Manufacturing Cost Model - Streamlit app with AI-driven cost optimization
# Co-authored with CoCo
# =====================================================
# Discrete Manufacturing Cost Model
# Premium Glass UI Patch - Enhanced Version
# =====================================================
# Replace the current imports / page config / CSS / title section
# at the top of your existing Streamlit app with this block.
# Keep all existing data, mapping, Snowflake, and costing logic below it.

# =====================================================
# Imports
# =====================================================
# pip install google-generativeai
import streamlit as st
from difflib import SequenceMatcher
import uuid
import time
from datetime import datetime

RAPIDFUZZ_AVAILABLE = False
import pandas as pd
from snowflake.snowpark.context import get_active_session

# Initialize session state
session = get_active_session()
if "saved_scenarios" not in st.session_state:
    st.session_state.saved_scenarios = []

if "ai_scenarios" not in st.session_state:
    st.session_state.ai_scenarios = []

if "analysis_history" not in st.session_state:
    st.session_state.analysis_history = []

if "user_preferences" not in st.session_state:
    st.session_state.user_preferences = {
        "currency": "USD",
        "decimal_places": 2,
        "date_format": "YYYY-MM-DD"
    }


# =====================================================
# Page configuration
# =====================================================
st.set_page_config(
    page_title="Discrete Manufacturing Cost Studio",
    page_icon="🏭",
    layout="wide",
    initial_sidebar_state="expanded",
)


# =====================================================
# Premium glass theme - Enhanced Version
# =====================================================
st.markdown(
    """
    <style>
    :root {
        --dm-bg-deep: #07111f;
        --dm-bg-mid: #0d1b2f;
        --dm-panel: rgba(255,255,255,0.085);
        --dm-panel-strong: rgba(255,255,255,0.13);
        --dm-border: rgba(255,255,255,0.16);
        --dm-text: #f3f8ff;
        --dm-muted: rgba(230,239,250,0.67);
        --dm-cyan: #67e8f9;
        --dm-violet: #a78bfa;
        --dm-green: #86efac;
        --dm-amber: #fcd34d;
        --dm-red: #fb7185;
        --dm-pink: #f472b6;
        --dm-blue: #60a5fa;
        --dm-glass: rgba(255,255,255,0.05);
        --dm-glow: rgba(103,232,249,0.15);
    }

    html, body, [class*="css"] {
        font-family: 'Inter', ui-sans-serif, system-ui, -apple-system,
                     BlinkMacSystemFont, 'Segoe UI', sans-serif;
        scroll-behavior: smooth;
    }

    .stApp {
        background:
            radial-gradient(circle at 8% 6%, rgba(103,232,249,0.20), transparent 34%),
            radial-gradient(circle at 92% 3%, rgba(167,139,250,0.20), transparent 36%),
            radial-gradient(circle at 58% 95%, rgba(134,239,172,0.10), transparent 34%),
            radial-gradient(circle at 30% 50%, rgba(96,165,250,0.08), transparent 40%),
            linear-gradient(145deg, var(--dm-bg-deep) 0%, var(--dm-bg-mid) 52%, #111827 100%);
        color: var(--dm-text);
        transition: background 0.5s ease;
    }

    .block-container {
        max-width: 1480px;
        padding-top: 1.25rem;
        padding-bottom: 3rem;
        position: relative;
    }

    /* Sidebar - Enhanced */
    section[data-testid="stSidebar"] {
        background: linear-gradient(
            180deg,
            rgba(10,20,36,0.98),
            rgba(7,14,27,0.99)
        );
        border-right: 1px solid rgba(255,255,255,0.11);
        backdrop-filter: blur(20px);
        transition: all 0.3s ease;
    }

    section[data-testid="stSidebar"] > div {
        padding-top: 1.1rem;
        padding-left: 0.5rem;
        padding-right: 0.5rem;
    }

    section[data-testid="stSidebar"]::-webkit-scrollbar {
        width: 4px;
    }

    section[data-testid="stSidebar"]::-webkit-scrollbar-track {
        background: rgba(255,255,255,0.05);
    }

    section[data-testid="stSidebar"]::-webkit-scrollbar-thumb {
        background: rgba(103,232,249,0.3);
        border-radius: 10px;
    }

    /* Hero - Enhanced */
    .dm-hero {
        position: relative;
        overflow: hidden;
        border-radius: 28px;
        border: 1px solid var(--dm-border);
        padding: 31px 34px;
        margin-bottom: 22px;
        background: linear-gradient(
            135deg,
            rgba(255,255,255,0.135),
            rgba(255,255,255,0.045)
        );
        box-shadow:
            0 26px 80px rgba(0,0,0,0.34),
            inset 0 1px 0 rgba(255,255,255,0.17);
        backdrop-filter: blur(20px);
        animation: fadeInUp 0.8s ease-out;
        transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .dm-hero:hover {
        box-shadow:
            0 30px 90px rgba(0,0,0,0.4),
            inset 0 1px 0 rgba(255,255,255,0.2);
        transform: translateY(-2px);
    }

    .dm-hero::after {
        content: "";
        position: absolute;
        width: 360px;
        height: 360px;
        right: -130px;
        top: -185px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(103,232,249,0.28), transparent 66%);
        pointer-events: none;
        animation: pulseGlow 4s ease-in-out infinite;
    }

    .dm-hero::before {
        content: "";
        position: absolute;
        width: 240px;
        height: 240px;
        left: -100px;
        bottom: -120px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(167,139,250,0.2), transparent 60%);
        pointer-events: none;
        animation: pulseGlow 6s ease-in-out infinite reverse;
    }

    @keyframes pulseGlow {
        0%, 100% { opacity: 0.6; transform: scale(1); }
        50% { opacity: 1; transform: scale(1.1); }
    }

    @keyframes fadeInUp {
        from { opacity: 0; transform: translateY(30px); }
        to { opacity: 1; transform: translateY(0); }
    }

    .dm-eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 7px 12px;
        border-radius: 999px;
        border: 1px solid rgba(103,232,249,0.28);
        background: rgba(103,232,249,0.11);
        color: #bff7ff;
        font-size: 0.76rem;
        font-weight: 800;
        letter-spacing: 0.075em;
        text-transform: uppercase;
        margin-bottom: 14px;
        position: relative;
        z-index: 1;
        backdrop-filter: blur(4px);
    }

    .dm-title {
        margin: 0;
        color: #ffffff;
        font-size: clamp(2.1rem, 4vw, 4rem);
        line-height: 0.97;
        font-weight: 850;
        letter-spacing: -0.065em;
        position: relative;
        z-index: 1;
    }

    .dm-title span {
        background: linear-gradient(90deg, var(--dm-cyan), var(--dm-violet), #f0abfc);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-size: 200% auto;
        animation: shimmer 4s ease-in-out infinite;
    }

    @keyframes shimmer {
        0% { background-position: 0% center; }
        50% { background-position: 200% center; }
        100% { background-position: 0% center; }
    }

    .dm-subtitle {
        max-width: 940px;
        margin-top: 14px;
        color: var(--dm-muted);
        font-size: 1rem;
        line-height: 1.65;
        position: relative;
        z-index: 1;
    }

    .dm-pills {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-top: 21px;
        position: relative;
        z-index: 1;
    }

    .dm-pill {
        padding: 9px 12px;
        border-radius: 999px;
        border: 1px solid rgba(255,255,255,0.15);
        background: rgba(255,255,255,0.075);
        color: rgba(245,250,255,0.90);
        font-size: 0.84rem;
        font-weight: 650;
        backdrop-filter: blur(4px);
        transition: all 0.3s ease;
        cursor: default;
    }

    .dm-pill:hover {
        background: rgba(255,255,255,0.12);
        border-color: rgba(103,232,249,0.3);
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
    }

    .dm-pill strong {
        color: #ffffff;
        font-weight: 800;
    }

    /* Headings */
    h1, h2, h3, h4 {
        color: #f7fbff;
        letter-spacing: -0.035em;
        font-weight: 800;
    }

    h2 {
        margin-top: 1.3rem;
        background: linear-gradient(90deg, #ffffff, rgba(255,255,255,0.7));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    /* Native metric cards - Enhanced */
    [data-testid="stMetric"] {
        min-height: 132px;
        padding: 19px 19px 16px 19px;
        border-radius: 22px;
        border: 1px solid rgba(255,255,255,0.15);
        background: linear-gradient(
            145deg,
            rgba(255,255,255,0.125),
            rgba(255,255,255,0.048)
        );
        box-shadow:
            0 16px 44px rgba(0,0,0,0.24),
            inset 0 1px 0 rgba(255,255,255,0.15);
        backdrop-filter: blur(16px);
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        position: relative;
        overflow: hidden;
    }

    [data-testid="stMetric"]::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 2px;
        background: linear-gradient(90deg, transparent, rgba(103,232,249,0.3), transparent);
        transform: scaleX(0);
        transition: transform 0.6s ease;
    }

    [data-testid="stMetric"]:hover::before {
        transform: scaleX(1);
    }

    [data-testid="stMetric"]:hover {
        transform: translateY(-3px) scale(1.01);
        border-color: rgba(103,232,249,0.32);
        box-shadow:
            0 20px 50px rgba(0,0,0,0.28),
            inset 0 1px 0 rgba(255,255,255,0.2);
    }

    [data-testid="stMetricLabel"] {
        color: rgba(226,236,248,0.67);
        font-size: 0.78rem;
        font-weight: 760;
        letter-spacing: 0.055em;
        text-transform: uppercase;
    }

    [data-testid="stMetricValue"] {
        color: #ffffff;
        font-size: 1.9rem;
        font-weight: 840;
        letter-spacing: -0.045em;
        background: linear-gradient(135deg, #ffffff, rgba(255,255,255,0.7));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    [data-testid="stMetricDelta"] {
        font-weight: 700;
        padding: 4px 8px;
        border-radius: 8px;
        background: rgba(255,255,255,0.05);
    }

    /* Buttons - Enhanced */
    div[data-testid="stButton"] > button {
        min-height: 3rem;
        border-radius: 16px;
        border: 1px solid rgba(255,255,255,0.16);
        background: linear-gradient(
            135deg,
            rgba(255,255,255,0.12),
            rgba(255,255,255,0.055)
        );
        color: #f8fbff;
        font-weight: 800;
        box-shadow: 0 11px 28px rgba(0,0,0,0.24);
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        position: relative;
        overflow: hidden;
    }

    div[data-testid="stButton"] > button::after {
        content: "";
        position: absolute;
        inset: 0;
        background: linear-gradient(135deg, transparent, rgba(255,255,255,0.05));
        opacity: 0;
        transition: opacity 0.3s ease;
    }

    div[data-testid="stButton"] > button:hover::after {
        opacity: 1;
    }

    div[data-testid="stButton"] > button:hover {
        transform: translateY(-2px) scale(1.01);
        border-color: rgba(103,232,249,0.38);
        box-shadow: 0 16px 35px rgba(0,0,0,0.28);
    }

    div[data-testid="stButton"] > button:active {
        transform: scale(0.98);
    }

    div[data-testid="stButton"] > button[kind="primary"] {
        border: 0 !important;
        color: #ffffff !important;
        background: linear-gradient(90deg, #22d3ee, #7c3aed) !important;
        position: relative;
        overflow: hidden;
    }

    div[data-testid="stButton"] > button[kind="primary"]::before {
        content: "";
        position: absolute;
        inset: 0;
        background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
        transform: translateX(-100%);
        transition: transform 0.6s ease;
    }

    div[data-testid="stButton"] > button[kind="primary"]:hover::before {
        transform: translateX(100%);
    }

    /* Inputs and select boxes - Enhanced */
    div[data-baseweb="select"] > div,
    div[data-testid="stTextInput"] input,
    div[data-testid="stNumberInput"] input,
    div[data-testid="stTextArea"] textarea {
        color: #ffffff !important;
        border-radius: 14px !important;
        border-color: rgba(255,255,255,0.16) !important;
        background: rgba(255,255,255,0.075) !important;
        transition: all 0.3s ease !important;
        backdrop-filter: blur(8px) !important;
    }

    div[data-baseweb="select"] > div:hover,
    div[data-testid="stTextInput"] input:hover,
    div[data-testid="stNumberInput"] input:hover,
    div[data-testid="stTextArea"] textarea:hover {
        border-color: rgba(103,232,249,0.3) !important;
        background: rgba(255,255,255,0.1) !important;
    }

    div[data-baseweb="select"] > div:focus,
    div[data-testid="stTextInput"] input:focus,
    div[data-testid="stNumberInput"] input:focus,
    div[data-testid="stTextArea"] textarea:focus {
        border-color: rgba(103,232,249,0.5) !important;
        box-shadow: 0 0 0 3px rgba(103,232,249,0.1) !important;
        outline: none !important;
    }

    label[data-testid="stWidgetLabel"] p {
        color: rgba(234,242,252,0.80) !important;
        font-weight: 740;
        letter-spacing: 0.02em;
    }

    /* File uploader - Enhanced */
    [data-testid="stFileUploaderDropzone"] {
        padding: 26px;
        border-radius: 20px;
        border: 1px dashed rgba(103,232,249,0.34);
        background: linear-gradient(
            145deg,
            rgba(103,232,249,0.075),
            rgba(167,139,250,0.055)
        );
        transition: all 0.3s ease;
        backdrop-filter: blur(8px);
    }

    [data-testid="stFileUploaderDropzone"]:hover {
        border-color: rgba(103,232,249,0.5);
        background: linear-gradient(
            145deg,
            rgba(103,232,249,0.12),
            rgba(167,139,250,0.08)
        );
        transform: scale(1.01);
    }

    /* Tabs - Enhanced */
    button[data-baseweb="tab"] {
        margin-right: 8px !important;
        padding: 11px 17px !important;
        border-radius: 999px !important;
        border: 1px solid rgba(255,255,255,0.11) !important;
        background: rgba(255,255,255,0.055) !important;
        color: rgba(232,241,252,0.72) !important;
        font-weight: 780 !important;
        transition: all 0.3s ease !important;
        backdrop-filter: blur(4px) !important;
    }

    button[data-baseweb="tab"]:hover {
        background: rgba(255,255,255,0.09) !important;
        border-color: rgba(255,255,255,0.2) !important;
        transform: translateY(-1px);
    }

    button[data-baseweb="tab"][aria-selected="true"] {
        color: #ffffff !important;
        border-color: rgba(103,232,249,0.30) !important;
        background: linear-gradient(
            90deg,
            rgba(103,232,249,0.18),
            rgba(167,139,250,0.17)
        ) !important;
        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }

    div[data-baseweb="tab-highlight"] {
        display: none !important;
    }

    /* Dataframes - Enhanced */
    div[data-testid="stDataFrame"] {
        overflow: hidden;
        border-radius: 20px;
        border: 1px solid rgba(255,255,255,0.12);
        box-shadow: 0 13px 34px rgba(0,0,0,0.19);
        transition: all 0.3s ease;
    }

    div[data-testid="stDataFrame"]:hover {
        box-shadow: 0 16px 40px rgba(0,0,0,0.25);
        border-color: rgba(255,255,255,0.18);
    }

    /* Expanders - Enhanced */
    details[data-testid="stExpander"] {
        border-radius: 18px;
        border: 1px solid rgba(255,255,255,0.12);
        background: rgba(255,255,255,0.055);
        backdrop-filter: blur(8px);
        transition: all 0.3s ease;
    }

    details[data-testid="stExpander"]:hover {
        border-color: rgba(255,255,255,0.2);
        background: rgba(255,255,255,0.07);
    }

    details[data-testid="stExpander"] summary {
        padding: 12px 16px;
        font-weight: 700;
        color: rgba(255,255,255,0.9);
    }

    /* Alerts - Enhanced */
    div[data-testid="stAlert"] {
        border-radius: 18px;
        border: 1px solid rgba(255,255,255,0.13);
        background: rgba(255,255,255,0.065);
        backdrop-filter: blur(12px);
        padding: 16px 20px;
        animation: slideIn 0.5s ease-out;
    }

    @keyframes slideIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
    }

    /* Dividers */
    hr {
        border-color: rgba(255,255,255,0.10);
        margin: 2rem 0;
        background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
        height: 1px;
        border: none;
    }

    /* Optional reusable section shell - Enhanced */
    .dm-section {
        margin: 17px 0;
        padding: 20px;
        border-radius: 23px;
        border: 1px solid rgba(255,255,255,0.13);
        background: linear-gradient(
            145deg,
            rgba(255,255,255,0.095),
            rgba(255,255,255,0.045)
        );
        box-shadow: 0 15px 42px rgba(0,0,0,0.21);
        backdrop-filter: blur(15px);
        transition: all 0.3s ease;
        animation: fadeInUp 0.6s ease-out;
    }

    .dm-section:hover {
        border-color: rgba(255,255,255,0.2);
        box-shadow: 0 18px 48px rgba(0,0,0,0.25);
    }

    .dm-section-title {
        margin: 0 0 5px 0;
        color: #ffffff;
        font-size: 1.22rem;
        font-weight: 820;
        letter-spacing: -0.035em;
        background: linear-gradient(90deg, #ffffff, rgba(255,255,255,0.7));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    .dm-section-copy {
        margin: 0;
        color: rgba(228,238,249,0.62);
        font-size: 0.9rem;
        line-height: 1.6;
    }
    /* =============================================
       LEVEL 2: SECTION HEADERS (Prominent)
       ============================================= */
    .dm-section-hero {
        margin: 28px 0 18px 0;
        padding: 20px 24px;
        border-radius: 20px;
        border-left: 4px solid var(--dm-cyan);
        background: linear-gradient(
            90deg,
            rgba(103,232,249,0.08),
            rgba(103,232,249,0.02),
            transparent
        );
        backdrop-filter: blur(8px);
        transition: all 0.3s ease;
    }
    
    .dm-section-hero:hover {
        background: linear-gradient(
            90deg,
            rgba(103,232,249,0.12),
            rgba(103,232,249,0.04),
            transparent
        );
        border-left-color: var(--dm-violet);
    }
    
    .dm-section-hero .dm-section-title {
        margin: 0 0 4px 0;
        color: #ffffff;
        font-size: 1.5rem;
        font-weight: 850;
        letter-spacing: -0.04em;
        background: linear-gradient(90deg, #ffffff, rgba(255,255,255,0.85));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }
    
    .dm-section-hero .dm-section-copy {
        margin: 0;
        color: rgba(200,215,240,0.7);
        font-size: 0.92rem;
        line-height: 1.5;
        font-weight: 400;
    }

    /* =============================================
       LEVEL 3: SUB-SECTION HEADERS (Clean Text)
       ============================================= */
    .dm-section {
        margin: 22px 0 14px 0;
        padding: 6px 0;
        border: none;
        background: none;
        box-shadow: none;
        backdrop-filter: none;
        animation: fadeInUp 0.6s ease-out;
    }
    
    .dm-section .dm-section-title {
        margin: 0 0 2px 0;
        color: #e8eeff;
        font-size: 1.1rem;
        font-weight: 700;
        letter-spacing: -0.025em;
        display: flex;
        align-items: center;
        gap: 8px;
        opacity: 0.95;
    }
    
    .dm-section .dm-section-title .dm-icon {
        display: inline-block;
        font-size: 1.2rem;
        opacity: 0.8;
    }
    
    .dm-section .dm-section-copy {
        margin: 0;
        color: rgba(200,215,240,0.5);
        font-size: 0.85rem;
        line-height: 1.5;
        font-weight: 400;
        padding-left: 32px;
    }
    
    /* Optional subtle underline for visual interest */
    .dm-section .dm-underline {
        margin-top: 6px;
        width: 60px;
        height: 2px;
        background: linear-gradient(90deg, rgba(103,232,249,0.2), transparent);
        border-radius: 2px;
        transition: width 0.3s ease;
    }
    
    .dm-section:hover .dm-underline {
        width: 80px;
        background: linear-gradient(90deg, rgba(103,232,249,0.3), transparent);
    }
    
    /* =============================================
       LEVEL 4: CONTENT CARDS (Subtle, for data display)
       ============================================= */
    .dm-card {
        padding: 14px 18px;
        border-radius: 12px;
        border: 1px solid rgba(255,255,255,0.05);
        background: rgba(255,255,255,0.02);
        backdrop-filter: blur(8px);
        transition: all 0.2s ease;
        min-height: 70px;
    }
    
    .dm-card:hover {
        border-color: rgba(255,255,255,0.08);
        background: rgba(255,255,255,0.04);
        transform: translateY(-1px);
    }
    
    .dm-card-title {
        color: rgba(200,215,240,0.5);
        font-size: 0.7rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        margin-bottom: 4px;
    }
    
    .dm-card-value {
        color: #ffffff;
        font-size: 1.2rem;
        font-weight: 700;
        letter-spacing: -0.03em;
        line-height: 1.3;
    }
    
    .dm-card-description {
        color: rgba(200,215,240,0.35);
        font-size: 0.7rem;
        margin-top: 4px;
        font-weight: 400;
    }
    
    /* Different variants for different content types */
    .dm-card-status {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.7rem;
        font-weight: 600;
    }
    
    .dm-card-status.success {
        background: rgba(134,239,172,0.15);
        color: var(--dm-green);
    }
    
    .dm-card-status.warning {
        background: rgba(252,211,77,0.15);
        color: var(--dm-amber);
    }
    
    .dm-card-status.error {
        background: rgba(251,113,133,0.15);
        color: var(--dm-red);
    }
    
    .dm-card-status.info {
        background: rgba(103,232,249,0.15);
        color: var(--dm-cyan);
    }
    
    /* =============================================
       DIVIDER - Visual separation
       ============================================= */
    .dm-divider {
        margin: 32px 0 28px 0;
        height: 1px;
        background: linear-gradient(90deg, transparent, rgba(103,232,249,0.15), rgba(167,139,250,0.15), transparent);
        border: none;
        position: relative;
    }
    
    .dm-divider::after {
        content: "✦";
        position: absolute;
        left: 50%;
        top: 50%;
        transform: translate(-50%, -50%);
        color: rgba(103,232,249,0.2);
        font-size: 0.8rem;
        background: var(--dm-bg-mid);
        padding: 0 12px;
    }
    /* Remove default visual clutter */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {background: transparent !important;}

    /* Scrollbar styling */
    ::-webkit-scrollbar {
        width: 6px;
        height: 6px;
    }

    ::-webkit-scrollbar-track {
        background: rgba(255,255,255,0.05);
    }

    ::-webkit-scrollbar-thumb {
        background: rgba(103,232,249,0.3);
        border-radius: 10px;
        transition: all 0.3s ease;
    }

    ::-webkit-scrollbar-thumb:hover {
        background: rgba(103,232,249,0.5);
    }

    /* Loading spinner customization */
    .stSpinner > div {
        border-color: rgba(103,232,249,0.3) !important;
    }

    /* Toast notifications */
    .stToast {
        border-radius: 16px !important;
        backdrop-filter: blur(12px) !important;
        background: rgba(10,20,36,0.95) !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
    }

    @media (max-width: 900px) {
        .dm-title { font-size: 2.35rem; }
        .dm-hero { padding: 24px; }
        [data-testid="stMetric"] { min-height: 100px; }
        [data-testid="stMetricValue"] { font-size: 1.5rem; }
        .block-container { padding: 0.5rem; }
    }

    @media (max-width: 600px) {
        .dm-title { font-size: 1.8rem; }
        .dm-hero { padding: 18px; }
        .dm-pills { gap: 6px; }
        .dm-pill { font-size: 0.7rem; padding: 6px 10px; }
        [data-testid="stMetric"] { padding: 12px; min-height: 80px; }
        [data-testid="stMetricValue"] { font-size: 1.2rem; }
        button[data-baseweb="tab"] { padding: 8px 12px !important; font-size: 0.8rem; }
    }
    </style>
    """,
    unsafe_allow_html=True,
)


# =====================================================
# Premium application header
# =====================================================
st.markdown(
    """
    <div class="dm-hero">
        <div class="dm-eyebrow">🏭 Snowflake Manufacturing Intelligence</div>
        <h1 class="dm-title">Discrete Cost <span>Studio</span></h1>
        <p class="dm-subtitle">
            Analyze multi-level BOM costs, routing expenses, production drivers,
            field mappings, and what-if manufacturing scenarios from one refined workspace.
            Powered by real-time Snowflake data intelligence.
        </p>
        <div class="dm-pills">
            <div class="dm-pill">Model <strong>Discrete Manufacturing</strong></div>
            <div class="dm-pill">Engine <strong>Snowflake + Snowpark</strong></div>
            <div class="dm-pill">Cost Layers <strong>Material · Routing · Overhead</strong></div>
            <div class="dm-pill">Analysis <strong>What-If Simulation</strong></div>
            <div class="dm-pill">AI <strong>Scenario Generation</strong></div>
        </div>
    </div>
    """,
    unsafe_allow_html=True,
)

MAX_RUNTIME_MINUTES = 600


# =====================================================
# Enhanced helper functions with clear visual hierarchy
# =====================================================

def section_header(title: str, subtitle: str = "", icon: str = "📊") -> None:
    """
    LEVEL 2: Major section headers with left accent border
    Use this for main sections within tabs
    """
    st.markdown(
        f"""
        <div class="dm-section-hero">
            <div class="dm-section-title">{icon} {title}</div>
            <div class="dm-section-copy">{subtitle}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def premium_section(title: str, subtitle: str = "", icon: str = "✨") -> None:
    """
    LEVEL 3: Clean text-based section headers
    Use this for grouping related content with minimal styling
    """
    # Extract emoji from title if it starts with one
    title_parts = title.split(" ", 1)
    if len(title_parts) == 2 and title_parts[0] in ["📊", "📈", "💰", "📋", "🔍", "📦", "🏗️", "✅", "🎯", "💡", "📚", "✏️", "🔄", "📝", "🚦", "📂", "🏆", "🧠", "📄"]:
        # Title already has emoji, use it
        display_title = title
        icon_display = ""
    else:
        # Use the provided icon
        display_title = title
        icon_display = f'<span class="dm-icon">{icon}</span>'
    
    st.markdown(
        f"""
        <div class="dm-section">
            <div class="dm-section-title">
                {icon_display} {display_title}
            </div>
            <div class="dm-section-copy">{subtitle}</div>
            <div class="dm-underline"></div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def premium_divider() -> None:
    """Visual divider with decorative element for section separation"""
    st.markdown('<div class="dm-divider"></div>', unsafe_allow_html=True)


def content_card(value, label: str = "", description: str = "", status: str = None) -> None:
    """
    LEVEL 4: Individual content cards for data display
    
    Args:
        value: The main value to display (can be string, int, float, or formatted currency)
        label: Optional label above the value
        description: Optional description below the value
        status: Optional status indicator ('success', 'warning', 'error', 'info')
    """
    status_html = ""
    if status:
        status_html = f'<div class="dm-card-status {status}">{status.upper()}</div>'
    else:
        status_html = f'<br>'
    
    # Convert value to string and handle None
    if value is None:
        value_str = "N/A"
    else:
        value_str = str(value)
    
    st.markdown(
        f"""
        <div class="dm-card">
            {status_html}
            <div class="dm-card-title">{label}</div>
            <div class="dm-card-value">{value_str}</div>
            <div class="dm-card-description">{description}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


# =====================================================
# Utility functions for enhanced functionality
# =====================================================
def add_to_history(analysis_type: str, details: dict) -> None:
    """Add analysis to history with timestamp."""
    if "analysis_history" not in st.session_state:
        st.session_state.analysis_history = []
    
    entry = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "type": analysis_type,
        "details": details,
        "id": str(uuid.uuid4())[:8]
    }
    st.session_state.analysis_history.append(entry)
    # Keep last 50 entries
    if len(st.session_state.analysis_history) > 50:
        st.session_state.analysis_history = st.session_state.analysis_history[-50:]


def format_currency(value: float, currency: str = "USD") -> str:
    """Format value as currency with proper symbol."""
    symbols = {
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "JPY": "¥",
        "CAD": "C$",
        "AUD": "A$"
    }
    symbol = symbols.get(currency, "$")
    decimal_places = st.session_state.user_preferences.get("decimal_places", 2)
    return f"{symbol}{value:,.{decimal_places}f}"


def show_loading_animation(message: str = "Processing...") -> None:
    """Display a loading spinner with custom message."""
    with st.spinner(message):
        time.sleep(0.5)  # Simulate processing time


def display_metric_card(label: str, value: any, delta: float = None, help_text: str = "") -> None:
    """Helper to display consistent metric cards."""
    if delta is not None:
        st.metric(label=label, value=value, delta=delta, help=help_text)
    else:
        st.metric(label=label, value=value, help=help_text)


# =====================================================
# Existing field matching logic - unchanged
# =====================================================
FIELD_KEYWORDS = {

    "PARENT_ID": [
        "PARENT",
        "PRODUCT",
        "ASSEMBLY",
        "MATNR",
        "ITEM",
        "HEADER"
    ],

    "COMPONENT_ID": [
        "COMPONENT",
        "CHILD",
        "PART",
        "IDNRK",
        "MATERIAL"
    ],

    "QUANTITY": [
        "QTY",
        "QUANTITY",
        "MENGE",
        "QTY_PER",
        "REQUIRED"
    ]
}


# ================
# HELPER FUNCTIONS
# ================

def suggest_mapping(columns):
    mapping = {}

    for col in columns:

        col_upper = col.upper()

        if any(
            keyword in col_upper
            for keyword in [
                "PARENT",
                "PRODUCT",
                "ASSEMBLY",
                "MATNR",
                "HEADER"
            ]
        ):
            mapping["PARENT_ID"] = col

        elif any(
            keyword in col_upper
            for keyword in [
                "CHILD",
                "COMPONENT",
                "PART",
                "IDNRK",
                "MATERIAL"
            ]
        ):
            mapping["COMPONENT_ID"] = col

        elif any(
            keyword in col_upper
            for keyword in [
                "QTY",
                "QUANTITY",
                "MENGE",
                "REQUIRED"
            ]
        ):
            mapping["QUANTITY"] = col

    return mapping

def normalize(value, limit):
    return min((value / limit) * 100, 100)

# ==========================================
# AI ENGINE
# ==========================================

def calculate_css(features, dimensions):
    # =====================================
    # Historical Quality
    # =====================================
    
    quality_score = (
        features["historical_scrap_rate"] * 6
        +
        features["historical_defect_rate"] * 4
        +
        features["rework_ratio"] * 100 * 1.5
        +
        features["reject_ratio"] * 100 * 1.5
        +
        (100 - features["first_pass_yield"]) * 0.5
    )
    
    quality_score = min(quality_score,100)
    
    # =====================================
    # Configuration
    # =====================================
    
    configuration_score = (
        dimensions["bom_complexity"] * 0.40
        +
        dimensions["routing_stress"] * 0.25
        +
        dimensions["supplier_risk"] * 0.20
        +
        dimensions["material_risk"] * 0.15
    )
    
    configuration_score = min(configuration_score,100)
    
    # =====================================
    # Production
    # =====================================
    
    production_score = (
        features["production_scrap_ratio"] * 100 * 0.60
        +    
        (100 - features["production_yield"] * 100) * 0.40
    )
    
    production_score = min(production_score,100)
    
    # =====================================
    # Supplier
    # =====================================
    
    supplier_score = dimensions["supplier_risk"]
    
    # =====================================
    # Final CSS
    # =====================================
    
    css = (
        quality_score * 0.40
        +
        configuration_score * 0.30
        +
        production_score * 0.20
        +
        supplier_score * 0.10
    )
    
    # =====================================
    # Risk Penalties
    # =====================================
    
    if features["historical_scrap_rate"] > 5:
        css += 5
    
    if features["first_pass_yield"] < 90:
        css += 5
    
    if features["production_scrap_ratio"] > 0.05:
        css += 5
    
    css = round(min(css,100),1)
    
    return {
        "css": css,
        "quality_score": quality_score,
        "configuration_score": configuration_score,
        "production_score": production_score,
        "supplier_score": supplier_score
    }

def calculate_fmis(features, dimensions):
    # =====================================
    # Commodity Market Score
    # =====================================
    commodity_score = (
        max(features["weighted_price_change"], 0) * 4
        +
        features["weighted_price_volatility"] * 6
    )

    commodity_score = min(commodity_score, 100)

    # =====================================
    # Inventory Health Score
    # =====================================
    inventory_score = 0

    if features["stock_ratio"] < 1:
        inventory_score += 40

    elif features["stock_ratio"] < 1.2:
        inventory_score += 20

    if features["days_of_cover"] < 7:
        inventory_score += 30

    elif features["days_of_cover"] < 14:
        inventory_score += 15

    inventory_score += (features["low_stock_ratio"] * 30)

    inventory_score = min(inventory_score, 100)

    # =====================================
    # Supplier Reliability
    # =====================================
    supplier_score = dimensions["supplier_risk"]

    # =====================================
    # Material Dependency
    # =====================================
    dependency_score = (
        features["supplier_concentration"] * 40
        +
        features["single_source_ratio"] * 40
        +
        features["material_ratio"] * 20
    )

    dependency_score = min(dependency_score, 100)

    # =====================================
    # Final FMIS
    # =====================================
    fmis = (
        commodity_score * 0.40
        +
        inventory_score * 0.30
        +
        supplier_score * 0.20
        +
        dependency_score * 0.10
    )
    return round(min(fmis, 100), 1)

def calculate_tds(features, dimensions):
    # =====================================
    # Machine Health
    # =====================================
    machine_score = (
        (100 - features["machine_health"]) * 0.70
        +
        features["machine_utilization"] * 0.15
        +
        features["machine_temperature"] * 0.10
        +
        features["machine_vibration"] * 0.05
    )

    machine_score = min(machine_score, 100)

    # =====================================
    # Production Load
    # =====================================
    runtime_score = min(
        (features["weighted_runtime"] / MAX_RUNTIME_MINUTES) * 100,
        100
    )
    production_score = (
        runtime_score * 0.50
        +
        features["weighted_scrap_ratio"] * 100 * 0.30
        +
        (100 - features["weighted_yield"] * 100) * 0.20
    )

    production_score = min(production_score, 100)

    # =====================================
    # Routing Complexity
    # =====================================

    routing_score = dimensions["routing_stress"]

    # =====================================
    # Manufacturing Complexity
    # =====================================

    complexity_score = dimensions["bom_complexity"]

    # =====================================
    # Final TDS
    # =====================================

    tds = (
        machine_score * 0.50
        +
        production_score * 0.20
        +
        routing_score * 0.20
        +
        complexity_score * 0.10
    )

    # Extra penalties

    if features["machine_health"] < 70:
        tds += 5

    if features["machine_utilization"] > 90:
        tds += 5

    if features["breakdown_count"] > 3:
        tds += 5
        
    return {
        "tds": round(min(tds, 100), 1),
        "machine_score": machine_score,
        "production_score": production_score,
        "routing_score": routing_score,
        "complexity_score": complexity_score
    }

def calculate_bmcs(features, dimensions):

    # =====================================
    # Data Completeness
    # =====================================
    completeness_score = (
        features["supplier_coverage"] * 100 * 0.40
        +
        features["raw_material_ratio"] * 100 * 0.30
        +
        features["leaf_ratio"] * 100 * 0.30
    )

    completeness_score = min(completeness_score,100)


    # =====================================
    # BOM Integrity
    # =====================================
    integrity_score = (
        (100 - dimensions["bom_complexity"]) * 0.50
        +
        dimensions["manufacturing_simplicity"] * 0.50
    )

    integrity_score = min(integrity_score,100)

    # =====================================
    # Supplier Coverage
    # =====================================
    supplier_score = (
        features["supplier_coverage"] * 60
        +
        features["supplier_diversity"] * 40
    )
    supplier_score = min(supplier_score,100)

    # =====================================
    # Engineering Stability
    # =====================================
    engineering_score = features["engineering_stability"]

    # =====================================
    # Final BMCS
    # =====================================
    bmcs = (
        completeness_score * 0.25
        +
        integrity_score * 0.25
        +
        supplier_score * 0.15
        +
        engineering_score * 0.35
    )
    return round(min(bmcs,100),1)

# ==========================================
# AI COST OPTIMIZATION ENGINE
# ==========================================

def calculate_risk_adjusted_quote(material_cost, labor_cost, machine_cost,
                                  css, fmis, tds):

    # ----------------------------------
    # CSS → Scrap Buffer
    # ----------------------------------
    if css < 50:
        scrap_buffer = 0.015

    elif css < 75:
        scrap_buffer = 0.03
    
    else:
        scrap_buffer = 0.06

    # ----------------------------------
    # FMIS → Material Forecast
    # ----------------------------------
    # FMIS is centered at 50
    forecast_multiplier = max(
        1.0,
        1 + ((fmis - 50) / 500)
    )

    # ----------------------------------
    # TDS → Machine Depreciation
    # ----------------------------------
    if tds < 25:
        machine_multiplier = 1.00
    
    elif tds < 50:
        machine_multiplier = 1.10
    
    elif tds < 75:
        machine_multiplier = 1.25
    
    else:
        machine_multiplier = 1.50

    # ----------------------------------
    # Adjust Costs
    # ----------------------------------
    adjusted_material = (
        material_cost
        * (1 + scrap_buffer)
        * forecast_multiplier
    )

    adjusted_machine = (
        machine_cost
        * machine_multiplier
    )

    # ----------------------------------
    # Standard vs Recommended Quote
    # ----------------------------------
    standard_cost = (
        material_cost
        + labor_cost
        + machine_cost
    )
    standard_cost = round(standard_cost, 2)
    
    recommended_quote = (
        adjusted_material +
        labor_cost +
        adjusted_machine
    )
    recommended_quote = round(recommended_quote, 2)

    quote_increase = (
        recommended_quote
        - standard_cost
    )
    quote_increase = round(quote_increase, 2)
    
    material_adjustment = adjusted_material - material_cost
    material_adjustment = round(material_adjustment, 2)

    machine_adjustment = adjusted_machine - machine_cost
    machine_adjustment = round(machine_adjustment, 2)
    
    risk_adjustment = recommended_quote - standard_cost
    risk_adjustment = round(risk_adjustment, 2)

    return {
        "standard_cost": standard_cost,
        "recommended_quote": recommended_quote,
        "quote_increase": quote_increase,
        "risk_adjustment": quote_increase,
        "material_adjustment": material_adjustment,
        "machine_adjustment": machine_adjustment,
        "scrap_buffer": scrap_buffer,
        "forecast_multiplier": forecast_multiplier,
        "machine_multiplier": machine_multiplier,
        "adjusted_material": adjusted_material,
        "adjusted_machine": adjusted_machine
    }

def ai_decision_engine(css, fmis, tds, bmcs):

    decisions = {}

    # ----------------------------
    # Scrap
    # ----------------------------
    
    if css >= 75:
        decisions["scrap"] = {
            "buffer": 0.06,
            "risk": "Critical"
        }
    
    elif css >= 50:
        decisions["scrap"] = {
            "buffer": 0.03,
            "risk": "High"
        }
    
    elif css >= 25:
        decisions["scrap"] = {
            "buffer": 0.015,
            "risk": "Moderate"
        }
    
    else:
        decisions["scrap"] = {
            "buffer": 0.015,
            "risk": "Low"
        }

    # ----------------------------
    # Quote Confidence
    # ----------------------------
    
    if bmcs >= 80:
        decisions["quote"] = "Automatic Quote"
    
    elif bmcs >= 65:
        decisions["quote"] = "Engineering Review"
    
    else:
        decisions["quote"] = "Manual Review Required"

    # ----------------------------
    # Machine Health
    # ----------------------------
    
    if tds >= 75:
        decisions["machine"] = "Immediate Maintenance"
    
    elif tds >= 50:
        decisions["machine"] = "Maintenance Required"
    
    elif tds >= 25:
        decisions["machine"] = "Monitor Equipment"
    
    else:
        decisions["machine"] = "Healthy"

    # ----------------------------
    # Material Outlook
    # ----------------------------
    
    if fmis >= 75:
        decisions["material"] = "Critical Procurement"
    
    elif fmis >= 50:
        decisions["material"] = "Price Increase Expected"
    
    elif fmis >= 25:
        decisions["material"] = "Monitor Market"
    
    else:
        decisions["material"] = "Stable"

    # ----------------------------
    # Overall Decision
    # ----------------------------
    
    if decisions["quote"] == "Manual Review Required":
        decisions["overall"] = "Manual Review Required"
    
    elif (
        decisions["machine"] == "Immediate Maintenance"
        or decisions["material"] == "Critical Procurement"
        or decisions["scrap"]["risk"] == "Critical"
    ):
        decisions["overall"] = "Engineering Review Required"
    
    elif (
        decisions["machine"] == "Maintenance Required"
        or decisions["material"] == "Price Increase Expected"
        or decisions["scrap"]["risk"] == "High"
    ):
        decisions["overall"] = "Engineering Review Recommended"
    
    else:
        decisions["overall"] = "Approved for Quotation"
    return decisions

def generate_ai_explanation(features, dimensions, css, fmis, tds, bmcs):

    findings = []

    recommendations = []

    if css >= 75:
        findings.append(
            "Configuration has a high probability of manufacturing scrap."
        )
        recommendations.append(
            "Review product configuration and manufacturing process before production."
        )
    
    elif css >= 50:
        findings.append(
            "Moderate manufacturing scrap risk detected."
        )
        recommendations.append(
            "Monitor production quality during initial batches."
        )
    
    else:
        findings.append(
            "Manufacturing scrap risk is low."
        )

    if fmis >= 75:
        findings.append(
            "Commodity market conditions indicate significant material cost pressure."
        )
    
        recommendations.append(
            "Secure material contracts immediately."
        )
    
    elif fmis >= 50:
        findings.append(
            "Material prices are expected to increase."
        )
    
        recommendations.append(
            "Consider early procurement."
        )
    
    elif fmis >= 25:
        findings.append(
            "Commodity market should be monitored."
        )
    
    else:
        findings.append(
            "Material outlook is stable."
        )

    if tds >= 75:
        findings.append(
            "Critical tooling degradation detected."
        )
    
        recommendations.append(
            "Perform immediate preventive maintenance."
        )
    
    elif tds >= 50:
        findings.append(
            "Tool wear is increasing."
        )
    
        recommendations.append(
            "Schedule maintenance before the next production cycle."
        )
    
    elif tds >= 25:
        findings.append(
            "Equipment health should be monitored."
        )
    
    else:
        findings.append(
            "Machine health is within acceptable limits."
        )
    if bmcs >= 75:
        findings.append(
            "Engineering and BOM data have high confidence."
        )
    
    elif bmcs >= 50:
        findings.append(
            "Moderate confidence in engineering data."
        )
    
        recommendations.append(
            "Engineering validation is recommended before quotation."
        )
    
    else:
        findings.append(
            "Low confidence in engineering and BOM data."
        )
    
        recommendations.append(
            "Manual engineering review is required before generating the quotation."
        )

    return findings, recommendations


def recommend_best_scenario(scenario_df):

    if scenario_df.empty:
        return None

    ranked = scenario_df.copy()

    # Lower is better
    ranked["Quote Score"] = (
        ranked["Quote"] / ranked["Quote"].max()
    ) * 100

    ranked["CSS Score"] = ranked["CSS"]

    ranked["Supplier Score"] = ranked["Supplier Risk"]

    # Higher BMCS is better
    ranked["BMCS Score"] = 100 - ranked["BMCS"]

    # Final weighted score
    ranked["Overall Score"] = (

        ranked["Quote Score"] * 0.35

        +

        ranked["CSS Score"] * 0.25

        +

        ranked["Supplier Score"] * 0.20

        +

        ranked["BMCS Score"] * 0.20

    )
    ranked = ranked.round({
        "CSS": 1,
        "FMIS": 3,
        "TDS": 2,
        "BMCS": 1,
        "Quote": 2,
        "Overall Score": 2
    })
    
    return ranked.sort_values(
        "Overall Score"
    )

def generate_executive_report(
    product_name,
    ai_cost,
    css,
    fmis,
    tds,
    bmcs,
    findings,
    recommendations,
    ranked_df
):

    report = []

    from datetime import datetime

    report.append("=" * 70)
    report.append("AI MANUFACTURING COST OPTIMIZATION REPORT")
    report.append("=" * 70)
    report.append("Generated by : Snowflake Cortex Manufacturing Intelligence")
    report.append(
        f"Generated On : {datetime.now().strftime('%d-%b-%Y %I:%M %p')}"
    )
    report.append("")

    report.append(f"Product : {product_name}")
    report.append("")

    decision = (
        "Automatic Quote Generation"
        if bmcs >= 70
        else "Engineering Review Required"
    )
    
    report.append("EXECUTIVE SUMMARY")
    report.append("-" * 25)
    
    report.append(
        f"The AI analyzed the manufacturing configuration for "
        f"{product_name} and recommends a customer quote of "
        f"${ai_cost['recommended_quote']:.2f} "
        f"(+{(ai_cost['quote_increase']/ai_cost['standard_cost'])*100:.2f}%) "
        f"after evaluating manufacturing complexity, supplier dependency, "
        f"material outlook and tooling degradation."
    )
    
    report.append("")
    
    report.append(
        f"{len(ranked_df)} planning scenario(s) were evaluated."
    )
    
    if not ranked_df.empty:
        report.append(
            f"'{ranked_df.iloc[0]['Scenario']}' was identified as the optimal manufacturing plan."
        )
    
    report.append("")
    
    report.append(f"Decision Status : {decision}")
    
    report.append("")
    
    report.append("COST SUMMARY")
    report.append("-" * 20)
    report.append(
        f"Standard Manufacturing Cost : ${ai_cost['standard_cost']:.2f}"
    )
    report.append(
        f"Recommended Customer Quote  : ${ai_cost['recommended_quote']:.2f}"
    )
    report.append(
        f"Quote Increase : ${ai_cost['quote_increase']:.2f}"
    )
    
    report.append(
        f"Risk Adjustment : "
        f"{(ai_cost['quote_increase']/ai_cost['standard_cost'])*100:.2f}%"
    )
    report.append("")

    report.append("AI SCORES")
    report.append("-" * 20)
    css_status = (
        "Low"
        if css < 25
        else
        "Moderate"
        if css < 50
        else
        "High"
        if css < 75
        else
        "Critical"
    )
    
    fmis_status = (
        "Stable"
        if fmis < 25
        else
        "Watch"
        if fmis < 50
        else
        "Rising"
        if fmis < 75
        else
        "Critical"
    )
    
    tds_status = (
        "Low"
        if tds < 25
        else
        "Moderate"
        if tds < 50
        else
        "High"
        if tds < 75
        else
        "Critical"
    )
    
    bmcs_status = (
        "Low"
        if bmcs < 50
        else
        "Moderate"
        if bmcs < 75
        else
        "High"
    )
    
    report.append(
        f"Configuration Scrap Score : {css:.1f}% ({css_status})"
    )
    
    report.append(
        f"Forward Material Index : {fmis:.1f}% ({fmis_status})"
    )
    
    report.append(
        f"Tooling Degradation : {tds:.1f}% ({tds_status})"
    )
    
    report.append(
        f"BOM Match Confidence : {bmcs:.1f}% ({bmcs_status})"
    )
    report.append("")

    report.append("")

    report.append("MANUFACTURING RISK SUMMARY")
    report.append("-" * 25)
    
    overall_risk = "Low"
    
    if css >= 70 or tds >= 70:
        overall_risk = "High"
    
    elif css >= 40 or tds >= 40:
        overall_risk = "Medium"
    
    highest_driver = max(
        {
            "Configuration Scrap": css,
            "Material Outlook": fmis,
            "Tooling Stress": tds,
            "BOM Confidence Gap": 100 - bmcs
        },
        key=lambda x: {
            "Configuration Scrap": css,
            "Material Outlook": fmis,
            "Tooling Stress": tds,
            "BOM Confidence Gap": 100 - bmcs
        }[x]
    )
    
    report.append(f"Overall Manufacturing Risk : {overall_risk}")
    
    report.append(f"Highest Risk Driver        : {highest_driver}")
    
    report.append(
        f"Supplier Risk              : {css_status}"
    )
    
    report.append("")

    report.append("KEY FINDINGS")
    report.append("-" * 20)

    for item in findings:
        report.append(f"• {item}")

    report.append("")

    report.append("RECOMMENDED ACTIONS")
    report.append("-" * 20)

    for item in recommendations:
        report.append(f"• {item}")

    report.append("")

    if not ranked_df.empty:
        
        report.append("")
        report.append("SCENARIO COMPARISON")
        report.append("-" * 60)
        
        report.append(
            f"{'Rank':<6}"
            f"{'Scenario':<18}"
            f"{'Quote':<12}"
            f"{'CSS':<10}"
            f"{'BMCS':<10}"
            f"{'Score'}"
        )
        
        report.append("-" * 70)
        
        for rank, (_, row) in enumerate(ranked_df.iterrows(), start=1):
            report.append(
                f"{rank:<6}"
                f"{row['Scenario']:<18}"
                f"${row['Quote']:<11.2f}"
                f"{row['CSS']:<10.1f}"
                f"{row['BMCS']:<10.1f}"
                f"{row['Overall Score']:.2f}"
            )
        
        report.append("")
        best = ranked_df.iloc[0]

        report.append("BEST SCENARIO")
        report.append("-" * 20)
        report.append(
            f"Selected Scenario : {best['Scenario']}"
        )
        
        report.append(
            f"Recommended Quote : ${best['Quote']:.2f}"
        )
        
        report.append(
            f"Overall Score : {best['Overall Score']:.2f}"
        )
        
        report.append("")
        
        report.append("")
        report.append("BUSINESS JUSTIFICATION")
        report.append("-" * 25)
        
        if best["Quote"] == ranked_df["Quote"].min():
            report.append("• Lowest recommended customer quote.")
        
        if best["CSS"] == ranked_df["CSS"].min():
            report.append("• Lowest manufacturing scrap risk.")
        
        if best["Supplier Risk"] == ranked_df["Supplier Risk"].min():
            report.append("• Lowest supplier dependency.")
        
        if best["BMCS"] == ranked_df["BMCS"].max():
            report.append("• Highest BOM mapping confidence.")
        
        report.append("")
        
        report.append(
            "Overall, this scenario provides the best balance between "
            "manufacturing cost, operational risk and quoting confidence."
        )
        
        report.append("")
        report.append("=" * 70)
        
        report.append("FINAL AI DECISION")
        
        report.append("-" * 25)
        
        report.append(f"Quote Generation     : {decision}")
        
        if bmcs >= 70:
        
            report.append(
                "Engineering Approval : Not Required"
            )
        
            report.append(
                "Business Recommendation : Proceed with automated customer quotation."
            )
        
        else:
        
            report.append(
                "Engineering Approval : Required"
            )
        
            report.append(
                "Reason : BOM Match Confidence is below the automatic quotation threshold."
            )
        
            report.append(
                "Business Recommendation : Complete engineering validation before releasing the customer quotation."
            )
        
        report.append("=" * 70)

    return "\n".join(report)

# =====================================================
# Product Selection
# =====================================================

products = session.sql("""
SELECT DISTINCT PARENT_ID
FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
ORDER BY PARENT_ID
""").to_pandas()

col1, col2 = st.columns([4,1])

with col1:
    product_list = products["PARENT_ID"].tolist()
    
    if "selected_product" not in st.session_state:
        st.session_state.selected_product = product_list[0]
        
    selected = st.selectbox(
        "Select Product",
        product_list,
        index=product_list.index(st.session_state.selected_product),
        key="product_selector"
    )
    
    st.session_state.selected_product = selected

    revision_df = session.sql(f"""
    SELECT DISTINCT REVISION
    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
    WHERE PARENT_ID = '{selected}'
    ORDER BY REVISION
    """).to_pandas()

    revision_list = revision_df["REVISION"].tolist()

    if "selected_revision" not in st.session_state:
        st.session_state.selected_revision = revision_list[0]
    
    if st.session_state.selected_revision not in revision_list:
        st.session_state.selected_revision = revision_list[0]
    
    revision = st.selectbox(
        "Revision",
        revision_list,
        index=revision_list.index(
            st.session_state.selected_revision
        ),
        key="revision_selector"
    )
    
    st.session_state.selected_revision = revision

    revision_list = revision_df["REVISION"].tolist()

    previous_revision = None
    
    if revision in revision_list:
    
        current_idx = revision_list.index(revision)
    
        if current_idx > 0:
    
            previous_revision = revision_list[current_idx - 1]

with col2:
    st.write("")
    st.write("")

if "show_details" not in st.session_state:
    st.session_state.show_details = False

if st.button("View Cost Details"):
    st.session_state.show_details = True
    st.session_state.selected_product = selected

    run_id = str(uuid.uuid4())

    session.sql(f"""
    INSERT INTO
    DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_RUN_HISTORY
    (
    RUN_ID,
    ITEM_ID,
    REVISION,
    MATERIAL_COST,
    LABOR_COST,
    MACHINE_COST,
    TOTAL_COST,
    RUN_TIMESTAMP,
    RUN_BY
    )
    
    SELECT
    
    '{run_id}',
    TOP_LEVEL_ITEM,
    REVISION,
    TOTAL_MATERIAL_COST,
    LABOR_COST,
    MACHINE_COST,
    TOTAL_COST,
    CURRENT_TIMESTAMP,
    CURRENT_USER()
    
    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TOTAL_PRODUCT_COSTS
    
    WHERE TOP_LEVEL_ITEM='{selected}'
    AND REVISION='{revision}'
    """).collect()

if st.session_state.show_details:
    # =====================================================
    # Data Loading (Common to all tabs)
    # =====================================================
    summary_query = f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TOTAL_PRODUCT_COSTS
    WHERE TOP_LEVEL_ITEM = '{selected}'
    AND REVISION = '{revision}'
    """
    
    summary_df = session.sql(summary_query).to_pandas()
    
    if summary_df.empty:
        st.warning("No data found")
        st.stop()
    
    row = summary_df.iloc[0]
    
    material_cost = float(row["TOTAL_MATERIAL_COST"])
    labor_cost = float(row["LABOR_COST"])
    machine_cost = float(row["MACHINE_COST"])
    total_cost = float(row["TOTAL_COST"])
    previous_total_cost = None

    if previous_revision:
    
        prev_df = session.sql(f"""
        SELECT TOTAL_COST
    
        FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.TOTAL_PRODUCT_COSTS
    
        WHERE TOP_LEVEL_ITEM = '{selected}'
        AND REVISION = '{previous_revision}'
        """).to_pandas()
    
        if not prev_df.empty:
    
            previous_total_cost = float(
                prev_df.iloc[0]["TOTAL_COST"]
            )
    
    # Load material breakdown data
    material_query = f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_BREAKDOWN
    WHERE TOP_LEVEL_ITEM = '{selected}'
      AND REVISION = '{revision}'
    ORDER BY EXTENDED_COST DESC
    """
    
    material_df = session.sql(material_query).to_pandas()
    
    # Load routing operations data
    routing_query = f"""
        SELECT
            ITEM_ID,
            OPERATION_ID,
            WORK_CENTER,
            SETUP_HOURS,
            RUN_HOURS,
            LABOR_RATE,
            MACHINE_RATE,
        
            (SETUP_HOURS + RUN_HOURS) * LABOR_RATE
                AS LABOR_COST,
        
            (SETUP_HOURS + RUN_HOURS) * MACHINE_RATE
                AS MACHINE_COST,
        
            (
                ((SETUP_HOURS + RUN_HOURS) * LABOR_RATE)
                +
                ((SETUP_HOURS + RUN_HOURS) * MACHINE_RATE)
            ) AS TOTAL_OPERATION_COST
        
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ROUTING_OPERATIONS
        
        WHERE ITEM_ID = '{selected}'
        AND REVISION = '{revision}'
        """
    
    routing_df = session.sql(routing_query).to_pandas()
    bom_df = session.sql(f"""
    SELECT
        b.PARENT_ID,
        b.COMPONENT_ID,
        b.QUANTITY,
        b.REVISION,
        b.PLANT_ID,
        i.ITEM_TYPE
    
    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE b
    
    LEFT JOIN
    DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER i
    
    ON b.COMPONENT_ID = i.ITEM_ID
    
    WHERE b.REVISION = '{revision}'
    
    AND CURRENT_DATE BETWEEN
          b.EFFECTIVE_FROM
      AND COALESCE(b.EFFECTIVE_TO,'9999-12-31')
    """).to_pandas()

    decision_query = f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.AI_DECISION_ENGINE_V
    WHERE TOP_LEVEL_ITEM = '{selected}'
    AND REVISION = '{revision}'
    ORDER BY RFQ_ID
    """
    
    decision_df = session.sql(decision_query).to_pandas()

    quality_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.QUALITY_FEATURES_V
    WHERE ITEM_ID='{selected}'
    """).to_pandas()
    
    production_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCTION_FEATURES_V
    WHERE ITEM_ID='{selected}'
    """).to_pandas()
    
    supplier_perf_df = session.sql("""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.SUPPLIER_FEATURES_V
    """).to_pandas()
    
    routing_feature_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ROUTING_FEATURES_V
    WHERE ITEM_ID='{selected}'
    """).to_pandas()

    commodity_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_COMMODITY_FEATURES_V
    WHERE TOP_LEVEL_ITEM='{selected}'
    """).to_pandas()
    
    inventory_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_INVENTORY_FEATURES_V
    WHERE TOP_LEVEL_ITEM='{selected}'
    """).to_pandas()

    machine_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_MACHINE_FEATURES_V
    WHERE TOP_LEVEL_ITEM='{selected}'
    """).to_pandas()
    
    production_product_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.PRODUCT_PRODUCTION_FEATURES_V
    WHERE TOP_LEVEL_ITEM='{selected}'
    """).to_pandas()

    engineering_df = session.sql(f"""
    SELECT *
    FROM DISCRETE_MFG_COST_MODEL.CORE_FEATURES.ENGINEERING_FEATURES_V
    WHERE ITEM_ID='{selected}'
    """).to_pandas()

    # ==========================================
    # Reusable DataFrames
    # ==========================================
    
    component_costs = (
        material_df["EXTENDED_COST"]
        .fillna(0)
    )
    
    supplier_df = material_df.copy()
    
    routing_summary = routing_df.copy()

    
    ##############################################
    # FEATURE ENGINEERING STARTS HERE
    ##############################################
    
    features = {}

    # =====================================
    # Manufacturing History Features
    # =====================================
    
    if not quality_df.empty:
        q = quality_df.iloc[0]
    
        features["historical_scrap_rate"] = float(q["AVG_SCRAP_RATE"])
        features["historical_defect_rate"] = float(q["AVG_DEFECT_RATE"])
        features["first_pass_yield"] = float(q["AVG_FIRST_PASS_YIELD"])
        features["rework_ratio"] = float(q["REWORK_RATIO"])
        features["reject_ratio"] = float(q["REJECT_RATIO"])
    
    else:
        features["historical_scrap_rate"] = 0
        features["historical_defect_rate"] = 0
        features["first_pass_yield"] = 100
        features["rework_ratio"] = 0
        features["reject_ratio"] = 0

    if not production_df.empty:
        p = production_df.iloc[0]
    
        features["production_scrap_ratio"] = float(p["SCRAP_RATIO"])
        features["production_yield"] = float(p["YIELD_RATIO"])
        features["avg_runtime"] = float(p["AVG_RUNTIME"])
    
    else:
        features["production_scrap_ratio"] = 0
        features["production_yield"] = 100
        features["avg_runtime"] = 0

    if not routing_feature_df.empty:
        r = routing_feature_df.iloc[0]
    
        features["process_time"] = float(r["TOTAL_PROCESS_TIME"])
        features["operation_count"] = float(r["TOTAL_OPERATIONS"])
    
    else:
        features["process_time"] = 0
        features["operation_count"] = 0

    if not commodity_df.empty:
        commodity = commodity_df.iloc[0]

        features["commodity_count"] = int(commodity["COMMODITY_COUNT"])
        features["weighted_avg_price"] = float(commodity["WEIGHTED_AVG_PRICE"])
        features["weighted_price_volatility"] = float(commodity["WEIGHTED_PRICE_VOLATILITY"])
        features["weighted_price_change"] = float(commodity["WEIGHTED_PRICE_CHANGE"])
        features["max_price_change"] = float(commodity["MAX_PRICE_CHANGE"])
        features["max_price_volatility"] = float(commodity["MAX_PRICE_VOLATILITY"])

    else:
        features["commodity_count"] = 0
        features["weighted_avg_price"] = 0
        features["weighted_price_volatility"] = 0
        features["weighted_price_change"] = 0
        features["max_price_change"] = 0
        features["max_price_volatility"] = 0

    if not inventory_df.empty:
        inv = inventory_df.iloc[0]
        features["weighted_stock"] = float(inv["WEIGHTED_STOCK"])
        features["weighted_safety_stock"] = float(inv["WEIGHTED_SAFETY_STOCK"])
        features["days_of_cover"] = float(inv["WEIGHTED_DAYS_OF_COVER"])
        features["stock_ratio"] = float(inv["WEIGHTED_STOCK_RATIO"])
        features["low_stock_ratio"] = float(inv["LOW_STOCK_RATIO"])
            
    else:
        features["weighted_stock"] = 0
        features["weighted_safety_stock"] = 0
        features["days_of_cover"] = 0
        features["stock_ratio"] = 1
        features["low_stock_ratio"] = 0

    # =====================================
    # Machine Health Features
    # =====================================
    
    if not machine_df.empty:
        m = machine_df.iloc[0]
        features["machine_health"] = float(m["AVG_MACHINE_HEALTH"])
        features["machine_utilization"] = float(m["AVG_UTILIZATION"])
        features["machine_temperature"] = float(m["AVG_TEMPERATURE"])
        features["machine_vibration"] = float(m["AVG_VIBRATION"])
        features["breakdown_count"] = float(m["AVG_BREAKDOWNS"])
    
    else:
        features["machine_health"] = 100
        features["machine_utilization"] = 0
        features["machine_temperature"] = 25
        features["machine_vibration"] = 0
        features["breakdown_count"] = 0

    # =====================================
    # Product Production Features
    # =====================================
    
    if not production_product_df.empty:
        p = production_product_df.iloc[0]
        features["weighted_runtime"] = float(p["WEIGHTED_RUNTIME"])
        features["weighted_scrap_ratio"] = float(p["WEIGHTED_SCRAP_RATIO"])
        features["weighted_yield"] = float(p["WEIGHTED_YIELD"])
        features["production_runs"] = float(p["TOTAL_RUNS"])
    
    else:
        features["weighted_runtime"] = 0
        features["weighted_scrap_ratio"] = 0
        features["weighted_yield"] = 1
        features["production_runs"] = 0

    # =====================================
    # Engineering Features
    # =====================================
    
    if not engineering_df.empty:
        e = engineering_df.iloc[0]
        features["engineering_changes"] = int(e["CHANGE_COUNT"])
        features["affected_components"] = float(e["AVG_AFFECTED_COMPONENTS"])
        features["days_since_change"] = float(e["DAYS_SINCE_LAST_CHANGE"])
        features["engineering_stability"] = float(e["ENGINEERING_STABILITY"])
    
    else:
        features["engineering_changes"] = 0
        features["affected_components"] = 0
        features["days_since_change"] = 365
        features["engineering_stability"] = 100

        
    # ------------------------------
    # BOM Features
    # ------------------------------
    
    features["component_count"] = (
        bom_df["COMPONENT_ID"]
        .nunique()
    )
    
    features["assembly_count"] = (
        bom_df["PARENT_ID"]
        .nunique()
    )
    
    features["bom_relationships"] = len(bom_df)
    
    features["avg_quantity"] = (
        bom_df["QUANTITY"]
        .mean()
    )
    
    features["max_quantity"] = (
        bom_df["QUANTITY"]
        .max()
    )
    
    features["min_quantity"] = (
        bom_df["QUANTITY"]
        .min()
    )

    # ------------------------------
    # Cost Features
    # ------------------------------
    
    features["material_cost"] = material_cost
    features["labor_cost"] = labor_cost
    features["machine_cost"] = machine_cost
    features["total_cost"] = total_cost
    
    if total_cost > 0:
        features["material_ratio"] = material_cost / total_cost
    
        features["labor_ratio"] = labor_cost / total_cost
    
        features["machine_ratio"] = machine_cost / total_cost
    
    else:
        features["material_ratio"] = 0
    
        features["labor_ratio"] = 0
    
        features["machine_ratio"] = 0

    # Component Cost Statistics
    if not material_df.empty:
        component_costs = (
            material_df["EXTENDED_COST"]
            .fillna(0)
        )
    
        features["avg_component_cost"] = (
            component_costs.mean()
        )
    
        features["max_component_cost"] = (
            component_costs.max()
        )
    
        features["min_component_cost"] = (
            component_costs.min()
        )
    
        features["component_cost_std"] = (
            component_costs.std()
        )
    
    else:
        features["avg_component_cost"] = 0
    
        features["max_component_cost"] = 0
    
        features["min_component_cost"] = 0
    
        features["component_cost_std"] = 0

    # Largest Cost Driver
    if not material_df.empty:
        largest_cost = (
            material_df["EXTENDED_COST"]
            .fillna(0)
            .max()
        )
    
        if total_cost > 0:
            features["largest_component_ratio"] = (
                largest_cost / total_cost
            )
    
        else:
            features["largest_component_ratio"] = 0
    
    else:
        features["largest_component_ratio"] = 0


    # ------------------------------
    # Supplier Features
    # ------------------------------
    
    features["supplier_count"] = (
        supplier_df["PREFERRED_SUPPLIER"]
        .fillna("")
        .replace("", pd.NA)
        .dropna()
        .nunique()
    )
    
    features["supplier_coverage"] = (
        supplier_df["PREFERRED_SUPPLIER"]
        .notna()
        .mean()
    )

    supplier_spend = (
        supplier_df
        .groupby("PREFERRED_SUPPLIER")["EXTENDED_COST"]
        .sum()
    )
    
    if supplier_spend.sum() > 0:
        features["supplier_concentration"] = (
            supplier_spend.max()
            /
            supplier_spend.sum()
        )
    
    else:
        features["supplier_concentration"] = 0

    component_supplier = (
        supplier_df
        .groupby("COMPONENT_ID")["PREFERRED_SUPPLIER"]
        .nunique()
    )
    
    if len(component_supplier):
        features["single_source_ratio"] = (
            (component_supplier == 1).sum()
            /
            len(component_supplier)
        )
    
    else:
        features["single_source_ratio"] = 0

    if features["component_count"] > 0:
        features["supplier_diversity"] = (
    
            features["supplier_count"]
    
            /
    
            features["component_count"]
    
        )
    
    else:
        features["supplier_diversity"] = 0

    # ------------------------------
    # Routing Features
    # ------------------------------
    
    features["routing_operations"] = len(routing_df)
    
    features["total_setup_hours"] = (
        routing_df["SETUP_HOURS"]
        .sum()
    )
    
    features["total_run_hours"] = (
        routing_df["RUN_HOURS"]
        .sum()
    )

    if len(routing_df):
        features["avg_setup_hours"] = (
            routing_df["SETUP_HOURS"]
            .mean()
        )
    
        features["avg_run_hours"] = (
            routing_df["RUN_HOURS"]
            .mean()
        )
    
    else:
        features["avg_setup_hours"] = 0
        features["avg_run_hours"] = 0


    features["total_labor_rate"] = (
        routing_df["LABOR_RATE"]
        .sum()
    )
    
    features["total_machine_rate"] = (
        routing_df["MACHINE_RATE"]
        .sum()
    )

    if len(routing_df):
        features["avg_labor_rate"] = (
            routing_df["LABOR_RATE"]
            .mean()
        )
    
        features["avg_machine_rate"] = (
            routing_df["MACHINE_RATE"]
            .mean()
        )
    
    else:
        features["avg_labor_rate"] = 0
        features["avg_machine_rate"] = 0

    if features["assembly_count"] > 0:
        features["routing_complexity"] = (
    
            features["routing_operations"]
    
            /
    
            features["assembly_count"]
    
        )
    
    else:
        features["routing_complexity"] = 0

    # ------------------------------
    # BOM Topology Features
    # ------------------------------
    
    if features["component_count"] > 0:
        features["assembly_density"] = (
    
            features["assembly_count"]
    
            /
    
            features["component_count"]
    
        )
    
    else:
        features["assembly_density"] = 0

    raw_materials = len(
        set(bom_df["COMPONENT_ID"])
        -
        set(bom_df["PARENT_ID"])
    )
    
    features["raw_material_count"] = raw_materials
    
    if features["component_count"] > 0:
        features["raw_material_ratio"] = (
    
            raw_materials
    
            /
    
            features["component_count"]
    
        )
    
    else:
        features["raw_material_ratio"] = 0

    component_usage = (
        bom_df["COMPONENT_ID"]
        .value_counts()
    )
    
    reused_components = (
        component_usage > 1
    ).sum()
    
    features["reused_components"] = int(reused_components)
    
    if features["component_count"] > 0:
        features["component_reuse_ratio"] = (
    
            reused_components
    
            /
    
            features["component_count"]
    
        )
    
    else:
        features["component_reuse_ratio"] = 0

    children_per_parent = (
        bom_df
        .groupby("PARENT_ID")
        .size()
    )
    
    features["avg_branch_factor"] = (
        children_per_parent.mean()
    )
    
    features["max_branch_factor"] = int(children_per_parent.max())

    parents = set(
        bom_df["PARENT_ID"]
    )
    
    leaf_nodes = (
        bom_df["COMPONENT_ID"]
        .apply(lambda x: x not in parents)
        .sum()
    )
    
    features["leaf_nodes"] = int(leaf_nodes)
    
    if features["component_count"] > 0:
        features["leaf_ratio"] = (
    
            leaf_nodes
    
            /
    
            features["component_count"]
    
        )
    
    else:
        features["leaf_ratio"] = 0

    # st.write(features)

    # ==========================================
    # Dynamic Feature Normalization
    # ==========================================
    normalized = {}
    
    normalized["component_score"] = normalize(
        features["component_count"], 50
    )
    
    normalized["assembly_score"] = normalize(
        features["assembly_count"], 15
    )
    
    normalized["branch_score"] = normalize(
        features["avg_branch_factor"], 8
    )
    
    normalized["assembly_density_score"] = normalize(
        features["assembly_density"], 1
    )

    # ==========================================
    # Manufacturing Dimensions
    # ==========================================
    
    dimensions = {}
    
    # ------------------------------
    # BOM Complexity
    # ------------------------------
    
    dimensions["bom_complexity"] = (
        normalized["component_score"] * 0.35
        +
        normalized["assembly_score"] * 0.25
        +
        normalized["branch_score"] * 0.25
        +
        normalized["assembly_density_score"] * 0.15
    )
    
    # ------------------------------
    # Supplier Risk
    # ------------------------------
    
    dimensions["supplier_risk"] = min(
    
        100,
    
        (
            features["supplier_concentration"] * 40
            +
            features["single_source_ratio"] * 35
            +
            (1 - features["supplier_diversity"]) * 25
        )
    
    )
    
    # ------------------------------
    # Routing Stress
    # ------------------------------
    
    dimensions["routing_stress"] = min(
    
        100,
    
        (
            features["routing_complexity"] * 30
            +
            features["avg_setup_hours"] * 12
            +
            features["avg_run_hours"] * 12
        )
    
    )
    
    # ------------------------------
    # Material Risk
    # ------------------------------
    
    dimensions["material_risk"] = min(
    
        100,
    
        (
            features["largest_component_ratio"] * 50
            +
            features["material_ratio"] * 50
        )
    
    )

    # ------------------------------
    # Cost Efficiency
    # ------------------------------

    dimensions["cost_efficiency"] = max(
        0,
        100
        -
        (
            features["material_ratio"] * 50
            +
            features["labor_ratio"] * 30
            +
            features["machine_ratio"] * 20
        )
    )

    # ------------------------------
    # Supplier Health
    # ------------------------------

    dimensions["supplier_health"] = (

        features["supplier_coverage"] * 40
    
        +
    
        features["supplier_diversity"] * 30
    
        +
    
        (1 - features["supplier_concentration"]) * 30
    
    )

    # ------------------------------
    # Manufacturing Simplicity
    # ------------------------------

    dimensions["manufacturing_simplicity"] = max(
        0,
        100
        -
        (
            dimensions["bom_complexity"] * 0.5
            +
            dimensions["routing_stress"] * 0.5
        )
    )

    # ------------------------------
    # Procurement Health
    # ------------------------------

    dimensions["procurement_health"] = (

        (1 - features["single_source_ratio"]) * 50
    
        +
    
        features["supplier_coverage"] * 50
    
    )

    # st.write(dimensions)
    
    ##############################################
    # FEATURE ENGINEERING ENDS HERE
    ##############################################

    tree = {}
    for _, row in bom_df.iterrows():
    
        parent = row["PARENT_ID"]
    
        tree.setdefault(parent, []).append({
            "component":
                row["COMPONENT_ID"],
        
            "qty":
                row["QUANTITY"],
        
            "item_type":
                row["ITEM_TYPE"]
        })


    def render_tree(node, tree):
        children = tree.get(node, [])
    
        for child in children:
    
            component = child["component"]
            qty = child["qty"]
            item_type = child["item_type"]
    
            grandchildren = tree.get(component, [])
    
            if grandchildren:
    
                with st.expander(
                    f"{component} [{item_type}] (Qty: {qty})",
                    expanded=False
                ):
                    render_tree(component, tree)
    
            else:
    
                st.write(
                    f"└── {component} [{item_type}] (Qty: {qty})"
                )

    # =====================================================
    # Premium Tabs with Sliding Pill Animation
    # =====================================================
    
    st.markdown(
        """
        <style>
        /* =============================================
           SINGLE PILL TAB CONTAINER
           ============================================= */
        
        /* Hide default Streamlit tab elements */
        .stTabs [data-baseweb="tab-highlight"] {
            display: none !important;
        }
        
        /* The main pill container - ONE big pill */
        .stTabs [data-baseweb="tab-list"] {
            background: rgba(255, 255, 255, 0.06);
            border-radius: 50px !important;
            padding: 6px !important;
            gap: 2px !important;
            border: 1px solid rgba(255, 255, 255, 0.08);
            backdrop-filter: blur(20px);
            box-shadow: 0 4px 30px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.05);
            min-height: 52px;
            display: flex;
            align-items: center;
            flex-wrap: nowrap;
            overflow: hidden;
            position: relative;
            width: 100%;
        }
        
        /* Individual tab buttons - NO BACKGROUND */
        .stTabs [data-baseweb="tab"] {
            padding: 8px 24px !important;
            border-radius: 40px !important;
            border: none !important;
            background: transparent !important;
            color: rgba(200, 215, 240, 0.45) !important;
            font-weight: 600 !important;
            font-size: 0.85rem !important;
            letter-spacing: 0.02em !important;
            transition: color 0.3s ease !important;
            position: relative !important;
            z-index: 2 !important;
            white-space: nowrap !important;
            height: auto !important;
            min-height: 38px !important;
            margin: 0 !important;
            font-family: 'Inter', ui-sans-serif, system-ui, sans-serif !important;
            cursor: pointer !important;
            flex: 0 0 auto !important;
            text-align: center;
        }
        
        /* Tab hover - subtle text change only */
        .stTabs [data-baseweb="tab"]:hover {
            color: rgba(255, 255, 255, 0.75) !important;
            background: transparent !important;
        }
        
        /* Active tab text - bright white */
        .stTabs [data-baseweb="tab"][aria-selected="true"] {
            color: #ffffff !important;
            background: transparent !important;
        }
        
        /* =============================================
           THE SLIDING GLOW PILL
           ============================================= */
        
        /* The glowing pill that slides */
        .stTabs [data-baseweb="tab"]::before {
            content: '';
            position: absolute;
            inset: 0;
            border-radius: 40px;
            background: linear-gradient(135deg, rgba(103, 232, 249, 0.25), rgba(167, 139, 250, 0.25));
            opacity: 0;
            transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: -1;
            border: 1px solid rgba(103, 232, 249, 0.2);
            box-shadow: 
                0 4px 25px rgba(103, 232, 249, 0.15),
                0 0 60px rgba(103, 232, 249, 0.05),
                inset 0 1px 0 rgba(255, 255, 255, 0.08);
            transform: scale(0.92);
        }
        
        /* Active tab shows the glowing pill */
        .stTabs [data-baseweb="tab"][aria-selected="true"]::before {
            opacity: 1;
            transform: scale(1);
            background: linear-gradient(135deg, rgba(103, 232, 249, 0.25), rgba(167, 139, 250, 0.25));
            border-color: rgba(103, 232, 249, 0.35);
            box-shadow: 
                0 4px 30px rgba(103, 232, 249, 0.2),
                0 0 80px rgba(103, 232, 249, 0.08),
                inset 0 1px 0 rgba(255, 255, 255, 0.1);
        }
        
        /* Tab content panel animation */
        .stTabs [data-baseweb="tab-panel"] {
            padding-top: 24px;
            animation: tabSlideIn 0.35s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        @keyframes tabSlideIn {
            from {
                opacity: 0;
                transform: translateX(6px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }
        
        /* =============================================
           RESPONSIVE
           ============================================= */
        
        @media (max-width: 900px) {
            .stTabs [data-baseweb="tab-list"] {
                border-radius: 30px !important;
                padding: 4px !important;
                min-height: 44px;
                flex-wrap: nowrap;
                overflow-x: auto;
                overflow-y: hidden;
                -webkit-overflow-scrolling: touch;
            }
            
            .stTabs [data-baseweb="tab-list"]::-webkit-scrollbar {
                height: 2px;
            }
            
            .stTabs [data-baseweb="tab-list"]::-webkit-scrollbar-track {
                background: rgba(255, 255, 255, 0.02);
            }
            
            .stTabs [data-baseweb="tab-list"]::-webkit-scrollbar-thumb {
                background: rgba(103, 232, 249, 0.2);
                border-radius: 10px;
            }
            
            .stTabs [data-baseweb="tab"] {
                padding: 6px 16px !important;
                font-size: 0.75rem !important;
                min-height: 32px !important;
                flex: 0 0 auto !important;
            }
        }
        
        @media (max-width: 600px) {
            .stTabs [data-baseweb="tab-list"] {
                border-radius: 20px !important;
                padding: 3px !important;
                min-height: 36px;
            }
            
            .stTabs [data-baseweb="tab"] {
                padding: 4px 12px !important;
                font-size: 0.65rem !important;
                min-height: 28px !important;
            }
        }
        </style>
        """,
        unsafe_allow_html=True,
    )
    
    # =====================================================
    # Tab Definition with Short Labels
    # =====================================================
    
    # Use shorter labels to fit better
    tab_labels = [
        "Overview",
        "AI Decision Engine",
        "Cost Breakdown",
        "BOM Explorer",
        "Data Quality",
        "Cost Drivers",
        "Simulation",
        "Data Management",
        "Data Onboard"
    ]
    
    tab1, tab2, tab3, tab4, tab5, tab6, tab7, tab8, tab9 = st.tabs(tab_labels)
    
    # =====================================================
    # TAB 1: OVERVIEW
    # =====================================================
    with tab1:
        section_header(
            "Executive AI Overview",
            "Current AI assessment for the selected revision.",
            "📈"
        )
        
        # ===============================================
        # 1. AI RECOMMENDATIONS (Top Priority - Actionable)
        # ===============================================

        # Add loading animation for AI computation
        show_loading_animation("Computing AI risk scores...")
        
        # Calculate metrics for recommendations
        component_count = bom_df["COMPONENT_ID"].nunique()
        supplier_count = (
            material_df["PREFERRED_SUPPLIER"]
            .fillna("")
            .replace("", pd.NA)
            .dropna()
            .nunique()
        )
        subassembly_count = (
            bom_df["ITEM_TYPE"]
            .fillna("")
            .str.upper()
            .eq("ASM")
            .sum()
        )

        # AI Scores
        decision_query = f"""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.AI_DECISION_ENGINE_V
        WHERE TOP_LEVEL_ITEM = '{selected}'
        AND REVISION = '{revision}'
        LIMIT 1
        """
        
        decision_df = session.sql(decision_query).to_pandas()
        decision = decision_df.iloc[0]

        css = decision["CSS"]
        fmis = decision["FMIS"]
        tds = decision["TDS"]
        bmcs = decision["BMCS"]

        # CSS
        if css >= 75:
            scrap_label = "Critical"
        elif css >= 50:
            scrap_label = "High"
        elif css >= 25:
            scrap_label = "Moderate"
        else:
            scrap_label = "Low"
        
        # FMIS
        if fmis >= 75:
            material_label = "Critical Procurement"
        elif fmis >= 50:
            material_label = "Price Increase Expected"
        elif fmis >= 25:
            material_label = "Monitor Market"
        else:
            material_label = "Stable"
        
        # TDS
        if tds >= 75:
            machine_label = "Immediate Maintenance"
        elif tds >= 50:
            machine_label = "Maintenance Required"
        elif tds >= 25:
            machine_label = "Monitor Equipment"
        else:
            machine_label = "Healthy"
        
        # BMCS
        if bmcs >= 80:
            quote_label = "Automatic Quote"
        elif bmcs >= 60:
            quote_label = "Engineering Review"
        else:
            quote_label = "Manual Review"
        
        risk_score = decision["AI_RISK_SCORE"]
        risk_level = decision["AI_RISK_LEVEL"]

        # Keep explanation engine
        explanations, recommendations = generate_ai_explanation(
            features,
            dimensions,
            css,
            fmis,
            tds,
            bmcs
        )
        
        # Keep decision engine only for UI labels
        decisions = ai_decision_engine(
            css,
            fmis,
            tds,
            bmcs
        )
        
        recommended_quote = decision["RECOMMENDED_QUOTE"]

        standard_cost = decision["TOTAL_COST"]

        cost_delta = recommended_quote - standard_cost
        
        cost_delta_pct = (
            (cost_delta / standard_cost) * 100
            if standard_cost > 0
            else 0
        )

        # AI Metrics Row
        ai1, ai2, ai3, ai4 = st.columns(4)
        
        with ai1:
            css_delta = 0
            if scrap_label == "Critical":
                css_delta = -25
            elif scrap_label == "High":
                css_delta = -15
            elif scrap_label == "Moderate":
                css_delta = -5
            else:
                css_delta = 5
                
            display_metric_card(
                label="Configuration Scrap Score",
                value=f"{css:.1f}%",
                delta=css_delta,
                help_text="Higher score indicates higher scrap risk"
            )
        
        with ai2:
            fmis_delta = 0
            if material_label == "Critical Procurement":
                fmis_delta = -20
            elif material_label == "Price Increase Expected":
                fmis_delta = -10
            elif material_label == "Monitor Market":
                fmis_delta = -5
            else:
                fmis_delta = 5
                
            display_metric_card(
                label="Forward Material Index",
                value=f"{fmis:.1f}%",
                delta=fmis_delta,
                help_text="Higher score indicates higher material risk"
            )
        
        with ai3:
            tds_delta = 0
            if machine_label == "Immediate Maintenance":
                tds_delta = -25
            elif machine_label == "Maintenance Required":
                tds_delta = -15
            elif machine_label == "Monitor Equipment":
                tds_delta = -5
            else:
                tds_delta = 5
                
            display_metric_card(
                label="Tooling Degradation Score",
                value=f"{tds:.1f}%",
                delta=tds_delta,
                help_text="Higher score indicates higher tooling degradation"
            )
        
        with ai4:
            bmcs_delta = 0
            if quote_label == "Automatic Quote":
                bmcs_delta = 20
            elif quote_label == "Engineering Review":
                bmcs_delta = 0
            else:
                bmcs_delta = -20
                
            display_metric_card(
                label="BOM Match Confidence",
                value=f"{bmcs:.1f}%",
                delta=bmcs_delta,
                help_text="Higher score indicates better RFQ match"
            )

        premium_divider()
        
        # ===============================================
        # AI Decision Summary
        # ===============================================
        section_header(
            "AI Decision Summary",
            "Manufacturing recommendations generated by AI.",
            "🚦"
        )
        # ----------------------------
        # Scrap Risk
        # ----------------------------
        
        if scrap_label == "Critical":
        
            st.error(
                "🚨 Critical scrap risk detected. Additional material buffer is recommended."
            )
        
        elif scrap_label == "High":
        
            st.warning(
                "⚠️ High scrap risk detected. Additional material buffer is recommended."
            )
        
        elif scrap_label == "Moderate":
        
            st.info(
                "📋 Moderate scrap risk detected. Standard material buffer is recommended."
            )
        
        else:
        
            st.success(
                "✅ Low scrap risk. No additional material buffer is required."
            )
        
        
        # ----------------------------
        # Material Outlook
        # ----------------------------
        
        if material_label == "Critical Procurement":
        
            st.error(
                "🚨 Commodity market is highly volatile. Immediate procurement is recommended to minimize material cost escalation."
            )
        
        elif material_label == "Price Increase Expected":
        
            st.warning(
                "📦 Raw material prices are expected to rise. Consider early procurement."
            )
        
        elif material_label == "Monitor Market":
        
            st.info(
                "📊 Commodity prices are showing moderate movement. Continue monitoring supplier pricing and market trends."
            )
        
        else:
        
            st.success(
                "📦 Raw material outlook is stable."
            )
        
        if machine_label == "Immediate Maintenance":

            st.error(
                "🚨 Tooling degradation is critical. Immediate maintenance is recommended."
            )
        
        elif machine_label == "Maintenance Required":
        
            st.warning(
                "🔧 High tooling stress detected. Preventive maintenance is recommended."
            )
        
        elif machine_label == "Monitor Equipment":
        
            st.info(
                "🛠️ Tooling is operating normally but should be monitored for increasing wear."
            )
        
        else:
        
            st.success(
                "🔧 Machine utilization is within acceptable limits."
            )
        
        if quote_label == "Automatic Quote":
            st.success(
                "📋 Quote can be generated automatically."
            )
        
        elif quote_label == "Engineering Review":
            st.warning(
                "📋 Engineering validation is recommended before quotation."
            )
        
        else:
            st.error(
                "📋 Manual engineering review is required before generating the quotation."
            )
        
        premium_section(
            "Risk-Adjusted Customer Quote",
            "AI-recommended pricing based on risk assessment",
            "💲"
        )
        
        c1, c2, c3, c4 = st.columns(4)
        
        with c1:
            content_card(
                value=format_currency(standard_cost),
                label="Standard Manufacturing Cost",
                description="Base cost before risk adjustment"
            )
        
        with c2:
            content_card(
                value=format_currency(recommended_quote),
                label="Recommended Customer Quote",
                description="AI-optimized price including risk",
                status="success" if cost_delta > 0 else "warning"
            )
            
        with c3:
            content_card(
                value=format_currency(cost_delta),
                label="Quote Increase",
                description="Risk adjustment premium",
                status="error" if cost_delta > 0 else "info"
            )
        
        with c4:
            content_card(
                value=f"{cost_delta_pct:.2f}%",
                label="Risk Adjustment",
                description="Percentage adjustment over base cost",
                status="warning" if cost_delta_pct > 10 else "success"
            )

        section_header(
            "AI Insights",
            "Key findings and recommended actions",
            "🧠"
        )

        col1, col2 = st.columns(2)
        
        with col1:
            premium_section(
                "Key Findings",
                "AI-identified manufacturing risks",
                "🔍"
            )
        
            for item in explanations:
                st.write(f"• {item}")
        
        with col2:
            premium_section(
                "Recommended Actions",
                "AI-generated action items",
                "💡"
            )
        
            for item in recommendations:
                st.write(f"✓ {item}")

            premium_section(
                "Quote Approval",
                "Current AI decision status",
                "📋"
            )

            st.info(f"""
            **Current Decision**
            
            {decisions["quote"]}
            """)
        
        premium_divider()
        
        # ===============================================
        # 2. PRODUCT COST SUMMARY
        # ===============================================
        section_header(
            "Product Cost Summary",
            "Material, labor and machine cost distribution.",
            "💰"
        )
        
        show_loading_animation("Loading plant data...")
        # Get plant data
        plant_df = session.sql(f"""
            SELECT DISTINCT PLANT_ID
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
            WHERE PARENT_ID = '{selected}'
        """).to_pandas()
        
        driver_df = material_df[material_df["EXTENDED_COST"].notna()].copy()
        
        # Cost Distribution Metrics
        c1, c2, c3, c4, c5 = st.columns(5)
        with c1:
            display_metric_card("Material Cost", format_currency(material_cost))
        with c2:
            display_metric_card("Labor Cost", format_currency(labor_cost))
        with c3:
            display_metric_card("Machine Cost", format_currency(machine_cost))
        with c4:
            display_metric_card("Total Cost", format_currency(total_cost))
        with c5:
            display_metric_card("Plants", len(plant_df))
        
        # Cost Distribution Chart
        premium_section(
            "Manufacturing Cost Breakdown",
            "Distribution of costs by category",
            "📊"
        )
        distribution_df = pd.DataFrame({
            "Cost Type": ["Material", "Labor", "Machine"],
            "Cost": [material_cost, labor_cost, machine_cost]
        })
        st.bar_chart(distribution_df.set_index("Cost Type"))
        
        premium_divider()
        
        # ===============================================
        # 3. EXECUTIVE SUMMARY
        # ===============================================
        section_header(
            "Executive Summary",
            "Key cost drivers and component metrics",
            "📋"
        )
        
        # Calculate top driver
        if not driver_df.empty:
            driver_df["CONTRIBUTION_PCT"] = (
                driver_df["EXTENDED_COST"] / driver_df["EXTENDED_COST"].sum() * 100
            )
            top_driver = driver_df.sort_values("EXTENDED_COST", ascending=False).iloc[0]
        else:
            top_driver = {"COMPONENT_ID": "N/A", "CONTRIBUTION_PCT": 0}
        
        component_count = bom_df["COMPONENT_ID"].nunique()
        assembly_count = bom_df["PARENT_ID"].nunique()
        
        # Executive Summary Metrics
        e1, e2, e3, e4 = st.columns(4)
        with e1:
            st.metric("Highest Cost Driver", top_driver["COMPONENT_ID"])
        with e2:
            st.metric("Cost Impact", f"{top_driver['CONTRIBUTION_PCT']:.1f}%")
        with e3:
            st.metric("Total Components", component_count)
        with e4:
            st.metric("Assemblies", assembly_count)
        
        premium_divider()
        
        # ===============================================
        # 4. REVISION DIFFERENCE ANALYSIS
        # ===============================================
        section_header(
            "Engineering Change Analysis",
            "Revision comparison and cost impact",
            "🔄"
        )
        
        # Get previous revision
        previous_revision_df = session.sql(f"""
            SELECT DISTINCT REVISION
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
            WHERE PARENT_ID = '{selected}'
            AND REVISION <> '{revision}'
            ORDER BY REVISION DESC
            LIMIT 1
        """).to_pandas()
        
        previous_revision = previous_revision_df.iloc[0]["REVISION"] if not previous_revision_df.empty else None
        
        # Get previous BOM
        previous_bom = pd.DataFrame()
        if previous_revision:
            previous_bom = session.sql(f"""
                SELECT COMPONENT_ID, QUANTITY
                FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
                WHERE PARENT_ID = '{selected}'
                AND REVISION = '{previous_revision}'
            """).to_pandas()
        
        # Current BOM
        current_bom = bom_df[["COMPONENT_ID", "QUANTITY"]].copy()
        
        # Calculate differences
        current_set = set(current_bom["COMPONENT_ID"])
        if previous_bom.empty:
            previous_set = set()
            added_components = current_set
            removed_components = set()
            quantity_changes = pd.DataFrame(columns=["COMPONENT_ID", "QUANTITY_NEW", "QUANTITY_OLD"])
        else:
            previous_set = set(previous_bom["COMPONENT_ID"])
            added_components = current_set - previous_set
            removed_components = previous_set - current_set
            quantity_changes = current_bom.merge(
                previous_bom, on="COMPONENT_ID", suffixes=("_NEW", "_OLD")
            )
            quantity_changes = quantity_changes[
                quantity_changes["QUANTITY_NEW"] != quantity_changes["QUANTITY_OLD"]
            ]
        
        # Revision Summary Metrics
        d1, d2, d3, d4 = st.columns(4)
        with d1:
            st.metric("Added Components", len(added_components))
        with d2:
            st.metric("Removed Components", len(removed_components))
        with d3:
            st.metric("Quantity Changes", len(quantity_changes))
        with d4:
            if previous_total_cost is not None:
                st.metric("Cost Delta", f"{total_cost - previous_total_cost:,.2f}")
            else:
                st.metric("Cost Delta", "N/A")
        
        # Revision Cost Comparison
        if previous_total_cost is not None:
            premium_divider()
            if total_cost < previous_total_cost:
                st.success(f"✅ Revision {revision} reduced product cost by {abs(total_cost - previous_total_cost):,.2f} compared to {previous_revision}.")
            elif total_cost > previous_total_cost:
                st.warning(f"⚠️ Revision {revision} increased product cost by {abs(total_cost - previous_total_cost):,.2f} compared to {previous_revision}.")
            else:
                st.info("ℹ️ No cost difference between revisions.")
        
        # Revision Metadata
        e5, e6, e7 = st.columns(3)
        with e5:
            st.metric("Current Revision", revision)
        with e6:
            if previous_total_cost is not None:
                st.metric("Previous Rev Cost", f"{previous_total_cost:,.2f}")
        with e7:
            if previous_total_cost is not None:
                diff = total_cost - previous_total_cost
                pct = (diff / previous_total_cost * 100) if previous_total_cost > 0 else 0
                st.metric("Revision Delta", f"{diff:,.2f}", f"{pct:.1f}%")
        
        premium_divider()
        
        # ===============================================
        # 5. ROUTING ANALYSIS
        # ===============================================
        section_header(
            "Routing Operations",
            "Labor and machine costs by operation",
            "🗺️"
        )
        
        if routing_df.empty:
            st.info("No routing operations available for this item")
        else:
            st.dataframe(routing_df, use_container_width=True)
            
            # Routing Cost Summary
            premium_section(
                "Routing Cost Summary",
                "Labor and machine costs by operation",
                "🗺️"
            )
            total_labor = routing_df["LABOR_COST"].sum()
            total_machine = routing_df["MACHINE_COST"].sum()
            total_routing = routing_df["TOTAL_OPERATION_COST"].sum()
            
            r1, r2, r3 = st.columns(3)
            with r1:
                display_metric_card("Total Labor Cost", format_currency(total_labor))
            with r2:
                display_metric_card("Total Machine Cost", format_currency(total_machine))
            with r3:
                display_metric_card("Total Routing Cost", format_currency(total_routing))
        
        premium_divider()
        
        # ===============================================
        # 6. COST RUN HISTORY
        # ===============================================
        section_header(
            "Latest Cost Run",
            "Recent manufacturing cost calculations",
            "📊"
        )
        
        history = session.sql(f"""
            SELECT *
            FROM DISCRETE_MFG_COST_MODEL.CORE_OUTPUT.COST_RUN_HISTORY
            WHERE ITEM_ID='{selected}'
            AND REVISION='{revision}'
            ORDER BY RUN_TIMESTAMP DESC
            LIMIT 5
        """).to_pandas()
        
        h1, h2 = st.columns(2)
        with h1:
            content_card(
                value=len(history),
                label="Cost Runs",
                description="Total calculation runs"
            )
        with h2:
            if not history.empty:
                content_card(
                    value=str(history.iloc[0]["RUN_TIMESTAMP"]),
                    label="Last Run",
                    description="Most recent calculation"
                )
        
        st.dataframe(history, use_container_width=True)
        st.caption("Latest manufacturing cost calculation runs.")
        # After calculating cost_delta_pct, add:
        ai_cost = {
            "standard_cost": standard_cost,
            "recommended_quote": recommended_quote,
            "quote_increase": cost_delta,
            "risk_adjustment": cost_delta
        }
    # =====================================================
    # TAB 2: AI DECISION ENGINE
    # =====================================================
    with tab2:
        section_header(
            "AI Decision Engine",
            "Advanced machine learning insights for manufacturing optimization",
            "🤖"
        )

        if decision_df.empty:
            st.warning("No AI decision available for this product.")
            st.stop()
    
        decision = decision_df.iloc[0]

        premium_section(
            f"Product: {decision['ITEM_NAME']}",
            f"Revision: {decision['REVISION']} | Family: {decision['PRODUCT_FAMILY']}",
            "📦"
        )
        
        c1, c2, c3, c4 = st.columns(4)

        with c1:
            display_metric_card(
                label="AI Risk Score",
                value=f"{decision['AI_RISK_SCORE']:.2f}",
                help_text="Overall AI risk assessment score"
            )
        
        with c2:
            risk_delta = 15 if decision['AI_RISK_LEVEL'] == "LOW" else 0 if decision['AI_RISK_LEVEL'] == "MEDIUM" else -15
            display_metric_card(
                label="Risk Level",
                value=decision["AI_RISK_LEVEL"],
                delta=risk_delta,
                help_text="Risk classification level"
            )
        
        with c3:
            display_metric_card(
                label="Manufacturing Cost",
                value=format_currency(decision['TOTAL_COST']),
                help_text="Total manufacturing cost"
            )
        
        with c4:
            display_metric_card(
                label="Recommended Quote",
                value=format_currency(decision['RECOMMENDED_QUOTE']),
                help_text="AI-recommended customer quote"
            )
        
        premium_divider()
        
        section_header(
            "AI Model Scores",
            "Individual model contributions to risk assessment",
            "📊"
        )

        a1, a2, a3, a4 = st.columns(4)
        
        with a1:
            # CSS - Configuration Scrap Score (Higher = Worse)
            css_delta = 0
            if decision["CSS"] >= 75:
                css_delta = -25
            elif decision["CSS"] >= 50:
                css_delta = -15
            elif decision["CSS"] >= 25:
                css_delta = -5
            else:
                css_delta = 5
                
            display_metric_card(
                label="CSS",
                value=f"{decision['CSS']:.1f}%",
                delta=css_delta,
                help_text="Configuration Scrap Score - Higher indicates higher scrap risk"
            )
        
        with a2:
            # FMIS - Forward Material Index (Higher = Worse)
            fmis_delta = 0
            if decision["FMIS"] >= 75:
                fmis_delta = -20
            elif decision["FMIS"] >= 50:
                fmis_delta = -10
            elif decision["FMIS"] >= 25:
                fmis_delta = -5
            else:
                fmis_delta = 5
                
            display_metric_card(
                label="FMIS",
                value=f"{decision['FMIS']:.1f}%",
                delta=fmis_delta,
                help_text="Forward Material Index - Higher indicates higher material risk"
            )
        
        with a3:
            # TDS - Tooling Degradation Score (Higher = Worse)
            tds_delta = 0
            if decision["TDS"] >= 75:
                tds_delta = -25
            elif decision["TDS"] >= 50:
                tds_delta = -15
            elif decision["TDS"] >= 25:
                tds_delta = -5
            else:
                tds_delta = 5
                
            display_metric_card(
                label="TDS",
                value=f"{decision['TDS']:.1f}%",
                delta=tds_delta,
                help_text="Tooling Degradation Score - Higher indicates higher tooling degradation"
            )
        
        with a4:
            # BMCS - BOM Match Confidence (Higher = Better)
            bmcs_delta = 0
            if decision["BMCS"] >= 80:
                bmcs_delta = 20
            elif decision["BMCS"] >= 60:
                bmcs_delta = 0
            else:
                bmcs_delta = -20
                
            display_metric_card(
                label="BMCS",
                value=f"{decision['BMCS']:.1f}%",
                delta=bmcs_delta,
                help_text="BOM Match Confidence - Higher indicates better RFQ match"
            )
        
        premium_divider()
        
        section_header(
            "RFQ Assessment",
            "Customer requirements analysis and completeness",
            "📋"
        )
        
        premium_section(
            "Match Status",
            "AI assessment of RFQ completeness",
            "📊"
        )
        st.info(decision["MATCH_STATUS"])
        
        premium_section(
            "Missing Requirements",
            "Requirements not yet fulfilled by current design",
            "⚠️"
        )
        st.warning(decision["MISSING_REQUIREMENTS"])
        
        premium_section(
            "Suggested Components",
            "AI-generated component recommendations",
            "💡"
        )
        st.success(decision["SUGGESTED_COMPONENTS"])

        premium_divider()
        
        section_header(
            "AI Summary",
            "Overall AI assessment and recommendation",
            "🧠"
        )

        st.write(decision["AI_SUMMARY"])

        if decision["AI_RISK_LEVEL"] == "LOW":
            st.success("✅ AI Decision: APPROVE FOR QUOTATION")
        
        elif decision["AI_RISK_LEVEL"] == "MEDIUM":
            st.warning("⚠️ AI Decision: PROCEED WITH CAUTION")
        
        else:
            st.error("🚨 AI Decision: MANAGEMENT REVIEW REQUIRED")

        premium_divider()
        
        section_header(
            "AI Recommendations",
            "Actionable insights from AI analysis",
            "💡"
        )

        recommendations = []
        
        # ---------------- CSS ----------------
        if decision["CSS"] >= 80:
            recommendations.append(
                ("🔴 High Scrap Risk",
                 "Increase quality inspections and review manufacturing process.")
            )
        elif decision["CSS"] >= 50:
            recommendations.append(
                ("🟡 Moderate Scrap Risk",
                 "Monitor production quality closely.")
            )
        else:
            recommendations.append(
                ("🟢 Low Scrap Risk",
                 "No additional quality actions required.")
            )
        
        # ---------------- FMIS ----------------
        if decision["FMIS"] >= 75:
            recommendations.append(
                (
                    "🔴 Critical Material Risk",
                    "Secure raw materials immediately or negotiate long-term supplier contracts."
                )
            )
        
        elif decision["FMIS"] >= 50:
            recommendations.append(
                (
                    "🟠 Material Inflation Expected",
                    "Increase quotation buffer due to expected raw material price increases."
                )
            )
        
        elif decision["FMIS"] >= 25:
            recommendations.append(
                (
                    "🟡 Commodity Watch",
                    "Monitor supplier pricing and commodity market trends."
                )
            )
        
        else:
            recommendations.append(
                (
                    "🟢 Stable Material Market",
                    "Commodity prices are stable. No additional procurement action required."
                )
            )
        
        # ---------------- TDS ----------------
        if decision["TDS"] >= 75:
            recommendations.append(
                (
                    "🔧 Tool Maintenance",
                    "Schedule preventive maintenance before production."
                )
            )
        
        elif decision["TDS"] >= 50:
            recommendations.append(
                (
                    "🟡 Tool Monitoring",
                    "Monitor tooling wear."
                )
            )
        
        elif decision["TDS"] >= 25:
            recommendations.append(
                (
                    "🟢 Healthy Tooling",
                    "Continue routine inspections."
                )
            )
        
        else:
            recommendations.append(
                (
                    "✅ Excellent Tooling",
                    "No maintenance action required."
                )
            )
        
        # ---------------- BMCS ----------------
        if decision["BMCS"] < 60:
            recommendations.append(
                ("📋 RFQ Review",
                 "Customer RFQ is incomplete. Clarify missing requirements before quoting.")
            )
        elif decision["BMCS"] < 80:
            recommendations.append(
                ("📄 Engineering Review",
                 "Validate RFQ with engineering team.")
            )
        else:
            recommendations.append(
                ("✅ RFQ Complete",
                 "Requirements appear complete.")
            )
        
        # Display
        for title, desc in recommendations:
            if "🔴" in title or "Critical" in title:
                status = "error"
            elif "🟡" in title or "🟠" in title or "Watch" in title:
                status = "warning"
            else:
                status = "success"
            
            content_card(
                value=title,
                label="Recommendation",
                description=desc,
                status=status
            )

        premium_divider()

        section_header(
            "AI Risk Explainability",
            "Understanding the drivers behind the risk score",
            "🔍"
        )

        css_contribution = decision["CSS"] * 0.35
        
        fmis_contribution = decision["FMIS"] * 0.20
        
        tds_contribution = decision["TDS"] * 0.20
        
        bmcs_contribution = (100 - decision["BMCS"]) * 0.25
        
        c1, c2 = st.columns(2)

        with c1:
        
            display_metric_card(
                label="CSS Contribution",
                value=f"{css_contribution:.2f}",
                help_text="35% weight in overall AI Risk Score"
            )
            display_metric_card(
                label="FMIS Contribution",
                value=f"{fmis_contribution:.2f}",
                help_text="20% weight in overall AI Risk Score"
            )
        
        with c2:
            display_metric_card(
                label="TDS Contribution",
                value=f"{tds_contribution:.2f}",
                help_text="20% weight in overall AI Risk Score"
            )
            display_metric_card(
                label="BMCS Contribution",
                value=f"{bmcs_contribution:.2f}",
                help_text="25% weight in overall AI Risk Score"
            )

        premium_divider()
        
        premium_section(
            "Contribution Breakdown",
            "AI model weights and their impact",
            "📊"
        )

        explain_df = pd.DataFrame(
            {
                "AI Model": ["CSS", "FMIS", "TDS", "BMCS"],
                "Current Score": [
                    decision["CSS"],
                    round(decision["FMIS"], 3),
                    round(decision["TDS"], 2),
                    decision["BMCS"],
                ],
                "Weight": ["35%", "20%", "20%", "25%"],
                "Contribution": [
                    round(css_contribution, 2),
                    round(fmis_contribution, 2),
                    round(tds_contribution, 2),
                    round(bmcs_contribution, 2),
                ],
            }
        )
        
        st.dataframe(
            explain_df,
            use_container_width=True,
            hide_index=True,
        )

        premium_section(
            "Primary Risk Driver",
            "The factor with the highest contribution to risk",
            "🎯"
        )

        contributions = {
            "CSS": css_contribution,
            "FMIS": fmis_contribution,
            "TDS": tds_contribution,
            "BMCS": bmcs_contribution,
        }
        
        highest = max(contributions, key=contributions.get)
        
        messages = {
            "CSS": "Scrap risk has the highest impact on the quotation. Review manufacturing quality before production.",
            "FMIS": "Material price volatility is driving the quotation. Consider adding a pricing buffer.",
            "TDS": "Tool degradation is the major contributor. Preventive maintenance is recommended.",
            "BMCS": "Customer RFQ completeness is the largest source of uncertainty. Engineering review is recommended.",
        }
        
        premium_section(
            f"Highest Contributor: {highest}",
            f"Contribution: {contributions[highest]:.2f} - {messages[highest]}",
            "🎯"
        )

        c1,c2 = st.columns(2)
        
        with c1:
            display_metric_card(
                label="Manufacturing Risk",
                value=round(css_contribution + tds_contribution, 2),
                help_text="Risk from manufacturing operations"
            )
        
        with c2:
            display_metric_card(
                label="Business Risk",
                value=round(fmis_contribution + bmcs_contribution, 2),
                help_text="Risk from business factors"
            )
            
        premium_divider()
        
        section_header(
            "AI Interpretation",
            "Understanding the primary risk driver",
            "🧠"
        )

        highest = max(
            {
                "CSS": css_contribution,
                "FMIS": fmis_contribution,
                "TDS": tds_contribution,
                "BMCS": bmcs_contribution
            },
            key=lambda x: {
                "CSS": css_contribution,
                "FMIS": fmis_contribution,
                "TDS": tds_contribution,
                "BMCS": bmcs_contribution
            }[x]
        )
        
        explanations = {
            "CSS":"Manufacturing quality risk is the dominant factor affecting this quotation.",
            "FMIS":"Material price forecast is the largest contributor to business risk.",
            "TDS":"Tool degradation is driving the quotation increase.",
            "BMCS":"Customer RFQ completeness is the primary uncertainty."
        }
        
        premium_section(
            f"Primary Risk Driver: {highest}",
            explanations[highest],
            "🧠"
        )
        
    # =====================================================
    # TAB 3: MATERIALS
    # =====================================================
    with tab3:
        section_header(
            "Material Intelligence",
            "Component cost breakdown and supplier analytics",
            "📦"
        )
        
        k1, k2, k3, k4 = st.columns(4)
    
        with k1:
            display_metric_card(
                label="Components",
                value=material_df["COMPONENT_ID"].nunique(),
                help_text="Total number of unique components"
            )
        
        with k2:
            display_metric_card(
                label="Material Cost",
                value=format_currency(material_df['EXTENDED_COST'].sum()),
                help_text="Total material cost"
            )
        
        with k3:
            display_metric_card(
                label="Average Component Cost",
                value=format_currency(material_df['USED_COST'].mean()),
                help_text="Average cost per component"
            )
        
        with k4:
            display_metric_card(
                label="Total Suppliers",
                value=material_df["PREFERRED_SUPPLIER"].nunique(),
                help_text="Number of unique suppliers"
            )
            
        premium_divider()
        
        # Material Cost Breakdown
        section_header(
            "Component Cost Breakdown",
            "Detailed view of all material costs",
            "📊"
        )
        
        if material_df.empty:
            st.warning("No material data found")
        else:
            left, right = st.columns(2)
            with left:
                st.dataframe(
                    material_df[
                        [
                            "COMPONENT_ID",
                            "UNITS",
                            "PREFERRED_SUPPLIER",
                            "SUPPLIER_COST",
                            "USED_COST",
                            "EXTENDED_COST"
                        ]
                    ],
                    use_container_width=True
                )
            with right:
                material_chart = material_df[
                    material_df["EXTENDED_COST"].notna()
                ]
                
                if not material_chart.empty:
                    st.bar_chart(
                        material_chart.set_index("COMPONENT_ID")["EXTENDED_COST"]
                    )
    
            premium_divider()
            
            section_header(
                "Supplier Analytics",
                "Supplier performance and spend analysis",
                "🏢"
            )
    
            supplier_summary = (
                material_df
                .groupby("PREFERRED_SUPPLIER", dropna=False)
                .agg(
                    Components=("COMPONENT_ID", "nunique"),
                    Spend=("EXTENDED_COST", "sum"),
                    Average_Cost=("USED_COST", "mean")
                )
                .reset_index()
            )
            
            supplier_summary.rename(
                columns={
                    "PREFERRED_SUPPLIER": "Supplier"
                },
                inplace=True
            )
    
            coverage = (
                material_df["PREFERRED_SUPPLIER"]
                .notna()
                .mean()
            ) * 100
            
            supplier_count = (
                material_df["PREFERRED_SUPPLIER"]
                .dropna()
                .nunique()
            )
            
            preferred = (
                material_df["PREFERRED_SUPPLIER"]
                .mode()[0]
                if supplier_count > 0
                else "-"
            )
            
            average_supplier_cost = (
                supplier_summary["Average_Cost"]
                .mean()
            )
    
            k1, k2, k3 = st.columns(3)
            
            with k1:
                display_metric_card(
                    label="Suppliers Used",
                    value=supplier_count,
                    help_text="Number of active suppliers"
                )
            
            with k2:
                display_metric_card(
                    label="Preferred Supplier",
                    value=preferred,
                    help_text="Most frequently used supplier"
                )
                
            with k3:
                display_metric_card(
                    label="Average Supplier Cost",
                    value=format_currency(average_supplier_cost),
                    help_text="Average cost across all suppliers"
                )
                
            premium_section(
                "Supplier Summary",
                "Aggregated supplier metrics",
                "📊"
            )
    
            st.dataframe(
                supplier_summary,
                use_container_width=True
            )
    
            premium_section(
                "Component Supplier Details",
                "Supplier assignments by component",
                "📋"
            )
    
            st.dataframe(
                material_df[
                    [
                        "COMPONENT_ID",
                        "PREFERRED_SUPPLIER",
                        "SUPPLIER_COST",
                        "USED_COST",
                        "EXTENDED_COST"
                    ]
                ],
                use_container_width=True
            )
    
            premium_divider()
            
            section_header(
                "Procurement Risk Dashboard",
                "Supplier concentration and risk assessment",
                "🚚"
            )
            
            # =====================================================
            # PROCUREMENT RISK
            # =====================================================
            
            supplier_df = material_df.copy()
            
            total_components = supplier_df["COMPONENT_ID"].nunique()
            
            supplier_coverage = (
                supplier_df["PREFERRED_SUPPLIER"]
                .fillna("")
                .replace("", pd.NA)
                .dropna()
                .nunique()
            )
            
            coverage_pct = (
                supplier_df["PREFERRED_SUPPLIER"]
                .notna()
                .mean()
                * 100
            )
            
            # Spend by supplier
            supplier_spend = (
                supplier_df
                .groupby("PREFERRED_SUPPLIER", dropna=False)
                ["EXTENDED_COST"]
                .sum()
                .reset_index()
            )
            
            supplier_spend.rename(
                columns={
                    "EXTENDED_COST": "SPEND"
                },
                inplace=True
            )
            
            # Supplier concentration
            largest_supplier_share = 0
            
            if supplier_spend["SPEND"].sum() > 0:
                largest_supplier_share = (
                    supplier_spend["SPEND"].max()
                    /
                    supplier_spend["SPEND"].sum()
                    * 100
                )
    
            component_supplier = (
                supplier_df
                .groupby("COMPONENT_ID")
                ["PREFERRED_SUPPLIER"]
                .nunique()
            )
            
            single_source = (
                component_supplier == 1
            ).sum()
            
            single_source_pct = (
                single_source
                /
                len(component_supplier)
                * 100
            )
            
            missing_supplier_cost = (
                supplier_df["SUPPLIER_COST"]
                .isna()
                .sum()
            )
            
            health_score = 100
            health_score -= missing_supplier_cost * 5
            
            if largest_supplier_share > 50:
                health_score -= 20
            
            if single_source_pct > 60:
                health_score -= 15
            
            health_score = max(0, health_score)
    
            k1, k2, k3, k4, k5 = st.columns(5)
    
            with k1:
                # Higher coverage is better
                coverage_delta = 15 if coverage_pct > 80 else 0 if coverage_pct > 50 else -15
                display_metric_card(
                    label="Supplier Coverage",
                    value=f"{coverage_pct:.0f}%",
                    delta=coverage_delta,
                    help_text="Percentage of components with supplier assigned"
                )
            
            with k2:
                # Lower concentration is better
                concentration_delta = -15 if largest_supplier_share > 50 else 0 if largest_supplier_share > 30 else 15
                display_metric_card(
                    label="Largest Supplier",
                    value=f"{largest_supplier_share:.1f}%",
                    delta=concentration_delta,
                    help_text="Share of spend with largest supplier"
                )
            
            with k3:
                # Lower single source risk is better
                single_source_delta = -20 if single_source_pct > 60 else -10 if single_source_pct > 40 else 10
                display_metric_card(
                    label="Single Source Risk",
                    value=f"{single_source_pct:.0f}%",
                    delta=single_source_delta,
                    help_text="Percentage of components with single supplier"
                )
            
            with k4:
                # Lower missing cost is better
                missing_delta = -20 if missing_supplier_cost > 5 else -10 if missing_supplier_cost > 0 else 20
                display_metric_card(
                    label="Missing Supplier Cost",
                    value=missing_supplier_cost,
                    delta=missing_delta,
                    help_text="Components missing supplier cost data"
                )
            
            with k5:
                # Higher health score is better
                health_delta = 20 if health_score > 80 else 0 if health_score > 50 else -20
                display_metric_card(
                    label="Health Score",
                    value=f"{health_score:.0f}%",
                    delta=health_delta,
                    help_text="Overall procurement health score"
                )
            
            premium_section(
                "Supplier Spend",
                "Distribution of spend across suppliers",
                "💰"
            )
    
            st.bar_chart(
                supplier_spend.set_index("PREFERRED_SUPPLIER")["SPEND"]
            )
    
            premium_section(
                "Risk Alerts",
                "Identified procurement risks",
                "⚠️"
            )
            
            if largest_supplier_share > 50:
                content_card(
                    value="High Supplier Concentration",
                    label="Risk Alert",
                    description="Over 50% of spend is with a single supplier. Consider diversifying.",
                    status="error"
                )
            
            if single_source_pct > 60:
                content_card(
                    value="Single Source Dependency",
                    label="Risk Alert",
                    description="Over 60% of components rely on a single supplier. High supply chain risk.",
                    status="error"
                )
            
            if missing_supplier_cost > 0:
                content_card(
                    value=f"Missing Supplier Costs",
                    label=f"{missing_supplier_cost} Components",
                    description=f"{missing_supplier_cost} component(s) missing supplier cost data. Complete supplier master data.",
                    status="warning"
                )
            
            if (
                largest_supplier_share <= 50
                and single_source_pct <= 60
                and missing_supplier_cost == 0
            ):
                content_card(
                    value="Procurement Risk is Low",
                    label="Status",
                    description="Supplier diversification is healthy. No immediate procurement risks detected.",
                    status="success"
                )

    # =====================================================
    # TAB 4: BOM EXPLORER
    # =====================================================
    
    with tab4:
        section_header(
            "Bill of Materials Explorer",
            "Hierarchical view of product structure",
            "🌳"
        )
        
        product_bom = session.sql(f"""
        WITH RECURSIVE BOM_TREE AS (
        
            SELECT
                PARENT_ID,
                COMPONENT_ID,
                QUANTITY,
                1 AS LEVEL
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
            WHERE PARENT_ID = '{selected}'
            AND REVISION = '{revision}'
            AND CURRENT_DATE BETWEEN EFFECTIVE_FROM
            AND COALESCE(EFFECTIVE_TO,'9999-12-31')
        
            UNION ALL
        
            SELECT
                c.PARENT_ID,
                c.COMPONENT_ID,
                c.QUANTITY,
                b.LEVEL + 1
            FROM BOM_TREE b
            JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE c
                ON b.COMPONENT_ID = c.PARENT_ID
                AND c.REVISION = '{revision}'
        )
        
        SELECT *
        FROM BOM_TREE
        """).to_pandas()
    
        total_components = product_bom["COMPONENT_ID"].nunique()
        assemblies = product_bom["PARENT_ID"].nunique()
        raw_materials = len(
            set(product_bom["COMPONENT_ID"]) -
            set(product_bom["PARENT_ID"])
        )
    
        k1, k2, k3 = st.columns(3)
    
        with k1:
            display_metric_card(
                label="Total Components",
                value=total_components,
                help_text="Total number of unique components in the BOM"
            )
    
        with k2:
            display_metric_card(
                label="Assemblies",
                value=assemblies,
                help_text="Number of assembly nodes in the BOM"
            )
    
        with k3:
            display_metric_card(
                label="Raw Materials",
                value=raw_materials,
                help_text="Number of raw material components (leaf nodes)"
            )
    
        search_component = st.text_input(
            "🔍 Search Component",
            placeholder="Enter component ID to search..."
        )
    
        if search_component:
            result = bom_df[
                bom_df["COMPONENT_ID"]
                .str.contains(
                    search_component,
                    case=False,
                    na=False
                )
            ]
            if result.empty:
                st.info("No matching component found.")
            else:
                st.dataframe(
                    result,
                    use_container_width=True
                )
    
        premium_divider()
            
        section_header(
            "Product Structure",
            "Interactive BOM tree visualization",
            "🏗️"
        )
        
        with st.expander(
            f"{selected} (Finished Good)",
            expanded=True
        ):
            render_tree(
                selected,
                tree
            )
        
        premium_divider()
    
        section_header(
            "BOM Statistics",
            "Structural metrics and analysis",
            "📊"
        )
    
        col1, col2 = st.columns(2)
    
        with col1:
            avg_components = round(
                total_components / max(assemblies, 1),
                2
            )
            display_metric_card(
                label="Average Components / Assembly",
                value=avg_components,
                help_text="Average number of components per assembly"
            )
    
        with col2:
            leaf_ratio = (
                raw_materials / max(total_components, 1)
            )
            leaf_ratio_pct = leaf_ratio * 100
            
            # Delta based on leaf ratio - lower is more complex
            leaf_delta = 15 if leaf_ratio > 0.5 else 0 if leaf_ratio > 0.3 else -15
            
            display_metric_card(
                label="Leaf Node Ratio",
                value=f"{leaf_ratio_pct:.1f}%",
                delta=leaf_delta,
                help_text="Percentage of components that are raw materials (leaf nodes)"
            )

    # =====================================================
    # TAB 5: DATA QUALITY
    # =====================================================
    with tab5:
        section_header(
            "Manufacturing Data Quality",
            "Validation and completeness assessment",
            "📊"
        )
    
        product_bom = session.sql(f"""
        WITH RECURSIVE BOM_TREE AS (
        
            SELECT
                PARENT_ID,
                COMPONENT_ID,
                QUANTITY
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
            WHERE PARENT_ID = '{selected}'
            AND REVISION = '{revision}'
            AND CURRENT_DATE BETWEEN EFFECTIVE_FROM
            AND COALESCE(EFFECTIVE_TO,'9999-12-31')
        
            UNION ALL
        
            SELECT
                c.PARENT_ID,
                c.COMPONENT_ID,
                c.QUANTITY
            FROM BOM_TREE b
            JOIN DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE c
                ON b.COMPONENT_ID = c.PARENT_ID
                AND c.REVISION = '{revision}'
        
        )
        
        SELECT *
        FROM BOM_TREE
        """).to_pandas()
    
        product_components = tuple(
            product_bom["COMPONENT_ID"].unique().tolist()
        )
        
    
        material_costs_df = session.sql("""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.MATERIAL_COSTS
        """).to_pandas()
        
        # Normalize values
        product_bom["COMPONENT_ID"] = (
            product_bom["COMPONENT_ID"]
            .astype(str)
            .str.strip()
            .str.upper()
        )
        
        material_costs_df["ITEM_ID"] = (
            material_costs_df["ITEM_ID"]
            .astype(str)
            .str.strip()
            .str.upper()
        )
        
        missing_cost_df = product_bom[
            ~product_bom["COMPONENT_ID"].isin(
                material_costs_df["ITEM_ID"]
            )
        ][["COMPONENT_ID"]].drop_duplicates()
    
        item_master_df = session.sql("""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER
        """).to_pandas()
    
        missing_item_df = product_bom[
            ~product_bom["COMPONENT_ID"].isin(
                item_master_df["ITEM_ID"]
            )
        ][["COMPONENT_ID"]].drop_duplicates()
    
        duplicate_df = (
            product_bom
            .groupby(
                ["PARENT_ID","COMPONENT_ID"]
            )
            .size()
            .reset_index(name="DUPLICATE_COUNT")
        )
        
        duplicate_df = duplicate_df[
            duplicate_df["DUPLICATE_COUNT"] > 1
        ]
        
        expired_bom_df = session.sql("""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
        WHERE EFFECTIVE_TO IS NOT NULL
        AND EFFECTIVE_TO < CURRENT_DATE
        """).to_pandas()
        
        missing_revision_df = session.sql("""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
        WHERE REVISION IS NULL
        OR TRIM(REVISION) = ''
        """).to_pandas()
        
        missing_revisions = len(missing_revision_df)
    
        missing_dates_df = session.sql("""
        SELECT *
        FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
        WHERE EFFECTIVE_FROM IS NULL
        """).to_pandas()
        
        missing_dates = len(missing_dates_df)
        
        expired_boms = len(expired_bom_df)
        missing_costs = len(missing_cost_df)
        missing_items = len(missing_item_df)
        duplicates = len(duplicate_df)
        
        quality_score = 100
        quality_score -= missing_costs * 5
        quality_score -= missing_items * 5
        quality_score -= duplicates * 10
        quality_score -= expired_boms * 3
        quality_score -= missing_revisions * 5
        quality_score -= missing_dates * 5
        quality_score = max(quality_score, 0)
    
        components_checked = product_bom["COMPONENT_ID"].nunique()
    
        # Quality metrics row - using 8 columns with content_card
        k1, k2, k3, k4, k5, k6, k7, k8 = st.columns(8)
    
        with k1:
            # Quality Score - higher is better
            quality_delta = 20 if quality_score >= 95 else 0 if quality_score >= 80 else -20
            display_metric_card(
                label="Quality Score",
                value=f"{quality_score}%",
                delta=quality_delta,
                help_text="Overall data quality score"
            )
    
        with k2:
            display_metric_card(
                label="BOM Components",
                value=components_checked,
                help_text="Total components checked"
            )
        
        with k3:
            status = "error" if missing_costs > 0 else "success"
            # Missing costs - lower is better
            missing_delta = -20 if missing_costs > 5 else -10 if missing_costs > 0 else 20
            display_metric_card(
                label="Missing Costs",
                value=missing_costs,
                delta=missing_delta,
                help_text="Components missing material cost data"
            )
        
        with k4:
            status = "error" if missing_items > 0 else "success"
            missing_items_delta = -20 if missing_items > 5 else -10 if missing_items > 0 else 20
            display_metric_card(
                label="Missing Master Data",
                value=missing_items,
                delta=missing_items_delta,
                help_text="Components not in item master"
            )
        
        with k5:
            status = "warning" if duplicates > 0 else "success"
            duplicate_delta = -20 if duplicates > 5 else -10 if duplicates > 0 else 20
            display_metric_card(
                label="Duplicate Records",
                value=duplicates,
                delta=duplicate_delta,
                help_text="Duplicate BOM relationships"
            )
        
        with k6:
            status = "warning" if expired_boms > 0 else "success"
            expired_delta = -15 if expired_boms > 10 else -5 if expired_boms > 0 else 15
            display_metric_card(
                label="Expired BOMs",
                value=expired_boms,
                delta=expired_delta,
                help_text="Outdated BOM records"
            )
        
        with k7:
            status = "error" if missing_revisions > 0 else "success"
            rev_delta = -20 if missing_revisions > 5 else -10 if missing_revisions > 0 else 20
            display_metric_card(
                label="Missing Revisions",
                value=missing_revisions,
                delta=rev_delta,
                help_text="BOMs without revision"
            )
        
        with k8:
            status = "warning" if missing_dates > 0 else "success"
            date_delta = -15 if missing_dates > 5 else -5 if missing_dates > 0 else 15
            display_metric_card(
                label="Missing Dates",
                value=missing_dates,
                delta=date_delta,
                help_text="BOMs without effective dates"
            )
    
        st.divider()
        
        premium_section(
            "Validation Summary",
            "Data quality issues and recommendations",
            "✅"
        )
    
        alerts = []
        
        if missing_costs:
            alerts.append(f"🔴 {missing_costs} component(s) missing material cost.")
        
        if missing_items:
            alerts.append(f"🔴 {missing_items} component(s) missing in Item Master.")
        
        if duplicates:
            alerts.append(f"🟠 {duplicates} duplicate BOM relationship(s).")
        
        if expired_boms:
            alerts.append(f"🟡 {expired_boms} expired BOM record(s).")
        
        if missing_revisions:
            alerts.append(f"🔴 {missing_revisions} missing revision(s).")
        
        if missing_dates:
            alerts.append(f"🟠 {missing_dates} missing effective date(s).")
        
        if alerts:
            st.warning("\n\n".join(alerts))
        else:
            content_card(
                value="All Checks Passed",
                label="Validation Status",
                description="All manufacturing validation checks passed.",
                status="success"
            )
        
        premium_divider()
    
        with st.expander("Missing Material Costs"):
            if missing_cost_df.empty:
                content_card(
                    value="No Missing Costs",
                    label="Status",
                    description="All components have material cost data.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(missing_cost_df)} Components",
                    label="Missing Material Costs",
                    description="Components have no material cost data.",
                    status="error"
                )
                st.dataframe(
                    missing_cost_df,
                    use_container_width=True
                )
            
        st.divider()
    
        with st.expander("Missing Item Master Records"):
            if missing_item_df.empty:
                content_card(
                    value="All Items Exist",
                    label="Status",
                    description="All components exist in Item Master.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(missing_item_df)} Components",
                    label="Missing Item Master Records",
                    description="Components missing in Item Master.",
                    status="error"
                )
                st.dataframe(
                    missing_item_df,
                    use_container_width=True
                )
    
        st.divider()
    
        with st.expander("Duplicate BOM Records"):
            if duplicate_df.empty:
                content_card(
                    value="No Duplicates",
                    label="Status",
                    description="No duplicate BOM records found.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(duplicate_df)} Duplicates",
                    label="Duplicate BOM Records",
                    description="Duplicate BOM relationships found.",
                    status="error"
                )
                st.dataframe(
                    duplicate_df,
                    use_container_width=True
                )
    
        st.divider()
    
        with st.expander("Expired BOM Records"):
            if expired_bom_df.empty:
                content_card(
                    value="No Expired Records",
                    label="Status",
                    description="No expired BOM records found.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(expired_bom_df)} Records",
                    label="Expired BOM Records",
                    description="BOM records that have expired.",
                    status="warning"
                )
                st.dataframe(
                    expired_bom_df,
                    use_container_width=True
                )
    
        st.divider()
    
        with st.expander("Missing Revision Assignments"):
            if missing_revision_df.empty:
                content_card(
                    value="All Have Revisions",
                    label="Status",
                    description="All BOM records contain revisions.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(missing_revision_df)} Records",
                    label="Missing Revisions",
                    description="BOM records missing revision assignments.",
                    status="error"
                )
                st.dataframe(
                    missing_revision_df,
                    use_container_width=True
                )
    
        st.divider()
    
        with st.expander("Missing Effective Dates"):
            if missing_dates_df.empty:
                content_card(
                    value="All Have Dates",
                    label="Status",
                    description="All BOM records contain effective dates.",
                    status="success"
                )
            else:
                content_card(
                    value=f"{len(missing_dates_df)} Records",
                    label="Missing Effective Dates",
                    description="BOM records missing effective dates.",
                    status="error"
                )
                st.dataframe(
                    missing_dates_df,
                    use_container_width=True
                )
    
        premium_divider()
    
        section_header(
            "Overall Assessment",
            "Executive summary of data quality",
            "🎯"
        )
        
        if quality_score >= 95:
            content_card(
                value="Excellent Quality",
                label="Overall Assessment",
                description="🟢 Manufacturing master data quality is excellent.",
                status="success"
            )
        elif quality_score >= 80:
            content_card(
                value="Good Quality",
                label="Overall Assessment",
                description="🟡 Minor data quality issues require attention.",
                status="warning"
            )
        else:
            content_card(
                value="Critical Issues Detected",
                label="Overall Assessment",
                description="🔴 Critical manufacturing data issues detected.",
                status="error"
            )
        
        
    # =====================================================
    # TAB 6: COST DRIVER
    # =====================================================
    with tab6:
        section_header(
            "Cost Driver Analysis",
            "Identify high-impact cost components",
            "💰"
        )
        
        driver_df = material_df.copy()
    
        driver_df = driver_df[
            driver_df["EXTENDED_COST"].notna()
        ]
    
        driver_df = (
            driver_df
            .groupby(
                "COMPONENT_ID",
                as_index=False
            )
            .agg({
                "UNITS": "sum",
                "USED_COST": "max",
                "EXTENDED_COST": "sum"
            })
        )
        
        if driver_df.empty:
            st.warning(
                """
                No material cost data available
                for this product.
        
                Add records to MATERIAL_COSTS
                to perform Cost Driver Analysis.
                """
            )
            st.stop()
        
        driver_df["UNIT_COST"] = driver_df["USED_COST"]
        
        if not driver_df.empty:
            driver_df["CONTRIBUTION_PCT"] = (
                driver_df["EXTENDED_COST"]
                /
                driver_df["EXTENDED_COST"].sum()
                * 100
            )
    
        driver_df = driver_df.sort_values("EXTENDED_COST", ascending=False)
        driver_df["CUMULATIVE_PCT"] = driver_df["CONTRIBUTION_PCT"].cumsum()
        
        major_drivers = driver_df[
            driver_df["CUMULATIVE_PCT"] <= 80
        ]
        
        if len(major_drivers) < len(driver_df):
            major_drivers = driver_df.iloc[:len(major_drivers)+1]
            
        k1, k2, k3, k4 = st.columns(4)
        
        with k1:
            top_driver = driver_df.iloc[0]
            display_metric_card(
                label="Highest Cost Driver",
                value=top_driver["COMPONENT_ID"],
                help_text="Component with the highest total cost"
            )
    
        with k2:
            display_metric_card(
                label="Cost Impact",
                value=f"{top_driver['CONTRIBUTION_PCT']:.1f}%",
                help_text="Percentage of total cost from top driver",
                delta=15 if top_driver['CONTRIBUTION_PCT'] > 30 else 0
            )
            
        with k3:
            display_metric_card(
                label="Cost Drivers",
                value=len(driver_df),
                help_text="Total number of cost drivers"
            )
        
        with k4:
            display_metric_card(
                label="Top 80% Drivers",
                value=len(major_drivers),
                help_text="Number of drivers accounting for 80% of cost",
                delta=-(len(major_drivers)) if len(major_drivers) > 5 else 5
            )
    
        premium_divider()
        
        premium_section(
            "Component Cost Breakdown",
            "Detailed cost analysis by component",
            "📊"
        )
    
        st.dataframe(
            driver_df[
                [
                    "COMPONENT_ID",
                    "UNITS",
                    "UNIT_COST",
                    "EXTENDED_COST",
                    "CONTRIBUTION_PCT",
                    "CUMULATIVE_PCT"
                ]
            ].rename(
                columns={
                    "COMPONENT_ID": "Component",
                    "UNITS": "Qty",
                    "UNIT_COST": "Unit Cost",
                    "EXTENDED_COST": "Extended Cost",
                    "CONTRIBUTION_PCT": "Contribution %",
                    "CUMULATIVE_PCT": "Cumulative %"
                }
            ),
            use_container_width=True
        )
        
        pareto_df = driver_df[
            [
                "COMPONENT_ID",
                "CONTRIBUTION_PCT"
            ]
        ]
    
        premium_divider()
    
        premium_section(
            "Cost Contribution by Component",
            "Visual distribution of costs",
            "📈"
        )
        
        st.bar_chart(
            pareto_df.set_index("COMPONENT_ID")
        )
        
        driver_names = (
            major_drivers["COMPONENT_ID"]
            .drop_duplicates()
            .tolist()
        )
        
        # Use content_card for key drivers summary
        content_card(
            value="Key Cost Drivers",
            label="Identified High-Impact Components",
            description=f"**{' • '.join(driver_names)}**\n\nCombined Cost Contribution: **{major_drivers['CONTRIBUTION_PCT'].sum():.1f}%**",
            status="warning" if len(major_drivers) > 5 else "success"
        )
    
    # =====================================================
    # TAB 7: SIMULATION
    # =====================================================
    with tab7:
        simulation_mode = st.radio(
            "Simulation Type",
            [
                "AI What-If Analysis",
                "Material Inflation",
                "Labor Inflation",
                "Manual Component Override",
                "Volume Discount",
                "Scenario Comparison"
            ]
        )
        if simulation_mode == "AI What-If Analysis":
            premium_section(
                "AI What-If Analysis",
                "Simulate changes in manufacturing conditions",
                "🤖"
            )
            st.info("Simulate changes in manufacturing conditions and observe how the AI recommendation changes.")
            
            premium_divider()
            
            supplier_change = st.slider(
                "Supplier Concentration (%)",
                0,
                100,
                int(features["supplier_concentration"] * 100)
            )
            
            routing_change = st.slider(
                "Routing Stress",
                0,
                100,
                int(dimensions["routing_stress"])
            )
    
            machine_change = st.slider(
                "Machine Health",
                0,
                100,
                int(features["machine_health"])
            )
            
            material_change = st.slider(
                "Material Risk",
                0,
                100,
                int(dimensions["material_risk"])
            )
    
            engineering_change = st.slider(
                "Engineering Stability",
                0,
                100,
                int(features["engineering_stability"])
            )
            
            scenario_features = features.copy()
            scenario_dimensions = dimensions.copy()
            
            # ----------------------------------------
            # Update scenario dimensions
            # ----------------------------------------
            
            scenario_dimensions["supplier_risk"] = supplier_change
            scenario_dimensions["routing_stress"] = routing_change
            scenario_dimensions["material_risk"] = material_change
            
            # ----------------------------------------
            # Update scenario features
            # ----------------------------------------
            
            scenario_features["supplier_concentration"] = supplier_change / 100
            scenario_features["machine_health"] = machine_change
            scenario_features["engineering_stability"] = engineering_change
            
            scale = material_change / max(dimensions["material_risk"], 1)
    
            scenario_features["weighted_price_change"] = (
                features["weighted_price_change"] * scale
            )
            
            # ----------------------------------------
            # Recalculate AI Scores
            # ----------------------------------------
            
            css_result = calculate_css(
                scenario_features,
                scenario_dimensions
            )
            
            scenario_css = css_result["css"]
            
            scenario_fmis = calculate_fmis(
                scenario_features,
                scenario_dimensions
            )
            
            tds_result = calculate_tds(
                scenario_features,
                scenario_dimensions
            )
            
            scenario_tds = tds_result["tds"]
            
            scenario_bmcs = calculate_bmcs(
                scenario_features,
                scenario_dimensions
            )
            
            scenario_quote = calculate_risk_adjusted_quote(
                material_cost,
                labor_cost,
                machine_cost,
                scenario_css,
                scenario_fmis,
                scenario_tds
            )
            scenario_decisions = ai_decision_engine(
                scenario_css,
                scenario_fmis,
                scenario_tds,
                scenario_bmcs
            )
    
            scenario_findings, scenario_recommendations = generate_ai_explanation(
                scenario_features,
                scenario_dimensions,
                scenario_css,
                scenario_fmis,
                scenario_tds,
                scenario_bmcs
            )
    
            scenario_name = st.text_input(
                "Scenario Name",
                value=f"Scenario {len(st.session_state.ai_scenarios)+1}"
            )
            
            if st.button("💾 Save AI Scenario"):
            
                st.session_state.ai_scenarios.append({
                    "Scenario": scenario_name,
                    "CSS": scenario_css,
                    "FMIS": scenario_fmis,
                    "TDS": scenario_tds,
                    "BMCS": scenario_bmcs,
                    "Quote": scenario_quote["recommended_quote"],
                    "Supplier Risk": scenario_dimensions["supplier_risk"],
                    "Routing Stress": scenario_dimensions["routing_stress"],
                    "Material Risk": scenario_dimensions["material_risk"],
                    "Machine Health": scenario_features["machine_health"],
                    "Engineering Stability": scenario_features["engineering_stability"]
                })
            
                st.success("AI Scenario saved.")
    
            c1, c2, c3, c4, c5 = st.columns(5)
    
            with c1:
                display_metric_card(
                    label="Configuration Scrap Score",
                    value=f"{scenario_css:.1f}%",
                    delta=round(scenario_css - css, 1),
                    help_text="Simulated scrap risk score"
                )
            
            with c2:
                display_metric_card(
                    label="Forward Material Index",
                    value=f"{scenario_fmis:.1f}%",
                    delta=round(scenario_fmis - fmis, 1),
                    help_text="Simulated material risk score"
                )
            
            with c3:
                display_metric_card(
                    label="Tooling Degradation Score",
                    value=f"{scenario_tds:.1f}%",
                    delta=round(scenario_tds - tds, 1),
                    help_text="Simulated tooling degradation score"
                )
            
            with c4:
                display_metric_card(
                    label="Recommended Quote",
                    value=format_currency(scenario_quote['recommended_quote']),
                    delta=scenario_quote['quote_increase'],
                    help_text="Simulated recommended customer quote"
                )
            
            with c5:
                display_metric_card(
                    label="Engineering Confidence",
                    value=f"{scenario_bmcs:.1f}%",
                    delta=round(scenario_bmcs - bmcs, 1),
                    help_text="Simulated engineering confidence score"
                )
    
            premium_section(
                "Quote Approval",
                "AI decision on quotation approval",
                "🚦"
            )
    
            col1, col2 = st.columns(2)
            
            with col1:
                content_card(
                    value=quote_label,
                    label="Current Approval",
                    description="Current AI decision status",
                    status="success" if quote_label == "Automatic Quote" else "warning" if quote_label == "Engineering Review" else "error"
                )
            
            with col2:
                content_card(
                    value=scenario_decisions["quote"],
                    label="Scenario Approval",
                    description="Simulated AI decision status",
                    status="success" if scenario_decisions["quote"] == "Automatic Quote" else "warning" if scenario_decisions["quote"] == "Engineering Review" else "error"
                )
    
            quote_difference = (scenario_quote["recommended_quote"] - recommended_quote)
            
            if quote_difference > 0:
                content_card(
                    value=f"${quote_difference:,.2f} Increase",
                    label="Quote Impact",
                    description="Recommended quote increases under simulation.",
                    status="warning"
                )
            elif quote_difference < 0:
                content_card(
                    value=f"${abs(quote_difference):,.2f} Decrease",
                    label="Quote Impact",
                    description="Recommended quote decreases under simulation.",
                    status="success"
                )
            else:
                content_card(
                    value="No Change",
                    label="Quote Impact",
                    description="Recommended quote remains unchanged.",
                    status="info"
                )
                
            premium_divider()
            
            premium_section(
                "AI Score Comparison",
                "Current vs. simulated AI metrics",
                "📊"
            )
            
            comparison_df = pd.DataFrame({
                "Metric":[
            
                    "Configuration Scrap Score",
            
                    "Forward Material Index",
            
                    "Tooling Degradation Score",
            
                    "Engineering Confidence",
            
                    "Quote Approval",
            
                    "Recommended Customer Quote"
            
                ],
            
                "Current":[
    
                    f"{css:.1f}%",
                
                    f"{fmis:.1f}%",
                
                    f"{tds:.1f}%",
                
                    f"{bmcs:.1f}%",
                
                    quote_label,
                
                    format_currency(recommended_quote)
                
                ],
            
                "Scenario":[
            
                    f"{scenario_css:.1f}%",
            
                    f"{scenario_fmis:.1f}%",
            
                    f"{scenario_tds:.1f}%",
            
                    f"{scenario_bmcs:.1f}%",
            
                    scenario_decisions["quote"],
            
                    format_currency(scenario_quote['recommended_quote'])
            
                ]
            
            })
            
            st.dataframe(
                comparison_df,
                use_container_width=True,
                hide_index=True
            )
    
            premium_divider()
    
            section_header(
                "AI Scenario Insights",
                "Detailed analysis of scenario impact",
                "🧠"
            )
            
            left, right = st.columns(2)
            
            with left:
            
                premium_section(
                    "Manufacturing Findings",
                    "Key observations from scenario analysis",
                    "🔍"
                )
            
                for finding in scenario_findings:
            
                    st.write(f"• {finding}")
            
            with right:
                premium_section(
                    "AI Recommendations",
                    "Actionable insights from scenario",
                    "💡"
                )
                for recommendation in scenario_recommendations:
            
                    st.write(f"✓ {recommendation}")
    
            premium_divider()
    
            section_header(
                "Executive Assessment",
                "Strategic recommendations and impact analysis",
                "📈"
            )
            
            if quote_difference > 0:
            
                st.warning(
            
                    f"""
            The simulated manufacturing conditions increase the recommended customer quote by **${quote_difference:,.2f}**.
            
            Primary drivers include supplier risk, routing complexity, machine health, engineering confidence and material market conditions.
    
            Current Quote Status: **{scenario_decisions['quote']}**
            
            Management should review sourcing and production planning before approving this configuration.
            """
                )
    
                approval_changed = (
                    quote_label != scenario_decisions["quote"]
                )
                if approval_changed:
                    st.warning(
                        f"""
                ### 🔄 Approval Workflow Changed
                
                **Current:** {quote_label}
                
                **Scenario:** {scenario_decisions["quote"]}
                """
                    )
            
            elif quote_difference < 0:
            
                st.success(
            
                    f"""
            The simulated scenario reduces the recommended quote by **${abs(quote_difference):,.2f}**.
            
            The AI predicts lower manufacturing risk, making the configuration more cost-efficient.
            """
                )
    
                approval_changed = (
                    quote_label != scenario_decisions["quote"]
                )
                if approval_changed:
                    st.warning(
                        f"""
                ### 🔄 Approval Workflow Changed
                
                **Current:** {quote_label}
                
                **Scenario:** {scenario_decisions["quote"]}
                """
                    )
            
            else:
            
                st.info(
            
                    """
            The simulated scenario has minimal impact on the recommended customer quote.
            
            Current manufacturing configuration remains optimal.
            """
                )
    
            comparison_chart = pd.DataFrame({
    
                "Scenario":[
            
                    "Current",
            
                    "What-If"
            
                ],
            
                "Quote":[
    
                    recommended_quote,
                
                    scenario_quote["recommended_quote"]
                
                ]
            
            })
            
            st.bar_chart(
                comparison_chart.set_index("Scenario")
            )
    
            premium_divider()
            
            premium_section(
                "Saved AI Scenarios",
                "All previously created scenarios",
                "📂"
            )
            
            if st.session_state.ai_scenarios:
            
                scenario_df = pd.DataFrame(
                    st.session_state.ai_scenarios
                )
            
                ranked_df = recommend_best_scenario(
                    scenario_df
                )
            
                display_df = ranked_df.rename(columns={
                    "CSS":"Scrap Risk (%)",
                    "FMIS":"Material Risk Score",
                    "TDS":"Tooling Score",
                    "BMCS":"Confidence (%)",
                    "Quote":"Recommended Quote ($)"
                })
                
                st.dataframe(
                    display_df,
                    use_container_width=True,
                    hide_index=True
                )
            
                premium_divider()
            
                best = ranked_df.iloc[0]
            
                premium_section(
                    "Recommended Manufacturing Scenario",
                    "AI-optimized configuration",
                    "🏆"
                )
            
                content_card(
                    value=best['Scenario'],
                    label="Scenario Name",
                    description=f"**Recommended Customer Quote:** ${best['Quote']:,.2f}\n\n**Overall Score:** {best['Overall Score']:.2f}",
                    status="success"
                )
            
                premium_section(
                    "Why was this selected?",
                    "Reasons for AI recommendation",
                    "🏆"
                )
            
                reasons = []
            
                if best["Quote"] == ranked_df["Quote"].min():
                    reasons.append("Lowest recommended customer quote.")
            
                if best["CSS"] == ranked_df["CSS"].min():
                    reasons.append("Lowest configuration scrap risk.")
            
                if best["Supplier Risk"] == ranked_df["Supplier Risk"].min():
                    reasons.append("Lowest supplier risk.")
            
                if best["BMCS"] == ranked_df["BMCS"].max():
                    reasons.append("Highest engineering confidence.")
    
                if best["Machine Health"] == ranked_df["Machine Health"].max():
                    reasons.append("Highest machine health.")
                
                if best["Engineering Stability"] == ranked_df["Engineering Stability"].max():
                    reasons.append("Most stable engineering configuration.")
            
                if not reasons:
                    reasons.append(
                        "Provides the best balance between cost and manufacturing risk."
                    )
            
                for reason in reasons:
                    st.write(f"✅ {reason}")
    
                premium_divider()
                
                premium_section(
                    "Executive Manufacturing Report",
                    "Comprehensive scenario analysis report",
                    "📄"
                )
    
                
                report = generate_executive_report(
                    selected,
                    ai_cost,
                    css,
                    fmis,
                    tds,
                    bmcs,
                    scenario_findings,
                    scenario_recommendations,  # FIXED: was 'recommendations'
                    ranked_df
                )
    
                st.text_area(
                    "Executive Report Preview",
                    report,
                    height=500
                )
    
                st.download_button(
                    "📥 Download Executive Report",
                    data=report,
                    file_name=f"{selected}_Executive_Report.txt",
                    mime="text/plain"
                )
            
            else:
            
                st.info(
                    "No AI scenarios saved yet."
                )
    
            
        elif material_df.empty:
            st.warning("No material data available for simulation")
        else:
            premium_section(
                "Material Cost Simulation",
                "Test different cost scenarios",
                "💰"
            )
    
            scenario_name = st.text_input(
                "Scenario Name",
                value="Scenario 1"
            )
            simulation_df = (
                material_df[
                    material_df["USED_COST"].notna()
                ]
                .groupby(
                    ["COMPONENT_ID", "USED_COST"],
                    as_index=False
                )
                .agg({
                    "UNITS": "sum",
                    "EXTENDED_COST": "sum"
                })
            )
            if simulation_mode == "Volume Discount":
                discount_pct = st.slider(
                    "Procurement Discount %",
                    0,
                    30,
                    10
                )
            
                simulation_df["NEW_UNIT_COST"] = (
                    simulation_df["USED_COST"]
                    *
                    (1 - discount_pct / 100)
                )
            
            elif simulation_mode == "Material Inflation":
                inflation_pct = st.slider(
                    "Material Inflation %",
                    0,
                    50,
                    10
                )
            
                simulation_df["NEW_UNIT_COST"] = (
                    simulation_df["USED_COST"]
                    *
                    (1 + inflation_pct / 100)
                )
            
            elif simulation_mode == "Labor Inflation":
                labor_inflation = st.slider(
                    "Labor Inflation %",
                    0,
                    50,
                    10
                )
            
                simulation_df["NEW_UNIT_COST"] = (
                    simulation_df["USED_COST"]
                )
            
            elif simulation_mode == "Manual Component Override":
                st.write(
                    "Adjust component costs manually"
                )
            
                new_costs = {}
            
                for idx, r in simulation_df.iterrows():
            
                    component = r["COMPONENT_ID"]
            
                    new_costs[component] = st.number_input(
                        f"{component} Unit Cost",
                        value=float(r["USED_COST"]),
                        min_value=0.0,
                        step=1.0,
                        key=f"sim_{component}_{idx}"
                    )
            
                simulation_df["NEW_UNIT_COST"] = (
                    simulation_df["COMPONENT_ID"]
                    .map(new_costs)
                )
            
            elif simulation_mode == "Scenario Comparison":
                material_inflation = st.slider(
                    "Material Inflation %",
                    0,
                    50,
                    10,
                    key="scenario_material"
                )
            
                labor_inflation = st.slider(
                    "Labor Inflation %",
                    0,
                    50,
                    5,
                    key="scenario_labor"
                )
            
                supplier_discount = st.slider(
                    "Supplier Discount %",
                    0,
                    30,
                    5,
                    key="scenario_supplier"
                )
            
                simulation_df["NEW_UNIT_COST"] = (
                    simulation_df["USED_COST"]
                    *
                    (1 + material_inflation/100)
                    *
                    (1 - supplier_discount/100)
                )
            
            simulation_df["NEW_EXTENDED_COST"] = (
                simulation_df["UNITS"]
                *
                simulation_df["NEW_UNIT_COST"]
            )
            
            simulated_material_cost = (
                simulation_df["NEW_EXTENDED_COST"]
                .sum()
            )
            
            if simulation_mode == "Labor Inflation":
                simulated_labor_cost = (
                    labor_cost
                    *
                    (1 + labor_inflation/100)
                )
            
            elif simulation_mode == "Scenario Comparison":
                simulated_labor_cost = (
                    labor_cost
                    *
                    (1 + labor_inflation/100)
                )
            
            else:
                simulated_labor_cost = labor_cost
            
            
            simulated_total_cost = (
                simulated_material_cost
                +
                simulated_labor_cost
                +
                machine_cost
            )
            
            impact_value = (
                simulated_total_cost
                -
                total_cost
            )
            
            impact_pct = (
                impact_value
                /
                total_cost
                * 100
            )
            
            
            premium_section(
                "Simulation Summary",
                "Cost impact of scenario changes",
                "📊"
            )
            
            s1, s2, s3, s4 = st.columns(4)
            
            with s1:
                display_metric_card(
                    label="Current Total Cost",
                    value=format_currency(total_cost),
                    help_text="Current manufacturing cost"
                )
            
            with s2:
                display_metric_card(
                    label="Simulated Cost",
                    value=format_currency(simulated_total_cost),
                    help_text="Simulated manufacturing cost"
                )
            
            with s3:
                display_metric_card(
                    label="Cost Impact",
                    value=format_currency(impact_value),
                    delta=round(impact_pct, 2),
                    help_text="Absolute cost impact"
                )
            
            with s4:
                display_metric_card(
                    label="Impact %",
                    value=f"{impact_pct:.2f}%",
                    help_text="Percentage cost impact"
                )
                
            if st.button("💾 Save Scenario"):
                st.session_state.saved_scenarios.append({
            
                    "Scenario": scenario_name,
            
                    "Material Cost": simulated_material_cost,
            
                    "Labor Cost": simulated_labor_cost,
            
                    "Machine Cost": machine_cost,
            
                    "Total Cost": simulated_total_cost,
            
                    "Impact %": impact_pct
            
                })
            
                st.success("Scenario saved.")
            
            st.divider()
    
            if impact_pct > 10:
                content_card(
                    value="High Cost Increase",
                    label="Impact Assessment",
                    description="High cost increase detected. Review material and labor assumptions.",
                    status="error"
                )
            elif impact_pct > 0:
                content_card(
                    value="Moderate Cost Increase",
                    label="Impact Assessment",
                    description="Moderate cost increase expected.",
                    status="warning"
                )
            elif impact_pct < 0:
                content_card(
                    value="Cost Savings Identified",
                    label="Impact Assessment",
                    description=f"Potential savings of {abs(impact_pct):.2f}% identified.",
                    status="success"
                )
            else:
                content_card(
                    value="No Impact",
                    label="Impact Assessment",
                    description="No material cost impact.",
                    status="info"
                )
            
            
            premium_section(
                "Updated Component Costs",
                "Revised cost structure under simulation",
                "💰"
            )
            
            st.dataframe(
                simulation_df[
                    [
                        "COMPONENT_ID",
                        "UNITS",
                        "USED_COST",
                        "NEW_UNIT_COST",
                        "EXTENDED_COST",
                        "NEW_EXTENDED_COST"
                    ]
                ],
                use_container_width=True
            )
            
            
            simulation_df["DELTA"] = (
                simulation_df["NEW_EXTENDED_COST"]
                -
                simulation_df["EXTENDED_COST"]
            )
            
            impact_df = (
                simulation_df
                .sort_values(
                    "DELTA",
                    ascending=False
                )
            )
            
            premium_section(
                "Component Cost Impact",
                "Individual component cost changes",
                "📈"
            )
            
            st.dataframe(
                impact_df[
                    [
                        "COMPONENT_ID",
                        "DELTA"
                    ]
                ],
                use_container_width=True
            )
            
            st.divider()
            
            premium_section(
                "Scenario Library",
                "Saved scenarios and comparison",
                "📚"
            )
            
            if st.session_state.saved_scenarios:
            
                compare_df = pd.DataFrame(
                    st.session_state.saved_scenarios
                )
            
                st.dataframe(
                    compare_df,
                    use_container_width=True
                )
            
                premium_section(
                    "Scenario Comparison",
                    "Visual comparison of scenarios",
                    "📊"
                )
            
                st.bar_chart(
                    compare_df.set_index("Scenario")["Total Cost"]
                )
            
                best = compare_df.loc[
                    compare_df["Total Cost"].idxmin()
                ]
            
                content_card(
                    value=best['Scenario'],
                    label="Best Scenario",
                    description=f"Estimated Cost: ${best['Total Cost']:,.2f}",
                    status="success"
                )
            
            else:
            
                st.info("No scenarios saved yet.")

    # =====================================================
    # TAB 8: DATA UPDATE
    # =====================================================
    with tab8:
        section_header(
            "Data Management",
            "Update operational manufacturing data used by AI scoring.",
            "🛠️"
        )
    
        col1, col2 = st.columns(2)
    
        with col1:
            st.metric("Product", selected)
    
        with col2:
            st.metric("Revision", revision)
    
        st.info(
            """
            Update operational data for this product.
    
            After clicking **Save Changes**, the dashboard will automatically
            refresh and all AI scores will be recalculated using the latest values.
            """
        )

        premium_divider()

        with st.form("data_management_form"):
            # Machine Health
            with st.expander("⚙ Machine Health", expanded=True):
                machine_df = session.sql(f"""
                    SELECT
                        MACHINE_ID,
                        PLANT_ID,
                        WORK_CENTER,
                        HEALTH_SCORE,
                        TEMPERATURE,
                        VIBRATION_LEVEL,
                        UTILIZATION_PERCENT,
                        BREAKDOWN_COUNT,
                        LAST_MAINTENANCE
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.MACHINE_HEALTH
                    ORDER BY MACHINE_ID
                """).to_pandas()
                
                if machine_df.empty:
                    st.info("No machine health records found for this product.")
                
                else:
                    edited_machine = []

                    for _, row in machine_df.iterrows():
                    
                        st.markdown(f"### 🔧 {row['MACHINE_ID']}")
                    
                        col1, col2 = st.columns(2)
                    
                        with col1:
                            health = st.slider(
                                "Health Score",
                                0.0,
                                100.0,
                                float(row["HEALTH_SCORE"]),
                                key=f"health_{row['MACHINE_ID']}"
                            )
                    
                            temperature = st.number_input(
                                "Temperature (°C)",
                                value=float(row["TEMPERATURE"]),
                                key=f"temp_{row['MACHINE_ID']}"
                            )
                    
                            vibration = st.number_input(
                                "Vibration Level",
                                value=float(row["VIBRATION_LEVEL"]),
                                key=f"vibration_{row['MACHINE_ID']}"
                            )
                    
                        with col2:
                            utilization = st.slider(
                                "Utilization (%)",
                                0.0,
                                100.0,
                                float(row["UTILIZATION_PERCENT"]),
                                key=f"util_{row['MACHINE_ID']}"
                            )
                    
                            breakdowns = st.number_input(
                                "Breakdown Count",
                                min_value=0,
                                value=int(row["BREAKDOWN_COUNT"]),
                                key=f"break_{row['MACHINE_ID']}"
                            )
                    
                            maintenance = st.date_input(
                                "Last Maintenance",
                                value=row["LAST_MAINTENANCE"],
                                key=f"maint_{row['MACHINE_ID']}"
                            )
                    
                        edited_machine.append({
                            "machine_id": row["MACHINE_ID"],
                            "health_score": health,
                            "temperature": temperature,
                            "vibration_level": vibration,
                            "utilization_percent": utilization,
                            "breakdown_count": breakdowns,
                            "last_maintenance": maintenance
                        })
                    
                        st.divider()
    
            # Production History
            with st.expander("🏭 Production History"):
                production_df = session.sql(f"""
                    SELECT
                        RUN_ID,
                        ITEM_ID,
                        ROUTING_ID,
                        OPERATOR_ID,
                        PRODUCED_QTY,
                        GOOD_QTY,
                        SCRAP_QTY,
                        START_TIME,
                        END_TIME
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.PRODUCTION_HISTORY
                    WHERE ITEM_ID = '{selected}'
                    ORDER BY START_TIME DESC
                """).to_pandas()
                
                if production_df.empty:
                    st.info("No production history found for this product.")
                else:
                    edited_production = []
                
                    for _, row in production_df.iterrows():
                
                        st.markdown(f"### 🏭 Run {row['RUN_ID']}")
                        st.caption(
                            f"Operator: {row['OPERATOR_ID']} | Routing: {row['ROUTING_ID']}"
                        )
                
                        col1, col2 = st.columns(2)

                        with col1:
                            produced = st.number_input(
                                "Produced Qty",
                                min_value=0,
                                value=int(row["PRODUCED_QTY"]),
                                key=f"prod_{row['RUN_ID']}"
                            )
                        
                            good = st.number_input(
                                "Good Qty",
                                min_value=0,
                                value=int(row["GOOD_QTY"]),
                                key=f"good_{row['RUN_ID']}"
                            )
                        
                            scrap = st.number_input(
                                "Scrap Qty",
                                min_value=0,
                                value=int(row["SCRAP_QTY"]),
                                key=f"scrap_{row['RUN_ID']}"
                            )
                        
                        with col2:
                            st.metric("Start Time", str(row["START_TIME"]))
                            st.metric("End Time", str(row["END_TIME"]))
                
                        edited_production.append({
                            "run_id": row["RUN_ID"],
                            "produced_qty": produced,
                            "good_qty": good,
                            "scrap_qty": scrap,
                        })
                
                        st.divider()
    
            # Quality History
            with st.expander("✅ Quality History"):
                production_quality_df = session.sql(f"""
                    SELECT
                        BATCH_ID,
                        ITEM_ID,
                        DEFECT_CATEGORY,
                        DEFECT_RATE,
                        FIRST_PASS_YIELD,
                        PRODUCTION_DATE,
                        SCRAP_RATE,
                        UNITS_PRODUCED,
                        UNITS_PASSED,
                        UNITS_REJECTED,
                        UNITS_REWORKED
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_HISTORY
                    WHERE ITEM_ID = '{selected}'
                    ORDER BY PRODUCTION_DATE DESC
                """).to_pandas()

                if production_quality_df.empty:
                    st.info("No quality history found for this product.")

                else:
                    edited_quality = []
                
                    for _, row in production_quality_df.iterrows():
                
                        st.markdown(f"### ✅ Batch {row['BATCH_ID']}")
                        st.caption(f"Defect Category: {row['DEFECT_CATEGORY']}")
                
                        col1, col2 = st.columns(2)
                
                        with col1:
                
                            produced = st.number_input(
                                "Units Produced",
                                min_value=0,
                                value=int(row["UNITS_PRODUCED"]),
                                key=f"q_prod_{row['BATCH_ID']}"
                            )
                
                            passed = st.number_input(
                                "Units Passed",
                                min_value=0,
                                value=int(row["UNITS_PASSED"]),
                                key=f"q_pass_{row['BATCH_ID']}"
                            )
                
                            rejected = st.number_input(
                                "Units Rejected",
                                min_value=0,
                                value=int(row["UNITS_REJECTED"]),
                                key=f"q_reject_{row['BATCH_ID']}"
                            )
                
                            reworked = st.number_input(
                                "Units Reworked",
                                min_value=0,
                                value=int(row["UNITS_REWORKED"]),
                                key=f"q_rework_{row['BATCH_ID']}"
                            )
                
                        with col2:
                
                            defect_rate = st.number_input(
                                "Defect Rate",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["DEFECT_RATE"]),
                                key=f"q_defect_{row['BATCH_ID']}"
                            )
                
                            first_pass = st.number_input(
                                "First Pass Yield",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["FIRST_PASS_YIELD"]),
                                key=f"q_fpy_{row['BATCH_ID']}"
                            )
                
                            scrap_rate = st.number_input(
                                "Scrap Rate",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["SCRAP_RATE"]),
                                key=f"q_scrap_{row['BATCH_ID']}"
                            )
                
                            production_date = st.date_input(
                                "Production Date",
                                value=row["PRODUCTION_DATE"],
                                key=f"q_date_{row['BATCH_ID']}"
                            )
                
                        edited_quality.append({
                            "batch_id": row["BATCH_ID"],
                            "units_produced": produced,
                            "units_passed": passed,
                            "units_rejected": rejected,
                            "units_reworked": reworked,
                            "defect_rate": defect_rate,
                            "first_pass_yield": first_pass,
                            "scrap_rate": scrap_rate,
                            "production_date": production_date
                        })
                
                        st.divider()
    
            # Supplier Performance
            with st.expander("🚚 Supplier Performance"):
            
                supplier_df = session.sql("""
                    SELECT
                        SUPPLIER_ID,
                        DELIVERY_DATE,
                        ON_TIME_PERCENT,
                        QUALITY_SCORE,
                        DEFECT_RATE,
                        LOT_ACCEPTANCE_RATE
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.SUPPLIER_PERFORMANCE
                    ORDER BY DELIVERY_DATE DESC
                """).to_pandas()
            
                if supplier_df.empty:
                    st.info("No supplier performance records found.")
            
                else:
            
                    edited_supplier = []
            
                    for _, row in supplier_df.iterrows():
            
                        st.markdown(f"### 🚚 Supplier {row['SUPPLIER_ID']}")
            
                        col1, col2 = st.columns(2)
            
                        with col1:
            
                            on_time = st.number_input(
                                "On-Time Delivery (%)",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["ON_TIME_PERCENT"]),
                                key=f"ontime_{row['SUPPLIER_ID']}_{row['DELIVERY_DATE']}"
                            )
            
                            quality = st.number_input(
                                "Quality Score",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["QUALITY_SCORE"]),
                                key=f"quality_{row['SUPPLIER_ID']}_{row['DELIVERY_DATE']}"
                            )
            
                        with col2:
            
                            defect = st.number_input(
                                "Defect Rate",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["DEFECT_RATE"]),
                                key=f"defect_{row['SUPPLIER_ID']}_{row['DELIVERY_DATE']}"
                            )
            
                            acceptance = st.number_input(
                                "Lot Acceptance Rate",
                                min_value=0.0,
                                max_value=100.0,
                                value=float(row["LOT_ACCEPTANCE_RATE"]),
                                key=f"accept_{row['SUPPLIER_ID']}_{row['DELIVERY_DATE']}"
                            )
            
                            delivery = st.date_input(
                                "Delivery Date",
                                value=row["DELIVERY_DATE"],
                                key=f"delivery_{row['SUPPLIER_ID']}_{row['DELIVERY_DATE']}"
                            )
            
                        edited_supplier.append({
                            "supplier_id": row["SUPPLIER_ID"],
                            "delivery_date": delivery,
                            "on_time_percent": on_time,
                            "quality_score": quality,
                            "defect_rate": defect,
                            "lot_acceptance_rate": acceptance
                        })
            
                        st.divider()
                
    
            # Material Properties
            with st.expander("📦 Material Properties"):
                material_df = session.sql(f"""
                    SELECT
                        ITEM_ID,
                        MATERIAL_TYPE,
                        CRITICALITY,
                        TOLERANCE_CLASS,
                        DENSITY,
                        HARDNESS,
                        FRAGILITY_SCORE
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.MATERIAL_PROPERTIES
                    WHERE ITEM_ID = '{selected}'
                """).to_pandas()
            
                if material_df.empty:
                    st.info("No material properties found for this product.")
            
                else:
                    edited_material = []
            
                    for _, row in material_df.iterrows():
            
                        st.markdown(f"### 📦 {row['ITEM_ID']}")
                        st.caption(
                            f"Material Type: {row['MATERIAL_TYPE']} | "
                            f"Criticality: {row['CRITICALITY']} | "
                            f"Tolerance Class: {row['TOLERANCE_CLASS']}"
                        )
            
                        col1, col2 = st.columns(2)
            
                        with col1:
            
                            density = st.number_input(
                                "Density",
                                min_value=0.0,
                                value=float(row["DENSITY"]),
                                key=f"density_{row['ITEM_ID']}"
                            )
            
                        with col2:
            
                            hardness = st.number_input(
                                "Hardness",
                                min_value=0.0,
                                value=float(row["HARDNESS"]),
                                key=f"hardness_{row['ITEM_ID']}"
                            )
            
                            fragility = st.slider(
                                "Fragility Score",
                                0.0,
                                100.0,
                                float(row["FRAGILITY_SCORE"]),
                                key=f"fragility_{row['ITEM_ID']}"
                            )
            
                        edited_material.append({
                            "item_id": row["ITEM_ID"],
                            "density": density,
                            "hardness": hardness,
                            "fragility_score": fragility
                        })
            
                        st.divider()
    
            # Engineering Changes
            with st.expander("📝 Engineering Changes"):
            
                ecn_df = session.sql(f"""
                    SELECT
                        ECN_ID,
                        ITEM_ID,
                        REVISION,
                        CHANGE_REASON,
                        CHANGE_DATE,
                        AFFECTED_COMPONENTS
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ENGINEERING_CHANGE
                    WHERE ITEM_ID = '{selected}'
                    ORDER BY CHANGE_DATE DESC
                """).to_pandas()
            
                if ecn_df.empty:
                    st.info("No engineering changes found for this product.")
            
                else:
            
                    edited_ecn = []
            
                    for _, row in ecn_df.iterrows():
            
                        st.markdown(f"### 📝 {row['ECN_ID']}")
                        st.caption(f"Revision: {row['REVISION']}")
            
                        col1, col2 = st.columns(2)
            
                        with col1:
            
                            affected = st.number_input(
                                "Affected Components",
                                min_value=0,
                                value=int(row["AFFECTED_COMPONENTS"]),
                                key=f"affected_{row['ECN_ID']}"
                            )
            
                            change_date = st.date_input(
                                "Change Date",
                                value=row["CHANGE_DATE"],
                                key=f"date_{row['ECN_ID']}"
                            )
            
                        with col2:
            
                            reason = st.text_area(
                                "Change Reason",
                                value=row["CHANGE_REASON"],
                                key=f"reason_{row['ECN_ID']}"
                            )
            
                        edited_ecn.append({
                            "ecn_id": row["ECN_ID"],
                            "affected_components": affected,
                            "change_date": change_date,
                            "change_reason": reason
                        })
            
                        st.divider()
    
            # Inventory History
            with st.expander("📊 Inventory History"):
            
                inventory_df = session.sql(f"""
                    SELECT
                        ITEM_ID,
                        STOCK_QTY,
                        SAFETY_STOCK,
                        DAYS_OF_COVER,
                        CREATED_AT
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.INVENTORY_HISTORY
                    WHERE ITEM_ID = '{selected}'
                """).to_pandas()
            
                if inventory_df.empty:
                    st.info("No inventory history found for this product.")
            
                else:
            
                    edited_inventory = []
            
                    for _, row in inventory_df.iterrows():
            
                        st.markdown(f"### 📦 {row['ITEM_ID']}")
            
                        col1, col2 = st.columns(2)
            
                        with col1:
            
                            stock = st.number_input(
                                "Stock Quantity",
                                min_value=0,
                                value=int(row["STOCK_QTY"]),
                                key=f"stock_{row['ITEM_ID']}"
                            )
            
                            safety = st.number_input(
                                "Safety Stock",
                                min_value=0,
                                value=int(row["SAFETY_STOCK"]),
                                key=f"safety_{row['ITEM_ID']}"
                            )
            
                        with col2:
            
                            days = st.number_input(
                                "Days of Cover",
                                min_value=0.0,
                                value=float(row["DAYS_OF_COVER"]),
                                key=f"cover_{row['ITEM_ID']}"
                            )
            
                            st.metric(
                                "Created At",
                                str(row["CREATED_AT"])
                            )
            
                        edited_inventory.append({
                            "item_id": row["ITEM_ID"],
                            "stock_qty": stock,
                            "safety_stock": safety,
                            "days_of_cover": days
                        })
            
                        st.divider()
    
            # Quality Inspection
            with st.expander("🔍 Quality Inspection"):
            
                inspection_df = session.sql(f"""
                    SELECT
                        INSPECTION_ID,
                        ITEM_ID,
                        OPERATION_ID,
                        INSPECTION_STAGE,
                        INSPECTOR,
                        DEFECT_TYPE,
                        RESULT,
                        CREATED_AT
                    FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_INSPECTION
                    WHERE ITEM_ID = '{selected}'
                    ORDER BY CREATED_AT DESC
                """).to_pandas()
            
                if inspection_df.empty:
                    st.info("No quality inspection records found.")
            
                else:
            
                    edited_inspection = []
            
                    for _, row in inspection_df.iterrows():
            
                        st.markdown(f"### 🔍 Inspection {row['INSPECTION_ID']}")
                        st.caption(
                            f"Stage: {row['INSPECTION_STAGE']} | "
                            f"Inspector: {row['INSPECTOR']}"
                        )
            
                        col1, col2 = st.columns(2)
            
                        with col1:
            
                            defect = st.text_input(
                                "Defect Type",
                                value=row["DEFECT_TYPE"],
                                key=f"defect_{row['INSPECTION_ID']}"
                            )
            
                            result = st.selectbox(
                                "Inspection Result",
                                ["PASS", "FAIL", "REWORK"],
                                index=["PASS", "FAIL", "REWORK"].index(row["RESULT"]),
                                key=f"result_{row['INSPECTION_ID']}"
                            )
            
                        with col2:
            
                            st.metric("Operation", row["OPERATION_ID"])
                            st.metric("Created At", str(row["CREATED_AT"]))
            
                        edited_inspection.append({
                            "inspection_id": row["INSPECTION_ID"],
                            "defect_type": defect,
                            "result": result
                        })
            
                        st.divider()
    
            submitted = st.form_submit_button(
                "💾 Save Changes",
                use_container_width=True
            )

            if submitted:
                try:
                    for machine in edited_machine:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.MACHINE_HEALTH
                            SET
                                HEALTH_SCORE = {machine["health_score"]},
                                TEMPERATURE = {machine["temperature"]},
                                VIBRATION_LEVEL = {machine["vibration_level"]},
                                UTILIZATION_PERCENT = {machine["utilization_percent"]},
                                BREAKDOWN_COUNT = {machine["breakdown_count"]},
                                LAST_MAINTENANCE = '{machine["last_maintenance"]}'
                            WHERE MACHINE_ID = '{machine["machine_id"]}'
                        """).collect()

                    for production in edited_production:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.PRODUCTION_HISTORY
                            SET
                                PRODUCED_QTY = {production["produced_qty"]},
                                GOOD_QTY = {production["good_qty"]},
                                SCRAP_QTY = {production["scrap_qty"]},
                            WHERE RUN_ID = '{production["run_id"]}'
                        """).collect()

                    for quality in edited_quality:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_HISTORY
                            SET
                                UNITS_PRODUCED = {quality["units_produced"]},
                                UNITS_PASSED = {quality["units_passed"]},
                                UNITS_REJECTED = {quality["units_rejected"]},
                                UNITS_REWORKED = {quality["units_reworked"]},
                                DEFECT_RATE = {quality["defect_rate"]},
                                FIRST_PASS_YIELD = {quality["first_pass_yield"]},
                                SCRAP_RATE = {quality["scrap_rate"]},
                                PRODUCTION_DATE = '{quality["production_date"]}'
                            WHERE BATCH_ID = '{quality["batch_id"]}'
                        """).collect()

                    for supplier in edited_supplier:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.SUPPLIER_PERFORMANCE
                            SET
                                DELIVERY_DATE = '{supplier["delivery_date"]}',
                                ON_TIME_PERCENT = {supplier["on_time_percent"]},
                                QUALITY_SCORE = {supplier["quality_score"]},
                                DEFECT_RATE = {supplier["defect_rate"]},
                                LOT_ACCEPTANCE_RATE = {supplier["lot_acceptance_rate"]}
                            WHERE SUPPLIER_ID = '{supplier["supplier_id"]}'
                        """).collect()

                    for material in edited_material:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.MATERIAL_PROPERTIES
                            SET
                                DENSITY = {material["density"]},
                                HARDNESS = {material["hardness"]},
                                FRAGILITY_SCORE = {material["fragility_score"]}
                            WHERE ITEM_ID = '{material["item_id"]}'
                        """).collect()

                    for ecn in edited_ecn:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.ENGINEERING_CHANGE
                            SET
                                AFFECTED_COMPONENTS = {ecn["affected_components"]},
                                CHANGE_DATE = '{ecn["change_date"]}',
                                CHANGE_REASON = '{ecn["change_reason"]}'
                            WHERE ECN_ID = '{ecn["ecn_id"]}'
                        """).collect()

                    for inventory in edited_inventory:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.INVENTORY_HISTORY
                            SET
                                STOCK_QTY = {inventory["stock_qty"]},
                                SAFETY_STOCK = {inventory["safety_stock"]},
                                DAYS_OF_COVER = {inventory["days_of_cover"]}
                            WHERE ITEM_ID = '{inventory["item_id"]}'
                        """).collect()

                    for inspection in edited_inspection:
                        session.sql(f"""
                            UPDATE DISCRETE_MFG_COST_MODEL.CORE_INPUT.QUALITY_INSPECTION
                            SET
                                DEFECT_TYPE = '{inspection["defect_type"]}',
                                RESULT = '{inspection["result"]}'
                            WHERE INSPECTION_ID = '{inspection["inspection_id"]}'
                        """).collect()
            
                    session.sql("COMMIT").collect()
            
                    st.success("Data updated successfully!")
            
                    st.rerun()
            
                except Exception as e:
                    st.error(f"Update failed: {e}")

            
    # =====================================================
    # TAB 9: DATA ONBOARDING
    # =====================================================
    with tab9:
        section_header(
            "Data Onboarding",
            "Upload and validate manufacturing data",
            "📊"
        )
        mode = st.radio(
            "Choose Input Method",
            [
                "Upload File",
                "Manual Entry"
            ]
        )
    
        if mode == "Upload File":
            uploaded_file = st.file_uploader(
                "Upload CSV or Excel",
                type=["csv","xlsx"],
                key="bom_upload"
            )
            
            # Read only once
            if uploaded_file is not None:
                if uploaded_file.name.endswith(".csv"):
                    st.session_state["uploaded_df"] = pd.read_csv(uploaded_file)
                else:
                    st.session_state["uploaded_df"] = pd.read_excel(uploaded_file)
            
                st.session_state["uploaded_filename"] = uploaded_file.name
            
            # Stop only if nothing has ever been uploaded
            if "uploaded_df" not in st.session_state:
                st.info("Upload a BOM file to continue.")
                st.stop()
            
            df = st.session_state["uploaded_df"]
            filename = st.session_state["uploaded_filename"]
            
            premium_section(
                "Preview",
                "First 5 rows of uploaded data",
                "🔍"
            )
            st.dataframe(df.head())
    
            premium_divider()
            
            premium_section(
                "Detected Columns",
                "AI-detected column mapping",
                "📋"
            )
            st.write(df.columns.tolist())
    
            premium_divider()
            
            mapping = suggest_mapping(
                df.columns.tolist()
            )
            
            premium_section(
                "AI Mapping Result",
                "Automated column mapping confidence",
                "🤖"
            )
                
            st.json(mapping)
                
            mapped_fields = len(mapping)
                
            confidence = (
                mapped_fields / 3
            ) * 100
            
            # Use content_card for mapping confidence
            if confidence >= 90:
                content_card(
                    value=f"Mapping Confidence: {confidence:.0f}%",
                    label="High",
                    description="All required columns successfully mapped",
                    status="success"
                )
            elif confidence >= 60:
                content_card(
                    value=f"Mapping Confidence: {confidence:.0f}%",
                    label="Medium",
                    description="Some columns require manual mapping",
                    status="warning"
                )
            else:
                content_card(
                    value=f"Mapping Confidence: {confidence:.0f}%",
                    label="Low",
                    description="Most columns need manual mapping",
                    status="error"
                )
    
            parent_default = (
                df.columns.tolist().index(
                    mapping["PARENT_ID"]
                )
                if mapping.get("PARENT_ID") in df.columns
                else 0
            )
            
            component_default = (
                df.columns.tolist().index(
                    mapping["COMPONENT_ID"]
                )
                if mapping.get("COMPONENT_ID") in df.columns
                else 0
            )
            
            qty_default = (
                df.columns.tolist().index(
                    mapping["QUANTITY"]
                )
                if mapping.get("QUANTITY") in df.columns
                else 0
            )
            
            parent_col = st.selectbox(
                "Parent Column",
                df.columns,
                index=parent_default
            )
            
            component_col = st.selectbox(
                "Component Column",
                df.columns,
                index=component_default
            )
            
            qty_col = st.selectbox(
                "Quantity Column",
                df.columns,
                index=qty_default
            )
            upload_revision = st.text_input(
                "Revision",
                value="REV_A"
            )
    
            effective_from = st.date_input(
                "Effective From"
            )
            
            effective_to_enabled = st.checkbox(
                "Has End Date",
                value=False
            )
            effective_to = None
            if effective_to_enabled:
                effective_to = st.date_input(
                    "Effective To"
                )
    
            canonical_df = pd.DataFrame({
                "BOM_ID":
                    [
                        f"UPLOAD_{i+1}"
                        for i in range(len(df))
                    ],
            
                "PARENT_ID":
                    df[parent_col],
            
                "COMPONENT_ID":
                    df[component_col],
            
                "QUANTITY":
                    df[qty_col],
            
                "UOM":
                    ["EA"] * len(df),
            
                "REVISION":
                    [upload_revision] * len(df),
            
                "PLANT_ID":
                    ["PLANT_A"] * len(df),
            
                "EFFECTIVE_FROM":
                    [effective_from] * len(df),
                
                "EFFECTIVE_TO":
                    [effective_to] * len(df),
            })
    
            rows_uploaded = len(df)
            missing_parents = (
                canonical_df["PARENT_ID"]
                .isna()
                .sum()
            )
            
            missing_components = (
                canonical_df["COMPONENT_ID"]
                .isna()
                .sum()
            )
            
            missing_qty = (
                canonical_df["QUANTITY"]
                .isna()
                .sum()
            )
            
            premium_divider()
            
            premium_section(
                "Validation Summary",
                "Data validation results",
                "✅"
            )
            
            v1, v2, v3, v4 = st.columns(4)
            
            with v1:
                display_metric_card(
                    label="Rows Uploaded",
                    value=rows_uploaded,
                    help_text="Total rows uploaded"
                )
            
            with v2:
                # Missing Parents - lower is better
                missing_parents_delta = -20 if missing_parents > 0 else 20
                display_metric_card(
                    label="Missing Parents",
                    value=missing_parents,
                    delta=missing_parents_delta,
                    help_text="Rows missing parent ID"
                )
            
            with v3:
                # Missing Components - lower is better
                missing_components_delta = -20 if missing_components > 0 else 20
                display_metric_card(
                    label="Missing Components",
                    value=missing_components,
                    delta=missing_components_delta,
                    help_text="Rows missing component ID"
                )
            
            with v4:
                # Missing Quantities - lower is better
                missing_qty_delta = -20 if missing_qty > 0 else 20
                display_metric_card(
                    label="Missing Quantities",
                    value=missing_qty,
                    delta=missing_qty_delta,
                    help_text="Rows missing quantity"
                )
    
            premium_divider()
            
            premium_section(
                "Canonical Preview",
                "Standardized BOM format",
                "📋"
            )
            
            d1, d2 = st.columns(2)
    
            with d1:
                content_card(
                    value=str(effective_from),
                    label="Effective From",
                    description="Start date of BOM validity"
                )
            
            with d2:
                content_card(
                    value=str(effective_to) if effective_to else "Open Ended",
                    label="Effective To",
                    description="End date of BOM validity"
                )
            
            st.dataframe(
                canonical_df,
                use_container_width=True
            )
    
            premium_divider()
            
            # ==========================================
            # DUPLICATE CHECK
            # ==========================================
            
            existing_bom = session.sql("""
            SELECT
                PARENT_ID,
                COMPONENT_ID,
                REVISION,
                EFFECTIVE_FROM
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
            """).to_pandas()
            
            upload_check = canonical_df[
                [
                    "PARENT_ID",
                    "COMPONENT_ID",
                    "REVISION",
                    "EFFECTIVE_FROM"
                ]
            ]
            
            duplicates = upload_check.merge(
                existing_bom,
                on=[
                    "PARENT_ID",
                    "COMPONENT_ID",
                    "REVISION",
                    "EFFECTIVE_FROM"
                ],
                how="inner"
            )
            
            duplicate_count = len(duplicates)
            
            premium_section(
                "Duplicate Check",
                "Prevent duplicate BOM records",
                "🔄"
            )
            
            d1, d2 = st.columns(2)
            
            with d1:
                display_metric_card(
                    label="Uploaded Records",
                    value=len(upload_check),
                    help_text="Total records to upload"
                )
            
            with d2:
                # Duplicate Records - lower is better
                duplicate_delta = -20 if duplicate_count > 0 else 20
                display_metric_card(
                    label="Duplicate Records",
                    value=duplicate_count,
                    delta=duplicate_delta,
                    help_text="Records already existing in database"
                )
            
            if duplicate_count > 0:
                content_card(
                    value=f"{duplicate_count} duplicate BOM records detected",
                    label="Duplicate Alert",
                    description="These records already exist in the database",
                    status="warning"
                )
                st.dataframe(
                    duplicates,
                    use_container_width=True
                )
    
            can_load = (
                missing_parents == 0
                and
                missing_components == 0
                and
                missing_qty == 0
                and
                duplicate_count == 0
            )
            
            if st.button("Load Data"):
                if not can_load:
                    st.error("Cannot load until validation passes.")
                    st.stop()
                session.write_pandas(
                    canonical_df,
                    "BOM_STRUCTURE",
                    database="DISCRETE_MFG_COST_MODEL",
                    schema="CORE_INPUT",
                    auto_create_table=False
                )
    
                load_id = str(uuid.uuid4())
    
                session.sql(f"""
                INSERT INTO
                DISCRETE_MFG_COST_MODEL.CORE_INPUT.DATA_LOAD_AUDIT
                (
                    LOAD_ID,
                    TABLE_NAME,
                    RECORD_COUNT,
                    LOAD_TIME,
                    STATUS,
                    FILE_NAME,
                    REVISION,
                    EFFECTIVE_FROM,
                    EFFECTIVE_TO
                )
                VALUES
                (
                    '{load_id}',
                    'BOM_STRUCTURE',
                    {len(canonical_df)},
                    CURRENT_TIMESTAMP,
                    'SUCCESS',
                    '{st.session_state["uploaded_filename"]}',
                    '{upload_revision}',
                    '{effective_from}',
                    {f"'{effective_to}'" if effective_to else "NULL"}
                )
                """).collect()
            
                st.success(
                    "Load Completed Successfully"
                )
                st.info(
                    f"Load ID: {load_id}"
                )
                st.session_state["load_complete"] = True
                st.rerun()
    
            premium_divider()
            
            premium_section(
                "Load Summary",
                "Data loading completion status",
                "📊"
            )
            
            l1, l2, l3, l4 = st.columns(4)
            
            with l1:
                display_metric_card(
                    label="Rows Loaded",
                    value=len(canonical_df),
                    help_text="Total rows loaded to database"
                )
            
            with l2:
                display_metric_card(
                    label="Target Table",
                    value="BOM_STRUCTURE",
                    help_text="Database table loaded"
                )
            
            with l3:
                display_metric_card(
                    label="Status",
                    value="SUCCESS" if can_load else "FAILED",
                    help_text="Load status",
                    delta=10 if can_load else -10
                )
                
            with l4:
                display_metric_card(
                    label="Revision",
                    value=upload_revision,
                    help_text="Revision loaded"
                )
    
            premium_divider()
    
            premium_section(
                "Recent Loads",
                "Historical data load audit",
                "📋"
            )
            
            audit_df = session.sql("""
            SELECT
                LOAD_ID,
                TABLE_NAME,
                RECORD_COUNT,
                LOAD_TIME,
                STATUS,
                FILE_NAME,
                REVISION
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.DATA_LOAD_AUDIT
            ORDER BY LOAD_TIME DESC
            LIMIT 10
            """).to_pandas()
            
            st.dataframe(
                audit_df,
                use_container_width=True
            )
            
            premium_divider()
            
            premium_section(
                "Item Master Validation",
                "Verify items exist in master data",
                "🔍"
            )
            
            uploaded_items = pd.concat([
                canonical_df["PARENT_ID"],
                canonical_df["COMPONENT_ID"]
            ]).drop_duplicates()
            
            existing_items = session.sql("""
            SELECT ITEM_ID
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ITEM_MASTER
            """).to_pandas()
            
            missing_items = (
                set(uploaded_items)
                -
                set(existing_items["ITEM_ID"])
            )
            
            c1, c2, c3 = st.columns(3)
            
            with c1:
                display_metric_card(
                    label="Items Uploaded",
                    value=len(uploaded_items),
                    help_text="Total items in uploaded data"
                )
            
            with c2:
                display_metric_card(
                    label="Existing Items",
                    value=len(uploaded_items) - len(missing_items),
                    help_text="Items already in master data"
                )
            
            with c3:
                # New Items - lower is better for validation
                missing_items_delta = -15 if len(missing_items) > 10 else 0 if len(missing_items) > 0 else 15
                display_metric_card(
                    label="New Items",
                    value=len(missing_items),
                    delta=missing_items_delta,
                    help_text="New items to be added to master data"
                )
            
            if missing_items:
                content_card(
                    value=f"{len(missing_items)} items missing from ITEM_MASTER",
                    label="Master Data Gap",
                    description="These items need to be added to the Item Master",
                    status="error"
                )
                st.dataframe(
                    pd.DataFrame({
                        "ITEM_ID": list(missing_items)
                    }),
                    use_container_width=True
                )
            else:
                content_card(
                    value="All items exist in ITEM_MASTER",
                    label="Validation Passed",
                    description="No missing master data items",
                    status="success"
                )
            
            # ==========================================
            # MATERIAL COST VALIDATION
            # ==========================================
            
            premium_divider()
            
            premium_section(
                "Material Cost Validation",
                "Verify cost records for all components",
                "💰"
            )
            
            cost_items = session.sql("""
            SELECT ITEM_ID
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.MATERIAL_COSTS
            """).to_pandas()
            
            cost_items["ITEM_ID"] = (
                cost_items["ITEM_ID"]
                .astype(str)
                .str.strip()
                .str.upper()
            )
            
            uploaded_items_set = {
                str(x).strip().upper()
                for x in uploaded_items
            }
            
            cost_item_set = set(
                cost_items["ITEM_ID"]
            )
            
            missing_cost_items = (
                uploaded_items_set
                -
                cost_item_set
            )
            
            m1, m2, m3 = st.columns(3)
            
            with m1:
                display_metric_card(
                    label="Items Uploaded",
                    value=len(uploaded_items_set),
                    help_text="Total items in uploaded data"
                )
            
            with m2:
                display_metric_card(
                    label="Items With Costs",
                    value=len(uploaded_items_set) - len(missing_cost_items),
                    help_text="Items with material cost records"
                )
            
            with m3:
                # Missing Cost Records - lower is better
                missing_cost_delta = -20 if len(missing_cost_items) > 10 else -10 if len(missing_cost_items) > 0 else 20
                display_metric_card(
                    label="Missing Cost Records",
                    value=len(missing_cost_items),
                    delta=missing_cost_delta,
                    help_text="Items missing material cost data"
                )
            
            if missing_cost_items:
                content_card(
                    value=f"{len(missing_cost_items)} items missing material cost records",
                    label="Cost Data Gap",
                    description="These items need material cost records",
                    status="warning"
                )
                st.dataframe(
                    pd.DataFrame({
                        "ITEM_ID": list(missing_cost_items)
                    }),
                    use_container_width=True
                )
            else:
                content_card(
                    value="All items have material costs",
                    label="Validation Passed",
                    description="Complete material cost coverage",
                    status="success"
                )
            
            cost_completeness = (
                (
                    len(uploaded_items_set)
                    -
                    len(missing_cost_items)
                )
                /
                len(uploaded_items_set)
            ) * 100
            
            st.progress(
                cost_completeness / 100
            )
            
            st.caption(
                f"Cost Coverage: {cost_completeness:.1f}%"
            )
            
            # ==========================================
            # ROUTING VALIDATION
            # ==========================================
            
            premium_divider()
            
            premium_section(
                "Routing Validation",
                "Verify routing definitions for products",
                "🗺️"
            )
            
            routing_items = session.sql("""
            SELECT DISTINCT ITEM_ID
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.ROUTING_OPERATIONS
            """).to_pandas()
            
            routing_set = set(
                routing_items["ITEM_ID"]
            )
            
            top_level_products = set(
                canonical_df["PARENT_ID"]
            )
            
            missing_routing = (
                top_level_products
                -
                routing_set
            )
            
            r1, r2, r3 = st.columns(3)
            
            with r1:
                display_metric_card(
                    label="Products Uploaded",
                    value=len(top_level_products),
                    help_text="Top-level products in BOM"
                )
            
            with r2:
                display_metric_card(
                    label="Products With Routing",
                    value=len(top_level_products) - len(missing_routing),
                    help_text="Products with routing definitions"
                )
            
            with r3:
                # Missing Routing - lower is better
                missing_routing_delta = -20 if len(missing_routing) > 0 else 20
                display_metric_card(
                    label="Missing Routing",
                    value=len(missing_routing),
                    delta=missing_routing_delta,
                    help_text="Products without routing definitions"
                )
            
            if missing_routing:
                content_card(
                    value=f"{len(missing_routing)} products missing routing definitions",
                    label="Routing Data Gap",
                    description="These products need routing operations",
                    status="warning"
                )
                st.dataframe(
                    pd.DataFrame({
                        "ITEM_ID": list(missing_routing)
                    }),
                    use_container_width=True
                )
            else:
                content_card(
                    value="All products have routing definitions",
                    label="Validation Passed",
                    description="Complete routing coverage",
                    status="success"
                )
            
            routing_coverage = (
                (
                    len(top_level_products)
                    -
                    len(missing_routing)
                )
                /
                len(top_level_products)
            ) * 100
            
            st.progress(
                routing_coverage / 100
            )
            
            st.caption(
                f"Routing Coverage: {routing_coverage:.1f}%"
            )
    
            # ==========================================
            # SUPPLIER COST VALIDATION
            # ==========================================
            
            premium_divider()
            
            premium_section(
                "Supplier Cost Validation",
                "Verify supplier costs for all components",
                "🏢"
            )
            
            supplier_cost_df = session.sql("""
            SELECT DISTINCT ITEM_ID
            FROM DISCRETE_MFG_COST_MODEL.CORE_INPUT.SUPPLIER_COSTS
            """).to_pandas()
            
            supplier_items = set(
                supplier_cost_df["ITEM_ID"]
            )
            
            missing_supplier_costs = (
                uploaded_items_set
                -
                supplier_items
            )
            
            s1, s2, s3 = st.columns(3)
            
            with s1:
                display_metric_card(
                    label="Items Uploaded",
                    value=len(uploaded_items_set),
                    help_text="Total items in uploaded data"
                )
            
            with s2:
                display_metric_card(
                    label="Items With Supplier Cost",
                    value=len(uploaded_items_set) - len(missing_supplier_costs),
                    help_text="Items with supplier cost records"
                )
            
            with s3:
                # Missing Supplier Costs - lower is better
                missing_supplier_delta = -20 if len(missing_supplier_costs) > 10 else -10 if len(missing_supplier_costs) > 0 else 20
                display_metric_card(
                    label="Missing Supplier Costs",
                    value=len(missing_supplier_costs),
                    delta=missing_supplier_delta,
                    help_text="Items missing supplier cost data"
                )
            
            if missing_supplier_costs:
                content_card(
                    value=f"{len(missing_supplier_costs)} items missing supplier cost records",
                    label="Supplier Cost Data Gap",
                    description="These items need supplier cost records",
                    status="warning"
                )
                st.dataframe(
                    pd.DataFrame({
                        "ITEM_ID": list(missing_supplier_costs)
                    }),
                    use_container_width=True
                )
            else:
                content_card(
                    value="All items have supplier costs",
                    label="Validation Passed",
                    description="Complete supplier cost coverage",
                    status="success"
                )
            
            supplier_score = (
                (
                    len(uploaded_items_set)
                    -
                    len(missing_supplier_costs)
                )
                /
                max(len(uploaded_items_set), 1)
            ) * 100
            
            st.progress(
                supplier_score / 100
            )
            
            st.caption(
                f"Supplier Cost Coverage: {supplier_score:.1f}%"
            )
    
            # ==========================================
            # PRODUCT READINESS SCORE
            # ==========================================
            
            premium_divider()
            
            premium_section(
                "Product Readiness Assessment",
                "Overall manufacturing data completeness",
                "🎯"
            )
            
            total_uploaded_items = max(
                len(uploaded_items_set),
                1
            )
            
            item_master_score = (
                (
                    len(uploaded_items_set)
                    -
                    len(missing_items)
                )
                /
                total_uploaded_items
            ) * 100
            
            cost_score = (
                (
                    len(uploaded_items_set)
                    -
                    len(missing_cost_items)
                )
                /
                total_uploaded_items
            ) * 100
            
            total_products = max(
                len(top_level_products),
                1
            )
            
            routing_score = (
                (
                    len(top_level_products)
                    -
                    len(missing_routing)
                )
                /
                total_products
            ) * 100
            
            overall_readiness = (
                item_master_score
                +
                cost_score
                +
                routing_score
                +
                supplier_score
            ) / 4
    
            r1, r2, r3, r4, r5 = st.columns(5)
    
            with r1:
                readiness_delta = 15 if item_master_score == 100 else 0 if item_master_score >= 80 else -15
                display_metric_card(
                    label="Item Master",
                    value=f"{item_master_score:.0f}%",
                    delta=readiness_delta,
                    help_text="Item master data completeness"
                )
            
            with r2:
                readiness_delta = 15 if cost_score == 100 else 0 if cost_score >= 80 else -15
                display_metric_card(
                    label="Material Costs",
                    value=f"{cost_score:.0f}%",
                    delta=readiness_delta,
                    help_text="Material cost data completeness"
                )
            
            with r3:
                readiness_delta = 15 if routing_score == 100 else 0 if routing_score >= 80 else -15
                display_metric_card(
                    label="Routing",
                    value=f"{routing_score:.0f}%",
                    delta=readiness_delta,
                    help_text="Routing data completeness"
                )
            
            with r4:
                readiness_delta = 15 if supplier_score == 100 else 0 if supplier_score >= 80 else -15
                display_metric_card(
                    label="Supplier Costs",
                    value=f"{supplier_score:.0f}%",
                    delta=readiness_delta,
                    help_text="Supplier cost data completeness"
                )
            
            with r5:
                readiness_delta = 20 if overall_readiness == 100 else 0 if overall_readiness >= 75 else -20
                display_metric_card(
                    label="Overall Readiness",
                    value=f"{overall_readiness:.0f}%",
                    delta=readiness_delta,
                    help_text="Overall manufacturing data readiness"
                )
    
            st.progress(
                overall_readiness / 100
            )
    
            # Use content_card for readiness assessment
            if overall_readiness == 100:
                content_card(
                    value="Fully Ready",
                    label="Product Status",
                    description="Product is fully ready for costing.",
                    status="success"
                )
            elif overall_readiness >= 75:
                content_card(
                    value="Mostly Ready",
                    label="Product Status",
                    description="Product is mostly ready. Minor master-data gaps remain.",
                    status="info"
                )
            elif overall_readiness >= 50:
                content_card(
                    value="Needs Setup",
                    label="Product Status",
                    description="Product requires additional master-data setup.",
                    status="warning"
                )
            else:
                content_card(
                    value="Not Ready",
                    label="Product Status",
                    description="Product is not ready for costing.",
                    status="error"
                )
    
            # ==========================================
            # MASTER DATA COMPLETION
            # ==========================================
            
            premium_divider()
            
            section_header(
                "Master Data Completion",
                "Create missing master data records",
                "📝"
            )
            premium_section(
                "Create Missing Item Master Records",
                "Add items to master data",
                "📋"
            )
            
            if missing_items:
            
                item_master_input = pd.DataFrame({
                    "ITEM_ID": list(missing_items),
                    "ITEM_NAME": list(missing_items),
                    "ITEM_TYPE": ["RM"] * len(missing_items),
                    "UOM": ["EA"] * len(missing_items),
                    "PRODUCT_FAMILY": ["UNKNOWN"] * len(missing_items),
                    "COMMODITY_GROUP": ["UNKNOWN"] * len(missing_items),
                    "STATUS": ["ACTIVE"] * len(missing_items),
                    "REVISION": ["REV_A"] * len(missing_items)
                })
            
                edited_item_master = st.data_editor(
                    item_master_input,
                    use_container_width=True,
                    key="item_master_editor"
                )
            
                if st.button(
                    "Save Item Master"
                ):
            
                    session.write_pandas(
                        edited_item_master,
                        "ITEM_MASTER",
                        database="DISCRETE_MFG_COST_MODEL",
                        schema="CORE_INPUT",
                        auto_create_table=False
                    )
            
                    st.success(
                        "Item Master Records Created"
                    )
                    
            premium_divider()
    
            premium_section(
                "Create Material Costs",
                "Add cost records for missing items",
                "💰"
            )
            
            if missing_cost_items:
            
                material_cost_input = pd.DataFrame({
                    "ITEM_ID": list(missing_cost_items),
                    "STANDARD_COST": [0.0] * len(missing_cost_items),
                    "CURRENCY_CODE": ["INR"] * len(missing_cost_items),
                    "COST_TYPE": ["STANDARD"] * len(missing_cost_items),
                    "EFFECTIVE_FROM": [pd.Timestamp.today().date()] * len(missing_cost_items),
                    "EFFECTIVE_TO": [None] * len(missing_cost_items),
                })
            
                edited_costs = st.data_editor(
                    material_cost_input,
                    use_container_width=True,
                    key="material_cost_editor"
                )
            
                if st.button(
                    "Save Material Costs"
                ):
            
                    session.write_pandas(
                        edited_costs,
                        "MATERIAL_COSTS",
                        database="DISCRETE_MFG_COST_MODEL",
                        schema="CORE_INPUT",
                        auto_create_table=False
                    )
            
                    st.success(
                        "Material Costs Saved"
                    )
            
            premium_divider()
    
            premium_section(
                "Create Routing Operations",
                "Add routing definitions for products",
                "🗺️"
            )
            
            if missing_routing:
            
                routing_input = pd.DataFrame({
            
                    "ROUTING_ID":
                        [
                            f"ROUTE_{i+1}"
                            for i in range(
                                len(missing_routing)
                            )
                        ],
            
                    "ITEM_ID":
                        list(missing_routing),
            
                    "OPERATION_SEQ":
                        [10] * len(missing_routing),
            
                    "OPERATION_ID":
                        ["ASSEMBLY"] * len(missing_routing),
            
                    "WORK_CENTER":
                        ["WC_MAIN"] * len(missing_routing),
            
                    "SETUP_HOURS":
                        [0.0] * len(missing_routing),
            
                    "RUN_HOURS":
                        [0.0] * len(missing_routing),
            
                    "LABOR_RATE":
                        [25.0] * len(missing_routing),
            
                    "MACHINE_RATE":
                        [20.0] * len(missing_routing),
            
                    "PLANT_ID":
                        ["PLANT_A"] * len(missing_routing),
            
                    "REVISION":
                        ["REV_A"] * len(missing_routing)
            
                })
            
                edited_routing = st.data_editor(
                    routing_input,
                    use_container_width=True,
                    key="routing_editor"
                )
            
                if st.button("Save Routing"):
                    session.write_pandas(
                        edited_routing,
                        "ROUTING_OPERATIONS",
                        database="DISCRETE_MFG_COST_MODEL",
                        schema="CORE_INPUT",
                        auto_create_table=False
                    )
            
                    st.success(
                        "Routing Operations Saved"
                    )
                    
            premium_divider()
    
            premium_section(
                "Create Supplier Master",
                "Add supplier records",
                "🏢"
            )
    
            supplier_input = pd.DataFrame({
                "SUPPLIER_ID":["SUPP001"],
                "SUPPLIER_NAME":[""],
                "COUNTRY":["India"],
                "STATUS":["ACTIVE"]
            })
            
            edited_supplier = st.data_editor(
                supplier_input,
                use_container_width=True,
                key="supplier_editor"
            )
            
            if st.button(
                "Save Supplier Master"
            ):
            
                session.write_pandas(
                    edited_supplier,
                    "SUPPLIER_MASTER",
                    database="DISCRETE_MFG_COST_MODEL",
                    schema="CORE_INPUT",
                    auto_create_table=False
                )
            
                st.success(
                    "Supplier Master Saved"
                )
                
        elif mode == "Manual Entry":
            premium_section(
                "Manual BOM Entry",
                "Add BOM records manually",
                "✏️"
            )
        
            parent = st.text_input(
                "Parent Item"
            )
        
            component = st.text_input(
                "Component Item"
            )
        
            quantity = st.number_input(
                "Quantity",
                min_value=1,
                value=1
            )
        
            if st.button("Add BOM Record"):
                session.sql(f"""
                INSERT INTO
                DISCRETE_MFG_COST_MODEL.CORE_INPUT.BOM_STRUCTURE
                (
                    BOM_ID,
                    PARENT_ID,
                    COMPONENT_ID,
                    QUANTITY,
                    UOM,
                    REVISION,
                    PLANT_ID,
                    EFFECTIVE_FROM,
                    EFFECTIVE_TO,
                    CREATED_AT
                )
            
                VALUES
                (
                    UUID_STRING(),
            
                    '{parent}',
            
                    '{component}',
            
                    {quantity},
            
                    'EA',
            
                    'REV_A',
            
                    'PLANT_A',
            
                    CURRENT_DATE,
            
                    NULL,
            
                    CURRENT_TIMESTAMP
                )
                """).collect()
            
                st.success(
                    "Record Added Successfully"
                )