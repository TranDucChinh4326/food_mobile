import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/local_cache_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.initialize();
  runApp(const Bep1979App());

  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  // Keep plugin setup and the permission dialog away from the first frames.
  await Future<void>.delayed(const Duration(seconds: 2));
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermission();
}
