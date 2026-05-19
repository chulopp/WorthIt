import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/history_controller.dart';
import '../models/dashboard_data.dart';
import '../models/api/api_models.dart';
import '../widgets/recent_activity_card.dart';
import '../widgets/product_analysis_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(historyControllerProvider.notifier).fetchScans();
    });
  }

  RecentActivity _activityFromScan(ScanHistoryItemModel item) {
    return RecentActivity(
      name: item.productName,
      price: item.scannedPrice ?? item.normalPrice ?? 0,
      color: _colorFromDecision(item.decision),
      date: item.scannedAt,
      category: item.category ?? 'Lainnya',
      imageUrl: item.imageUrl ?? item.analysis.imageUrl,
    );
  }

  void _showHistoryAnalysis(
    BuildContext context,
    ScanHistoryItemModel item,
  ) {
    showHistoryAnalysisSheet(
      context,
      data: item,
    );
  }

  String _colorFromDecision(String? decision) {
    final value = (decision ?? '').toUpperCase();
    if (value.contains('MAHAL') || value.contains('DONT')) return 'red';
    if (value.contains('WASPADA') || value.contains('SUBSTITUTE')) {
      return 'yellow';
    }
    return 'green';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final items = (state.data?.scans ?? const <ScanHistoryItemModel>[])
        .map(_activityFromScan)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: Text(
          'dashboard.history'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: state.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          : items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada riwayat scan barang',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return RecentActivityCard(
                  item: items[index],
                  subtitleMode: RecentActivitySubtitleMode.decisionBadgeOnly,
                  onTap: () => _showHistoryAnalysis(
                    context,
                    state.data!.scans[index],
                  ),
                );
              },
            ),
    );
  }
}
