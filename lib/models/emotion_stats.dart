import '../core/emotion_meta.dart';
import 'emotion_log.dart';

class EmotionStats {
  EmotionStats(this.counts);

  final Map<String, int> counts;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  int countFor(String emotion) => counts[emotion] ?? 0;

  double percentFor(String emotion) {
    if (total == 0) return 0;
    return (countFor(emotion) / total) * 100;
  }

  String get dominantEmotion {
    if (total == 0) return EmotionCatalog.neutral;
    return EmotionCatalog.orderedLabels.reduce((a, b) {
      return countFor(a) >= countFor(b) ? a : b;
    });
  }

  double get engagementScore {
    if (total == 0) return 0;
    final positive = countFor(EmotionCatalog.positive);
    final neutral = countFor(EmotionCatalog.neutral) * 0.5;
    final confused = countFor(EmotionCatalog.confused) * 0.25;
    return ((positive + neutral + confused) / total) * 100;
  }

  factory EmotionStats.empty() {
    return EmotionStats({
      for (final emotion in EmotionCatalog.orderedLabels) emotion: 0,
    });
  }

  factory EmotionStats.fromLogs(List<EmotionLog> logs) {
    final counts = {
      for (final emotion in EmotionCatalog.orderedLabels) emotion: 0,
    };
    for (final log in logs) {
      counts[log.emotion] = (counts[log.emotion] ?? 0) + 1;
    }
    return EmotionStats(counts);
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSamples': total,
      'dominantEmotion': dominantEmotion,
      'engagementScore': engagementScore,
      'percentages': {
        for (final emotion in EmotionCatalog.orderedLabels)
          emotion: percentFor(emotion),
      },
      'counts': counts,
    };
  }
}
