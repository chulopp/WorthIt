"""
engine/templates.py
Structured deterministic explanations for WorthIt analysis results.

The API returns stable keys plus numeric parameters. The Flutter client renders
the final text in the active locale, while older saved scan snapshots that only
contain strings remain supported by the client-side fallback parser.
"""


def build_explanations(
    *,
    scanned_price: float,
    normal_price: float,
    urgency: int,
    analysis: dict,
    is_pro: bool,
) -> list[dict]:
    explanations: list[dict] = []
    delta = analysis["price_delta_percent"]
    history_months = analysis.get("history_months", 6)

    if delta <= -5:
        wma_key = "analysis.explanations.wma_below"
        wma_tone = "positive"
    elif delta <= 5:
        wma_key = "analysis.explanations.wma_fair"
        wma_tone = "positive"
    elif delta <= 15:
        wma_key = "analysis.explanations.wma_above"
        wma_tone = "warning"
    else:
        wma_key = "analysis.explanations.wma_expensive"
        wma_tone = "negative"

    explanations.append({
        "title_key": "analysis.explanation_titles.wma",
        "description_key": wma_key,
        "tone": wma_tone,
        "icon_type": "trend",
        "params": {
            "period": str(history_months),
            "normal": f"{normal_price:.0f}",
            "scan": f"{scanned_price:.0f}",
            "delta": f"{abs(delta):.1f}",
        },
    })

    sr_position = analysis["sr_position"]
    support = analysis["support"]
    resistance = analysis["resistance"]
    if sr_position <= 25:
        sr_key = "analysis.explanations.sr_support"
        sr_tone = "positive"
    elif sr_position >= 75:
        sr_key = "analysis.explanations.sr_resistance"
        sr_tone = "negative"
    else:
        sr_key = "analysis.explanations.sr_middle"
        sr_tone = "warning"
    explanations.append({
        "title_key": "analysis.explanation_titles.sr",
        "description_key": sr_key,
        "tone": sr_tone,
        "icon_type": "range",
        "params": {
            "period": str(history_months),
            "support": f"{support:.0f}",
            "resistance": f"{resistance:.0f}",
        },
    })

    decision_key = analysis.get("decision", "WorthIt").lower()
    mapped_urgency = urgency if urgency in [1, 2, 3] else 2
    if decision_key in {"worthit", "waspada", "mahal"}:
        explanations.append({
            "title_key": "analysis.explanation_titles.urgency",
            "description_key": f"analysis.explanations.urgency_{mapped_urgency}_{decision_key}",
            "tone": "negative" if decision_key == "mahal" else ("warning" if decision_key == "waspada" else "positive"),
            "icon_type": "urgency",
            "params": {},
        })

    if is_pro:
        price_anomaly = analysis.get("price_anomaly") or {}
        shrinkflation = analysis.get("shrinkflation") or {}

        if price_anomaly.get("detected"):
            explanations.append({
                "title_key": "analysis.explanation_titles.anomaly",
                "description_key": "analysis.explanations.anomaly_detected",
                "tone": "negative",
                "icon_type": "anomaly",
                "params": {
                    "period": str(history_months),
                    "fairUpper": f"{analysis['fair_upper_bound']:.0f}",
                },
            })
        else:
            explanations.append({
                "title_key": "analysis.explanation_titles.anomaly",
                "description_key": "analysis.explanations.anomaly_clear",
                "tone": "positive",
                "icon_type": "anomaly",
                "params": {},
            })

        if shrinkflation.get("detected"):
            weight_drop = abs(shrinkflation.get("weight_delta_percent", 0))
            unit_rise = shrinkflation.get("unit_price_delta_percent", 0)
            explanations.append({
                "title_key": "analysis.explanation_titles.shrinkflation",
                "description_key": "analysis.explanations.shrinkflation_detected",
                "tone": "negative",
                "icon_type": "shrinkflation",
                "params": {
                    "weightDrop": f"{weight_drop:.1f}",
                    "unitRise": f"{unit_rise:.1f}",
                },
            })
        else:
            explanations.append({
                "title_key": "analysis.explanation_titles.shrinkflation",
                "description_key": "analysis.explanations.shrinkflation_clear",
                "tone": "positive",
                "icon_type": "shrinkflation",
                "params": {},
            })
    else:
        explanations.append({
            "title_key": "analysis.explanation_titles.pro",
            "description_key": "analysis.explanations.pro_locked",
            "tone": "warning",
            "icon_type": "lock",
            "params": {},
        })

    return explanations
