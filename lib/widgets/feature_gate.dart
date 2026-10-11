import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/l10n/ltext.dart';
import 'tr.dart';

/// Shows [child] while the feature is on; otherwise a friendly
/// "temporarily turned off" message. The owner flips the switch from the
/// website or the Admin panel, with no new APK.
class FeatureGate extends StatelessWidget {
  /// One of the names in `FeatureFlags`.
  final String flag;

  /// Title of the screen (used for the message screen's top bar).
  final LText title;

  /// true = only the message (no top bar), for use inside another screen.
  final bool inline;
  final Widget child;

  const FeatureGate({
    super.key,
    required this.flag,
    required this.title,
    required this.child,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppScope.of(context).config;
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) {
        if (config.flagOn(flag)) return child;
        final body = _OffMessage(
          message: tr(
            context,
            t('This feature is temporarily turned off. Please try again later.',
                'यह सुविधा अभी बंद है। कृपया बाद में प्रयास करें।'),
          ),
        );
        if (inline) return body;
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, title))),
          body: body,
        );
      },
    );
  }
}

/// Same message for a tool the owner switched off.
class ToolOffScreen extends StatelessWidget {
  const ToolOffScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: _OffMessage(
          message: tr(
            context,
            t('This tool is temporarily turned off. Please try again later.',
                'यह टूल अभी बंद है। कृपया बाद में प्रयास करें।'),
          ),
        ),
      );
}

class _OffMessage extends StatelessWidget {
  final String message;
  const _OffMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
