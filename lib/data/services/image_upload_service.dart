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

  /// Upload a single image with compression and validation
  Future<String> uploadProductImage(File imageFile, String productId) async {
    try {
      // Validate file size before compression
      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes * 2) {
        throw Exception('Imagem muito grande. Máximo: 10MB');
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

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Upload multiple images with progress tracking
  Future<List<String>> uploadProductImages(
    List<File> imageFiles,
    String productId, {
    Function(int current, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final url = await uploadProductImage(imageFiles[i], productId);
        urls.add(url);
        onProgress?.call(i + 1, imageFiles.length);
      } catch (e) {
        // Continue with other images even if one fails
        continue;
      }
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

  /// Upload a chat image with compression
  Future<String> uploadChatImage(File imageFile, String chatId) async {
    try {
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
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Erro do Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Upload a profile avatar image with compression
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
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
      return await snapshot.ref.getDownloadURL();
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
