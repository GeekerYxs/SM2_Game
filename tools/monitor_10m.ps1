# tools/monitor_10m.ps1
param(
    [string]$StartTimeStr = "2026-10-03 20:37:00"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$startTime = [datetime]::ParseExact($StartTimeStr, "yyyy-MM-dd HH:mm:ss", $null)
$logDir = "D:\什么什么大冒险2.0\v2.1\logs"

function Parse-FightLog($filePath) {
    if (-not (Test-Path $filePath)) { return @() }
    
    # 采用 FileShare.ReadWrite 允许并发无锁读取
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

Write-Host "================================================================================"
Write-Host "                10分钟战斗数据与自保策略全景监控中枢"
Write-Host "                监控起始时间: $StartTimeStr | 当前时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "================================================================================"

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
            H4_ActCount = 0
            H5_ActCount = 0
            CeasefireTriggered = $false
            ReviveTriggered = $false
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
        if ($l -match "紧急停火" -or $l -match "停火待命") {
            $curFight.CeasefireTriggered = $true
        }
    }
}

# 关联小号4、5行为与血量
foreach ($f in $fights) {
    $fStart = $f.Start
    $fEnd = if ($f.End) { $f.End } else { $fStart.AddSeconds(40) }

    foreach ($item in $h4Logs) {
        if ($item.Time -ge $fStart -and $item.Time -le $fEnd) {
            $l = $item.Line
            if ($l -match "pos:18.*?hp:(\d+)/(\d+)") {
                $hp = [int]$matches[1]
                if ($hp -lt $f.H4_MinHp) { $f.H4_MinHp = $hp }
            }
            if ($l -match "\[BATTLE_EVENT\]\[ACTION\]") {
                $f.H4_ActCount++
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
            if ($l -match "\[BATTLE_EVENT\]\[ACTION\]") {
                $f.H5_ActCount++
            }
            if ($l -match "复活术") {
                $f.ReviveTriggered = $true
            }
            if ($l -match "紧急停火" -or $l -match "停火待命") {
                $f.CeasefireTriggered = $true
            }
        }
    }
}

Write-Host "已捕获并结算战斗场次: $($fights.Count) 场"
Write-Host "--------------------------------------------------------------------------------"
$idx = 1
foreach ($f in $fights) {
    $h4Text = if ($f.H4_MinHp -eq 9999) { "满血(1305)" } else { "$($f.H4_MinHp)/1305" }
    $h5Text = if ($f.H5_MinHp -eq 9999) { "满血(1227)" } else { "$($f.H5_MinHp)/1227" }
    $ceaseText = if ($f.CeasefireTriggered) { "[触发停火]" } else { "正常输出" }
    $reviveText = if ($f.ReviveTriggered) { "[触发复活]" } else { "-" }
    
    $startStr = $f.Start.ToString("HH:mm:ss")
    $endStr = if ($f.End) { $f.End.ToString("HH:mm:ss") } else { "未完" }
    
    Write-Host ("第 {0:D2} 场 | {1} ~ {2} | 耗时:{3,4:F1}s | 怪数:{4} | 阵型:{5}人 | 四号最低HP:{6,-10} | 五号最低HP:{7,-10} | 停火:{8}" -f $idx, $startStr, $endStr, $f.Duration, $f.EnemyCount, ($f.LineupCount/2), $h4Text, $h5Text, $ceaseText)
    $idx++
}
Write-Host "================================================================================"
