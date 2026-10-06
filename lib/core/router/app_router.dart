import 'package:go_router/go_router.dart';

import '../../screens/home_screen.dart';
import '../../screens/more_screen.dart';
import '../../screens/shell/app_shell.dart';
import '../../screens/splash_screen.dart';
import '../../screens/study/study_hub_screen.dart';
import '../../screens/tabs/platform_tab.dart';
import '../../screens/tools/tools_screen.dart';
import '../l10n/app_strings.dart';

/// Single place that defines every screen address in the app.
/// Later phases add deep links here (notification -> exact job/test/product).
abstract class AppRoutes {
  static const splash = '/splash';
  static const home = '/home';
  static const study = '/study';
  static const jobs = '/jobs';
  static const tools = '/tools';
  static const more = '/more';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.study,
              builder: (context, state) => const StudyHubScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.jobs,
              builder: (context, state) {
                final s = AppStrings.of(context);
                return PlatformTab(
                  title: s.jobsTitle,
                  subtitle: s.jobsSubtitle,
                  siteIds: const ['examjobalert'],
                  comingSoon: s.comingSoonJobs,
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.tools,
              builder: (context, state) => const ToolsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}
