<#
.SYNOPSIS
  Start a new game from the base.
.DESCRIPTION
  Copies the base into a new folder, names the project, records which base version it came
  from, and starts a fresh git repo with a first commit. Run it from the base folder.
.EXAMPLE
  .\tools\new_game.ps1 -Name "My Game" -Dest "C:\Users\you\Desktop\my-game"
#>
param(
	[Parameter(Mandatory = $true)][string]$Name,
	[Parameter(Mandatory = $true)][string]$Dest,
	[switch]$NoGit
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot

if (Test-Path -LiteralPath $Dest) {
	throw "The destination already exists: $Dest. Choose a folder that does not exist yet."
}

# Copy everything except git history and Godot's cache (the new game rebuilds its own).
New-Item -ItemType Directory -Path $Dest | Out-Null
robocopy $base $Dest /E /XD ".git" ".godot" /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -gt 7) { throw "Copying the base failed (robocopy exit code $LASTEXITCODE)." }

# Name the project. project.godot must stay UTF-8 without a byte-order mark.
$noBom = New-Object System.Text.UTF8Encoding($false)
$project = Join-Path $Dest 'project.godot'
$text = [System.IO.File]::ReadAllText($project)
$safeName = $Name.Replace('\', '\\').Replace('"', '\"')
$text = [regex]::Replace($text, 'config/name="[^"]*"', ('config/name="' + $safeName + '"'))
[System.IO.File]::WriteAllText($project, $text, $noBom)

# Put the game's name into the docs that have a placeholder.
foreach ($doc in @('CLAUDE.md', 'docs/DESIGN.md')) {
	$path = Join-Path $Dest $doc
	if (Test-Path -LiteralPath $path) {
		$content = [System.IO.File]::ReadAllText($path)
		[System.IO.File]::WriteAllText($path, $content.Replace('[GAME NAME]', $Name), $noBom)
	}
}

# Game-only files that live in folders the base shares are listed here, so the drift tools do
# not mistake them for new reusable files.
$exclusions = "# Game-only files in folders the base shares (one pattern per line; `"*`" matches any characters,`n# a trailing `"/`" means a whole folder). tools/diff_against_base.ps1 ignores these.`n"
[System.IO.File]::WriteAllText((Join-Path $Dest 'tools/game_exclusions.txt'), $exclusions, $noBom)

# Record where this game came from, so the drift checker and future you know.
$hash = 'unknown'
if (Get-Command git -ErrorAction SilentlyContinue) {
	$h = & git -C $base rev-parse --short HEAD 2>$null
	if ($LASTEXITCODE -eq 0 -and $h) { $hash = $h }
}
[System.IO.File]::WriteAllText((Join-Path $Dest 'tools/base_version.txt'),
	"Started from game-base commit $hash on $(Get-Date -Format 'yyyy-MM-dd').`n", $noBom)

if (-not $NoGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
	& git -C $Dest init -b main | Out-Null
	& git -C $Dest add -A | Out-Null
	& git -C $Dest commit -q -m "Start $Name from game-base $hash" | Out-Null
	Write-Host "Started a git repo with a first commit."
}

Write-Host ""
Write-Host "Created '$Name' at $Dest (from game-base $hash)."
Write-Host "Next:"
Write-Host "  1. Open the folder in Godot once so it imports."
Write-Host "  2. Run the tests to confirm the starting point is green (see README.md)."
Write-Host "  3. Fill in docs/DESIGN.md and CLAUDE.md, then replace the worked examples with your own data."
