import 'package:flutter_test/flutter_test.dart';
import 'package:food_mobile/models/food_review_item.dart';

void main() {
  test('normalizes review text and date like the website', () {
    final review = FoodReviewItem.fromJson({
      'id': 1,
      'food_id': 2,
      'food_name': 'Trà dâu',
      'customer_name': 'Khách hàng',
      'rating': 5,
      'comment': '',
      'created_at': '2026-08-25T14:29:40.000Z',
    });

    expect(
      review.comment,
      'Khách hàng đã chấm điểm và không để lại bình luận.',
    );
    expect(review.createdAt, '25/08/2026');
    expect(review.rating, 5);
  });
}
