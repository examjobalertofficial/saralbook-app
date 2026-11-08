import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_services.dart';
import '../core/l10n/ltext.dart';
import 'tr.dart';

class _Look {
  final String name;
  final IconData icon;
  final Color color;
  const _Look(this.name, this.icon, this.color);
}

const Map<String, _Look> _looks = {
  'whatsapp': _Look('WhatsApp', Icons.chat_rounded, Color(0xFF25D366)),
  'telegram': _Look('Telegram', Icons.send_rounded, Color(0xFF229ED9)),
  'facebook': _Look('Facebook', Icons.facebook, Color(0xFF1877F2)),
  'instagram': _Look('Instagram', Icons.camera_alt_rounded, Color(0xFFD6336C)),
  'x': _Look('X', Icons.alternate_email_rounded, Color(0xFF222222)),
  'linkedin': _Look('LinkedIn', Icons.work_rounded, Color(0xFF0A66C2)),
  'threads': _Look('Threads', Icons.forum_rounded, Color(0xFF444444)),
};

/// "Follow us" buttons for the social pages filled in on the website.
/// Shows nothing until at least one link is set.
class SocialLinksCard extends StatelessWidget {
  const SocialLinksCard({super.key});

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* no app or browser: nothing to do */}
  }

  @override
  Widget build(BuildContext context) {
    final config = AppScope.of(context).config;
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) {
        final links = config.config.social;
        if (links.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, t('Follow us', 'हमें फ़ॉलो करें')),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tr(context, t('Join our channels for quick job and exam updates', 'जल्दी नौकरी और परीक्षा अपडेट के लिए हमारे चैनल से जुड़ें')),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final l in links)
                    if (_looks[l.id] != null)
                      Material(
                        color: _looks[l.id]!.color,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(l.url),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_looks[l.id]!.icon, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _looks[l.id]!.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
