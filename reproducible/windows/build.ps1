param(
    [Parameter(Mandatory=$true)][string]$Work,
    [Parameter(Mandatory=$true)][string]$Cache,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
& $Python "$PSScriptRoot\build.py" --work $Work --cache $Cache
if ($LASTEXITCODE -ne 0) { throw "Windows native build failed ($LASTEXITCODE)" }
