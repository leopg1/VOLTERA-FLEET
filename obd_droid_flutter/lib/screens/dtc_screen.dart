import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/models/dtc.dart';
import '../core/services/dtc_database.dart';
import '../providers/connection_provider.dart';
import '../providers/diagnostics_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/racing_button.dart';
import '../widgets/severity_chip.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              count: all.length,
              storedCount: diag.stored.length,
              pendingCount: diag.pending.length,
              permanentCount: diag.permanent.length,
              hasCodes: hasCodes,
              lastScan: diag.lastScan,
            ),
            if (hasCodes) _FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
              counts: {
                'all': all.length,
                'stored': diag.stored.length,
                'pending': diag.pending.length,
                'permanent': diag.permanent.length,
              },
            ),
            if (hasCodes) Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: AppText.body(size: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 20),
                  hintText: 'Cauta cod sau descriere...',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
              ),
            ),
            Expanded(
              child: hasCodes
                  ? (filtered.isEmpty
                      ? _NoMatchState()
                      : _CodesList(codes: filtered))
                  : _EmptyState(scanning: diag.isScanning),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: conn.service == null || diag.isScanning
                          ? null
                          : () => diag.scan(conn.service!),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        diag.isScanning ? 'SCANARE...' : 'SCAN ECU',
                        style: AppText.label(
                            size: 12,
                            color: AppColors.cyan,
                            weight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: RacingButton(
                      label: 'STERGE',
                      icon: Icons.delete_sweep_rounded,
                      color: AppColors.danger,
                      isOn: false,
                      height: 50,
                      onPressed: hasCodes && conn.service != null
                          ? () => _confirmClear(context, diag, conn)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, DiagnosticsProvider diag,
      ConnectionProvider conn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHi,
        title: Text('Stergi codurile?',
            style: AppText.title(color: AppColors.danger)),
        content: Text(
          'Aceasta operatiune va sterge toate codurile DTC stocate, va '
          'reseta monitorii readiness si va stinge MIL. Este permanent.',
          style: AppText.body(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ANULEAZA',
                style: AppText.label(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('STERGE',
                style: AppText.label(
                    color: Colors.white, weight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true && conn.service != null) {
      final cleared = await diag.clear(conn.service!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: cleared ? AppColors.ok : AppColors.danger,
          content: Text(cleared
              ? 'Codurile au fost sterse'
              : 'Stergerea a esuat — incearca din nou'),
        ));
      }
    }
  }
}

class _Header extends StatelessWidget {
  final int count;
  final int storedCount;
  final int pendingCount;
  final int permanentCount;
  final bool hasCodes;
  final DateTime? lastScan;
  const _Header({
    required this.count,
    required this.storedCount,
    required this.pendingCount,
    required this.permanentCount,
    required this.hasCodes,
    required this.lastScan,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasCodes ? AppColors.danger : AppColors.ok;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 26),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Icon(
                  hasCodes
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FAULT CODES', style: AppText.label(size: 10)),
                    const Gap(4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(count.toString(),
                            style: AppText.digital(size: 38, color: color)),
                        const Gap(8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            hasCodes ? 'CODURI ACTIVE' : 'TOTUL OK',
                            style: AppText.label(
                                size: 11,
                                color: color,
                                weight: FontWeight.w800),
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
            const Gap(12),
            Row(
              children: [
                _Pill(
                  label: 'STORED',
                  count: storedCount,
                  color: AppColors.danger,
                ),
                const Gap(8),
                _Pill(
                  label: 'PENDING',
                  count: pendingCount,
                  color: AppColors.warn,
                ),
                const Gap(8),
                _Pill(
                  label: 'PERM',
                  count: permanentCount,
                  color: AppColors.cyan,
                ),
              ],
            ),
          ],
          if (lastScan != null) ...[
            const Gap(10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ULTIMUL SCAN · ${_fmtTime(lastScan!)}',
                style: AppText.label(size: 9, color: AppColors.textDim),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0);
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
  final Color color;
  const _Pill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Column(
          children: [
            Text(count.toString(),
                style:
                    AppText.digital(size: 18, color: color, weight: FontWeight.w900)),
            Text(label,
                style: AppText.label(
                    size: 8.5, color: color, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

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
    final labels = const {
      'all': 'TOATE',
      'stored': 'STORED',
      'pending': 'PENDING',
      'permanent': 'PERMANENT',
    };
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const Gap(8),
        itemBuilder: (_, i) {
          final key = keys[i];
          final selected = key == filter;
          final color = selected ? AppColors.cyan : AppColors.textMuted;
          return InkWell(
            onTap: () => onChanged(key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.cyan.withOpacity(0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected
                        ? AppColors.cyan.withOpacity(0.5)
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Text(labels[key]!,
                      style: AppText.label(
                          size: 10,
                          color: color,
                          weight: FontWeight.w800)),
                  const Gap(6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${counts[key] ?? 0}',
                      style: AppText.digital(size: 11, color: color),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              color: AppColors.textMuted, size: 60),
          const Gap(10),
          Text('FARA REZULTATE',
              style: AppText.label(size: 12, color: AppColors.textMuted)),
        ],
      ),
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
            const CircularProgressIndicator(color: AppColors.cyan),
            const Gap(20),
            Text('SCANARE ECU...', style: AppText.label(size: 12)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.ok.withOpacity(0.25),
                  AppColors.ok.withOpacity(0),
                ],
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.ok,
              size: 80,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 1400.ms,
                curve: Curves.easeInOut,
              ),
          const Gap(20),
          Text('NICIUN COD ACTIV',
              style: AppText.label(
                  size: 14,
                  color: AppColors.ok,
                  weight: FontWeight.w900)),
          const Gap(8),
          Text(
            'Toate sistemele functioneaza normal.',
            style: AppText.body(color: AppColors.textMuted),
          ),
          const Gap(20),
          Text('Apasa SCAN ECU pentru o noua diagnoza',
              style: AppText.label(size: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _CodesList extends StatelessWidget {
  final List<Dtc> codes;
  const _CodesList({required this.codes});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: codes.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (_, i) => _DtcCard(dtc: codes[i])
          .animate(delay: Duration(milliseconds: 50 * i))
          .fadeIn(duration: 350.ms)
          .slideX(begin: 0.1, end: 0),
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

  Severity _sev() => switch (widget.dtc.severity) {
        DtcSeverity.permanent => Severity.critical,
        DtcSeverity.confirmed => Severity.warning,
        DtcSeverity.pending => Severity.info,
        DtcSeverity.history => Severity.info,
      };

  Color _accent() {
    final info = DtcDatabase.lookup(widget.dtc.code);
    return switch (info.impact) {
      DtcImpact.critical => AppColors.danger,
      DtcImpact.high => AppColors.danger,
      DtcImpact.medium => AppColors.warn,
      DtcImpact.low => AppColors.cyan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final dtc = widget.dtc;
    final info = DtcDatabase.lookup(dtc.code);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.10), blurRadius: 16),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dtc.code,
                            style: AppText.digital(
                                size: 18,
                                color: accent,
                                weight: FontWeight.w900),
                          ),
                          const Gap(10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHi,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              info.system.toUpperCase(),
                              style: AppText.label(size: 8.5),
                            ),
                          ),
                          const Spacer(),
                          SeverityChip(severity: _sev()),
                          const Gap(6),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        info.description,
                        style: AppText.body(size: 13.5, color: AppColors.text),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (info.consequence != null) ...[
                                _DetailLine(
                                  icon: Icons.warning_amber_rounded,
                                  color: AppColors.warn,
                                  label: 'CONSECINTE',
                                  text: info.consequence!,
                                ),
                                const Gap(8),
                              ],
                              if (info.remedy != null) ...[
                                _DetailLine(
                                  icon: Icons.build_rounded,
                                  color: AppColors.ok,
                                  label: 'SOLUTIE',
                                  text: info.remedy!,
                                ),
                              ],
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLo,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                        color: AppColors.textMuted, size: 14),
                                    const Gap(8),
                                    Expanded(
                                      child: Text(
                                        'Severitate: ${dtc.severity.name.toUpperCase()} · '
                                        'Categorie: ${dtc.category.label}',
                                        style: AppText.label(
                                            size: 9.5,
                                            color: AppColors.textMuted),
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
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;
  const _DetailLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppText.label(
                      size: 9, color: color, weight: FontWeight.w800)),
              const Gap(2),
              Text(text,
                  style: AppText.body(size: 12, color: AppColors.text)),
            ],
          ),
        ),
      ],
    );
  }
}
