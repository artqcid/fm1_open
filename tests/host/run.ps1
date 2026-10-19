# Host-side checks for APP persistence logic (T-29).
# Compiles app/project.c + app/samples.c against a RAM-backed Flash and runs
# tests/host/fm1_host_test.c. All artifacts stay under %TEMP%\opencode.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$clang = (Get-Command clang -ErrorAction SilentlyContinue).Source
if (-not $clang) {
    $candidate = 'C:\Program Files\LLVM\bin\clang.exe'
    if (Test-Path -LiteralPath $candidate) { $clang = $candidate }
}
if (-not $clang) { throw 'clang not found (install LLVM or add it to PATH).' }

function Find-Latest($pattern) {
    Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Directory.Parent.Name) } -Descending |
        Select-Object -First 1
}

$vcruntime = Find-Latest 'C:\Program Files\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\include\vcruntime.h'
if (-not $vcruntime) { throw 'MSVC vcruntime.h not found; install the C++ build tools.' }
$msvc = Split-Path (Split-Path $vcruntime.FullName)

$ucrt = Find-Latest 'C:\Program Files (x86)\Windows Kits\10\Include\*\ucrt\stdlib.h'
if (-not $ucrt) { throw 'Windows SDK ucrt headers not found.' }
$sdkVersion = Split-Path (Split-Path $ucrt.FullName)
$sdkRoot = Split-Path (Split-Path $sdkVersion)
$sdkLib = Join-Path $sdkRoot ("Lib\" + (Split-Path $sdkVersion -Leaf))

$env:INCLUDE = @(
    (Join-Path $msvc 'include')
    (Join-Path $sdkVersion 'ucrt')
    (Join-Path $sdkVersion 'um')
    (Join-Path $sdkVersion 'shared')
    (Join-Path $sdkVersion 'winrt')
) -join ';'
$env:LIB = @(
    (Join-Path $msvc 'lib\x64')
    (Join-Path $sdkLib 'ucrt\x64')
    (Join-Path $sdkLib 'um\x64')
) -join ';'

$out = Join-Path $env:TEMP 'opencode\fm1_host_test'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$exe = Join-Path $out 'fm1_host_test.exe'

$sources = @(
    (Join-Path $root 'app\project.c')
    (Join-Path $root 'app\samples.c')
    (Join-Path $PSScriptRoot 'fm1_host_test.c')
)
$includes = @(
    (Join-Path $root 'app')
    (Join-Path $root 'app\synth')
    (Join-Path $root 'third_party\synth')
    (Join-Path $root 'sdk\include')
) | ForEach-Object { "-I$_" }

# COFF cannot combine clang's weak aliases from several TUs (LNK1227).
# FM1_HOST_TEST only needs the weak hooks as feature flags, so strip the
# attribute for this host build; the harness provides normal definitions.
& $clang -std=c11 -O1 -Wall -Wextra -Wno-unused-parameter -Wno-pointer-bool-conversion `
    '-D__attribute__(x)=' -DFM1_HOST_TEST @includes @sources -o $exe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $exe
exit $LASTEXITCODE
