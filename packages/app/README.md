# fingerbell_app

핑거벨 Flutter 앱 셸. 기능 패키지(`feature_*`)를 화면에 연결하고, 화면 폭에 따라 두 레이아웃을 그립니다.

- **웹 (폭 900px 이상)**: 16:9 프레임, 왼쪽 사이드바 메뉴와 "바로 시연해 보기", 위쪽 시연 사용자 전환, 본문 2단, 시트는 가운데 모달.
- **모바일**: 위쪽 브랜드·사용자 전환·알림, 본문 1단, 하단 메뉴, 시트는 바텀 시트.

| 경로 | 내용 |
| :--- | :--- |
| `lib/main.dart` | 서버 주소(`FINGERBELL_API_URL`) → 저장소 → `FamilyCubit` 시작 |
| `lib/app.dart` | `FamilyCubit`·`ShellCubit` 제공, 테마(고대비), 글자 배율(어르신 17/16, 큰 글씨 1.12배) |
| `lib/shell/` | 레이아웃, 배너, 토스트, 흔들기 감지 연결, 실시간 이벤트 반응(ARS 화면 등), 시연 시나리오 |
| `lib/views/` | 어르신·아이 홈/내역/안심, 설정 |

실행 방법은 저장소 루트의 [README](../../README.md)를 보세요.

```powershell
flutter test
```
