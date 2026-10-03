# -*- coding: utf-8 -*-
# ==============================================================================
# SMSM2 独立巡逻与多智能体战术中控台 (PowerShell 原生无依赖版)
# ==============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$targetDirs = @("D:\什么什么大冒险2.0\v2.1\win32", "D:\什么什么大冒险2.0\v2.1", "D:\什么什么大冒险2.0")
$gameDir = "D:\什么什么大冒险2.0\v2.1"
$cfgPath = Join-Path $gameDir "patrol_config.ini"
$stPath  = Join-Path $gameDir "patrol_status.ini"
$logDir  = Join-Path $gameDir "logs"

function Parse-IniFile($path) {
    $hash = [ordered]@{}
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
    foreach ($d in $targetDirs) {
        $p = Join-Path $d "patrol_config.ini"
        Set-Content -Path $p -Value $lines -Encoding UTF8
    }
}

function Show-Dashboard {
    Clear-Host
    $cfg = Parse-IniFile $cfgPath
    $st  = @{}
    foreach ($d in $targetDirs) {
        $sp = Join-Path $d "patrol_status.ini"
        if (Test-Path $sp) {
            $st = Parse-IniFile $sp
            break
        }
    }

    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "     什么什么大冒险 2.0 - 巡逻控制与多智能体协同中控台 (v2.1)       " -ForegroundColor Yellow
    Write-Host "====================================================================" -ForegroundColor Cyan

    $leaderName = if ($cfg["LeaderName"]) { $cfg["LeaderName"] } else { "伏地魔1" }
    $isEnabled  = if ($null -ne $cfg["Enabled"]) { $cfg["Enabled"] } else { $false }
    $pMode      = if ($st["Mode"]) { $st["Mode"] } elseif ($cfg["Mode"]) { $cfg["Mode"] } else { "AutoAnchor" }
    $mapId      = if ($st["MapID"]) { $st["MapID"] } else { 0 }
    $curX       = if ($st["PlayerX"]) { $st["PlayerX"] } else { 0 }
    $curY       = if ($st["PlayerY"]) { $st["PlayerY"] } else { 0 }
    $pAx        = if ($st["PointAX"]) { $st["PointAX"] } elseif ($cfg["PointAX"]) { $cfg["PointAX"] } else { 0 }
    $pAy        = if ($st["PointAY"]) { $st["PointAY"] } elseif ($cfg["PointAY"]) { $cfg["PointAY"] } else { 0 }
    $pBx        = if ($st["PointBX"]) { $st["PointBX"] } elseif ($cfg["PointBX"]) { $cfg["PointBX"] } else { 0 }
    $pBy        = if ($st["PointBY"]) { $st["PointBY"] } elseif ($cfg["PointBY"]) { $cfg["PointBY"] } else { 0 }
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

    Write-Host "  🎯 巡逻目标区间: " -NoNewline
    Write-Host "点A($pAx, $pAy) <===> 点B($pBx, $pBy) [$(if ($pMode -eq 'Custom') { '🎯 自定义坐标模式' } else { '⚡ 智能定点模式' })]" -ForegroundColor Cyan
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
                        elseif ($l -match "烈爆术" -or $l -match "流火") { $role = "【大号主力-火法】" }
                        if ($l -match "释放 \[群体治疗术") { $action = "释放 [群体治疗术]" }
                        elseif ($l -match "释放技能: 扫射") { $action = "释放 [扫射]" }
                        elseif ($l -match "释放技能: 连珠箭") { $action = "释放 [连珠箭]" }
                        elseif ($l -match "释放法术: 烈爆术") { $action = "释放 [烈爆术]" }
                        elseif ($l -match "待机待命") { $action = "防御待命" }
                    }
                }
                Write-Host "    - $lName `t 位号:$pos `t 角色:$role `t 近期动作:$action" -ForegroundColor Gray
            }
        }
    }
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  【操作控制选项】:" -ForegroundColor Yellow
    Write-Host "    [1] 🚀 开启巡逻 (自动定点或恢复已存坐标)" -ForegroundColor Green
    Write-Host "    [2] ⏹ 停止巡逻 (原地驻足)" -ForegroundColor Red
    Write-Host "    [3] ⚡ 就地重新定点 (重置为以当前站位就地智能定点)" -ForegroundColor Cyan
    Write-Host "    [4] 🎯 自定义设置两点坐标 (手动输入 A 点与 B 点 4 个坐标数字)" -ForegroundColor Yellow
    Write-Host "    [5] 👑 更换队长角色名 (换号时一键指定新队长)" -ForegroundColor Magenta
    Write-Host "    [6] 🔄 刷新面板数据" -ForegroundColor White
    Write-Host "    [0] 退出中控台" -ForegroundColor Gray
    Write-Host "====================================================================" -ForegroundColor Cyan
}

do {
    Show-Dashboard
    $choice = Read-Host "请输入操作选项编号 [0-6]"
    $cfg = Parse-IniFile $cfgPath
    switch ($choice) {
        "1" {
            $cfg["Enabled"] = $true
            if ($cfg["Mode"] -ne "Custom") {
                $cfg["Command"] = "ANCHOR"
            } else {
                $cfg["Command"] = "START"
            }
            Write-IniFile $cfgPath $cfg
            Write-Host "[+] 指令已下发：巡逻已开启！" -ForegroundColor Green
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
            $cfg["Mode"] = "AutoAnchor"
            $cfg["Command"] = "ANCHOR"
            $cfg["PointAX"] = 0
            $cfg["PointAY"] = 0
            $cfg["PointBX"] = 0
            $cfg["PointBY"] = 0
            Write-IniFile $cfgPath $cfg
            Write-Host "[+] 指令已下发：已重置为就地智能定点模式，正在重新抓取脚下坐标..." -ForegroundColor Cyan
            Start-Sleep -Seconds 1.5
        }
        "4" {
            Write-Host ""
            Write-Host "--- 自定义设置巡逻两点坐标 ---" -ForegroundColor Cyan
            $ax = Read-Host "  [1/4] 请输入 点 A 的 X 坐标"
            $ay = Read-Host "  [2/4] 请输入 点 A 的 Y 坐标"
            $bx = Read-Host "  [3/4] 请输入 点 B 的 X 坐标"
            $by = Read-Host "  [4/4] 请输入 点 B 的 Y 坐标"
            if ($ax -match "^\d+$" -and $ay -match "^\d+$" -and $bx -match "^\d+$" -and $by -match "^\d+$") {
                $cfg["Enabled"] = $true
                $cfg["Mode"] = "Custom"
                $cfg["Command"] = "CUSTOM"
                $cfg["PointAX"] = [int]$ax
                $cfg["PointAY"] = [int]$ay
                $cfg["PointBX"] = [int]$bx
                $cfg["PointBY"] = [int]$by
                Write-IniFile $cfgPath $cfg
                Write-Host "[+] 自定义坐标设置成功：点A($ax, $ay) <-> 点B($bx, $by)！" -ForegroundColor Green
                Write-Host "[i] 队长将在 1 秒内开始在自定义两点之间自动寻路踱步。" -ForegroundColor Gray
            } else {
                Write-Host "[!] 错误：坐标输入无效，必须全部为正整数数字！" -ForegroundColor Red
            }
            Start-Sleep -Seconds 2
        }
        "5" {
            $newName = Read-Host "请输入新的队长角色名 (如: 伏地魔1 / 先驱01)"
            if ($newName) {
                $cfg["LeaderName"] = $newName
                Write-IniFile $cfgPath $cfg
                Write-Host "[+] 队长已成功更换为: $newName" -ForegroundColor Green
                Start-Sleep -Seconds 1.5
            }
        }
        "6" {
            # 仅刷新
        }
        "0" {
            break
        }
    }
} while ($choice -ne "0")
