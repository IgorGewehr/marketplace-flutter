import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../data/models/tenant_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'tenant_provider.dart';

/// Fetches the current seller's subscription.
/// Primary source: authenticated /api/seller/profile (works even if user.tenantId is not set).
/// Fallback: public tenant endpoint via user.tenantId.
final currentSellerSubscriptionProvider =
    FutureProvider<TenantSubscription>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const TenantSubscription(plan: 'free');

  // Primary: authenticated seller profile endpoint (always has correct subscription)
  if (user.isSeller) {
    try {
      final apiClient = ref.read(apiClientProvider);
      final data = await apiClient.get<Map<String, dynamic>>(ApiConstants.sellerProfile);
      if (data['subscription'] is Map<String, dynamic>) {
        return TenantSubscription.fromJson(data['subscription'] as Map<String, dynamic>);
      }
    } catch (_) {
      // fallthrough to tenant-based lookup
    }
  }

  // Fallback: public tenant endpoint via tenantId
  if (user.tenantId != null) {
    final tenant = await ref.watch(tenantByIdProvider(user.tenantId!).future);
    return tenant?.currentSubscription ?? const TenantSubscription(plan: 'free');
  }

  return const TenantSubscription(plan: 'free');
});

/// Whether the current seller can create rental listings.
final canCreateRentalsProvider = Provider<bool>((ref) {
  final sub = ref.watch(currentSellerSubscriptionProvider).valueOrNull;
  return sub?.canCreateRentals ?? false;
});

/// Whether the current seller can create job postings.
final canCreateJobsProvider = Provider<bool>((ref) {
  final sub = ref.watch(currentSellerSubscriptionProvider).valueOrNull;
  return sub?.canCreateJobs ?? false;
});

/// Whether the current seller can create services.
final canCreateServicesProvider = Provider<bool>((ref) {
  final sub = ref.watch(currentSellerSubscriptionProvider).valueOrNull;
  return sub?.canCreateServices ?? false;
});

/// Whether the current seller can use the service agenda.
final canUseAgendaProvider = Provider<bool>((ref) {
  final sub = ref.watch(currentSellerSubscriptionProvider).valueOrNull;
  return sub?.canUseAgenda ?? false;
});

/// Current plan name for display.
final currentPlanNameProvider = Provider<String>((ref) {
  final sub = ref.watch(currentSellerSubscriptionProvider).valueOrNull;
  return sub?.planLabel ?? 'Free';
});
