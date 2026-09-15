param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'setup', 'check', 'lint', 'test', 'verify', 'release-check', 'publish')]
    [string]$Target = 'verify',
    [string]$Organization,
    [string]$ModuleName,
    [string]$Title,
    [string]$Namespace,
    [string]$Tag,
    [string]$GitHubOwner,
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'public',
    # The shell declares the `gfx` module, which only a local build of the
    # runtime fork has (wippy-windows/runtime, branch wippy-projects); the
    # release `wippy` does not load the shell. Name your build here or in
    # the WIPPY environment variable.
    [string]$Wippy = $(if ($env:WIPPY) { $env:WIPPY } else { 'wippy' }),
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Identity = (Get-Content (Join-Path $Root '.kickside-module.json') -Raw | ConvertFrom-Json).identity
$TestHost = 'wippy.terminal:host'

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments, [string]$Directory = $Root)
    Push-Location $Directory
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

function Invoke-Init {
    if (-not $Organization -or -not $ModuleName -or -not $Title) {
        throw 'init requires -Organization, -ModuleName, and -Title'
    }
    $args = @('scripts/init-module.mjs', '--organization', $Organization, '--module', $ModuleName, '--title', $Title)
    if ($Namespace) { $args += @('--namespace', $Namespace) }
    if ($Tag) { $args += @('--tag', $Tag) }
    if ($GitHubOwner) { $args += @('--github-owner', $GitHubOwner) }
    Invoke-Checked node $args
}

function Invoke-Setup {
    Invoke-Checked $Wippy @('update')
    Invoke-Checked $Wippy @('update') (Join-Path $Root 'test')
}

function Invoke-Check {
    Invoke-Checked node @('scripts/check-module.mjs')
    Invoke-Checked node @('scripts/test-initializer.mjs')
}

# Late locals first (a local read above its declaration is a nil global and
# `wippy lint` does not see it), then the type check from the harness, which
# loads the module together with the shell.
function Invoke-Lint {
    Invoke-Checked $Python @('tools/late-locals.py', 'src', 'test/src')
    Invoke-Checked $Wippy @('lint', '--ns', $Identity.namespace, '--ns', 'app') (Join-Path $Root 'test')
}

# The runner exits 0 when it discovers zero tests, which turns a broken
# discovery setup into a false-green run; mirror the Makefile guard.
function Invoke-Test {
    Push-Location (Join-Path $Root 'test')
    try {
        $output = & $Wippy @('test', '--host', $TestHost) 2>&1 | ForEach-Object { "$_" }
        $output | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "wippy failed with exit code $LASTEXITCODE" }
        if ($output -match 'No tests found') { throw 'test runner discovered no tests' }
    } finally {
        Pop-Location
    }
}

function Invoke-Verify {
    Invoke-Setup
    Invoke-Check
    Invoke-Lint
    Invoke-Test
}

switch ($Target) {
    'init' { Invoke-Init }
    'setup' { Invoke-Setup }
    'check' { Invoke-Check }
    'lint' { Invoke-Lint }
    'test' { Invoke-Test }
    'verify' { Invoke-Verify }
    'release-check' {
        Invoke-Verify
        Invoke-Checked $Wippy @('auth', 'status')
        Invoke-Checked $Wippy @('publish', '--dry-run', '--create', '--module-visibility', $Visibility, '--module-type', 'plugin')
    }
    'publish' {
        Invoke-Checked node @('scripts/check-module.mjs')
        Invoke-Checked $Wippy @('auth', 'status')
        Invoke-Checked $Wippy @('publish', '--create', '--module-visibility', $Visibility, '--module-type', 'plugin')
    }
}
