import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'providers/geofence_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/name_provider.dart';
import 'screens/home_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final geofenceProvider = GeofenceProvider();
  await geofenceProvider.ready;

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => NameProvider()),
          ChangeNotifierProvider<GeofenceProvider>.value(
            value: geofenceProvider,
          ),
        ],
        child: const PortfolioApp(),
      ),
    ),
  );
}

class PortfolioApp extends StatelessWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Flutter Portfolio',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: const HomeDashboard(),
    );
  }
}
