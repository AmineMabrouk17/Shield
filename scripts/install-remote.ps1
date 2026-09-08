$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SkillUrl = "https://raw.githubusercontent.com/AmineMabrouk17/Shield/main/.agents/skills/shield/SKILL.md"
$SkillDir = Join-Path $HOME ".agents\skills\shield"
$Target = Join-Path $SkillDir "SKILL.md"

New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null

$Updated = Test-Path $Target
Invoke-WebRequest -Uri $SkillUrl -UseBasicParsing -OutFile $Target

if ($Updated) {
  Write-Output "shield updated: $Target"
} else {
  Write-Output "shield installed: $Target"
}
Write-Output "Run /shield in any project to audit it."