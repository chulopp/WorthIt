class OcrParserService {
  static final RegExp _priceRegex = RegExp(
    r'(?:Rp|RP|rp)?\s*\.?\s*(\d{1,3}(?:\.\d{3})*)',
  );
  static final RegExp _weightRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|gr)\b',
    caseSensitive: false,
  );

  static Map<String, dynamic> parseSupermarketLabel(String rawText) {
    final prices = _extractPrices(rawText);
    final weightMatch = _weightRegex.firstMatch(rawText);
    final weight = weightMatch == null
        ? null
        : double.tryParse(weightMatch.group(1) ?? '');
    final weightUnit = weightMatch?.group(2)?.toLowerCase();

    var sanitizedText = rawText;
    final weightMatches = _weightRegex.allMatches(rawText).toList();
    final extractedMatches = <RegExpMatch>[
      ...weightMatches,
      ..._priceRegex.allMatches(rawText).where(
            (priceMatch) => !weightMatches.any(
              (weightMatch) =>
                  priceMatch.start < weightMatch.end &&
                  weightMatch.start < priceMatch.end,
            ),
          ),
    ]..sort((a, b) => b.start.compareTo(a.start));

    for (final match in extractedMatches) {
      sanitizedText = sanitizedText.replaceRange(match.start, match.end, ' ');
    }

    sanitizedText = sanitizedText
        .replaceAll(RegExp(r'\b\d{8,}\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'), ' ')
        .replaceAll(RegExp(r'[^\nA-Za-z0-9\s]'), ' ');

    final nameCandidates = _findNameCandidates(sanitizedText);
    final productName = nameCandidates.isEmpty ? '' : nameCandidates.first;

    return <String, dynamic>{
      'productName': productName,
      'nameCandidates': nameCandidates,
      'price': prices.isEmpty ? null : prices.reduce((a, b) => a > b ? a : b),
      'weight': weight,
      'weightUnit': weightUnit,
      'rawText': rawText,
    };
  }

  static List<int> _extractPrices(String rawText) {
    final prices = <int>[];
    for (final match in _priceRegex.allMatches(rawText)) {
      final rawPrice = match.group(1);
      if (rawPrice == null || !rawPrice.contains('.')) continue;

      final parsedPrice = int.tryParse(rawPrice.replaceAll('.', ''));
      if (parsedPrice == null || parsedPrice <= 0) continue;
      prices.add(parsedPrice);
    }
    return prices;
  }

  static List<String> _findNameCandidates(String sanitizedText) {
    final candidates = sanitizedText
        .split('\n')
        .expand((line) => line.split(RegExp(r'\s{2,}')))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where(_isLikelyProductName)
        .toList();

    final flattened = sanitizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (candidates.isEmpty && _isLikelyProductName(flattened)) {
      candidates.add(flattened);
    }

    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates;
  }

  static bool _isLikelyProductName(String value) {
    final text = value.trim();
    if (text.length < 3) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) return false;
    if (RegExp(
      r'^(total|subtotal|tunai|kembali|qty|disc|diskon|harga|promo|sale)$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return false;
    }
    return true;
  }
}
