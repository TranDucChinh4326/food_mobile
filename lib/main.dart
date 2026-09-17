import 'package:flutter/material.dart';

import 'app.dart';
import 'services/local_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.initialize();
  runApp(const Bep1979App());
}
