/// Wallet model matching SCHEMA.md
library;

import '../../core/utils/firestore_utils.dart';

class WalletModel {
  final String id;
  final String tenantId;
  final String status; // active, blocked, pending
  final WalletBalance balance;
  final BankAccount? bankAccount;
  final String? gatewayRecipientId;
  final String? gatewayProvider;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.tenantId,
    this.status = 'active',
    required this.balance,
    this.bankAccount,
    this.gatewayRecipientId,
    this.gatewayProvider,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if wallet is active
  bool get isActive => status == 'active';

  /// Check if can withdraw
  bool get canWithdraw => isActive && balance.available > 0 && bankAccount != null;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      balance: json['balance'] != null
          ? WalletBalance.fromJson(json['balance'] as Map<String, dynamic>)
          : const WalletBalance(),
      bankAccount: json['bankAccount'] != null
          ? BankAccount.fromJson(json['bankAccount'] as Map<String, dynamic>)
          : null,
      gatewayRecipientId: json['gatewayRecipientId'] as String?,
      gatewayProvider: json['gatewayProvider'] as String?,
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'status': status,
      'balance': balance.toJson(),
      if (bankAccount != null) 'bankAccount': bankAccount!.toJson(),
      if (gatewayRecipientId != null) 'gatewayRecipientId': gatewayRecipientId,
      if (gatewayProvider != null) 'gatewayProvider': gatewayProvider,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WalletModel copyWith({
    String? id,
    String? tenantId,
    String? status,
    WalletBalance? balance,
    BankAccount? bankAccount,
    String? gatewayRecipientId,
    String? gatewayProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      balance: balance ?? this.balance,
      bankAccount: bankAccount ?? this.bankAccount,
      gatewayRecipientId: gatewayRecipientId ?? this.gatewayRecipientId,
      gatewayProvider: gatewayProvider ?? this.gatewayProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class WalletBalance {
  final double available;
  final double pending;
  final double blocked;
  final double total;

  const WalletBalance({
    this.available = 0.0,
    this.pending = 0.0,
    this.blocked = 0.0,
    this.total = 0.0,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      available: (json['available'] as num?)?.toDouble() ?? 0.0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0.0,
      blocked: (json['blocked'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available': available,
      'pending': pending,
      'blocked': blocked,
      'total': total,
    };
  }
}

class BankAccount {
  final String bankCode;
  final String bankName;
  final String branch;
  final String? branchDigit;
  final String accountNumber;
  final String accountDigit;
  final String accountType; // checking, savings
  final String holderName;
  final String holderDocument;

  const BankAccount({
    required this.bankCode,
    required this.bankName,
    required this.branch,
    this.branchDigit,
    required this.accountNumber,
    required this.accountDigit,
    this.accountType = 'checking',
    required this.holderName,
    required this.holderDocument,
  });

  /// Get formatted account string
  String get formattedAccount {
    final branchStr = branchDigit != null ? '$branch-$branchDigit' : branch;
    return '$bankName | Ag: $branchStr | CC: $accountNumber-$accountDigit';
  }

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      bankCode: json['bankCode'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      branchDigit: json['branchDigit'] as String?,
      accountNumber: json['accountNumber'] as String? ?? '',
      accountDigit: json['accountDigit'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'checking',
      holderName: json['holderName'] as String? ?? '',
      holderDocument: json['holderDocument'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bankCode': bankCode,
      'bankName': bankName,
      'branch': branch,
      if (branchDigit != null) 'branchDigit': branchDigit,
      'accountNumber': accountNumber,
      'accountDigit': accountDigit,
      'accountType': accountType,
      'holderName': holderName,
      'holderDocument': holderDocument,
    };
  }
}
