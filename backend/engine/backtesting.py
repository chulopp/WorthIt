from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class Prediction:
    decision: str
    current_price: float
    substitute_price: float | None = None


@dataclass(frozen=True)
class ActualOutcome:
    future_price: float
    current_price: float
    substitute_was_cheaper: bool = False


def calculate_hit_rate(
    predictions: Iterable[Prediction],
    actuals: Iterable[ActualOutcome],
) -> float:
    """
    PRD hit-rate metric.

    BUY is correct when future price is >= current price.
    DONT_BUY is correct when future price drops.
    SUBSTITUTE is correct when the substitute was actually cheaper.
    """
    prediction_list = list(predictions)
    actual_list = list(actuals)
    total = min(len(prediction_list), len(actual_list))
    if total == 0:
        return 0.0

    correct = 0
    for pred, actual in zip(prediction_list[:total], actual_list[:total]):
        decision = pred.decision.upper()
        if decision == "BUY" and actual.future_price >= actual.current_price:
            correct += 1
        elif decision == "DONT_BUY" and actual.future_price < actual.current_price:
            correct += 1
        elif decision == "SUBSTITUTE" and actual.substitute_was_cheaper:
            correct += 1

    return round((correct / total) * 100, 2)


def calculate_cost_savings(recommendations: Iterable[Prediction]) -> float:
    """
    PRD cost-savings metric.

    Baseline is buying every scanned item at current price. WorthIt outcome is:
    BUY -> current price, SUBSTITUTE -> substitute price, DONT_BUY -> zero spend.
    """
    recs = list(recommendations)
    total_without_worthit = sum(r.current_price for r in recs)
    if total_without_worthit <= 0:
        return 0.0

    total_with_worthit = 0.0
    for rec in recs:
        decision = rec.decision.upper()
        if decision == "BUY":
            total_with_worthit += rec.current_price
        elif decision == "SUBSTITUTE":
            total_with_worthit += rec.substitute_price or rec.current_price

    savings = total_without_worthit - total_with_worthit
    return round((savings / total_without_worthit) * 100, 2)


def format_backtesting_report(
    dataset_label: str,
    period_label: str,
    hit_rate: float,
    cost_savings: float,
    total_predictions: int,
) -> str:
    return (
        "LAPORAN BACKTESTING WORTHIT v1.0\n"
        "=================================\n"
        f"Dataset             : {dataset_label}\n"
        f"Periode             : {period_label}\n"
        f"Jumlah Prediksi     : {total_predictions}\n\n"
        "METRIK TEKNIS\n"
        f"Hit Rate Keseluruhan: {hit_rate:.2f}%\n\n"
        "METRIK BISNIS\n"
        f"Cost Savings Impact : {cost_savings:.2f}%\n"
    )

