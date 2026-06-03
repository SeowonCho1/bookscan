class OcrTextRecord {
  const OcrTextRecord({
    required this.ocrId,
    required this.documentId,
    required this.pageId,
    required this.pageNo,
    required this.textContent,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  final String ocrId;
  final String documentId;
  final String pageId;
  final int pageNo;
  final String textContent;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;
}
