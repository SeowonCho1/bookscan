import 'package:flutter_test/flutter_test.dart';

import 'package:bookscan_app/config/app_constants.dart';

void main() {
  test('무료 모드 연속 촬영 제한은 UI·PRD 기본값 10', () {
    expect(kFreeContinuousScanLimit, 10);
  });
}
