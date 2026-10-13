import 'package:flutter/material.dart';

import '../core/emotion_meta.dart';

class EmotionBadge extends StatelessWidget {
  const EmotionBadge({
    super.key,
    required this.emotion,
    this.confidence,
    this.compact = false,
  });

  final String emotion;
  final double? confidence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = EmotionCatalog.of(emotion);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 8 : 13,
      ),
      decoration: BoxDecoration(
        color: compact ? meta.softColor : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.color.withOpacity(0.28)),
        boxShadow: [
          if (!compact)
            BoxShadow(
              color: meta.color.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 26 : 34,
            height: compact ? 26 : 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: meta.softColor,
              shape: BoxShape.circle,
            ),
            child: Text(meta.icon, style: TextStyle(fontSize: compact ? 15 : 20)),
          ),
          const SizedBox(width: 8),
          Text(
            confidence == null
                ? emotion
                : '$emotion ${(confidence! * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: meta.color,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
