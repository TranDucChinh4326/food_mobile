class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    this.parentId,
  });

  final int id;
  final String name;
  final String slug;
  final int sortOrder;
  final int? parentId;

  bool get isChild => parentId != null;

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
      slug: '${json['slug'] ?? ''}'.trim(),
      sortOrder:
          int.tryParse('${json['sortOrder'] ?? json['sort_order']}') ?? 0,
      parentId: int.tryParse('${json['parentId'] ?? json['parent_id']}'),
    );
  }
}

class HomeAnnouncement {
  const HomeAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.isRead,
  });

  final int id;
  final String title;
  final String content;
  final bool isRead;

  factory HomeAnnouncement.fromJson(Map<String, dynamic> json) {
    return HomeAnnouncement(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}'.trim(),
      content: '${json['content'] ?? ''}'.trim(),
      isRead:
          '${json['is_read'] ?? json['isRead']}' == '1' ||
          json['is_read'] == true ||
          json['isRead'] == true,
    );
  }

  HomeAnnouncement copyWith({bool? isRead}) {
    return HomeAnnouncement(
      id: id,
      title: title,
      content: content,
      isRead: isRead ?? this.isRead,
    );
  }
}

class HomeAdvertisement {
  const HomeAdvertisement({
    required this.id,
    required this.title,
    required this.image,
    this.linkUrl,
  });

  final int id;
  final String title;
  final String image;
  final String? linkUrl;

  factory HomeAdvertisement.fromJson(Map<String, dynamic> json) {
    return HomeAdvertisement(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}'.trim(),
      image: '${json['image'] ?? ''}'.trim(),
      linkUrl: (json['linkUrl'] ?? json['link_url'])?.toString().trim(),
    );
  }

  int? get linkedFoodId {
    final uri = Uri.tryParse(linkUrl ?? '');
    return int.tryParse(uri?.queryParameters['id'] ?? '');
  }
}
