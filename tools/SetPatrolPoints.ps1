# -*- coding: utf-8 -*-
param(
    [string]$Ax = "",
    [string]$Ay = "",
    [string]$Bx = "",
    [string]$By = ""
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$cfgPath = "D:\什么什么大冒险2.0\v2.1\patrol_config.ini"
$stPath  = "D:\什么什么大冒险2.0\v2.1\patrol_status.ini"

function Parse-IniFile($path) {
    $hash = @{}
    if (-not (Test-Path $path)) { return $hash }
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and -not $line.StartsWith(";")) {
            if ($line -match "^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$") {
                $hash[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    return $hash
}

$cfg = Parse-IniFile $cfgPath
$st  = Parse-IniFile $stPath

$curMode = if ($cfg["Mode"]) { $cfg["Mode"] } else { "AutoAnchor" }
$curAx   = if ($cfg["PointAX"]) { $cfg["PointAX"] } else { "0" }
$curAy   = if ($cfg["PointAY"]) { $cfg["PointAY"] } else { "0" }
$curBx   = if ($cfg["PointBX"]) { $cfg["PointBX"] } else { "0" }
$curBy   = if ($cfg["PointBY"]) { $cfg["PointBY"] } else { "0" }
$playerX = if ($st["PlayerX"]) { $st["PlayerX"] } else { "未探测" }
$playerY = if ($st["PlayerY"]) { $st["PlayerY"] } else { "未探测" }
$mapId   = if ($st["MapID"]) { $st["MapID"] } else { "未探测" }

Clear-Host
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "      什么什么大冒险 2.0 - 自定义巡逻坐标设置 (A点与B点)           " -ForegroundColor Yellow
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "  【当前状态参考】:" -ForegroundColor Gray
Write-Host "    当前地图: $mapId | 队长当前脚下坐标: ($playerX, $playerY)" -ForegroundColor Gray
Write-Host "    当前模式: $(if ($curMode -eq 'Custom') { '🎯 自定义坐标模式' } else { '⚡ 智能就地定点模式' })" -ForegroundColor Gray
Write-Host "    已存点 A: ($curAx, $curAy)  <--->  已存点 B: ($curBx, $curBy)" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------" -ForegroundColor DarkGray

if (-not $Ax -or -not $Ay -or -not $Bx -or -not $By) {
    Write-Host "  请输入两点坐标数值 (共 4 个正整数数字):" -ForegroundColor Green
    Write-Host ""
    $Ax = Read-Host "  [1/4] 请输入 点 A 的 X 坐标 (例如: 1200)"
    $Ay = Read-Host "  [2/4] 请输入 点 A 的 Y 坐标 (例如: 800)"
    $Bx = Read-Host "  [3/4] 请输入 点 B 的 X 坐标 (例如: 1360)"
    $By = Read-Host "  [4/4] 请输入 点 B 的 Y 坐标 (例如: 800)"
}

if ($Ax -match "^\d+$" -and $Ay -match "^\d+$" -and $Bx -match "^\d+$" -and $By -match "^\d+$") {
    $toggleScript = Join-Path $PSScriptRoot "TogglePatrol.ps1"
    if (-not (Test-Path $toggleScript)) {
        $toggleScript = "D:\什么什么大冒险2.0\TogglePatrol.ps1"
    }
    & $toggleScript -Action CUSTOM -Ax ([int]$Ax) -Ay ([int]$Ay) -Bx ([int]$Bx) -By ([int]$By)
} else {
    Write-Host ""
    Write-Host "  [!] 错误：输入的坐标必须全部为正整数数字！" -ForegroundColor Red
    Write-Host "  [i] 本次设置未生效，请重新运行脚本输入。" -ForegroundColor Gray
    Write-Host ""
}
