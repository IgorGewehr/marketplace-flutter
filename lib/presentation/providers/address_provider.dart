import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/address_model.dart';
import 'core_providers.dart';

/// Address list provider with full CRUD support
class AddressNotifier extends AsyncNotifier<List<AddressModel>> {
  @override
  Future<List<AddressModel>> build() async {
    try {
      final repo = ref.read(addressRepositoryProvider);
      return await repo.getAddresses();
    } catch (e) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<AddressModel?> createAddress(AddressModel address) async {
    try {
      final repo = ref.read(addressRepositoryProvider);
      final created = await repo.createAddress(address);

      // Add to local state
      final current = state.valueOrNull ?? [];
      // If new address is default, unset others locally
      final updated = created.isDefault
          ? current.map((a) => a.copyWith(isDefault: false)).toList()
          : [...current];
      if (created.isDefault) {
        updated.add(created);
      } else {
        updated.add(created);
      }
      state = AsyncValue.data(updated);
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<AddressModel?> updateAddress(AddressModel address) async {
    try {
      final repo = ref.read(addressRepositoryProvider);
      final updated = await repo.updateAddress(address);

      final current = state.valueOrNull ?? [];
      final newList = current.map((a) {
        if (a.id == updated.id) return updated;
        // If updated became default, unset others
        if (updated.isDefault && a.isDefault) {
          return a.copyWith(isDefault: false);
        }
        return a;
      }).toList();
      state = AsyncValue.data(newList);
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      final repo = ref.read(addressRepositoryProvider);
      await repo.deleteAddress(addressId);

      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.where((a) => a.id != addressId).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setDefault(String addressId) async {
    try {
      final repo = ref.read(addressRepositoryProvider);
      final updated = await repo.setDefault(addressId);

      final current = state.valueOrNull ?? [];
      final newList = current.map((a) {
        if (a.id == addressId) return updated;
        if (a.isDefault) return a.copyWith(isDefault: false);
        return a;
      }).toList();
      state = AsyncValue.data(newList);
    } catch (e) {
      rethrow;
    }
  }
}

final addressProvider = AsyncNotifierProvider<AddressNotifier, List<AddressModel>>(
  () => AddressNotifier(),
);

/// Default address provider
final defaultAddressProvider = Provider<AddressModel?>((ref) {
  final addresses = ref.watch(addressProvider).valueOrNull ?? [];
  return addresses.where((a) => a.isDefault).firstOrNull;
});
