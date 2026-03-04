import '../../core/constants/api_constants.dart';
import '../../domain/repositories/job_application_repository.dart';
import '../datasources/api_client.dart';
import '../models/job_application_model.dart';

class JobApplicationRepositoryImpl implements JobApplicationRepository {
  final ApiClient _apiClient;

  JobApplicationRepositoryImpl(this._apiClient);

  @override
  Future<JobApplicationModel> apply({
    required String jobId,
    String? coverLetter,
    String? applicantPhone,
    String? applicantEmail,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.jobApplications,
      data: {
        'jobId': jobId,
        if (coverLetter != null) 'coverLetter': coverLetter,
        if (applicantPhone != null) 'applicantPhone': applicantPhone,
        if (applicantEmail != null) 'applicantEmail': applicantEmail,
      },
    );
    return JobApplicationModel.fromJson(response);
  }

  @override
  Future<List<JobApplicationModel>> getMyApplications({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.jobApplications,
      queryParameters: params,
    );
    final list = (response['applications'] as List<dynamic>?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => JobApplicationModel.fromJson(j))
        .toList();
  }

  @override
  Future<void> withdraw(String applicationId) async {
    await _apiClient.delete<void>(
      ApiConstants.jobApplicationById(applicationId),
    );
  }

  @override
  Future<List<JobApplicationModel>> getJobApplications({
    required String jobId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.jobApplicationsByJob(jobId),
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final list = (response['applications'] as List<dynamic>?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => JobApplicationModel.fromJson(j))
        .toList();
  }

  @override
  Future<JobApplicationModel> updateStatus({
    required String applicationId,
    required String status,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.jobApplicationStatus(applicationId),
      data: {'status': status},
    );
    return JobApplicationModel.fromJson(response);
  }

  @override
  Future<bool> hasApplied(String jobId) async {
    final apps = await getMyApplications(limit: 1, status: 'pending');
    return apps.any((a) => a.jobId == jobId);
  }
}
