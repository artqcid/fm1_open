# Wrapper for the VS Code build tasks (see .vscode/tasks.json).
#
# Why a wrapper instead of an inline `-Command` or an `options.env` block:
#  - PowerShell 7 re-appends its own module paths to PSModulePath *at startup*,
#    so the reset only sticks when it happens inside the running pwsh process
#    (BUG-001: the 5.1 powershell.exe spawned by build.bat would otherwise
#    auto-load PowerShell 7's Microsoft.PowerShell.Utility and lose
#    Get-FileHash).
#  - Passing the whole setup as an inline `-Command` string makes VS Code hand
#    it through two PowerShell parsers, which strips the inner quotes
#    (`$env:X = C:\Program Files\...` -> two bogus commands).
#  - A stale machine-wide LIB pointing at an uninstalled Visual Studio breaks
#    the Add-Type packaging step (T-25). It is cleared here too; a User-level
#    LIB override repairs the effective value for other tools.
param(
    [ValidateSet('web', 'package')]
    [string]$Mode = 'package'
)

$ErrorActionPreference = 'Stop'

$env:PSModulePath = 'C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
$env:LIB = ''

$env:FM1_SOURCE_URL = 'https://github.com/m-vave/fm1_open'

# Reuse the extracted WASI SDK 27 (T-38) instead of re-downloading it into
# the gitignored build/ tree.
if (Test-Path 'C:\wasi-sdk-27\bin\clang.exe') {
    $env:FM1_WASI_SDK = 'C:\wasi-sdk-27'
}

if ($Mode -eq 'package') {
    $env:FM1_PI32_TOOLCHAIN = 'C:\JL\pi32-2.5.2\C$\JL\pi32'
}

$buildBat = Join-Path $PSScriptRoot '..\build.bat'
$arg = if ($Mode -eq 'web') { '--web' } else { '--package' }

& $buildBat $arg
exit $LASTEXITCODE
