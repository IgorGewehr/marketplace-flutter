import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job_application_model.dart';
import 'core_providers.dart';

/// My applications (buyer view)
final myJobApplicationsProvider =
    FutureProvider.autoDispose<List<JobApplicationModel>>((ref) async {
  final repo = ref.read(jobApplicationRepositoryProvider);
  return repo.getMyApplications();
});

/// Applications for a specific job (seller view)
final jobApplicationsForJobProvider =
    FutureProvider.autoDispose.family<List<JobApplicationModel>, String>((ref, jobId) async {
  final repo = ref.read(jobApplicationRepositoryProvider);
  return repo.getJobApplications(jobId: jobId);
});

/// Check if current user already applied to a job
final hasAppliedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, jobId) async {
  final apps = ref.watch(myJobApplicationsProvider).valueOrNull ?? [];
  return apps.any((a) => a.jobId == jobId && (a.isPending || a.isAccepted));
});

/// Application submit notifier
class JobApplicationNotifier extends StateNotifier<JobApplicationState> {
  final Ref _ref;

  JobApplicationNotifier(this._ref) : super(const JobApplicationState());

  Future<bool> apply({
    required String jobId,
    String? coverLetter,
    String? applicantPhone,
    String? applicantEmail,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(jobApplicationRepositoryProvider);
      final application = await repo.apply(
        jobId: jobId,
        coverLetter: coverLetter,
        applicantPhone: applicantPhone,
        applicantEmail: applicantEmail,
      );
      state = state.copyWith(isLoading: false, application: application);
      _ref.invalidate(myJobApplicationsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> withdraw(String applicationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(jobApplicationRepositoryProvider);
      await repo.withdraw(applicationId);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(myJobApplicationsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateStatus({
    required String applicationId,
    required String status,
    String? jobId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(jobApplicationRepositoryProvider);
      await repo.updateStatus(applicationId: applicationId, status: status);
      state = state.copyWith(isLoading: false);
      if (jobId != null) {
        _ref.invalidate(jobApplicationsForJobProvider(jobId));
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final jobApplicationNotifierProvider =
    StateNotifierProvider.autoDispose<JobApplicationNotifier, JobApplicationState>((ref) {
  return JobApplicationNotifier(ref);
});

class JobApplicationState {
  final bool isLoading;
  final JobApplicationModel? application;
  final String? error;

  const JobApplicationState({
    this.isLoading = false,
    this.application,
    this.error,
  });

  JobApplicationState copyWith({
    bool? isLoading,
    JobApplicationModel? application,
    String? error,
  }) {
    return JobApplicationState(
      isLoading: isLoading ?? this.isLoading,
      application: application ?? this.application,
      error: error,
    );
  }
}
