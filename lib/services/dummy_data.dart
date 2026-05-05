import '../models/product_analysis.dart';
import '../models/dashboard_data.dart';
import '../models/tracker_data.dart';

class DummyDataService {
  static ProductAnalysis getDummyAnalysis() {
    return ProductAnalysis(
      decision: "SUBSTITUTE",
      color: "yellow",
      score: 42,
      insights: [
        "Harga Rp3.500 untuk 80g = Rp43.75/g",
        "Rata-rata 3 bulan terakhir: Rp3.200 (Rp40/g)",
        "⚠️ Terdeteksi kenaikan 9.4% tanpa perubahan kualitas",
      ],
      reasoning:
          "Harga Indomie Goreng saat ini berada di atas level resistance Rp3.300. Disarankan beralih ke Mie Sedaap yang menawarkan rasio harga/gram 20% lebih hemat.",
      substitution: Substitution(
        productName: "Mie Sedaap Goreng",
        price: 3000,
        weightGram: 86,
        pricePerGram: 34.88,
        savingsPercent: 20.3,
      ),
    );
  }

  static DashboardData getDummyDashboard() {
    return DashboardData(
      monthlyBudget: 2000000,
      budgetRemaining: 1250000,
      moneySaved: 187500,
      recentItems: [
        RecentActivity(name: "Indomie Goreng", price: 3500, color: "yellow"),
        RecentActivity(name: "Susu UHT 1L", price: 18500, color: "green"),
        RecentActivity(name: "Keripik Kentang 68g", price: 15000, color: "red"),
        RecentActivity(name: "Minyak Goreng 2L", price: 34000, color: "green"),
        RecentActivity(name: "Kopi Instan", price: 12000, color: "yellow"),
      ],
    );
  }

  static TrackerData getDummyTracker() {
    return TrackerData(
      totalSpent: 750000,
      totalItems: 23,
      avgPerItem: 32608,
      byCategory: [
        CategorySummary(category: "Susu & Olahan", amount: 200000, percentage: 26.7),
        CategorySummary(category: "Mie Instan", amount: 150000, percentage: 20.0),
        CategorySummary(category: "Snack & Biskuit", amount: 100000, percentage: 13.3),
        CategorySummary(category: "Minuman", amount: 150000, percentage: 20.0),
        CategorySummary(category: "Lain-lain", amount: 150000, percentage: 20.0),
      ],
      items: [
        TrackerItem(productName: "Susu UHT 1L", pricePaid: 18500, date: "2026-05-04", decisionScore: 85),
        TrackerItem(productName: "Mie Sedaap Goreng", pricePaid: 3000, date: "2026-05-05", decisionScore: 42),
        TrackerItem(productName: "Roti Tawar", pricePaid: 15000, date: "2026-05-03", decisionScore: 78),
        TrackerItem(productName: "Kopi Instan", pricePaid: 12000, date: "2026-05-02", decisionScore: 55),
        TrackerItem(productName: "Air Mineral 1.5L", pricePaid: 6000, date: "2026-05-01", decisionScore: 90),
      ],
    );
  }
}
