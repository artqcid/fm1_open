# tools/check-repo.ps1 — Level-4 repo-hygiene automation
# Purpose: automate the git-status / gitignore / .gitattributes hygiene checks
#         that doc/test-strategy.md Level 4 currently asks a human to run manually.
# Usage:  pwsh tools/check-repo.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is not available on PATH; cannot run hygiene checks."
    exit 1
}

$artifactExts = @('.o', '.obj', '.exe', '.pdb', '.ilk', '.wasm', '.elf', '.map', '.d')

# Helper: .NET case-insensitive ends-with check (avoids PS version issues)
function _endsWithCI([string]$path, [string[]]$exts) {
    $lower = $path.ToLowerInvariant()
    foreach ($ext in $exts) {
        if ($lower.EndsWith($ext.ToLowerInvariant())) { return $true }
    }
    return $false
}


$results = [System.Collections.Generic.List[object]]::new()

# ---- Check 1: stray untracked / modified compiler artifacts outside build/ ----
$statusLines = & git -C $repoRoot status --porcelain 2>$null
$flagged = @()
foreach ($line in $statusLines) {
    if ($line.Length -lt 3) { continue }
    $path = $line.Substring(3)

    # Rename entry: "R  old -> new" → take the target path
    $idx = $path.IndexOf(" -> ")
    if ($idx -gt 0) { $path = $path.Substring($idx + 3) }

    # Strip one pair of surrounding double quotes if present
    if ($path.Length -ge 2 -and $path[0] -eq '"' -and $path[-1] -eq '"') {
        $path = $path.Substring(1, $path.Length - 2)
    }

    # Exclude build/ (gitignored)
    if ($path -like 'build/*' -or $path -eq 'build') { continue }

    if (_endsWithCI $path $artifactExts) {
        $flagged += $path
    }
}

if ($flagged.Count -eq 0) {
    $results += [pscustomobject]@{ check = 'stray_untracked_artifacts'; status = 'OK'; reason = 'No stray compiler artifacts among untracked/modified files outside build/' }
} else {
    $results += [pscustomobject]@{ check = 'stray_untracked_artifacts'; status = 'FAIL'; reason = ($flagged -join '; ') }
}

# ---- Check 2: build/ is gitignored and absent from tracked files ----
& git -C $repoRoot check-ignore -q build 2>$null
$ignoreOk = $LASTEXITCODE -eq 0
$lsOut = & git -C $repoRoot ls-files -- build 2>$null
$lsLines = if ([string]::IsNullOrWhiteSpace($lsOut)) { @() } else { $lsOut -split "`n" | Where-Object { $_ -ne "" } }
$trackedEmpty = $lsLines.Count -eq 0

if ($ignoreOk -and $trackedEmpty) {
    $results += [pscustomobject]@{ check = 'build_dir_gitignored'; status = 'OK'; reason = 'build/ is gitignored and not tracked' }
} else {
    $parts = @()
    if (-not $ignoreOk) { $parts += 'gitignore mismatch' }
    if (-not $trackedEmpty) { $parts += 'tracked files under build/' }
    $results += [pscustomobject]@{ check = 'build_dir_gitignored'; status = 'FAIL'; reason = ($parts -join '; ') }
}

# ---- Check 3: .gitattributes present at repo root ----
if (Test-Path (Join-Path $repoRoot '.gitattributes')) {
    $results += [pscustomobject]@{ check = 'gitattributes_present'; status = 'OK'; reason = '.gitattributes exists at repo root' }
} else {
    $results += [pscustomobject]@{ check = 'gitattributes_present'; status = 'FAIL'; reason = 'missing .gitattributes at repo root' }
}

# ---- Output ----
foreach ($r in $results) {
    Write-Output "$($r.status)  $($r.check)  $($r.reason)"
}

$failed = $results | Where-Object { $_.status -eq 'FAIL' }
if ($failed.Count -gt 0) {
    Write-Output "SUMMARY: $($failed.Count) failure(s)"
    exit 1
} else {
    Write-Output "SUMMARY: all checks passed"
    exit 0
}
