$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$inputs=Get-Content -Raw -LiteralPath (Join-Path $root 'app/build/license-inputs.json') | ConvertFrom-Json
$rows=[Collections.Generic.List[object]]::new()
$apache=''
foreach($a in $inputs){
    $zip=[IO.Compression.ZipFile]::OpenRead($a.file)
    try{
        $texts=@($zip.Entries | Where-Object FullName -Match '(?i)(license|notice)(\.txt)?$' | ForEach-Object {$reader=[IO.StreamReader]::new($_.Open());try{$reader.ReadToEnd()}finally{$reader.Dispose()}} | Select-Object -Unique)
        if(-not $apache){$apache=$texts|Where-Object {$_ -match 'Apache License' -and $_.Length -gt 9000}|Select-Object -First 1}
        $versionDir=Split-Path (Split-Path $a.file)
        $pom=Get-ChildItem -LiteralPath $versionDir -Recurse -Filter '*.pom'|Select-Object -First 1
        $license='';$url=''
        if($pom){[xml]$p=Get-Content -Raw -LiteralPath $pom.FullName;$license=($p.project.licenses.license|ForEach-Object {$_.name}) -join ', ';$url=($p.project.licenses.license|ForEach-Object {$_.url}) -join ', '}
        if(-not $license){if($a.coordinate -match '^(androidx\.|com.google.zxing:|com.google.guava:|org.jetbrains|com.caverock:)'){$license='Apache License 2.0'}else{throw "Missing license metadata: $($a.coordinate)"}}
        $rows.Add([ordered]@{name=$a.coordinate;license=$license;url=$url;text=($texts -join "`n`n")})
    }finally{$zip.Dispose()}
}
if(-not $apache){throw 'Apache license text was not found in the resolved artifacts'}
foreach($r in $rows){if($r.license -match 'Apache' -and $r.text -notmatch 'TERMS AND CONDITIONS FOR USE'){$r.text=$apache+"`n`n"+$r.text};if(-not $r.text){throw "Missing full license: $($r.name)"}}
$rows.Add([ordered]@{name='liquid_glass_widgets:1.13.0 (ported shaders)';license='MIT License';url='';text=(Get-Content -Raw -LiteralPath (Join-Path $root 'app/src/main/assets/glass/LICENSE.txt'))})
$rows | Sort-Object {$_.name} | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'app/src/main/assets/licenses.json')
Write-Output "Saved $($rows.Count) dependency license entries."
