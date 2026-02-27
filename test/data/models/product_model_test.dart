import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket/data/models/product_model.dart';

void main() {
  group('ProductModel', () {
    final testJson = {
      'id': 'prod_123',
      'tenantId': 'tenant_123',
      'name': 'Test Product',
      'description': 'A test product description',
      'shortDescription': 'Short desc',
      'images': [
        {
          'id': 'img_1',
          'url': 'https://example.com/image.jpg',
          'alt': 'Product image',
          'order': 0,
        }
      ],
      'price': 99.90,
      'compareAtPrice': 149.90,
      'categoryId': 'cat_123',
      'tags': ['new', 'featured'],
      'marketplaceStats': {
        'rating': 4.8,
        'reviewCount': 50,
        'views': 1000,
        'favorites': 25,
        'sales': 10,
      },
      'hasVariants': false,
      'variants': [],
      'status': 'active',
      'visibility': 'both',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-01T00:00:00.000Z',
    };

    test('fromJson creates valid ProductModel', () {
      final product = ProductModel.fromJson(testJson);

      expect(product.id, 'prod_123');
      expect(product.tenantId, 'tenant_123');
      expect(product.name, 'Test Product');
      expect(product.description, 'A test product description');
      expect(product.price, 99.90);
      expect(product.compareAtPrice, 149.90);
      expect(product.rating, 4.8);
      expect(product.reviewCount, 50);
      expect(product.isActive, true);
    });

    test('toJson creates valid JSON', () {
      final product = ProductModel.fromJson(testJson);
      final json = product.toJson();

      expect(json['id'], 'prod_123');
      expect(json['tenantId'], 'tenant_123');
      expect(json['name'], 'Test Product');
      expect(json['price'], 99.90);
    });

    test('hasDiscount returns true when compareAtPrice exists', () {
      final product = ProductModel.fromJson(testJson);
      expect(product.hasDiscount, true);
    });

    test('discountPercentage calculates correctly', () {
      final product = ProductModel.fromJson(testJson);
      expect(product.discountPercentage, 33);
    });

    test('mainImageUrl returns first image URL', () {
      final product = ProductModel.fromJson(testJson);
      expect(product.mainImageUrl, 'https://example.com/image.jpg');
    });

    test('copyWith creates new instance with updated values', () {
      final product = ProductModel.fromJson(testJson);
      final updated = product.copyWith(name: 'Updated Name', price: 199.90);

      expect(updated.name, 'Updated Name');
      expect(updated.price, 199.90);
      expect(updated.id, 'prod_123'); // Unchanged
    });

    test('equality operator works correctly', () {
      final product1 = ProductModel.fromJson(testJson);
      final product2 = ProductModel.fromJson(testJson);

      expect(product1, equals(product2));
      expect(product1.hashCode, equals(product2.hashCode));
    });
  });
}
