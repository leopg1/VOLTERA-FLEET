import 'package:flutter/animation.dart';

/// Durate si curbe standard. Motion ajuta navigarea, nu performance-ul.
class VMotion {
  VMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration heavy = Duration(milliseconds: 280);

  /// Pulse cardiac pe state changes critice (connection up/down).
  static const Duration heartbeat = Duration(milliseconds: 320);

  /// Tween numeric pentru valori live (km/h, RPM).
  static const Duration numeric = Duration(milliseconds: 220);

  static const Curve enter = Curves.easeOut;
  static const Curve transition = Curves.easeOutCubic;
}
