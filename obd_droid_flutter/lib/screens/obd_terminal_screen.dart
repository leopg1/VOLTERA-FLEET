import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/connection_provider.dart';

/// OBD/AT raw terminal — console log + input + quick commands.
class ObdTerminalScreen extends StatefulWidget {
  const ObdTerminalScreen({super.key});

  @override
  State<ObdTerminalScreen> createState() => _ObdTerminalScreenState();
}

class _ObdTerminalScreenState extends State<ObdTerminalScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_LogEntry> _log = [];
  bool _running = false;

  static const _quickCommands = <_QuickCmd>[
    _QuickCmd('ATZ', 'Reset'),
    _QuickCmd('ATI', 'Identify'),
    _QuickCmd('ATRV', 'Battery V'),
    _QuickCmd('ATSP0', 'Auto proto'),
    _QuickCmd('ATDP', 'Current proto'),
    _QuickCmd('0100', 'PIDs 01-20'),
    _QuickCmd('010C', 'RPM'),
    _QuickCmd('010D', 'Speed'),
    _QuickCmd('0105', 'Coolant'),
    _QuickCmd('0902', 'VIN'),
    _QuickCmd('03', 'Stored DTCs'),
    _QuickCmd('07', 'Pending DTCs'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String cmd) async {
    if (cmd.trim().isEmpty || _running) return;
    final engine = context.read<ConnectionProvider>().engine;
    if (engine == null) {
      setState(() {
        _log.add(_LogEntry.error('Adapter not connected'));
      });
      return;
    }
    setState(() {
      _running = true;
      _log.add(_LogEntry.tx(cmd));
    });
    try {
      final res = await engine.sendRaw(cmd.trim());
      if (!mounted) return;
      setState(() {
        _log.add(_LogEntry.rx(res.raw));
        if (res.isError) {
          _log.add(_LogEntry.error(res.error ?? 'unknown error'));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _log.add(_LogEntry.error(e.toString())));
    }
    if (!mounted) return;
    setState(() => _running = false);
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut);
      }
    });
  }

  void _clear() => setState(() => _log.clear());

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final t = context.tokens;
    final ready = conn.isReady;
    return VScaffold(
      appBar: VAppBar(
        title: 'OBD Terminal',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear log',
            onPressed: _log.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Status
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSpace.s12),
            child: Row(
              children: [
                StatusBadge(
                  label: ready ? 'Connected' : 'Offline',
                  status: ready ? VStatus.ok : VStatus.danger,
                  icon: ready
                      ? Icons.cable_rounded
                      : Icons.power_off_rounded,
                  dense: true,
                ),
                const Spacer(),
                Text('${_log.length} lines',
                    style: VType.body13.copyWith(color: t.textDisabled)),
              ],
            ),
          ),

          // ─── Log
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(VSpace.s12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: VRadius.brMd,
              ),
              child: _log.isEmpty
                  ? Center(
                      child: Text(
                        'Send a command (ATZ, 010C, 03, 0902…)',
                        textAlign: TextAlign.center,
                        style: VType.body13.copyWith(color: t.textDisabled),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _log.length,
                      itemBuilder: (_, i) {
                        final e = _log[i];
                        final color = switch (e.kind) {
                          _Kind.tx => t.accent,
                          _Kind.rx => t.ok,
                          _Kind.error => t.danger,
                        };
                        final prefix = switch (e.kind) {
                          _Kind.tx => '>',
                          _Kind.rx => '<',
                          _Kind.error => '!',
                        };
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            '$prefix  ${e.text}',
                            style: VType.mono13.copyWith(color: color),
                          ),
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(height: VSpace.s12),

          // ─── Quick commands
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: _quickCommands.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: VSpace.s8),
              itemBuilder: (_, i) {
                final q = _quickCommands[i];
                return _QuickChip(cmd: q.cmd, label: q.label, onTap: () => _send(q.cmd));
              },
            ),
          ),

          const SizedBox(height: VSpace.s12),

          // ─── Input
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.s16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: ready && !_running,
                    style: VType.mono15.copyWith(color: t.textStrong),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9 ]'))
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Command (010C, ATZ, 03, 0902…)',
                      isDense: true,
                    ),
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: VSpace.s12),
                FilledButton(
                  onPressed:
                      ready && !_running ? () => _send(_ctrl.text) : null,
                  child: _running
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onAccent,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String cmd;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.cmd, required this.label, required this.onTap});

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
            color: t.surface,
            borderRadius: VRadius.brSm,
            border: Border.all(color: t.hairline),
          ),
          child: Row(
            children: [
              Text(cmd,
                  style: VType.mono13.copyWith(color: t.accent)),
              const SizedBox(width: VSpace.s8),
              Text(label,
                  style: VType.body13.copyWith(color: t.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Kind { tx, rx, error }

class _LogEntry {
  final _Kind kind;
  final String text;
  _LogEntry._(this.kind, this.text);
  factory _LogEntry.tx(String s) => _LogEntry._(_Kind.tx, s);
  factory _LogEntry.rx(String s) => _LogEntry._(_Kind.rx, s);
  factory _LogEntry.error(String s) => _LogEntry._(_Kind.error, s);
}

class _QuickCmd {
  final String cmd;
  final String label;
  const _QuickCmd(this.cmd, this.label);
}
