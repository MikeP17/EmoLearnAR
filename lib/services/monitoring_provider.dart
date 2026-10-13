import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/emotion_meta.dart';
import '../models/emotion_log.dart';
import '../models/emotion_result.dart';
import '../models/emotion_stats.dart';
import '../models/monitoring_session.dart';
import 'api_service.dart';
import 'database_service.dart';

class MonitoringProvider extends ChangeNotifier {
  MonitoringProvider({
    ApiService? apiService,
    DatabaseService? databaseService,
  })  : _apiService = apiService ?? ApiService(),
        _databaseService = databaseService ?? DatabaseService.instance;

  final ApiService _apiService;
  final DatabaseService _databaseService;
  static const MethodChannel _excelExportChannel = MethodChannel(
    'emolearnar/excel_export',
  );

  MonitoringSession? _currentSession;
  EmotionResult? _latestResult;
  List<EmotionLog> _logs = [];
  List<MonitoringSession> _sessions = [];
  bool _isMonitoring = false;
  bool _isDetecting = false;
  bool _isSessionDirty = false;
  int _frameRequestId = 0;
  Future<void> _reflectionSaveQueue = Future.value();
  String? _error;
  DetectionStatus _detectionStatus = DetectionStatus.analyzing;
  bool _isBackendConnected = false;
  bool _isCheckingHealth = false;

  MonitoringSession? get currentSession => _currentSession;
  EmotionResult? get latestResult => _latestResult;
  List<EmotionLog> get logs => List.unmodifiable(_logs);
  List<MonitoringSession> get sessions => List.unmodifiable(_sessions);
  EmotionStats get stats => EmotionStats.fromLogs(_logs);
  bool get isMonitoring => _isMonitoring;
  bool get isDetecting => _isDetecting;
  bool get isSessionDirty => _isSessionDirty;
  String? get error => _error;
  DetectionStatus get detectionStatus => _detectionStatus;
  bool get isBackendConnected => _isBackendConnected;
  bool get isCheckingHealth => _isCheckingHealth;
  String get backendUrl => _apiService.baseUrl;

  Future<void> loadHistory() async {
    _sessions = await _databaseService.allSessions();
    final latest = _sessions.isEmpty ? null : _sessions.first;
    if (_currentSession == null && latest != null) {
      _currentSession = latest;
      _logs = await _databaseService.logsForSession(latest.id);
    }
    notifyListeners();
  }

  Future<void> loadSession(String sessionId) async {
    final all = await _databaseService.allSessions();
    _sessions = all;
    _currentSession = null;
    for (final session in all) {
      if (session.id == sessionId) {
        _currentSession = session;
        break;
      }
    }
    _logs = await _databaseService.logsForSession(sessionId);
    _latestResult = _logs.isEmpty
        ? null
        : EmotionResult(
            emotion: _logs.last.emotion,
            confidence: _logs.last.confidence,
            timestamp: _logs.last.timestamp,
            faces: const [],
          );
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    if (_currentSession?.id == sessionId && _isMonitoring) {
      _isMonitoring = false;
    }

    await _databaseService.deleteSession(sessionId);
    _sessions = await _databaseService.allSessions();

    if (_currentSession?.id == sessionId) {
      final next = _sessions.isEmpty ? null : _sessions.first;
      _currentSession = next;
      _latestResult = null;
      _logs = next == null
          ? []
          : await _databaseService.logsForSession(next.id);
      if (_logs.isNotEmpty) {
        _latestResult = EmotionResult(
          emotion: _logs.last.emotion,
          confidence: _logs.last.confidence,
          timestamp: _logs.last.timestamp,
          faces: const [],
        );
      }
    }

    notifyListeners();
  }

  Future<void> startSession({required String className}) async {
    final now = DateTime.now();
    final session = MonitoringSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      className: className.trim().isEmpty ? 'Untitled Class' : className.trim(),
      startedAt: now,
    );
    _currentSession = session;
    _latestResult = null;
    _logs = [];
    _isMonitoring = true;
    _isSessionDirty = false;
    _error = null;
    _detectionStatus = DetectionStatus.analyzing;
    await _databaseService.insertSession(session);
    await loadHistory();
    _currentSession = session;
    _isMonitoring = true;
    notifyListeners();
  }

  Future<void> stopSession() async {
    if (_currentSession == null) return;
    _isMonitoring = false;
    _isSessionDirty = true;
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (_currentSession == null) return;
    _isMonitoring = true;
    _isSessionDirty = false;
    _error = null;
    _detectionStatus = DetectionStatus.analyzing;
    notifyListeners();
  }

  Future<void> saveSession() async {
    if (_currentSession == null) return;
    final finished = _currentSession!.copyWith(
      endedAt: DateTime.now(),
      totalSamples: _logs.length,
      dominantEmotion: stats.dominantEmotion,
    );
    _currentSession = finished;
    _isSessionDirty = false;
    await _databaseService.updateSession(finished);
    await loadHistory();
    notifyListeners();
  }

  Future<void> discardSession() async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;
    _currentSession = null;
    _logs = [];
    _latestResult = null;
    _isMonitoring = false;
    _isSessionDirty = false;
    _error = null;
    await _databaseService.deleteSession(sessionId);
    await loadHistory();
    notifyListeners();
  }

  Future<void> checkBackendHealth() async {
    _isCheckingHealth = true;
    notifyListeners();
    _isBackendConnected = await _apiService.checkHealth();
    _isCheckingHealth = false;
    if (!_isBackendConnected) {
      _detectionStatus = DetectionStatus.backendDisconnected;
    } else {
      _error = null;
      _detectionStatus = DetectionStatus.analyzing;
    }
    notifyListeners();
  }

  Future<void> updateReflectionNote(String note) async {
    final session = _currentSession;
    if (session == null) return;

    final updated = session.copyWith(reflectionNote: note);
    _currentSession = updated;
    _sessions = [
      for (final item in _sessions) item.id == updated.id ? updated : item,
    ];
    notifyListeners();
    _reflectionSaveQueue = _reflectionSaveQueue
        .then((_) => _databaseService.updateSession(updated))
        .catchError((_) {});
    await _reflectionSaveQueue;
  }

  Future<void> processFrame(Uint8List bytes) async {
    if (!_isMonitoring || _currentSession == null || _isDetecting) return;

    final requestId = ++_frameRequestId;
    _isDetecting = true;
    _error = null;
    _detectionStatus = DetectionStatus.analyzing;
    notifyListeners();

    try {
      final imageSize = await _readImageSize(bytes);
      final result = (await _apiService.detectEmotion(bytes)).copyWith(
        sourceWidth: imageSize?.width,
        sourceHeight: imageSize?.height,
      );
      if (requestId != _frameRequestId) return;

      final normalized = EmotionCatalog.orderedLabels.contains(result.emotion)
          ? result
          : EmotionResult(
              emotion: EmotionCatalog.neutral,
              confidence: result.confidence,
              timestamp: result.timestamp,
              faces: result.faces,
              sourceWidth: result.sourceWidth,
              sourceHeight: result.sourceHeight,
              status: result.status,
            );
      final stable = _validEmotionResult(normalized);

      if (stable.faces.isEmpty) {
        _detectionStatus = normalized.status == 'low_confidence'
            ? DetectionStatus.lowConfidence
            : DetectionStatus.noFace;
        _latestResult = stable;
      } else {
        _detectionStatus = DetectionStatus.faceDetected;
        final newLogs = <EmotionLog>[];
        for (final face in stable.faces.take(5)) {
          final emotion = EmotionCatalog.orderedLabels.contains(face.emotion)
              ? face.emotion
              : EmotionCatalog.neutral;
          final log = EmotionLog(
            sessionId: _currentSession!.id,
            emotion: emotion,
            confidence: face.confidence,
            timestamp: normalized.timestamp,
          );
          await _databaseService.insertLog(log);
          newLogs.add(log);
        }
        _logs = [..._logs, ...newLogs];
        _currentSession = _currentSession!.copyWith(
          totalSamples: _logs.length,
          dominantEmotion: stats.dominantEmotion,
        );
        _latestResult = stable;
      }
      _isBackendConnected = true;
    } catch (error) {
      _error = error.toString();
      _detectionStatus = DetectionStatus.backendDisconnected;
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  EmotionResult _validEmotionResult(EmotionResult result) {
    final validFaces = result.faces
        .where((face) =>
            face.confidence >= 0.32 &&
            EmotionCatalog.orderedLabels.contains(face.emotion))
        .take(5)
        .toList();

    if (validFaces.isEmpty) {
      return result.copyWith(
        emotion: EmotionCatalog.neutral,
        confidence: 0,
        faces: const [],
      );
    }

    final topFace = validFaces.first;
    return result.copyWith(
      emotion: topFace.emotion,
      confidence: topFace.confidence,
      faces: validFaces,
    );
  }

  Future<ui.Size?> _readImageSize(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = ui.Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      descriptor.dispose();
      buffer.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<String> exportCurrentSessionExcel() async {
    final session = _currentSession;
    if (session == null) {
      throw StateError('No session selected');
    }

    final excel = Excel.createExcel();
    const sheetName = 'Session Summary';
    final defaultSheet = excel.getDefaultSheet();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }

    // Column widths
    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 44);

    // --- Color palette ---
    final primaryBlue = ExcelColor.fromHexString('FF2563EB');
    final darkText = ExcelColor.fromHexString('FF111827');
    final mutedText = ExcelColor.fromHexString('FF6B7280');
    final sectionBg = ExcelColor.fromHexString('FF2563EB');
    final borderColor = ExcelColor.fromHexString('FFE5E7EB');

    // --- Cell styles ---
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: primaryBlue,
      horizontalAlign: HorizontalAlign.Center,
    );
    final subtitleStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: mutedText,
      horizontalAlign: HorizontalAlign.Center,
    );
    final sectionStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: sectionBg,
      horizontalAlign: HorizontalAlign.Left,
    );
    final labelStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: darkText,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: borderColor,
      ),
    );
    final valueStyle = CellStyle(
      fontSize: 11,
      fontColorHex: darkText,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: borderColor,
      ),
    );
    final reflectionStyle = CellStyle(
      fontSize: 11,
      fontColorHex: darkText,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );

    int row = 0;

    // ── Title ──
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('EmoLearnAR Session Report');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = titleStyle;
    sheet.setRowHeight(row, 32);
    row++;

    // ── Subtitle ──
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('Generated: ${_formatDateTime(DateTime.now())}');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = subtitleStyle;
    row++;

    // blank
    _writeEmptyRow(sheet, row, borderColor);
    row++;

    // ── Session Overview ──
    row = _writeSectionHeader(sheet, row, 'SESSION OVERVIEW', sectionStyle);
    row = _writeMetricRow(sheet, row, 'Class Name',
        session.displayName, labelStyle, valueStyle);
    row = _writeMetricRow(sheet, row, 'Start Time',
        _formatDateTime(session.startedAt), labelStyle, valueStyle);
    row = _writeMetricRow(
      sheet,
      row,
      'End Time',
      session.endedAt == null
          ? 'Active or not stopped'
          : _formatDateTime(session.endedAt!),
      labelStyle,
      valueStyle,
    );
    row = _writeMetricRow(sheet, row, 'Total Samples',
        '${stats.total}', labelStyle, valueStyle);

    // blank
    _writeEmptyRow(sheet, row, borderColor);
    row++;

    // ── Emotion Distribution ──
    row = _writeSectionHeader(
        sheet, row, 'EMOTION DISTRIBUTION', sectionStyle);
    row = _writeMetricRow(
      sheet,
      row,
      EmotionCatalog.positive,
      '${stats.percentFor(EmotionCatalog.positive).toStringAsFixed(1)}%',
      labelStyle,
      valueStyle,
    );
    row = _writeMetricRow(
      sheet,
      row,
      EmotionCatalog.neutral,
      '${stats.percentFor(EmotionCatalog.neutral).toStringAsFixed(1)}%',
      labelStyle,
      valueStyle,
    );
    row = _writeMetricRow(
      sheet,
      row,
      EmotionCatalog.confused,
      '${stats.percentFor(EmotionCatalog.confused).toStringAsFixed(1)}%',
      labelStyle,
      valueStyle,
    );
    row = _writeMetricRow(
      sheet,
      row,
      EmotionCatalog.negative,
      '${stats.percentFor(EmotionCatalog.negative).toStringAsFixed(1)}%',
      labelStyle,
      valueStyle,
    );

    // blank
    _writeEmptyRow(sheet, row, borderColor);
    row++;

    // ── Engagement ──
    row = _writeSectionHeader(sheet, row, 'ENGAGEMENT', sectionStyle);
    row = _writeMetricRow(
      sheet,
      row,
      'Engagement Score',
      '${stats.engagementScore.toStringAsFixed(1)}%',
      labelStyle,
      valueStyle,
    );

    // blank
    _writeEmptyRow(sheet, row, borderColor);
    row++;

    // ── Teaching Reflection ──
    row = _writeSectionHeader(
        sheet, row, 'TEACHING REFLECTION', sectionStyle);
    final reflectionText = session.reflectionNote.trim().isEmpty
        ? 'No reflection note'
        : session.reflectionNote.trim();
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(reflectionText);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = reflectionStyle;
    final estimatedLines =
        math.max(1, (reflectionText.length / 38).ceil());
    sheet.setRowHeight(row, math.max(28, estimatedLines * 18).toDouble());

    // ── Encode & Save ──
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Unable to generate Excel report');
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Custom save location is currently supported on Android only',
      );
    }

    final fileName = _buildExcelFileName(session);
    final savedUri = await _excelExportChannel.invokeMethod<String>(
      'saveExcelReport',
      {
        'fileName': fileName,
        'bytes': Uint8List.fromList(bytes),
      },
    );
    return savedUri ?? fileName;
  }

  int _writeSectionHeader(
      Sheet sheet, int row, String title, CellStyle style) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(title);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = style;
    sheet.setRowHeight(row, 22);
    return row + 1;
  }

  int _writeMetricRow(Sheet sheet, int row, String label, String value,
      CellStyle labelStyle, CellStyle valueStyle) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('  $label');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = labelStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(value);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .cellStyle = valueStyle;
    return row + 1;
  }

  void _writeEmptyRow(Sheet sheet, int row, ExcelColor borderColor) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      bottomBorder: Border(
        borderStyle: BorderStyle.None,
        borderColorHex: borderColor,
      ),
    );
    sheet.setRowHeight(row, 8);
  }

  String _buildExcelFileName(MonitoringSession session) {
    final className = _safeFileName(session.displayName);
    final startedAt = _compactDateTime(session.startedAt);
    return 'emolearnar_${className}_$startedAt.xlsx';
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'session_report' : cleaned;
  }

  String _formatDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _compactDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}';
  }
}
