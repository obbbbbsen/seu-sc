[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$MentorGroup,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$CardNumber,
    [string]$AnacondaModule = 'anaconda3-2024.10-1',
    [string[]]$ProjectRoots = @(),
    [string]$DefaultProjectRoot = '',
    [string]$OutputRoot = '',
    [string]$CondaRoot = '',
    [string]$DefaultCondaEnv = '',
    [string]$JumpAlias = 'seu-jump',
    [string]$LoginAlias = 'seu-login',
    [string]$GpuAlias = 'seu-gpu',
    [string]$ConfigPath = '',
    [switch]$CheckSsh
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'common.ps1')

foreach ($value in @($AnacondaModule, $JumpAlias, $LoginAlias, $GpuAlias)) {
    if ($value -notmatch '^[A-Za-z0-9._+\-]+$') { throw "Invalid configuration value: $value" }
}

$share2Root = "/seu_share2/home/$MentorGroup/$CardNumber"
$shareRoot = "/seu_share/home/$MentorGroup/$CardNumber"
if (-not $ProjectRoots.Count) { $ProjectRoots = @($share2Root, $shareRoot) }
if (-not $DefaultProjectRoot) { $DefaultProjectRoot = [string]$ProjectRoots[0] }
if (-not $OutputRoot) { $OutputRoot = "/seu_nvme/home/$MentorGroup/$CardNumber" }
if (-not $CondaRoot) { $CondaRoot = "$share2Root/.conda/envs" }
foreach ($root in $ProjectRoots) { Assert-SeuRemotePath $root 'Project root' }
if ($DefaultProjectRoot -notin $ProjectRoots) { throw 'DefaultProjectRoot must exactly match one configured ProjectRoots entry.' }
Assert-SeuRemotePath $OutputRoot 'Output root'
Assert-SeuRemotePath $CondaRoot 'Conda root'
if ($DefaultCondaEnv) {
    if ($DefaultCondaEnv -notmatch '^/') {
        if ($DefaultCondaEnv -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid default Conda environment name.' }
        $DefaultCondaEnv = "$CondaRoot/$DefaultCondaEnv"
    }
    Assert-SeuPathWithin $DefaultCondaEnv $CondaRoot 'Default Conda environment'
}
$targetPath = Get-SeuScConfigPath $ConfigPath
$config = [ordered]@{
    version = 2
    mentorGroup = $MentorGroup
    cardNumber = $CardNumber
    projectRoots = @($ProjectRoots)
    defaultProjectRoot = $DefaultProjectRoot
    outputRoot = $OutputRoot
    condaRoot = $CondaRoot
    defaultCondaEnv = $DefaultCondaEnv
    anacondaModule = $AnacondaModule
    ssh = [ordered]@{
        jump = $JumpAlias
        login = $LoginAlias
        gpu = $GpuAlias
    }
    updatedAt = (Get-Date).ToString('o')
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
[IO.File]::WriteAllText($targetPath, ($config | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

Write-Host "Config       : $targetPath"
Write-Host "Project roots: $($ProjectRoots -join ', ')"
Write-Host "Default root : $DefaultProjectRoot"
Write-Host "Output root  : $OutputRoot"
Write-Host "Conda root   : $CondaRoot"
Write-Host "Default env  : $(if ($DefaultCondaEnv) { $DefaultCondaEnv } else { '(choose per project/run)' })"

if ($CheckSsh) {
    Write-Host 'Checking stable login SSH path...'
    & ssh -o BatchMode=yes -o ConnectTimeout=12 $LoginAlias 'hostname; printf "HOME=%s\n" "$HOME"'
    if ($LASTEXITCODE -ne 0) {
        throw "SSH check failed for '$LoginAlias'. Read references/ssh-setup.md before remote work."
    }
    Write-Host "SSH alias '$LoginAlias' is ready. The dynamic '$GpuAlias' alias is checked only when interactive GPU work is requested."
}

