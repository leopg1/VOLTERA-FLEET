import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum Severity { critical, warning, info, ok }

class SeverityChip extends StatelessWidget {
  final Severity severity;
  final String? label;

  const SeverityChip({super.key, required this.severity, this.label});

  Color get _color => switch (severity) {
        Severity.critical => AppColors.red,
        Severity.warning => AppColors.orange,
        Severity.info => AppColors.cyan,
        Severity.ok => AppColors.green,
      };

  String get _label => label ?? switch (severity) {
        Severity.critical => 'CRITICAL',
        Severity.warning => 'WARNING',
        Severity.info => 'INFO',
        Severity.ok => 'OK',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: AppText.label(size: 9.5, color: _color, weight: FontWeight.w800),
      ),
    );
  }
}
