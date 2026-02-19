// ===========================================================================
// Storage Service - Upload de arquivos para Firebase Storage
// ===========================================================================

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Service para upload de arquivos no Firebase Storage
class StorageService {
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Uuid _uuid = const Uuid();

  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Upload de imagem de produto
  /// Retorna a URL pública da imagem
  Future<String> uploadProductImage({
    required File file,
    required String productId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const ApiException(message: 'Usuário não autenticado');
      }

      // Validar tipo de arquivo
      _validateImageFile(file);

      // Gerar nome único para o arquivo
      final fileName = '${_uuid.v4()}.jpg';
      final path = 'products/$productId/$fileName';

      AppConfig.logger.d('Uploading image to: $path');

      // Upload do arquivo
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'productId': productId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Aguardar conclusão do upload
      final snapshot = await uploadTask;

      // Obter URL de download
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppConfig.logger.i('Image uploaded successfully: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      AppConfig.logger.e('Firebase Storage error', error: e);
      throw ApiException(message: _getStorageErrorMessage(e.code));
    } catch (e, stackTrace) {
      AppConfig.logger.e('Upload error', error: e, stackTrace: stackTrace);
      throw const ApiException(message: 'Erro ao fazer upload da imagem');
    }
  }

  /// Upload de múltiplas imagens de produto
  Future<List<String>> uploadProductImages({
    required List<File> files,
    required String productId,
    Function(int current, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (var i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length);
      final url = await uploadProductImage(
        file: files[i],
        productId: productId,
      );
      urls.add(url);
    }

    return urls;
  }

  /// Upload de logo de tenant
  Future<String> uploadTenantLogo({
    required File file,
    required String tenantId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const ApiException(message: 'Usuário não autenticado');
      }

      _validateImageFile(file);

      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'tenants/$tenantId/$fileName';

      AppConfig.logger.d('Uploading tenant logo to: $path');

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'tenantId': tenantId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppConfig.logger.i('Tenant logo uploaded: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      AppConfig.logger.e('Firebase Storage error', error: e);
      throw ApiException(message: _getStorageErrorMessage(e.code));
    } catch (e, stackTrace) {
      AppConfig.logger.e('Upload error', error: e, stackTrace: stackTrace);
      throw const ApiException(message: 'Erro ao fazer upload do logo');
    }
  }

  /// Upload de foto de perfil de usuário
  Future<String> uploadUserPhoto({
    required File file,
    required String userId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const ApiException(message: 'Usuário não autenticado');
      }

      _validateImageFile(file);

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'users/$userId/$fileName';

      AppConfig.logger.d('Uploading user photo to: $path');

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppConfig.logger.i('User photo uploaded: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      AppConfig.logger.e('Firebase Storage error', error: e);
      throw ApiException(message: _getStorageErrorMessage(e.code));
    } catch (e, stackTrace) {
      AppConfig.logger.e('Upload error', error: e, stackTrace: stackTrace);
      throw const ApiException(message: 'Erro ao fazer upload da foto');
    }
  }

  /// Upload de imagem de serviço
  /// Retorna a URL pública da imagem
  Future<String> uploadServiceImage(
    String serviceId,
    String filePath, {
    String category = 'profile',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const ApiException(message: 'Usuário não autenticado');
      }

      final file = File(filePath);
      _validateImageFile(file);

      final fileName = '${_uuid.v4()}.jpg';
      final path = 'services/$serviceId/$category/$fileName';

      AppConfig.logger.d('Uploading service image to: $path');

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'serviceId': serviceId,
            'category': category,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppConfig.logger.i('Service image uploaded: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      AppConfig.logger.e('Firebase Storage error', error: e);
      throw ApiException(message: _getStorageErrorMessage(e.code));
    } catch (e, stackTrace) {
      AppConfig.logger.e('Upload error', error: e, stackTrace: stackTrace);
      throw const ApiException(message: 'Erro ao fazer upload da imagem');
    }
  }

  /// Upload de múltiplas imagens de serviço
  Future<List<String>> uploadServiceImages({
    required List<String> filePaths,
    required String serviceId,
    String category = 'profile',
    Function(int current, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (var i = 0; i < filePaths.length; i++) {
      onProgress?.call(i + 1, filePaths.length);
      final url = await uploadServiceImage(
        serviceId,
        filePaths[i],
        category: category,
      );
      urls.add(url);
    }

    return urls;
  }

  /// Deleta uma imagem do Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extrair o path do storage da URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      AppConfig.logger.i('Image deleted: $imageUrl');
    } on FirebaseException catch (e) {
      AppConfig.logger.e('Error deleting image', error: e);
      throw ApiException(message: _getStorageErrorMessage(e.code));
    }
  }

  /// Valida se o arquivo é uma imagem válida
  void _validateImageFile(File file) {
    // Verificar se arquivo existe
    if (!file.existsSync()) {
      throw const ApiException(message: 'Arquivo não encontrado');
    }

    // Verificar tamanho (máx 5MB)
    final fileSize = file.lengthSync();
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (fileSize > maxSize) {
      throw const ApiException(message: 'Imagem muito grande (máximo 5MB)');
    }

    // Verificar extensão
    final extension = file.path.split('.').last.toLowerCase();
    const validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
    if (!validExtensions.contains(extension)) {
      throw const ApiException(message: 'Formato de imagem inválido (use JPG, PNG ou WebP)');
    }
  }

  /// Traduz códigos de erro do Firebase Storage
  String _getStorageErrorMessage(String code) {
    switch (code) {
      case 'storage/unauthorized':
        return 'Você não tem permissão para fazer upload';
      case 'storage/canceled':
        return 'Upload cancelado';
      case 'storage/unknown':
        return 'Erro desconhecido ao fazer upload';
      case 'storage/object-not-found':
        return 'Arquivo não encontrado';
      case 'storage/bucket-not-found':
        return 'Bucket do Storage não encontrado';
      case 'storage/project-not-found':
        return 'Projeto Firebase não encontrado';
      case 'storage/quota-exceeded':
        return 'Cota de armazenamento excedida';
      case 'storage/unauthenticated':
        return 'Você precisa fazer login primeiro';
      case 'storage/retry-limit-exceeded':
        return 'Tempo limite excedido. Tente novamente';
      default:
        return 'Erro ao fazer upload da imagem';
    }
  }
}
