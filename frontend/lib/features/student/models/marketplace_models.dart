// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE POST (Browse Tab)
// ─────────────────────────────────────────────────────────────────────────────

/// A sell-post listed in the marketplace (Browse tab).
class MarketplacePost {
  final String postId;
  final String sellerName;
  final String mealType; // 'Lunch' | 'Dinner'
  final String mealDate;
  final String? mealMenu;
  final int mealPrice;
  final int? sellerId;
  final int? buyerId;
  final String? buyerName;
  final String status;
  final String? paymentType;
  final String? createdAt;
  final String? buyerRequestedAt;

  const MarketplacePost({
    required this.postId,
    required this.sellerName,
    required this.mealType,
    required this.mealDate,
    this.mealMenu,
    required this.mealPrice,
    this.sellerId,
    this.buyerId,
    this.buyerName,
    required this.status,
    this.paymentType,
    this.createdAt,
    this.buyerRequestedAt,
  });

  factory MarketplacePost.fromJson(Map<String, dynamic> json) =>
      MarketplacePost(
        postId: json['id'].toString(),
        sellerName: json['sellerName'] as String? ?? '',
        mealType: json['mealType'] as String? ?? '',
        mealDate: json['mealDate'] as String? ?? '',
        mealMenu: json['mealMenu'] as String?,
        mealPrice: (json['mealPrice'] as num?)?.toInt() ?? 0,
        sellerId: json['sellerId'] as int?,
        buyerId: json['buyerId'] as int?,
        buyerName: json['buyerName'] as String?,
        status: json['status'] as String? ?? '',
        paymentType: json['paymentType'] as String?,
        createdAt: json['createdAt'] as String?,
        buyerRequestedAt: json['buyerRequestedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': postId,
        'sellerName': sellerName,
        'mealType': mealType,
        'mealDate': mealDate,
        'mealMenu': mealMenu,
        'mealPrice': mealPrice,
        'sellerId': sellerId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'status': status,
        'paymentType': paymentType,
        'createdAt': createdAt,
        'buyerRequestedAt': buyerRequestedAt,
      };

  /// Get seller initial for avatar.
  String get sellerInitial =>
      sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';

  /// Whether this is a lunch post.
  bool get isLunch => mealType.toUpperCase() == 'LUNCH';

  MarketplacePost copyWith({
    String? postId,
    String? sellerName,
    String? mealType,
    String? mealDate,
    String? mealMenu,
    int? mealPrice,
    int? sellerId,
    int? buyerId,
    String? buyerName,
    String? status,
    String? paymentType,
    String? createdAt,
    String? buyerRequestedAt,
  }) =>
      MarketplacePost(
        postId: postId ?? this.postId,
        sellerName: sellerName ?? this.sellerName,
        mealType: mealType ?? this.mealType,
        mealDate: mealDate ?? this.mealDate,
        mealMenu: mealMenu ?? this.mealMenu,
        mealPrice: mealPrice ?? this.mealPrice,
        sellerId: sellerId ?? this.sellerId,
        buyerId: buyerId ?? this.buyerId,
        buyerName: buyerName ?? this.buyerName,
        status: status ?? this.status,
        paymentType: paymentType ?? this.paymentType,
        createdAt: createdAt ?? this.createdAt,
        buyerRequestedAt: buyerRequestedAt ?? this.buyerRequestedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketplacePost &&
          runtimeType == other.runtimeType &&
          postId == other.postId;

  @override
  int get hashCode => postId.hashCode;

  @override
  String toString() =>
      'MarketplacePost(postId: $postId, seller: $sellerName, mealType: $mealType)';
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING STATUS
// ─────────────────────────────────────────────────────────────────────────────

/// Status options for a marketplace listing.
enum ListingStatus {
  open('OPEN'),
  pending('PENDING'),
  completed('COMPLETED');

  final String value;
  const ListingStatus(this.value);

  static ListingStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OPEN':
        return ListingStatus.open;
      case 'PENDING':
        return ListingStatus.pending;
      case 'COMPLETED':
        return ListingStatus.completed;
      default:
        return ListingStatus.open;
    }
  }
}

/// Status options for a marketplace purchase.
enum PurchaseStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  cancelled('CANCELLED');

  final String value;
  const PurchaseStatus(this.value);

  static PurchaseStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return PurchaseStatus.pending;
      case 'CONFIRMED':
        return PurchaseStatus.confirmed;
      case 'CANCELLED':
        return PurchaseStatus.cancelled;
      default:
        return PurchaseStatus.pending;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY LISTING (Activity → My Listings)
// ─────────────────────────────────────────────────────────────────────────────

/// A listing the student created (Activity → My Listings tab).
class MyListing {
  final String listingId;
  final String mealType; // 'Lunch' | 'Dinner'
  final String? mealDate;
  final String? mealMenu;
  final int mealPrice;
  final String? buyerName;
  final String status; // 'OPEN' | 'PENDING' | 'COMPLETED'
  final String? paymentType;
  final String? createdAt;
  final String? buyerRequestedAt;

  const MyListing({
    required this.listingId,
    required this.mealType,
    this.mealDate,
    this.mealMenu,
    required this.mealPrice,
    this.buyerName,
    required this.status,
    this.paymentType,
    this.createdAt,
    this.buyerRequestedAt,
  });

  factory MyListing.fromJson(Map<String, dynamic> json) => MyListing(
        listingId: json['id'].toString(),
        mealType: json['mealType'] as String? ?? '',
        mealDate: json['mealDate'] as String?,
        mealMenu: json['mealMenu'] as String?,
        mealPrice: (json['mealPrice'] as num?)?.toInt() ?? 0,
        buyerName: json['buyerName'] as String?,
        status: json['status'] as String? ?? '',
        paymentType: json['paymentType'] as String?,
        createdAt: json['createdAt'] as String?,
        buyerRequestedAt: json['buyerRequestedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': listingId,
        'mealType': mealType,
        'mealDate': mealDate,
        'mealMenu': mealMenu,
        'mealPrice': mealPrice,
        'buyerName': buyerName,
        'status': status,
        'paymentType': paymentType,
        'createdAt': createdAt,
        'buyerRequestedAt': buyerRequestedAt,
      };

  /// Parsed status enum.
  ListingStatus get listingStatus => ListingStatus.fromString(status);

  /// Whether the listing has a buyer assigned.
  bool get hasBuyer => buyerName != null && buyerName!.isNotEmpty;

  /// Whether this listing is awaiting seller confirmation.
  bool get isPending => status == 'PENDING';

  /// Whether this listing is still open for buyers.
  bool get isOpen => status == 'OPEN';

  /// Whether this listing has been completed.
  bool get isCompleted => status == 'COMPLETED';

  /// Price getter for backward compat.
  int get price => mealPrice;

  MyListing copyWith({
    String? listingId,
    String? mealType,
    String? mealDate,
    String? mealMenu,
    int? mealPrice,
    String? buyerName,
    String? status,
    String? paymentType,
    String? createdAt,
    String? buyerRequestedAt,
  }) =>
      MyListing(
        listingId: listingId ?? this.listingId,
        mealType: mealType ?? this.mealType,
        mealDate: mealDate ?? this.mealDate,
        mealMenu: mealMenu ?? this.mealMenu,
        mealPrice: mealPrice ?? this.mealPrice,
        buyerName: buyerName ?? this.buyerName,
        status: status ?? this.status,
        paymentType: paymentType ?? this.paymentType,
        createdAt: createdAt ?? this.createdAt,
        buyerRequestedAt: buyerRequestedAt ?? this.buyerRequestedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyListing &&
          runtimeType == other.runtimeType &&
          listingId == other.listingId;

  @override
  int get hashCode => listingId.hashCode;

  @override
  String toString() =>
      'MyListing(listingId: $listingId, mealType: $mealType, status: $status)';
}

// ─────────────────────────────────────────────────────────────────────────────
// MY PURCHASE (Activity → My Purchases)
// ─────────────────────────────────────────────────────────────────────────────

/// A purchase the student made from the marketplace (Activity → My Purchases).
class MyPurchase {
  final String purchaseId;
  final String sellerName;
  final String mealType; // 'Lunch' | 'Dinner'
  final String? mealDate;
  final String? mealMenu;
  final int mealPrice;
  final String status; // 'PENDING' | 'CONFIRMED' | 'CANCELLED'
  final String? paymentType;
  final String? createdAt;
  final String? buyerRequestedAt;

  const MyPurchase({
    required this.purchaseId,
    required this.sellerName,
    required this.mealType,
    this.mealDate,
    this.mealMenu,
    required this.mealPrice,
    required this.status,
    this.paymentType,
    this.createdAt,
    this.buyerRequestedAt,
  });

  factory MyPurchase.fromJson(Map<String, dynamic> json) => MyPurchase(
        purchaseId: json['id'].toString(),
        sellerName: json['sellerName'] as String? ?? '',
        mealType: json['mealType'] as String? ?? '',
        mealDate: json['mealDate'] as String?,
        mealMenu: json['mealMenu'] as String?,
        mealPrice: (json['mealPrice'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        paymentType: json['paymentType'] as String?,
        createdAt: json['createdAt'] as String?,
        buyerRequestedAt: json['buyerRequestedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': purchaseId,
        'sellerName': sellerName,
        'mealType': mealType,
        'mealDate': mealDate,
        'mealMenu': mealMenu,
        'mealPrice': mealPrice,
        'status': status,
        'paymentType': paymentType,
        'createdAt': createdAt,
        'buyerRequestedAt': buyerRequestedAt,
      };

  /// Parsed status enum.
  PurchaseStatus get purchaseStatus => PurchaseStatus.fromString(status);

  /// Seller initial for avatar display.
  String get sellerInitial =>
      sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';

  /// Price getter for backward compat.
  int get price => mealPrice;

  /// Whether this purchase is awaiting confirmation.
  bool get isPending => status == 'PENDING';

  /// Whether this purchase has been confirmed.
  bool get isConfirmed => status == 'CONFIRMED';

  /// Whether this purchase has been cancelled.
  bool get isCancelled => status == 'CANCELLED';

  MyPurchase copyWith({
    String? purchaseId,
    String? sellerName,
    String? mealType,
    String? mealDate,
    String? mealMenu,
    int? mealPrice,
    String? status,
    String? paymentType,
    String? createdAt,
    String? buyerRequestedAt,
  }) =>
      MyPurchase(
        purchaseId: purchaseId ?? this.purchaseId,
        sellerName: sellerName ?? this.sellerName,
        mealType: mealType ?? this.mealType,
        mealDate: mealDate ?? this.mealDate,
        mealMenu: mealMenu ?? this.mealMenu,
        mealPrice: mealPrice ?? this.mealPrice,
        status: status ?? this.status,
        paymentType: paymentType ?? this.paymentType,
        createdAt: createdAt ?? this.createdAt,
        buyerRequestedAt: buyerRequestedAt ?? this.buyerRequestedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyPurchase &&
          runtimeType == other.runtimeType &&
          purchaseId == other.purchaseId;

  @override
  int get hashCode => purchaseId.hashCode;

  @override
  String toString() =>
      'MyPurchase(purchaseId: $purchaseId, seller: $sellerName, status: $status)';
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE REQUESTS
// ─────────────────────────────────────────────────────────────────────────────

/// Request to create a sell listing in the marketplace.
class CreateSellRequest {
  final int tokenId;

  const CreateSellRequest({required this.tokenId});

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
      };

  @override
  String toString() =>
      'CreateSellRequest(tokenId: $tokenId)';
}

/// Request to buy a token from the marketplace.
class BuyFromMarketplaceRequest {
  final int postId;
  final String paymentType; // 'TRANSACTION' or 'TOPUP'

  const BuyFromMarketplaceRequest({
    required this.postId,
    required this.paymentType,
  });

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'paymentType': paymentType,
      };

  @override
  String toString() =>
      'BuyFromMarketplaceRequest(postId: $postId, paymentType: $paymentType)';
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS

