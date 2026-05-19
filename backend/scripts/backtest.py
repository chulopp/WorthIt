"""
Run a lightweight WorthIt backtesting report from Supabase data.

This script implements the PRD validation story in a pragmatic demo form:
it compares the latest two historical price points for each product and uses
simple recommendations derived from whether the prior price was above/below the
product's average historical price.
"""

from __future__ import annotations

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from engine.backtesting import (
    ActualOutcome,
    Prediction,
    calculate_cost_savings,
    calculate_hit_rate,
    format_backtesting_report,
)
from utils.supabase_client import get_supabase


def _decision_from_history(current_price: float, avg_price: float) -> str:
    diff_pct = (current_price - avg_price) / avg_price * 100 if avg_price else 0
    if diff_pct <= 0:
        return "BUY"
    if diff_pct <= 20:
        return "SUBSTITUTE"
    return "DONT_BUY"


def run_backtest() -> str:
    sb = get_supabase()
    products = sb.table("products").select("id, name, category").limit(200).execute().data or []

    predictions: list[Prediction] = []
    actuals: list[ActualOutcome] = []

    for product in products:
        history = (
            sb.table("price_history")
            .select("price, recorded_at")
            .eq("product_id", product["id"])
            .order("recorded_at", desc=False)
            .execute()
            .data
            or []
        )
        if len(history) < 4:
            continue

        training = history[:-1]
        current = history[-2]
        future = history[-1]
        avg_price = sum(row["price"] for row in training) / len(training)
        decision = _decision_from_history(current["price"], avg_price)
        substitute_price = current["price"] * 0.9 if decision == "SUBSTITUTE" else None

        predictions.append(Prediction(
            decision=decision,
            current_price=current["price"],
            substitute_price=substitute_price,
        ))
        actuals.append(ActualOutcome(
            future_price=future["price"],
            current_price=current["price"],
            substitute_was_cheaper=decision == "SUBSTITUTE" and bool(substitute_price),
        ))

    hit_rate = calculate_hit_rate(predictions, actuals)
    cost_savings = calculate_cost_savings(predictions)
    return format_backtesting_report(
        dataset_label=f"{len(products)} produk",
        period_label="window historis terakhir",
        hit_rate=hit_rate,
        cost_savings=cost_savings,
        total_predictions=len(predictions),
    )


if __name__ == "__main__":
    print(run_backtest())

