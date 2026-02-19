// ===========================================================================
// Fiscal Repository Implementation
// ===========================================================================

import '../../core/constants/api_constants.dart';
import '../../domain/repositories/fiscal_repository.dart';
import '../datasources/api_client.dart';

class FiscalRepositoryImpl implements FiscalRepository {
  final ApiClient _apiClient;

  FiscalRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<String> emitNFCe({
    required String orderId,
    String? customerName,
    String? customerDocument,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/fiscal/nfce',
      data: {
        'orderId': orderId,
        if (customerName != null) 'customerName': customerName,
        if (customerDocument != null) 'customerDocument': customerDocument,
      },
    );

    return response['invoiceId'] as String;
  }

  @override
  Future<String> emitNFe({
    required String orderId,
    required String customerName,
    required String customerDocument,
    required Map<String, dynamic> customerAddress,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/fiscal/nfe',
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'customerDocument': customerDocument,
        'customerAddress': customerAddress,
      },
    );

    return response['invoiceId'] as String;
  }

  @override
  Future<String> emitNFSe({
    required String description,
    required double amount,
    required String customerName,
    required String customerDocument,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/fiscal/nfse',
      data: {
        'description': description,
        'amount': amount,
        'customerName': customerName,
        'customerDocument': customerDocument,
      },
    );

    return response['invoiceId'] as String;
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoices({
    String? type,
    String? status,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/fiscal/invoices',
      queryParameters: {
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        'limit': limit,
      },
    );

    final invoices = response['invoices'] as List<dynamic>?;
    return invoices?.cast<Map<String, dynamic>>() ?? [];
  }

  @override
  Future<Map<String, dynamic>> getInvoiceById(String invoiceId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/fiscal/invoices/$invoiceId',
    );

    return response['invoice'] as Map<String, dynamic>;
  }

  @override
  Future<String> downloadInvoiceXml(String invoiceId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/fiscal/invoices/$invoiceId/xml',
    );

    return response['xmlUrl'] as String;
  }

  @override
  Future<String> downloadInvoicePdf(String invoiceId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/fiscal/invoices/$invoiceId/pdf',
    );

    return response['pdfUrl'] as String;
  }

  @override
  Future<Map<String, dynamic>> getCertificateStatus() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/fiscal/certificate/status',
    );

    return response['certificate'] as Map<String, dynamic>;
  }

  @override
  Future<void> uploadCertificate({
    required String certificateBase64,
    required String password,
  }) async {
    await _apiClient.post(
      '/api/fiscal/certificate/upload',
      data: {
        'certificate': certificateBase64,
        'password': password,
      },
    );
  }
}
