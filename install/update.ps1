# Runs install.ps1 with the same arguments (PowerShell 5.1 or 7+).
# A checkout uses the copy beside this file. A pipe needs -Ref/--ref or EJ_REF.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RanAsFile = [bool]$PSCommandPath
function Fail([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine($Message)
    if ($RanAsFile) { exit $Code }
    $global:LASTEXITCODE = $Code
    throw $Message
}

$here = $null
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $candidate = Split-Path -Parent $PSCommandPath
    $installer = Join-Path $candidate "install.ps1"
    $pins = Join-Path $candidate "pins.txt"
    if ((Test-Path -LiteralPath $installer) -and (Test-Path -LiteralPath $pins)) { $here = $candidate }
}

$ref = if ($env:EJ_REF) { $env:EJ_REF.Trim() } else { "" }
$i = 0
while ($i -lt $args.Count) {
    $token = [string]$args[$i]
    if ($token -eq "--ref" -or $token -eq "-Ref" -or $token -eq "-ref") {
        if ($i + 1 -ge $args.Count) { Fail "Missing value for --ref.`nNothing was installed. Rerunning is safe." 2 }
        $ref = [string]$args[$i + 1]
        $i += 2
        continue
    }
    $i++
}

if ($here) {
    $installer = Join-Path $here "install.ps1"
    & $installer @args
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        if ($RanAsFile) { exit $LASTEXITCODE }
        throw "Installer failed with exit code $LASTEXITCODE."
    }
    return
}

if (-not $ref) {
    Fail "update.ps1 was started from a pipe and has no local install/pins.txt.`nRun it from a checkout, or pass --ref <commit-tag-or-branch> (or set EJ_REF).`nNothing was installed. Rerunning is safe."
}

$root = if ($env:EJ_RAW_ROOT) { $env:EJ_RAW_ROOT.TrimEnd("/") } else { "https://raw.githubusercontent.com" }
if ($root -notmatch '^https?://') {
    Fail "EJ_RAW_ROOT must start with http:// or https://.`nNothing was installed. Rerunning is safe."
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ej-update-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$base = "$root/dimitriskl/engineering-judgment-skill/$ref/install"
function Save-Pinned([string]$Url, [string]$Dest, [string]$Label) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Dest -TimeoutSec 60 | Out-Null
    } catch {
        Fail "Failed to download $Label.`nURL: $Url`n$($_.Exception.Message)`nNothing was installed. Rerunning is safe."
    }
    if (-not (Test-Path -LiteralPath $Dest) -or (Get-Item -LiteralPath $Dest).Length -eq 0) {
        Fail "Failed to download ${Label}: the file was empty.`nURL: $Url`nNothing was installed. Rerunning is safe."
    }
}
Save-Pinned "$base/install.ps1" (Join-Path $tmp "install.ps1") "install/install.ps1"
Save-Pinned "$base/pins.txt" (Join-Path $tmp "pins.txt") "install/pins.txt"
Save-Pinned "$base/agents.txt" (Join-Path $tmp "agents.txt") "install/agents.txt"
$installer = Join-Path $tmp "install.ps1"
& $installer @args
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    if ($RanAsFile) { exit $LASTEXITCODE }
    throw "Installer failed with exit code $LASTEXITCODE."
}
