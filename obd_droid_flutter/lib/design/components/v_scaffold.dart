import 'package:flutter/material.dart';

import '../theme/voltera_tokens.dart';
import '../tokens/spacing.dart';

/// Wrapper Scaffold cu paddings consistente + canvas color din tokens.
/// Variantele: `.list` (padding orizontal), `.canvas` (zero padding, ex. harti).
class VScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool padHorizontal;
  final bool safeArea;

  const VScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.padHorizontal = true,
    this.safeArea = true,
  });

  /// Canvas variant — pentru harti / track mode unde body-ul ocupa tot ecranul.
  const VScaffold.canvas({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  })  : padHorizontal = false,
        safeArea = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final isTablet = media.size.shortestSide >= 600;
    final edge = isTablet ? VSpace.screenEdgeTablet : VSpace.screenEdgeMobile;

    Widget content = body;
    if (padHorizontal) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: edge),
        child: content,
      );
    }
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
