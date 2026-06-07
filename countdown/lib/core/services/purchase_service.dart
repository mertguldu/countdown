import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  PurchaseService._();

  // TODO: Replace with your actual RevenueCat API keys.
  // iOS key  → RevenueCat dashboard > Your app > API keys > Apple App Store
  // Android  → RevenueCat dashboard > Your app > API keys > Google Play Store
  static const _iosApiKey     = 'appl_XXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  static const _androidApiKey = 'goog_XXXXXXXXXXXXXXXXXXXXXXXXXXXX';

  // TODO: Set your entitlement identifier to match what's in the
  // RevenueCat dashboard (e.g. 'pro', 'premium').
  static const entitlementId = 'pro';

  // ── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );

    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosApiKey
        : _androidApiKey;

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
  }

  // ── Entitlement check ──────────────────────────────────────────────────────

  /// Returns true if the user currently has an active 'pro' entitlement.
  static Future<bool> isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      debugPrint('PurchaseService.isPro error: $e');
      return false;
    }
  }

  /// Restores previous purchases. Call from a "Restore Purchases" button.
  static Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      debugPrint('PurchaseService.restorePurchases error: $e');
      return null;
    }
  }
}