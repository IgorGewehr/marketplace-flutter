import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant_model.dart';
import 'core_providers.dart';

/// Fetches a tenant by ID — returns null on error (safe fallback)
final tenantByIdProvider = FutureProvider.family<TenantModel?, String>((ref, id) async {
  try {
    final repo = ref.read(tenantRepositoryProvider);
    return await repo.getById(id);
  } catch (_) {
    return null;
  }
});
