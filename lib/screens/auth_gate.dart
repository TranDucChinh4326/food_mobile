import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/api_exception.dart';
import '../widgets/app_brand_mark.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  AuthSession? _session;
  String? _sessionNotice;
  bool _restoring = true;
  bool _checkingSession = false;
  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyActiveSession());
    }
  }

  Future<void> _restore() async {
    final session = await _authService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _restoring = false;
    });
    _startSessionChecks();
  }

  Future<void> _logout({String? notice}) async {
    _sessionCheckTimer?.cancel();
    await _authService.logout();
    if (mounted) {
      setState(() {
        _session = null;
        _sessionNotice = notice;
      });
    }
  }

  void _authenticated(AuthSession session) {
    setState(() {
      _session = session;
      _sessionNotice = null;
    });
    _startSessionChecks();
  }

  void _startSessionChecks() {
    _sessionCheckTimer?.cancel();
    if (_session == null) return;
    _sessionCheckTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_verifyActiveSession()),
    );
  }

  Future<void> _verifyActiveSession() async {
    final session = _session;
    if (session == null || _checkingSession) return;

    _checkingSession = true;
    try {
      final user = await _authService.fetchProfile(session.token);
      if (mounted && _session?.token == session.token) {
        setState(() => _session = session.copyWith(user: user));
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 && _session?.token == session.token) {
        await _logout(
          notice: 'Tài khoản của bạn đã được đăng nhập trên một điện thoại khác. Phiên đăng nhập trên thiết bị này đã kết thúc.',
        );
      }
    } finally {
      _checkingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const _StartupScreen();
    if (_session == null) {
      return AuthScreen(
        authService: _authService,
        onAuthenticated: _authenticated,
        initialNotice: _sessionNotice,
      );
    }
    return AppShell(
      session: _session!,
      onLogout: () => _logout(),
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
