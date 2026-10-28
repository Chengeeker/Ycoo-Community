$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$flutter = 'D:\flutter_sdk\bin\flutter.bat'
$logDirectory = Join-Path $project 'build\logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$logPath = Join-Path $logDirectory ('release-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
if (!(Test-Path (Join-Path $project 'android\key.properties'))) { throw 'Missing local signing configuration. Configure the BKS release key; debug signing is not allowed.' }
$letter = @('X','W','V','U','T') | Where-Object { !(Test-Path "$($_):\") } | Select-Object -First 1
if (!$letter) { throw 'No free temporary build drive.' }
& subst.exe "$($letter):" $project
if ($LASTEXITCODE -ne 0) { throw 'Cannot create temporary ASCII build path.' }
$previousJavaOptions=$env:JAVA_TOOL_OPTIONS
$previousJavaHome=$env:JAVA_HOME
Start-Transcript -Path $logPath -Force | Out-Null
try {
    Push-Location "$($letter):\"
    if (!(Test-Path '.\lib\main.dart')) { throw 'Mapped path is not the expected project.' }
    $env:JAVA_HOME='D:\jdk17'
    $env:JAVA_TOOL_OPTIONS="$previousJavaOptions -Djdk.net.unixdomain.tmpdir=C:\Windows\Temp -Dfile.encoding=UTF-8"
    $dep=Join-Path $project 'build\app\intermediates\flutter\release\flutter_build.d'
    if(Test-Path -LiteralPath $dep) { Remove-Item -LiteralPath $dep }
    # Keep all Material glyphs used through liquid-glass icon widgets.
    & $flutter build apk --release --target-platform android-arm64 --no-pub --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
    $apk=Join-Path "$($letter):\" 'build\app\outputs\flutter-apk\app-release.apk'
    $tools=Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\36.0.0'
    $badging=(& (Join-Path $tools 'aapt.exe') dump badging $apk) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='ycoo.net.php'" -or $badging -notmatch "native-code: 'arm64-v8a'" -or $badging -match "'armeabi-v7a'|'x86_64'|'x86'") { throw 'APK identity or ABI verification failed.' }
    & (Join-Path $tools 'apksigner.bat') verify --verbose $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & (Join-Path $tools 'zipalign.exe') -c -P 16 -v 4 $apk | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
    $versionLine=Get-Content (Join-Path $project 'pubspec.yaml') | Where-Object {$_ -match '^version:'}
    $version=($versionLine -split ':',2)[1].Trim().Split('+')[0]
    $output=Join-Path $project "源社区_v$version.apk"
    Copy-Item -LiteralPath $apk -Destination $output -Force
    $hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    "$hash  $(Split-Path -Leaf $output)" | Set-Content -Encoding utf8 (Join-Path $project 'release.sha256')
    Get-ChildItem -LiteralPath $project -File -Filter '*.apk' |
        Where-Object { $_.FullName -ne $output } |
        Remove-Item -Force
    $oldReleases = Join-Path $project 'previous-releases'
    if (Test-Path -LiteralPath $oldReleases) {
        Get-ChildItem -LiteralPath $oldReleases -File -Filter '*.apk' -Recurse |
            Remove-Item -Force
    }
    Write-Output "Verified APK: $output"
} finally {
    Pop-Location
    & subst.exe "$($letter):" /D
    $env:JAVA_TOOL_OPTIONS=$previousJavaOptions
    $env:JAVA_HOME=$previousJavaHome
    Stop-Transcript | Out-Null
}


