import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/emotion_meta.dart';
import '../models/emotion_stats.dart';
import '../routes/app_routes.dart';
import '../services/monitoring_provider.dart';
import '../widgets/emotion_badge.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/screen_header.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.fromMonitoring = false,
  });

  final bool fromMonitoring;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MonitoringProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Live Dashboard'),
        leading: IconButton(
          tooltip: 'Back to monitoring',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _returnToMonitoring(context, provider),
        ),
      ),
      child: Consumer<MonitoringProvider>(
        builder: (context, provider, _) {
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
                        title: 'Live engagement analytics',
                        trailing: EmotionBadge(
                          emotion: stats.dominantEmotion,
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _EngagementHero(stats: stats),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _ChartPanel(stats: stats),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: _SignalPanel(stats: stats),
                            ),
                          ],
                        )
                      else ...[
                        _ChartPanel(stats: stats),
                        const SizedBox(height: 18),
                        _SignalPanel(stats: stats),
                      ],
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: wide ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: wide ? 1.06 : 1.08,
                        children: [
                          for (final emotion in EmotionCatalog.orderedLabels)
                            StatCard(
                              title: emotion,
                              value:
                                  '${stats.percentFor(emotion).toStringAsFixed(0)}%',
                              subtitle: '${stats.countFor(emotion)} samples',
                              color: EmotionCatalog.of(emotion).color,
                              iconText: EmotionCatalog.of(emotion).icon,
                            ),
                        ],
                      ),
                      if (!provider.isMonitoring) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.summary,
                          ),
                          icon: const Icon(Icons.summarize_rounded),
                          label: const Text('Open Session Summary'),
                        ),
                      ],
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

  void _returnToMonitoring(BuildContext context, MonitoringProvider provider) {
    if (fromMonitoring && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    final session = provider.currentSession;
    if (session != null) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.monitoring,
        arguments: {
          'className': session.displayName,
        },
      );
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

}

class _EngagementHero extends StatelessWidget {
  const _EngagementHero({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      radius: 30,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement Score',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: stats.engagementScore),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      '${value.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0B1120),
                            height: 0.95,
                          ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.total} analyzed face samples in the selected session',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 96,
            height: 96,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: stats.engagementScore / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    stats.engagementScore >= 65
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emotion Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B1120),
                  ),
            ),
            const SizedBox(height: 18),
            Expanded(child: _EmotionPieChart(stats: stats)),
            const SizedBox(height: 18),
            SizedBox(
              height: 132,
              child: _EmotionBarChart(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  const _SignalPanel({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Signals',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0B1120),
                ),
          ),
          const SizedBox(height: 18),
          for (final emotion in EmotionCatalog.orderedLabels)
            _SignalRow(
              emotion: emotion,
              percent: stats.percentFor(emotion),
              count: stats.countFor(emotion),
            ),
        ],
      ),
    );
  }
}

class _EmotionPieChart extends StatelessWidget {
  const _EmotionPieChart({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const Center(
        child: Text(
          'No emotion samples yet',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final chart = PieChart(
          PieChartData(
            centerSpaceRadius: compact ? 42 : 54,
            sectionsSpace: 4,
            sections: [
              for (final emotion in EmotionCatalog.orderedLabels)
                PieChartSectionData(
                  value: stats.countFor(emotion).toDouble(),
                  color: EmotionCatalog.of(emotion).color,
                  radius: compact ? 54 : 72,
                  title: '${stats.percentFor(emotion).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        );

        final legend = Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            for (final emotion in EmotionCatalog.orderedLabels)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: EmotionCatalog.of(emotion).color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    emotion,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chart),
              const SizedBox(height: 14),
              legend,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: chart),
            const SizedBox(width: 16),
            SizedBox(width: 132, child: legend),
          ],
        );
      },
    );
  }
}

class _EmotionBarChart extends StatelessWidget {
  const _EmotionBarChart({required this.stats});

  final EmotionStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'Bar chart will update after monitoring starts',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= EmotionCatalog.orderedLabels.length) {
                  return const SizedBox.shrink();
                }
                final emotion = EmotionCatalog.orderedLabels[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    EmotionCatalog.of(emotion).icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0;
              index < EmotionCatalog.orderedLabels.length;
              index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: stats.percentFor(EmotionCatalog.orderedLabels[index]),
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color:
                      EmotionCatalog.of(EmotionCatalog.orderedLabels[index])
                          .color,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color:
                        EmotionCatalog.of(EmotionCatalog.orderedLabels[index])
                            .softColor,
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final emotion = EmotionCatalog.orderedLabels[group.x];
              return BarTooltipItem(
                '$emotion\n${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.emotion,
    required this.percent,
    required this.count,
  });

  final String emotion;
  final double percent;
  final int count;

  @override
  Widget build(BuildContext context) {
    final meta = EmotionCatalog.of(emotion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
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
                    color: Color(0xFF0B1120),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: percent / 100),
              duration: const Duration(milliseconds: 540),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
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
