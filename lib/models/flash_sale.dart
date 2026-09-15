class FlashSaleItem {
  const FlashSaleItem({
    required this.id,
    required this.foodId,
    required this.name,
    required this.image,
    required this.categoryName,
    required this.originalPrice,
    required this.salePrice,
    this.stockLimit,
    required this.soldCount,
    this.remaining,
  });

  final int id;
  final int foodId;
  final String name;
  final String image;
  final String categoryName;
  final int originalPrice;
  final int salePrice;
  final int? stockLimit;
  final int soldCount;
  final int? remaining;

  factory FlashSaleItem.fromJson(Map<String, dynamic> json) {
    String image = '${json['image'] ?? ''}'.trim();
    if (image.startsWith('/')) {
      image = 'https://food-backend-xrb9.onrender.com$image';
    }
    return FlashSaleItem(
      id: int.tryParse('${json['id']}') ?? 0,
      foodId: int.tryParse('${json['foodId'] ?? json['food_id']}') ?? 0,
      name: '${json['name'] ?? json['food_name'] ?? 'Món Flash Sale'}',
      image: image,
      categoryName: '${json['categoryName'] ?? json['category_name'] ?? ''}',
      originalPrice:
          double.tryParse('${json['originalPrice'] ?? json['original_price']}')
              ?.round() ??
          0,
      salePrice:
          double.tryParse('${json['salePrice'] ?? json['sale_price']}')
              ?.round() ??
          0,
      stockLimit: int.tryParse('${json['stockLimit'] ?? json['stock_limit']}'),
      soldCount:
          int.tryParse('${json['soldCount'] ?? json['sold_count']}') ?? 0,
      remaining: int.tryParse('${json['remaining']}'),
    );
  }
}

class FlashSaleCampaign {
  const FlashSaleCampaign({
    required this.id,
    required this.title,
    this.startsAt,
    this.endsAt,
    required this.items,
  });

  final int id;
  final String title;
  final String? startsAt;
  final String? endsAt;
  final List<FlashSaleItem> items;

  factory FlashSaleCampaign.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = (rawItems is List)
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(FlashSaleItem.fromJson)
              .toList()
        : <FlashSaleItem>[];

    return FlashSaleCampaign(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? 'Flash sale hôm nay'}',
      startsAt: json['startsAt']?.toString() ?? json['starts_at']?.toString(),
      endsAt: json['endsAt']?.toString() ?? json['ends_at']?.toString(),
      items: itemsList,
    );
  }
}
