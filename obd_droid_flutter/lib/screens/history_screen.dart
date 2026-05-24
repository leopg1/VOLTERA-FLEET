import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../design/design.dart';

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

/// History — sessions list cu mini-chart saptamanal.
/// Cand activam CSV logger, dataset-ul devine real.
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

  static final List<double> _monthly = [420, 510, 380, 612, 290, 720, 540];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = _monthly.fold<double>(0, (a, b) => a + b);
    return VScaffold(
      appBar: const VAppBar(
        title: 'Trip History',
        subtitle: 'Recent driving sessions',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, VSpace.s8, 0, VSpace.s24),
        children: [
          // ─── Weekly distance card
          VCard.hero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricBlock(
                        label: 'Last 7 days',
                        value: total.toStringAsFixed(0),
                        unit: 'km',
                        size: MetricSize.lg,
                      ),
                    ),
                    StatusBadge(
                      label: '${_demo.length} trips',
                      status: VStatus.info,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.s16),
                SizedBox(
                  height: 140,
                  child: _WeeklyBarChart(data: _monthly, accent: t.accent),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.sectionGap),

          // ─── Sessions list
          Padding(
            padding: const EdgeInsets.fromLTRB(
                VSpace.s4, 0, VSpace.s4, VSpace.s8),
            child: Text('SESSIONS',
                style: VType.label11.copyWith(color: t.textMuted)),
          ),
          ClipRRect(
            borderRadius: VRadius.brMd,
            child: Container(
              color: t.surface,
              child: Column(
                children: [
                  for (int i = 0; i < _demo.length; i++)
                    _SessionRow(
                      session: _demo[i],
                      divider: i < _demo.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final _Session session;
  final bool divider;
  const _SessionRow({required this.session, required this.divider});

  @override
  Widget build(BuildContext context) {
    final hasDtc = session.dtcCount > 0;
    return VListTile(
      divider: divider,
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: StatusDot(
            status: hasDtc ? VStatus.warn : VStatus.ok,
            size: 10,
          ),
        ),
      ),
      title: _formatDate(session.when),
      subtitle:
          '${session.distanceKm.toStringAsFixed(1)} km  ·  max ${session.maxSpeed.toStringAsFixed(0)} km/h  ·  ${session.duration.inMinutes} min',
      trailing: StatusBadge(
        label: hasDtc ? '${session.dtcCount} DTC' : 'Clean',
        status: hasDtc ? VStatus.warn : VStatus.ok,
        dense: true,
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago  ·  ${_hm(d)}';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago  ·  ${_hm(d)}';
    }
    return '${d.day}.${d.month}.${d.year}  ·  ${_hm(d)}';
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _WeeklyBarChart extends StatelessWidget {
  final List<double> data;
  final Color accent;
  const _WeeklyBarChart({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
                      style: VType.body13.copyWith(color: t.textDisabled)),
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
                width: 12,
                borderRadius: BorderRadius.circular(2),
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
