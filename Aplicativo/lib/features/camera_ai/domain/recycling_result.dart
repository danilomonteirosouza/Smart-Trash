enum RecyclingCategory { paper, plastic, metal, glass, unknown }

class RecyclingResult {
  const RecyclingResult({required this.category, required this.label, required this.confidence, required this.evidence});
  final RecyclingCategory category;
  final String label;
  final double confidence;
  final List<String> evidence;

  String get categoryName => switch (category) {
        RecyclingCategory.paper => 'Papel',
        RecyclingCategory.plastic => 'Plástico',
        RecyclingCategory.metal => 'Metal',
        RecyclingCategory.glass => 'Vidro',
        RecyclingCategory.unknown => 'Não identificado',
      };
}
