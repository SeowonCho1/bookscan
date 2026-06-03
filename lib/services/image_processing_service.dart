import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/filter_type.dart';

/// 필터·선명도를 적용해 `processed` 이미지를 만듭니다.
class ImageProcessingService {
  Future<void> writeProcessedImage({
    required String sourcePath,
    required String outputPath,
    required PageFilterType filter,
    required int sharpness,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('이미지를 읽을 수 없습니다.');
    }

    switch (filter) {
      case PageFilterType.color:
        break;
      case PageFilterType.grayscale:
        image = img.grayscale(image);
        break;
      case PageFilterType.blackWhite:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.35);
        image = _threshold(image, threshold: 128);
        break;
    }

    if (sharpness > 0) {
      image = _sharpen(image, sharpness);
    }

    final out = img.encodePng(image);
    await File(outputPath).writeAsBytes(out, flush: true);
  }

  img.Image _threshold(img.Image src, {required int threshold}) {
    final out = src.clone();
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final l = p.luminance;
        final v = l >= threshold ? 255 : 0;
        out.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    return out;
  }

  img.Image _sharpen(img.Image src, int amount) {
    final t = (amount / 100.0).clamp(0.0, 1.0);
    if (t == 0) return src;
    final w = 1.0 + 4.0 * t;
    final n = -1.0 * t;
    final kernel = [
      0.0, n, 0.0,
      n, w, n,
      0.0, n, 0.0,
    ];
    return img.convolution(src, filter: kernel, div: 1, amount: 1);
  }
}
