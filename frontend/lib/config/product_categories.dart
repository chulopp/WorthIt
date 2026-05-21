import 'package:easy_localization/easy_localization.dart';

const officialProductCategories = <String>[
  'Sembako',
  'Makanan Ringan',
  'Bumbu Dapur',
  'Makanan Beku',
  'Kesehatan dan Kebersihan',
  'Kebutuhan Rumah',
  'Minuman',
];

const allProductCategoryLabel = 'Semua';

String productCategoryTranslationKey(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) return 'cat_lainnya';
  final normalized = value.toLowerCase();

  if (normalized == 'all' || normalized == 'semua') return 'all';
  if (normalized.contains('sembako') ||
      normalized.contains('groceries') ||
      normalized.contains('beras') ||
      normalized.contains('minyak')) {
    return 'cat_sembako';
  }
  if (normalized.contains('makanan ringan') ||
      normalized.contains('cemilan') ||
      normalized.contains('snack')) {
    return 'cat_makanan_ringan';
  }
  if (normalized.contains('bumbu') || normalized.contains('seasoning')) {
    return 'cat_bumbu_dapur';
  }
  if (normalized.contains('beku') || normalized.contains('frozen')) {
    return 'cat_makanan_beku';
  }
  if (normalized.contains('alat mandi') ||
      normalized.contains('mandi') ||
      normalized.contains('toiletries')) {
    return 'cat_alat_mandi';
  }
  if (normalized.contains('kesehatan') ||
      normalized.contains('kebersihan') ||
      normalized.contains('health') ||
      normalized.contains('hygiene')) {
    return 'cat_kesehatan_kebersihan';
  }
  if (normalized.contains('rumah') || normalized.contains('household')) {
    return 'cat_kebutuhan_rumah';
  }
  if (normalized.contains('bayi') || normalized.contains('baby')) {
    return 'Susu & Bayi';
  }
  if (normalized.contains('susu') || normalized.contains('milk')) {
    return 'filter_milk';
  }
  if (normalized.contains('minuman') ||
      normalized.contains('beverage') ||
      normalized.contains('drink') ||
      normalized.contains('kopi')) {
    return 'cat_minuman';
  }
  if (normalized.contains('mie')) return 'filter_instant_noodle';
  if (normalized.contains('lain') || normalized.contains('other')) {
    return 'cat_lainnya';
  }

  return value;
}

String displayProductCategory(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) return 'cat_lainnya'.tr();
  final key = productCategoryTranslationKey(value);
  return key.tr();
}
