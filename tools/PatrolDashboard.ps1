# -*- coding: utf-8 -*-
# ==============================================================================
# SMSM2 独立巡逻与多智能体战术中控台 (PowerShell 原生无依赖版)
# ==============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$gameDir = "D:\什么什么大冒险2.0\v2.1"
$cfgPath = Join-Path $gameDir "patrol_config.ini"
$stPath  = Join-Path $gameDir "patrol_status.ini"
$logDir  = Join-Path $gameDir "logs"

function Parse-IniFile($path) {
    $hash = @{}
    if (-not (Test-Path $path)) { return $hash }
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and -not $line.StartsWith(";")) {
            if ($line -match "^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$") {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim()
                if ($v -eq "true") { $hash[$k] = $true }
                elseif ($v -eq "false") { $hash[$k] = $false }
                elseif ($v -match "^\d+$") { $hash[$k] = [int]$v }
                else { $hash[$k] = $v }
            }
        }
    }
    return $hash
}

function Write-IniFile($path, $hash) {
    $lines = @("# SMSM2 Patrol Configuration")
    foreach ($k in $hash.Keys) {
        $v = $hash[$k]
        if ($v -is [bool]) { $vStr = if ($v) { "true" } else { "false" } }
        else { $vStr = "$v" }
        $lines += "$k = $vStr"
    }
    Set-Content -Path $path -Value $lines -Encoding UTF8
}

function Show-Dashboard {
    Clear-Host
    $cfg = Parse-IniFile $cfgPath
    $st  = Parse-IniFile $stPath

    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "     什么什么大冒险 2.0 - 巡逻控制与多智能体协同中控台 (v2.0)       " -ForegroundColor Yellow
    Write-Host "====================================================================" -ForegroundColor Cyan

    $leaderName = if ($cfg["LeaderName"]) { $cfg["LeaderName"] } else { "伏地魔" }
    $isEnabled  = if ($null -ne $cfg["Enabled"]) { $cfg["Enabled"] } else { $false }
    $mapId      = if ($st["MapID"]) { $st["MapID"] } else { 0 }
    $curX       = if ($st["PlayerX"]) { $st["PlayerX"] } else { 0 }
    $curY       = if ($st["PlayerY"]) { $st["PlayerY"] } else { 0 }
    $pAx        = if ($st["PointAX"]) { $st["PointAX"] } else { 0 }
    $pAy        = if ($st["PointAY"]) { $st["PointAY"] } else { 0 }
    $pBx        = if ($st["PointBX"]) { $st["PointBX"] } else { 0 }
    $pBy        = if ($st["PointBY"]) { $st["PointBY"] } else { 0 }
    $inFight    = if ($null -ne $st["InFight"]) { $st["InFight"] } else { $false }

    Write-Host "  👑 当前带队队长: " -NoNewline; Write-Host "$leaderName" -ForegroundColor Green
    Write-Host "  🗺️ 当前地图编号: " -NoNewline; Write-Host "MapID = $(if ($mapId -gt 0) { $mapId } else { '实时探测中' })" -ForegroundColor Magenta
    Write-Host "  📍 队长当前坐标: " -NoNewline; Write-Host "X = $curX, Y = $curY" -ForegroundColor White
    
    Write-Host "  🚦 巡逻运行状态: " -NoNewline
    if ($inFight) {
        Write-Host "⚔️ 战斗中 (巡逻自动冻结挂起)" -ForegroundColor Yellow
    } elseif ($isEnabled) {
        Write-Host "🚶 巡逻中 (在点A与点B之间往返踱步)" -ForegroundColor Green
    } else {
        Write-Host "⏹ 已停止" -ForegroundColor Red
    }

    Write-Host "  🎯 巡逻目标区间: " -NoNewline; Write-Host "点A($pAx, $pAy) <===> 点B($pBx, $pBy)" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------------------" -ForegroundColor DarkGray

    Write-Host "  👥 在线多客户端协同战况:" -ForegroundColor White
    if (Test-Path $logDir) {
        0..4 | ForEach-Object {
            $lName = if ($_ -eq 0) { "client.log" } else { "client$_.log" }
            $lp = Join-Path $logDir $lName
            if (Test-Path $lp) {
                $lines = Get-Content $lp -Tail 25 -Encoding default -ErrorAction SilentlyContinue
                $pos = "未知"; $role = "队员"; $action = "待命"
                if ($lines) {
                    foreach ($l in $lines) {
                        if ($l -match "myPos=(\d+)") { $pos = $matches[1] }
                        if ($l -match "扫射" -or $l -match "连珠箭") { $role = "【大号主力-猎人】" }
                        elseif ($l -match "群体治疗术") { $role = "【保姆小号-医仙】" }
                        if ($l -match "释放 \[群体治疗术") { $action = "释放 [群体治疗术]" }
                        elseif ($l -match "释放技能: 扫射") { $action = "释放 [扫射]" }
                        elseif ($l -match "释放技能: 连珠箭") { $action = "释放 [连珠箭]" }
                        elseif ($l -match "待机待命") { $action = "防御待命" }
                    }
                }
                Write-Host "    - $lName `t 位号:$pos `t 角色:$role `t 近期动作:$action" -ForegroundColor Gray
            }
        }
    }
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  【操作控制选项】:" -ForegroundColor Yellow
    Write-Host "    [1] 🚀 开启巡逻 (以队长当前站位就地智能定点往返)" -ForegroundColor Green
    Write-Host "    [2] ⏹ 停止巡逻 (原地驻足)" -ForegroundColor Red
    Write-Host "    [3] 🎯 就地重新定点 (把当前站位设为新的巡逻原点)" -ForegroundColor Cyan
    Write-Host "    [4] 👑 更换队长角色名 (换号时一键指定新队长)" -ForegroundColor Magenta
    Write-Host "    [5] 🔄 刷新面板数据" -ForegroundColor White
    Write-Host "    [0] 退出中控台" -ForegroundColor Gray
    Write-Host "====================================================================" -ForegroundColor Cyan
}

do {
    Show-Dashboard
    $choice = Read-Host "请输入操作选项编号 [0-5]"
    $cfg = Parse-IniFile $cfgPath
    switch ($choice) {
        "1" {
            $cfg["Enabled"] = $true
            $cfg["Command"] = "ANCHOR"
            Write-IniFile $cfgPath $cfg
            Write-Host "[+] 指令已下发：巡逻已开启！队长将在 1 秒内开始在当前站位往返踱步。" -ForegroundColor Green
            Start-Sleep -Seconds 1.5
        }
        "2" {
            $cfg["Enabled"] = $false
            $cfg["Command"] = "STOP"
            Write-IniFile $cfgPath $cfg
            Write-Host "[+] 指令已下发：巡逻已停止！队长已原地驻足。" -ForegroundColor Yellow
            Start-Sleep -Seconds 1.5
        }
        "3" {
            $cfg["Enabled"] = $true
            $cfg["Command"] = "ANCHOR"
            $cfg["PointAX"] = 0
            $cfg["PointBX"] = 0
            Write-IniFile $cfgPath $cfg
            Write-Host "[+] 指令已下发：正在重新抓取脚下坐标定点..." -ForegroundColor Cyan
            Start-Sleep -Seconds 1.5
        }
        "4" {
            $newName = Read-Host "请输入新的队长角色名 (如: 伏地魔 / 先驱01)"
            if ($newName) {
                $cfg["LeaderName"] = $newName
                Write-IniFile $cfgPath $cfg
                Write-Host "[+] 队长已成功更换为: $newName" -ForegroundColor Green
                Start-Sleep -Seconds 1.5
            }
        }
        "5" { }
        "0" { break }
        default {
            Write-Host "[!] 无效选项，请重新输入。" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "0")
