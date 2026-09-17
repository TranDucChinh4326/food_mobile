import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_image.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.onLogout,
    this.onSessionUpdated,
    this.onAddToCart,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<AuthSession>? onSessionUpdated;
  final ValueChanged<String>? onAddToCart;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  late TabController _tabController;
  int _currentTabIndex = 0;

  // Profile Form Controllers
  late TextEditingController _fullnameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _updatingProfile = false;

  // Addresses State
  List<UserAddress> _addresses = const [];
  bool _loadingAddresses = false;
  String? _addressError;

  // Vouchers State
  List<UserVoucher> _vouchers = const [];
  bool _loadingVouchers = false;
  String? _voucherError;

  // Favorites State
  List<FavoriteFoodItem> _favorites = const [];
  bool _loadingFavorites = false;
  String? _favoriteError;

  // Password Form State
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _captchaAnswerController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  PasswordCaptcha? _passwordCaptcha;
  bool _loadingCaptcha = false;
  int _captchaCooldownRemaining = 0;
  Timer? _captchaCooldownTimer;
  bool _changingPassword = false;

  // PIN Form State
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  bool _savingPin = false;

  // Social accounts
  List<SocialAccount> _socialAccounts = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
        _onTabChanged(_tabController.index);
      }
    });

    _initControllers(widget.session.user);
    _loadSocialAccounts();
    _loadAddresses();
  }

  void _initControllers(AuthUser user) {
    _fullnameController = TextEditingController(text: user.fullname);
    _usernameController = TextEditingController(text: user.username);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.user != widget.session.user) {
      final user = widget.session.user;
      _fullnameController.text = user.fullname;
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _captchaAnswerController.dispose();
    _captchaCooldownTimer?.cancel();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    switch (index) {
      case 1:
        if (_addresses.isEmpty && !_loadingAddresses) _loadAddresses();
        break;
      case 2:
        if (_vouchers.isEmpty && !_loadingVouchers) _loadVouchers();
        break;
      case 3:
        if (_favorites.isEmpty && !_loadingFavorites) _loadFavorites();
        break;
      case 4:
        if (_passwordCaptcha == null && !_loadingCaptcha) _loadCaptcha();
        break;
      default:
        break;
    }
  }

  // ==========================================
  // DATA LOADERS
  // ==========================================

  Future<void> _loadSocialAccounts() async {
    final accounts = await _authService.fetchSocialAccounts(
      widget.session.token,
    );
    if (mounted) setState(() => _socialAccounts = accounts);
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressError = null;
    });
    try {
      final list = await _authService.fetchAddresses(widget.session.token);
      if (mounted) setState(() => _addresses = list);
    } catch (e) {
      if (mounted) setState(() => _addressError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _loadingVouchers = true;
      _voucherError = null;
    });
    try {
      final list = await _authService.fetchVouchers(widget.session.token);
      if (mounted) setState(() => _vouchers = list);
    } catch (e) {
      if (mounted) setState(() => _voucherError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loadingFavorites = true;
      _favoriteError = null;
    });
    try {
      final list = await _authService.fetchFavoriteFoods(widget.session.token);
      if (mounted) setState(() => _favorites = list);
    } catch (e) {
      if (mounted) setState(() => _favoriteError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingFavorites = false);
    }
  }

  Future<void> _loadCaptcha() async {
    if (_captchaCooldownRemaining > 0) return;
    setState(() => _loadingCaptcha = true);
    try {
      final captcha = await _authService.fetchPasswordCaptcha(
        widget.session.token,
      );
      if (mounted) {
        setState(() {
          _passwordCaptcha = captcha;
          _captchaAnswerController.clear();
          _startCaptchaCooldown(captcha.cooldownSeconds);
        });
      }
    } catch (e) {
      if (mounted) _showToast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  void _startCaptchaCooldown(int seconds) {
    _captchaCooldownTimer?.cancel();
    setState(() => _captchaCooldownRemaining = seconds);
    _captchaCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_captchaCooldownRemaining <= 1) {
        timer.cancel();
        setState(() => _captchaCooldownRemaining = 0);
      } else {
        setState(() => _captchaCooldownRemaining--);
      }
    });
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================

  Future<void> _handleSaveProfile() async {
    final fullname = _fullnameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullname.isEmpty || username.isEmpty || email.isEmpty) {
      _showToast('Vui lòng điền họ tên, username và email.', isError: true);
      return;
    }

    setState(() => _updatingProfile = true);
    try {
      final updatedUser = await _authService.updateProfile(
        widget.session.token,
        username: username,
        fullname: fullname,
        email: email,
        phone: phone,
      );
      final newSession = widget.session.copyWith(user: updatedUser);
      widget.onSessionUpdated?.call(newSession);
      _showToast('Cập nhật thông tin thành công! 🎉');
    } catch (e) {
      _showToast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _updatingProfile = false);
    }
  }

  Future<void> _handleChangePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final captchaAnswer = _captchaAnswerController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showToast('Vui lòng nhập mật khẩu mới.', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showToast('Mật khẩu mới nhập lại không khớp.', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showToast('Mật khẩu mới tối thiểu 6 ký tự.', isError: true);
      return;
    }
    if (_passwordCaptcha == null) {
      _showToast('Vui lòng bấm "Xin mã" captcha trước.', isError: true);
      return;
    }
    if (captchaAnswer.isEmpty) {
      _showToast('Vui lòng nhập mã captcha.', isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final msg = await _authService.changePassword(
        widget.session.token,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
        captchaAnswer: captchaAnswer,
        captchaId: _passwordCaptcha!.id,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _captchaAnswerController.clear();
      _passwordCaptcha = null;
      _showToast(msg);
      _loadCaptcha();
    } catch (e) {
      _showToast(e.toString(), isError: true);
      _loadCaptcha();
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _handleSavePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
      _showToast('Mã PIN phải gồm đúng 6 chữ số.', isError: true);
      return;
    }
    if (newPin != confirmPin) {
      _showToast('Mã PIN xác nhận không khớp.', isError: true);
      return;
    }
    if (widget.session.user.hasPin && currentPin.isEmpty) {
      _showToast('Vui lòng nhập mã PIN hiện tại.', isError: true);
      return;
    }

    setState(() => _savingPin = true);
    try {
      final updatedUser = await _authService.savePin(
        widget.session.token,
        currentPin: currentPin,
        newPin: newPin,
        confirmPin: confirmPin,
      );
      final newSession = widget.session.copyWith(user: updatedUser);
      widget.onSessionUpdated?.call(newSession);
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      _showToast('Đã lưu mã PIN bảo vệ thành công! 🔐');
    } catch (e) {
      _showToast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _savingPin = false);
    }
  }

  Future<void> _handleRemoveFavorite(FavoriteFoodItem item) async {
    try {
      await _authService.removeFavoriteFood(widget.session.token, item.id);
      setState(() {
        _favorites = _favorites.where((f) => f.id != item.id).toList();
      });
      _showToast('Đã xóa món khỏi danh sách yêu thích.');
    } catch (e) {
      _showToast(e.toString(), isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (isError) {
      NotificationService.instance.showError(message);
    } else {
      NotificationService.instance.showSuccess('Bếp 1979', message);
    }
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      _showToast('Đang tải ảnh đại diện lên...');
      final bytes = await pickedFile.readAsBytes();
      final updated = await _authService.uploadAvatarBytes(
        widget.session.token,
        bytes,
        pickedFile.name,
      );
      widget.onSessionUpdated?.call(widget.session.copyWith(user: updated));
      _showToast('Cập nhật ảnh đại diện thành công! ✨');
    } catch (e) {
      final err = e.toString();
      if (err.contains('MissingPluginException')) {
        _showToast(
          'Vui lòng khởi động lại app ("q" rồi "flutter run") để cấp quyền ảnh.',
          isError: true,
        );
      } else {
        _showToast(err.replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  void _showAvatarChoiceModal() {
    final presets = [
      (
        'assets/images/avatars/chef-boy.svg',
        'Đầu bếp Nam',
        '👨‍🍳',
        const Color(0xFFFFECE5),
      ),
      (
        'assets/images/avatars/chef-girl.svg',
        'Đầu bếp Nữ',
        '👩‍🍳',
        const Color(0xFFFFF0F5),
      ),
      (
        'assets/images/avatars/burger-buddy.svg',
        'Bé Burger',
        '🍔',
        const Color(0xFFFFF8E7),
      ),
      (
        'assets/images/avatars/boba-cat.svg',
        'Bé Trà Sữa',
        '🧋',
        const Color(0xFFF0F8FF),
      ),
      (
        'assets/images/avatars/pizza-slice.svg',
        'Bé Pizza',
        '🍕',
        const Color(0xFFFFEFEF),
      ),
      (
        'assets/images/avatars/ramen-bowl.svg',
        'Bé Mì Ramen',
        '🍜',
        const Color(0xFFF5FFF0),
      ),
    ];

    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đổi ảnh đại diện',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chụp ảnh trực tiếp hoặc chọn ảnh từ thư viện thiết bị:',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        _pickAndUploadImage(ImageSource.camera);
                      },
                      icon: const Icon(
                        Icons.photo_camera_rounded,
                        color: AppColors.orange,
                        size: 20,
                      ),
                      label: const Text(
                        'Chụp ảnh',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFFCCBC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFFFFF8F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        _pickAndUploadImage(ImageSource.gallery);
                      },
                      icon: const Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.orange,
                        size: 20,
                      ),
                      label: const Text(
                        'Thư viện ảnh',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFFCCBC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFFFFF8F6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '🎨 Hoặc chọn avatar Bếp 1979:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final item = presets[index];
                  final isSelected =
                      widget.session.user.rawAvatar?.contains(item.$1) == true;
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(modalContext);
                      try {
                        final updated = await _authService.updatePresetAvatar(
                          widget.session.token,
                          item.$1,
                        );
                        widget.onSessionUpdated?.call(
                          widget.session.copyWith(user: updated),
                        );
                        _showToast('Đã chọn ${item.$2}! ✨');
                      } catch (e) {
                        _showToast(e.toString(), isError: true);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.$4,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.orange
                              : Colors.grey.shade200,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.$3, style: const TextStyle(fontSize: 36)),
                          const SizedBox(height: 6),
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.orangeDark
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '🔗 Nhập URL ảnh đại diện:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/avatar.jpg',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final url = urlController.text.trim();
                      if (url.isEmpty) return;
                      Navigator.pop(modalContext);
                      try {
                        final updated = await _authService.updatePresetAvatar(
                          widget.session.token,
                          url,
                        );
                        widget.onSessionUpdated?.call(
                          widget.session.copyWith(user: updated),
                        );
                        _showToast('Đã cập nhật ảnh đại diện mới!');
                      } catch (e) {
                        _showToast(e.toString(), isError: true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarLightbox() {
    final user = widget.session.user;
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: _buildAvatarImage(user, size: 260, fontSize: 80),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Đóng'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showAvatarChoiceModal();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Đổi ảnh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở màn hình quét QR live bằng camera
  Future<void> _openCameraScanner(
    Future<void> Function(String scannedValue) onDetected,
  ) async {
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
    bool handled = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text(
              'Quét mã QR Web',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.flash_on, color: Colors.white),
                onPressed: () => controller.toggleTorch(),
              ),
            ],
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (handled) return;
                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;
                  final raw = barcodes.first.rawValue ?? '';
                  if (raw.isEmpty) return;
                  handled = true;
                  controller.stop();
                  Navigator.of(ctx).pop();
                  onDetected(raw);
                },
              ),
              // Khung ngắm QR
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Căn giữa mã QR vào khung cam',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  void _showWebLoginQrModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final codeController = TextEditingController();
        String currentStep = 'input'; // 'input' | 'confirm' | 'success'
        bool isSubmitting = false;
        String? errorMessage;
        String? targetSessionId;
        String? targetShortCode;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitScan(String rawCode) async {
              final code = rawCode.trim();
              if (code.isEmpty) return;

              setModalState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                final res = await _authService.scanQrSession(
                  widget.session.token,
                  code,
                );

                if (res['success'] == true) {
                  setModalState(() {
                    isSubmitting = false;
                    currentStep = 'confirm';
                    targetSessionId = res['sessionId']?.toString();
                    targetShortCode = res['shortCode']?.toString();
                  });
                } else {
                  setModalState(() {
                    isSubmitting = false;
                    errorMessage =
                        res['message']?.toString() ??
                        'Mã QR không hợp lệ hoặc đã hết hạn.';
                  });
                }
              } catch (e) {
                setModalState(() {
                  isSubmitting = false;
                  errorMessage = e.toString().replaceAll('Exception: ', '');
                });
              }
            }

            Future<void> scanWithCamera() async {
              try {
                await _openCameraScanner((scannedValue) async {
                  // QR đã được decode trên thiết bị → gửi lên backend để tìm session
                  setModalState(() {
                    isSubmitting = true;
                    errorMessage = null;
                  });
                  try {
                    final res = await _authService.scanQrSession(
                      widget.session.token,
                      scannedValue,
                    );
                    if (res['success'] == true) {
                      setModalState(() {
                        isSubmitting = false;
                        currentStep = 'confirm';
                        targetSessionId = res['sessionId']?.toString();
                        targetShortCode = res['shortCode']?.toString();
                      });
                    } else {
                      setModalState(() {
                        isSubmitting = false;
                        errorMessage = res['message']?.toString() ?? 'Không tìm thấy phiên đăng nhập. Mã QR có thể đã hết hạn.';
                      });
                    }
                  } catch (e) {
                    setModalState(() {
                      isSubmitting = false;
                      errorMessage = e.toString().replaceAll('Exception: ', '');
                    });
                  }
                });
              } catch (e) {
                setModalState(() {
                  isSubmitting = false;
                  errorMessage =
                      'Không thể mở camera: ${e.toString().replaceAll('Exception: ', '')}';
                });
              }
            }

            Future<void> confirmLogin() async {
              final codeToConfirm = targetSessionId ?? targetShortCode;
              if (codeToConfirm == null) return;

              setModalState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                final res = await _authService.confirmQrSession(
                  widget.session.token,
                  codeToConfirm,
                );

                if (res['success'] == true) {
                  setModalState(() {
                    isSubmitting = false;
                    currentStep = 'success';
                  });

                  Future.delayed(const Duration(milliseconds: 1800), () {
                    if (modalCtx.mounted) {
                      Navigator.of(modalCtx).pop();
                      _showToast('Đăng nhập Website thành công! 🎉');
                    }
                  });
                } else {
                  setModalState(() {
                    isSubmitting = false;
                    errorMessage =
                        res['message']?.toString() ??
                        'Không thể xác nhận đăng nhập.';
                  });
                }
              } catch (e) {
                setModalState(() {
                  isSubmitting = false;
                  errorMessage = e.toString().replaceAll('Exception: ', '');
                });
              }
            }

            Future<void> rejectLogin() async {
              final codeToReject = targetSessionId ?? targetShortCode;
              if (codeToReject != null) {
                try {
                  await _authService.rejectQrSession(
                    widget.session.token,
                    codeToReject,
                  );
                } catch (_) {}
              }
              if (modalCtx.mounted) {
                Navigator.of(modalCtx).pop();
                _showToast('Đã từ chối đăng nhập Website.');
              }
            }

            final user = widget.session.user;

            return Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom +
                      20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đăng nhập Website bằng mã QR',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Bếp 1979 · Quét camera hoặc nhập mã 6 số',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.muted,
                            ),
                            onPressed: () => Navigator.of(modalCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.line),
                      const SizedBox(height: 18),

                      // STEP 1: CAMERA SCAN & INPUT CODE
                      if (currentStep == 'input') ...[
                        // Option A: Camera QR Scan
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF9F5), Color(0xFFFFF3EC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.orange.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppColors.orange,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Quét mã QR trên màn hình Web',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hướng camera vào mã QR đang hiển thị trên trang đăng nhập máy tính',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : scanWithCamera,
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 20,
                                        ),
                                  label: const Text(
                                    'Mở Camera quét mã QR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'HOẶC NHẬP MÃ 6 CHỮ SỐ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Option B: 6-digit Code Input
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Mã 6 số hiển thị ngay dưới mã QR trên Web:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: codeController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                  color: AppColors.orange,
                                ),
                                decoration: InputDecoration(
                                  hintText: '123456',
                                  hintStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 8,
                                    color: Colors.grey.shade300,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFFAFAFA),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.orange,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (val) => submitScan(val),
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 16,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: FilledButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => submitScan(codeController.text),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.ink,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Kiểm tra & Xác nhận đăng nhập',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF3E8E2)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: AppColors.orange,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Cách đăng nhập:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                '1. Mở trang web Bếp 1979 trên máy tính > bấm tab "Quét mã QR".\n'
                                '2. Nhập mã số 6 chữ số hiển thị ở bên dưới mã QR vào ô trên.\n'
                                '3. Nhấn "Xác nhận đăng nhập" để vào web ngay lập tức.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF6B584F),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // STEP 2: CONFIRMATION
                      if (currentStep == 'confirm') ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4EE),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.orange.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.devices_rounded,
                                  color: AppColors.orange,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Xác nhận đăng nhập Web?',
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Yêu cầu đăng nhập vào trang web Bếp 1979',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Tài khoản:',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        Text(
                                          user.fullname,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Email:',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        Text(
                                          user.email,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Thiết bị:',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        Text(
                                          'Website Bếp 1979',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : rejectLogin,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(
                                          color: Colors.red.shade200,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                      ),
                                      child: const Text(
                                        'Từ chối',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : confirmLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.orange,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                      ),
                                      child: isSubmitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Xác nhận đăng nhập',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // STEP 3: SUCCESS
                      if (currentStep == 'success') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Đăng nhập thành công! 🎉',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Trang web Bếp 1979 của bạn đã được đăng nhập tự động.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddressDialog({UserAddress? existing}) {
    final isEdit = existing != null;
    final labelCtrl = TextEditingController(
      text: existing?.label ?? 'Nhà riêng',
    );
    final receiverCtrl = TextEditingController(
      text: existing?.receiverName ?? widget.session.user.fullname,
    );
    final phoneCtrl = TextEditingController(
      text: existing?.phone ?? widget.session.user.phone,
    );
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    bool isDefault = existing?.isDefault ?? (_addresses.isEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ giao hàng',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên địa chỉ (Nhà riêng, công ty...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receiverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên người nhận',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ cụ thể (Số nhà, đường, phường/xã...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDefault,
                  onChanged: (val) =>
                      setModalState(() => isDefault = val ?? false),
                  title: const Text(
                    'Đặt làm địa chỉ mặc định',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final addrText = addressCtrl.text.trim();
                    if (addrText.isEmpty) {
                      _showToast(
                        'Vui lòng nhập địa chỉ cụ thể.',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.pop(bottomSheetContext);
                    try {
                      if (isEdit) {
                        await _authService.updateAddress(
                          widget.session.token,
                          existing.id,
                          label: labelCtrl.text.trim(),
                          receiverName: receiverCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addrText,
                          isDefault: isDefault,
                        );
                        _showToast('Đã cập nhật địa chỉ giao hàng!');
                      } else {
                        await _authService.createAddress(
                          widget.session.token,
                          label: labelCtrl.text.trim(),
                          receiverName: receiverCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addrText,
                          isDefault: isDefault,
                        );
                        _showToast('Đã thêm địa chỉ giao hàng mới!');
                      }
                      _loadAddresses();
                    } catch (e) {
                      _showToast(e.toString(), isError: true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEdit ? 'Lưu thay đổi' : 'Thêm địa chỉ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa địa chỉ?'),
        content: Text(
          'Bạn có chắc muốn xóa "${address.label} - ${address.address}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteAddress(widget.session.token, address.id);
        _showToast('Đã xóa địa chỉ thành công.');
        _loadAddresses();
      } catch (e) {
        _showToast(e.toString(), isError: true);
      }
    }
  }

  // ==========================================
  // MAIN BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSummaryCard(user),
          const SizedBox(height: 16),
          _buildTabHeader(),
          const SizedBox(height: 16),
          _buildActiveTabContent(user),
          const SizedBox(height: 32),
          _buildLogoutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // SUMMARY CARD WIDGET
  // ==========================================

  Widget _buildSummaryCard(AuthUser user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange.withValues(alpha: 0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _showAvatarLightbox,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(user, size: 72, fontSize: 26),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _showAvatarChoiceModal,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          _buildSocialAccountsRow(),
          const SizedBox(height: 14),
          InkWell(
            onTap: _showWebLoginQrModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4EE), Color(0xFFFFECE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đăng nhập Website bằng mã QR',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Quét hoặc nhập mã số để đăng nhập nhanh trên máy tính',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.orange,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(
    AuthUser user, {
    required double size,
    required double fontSize,
  }) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: AppImage(
          source: user.avatar!,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          errorBuilder: (_, _, _) => _buildAvatarFallback(user, fontSize),
        ),
      );
    }
    // Preset avatar emoji mapping
    final raw = user.rawAvatar?.toLowerCase() ?? '';
    if (raw.contains('chef-boy')) {
      return _buildEmojiAvatar('👨‍🍳', const Color(0xFFFFECE5), fontSize);
    } else if (raw.contains('chef-girl')) {
      return _buildEmojiAvatar('👩‍🍳', const Color(0xFFFFF0F5), fontSize);
    } else if (raw.contains('burger-buddy')) {
      return _buildEmojiAvatar('🍔', const Color(0xFFFFF8E7), fontSize);
    } else if (raw.contains('boba-cat')) {
      return _buildEmojiAvatar('🧋', const Color(0xFFF0F8FF), fontSize);
    } else if (raw.contains('pizza-slice')) {
      return _buildEmojiAvatar('🍕', const Color(0xFFFFEFEF), fontSize);
    } else if (raw.contains('ramen-bowl')) {
      return _buildEmojiAvatar('🍜', const Color(0xFFF5FFF0), fontSize);
    }
    return _buildAvatarFallback(user, fontSize);
  }

  Widget _buildEmojiAvatar(String emoji, Color bg, double fontSize) {
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: fontSize)),
    );
  }

  Widget _buildAvatarFallback(AuthUser user, double fontSize) {
    final initials = user.fullname.isNotEmpty
        ? user.fullname[0].toUpperCase()
        : (user.username.isNotEmpty ? user.username[0].toUpperCase() : 'B');
    return Container(
      color: AppColors.orange.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.orange,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildSocialAccountsRow() {
    final googleAccount = _socialAccounts.firstWhere(
      (a) => a.provider == 'google',
      orElse: () => const SocialAccount(provider: 'google', providerEmail: ''),
    );
    final isGoogleLinked = googleAccount.providerEmail.isNotEmpty;

    final fbAccount = _socialAccounts.firstWhere(
      (a) => a.provider == 'facebook',
      orElse: () =>
          const SocialAccount(provider: 'facebook', providerEmail: ''),
    );
    final isFbLinked = fbAccount.providerEmail.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _buildSocialPill(
            name: 'Google',
            icon: Icons.g_mobiledata,
            isLinked: isGoogleLinked,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSocialPill(
            name: 'Facebook',
            icon: Icons.facebook,
            isLinked: isFbLinked,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialPill({
    required String name,
    required IconData icon,
    required bool isLinked,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isLinked ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLinked ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: isLinked ? Colors.green.shade700 : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isLinked ? '$name (Đã nối)' : '$name (Chưa nối)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isLinked ? Colors.green.shade800 : AppColors.muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB HEADER SELECTOR
  // ==========================================

  Widget _buildTabHeader() {
    final tabs = [
      ('Hồ sơ', Icons.person_outline),
      ('Địa chỉ', Icons.location_on_outlined),
      ('Voucher', Icons.confirmation_num_outlined),
      ('Yêu thích', Icons.favorite_border),
      ('Đổi MK', Icons.lock_outline),
      ('Mã PIN', Icons.pin_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _currentTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                tab.$2,
                size: 16,
                color: isSelected ? Colors.white : AppColors.muted,
              ),
              label: Text(tab.$1),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _currentTabIndex = index);
                  _tabController.animateTo(index);
                  _onTabChanged(index);
                }
              },
              selectedColor: AppColors.orange,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.orange : Colors.grey.shade200,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // ACTIVE TAB CONTENT ROUTER
  // ==========================================

  Widget _buildActiveTabContent(AuthUser user) {
    switch (_currentTabIndex) {
      case 0:
        return _buildProfileTab(user);
      case 1:
        return _buildAddressesTab();
      case 2:
        return _buildVouchersTab();
      case 3:
        return _buildFavoritesTab();
      case 4:
        return _buildPasswordTab();
      case 5:
        return _buildPinTab(user);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // TAB 1: THÔNG TIN CÁ NHÂN (PROFILE)
  // ==========================================

  Widget _buildProfileTab(AuthUser user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin tài khoản',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cập nhật họ tên, username, email và số điện thoại.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _fullnameController,
            label: 'Họ và tên',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _phoneController,
            label: 'Số điện thoại',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _buildEmailVerifyStatus(user),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _updatingProfile ? null : _handleSaveProfile,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _updatingProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Lưu thông tin',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailVerifyStatus(AuthUser user) {
    final isVerified = user.emailVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? Colors.green.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 20,
            color: isVerified ? Colors.green.shade700 : Colors.amber.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isVerified ? 'Email đã được xác thực an toàn.' : 'Email chưa xác thực. Hãy kiểm tra hộp thư để kích hoạt tài khoản.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isVerified
                    ? Colors.green.shade900
                    : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ĐỊA CHỈ ĐÃ LƯU (ADDRESSES)
  // ==========================================

  Widget _buildAddressesTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sổ địa chỉ giao hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chọn địa chỉ mặc định khi đặt món.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddressDialog(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                  foregroundColor: AppColors.orangeDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Thêm mới',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_addressError != null)
            _buildErrorState(_addressError!, _loadAddresses)
          else if (_addresses.isEmpty)
            _buildEmptyState(
              icon: Icons.location_off_outlined,
              message: 'Chưa có địa chỉ giao hàng nào.',
              actionLabel: 'Thêm địa chỉ ngay',
              onAction: () => _showAddressDialog(),
            )
          else
            ..._addresses.map((address) => _buildAddressCard(address)),
        ],
      ),
    );
  }

  Widget _buildAddressCard(UserAddress address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: address.isDefault
            ? AppColors.orange.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isDefault
              ? AppColors.orange.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: address.isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                address.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MẶC ĐỊNH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.muted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showAddressDialog(existing: address),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteAddress(address),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${address.receiverName} - ${address.phone}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            address.address,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: VOUCHER CỦA TÔI (VOUCHERS)
  // ==========================================

  Widget _buildVouchersTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voucher của tôi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Danh sách mã ưu đãi còn hiệu lực trong tài khoản.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_loadingVouchers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_voucherError != null)
            _buildErrorState(_voucherError!, _loadVouchers)
          else if (_vouchers.isEmpty)
            _buildEmptyState(
              icon: Icons.confirmation_num_outlined,
              message: 'Bạn chưa có voucher nào.',
              actionLabel: 'Làm mới',
              onAction: _loadVouchers,
            )
          else
            ..._vouchers.map((voucher) => _buildVoucherTicketCard(voucher)),
        ],
      ),
    );
  }

  Widget _buildVoucherTicketCard(UserVoucher voucher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(13)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_activity_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  voucher.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    voucher.discountDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.orangeDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Còn ${voucher.remaining} lượt',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (voucher.expiresAt != null)
                        Text(
                          'Hạn: ${voucher.expiresAt!.day}/${voucher.expiresAt!.month}/${voucher.expiresAt!.year}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: MÓN YÊU THÍCH (FAVORITES)
  // ==========================================

  Widget _buildFavoritesTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Món ăn yêu thích',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Các món bạn đã bấm thích để dễ dàng đặt lại.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_loadingFavorites)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_favoriteError != null)
            _buildErrorState(_favoriteError!, _loadFavorites)
          else if (_favorites.isEmpty)
            _buildEmptyState(
              icon: Icons.favorite_border,
              message: 'Bạn chưa lưu món yêu thích nào.',
              actionLabel: 'Làm mới',
              onAction: _loadFavorites,
            )
          else
            ..._favorites.map((food) => _buildFavoriteFoodCard(food)),
        ],
      ),
    );
  }

  Widget _buildFavoriteFoodCard(FavoriteFoodItem food) {
    final priceStr = food.price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: food.image != null
                  ? AppImage(
                      source: food.image!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                      errorBuilder: (_, _, _) =>
                          _buildFoodPlaceholder(food.name),
                    )
                  : _buildFoodPlaceholder(food.name),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    food.categoryDisplayName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$priceStrđ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      food.stockQuantity > 0
                          ? 'Còn ${food.stockQuantity} phần'
                          : 'Hết hàng',
                      style: TextStyle(
                        fontSize: 11,
                        color: food.stockQuantity > 0
                            ? Colors.green.shade700
                            : Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        size: 20,
                        color: Colors.red,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Bỏ lưu',
                      onPressed: () => _handleRemoveFavorite(food),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: food.stockQuantity > 0
                          ? () => widget.onAddToCart?.call(food.name)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Thêm giỏ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodPlaceholder(String name) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood_outlined, color: AppColors.muted),
    );
  }

  // ==========================================
  // TAB 5: ĐỔI MẬT KHẨU (PASSWORD)
  // ==========================================

  Widget _buildPasswordTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đổi mật khẩu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Nhập mật khẩu hiện tại và mã captcha để đổi mật khẩu mới.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _currentPasswordController,
            label: 'Mật khẩu hiện tại',
            obscure: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: _newPasswordController,
            label: 'Mật khẩu mới (tối thiểu 6 ký tự)',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Nhập lại mật khẩu mới',
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          const SizedBox(height: 16),
          _buildCaptchaSection(),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _captchaAnswerController,
            label: 'Nhập mã captcha',
            icon: Icons.security_outlined,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _changingPassword ? null : _handleChangePassword,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _changingPassword
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Đổi mật khẩu',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptchaSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: _loadingCaptcha
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _passwordCaptcha != null
                ? Text(
                    _passwordCaptcha!.code.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                      color: AppColors.orangeDark,
                    ),
                  )
                : const Text(
                    'Bấm "Xin mã"',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: (_captchaCooldownRemaining > 0 || _loadingCaptcha)
              ? null
              : _loadCaptcha,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: AppColors.orangeDark,
            side: const BorderSide(color: AppColors.orange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(
            _captchaCooldownRemaining > 0
                ? '${_captchaCooldownRemaining}s'
                : 'Xin mã',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 6: MÃ PIN BẢO VỆ (PIN)
  // ==========================================

  Widget _buildPinTab(AuthUser user) {
    final hasPin = user.hasPin;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã PIN bảo vệ phiên',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Dùng để khóa và mở tài khoản nhanh.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: hasPin ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPin
                        ? Colors.green.shade300
                        : Colors.amber.shade300,
                  ),
                ),
                child: Text(
                  hasPin ? 'Đã bật PIN' : 'Chưa tạo PIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasPin
                        ? Colors.green.shade800
                        : Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasPin) ...[
            _buildPinField(
              controller: _currentPinController,
              label: 'Mã PIN hiện tại (6 số)',
              obscure: _obscureCurrentPin,
              onToggle: () =>
                  setState(() => _obscureCurrentPin = !_obscureCurrentPin),
            ),
            const SizedBox(height: 14),
          ],
          _buildPinField(
            controller: _newPinController,
            label: 'Mã PIN mới (6 chữ số)',
            obscure: _obscureNewPin,
            onToggle: () => setState(() => _obscureNewPin = !_obscureNewPin),
          ),
          const SizedBox(height: 14),
          _buildPinField(
            controller: _confirmPinController,
            label: 'Nhập lại mã PIN mới',
            obscure: _obscureConfirmPin,
            onToggle: () =>
                setState(() => _obscureConfirmPin = !_obscureConfirmPin),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _savingPin ? null : _handleSavePin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _savingPin
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    hasPin ? 'Đổi mã PIN' : 'Tạo mã PIN',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED FORM HELPERS
  // ==========================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: AppColors.muted,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.muted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(
          Icons.pin_outlined,
          color: AppColors.muted,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.muted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LOGOUT BUTTON
  // ==========================================

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: () => _confirmLogout(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.logout),
      label: const Text(
        'Đăng xuất tài khoản',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục đặt món.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (accepted == true) await widget.onLogout();
  }
}
