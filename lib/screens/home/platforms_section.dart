import 'package:flutter/material.dart';

import '../../config/websites.dart';
import '../../core/l10n/app_strings.dart';
import '../../utils/navigation.dart';
import 'section_header.dart';

class PlatformsSection extends StatelessWidget {
  final List<Website> sites;
  final String title;
  const PlatformsSection({super.key, required this.sites, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title.isEmpty ? s.platformsTitle : title),
          for (final site in sites)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: scheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: site.enabled ? site.color : scheme.outline,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(site.icon, color: Colors.white),
                  ),
                  title: Text(
                    site.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    site.enabled ? site.description : s.unavailable,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openWebsite(context, site),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
