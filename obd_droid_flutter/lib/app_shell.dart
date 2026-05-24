import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/connection_state.dart';
import 'design/design.dart';
import 'features/connect/connect_screen.dart';
import 'providers/connection_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/live_data_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dtc_screen.dart';
import 'screens/eco_screen.dart';
import 'screens/more_screen.dart';
import 'screens/trip_analysis_screen.dart';
import 'widgets/custom_bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  ObdLinkState? _lastState;

  static const _pages = <Widget>[
    DashboardScreen(),
    TripAnalysisScreen(),
    DtcScreen(),
    EcoScreen(),
    MoreScreen(),
  ];

  static const _navItems = [
    NavItem(
      icon: Icons.dashboard_outlined,
      iconActive: Icons.dashboard_rounded,
      label: 'Dash',
    ),
    NavItem(
      icon: Icons.map_outlined,
      iconActive: Icons.map_rounded,
      label: 'Trip',
    ),
    NavItem(
      icon: Icons.error_outline_rounded,
      iconActive: Icons.error_rounded,
      label: 'Codes',
    ),
    NavItem(
      icon: Icons.eco_outlined,
      iconActive: Icons.eco_rounded,
      label: 'Eco',
    ),
    NavItem(
      icon: Icons.apps_outlined,
      iconActive: Icons.apps_rounded,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conn = context.read<ConnectionProvider>();
      if (conn.activeAdapter == null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConnectScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final t = context.tokens;

    if (_lastState != conn.state) {
      final wasReady = _lastState == ObdLinkState.ready;
      _lastState = conn.state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final live = context.read<LiveDataProvider>();
        live.bind(conn.service);
        if (!wasReady &&
            conn.state == ObdLinkState.ready &&
            conn.service != null) {
          context.read<DiagnosticsProvider>().scan(conn.service!);
        }
      });
    }

    return Scaffold(
      backgroundColor: t.canvas,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _pages[_index],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        index: _index,
        items: _navItems,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
