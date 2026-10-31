import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled font license shows up on the license page', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final noto = entries.where((e) => e.packages.contains('Noto Sans KR')).toList();
    expect(noto, hasLength(1));
    final text = noto.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains('Adobe'));
  });
}
