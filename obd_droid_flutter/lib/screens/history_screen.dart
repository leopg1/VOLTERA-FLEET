import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../theme/app_theme.dart';
import '../widgets/neon_card.dart';

class _Session {
  final DateTime when;
  final double distanceKm;
  final double maxSpeed;
  final int dtcCount;
  final Duration duration;
  const _Session({
    required this.when,
    required this.distanceKm,
    required this.maxSpeed,
    required this.dtcCount,
    required this.duration,
  });
}

/// History tab — pana cand integram persistenta sesiunilor reale, aratam
/// un dataset reprezentativ stilizat. Logica reala vine cand activam
/// CSV logger din `core/services/csv_logger.dart`.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static final List<_Session> _demo = [
    _Session(
      when: DateTime.now().subtract(const Duration(hours: 4)),
      distanceKm: 42.6,
      maxSpeed: 138,
      dtcCount: 0,
      duration: const Duration(minutes: 38),
    ),
    _Session(
      when: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      distanceKm: 18.2,
      maxSpeed: 92,
      dtcCount: 1,
      duration: const Duration(minutes: 22),
    ),
    _Session(
      when: DateTime.now().subtract(const Duration(days: 2)),
      distanceKm: 65.1,
      maxSpeed: 154,
      dtcCount: 0,
      duration: const Duration(minutes: 51),
    ),
    _Session(
      when: DateTime.now().subtract(const Duration(days: 4, hours: 5)),
      distanceKm: 12.4,
      maxSpeed: 78,
      dtcCount: 0,
      duration: const Duration(minutes: 17),
    ),
  ];

  static final List<double> _monthly = [
    420, 510, 380, 612, 290, 720, 540
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: AppColors.cyan, size: 22),
                  const Gap(8),
                  Text('VEHICLE HISTORY',
                      style: AppText.label(
                          size: 13,
                          color: AppColors.cyan,
                          weight: FontWeight.w900)),
                ],
              ),
              const Gap(16),

              // Monthly chart
              NeonCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('MONTHLY KM', style: AppText.label(size: 10)),
                        const Spacer(),
                        Text(
                          '${_monthly.fold<double>(0, (a, b) => a + b).toStringAsFixed(0)} km',
                          style: AppText.digital(
                              size: 16, color: AppColors.cyan),
                        ),
                      ],
                    ),
                    const Gap(14),
                    SizedBox(height: 160, child: _MonthlyBarChart(data: _monthly)),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0),

              const Gap(20),
              Text('SESSIONS', style: AppText.label(size: 10)),
              const Gap(10),

              ..._demo.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TimelineEntry(
                    session: e.value,
                    isFirst: e.key == 0,
                    isLast: e.key == _demo.length - 1,
                  )
                      .animate(delay: Duration(milliseconds: 80 * e.key))
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.1, end: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<double> data;
  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.fold<double>(0, (a, b) => b > a ? b : a) * 1.15,
        gridData: const FlGridData(show: false),
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
              reservedSize: 22,
              getTitlesWidget: (v, m) {
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i],
                      style: AppText.label(
                          size: 9.5, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          data.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                width: 14,
                borderRadius: BorderRadius.circular(4),
                gradient: AppColors.gradientCyan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final _Session session;
  final bool isFirst;
  final bool isLast;
  const _TimelineEntry({
    required this.session,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final accent = session.dtcCount > 0 ? AppColors.orange : AppColors.green;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 11),
                    color: AppColors.border,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: NeonCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDate(session.when),
                        style: AppText.label(size: 10),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: accent.withOpacity(0.4)),
                        ),
                        child: Text(
                          session.dtcCount > 0
                              ? '${session.dtcCount} DTC'
                              : 'CLEAN',
                          style: AppText.label(
                              size: 9.5,
                              color: accent,
                              weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      _Stat(
                        label: 'DIST',
                        value: session.distanceKm.toStringAsFixed(1),
                        unit: 'km',
                        color: AppColors.cyan,
                      ),
                      const Gap(18),
                      _Stat(
                        label: 'MAX',
                        value: session.maxSpeed.toStringAsFixed(0),
                        unit: 'km/h',
                        color: AppColors.orange,
                      ),
                      const Gap(18),
                      _Stat(
                        label: 'TIME',
                        value: '${session.duration.inMinutes}',
                        unit: 'min',
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 24) {
      return '${diff.inHours}H AGO · ${_hm(d)}';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}D AGO · ${_hm(d)}';
    }
    return '${d.day}.${d.month}.${d.year} · ${_hm(d)}';
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(size: 9)),
        const Gap(2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: value,
                  style: AppText.digital(size: 18, color: color)),
              TextSpan(
                  text: ' $unit',
                  style:
                      AppText.body(size: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
