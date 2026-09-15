# Run without Python, Dart packages, or native toolchain installation.
[CmdletBinding()]
param(
    [string]$Cache = (Join-Path $env:LOCALAPPDATA 'flutter_libmwc'),
    [string]$Work,
    [string]$Flutter = 'flutter',
    [switch]$Release,
    [switch]$Network,
    [switch]$Desktop,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$checks = [Collections.Generic.List[object]]::new()
function Record($name, $status, $detail) {
    $checks.Add([pscustomobject]@{name=$name; status=$status; detail=[string]$detail})
}
function Check($name, [scriptblock]$action) {
    try { & $action } catch { Record $name 'fail' $_.Exception.Message }
}
Check 'architecture' {
    $arch = $env:PROCESSOR_ARCHITEW6432
    if (!$arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    if ($env:OS -ne 'Windows_NT' -or $arch -ne 'AMD64') {
        throw 'Use an x64 Windows host; ARM64/emulated hosts have not been validated.'
    }
    Record 'architecture' 'pass' 'Windows x64'
}
Check 'git' {
    $version = & git --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Install Git for Windows and put git.exe on PATH.' }
    Record 'git' 'pass' "$version"
}
Check 'flutter' {
    $versionText = & $Flutter --version --machine 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Flutter failed. Install Flutter and use -Flutter with its flutter.bat path.' }
    $version = ($versionText -join "`n") | ConvertFrom-Json
    $requirements = Get-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Raw
    $flutterMinimum = [regex]::Match($requirements, 'flutter:.*?>=([\d.]+)').Groups[1].Value
    $dartMinimum = [regex]::Match($requirements, 'sdk:.*?>=([\d.]+)').Groups[1].Value
    if (!$flutterMinimum -or !$dartMinimum) { throw 'Cannot read SDK minimums from pubspec.yaml.' }
    $flutterNumber = [regex]::Match($version.frameworkVersion, '^\d+\.\d+\.\d+').Value
    $dartNumber = [regex]::Match($version.dartSdkVersion, '^\d+\.\d+\.\d+').Value
    if (!$flutterNumber -or !$dartNumber -or [version]$flutterNumber -lt [version]$flutterMinimum -or
        [version]$dartNumber -lt [version]$dartMinimum -or [version]$dartNumber -ge [version]'4.0.0') {
        throw "Need Flutter >= $flutterMinimum and Dart >= $dartMinimum < 4.0.0. Found Flutter $($version.frameworkVersion), Dart $($version.dartSdkVersion)."
    }
    $workflow = Get-Content -LiteralPath (Join-Path $root '.github/workflows/reproducible-windows.yml') -Raw
    $ciVersion = [regex]::Match($workflow, "flutter-version: '([^']+)'").Groups[1].Value
    $status = if ($version.frameworkVersion -eq $ciVersion) { 'pass' } else { 'warn' }
    Record 'flutter' $status "Flutter $($version.frameworkVersion), Dart $($version.dartSdkVersion); Windows CI uses Flutter $ciVersion. Use that SDK for the closest match."
}
Check 'powershell-extraction' {
    $ps = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $result = & $ps -NoProfile -NonInteractive -Command 'Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile].FullName' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Windows PowerShell ZIP extraction unavailable: $result" }
    Record 'powershell-extraction' 'pass' 'The builder can load the Windows ZIP extraction API.'
}
function CheckStorage($name, $path, $fresh) {
    Check $name {
        $absolute = [IO.Path]::GetFullPath($path)
        if ($fresh -and (Test-Path -LiteralPath $absolute)) { throw "Choose a fresh, nonexistent work path: $absolute" }
        $ancestor = $absolute
        while (!(Test-Path -LiteralPath $ancestor)) {
            $ancestor = [IO.Path]::GetDirectoryName($ancestor)
            if (!$ancestor) { throw "No existing parent for $absolute" }
        }
        if (!(Test-Path -LiteralPath $ancestor -PathType Container)) { throw "$ancestor is not a directory." }
        # Resolve junctions/mount points using the actual containing volume.
        $volume = Get-Volume -FilePath $ancestor
        if ($volume.FileSystemType -ne 'NTFS') { throw "Use local NTFS storage for $name; $ancestor uses $($volume.FileSystemType)." }
        $probe = Join-Path $ancestor ('mwc-doctor-' + [guid]::NewGuid().ToString('N'))
        $stream = $null
        try {
            $stream = [IO.File]::Open($probe, 'CreateNew', 'ReadWrite', 'None')
            $stream.WriteByte(42)
            $stream.Lock(0, 1)
            $stream.Unlock(0, 1)
            $stream.Dispose(); $stream = $null
            [IO.File]::SetLastWriteTimeUtc($probe, [datetime]'1970-01-01T00:00:01Z')
        } finally {
            if ($stream) { $stream.Dispose() }
            if ([IO.File]::Exists($probe)) { [IO.File]::Delete($probe) }
        }
        $free = [math]::Round($volume.SizeRemaining / 1GB, 1)
        Record $name 'pass' "$absolute : NTFS, write/lock/old timestamp probe passed; $free GiB free."
        if ($free -lt 25) { Record "$name-space" 'warn' 'Allow roughly 25 GiB free for a fresh build; usage varies and retained builds require more.' }
        $parent = $absolute
        while ($parent) {
            foreach ($config in @('.cargo/config', '.cargo/config.toml')) {
                if (Test-Path -LiteralPath (Join-Path $parent $config)) {
                    throw "Ambient Cargo configuration found under $parent. Choose work/cache outside that directory tree."
                }
            }
            $parent = [IO.Path]::GetDirectoryName($parent)
        }
    }
}
CheckStorage 'cache' $Cache $false
if ($Work) { CheckStorage 'work' $Work $true }
Check 'recipe' {
    foreach ($relative in @('rust/Cargo.lock', 'rust/rust-toolchain.toml', 'reproducible/windows/build.py',
        'reproducible/windows/provision.py', 'reproducible/windows/archive.py', 'reproducible/windows/audit.py',
        'reproducible/windows/static-smoke.c', 'hook/src/windows_builder.dart')) {
        if (!(Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) { throw "Missing recipe input: $relative" }
    }
    $pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.lock.json') -Raw | ConvertFrom-Json
    if (!$pins.Count) { throw 'Empty native tool lockfile.' }
    foreach ($pin in $pins) {
        if ($pin.sha256 -notmatch '^[a-f0-9]{64}$' -or $pin.url -notmatch '^https://') { throw "Invalid tool pin: $($pin.id)" }
    }
    Record 'recipe' 'pass' "$($pins.Count) hash-pinned native tool archives. Python, Rust, MSVC, SDK, CMake and protoc are provisioned automatically; R: is unnecessary."
}
if ($Release) {
    Check 'release-checkout' {
        $head = & git -C $root rev-parse HEAD 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'Release packaging requires a Git checkout.' }
        $dirty = & git -C $root status --porcelain --untracked-files=all 2>&1
        if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Release packaging requires committed, clean inputs. Commit or separately preserve outstanding work first.' }
        Record 'release-checkout' 'pass' "Clean source commit $head. Compare against a CI run of this exact revision."
    }
}
if ($Network) {
    Check 'network' {
        # HEAD checks reachability only; the builder verifies complete downloads.
        $pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.lock.json') -Raw | ConvertFrom-Json
        $builder = Get-Content -LiteralPath (Join-Path $root 'hook/src/windows_builder.dart') -Raw
        $pythonUrl = [regex]::Match($builder, "https://www.python.org/[^']+").Value
        if (!$pythonUrl) { throw 'Cannot locate pinned Python URL.' }
        $urls = @($pythonUrl, 'https://index.crates.io/config.json', 'https://github.com', 'https://pub.dev') + @($pins | ForEach-Object { $_.url })
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        foreach ($url in ($urls | Select-Object -Unique)) {
            $null = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 20
        }
        Record 'network' 'pass' 'Pinned tool URLs and package endpoints respond. This does not verify complete downloads or every Cargo Git dependency.'
    }
} else { Record 'network' 'warn' 'Not probed. Use -Network to check tool URLs and package endpoints; builds need network access for locked Cargo sources.' }
if ($Desktop) {
    Check 'flutter-desktop' {
        $doctor = & $Flutter doctor -v 2>&1
        if ($LASTEXITCODE -ne 0) { throw "flutter doctor failed: $($doctor -join "`n")" }
        $vs = @($doctor | Where-Object { "$_" -match '^\[.*\] Visual Studio' })
        if (!$vs -or !"$($vs[0])".StartsWith('[' + [char]0x2713 + ']')) { throw "Flutter Windows desktop tools need attention. Run flutter doctor -v. $($vs -join ' ')" }
        Record 'flutter-desktop' 'pass' ($vs -join ' ')
    }
}
$failed = @($checks | Where-Object status -eq 'fail').Count
$warnings = @($checks | Where-Object status -eq 'warn').Count
$status = if ($failed) { 'blocked' } elseif ($warnings) { 'ready-with-warnings' } else { 'ready' }
$report = [ordered]@{schema=1; status=$status; root=$root; checks=@($checks.ToArray());
    scope='Host preflight only. Proof requires a clean build and artifact comparison with a successful CI run of the same revision.'}
if ($Json) { $report | ConvertTo-Json -Depth 5 } else {
    foreach ($check in $checks) { Write-Output "[$($check.status.ToUpper())] $($check.name): $($check.detail)" }
    Write-Output "Result: $status. $($report.scope)"
}
if ($failed) { exit 1 }
exit 0

