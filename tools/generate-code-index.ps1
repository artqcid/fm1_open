#!/usr/bin/env pwsh
<#
PURPOSE:
  Generate a deterministic Markdown code index (doc/code_index.md) from the
  C99 source files in the FM1 Open V13 project. The index is a symbol finder
  for functions, defines, structs/enums, and static assertions across the APP
  and web engine sources.

USAGE:
  pwsh tools/generate-code-index.ps1

OUTPUT:
  doc/code_index.md  — regenerated each run; do not edit by hand.

REQUIREMENTS:
  - PowerShell 7 (pwsh). Avoids PS7-only syntax where trivial; PS7 is the target.
  - Repository root = Split-Path $PSScriptRoot -Parent.
  - Source files scanned relative to repo root, sorted by path.
  - UTF-8 without BOM output.
  - No timestamps, no absolute paths.
#>

# Ensure deterministic exit
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot
$docRoot  = Join-Path $repoRoot "doc"
$outPath  = Join-Path $docRoot "code_index.md"

# Source globs (relative to repo root)
$sources = @(
    @{ Name = "app_sources";        Glob = "app/*.c" },
    @{ Name = "board_sources";      Glob = "app/board/*.c" },
    @{ Name = "api_header";         Glob = "app/instrument.h" },
    @{ Name = "web_engine_sources"; Glob = "web/engine/*.c" }
)

# ---------------------------------------------------------------------------
# Symbol extraction rules (heuristic, best-effort, single-line)
# ---------------------------------------------------------------------------
#
# define:
#   Regex: ^#\s*define\s+(?<name>[A-Z_][A-Z0-9_]*)\s+(?<value>.*)$
#   Captures name and value. Applies ONLY to lines starting with #define
#   (not other directives).
#
# function:
#   Regex: ^\s*(?<ret>[A-Za-z_][\w\s\*]+?)\s*[\r]*\s*(?<name>[A-Za-z_][\w_]*)\s*\((?<params>[^\)]*)\)\s*\{?\s*$
#   Heuristic for C99-style function definitions. Captures return type (may
#   span lines but we treat single-line only here), name, parameter list.
#
#   IMPORTANT exclusions: the regex is applied AFTER a pre-filter that removes
#   lines that are:
#     - control keywords (if, for, while, switch, return, sizeof, else)
#     - preprocessor lines EXCEPT #define (handled separately)
#     - comment lines (// ... or /* ... */)
#     - function CALL lines (typically end with ; and NOT with { or new line)
#   A call line typically has a trailing ';' and no '{' on the same line.
#   A definition line typically has '{' optionally on the line, or the line
#   ends after ')' (the function body starts on next line).
#
# struct / enum:
#   Regex (struct):     ^\s*struct\s+(?<name>[A-Za-z_][\w_]*)\s*\{?\s*$
#   Regex (struct decl):^\s*struct\s+(?<name>[A-Za-z_][\w_]*)\s+(?<var>[A-Za-z_][\w_]*)\s*[\r]*\s*;
#   Regex (enum):       ^\s*enum\s+(?<name>[A-Za-z_][\w_]*)\s*\{?\s*$
#   Captures the tag name (and optionally a variable declaration for struct)
#   for navigation purposes.
#
# static_assert:
#   Regex: _Static_assert\s*\(\s*(?<expr>[^,]+)\s*,\s*"(?<msg>[^"]+)"\s*\);
#   Captures the message string.
#
# Heuristic limitations (KNOWN):
#   - Multi-line function signatures where the return type or name spans lines
#     may be missed; we do a best-effort single-line match.
#   - Macros that look like function calls (e.g. #define FOO() ...) are NOT
#     captured as functions (they are captured as defines only).
#   - Function pointers declared as variables (e.g. void (*cb)(void)) may be
#     captured as functions; this is acceptable for a finder.
#   - C++-style comments (//) and block comments (/*) are heuristically
#     stripped line-by-line; multi-line block comments that do not occupy a
#     full line may still leak. This is acceptable for a finder.
#   - Nested structs/unions inside a struct body are not captured individually.
#   - Static functions defined with the body on the same line work. Static
#     assertions with expressions containing commas inside the first argument
#     may be mis-parsed.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Helper: strip // and /* ... */ comments from a single line (heuristic)
# ---------------------------------------------------------------------------
function Get-StrippedLine {
    param([string]$line)
    # Remove // comments
    $line = $line -replace '//.*$', ''
    # Remove /* ... */ on a single line (non-greedy)
    $line = $line -replace '/\*.*?\*/', ''
    return $line.Trim()
}

# ---------------------------------------------------------------------------
# Helper: test whether a stripped line is a function CALL (heuristic)
# ---------------------------------------------------------------------------
function Test-FunctionCallLine {
    param([string]$stripped)
    # A call line very often ends with ';'. A definition line tends to end
    # with '{' (or has '{' somewhere after the parens) or ends right after ')'.
    # We also require the line to contain a '(' ... ')' pair that does NOT start
    # with a known control keyword.
    if ($stripped -notmatch '\(') { return $false }
    # If the line ends with '{' it is likely a definition (or start of body).
    if ($stripped -match '\{\s*$') { return $false }
    # If the line ends with ';' and there is no '{' after the last ')', treat
    # as a probable call. Also accept lines that end at ')' with no '{' (def).
    # This is imperfect but good enough for a finder.
    if ($stripped -match ';\s*$') {
        # But be careful: definitions with a semicolon after a macro expand
        # would be rare; we accept the call heuristic.
        return $true
    }
    # If line ends with ')' and no '{' we treat as definition (body on next line)
    if ($stripped -match '\)\s*$') {
        return $false
    }
    # Anything else: not a clear call; treat as definition candidate.
    return $false
}

# ---------------------------------------------------------------------------
# Helper: extract symbols from a single file
# ---------------------------------------------------------------------------
function Get-SymbolsFromFile {
    param(
        [string]$filePath,
        [string]$relativePath
    )

    $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.Encoding]::UTF8)

    $defines    = @()
    $functions  = @()
    $structs    = @()
    $enums      = @()
    $asserts    = @()

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $rawLine = $lines[$i]
        $line = Get-StrippedLine -line $rawLine
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # ---- defines (only #define) ----
        if ($line -match '^#\s*define\s+([A-Za-z_][\w_]*)\s+(.*)$') {
            $name  = $matches[1]
            $value = $matches[2].Trim()
            $defines += [PSCustomObject]@{ Name = $name; Value = $value }
            continue
        }

        # ---- skip other preprocessor directives ----
        if ($line -match '^#\s*\S') { continue }

        # ---- static_assert ----
        if ($line -match '_Static_assert\s*\(\s*[^,]+\s*,\s*"([^"]+)"\s*\)') {
            $msg = $matches[1]
            $asserts += [PSCustomObject]@{ Message = $msg }
            continue
        }

        # ---- struct / enum declarations ----
        # struct tag with possible body start
        if ($line -match '^\s*struct\s+([A-Za-z_][\w_]*)\s*\{?\s*$') {
            $structs += [PSCustomObject]@{ Name = $matches[1]; Kind = "struct tag" }
            continue
        }
        # struct variable declaration (e.g. struct foo bar;)
        if ($line -match '^\s*struct\s+([A-Za-z_][\w_]*)\s+([A-Za-z_][\w_]*)\s*;\s*$') {
            $structs += [PSCustomObject]@{ Name = "$($matches[1]) $($matches[2])"; Kind = "struct decl" }
            continue
        }
        # anonymous struct / typedef struct { ...
        if ($line -match '^\s*struct\s*\{?\s*$') {
            $structs += [PSCustomObject]@{ Name = "(anonymous)"; Kind = "struct (anon)" }
            continue
        }
        # enum tag
        if ($line -match '^\s*enum\s+([A-Za-z_][\w_]*)\s*\{?\s*$') {
            $enums += [PSCustomObject]@{ Name = $matches[1] }
            continue
        }
        # enum with explicit underlying type (C23 / GNU): enum foo : int { ... ; ignore
        # but capture the tag name anyway if present
        if ($line -match '^\s*enum\s+([A-Za-z_][\w_]*)\s*') {
            $enums += [PSCustomObject]@{ Name = $matches[1] }
            continue
        }

        # ---- function detection ----
        # First: skip lines that are control keywords or look like calls
        $lower = $line.ToLowerInvariant()
        $controlKeywords = @('if', 'for', 'while', 'switch', 'return', 'sizeof', 'else', 'do', 'case', 'default', 'goto', 'break', 'continue')
        $isControl = $false
        foreach ($kw in $controlKeywords) {
            if ($lower -eq $kw -or $lower -match "^$kw\s*\(") {
                $isControl = $true
                break
            }
        }
        if ($isControl) { continue }

        # Exclude lines that look like function calls
        if (Test-FunctionCallLine -stripped $line) { continue }

        # Heuristic function signature: return type (may contain spaces and *)
        # then function name, then '(' ... ')' optionally followed by '{'
        $funcPattern = '^\s*([A-Za-z_][\w\s\*]*?)\s+([\w_][\w_]*)\s*\(([^)]*)\)\s*(\{?\s*)$'
        if ($line -match $funcPattern) {
            $ret  = $matches[1].Trim()
            $name = $matches[2]
            $params = $matches[3]
            $brace = $matches[4]
            # Filter out common non-function matches:
            #   - if the "return type" part is just a keyword like 'return', skip
            #   - if the name looks like a variable declaration (e.g. int x;)
            #     we require the line to end with '{' (body start) OR the line
            #     is a prototype ending with ');' which we skip here (declarations
            #     without body). Here we only capture definitions (with '{') or
            #     prototypes that end with ')' + newline (multi-line).
            # For a finder, capture both definitions and prototypes that end with
            # ')' and no ';'. This is acceptable.
            $trimmed = $line.TrimEnd()
            if ($trimmed -match ';\s*$') {
                # prototype declaration; capture for finder but flag
                $functions += [PSCustomObject]@{
                    Return = $ret
                    Name   = $name
                    Params = $params
                    Note   = "prototype"
                }
            } elseif ($brace -eq '{') {
                $functions += [PSCustomObject]@{
                    Return = $ret
                    Name   = $name
                    Params = $params
                    Note   = ""
                }
            } else {
                # ends after ')' with no ';' -> definition with body on next line
                $functions += [PSCustomObject]@{
                    Return = $ret
                    Name   = $name
                    Params = $params
                    Note   = ""
                }
            }
            continue
        }

        # Also catch function definitions where return type is on the previous
        # line (e.g. static\nint foo(...) { }). This single-line pass cannot see
        # that; we accept the limitation. A best-effort: if a line starts with a
        # name followed by '(' it might be a continuation; but we skip to avoid
        # false positives on calls like foo( already handled).
    }

    return [PSCustomObject]@{
        RelativePath = $relativePath
        Defines      = $defines
        Functions    = $functions
        Structs      = $structs
        Enums        = $enums
        Asserts      = $asserts
    }
}

# ---------------------------------------------------------------------------
# Collect and sort source files
# ---------------------------------------------------------------------------
$collected = @()
$symbolCount = 0
$fileCount = 0

foreach ($src in $sources) {
    $files = Get-ChildItem -Path $repoRoot -Filter $src.Glob -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { -not $_.FullName.Contains('\build\') -and -not $_.FullName.Contains('\obj\') } |
        Sort-Object -Property FullName
    foreach ($f in $files) {
        $relative = [System.IO.Path]::GetRelativePath($repoRoot, $f.FullName)
        # Normalize to forward slashes for Markdown readability
        $relative = $relative -replace '\\', '/'
        $symbols = Get-SymbolsFromFile -filePath $f.FullName -relativePath $relative
        $collected += $symbols
        $fileCount++
        $symbolCount += $symbols.Defines.Count + $symbols.Functions.Count + $symbols.Structs.Count + $symbols.Enums.Count + $symbols.Asserts.Count
    }
}

# Sort collected results by relative path
$collected = $collected | Sort-Object -Property RelativePath

# ---------------------------------------------------------------------------
# Build Markdown
# ---------------------------------------------------------------------------
function EscapeTableField {
    param([string]$value)
    $value = $value -replace '&', '&amp;'
    $value = $value -replace '<', '&lt;'
    $value = $value -replace '>', '&gt;'
    return $value
}

$markdown = @()
$markdown += "---"
$markdown += "title: Generated Code Index"
$markdown += "description: Auto-generated symbol finder for APP and web sources. Do not edit by hand; regenerate with tools/generate-code-index.ps1."
$markdown += "status: generated"
$markdown += "generated_by: tools/generate-code-index.ps1"
$markdown += "---"
$markdown += ""
$markdown += "# Generated Code Index"
$markdown += ""
$markdown += 'This file is auto-generated by `tools/generate-code-index.ps1`. It provides'
$markdown += "a navigation index of symbols across the APP and web engine sources."
$markdown += ""
$markdown += "## Legend"
$markdown += ""
$markdown += '- **Define** — `#define` macro name and value.'
$markdown += "- **Function** — function definition or prototype (heuristic)."
$markdown += '  - `prototype` indicates a declaration without body on the same line.'
$markdown += "- **Struct** — struct tag or variable declaration."
$markdown += "- **Enum** — enum tag."
$markdown += '- **Static Assert** — `_Static_assert` message.'
$markdown += ""
$markdown += "## Symbols by File"
$markdown += ""

foreach ($item in $collected) {
    $markdown += "### $($item.RelativePath)"
    $markdown += ""

    # Defines
    if ($item.Defines.Count -gt 0) {
        $markdown += "#### Defines"
        $markdown += ""
        $markdown += "| Name | Value |"
        $markdown += "|------|-------|"
        foreach ($d in $item.Defines) {
            $markdown += "| $($d.Name) | $(EscapeTableField $d.Value) |"
        }
        $markdown += ""
    }

    # Functions
    if ($item.Functions.Count -gt 0) {
        $markdown += "#### Functions"
        $markdown += ""
        $markdown += "| Return | Name | Parameters | Note |"
        $markdown += "|--------|------|------------|------|"
        foreach ($f in $item.Functions) {
            $note = if ($f.Note) { $f.Note } else { "" }
            $markdown += "| $(EscapeTableField $f.Return) | $(EscapeTableField $f.Name) | $(EscapeTableField $f.Params) | $note |"
        }
        $markdown += ""
    }

    # Structs
    if ($item.Structs.Count -gt 0) {
        $markdown += "#### Structs"
        $markdown += ""
        $markdown += "| Name | Kind |"
        $markdown += "|------|------|"
        foreach ($s in $item.Structs) {
            $markdown += "| $(EscapeTableField $s.Name) | $s.Kind |"
        }
        $markdown += ""
    }

    # Enums
    if ($item.Enums.Count -gt 0) {
        $markdown += "#### Enums"
        $markdown += ""
        $markdown += "| Name |"
        $markdown += "|------|"
        foreach ($e in $item.Enums) {
            $markdown += "| $(EscapeTableField $e.Name) |"
        }
        $markdown += ""
    }

    # Static Asserts
    if ($item.Asserts.Count -gt 0) {
        $markdown += "#### Static Assertions"
        $markdown += ""
        $markdown += "| Message |"
        $markdown += "|---------|"
        foreach ($a in $item.Asserts) {
            $markdown += "| $(EscapeTableField $a.Message) |"
        }
        $markdown += ""
    }
}

$markdown += "---"
$markdown += ""
$markdown += "Generated from $fileCount source file(s) with $symbolCount symbol(s)."

$text = $markdown -join "`n"

# ---------------------------------------------------------------------------
# Write UTF-8 without BOM, deterministic
# ---------------------------------------------------------------------------
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $text, $encoding)

Write-Host "Generated $outPath"
Write-Host "Files scanned: $fileCount"
Write-Host "Symbols extracted: $symbolCount"
exit 0
