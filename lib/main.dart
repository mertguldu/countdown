import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_root.dart';
import 'core/services/notification_service.dart';
import 'core/services/purchase_service.dart';
import 'core/services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Order matters: notification service sets up timezone data that other
  // services may rely on. Keep these sequential, not parallel.
  await NotificationService.init();
  await PurchaseService.init();
  await WidgetService.init();

  runApp(const ProviderScope(child: AppRoot()));
}