[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LocalProject,
    [string]$RemoteProject = '',
    [string]$ProjectName = '',
    [string]$SshAlias = '',
    [string]$ConfigPath = '',
    [string[]]$AdditionalExclude = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Test-Path -LiteralPath $LocalProject -PathType Container)) {
    throw "Local project does not exist: $LocalProject"
}
$config = Get-SeuScConfig $ConfigPath
if (-not $ProjectName) { $ProjectName = Split-Path -Leaf (Resolve-Path -LiteralPath $LocalProject).Path }
if ($ProjectName -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid project name: $ProjectName" }
if (-not $RemoteProject) { $RemoteProject = "$($config.defaultProjectRoot)/projects/$ProjectName" }
Assert-SeuPathWithinAny $RemoteProject @($config.projectRoots) 'Remote project directory'
if (-not $SshAlias) { $SshAlias = [string]$config.ssh.login }
if ($SshAlias -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid SSH alias: $SshAlias" }

$resolvedLocal = (Resolve-Path -LiteralPath $LocalProject).Path
$uploadId = [Guid]::NewGuid().ToString('N')
$localArchive = Join-Path ([IO.Path]::GetTempPath()) "seu-sc-$uploadId.tar.gz"
$remoteArchive = "$RemoteProject/.seu-sc-upload-$uploadId.tar.gz"
$excludes = @(
    '.git', '.vscode', '.idea', '__pycache__', '.pytest_cache', '.mypy_cache',
    'logs', '*.pyc', '*.pyo', '*.pt', '*.pth', '*.ckpt'
) + $AdditionalExclude

try {
    Write-Host "Local source : $resolvedLocal"
    Write-Host "Remote copy : ${SshAlias}:$RemoteProject"

    $tarArgs = @('-czf', $localArchive, '-C', $resolvedLocal)
    foreach ($exclude in $excludes) {
        if ($exclude -match "[`r`n]") { throw "Invalid exclusion pattern: $exclude" }
        $tarArgs += "--exclude=$exclude"
    }
    $tarArgs += '.'
    & tar @tarArgs
    if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }

    & ssh -o BatchMode=yes $SshAlias "mkdir -p '$RemoteProject'"
    if ($LASTEXITCODE -ne 0) { throw "Could not create remote project directory." }

    & scp -q $localArchive "${SshAlias}:$remoteArchive"
    if ($LASTEXITCODE -ne 0) { throw "scp failed with exit code $LASTEXITCODE" }

    & ssh -o BatchMode=yes $SshAlias "tar -xzf '$remoteArchive' -C '$RemoteProject' && rm -f '$remoteArchive'"
    if ($LASTEXITCODE -ne 0) { throw "Remote extraction failed with exit code $LASTEXITCODE" }

    Write-Host "Synchronized source to ${SshAlias}:$RemoteProject"
    Write-Host 'Note: synchronization overlays files; stale remote-only files are not deleted.'
}
finally {
    Remove-Item -LiteralPath $localArchive -Force -ErrorAction SilentlyContinue
}

