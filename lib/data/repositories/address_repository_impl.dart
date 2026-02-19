import '../../core/constants/api_constants.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/api_client.dart';
import '../models/address_model.dart';

/// Address Repository Implementation
class AddressRepositoryImpl implements AddressRepository {
  final ApiClient _apiClient;

  AddressRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.addresses,
    );

    final addresses = (response['addresses'] as List<dynamic>?)
            ?.map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return addresses;
  }

  @override
  Future<AddressModel> createAddress(AddressModel address) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.addresses,
      data: address.toJson(),
    );

    return AddressModel.fromJson(response);
  }

  @override
  Future<AddressModel> updateAddress(AddressModel address) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      ApiConstants.addressById(address.id!),
      data: address.toJson(),
    );

    return AddressModel.fromJson(response);
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    await _apiClient.delete<Map<String, dynamic>>(
      ApiConstants.addressById(addressId),
    );
  }

  @override
  Future<AddressModel> setDefault(String addressId) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.addressSetDefault(addressId),
    );

    return AddressModel.fromJson(response);
  }
}
