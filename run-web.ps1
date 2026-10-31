[CmdletBinding()]
param(
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Device = 'chrome',
    [ValidateRange(1024, 65535)]
    [int]$Port = 8080,
    # 핑거벨 백엔드 주소 (.\run-backend.ps1 로 먼저 실행)
    [string]$ApiUrl = 'http://127.0.0.1:8765'
)

$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot 'packages\app'
$configPath = Join-Path $PSScriptRoot '.env.local.json'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExe = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExe)) { throw 'Flutter SDK was not found. Add flutter\bin to PATH.' }

$previousWindowsFlag = $env:FLUTTER_WINDOWS
$previousLinuxFlag = $env:FLUTTER_LINUX
try {
    $env:FLUTTER_WINDOWS = 'false'
    $env:FLUTTER_LINUX = 'false'
    Push-Location $appDirectory
    try {
        & $flutterExe pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency setup failed.' }

        $runArguments = @('run', '-d', $Device, '--web-hostname=127.0.0.1', "--web-port=$Port", '--no-pub')
        # .env.local.json에 FINGERBELL_API_URL이 있으면 그 값을, 없으면 기본 주소를 씁니다.
        $useConfig = $false
        if (Test-Path -LiteralPath $configPath) {
            try {
                $useConfig = [bool](Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).FINGERBELL_API_URL
            } catch {
                $useConfig = $false
            }
        }
        if ($useConfig) {
            $runArguments += "--dart-define-from-file=$configPath"
        } else {
            $runArguments += "--dart-define=FINGERBELL_API_URL=$ApiUrl"
        }
        Write-Host "FingerBell web: http://127.0.0.1:$Port  (API: $ApiUrl)"
        & $flutterExe @runArguments
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web launch failed.' }
    } finally {
        Pop-Location
    }
} finally {
    $env:FLUTTER_WINDOWS = $previousWindowsFlag
    $env:FLUTTER_LINUX = $previousLinuxFlag
}
