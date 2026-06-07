import 'package:home_widget/home_widget.dart';

class WidgetService {
  WidgetService._();

  // TODO: This must match EXACTLY across three places:
  //   1. Here (Dart side)
  //   2. Xcode > Runner target > Signing & Capabilities > App Groups
  //   3. Xcode > CountdownWidget target > Signing & Capabilities > App Groups
  // If these don't match the widget will never receive data from Flutter.
  static const _appGroupId = 'group.com.yourcompany.countdown';

  // Must match the class name / widget name registered on each platform:
  //   iOS    → the @main struct name in CountdownWidget.swift
  //   Android → the class name in CountdownWidget.kt
  static const _iOSWidgetName     = 'CountdownWidget';
  static const _androidWidgetName = 'CountdownWidget';

  // ── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    // Registers the Dart callback that runs when a user taps an interactive
    // element inside the home screen widget.
    HomeWidget.registerInteractivityCallback(_backgroundCallback);
  }

  // ── Background callback ────────────────────────────────────────────────────

  // @pragma annotation ensures the Dart VM doesn't tree-shake this function
  // since it's called from native code, not from Dart.
  @pragma('vm:entry-point')
  static Future<void> _backgroundCallback(Uri? uri) async {
    // TODO: Parse the URI to determine which widget action was tapped,
    // then update app state accordingly.
    // e.g. uri?.host == 'increment' → increment counter for uri?.queryParameters['id']
  }

  // ── Data helpers ───────────────────────────────────────────────────────────

  /// Writes [value] under [key] to the shared container and triggers
  /// a widget refresh on both platforms.
  static Future<void> updateWidget({
    required String key,
    required dynamic value,
  }) async {
    await HomeWidget.saveWidgetData(key, value);
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: _androidWidgetName,
    );
  }

  /// Writes multiple key-value pairs in one batch before triggering refresh.
  /// Prefer this over multiple [updateWidget] calls to avoid redundant redraws.
  static Future<void> updateWidgetBatch(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      await HomeWidget.saveWidgetData(entry.key, entry.value);
    }
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: _androidWidgetName,
    );
  }
}