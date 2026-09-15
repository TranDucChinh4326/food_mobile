class ComboItem {
  const ComboItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.image,
    this.maxAvailable = 0,
  });

  final int id;
  final String name;
  final String? description;
  final int price;
  final String image;
  final int maxAvailable;

  factory ComboItem.fromJson(Map<String, dynamic> json) {
    String image = '${json['image'] ?? ''}'.trim();
    if (image.startsWith('/')) {
      image = 'https://food-backend-xrb9.onrender.com$image';
    }
    return ComboItem(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? 'Combo Bếp 1979'}',
      description: json['description']?.toString(),
      price: double.tryParse('${json['price']}')?.round() ?? 0,
      image: image,
      maxAvailable: int.tryParse('${json['maxAvailable']}') ?? 0,
    );
  }
}
