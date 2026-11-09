import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';

/// Phones: bottom navigation bar. Tablets / wide screens: navigation rail.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static DateTime _lastHomeRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  void _select(BuildContext context, int index) {
    final goingHome = index == 0 && navigationShell.currentIndex != 0;
    navigationShell.goBranch(
      index,
      // Tapping the current tab again returns to its first screen.
      initialLocation: index == navigationShell.currentIndex,
    );
    // Back on Home from another tab: load the newest posts again
    // (at most once every 20 seconds).
    if (goingHome) {
      final now = DateTime.now();
      if (now.difference(_lastHomeRefresh) > const Duration(seconds: 20)) {
        _lastHomeRefresh = now;
        unawaited(AppScope.of(context).config.refresh(force: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final items = <_Dest>[
      _Dest(Icons.home_outlined, Icons.home_rounded, s.navHome),
      _Dest(Icons.menu_book_outlined, Icons.menu_book_rounded, s.navStudy),
      _Dest(Icons.work_outline_rounded, Icons.work_rounded, s.navJobs),
      _Dest(Icons.handyman_outlined, Icons.handyman_rounded, s.navTools),
      _Dest(Icons.grid_view_outlined, Icons.grid_view_rounded, s.navMore),
    ];
    final index = navigationShell.currentIndex;

    return PopScope(
      // Back on any tab other than Home goes to Home first.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= 600 && constraints.maxHeight >= 480;
          if (!useRail) {
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => _select(context, i),
                destinations: [
                  for (final d in items)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            );
          }
          final extended = constraints.maxWidth >= 1000;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => _select(context, i),
                  extended: extended,
                  labelType:
                      extended ? null : NavigationRailLabelType.all,
                  destinations: [
                    for (final d in items)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Dest(this.icon, this.selectedIcon, this.label);
}
