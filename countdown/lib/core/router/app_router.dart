import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_router.g.dart';

// ── Route path constants ──────────────────────────────────────────────────────
// Always navigate via these constants — never use raw strings in the codebase.

abstract final class AppRoutes {
  static const onboarding  = '/onboarding';
  static const home        = '/home';
  static const newEvent    = '/events/new';
  static const eventDetail = '/events/:id';
  static const settings    = '/settings';
  static const paywall     = '/paywall';
  static const widgetConfig = '/widget-config';

  // Helper for programmatic event detail navigation.
  static String eventDetailPath(String id) => '/events/$id';
}

// ── Router provider ───────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true, // TODO: set to false before release
    redirect: _onboardingRedirect,
    errorBuilder: (context, state) => _ErrorScreen(state.uri.toString()),
    routes: [
      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const _StubScreen('Onboarding'),
      ),

      // ── Main ────────────────────────────────────────────────────────────
      // TODO: Wrap in StatefulShellRoute when bottom nav is designed.
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const _StubScreen('Home'),
      ),

      // ── Events ──────────────────────────────────────────────────────────
      // new must be declared before :id so 'new' isn't treated as an ID.
      GoRoute(
        path: AppRoutes.newEvent,
        builder: (context, state) => const _StubScreen('New Event'),
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
// Reads the onboarding flag from SharedPreferences on every navigation until
// the flag is set. Once onboarding_complete is true the redirect becomes a
// no-op and costs only a single prefs.getBool() call.
//
// TODO: When the onboarding feature is built, replace this with a proper
// Riverpod provider so the router can refresh via refreshListenable instead
// of reading prefs on every redirect call.

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

// ── Temporary stub screens ────────────────────────────────────────────────────
// Remove each stub as the real screen is built.

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