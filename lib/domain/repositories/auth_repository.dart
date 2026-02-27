import '../../data/models/user_model.dart';

/// Auth Repository Interface
abstract class AuthRepository {
  /// Register a new user
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Complete user profile after registration
  Future<UserModel> completeProfile({
    required String phone,
    String? cpfCnpj,
    DateTime? birthDate,
  });

  /// Get current authenticated user data
  Future<UserModel> getCurrentUser();

  /// Become a seller (upgrade from buyer)
  Future<UserModel> becomeSeller({
    required String tradeName,
    required String documentNumber,
    required String documentType, // cpf or cnpj
    String? phone,
    String? whatsapp,
    String? address,
  });

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? phone,
    String? photoURL,
    String? cpfCnpj,
  });

  /// Update FCM token for push notifications
  Future<void> updateFcmToken(String token);

  /// Remove FCM token
  Future<void> removeFcmToken(String token);

  /// Update favoriteProductIds list on the server
  Future<void> updateFavorites(List<String> favoriteIds);

  /// Sign out
  Future<void> signOut();

  /// Permanently delete the current user's account
  Future<void> deleteAccount();
}
