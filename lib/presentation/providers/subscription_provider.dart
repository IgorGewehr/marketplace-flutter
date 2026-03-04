import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant_model.dart';
import 'auth_providers.dart';
import 'tenant_provider.dart';

/// Fetches the current seller's subscription from their tenant document.
final currentSellerSubscriptionProvider =
    FutureProvider<TenantSubscription>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || user.tenantId == null) {
    return const TenantSubscription(plan: 'free');
  }
  final tenant = await ref.watch(tenantByIdProvider(user.tenantId!).future);
  return tenant?.currentSubscription ?? const TenantSubscription(plan: 'free');
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
