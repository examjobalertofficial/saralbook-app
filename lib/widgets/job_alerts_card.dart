import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/l10n/ltext.dart';
import 'tr.dart';

/// The Jobs tab's alert switch: new AND updated posts (jobs, admit cards,
/// results). Shows a plain note until the website has switched alerts on.
class JobAlertsCard extends StatelessWidget {
  const JobAlertsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final push = AppScope.of(context).push;
    final title = tr(context, t('Job alerts', 'जॉब अलर्ट'));
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: push == null
          ? _note(context, title)
          : ListenableBuilder(
              listenable: push,
              builder: (context, _) {
                if (!push.available) return _note(context, title);
                return SwitchListTile(
                  contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
                  secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
                  title: Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr(
                    context,
                    t('Get a notification for new and updated jobs, admit cards and results.',
                        'नई और अपडेट हुई नौकरी, एडमिट कार्ड और रिज़ल्ट की सूचना पाएं।'),
                  )),
                  value: push.enabled,
                  onChanged: (v) => push.setEnabled(v),
                );
              },
            ),
    );
  }

  Widget _note(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_none_rounded, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    t('Alerts are not switched on yet. They will appear here as soon as they are ready.',
                        'अलर्ट अभी चालू नहीं हैं। तैयार होते ही यहाँ दिखेंगे।'),
                  ),
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
