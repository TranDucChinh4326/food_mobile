import '../core/image_url.dart';

class FoodReviewItem {
  const FoodReviewItem({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.customerName,
    this.avatar,
    required this.rating,
    required this.comment,
    this.adminReply,
    this.createdAt,
  });

  final int id;
  final int foodId;
  final String foodName;
  final String customerName;
  final String? avatar;
  final int rating;
  final String comment;
  final String? adminReply;
  final String? createdAt;

  factory FoodReviewItem.fromJson(Map<String, dynamic> json) {
    final avatar = normalizeRasterImageUrl(json['avatar']);
    final rawComment = '${json['comment'] ?? ''}'.trim();
    final rawCreatedAt =
        json['createdAt']?.toString() ?? json['created_at']?.toString();
    return FoodReviewItem(
      id: int.tryParse('${json['id']}') ?? 0,
      foodId: int.tryParse('${json['foodId'] ?? json['food_id']}') ?? 0,
      foodName: '${json['foodName'] ?? json['food_name'] ?? 'Món ăn'}',
      customerName:
          '${json['customerName'] ?? json['customer_name'] ?? 'Khách hàng'}',
      avatar: avatar,
      rating: (int.tryParse('${json['rating']}') ?? 0).clamp(0, 5),
      comment:
          rawComment.isEmpty ||
              rawComment == 'Khách hàng đã đánh giá món ăn này.'
          ? 'Khách hàng đã chấm điểm và không để lại bình luận.'
          : rawComment,
      adminReply:
          json['adminReply']?.toString() ?? json['admin_reply']?.toString(),
      createdAt: _formatDate(rawCreatedAt),
    );
  }

  static String? _formatDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
