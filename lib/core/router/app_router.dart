import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/events/domain/event.dart';
import '../../features/events/presentation/screens/home_screen.dart';
import '../../features/events/presentation/screens/new_event/new_event_screen.dart';

part 'app_router.g.dart';

// ── Route path constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const onboarding   = '/onboarding';
  static const home         = '/home';
  static const newEvent     = '/events/new';
  static const eventDetail  = '/events/:id';
  static const settings     = '/settings';
  static const paywall      = '/paywall';
  static const widgetConfig = '/widget-config';

  static String eventDetailPath(String id) => '/events/$id';
}

// ── Router provider ───────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: _onboardingRedirect,
    errorBuilder: (context, state) => _ErrorScreen(state.uri.toString()),
    routes: [
      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const _OnboardingBypass(),
      ),

      // ── Main ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      // ── Events ──────────────────────────────────────────────────────────

      // FAB passes an EventType as `extra` to pre-select the type step.
      GoRoute(
        path: AppRoutes.newEvent,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          key: state.pageKey,
          child: NewEventScreen(
            initialEventType: state.extra is EventType
                ? state.extra as EventType
                : null,
          ),
        ),
      ),

      GoRoute(
        path: AppRoutes.eventDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _StubScreen('Event $id');
        },
      ),

      // ── Settings ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const _StubScreen('Settings'),
      ),

      // ── Paywall ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.paywall,
        builder: (context, state) => const _StubScreen('Paywall'),
      ),

      // ── Widget config ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.widgetConfig,
        builder: (context, state) => const _StubScreen('Widget Config'),
      ),
    ],
  );
}

// ── Redirect logic ────────────────────────────────────────────────────────────

Future<String?> _onboardingRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarding_complete') ?? false;
  final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;

  if (!onboarded && !goingToOnboarding) return AppRoutes.onboarding;
  if (onboarded && goingToOnboarding) return AppRoutes.home;
  return null;
}

// ── Dev onboarding bypass ─────────────────────────────────────────────────────

class _OnboardingBypass extends StatelessWidget {
  const _OnboardingBypass();

  Future<void> _complete(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (context.mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Onboarding — not built yet'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _complete(context),
              child: const Text('Continue to app →'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stub screens ──────────────────────────────────────────────────────────────

class _StubScreen extends StatelessWidget {
  const _StubScreen(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Text(name, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen(this.uri);
  final String uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('No route found for: $uri')),
    );
  }
}