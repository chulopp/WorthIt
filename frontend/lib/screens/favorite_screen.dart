import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/favorite_controller.dart';
import '../models/dashboard_data.dart';
import '../models/api/api_models.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/recent_activity_card.dart';

class FavoriteScreen extends ConsumerStatefulWidget {
  const FavoriteScreen({super.key});

  @override
  ConsumerState<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends ConsumerState<FavoriteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(favoriteControllerProvider.notifier).fetchFavorites();
      }
    });
  }

  void _removeFavorite(FavoriteModel item) {
    ref
        .read(favoriteControllerProvider.notifier)
        .removeFavorite(item.productId);
    SnackbarHelper.showTopSnackbar(
      context,
      'favorite_removed_success'.tr(),
      icon: Icons.star,
    );
  }

  RecentActivity _activityFromFavorite(FavoriteModel item) {
    return RecentActivity(
      name: item.productName,
      price: item.currentPrice ?? 0,
      color: 'green',
      date: item.favoritedAt ?? DateTime.now().toIso8601String(),
      category: item.category ?? 'Lainnya',
      imageUrl: item.imageUrl,
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
    ref.listen(favoriteControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || previous?.errorMessage == message) return;
      SnackbarHelper.showTopSnackbar(
        context,
        message,
        icon: Icons.warning_amber_rounded,
      );
    });

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
      body: Builder(
        builder: (context) {
          final favoriteState = ref.watch(favoriteControllerProvider);
          final favoriteProductsList =
              favoriteState.data ?? const <FavoriteModel>[];
          if (favoriteState.isLoading && favoriteProductsList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (favoriteState.errorMessage != null &&
              favoriteProductsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  favoriteState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }
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
              final activity = _activityFromFavorite(item);
              return RecentActivityCard(
                item: activity,
                subtitleMode: RecentActivitySubtitleMode.categoryOnly,
                onTap: () => showProductDetailBottomSheet(
                  context,
                  productName: item.productName,
                  productCategory: item.category ?? 'Lainnya',
                  currentPrice: item.currentPrice ?? 0,
                  imageUrl: item.imageUrl,
                  productId: item.productId,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: Text(
                        _formatRp(item.currentPrice ?? 0),
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
