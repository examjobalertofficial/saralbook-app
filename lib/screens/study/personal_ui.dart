import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart' show dayOf;
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../account/account_widgets.dart';

/// Colours people can give their subjects (stored as an index).
const List<Color> subjectColors = [
  Colors.indigo,
  Colors.teal,
  Colors.orange,
  Colors.pink,
  Colors.green,
  Colors.purple,
  Colors.brown,
  Colors.blueGrey,
];

Color subjectColor(int index) => subjectColors[index.abs() % subjectColors.length];

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtDateMs(int ms) => fmtDate(DateTime.fromMillisecondsSinceEpoch(ms));

/// Shows [builder] only for a signed-in person, with THEIR data.
/// Otherwise asks to sign in. Used by every personal screen.
class PersonalGate extends StatelessWidget {
  final LText title;
  final Widget Function(BuildContext context, PersonalData data) builder;
  const PersonalGate({super.key, required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.auth, services.personal]),
      builder: (context, _) {
        final data = services.personal.current;
        if (data != null) {
          // key = account, so a new account always gets fresh screens
          return KeyedSubtree(key: ValueKey(data.uid), child: builder(context, data));
        }
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, title), style: const TextStyle(fontWeight: FontWeight.w700))),
          body: PageBody(child: const SignInRequiredView()),
        );
      },
    );
  }
}

class SignInRequiredView extends StatelessWidget {
  const SignInRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final auth = AppScope.of(context).auth;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(s.signInRequiredTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              auth.isAvailable ? s.signInRequiredBody : s.signInUnavailable,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (auth.isAvailable)
              FilledButton.icon(
                onPressed: () => requireSignIn(context),
                icon: const Icon(Icons.login_rounded),
                label: Text(s.signInGoogle),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small row of choices (like radio buttons, but friendlier on a phone).
class ChipRow<V> extends StatelessWidget {
  final List<(V, LText)> options;
  final V value;
  final ValueChanged<V> onChanged;
  const ChipRow({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(tr(context, o.$2)),
            selected: o.$1 == value,
            onSelected: (_) => onChanged(o.$1),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final LText message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(tr(context, message), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Shown above a list when saving or loading went wrong.
class SyncProblemBanner extends StatelessWidget {
  final bool visible;
  const SyncProblemBanner({super.key, required this.visible});

  static final LText _text = t(
    'Could not sync with the cloud. Check your internet connection.',
    'क्लाउड से सिंक नहीं हो सका। अपना इंटरनेट कनेक्शन जांचें।',
  );

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(tr(context, _text), style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}

/// "Due date" picker row with a clear button.
class DueDateField extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const DueDateField({super.key, required this.value, required this.onChanged});

  static final LText _label = t('Due date', 'अंतिम तारीख');
  static final LText _none = t('No due date', 'कोई अंतिम तारीख नहीं');

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final now = DateTime.now();
        final initial = v == null ? dayOf(now) : DateTime.fromMillisecondsSinceEpoch(v);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 10),
        );
        if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr(context, _label),
          border: const OutlineInputBorder(),
          suffixIcon: v == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => onChanged(null)),
        ),
        child: Text(v == null ? tr(context, _none) : fmtDateMs(v)),
      ),
    );
  }
}

/// Standard bottom sheet container for the small "add / edit" forms.
Future<T?> showFormSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

/// Undo snackbar used after deleting something.
void showUndo(BuildContext context, LText message, VoidCallback undo) {
  final lang = Localizations.localeOf(context).languageCode;
  final undoLabel = t('Undo', 'वापस लाएं').of(lang);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message.of(lang)), action: SnackBarAction(label: undoLabel, onPressed: undo)));
}

String subjectNameOf(List<Subject> subjects, String id) {
  for (final s in subjects) {
    if (s.id == id) return s.name;
  }
  return '';
}
