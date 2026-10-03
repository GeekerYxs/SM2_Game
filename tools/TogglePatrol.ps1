# -*- coding: utf-8 -*-
param([string]$Action = "START")

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$gameDirs = @("D:\什么什么大冒险2.0\v2.1", "D:\什么什么大冒险2.0")
$updated = $false

foreach ($g in $gameDirs) {
    $cfg = Join-Path $g "patrol_config.ini"
    if (Test-Path $cfg) {
        $lines = Get-Content $cfg -Encoding UTF8
        if ($Action -eq "START") {
            $lines = $lines -replace '^\s*Enabled\s*=.*', 'Enabled = true' -replace '^\s*Command\s*=.*', 'Command = ANCHOR'
            Set-Content $cfg $lines -Encoding UTF8
            $updated = $true
        } elseif ($Action -eq "STOP") {
            $lines = $lines -replace '^\s*Enabled\s*=.*', 'Enabled = false' -replace '^\s*Command\s*=.*', 'Command = STOP'
            Set-Content $cfg $lines -Encoding UTF8
            $updated = $true
        } elseif ($Action -eq "ANCHOR") {
            $lines = $lines -replace '^\s*Enabled\s*=.*', 'Enabled = true' -replace '^\s*Command\s*=.*', 'Command = ANCHOR' -replace '^\s*PointAX\s*=.*', 'PointAX = 0' -replace '^\s*PointBX\s*=.*', 'PointBX = 0'
            Set-Content $cfg $lines -Encoding UTF8
            $updated = $true
        }
    }
}

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
if ($Action -eq "START") {
    Write-Host "  [+] 指令已下发：巡逻已开启！" -ForegroundColor Green
    Write-Host "  [i] 队长将在 1 秒内开始在当前站位往返踱步触发暗雷。" -ForegroundColor Gray
} elseif ($Action -eq "STOP") {
    Write-Host "  [+] 指令已下发：巡逻已停止！" -ForegroundColor Yellow
    Write-Host "  [i] 队长已原地驻足。" -ForegroundColor Gray
} elseif ($Action -eq "ANCHOR") {
    Write-Host "  [+] 指令已下发：就地重新定点成功！" -ForegroundColor Cyan
    Write-Host "  [i] 队长已将当前站位设为新的巡逻原点。" -ForegroundColor Gray
}
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 2
