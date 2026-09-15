class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.sold,
    this.oldPrice,
    this.description,
    this.stockQuantity = 99,
  });

  final int id;
  final String name;
  final String category;
  final int price;
  final int? oldPrice;
  final String imageUrl;
  final double rating;
  final int sold;
  final String? description;
  final int stockQuantity;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    String imageUrl = '${json['image'] ?? ''}'.trim();
    if (imageUrl.startsWith('/')) {
      imageUrl = 'https://food-backend-xrb9.onrender.com$imageUrl';
    }
    return FoodItem(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? 'Món ăn'}',
      category:
          '${json['category_name'] ?? json['parent_category_name'] ?? 'Món ăn'}',
      price: double.tryParse('${json['price']}')?.round() ?? 0,
      imageUrl: imageUrl,
      rating: double.tryParse('${json['rating']}') ?? 0,
      sold: double.tryParse('${json['sold_count']}')?.round() ?? 0,
      description: json['description']?.toString() ?? json['desc']?.toString(),
      stockQuantity:
          int.tryParse('${json['stock_quantity'] ?? json['stockQuantity']}') ??
          99,
    );
  }
}
