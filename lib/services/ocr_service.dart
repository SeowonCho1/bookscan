import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 보정 이미지 경로에서 ML Kit 온디바이스 OCR을 수행합니다 (한국어 스크립트).
class OcrService {
  Future<String> recognizeFromFile(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
