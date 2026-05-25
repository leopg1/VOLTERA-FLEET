import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/dtc.dart';
import '../core/services/dtc_database.dart';
import '../design/design.dart';
import '../providers/connection_provider.dart';
import '../providers/diagnostics_provider.dart';

class DtcScreen extends StatefulWidget {
  const DtcScreen({super.key});

  @override
  State<DtcScreen> createState() => _DtcScreenState();
}

class _DtcScreenState extends State<DtcScreen> {
  String _filter = 'all'; // all | stored | pending | permanent
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Dtc> _filtered(DiagnosticsProvider d) {
    Iterable<Dtc> base = d.all;
    switch (_filter) {
      case 'stored':
        base = d.stored;
        break;
      case 'pending':
        base = d.pending;
        break;
      case 'permanent':
        base = d.permanent;
        break;
    }
    if (_query.isEmpty) return base.toList();
    final q = _query.toLowerCase();
    return base
        .where((c) =>
            c.code.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final diag = context.watch<DiagnosticsProvider>();
    final conn = context.watch<ConnectionProvider>();
    final all = diag.all;
    final hasCodes = all.isNotEmpty;
    final filtered = _filtered(diag);

    return VScaffold(
      body: Column(
        children: [
          const SizedBox(height: VSpace.s8),

          // Header summary
          _Header(
            count: all.length,
            storedCount: diag.stored.length,
            pendingCount: diag.pending.length,
            permanentCount: diag.permanent.length,
            hasCodes: hasCodes,
            lastScan: diag.lastScan,
            autoPolling: diag.isAutoPolling,
          ),

          const SizedBox(height: VSpace.s16),

          // Filter + search (only if we have codes)
          if (hasCodes) ...[
            _FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
              counts: {
                'all': all.length,
                'stored': diag.stored.length,
                'pending': diag.pending.length,
                'permanent': diag.permanent.length,
              },
            ),
            const SizedBox(height: VSpace.s12),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search code or description',
              ),
            ),
            const SizedBox(height: VSpace.s12),
          ],

          // List body
          Expanded(
            child: hasCodes
                ? (filtered.isEmpty
                    ? const _NoMatchState()
                    : _CodesList(codes: filtered))
                : _EmptyState(scanning: diag.isScanning),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.only(top: VSpace.s8, bottom: VSpace.s16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: conn.service == null || diag.isScanning
                        ? null
                        : () => diag.scan(conn.service!),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(diag.isScanning ? 'Scanning…' : 'Scan ECU'),
                  ),
                ),
                const SizedBox(width: VSpace.s12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.tokens.danger,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.tokens.surfaceHover,
                    ),
                    onPressed: hasCodes && conn.service != null
                        ? () => _confirmClear(context, diag, conn)
                        : null,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Clear codes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    DiagnosticsProvider diag,
    ConnectionProvider conn,
  ) async {
    final t = context.tokens;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear stored codes?',
            style: VType.title18.copyWith(color: t.textStrong)),
        content: Text(
          'This clears all stored DTCs, resets readiness monitors and turns '
          'off the MIL light. The action is permanent.',
          style: VType.body15.copyWith(color: t.textDefault),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && conn.service != null) {
      final cleared = await diag.clear(conn.service!);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cleared ? t.ok : t.danger,
          content: Text(
            cleared ? 'Codes cleared' : 'Clear failed — try again',
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int count;
  final int storedCount;
  final int pendingCount;
  final int permanentCount;
  final bool hasCodes;
  final DateTime? lastScan;
  final bool autoPolling;

  const _Header({
    required this.count,
    required this.storedCount,
    required this.pendingCount,
    required this.permanentCount,
    required this.hasCodes,
    required this.lastScan,
    required this.autoPolling,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = hasCodes ? VStatus.danger : VStatus.ok;
    return VCard.hero(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: status.resolve(t).withValues(alpha: 0.12),
                  borderRadius: VRadius.brSm,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasCodes
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  color: status.resolve(t),
                  size: 24,
                ),
              ),
              const SizedBox(width: VSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fault codes',
                        style: VType.label11.copyWith(color: t.textMuted)),
                    const SizedBox(height: VSpace.s4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          count.toString(),
                          style: VType.display40.copyWith(
                            color: status.resolve(t),
                          ),
                        ),
                        const SizedBox(width: VSpace.s8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            hasCodes ? 'active' : 'all clear',
                            style:
                                VType.body15.copyWith(color: t.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasCodes) ...[
            const SizedBox(height: VSpace.s16),
            Row(
              children: [
                _Pill(label: 'Stored', count: storedCount, status: VStatus.danger),
                const SizedBox(width: VSpace.s8),
                _Pill(label: 'Pending', count: pendingCount, status: VStatus.warn),
                const SizedBox(width: VSpace.s8),
                _Pill(label: 'Permanent', count: permanentCount, status: VStatus.info),
              ],
            ),
          ],
          if (lastScan != null || autoPolling) ...[
            const SizedBox(height: VSpace.s12),
            Row(
              children: [
                if (lastScan != null)
                  Text(
                    'Last scan · ${_fmtTime(lastScan!)}',
                    style: VType.body13.copyWith(color: t.textMuted),
                  ),
                const Spacer(),
                if (autoPolling)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: VSpace.s8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.ok.withValues(alpha: 0.12),
                      borderRadius: VRadius.brSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.ok,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: VSpace.s8),
                        Text(
                          'AUTO-SCAN · 8s',
                          style: VType.label11.copyWith(
                            color: t.ok,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final VStatus status;
  const _Pill({required this.label, required this.count, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = status.resolve(t);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: VSpace.s12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: VRadius.brSm,
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: VType.title24.copyWith(
                color: color,
                fontFamily: VType.mono,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: VType.body13.copyWith(color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;
  final Map<String, int> counts;
  const _FilterBar({
    required this.filter,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final keys = ['all', 'stored', 'pending', 'permanent'];
    const labels = {
      'all': 'All',
      'stored': 'Stored',
      'pending': 'Pending',
      'permanent': 'Permanent',
    };
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: VSpace.s8),
        itemBuilder: (_, i) {
          final key = keys[i];
          return _FilterChip(
            label: labels[key]!,
            count: counts[key] ?? 0,
            selected: key == filter,
            onTap: () => onChanged(key),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: VRadius.brSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: VRadius.brSm,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: VSpace.s12, vertical: VSpace.s8),
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.12)
                : t.surface,
            borderRadius: VRadius.brSm,
            border: Border.all(
              color: selected ? t.accent : t.hairline,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: VType.body13.copyWith(
                  color: selected ? t.accent : t.textDefault,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: VSpace.s8),
              Text(
                count.toString(),
                style: VType.mono13.copyWith(
                  color: selected ? t.accent : t.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();
  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matches',
      body: 'Try a different search term or filter.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool scanning;
  const _EmptyState({required this.scanning});

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.tokens.accent,
              ),
            ),
            const SizedBox(height: VSpace.s16),
            Text(
              'Scanning ECU…',
              style: VType.body15.copyWith(color: context.tokens.textMuted),
            ),
          ],
        ),
      );
    }
    return const EmptyState(
      icon: Icons.verified_rounded,
      iconStatus: VStatus.ok,
      title: 'No active fault codes',
      body: 'All monitored systems are operating normally.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Code list & item
// ─────────────────────────────────────────────────────────────────────

class _CodesList extends StatelessWidget {
  final List<Dtc> codes;
  const _CodesList({required this.codes});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: VSpace.s8),
      itemBuilder: (_, i) => _DtcCard(dtc: codes[i]),
    );
  }
}

class _DtcCard extends StatefulWidget {
  final Dtc dtc;
  const _DtcCard({required this.dtc});

  @override
  State<_DtcCard> createState() => _DtcCardState();
}

class _DtcCardState extends State<_DtcCard> {
  bool _expanded = false;

  VStatus _statusFromImpact(DtcImpact impact) => switch (impact) {
        DtcImpact.critical => VStatus.danger,
        DtcImpact.high => VStatus.danger,
        DtcImpact.medium => VStatus.warn,
        DtcImpact.low => VStatus.info,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dtc = widget.dtc;
    final info = DtcDatabase.lookup(dtc.code);
    final status = _statusFromImpact(info.impact);
    final color = status.resolve(t);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: VRadius.brMd,
      child: ClipRRect(
        borderRadius: VRadius.brMd,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: VRadius.brMd,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(VSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dtc.code,
                              style: VType.mono15.copyWith(
                                color: t.textStrong,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: VSpace.s8),
                            Text(
                              info.system,
                              style:
                                  VType.body13.copyWith(color: t.textMuted),
                            ),
                            const Spacer(),
                            StatusBadge(
                              label: _severityLabel(dtc.severity),
                              status: status,
                              dense: true,
                            ),
                            const SizedBox(width: VSpace.s8),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                Icons.expand_more_rounded,
                                color: t.textMuted,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: VSpace.s8),
                        Text(
                          info.description,
                          style: VType.body15.copyWith(color: t.textStrong),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: VSpace.s12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (info.consequence != null) ...[
                                  _DetailLine(
                                    icon: Icons.warning_amber_rounded,
                                    status: VStatus.warn,
                                    label: 'Consequence',
                                    text: info.consequence!,
                                  ),
                                  const SizedBox(height: VSpace.s12),
                                ],
                                if (info.remedy != null) ...[
                                  _DetailLine(
                                    icon: Icons.build_rounded,
                                    status: VStatus.ok,
                                    label: 'Remedy',
                                    text: info.remedy!,
                                  ),
                                  const SizedBox(height: VSpace.s12),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(VSpace.s12),
                                  decoration: BoxDecoration(
                                    color: t.canvas,
                                    borderRadius: VRadius.brSm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: t.textMuted, size: 14),
                                      const SizedBox(width: VSpace.s8),
                                      Expanded(
                                        child: Text(
                                          'Severity: ${dtc.severity.name} · '
                                          'Category: ${dtc.category.label}',
                                          style: VType.body13
                                              .copyWith(color: t.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _expanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _severityLabel(DtcSeverity s) => switch (s) {
        DtcSeverity.permanent => 'Permanent',
        DtcSeverity.confirmed => 'Stored',
        DtcSeverity.pending => 'Pending',
        DtcSeverity.history => 'History',
      };
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final VStatus status;
  final String label;
  final String text;
  const _DetailLine({
    required this.icon,
    required this.status,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = status.resolve(t);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: VRadius.brXs,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: VSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: VType.label11.copyWith(color: color)),
              const SizedBox(height: 2),
              Text(text,
                  style: VType.body13.copyWith(color: t.textDefault)),
            ],
          ),
        ),
      ],
    );
  }
}
