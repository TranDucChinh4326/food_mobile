import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../widgets/app_brand_mark.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  AuthSession? _session;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _authService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _restoring = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const _StartupScreen();
    if (_session == null) {
      return AuthScreen(
        authService: _authService,
        onAuthenticated: (session) => setState(() => _session = session),
      );
    }
    return AppShell(
      session: _session!,
      onLogout: _logout,
      onSessionUpdated: (session) => setState(() => _session = session),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF8), Color(0xFFF7ECE1)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBrandMark(size: 76),
              SizedBox(height: 14),
              Text(
                'Bếp 1979',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF241812),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'MÓN NGON MỖI NGÀY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF5722),
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFFF5722),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
