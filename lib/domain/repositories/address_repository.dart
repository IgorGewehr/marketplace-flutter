import '../../data/models/address_model.dart';

/// Address Repository Interface
abstract class AddressRepository {
  /// Get all addresses for the current user
  Future<List<AddressModel>> getAddresses();

  /// Create a new address
  Future<AddressModel> createAddress(AddressModel address);

  /// Update an existing address
  Future<AddressModel> updateAddress(AddressModel address);

  /// Delete an address
  Future<void> deleteAddress(String addressId);

  /// Set an address as default
  Future<AddressModel> setDefault(String addressId);
}
