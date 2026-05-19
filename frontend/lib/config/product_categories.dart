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

String displayProductCategory(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) return 'Lainnya';
  return value;
}
