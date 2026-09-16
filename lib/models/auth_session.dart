import '../core/image_url.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.role,
    this.avatar,
    this.rawAvatar,
    this.phone = '',
    this.address = '',
    this.emailVerified = false,
    this.passwordSet = false,
    this.hasPin = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawAvatarVal = json['avatar']?.toString();
    return AuthUser(
      id: int.tryParse('${json['id']}') ?? 0,
      username: '${json['username'] ?? ''}',
      fullname: '${json['fullname'] ?? json['username'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? 'USER'}',
      avatar: normalizeRasterImageUrl(rawAvatarVal),
      rawAvatar: rawAvatarVal,
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      emailVerified:
          '${json['emailVerified'] ?? json['email_verified']}' == '1' ||
          json['emailVerified'] == true,
      passwordSet:
          '${json['passwordSet'] ?? json['password_set']}' == '1' ||
          json['passwordSet'] == true,
      hasPin:
          '${json['hasPin'] ?? json['has_pin']}' == '1' ||
          json['hasPin'] == true,
    );
  }

  final int id;
  final String username;
  final String fullname;
  final String email;
  final String role;
  final String? avatar;
  final String? rawAvatar;
  final String phone;
  final String address;
  final bool emailVerified;
  final bool passwordSet;
  final bool hasPin;

  AuthUser copyWith({
    int? id,
    String? username,
    String? fullname,
    String? email,
    String? role,
    String? avatar,
    String? rawAvatar,
    String? phone,
    String? address,
    bool? emailVerified,
    bool? passwordSet,
    bool? hasPin,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      rawAvatar: rawAvatar ?? this.rawAvatar,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      emailVerified: emailVerified ?? this.emailVerified,
      passwordSet: passwordSet ?? this.passwordSet,
      hasPin: hasPin ?? this.hasPin,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;

  AuthSession copyWith({String? token, AuthUser? user}) {
    return AuthSession(token: token ?? this.token, user: user ?? this.user);
  }
}

class UserAddress {
  const UserAddress({
    required this.id,
    required this.label,
    required this.receiverName,
    required this.phone,
    required this.address,
    required this.isDefault,
    this.createdAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: int.tryParse('${json['id']}') ?? 0,
      label: '${json['label'] ?? 'Địa chỉ giao hàng'}',
      receiverName: '${json['receiverName'] ?? json['receiver_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      isDefault:
          '${json['isDefault'] ?? json['is_default']}' == '1' ||
          json['isDefault'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  final int id;
  final String label;
  final String receiverName;
  final String phone;
  final String address;
  final bool isDefault;
  final DateTime? createdAt;
}

class UserVoucher {
  const UserVoucher({
    required this.userDiscountId,
    required this.quantity,
    required this.usedCount,
    required this.remaining,
    required this.code,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.applyTo,
    required this.minOrder,
    required this.maxDiscount,
    this.expiresAt,
  });

  factory UserVoucher.fromJson(Map<String, dynamic> json) {
    final discount = json['discount'] is Map<String, dynamic>
        ? json['discount'] as Map<String, dynamic>
        : json;

    return UserVoucher(
      userDiscountId:
          int.tryParse(
            '${json['userDiscountId'] ?? json['user_discount_id']}',
          ) ??
          0,
      quantity: int.tryParse('${json['quantity']}') ?? 1,
      usedCount:
          int.tryParse('${json['usedCount'] ?? json['user_used_count']}') ?? 0,
      remaining: int.tryParse('${json['remaining']}') ?? 1,
      code: '${discount['code'] ?? ''}',
      name: '${discount['name'] ?? discount['code'] ?? 'Voucher'}',
      discountType:
          '${discount['discountType'] ?? discount['discount_type'] ?? 'fixed'}',
      discountValue:
          num.tryParse(
            '${discount['discountValue'] ?? discount['discount_value']}',
          ) ??
          0,
      applyTo: '${discount['applyTo'] ?? discount['apply_to'] ?? 'order'}',
      minOrder:
          num.tryParse('${discount['minOrder'] ?? discount['min_order']}') ?? 0,
      maxDiscount:
          num.tryParse(
            '${discount['maxDiscount'] ?? discount['max_discount']}',
          ) ??
          0,
      expiresAt: discount['expiresAt'] != null || discount['expires_at'] != null
          ? DateTime.tryParse(
              '${discount['expiresAt'] ?? discount['expires_at']}',
            )
          : null,
    );
  }

  final int userDiscountId;
  final int quantity;
  final int usedCount;
  final int remaining;
  final String code;
  final String name;
  final String discountType;
  final num discountValue;
  final String applyTo;
  final num minOrder;
  final num maxDiscount;
  final DateTime? expiresAt;

  String get discountDescription {
    final applyText = applyTo == 'shipping' ? 'Phí giao hàng' : 'Đơn hàng';
    String valueText;
    if (discountType == 'free_shipping') {
      valueText = 'Miễn phí ship';
    } else if (discountType == 'percent') {
      valueText = 'Giảm ${discountValue.toInt()}%';
    } else {
      valueText =
          'Giảm ${discountValue.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
    }
    final minText = minOrder > 0
        ? ' từ ${minOrder.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ'
        : ' không yêu cầu đơn tối thiểu';
    return '$valueText cho $applyText,$minText';
  }
}

class FavoriteFoodItem {
  const FavoriteFoodItem({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    required this.desc,
    this.image,
    this.categoryName = '',
    this.category = '',
    this.parentCategoryName = '',
    this.soldCount = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.favoritedAt,
  });

  factory FavoriteFoodItem.fromJson(Map<String, dynamic> json) {
    return FavoriteFoodItem(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      price: num.tryParse('${json['price']}') ?? 0,
      stockQuantity:
          int.tryParse('${json['stockQuantity'] ?? json['stock_quantity']}') ??
          0,
      desc: '${json['desc'] ?? json['description'] ?? ''}',
      image: normalizeRasterImageUrl(json['image']),
      categoryName: '${json['categoryName'] ?? json['category_name'] ?? ''}',
      category: '${json['category'] ?? json['category_slug'] ?? ''}',
      parentCategoryName:
          '${json['parentCategoryName'] ?? json['parent_category_name'] ?? ''}',
      soldCount:
          int.tryParse('${json['soldCount'] ?? json['sold_count']}') ?? 0,
      rating: double.tryParse('${json['rating']}') ?? 0.0,
      reviewCount:
          int.tryParse('${json['reviewCount'] ?? json['review_count']}') ?? 0,
      favoritedAt: json['favoritedAt'] != null || json['created_at'] != null
          ? DateTime.tryParse('${json['favoritedAt'] ?? json['created_at']}')
          : null,
    );
  }

  final int id;
  final String name;
  final num price;
  final int stockQuantity;
  final String desc;
  final String? image;
  final String categoryName;
  final String category;
  final String parentCategoryName;
  final int soldCount;
  final double rating;
  final int reviewCount;
  final DateTime? favoritedAt;

  String get categoryDisplayName => categoryName.isNotEmpty
      ? categoryName
      : (parentCategoryName.isNotEmpty ? parentCategoryName : 'Món ăn');
}

class PasswordCaptcha {
  const PasswordCaptcha({
    required this.id,
    required this.code,
    required this.expiresInSeconds,
    required this.cooldownSeconds,
  });

  factory PasswordCaptcha.fromJson(Map<String, dynamic> json) {
    return PasswordCaptcha(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      expiresInSeconds: int.tryParse('${json['expiresInSeconds']}') ?? 300,
      cooldownSeconds: int.tryParse('${json['cooldownSeconds']}') ?? 60,
    );
  }

  final String id;
  final String code;
  final int expiresInSeconds;
  final int cooldownSeconds;
}

class SocialAccount {
  const SocialAccount({
    required this.provider,
    required this.providerEmail,
    this.createdAt,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      provider: '${json['provider'] ?? ''}'.toLowerCase(),
      providerEmail: '${json['provider_email'] ?? json['providerEmail'] ?? ''}',
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.tryParse('${json['created_at'] ?? json['createdAt']}')
          : null,
    );
  }

  final String provider;
  final String providerEmail;
  final DateTime? createdAt;
}
