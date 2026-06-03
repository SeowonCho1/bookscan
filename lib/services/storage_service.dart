import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 스캔·PDF 파일을 앱 문서 디렉터리 하위에 보관합니다.
class StorageService {
  static const _root = 'bookscan_files';
  static const _uuid = Uuid();

  Future<Directory> get _rootDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _root));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> documentDir(String documentId) async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, documentId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String newFileName(String ext) => '${_uuid.v4()}.$ext';

  /// 외부(스캐너 임시 경로 등) 파일을 앱 저장소로 복사합니다.
  Future<String> importToDocument({
    required String documentId,
    required String sourcePath,
    String ext = 'png',
  }) async {
    final dir = await documentDir(documentId);
    final name = newFileName(ext);
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<String> copyWithinDocument({
    required String documentId,
    required String sourcePath,
    String ext = 'png',
  }) async {
    return importToDocument(
      documentId: documentId,
      sourcePath: sourcePath,
      ext: ext,
    );
  }

  Future<String> pdfPathForDocument(String documentId) async {
    final dir = await documentDir(documentId);
    return p.join(dir.path, 'document.pdf');
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<void> deleteDocumentFolder(String documentId) async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, documentId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
