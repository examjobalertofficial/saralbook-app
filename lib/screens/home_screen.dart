import 'package:flutter/material.dart';

import '../config/websites.dart';
import '../utils/navigation.dart';
import '../widgets/brand_logo.dart';
import '../widgets/website_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sites = Websites.all;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BrandLogo(size: 48),
                        const SizedBox(width: 12),
                        Text(
                          'SaralBook',
                          style: text.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Explore SaralBook',
                      style: text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All our platforms in one app',
                      style: text.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList.separated(
                itemCount: sites.length,
                separatorBuilder: (context, i) => const SizedBox(height: 14),
                itemBuilder: (context, i) => WebsiteCard(
                  site: sites[i],
                  index: i,
                  onOpen: () => openWebsite(context, sites[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
