[CmdletBinding()]
param(
    [string]$Device = 'emulator-5554',
    [string]$Emulator = 'Medium_Phone_API_37.0',
    [ValidateRange(1024, 65535)]
    [int]$ApiPort = 8765,
    [switch]$NoResident
)

$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot 'packages\app'
$configPath = Join-Path $PSScriptRoot '.env.local.json'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExe = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExe)) { throw 'Flutter SDK was not found. Add flutter\bin to PATH.' }
$androidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adbExe = Join-Path $androidSdk 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbExe)) { throw 'Android SDK platform-tools were not found.' }

# Only Android is prepared by this launcher; desktop builds keep their own settings.
$previousWindowsFlag = $env:FLUTTER_WINDOWS
$previousLinuxFlag = $env:FLUTTER_LINUX
try {
    $env:FLUTTER_WINDOWS = 'false'
    $env:FLUTTER_LINUX = 'false'
    Push-Location $appDirectory
    try {
        & $flutterExe pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency setup failed.' }

        $connectedDevices = & $adbExe devices
        if (-not ($connectedDevices -match ('^' + [regex]::Escape($Device) + '\s+(device|offline)$'))) {
            if (-not $Device.StartsWith('emulator-')) {
                throw "Android device '$Device' is not connected."
            }
            & $flutterExe emulators --launch $Emulator
            if ($LASTEXITCODE -ne 0) { throw "Could not launch emulator '$Emulator'." }
        }

        $bootDeadline = [DateTime]::UtcNow.AddMinutes(3)
        do {
            try {
                $bootState = & $adbExe -s $Device shell getprop sys.boot_completed 2>$null
            } catch {
                $bootState = ''
            }
            if (($bootState -join '').Trim() -eq '1') { break }
            if ([DateTime]::UtcNow -ge $bootDeadline) { throw "Timed out waiting for '$Device' to boot." }
            Start-Sleep -Seconds 2
        } while ($true)

        # 기기의 127.0.0.1:8765 을 이 PC의 핑거벨 백엔드로 연결합니다 (에뮬레이터·USB 기기 공통).
        & $adbExe -s $Device reverse "tcp:$ApiPort" "tcp:$ApiPort"
        if ($LASTEXITCODE -ne 0) { throw 'adb reverse failed.' }

        $runArguments = @('run', '-d', $Device, '--no-pub')
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
            $runArguments += "--dart-define=FINGERBELL_API_URL=http://127.0.0.1:$ApiPort"
        }
        if ($NoResident) { $runArguments += '--no-resident' }
        & $flutterExe @runArguments
        if ($LASTEXITCODE -ne 0) { throw 'Flutter app launch failed.' }
    } finally {
        Pop-Location
    }
} finally {
    $env:FLUTTER_WINDOWS = $previousWindowsFlag
    $env:FLUTTER_LINUX = $previousLinuxFlag
}
