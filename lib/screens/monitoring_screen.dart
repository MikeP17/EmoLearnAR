import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/monitoring_provider.dart';
import '../widgets/ar_overlay.dart';
import '../widgets/emotion_badge.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({
    super.key,
    this.initialClassName,
    this.initialClassTime,
  });

  final String? initialClassName;
  final String? initialClassTime;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  CameraController? _controller;
  Future<void>? _initializeCameraFuture;
  Timer? _timer;
  late final String _className;
  bool _isCapturing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _className = widget.initialClassName ?? 'TTTK4086 Project';
    _initializeCameraFuture = _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().checkBackendHealth();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found on this device.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _cameraError = error.toString());
    }
  }

  Future<void> _toggleMonitoring() async {
    final provider = context.read<MonitoringProvider>();
    if (provider.isMonitoring) {
      _timer?.cancel();
      await provider.stopSession();
      return;
    }

    if (provider.isSessionDirty) {
      await provider.resumeSession();
    } else {
      await provider.startSession(className: _className);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _captureAndAnalyze();
    });
    await _captureAndAnalyze();
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _controller;
    final provider = context.read<MonitoringProvider>();
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        !provider.isMonitoring) {
      return;
    }

    _isCapturing = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await provider.processFrame(bytes);
    } finally {
      _isCapturing = false;
    }
  }

  Future<bool> _handleBack() async {
    final provider = context.read<MonitoringProvider>();
    if (!provider.isSessionDirty) return true;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save session?'),
        content: const Text(
          'You have unsaved detection data. Save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Don\'t save'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true) {
      await provider.saveSession();
    } else {
      await provider.discardSession();
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitoringProvider>(
      builder: (context, provider, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final allowed = await _handleBack();
            if (allowed && mounted) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
          backgroundColor: const Color(0xFF020617),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 560 : constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 20 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(wide ? 34 : 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: Colors.white.withOpacity(wide ? 0.12 : 0),
                            ),
                            boxShadow: [
                              if (wide)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 40,
                                  offset: const Offset(0, 24),
                                ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(child: _buildCamera()),
                              Positioned.fill(
                                child: AROverlay(
                                  result: provider.latestResult,
                                  isDetecting: provider.isDetecting,
                                  detectionStatus: provider.detectionStatus,
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: _MonitoringTopBar(
                                  isMonitoring: provider.isMonitoring,
                                  isBackendConnected:
                                      provider.isBackendConnected,
                                  className:
                                      provider.currentSession?.displayName ??
                                          _className,
                                  classTime: widget.initialClassTime,
                                  onBack: provider.isMonitoring
                                      ? null
                                      : () async {
                                          final allowed = await _handleBack();
                                          if (allowed && mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 18,
                                child: _MonitoringControls(
                                  provider: provider,
                                  onToggle: _toggleMonitoring,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildCamera() {
    if (_cameraError != null) {
      return _CameraMessage(message: _cameraError!);
    }

    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const _CameraMessage(message: 'Preparing camera');
        }

        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }
}

class _MonitoringTopBar extends StatelessWidget {
  const _MonitoringTopBar({
    required this.isMonitoring,
    required this.isBackendConnected,
    required this.className,
    required this.classTime,
    required this.onBack,
  });

  final bool isMonitoring;
  final bool isBackendConnected;
  final String className;
  final String? classTime;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9),
              foregroundColor: const Color(0xFF0B1120),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF020617).withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF7DD3FC),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        className.trim().isEmpty
                            ? 'AI Emotion Scan'
                            : className.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      if (classTime != null && classTime!.trim().isNotEmpty)
                        Text(
                          classTime!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMonitoring
                ? const Color(0xFF22C55E).withOpacity(0.92)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isMonitoring ? 'LIVE' : 'IDLE',
            style: TextStyle(
              color: isMonitoring ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBackendConnected
                ? const Color(0xFF22C55E)
                : const Color(0xFFEF4444),
            boxShadow: [
              BoxShadow(
                color: (isBackendConnected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444))
                    .withOpacity(0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonitoringControls extends StatelessWidget {
  const _MonitoringControls({
    required this.provider,
    required this.onToggle,
  });

  final MonitoringProvider provider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final result = provider.latestResult;
    final faceCount = result?.faces.length ?? 0;
    final hasFaces = faceCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: !hasFaces
                    ? Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.center_focus_strong_rounded,
                              color: Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Waiting for reliable face detections.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      )
                    : FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: EmotionBadge(
                          emotion: result!.emotion,
                          confidence: result.confidence,
                          compact: true,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasFaces
                      ? '$faceCount face${faceCount == 1 ? '' : 's'}'
                      : '${provider.logs.length} samples',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 10),
            _StatusChip(status: provider.detectionStatus),
            if (provider.detectionStatus ==
                DetectionStatus.backendDisconnected) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      context.read<MonitoringProvider>().checkBackendHealth(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry connection',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 10),
            _StatusChip(status: provider.detectionStatus),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: provider.isMonitoring
                          ? const [Color(0xFFEF4444), Color(0xFFFB7185)]
                          : const [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (provider.isMonitoring
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF2563EB))
                            .withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: onToggle,
                    icon: Icon(
                      provider.isMonitoring
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      provider.isMonitoring ? 'Stop Monitoring' : 'Start Scan',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Dashboard',
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.dashboard,
                  arguments: {'fromMonitoring': true},
                ),
                icon: const Icon(Icons.query_stats_rounded),
              ),
              if (provider.isSessionDirty) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Save session',
                  onPressed: () async {
                    await provider.saveSession();
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, AppRoutes.summary);
                  },
                  icon: const Icon(Icons.save_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DetectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      DetectionStatus.analyzing => (
          Icons.sync_rounded,
          'Analyzing...',
          const Color(0xFF0284C7),
        ),
      DetectionStatus.noFace => (
          Icons.face_retouching_off_rounded,
          'No face detected',
          const Color(0xFF64748B),
        ),
      DetectionStatus.lowConfidence => (
          Icons.warning_amber_rounded,
          'Low confidence',
          const Color(0xFFD97706),
        ),
      DetectionStatus.backendDisconnected => (
          Icons.cloud_off_rounded,
          'Backend disconnected',
          const Color(0xFFDC2626),
        ),
      DetectionStatus.faceDetected => (
          Icons.check_circle_rounded,
          'Face detected',
          const Color(0xFF16A34A),
        ),
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
