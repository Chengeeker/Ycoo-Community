param(
    [string]$Apk = (Join-Path $PSScriptRoot '../app/build/outputs/apk/release/app-release.apk'),
    [string]$BuildTools = (Join-Path $env:LOCALAPPDATA 'Android/sdk/build-tools/37.0.0'),
    [string]$VersionName = '2.0.3',
    [int]$VersionCode = 86
)
$ErrorActionPreference = 'Stop'
$Apk = (Resolve-Path -LiteralPath $Apk).Path
$badging = (& (Join-Path $BuildTools 'aapt2.exe') dump badging $Apk) -join "`n"
if ($LASTEXITCODE -ne 0 -or !$badging.Contains("package: name='ycoo.net.php' versionCode='$VersionCode' versionName='$VersionName'") -or $badging -notmatch "minSdkVersion:'24'" -or $badging -notmatch "targetSdkVersion:'36'") { throw 'Unexpected APK identity or SDK configuration.' }
$signature = (& (Join-Path $BuildTools 'apksigner.bat') verify --verbose --print-certs $Apk) -join "`n"
$certificate = '3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975'
if ($LASTEXITCODE -ne 0 -or $signature -notmatch "certificate SHA-256 digest: $certificate") { throw 'APK does not have the original release signature.' }
& (Join-Path $BuildTools 'zipalign.exe') -c -P 16 4 $Apk
if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($Apk)
try {
    $names = @($archive.Entries.FullName)
    $native = @($names | Where-Object { $_ -like 'lib/*' })
    if (@($native | Where-Object { $_ -notlike 'lib/arm64-v8a/*' }).Count) { throw 'Unexpected native ABI.' }
    if (@($names | Where-Object { $_ -match 'flutter_assets|libflutter\.so|libapp\.so' }).Count) { throw 'Flutter runtime must not be packaged in Compose.' }
    foreach ($asset in @('assets/licenses.json','assets/glass/navigation_glass.agsl','assets/glass/premium_glass.agsl','assets/glass/premium_glass.frag','assets/glass/gallery_glass_button.agsl','assets/glass/gallery_glass_button.frag')) {
        if (!$archive.GetEntry($asset) -or $archive.GetEntry($asset).Length -eq 0) { throw "Missing asset: $asset" }
    }
    [pscustomobject]@{
        apk = $Apk
        version = "$VersionName+$VersionCode"
        package = 'ycoo.net.php'
        bytes = (Get-Item -LiteralPath $Apk).Length
        sha256 = (Get-FileHash -LiteralPath $Apk -Algorithm SHA256).Hash
        certificateSha256 = $certificate
        nativeLibraries = $native
        alignment16Kb = $true
        installed = $false
    } | ConvertTo-Json -Depth 4
} finally { $archive.Dispose() }
