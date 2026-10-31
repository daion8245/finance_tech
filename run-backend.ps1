[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8765,
    # 같은 Wi-Fi의 휴대폰에서 접속할 수 있게 모든 네트워크 주소에 엽니다.
    [switch]$Lan,
    # Flutter 웹을 빌드해서 같은 서버(http://127.0.0.1:8765)에서 함께 제공합니다.
    [switch]$WithWeb,
    # 시연 데이터를 지우고 처음 상태로 시작합니다.
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'
$backend = Join-Path $PSScriptRoot 'backend'
$venv = Join-Path $backend '.venv'
$python = Join-Path $venv 'Scripts\python.exe'

if (-not (Test-Path -LiteralPath $python)) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        & $uv.Source venv $venv --python 3.13
    } else {
        $py = Get-Command python -ErrorAction SilentlyContinue
        if (-not $py) { throw 'Python 3.11 이상이 필요합니다. https://www.python.org 에서 설치하세요.' }
        & $py.Source -m venv $venv
    }
    if ($LASTEXITCODE -ne 0) { throw '가상환경을 만들지 못했습니다.' }
}

$requirements = Join-Path $backend 'requirements.txt'
$stamp = Join-Path $venv '.requirements.stamp'
$needsInstall = -not (Test-Path -LiteralPath $stamp) -or ((Get-Item $requirements).LastWriteTimeUtc -gt (Get-Item $stamp).LastWriteTimeUtc)
if ($needsInstall) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        & $uv.Source pip install --python $python -r $requirements
    } else {
        & $python -m pip install -r $requirements
    }
    if ($LASTEXITCODE -ne 0) { throw '백엔드 패키지를 설치하지 못했습니다.' }
    Set-Content -LiteralPath $stamp -Value (Get-Date -Format o) -Encoding utf8
}

if ($Reset) {
    $db = Join-Path $backend 'fingerbell.db'
    if (Test-Path -LiteralPath $db) { Remove-Item -LiteralPath $db }
}

$previousWebDir = $env:FINGERBELL_WEB_DIR
try {
    if ($WithWeb) {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        $flutterExe = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\flutter\bin\flutter.bat' }
        Push-Location (Join-Path $PSScriptRoot 'packages\app')
        try {
            $env:FLUTTER_WINDOWS = 'false'
            $env:FLUTTER_LINUX = 'false'
            # 주소를 비워 두면 웹 앱이 자신을 연 서버를 백엔드로 씁니다.
            # --no-web-resources-cdn: CanvasKit을 인터넷(CDN)이 아니라 이 서버에서 받아, 인터넷 없이도 동작합니다.
            & $flutterExe build web --release --no-web-resources-cdn
            if ($LASTEXITCODE -ne 0) { throw 'Flutter 웹 빌드에 실패했습니다.' }
        } finally {
            Pop-Location
        }
        $env:FINGERBELL_WEB_DIR = Join-Path $PSScriptRoot 'packages\app\build\web'
    }

    $hostAddress = if ($Lan) { '0.0.0.0' } else { '127.0.0.1' }
    Write-Host "FingerBell API: http://127.0.0.1:$Port/docs"
    if ($WithWeb) { Write-Host "FingerBell Web: http://127.0.0.1:$Port" }
    if ($Lan) { Write-Host '같은 Wi-Fi의 기기에서는 이 PC의 IP 주소로 접속하세요 (방화벽 허용 필요).' }

    Push-Location $backend
    try {
        & $python -m uvicorn app.asgi:app --host $hostAddress --port $Port
    } finally {
        Pop-Location
    }
} finally {
    $env:FINGERBELL_WEB_DIR = $previousWebDir
}
