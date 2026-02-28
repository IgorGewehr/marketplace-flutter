import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Compares two semantic version strings (e.g. "2.1.2" vs "2.1.1").
/// Returns true if [current] is older than [minimum].
bool _isVersionOlderThan(String current, String minimum) {
  final currentParts = current.split('.').map(int.tryParse).toList();
  final minimumParts = minimum.split('.').map(int.tryParse).toList();

  for (var i = 0; i < 3; i++) {
    final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
    final m = (i < minimumParts.length ? minimumParts[i] : 0) ?? 0;
    if (c < m) return true;
    if (c > m) return false;
  }
  return false; // equal
}

/// Reads Firestore `config/app` → `minVersion` and compares with the running
/// app version. Returns `true` when an update is required.
final forceUpdateProvider = FutureProvider<bool>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('app')
        .get();

    if (!doc.exists) return false;

    final minVersion = doc.data()?['minVersion'] as String?;
    if (minVersion == null || minVersion.isEmpty) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. "2.1.2"

    return _isVersionOlderThan(currentVersion, minVersion);
  } catch (_) {
    // On error (offline, etc.), allow the user through
    return false;
  }
});
