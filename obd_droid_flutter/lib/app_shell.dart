import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/connection_state.dart';
import 'features/connect/connect_screen.dart';
import 'providers/connection_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/live_data_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dtc_screen.dart';
import 'screens/eco_screen.dart';
import 'screens/more_screen.dart';
import 'screens/trip_analysis_screen.dart';
import 'theme/app_theme.dart';
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
      icon: Icons.speed_outlined,
      iconActive: Icons.speed_rounded,
      label: 'DASH',
    ),
    NavItem(
      icon: Icons.map_outlined,
      iconActive: Icons.map_rounded,
      label: 'MAP',
    ),
    NavItem(
      icon: Icons.warning_amber_outlined,
      iconActive: Icons.warning_amber_rounded,
      label: 'CODES',
    ),
    NavItem(
      icon: Icons.eco_outlined,
      iconActive: Icons.eco_rounded,
      label: 'ECO',
    ),
    NavItem(
      icon: Icons.apps_outlined,
      iconActive: Icons.apps_rounded,
      label: 'MORE',
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

    if (_lastState != conn.state) {
      final wasReady = _lastState == ObdLinkState.ready;
      _lastState = conn.state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final live = context.read<LiveDataProvider>();
        live.bind(conn.service);
        // First time we reach ready → trigger an auto DTC scan so the
        // CODES screen immediately reflects vehicle health.
        if (!wasReady &&
            conn.state == ObdLinkState.ready &&
            conn.service != null) {
          context.read<DiagnosticsProvider>().scan(conn.service!);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
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
