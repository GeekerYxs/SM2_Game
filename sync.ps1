$srcStrat = "d:\Codes\GG_Antigravity\smsm2-game\src\ai_fight_strategy.lua"
$srcPatrol = "d:\Codes\GG_Antigravity\smsm2-game\src\map_patrol.lua"

$gameDir = (Get-ChildItem -Path "D:\" -Directory -Filter "*2.0").FullName
Write-Host "Resolved game directory: $gameDir"

$stratFiles = Get-ChildItem -Path $gameDir -Recurse -Filter "ai_fight_strategy.lua"
foreach ($f in $stratFiles) {
    Copy-Item $srcStrat -Destination $f.FullName -Force
    Write-Host "Updated strategy: $($f.FullName)"
}

$patrolFiles = Get-ChildItem -Path $gameDir -Recurse -Filter "map_patrol.lua"
foreach ($f in $patrolFiles) {
    Copy-Item $srcPatrol -Destination $f.FullName -Force
    Write-Host "Updated patrol: $($f.FullName)"
}

Write-Host "ALL SYNC COMPLETED SUCCESSFULLY!"
