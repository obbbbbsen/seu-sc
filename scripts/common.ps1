Set-StrictMode -Version Latest

function Get-SeuScConfigPath {
    param([string]$ConfigPath = '')
    if ($ConfigPath) { return $ConfigPath }
    return Join-Path $env:LOCALAPPDATA 'seu-sc\config.json'
}

function Get-SeuScConfig {
    param([string]$ConfigPath = '')
    $resolved = Get-SeuScConfigPath $ConfigPath
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "SEU SC is not initialized. Run initialize-seu-sc.ps1 with your mentor group and card number. Expected config: $resolved"
    }
    $config = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    foreach ($name in @('mentorGroup', 'cardNumber', 'projectRoots', 'defaultProjectRoot', 'outputRoot', 'condaRoot', 'defaultCondaEnv', 'anacondaModule', 'ssh')) {
        if (-not $config.PSObject.Properties[$name]) { throw "SEU SC config is missing '$name': $resolved" }
    }
    if ([int]$config.version -lt 2) { throw "SEU SC config version is obsolete. Re-run initialize-seu-sc.ps1: $resolved" }
    return $config
}

function Assert-SeuRemotePath {
    param([Parameter(Mandatory)][string]$Value, [string]$Label = 'Remote path')
    if ($Value -notmatch '^/[A-Za-z0-9._/+\-]+$' -or $Value -match '(^|/)\.\.(/|$)') {
        throw "$Label must be an absolute path without spaces or '..': $Value"
    }
}

function Assert-SeuPathWithin {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Root,
        [string]$Label = 'Remote path'
    )
    Assert-SeuRemotePath $Value $Label
    $prefix = $Root.TrimEnd('/') + '/'
    if ($Value -ne $Root -and -not $Value.StartsWith($prefix, [StringComparison]::Ordinal)) {
        throw "$Label must be located under $Root. Received: $Value"
    }
}

function Assert-SeuPathWithinAny {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][object[]]$Roots,
        [string]$Label = 'Remote path'
    )
    Assert-SeuRemotePath $Value $Label
    foreach ($rootValue in $Roots) {
        $root = [string]$rootValue
        $prefix = $root.TrimEnd('/') + '/'
        if ($Value -eq $root -or $Value.StartsWith($prefix, [StringComparison]::Ordinal)) { return }
    }
    throw "$Label must be located under one of: $($Roots -join ', '). Received: $Value"
}

function Resolve-SeuCondaEnv {
    param(
        [string]$CondaEnv,
        [Parameter(Mandatory)]$Config
    )
    $resolved = $CondaEnv
    if (-not $resolved) { $resolved = [string]$Config.defaultCondaEnv }
    if (-not $resolved) {
        throw "No Conda environment selected. Pass -CondaEnv with an environment name under $($Config.condaRoot), or an absolute path there."
    }
    if ($resolved -notmatch '^/') {
        if ($resolved -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Conda environment name: $resolved" }
        $resolved = "$($Config.condaRoot.TrimEnd('/'))/$resolved"
    }
    Assert-SeuPathWithin $resolved ([string]$Config.condaRoot) 'Conda environment'
    return $resolved
}

