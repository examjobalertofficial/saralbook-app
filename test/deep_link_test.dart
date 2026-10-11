import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/groups/group_logic.dart';
import 'package:app/core/links/deep_link.dart';

void main() {
  group('parseDeepLink', () {
    test('app scheme join link', () {
      final l = parseDeepLink(Uri.parse('saralbook://join/abcd2345'));
      expect(l, isA<JoinGroupLink>());
      expect((l as JoinGroupLink).code, 'ABCD2345');
    });

    test('https join link', () {
      final l = parseDeepLink(Uri.parse('https://saralbook.com/app/join/ABCD2345'));
      expect((l as JoinGroupLink).code, 'ABCD2345');
      expect(parseDeepLink(Uri.parse('https://www.saralbook.com/app/join/ABCD2345')), isA<JoinGroupLink>());
    });

    test('bad codes and other sites are ignored', () {
      expect(parseDeepLink(Uri.parse('saralbook://join/ABC')), isNull);
      expect(parseDeepLink(Uri.parse('saralbook://join/ABCD0OI1')), isNull);
      expect(parseDeepLink(Uri.parse('saralbook://join')), isNull);
      expect(parseDeepLink(Uri.parse('https://evil.com/app/join/ABCD2345')), isNull);
      expect(parseDeepLink(Uri.parse('https://saralbook.com/blog/join/ABCD2345')), isNull);
      expect(parseDeepLink(Uri.parse('http://saralbook.com/app/join/ABCD2345')), isNull);
      expect(parseDeepLink(Uri.parse('other://join/ABCD2345')), isNull);
    });

    test('tools, tabs and groups', () {
      expect((parseDeepLink(Uri.parse('saralbook://tool/resume_maker')) as ToolLink).toolId, 'resume_maker');
      expect(parseDeepLink(Uri.parse('saralbook://tool/Bad-Id!')), isNull);
      expect((parseDeepLink(Uri.parse('saralbook://tab/jobs')) as TabLink).tab, 'jobs');
      expect(parseDeepLink(Uri.parse('saralbook://tab/nowhere')), isNull);
      expect(parseDeepLink(Uri.parse('saralbook://groups')), isA<GroupsLink>());
      expect(parseDeepLink(Uri.parse('https://saralbook.com/app/groups')), isA<GroupsLink>());
      expect(parseDeepLink(Uri.parse('https://saralbook.com/app')), isNull);
    });
  });

  group('DeepLinkController', () {
    test('pending invite is taken once', () {
      final c = DeepLinkController();
      var n = 0;
      c.addListener(() => n++);
      c.setPendingJoin('ABCD2345');
      expect(n, 1);
      expect(c.takePendingJoin(), 'ABCD2345');
      expect(c.takePendingJoin(), isNull);
    });
  });

  test('shared invite message carries the link and the code', () {
    final m = inviteMessage('Trip', 'ABCD2345');
    expect(m, contains('https://saralbook.com/app/join/ABCD2345'));
    expect(extractInviteCode(m), 'ABCD2345');
    expect(extractInviteCode(groupInviteLink('ABCD2345')), 'ABCD2345');
    expect(parseDeepLink(Uri.parse(groupInviteLink('ABCD2345'))), isA<JoinGroupLink>());
    expect(parseDeepLink(Uri.parse(groupInviteAppLink('ABCD2345'))), isA<JoinGroupLink>());
  });
}
