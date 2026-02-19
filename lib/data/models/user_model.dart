/// User model matching SCHEMA.md
/// Supports buyer, seller, erp_only, and full user types
library;

import 'address_model.dart';

class UserModel {
  final String id;
  final String type; // buyer, seller, erp_only, full
  final String? tenantId;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? phone;
  final String? cpfCnpj;
  final DateTime? birthDate;
  final List<String> fcmTokens;
  final bool isActive;
  final DateTime? lastLoginAt;
  final List<AddressModel> addresses;
  final UserPreferences? preferences;
  final String? role; // owner, admin, employee (for seller/full types)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.type,
    this.tenantId,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.phone,
    this.cpfCnpj,
    this.birthDate,
    this.fcmTokens = const [],
    this.isActive = true,
    this.lastLoginAt,
    this.addresses = const [],
    this.preferences,
    this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if user is a buyer
  bool get isBuyer => type == 'buyer';

  /// Check if user is a seller (seller, erp_only, or full)
  bool get isSeller => type == 'seller' || type == 'erp_only' || type == 'full';

  /// Check if user has ERP access (erp_only or full)
  bool get hasErpAccess => type == 'erp_only' || type == 'full';

  /// Check if user can sell on marketplace (seller or full)
  bool get canSellOnMarketplace => type == 'seller' || type == 'full';

  /// Check if user has a tenant
  bool get hasTenant => tenantId != null;

  /// Check if user has completed profile (has phone)
  bool get hasCompletedProfile => phone != null && phone!.isNotEmpty;

  /// Get default address
  AddressModel? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'buyer',
      tenantId: json['tenantId'] as String?,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoURL: json['photoURL'] as String?,
      phone: json['phone'] as String?,
      cpfCnpj: json['cpfCnpj'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      fcmTokens: (json['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [],
      isActive: json['isActive'] as bool? ?? true,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      addresses: (json['addresses'] as List<dynamic>?)
              ?.map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : null,
      role: json['role'] as String?,
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
      'type': type,
      if (tenantId != null) 'tenantId': tenantId,
      'email': email,
      'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      if (phone != null) 'phone': phone,
      if (cpfCnpj != null) 'cpfCnpj': cpfCnpj,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      'fcmTokens': fcmTokens,
      'isActive': isActive,
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      'addresses': addresses.map((a) => a.toJson()).toList(),
      if (preferences != null) 'preferences': preferences!.toJson(),
      if (role != null) 'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? type,
    String? tenantId,
    String? email,
    String? displayName,
    String? photoURL,
    String? phone,
    String? cpfCnpj,
    DateTime? birthDate,
    List<String>? fcmTokens,
    bool? isActive,
    DateTime? lastLoginAt,
    List<AddressModel>? addresses,
    UserPreferences? preferences,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      type: type ?? this.type,
      tenantId: tenantId ?? this.tenantId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phone: phone ?? this.phone,
      cpfCnpj: cpfCnpj ?? this.cpfCnpj,
      birthDate: birthDate ?? this.birthDate,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      addresses: addresses ?? this.addresses,
      preferences: preferences ?? this.preferences,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class UserPreferences {
  final bool notifyPromotions;
  final bool notifyOrderUpdates;
  final List<String> preferredCategories;
  final int searchRadius;

  const UserPreferences({
    this.notifyPromotions = true,
    this.notifyOrderUpdates = true,
    this.preferredCategories = const [],
    this.searchRadius = 10,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      notifyPromotions: json['notifyPromotions'] as bool? ?? true,
      notifyOrderUpdates: json['notifyOrderUpdates'] as bool? ?? true,
      preferredCategories:
          (json['preferredCategories'] as List<dynamic>?)?.cast<String>() ?? [],
      searchRadius: json['searchRadius'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifyPromotions': notifyPromotions,
      'notifyOrderUpdates': notifyOrderUpdates,
      'preferredCategories': preferredCategories,
      'searchRadius': searchRadius,
    };
  }

  UserPreferences copyWith({
    bool? notifyPromotions,
    bool? notifyOrderUpdates,
    List<String>? preferredCategories,
    int? searchRadius,
  }) {
    return UserPreferences(
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifyOrderUpdates: notifyOrderUpdates ?? this.notifyOrderUpdates,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      searchRadius: searchRadius ?? this.searchRadius,
    );
  }
}
