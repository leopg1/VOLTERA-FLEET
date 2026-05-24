import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Buton mare stilizat ca buton de racing — folosit pentru START/STOP in
/// Track Mode si pentru actiuni primare critice (Clear DTC).
class RacingButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool isOn;
  final double height;

  const RacingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.cyan,
    this.isOn = false,
    this.height = 80,
  });

  @override
  State<RacingButton> createState() => _RacingButtonState();
}

class _RacingButtonState extends State<RacingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.height,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isOn
                ? [
                    widget.color,
                    widget.color.withOpacity(0.6),
                  ]
                : [
                    AppColors.surfaceHi,
                    AppColors.surface,
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(widget.isOn ? 0.6 : 0.25),
              blurRadius: widget.isOn ? 30 : 14,
              spreadRadius: widget.isOn ? 2 : 0,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isOn ? Colors.black : widget.color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: AppText.label(
                  size: 16,
                  color: widget.isOn ? Colors.black : widget.color,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
