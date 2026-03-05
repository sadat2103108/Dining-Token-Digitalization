/// Represents a meal configuration for a specific date and meal type.
class MealConfig {
  final int? id;
  final String date; // YYYY-MM-DD
  final MealType mealType;
  final int price;
  final String menu;
  final String? purchaseDeadline; // HH:mm format
  final DateTime? createdAt;
  final bool isClosed;
  final int tokensSold;

  const MealConfig({
    this.id,
    required this.date,
    required this.mealType,
    required this.price,
    required this.menu,
    this.purchaseDeadline,
    this.createdAt,
    this.isClosed = false,
    this.tokensSold = 0,
  });

  factory MealConfig.fromJson(Map<String, dynamic> json) {
    return MealConfig(
      id: json['id'] as int?,
      date: json['date'] as String,
      mealType: MealType.fromString(json['mealType'] as String),
      price: (json['price'] as num).toInt(),
      menu: json['menu'] as String,
      purchaseDeadline: json['purchaseDeadline'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isClosed: json['isClosed'] as bool? ?? json['closed'] as bool? ?? false,
      tokensSold: (json['tokensSold'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'mealType': mealType.name,
      'price': price,
      'menu': menu,
      if (purchaseDeadline != null) 'purchaseDeadline': purchaseDeadline,
    };
  }

  MealConfig copyWith({
    int? id,
    String? date,
    MealType? mealType,
    int? price,
    String? menu,
    String? purchaseDeadline,
    bool? isClosed,
    int? tokensSold,
  }) {
    return MealConfig(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      price: price ?? this.price,
      menu: menu ?? this.menu,
      purchaseDeadline: purchaseDeadline ?? this.purchaseDeadline,
      createdAt: createdAt,
      isClosed: isClosed ?? this.isClosed,
      tokensSold: tokensSold ?? this.tokensSold,
    );
  }
}

enum MealType {
  lunch,
  dinner;

  static MealType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.lunch;
    }
  }

  String get displayName {
    switch (this) {
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }
}
