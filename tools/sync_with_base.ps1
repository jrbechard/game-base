<#
.SYNOPSIS
  Copy base files between a game and the base, in either direction.
.DESCRIPTION
  Works on the files listed in tools/base_files.txt. By default it only shows what it would
  copy; add -Apply to copy. It never deletes anything.

  -Direction ToBase  : bring a game's improvements into the base (DIFFERS and ONLY_IN_GAME).
  -Direction ToGame  : bring the base's upgrades into a game (DIFFERS and ONLY_IN_BASE).

  A brand-new reusable file must be listed in tools/base_files.txt (in the base) before it
  can be synced. After syncing to the base: run the base tests, add a line to CHANGELOG.md,
  and commit.
.EXAMPLE
  .\tools\sync_with_base.ps1 -GameDir "C:\Users\you\Desktop\my-game" -Direction ToBase
  .\tools\sync_with_base.ps1 -GameDir "C:\Users\you\Desktop\my-game" -Direction ToGame -Apply
#>
param(
	[Parameter(Mandatory = $true)][string]$GameDir,
	[Parameter(Mandatory = $true)][ValidateSet('ToBase', 'ToGame')][string]$Direction,
	[string]$BaseDir = '',
	[switch]$Apply
)

$ErrorActionPreference = 'Stop'
# Why here and not as a parameter default: $PSScriptRoot is not set yet while defaults are evaluated.
if (-not $BaseDir) { $BaseDir = Split-Path -Parent $PSScriptRoot }
. "$PSScriptRoot\base_lib.ps1"
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Cannot find the game folder: $GameDir" }

$result = Compare-WithBase $BaseDir $GameDir
$wanted = if ($Direction -eq 'ToBase') { @('DIFFERS', 'ONLY_IN_GAME') } else { @('DIFFERS', 'ONLY_IN_BASE') }
$plan = @($result.Differences | Where-Object { $wanted -contains $_.Status })
$skipped = @($result.Differences | Where-Object { $wanted -notcontains $_.Status })

$from = if ($Direction -eq 'ToBase') { $GameDir } else { $BaseDir }
$to = if ($Direction -eq 'ToBase') { $BaseDir } else { $GameDir }

if ($plan.Count -eq 0) { Write-Host "Nothing to copy $Direction."; }
else {
	Write-Host "$($plan.Count) file(s) to copy $Direction (from $from to $to):"
	$plan | Format-Table -AutoSize | Out-String | Write-Host
}
if ($skipped.Count -gt 0) {
	Write-Host "Not touched (they go the other way):"
	$skipped | Format-Table -AutoSize | Out-String | Write-Host
}

if (-not $Apply) {
	if ($plan.Count -gt 0) { Write-Host "Dry run. Add -Apply to copy." }
	exit 0
}

foreach ($item in $plan) {
	$src = Join-Path $from $item.File
	$dst = Join-Path $to $item.File
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
	Copy-Item -LiteralPath $src -Destination $dst -Force
}
Write-Host "Copied $($plan.Count) file(s)."
if ($Direction -eq 'ToBase' -and $plan.Count -gt 0) {
	Write-Host "Next: run the base tests, add a line to CHANGELOG.md, and commit in the base."
}
