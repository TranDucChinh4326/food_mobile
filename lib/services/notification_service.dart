import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service quản lý system notification (thông báo hệ thống Android)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ID counter cho mỗi loại thông báo
  static int _idCounter = 0;
  static int get _nextId => ++_idCounter;

  // Channel IDs
  static const _cartChannelId = 'bep1979_cart';
  static const _orderChannelId = 'bep1979_order';
  static const _generalChannelId = 'bep1979_general';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Tạo notification channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _cartChannelId,
          'Giỏ hàng',
          description: 'Thông báo khi thêm món vào giỏ hàng',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _orderChannelId,
          'Đơn hàng',
          description: 'Thông báo trạng thái đơn hàng',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          'Thông báo chung',
          description: 'Thông báo chung của ứng dụng Bếp 1979',
          importance: Importance.defaultImportance,
          playSound: false,
        ),
      );
    }

    _initialized = true;
  }

  /// Xin quyền thông báo (Android 13+)
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Kiểm tra đã có quyền chưa
  Future<bool> hasPermission() async {
    return Permission.notification.isGranted;
  }

  /// Thông báo thêm vào giỏ hàng
  Future<void> showAddedToCart(String foodName) async {
    await _show(
      id: _nextId,
      channelId: _cartChannelId,
      title: '🛒 Đã thêm vào giỏ hàng',
      body: foodName,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// Thông báo đặt hàng thành công
  Future<void> showOrderPlaced(String orderId) async {
    await _show(
      id: _nextId,
      channelId: _orderChannelId,
      title: '✅ Đặt hàng thành công!',
      body:
          'Đơn hàng #$orderId đang được chuẩn bị. Cảm ơn bạn đã tin tưởng Bếp 1979!',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// Thông báo cập nhật trạng thái đơn
  Future<void> showOrderStatusUpdate(String orderId, String status) async {
    await _show(
      id: _nextId,
      channelId: _orderChannelId,
      title: '📦 Cập nhật đơn hàng #$orderId',
      body: status,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// Thông báo lỗi
  Future<void> showError(String message) async {
    await _show(
      id: _nextId,
      channelId: _generalChannelId,
      title: '⚠️ Bếp 1979',
      body: message,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
  }

  /// Thông báo thành công chung
  Future<void> showSuccess(String title, String message) async {
    await _show(
      id: _nextId,
      channelId: _generalChannelId,
      title: title,
      body: message,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
  }

  /// Thông báo chung
  Future<void> showInfo(String title, String message) async {
    await _show(
      id: _nextId,
      channelId: _generalChannelId,
      title: title,
      body: message,
      importance: Importance.low,
      priority: Priority.low,
    );
  }

  Future<void> _show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required Importance importance,
    required Priority priority,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _cartChannelId
          ? 'Giỏ hàng'
          : channelId == _orderChannelId
          ? 'Đơn hàng'
          : 'Thông báo chung',
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFE65100),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Bỏ qua nếu không có quyền
    }
  }
}
