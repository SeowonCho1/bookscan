import 'package:cunning_document_scanner/cunning_document_scanner.dart';

/// 네이티브 문서 스캐너(Android ML Kit / iOS VisionKit 계열)를 호출합니다.
class ScanService {
  Future<List<String>?> scan({required int maxPages}) {
    return CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: false,
    );
  }
}
