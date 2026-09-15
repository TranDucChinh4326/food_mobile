import 'package:flutter_test/flutter_test.dart';
import 'package:food_mobile/core/image_url.dart';

void main() {
  test('accepts remote raster images', () {
    expect(
      normalizeRasterImageUrl('https://cdn.example.com/avatar.jpg'),
      'https://cdn.example.com/avatar.jpg',
    );
  });

  test('expands backend upload paths', () {
    expect(
      normalizeRasterImageUrl('/uploads/avatars/user.png'),
      'https://food-backend-xrb9.onrender.com/uploads/avatars/user.png',
    );
  });

  test('rejects relative and SVG avatar paths', () {
    expect(
      normalizeRasterImageUrl('assets/images/avatars/chef-boy.svg'),
      isNull,
    );
    expect(normalizeRasterImageUrl('file:///assets/avatar.png'), isNull);
  });
}
