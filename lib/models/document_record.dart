class DocumentRecord {
  const DocumentRecord({
    required this.documentId,
    required this.title,
    required this.pageCount,
    this.pdfPath,
    this.coverImagePath,
    required this.ocrStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String documentId;
  final String title;
  final int pageCount;
  final String? pdfPath;
  /// 목록용 첫 페이지 보정 이미지 경로 (없으면 null).
  final String? coverImagePath;
  final String ocrStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;
}
