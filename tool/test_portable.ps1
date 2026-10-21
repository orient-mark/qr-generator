$ErrorActionPreference = 'Stop'
$projectFolder = Split-Path -Parent $PSScriptRoot
$releaseFolder = Join-Path $projectFolder 'build\windows\x64\runner\Release'
$versionText = Get-Content -Raw -LiteralPath (Join-Path $projectFolder 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') { throw 'Missing version.' }
$portableFile = Join-Path (Split-Path -Parent $projectFolder) "OrientMark_relise\OrientMark-QR-$($Matches[1]).exe"
$testFolder = Join-Path $projectFolder 'build\portable-test\Русская папка'
$temporary = Join-Path $testFolder 'Временные файлы'
New-Item -ItemType Directory -Path $testFolder, $temporary -Force | Out-Null
$application = Join-Path $testFolder 'Одно приложение.exe'
Copy-Item -LiteralPath $portableFile -Destination $application -Force
$sentinel = Join-Path $temporary 'keep.txt'
Set-Content -LiteralPath $sentinel -Value 'Do not remove unrelated temp files.'
$originalTemp = $env:TEMP
$originalTmp = $env:TMP
$launcher = $null
$child = $null
try {
    $env:TEMP = $temporary
    $env:TMP = $temporary
    $launcher = Start-Process -FilePath $application -ArgumentList '--diagnostics' -WorkingDirectory $testFolder -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        $child = Get-Process -Name orientmark_qr -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -and $_.Path.StartsWith("$temporary\", [StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if ($child) { break }
        $launcher.Refresh()
        if ($launcher.HasExited) {
            $details = Get-Content -LiteralPath (Join-Path $temporary 'portable-error.txt') -ErrorAction SilentlyContinue
            throw "Переносимый EXE завершился раньше запуска приложения: $($launcher.ExitCode). $details"
        }
    }
    if (-not $child) { throw 'Не найден запущенный экземпляр приложения.' }
    Start-Sleep -Seconds 3
    $child.Refresh()
    if ($child.HasExited) { throw 'Приложение завершилось сразу после запуска.' }
    $unpacked = Split-Path -Parent $child.Path
    $checked = 0
    foreach ($file in (Get-ChildItem -LiteralPath $releaseFolder -Recurse -File)) {
        if ($file.Extension -in @('.pdb', '.obj', '.lib', '.exp')) { continue }
        $relative = $file.FullName.Substring($releaseFolder.Length + 1)
        $extracted = Join-Path $unpacked $relative
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $extracted).Hash) {
            throw "Поврежден файл после распаковки: $relative"
        }
        $checked++
    }
    if (-not $child.CloseMainWindow()) { throw 'Не удалось закрыть тестовый экземпляр приложения.' }
    if (-not $launcher.WaitForExit(15000)) { throw 'Переносимый запускатель не завершился после приложения.' }
    if ($launcher.ExitCode -ne 0) { throw "Код завершения переносимого EXE: $($launcher.ExitCode)" }
    if (Test-Path -LiteralPath $unpacked) { throw 'Временная папка приложения не удалена.' }
    if (-not (Test-Path -LiteralPath $sentinel)) { throw 'Удалён посторонний файл во временной папке.' }
    Write-Output "Проверено: запуск одного EXE из русского пути, $checked файлов по SHA-256, закрытие и очистка временной папки."
} finally {
    # Only stop processes started by this verification.
    if ($child) { $child.Refresh(); if (-not $child.HasExited) { Stop-Process -Id $child.Id } }
    if ($launcher) { $launcher.Refresh(); if (-not $launcher.HasExited) { Stop-Process -Id $launcher.Id } }
    $env:TEMP = $originalTemp
    $env:TMP = $originalTmp
}
