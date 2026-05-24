import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/models/pid.dart';
import '../providers/live_data_provider.dart';
import '../theme/app_theme.dart';

/// Live grid of every PID being polled. Each tile shows the latest value,
/// a 60-sample sparkline and the unit. Useful for OBD diagnostics.
class LiveSensorsScreen extends StatefulWidget {
  const LiveSensorsScreen({super.key});

  @override
  State<LiveSensorsScreen> createState() => _LiveSensorsScreenState();
}

class _LiveSensorsScreenState extends State<LiveSensorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveDataProvider>();
    final pids = live.pids;
    final filtered = _query.isEmpty
        ? pids
        : pids
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()) ||
                p.shortName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text('LIVE SENSORS', style: AppText.title(size: 16))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppText.body(size: 13),
                decoration: const InputDecoration(
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.textMuted),
                  hintText: 'Cauta senzor (RPM, MAF, ECT, ...)',
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _StatusDot(active: live.isPolling),
                  const Gap(6),
                  Text(
                    live.isPolling
                        ? 'POLLING ${live.refreshHz} Hz · ${live.totalReads} reads'
                        : 'POLLING OPRIT — conecteaza adaptorul',
                    style: AppText.label(
                        size: 9.5,
                        color: live.isPolling
                            ? AppColors.ok
                            : AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}/${pids.length} senzori',
                    style: AppText.label(size: 9.5, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _SensorTile(
                  pid: filtered[i],
                  history: live.historyFor(filtered[i]),
                  latest: live.latest[filtered[i].code],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.ok : AppColors.textDim,
        shape: BoxShape.circle,
        boxShadow:
            active ? [const BoxShadow(color: AppColors.ok, blurRadius: 4)] : null,
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final Pid pid;
  final Queue<PidSample> history;
  final PidSample? latest;
  const _SensorTile({
    required this.pid,
    required this.history,
    required this.latest,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(pid);
    final value = latest?.value;
    final txt = value == null ? '—' : value.toStringAsFixed(_precision());
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pid.shortName,
                  style: AppText.label(
                      size: 9, color: color, weight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text('0x${pid.code.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                  style: AppText.label(size: 8.5, color: AppColors.textDim)),
            ],
          ),
          const Gap(6),
          Text(pid.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 11, color: AppColors.textMuted)),
          const Spacer(),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                text: txt,
                style: AppText.digital(
                    size: 22, color: color, weight: FontWeight.w900),
              ),
              TextSpan(
                  text: ' ${pid.unit}',
                  style:
                      AppText.body(size: 10, color: AppColors.textMuted)),
            ]),
          ),
          const Gap(4),
          SizedBox(
            height: 22,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparkPainter(
                samples: history.toList(),
                color: color,
                min: pid.min,
                max: pid.max,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _precision() => pid.unit == '%'
      ? 1
      : pid.max > 1000
          ? 0
          : pid.max > 100
              ? 1
              : 2;

  Color _categoryColor(Pid p) {
    switch (p.code) {
      case 0x05:
      case 0x5C:
        return AppColors.warn;
      case 0x42:
        return AppColors.ok;
      case 0x0C:
        return AppColors.cyan;
      case 0x0D:
        return AppColors.cyan;
      case 0x11:
        return AppColors.cyan;
      case 0x10:
        return AppColors.cyan;
      case 0x2F:
        return AppColors.warn;
    }
    return AppColors.cyan;
  }
}

class _SparkPainter extends CustomPainter {
  final List<PidSample> samples;
  final Color color;
  final double min;
  final double max;
  _SparkPainter({
    required this.samples,
    required this.color,
    required this.min,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) {
      final p = Paint()
        ..color = AppColors.border
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(0, size.height - 1), Offset(size.width, size.height - 1), p);
      return;
    }

    final span = (max - min);
    if (span <= 0) return;
    double minSampled = double.infinity;
    double maxSampled = -double.infinity;
    for (final s in samples) {
      if (s.value < minSampled) minSampled = s.value;
      if (s.value > maxSampled) maxSampled = s.value;
    }
    final lo = minSampled - 0.05 * span;
    final hi = maxSampled + 0.05 * span;
    final s = (hi - lo) <= 0 ? 1 : (hi - lo);

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final yNorm = ((samples[i].value - lo) / s).clamp(0.0, 1.0);
      final y = size.height - yNorm * (size.height - 2) - 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.samples.length != samples.length;
}
