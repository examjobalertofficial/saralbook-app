import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/widgets/offline_view.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows English text and calls retry', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(const Locale('en'), OfflineView(onRetry: () => taps++)),
    );
    expect(find.text('No Internet Connection'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(taps, 1);
  });

  testWidgets('shows Hindi text when language is Hindi', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('hi'), OfflineView(onRetry: () {})),
    );
    expect(find.text('फिर कोशिश करें'), findsOneWidget);
  });
}
