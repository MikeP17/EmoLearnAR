class EmotionLog {
  const EmotionLog({
    this.id,
    required this.sessionId,
    required this.emotion,
    required this.confidence,
    required this.timestamp,
  });

  final int? id;
  final String sessionId;
  final String emotion;
  final double confidence;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory EmotionLog.fromMap(Map<String, dynamic> map) {
    return EmotionLog(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      emotion: map['emotion'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
