[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]{1,80}$')][string]$JobName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$Partition,
    [Parameter(Mandatory)][string]$WorkDir,
    [Parameter(Mandatory)][string]$Command,
    [ValidateRange(1, 8)][int]$GpuCount = 1,
    [ValidateRange(1, 64)][int]$CpuCount = 1,
    [string]$CondaEnv = '',
    [string]$AnacondaModule = '',
    [string]$LogRoot = '',
    [string]$RunRoot = '',
    [string]$SshAlias = '',
    [string]$ConfigPath = '',
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-SeuScConfig $ConfigPath
$CondaEnv = Resolve-SeuCondaEnv $CondaEnv $config
if (-not $AnacondaModule) { $AnacondaModule = [string]$config.anacondaModule }
if (-not $LogRoot) { $LogRoot = "$($config.outputRoot)/slurm_logs" }
if (-not $RunRoot) { $RunRoot = "$($config.outputRoot)/runs" }
if (-not $SshAlias) { $SshAlias = [string]$config.ssh.login }
Assert-SeuPathWithinAny $WorkDir @($config.projectRoots) 'Slurm work directory'
Assert-SeuPathWithin $LogRoot $config.outputRoot 'Slurm log root'
Assert-SeuPathWithin $RunRoot $config.outputRoot 'Run output root'
if (-not $Command.Trim() -or $Command.Length -gt 32000) { throw 'Command must contain 1-32000 characters.' }
if ($AnacondaModule -notmatch '^[A-Za-z0-9._+\-]+$') { throw 'Invalid Anaconda module name.' }
if ($SshAlias -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid SSH alias.' }

$timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
$remoteScript = "$LogRoot/submitted/$JobName-$timestamp.slurm"
$outputPath = "$LogRoot/$JobName-%j.out"
$errorPath = "$LogRoot/$JobName-%j.err"
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
$localScript = Join-Path ([IO.Path]::GetTempPath()) "seu-sc-$([Guid]::NewGuid().ToString('N')).slurm"

$template = @'
#!/bin/bash
#SBATCH --job-name=__JOB_NAME__
#SBATCH --partition=__PARTITION__
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=__CPU_COUNT__
#SBATCH --gres=gpu:__GPU_COUNT__
#SBATCH --output=__OUTPUT_PATH__
#SBATCH --error=__ERROR_PATH__

set -euo pipefail

WORK_DIR='__WORK_DIR__'
RUN_ROOT='__RUN_ROOT__'
SUBMITTED_SCRIPT='__REMOTE_SCRIPT__'
RUN_DIR="${RUN_ROOT}/${SLURM_JOB_NAME}-${SLURM_JOB_ID}"
SEU_SC_COMMAND=$(printf '%s' '__ENCODED_COMMAND__' | base64 -d)

mkdir -p "$RUN_DIR"
cp "$SUBMITTED_SCRIPT" "$RUN_DIR/job.slurm"
cd "$WORK_DIR"

unset PYTHONPATH PYTHONHOME
module purge || true
module load '__ANACONDA_MODULE__'
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate '__CONDA_ENV__'

echo "job_id=$SLURM_JOB_ID"
echo "job_name=$SLURM_JOB_NAME"
echo "node=$(hostname)"
echo "python=$(command -v python)"
python --version
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv || true
echo "work_dir=$WORK_DIR"
echo "run_dir=$RUN_DIR"
echo "command=$SEU_SC_COMMAND"

export RUN_DIR
bash -c "$SEU_SC_COMMAND"
'@

$content = $template.Replace('__JOB_NAME__', $JobName).
    Replace('__PARTITION__', $Partition).
    Replace('__CPU_COUNT__', [string]$CpuCount).
    Replace('__GPU_COUNT__', [string]$GpuCount).
    Replace('__OUTPUT_PATH__', $outputPath).
    Replace('__ERROR_PATH__', $errorPath).
    Replace('__WORK_DIR__', $WorkDir).
    Replace('__RUN_ROOT__', $RunRoot).
    Replace('__REMOTE_SCRIPT__', $remoteScript).
    Replace('__ENCODED_COMMAND__', $encodedCommand).
    Replace('__ANACONDA_MODULE__', $AnacondaModule).
    Replace('__CONDA_ENV__', $CondaEnv)

try {
    [IO.File]::WriteAllText($localScript, ($content -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))

    Write-Host "Job          : $JobName"
    Write-Host "Queue / GPUs : $Partition / $GpuCount"
    Write-Host "Remote source: $WorkDir"
    Write-Host "Command      : $Command"
    Write-Host "Log root     : $LogRoot"
    Write-Host "Run root     : $RunRoot"

    if ($Preview) {
        Write-Host '--- SLURM SCRIPT PREVIEW ---'
        Write-Output $content
        return
    }

    & ssh -o BatchMode=yes $SshAlias "test -d '$WorkDir' && mkdir -p '$LogRoot/submitted' '$RunRoot'"
    if ($LASTEXITCODE -ne 0) { throw 'Remote work directory is missing or output directories could not be created.' }

    & scp -q $localScript "${SshAlias}:$remoteScript"
    if ($LASTEXITCODE -ne 0) { throw "Could not upload Slurm script (exit $LASTEXITCODE)." }

    $submission = & ssh -o BatchMode=yes $SshAlias "cd '$WorkDir' && /usr/bin/sbatch_wrapper '$remoteScript'" 2>&1
    $submission | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Slurm submission failed with exit code $LASTEXITCODE" }

    $match = [regex]::Match(($submission -join "`n"), 'Submitted batch job\s+(\d+)')
    if (-not $match.Success) { throw 'Submission completed but no Slurm Job ID was found.' }
    $jobId = $match.Groups[1].Value

    Write-Host "JOB_ID=$jobId"
    Write-Host "SCRIPT_PATH=$remoteScript"
    Write-Host "OUT_PATH=$($outputPath.Replace('%j', $jobId))"
    Write-Host "ERR_PATH=$($errorPath.Replace('%j', $jobId))"
    Write-Host "RUN_DIR=$RunRoot/$JobName-$jobId"
}
finally {
    Remove-Item -LiteralPath $localScript -Force -ErrorAction SilentlyContinue
}

