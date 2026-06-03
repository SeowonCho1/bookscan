import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<void> buildFromImages({
    required List<String> imagePathsOrdered,
    required String outputPath,
  }) async {
    final doc = pw.Document();
    for (final path in imagePathsOrdered) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final file = File(outputPath);
    await file.writeAsBytes(await doc.save(), flush: true);
  }
}
