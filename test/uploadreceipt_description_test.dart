import 'package:flutter_test/flutter_test.dart';
import 'package:kologsoft/screens/uploadreceipt.dart';

void main() {
  group('normalizeReceiptDescription', () {
    test('trims and collapses whitespace', () {
      expect(normalizeReceiptDescription('  Milk receipt   for branch  1  '),
          'Milk receipt for branch 1');
    });

    test('keeps empty descriptions empty', () {
      expect(normalizeReceiptDescription('   '), isEmpty);
    });
  });
}
