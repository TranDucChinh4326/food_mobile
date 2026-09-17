import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_mobile/screens/auth_screen.dart';
import 'package:food_mobile/services/auth_service.dart';

void main() {
  testWidgets('switches between login and registration forms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(authService: AuthService(), onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Username hoặc email'), findsOneWidget);

    await tester.tap(find.text('Đăng ký').first);
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('shows a clear notice when another phone replaces the session', (
    tester,
  ) async {
    const notice =
        'Tài khoản của bạn đã được đăng nhập trên một điện thoại khác. Phiên đăng nhập trên thiết bị này đã kết thúc.';

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          authService: AuthService(),
          onAuthenticated: (_) {},
          initialNotice: notice,
        ),
      ),
    );

    expect(find.text(notice), findsOneWidget);
  });
}
