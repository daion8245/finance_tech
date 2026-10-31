import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱에 넣은 글꼴의 라이선스(SIL OFL 1.1)를 Flutter 라이선스 화면(showLicensePage)에 올립니다.
/// OFL은 글꼴을 배포할 때 저작권 표시와 라이선스를 사용자가 볼 수 있게 함께 두도록 요구합니다.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('packages/core_ui/assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Noto Sans KR'], text);
  });
}
