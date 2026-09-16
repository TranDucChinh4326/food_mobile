class ShippingMethod {
  const ShippingMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.fee,
    required this.estimatedTime,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String description;
  final int fee;
  final String estimatedTime;
  final int sortOrder;

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    return ShippingMethod(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? 'Giao hàng'}',
      description: '${json['description'] ?? ''}',
      fee: double.tryParse('${json['fee'] ?? 0}')?.round() ?? 0,
      estimatedTime: '${json['estimatedTime'] ?? json['estimated_time'] ?? ''}',
      sortOrder:
          int.tryParse('${json['sortOrder'] ?? json['sort_order'] ?? 0}') ?? 0,
    );
  }
}

class ShippingQuote {
  const ShippingQuote({
    required this.shippingMethodId,
    required this.name,
    required this.fee,
    required this.baseFee,
    required this.areaSurcharge,
    required this.distanceFee,
    this.distanceKm,
    this.durationMinutes,
    required this.source,
    required this.estimatedTime,
  });

  final int shippingMethodId;
  final String name;
  final int fee;
  final int baseFee;
  final int areaSurcharge;
  final int distanceFee;
  final double? distanceKm;
  final int? durationMinutes;
  final String source;
  final String estimatedTime;

  factory ShippingQuote.fromJson(Map<String, dynamic> json) {
    return ShippingQuote(
      shippingMethodId: int.tryParse('${json['shippingMethodId']}') ?? 0,
      name: '${json['name'] ?? ''}',
      fee: double.tryParse('${json['fee'] ?? 0}')?.round() ?? 0,
      baseFee: double.tryParse('${json['baseFee'] ?? 0}')?.round() ?? 0,
      areaSurcharge:
          double.tryParse('${json['areaSurcharge'] ?? 0}')?.round() ?? 0,
      distanceFee: double.tryParse('${json['distanceFee'] ?? 0}')?.round() ?? 0,
      distanceKm: double.tryParse('${json['distanceKm']}'),
      durationMinutes: int.tryParse('${json['durationMinutes']}'),
      source: '${json['source'] ?? 'area'}',
      estimatedTime: '${json['estimatedTime'] ?? ''}',
    );
  }
}

class DiscountPreview {
  const DiscountPreview({
    required this.code,
    required this.name,
    this.userDiscountId,
    required this.applyTo,
    required this.discountAmount,
    required this.orderDiscount,
    required this.shippingDiscount,
  });

  final String code;
  final String name;
  final int? userDiscountId;
  final String applyTo; // 'order' or 'shipping'
  final int discountAmount;
  final int orderDiscount;
  final int shippingDiscount;

  factory DiscountPreview.fromJson(Map<String, dynamic> json) {
    return DiscountPreview(
      code: '${json['code'] ?? ''}',
      name: '${json['name'] ?? ''}',
      userDiscountId: int.tryParse('${json['userDiscountId']}'),
      applyTo: '${json['applyTo'] ?? 'order'}',
      discountAmount:
          double.tryParse('${json['discountAmount'] ?? 0}')?.round() ?? 0,
      orderDiscount:
          double.tryParse('${json['orderDiscount'] ?? 0}')?.round() ?? 0,
      shippingDiscount:
          double.tryParse('${json['shippingDiscount'] ?? 0}')?.round() ?? 0,
    );
  }
}
