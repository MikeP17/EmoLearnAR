import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.extendBodyBehindAppBar = false,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFF6FF),
                    Color(0xFFF8FAFC),
                    Color(0xFFFFF7ED),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridTexturePainter())),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 24),
    this.maxWidth = 1100,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _GridTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.035)
      ..strokeWidth = 1;

    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
