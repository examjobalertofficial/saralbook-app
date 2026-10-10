import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/expense/models.dart';
import '../../core/groups/group_controllers.dart';
import '../../core/groups/group_models.dart';
import '../../core/l10n/ltext.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../expense/expense_ui.dart';
import '../study/personal_ui.dart';

IconData groupIcon(String key) => switch (key) {
      'home' => Icons.home_rounded,
      'trip' => Icons.flight_takeoff_rounded,
      'food' => Icons.restaurant_rounded,
      'party' => Icons.celebration_rounded,
      'work' => Icons.work_rounded,
      'school' => Icons.school_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      _ => Icons.groups_rounded,
    };

Color groupColor(int index) => subjectColor(index);

/// Round badge of a group (its icon on its colour).
class GroupBadge extends StatelessWidget {
  final ExpenseGroup group;
  final double size;
  const GroupBadge({super.key, required this.group, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = groupColor(group.colorIndex);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.withAlpha(40),
      child: Icon(groupIcon(group.iconKey), color: c, size: size * 0.52),
    );
  }
}

/// Photo (when there is one) or the first letter of a member.
class MemberAvatar extends StatelessWidget {
  final GroupMember member;
  final double radius;
  const MemberAvatar({super.key, required this.member, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = member.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundImage: url.startsWith('https://') ? NetworkImage(url) : null,
      onForegroundImageError: url.startsWith('https://') ? (_, __) {} : null,
      child: Text(member.initial, style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
    );
  }
}

final LText youLabel = t('You', 'आप');

LText roleLabel(GroupRole r) => switch (r) {
      GroupRole.owner => t('Owner', 'मालिक'),
      GroupRole.admin => t('Admin', 'एडमिन'),
      GroupRole.member => t('Member', 'सदस्य'),
    };

LText splitTypeLabel(SplitType s) => switch (s) {
      SplitType.equal => t('Equally', 'बराबर'),
      SplitType.exact => t('Exact amounts', 'सटीक राशि'),
      SplitType.percent => t('Percentages', 'प्रतिशत'),
    };

/// Green when somebody is owed, red when somebody owes.
Color balanceColor(BuildContext context, int minor) {
  if (minor == 0) return Theme.of(context).colorScheme.onSurfaceVariant;
  return minor > 0 ? incomeColor(context) : expenseColor(context);
}

/// Category used by group bills (the built-in expense categories).
CategoryInfo groupCategory(String id) => categoryById(id, const []);

final List<CategoryInfo> groupCategories = [
  for (final c in defaultCategories)
    if (c.kind == CategoryKind.expense) c,
];

/// Shows [builder] only for a signed-in person, with THEIR groups.
class GroupsGate extends StatelessWidget {
  final LText title;
  final Widget Function(BuildContext context, GroupsController groups) builder;
  const GroupsGate({super.key, required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.auth, services.groups]),
      builder: (context, _) {
        final groups = services.groups.current;
        if (groups != null) {
          // key = account, so a new account always gets fresh screens
          return KeyedSubtree(key: ValueKey(groups.me.uid), child: builder(context, groups));
        }
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, title), style: const TextStyle(fontWeight: FontWeight.w700))),
          body: const PageBody(child: SignInRequiredView()),
        );
      },
    );
  }
}

/// "Paid by Asha" / "Paid by Asha, Bala" text.
String paidByText(BuildContext context, GroupSession s, GroupExpense e) {
  final ids = e.paidBy.keys.toList()..sort();
  final names = [for (final id in ids) id == s.me.uid ? tr(context, youLabel) : s.nameOf(id)];
  return names.join(', ');
}

void showSnack(BuildContext context, LText text, {bool error = false}) {
  final lang = Localizations.localeOf(context).languageCode;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text.of(lang)),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

/// Pick a group icon and colour.
class LookPicker extends StatelessWidget {
  final String icon;
  final int color;
  final void Function(String icon, int color) onChanged;
  const LookPicker({super.key, required this.icon, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in groupIconKeys)
              InkResponse(
                onTap: () => onChanged(k, color),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: k == icon ? groupColor(color).withAlpha(60) : scheme.surfaceContainerHighest,
                  child: Icon(groupIcon(k), color: k == icon ? groupColor(color) : scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            for (var i = 0; i < 8; i++)
              InkResponse(
                onTap: () => onChanged(icon, i),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: groupColor(i),
                  child: i == color ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
