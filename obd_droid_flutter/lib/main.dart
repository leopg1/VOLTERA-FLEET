import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'core/services/cloud_sync.dart';
import 'core/services/location_service.dart';
import 'providers/connection_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/live_data_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/vehicle_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Folosim fonturile Orbitron + Rajdhani din assets/fonts (bundled in app)
  // direct prin TextStyle(fontFamily: ...) — fara dependinta de retea.
  // App-ul ruleaza 100% offline pe tableta conectata la WiFi-ul ESP32.

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status & nav bar tonale cu UI-ul (transparent overlay).
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final settings = SettingsProvider();
  await settings.load();

  final vehicle = VehicleProvider();
  await vehicle.load();

  final trips = TripProvider();
  await trips.load();

  // Fleet cloud sync — incarca config Supabase din prefs daca exista.
  // Fara config, ramane disabled si app-ul ruleaza 100% local ca inainte.
  await CloudSync.I.init();

  // Daca CloudSync a fost configurat anterior, pornim GPS-ul de la start ca
  // sample-urile sa aiba lat/lon cat timp app-ul e activ — nu doar cand
  // utilizatorul intra pe MAP. Fara fix, sample-urile pleaca tot, doar fara
  // coordonate.
  if (CloudSync.I.isEnabled) {
    LocationService.I.start();
  }

  runApp(ObdDroidApp(
    settings: settings,
    vehicle: vehicle,
    trips: trips,
  ));
}

class ObdDroidApp extends StatelessWidget {
  final SettingsProvider settings;
  final VehicleProvider vehicle;
  final TripProvider trips;

  const ObdDroidApp({
    super.key,
    required this.settings,
    required this.vehicle,
    required this.trips,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: vehicle),
        ChangeNotifierProvider.value(value: trips),
        ChangeNotifierProvider.value(value: LocationService.I),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => LiveDataProvider()),
        ChangeNotifierProvider(create: (_) => DiagnosticsProvider()),
      ],
      child: MaterialApp(
        title: 'Voltera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
