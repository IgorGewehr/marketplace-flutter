import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson creates buyer user', () {
      final json = {
        'id': 'user_123',
        'userType': 'buyer',
        'email': 'buyer@example.com',
        'displayName': 'Test Buyer',
        'photoURL': 'https://example.com/photo.jpg',
        'phone': '+5511999999999',
        'tenantId': null,
        'role': null,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user_123');
      expect(user.userType, 'buyer');
      expect(user.email, 'buyer@example.com');
      expect(user.isBuyer, true);
      expect(user.isSeller, false);
      expect(user.tenantId, null);
    });

    test('fromJson creates seller user', () {
      final json = {
        'id': 'user_123',
        'userType': 'seller',
        'email': 'seller@example.com',
        'displayName': 'Test Seller',
        'photoURL': null,
        'phone': '+5511999999999',
        'tenantId': 'tenant_123',
        'role': 'owner',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.userType, 'seller');
      expect(user.isSeller, true);
      expect(user.isBuyer, false);
      expect(user.tenantId, 'tenant_123');
      expect(user.role, 'owner');
    });

    test('isBuyer returns true for buyer userType', () {
      final user = UserModel.fromJson({
        'id': 'user_123',
        'userType': 'buyer',
        'email': 'test@example.com',
        'displayName': 'Test',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });

      expect(user.isBuyer, true);
    });

    test('isSeller returns true for seller types', () {
      final seller = UserModel.fromJson({
        'id': 'user_123',
        'userType': 'seller',
        'email': 'test@example.com',
        'displayName': 'Test',
        'tenantId': 'tenant_123',
        'role': 'owner',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });

      final full = UserModel.fromJson({
        'id': 'user_124',
        'userType': 'full',
        'email': 'test2@example.com',
        'displayName': 'Test 2',
        'tenantId': 'tenant_124',
        'role': 'owner',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });

      expect(seller.isSeller, true);
      expect(full.isSeller, true);
    });

    test('copyWith creates new instance with updated values', () {
      final user = UserModel.fromJson({
        'id': 'user_123',
        'userType': 'buyer',
        'email': 'test@example.com',
        'displayName': 'Test',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });

      final updated = user.copyWith(displayName: 'Updated Name', phone: '+5511999999999');

      expect(updated.displayName, 'Updated Name');
      expect(updated.phone, '+5511999999999');
      expect(updated.email, 'test@example.com'); // Unchanged
    });
  });
}
