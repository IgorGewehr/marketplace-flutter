/// Review model for products and sellers
library;

class ReviewModel {
  final String id;
  final String targetId; // productId or tenantId
  final String targetType; // product, seller
  final String userId;
  final String userName;
  final String? userPhotoURL;
  final double rating; // 1-5 stars
  final String? comment;
  final List<String> images;
  final String? orderId; // Reference to purchase
  final bool isVerifiedPurchase;
  final ReviewResponse? sellerResponse;
  final int helpfulCount;
  final int reportCount;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.userId,
    required this.userName,
    this.userPhotoURL,
    required this.rating,
    this.comment,
    this.images = const [],
    this.orderId,
    this.isVerifiedPurchase = false,
    this.sellerResponse,
    this.helpfulCount = 0,
    this.reportCount = 0,
    this.isHidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if this is a product review
  bool get isProductReview => targetType == 'product';

  /// Check if this is a seller review
  bool get isSellerReview => targetType == 'seller';

  /// Check if review has images
  bool get hasImages => images.isNotEmpty;

  /// Check if seller responded
  bool get hasSellerResponse => sellerResponse != null;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? 'product',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userPhotoURL: json['userPhotoURL'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      orderId: json['orderId'] as String?,
      isVerifiedPurchase: json['isVerifiedPurchase'] as bool? ?? false,
      sellerResponse: json['sellerResponse'] != null
          ? ReviewResponse.fromJson(json['sellerResponse'] as Map<String, dynamic>)
          : null,
      helpfulCount: json['helpfulCount'] as int? ?? 0,
      reportCount: json['reportCount'] as int? ?? 0,
      isHidden: json['isHidden'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetId': targetId,
      'targetType': targetType,
      'userId': userId,
      'userName': userName,
      if (userPhotoURL != null) 'userPhotoURL': userPhotoURL,
      'rating': rating,
      if (comment != null) 'comment': comment,
      'images': images,
      if (orderId != null) 'orderId': orderId,
      'isVerifiedPurchase': isVerifiedPurchase,
      if (sellerResponse != null) 'sellerResponse': sellerResponse!.toJson(),
      'helpfulCount': helpfulCount,
      'reportCount': reportCount,
      'isHidden': isHidden,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ReviewModel copyWith({
    String? id,
    String? targetId,
    String? targetType,
    String? userId,
    String? userName,
    String? userPhotoURL,
    double? rating,
    String? comment,
    List<String>? images,
    String? orderId,
    bool? isVerifiedPurchase,
    ReviewResponse? sellerResponse,
    int? helpfulCount,
    int? reportCount,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoURL: userPhotoURL ?? this.userPhotoURL,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      orderId: orderId ?? this.orderId,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      sellerResponse: sellerResponse ?? this.sellerResponse,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      reportCount: reportCount ?? this.reportCount,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ReviewResponse {
  final String message;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const ReviewResponse({
    required this.message,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory ReviewResponse.fromJson(Map<String, dynamic> json) {
    return ReviewResponse(
      message: json['message'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Rating summary for products/sellers
class RatingSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // star -> count

  const RatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  /// Get percentage for a specific star rating
  double getPercentage(int stars) {
    if (totalReviews == 0) return 0.0;
    final count = ratingDistribution[stars] ?? 0;
    return (count / totalReviews) * 100;
  }

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      ratingDistribution: (json['ratingDistribution'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingDistribution': ratingDistribution.map((k, v) => MapEntry(k.toString(), v)),
    };
  }
}
