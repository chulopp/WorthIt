import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dashboard_data.dart';
import '../services/favorite_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/recent_activity_card.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final FavoriteService _favoriteService = FavoriteService();

  @override
  void initState() {
    super.initState();
    _favoriteService.loadFavorites();
  }

  void _removeFavorite(RecentActivity item) {
    _favoriteService.removeFavorite(item);
    SnackbarHelper.showTopSnackbar(
      context,
      'favorite_removed_success'.tr(),
      icon: Icons.star,
    );
  }

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF1E293B);
    const bgScaffold = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgScaffold,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Favorit',
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: ValueListenableBuilder<List<RecentActivity>>(
        valueListenable: _favoriteService.favoriteProducts,
        builder: (context, favoriteProductsList, child) {
          if (favoriteProductsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada produk favorit yang disimpan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: favoriteProductsList.length,
            itemBuilder: (context, index) {
              final item = favoriteProductsList[index];
              return RecentActivityCard(
                item: item,
                subtitleMode: RecentActivitySubtitleMode.categoryOnly,
                onTap: () => showProductDetailBottomSheet(
                  context,
                  productName: item.name,
                  productCategory: item.category,
                  currentPrice: item.price,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: Text(
                        _formatRp(item.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeFavorite(item),
                      icon: const Icon(
                        Icons.star,
                        color: Color(0xFFC9E88A),
                        size: 22,
                      ),
                      splashRadius: 18,
                      tooltip: 'Hapus dari favorit',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
