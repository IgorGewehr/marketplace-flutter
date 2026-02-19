import '../../core/constants/api_constants.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/api_client.dart';
import '../models/wallet_model.dart';

/// Wallet Repository Implementation
class WalletRepositoryImpl implements WalletRepository {
  final ApiClient _apiClient;

  WalletRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<WalletModel> getWallet() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.wallet,
    );

    return WalletModel.fromJson(response);
  }

  @override
  Future<TransactionListResponse> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.walletTransactions,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null) 'type': type,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );

    return TransactionListResponse.fromJson(response);
  }

  @override
  Future<WithdrawalModel> requestWithdrawal({
    required double amount,
    String? pixKey,
    String? pixKeyType,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.walletWithdraw,
      data: {
        'amount': amount,
        if (pixKey != null) 'pixKey': pixKey,
        if (pixKeyType != null) 'pixKeyType': pixKeyType,
      },
    );

    return WithdrawalModel.fromJson(response);
  }

  @override
  Future<List<WithdrawalModel>> getPendingWithdrawals() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.wallet}/withdrawals',
      queryParameters: {'status': 'pending'},
    );

    final withdrawals = (response['withdrawals'] as List<dynamic>?)
            ?.map((w) => WithdrawalModel.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    return withdrawals;
  }

  @override
  Future<WalletModel> updateBankAccount(BankAccount bankAccount) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '${ApiConstants.wallet}/bank-account',
      data: bankAccount.toJson(),
    );

    return WalletModel.fromJson(response);
  }
}
