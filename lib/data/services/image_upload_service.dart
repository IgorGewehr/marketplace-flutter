import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Service for uploading images to Firebase Storage
class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Maximum file size: 5MB
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  // Image quality settings
  static const int compressionQuality = 85;
  static const int maxWidth = 1024;
  static const int maxHeight = 1024;

  // Allowed image extensions
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];

  /// Validate that a file has an allowed image extension
  void _validateFileExtension(File file) {
    final ext = path.extension(file.path).toLowerCase().replaceAll('.', '');
    if (ext.isNotEmpty && !_allowedExtensions.contains(ext)) {
      throw Exception('Formato não suportado. Use: JPG, PNG ou WebP');
    }
  }

  /// Upload a single image with compression and validation
  Future<String> uploadProductImage(File imageFile, String productId) async {
    try {
      // Validate file extension
      _validateFileExtension(imageFile);

      // Validate file size before compression
      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes) {
        throw Exception('Imagem muito grande. Máximo: 5MB');
      }

      // Compress image before upload
      final compressedFile = await _compressImage(imageFile);

      // Validate compressed file size
      final compressedSize = await compressedFile.length();
      if (compressedSize > maxFileSizeBytes) {
        throw Exception('Erro ao comprimir imagem. Tente outra imagem.');
      }

      // Generate unique filename with timestamp for better organization
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${_uuid.v4()}.jpg';
      final filePath = 'products/$productId/$fileName';

      // Upload to Firebase Storage with metadata
      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'productId': productId,
        },
      );

      final uploadTask = ref.putFile(compressedFile, metadata);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Clean up temp compressed file
      await _deleteTempCompressed(imageFile, compressedFile);

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  // Gap #23: Track active upload tasks for cancellation
  final List<UploadTask> _activeUploads = [];
  bool _isCancelled = false;

  /// Cancel all pending uploads
  void cancelUploads() {
    _isCancelled = true;
    for (final task in _activeUploads) {
      task.cancel();
    }
    _activeUploads.clear();
  }

  /// Upload multiple images with progress tracking and cancellation support
  Future<List<String>> uploadProductImages(
    List<File> imageFiles,
    String productId, {
    Function(int current, int total)? onProgress,
  }) async {
    _isCancelled = false;
    _activeUploads.clear();
    final urls = <String>[];
    int failedCount = 0;
    String? lastError;

    for (int i = 0; i < imageFiles.length; i++) {
      if (_isCancelled) break;
      try {
        final url = await uploadProductImage(imageFiles[i], productId);
        urls.add(url);
        onProgress?.call(i + 1, imageFiles.length);
      } catch (e) {
        lastError = e.toString().replaceAll('Exception: ', '');
        failedCount++;
        continue;
      }
    }

    _activeUploads.clear();

    if (failedCount > 0) {
      if (urls.isEmpty) {
        throw Exception(lastError ?? 'Nenhuma foto pôde ser enviada.');
      }
      throw Exception('$failedCount foto(s) não puderam ser enviadas. Último erro: $lastError');
    }

    return urls;
  }

  /// Compress image to reduce file size
  Future<File> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final dir = path.dirname(filePath);
      final filename = path.basenameWithoutExtension(filePath);
      final outPath = path.join(dir, '${filename}_compressed.jpg');

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: compressionQuality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      }

      // If compression fails, return original
      return file;
    } catch (e) {
      // If compression fails, return original file
      return file;
    }
  }

  /// Delete a temporary compressed file if it is different from the original.
  Future<void> _deleteTempCompressed(File original, File compressed) async {
    if (original.path == compressed.path) return;
    try {
      if (await compressed.exists()) {
        await compressed.delete();
      }
    } catch (_) {
      // Ignore cleanup errors — not critical
    }
  }

  /// Upload a chat image with compression
  Future<String> uploadChatImage(File imageFile, String chatId) async {
    try {
      _validateFileExtension(imageFile);

      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes * 2) {
        throw Exception('Imagem muito grande. Máximo: 10MB');
      }

      final compressedFile = await _compressImage(imageFile);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${_uuid.v4()}.jpg';
      final filePath = 'chats/$chatId/$fileName';

      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'chatId': chatId,
        },
      );

      final uploadTask = ref.putFile(compressedFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Clean up temp compressed file
      await _deleteTempCompressed(imageFile, compressedFile);

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Upload a profile avatar image with compression
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      _validateFileExtension(imageFile);

      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes * 2) {
        throw Exception('Imagem muito grande. Máximo: 10MB');
      }

      final compressedFile = await _compressImage(imageFile);

      final fileName = '${_uuid.v4()}.jpg';
      final filePath = 'avatars/$userId/$fileName';

      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'userId': userId,
        },
      );

      final uploadTask = ref.putFile(compressedFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Clean up temp compressed file
      await _deleteTempCompressed(imageFile, compressedFile);

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Upload a tenant logo or cover image with compression.
  /// [isCover] = true uploads as cover image, false as logo.
  Future<String> uploadTenantImage(
    File imageFile,
    String tenantId, {
    bool isCover = false,
  }) async {
    try {
      _validateFileExtension(imageFile);

      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes * 2) {
        throw Exception('Imagem muito grande. Máximo: 10MB');
      }

      final compressedFile = await _compressImage(imageFile);

      final type = isCover ? 'cover' : 'logo';
      final fileName = '${type}_${_uuid.v4()}.jpg';
      final filePath = 'tenants/$tenantId/$fileName';

      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'tenantId': tenantId,
          'type': type,
        },
      );

      final uploadTask = ref.putFile(compressedFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _deleteTempCompressed(imageFile, compressedFile);

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Delete image from Firebase Storage
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Silent fail - image might not exist
    }
  }

  /// Delete all images for a product
  Future<void> deleteProductImages(String productId) async {
    try {
      final ref = _storage.ref().child('products/$productId');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      // Silent fail
    }
  }
}

/// Provider for image upload service
final imageUploadServiceProvider = ImageUploadService();
