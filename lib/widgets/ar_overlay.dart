import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/emotion_meta.dart';
import '../models/emotion_result.dart';
import '../services/api_service.dart';

class AROverlay extends StatefulWidget {
  const AROverlay({
    super.key,
    required this.result,
    required this.isDetecting,
    required this.detectionStatus,
  });

  final EmotionResult? result;
  final bool isDetecting;
  final DetectionStatus detectionStatus;

  @override
  State<AROverlay> createState() => _AROverlayState();
}

class _AROverlayState extends State<AROverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStatusPill(List<DetectedFace> faces) {
    final status = widget.detectionStatus;
    final faceCount = faces.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: switch (status) {
        DetectionStatus.analyzing => _HudPill(
            key: const ValueKey('analyzing'),
            icon: Icons.sync_rounded,
            text: 'Analyzing...',
            color: const Color(0xFF38BDF8),
            loading: widget.isDetecting,
          ),
        DetectionStatus.noFace => _HudPill(
            key: const ValueKey('noFace'),
            icon: Icons.face_retouching_off_rounded,
            text: 'No face detected',
            color: const Color(0xFF94A3B8),
            loading: false,
          ),
        DetectionStatus.lowConfidence => _HudPill(
            key: ValueKey('lowConf-$faceCount'),
            icon: Icons.warning_amber_rounded,
            text: faceCount > 0
                ? '$faceCount face${faceCount == 1 ? '' : 's'} · low confidence'
                : 'Low confidence',
            color: const Color(0xFFF59E0B),
            loading: widget.isDetecting,
          ),
        DetectionStatus.backendDisconnected => _HudPill(
            key: const ValueKey('disconnected'),
            icon: Icons.cloud_off_rounded,
            text: 'Backend disconnected',
            color: const Color(0xFFEF4444),
            loading: false,
          ),
        DetectionStatus.faceDetected => _HudPill(
            key: ValueKey('faces-$faceCount'),
            icon: Icons.groups_rounded,
            text: '$faceCount face${faceCount == 1 ? '' : 's'} detected',
            color: const Color(0xFF7DD3FC),
            loading: widget.isDetecting,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final faces = widget.result?.faces.take(5).toList() ?? [];
    final accent = faces.isEmpty
        ? const Color(0xFF38BDF8)
        : EmotionCatalog.of(faces.first.emotion).color;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overlaySize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ScanSurfacePainter(
                        progress: _controller.value,
                        accent: accent,
                        active: widget.isDetecting,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 74,
                left: 20,
                right: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildStatusPill(faces),
                ),
              ),
              if (widget.result != null)
                for (final face in faces)
                  _FaceOverlayBadge(
                    key: ValueKey('face-${widget.result!.timestamp.millisecondsSinceEpoch}-${face.id}'),
                    face: face,
                    result: widget.result!,
                    overlaySize: overlaySize,
                  ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 132,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: widget.isDetecting ? 1 : 0.56,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.18),
                          accent,
                          Colors.white.withOpacity(0.86),
                          accent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FaceOverlayBadge extends StatelessWidget {
  const _FaceOverlayBadge({
    super.key,
    required this.face,
    required this.result,
    required this.overlaySize,
  });

  final DetectedFace face;
  final EmotionResult result;
  final Size overlaySize;

  @override
  Widget build(BuildContext context) {
    final sourceWidth = result.sourceWidth;
    final sourceHeight = result.sourceHeight;
    if (sourceWidth == null || sourceHeight == null) {
      return const SizedBox.shrink();
    }

    final rect = _mapFaceRect(
      face: face,
      sourceSize: Size(sourceWidth, sourceHeight),
      overlaySize: overlaySize,
    );
    final meta = EmotionCatalog.of(face.emotion);
    const badgeWidth = 118.0;
    final maxLeft = math.max(12.0, overlaySize.width - badgeWidth - 12);
    final minTop = math.min(118.0, overlaySize.height - 120);
    final maxTop = math.max(minTop, overlaySize.height - 190);
    final badgeLeft =
        (rect.center.dx - (badgeWidth / 2)).clamp(12.0, maxLeft).toDouble();
    final badgeTop = (rect.top - 42).clamp(minTop, maxTop).toDouble();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      left: badgeLeft,
      top: badgeTop,
      width: badgeWidth,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF020617).withOpacity(0.58),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: meta.color.withOpacity(0.45)),
                boxShadow: [
                  BoxShadow(
                    color: meta.color.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(meta.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      face.emotion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.82),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Rect _mapFaceRect({
    required DetectedFace face,
    required Size sourceSize,
    required Size overlaySize,
  }) {
    final scale = math.min(
      overlaySize.width / sourceSize.width,
      overlaySize.height / sourceSize.height,
    );
    final displayWidth = sourceSize.width * scale;
    final displayHeight = sourceSize.height * scale;
    final dx = (overlaySize.width - displayWidth) / 2;
    final dy = (overlaySize.height - displayHeight) / 2;

    return Rect.fromLTWH(
      dx + face.x * scale,
      dy + face.y * scale,
      face.w * scale,
      face.h * scale,
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.loading,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withOpacity(0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSurfacePainter extends CustomPainter {
  _ScanSurfacePainter({
    required this.progress,
    required this.accent,
    required this.active,
  });

  final double progress;
  final Color accent;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x66000000),
          Color(0x08000000),
          Color(0x99000000),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, scrim);

    final scanY = size.height * progress;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withOpacity(0),
          accent.withOpacity(active ? 0.75 : 0.34),
          accent.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(24, scanY - 1, size.width - 48, 2))
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(24, scanY),
      Offset(size.width - 24, scanY),
      scanPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white.withOpacity(0.34)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const inset = 22.0;
    const corner = 24.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + corner, inset),
      cornerPaint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + corner),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - corner, inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + corner),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanSurfacePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.active != active;
  }
}
