# -*- coding: utf-8 -*-
param(
    [string]$Action = "START",
    [int]$Ax = 0,
    [int]$Ay = 0,
    [int]$Bx = 0,
    [int]$By = 0
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$gameDirs = @("D:\什么什么大冒险2.0\v2.1\win32", "D:\什么什么大冒险2.0\v2.1", "D:\什么什么大冒险2.0")

function Update-PatrolConfig($path) {
    if (-not (Test-Path $path)) { return }
    $hash = [ordered]@{}
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and -not $line.StartsWith(";")) {
            if ($line -match "^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$") {
                $hash[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    
    if ($Action -eq "START") {
        $hash["Enabled"] = "true"
        if ($hash["Mode"] -ne "Custom") {
            $hash["Command"] = "ANCHOR"
        } else {
            $hash["Command"] = "START"
        }
    } elseif ($Action -eq "STOP") {
        $hash["Enabled"] = "false"
        $hash["Command"] = "STOP"
    } elseif ($Action -eq "ANCHOR") {
        $hash["Enabled"] = "true"
        $hash["Mode"] = "AutoAnchor"
        $hash["Command"] = "ANCHOR"
        $hash["PointAX"] = "0"
        $hash["PointAY"] = "0"
        $hash["PointBX"] = "0"
        $hash["PointBY"] = "0"
    } elseif ($Action -eq "CUSTOM") {
        $hash["Enabled"] = "true"
        $hash["Mode"] = "Custom"
        $hash["Command"] = "CUSTOM"
        $hash["PointAX"] = "$Ax"
        $hash["PointAY"] = "$Ay"
        $hash["PointBX"] = "$Bx"
        $hash["PointBY"] = "$By"
    }

    $outLines = @("# SMSM2 Patrol Configuration")
    foreach ($k in $hash.Keys) {
        $outLines += "$k = $($hash[$k])"
    }
    Set-Content -Path $path -Value $outLines -Encoding UTF8
}

foreach ($g in $gameDirs) {
    $cfg = Join-Path $g "patrol_config.ini"
    Update-PatrolConfig $cfg
}

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
if ($Action -eq "START") {
    Write-Host "  [+] 指令已下发：巡逻已开启！" -ForegroundColor Green
    Write-Host "  [i] 队长将在 1 秒内开始往返踱步触发暗雷。" -ForegroundColor Gray
} elseif ($Action -eq "STOP") {
    Write-Host "  [+] 指令已下发：巡逻已停止！" -ForegroundColor Yellow
    Write-Host "  [i] 队长已原地驻足。" -ForegroundColor Gray
} elseif ($Action -eq "ANCHOR") {
    Write-Host "  [+] 指令已下发：就地重新定点成功！" -ForegroundColor Cyan
    Write-Host "  [i] 队长已将当前站位设为新的巡逻原点。" -ForegroundColor Gray
} elseif ($Action -eq "CUSTOM") {
    Write-Host "  [+] 指令已下发：用户自定义巡逻坐标已设置生效！" -ForegroundColor Green
    Write-Host "  [★] 巡逻区间: 点 A ($Ax, $Ay)  <--->  点 B ($Bx, $By)" -ForegroundColor Yellow
    Write-Host "  [i] 队长将在 1 秒内开始在自定义两点之间自动寻路踱步。" -ForegroundColor Gray
}
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 2
