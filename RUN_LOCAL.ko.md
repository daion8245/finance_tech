# Windows에서 핑거벨 실행

Flutter 앱 진입점은 `packages/app/lib/main.dart`, 백엔드는 `backend/`(FastAPI)입니다. 저장소 루트의 `pubspec.yaml`은 10개 Flutter 패키지를 관리하는 워크스페이스입니다.

## 1. 백엔드 먼저 실행

```powershell
.\run-backend.ps1
```

처음에는 `backend/.venv`를 만들고 패키지를 설치합니다. 서버는 `http://127.0.0.1:8765`에서 열리고 API 문서는 `/docs`입니다. 포트 8000은 이 PC에서 다른 프로그램(Godot MCP 서버)이 쓰고 있어 8765를 기본값으로 씁니다.

- `-Reset`: 시연 데이터를 처음 상태로 되돌리고 시작
- `-WithWeb`: Flutter 웹을 빌드해서 같은 서버에서 제공 (`http://127.0.0.1:8765`)
- `-Lan`: 같은 Wi-Fi의 휴대폰에서 접속할 수 있게 모든 네트워크 주소에 엶 (방화벽 허용 필요)
- `-Port 9000`: 다른 포트

## 2. 앱 실행

### Android (PowerShell)

```powershell
.\run-android.ps1
```

`Medium_Phone_API_37.0` 에뮬레이터를 켜고, `adb reverse tcp:8765 tcp:8765`로 기기의 `127.0.0.1:8765`를 이 PC의 백엔드에 연결한 뒤 앱을 실행합니다. 실행 중 `r`은 핫 리로드, `R`은 핫 리스타트, `q`는 종료입니다.

```powershell
.\run-android.ps1 -Device emulator-5556 -Emulator '다른_AVD_이름'
```

### 웹 (Chrome)

```powershell
.\run-web.ps1
```

Chrome에서 `http://127.0.0.1:8080`을 열고 백엔드 `http://127.0.0.1:8765`에 연결합니다. 서버만 띄우려면 `.\run-web.ps1 -Device web-server -Port 8090`.

## 서버 주소 바꾸기

`.env.local.json`에 `FINGERBELL_API_URL`이 있으면 그 값을 씁니다 (형식은 `.env.example`). 없으면 기본 주소 `http://127.0.0.1:8765`를 씁니다. 예전 Supabase 값만 들어 있는 `.env.local.json`은 더 이상 쓰지 않으니 지워도 됩니다.

## IntelliJ IDEA · Cursor / VS Code

실행 구성 **FingerBell (Android)**, **FingerBell (Web)** 을 고르면 됩니다. 백엔드는 따로 `run-backend.ps1`로 켜 두세요.

## 참고

- 실행 스크립트는 `FLUTTER_WINDOWS=false`, `FLUTTER_LINUX=false`로 Windows 데스크톱 플러그인 심볼릭 링크 준비를 건너뜁니다.
- C: 드라이브 Pub 캐시와 D: 드라이브 프로젝트 사이의 Kotlin 캐시 오류를 막기 위해 Android `gradle.properties`에 `kotlin.incremental=false`가 있습니다.
- 한글 글꼴(Noto Sans KR, OFL 1.1)은 앱에 들어 있습니다. `run-backend.ps1 -WithWeb`으로 빌드한 웹은 인터넷 없이도 글꼴·CanvasKit을 모두 이 PC의 서버에서 받습니다. 직접 빌드할 때는 `flutter build web --no-web-resources-cdn`을 쓰세요.
- 웹을 다시 빌드한 뒤에는 브라우저에서 Ctrl+F5로 새로고침하세요 (예전 빌드가 캐시에 남아 있을 수 있습니다).
