# -*- coding: utf-8 -*-
# ==============================================================================
# SMSM2 Code & Patrol Tools Sync Script (sync.ps1)
# ==============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repoDir   = "d:\Codes\GG_Antigravity\smsm2-game"
$srcStrat  = Join-Path $repoDir "src\ai_fight_strategy.lua"
$srcPatrol = Join-Path $repoDir "src\map_patrol.lua"
$toolsDir  = Join-Path $repoDir "tools"

$gameDir = (Get-ChildItem -Path "D:\" -Directory -Filter "*2.0").FullName
if (-not $gameDir) {
    $gameDir = "D:\什么什么大冒险2.0"
}
Write-Host "Resolved game directory: $gameDir" -ForegroundColor Cyan

# 1. Sync Lua Scripts
$stratFiles = Get-ChildItem -Path $gameDir -Recurse -Filter "ai_fight_strategy.lua"
foreach ($f in $stratFiles) {
    Copy-Item $srcStrat -Destination $f.FullName -Force
    Write-Host "[+] Updated strategy: $($f.FullName)" -ForegroundColor Green
}

$patrolFiles = Get-ChildItem -Path $gameDir -Recurse -Filter "map_patrol.lua"
foreach ($f in $patrolFiles) {
    Copy-Item $srcPatrol -Destination $f.FullName -Force
    Write-Host "[+] Updated patrol: $($f.FullName)" -ForegroundColor Green
}

# 2. Sync Tools to Game Root
$toolFiles = @(
    "SetPatrolPoints.ps1",
    "设置巡逻坐标.bat",
    "TogglePatrol.ps1",
    "PatrolDashboard.ps1",
    "开启巡逻.bat",
    "关闭巡逻.bat",
    "就地重新定点.bat",
    "打开巡逻中控台.bat"
)

foreach ($tf in $toolFiles) {
    $srcFile = Join-Path $toolsDir $tf
    if (Test-Path $srcFile) {
        Copy-Item $srcFile -Destination (Join-Path $gameDir $tf) -Force
        Write-Host "[+] Synced tool to game root: $tf" -ForegroundColor Yellow
    }
}

# 3. Sync patrol_config.ini to candidate directories
$cfgDirs = @(
    $gameDir,
    (Join-Path $gameDir "v2.1"),
    (Join-Path $gameDir "v2.1\win32")
)
$sampleCfg = Join-Path $repoDir "src\patrol_config.ini"

foreach ($cd in $cfgDirs) {
    if (Test-Path $cd) {
        $targetCfg = Join-Path $cd "patrol_config.ini"
        if (-not (Test-Path $targetCfg)) {
            Copy-Item $sampleCfg -Destination $targetCfg -Force
            Write-Host "[+] Initialized patrol_config.ini in: $cd" -ForegroundColor Magenta
        }
    }
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "ALL SYNC COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
