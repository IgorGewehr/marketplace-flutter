import '../../data/models/job_application_model.dart';

abstract class JobApplicationRepository {
  /// Apply to a job (buyer)
  Future<JobApplicationModel> apply({
    required String jobId,
    String? coverLetter,
    String? applicantPhone,
    String? applicantEmail,
  });

  /// List current user's applications (buyer)
  Future<List<JobApplicationModel>> getMyApplications({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Withdraw an application (buyer)
  Future<void> withdraw(String applicationId);

  /// List applications for a job (seller)
  Future<List<JobApplicationModel>> getJobApplications({
    required String jobId,
    int page = 1,
    int limit = 20,
  });

  /// Update application status (seller: accepted/rejected)
  Future<JobApplicationModel> updateStatus({
    required String applicationId,
    required String status,
  });

  /// Check if user already applied to a job
  Future<bool> hasApplied(String jobId);
}
