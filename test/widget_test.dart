import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_mobile/app.dart';
import 'package:food_mobile/data/demo_data.dart';
import 'package:food_mobile/models/combo_item.dart';
import 'package:food_mobile/screens/home_screen.dart';

void main() {
  testWidgets('renders the Bep 1979 home experience', (tester) async {
    await tester.pumpWidget(
      Bep1979App(
        home: Scaffold(
          body: HomeScreen(
            foods: demoFoods,
            combos: const [
              ComboItem(
                id: 1,
                name: 'Combo Cơm Trưa',
                description: 'Combo đồng bộ từ API',
                price: 65000,
                image: 'https://example.com/combo.jpg',
                maxAvailable: 10,
              ),
            ],
            loading: false,
            loadError: null,
            onRetry: () {},
            cartCount: 0,
            favorites: const {},
            onAddToCart: (_) {},
            onToggleFavorite: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Bạn muốn ăn gì hôm nay?'), findsOneWidget);
    expect(find.text('Combo Cơm Trưa'), findsOneWidget);
    expect(find.text('Bếp 1979'), findsOneWidget);
    expect(find.text('Danh mục'), findsOneWidget);
  });
}
