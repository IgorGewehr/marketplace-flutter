import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/service_model.dart';
import '../../domain/repositories/service_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Filter options for my services
enum MyServicesFilter { all, active, paused, inactive }

/// Search query for my services
final myServicesSearchProvider = StateProvider<String>((ref) => '');

/// Filter state for my services
final myServicesFilterProvider = StateProvider<MyServicesFilter>((ref) => MyServicesFilter.all);

/// Provider for seller's own services
final myServicesProvider = AsyncNotifierProvider<MyServicesNotifier, List<ServiceModel>>(() {
  return MyServicesNotifier();
});

/// Filtered services based on search and filter
final filteredMyServicesProvider = Provider<AsyncValue<List<ServiceModel>>>((ref) {
  final servicesAsync = ref.watch(myServicesProvider);
  final search = ref.watch(myServicesSearchProvider).toLowerCase();
  final filter = ref.watch(myServicesFilterProvider);

  return servicesAsync.whenData((services) {
    var filtered = services;

    // Apply search filter
    if (search.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(search) ||
              s.description.toLowerCase().contains(search))
          .toList();
    }

    // Apply status filter
    switch (filter) {
      case MyServicesFilter.active:
        filtered = filtered.where((s) => s.status == 'active' && s.isAvailable).toList();
        break;
      case MyServicesFilter.paused:
        filtered = filtered.where((s) => s.status == 'draft').toList();
        break;
      case MyServicesFilter.inactive:
        filtered = filtered.where((s) => s.status == 'inactive' || !s.isAvailable).toList();
        break;
      case MyServicesFilter.all:
        break;
    }

    return filtered;
  });
});

class MyServicesNotifier extends AsyncNotifier<List<ServiceModel>> {
  ServiceRepository get _repository => ref.read(serviceRepositoryProvider);

  @override
  Future<List<ServiceModel>> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return [];

    try {
      final response = await _repository.getSellerServices(limit: 50);
      return response.services;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> createService(CreateServiceRequest request) async {
    state = await AsyncValue.guard(() async {
      final newService = await _repository.create(request);
      final current = state.valueOrNull ?? [];
      return [newService, ...current];
    });
  }

  Future<void> updateService(String serviceId, UpdateServiceRequest request) async {
    state = await AsyncValue.guard(() async {
      final updatedService = await _repository.update(serviceId, request);
      final current = state.valueOrNull ?? [];
      return current.map((s) => s.id == serviceId ? updatedService : s).toList();
    });
  }

  Future<void> toggleServiceStatus(String serviceId) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final service = current.firstWhereOrNull((s) => s.id == serviceId);
      if (service == null) return current;
      final newStatus = service.status == 'active' ? 'draft' : 'active';

      final updatedService = await _repository.update(
        serviceId,
        UpdateServiceRequest(status: newStatus),
      );

      return current.map((s) => s.id == serviceId ? updatedService : s).toList();
    });
  }

  Future<void> toggleServiceAvailability(String serviceId) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final service = current.firstWhereOrNull((s) => s.id == serviceId);
      if (service == null) return current;

      final updatedService = await _repository.update(
        serviceId,
        UpdateServiceRequest(isAvailable: !service.isAvailable),
      );

      return current.map((s) => s.id == serviceId ? updatedService : s).toList();
    });
  }

  Future<void> deleteService(String serviceId) async {
    state = await AsyncValue.guard(() async {
      await _repository.delete(serviceId);
      final current = state.valueOrNull ?? [];
      return current.where((s) => s.id != serviceId).toList();
    });
  }

  Future<void> uploadImages(
    String serviceId,
    List<String> imagePaths, {
    String category = 'profile',
  }) async {
    state = await AsyncValue.guard(() async {
      final uploadedImages = await _repository.uploadImages(
        serviceId,
        imagePaths,
        category: category,
      );

      final current = state.valueOrNull ?? [];
      return current.map((s) {
        if (s.id == serviceId) {
          if (category == 'portfolio') {
            return s.copyWith(
              portfolioImages: [...s.portfolioImages, ...uploadedImages],
            );
          } else {
            return s.copyWith(
              images: [...s.images, ...uploadedImages],
            );
          }
        }
        return s;
      }).toList();
    });
  }

  Future<void> deleteImage(
    String serviceId,
    String imageId, {
    String category = 'profile',
  }) async {
    state = await AsyncValue.guard(() async {
      await _repository.deleteImage(serviceId, imageId, category: category);

      final current = state.valueOrNull ?? [];
      return current.map((s) {
        if (s.id == serviceId) {
          if (category == 'portfolio') {
            return s.copyWith(
              portfolioImages: s.portfolioImages.where((img) => img.id != imageId).toList(),
            );
          } else {
            return s.copyWith(
              images: s.images.where((img) => img.id != imageId).toList(),
            );
          }
        }
        return s;
      }).toList();
    });
  }
}

/// Statistics for seller's services
final myServicesStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final servicesAsync = ref.watch(myServicesProvider);

  return servicesAsync.maybeWhen(
    data: (services) {
      final activeCount = services.where((s) => s.status == 'active').length;
      final draftCount = services.where((s) => s.status == 'draft').length;
      final inactiveCount = services.where((s) => s.status == 'inactive').length;

      final totalViews = services.fold<int>(
        0,
        (sum, s) => sum + (s.marketplaceStats?.views ?? 0),
      );

      final totalCompletedJobs = services.fold<int>(
        0,
        (sum, s) => sum + (s.marketplaceStats?.completedJobs ?? 0),
      );

      final avgRating = services.isEmpty
          ? 0.0
          : services.fold<double>(
                0.0,
                (sum, s) => sum + (s.marketplaceStats?.rating ?? 0),
              ) /
              services.length;

      return {
        'total': services.length,
        'active': activeCount,
        'draft': draftCount,
        'inactive': inactiveCount,
        'totalViews': totalViews,
        'totalCompletedJobs': totalCompletedJobs,
        'avgRating': avgRating,
      };
    },
    orElse: () => {
      'total': 0,
      'active': 0,
      'draft': 0,
      'inactive': 0,
      'totalViews': 0,
      'totalCompletedJobs': 0,
      'avgRating': 0.0,
    },
  );
});
