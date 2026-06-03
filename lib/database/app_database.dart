import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _name = 'bookscan.db';
  static const _version = 2;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _name);
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE documents (
  document_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  page_count INTEGER NOT NULL DEFAULT 0,
  pdf_path TEXT,
  ocr_status TEXT NOT NULL DEFAULT 'NONE',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE scan_pages (
  page_id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_no INTEGER NOT NULL,
  original_image_path TEXT NOT NULL,
  processed_image_path TEXT NOT NULL,
  filter_type TEXT NOT NULL,
  sharpness INTEGER NOT NULL DEFAULT 40,
  ocr_status TEXT NOT NULL DEFAULT 'NONE',
  created_at INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (document_id) ON DELETE CASCADE
)''');
        await db.execute(
          'CREATE INDEX idx_pages_doc ON scan_pages(document_id, page_no)',
        );
        await db.execute('''
CREATE TABLE ocr_text (
  ocr_id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_id TEXT NOT NULL UNIQUE,
  page_no INTEGER NOT NULL,
  text_content TEXT NOT NULL,
  language TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (document_id) ON DELETE CASCADE,
  FOREIGN KEY (page_id) REFERENCES scan_pages (page_id) ON DELETE CASCADE
)''');
        await db.execute(
          'CREATE INDEX idx_ocr_doc ON ocr_text(document_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE scan_pages ADD COLUMN ocr_status TEXT NOT NULL DEFAULT 'NONE'",
          );
          await db.execute('''
CREATE TABLE ocr_text (
  ocr_id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_id TEXT NOT NULL UNIQUE,
  page_no INTEGER NOT NULL,
  text_content TEXT NOT NULL,
  language TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (document_id) ON DELETE CASCADE,
  FOREIGN KEY (page_id) REFERENCES scan_pages (page_id) ON DELETE CASCADE
)''');
          await db.execute(
            'CREATE INDEX idx_ocr_doc ON ocr_text(document_id)',
          );
        }
      },
    );
    return AppDatabase._(db);
  }

  Database get raw => _db;

  Future<void> close() => _db.close();
}
