[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkDir,
    [string]$Command = '',
    [string]$CondaEnv = '',
    [string]$AnacondaModule = '',
    [string]$SshAlias = '',
    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-SeuScConfig $ConfigPath
$CondaEnv = Resolve-SeuCondaEnv $CondaEnv $config
if (-not $AnacondaModule) { $AnacondaModule = [string]$config.anacondaModule }
if (-not $SshAlias) { $SshAlias = [string]$config.ssh.gpu }
Assert-SeuPathWithinAny $WorkDir @($config.projectRoots) 'Interactive work directory'
if ($AnacondaModule -notmatch '^[A-Za-z0-9._+\-]+$') { throw 'Invalid Anaconda module name.' }
if ($SshAlias -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid SSH alias.' }

$setup = "unset PYTHONPATH PYTHONHOME; module purge >/dev/null 2>&1 || true; module load '$AnacondaModule'; source `"`$(conda info --base)/etc/profile.d/conda.sh`"; conda activate '$CondaEnv'; cd '$WorkDir'; echo node=`$(hostname); echo python=`$(command -v python); python --version; nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv"

if ($Command) {
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    $remote = "$setup; SEU_SC_COMMAND=`$(printf '%s' '$encodedCommand' | base64 -d); bash -c `"`$SEU_SC_COMMAND`""
    & ssh -tt $SshAlias $remote
}
else {
    $remote = "$setup; exec bash --noprofile --norc -i"
    & ssh -tt $SshAlias $remote
}
if ($LASTEXITCODE -ne 0) { throw "Interactive GPU command failed with exit code $LASTEXITCODE" }

