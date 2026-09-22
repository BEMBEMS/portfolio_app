import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:portfolio_app/providers/theme_provider.dart';
import 'package:portfolio_app/providers/name_provider.dart';
import 'package:portfolio_app/screens/home_dashboard.dart';

void main() {
  testWidgets('Portfolio dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => NameProvider()),
          ],
          child: MaterialApp(home: HomeDashboard()),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('Portfolio Dashboard'), findsOneWidget);
    expect(find.text('Student Information'), findsOneWidget);
    expect(find.text('Counter Module'), findsOneWidget);
    expect(find.text('Network Diagnostics'), findsOneWidget);
  });
}
