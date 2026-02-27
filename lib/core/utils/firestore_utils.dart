import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses a date value that may come from:
/// - Firestore direct read: [Timestamp] object
/// - REST API response: ISO-8601 [String]
/// - Already parsed: [DateTime]
/// Returns null if value is null or unparseable.
DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
