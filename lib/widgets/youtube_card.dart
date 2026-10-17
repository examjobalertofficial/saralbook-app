import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../core/l10n/ltext.dart';
import 'animations.dart';
import 'tr.dart';

/// Opens the SaralBook YouTube channel (in the YouTube app if it is installed).
Future<void> openYoutubeChannel() async {
  try {
    await launchUrl(Uri.parse(AppInfo.youtubeUrl), mode: LaunchMode.externalApplication);
  } catch (_) {/* no browser: nothing to do */}
}

/// A red call-to-action card for the YouTube channel.
class YoutubeCard extends StatelessWidget {
  const YoutubeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: openYoutubeChannel,
      child: GradientBanner(
        colors: const [Color(0xFFC92A2A), Color(0xFFFF4D4D)],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFC92A2A), size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, t('Watch us on YouTube', 'हमें YouTube पर देखें')),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    tr(context, t('Free classes, tips and exam updates', 'फ्री क्लास, टिप्स और परीक्षा अपडेट')),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
