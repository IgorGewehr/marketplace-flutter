import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant_model.dart';
import 'core_providers.dart';

/// Fetches a tenant by ID.
/// Returns null when the API explicitly returns no data (404-style).
/// Rethrows network/server errors so the UI error builder handles them correctly.
final tenantByIdProvider = FutureProvider.family<TenantModel?, String>((ref, id) async {
  final repo = ref.read(tenantRepositoryProvider);
  return await repo.getById(id);
});
