[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+$')][string]$JobId,
    [string]$JobName = '',
    [string]$LogRoot = '',
    [ValidateRange(1, 10000)][int]$Lines = 100,
    [switch]$Follow,
    [string]$SshAlias = '',
    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-SeuScConfig $ConfigPath
if (-not $LogRoot) { $LogRoot = "$($config.outputRoot)/slurm_logs" }
if (-not $SshAlias) { $SshAlias = [string]$config.ssh.login }
Assert-SeuPathWithin $LogRoot $config.outputRoot 'Slurm log root'
if ($JobName -and $JobName -notmatch '^[A-Za-z0-9_.-]{1,80}$') { throw 'Invalid job name.' }
if ($SshAlias -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid SSH alias.' }

$outPath = if ($JobName) { "$LogRoot/$JobName-$JobId.out" } else { '' }
$template = @'
echo '--- SLURM STATUS ---'
sjob -j __JOB_ID__ || true
echo '--- LOG PATHS ---'
OUT_PATH='__OUT_PATH__'
if [ -z "$OUT_PATH" ]; then
  OUT_PATH=$(find '__LOG_ROOT__' -maxdepth 1 -type f -name '*-__JOB_ID__.out' -print -quit)
fi
if [ -z "$OUT_PATH" ]; then
  echo 'Output file has not been created yet.'
  exit 0
fi
ERR_PATH="${OUT_PATH%.out}.err"
echo "OUT=$OUT_PATH"
echo "ERR=$ERR_PATH"
echo '--- STDERR ---'
if [ -s "$ERR_PATH" ]; then tail -n __LINES__ "$ERR_PATH"; else echo '(empty or not created)'; fi
echo '--- STDOUT ---'
__TAIL_COMMAND__
'@
$tailCommand = if ($Follow) { 'tail -n __LINES__ -F "$OUT_PATH"' } else { 'tail -n __LINES__ "$OUT_PATH"' }
$remote = $template.Replace('__JOB_ID__', $JobId).
    Replace('__OUT_PATH__', $outPath).
    Replace('__LOG_ROOT__', $LogRoot).
    Replace('__LINES__', [string]$Lines).
    Replace('__TAIL_COMMAND__', $tailCommand.Replace('__LINES__', [string]$Lines))

$sshArgs = @()
if ($Follow) { $sshArgs += '-tt' }
$sshArgs += @('-o', 'BatchMode=yes', $SshAlias, $remote)
& ssh @sshArgs
if ($LASTEXITCODE -ne 0) { throw "Monitoring command failed with exit code $LASTEXITCODE" }

