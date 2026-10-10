import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/expense/export_table.dart';
import '../../core/expense/money.dart';
import '../../core/expense/pdf_report.dart';
import '../../core/files/file_helpers.dart';
import '../../core/groups/group_controllers.dart';
import '../../core/groups/group_export.dart';
import '../../core/groups/group_logic.dart';
import '../../core/groups/group_models.dart';
import '../../core/l10n/ltext.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../expense/expense_ui.dart';
import '../study/personal_ui.dart';
import 'group_expense_screen.dart';
import 'group_ui.dart';

Future<bool> _confirm(BuildContext context, LText title, LText body, LText action) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(ctx, title)),
      content: Text(tr(ctx, body)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, action))),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for an amount in rupees, returns paise (null = cancelled).
Future<int?> _askAmount(BuildContext context, LText title, int initial) {
  final c = TextEditingController(text: minorToPlain(initial));
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(ctx, title)),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
        FilledButton(
          onPressed: () {
            final v = parseMinor(c.text);
            if (v != null) Navigator.of(ctx).pop(v);
          },
          child: Text(tr(ctx, t('OK', 'ठीक है'))),
        ),
      ],
    ),
  ).whenComplete(c.dispose);
}

class GroupDetailScreen extends StatefulWidget {
  final GroupsController groups;
  final String gid;
  const GroupDetailScreen({super.key, required this.groups, required this.gid});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late final GroupSession _session = GroupSession(groups: widget.groups, gid: widget.gid);
  late final TabController _tabs = TabController(length: 5, vsync: this);
  static const int _chatTab = 4;

  static final LText _tabExpenses = t('Expenses', 'खर्च');
  static final LText _tabBalances = t('Balances', 'हिसाब');
  static final LText _tabMembers = t('Members', 'सदस्य');
  static final LText _tabActivity = t('Activity', 'गतिविधि');
  static final LText _tabChat = t('Chat', 'चैट');
  static final LText _add = t('Add expense', 'खर्च जोड़ें');
  static final LText _gone = t('You are no longer in this group.', 'आप अब इस ग्रुप में नहीं हैं।');

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _session.dispose();
    super.dispose();
  }

  void _openExpenseForm({GroupExpense? existing}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => GroupExpenseScreen(session: _session, existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final g = _session.group;
        if (g == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.group_off_outlined, message: _gone),
          );
        }
        if (_tabs.index == _chatTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _session.markChatRead());
        }
        final unread = _session.unreadCount;
        return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  GroupBadge(group: g, size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              actions: [_menu(g)],
              bottom: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: tr(context, _tabExpenses)),
                  Tab(text: tr(context, _tabBalances)),
                  Tab(text: tr(context, _tabMembers)),
                  Tab(text: tr(context, _tabActivity)),
                  Tab(
                    child: Badge(
                      isLabelVisible: unread > 0 && _tabs.index != _chatTab,
                      label: Text('$unread'),
                      child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(tr(context, _tabChat))),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: g.archived || !_session.loaded || _tabs.index == _chatTab
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _openExpenseForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr(context, _add)),
                  ),
            body: PageBody(
              child: Column(
                children: [
                  SyncProblemBanner(visible: _session.hasError && !_session.writeFailed),
                  if (_session.writeFailed) _writeBanner(),
                  if (g.archived) _archivedBanner(),
                  Expanded(
                    child: !_session.loaded
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _ExpensesTab(session: _session, onOpen: _showExpense),
                              _BalancesTab(session: _session),
                              _MembersTab(session: _session, onLeft: () => Navigator.of(context).pop()),
                              _ActivityTab(session: _session),
                              _ChatTab(session: _session),
                            ],
                          ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _writeBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          title: Text(
            tr(context, t('A change could not be saved. Someone may have changed it first, or you may not have permission.', 'बदलाव सेव नहीं हो सका। शायद किसी और ने पहले बदल दिया या आपके पास अनुमति नहीं है।')),
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          trailing: IconButton(icon: Icon(Icons.close_rounded, color: scheme.onErrorContainer), onPressed: _session.clearWriteProblem),
        ),
      ),
    );
  }

  Widget _archivedBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.inventory_2_outlined, color: scheme.onTertiaryContainer),
          title: Text(
            tr(context, t('This group is archived. You can read it but not change it.', 'यह ग्रुप आर्काइव है। आप इसे पढ़ सकते हैं पर बदल नहीं सकते।')),
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
          trailing: _session.iAmAdmin
              ? TextButton(onPressed: () => _session.setArchived(false), child: Text(tr(context, t('Restore', 'वापस लाएं'))))
              : null,
        ),
      ),
    );
  }

  // ---------- menu ----------

  Widget _menu(ExpenseGroup g) {
    final admin = _session.iAmAdmin;
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _editGroup(g);
          case 'budget':
            _editBudget(g);
          case 'export':
            _export();
          case 'archive':
            _toggleArchive(g);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'export', child: Text(tr(context, t('Export bills', 'बिल एक्सपोर्ट करें')))),
        if (admin) PopupMenuItem(value: 'edit', child: Text(tr(context, t('Rename / icon / colour', 'नाम / आइकन / रंग बदलें')))),
        if (admin && !g.archived) PopupMenuItem(value: 'budget', child: Text(tr(context, t('Group budget', 'ग्रुप बजट')))),
        if (admin) PopupMenuItem(value: 'archive', child: Text(tr(context, g.archived ? t('Restore group', 'ग्रुप वापस लाएं') : t('Archive group', 'ग्रुप आर्काइव करें')))),
      ],
    );
  }

  Future<void> _toggleArchive(ExpenseGroup g) async {
    if (g.archived) {
      _session.setArchived(false);
      return;
    }
    final ok = await _confirm(
      context,
      t('Archive this group?', 'यह ग्रुप आर्काइव करें?'),
      t('Nobody can add or change bills while it is archived. Everything is kept and you can restore it any time.', 'आर्काइव रहते हुए कोई बिल जोड़ या बदल नहीं सकता। सब कुछ सुरक्षित रहेगा और आप कभी भी वापस ला सकते हैं।'),
      t('Archive', 'आर्काइव करें'),
    );
    if (ok) _session.setArchived(true);
  }

  void _editGroup(ExpenseGroup g) {
    showFormSheet<void>(context, (ctx) => _EditGroupForm(session: _session, group: g));
  }

  Future<void> _editBudget(ExpenseGroup g) async {
    final v = await _askAmount(
      context,
      t('Monthly group budget (₹)', 'मासिक ग्रुप बजट (₹)'),
      g.budgetMinor > 0 ? g.budgetMinor : 1000000,
    );
    if (v != null) _session.setBudget(v);
  }

  // ---------- one bill ----------

  void _showExpense(GroupExpense e) {
    showFormSheet<void>(context, (ctx) => _ExpenseSheet(session: _session, expense: e, onEdit: () => _openExpenseForm(existing: e)));
  }

  // ---------- export ----------

  void _export() {
    showFormSheet<void>(context, (ctx) => _ExportSheet(session: _session));
  }
}

// ======================= edit group =======================

class _EditGroupForm extends StatefulWidget {
  final GroupSession session;
  final ExpenseGroup group;
  const _EditGroupForm({required this.session, required this.group});

  @override
  State<_EditGroupForm> createState() => _EditGroupFormState();
}

class _EditGroupFormState extends State<_EditGroupForm> {
  late final TextEditingController _name = TextEditingController(text: widget.group.name);
  late String _icon = widget.group.iconKey;
  late int _color = widget.group.colorIndex;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, t('Edit group', 'ग्रुप बदलें')), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: tr(context, t('Group name', 'ग्रुप का नाम')), border: const OutlineInputBorder()),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () {
                    if (_name.text.trim() != widget.group.name) widget.session.rename(_name.text);
                    if (_icon != widget.group.iconKey || _color != widget.group.colorIndex) {
                      widget.session.setLook(iconKey: _icon, colorIndex: _color);
                    }
                    Navigator.of(context).pop();
                  },
            child: Text(tr(context, t('Save', 'सेव करें'))),
          ),
        ),
      ],
    );
  }
}

// ======================= expenses tab =======================

class _ExpensesTab extends StatelessWidget {
  final GroupSession session;
  final void Function(GroupExpense) onOpen;
  const _ExpensesTab({required this.session, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final list = session.expenses;
    final my = session.myBalance;
    final budget = session.budgetThisMonth();
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  my == 0
                      ? tr(context, t('You are settled up', 'आपका हिसाब बराबर है'))
                      : (my > 0 ? tr(context, t('You are owed', 'आपको मिलना है')) : tr(context, t('You owe', 'आपको देना है'))),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  formatInr(my.abs()),
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr(context, t('Group total', 'ग्रुप का कुल'))}: ${formatInr(totalSpent(list))}',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                if (budget.hasBudget) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: budget.fraction.clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: budget.over ? scheme.error : (budget.nearLimit ? Colors.orange : scheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tr(context, t('This month', 'यह महीना'))}: ${formatInr(budget.spent)} / ${formatInr(budget.budget)}'
                    '${budget.over ? '  •  ${tr(context, t('over budget', 'बजट से ज़्यादा'))}' : (budget.nearLimit ? '  •  ${tr(context, t('almost used', 'लगभग खत्म'))}' : '')}',
                    style: TextStyle(color: budget.over ? scheme.error : scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              message: t('No bills yet. Tap "Add expense" to record the first one.', 'अभी कोई बिल नहीं। पहला दर्ज करने के लिए "खर्च जोड़ें" दबाएं।'),
            ),
          ),
        for (final e in list) _tile(context, e),
      ],
    );
  }

  Widget _tile(BuildContext context, GroupExpense e) {
    final scheme = Theme.of(context).colorScheme;
    final cat = groupCategory(e.categoryId);
    final mine = (e.paidBy[session.me.uid] ?? 0) - (e.splits[session.me.uid] ?? 0);
    final involved = e.paidBy.containsKey(session.me.uid) || e.splits.containsKey(session.me.uid);
    return ListTile(
      onTap: () => onOpen(e),
      leading: CircleAvatar(
        backgroundColor: categoryColor(cat).withAlpha(36),
        child: Icon(categoryIcon(cat.iconKey), color: categoryColor(cat), size: 22),
      ),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${tr(context, t('Paid by', 'भुगतान'))} ${paidByText(context, session, e)}  •  ${dayLabel(context, DateTime.fromMillisecondsSinceEpoch(e.date))}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatInr(e.amountMinor), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (!involved)
            Text(tr(context, t('not involved', 'शामिल नहीं')), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
          else
            Text(
              mine >= 0
                  ? '${tr(context, t('you lent', 'आपने दिया'))} ${formatInr(mine)}'
                  : '${tr(context, t('you owe', 'आपको देना'))} ${formatInr(-mine)}',
              style: TextStyle(fontSize: 11, color: balanceColor(context, mine)),
            ),
        ],
      ),
    );
  }
}

class _ExpenseSheet extends StatelessWidget {
  final GroupSession session;
  final GroupExpense expense;
  final VoidCallback onEdit;
  const _ExpenseSheet({required this.session, required this.expense, required this.onEdit});

  List<Widget> _rows(BuildContext context, Map<String, int> m) {
    final ids = m.keys.toList()..sort((a, b) => session.nameOf(a).compareTo(session.nameOf(b)));
    return [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(id == session.me.uid ? '${session.nameOf(id)} (${tr(context, youLabel)})' : session.nameOf(id))),
              Text(formatInr(m[id]!), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final text = Theme.of(context).textTheme;
    final canEdit = !session.isArchived && canEditExpense(session.myRole, session.me.uid, e);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(formatInr(e.amountMinor), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (e.isForeign) Text('${formatForeign(e.origMinor, e.currency)}  (1 ${e.currency} = ₹${e.rate.toStringAsFixed(2)})'),
        const SizedBox(height: 4),
        Text('${fmtDate(DateTime.fromMillisecondsSinceEpoch(e.date))}  •  ${tr(context, categoryName2(e))}  •  ${tr(context, splitTypeLabel(e.splitType))}'),
        if (e.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.note)),
        const SizedBox(height: 12),
        Text(tr(context, t('Paid by', 'भुगतान किसने किया')), style: text.labelLarge),
        ..._rows(context, e.paidBy),
        const SizedBox(height: 10),
        Text(tr(context, t('Owed by', 'किसके हिस्से में')), style: text.labelLarge),
        ..._rows(context, e.splits),
        const SizedBox(height: 4),
        Text(
          '${tr(context, t('Added by', 'जोड़ने वाला'))}: ${session.nameOf(e.createdBy)}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        if (canEdit) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(tr(context, t('Delete', 'हटाएं'))),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ok = await _confirm(
                      context,
                      t('Delete this bill?', 'यह बिल हटाएं?'),
                      t('Everybody\'s balances will change.', 'सबका हिसाब बदल जाएगा।'),
                      t('Delete', 'हटाएं'),
                    );
                    if (ok) {
                      session.deleteExpense(e);
                      nav.pop();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(tr(context, t('Edit', 'बदलें'))),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  LText categoryName2(GroupExpense e) => groupCategory(e.categoryId).name;
}

// ======================= balances tab =======================

class _BalancesTab extends StatelessWidget {
  final GroupSession session;
  const _BalancesTab({required this.session});

  String _owesText(BuildContext context, int v) {
    if (v == 0) return tr(context, t('settled up', 'हिसाब बराबर'));
    return v > 0 ? '${tr(context, t('gets back', 'मिलना है'))} ${formatInr(v)}' : '${tr(context, t('owes', 'देना है'))} ${formatInr(-v)}';
  }

  Future<void> _pay(BuildContext context, Transfer tf) async {
    final me = session.me.uid;
    final iPay = tf.from == me;
    final amount = await _askAmount(
      context,
      iPay
          ? t('How much did you pay ${session.nameOf(tf.to)}?', '${session.nameOf(tf.to)} को कितना दिया?')
          : t('How much did ${session.nameOf(tf.from)} pay you?', '${session.nameOf(tf.from)} ने कितना दिया?'),
      tf.amountMinor,
    );
    if (amount == null) return;
    session.recordPayment(from: tf.from, to: tf.to, amountMinor: amount);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final net = session.net;
    final ids = net.keys.toList()
      ..sort((a, b) {
        final c = (net[b] ?? 0).compareTo(net[a] ?? 0);
        return c != 0 ? c : session.nameOf(a).compareTo(session.nameOf(b));
      });
    final transfers = session.suggestedPayments;
    final pending = [for (final s in session.settlements) if (!s.confirmed) s];
    final done = [for (final s in session.settlements) if (s.confirmed) s];
    final me = session.me.uid;
    final canAct = !session.isArchived;

    Widget head(LText l) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(tr(context, l), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        head(t('Who owes whom', 'किसे कितना देना है')),
        for (final id in ids)
          ListTile(
            dense: true,
            leading: session.memberById(id) == null
                ? const CircleAvatar(radius: 16, child: Icon(Icons.person_off_outlined, size: 18))
                : MemberAvatar(member: session.memberById(id)!, radius: 16),
            title: Text(id == me ? '${session.nameOf(id)} (${tr(context, youLabel)})' : session.nameOf(id)),
            trailing: Text(_owesText(context, net[id] ?? 0), style: TextStyle(fontWeight: FontWeight.w700, color: balanceColor(context, net[id] ?? 0))),
          ),
        head(t('Settle up (simplest way)', 'हिसाब चुकता करें (सबसे आसान तरीका)')),
        if (transfers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(tr(context, t('Everyone is settled up. 🎉', 'सबका हिसाब बराबर है। 🎉')), style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        for (final tf in transfers)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text('${tf.from == me ? tr(context, youLabel) : session.nameOf(tf.from)}  →  ${tf.to == me ? tr(context, youLabel) : session.nameOf(tf.to)}'),
              subtitle: pendingBetween(session.settlements, tf.from, tf.to) > 0
                  ? Text('${tr(context, t('Waiting for confirmation', 'पुष्टि का इंतज़ार'))}: ${formatInr(pendingBetween(session.settlements, tf.from, tf.to))}')
                  : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatInr(tf.amountMinor), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (canAct && (tf.from == me || tf.to == me))
                    SizedBox(
                      height: 28,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                        onPressed: () => _pay(context, tf),
                        child: Text(tr(context, tf.from == me ? t('I paid', 'मैंने दे दिया') : t('Received', 'मिल गया'))),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (pending.isNotEmpty) head(t('Waiting for confirmation', 'पुष्टि का इंतज़ार')),
        for (final s in pending)
          ListTile(
            leading: const Icon(Icons.hourglass_bottom_rounded),
            title: Text('${s.from == me ? tr(context, youLabel) : session.nameOf(s.from)}  →  ${s.to == me ? tr(context, youLabel) : session.nameOf(s.to)}'),
            subtitle: Text(formatInr(s.amountMinor)),
            trailing: !canAct
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.to == me)
                        FilledButton.tonal(onPressed: () => session.confirmPayment(s), child: Text(tr(context, t('Confirm', 'पुष्टि करें')))),
                      if (s.from == me || s.to == me || session.iAmAdmin)
                        IconButton(
                          tooltip: tr(context, t('Cancel', 'रद्द करें')),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => session.cancelPayment(s),
                        ),
                    ],
                  ),
          ),
        if (done.isNotEmpty) head(t('Payments made', 'किए गए भुगतान')),
        for (final s in done)
          ListTile(
            dense: true,
            leading: Icon(Icons.check_circle_outline_rounded, color: incomeColor(context)),
            title: Text('${s.from == me ? tr(context, youLabel) : session.nameOf(s.from)}  →  ${s.to == me ? tr(context, youLabel) : session.nameOf(s.to)}'),
            subtitle: Text(fmtDate(DateTime.fromMillisecondsSinceEpoch(s.confirmedAt > 0 ? s.confirmedAt : s.createdAt))),
            trailing: Text(formatInr(s.amountMinor), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            tr(context, t('Money is paid outside the app (cash, UPI...). Here you only note it down; a payment counts once the person who received it confirms.', 'पैसे ऐप के बाहर (कैश, UPI...) दिए जाते हैं। यहां सिर्फ़ दर्ज होता है; पैसे पाने वाले की पुष्टि के बाद ही भुगतान गिना जाता है।')),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ======================= members tab =======================

class _MembersTab extends StatelessWidget {
  final GroupSession session;
  final VoidCallback onLeft;
  const _MembersTab({required this.session, required this.onLeft});

  Future<void> _leave(BuildContext context) async {
    final reason = session.cannotLeaveReason;
    if (reason != null) {
      showSnack(
        context,
        reason == 'owner'
            ? t('You are the owner. Hand over ownership to another member first (tap a member).', 'आप मालिक हैं। पहले किसी और सदस्य को मालिकाना हक़ दें (सदस्य पर दबाएं)।')
            : t('Settle your balance before leaving the group.', 'ग्रुप छोड़ने से पहले अपना हिसाब चुकता करें।'),
        error: true,
      );
      return;
    }
    final ok = await _confirm(
      context,
      t('Leave this group?', 'यह ग्रुप छोड़ें?'),
      t('You will not see it any more unless somebody invites you again. Old bills stay in the group.', 'जब तक कोई दोबारा न जोड़े, यह आपको नहीं दिखेगा। पुराने बिल ग्रुप में रहेंगे।'),
      t('Leave', 'छोड़ें'),
    );
    if (!ok) return;
    final done = await session.leave();
    if (done) {
      onLeft();
    } else if (context.mounted) {
      showSnack(context, t('Could not leave. Check your internet.', 'ग्रुप नहीं छोड़ सके। इंटरनेट जांचें।'), error: true);
    }
  }

  void _memberActions(BuildContext context, GroupMember m) {
    final me = session.me.uid;
    if (m.uid == me || session.isArchived) return;
    final owner = session.myRole == GroupRole.owner;
    final canRemove = canRemoveMember(actor: session.myRole, actorId: me, target: m);
    if (!owner && !canRemove) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(tr(ctx, roleLabel(m.role)))),
            if (owner && m.role == GroupRole.member)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(tr(ctx, t('Make admin', 'एडमिन बनाएं'))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  session.changeRole(m, GroupRole.admin);
                },
              ),
            if (owner && m.role == GroupRole.admin)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(tr(ctx, t('Make normal member', 'सामान्य सदस्य बनाएं'))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  session.changeRole(m, GroupRole.member);
                },
              ),
            if (owner)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(tr(ctx, t('Make owner (you become admin)', 'मालिक बनाएं (आप एडमिन बनेंगे)'))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ok = await _confirm(
                    context,
                    t('Hand over ownership?', 'मालिकाना हक़ दें?'),
                    t('${m.name} becomes the owner. You stay as admin.', '${m.name} मालिक बन जाएंगे। आप एडमिन रहेंगे।'),
                    t('Hand over', 'दें'),
                  );
                  if (ok) session.transferOwnership(m);
                },
              ),
            if (canRemove)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(ctx).colorScheme.error),
                title: Text(tr(ctx, t('Remove from group', 'ग्रुप से हटाएं')), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ok = await _confirm(
                    context,
                    t('Remove ${m.name}?', '${m.name} को हटाएं?'),
                    t('Their old bills stay. Their balance stays in the group totals.', 'उनके पुराने बिल रहेंगे। उनका हिसाब ग्रुप में बना रहेगा।'),
                    t('Remove', 'हटाएं'),
                  );
                  if (ok) session.removeMember(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = session.group!;
    final me = session.me.uid;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, t('Invite people', 'लोगों को बुलाएं')), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelectableText(
                  g.inviteCode,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.share_rounded),
                      label: Text(tr(context, t('Share invite', 'इनवाइट भेजें'))),
                      onPressed: () => Share.share(inviteMessage(g.name, g.inviteCode)),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(tr(context, t('Copy code', 'कोड कॉपी करें'))),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: g.inviteCode));
                        if (context.mounted) showSnack(context, t('Code copied', 'कोड कॉपी हुआ'));
                      },
                    ),
                    if (session.iAmAdmin && !g.archived)
                      TextButton(
                        onPressed: () async {
                          final ok = await _confirm(
                            context,
                            t('Make a new code?', 'नया कोड बनाएं?'),
                            t('The old code stops working. People already in the group stay.', 'पुराना कोड काम करना बंद कर देगा। ग्रुप के मौजूदा लोग रहेंगे।'),
                            t('New code', 'नया कोड'),
                          );
                          if (ok) session.resetInviteCode();
                        },
                        child: Text(tr(context, t('Reset code', 'कोड बदलें'))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('${tr(context, t('Members', 'सदस्य'))} (${session.members.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        for (final m in session.members)
          ListTile(
            onTap: () => _memberActions(context, m),
            leading: MemberAvatar(member: m),
            title: Text(m.uid == me ? '${m.name} (${tr(context, youLabel)})' : m.name),
            trailing: Chip(
              label: Text(tr(context, roleLabel(m.role))),
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: Text(tr(context, t('Leave group', 'ग्रुप छोड़ें'))),
            onPressed: () => _leave(context),
          ),
        ),
      ],
    );
  }
}

// ======================= activity tab =======================

class _ActivityTab extends StatelessWidget {
  final GroupSession session;
  const _ActivityTab({required this.session});

  LText _describe(GroupActivity a) {
    final who = a.actorName.isEmpty ? 'Someone' : a.actorName;
    final amt = a.amountMinor > 0 ? formatInr(a.amountMinor) : '';
    final s = a.subject;
    switch (a.type) {
      case 'group_created':
        return t('$who created the group', '$who ने ग्रुप बनाया');
      case 'member_joined':
        return t('$who joined', '$who जुड़े');
      case 'member_left':
        return t('$who left', '$who ने ग्रुप छोड़ा');
      case 'member_removed':
        return t('$who removed $s', '$who ने $s को हटाया');
      case 'role_changed':
        return t('$who changed the role of $s', '$who ने $s की भूमिका बदली');
      case 'expense_added':
        return t('$who added "$s" $amt', '$who ने "$s" $amt जोड़ा');
      case 'expense_edited':
        return t('$who edited "$s" $amt', '$who ने "$s" $amt बदला');
      case 'expense_deleted':
        return t('$who deleted "$s" $amt', '$who ने "$s" $amt हटाया');
      case 'settlement_paid':
        return t('$who paid $s $amt (waiting for confirmation)', '$who ने $s को $amt दिए (पुष्टि बाकी)');
      case 'settlement_confirmed':
        return t('Payment of $amt between $who and $s confirmed', '$who और $s के बीच $amt का भुगतान पक्का हुआ');
      case 'settlement_cancelled':
        return t('$who cancelled a payment of $amt to $s', '$who ने $s को $amt का भुगतान रद्द किया');
      case 'group_archived':
        return t('$who archived the group', '$who ने ग्रुप आर्काइव किया');
      case 'group_restored':
        return t('$who restored the group', '$who ने ग्रुप वापस लाया');
      case 'group_renamed':
        return t('$who renamed the group to "$s"', '$who ने ग्रुप का नाम "$s" रखा');
      case 'budget_changed':
        return t('$who set the monthly budget to $amt', '$who ने मासिक बजट $amt किया');
      case 'code_reset':
        return t('$who made a new invite code', '$who ने नया इनवाइट कोड बनाया');
      default:
        return t('$who did something', '$who ने कुछ किया');
    }
  }

  IconData _icon(String type) => switch (type) {
        'expense_added' || 'expense_edited' => Icons.receipt_long_rounded,
        'expense_deleted' => Icons.delete_outline_rounded,
        'settlement_paid' || 'settlement_confirmed' || 'settlement_cancelled' => Icons.payments_outlined,
        'member_joined' || 'member_left' || 'member_removed' || 'role_changed' => Icons.person_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final list = session.activity;
    if (list.isEmpty) {
      return EmptyState(icon: Icons.history_rounded, message: t('Nothing has happened yet.', 'अभी कुछ नहीं हुआ।'));
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final a = list[i];
        final when = DateTime.fromMillisecondsSinceEpoch(a.at);
        return ListTile(
          dense: true,
          leading: Icon(_icon(a.type), color: scheme.primary),
          title: Text(tr(context, _describe(a))),
          subtitle: Text('${fmtDate(when)}  ${fmtTime(when)}'),
        );
      },
    );
  }
}

// ======================= chat tab =======================

class _ChatTab extends StatefulWidget {
  final GroupSession session;
  const _ChatTab({required this.session});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _input = TextEditingController();
  GroupMessage? _replyTo;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.session.sendMessage(_input.text, replyTo: _replyTo)) {
      _input.clear();
      setState(() => _replyTo = null);
    }
  }

  void _actions(GroupMessage m) {
    final s = widget.session;
    if (m.deleted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!s.isArchived)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(tr(ctx, t('Reply', 'जवाब दें'))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _replyTo = m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(tr(ctx, t('Copy', 'कॉपी करें'))),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: m.text));
              },
            ),
            if (!s.isArchived && (m.senderId == s.me.uid || s.iAmAdmin))
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                title: Text(tr(ctx, t('Delete message', 'संदेश हटाएं'))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  s.deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final scheme = Theme.of(context).colorScheme;
    final list = s.messages.reversed.toList();
    return Column(
      children: [
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: Icons.chat_bubble_outline_rounded, message: t('No messages yet. Say hello to the group!', 'अभी कोई संदेश नहीं। ग्रुप को नमस्ते कहें!'))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final mine = m.senderId == s.me.uid;
                    final when = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _actions(m),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          decoration: BoxDecoration(
                            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!mine)
                                Text(s.nameOf(m.senderId), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                              if (m.replyPreview.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 2, bottom: 4),
                                  padding: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.primary, width: 3))),
                                  child: Text(m.replyPreview, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ),
                              m.deleted
                                  ? Text(tr(context, t('This message was deleted', 'यह संदेश हटा दिया गया')), style: TextStyle(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant))
                                  : SelectableText(m.text),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(fmtTime(when), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (s.isArchived)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr(context, t('Chat is closed because the group is archived.', 'ग्रुप आर्काइव होने से चैट बंद है।')), style: TextStyle(color: scheme.onSurfaceVariant)),
          )
        else ...[
          if (_replyTo != null)
            Container(
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(child: Text('${tr(context, t('Replying to', 'जवाब'))}: ${_replyTo!.text}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _replyTo = null)),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr(context, t('Message', 'संदेश')),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ======================= export =======================

class _ExportSheet extends StatefulWidget {
  final GroupSession session;
  const _ExportSheet({required this.session});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _busy = false;
  String? _error;

  Future<ByteData> _font(String name) => rootBundle.load('assets/fonts/$name');

  Future<void> _run(bool pdf) async {
    final s = widget.session;
    if (s.expenses.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await cleanOldOutputs();
      String nameOf(String uid) => s.nameOf(uid);
      String cat(String id) => groupCategory(id).name.of('en');
      final stamp = DateTime.now();
      final base = 'group_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
      final OutputFile out;
      if (!pdf) {
        final table = buildGroupTable(s.expenses, nameOf: nameOf, categoryName: cat);
        out = await writeOutput('$base.csv', Uint8List.fromList(utf8.encode(buildCsv(table))));
      } else {
        final net = s.net;
        final bytes = await buildExpensePdf(
          title: 'SaralBook - ${s.group?.name ?? 'Group'}',
          subtitle: fmtDate(stamp),
          summary: [
            ('Total spent', formatInr(totalSpent(s.expenses))),
            ('Bills', '${s.expenses.length}'),
            for (final id in net.keys)
              (s.nameOf(id), net[id]! == 0 ? 'settled' : (net[id]! > 0 ? 'gets ${formatInr(net[id]!)}' : 'owes ${formatInr(-net[id]!)}')),
          ],
          headers: const ['Date', 'Title', 'Category', 'Total', 'Paid by', 'Owed by'],
          rows: groupPdfRows(s.expenses, nameOf: nameOf, categoryName: cat),
          fonts: PdfFontData(
            regular: await _font('NotoSans-Regular.ttf'),
            bold: await _font('NotoSans-Bold.ttf'),
            devanagari: await _font('NotoSansDevanagari-Regular.ttf'),
          ),
        );
        out = await writeOutput('$base.pdf', bytes);
      }
      await shareOutputs([out]);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr(context, t('Could not make the file. Try again.', 'फ़ाइल नहीं बन सकी। फिर कोशिश करें।')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.session.expenses.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, t('Export bills', 'बिल एक्सपोर्ट करें')), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (empty) Text(tr(context, t('No bills to export yet.', 'एक्सपोर्ट करने के लिए अभी कोई बिल नहीं।'))),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || empty ? null : () => _run(false),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('CSV'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || empty ? null : () => _run(true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ],
    );
  }
}
