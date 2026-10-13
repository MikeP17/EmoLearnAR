import 'package:flutter/material.dart';

class EmotionMeta {
  const EmotionMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final String label;
  final String icon;
  final Color color;
  final Color softColor;
}

class EmotionCatalog {
  static const positive = 'Positive';
  static const neutral = 'Neutral';
  static const confused = 'Confused';
  static const negative = 'Negative';

  static const orderedLabels = [
    positive,
    neutral,
    confused,
    negative,
  ];

  static const Map<String, EmotionMeta> meta = {
    positive: EmotionMeta(
      label: positive,
      icon: '😊',
      color: Color(0xFF10B981),
      softColor: Color(0xFFE7F8F0),
    ),
    neutral: EmotionMeta(
      label: neutral,
      icon: '😐',
      color: Color(0xFF64748B),
      softColor: Color(0xFFF1F5F9),
    ),
    confused: EmotionMeta(
      label: confused,
      icon: '😕',
      color: Color(0xFFF59E0B),
      softColor: Color(0xFFFFF7E6),
    ),
    negative: EmotionMeta(
      label: negative,
      icon: '😡',
      color: Color(0xFFEF4444),
      softColor: Color(0xFFFEECEC),
    ),
  };

  static EmotionMeta of(String emotion) {
    return meta[emotion] ?? meta[neutral]!;
  }
}
