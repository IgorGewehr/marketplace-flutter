import '../../data/models/wallet_model.dart';
import '../../data/models/transaction_model.dart';

/// Wallet Repository Interface (Seller only)
abstract class WalletRepository {
  /// Get wallet balance
  Future<WalletModel> getWallet();

  /// Get paginated transactions
  Future<TransactionListResponse> getTransactions({
    int page = 1,
    int limit = 20,
    String? type, // sale, refund, withdrawal
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Request withdrawal
  Future<WithdrawalModel> requestWithdrawal({
    required double amount,
    String? pixKey,
    String? pixKeyType,
  });

  /// Get pending withdrawals
  Future<List<WithdrawalModel>> getPendingWithdrawals();

  /// Update bank account
  Future<WalletModel> updateBankAccount(BankAccount bankAccount);
}

/// Response wrapper for paginated transaction lists
class TransactionListResponse {
  final List<TransactionModel> transactions;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const TransactionListResponse({
    required this.transactions,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    return TransactionListResponse(
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Withdrawal model
class WithdrawalModel {
  final String id;
  final String walletId;
  final String tenantId;
  final double amount;
  final double fee;
  final double netAmount;
  final String status; // pending, processing, completed, failed
  final BankAccount bankAccount;
  final String? gatewayWithdrawalId;
  final DateTime? processedAt;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WithdrawalModel({
    required this.id,
    required this.walletId,
    required this.tenantId,
    required this.amount,
    this.fee = 0.0,
    required this.netAmount,
    this.status = 'pending',
    required this.bankAccount,
    this.gatewayWithdrawalId,
    this.processedAt,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalModel(
      id: json['id'] as String? ?? '',
      walletId: json['walletId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      bankAccount: BankAccount.fromJson(json['bankAccount'] as Map<String, dynamic>),
      gatewayWithdrawalId: json['gatewayWithdrawalId'] as String?,
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
      failureReason: json['failureReason'] as String?,
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
      'walletId': walletId,
      'tenantId': tenantId,
      'amount': amount,
      'fee': fee,
      'netAmount': netAmount,
      'status': status,
      'bankAccount': bankAccount.toJson(),
      if (gatewayWithdrawalId != null) 'gatewayWithdrawalId': gatewayWithdrawalId,
      if (processedAt != null) 'processedAt': processedAt!.toIso8601String(),
      if (failureReason != null) 'failureReason': failureReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
