import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;

import '../../core/constants/api_constants.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/api_client.dart';
import '../models/user_model.dart';

/// Auth Repository Implementation
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    FirebaseAuth? firebaseAuth,
  })  : _apiClient = apiClient,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Create Firebase auth user
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user?.updateDisplayName(displayName);

    // Register with backend
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.authRegister,
      data: {
        'email': email,
        'displayName': displayName,
      },
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<UserModel> completeProfile({
    required String phone,
    required String cpfCnpj,
    DateTime? birthDate,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.authCompleteProfile,
      data: {
        'phone': phone,
        'cpfCnpj': cpfCnpj,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
      },
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.authMe,
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<UserModel> becomeSeller({
    required String tradeName,
    required String documentNumber,
    required String documentType,
    String? phone,
    String? whatsapp,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.authBecomeSeller,
      data: {
        'tradeName': tradeName,
        'documentNumber': documentNumber,
        'documentType': documentType,
        if (phone != null) 'phone': phone,
        if (whatsapp != null) 'whatsapp': whatsapp,
      },
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? phone,
    String? photoURL,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.authMe,
      data: {
        if (displayName != null) 'displayName': displayName,
        if (phone != null) 'phone': phone,
        if (photoURL != null) 'photoURL': photoURL,
      },
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<void> updateFcmToken(String token) async {
    await _apiClient.post<void>(
      '${ApiConstants.authMe}/fcm-token',
      data: {'token': token},
    );
  }

  @override
  Future<void> removeFcmToken(String token) async {
    await _apiClient.delete<void>(
      '${ApiConstants.authMe}/fcm-token',
      data: {'token': token},
    );
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
