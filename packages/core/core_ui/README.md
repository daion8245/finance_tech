# core_ui

핑거벨 디자인 시스템. 모든 것은 `package:core_ui/core_ui.dart`에서 가져옵니다.

- **색 토큰** `FbColors` (`context.fb`): 파랑은 기본 동작, 빨강은 SOS·위험에만 씁니다. `FbColors.highContrast`는 고대비 모드.
- **테마** `FbTheme.build(highContrast:)`.
- **글꼴** `FbTheme.fontFamily` = 앱에 넣은 Noto Sans KR 가변 글꼴(`assets/fonts/NotoSansKR-VF.ttf`, SIL OFL 1.1, 라이선스 `assets/fonts/OFL.txt`). `FontWeight`가 글꼴의 wght 축(100~900)에 그대로 적용됩니다. 버튼처럼 `textStyle`을 직접 정하는 곳은 테마 글꼴이 이어지지 않으므로 `fontFamily: FbTheme.fontFamily`를 꼭 넣으세요 (빠지면 웹에서 한글이 네모로 보입니다). 앱 시작 때 `registerFontLicenses()`를 불러 라이선스 화면에 올립니다.
- **글자** `FbText`: 시안의 rem 크기를 16px 기준으로 옮긴 스타일.
- **레이아웃** `FbLayout`(웹/모바일 판단), `FbView`, `FbSplit`(웹 2단 · 모바일 순서 지정).
- **시트** `showFbSheet`: 모바일은 바텀 시트, 웹은 모달. `SheetHead`.
- **위젯** `FbCard`, `FbButton`, `FbButtonRow`, `FbToggle`, `FbSegmented`, `FbFilterChips`, `FbOptionRow`, `FbSettingRow`, `FbListRow`, `TxLogo`, `FbRowLink`, `FbBanner`, `ResultIcon`, `CenterBlock`, `FbRail`, `RiskBox`, `CountdownText`, `Brand`.
- **형식** `won`, `wonOrHidden`, `formatWhen`, `formatCountdown`, `formatMinSec`, `ThousandsFormatter`.
