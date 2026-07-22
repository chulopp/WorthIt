"""
generate_backtest_report.py — Interactive HTML Report Generator

Reads data/backtest_latest.json and produces data/backtest_report.html
with Plotly interactive charts and a dark-themed professional layout.

Sections:
  1. Key Metrics Cards (Hit Rate, Total Predictions, Cost Savings)
  2. Bar Chart — Accuracy per Decision Type
  3. Scatter Plot — Score vs Correctness
  4. Scatter Plot — Price Delta vs Correctness
  5. Summary Table + Interpretation
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)

try:
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots
except ImportError:
    print("❌ plotly is required. Install with: pip install plotly")
    sys.exit(1)


# ─── Load Data ────────────────────────────────────────────────────────────────

def load_backtest_data() -> dict:
    data_path = os.path.join(BACKEND_DIR, "data", "backtest_latest.json")
    if not os.path.exists(data_path):
        print(f"❌ File not found: {data_path}")
        print("   Run backtest_v2.py first to generate the data.")
        sys.exit(1)

    with open(data_path, "r", encoding="utf-8") as f:
        return json.load(f)


# ─── Chart Generators ────────────────────────────────────────────────────────

def create_accuracy_bar_chart(decision_breakdown: dict) -> str:
    """Section 2: Bar chart of accuracy per decision type."""
    decisions = []
    accuracies = []
    colors = []
    hovertexts = []

    color_map = {
        "WorthIt": "#00e676",
        "Mahal": "#ff5252",
    }

    for decision_type in ["WorthIt", "Mahal"]:
        stats = decision_breakdown.get(decision_type, {"total": 0, "correct": 0, "accuracy": 0})
        decisions.append(decision_type)
        accuracies.append(stats["accuracy"])
        colors.append(color_map.get(decision_type, "#90caf9"))
        hovertexts.append(
            f"<b>{decision_type}</b><br>"
            f"Correct: {stats['correct']}/{stats['total']}<br>"
            f"Accuracy: {stats['accuracy']:.1f}%"
        )

    fig = go.Figure(data=[
        go.Bar(
            x=decisions,
            y=accuracies,
            marker_color=colors,
            hovertext=hovertexts,
            hoverinfo="text",
            text=[f"{a:.1f}%" for a in accuracies],
            textposition="outside",
            textfont=dict(color="#e0e0e0", size=14, family="Inter"),
        )
    ])

    fig.update_layout(
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(30,30,46,0.8)",
        title=dict(
            text="Accuracy per Decision Type<br><sup>Waspada = zona abu-abu (tidak dihitung)</sup>",
            font=dict(size=20, color="#e0e0e0", family="Inter"),
        ),
        yaxis=dict(
            title="Accuracy (%)",
            range=[0, 110],
            gridcolor="rgba(255,255,255,0.08)",
            tickfont=dict(color="#b0b0b0"),
        ),
        xaxis=dict(tickfont=dict(color="#b0b0b0", size=14)),
        margin=dict(l=50, r=30, t=70, b=40),
        height=400,
    )

    return fig.to_html(full_html=False, include_plotlyjs=False, config={"displayModeBar": True})


def create_decision_distribution_pie_chart(decision_breakdown: dict) -> str:
    """Section: Pie chart of decision distribution."""
    labels = ["WorthIt", "Waspada", "Mahal"]
    values = [decision_breakdown.get(label, {}).get("total", 0) for label in labels]
    colors = ["#00e676", "#ffc107", "#ff5252"]

    fig = go.Figure(data=[
        go.Pie(
            labels=labels,
            values=values,
            hole=0.4,
            marker=dict(colors=colors, line=dict(color="#1a1a3e", width=2)),
            hoverinfo="label+value+percent",
            textinfo="label+percent",
            textfont=dict(size=14, color="#e0e0e0", family="Inter"),
        )
    ])

    fig.update_layout(
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        title=dict(
            text="Decision Distribution",
            font=dict(size=20, color="#e0e0e0", family="Inter"),
        ),
        legend=dict(
            font=dict(color="#e0e0e0"),
        ),
        margin=dict(l=40, r=40, t=60, b=40),
        height=400,
    )

    return fig.to_html(full_html=False, include_plotlyjs=False, config={"displayModeBar": True})


def create_score_scatter(raw_results: list[dict]) -> str:
    """Section 3: Scatter plot of Score vs Correctness."""
    correct = [r for r in raw_results if r["was_correct"]]
    incorrect = [r for r in raw_results if not r["was_correct"]]

    fig = go.Figure()

    # Correct predictions
    fig.add_trace(go.Scatter(
        x=list(range(len(correct))),
        y=[r["score"] for r in correct],
        mode="markers",
        name="Correct ✅",
        marker=dict(color="#00e676", size=8, opacity=0.75,
                     line=dict(width=1, color="rgba(255,255,255,0.3)")),
        hovertext=[
            f"<b>{r['product_name']}</b><br>"
            f"Score: {r['score']}<br>"
            f"Decision: {r['decision']}<br>"
            f"Status: ✅ Correct"
            for r in correct
        ],
        hoverinfo="text",
    ))

    # Incorrect predictions
    fig.add_trace(go.Scatter(
        x=list(range(len(incorrect))),
        y=[r["score"] for r in incorrect],
        mode="markers",
        name="Incorrect ❌",
        marker=dict(color="#ff5252", size=8, opacity=0.75,
                     line=dict(width=1, color="rgba(255,255,255,0.3)")),
        hovertext=[
            f"<b>{r['product_name']}</b><br>"
            f"Score: {r['score']}<br>"
            f"Decision: {r['decision']}<br>"
            f"Status: ❌ Incorrect"
            for r in incorrect
        ],
        hoverinfo="text",
    ))

    # Threshold lines
    fig.add_hline(y=75, line_dash="dash", line_color="#00e676",
                   annotation_text="WorthIt (≥75)", annotation_position="right",
                   annotation_font=dict(color="#00e676", size=12))
    fig.add_hline(y=50, line_dash="dash", line_color="#ffc107",
                   annotation_text="Waspada (≥50)", annotation_position="right",
                   annotation_font=dict(color="#ffc107", size=12))

    fig.update_layout(
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(30,30,46,0.8)",
        title=dict(
            text="Score Distribution vs Correctness",
            font=dict(size=20, color="#e0e0e0", family="Inter"),
        ),
        xaxis=dict(title="Prediction Index", gridcolor="rgba(255,255,255,0.05)",
                    tickfont=dict(color="#b0b0b0")),
        yaxis=dict(title="Score (0–100)", range=[-5, 105],
                    gridcolor="rgba(255,255,255,0.08)",
                    tickfont=dict(color="#b0b0b0")),
        legend=dict(
            orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1,
            font=dict(color="#e0e0e0"),
        ),
        margin=dict(l=50, r=30, t=80, b=50),
        height=450,
    )

    return fig.to_html(full_html=False, include_plotlyjs=False, config={"displayModeBar": True})


def create_delta_scatter(raw_results: list[dict]) -> str:
    """Section 4: Scatter plot of Price Delta vs Correctness."""
    correct = [r for r in raw_results if r["was_correct"]]
    incorrect = [r for r in raw_results if not r["was_correct"]]

    fig = go.Figure()

    fig.add_trace(go.Scatter(
        x=list(range(len(correct))),
        y=[r["price_delta_percent"] for r in correct],
        mode="markers",
        name="Correct ✅",
        marker=dict(color="#00e676", size=8, opacity=0.75,
                     line=dict(width=1, color="rgba(255,255,255,0.3)")),
        hovertext=[
            f"<b>{r['product_name']}</b><br>"
            f"Δ Price: {r['price_delta_percent']:+.1f}%<br>"
            f"Status: ✅ Correct"
            for r in correct
        ],
        hoverinfo="text",
    ))

    fig.add_trace(go.Scatter(
        x=list(range(len(incorrect))),
        y=[r["price_delta_percent"] for r in incorrect],
        mode="markers",
        name="Incorrect ❌",
        marker=dict(color="#ff5252", size=8, opacity=0.75,
                     line=dict(width=1, color="rgba(255,255,255,0.3)")),
        hovertext=[
            f"<b>{r['product_name']}</b><br>"
            f"Δ Price: {r['price_delta_percent']:+.1f}%<br>"
            f"Status: ❌ Incorrect"
            for r in incorrect
        ],
        hoverinfo="text",
    ))

    fig.add_hline(y=0, line_dash="dash", line_color="rgba(255,255,255,0.4)",
                   annotation_text="No change", annotation_position="right",
                   annotation_font=dict(color="#90a4ae", size=12))

    fig.update_layout(
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(30,30,46,0.8)",
        title=dict(
            text="Price Delta (%) vs Correctness",
            font=dict(size=20, color="#e0e0e0", family="Inter"),
        ),
        xaxis=dict(title="Prediction Index", gridcolor="rgba(255,255,255,0.05)",
                    tickfont=dict(color="#b0b0b0")),
        yaxis=dict(title="Price Δ (%)", gridcolor="rgba(255,255,255,0.08)",
                    tickfont=dict(color="#b0b0b0")),
        legend=dict(
            orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1,
            font=dict(color="#e0e0e0"),
        ),
        margin=dict(l=50, r=30, t=80, b=50),
        height=450,
    )

    return fig.to_html(full_html=False, include_plotlyjs=False, config={"displayModeBar": True})


# ─── Interpretation Generator ────────────────────────────────────────────────

def generate_interpretation(data: dict) -> str:
    hit_rate = data["hit_rate"]
    total = data["total_predictions"]
    bd = data["decision_breakdown"]
    cost = data["cost_savings_percent"]
    evaluable = data.get("evaluable_predictions", total)
    waspada = data.get("waspada_predictions", 0)

    paragraphs = []

    # Paragraph 1: Overall assessment
    if hit_rate >= 75:
        assessment = (
            f"Scoring engine WorthIt menunjukkan performa yang <strong>sangat baik</strong> "
            f"dengan hit rate <strong>{hit_rate:.1f}%</strong> (dihitung dari {evaluable} prediksi WorthIt + Mahal, "
            f"dengan {waspada} prediksi Waspada di zona netral). "
            f"Ini berarti sebagian besar keputusan harga evaluabel terbukti akurat terhadap pergerakan harga aktual."
        )
    elif hit_rate >= 60:
        assessment = (
            f"Scoring engine WorthIt menunjukkan performa yang <strong>cukup baik</strong> "
            f"dengan hit rate <strong>{hit_rate:.1f}%</strong> (dihitung dari {evaluable} prediksi WorthIt + Mahal, "
            f"dengan {waspada} prediksi Waspada di zona netral). "
            f"Ada ruang untuk peningkatan, namun fondasi rule-based sudah memberikan nilai tambah yang terukur."
        )
    elif hit_rate >= 50:
        assessment = (
            f"Scoring engine menunjukkan hit rate <strong>{hit_rate:.1f}%</strong> dari "
            f"{evaluable} prediksi evaluabel (dengan {waspada} prediksi Waspada di zona netral) — sedikit di atas random baseline (50%). "
            f"Rule-based approach saat ini memberikan sinyal yang marjinal."
        )
    else:
        assessment = (
            f"Scoring engine menunjukkan hit rate <strong>{hit_rate:.1f}%</strong> dari "
            f"{evaluable} prediksi evaluabel (dengan {waspada} prediksi Waspada di zona netral) — <strong>di bawah baseline random</strong>. "
            f"Perlu evaluasi mendalam terhadap bobot komponen dan threshold."
        )
    paragraphs.append(f"<p>{assessment}</p>")

    # Paragraph 2: Per-decision analysis
    evaluable_bd = {k: v for k, v in bd.items() if k in ("WorthIt", "Mahal")}
    if evaluable_bd:
        best_decision = max(evaluable_bd.items(), key=lambda x: x[1]["accuracy"])
        worst_decision = min(evaluable_bd.items(), key=lambda x: x[1]["accuracy"])
        paragraphs.append(
            f"<p>Dari keputusan yang dievaluasi, tipe keputusan <strong>{best_decision[0]}</strong> memiliki "
            f"akurasi tertinggi ({best_decision[1]['accuracy']:.1f}%), sementara "
            f"<strong>{worst_decision[0]}</strong> memiliki akurasi terendah "
            f"({worst_decision[1]['accuracy']:.1f}%). Cost savings impact sebesar "
            f"<strong>{cost:.1f}%</strong> menunjukkan penghematan yang dihasilkan.</p>"
        )
    else:
        paragraphs.append(
            f"<p>Cost savings impact sebesar <strong>{cost:.1f}%</strong> menunjukkan penghematan yang dihasilkan.</p>"
        )

    # Paragraph 3: Recommendation
    if hit_rate >= 70:
        recommendation = (
            "Rule-based scoring engine saat ini <strong>sudah cukup efektif</strong> "
            "untuk fase MVP. Namun, untuk meningkatkan akurasi di zona Waspada (50-74 poin), "
            "pertimbangkan penambahan fitur ML seperti trend detection dan seasonal adjustment. "
            "Fokuskan pengembangan pada kalibrasi threshold WMA dan S/R position."
        )
    elif hit_rate >= 55:
        recommendation = (
            "Rule-based approach memberikan fondasi yang <strong>memadai</strong>, namun "
            "disarankan untuk mulai bereksperimen dengan model ML sederhana (misalnya "
            "Gradient Boosted Trees) sebagai ensemble layer di atas scoring components "
            "yang ada. Prioritaskan feature engineering pada volatility dan seasonal patterns."
        )
    else:
        recommendation = (
            "Hasil backtest menunjukkan bahwa rule-based approach <strong>perlu ditingkatkan "
            "secara signifikan</strong>. Rekomendasikan migrasi ke ML-based scoring dengan "
            "memanfaatkan fitur historis yang ada (WMA, S/R, volatility) sebagai input features. "
            "Random Forest atau XGBoost cocok sebagai baseline model."
        )
    paragraphs.append(f"<p><strong>Rekomendasi:</strong> {recommendation}</p>")

    return "\n".join(paragraphs)


# ─── HTML Template ────────────────────────────────────────────────────────────

def build_html(data: dict) -> str:
    hit_rate = data["hit_rate"]
    total_predictions = data["total_predictions"]
    cost_savings = data["cost_savings_percent"]
    generated_at = data.get("generated_at", datetime.now().isoformat())
    bd = data["decision_breakdown"]
    raw_results = data["raw_results"]
    evaluable_predictions = data.get("evaluable_predictions", total_predictions)
    waspada_predictions = data.get("waspada_predictions", 0)

    # Determine card colors
    if hit_rate >= 70:
        hr_color = "#00e676"
        hr_bg = "rgba(0, 230, 118, 0.12)"
        hr_border = "rgba(0, 230, 118, 0.3)"
    elif hit_rate >= 50:
        hr_color = "#ffc107"
        hr_bg = "rgba(255, 193, 7, 0.12)"
        hr_border = "rgba(255, 193, 7, 0.3)"
    else:
        hr_color = "#ff5252"
        hr_bg = "rgba(255, 82, 82, 0.12)"
        hr_border = "rgba(255, 82, 82, 0.3)"

    # Generate charts
    bar_chart = create_accuracy_bar_chart(bd)
    pie_chart = create_decision_distribution_pie_chart(bd)
    score_scatter = create_score_scatter(raw_results)
    delta_scatter = create_delta_scatter(raw_results)

    # Generate interpretation
    interpretation = generate_interpretation(data)

    # Summary table rows
    summary_rows = ""
    for decision_type in ["WorthIt", "Waspada", "Mahal"]:
        stats = bd.get(decision_type, {"total": 0, "correct": 0, "accuracy": 0})
        acc = stats["accuracy"]
        if decision_type == "Waspada":
            accuracy_str = "N/A (Neutral)"
            badge_class = "badge-yellow"
        else:
            accuracy_str = f"{acc:.1f}%"
            if acc >= 70:
                badge_class = "badge-green"
            elif acc >= 50:
                badge_class = "badge-yellow"
            else:
                badge_class = "badge-red"
        
        summary_rows += f"""
            <tr>
                <td><span class="decision-tag tag-{decision_type.lower()}">{decision_type}</span></td>
                <td>{stats['total']}</td>
                <td>{stats['correct'] if decision_type != 'Waspada' else '-'}</td>
                <td><span class="badge {badge_class}">{accuracy_str}</span></td>
            </tr>
        """

    # Count correct/incorrect
    evaluable_results = [r for r in raw_results if r["decision"] in ("WorthIt", "Mahal")]
    correct_in_evaluable = sum(1 for r in evaluable_results if r["was_correct"])
    incorrect_in_evaluable = len(evaluable_results) - correct_in_evaluable

    html = f"""<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WorthIt Backtest Report v2</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <script src="https://cdn.plot.ly/plotly-2.35.2.min.js" charset="utf-8"></script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        :root {{
            --bg-primary: #0a0a1a;
            --bg-secondary: #12122a;
            --bg-card: #1a1a3e;
            --bg-card-hover: #22224a;
            --border-subtle: rgba(255, 255, 255, 0.06);
            --border-accent: rgba(100, 100, 255, 0.15);
            --text-primary: #e8e8f0;
            --text-secondary: #a0a0c0;
            --text-muted: #6a6a90;
            --accent-green: #00e676;
            --accent-yellow: #ffc107;
            --accent-red: #ff5252;
            --accent-blue: #448aff;
            --accent-purple: #7c4dff;
            --glow-green: rgba(0, 230, 118, 0.15);
            --glow-blue: rgba(68, 138, 255, 0.15);
        }}

        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.7;
            min-height: 100vh;
        }}

        /* Background decoration */
        body::before {{
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background:
                radial-gradient(ellipse 600px 400px at 20% 10%, rgba(124, 77, 255, 0.06), transparent),
                radial-gradient(ellipse 500px 300px at 80% 80%, rgba(0, 230, 118, 0.04), transparent),
                radial-gradient(ellipse 400px 400px at 50% 50%, rgba(68, 138, 255, 0.03), transparent);
            pointer-events: none;
            z-index: 0;
        }}

        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 24px 80px;
            position: relative;
            z-index: 1;
        }}

        /* Header */
        .header {{
            text-align: center;
            margin-bottom: 48px;
            padding: 40px 0 32px;
        }}

        .header-badge {{
            display: inline-block;
            padding: 6px 16px;
            background: linear-gradient(135deg, rgba(124, 77, 255, 0.15), rgba(68, 138, 255, 0.15));
            border: 1px solid rgba(124, 77, 255, 0.25);
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            color: var(--accent-purple);
            margin-bottom: 20px;
        }}

        .header h1 {{
            font-size: 42px;
            font-weight: 800;
            background: linear-gradient(135deg, #e8e8f0 0%, #a0a0c0 50%, #7c4dff 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 12px;
            letter-spacing: -1px;
        }}

        .header .subtitle {{
            font-size: 16px;
            color: var(--text-secondary);
            font-weight: 400;
        }}

        .header .timestamp {{
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 8px;
            font-family: 'JetBrains Mono', monospace;
        }}

        /* Metric Cards */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 48px;
        }}

        .metric-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 28px 24px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }}

        .metric-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            border-radius: 16px 16px 0 0;
        }}

        .metric-card:hover {{
            background: var(--bg-card-hover);
            border-color: var(--border-accent);
            transform: translateY(-2px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }}

        .metric-card.card-hit-rate::before {{
            background: linear-gradient(90deg, {hr_color}, transparent);
        }}
        .metric-card.card-predictions::before {{
            background: linear-gradient(90deg, var(--accent-blue), transparent);
        }}
        .metric-card.card-savings::before {{
            background: linear-gradient(90deg, var(--accent-purple), transparent);
        }}

        .metric-label {{
            font-size: 13px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }}

        .metric-value {{
            font-size: 48px;
            font-weight: 800;
            font-family: 'JetBrains Mono', 'Inter', monospace;
            letter-spacing: -2px;
            line-height: 1.1;
        }}

        .metric-value.green {{ color: var(--accent-green); }}
        .metric-value.yellow {{ color: var(--accent-yellow); }}
        .metric-value.red {{ color: var(--accent-red); }}
        .metric-value.blue {{ color: var(--accent-blue); }}
        .metric-value.purple {{ color: var(--accent-purple); }}

        .metric-detail {{
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 8px;
        }}

        /* Section */
        .section {{
            margin-bottom: 48px;
        }}

        .section-header {{
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-subtle);
        }}

        .section-number {{
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 32px;
            height: 32px;
            background: linear-gradient(135deg, var(--accent-purple), var(--accent-blue));
            border-radius: 8px;
            font-size: 14px;
            font-weight: 700;
            color: white;
            flex-shrink: 0;
        }}

        .section-title {{
            font-size: 22px;
            font-weight: 700;
            color: var(--text-primary);
            letter-spacing: -0.5px;
        }}

        .chart-container {{
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 24px;
            transition: border-color 0.3s;
        }}

        .chart-container:hover {{
            border-color: var(--border-accent);
        }}

        /* Summary Table */
        .summary-table {{
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            background: var(--bg-card);
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid var(--border-subtle);
        }}

        .summary-table th {{
            background: rgba(124, 77, 255, 0.08);
            padding: 14px 20px;
            text-align: left;
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border-subtle);
        }}

        .summary-table td {{
            padding: 14px 20px;
            border-bottom: 1px solid var(--border-subtle);
            font-size: 14px;
            color: var(--text-secondary);
        }}

        .summary-table tr:last-child td {{
            border-bottom: none;
        }}

        .summary-table tr:hover td {{
            background: rgba(255, 255, 255, 0.02);
        }}

        .decision-tag {{
            display: inline-block;
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 700;
            font-family: 'JetBrains Mono', monospace;
            letter-spacing: 0.5px;
        }}

        .tag-worthit {{ background: rgba(0, 230, 118, 0.12); color: var(--accent-green); }}
        .tag-waspada {{ background: rgba(255, 193, 7, 0.12); color: var(--accent-yellow); }}
        .tag-mahal {{ background: rgba(255, 82, 82, 0.12); color: var(--accent-red); }}

        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 700;
            font-family: 'JetBrains Mono', monospace;
        }}

        .badge-green {{ background: rgba(0, 230, 118, 0.12); color: var(--accent-green); }}
        .badge-yellow {{ background: rgba(255, 193, 7, 0.12); color: var(--accent-yellow); }}
        .badge-red {{ background: rgba(255, 82, 82, 0.12); color: var(--accent-red); }}

        /* Interpretation */
        .interpretation {{
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-left: 3px solid var(--accent-purple);
            border-radius: 0 12px 12px 0;
            padding: 28px 28px;
            margin-top: 28px;
        }}

        .interpretation h3 {{
            font-size: 16px;
            font-weight: 700;
            color: var(--accent-purple);
            margin-bottom: 16px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}

        .interpretation p {{
            color: var(--text-secondary);
            font-size: 14px;
            line-height: 1.8;
            margin-bottom: 14px;
        }}

        .interpretation p:last-child {{
            margin-bottom: 0;
        }}

        .interpretation strong {{
            color: var(--text-primary);
        }}

        /* Footer */
        .footer {{
            text-align: center;
            padding: 40px 0 20px;
            border-top: 1px solid var(--border-subtle);
            margin-top: 60px;
        }}

        .footer p {{
            color: var(--text-muted);
            font-size: 13px;
        }}

        .footer .brand {{
            font-weight: 700;
            background: linear-gradient(135deg, var(--accent-purple), var(--accent-green));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }}

        /* Responsive */
        @media (max-width: 768px) {{
            .container {{
                padding: 24px 16px 60px;
            }}
            .header h1 {{
                font-size: 28px;
            }}
            .metrics-grid {{
                grid-template-columns: 1fr;
            }}
            .metric-value {{
                font-size: 36px;
            }}
            .chart-container {{
                padding: 16px;
            }}
            .section-title {{
                font-size: 18px;
            }}
        }}

        /* Animations */
        @keyframes fadeInUp {{
            from {{
                opacity: 0;
                transform: translateY(20px);
            }}
            to {{
                opacity: 1;
                transform: translateY(0);
            }}
        }}

        .animate-in {{
            animation: fadeInUp 0.6s ease forwards;
            opacity: 0;
        }}

        .animate-in:nth-child(1) {{ animation-delay: 0.1s; }}
        .animate-in:nth-child(2) {{ animation-delay: 0.2s; }}
        .animate-in:nth-child(3) {{ animation-delay: 0.3s; }}
    </style>
</head>
<body>
    <div class="container">

        <!-- Header -->
        <div class="header">
            <div class="header-badge">Backtest Report v2.0</div>
            <h1>WorthIt Scoring Engine</h1>
            <p class="subtitle">Full-pipeline backtesting report menggunakan engine/scoring.py::run_analysis()</p>
            <p class="timestamp">Generated: {generated_at[:19].replace('T', ' ')} UTC</p>
        </div>

        <!-- Section 1: Key Metrics -->
        <div class="metrics-grid">
            <div class="metric-card card-hit-rate animate-in">
                <div class="metric-label">Overall Hit Rate</div>
                <div class="metric-value {'green' if hit_rate >= 70 else 'yellow' if hit_rate >= 50 else 'red'}">{hit_rate:.1f}%</div>
                <div class="metric-detail">{correct_in_evaluable} correct / {incorrect_in_evaluable} incorrect (WorthIt &amp; Mahal)</div>
            </div>
            <div class="metric-card card-predictions animate-in">
                <div class="metric-label">Total Predictions</div>
                <div class="metric-value blue">{total_predictions}</div>
                <div class="metric-detail">WorthIt+Mahal: {evaluable_predictions} | Waspada: {waspada_predictions}</div>
            </div>
            <div class="metric-card card-savings animate-in">
                <div class="metric-label">Cost Savings</div>
                <div class="metric-value purple">{cost_savings:.1f}%</div>
                <div class="metric-detail">Potential savings vs buying everything</div>
            </div>
        </div>

        <!-- Section 2: Accuracy Bar Chart -->
        <div class="section">
            <div class="section-header">
                <span class="section-number">2</span>
                <h2 class="section-title">Accuracy per Decision Type</h2>
            </div>
            <div class="chart-container">
                {bar_chart}
            </div>
        </div>

        <!-- Section 3: Distribusi Keputusan -->
        <div class="section">
            <div class="section-header">
                <span class="section-number">3</span>
                <h2 class="section-title">Distribusi Keputusan</h2>
            </div>
            <div class="chart-container">
                {pie_chart}
            </div>
        </div>

        <!-- Section 4: Score Scatter -->
        <div class="section">
            <div class="section-header">
                <span class="section-number">4</span>
                <h2 class="section-title">Score Distribution vs Correctness</h2>
            </div>
            <div class="chart-container">
                {score_scatter}
            </div>
        </div>

        <!-- Section 5: Delta Scatter -->
        <div class="section">
            <div class="section-header">
                <span class="section-number">5</span>
                <h2 class="section-title">Price Delta vs Correctness</h2>
            </div>
            <div class="chart-container">
                {delta_scatter}
            </div>
        </div>

        <!-- Section 6: Summary Table + Interpretation -->
        <div class="section">
            <div class="section-header">
                <span class="section-number">6</span>
                <h2 class="section-title">Summary & Interpretation</h2>
            </div>

            <!-- Summary text update as requested -->
            <div style="background: rgba(26, 26, 62, 0.6); border: 1px solid var(--border-subtle); padding: 16px 20px; border-radius: 12px; margin-bottom: 24px; font-size: 14px; text-align: left; color: var(--text-secondary);">
                ℹ️ <strong>Informasi Hit Rate:</strong> Hit rate dihitung dari {evaluable_predictions} prediksi (WorthIt + Mahal), {waspada_predictions} prediksi Waspada di zona netral.
            </div>

            <table class="summary-table">
                <thead>
                    <tr>
                        <th>Decision Type</th>
                        <th>Total</th>
                        <th>Correct</th>
                        <th>Accuracy</th>
                    </tr>
                </thead>
                <tbody>
                    {summary_rows}
                    <tr>
                        <td><strong style="color: var(--text-primary);">TOTAL (Evaluable)</strong></td>
                        <td><strong>{evaluable_predictions}</strong></td>
                        <td><strong>{correct_in_evaluable}</strong></td>
                        <td><span class="badge {'badge-green' if hit_rate >= 70 else 'badge-yellow' if hit_rate >= 50 else 'badge-red'}">{hit_rate:.1f}%</span></td>
                    </tr>
                </tbody>
            </table>

            <div class="interpretation">
                <h3>📝 Interpretasi Hasil</h3>
                {interpretation}
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            <p>Generated by <span class="brand">WorthIt</span> Backtest Engine v2.0</p>
            <p style="margin-top: 4px;">Pipeline: Supabase → Monthly Buckets → WMA + S/R + Urgency → Decision Evaluation</p>
        </div>

    </div>
</body>
</html>"""

    return html


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("📊 Generating WorthIt Backtest Report...")

    data = load_backtest_data()
    html = build_html(data)

    output_dir = os.path.join(BACKEND_DIR, "data")
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "backtest_report.html")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Report saved to: {output_path}")
    print(f"   Open in browser to view interactive charts.")
    print(f"   Total predictions: {data['total_predictions']}")
    print(f"   Hit rate: {data['hit_rate']:.1f}%")


if __name__ == "__main__":
    main()
