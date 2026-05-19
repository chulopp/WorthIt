import unittest

from engine.scoring import run_analysis


BUCKETS = [
    {"avg_price": 10000, "avg_weight": 100},
    {"avg_price": 10200, "avg_weight": 100},
    {"avg_price": 10100, "avg_weight": 100},
    {"avg_price": 10300, "avg_weight": 100},
    {"avg_price": 10400, "avg_weight": 100},
    {"avg_price": 10500, "avg_weight": 100},
]


class ScoringTest(unittest.TestCase):
    def test_price_below_wma_is_worthit(self):
        result = run_analysis(9500, 100, 2, BUCKETS, "FREE")
        self.assertEqual(result["decision"], "WorthIt")
        self.assertGreaterEqual(result["score"], 75)

    def test_price_near_wma_is_not_mahal(self):
        result = run_analysis(10300, 100, 2, BUCKETS, "FREE")
        self.assertIn(result["decision"], {"WorthIt", "Waspada"})

    def test_high_price_is_mahal(self):
        result = run_analysis(14000, 100, 1, BUCKETS, "FREE")
        self.assertEqual(result["decision"], "Mahal")

    def test_urgency_cannot_hide_extreme_price(self):
        result = run_analysis(16000, 100, 3, BUCKETS, "FREE")
        self.assertEqual(result["decision"], "Mahal")

    def test_pro_gets_price_anomaly_detection(self):
        result = run_analysis(14000, 100, 1, BUCKETS, "PRO")
        self.assertIsNotNone(result["price_anomaly"])
        self.assertTrue(result["price_anomaly"]["detected"])

    def test_free_locks_pro_anomaly_features(self):
        result = run_analysis(14000, 100, 1, BUCKETS, "FREE")
        self.assertIsNone(result["price_anomaly"])
        self.assertIn("price_anomaly_detection", result["locked_features"])
        self.assertIn("shrinkflation_detection", result["locked_features"])


if __name__ == "__main__":
    unittest.main()
