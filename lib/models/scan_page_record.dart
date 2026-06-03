import 'filter_type.dart';

class ScanPageRecord {
  const ScanPageRecord({
    required this.pageId,
    required this.documentId,
    required this.pageNo,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.filterType,
    required this.sharpness,
    required this.ocrStatus,
    required this.createdAt,
  });

  final String pageId;
  final String documentId;
  final int pageNo;
  final String originalImagePath;
  final String processedImagePath;
  final PageFilterType filterType;
  /// 0–100, UI 슬라이더 (PRD 선명도).
  final int sharpness;
  final String ocrStatus;
  final DateTime createdAt;
}
