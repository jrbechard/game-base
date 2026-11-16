# Shared helpers for the base tools. Dot-source it:  . "$PSScriptRoot\base_lib.ps1"

function Get-BasePatterns([string]$BaseDir) {
	$listFile = Join-Path $BaseDir 'tools/base_files.txt'
	if (-not (Test-Path -LiteralPath $listFile)) { throw "Cannot find $listFile" }
	Get-Content -LiteralPath $listFile |
		Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
		ForEach-Object { $_.Trim() }
}

# A path is listed if it matches a pattern: "folder/" means everything under it, and "*"
# matches any characters. A pattern starting with "!" EXCLUDES: a file that matches one is never
# listed, even inside a listed folder (for game-only files that live in a shared folder).
function Test-Listed([string]$Relative, $Patterns) {
	$included = $false
	foreach ($p in $Patterns) {
		$exclude = $p.StartsWith('!')
		$pattern = if ($exclude) { $p.Substring(1) } else { $p }
		$hit = if ($pattern.EndsWith('/')) { $Relative.StartsWith($pattern) } else { $Relative -like $pattern }
		if ($hit) {
			if ($exclude) { return $false }
			$included = $true
		}
	}
	return $included
}

# Relative paths (forward slashes) of every file under a folder, skipping git and Godot's cache.
function Get-RelativeFiles([string]$Root) {
	$full = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
	Get-ChildItem -LiteralPath $full -Recurse -File -Force |
		Where-Object { $_.FullName -notmatch '\\(\.git|\.godot)\\' } |
		ForEach-Object { $_.FullName.Substring($full.Length + 1).Replace('\', '/') }
}

# Compare every listed file between the base and a game. Status is one of:
#   DIFFERS       in both, with different content
#   ONLY_IN_BASE  the game does not have it
#   ONLY_IN_GAME  the base does not have it (a new reusable file)
function Compare-WithBase([string]$BaseDir, [string]$GameDir) {
	$patterns = @(Get-BasePatterns $BaseDir)
	# A game lists its own game-only files (in folders the base shares) in tools/game_exclusions.txt.
	$exclusionFile = Join-Path $GameDir 'tools/game_exclusions.txt'
	if (Test-Path -LiteralPath $exclusionFile) {
		$patterns += Get-Content -LiteralPath $exclusionFile |
			Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
			ForEach-Object { '!' + $_.Trim() }
	}
	$baseFiles = Get-RelativeFiles $BaseDir | Where-Object { Test-Listed $_ $patterns }
	$gameFiles = Get-RelativeFiles $GameDir | Where-Object { Test-Listed $_ $patterns }
	$all = @($baseFiles) + @($gameFiles) | Sort-Object -Unique
	$same = 0
	$results = @()
	foreach ($rel in $all) {
		$b = Join-Path $BaseDir $rel
		$g = Join-Path $GameDir $rel
		$inBase = Test-Path -LiteralPath $b
		$inGame = Test-Path -LiteralPath $g
		if ($inBase -and -not $inGame) { $results += [pscustomobject]@{ Status = 'ONLY_IN_BASE'; File = $rel } }
		elseif ($inGame -and -not $inBase) { $results += [pscustomobject]@{ Status = 'ONLY_IN_GAME'; File = $rel } }
		elseif ((Get-FileHash -LiteralPath $b).Hash -ne (Get-FileHash -LiteralPath $g).Hash) { $results += [pscustomobject]@{ Status = 'DIFFERS'; File = $rel } }
		else { $same++ }
	}
	[pscustomobject]@{ Same = $same; Differences = $results }
}
