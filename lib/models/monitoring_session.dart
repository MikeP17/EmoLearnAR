class MonitoringSession {
  const MonitoringSession({
    required this.id,
    required this.startedAt,
    required this.className,
    this.endedAt,
    this.totalSamples = 0,
    this.dominantEmotion = 'Neutral',
    this.reflectionNote = '',
  });

  final String id;
  final DateTime startedAt;
  final String className;
  final DateTime? endedAt;
  final int totalSamples;
  final String dominantEmotion;
  final String reflectionNote;

  String get displayName => className.trim().isEmpty ? id : className.trim();

  MonitoringSession copyWith({
    String? className,
    DateTime? endedAt,
    int? totalSamples,
    String? dominantEmotion,
    String? reflectionNote,
  }) {
    return MonitoringSession(
      id: id,
      startedAt: startedAt,
      className: className ?? this.className,
      endedAt: endedAt ?? this.endedAt,
      totalSamples: totalSamples ?? this.totalSamples,
      dominantEmotion: dominantEmotion ?? this.dominantEmotion,
      reflectionNote: reflectionNote ?? this.reflectionNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_name': className,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'total_samples': totalSamples,
      'dominant_emotion': dominantEmotion,
      'reflection_note': reflectionNote,
    };
  }

  factory MonitoringSession.fromMap(Map<String, dynamic> map) {
    return MonitoringSession(
      id: map['id'] as String,
      className: (map['class_name'] as String?) ?? (map['id'] as String),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      totalSamples: (map['total_samples'] as int?) ?? 0,
      dominantEmotion: (map['dominant_emotion'] as String?) ?? 'Neutral',
      reflectionNote: (map['reflection_note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'className': className,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'totalSamples': totalSamples,
      'dominantEmotion': dominantEmotion,
      'reflectionNote': reflectionNote,
    };
  }
}
