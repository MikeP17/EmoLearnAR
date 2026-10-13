class DetectedFace {
  const DetectedFace({
    required this.id,
    required this.emotion,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final int id;
  final String emotion;
  final double confidence;
  final double x;
  final double y;
  final double w;
  final double h;

  factory DetectedFace.fromJson(Map<String, dynamic> json) {
    return DetectedFace(
      id: ((json['id'] as num?) ?? 0).toInt(),
      emotion: (json['emotion'] as String?) ?? 'Neutral',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      x: ((json['x'] as num?) ?? 0).toDouble(),
      y: ((json['y'] as num?) ?? 0).toDouble(),
      w: ((json['w'] as num?) ?? 0).toDouble(),
      h: ((json['h'] as num?) ?? 0).toDouble(),
    );
  }

  DetectedFace copyWith({
    int? id,
    String? emotion,
    double? confidence,
    double? x,
    double? y,
    double? w,
    double? h,
  }) {
    return DetectedFace(
      id: id ?? this.id,
      emotion: emotion ?? this.emotion,
      confidence: confidence ?? this.confidence,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emotion': emotion,
      'confidence': confidence,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
    };
  }
}

class EmotionResult {
  const EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.timestamp,
    this.faces = const [],
    this.sourceWidth,
    this.sourceHeight,
    this.status,
  });

  final String emotion;
  final double confidence;
  final DateTime timestamp;
  final List<DetectedFace> faces;
  final double? sourceWidth;
  final double? sourceHeight;
  final String? status;

  factory EmotionResult.fromJson(Map<String, dynamic> json) {
    final rawFaces = (json['faces'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(DetectedFace.fromJson)
            .take(5)
            .toList() ??
        [];

    if (rawFaces.isNotEmpty) {
      final topFace = rawFaces.first;
      return EmotionResult(
        emotion: topFace.emotion,
        confidence: topFace.confidence,
        timestamp: DateTime.now(),
        faces: rawFaces,
        status: json['status'] as String?,
      );
    }

    return EmotionResult(
      emotion: (json['emotion'] as String?) ?? 'Neutral',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      timestamp: DateTime.now(),
      faces: rawFaces,
      status: json['status'] as String?,
    );
  }

  EmotionResult copyWith({
    String? emotion,
    double? confidence,
    DateTime? timestamp,
    List<DetectedFace>? faces,
    double? sourceWidth,
    double? sourceHeight,
    String? status,
  }) {
    return EmotionResult(
      emotion: emotion ?? this.emotion,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      faces: faces ?? this.faces,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'faces': faces.map((face) => face.toJson()).toList(),
      'status': status,
    };
  }
}
