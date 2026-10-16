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
    final services = AppScope.of(context);
    final push = services.push;
    final title = tr(context, t('Job alerts', 'जॉब अलर्ट'));
    return ListenableBuilder(
      listenable: Listenable.merge([if (push != null) push, services.admin]),
      builder: (context, _) {
        if (push == null || !push.available) {
          // Students never see an unfinished switch. Only the owner gets a
          // hint on what is still missing.
          if (!services.admin.isAdmin) return const SizedBox.shrink();
          return _card(scheme, _note(context, title));
        }
        return _card(
          scheme,
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            secondary: Icon(Icons.notifications_active_rounded, color: scheme.primary),
            title: Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(tr(
              context,
              t('Get a notification for new and updated jobs, admit cards and results.',
                  'नई और अपडेट हुई नौकरी, एडमिट कार्ड और रिज़ल्ट की सूचना पाएं।'),
            )),
            value: push.enabled,
            onChanged: (v) => push.setEnabled(v),
          ),
        );
      },
    );
  }

  Widget _card(ColorScheme scheme, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.primaryContainer.withAlpha(120),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: child,
        ),
      );

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
                    t('Alerts are not switched on yet (only you, the owner, see this). On saralbook.com open '
                        'Settings > SaralBook App > Push notifications, paste the OneSignal App ID and save. Then restart the app.',
                        'अलर्ट अभी चालू नहीं हैं (यह सिर्फ आपको, ओनर को, दिखता है)। saralbook.com पर '
                        'Settings > SaralBook App > Push notifications में OneSignal App ID डालकर सेव करें, फिर ऐप दोबारा खोलें।'),
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
