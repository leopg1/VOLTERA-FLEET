import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../theme/app_theme.dart';

/// Raw OBD/AT command terminal — useful for diagnostics and debugging
/// the WiFi adapter when responses don't match expectations.
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
    _QuickCmd('ATZ', 'Reset adaptor'),
    _QuickCmd('ATI', 'Identifica adaptorul'),
    _QuickCmd('ATRV', 'Tensiune baterie'),
    _QuickCmd('ATSP0', 'Auto protocol'),
    _QuickCmd('ATDP', 'Protocol curent'),
    _QuickCmd('0100', 'PID-uri suportate 01-20'),
    _QuickCmd('010C', 'Engine RPM'),
    _QuickCmd('010D', 'Vehicle Speed'),
    _QuickCmd('0105', 'Coolant Temp'),
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
        _log.add(_LogEntry.error('Adaptorul nu este conectat'));
      });
      return;
    }
    setState(() {
      _running = true;
      _log.add(_LogEntry.tx(cmd));
    });
    try {
      final res = await engine.sendRaw(cmd.trim());
      setState(() {
        _log.add(_LogEntry.rx(res.raw));
        if (res.isError) {
          _log.add(_LogEntry.error(res.error ?? 'unknown error'));
        }
      });
    } catch (e) {
      setState(() => _log.add(_LogEntry.error(e.toString())));
    }
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
    final ready = conn.isReady;
    return Scaffold(
      appBar: AppBar(
        title: Text('OBD TERMINAL', style: AppText.title(size: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Curata log',
            onPressed: _log.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ready ? AppColors.ok : AppColors.danger,
                      shape: BoxShape.circle,
                      boxShadow: ready
                          ? [
                              const BoxShadow(
                                  color: AppColors.ok, blurRadius: 6)
                            ]
                          : null,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    ready ? 'CONECTAT' : 'NECONECTAT',
                    style: AppText.label(
                        size: 10,
                        color: ready ? AppColors.ok : AppColors.danger,
                        weight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text('${_log.length} linii',
                      style: AppText.label(
                          size: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
            // Log
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _log.isEmpty
                    ? Center(
                        child: Text(
                          'Trimite o comanda OBD/AT.\nExemple: ATZ, 010C, 03, 0902',
                          textAlign: TextAlign.center,
                          style: AppText.body(
                              size: 12, color: AppColors.textDim),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: _log.length,
                        itemBuilder: (_, i) {
                          final e = _log[i];
                          final color = switch (e.kind) {
                            _Kind.tx => AppColors.cyan,
                            _Kind.rx => AppColors.ok,
                            _Kind.error => AppColors.danger,
                          };
                          final prefix = switch (e.kind) {
                            _Kind.tx => '>>',
                            _Kind.rx => '<<',
                            _Kind.error => '!!',
                          };
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 1.5),
                            child: SelectableText(
                              '$prefix ${e.text}',
                              style: AppText.digital(
                                  size: 12,
                                  color: color,
                                  weight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const Gap(8),
            // Quick commands
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickCommands.length,
                separatorBuilder: (_, __) => const Gap(6),
                itemBuilder: (_, i) {
                  final q = _quickCommands[i];
                  return InkWell(
                    onTap: () => _send(q.cmd),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHi,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.cyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(q.cmd,
                              style: AppText.digital(
                                  size: 11,
                                  color: AppColors.cyan,
                                  weight: FontWeight.w800)),
                          const Gap(6),
                          Text(q.label,
                              style: AppText.label(
                                  size: 8.5,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(10),
            // Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: ready && !_running,
                      style: AppText.digital(size: 14, color: AppColors.cyan),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9 ]'))
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Comanda (ex: 010C, ATZ, 03, 0902)',
                        isDense: true,
                      ),
                      onSubmitted: _send,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const Gap(8),
                  FilledButton(
                    onPressed:
                        ready && !_running ? () => _send(_ctrl.text) : null,
                    child: _running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : Text('SEND',
                            style: AppText.label(
                                size: 12,
                                color: Colors.black,
                                weight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
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
