import 'package:flutter/widgets.dart';

import '../core/l10n/ltext.dart';

/// Picks the right language of an [LText] for the current screen.
String tr(BuildContext context, LText text) =>
    text.of(Localizations.localeOf(context).languageCode);
