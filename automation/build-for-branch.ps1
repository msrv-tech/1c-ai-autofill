<#
.SYNOPSIS
    Сборка расширения для указанной ветки (worktree) на своей базе 1С.

.DESCRIPTION
    Обёртка над update-extension-and-run-db.ps1. Использует build-config.json
    для маппинга ветка → строка подключения, имя расширения, имя .cfe.

    Для каждой ветки нужна своя база с подходящей конфигурацией:
    - main, UNF_Rozn, UT_KA_ERP → УНФ/Розница или УТ/КА/ERP
    - UNF_Rozn_Fresh → 1С:Фреш (УНФ)

.EXAMPLE
    .\build-for-branch.ps1 -Branch UNF_Rozn -BuildFromXml
    Собрать .cfe из xml ветки UNF_Rozn, загрузить в базу UNF_Rozn, обновить БД.

.EXAMPLE
    .\build-for-branch.ps1 -Branch UNF_Rozn_Fresh -BuildFromXml -SkipRunClient
    Собрать UNF_Rozn_Fresh без запуска 1С (для CI/релиза).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('main', 'UNF_Rozn', 'UNF_Rozn_Fresh', 'UT_KA_ERP')]
    [string]$Branch,

    [string]$PlatformExe = '',
    [string]$WorktreesRoot = '',
    [switch]$BuildFromXml,
    [switch]$SkipLoadExtension,
    [switch]$SkipDbUpdate,
    [switch]$SkipRunClient,
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path $scriptDir -Parent
$worktreesRootDefault = Split-Path $projectRoot -Parent

# Загрузка .env
$envPath = Join-Path $projectRoot '.env'
if (Test-Path -LiteralPath $envPath -PathType Leaf) {
    Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$') { return }
        if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
        }
    }
}

# Конфиг: build-config.json → build-config.local.json → build-config.example.json
$configPath = $null
foreach ($name in @('build-config.json', 'build-config.local.json', 'build-config.example.json')) {
    $p = Join-Path $scriptDir $name
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $configPath = $p
        break
    }
}
if (-not $configPath) {
    Write-Error "Файл конфигурации не найден. Добавьте build-config.example.json в automation/."
    exit 1
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$branchConfig = $config.branches.$Branch
if (-not $branchConfig) {
    Write-Error "Ветка '$Branch' не найдена в конфигурации."
    exit 1
}

$wtRoot = if ($WorktreesRoot) { $WorktreesRoot } elseif ($config.worktreesRoot) { $config.worktreesRoot } else { $worktreesRootDefault }
$worktreePath = Join-Path $wtRoot $Branch
$xmlPath = Join-Path $worktreePath 'xml'
$binPath = Join-Path $worktreePath 'bin'

if (-not (Test-Path -LiteralPath $xmlPath -PathType Container)) {
    Write-Error "Каталог worktree не найден: $worktreePath"
    exit 1
}

$version = '1.8.7'
$versionXmlPath = Join-Path $xmlPath 'Configuration.xml'
if (Test-Path -LiteralPath $versionXmlPath -PathType Leaf) {
    $versionContent = Get-Content -LiteralPath $versionXmlPath -Raw -Encoding UTF8
    $i = $versionContent.IndexOf('Version>')
    if ($i -ge 0) {
        $j = $versionContent.IndexOf('<', $i + 8)
        if ($j -gt $i) { $version = $versionContent.Substring($i + 8, $j - $i - 8).Trim() }
    }
}

$cfeBasename = if ($branchConfig.cfeBasename) { $branchConfig.cfeBasename } else { "1c-ai-autofill_$($Branch.ToLower())" }
$cfeFilename = "${cfeBasename}_${version}.cfe"
$versionFolder = "${Branch}_${version}"
$versionBinPath = Join-Path $binPath $versionFolder
$extensionCfePath = Join-Path $versionBinPath $cfeFilename

$connectionString = [System.Environment]::GetEnvironmentVariable($branchConfig.connectionStringEnv, 'Process')
if (-not $connectionString) {
    Write-Error ("Для ветки '$Branch' не задана строка подключения. Добавьте в .env: " + $branchConfig.connectionStringEnv + "=File=`"путь\к\базе`";Usr=`"Администратор`";Pwd=")
    exit 1
}

if (-not (Test-Path -LiteralPath $binPath -PathType Container)) {
    New-Item -ItemType Directory -Path $binPath -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $versionBinPath -PathType Container)) {
    New-Item -ItemType Directory -Path $versionBinPath -Force | Out-Null
}

$updateScript = Join-Path $scriptDir 'update-extension-and-run-db.ps1'
$params = @{
    ConnectionString = $connectionString
    XmlPath = $xmlPath
    ExtensionCfePath = $extensionCfePath
    ExtensionName = $branchConfig.extensionName
}
if ($PlatformExe) { $params['PlatformExe'] = $PlatformExe }
if ($BuildFromXml) { $params['BuildFromXml'] = $true }
if ($SkipLoadExtension) { $params['SkipLoadExtension'] = $true }
if ($SkipDbUpdate) { $params['SkipDbUpdate'] = $true }
if ($SkipRunClient) { $params['SkipRunClient'] = $true }
if ($Wait) { $params['Wait'] = $true }

Write-Host "==> Build: $Branch"
Write-Host "    Worktree: $worktreePath"
Write-Host "    DB env: $($branchConfig.connectionStringEnv)"
Write-Host "    Output: $extensionCfePath"
Write-Host ""

& $updateScript @params
