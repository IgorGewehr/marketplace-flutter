// ===========================================================================
// Fiscal Repository Interface
// Emissão e gerenciamento de notas fiscais
// ===========================================================================

abstract class FiscalRepository {
  /// Emite NFC-e (Nota Fiscal do Consumidor Eletrônica)
  Future<String> emitNFCe({
    required String orderId,
    String? customerName,
    String? customerDocument,
  });

  /// Emite NF-e (Nota Fiscal Eletrônica)
  Future<String> emitNFe({
    required String orderId,
    required String customerName,
    required String customerDocument,
    required Map<String, dynamic> customerAddress,
  });

  /// Emite NFS-e (Nota Fiscal de Serviço Eletrônica)
  Future<String> emitNFSe({
    required String description,
    required double amount,
    required String customerName,
    required String customerDocument,
  });

  /// Lista notas fiscais emitidas
  Future<List<Map<String, dynamic>>> getInvoices({
    String? type,
    String? status,
    int limit = 50,
  });

  /// Busca nota fiscal por ID
  Future<Map<String, dynamic>> getInvoiceById(String invoiceId);

  /// Download do XML da nota fiscal
  Future<String> downloadInvoiceXml(String invoiceId);

  /// Download do PDF (DANFE) da nota fiscal
  Future<String> downloadInvoicePdf(String invoiceId);

  /// Status do certificado digital
  Future<Map<String, dynamic>> getCertificateStatus();

  /// Upload de certificado digital (A1)
  Future<void> uploadCertificate({
    required String certificateBase64,
    required String password,
  });
}
