# FM1 Open wiki lint
# SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception
#
# Checks (see AGENTS.md -> "Wiki Lint Workflow"):
#   1. Orphan pages      : doc/*.md (and doc/archive/*.md) not linked in doc/index.md
#   2. Duplicate entries : same ./file.md linked more than once in doc/index.md
#   3. Stale claims      : frontmatter stale_after <= today -> mark "! STALE" in index.md
#   4. Contradictions    : same feature claimed with both a checkmark and a cross
#   5. Deprecated pages  : status: deprecated without a redirect note / archive move
#
# Exit codes: 0 = clean, 1 = warnings (human review), 2 = errors (broken input).
#
# Usage:  pwsh doc/lint.ps1
#         pwsh doc/lint.ps1 -Json

param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$docRoot  = $PSScriptRoot
$index    = Join-Path $docRoot 'index.md'
$problems = New-Object System.Collections.Generic.List[object]
$today    = (Get-Date).Date

function Add-Problem([string]$severity, [string]$file, [string]$message) {
    $script:problems.Add([pscustomobject]@{
        severity = $severity
        file     = $file
        message  = $message
    })
}

function Get-Frontmatter([string]$path) {
    $lines = Get-Content -LiteralPath $path -TotalCount 40
    if ($lines.Count -lt 2 -or $lines[0] -ne '---') { return @{} }
    $map = @{}
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') { break }
        if ($lines[$i] -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            $map[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $map
}

if (-not (Test-Path -LiteralPath $index)) {
    Add-Problem 'error' 'doc/index.md' 'Index page missing.'
    if ($Json) { $problems | ConvertTo-Json -Depth 4; exit 2 }
    Write-Host "ERROR   doc/index.md missing" -ForegroundColor Red
    exit 2
}

$indexText = Get-Content -LiteralPath $index -Raw
$indexLines = Get-Content -LiteralPath $index

# --- collect doc pages -------------------------------------------------------
$pages = @()
$pages += Get-ChildItem -LiteralPath $docRoot -Filter '*.md' -File
$archive = Join-Path $docRoot 'archive'
if (Test-Path -LiteralPath $archive) {
    $pages += Get-ChildItem -LiteralPath $archive -Filter '*.md' -File -Recurse
}
$exclude = @('index.md', 'log.md')   # log.md is intentionally a changelog, not a concept page

# --- 1. orphan pages --------------------------------------------------------
foreach ($page in $pages) {
    $name = $page.Name
    if ($exclude -contains $name) { continue }
    $rel = if ($page.DirectoryName -eq $docRoot) { "./$name" }
           else { "./" + $page.FullName.Substring($docRoot.Length + 1).Replace('\', '/') }
    if ($indexText -notmatch [regex]::Escape($rel)) {
        Add-Problem 'warning' $page.Name "Orphan page: not linked as $rel in doc/index.md."
    }
}

# --- 2. duplicate index entries --------------------------------------------
$links = [regex]::Matches($indexText, '\(\./(.*?)\.md\)') | ForEach-Object { $_.Groups[1].Value }
$dupes = $links | Group-Object | Where-Object { $_.Count -gt 1 }
foreach ($d in $dupes) {
    Add-Problem 'warning' 'index.md' "Duplicate index entry: ./$($d.Name).md appears $($d.Count) times."
}
foreach ($l in $links) {
    $target = Join-Path $docRoot "$l.md"
    if (-not (Test-Path -LiteralPath $target)) {
        Add-Problem 'error' 'index.md' "Broken link: ./$l.md does not exist."
    }
}

# --- 3. stale claims --------------------------------------------------------
foreach ($page in $pages) {
    $fm = Get-Frontmatter $page.FullName
    if (-not $fm.ContainsKey('stale_after')) { continue }
    $stale = $null
    try { $stale = [datetime]::ParseExact($fm['stale_after'], 'yyyy-MM-dd', $null) } catch {
        Add-Problem 'warning' $page.Name "Malformed stale_after: '$($fm['stale_after'])' (expected yyyy-MM-dd)."
        continue
    }
    if ($today -ge $stale) {
        Add-Problem 'warning' $page.Name "STALE: stale_after $($fm['stale_after']) has passed; re-verify claims against the code."
        # Flag the entry in index.md for human review (idempotent).
        $pattern = [regex]::Escape("./$($page.BaseName).md)")
        $idx = 0
        while ($idx -lt $indexLines.Count) {
            if ($indexLines[$idx] -match [regex]::Escape("./$($page.BaseName).md")) {
                if ($indexLines[$idx] -notmatch '! STALE') {
                    $indexLines[$idx] = $indexLines[$idx] -replace '(\|\s*)', '$1! STALE ', 1
                }
                break
            }
            $idx++
        }
    }
}
if (($problems | Where-Object { $_.message -like 'STALE*' }).Count -gt 0) {
    Set-Content -LiteralPath $index -Value $indexLines -Encoding utf8
}

# --- 4. contradictions (checkmark vs cross on the same claim) ---------------
$claimMap = @{}
foreach ($page in $pages) {
    foreach ($line in Get-Content -LiteralPath $page.FullName) {
        if ($line -match '(?i)(firmware build|web build|unit test|toolchain)\s*:?\s*(\u2713|\u2717|✅|❌)') {
            $key  = $Matches[1].ToLowerInvariant()
            $mark = $Matches[2]
            if (-not $claimMap.ContainsKey($key)) { $claimMap[$key] = @() }
            $claimMap[$key] += [pscustomobject]@{ file = $page.Name; mark = $mark; line = $line.Trim() }
        }
    }
}
foreach ($key in $claimMap.Keys) {
    $marks = $claimMap[$key] | ForEach-Object { $_.mark } | Select-Object -Unique
    if ($marks.Count -gt 1) {
        $where = ($claimMap[$key] | ForEach-Object { $_.file }) -join ', '
        Add-Problem 'warning' 'doc/' "Contradiction on '$key': both positive and negative claims in: $where. Verify against the code and update the outdated file."
    }
}

# --- 5. deprecated cross-reference health ----------------------------------
foreach ($page in $pages) {
    $fm = Get-Frontmatter $page.FullName
    if ($fm.ContainsKey('status') -and $fm['status'] -eq 'deprecated') {
        $raw = Get-Content -LiteralPath $page.FullName -Raw
        if ($raw -notmatch '(?i)redirect|see\s+\[|moved to') {
            Add-Problem 'warning' $page.Name "Deprecated page without a redirect note; add one or move it to doc/archive/."
        }
    }
}

# --- report -----------------------------------------------------------------
$errors   = @($problems | Where-Object severity -eq 'error')
$warnings = @($problems | Where-Object severity -eq 'warning')

if ($Json) {
    $problems | ConvertTo-Json -Depth 4
} else {
    Write-Host "FM1 Open wiki lint — $($pages.Count) pages scanned (today=$($today.ToString('yyyy-MM-dd')))"
    foreach ($p in $problems) {
        $tag = if ($p.severity -eq 'error') { 'ERROR  ' } else { 'WARNING' }
        $color = if ($p.severity -eq 'error') { 'Red' } else { 'Yellow' }
        Write-Host ("{0}  {1}: {2}" -f $tag, $p.file, $p.message) -ForegroundColor $color
    }
    if ($problems.Count -eq 0) {
        Write-Host 'OK — no issues.' -ForegroundColor Green
    } else {
        Write-Host ("{0} error(s), {1} warning(s)." -f $errors.Count, $warnings.Count)
    }
}

if ($errors.Count -gt 0)   { exit 2 }
if ($warnings.Count -gt 0) { exit 1 }
exit 0
