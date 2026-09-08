import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:portfolio_app/providers/theme_provider.dart';
import 'package:portfolio_app/providers/name_provider.dart';
import 'package:portfolio_app/screens/home_dashboard.dart';

void main() {
  testWidgets('Portfolio dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => NameProvider()),
        ],
        child: MaterialApp(home: HomeDashboard()),
      ),
    );

    expect(find.text('Portfolio Dashboard'), findsOneWidget);
    expect(find.text('Activity 1'), findsOneWidget);
    expect(find.text('Activity 2'), findsOneWidget);
  });
}
