# tools/analyze_10m_report.ps1
param(
    [string]$StartTimeStr = "2026-10-03 20:37:00"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$startTime = [datetime]::ParseExact($StartTimeStr, "yyyy-MM-dd HH:mm:ss", $null)
$logDir = "D:\什么什么大冒险2.0\v2.1\logs"

function Parse-FightLog($filePath) {
    if (-not (Test-Path $filePath)) { return @() }
    $fs = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sr = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::GetEncoding("GBK"))
    $res = @()
    while (-not $sr.EndOfStream) {
        $l = $sr.ReadLine()
        if ($l -match "(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})") {
            try {
                $t = [datetime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss", $null)
                if ($t -ge $startTime) {
                    $res += [PSCustomObject]@{ Time = $t; Line = $l }
                }
            } catch {}
        }
    }
    $sr.Close()
    $fs.Close()
    return $res
}

$leaderLogs = Parse-FightLog "$logDir\client.log"
$h4Logs = Parse-FightLog "$logDir\client4.log"
$h5Logs = Parse-FightLog "$logDir\client3.log"

$fights = @()
$curFight = $null

foreach ($item in $leaderLogs) {
    $t = $item.Time
    $l = $item.Line
    if ($l -match "OnBeginFight" -or $l -match "OnEnterFight") {
        $curFight = [ordered]@{
            Start = $t
            End = $null
            Duration = 0
            EnemyCount = 0
            LineupCount = 0
            H4_MinHp = 9999
            H5_MinHp = 9999
            H4_Actions = @()
            H5_Actions = @()
            CeasefireCount = 0
            ReviveCount = 0
            H4_Stealth = $false
            H5_Stealth = $false
            H4_Heal = $false
            H5_Heal = $false
            DeadCount = 0
        }
    } elseif ($l -match "OnLeaveFight" -and $curFight) {
        $curFight.End = $t
        $dur = ($t - $curFight.Start).TotalSeconds
        if ($dur -ge 2 -and $dur -le 180) {
            $curFight.Duration = $dur
            $fights += [PSCustomObject]$curFight
        }
        $curFight = $null
    } elseif ($curFight) {
        if ($l -match "count=(\d+),\s*enemies=") {
            if ($curFight.EnemyCount -eq 0) {
                $curFight.EnemyCount = [int]$matches[1]
            }
        }
        if ($l -match "count=(\d+),\s*allies=") {
            $curFight.LineupCount = [int]$matches[1]
        }
        if ($l -match "id=0,\s*name=待命" -and $l -match "role=Player") {
            $curFight.CeasefireCount++
        }
    }
}

# 关联小号4、5行为与血量 (通过技能ID精准判定)
# ID 212 = 隐匿, ID 305 = 群体治疗术, ID 306 = 复活术, ID 307 = 保护盾, ID 309 = 精准射击, ID 803 = 扫射
foreach ($f in $fights) {
    $fStart = $f.Start
    $fEnd = if ($f.End) { $f.End } else { $fStart.AddSeconds(45) }

    foreach ($item in $h4Logs) {
        if ($item.Time -ge $fStart -and $item.Time -le $fEnd) {
            $l = $item.Line
            if ($l -match "pos:18.*?hp:(\d+)/(\d+)") {
                $hp = [int]$matches[1]
                if ($hp -lt $f.H4_MinHp) { $f.H4_MinHp = $hp }
            }
            if ($l -match "\[BATTLE_EVENT\]\[ACTION\].*?id=(\d+)") {
                $actId = [int]$matches[1]
                if ($actId -eq 212) { $f.H4_Stealth = $true; $f.H4_Actions += "隐匿(212)" }
                elseif ($actId -eq 305) { $f.H4_Heal = $true; $f.H4_Actions += "群疗(305)" }
                elseif ($actId -eq 306) { $f.ReviveCount++; $f.H4_Actions += "复活(306)" }
                elseif ($actId -eq 307) { $f.H4_Actions += "护盾(307)" }
                elseif ($l -match "act=Standby") { $f.H4_Actions += "待命" }
            }
        }
    }

    foreach ($item in $h5Logs) {
        if ($item.Time -ge $fStart -and $item.Time -le $fEnd) {
            $l = $item.Line
            if ($l -match "pos:19.*?hp:(\d+)/(\d+)") {
                $hp = [int]$matches[1]
                if ($hp -lt $f.H5_MinHp) { $f.H5_MinHp = $hp }
            }
            if ($l -match "\[BATTLE_EVENT\]\[ACTION\].*?id=(\d+)") {
                $actId = [int]$matches[1]
                if ($actId -eq 212) { $f.H5_Stealth = $true; $f.H5_Actions += "隐匿(212)" }
                elseif ($actId -eq 305) { $f.H5_Heal = $true; $f.H5_Actions += "群疗(305)" }
                elseif ($actId -eq 306) { $f.ReviveCount++; $f.H5_Actions += "复活(306)" }
                elseif ($actId -eq 307) { $f.H5_Actions += "护盾(307)" }
                elseif ($l -match "act=Standby") { $f.H5_Actions += "待命" }
            }
        }
    }
}

Write-Host "================================================================================"
Write-Host "             10分钟全景实战战斗监控深度报表"
Write-Host "  起始时间: $StartTimeStr | 当前时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "================================================================================"

$totalFights = $fights.Count
if ($totalFights -eq 0) {
    Write-Host "当前暂未结算战斗，正在持续采集中..."
    exit
}

$totalDur = 0
$minDur = 999
$maxDur = 0
$h4StealthCount = 0
$h5StealthCount = 0
$h4DangerCount = 0
$h5DangerCount = 0
$reviveFights = 0

foreach ($f in $fights) {
    $totalDur += $f.Duration
    if ($f.Duration -lt $minDur) { $minDur = $f.Duration }
    if ($f.Duration -gt $maxDur) { $maxDur = $f.Duration }
    if ($f.H4_Stealth) { $h4StealthCount++ }
    if ($f.H5_Stealth) { $h5StealthCount++ }
    if ($f.H4_MinHp -lt 650) { $h4DangerCount++ }
    if ($f.H5_MinHp -lt 600) { $h5DangerCount++ }
    if ($f.ReviveCount -gt 0) { $reviveFights++ }
}

$avgDur = [math]::Round($totalDur / $totalFights, 2)

Write-Host ("【核心战斗指标总览】")
Write-Host ("- 采样总场次: {0} 场" -f $totalFights)
Write-Host ("- 平均单场耗时: {0} 秒 | 最快: {1} 秒 | 最慢: {2} 秒" -f $avgDur, $minDur, $maxDur)
Write-Host ("- 四号开局隐匿执行率: {0}/{1} ({2:P1})" -f $h4StealthCount, $totalFights, ($h4StealthCount/$totalFights))
Write-Host ("- 五号开局隐匿执行率: {0}/{1} ({2:P1})" -f $h5StealthCount, $totalFights, ($h5StealthCount/$totalFights))
Write-Host ("- 小号濒危(HP<50%)场次: 四号={0}场, 五号={1}场" -f $h4DangerCount, $h5DangerCount)
Write-Host ("- 倒地复活协议触发: {0} 场" -f $reviveFights)
Write-Host ("--------------------------------------------------------------------------------")
Write-Host "场次流水明细:"
$idx = 1
foreach ($f in $fights) {
    $h4Text = if ($f.H4_MinHp -eq 9999) { "1305(满)" } else { "$($f.H4_MinHp)" }
    $h5Text = if ($f.H5_MinHp -eq 9999) { "1227(满)" } else { "$($f.H5_MinHp)" }
    $h4Acts = ($f.H4_Actions | Select-Object -Unique) -join ","
    $h5Acts = ($f.H5_Actions | Select-Object -Unique) -join ","
    
    $status = "稳健存活"
    if ($f.H4_MinHp -lt 650 -or $f.H5_MinHp -lt 600) { $status = "曾受集火" }
    if ($f.ReviveCount -gt 0) { $status = "触发复活" }
    
    Write-Host ("#{0:D2} | {1}~{2} | 耗时:{3,4:F1}s | 怪:{4} | 四号HP:{5,-8} 五号HP:{6,-8} | 状态:[{7}]" -f `
        $idx, $f.Start.ToString("HH:mm:ss"), $f.End.ToString("HH:mm:ss"), $f.Duration, $f.EnemyCount, $h4Text, $h5Text, $status)
    Write-Host ("     -> 四号动作: [{0}]" -f $h4Acts)
    Write-Host ("     -> 五号动作: [{0}]" -f $h5Acts)
    $idx++
}
Write-Host "================================================================================"
