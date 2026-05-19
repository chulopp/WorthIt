OFFICIAL_CATEGORIES = (
    "Sembako",
    "Makanan Ringan",
    "Bumbu Dapur",
    "Makanan Beku",
    "Kesehatan dan Kebersihan",
    "Kebutuhan Rumah",
    "Minuman",
)


def is_official_category(category: str | None) -> bool:
    return bool(category and category in OFFICIAL_CATEGORIES)
