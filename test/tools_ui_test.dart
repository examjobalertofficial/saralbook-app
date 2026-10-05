import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/tools/calculators.dart';
import 'package:app/screens/tools/calc_tool_screen.dart';
import 'package:app/core/l10n/ltext.dart';
import 'package:app/core/tools/calc_model.dart';
import 'package:app/screens/tools/tool_entry.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('percentage: typing shows the result live', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('en'), CalcToolScreen(tool: calcToolById('percentage')!)),
    );
    expect(find.text('Enter values to see the result.'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '20');
    await tester.enterText(fields.at(1), '150');
    await tester.pump();

    expect(find.text('30'), findsOneWidget);
    expect(find.text('Enter values to see the result.'), findsNothing);
  });

  testWidgets('switching the mode changes the visible fields', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('en'), CalcToolScreen(tool: calcToolById('percentage')!)),
    );
    await tester.tap(find.text('% change X to Y'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '80');
    await tester.enterText(fields.at(1), '100');
    await tester.pump();
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('invalid combination shows an error, not a crash', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('en'), CalcToolScreen(tool: calcToolById('marks_percentage')!)),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '600');
    await tester.enterText(fields.at(1), '500');
    await tester.pump();
    expect(find.text('Marks obtained cannot be more than total marks.'), findsOneWidget);
  });

  testWidgets('Hindi mode shows Hindi labels', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('hi'), CalcToolScreen(tool: calcToolById('percentage')!)),
    );
    expect(find.text('प्रतिशत'), findsOneWidget); // title
    expect(find.text('परिणाम देखने के लिए मान दर्ज करें।'), findsOneWidget);
  });

  testWidgets('every calculator opens without errors (both languages)', (tester) async {
    for (final locale in const [Locale('en'), Locale('hi')]) {
      for (final tool in allCalcTools) {
        await tester.pumpWidget(_host(locale, CalcToolScreen(tool: tool)));
        expect(tester.takeException(), isNull, reason: '${tool.id} ${locale.languageCode}');
      }
    }
  });

  test('tool search matches English, Hindi and keywords', () {
    ToolEntry entry(String en, String hi, List<String> keys) => ToolEntry(
          id: en,
          title: t(en, hi),
          description: t('desc', 'desc'),
          icon: Icons.help_outline,
          category: ToolCategory.examCalc,
          keywords: keys,
          builder: (context) => const SizedBox(),
        );
    final emi = entry('EMI Calculator', 'EMI कैलकुलेटर', ['loan']);
    final pct = entry('Percentage', 'प्रतिशत', const []);
    expect(emi.matches('loan'), isTrue);
    expect(emi.matches('emi'), isTrue);
    expect(pct.matches('प्रतिशत'), isTrue);
    expect(pct.matches('zzz'), isFalse);
    expect(pct.matches(''), isTrue);
  });
}
