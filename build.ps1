[CmdletBinding()]
param(
    [switch]$CreateSigningKeyOnly,
    [switch]$SkipSigning
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectFolder = $PSScriptRoot
$envFile = Join-Path $projectFolder '.env'

function Invoke-Native {
    param([string]$Executable, [string[]]$NativeArguments)
    & $Executable @NativeArguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Executable (exit $LASTEXITCODE)." }
}

function New-LocalSigningKey {
    $identity = Read-BuildSettings -RequireIdentity
    $keyFolder = Join-Path $projectFolder '.local\signing'
    $pfx = Join-Path $keyFolder 'OrientMark-code-signing.pfx'
    if (Test-Path -LiteralPath $pfx) { throw 'A signing key already exists; refusing to overwrite it.' }
    New-Item -ItemType Directory -Path $keyFolder -Force | Out-Null
    $random = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($random) } finally { $rng.Dispose() }
    $password = [Convert]::ToBase64String($random)
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    if ($identity.ContainsKey('SIGNING_PFX_PATH') -and $identity['SIGNING_PFX_PATH'] -and
        (Test-Path -LiteralPath $identity['SIGNING_PFX_PATH'])) {
        throw 'A configured signing key already exists; refusing to replace it.'
    }
    $developerSubject = $identity['APP_DEVELOPER'].Replace('"', '""')
    $organizationSubject = $identity['APP_ORGANIZATION'].Replace('"', '""')
    $parameters = @{
        Type = 'CodeSigningCert'
        Subject = "CN=""$developerSubject"", O=""$organizationSubject"""
        FriendlyName = 'OrientMark QR code signing'
        KeyAlgorithm = 'RSA'
        KeyLength = 3072
        HashAlgorithm = 'SHA256'
        KeyExportPolicy = 'Exportable'
        CertStoreLocation = 'Cert:\CurrentUser\My'
        NotAfter = (Get-Date).AddYears(3)
    }
    $certificate = New-SelfSignedCertificate @parameters
    Export-PfxCertificate -Cert $certificate -FilePath $pfx -Password $securePassword | Out-Null
    Export-Certificate -Cert $certificate -FilePath (Join-Path $keyFolder 'OrientMark-code-signing.cer') | Out-Null
    $settings = @(
        "APP_DEVELOPER=$($identity['APP_DEVELOPER'])",
        "APP_ORGANIZATION=$($identity['APP_ORGANIZATION'])",
        'SIGNING_PFX_PATH=.local/signing/OrientMark-code-signing.pfx',
        "SIGNING_PFX_PASSWORD=$password",
        "SIGNING_TIMESTAMP_URL=$($identity['SIGNING_TIMESTAMP_URL'])"
    )
    [IO.File]::WriteAllLines($envFile, $settings, [Text.UTF8Encoding]::new($false))
    Write-Host 'Created a local self-signed certificate using publisher settings from .env.'
    Write-Host 'Private files: .local/signing/ and .env. Back them up privately; never publish them.'
}

function Read-BuildSettings {
    param([switch]$RequireSigning, [switch]$RequireIdentity)
    $settings = @{ APP_DEVELOPER = ''; APP_ORGANIZATION = '' }
    if (-not (Test-Path -LiteralPath $envFile)) {
        if ($RequireSigning -or $RequireIdentity) {
            throw 'Copy .env.example to .env and configure publisher settings first.'
        }
        return $settings
    }
    foreach ($entry in Get-Content -LiteralPath $envFile) {
        $entry = $entry.Trim()
        if (-not $entry -or $entry.StartsWith('#')) { continue }
        if ($entry -notmatch '^([A-Z_]+)=(.*)$') { throw 'Invalid .env syntax; expected KEY=value.' }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and
            (($value.StartsWith('"') -and $value.EndsWith('"')) -or
             ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($name -notin @('APP_DEVELOPER', 'APP_ORGANIZATION', 'SIGNING_PFX_PATH',
            'SIGNING_PFX_PASSWORD', 'SIGNING_TIMESTAMP_URL')) {
            throw "Unknown setting: $name"
        }
        $settings[$name] = $value
    }
    foreach ($name in @('APP_DEVELOPER', 'APP_ORGANIZATION')) {
        if ($settings[$name] -match '[\x00-\x1F\x7F]') {
            throw "Control characters are not allowed in $name."
        }
        if (($RequireSigning -or $RequireIdentity) -and
            (-not $settings[$name] -or $settings[$name] -in @('Your Name', 'Your Organization'))) {
            throw "Set $name in .env."
        }
    }
    if ($settings.ContainsKey('SIGNING_PFX_PATH') -and $settings['SIGNING_PFX_PATH'] -and
        -not [IO.Path]::IsPathRooted($settings['SIGNING_PFX_PATH'])) {
        $settings['SIGNING_PFX_PATH'] = Join-Path $projectFolder $settings['SIGNING_PFX_PATH']
    }
    if ($RequireSigning) {
        foreach ($name in @('SIGNING_PFX_PATH', 'SIGNING_PFX_PASSWORD')) {
            if (-not $settings.ContainsKey($name) -or -not $settings[$name] -or
                $settings[$name] -eq 'replace-with-your-local-password') {
                throw "Set $name in the private .env file."
            }
        }
        if (-not (Test-Path -LiteralPath $settings['SIGNING_PFX_PATH'])) { throw 'Signing PFX not found.' }
    }
    return $settings
}

function ConvertTo-RcString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Sign-Application {
    param([string]$Path, [hashtable]$Settings, [string]$SignTool)
    $parameters = @('sign', '/q', '/fd', 'SHA256', '/f', $Settings['SIGNING_PFX_PATH'],
        '/p', $Settings['SIGNING_PFX_PASSWORD'], '/d', 'OrientMark QR')
    if ($Settings.ContainsKey('SIGNING_TIMESTAMP_URL') -and $Settings['SIGNING_TIMESTAMP_URL']) {
        $parameters += @('/tr', $Settings['SIGNING_TIMESTAMP_URL'], '/td', 'SHA256')
    }
    $parameters += $Path
    # Never echo arguments: the PFX password must not enter logs or resources.
    Invoke-Native $SignTool $parameters
    $signature = Get-AuthenticodeSignature -FilePath $Path
    if (-not $signature.SignerCertificate) { throw 'The output has no signing certificate.' }
    if ($signature.Status -notin @('Valid', 'NotTrusted', 'UnknownError')) {
        throw "Unexpected Authenticode status: $($signature.Status)"
    }
}

$originalDeveloper = [Environment]::GetEnvironmentVariable('ORIENTMARK_APP_DEVELOPER', 'Process')
$originalOrganization = [Environment]::GetEnvironmentVariable('ORIENTMARK_APP_ORGANIZATION', 'Process')
Push-Location $projectFolder
try {
    if ($CreateSigningKeyOnly -and $SkipSigning) {
        throw 'CreateSigningKeyOnly and SkipSigning cannot be used together.'
    }
    if ($CreateSigningKeyOnly) { New-LocalSigningKey; return }
    $settings = Read-BuildSettings -RequireSigning:(-not $SkipSigning)
    $spec = Get-Content -Raw -LiteralPath (Join-Path $projectFolder 'pubspec.yaml')
    if ($spec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { throw 'Expected version: x.y.z+build in pubspec.yaml.' }
    $version = $Matches[1]
    $buildNumber = $Matches[2]
    $fileVersion = "$version.$buildNumber"
    $releaseFolder = Join-Path $projectFolder 'build\windows\x64\runner\Release'
    $workFolder = Join-Path $projectFolder 'build\portable'
    $distribution = Join-Path (Split-Path -Parent $projectFolder) 'OrientMark_relise'
    $outputName = "OrientMark-QR-$version.exe"
    if ($SkipSigning) { $outputName = "OrientMark-QR-$version-unsigned.exe" }
    $output = Join-Path $distribution $outputName

    $vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio\Installer\vswhere.exe'
    $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $visualStudio) { throw 'Visual Studio C++ build tools were not found.' }
    $vcvars = Join-Path $visualStudio 'VC\Auxiliary\Build\vcvars64.bat'
    $signTool = $null
    if (-not $SkipSigning) {
        $sdkRoot = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
        $signTool = Get-ChildItem -LiteralPath $sdkRoot -Filter signtool.exe -Recurse -File |
            Where-Object { $_.Directory.Name -eq 'x64' } | Sort-Object FullName -Descending | Select-Object -First 1
        if (-not $signTool) { throw 'Install SignTool from the Windows SDK.' }
    }

    Invoke-Native 'flutter' @('pub', 'get')
    $publicIdentity = @{
        APP_VERSION = $version
        APP_DEVELOPER = $settings['APP_DEVELOPER']
        APP_ORGANIZATION = $settings['APP_ORGANIZATION']
    }
    $identityFile = Join-Path $projectFolder '.dart_tool/app_identity.json'
    [IO.File]::WriteAllText($identityFile, ($publicIdentity | ConvertTo-Json),
        [Text.UTF8Encoding]::new($false))
    [Environment]::SetEnvironmentVariable('ORIENTMARK_APP_DEVELOPER',
        $settings['APP_DEVELOPER'], 'Process')
    [Environment]::SetEnvironmentVariable('ORIENTMARK_APP_ORGANIZATION',
        $settings['APP_ORGANIZATION'], 'Process')
    $application = Join-Path $releaseFolder 'orientmark_qr.exe'
    # Force relinking so an earlier signed EXE cannot enter an unsigned package.
    if ($SkipSigning -and (Test-Path -LiteralPath $application)) {
        Remove-Item -LiteralPath $application
    }
    Invoke-Native 'flutter' @('build', 'windows', '--release', "--build-name=$version",
        "--build-number=$buildNumber", "--dart-define-from-file=$identityFile")
    if ($SkipSigning -and (Get-AuthenticodeSignature -FilePath $application).Status -ne 'NotSigned') {
        throw 'The rebuilt application must be unsigned.'
    }

    $redist = Get-ChildItem -LiteralPath (Join-Path $visualStudio 'VC\Redist\MSVC') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $redist) { throw 'The MSVC redistributable directory was not found.' }
    $crt = Get-ChildItem -LiteralPath (Join-Path $redist.FullName 'x64') -Directory |
        Where-Object { $_.Name -match '^Microsoft\.VC\d+\.CRT$' } | Select-Object -First 1
    if (-not $crt) { throw 'The x64 CRT directory was not found.' }
    foreach ($library in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        Copy-Item -LiteralPath (Join-Path $crt.FullName $library) -Destination $releaseFolder -Force
    }
    $obsoleteNotices = Join-Path $releaseFolder 'THIRD_PARTY_NOTICES.md'
    if (Test-Path -LiteralPath $obsoleteNotices) {
        Remove-Item -LiteralPath $obsoleteNotices
    }
    foreach ($notice in @('LICENSE', 'THIRD_PARTY_LICENSES.md')) {
        Copy-Item -LiteralPath (Join-Path $projectFolder $notice) -Destination $releaseFolder -Force
    }
    if (-not $SkipSigning) { Sign-Application $application $settings $signTool.FullName }

    New-Item -ItemType Directory -Path $workFolder, $distribution -Force | Out-Null
    $directives = @('.OPTION EXPLICIT', '.Set Cabinet=ON', '.Set Compress=ON',
        '.Set CompressionType=LZX', '.Set CompressionMemory=21', '.Set MaxDiskSize=0',
        '.Set MaxCabinetSize=0', '.Set CabinetNameTemplate=payload.cab',
        ".Set DiskDirectoryTemplate=""$workFolder""",
        ".Set RptFileName=""$(Join-Path $workFolder 'payload.rpt')""",
        ".Set InfFileName=""$(Join-Path $workFolder 'payload.inf')""")
    foreach ($file in Get-ChildItem -LiteralPath $releaseFolder -File -Recurse | Sort-Object FullName) {
        if ($file.Extension -in @('.pdb', '.obj', '.lib', '.exp')) { continue }
        $relative = $file.FullName.Substring($releaseFolder.Length + 1)
        $directives += """$($file.FullName)"" ""$relative"""
    }
    $ddf = Join-Path $workFolder 'payload.ddf'
    $directives | Set-Content -LiteralPath $ddf -Encoding utf8
    $cabOutput = & "$env:SystemRoot\System32\makecab.exe" /V1 /F $ddf 2>&1
    $cabOutput | Set-Content -LiteralPath (Join-Path $workFolder 'makecab.log')
    if ($LASTEXITCODE -ne 0) { throw 'CAB packaging failed. See build/portable/makecab.log.' }

    $icon = (Join-Path $projectFolder 'windows\runner\resources\app_icon.ico').Replace('\', '/')
    $manifest = (Join-Path $projectFolder 'windows\runner\runner.exe.manifest').Replace('\', '/')
    $numericVersion = $fileVersion.Replace('.', ',')
    $organizationRc = ConvertTo-RcString $settings['APP_ORGANIZATION']
    $developerRc = ConvertTo-RcString $settings['APP_DEVELOPER']
    $copyright = 'MIT License.'
    if ($settings['APP_DEVELOPER'] -or $settings['APP_ORGANIZATION']) {
        $copyright = "Copyright (c) $((Get-Date).Year) $($settings['APP_DEVELOPER']), $($settings['APP_ORGANIZATION']). MIT License."
    }
    $copyrightRc = ConvertTo-RcString $copyright
    $resource = @"
#include <windows.h>
#pragma code_page(65001)
101 RCDATA "payload.cab"
102 ICON "$icon"
1 RT_MANIFEST "$manifest"
VS_VERSION_INFO VERSIONINFO
FILEVERSION $numericVersion
PRODUCTVERSION $numericVersion
FILEFLAGSMASK VS_FFI_FILEFLAGSMASK
FILEFLAGS 0
FILEOS VOS__WINDOWS32
FILETYPE VFT_APP
BEGIN
 BLOCK "StringFileInfo"
 BEGIN
  BLOCK "040904e4"
  BEGIN
   VALUE "CompanyName", "$organizationRc\0"
   VALUE "Author", "$developerRc\0"
   VALUE "FileDescription", "OrientMark QR portable application\0"
   VALUE "FileVersion", "$version\0"
   VALUE "ProductVersion", "$version\0"
   VALUE "ProductName", "OrientMark QR\0"
   VALUE "OriginalFilename", "$outputName\0"
   VALUE "LegalCopyright", "$copyrightRc\0"
  END
 END
 BLOCK "VarFileInfo"
 BEGIN
  VALUE "Translation", 0x409, 1252
 END
END
"@
    $resource | Set-Content -LiteralPath (Join-Path $workFolder 'launcher.rc') -Encoding utf8
    $source = Join-Path $projectFolder 'tool\portable\launcher.cpp'
    $compileScript = @"
@echo off
call "$vcvars"
if errorlevel 1 exit /b 1
rc.exe /nologo launcher.rc
if errorlevel 1 exit /b 1
cl.exe /nologo /std:c++17 /EHsc /O2 /MT /utf-8 /DUNICODE /D_UNICODE "$source" launcher.res /Fe:"$output" /link /SUBSYSTEM:WINDOWS cabinet.lib ole32.lib user32.lib
exit /b %errorlevel%
"@
    $compileFile = Join-Path $workFolder 'compile.cmd'
    $compileScript | Set-Content -LiteralPath $compileFile -Encoding utf8
    Push-Location $workFolder
    try { Invoke-Native $env:ComSpec @('/d', '/c', $compileFile) } finally { Pop-Location }
    if (-not $SkipSigning) { Sign-Application $output $settings $signTool.FullName }
    if ($SkipSigning -and (Get-AuthenticodeSignature -FilePath $output).Status -ne 'NotSigned') {
        throw 'The portable launcher must be unsigned.'
    }
    Write-Host "Ready: $output"
    if ($SkipSigning) {
        Write-Host 'The application and portable launcher are unsigned.'
    } else {
        Write-Host 'Both executables are signed. A self-signed certificate does not establish public Windows trust.'
    }
} finally {
    [Environment]::SetEnvironmentVariable('ORIENTMARK_APP_DEVELOPER', $originalDeveloper, 'Process')
    [Environment]::SetEnvironmentVariable('ORIENTMARK_APP_ORGANIZATION', $originalOrganization, 'Process')
    Pop-Location
}
