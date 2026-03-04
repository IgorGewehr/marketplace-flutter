class JobApplicationModel {
  final String id;
  final String jobId;
  final String jobTitle;
  final String tenantId;
  final String applicantUserId;
  final String applicantName;
  final String applicantEmail;
  final String? applicantPhone;
  final String? coverLetter;
  final String status; // pending, accepted, rejected, withdrawn
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobApplicationModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.tenantId,
    required this.applicantUserId,
    required this.applicantName,
    required this.applicantEmail,
    this.applicantPhone,
    this.coverLetter,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'accepted':
        return 'Aceita';
      case 'rejected':
        return 'Recusada';
      case 'withdrawn':
        return 'Cancelada';
      default:
        return status;
    }
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isWithdrawn => status == 'withdrawn';

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    return JobApplicationModel(
      id: json['id'] as String? ?? '',
      jobId: json['jobId'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      applicantUserId: json['applicantUserId'] as String? ?? '',
      applicantName: json['applicantName'] as String? ?? '',
      applicantEmail: json['applicantEmail'] as String? ?? '',
      applicantPhone: json['applicantPhone'] as String?,
      coverLetter: json['coverLetter'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'tenantId': tenantId,
        'applicantUserId': applicantUserId,
        'applicantName': applicantName,
        'applicantEmail': applicantEmail,
        'applicantPhone': applicantPhone,
        'coverLetter': coverLetter,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
