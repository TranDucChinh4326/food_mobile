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
    this.categoryId,
    this.categorySlug,
    this.categoryName,
    this.parentCategoryId,
    this.parentCategoryName,
    this.parentCategorySlug,
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
  final int? categoryId;
  final String? categorySlug;
  final String? categoryName;
  final int? parentCategoryId;
  final String? parentCategoryName;
  final String? parentCategorySlug;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    String imageUrl = '${json['image'] ?? ''}'.trim();
    if (imageUrl.startsWith('/')) {
      imageUrl = 'https://food-backend-xrb9.onrender.com$imageUrl';
    }
    final rawCatName =
        json['category_name']?.toString().trim() ??
        json['categoryName']?.toString().trim() ??
        json['category']?.toString().trim();
    final rawParentCatName =
        json['parent_category_name']?.toString().trim() ??
        json['parentCategoryName']?.toString().trim();

    return FoodItem(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? 'Món ăn'}',
      category: rawCatName?.isNotEmpty == true
          ? rawCatName!
          : (rawParentCatName?.isNotEmpty == true
                ? rawParentCatName!
                : 'Món ăn'),
      price: double.tryParse('${json['price']}')?.round() ?? 0,
      imageUrl: imageUrl,
      rating: double.tryParse('${json['rating']}') ?? 0,
      sold:
          double.tryParse('${json['sold_count'] ?? json['sold']}')?.round() ??
          0,
      description: json['description']?.toString() ?? json['desc']?.toString(),
      stockQuantity:
          int.tryParse('${json['stock_quantity'] ?? json['stockQuantity']}') ??
          99,
      categoryId: int.tryParse('${json['category_id'] ?? json['categoryId']}'),
      categorySlug:
          json['category_slug']?.toString() ?? json['categorySlug']?.toString(),
      categoryName: rawCatName,
      parentCategoryId: int.tryParse(
        '${json['parent_category_id'] ?? json['parentCategoryId']}',
      ),
      parentCategoryName: rawParentCatName,
      parentCategorySlug:
          json['parent_category_slug']?.toString() ??
          json['parentCategorySlug']?.toString(),
    );
  }
}
