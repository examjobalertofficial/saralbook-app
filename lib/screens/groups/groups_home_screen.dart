import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/expense/money.dart';
import '../../core/groups/group_backend.dart';
import '../../core/groups/group_controllers.dart';
import '../../core/groups/group_models.dart';
import '../../core/l10n/ltext.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'group_detail_screen.dart';
import 'group_ui.dart';

final LText _title = t('Group Expenses', 'ग्रुप खर्च');

void openGroup(BuildContext context, GroupsController groups, String gid) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => GroupDetailScreen(groups: groups, gid: gid)),
  );
}

class GroupsHomeScreen extends StatelessWidget {
  const GroupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GroupsGate(title: _title, builder: (context, groups) => _GroupsHome(groups: groups));
}

class _GroupsHome extends StatelessWidget {
  final GroupsController groups;
  const _GroupsHome({required this.groups});

  static final LText _empty = t(
    'Split bills with friends, flatmates or family. Create a group, or join one with an invite code.',
    'दोस्तों, रूममेट या परिवार के साथ बिल बांटें। ग्रुप बनाएं या इनवाइट कोड से जुड़ें।',
  );
  static final LText _create = t('New group', 'नया ग्रुप');
  static final LText _join = t('Join with code', 'कोड से जुड़ें');
  static final LText _archived = t('Archived groups', 'आर्काइव किए ग्रुप');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: tr(context, _join),
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => showJoinSheet(context, groups),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateGroupSheet(context, groups),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, _create)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: groups,
          builder: (context, _) {
            if (!groups.loaded) return const Center(child: CircularProgressIndicator());
            final active = groups.active;
            final archived = groups.archived;
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                SyncProblemBanner(visible: groups.hasError),
                if (active.isEmpty && archived.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        EmptyState(icon: Icons.groups_2_outlined, message: _empty),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => showJoinSheet(context, groups),
                          icon: const Icon(Icons.group_add_outlined),
                          label: Text(tr(context, _join)),
                        ),
                      ],
                    ),
                  ),
                for (final g in active) _GroupTile(group: g, onTap: () => openGroup(context, groups, g.id)),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    title: Text('${tr(context, _archived)} (${archived.length})'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      for (final g in archived) _GroupTile(group: g, onTap: () => openGroup(context, groups, g.id)),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ExpenseGroup group;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = group.memberIds.length;
    return ListTile(
      onTap: onTap,
      leading: GroupBadge(group: group),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(tr(context, t('$n members', '$n सदस्य'))),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

// ======================= create group =======================

void showCreateGroupSheet(BuildContext context, GroupsController groups) {
  showFormSheet<void>(context, (ctx) => _CreateGroupForm(groups: groups, parentContext: context));
}

class _CreateGroupForm extends StatefulWidget {
  final GroupsController groups;
  final BuildContext parentContext;
  const _CreateGroupForm({required this.groups, required this.parentContext});

  @override
  State<_CreateGroupForm> createState() => _CreateGroupFormState();
}

class _CreateGroupFormState extends State<_CreateGroupForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _budget = TextEditingController();
  String _icon = 'group';
  int _color = 0;

  static final LText _heading = t('New group', 'नया ग्रुप');
  static final LText _nameLabel = t('Group name', 'ग्रुप का नाम');
  static final LText _budgetLabel = t('Monthly group budget (optional)', 'मासिक ग्रुप बजट (वैकल्पिक)');
  static final LText _save = t('Create group', 'ग्रुप बनाएं');

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    final budget = _budget.text.trim().isEmpty ? 0 : (parseMinor(_budget.text) ?? 0);
    final g = widget.groups.createGroup(name: _name.text, iconKey: _icon, colorIndex: _color, budgetMinor: budget);
    final parent = widget.parentContext;
    Navigator.of(context).pop();
    if (parent.mounted) openGroup(parent, widget.groups, g.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, _heading), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: tr(context, _nameLabel), border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        LookPicker(
          icon: _icon,
          color: _color,
          onChanged: (i, c) => setState(() {
            _icon = i;
            _color = c;
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr(context, _budgetLabel), prefixText: '₹ ', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _valid ? _submit : null, child: Text(tr(context, _save))),
        ),
      ],
    );
  }
}

// ======================= join group =======================

void showJoinSheet(BuildContext context, GroupsController groups) {
  showFormSheet<void>(context, (ctx) => _JoinForm(groups: groups, parentContext: context));
}

class _JoinForm extends StatefulWidget {
  final GroupsController groups;
  final BuildContext parentContext;
  const _JoinForm({required this.groups, required this.parentContext});

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  InviteInfo? _found;
  LText? _problem;

  static final LText _heading = t('Join a group', 'ग्रुप से जुड़ें');
  static final LText _hint = t('Invite code (or paste the invite message)', 'इनवाइट कोड (या इनवाइट संदेश पेस्ट करें)');
  static final LText _paste = t('Paste', 'पेस्ट करें');
  static final LText _check = t('Find group', 'ग्रुप खोजें');
  static final LText _bad = t('This code is not valid, or it was changed. Ask for a new one.', 'यह कोड सही नहीं है या बदल दिया गया है। नया कोड मांगें।');
  static final LText _offline = t('Could not reach the cloud. Check your internet and try again.', 'क्लाउड तक नहीं पहुंच सके। इंटरनेट जांचकर फिर कोशिश करें।');
  static final LText _already = t('You are already in this group.', 'आप पहले से इस ग्रुप में हैं।');

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && mounted) {
      setState(() {
        _code.text = text;
        _found = null;
        _problem = null;
      });
    }
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _problem = null;
      _found = null;
    });
    final info = await widget.groups.preview(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _found = info;
      _problem = info == null ? _bad : null;
    });
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final r = await widget.groups.join(_code.text);
    if (!mounted) return;
    switch (r) {
      case JoinResult.joined:
      case JoinResult.alreadyMember:
        final gid = _found?.groupId;
        final parent = widget.parentContext;
        Navigator.of(context).pop();
        if (r == JoinResult.alreadyMember && parent.mounted) showSnack(parent, _already);
        if (gid != null && parent.mounted) openGroup(parent, widget.groups, gid);
      case JoinResult.invalidCode:
        setState(() {
          _busy = false;
          _found = null;
          _problem = _bad;
        });
      case JoinResult.failed:
        setState(() {
          _busy = false;
          _problem = _offline;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final found = _found;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, _heading), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr(context, _hint),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.content_paste_rounded), tooltip: tr(context, _paste), onPressed: _pasteText),
          ),
          onChanged: (_) => setState(() {
            _found = null;
            _problem = null;
          }),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tr(context, _problem!), style: TextStyle(color: scheme.error)),
          ),
        if (found != null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: Text(found.groupName.isEmpty ? '?' : found.groupName, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy || _code.text.trim().isEmpty ? null : (found == null ? _find : _join),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(found == null ? tr(context, _check) : tr(context, t('Join this group', 'इस ग्रुप से जुड़ें'))),
          ),
        ),
      ],
    );
  }
}
