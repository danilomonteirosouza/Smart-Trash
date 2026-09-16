import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../domain/recycling_result.dart';

class VisionService {
  final ImageLabeler _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.45));

  static const Map<RecyclingCategory, Set<String>> keywords = {
    RecyclingCategory.paper: {'paper', 'cardboard', 'carton', 'newspaper', 'book', 'document', 'box'},
    RecyclingCategory.plastic: {'plastic', 'bottle', 'container', 'packaging', 'jug', 'cup'},
    RecyclingCategory.metal: {'metal', 'aluminum', 'aluminium', 'can', 'tin', 'steel'},
    RecyclingCategory.glass: {'glass', 'jar', 'wine bottle'},
  };

  Future<RecyclingResult> classify(String filePath, {bool metalSensor = false}) async {
    if (metalSensor) {
      return const RecyclingResult(category: RecyclingCategory.metal, label: 'Metal confirmado pelo sensor', confidence: 0.99, evidence: ['sensor indutivo']);
    }
    final labels = await _labeler.processImage(InputImage.fromFilePath(filePath));
    final scores = <RecyclingCategory, double>{};
    final evidence = <String>[];
    for (final label in labels.take(12)) {
      final text = label.label.toLowerCase();
      evidence.add('${label.label} ${(label.confidence * 100).toStringAsFixed(0)}%');
      for (final entry in keywords.entries) {
        if (entry.value.any((word) => text.contains(word))) {
          scores[entry.key] = (scores[entry.key] ?? 0) + label.confidence;
        }
      }
    }
    if (scores.isEmpty) {
      return RecyclingResult(category: RecyclingCategory.unknown, label: 'Evidência visual insuficiente', confidence: 0, evidence: evidence);
    }
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final normalized = best.value.clamp(0.0, 1.0);
    if (normalized < 0.60) {
      return RecyclingResult(category: RecyclingCategory.unknown, label: 'Baixa confiança — tente outra foto', confidence: normalized, evidence: evidence);
    }
    return RecyclingResult(category: best.key, label: 'Sugestão baseada na imagem', confidence: normalized, evidence: evidence);
  }

  Future<void> dispose() => _labeler.close();
}
