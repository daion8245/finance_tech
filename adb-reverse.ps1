[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8765
)

# Before-launch step of the "FingerBell (Android)" run configuration:
# makes 127.0.0.1:$Port on every connected Android device reach this PC's backend.
$androidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adbExe = Join-Path $androidSdk 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbExe)) {
    Write-Warning 'Android SDK platform-tools were not found; skipping adb reverse.'
    exit 0
}

$devices = & $adbExe devices | Select-String '^(\S+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
if (-not $devices) {
    Write-Warning 'No Android device is connected; skipping adb reverse.'
    exit 0
}

foreach ($device in $devices) {
    & $adbExe -s $device reverse "tcp:$Port" "tcp:$Port" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "adb reverse tcp:$Port -> $device"
    } else {
        Write-Warning "adb reverse failed for $device."
    }
}
exit 0
