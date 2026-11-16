<#
.SYNOPSIS
  Show which base files differ between a game and the base.
.DESCRIPTION
  Compares the files listed in tools/base_files.txt. Exit code 0 means every listed file
  matches; 1 means something differs. Statuses: DIFFERS, ONLY_IN_BASE (the game lacks it),
  ONLY_IN_GAME (a new file the base does not have yet).
.EXAMPLE
  .\tools\diff_against_base.ps1 -GameDir "C:\Users\you\Desktop\my-game"
  .\tools\diff_against_base.ps1 -GameDir "C:\Users\you\Desktop\my-game" -Diff
#>
param(
	[Parameter(Mandatory = $true)][string]$GameDir,
	[string]$BaseDir = '',
	[switch]$Diff
)

$ErrorActionPreference = 'Stop'
# Why here and not as a parameter default: $PSScriptRoot is not set yet while defaults are evaluated.
if (-not $BaseDir) { $BaseDir = Split-Path -Parent $PSScriptRoot }
. "$PSScriptRoot\base_lib.ps1"
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Cannot find the game folder: $GameDir" }

$result = Compare-WithBase $BaseDir $GameDir
Write-Host "$($result.Same) listed files match the base."
if ($result.Differences.Count -eq 0) { Write-Host "Nothing differs."; exit 0 }

Write-Host "$($result.Differences.Count) differ:"
$result.Differences | Format-Table -AutoSize | Out-String | Write-Host
if ($Diff) {
	foreach ($d in ($result.Differences | Where-Object { $_.Status -eq 'DIFFERS' })) {
		Write-Host "----- $($d.File)"
		& git diff --no-index --no-color -- (Join-Path $BaseDir $d.File) (Join-Path $GameDir $d.File)
	}
}
exit 1
