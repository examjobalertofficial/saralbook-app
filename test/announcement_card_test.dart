import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/remote_config.dart';
import 'package:app/widgets/announcement_card.dart';

Widget _wrap(List<Announcement> items, void Function(Announcement) onOpen) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: AnnouncementCard(items: items, onOpen: onOpen))),
    );

void main() {
  testWidgets('shows the announcement and opens it when tapped', (tester) async {
    Announcement? opened;
    await tester.pumpWidget(_wrap(
      const [Announcement(id: '1', title: 'Exam date', message: 'Moved to Sunday', url: 'https://saralbook.com/x')],
      (a) => opened = a,
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Exam date'), findsOneWidget);
    expect(find.text('Moved to Sunday'), findsOneWidget);
    expect(find.text('ANNOUNCEMENT'), findsOneWidget);
    await tester.tap(find.text('Exam date'));
    expect(opened?.id, '1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('several announcements change by themselves', (tester) async {
    await tester.pumpWidget(_wrap(
      const [
        Announcement(id: '1', title: 'First one', message: 'a'),
        Announcement(id: '2', title: 'Second one', message: 'b'),
      ],
      (_) {},
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('First one'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Second one'), findsOneWidget);
    expect(find.text('First one'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
