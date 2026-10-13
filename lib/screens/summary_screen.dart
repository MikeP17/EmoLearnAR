import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/emotion_meta.dart';
import '../models/emotion_stats.dart';
import '../services/monitoring_provider.dart';
import '../widgets/emotion_badge.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/screen_header.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      child: Consumer<MonitoringProvider>(
        builder: (context, provider, _) {
          final session = provider.currentSession;
          final stats = provider.stats;

          return RefreshIndicator(
            onRefresh: provider.loadHistory,
            child: ResponsivePage(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 820;
                  return ListView(
                    children: [
                      ScreenHeader(
                        title: 'Session summary',
                        trailing: EmotionBadge(
                          emotion: stats.dominantEmotion,
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _SummaryCard(
                                className: session?.displayName,
                                startedAt: session?.startedAt,
                                endedAt: session?.endedAt,
                                samples: stats.total,
                                engagement:
                                    '${stats.engagementScore.toStringAsFixed(0)}%',
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: _TrendCard(stats: stats),
                            ),
                          ],
                        )
                      else ...[
                        _SummaryCard(
                          className: session?.displayName,
                          startedAt: session?.startedAt,
                          endedAt: session?.endedAt,
                          samples: stats.total,
                          engagement:
                              '${stats.engagementScore.toStringAsFixed(0)}%',
                        ),
                        const SizedBox(height: 18),
                        _TrendCard(stats: stats),
                      ],
                      const SizedBox(height: 18),
                      _ConfusionPeakCard(stats: stats),
                      const SizedBox(height: 18),
                      _ReflectionNoteCard(
                        note: session?.reflectionNote ?? '',
                        enabled: session != null,
                        onChanged: provider.updateReflectionNote,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: session == null
                            ? null
                            : () async {
                                try {
                                  await provider.exportCurrentSessionExcel();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Excel report exported successfully',
                                      ),
                                    ),
                                  );
                                } on PlatformException catch (error) {
                                  if (!context.mounted) return;
                                  final message =
                                      error.code == 'EXPORT_CANCELLED'
                                          ? 'Excel export cancelled'
                                          : 'Excel export failed: '
                                              '${error.message ?? error.code}';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Excel export failed: $error',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.table_view_rounded),
                        label: const Text('Export Excel Report'),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0B1120),
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (provider.sessions.isEmpty)
                        const _EmptyHistory()
                      else
                        for (final item in provider.sessions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HistoryTile(
                              selected: item.id == session?.id,
                              title: item.displayName,
                              subtitle:
                                  '${_formatDateTime(item.startedAt)} - ${item.totalSamples} samples',
                              emotion: item.dominantEmotion,
                              onTap: () => provider.loadSession(item.id),
                              onDelete: () => _confirmDeleteSession(
                                context,
                                provider,
                                item.id,
                                item.displayName,
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    MonitoringProvider provider,
    String sessionId,
    String sessionName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete history?'),
          content: Text(
            'Delete "$sessionName" and all related emotion logs? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await provider.deleteSession(sessionId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session history deleted')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.className,
    required this.startedAt,
    required this.endedAt,
    required this.samples,
    required this.engagement,
  });

  final String? className;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int samples;
  final String engagement;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className ?? 'No session selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0B1120),
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitoring record',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SummaryRow(
            label: 'Started',
            value: startedAt == null
                ? '-'
                : SummaryScreen._formatDateTime(startedAt!),
          ),
          _SummaryRow(
            label: 'Ended',
            value: endedAt == null
                ? 'Active or not stopped'
                : SummaryScreen._formatDateTime(endedAt!),
          ),
          _SummaryRow(label: 'Samples', value: '$samples'),
          _SummaryRow(label: 'Engagement', value: engagement),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotion Trends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0B1120),
                ),
          ),
          const SizedBox(height: 18),
          for (final emotion in EmotionCatalog.orderedLabels)
            _TrendBar(
              emotion: emotion,
              percent: stats.percentFor(emotion),
            ),
        ],
      ),
    );
  }
}

class _ConfusionPeakCard extends StatelessWidget {
  const _ConfusionPeakCard({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    final confusedPercent = stats.percentFor(EmotionCatalog.confused);
    final color = EmotionCatalog.of(EmotionCatalog.confused).color;
    final message = confusedPercent >= 35
        ? 'Confusion level is elevated. Consider revisiting the current topic.'
        : confusedPercent > 0
            ? 'Confusion signals are present but remain manageable.'
            : 'No confusion peak detected in this session yet.';

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EmotionCatalog.of(EmotionCatalog.confused).softColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  EmotionCatalog.of(EmotionCatalog.confused).icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confusion Peak',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B1120),
                      ),
                ),
              ),
              Text(
                '${confusedPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: confusedPercent / 100),
              duration: const Duration(milliseconds: 560),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0).toDouble(),
                  minHeight: 10,
                  backgroundColor:
                      EmotionCatalog.of(EmotionCatalog.confused).softColor,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionNoteCard extends StatefulWidget {
  const _ReflectionNoteCard({
    required this.note,
    required this.enabled,
    required this.onChanged,
  });

  final String note;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_ReflectionNoteCard> createState() => _ReflectionNoteCardState();
}

class _ReflectionNoteCardState extends State<_ReflectionNoteCard> {
  final TextEditingController _controller = TextEditingController();
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.note;
  }

  @override
  void didUpdateWidget(covariant _ReflectionNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != _controller.text) {
      _syncingText = true;
      _controller.text = widget.note;
      _syncingText = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Teaching Reflection',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B1120),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            maxLines: 4,
            onChanged: (value) {
              if (!_syncingText) widget.onChanged(value);
            },
            decoration: InputDecoration(
              hintText: widget.enabled
                  ? 'Write a short note for this session...'
                  : 'Select a session to write a reflection note',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0B1120),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.emotion, required this.percent});

  final String emotion;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final meta = EmotionCatalog.of(emotion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: meta.softColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(meta.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emotion,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: meta.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: percent / 100),
              duration: const Duration(milliseconds: 560),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: meta.softColor,
                  valueColor: AlwaysStoppedAnimation<Color>(meta.color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.emotion,
    required this.onTap,
    required this.onDelete,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String emotion;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = EmotionCatalog.of(emotion);
    return Material(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: meta.softColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(meta.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B1120),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: EmotionBadge(emotion: emotion, compact: true),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Delete history',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No saved sessions yet',
            style: TextStyle(
              color: Color(0xFF0B1120),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start monitoring to create your first session summary.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
