String normalizeForSimilarity(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int levenshteinDistance(String source, String target) {
  if (source.isEmpty) return target.length;
  if (target.isEmpty) return source.length;

  final previous = List<int>.generate(target.length + 1, (index) => index);
  final current = List<int>.filled(target.length + 1, 0);

  for (var i = 0; i < source.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < target.length; j++) {
      final substitutionCost = source[i] == target[j] ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + substitutionCost,
      ].reduce((a, b) => a < b ? a : b);
    }

    for (var j = 0; j < current.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous.last;
}

double calculateStringSimilarity(String first, String second) {
  final normalizedFirst = normalizeForSimilarity(first);
  final normalizedSecond = normalizeForSimilarity(second);

  if (normalizedFirst.isEmpty && normalizedSecond.isEmpty) {
    return 1;
  }
  if (normalizedFirst.isEmpty || normalizedSecond.isEmpty) {
    return 0;
  }

  final maxLength = normalizedFirst.length > normalizedSecond.length
      ? normalizedFirst.length
      : normalizedSecond.length;
  final distance = levenshteinDistance(normalizedFirst, normalizedSecond);

  return 1 - (distance / maxLength);
}
