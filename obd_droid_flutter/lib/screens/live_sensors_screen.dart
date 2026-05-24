import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/pid.dart';
import '../design/design.dart';
import '../providers/live_data_provider.dart';

/// Live sensors — densitate disciplinata. Lista verticala cu mini-spark,
/// nu grid colorat. Search rapid, status pill sus pentru polling.
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
    final t = context.tokens;
    final pids = live.pids;
    final filtered = _query.isEmpty
        ? pids
        : pids
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()) ||
                p.shortName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return VScaffold(
      appBar: VAppBar(
        title: 'Live Sensors',
        subtitle: live.isPolling
            ? '${live.refreshHz} Hz  ·  ${live.totalReads} reads'
            : 'Polling stopped',
      ),
      body: Column(
        children: [
          const SizedBox(height: VSpace.s8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search RPM, MAF, ECT…',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          Row(
            children: [
              StatusDot(
                status: live.isPolling ? VStatus.ok : VStatus.neutral,
                pulse: live.isPolling,
              ),
              const SizedBox(width: VSpace.s8),
              Text(
                live.isPolling
                    ? 'Live data'
                    : 'Connect an adapter to start polling',
                style: VType.body13.copyWith(color: t.textMuted),
              ),
              const Spacer(),
              Text('${filtered.length}/${pids.length}',
                  style: VType.body13.copyWith(color: t.textDisabled)),
            ],
          ),
          const SizedBox(height: VSpace.s12),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.sensors_off_rounded,
                    title: 'No sensors match',
                    body: 'Try a different search or wait for the ECU to '
                        'publish data.',
                  )
                : ClipRRect(
                    borderRadius: VRadius.brMd,
                    child: Container(
                      color: t.surface,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _SensorRow(
                          pid: filtered[i],
                          history: live.historyFor(filtered[i]),
                          latest: live.latest[filtered[i].code],
                          divider: i < filtered.length - 1,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: VSpace.s16),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final Pid pid;
  final Queue<PidSample> history;
  final PidSample? latest;
  final bool divider;

  const _SensorRow({
    required this.pid,
    required this.history,
    required this.latest,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = latest?.value;
    final txt = value == null ? '—' : value.toStringAsFixed(_precision());

    final row = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: VSpace.s16, vertical: VSpace.s12),
      child: Row(
        children: [
          // Short code + name
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(pid.shortName,
                        style: VType.label11.copyWith(color: t.textDefault)),
                    const SizedBox(width: VSpace.s8),
                    Text(
                      '0x${pid.code.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                      style: VType.mono13.copyWith(color: t.textDisabled),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pid.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VType.body13.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: VSpace.s12),
          // Sparkline
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 24,
              child: history.length >= 2
                  ? MiniSparkline(
                      values: [for (final s in history) s.value],
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 1,
                        width: double.infinity,
                        color: t.hairline,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: VSpace.s12),
          // Value
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    txt,
                    style: VType.mono15.copyWith(
                      color: value == null ? t.textDisabled : t.textStrong,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Text(pid.unit,
                    style: VType.body13.copyWith(color: t.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );

    if (!divider) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
      ),
      child: row,
    );
  }

  int _precision() => pid.unit == '%'
      ? 1
      : pid.max > 1000
          ? 0
          : pid.max > 100
              ? 1
              : 2;
}
