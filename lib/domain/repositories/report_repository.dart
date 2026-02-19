/// Report repository interface
library;

import '../../data/models/report_model.dart';

abstract class ReportRepository {
  /// Get all reports (admin only)
  Future<List<ReportModel>> getAllReports();

  /// Get reports by status
  Future<List<ReportModel>> getReportsByStatus(String status);

  /// Get report by ID
  Future<ReportModel?> getReportById(String reportId);

  /// Create a new report
  Future<ReportModel> createReport(ReportModel report);

  /// Update report status
  Future<void> updateReportStatus(
    String reportId,
    String status,
    String? resolution,
    String resolvedByUserId,
  );

  /// Get reports by target
  Future<List<ReportModel>> getReportsByTarget(String targetId);

  /// Check if user has already reported target
  Future<bool> hasUserReported(String userId, String targetId);
}
