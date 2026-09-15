import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/auth_gate.dart';

class Bep1979App extends StatelessWidget {
  const Bep1979App({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bếp 1979',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home ?? const AuthGate(),
    );
  }
}
