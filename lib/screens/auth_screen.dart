import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  // Password criteria trackers
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _hasSpecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);

  int get _passwordStrengthScore {
    if (_passwordController.text.isEmpty) return 0;
    var score = 0;
    if (_hasMinLength) score++;
    if (_hasLowercase && _hasUppercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecial) score++;
    return score;
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (_isRegister) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _loginController.dispose();
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _changeMode(bool register) {
    setState(() {
      _isRegister = register;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = _isRegister
          ? await widget.authService.register(
              fullname: _fullnameController.text,
              username: _usernameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await widget.authService.login(
              login: _loginController.text,
              password: _passwordController.text,
            );
      if (mounted) widget.onAuthenticated(session);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSocialNotice(String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đang kết nối cổng đăng nhập $provider...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _loginController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.orange),
            SizedBox(width: 8),
            Text(
              'Quên mật khẩu?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập email đã đăng ký để nhận liên kết khôi phục mật khẩu tài khoản Bếp 1979.',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email của bạn',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng kiểm tra email để đặt lại mật khẩu.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Gửi liên kết'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient and decor circles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFBF8),
                  Color(0xFFFBF4EC),
                  Color(0xFFF7ECE1),
                ],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4E2D19)
                              .withValues(alpha: 0.07),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBrandHeader(),
                          const SizedBox(height: 24),
                          _buildTabSelector(),
                          const SizedBox(height: 20),
                          _buildTitles(),
                          const SizedBox(height: 18),
                          _buildSocialGrid(),
                          const SizedBox(height: 16),
                          _buildDivider(),
                          const SizedBox(height: 16),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isRegister) ..._buildRegisterFields(),
                                if (!_isRegister) ..._buildLoginFields(),
                                _buildPasswordField(),
                                if (_isRegister) ...[
                                  const SizedBox(height: 12),
                                  _buildPasswordStrengthMeter(),
                                ],
                              ],
                            ),
                          ),
                          if (!_isRegister) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _submitting
                                    ? null
                                    : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: AppColors.orangeDark,
                                ),
                                child: const Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 18),
                          _buildSubmitButton(),
                          const SizedBox(height: 14),
                          _buildBottomSwitch(),
                          if (_isRegister) ...[
                            const SizedBox(height: 10),
                            _buildRegisterPerks(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6E40), AppColors.orange],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            '79',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bếp 1979',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'MÓN NGON MỖI NGÀY',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7ECE4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Đăng nhập',
              icon: Icons.login_rounded,
              selected: !_isRegister,
              onTap: _submitting ? null : () => _changeMode(false),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Đăng ký',
              icon: Icons.person_add_alt_1_rounded,
              selected: _isRegister,
              onTap: _submitting ? null : () => _changeMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isRegister ? 'TẠO TÀI KHOẢN MỚI' : 'CHÀO MỪNG BẠN QUAY LẠI',
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _isRegister ? 'Tạo tài khoản' : 'Chào mừng trở lại',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRegister
              ? 'Đăng ký để bắt đầu đặt món tại Bếp 1979.'
              : 'Đăng nhập để tiếp tục đặt món và theo dõi đơn hàng.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                iconColor: const Color(0xFFEA4335),
                symbol: 'G',
                label: 'Google',
                onPressed: () => _showSocialNotice('Google'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                iconColor: const Color(0xFF1877F2),
                symbol: 'f',
                label: 'Facebook',
                isSquare: true,
                onPressed: () => _showSocialNotice('Facebook'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _isRegister ? 'hoặc tạo bằng email' : 'hoặc dùng username/email',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
      ],
    );
  }

  List<Widget> _buildLoginFields() => [
    _buildFieldLabel('Username hoặc email'),
    const SizedBox(height: 6),
    TextFormField(
      controller: _loginController,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      decoration: InputDecoration(
        hintText: 'username hoặc you@example.com',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: const Icon(Icons.person_outline_rounded, size: 22),
      ),
      validator: (value) => (value?.trim().isEmpty ?? true)
          ? 'Vui lòng nhập username hoặc email.'
          : null,
    ),
    const SizedBox(height: 14),
  ];

  List<Widget> _buildRegisterFields() => [
    _buildFieldLabel('Họ và tên'),
    const SizedBox(height: 6),
    TextFormField(
      controller: _fullnameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'Nguyễn Văn A',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: const Icon(Icons.badge_outlined, size: 22),
      ),
      validator: (value) =>
          (value?.trim().length ?? 0) < 2 ? 'Vui lòng nhập họ và tên.' : null,
    ),
    const SizedBox(height: 14),
    _buildFieldLabel('Username'),
    const SizedBox(height: 6),
    TextFormField(
      controller: _usernameController,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'nguyenvana',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 22),
      ),
      validator: (value) =>
          RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(value?.trim() ?? '')
          ? null
          : 'Dùng 3-40 chữ, số, dấu chấm, gạch ngang hoặc gạch dưới.',
    ),
    const SizedBox(height: 14),
    _buildFieldLabel('Email'),
    const SizedBox(height: 6),
    TextFormField(
      controller: _emailController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: const Icon(Icons.mail_outline_rounded, size: 22),
      ),
      validator: (value) =>
          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '')
          ? null
          : 'Email không hợp lệ.',
    ),
    const SizedBox(height: 14),
  ];

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Mật khẩu'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitting ? null : _submit(),
          autofillHints: [
            _isRegister ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            hintText: _isRegister ? 'Tối thiểu 8 ký tự' : 'Nhập mật khẩu',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.muted,
                size: 21,
              ),
            ),
          ),
          validator: (value) {
            final password = value ?? '';
            if (!_isRegister) {
              return password.isEmpty ? 'Vui lòng nhập mật khẩu.' : null;
            }
            if (password.length < 8 ||
                !RegExp(r'[a-z]').hasMatch(password) ||
                !RegExp(r'[A-Z]').hasMatch(password) ||
                !RegExp(r'\d').hasMatch(password) ||
                !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
              return 'Mật khẩu chưa đáp ứng đủ yêu cầu bảo mật.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPasswordStrengthMeter() {
    final score = _passwordStrengthScore;
    final length = _passwordController.text.length;

    String statusText;
    Color statusColor;

    if (length == 0) {
      statusText = 'Chưa nhập';
      statusColor = AppColors.muted;
    } else if (score <= 1) {
      statusText = 'Yếu';
      statusColor = const Color(0xFFE53935);
    } else if (score == 2) {
      statusText = 'Trung bình';
      statusColor = AppColors.amber;
    } else if (score == 3) {
      statusText = 'Khá';
      statusColor = const Color(0xFF29B6F6);
    } else {
      statusText = 'Mạnh';
      statusColor = AppColors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Độ mạnh mật khẩu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (index) {
              final active = length > 0 && index < score;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? statusColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          _CriteriaRow(text: 'Tối thiểu 8 ký tự', met: _hasMinLength),
          _CriteriaRow(
            text: 'Chữ thường (a-z) và chữ hoa (A-Z)',
            met: _hasLowercase && _hasUppercase,
          ),
          _CriteriaRow(text: 'Chữ số (0-9)', met: _hasNumber),
          _CriteriaRow(text: 'Ký tự đặc biệt (!@#\$...)', met: _hasSpecial),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCCBD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.orangeDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.orangeDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6E40), AppColors.orange, AppColors.orangeDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _submitting ? null : _submit,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister ? 'Đăng ký' : 'Đăng nhập',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isRegister
                            ? Icons.arrow_forward_rounded
                            : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSwitch() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _isRegister ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
            style: const TextStyle(color: AppColors.muted, fontSize: 13.5),
          ),
          TextButton(
            onPressed: _submitting ? null : () => _changeMode(!_isRegister),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              _isRegister ? 'Đăng nhập' : 'Đăng ký ngay',
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterPerks() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.card_giftcard_rounded, color: AppColors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tặng voucher 30K cho đơn hàng đầu tiên sau khi đăng ký thành công!',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.orange : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? AppColors.ink : AppColors.muted,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.symbol,
    required this.label,
    required this.iconColor,
    required this.onPressed,
    this.isSquare = false,
  });

  final String symbol;
  final String label;
  final Color iconColor;
  final VoidCallback onPressed;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSquare ? iconColor : Colors.white,
              borderRadius: BorderRadius.circular(isSquare ? 4 : 12),
              border: isSquare ? null : Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                color: isSquare ? Colors.white : iconColor,
                fontSize: isSquare ? 15 : 14,
                fontWeight: FontWeight.w900,
                fontFamily: isSquare ? 'sans-serif' : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? AppColors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: met ? FontWeight.w600 : FontWeight.w500,
                color: met ? AppColors.green : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
