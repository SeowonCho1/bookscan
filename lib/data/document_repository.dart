import 'dart:io';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/document_record.dart';
import '../models/filter_type.dart';
import '../models/ocr_text_record.dart';
import '../models/scan_page_record.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

class DocumentRepository {
  DocumentRepository(this._db, this._storage, this._imageProcessing, this._ocr);

  final AppDatabase _db;
  final StorageService _storage;
  final ImageProcessingService _imageProcessing;
  final OcrService _ocr;
  static const _uuid = Uuid();

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<List<DocumentRecord>> listDocuments() async {
    final rows = await _db.raw.rawQuery('''
SELECT d.*,
  (SELECT sp.processed_image_path FROM scan_pages sp
   WHERE sp.document_id = d.document_id
   ORDER BY sp.page_no ASC LIMIT 1) AS cover_image_path
FROM documents d
ORDER BY d.updated_at DESC
''');
    return rows.map(_rowToDocument).toList();
  }

  /// 문서명·OCR 텍스트에서 검색합니다 (대소문자 무시, LIKE).
  Future<List<DocumentRecord>> searchDocuments(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return listDocuments();
    final pattern = '%$q%';
    final sql = StringBuffer()
      ..writeln('SELECT DISTINCT')
      ..writeln('  d.document_id, d.title, d.page_count, d.pdf_path,')
      ..writeln('  d.ocr_status, d.created_at, d.updated_at,')
      ..writeln('  (SELECT sp.processed_image_path FROM scan_pages sp')
      ..writeln('   WHERE sp.document_id = d.document_id')
      ..writeln('   ORDER BY sp.page_no ASC LIMIT 1) AS cover_image_path')
      ..writeln('FROM documents d')
      ..writeln('LEFT JOIN ocr_text o ON d.document_id = o.document_id')
      ..writeln('WHERE LOWER(d.title) LIKE LOWER(?)')
      ..writeln("   OR LOWER(COALESCE(o.text_content,'')) LIKE LOWER(?)")
      ..writeln('ORDER BY d.updated_at DESC');
    final rows = await _db.raw.rawQuery(sql.toString(), [pattern, pattern]);
    return rows.map(_rowToDocument).toList();
  }

  Future<DocumentRecord?> getDocument(String documentId) async {
    final rows = await _db.raw.query(
      'documents',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToDocument(rows.first);
  }

  Future<List<ScanPageRecord>> listPages(String documentId) async {
    final rows = await _db.raw.query(
      'scan_pages',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_no ASC',
    );
    return rows.map(_rowToPage).toList();
  }

  Future<ScanPageRecord?> getPage(String pageId) async {
    final rows = await _db.raw.query(
      'scan_pages',
      where: 'page_id = ?',
      whereArgs: [pageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToPage(rows.first);
  }

  Future<List<OcrTextRecord>> listOcrTexts(String documentId) async {
    final rows = await _db.raw.query(
      'ocr_text',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_no ASC',
    );
    return rows.map(_rowToOcr).toList();
  }

  Future<String> combinedOcrText(String documentId) async {
    final rows = await listOcrTexts(documentId);
    if (rows.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) buf.writeln('\n── ${i + 1}페이지 ──\n');
      buf.write(rows[i].textContent.trim());
    }
    return buf.toString();
  }

  /// 페이지별 보정 이미지 기준 OCR (PRD OCR-002). [onProgress]는 0~1.
  Future<void> runOcrForDocument(
    String documentId, {
    void Function(double progress)? onProgress,
  }) async {
    final pages = await listPages(documentId);
    if (pages.isEmpty) return;

    await _db.raw.update(
      'documents',
      {'ocr_status': 'PROCESSING', 'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      await _db.raw.update(
        'scan_pages',
        {'ocr_status': 'PROCESSING'},
        where: 'page_id = ?',
        whereArgs: [page.pageId],
      );
      try {
        final text = await _ocr.recognizeFromFile(page.processedImagePath);
        final ts = _now();
        await _db.raw.delete(
          'ocr_text',
          where: 'page_id = ?',
          whereArgs: [page.pageId],
        );
        await _db.raw.insert('ocr_text', {
          'ocr_id': _uuid.v4(),
          'document_id': documentId,
          'page_id': page.pageId,
          'page_no': page.pageNo,
          'text_content': text,
          'language': 'ko',
          'created_at': ts,
          'updated_at': ts,
        });
        await _db.raw.update(
          'scan_pages',
          {'ocr_status': 'DONE'},
          where: 'page_id = ?',
          whereArgs: [page.pageId],
        );
      } catch (_) {
        await _db.raw.delete(
          'ocr_text',
          where: 'page_id = ?',
          whereArgs: [page.pageId],
        );
        await _db.raw.update(
          'scan_pages',
          {'ocr_status': 'FAILED'},
          where: 'page_id = ?',
          whereArgs: [page.pageId],
        );
      }
      onProgress?.call((i + 1) / pages.length);
    }

    await _recomputeDocumentOcrStatus(documentId);
  }

  Future<DocumentRecord> createDocumentFromScanPaths(
    List<String> scannerPaths, {
    String title = '새 문서',
  }) async {
    final docId = _uuid.v4();
    final now = _now();
    await _db.raw.insert('documents', {
      'document_id': docId,
      'title': title,
      'page_count': scannerPaths.length,
      'pdf_path': null,
      'ocr_status': 'NONE',
      'created_at': now,
      'updated_at': now,
    });

    var index = 0;
    for (final path in scannerPaths) {
      final ext = path.split('.').last.toLowerCase();
      final safeExt = ext.length <= 5 ? ext : 'png';
      final original = await _storage.importToDocument(
        documentId: docId,
        sourcePath: path,
        ext: safeExt,
      );
      final processed = await _storage.copyWithinDocument(
        documentId: docId,
        sourcePath: original,
      );
      await _imageProcessing.writeProcessedImage(
        sourcePath: original,
        outputPath: processed,
        filter: PageFilterType.color,
        sharpness: 40,
      );
      await _db.raw.insert('scan_pages', {
        'page_id': _uuid.v4(),
        'document_id': docId,
        'page_no': index,
        'original_image_path': original,
        'processed_image_path': processed,
        'filter_type': PageFilterType.color.storageValue,
        'sharpness': 40,
        'ocr_status': 'NONE',
        'created_at': now,
      });
      index++;
    }

    final created = await getDocument(docId);
    if (created == null) {
      throw StateError('문서를 찾을 수 없습니다.');
    }
    return created;
  }

  Future<void> appendScannedPages(
    String documentId,
    List<String> scannerPaths,
  ) async {
    if (scannerPaths.isEmpty) return;
    final existing = await listPages(documentId);
    final now = _now();
    var index = existing.length;
    for (final path in scannerPaths) {
      final ext = path.split('.').last.toLowerCase();
      final safeExt = ext.length <= 5 ? ext : 'png';
      final original = await _storage.importToDocument(
        documentId: documentId,
        sourcePath: path,
        ext: safeExt,
      );
      final processed = await _storage.copyWithinDocument(
        documentId: documentId,
        sourcePath: original,
      );
      await _imageProcessing.writeProcessedImage(
        sourcePath: original,
        outputPath: processed,
        filter: PageFilterType.color,
        sharpness: 40,
      );
      await _db.raw.insert('scan_pages', {
        'page_id': _uuid.v4(),
        'document_id': documentId,
        'page_no': index,
        'original_image_path': original,
        'processed_image_path': processed,
        'filter_type': PageFilterType.color.storageValue,
        'sharpness': 40,
        'ocr_status': 'NONE',
        'created_at': now,
      });
      index++;
    }
    final docBefore = await getDocument(documentId);
    if (docBefore?.hasPdf == true) {
      await _storage.deleteIfExists(docBefore!.pdfPath);
    }
    await _db.raw.update(
      'documents',
      {
        'page_count': index,
        'pdf_path': null,
        'ocr_status': 'NONE',
        'updated_at': now,
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> updateDocumentTitle(String documentId, String title) async {
    await _db.raw.update(
      'documents',
      {'title': title, 'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> reorderPages(
    String documentId,
    List<String> pageIdsInOrder,
  ) async {
    final docBefore = await getDocument(documentId);
    if (docBefore?.hasPdf == true) {
      await _storage.deleteIfExists(docBefore!.pdfPath);
    }
    await _db.raw.transaction((txn) async {
      for (var i = 0; i < pageIdsInOrder.length; i++) {
        await txn.update(
          'scan_pages',
          {'page_no': i},
          where: 'page_id = ? AND document_id = ?',
          whereArgs: [pageIdsInOrder[i], documentId],
        );
        await txn.update(
          'ocr_text',
          {'page_no': i},
          where: 'page_id = ?',
          whereArgs: [pageIdsInOrder[i]],
        );
      }
      await txn.update(
        'documents',
        {
          'page_count': pageIdsInOrder.length,
          'pdf_path': null,
          'updated_at': _now(),
        },
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<void> deletePage(String documentId, String pageId) async {
    final docBefore = await getDocument(documentId);
    if (docBefore?.hasPdf == true) {
      await _storage.deleteIfExists(docBefore!.pdfPath);
    }
    final page = await getPage(pageId);
    if (page == null) return;
    await _storage.deleteIfExists(page.originalImagePath);
    await _storage.deleteIfExists(page.processedImagePath);
    await _db.raw.delete(
      'scan_pages',
      where: 'page_id = ?',
      whereArgs: [pageId],
    );
    final remaining = await listPages(documentId);
    await _db.raw.transaction((txn) async {
      for (var i = 0; i < remaining.length; i++) {
        await txn.update(
          'scan_pages',
          {'page_no': i},
          where: 'page_id = ?',
          whereArgs: [remaining[i].pageId],
        );
        await txn.update(
          'ocr_text',
          {'page_no': i},
          where: 'page_id = ?',
          whereArgs: [remaining[i].pageId],
        );
      }
      await txn.update(
        'documents',
        {
          'page_count': remaining.length,
          'pdf_path': null,
          'updated_at': _now(),
        },
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    });
    await _recomputeDocumentOcrStatus(documentId);
  }

  Future<void> updatePageFilterAndSharpness({
    required String pageId,
    required PageFilterType filter,
    required int sharpness,
  }) async {
    final page = await getPage(pageId);
    if (page == null) return;
    await _clearPageOcr(pageId, page.documentId);
    await _invalidatePdfForDocument(page.documentId);
    await _imageProcessing.writeProcessedImage(
      sourcePath: page.originalImagePath,
      outputPath: page.processedImagePath,
      filter: filter,
      sharpness: sharpness.clamp(0, 100),
    );
    await _db.raw.update(
      'scan_pages',
      {
        'filter_type': filter.storageValue,
        'sharpness': sharpness.clamp(0, 100),
      },
      where: 'page_id = ?',
      whereArgs: [pageId],
    );
    await _db.raw.update(
      'documents',
      {'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [page.documentId],
    );
  }

  Future<void> applyCroppedProcessedImage({
    required String pageId,
    required String croppedFilePath,
  }) async {
    final page = await getPage(pageId);
    if (page == null) return;
    final bytes = await File(croppedFilePath).readAsBytes();
    await File(page.originalImagePath).writeAsBytes(bytes, flush: true);
    await File(page.processedImagePath).writeAsBytes(bytes, flush: true);
    try {
      await File(croppedFilePath).delete();
    } catch (_) {}
    await updatePageFilterAndSharpness(
      pageId: pageId,
      filter: page.filterType,
      sharpness: page.sharpness,
    );
  }

  Future<String> savePdf(String documentId, String fileNameHint) async {
    final pages = await listPages(documentId);
    if (pages.isEmpty) {
      throw StateError('페이지가 없습니다.');
    }
    final paths = pages.map((p) => p.processedImagePath).toList();
    final pdfPath = await _storage.pdfPathForDocument(documentId);
    final pdf = PdfService();
    await pdf.buildFromImages(imagePathsOrdered: paths, outputPath: pdfPath);
    final title = fileNameHint.trim().isEmpty ? '문서' : fileNameHint.trim();
    await _db.raw.update(
      'documents',
      {'title': title, 'pdf_path': pdfPath, 'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    return pdfPath;
  }

  Future<void> deleteDocument(String documentId) async {
    final doc = await getDocument(documentId);
    if (doc == null) return;
    final pages = await listPages(documentId);
    for (final p in pages) {
      await _storage.deleteIfExists(p.originalImagePath);
      await _storage.deleteIfExists(p.processedImagePath);
    }
    await _storage.deleteIfExists(doc.pdfPath);
    await _storage.deleteDocumentFolder(documentId);
    await _db.raw.delete(
      'documents',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> _invalidatePdfForDocument(String documentId) async {
    final doc = await getDocument(documentId);
    if (doc == null || !doc.hasPdf) return;
    await _storage.deleteIfExists(doc.pdfPath);
    await _db.raw.update(
      'documents',
      {'pdf_path': null, 'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> _clearPageOcr(String pageId, String documentId) async {
    await _db.raw.delete('ocr_text', where: 'page_id = ?', whereArgs: [pageId]);
    await _db.raw.update(
      'scan_pages',
      {'ocr_status': 'NONE'},
      where: 'page_id = ?',
      whereArgs: [pageId],
    );
    await _recomputeDocumentOcrStatus(documentId);
  }

  Future<void> _recomputeDocumentOcrStatus(String documentId) async {
    final pages = await listPages(documentId);
    if (pages.isEmpty) {
      await _db.raw.update(
        'documents',
        {'ocr_status': 'NONE', 'updated_at': _now()},
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      return;
    }
    final statuses = pages.map((p) => p.ocrStatus).toList();
    String docStatus;
    if (statuses.contains('PROCESSING')) {
      docStatus = 'PROCESSING';
    } else if (statuses.every((s) => s == 'NONE')) {
      docStatus = 'NONE';
    } else if (statuses.any((s) => s == 'DONE')) {
      docStatus = 'DONE';
    } else if (statuses.every((s) => s == 'FAILED')) {
      docStatus = 'FAILED';
    } else {
      docStatus = 'NONE';
    }
    await _db.raw.update(
      'documents',
      {'ocr_status': docStatus, 'updated_at': _now()},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  DocumentRecord _rowToDocument(Map<String, Object?> m) {
    return DocumentRecord(
      documentId: m['document_id']! as String,
      title: m['title']! as String,
      pageCount: (m['page_count'] as num?)?.toInt() ?? 0,
      pdfPath: m['pdf_path'] as String?,
      coverImagePath: m['cover_image_path'] as String?,
      ocrStatus: m['ocr_status'] as String? ?? 'NONE',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    );
  }

  ScanPageRecord _rowToPage(Map<String, Object?> m) {
    return ScanPageRecord(
      pageId: m['page_id']! as String,
      documentId: m['document_id']! as String,
      pageNo: (m['page_no'] as num).toInt(),
      originalImagePath: m['original_image_path']! as String,
      processedImagePath: m['processed_image_path']! as String,
      filterType: PageFilterType.fromStorage(m['filter_type'] as String?),
      sharpness: (m['sharpness'] as num?)?.toInt() ?? 40,
      ocrStatus: m['ocr_status'] as String? ?? 'NONE',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    );
  }

  OcrTextRecord _rowToOcr(Map<String, Object?> m) {
    return OcrTextRecord(
      ocrId: m['ocr_id']! as String,
      documentId: m['document_id']! as String,
      pageId: m['page_id']! as String,
      pageNo: (m['page_no'] as num).toInt(),
      textContent: m['text_content'] as String? ?? '',
      language: m['language'] as String? ?? 'ko',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    );
  }
}
