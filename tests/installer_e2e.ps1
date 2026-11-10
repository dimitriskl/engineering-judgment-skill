# End-to-end tests for install/install.ps1 and install/update.ps1.
# Uses disposable HOME and project directories. Network calls use install/pins.txt.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $Root "install/install.ps1"))) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Install = Join-Path $Root "install/install.ps1"
$Update = Join-Path $Root "install/update.ps1"
$Pins = Join-Path $Root "install/pins.txt"
$Pwsh = (Get-Process -Id $PID).Path
$NpmCache = Join-Path ([IO.Path]::GetTempPath()) "ej-npm-cache"
New-Item -ItemType Directory -Force -Path $NpmCache | Out-Null
$env:EJ_NPM_CACHE = $NpmCache
$OrigPath = $env:PATH
$Windows = $env:OS -eq "Windows_NT"
$script:Passes = 0
$script:Fails = 0

function Ok([string]$Message) { Write-Output "PASS: $Message"; $script:Passes++ }
function Bad([string]$Message) { Write-Output "FAIL: $Message"; $script:Fails++ }
function Read-Text([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return [IO.File]::ReadAllText($Path)
}
function Assert-Has([string]$Path, [string]$Needle, [string]$Name) {
    $text = Read-Text $Path
    if ($text.Contains($Needle)) { Ok $Name } else { Bad "$Name (missing: $Needle)"; Write-Output $text }
}
function Assert-Lacks([string]$Path, [string]$Needle, [string]$Name) {
    $text = Read-Text $Path
    if ($text.Contains($Needle)) { Bad "$Name (found: $Needle)"; Write-Output $text } else { Ok $Name }
}
function Assert-Clean([string]$Dir, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Dir)) { Ok $Name; return }
    $names = @(".claude", ".codex", ".agents", ".engineering-judgment", ".engineering-workflow.json", "skills-lock.json", ".skill-lock.json")
    $hits = @(Get-ChildItem -LiteralPath $Dir -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.Name })
    if ($hits.Count -gt 0) {
        Bad $Name
        $hits | ForEach-Object { Write-Output $_.FullName }
    } else { Ok $Name }
}

$Driver = Join-Path ([IO.Path]::GetTempPath()) ("ej-driver-" + [guid]::NewGuid().ToString("n") + ".ps1")
@'
param(
    [string]$Script,
    [string]$HomeDir,
    [string]$WorkDir,
    [string]$ArgFile,
    [string]$PathValue,
    [string]$Mode
)
$ErrorActionPreference = "Continue"
$env:HOME = $HomeDir
$env:USERPROFILE = $HomeDir
foreach ($name in @("EJ_SCOPE", "EJ_REF", "EJ_PINS", "EJ_RAW", "EJ_RAW_ROOT", "EJ_NODE_MARKER", "EJ_GIT_LOG")) {
    Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
}
if ($env:EJ_EXTRA_ENV -and (Test-Path -LiteralPath $env:EJ_EXTRA_ENV)) {
    foreach ($line in [IO.File]::ReadAllLines($env:EJ_EXTRA_ENV)) {
        $eq = $line.IndexOf("=")
        if ($eq -gt 0) { Set-Item -Path ("Env:" + $line.Substring(0, $eq)) -Value $line.Substring($eq + 1) }
    }
}
if ($PathValue) { $env:PATH = $PathValue }
if ($env:EJ_NPM_CACHE) { $env:npm_config_cache = $env:EJ_NPM_CACHE }
$env:npm_config_update_notifier = "false"
$env:GIT_TERMINAL_PROMPT = "0"
Set-Location -LiteralPath $WorkDir
$ia = @()
if ($ArgFile -and (Test-Path -LiteralPath $ArgFile)) {
    $ia = @([IO.File]::ReadAllLines($ArgFile) | Where-Object { $_ -ne "" })
}
if ($Mode -eq "pipe") {
    $sb = [scriptblock]::Create([IO.File]::ReadAllText($Script))
    try { & $sb @ia } catch { exit 1 }
} else {
    & $Script @ia
}
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
exit 0
'@ | Set-Content -LiteralPath $Driver -Encoding UTF8

function New-Case {
    $case = Join-Path ([IO.Path]::GetTempPath()) ("ej-ps-" + [guid]::NewGuid().ToString("n"))
    $homeDir = Join-Path $case "home"
    $work = Join-Path $case "work"
    New-Item -ItemType Directory -Force -Path $homeDir, $work | Out-Null
    return [pscustomobject]@{
        Case = $case; Home = $homeDir; Work = $work
        Out = Join-Path $case "stdout.txt"; Err = Join-Path $case "stderr.txt"
        Args = Join-Path $case "args.txt"; Extra = Join-Path $case "extra.env"
    }
}
function Invoke-Install {
    param($Case, [string]$Script, [string[]]$Arguments, [hashtable]$Extra, [string]$PathValue, [string]$Mode = "file", [string]$Work)
    $argFile = $Case.Args
    if ($Arguments) { [IO.File]::WriteAllLines($argFile, [string[]]$Arguments) } else { [IO.File]::WriteAllText($argFile, "") }
    if ($Extra) {
        $lines = @($Extra.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
        [IO.File]::WriteAllLines($Case.Extra, $lines)
    } else { [IO.File]::WriteAllText($Case.Extra, "") }
    $env:EJ_EXTRA_ENV = $Case.Extra
    $cwd = if ($Work) { $Work } else { $Case.Work }
    & $Pwsh -NoProfile -File $Driver $Script $Case.Home $cwd $argFile $PathValue $Mode 1> $Case.Out 2> $Case.Err
    return $LASTEXITCODE
}
function Assert-Status($Code, $Expected, $Name, $Case) {
    if ($Code -eq $Expected) { Ok $Name } else {
        Bad "$Name (exit $Code, expected $Expected)"
        Write-Output "----- stdout -----"
        Write-Output (Read-Text $Case.Out)
        Write-Output "----- stderr -----"
        Write-Output (Read-Text $Case.Err)
    }
}
function Hub-Sha { (Select-String -LiteralPath $Pins -Pattern '^hub\s+\S+\s+(\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value }
function Agent-Sha([string]$Name) {
    (Select-String -LiteralPath $Pins -Pattern "^agent\s+$([regex]::Escape($Name))\s+(\S+)" | Select-Object -First 1).Matches[0].Groups[1].Value
}

$Hub = Hub-Sha
$Req = Agent-Sha "requirements-analyst"

$c = New-Case
$code = Invoke-Install $c $Install @("--scope")
Assert-Status $code 2 "missing --scope value exits 2" $c
Assert-Has $c.Err "Missing value for --scope" "missing --scope explains the flag"
Assert-Has $c.Err "Usage:" "missing --scope prints usage"
Assert-Clean $c.Home "missing --scope writes nothing in HOME"
Assert-Clean $c.Work "missing --scope writes nothing in the folder"

$c = New-Case
$code = Invoke-Install $c $Install @("--scope", "sideways")
Assert-Status $code 2 "bad --scope exits 2" $c
Assert-Has $c.Err "Scope must be personal or project, not 'sideways'" "bad --scope names the value"

$c = New-Case
$code = Invoke-Install $c $Install @("--scope", "personal") @{ EJ_RAW = "https://example.invalid/raw" }
Assert-Status $code 1 "EJ_RAW is rejected" $c
Assert-Has $c.Err "EJ_RAW is no longer used" "EJ_RAW tells you what to set instead"
Assert-Clean $c.Home "EJ_RAW writes nothing"

$c = New-Case
$shim = Join-Path $c.Case "shim"
New-Item -ItemType Directory -Force -Path $shim | Out-Null
$marker = Join-Path $c.Case "marker"
if ($Windows) {
    @'
@echo off
if "%~1"=="-v" (
  echo v18.20.4
  exit /b 0
)
echo node-called>"%EJ_NODE_MARKER%"
echo SyntaxError: styleText 1>&2
exit /b 1
'@ | Set-Content -LiteralPath (Join-Path $shim "node.cmd") -Encoding ASCII
    @'
@echo off
echo npx-called>"%EJ_NODE_MARKER%"
echo SyntaxError: styleText 1>&2
echo npm warn EBADENGINE unsupported engine 1>&2
exit /b 1
'@ | Set-Content -LiteralPath (Join-Path $shim "npx.cmd") -Encoding ASCII
    $sep = ";"
} else {
    @'
#!/bin/sh
if [ "${1:-}" = "-v" ]; then printf '%s\n' "v18.20.4"; exit 0; fi
if [ -n "${EJ_NODE_MARKER:-}" ]; then printf '%s\n' "node $*" > "$EJ_NODE_MARKER"; fi
printf '%s\n' "SyntaxError: styleText" >&2
exit 1
'@ | Set-Content -LiteralPath (Join-Path $shim "node") -Encoding ASCII
    @'
#!/bin/sh
if [ -n "${EJ_NODE_MARKER:-}" ]; then printf '%s\n' "npx $*" > "$EJ_NODE_MARKER"; fi
printf '%s\n' "SyntaxError: styleText" >&2
printf '%s\n' "npm warn EBADENGINE unsupported engine" >&2
exit 1
'@ | Set-Content -LiteralPath (Join-Path $shim "npx") -Encoding ASCII
    foreach ($name in @("node", "npx")) { & chmod +x (Join-Path $shim $name) }
    $sep = ":"
}
$code = Invoke-Install $c $Install @("--scope", "personal") @{ EJ_NODE_MARKER = $marker } ($shim + $sep + $OrigPath)
Assert-Status $code 1 "Node 18 exits 1" $c
Assert-Has $c.Err "Node.js 22.20 or later is required. Found v18.20.4." "Node 18 names the installed version"
Assert-Has $c.Err "https://nodejs.org" "Node 18 tells you where to install Node"
Assert-Has $c.Err "Nothing was installed. Rerunning is safe." "Node 18 says rerunning is safe"
Assert-Lacks $c.Err "styleText" "Node 18 does not reach the skills CLI stack trace"
Assert-Lacks $c.Out "styleText" "Node 18 stdout has no skills CLI stack trace"
if (Test-Path -LiteralPath $marker) { Bad "Node 18 invoked node or npx for more than node -v" } else { Ok "Node 18 stops before npx" }
Assert-Clean $c.Home "Node 18 does not save a scope file or agents"

$node18 = "/tmp/node18/node-v18.20.4-linux-x64/bin/node"
if (-not $Windows -and (Test-Path -LiteralPath $node18)) {
    $c = New-Case
    $code = Invoke-Install $c $Install @("--scope", "personal") $null ("/tmp/node18/node-v18.20.4-linux-x64/bin" + $sep + $OrigPath)
    Assert-Status $code 1 "real Node 18.20.4 exits 1" $c
    Assert-Has $c.Err "Node.js 22.20 or later is required. Found v18.20.4." "real Node 18.20.4 names the version"
    Assert-Lacks $c.Err "styleText" "real Node 18.20.4 does not print styleText"
    Assert-Clean $c.Home "real Node 18.20.4 writes nothing"
} else { Write-Output "SKIP: real Node 18.20.4 binary is not installed" }

$c = New-Case
$emptyBin = Join-Path $c.Case "empty-bin"
New-Item -ItemType Directory -Force -Path $emptyBin | Out-Null
$missingPath = if ($Windows) { "$emptyBin;C:\Windows\System32" } else { "${emptyBin}:/bin:/usr/bin" }
$code = Invoke-Install $c $Install @("--scope", "personal") $null $missingPath
Assert-Status $code 1 "missing node exits 1" $c
$missingText = Read-Text $c.Err
if ($missingText.Contains("node was not found") -or $missingText.Contains("npx was not found")) {
    Ok "missing node says node or npx was not found"
} else {
    Bad "missing node says node or npx was not found"
    Write-Output $missingText
}
Assert-Clean $c.Home "missing node writes nothing"

$c = New-Case
$copy = Join-Path $c.Case "copy"
New-Item -ItemType Directory -Force -Path $copy | Out-Null
Copy-Item $Install, $Pins, (Join-Path $Root "install/agents.txt") $copy
$pinsCopy = Join-Path $copy "pins.txt"
$text = [IO.File]::ReadAllText($pinsCopy) -replace "agent requirements-analyst\s+\S+", "agent requirements-analyst main"
[IO.File]::WriteAllText($pinsCopy, $text)
$code = Invoke-Install $c (Join-Path $copy "install.ps1") @("--scope", "personal")
Assert-Status $code 1 "branch name in pins.txt exits 1" $c
Assert-Has $c.Err "full 40-character commit SHA, not 'main'" "branch pin is rejected"
Assert-Clean $c.Home "bad pin writes nothing"

$c = New-Case
$copy = Join-Path $c.Case "copy"
New-Item -ItemType Directory -Force -Path $copy | Out-Null
Copy-Item $Install, $Pins, (Join-Path $Root "install/agents.txt") $copy
Add-Content -LiteralPath (Join-Path $copy "agents.txt") "not-a-real-agent"
$code = Invoke-Install $c (Join-Path $copy "install.ps1") @("--scope", "personal")
Assert-Status $code 1 "agents.txt drift exits 1" $c
Assert-Has $c.Err "install/pins.txt and install/agents.txt list different agents" "agents.txt drift is named"
Assert-Clean $c.Home "agents.txt drift writes nothing"

$c = New-Case
$code = Invoke-Install $c $Install @("--scope", "personal") $null $null "pipe"
Assert-Status $code 1 "piped install.ps1 without --ref exits 1" $c
Assert-Has $c.Err "started from a pipe" "piped install.ps1 explains the pipe"
Assert-Has $c.Err "install/pins.txt" "piped install.ps1 points at the pin file"
Assert-Clean $c.Home "piped install.ps1 writes nothing"

$c = New-Case
$code = Invoke-Install $c $Update @() $null $null "pipe"
Assert-Status $code 1 "piped update.ps1 without --ref exits 1" $c
Assert-Has $c.Err "update.ps1 was started from a pipe" "piped update.ps1 explains the pipe"
Assert-Clean $c.Home "piped update.ps1 writes nothing"

$c = New-Case
$scopeDir = Join-Path $c.Home ".engineering-judgment"
New-Item -ItemType Directory -Force -Path $scopeDir | Out-Null
[IO.File]::WriteAllText((Join-Path $scopeDir "install-scope"), "project`n")
$code = Invoke-Install $c $Install @()
Assert-Status $code 2 "legacy global project scope exits 2" $c
Assert-Has $c.Err "remembered project scope for every folder" "legacy project scope explains the change"
Assert-Has $c.Err "--scope project" "legacy project scope tells you how to rerun"
Assert-Clean $c.Work "legacy project scope does not install into the current folder"
if ((Test-Path (Join-Path $c.Home ".claude")) -or (Test-Path (Join-Path $c.Home ".agents"))) { Bad "legacy project scope installed files" } else { Ok "legacy project scope installs nothing" }

$c = New-Case
$badPins = Join-Path $c.Case "bad-pins.txt"
@"
hub engineering-judgment-skill $Hub
agent requirements-analyst $Req
agent csharp-expert-developer 0000000000000000000000000000000000000000
"@ | Set-Content -LiteralPath $badPins -Encoding ASCII
$code = Invoke-Install $c $Install @("--scope", "personal") @{ EJ_PINS = $badPins }
Assert-Status $code 1 "bad agent ref exits 1" $c
Assert-Has $c.Err "Failed to download csharp-expert-developer .claude/agents/csharp-expert-developer.md." "bad ref names the agent file"
Assert-Has $c.Err "0000000000000000000000000000000000000000" "bad ref prints the URL"
Assert-Has $c.Err "Nothing was installed. Rerunning is safe." "bad ref says rerunning is safe"
Assert-Clean $c.Home "bad ref does not leave the earlier agent installed"
Assert-Lacks $c.Out "Skill: engineering-judgment" "bad ref stops before npx skills add"

$c = New-Case
$code = Invoke-Install $c $Install @("--scope", "personal") @{ EJ_RAW_ROOT = "http://127.0.0.1:9" }
Assert-Status $code 1 "network failure exits 1" $c
Assert-Has $c.Err "Failed to download requirements-analyst .claude/agents/requirements-analyst.md." "network failure names the first file"
Assert-Has $c.Err "127.0.0.1" "network failure prints the URL"
Assert-Has $c.Err "Nothing was installed. Rerunning is safe." "network failure says rerunning is safe"
Assert-Clean $c.Home "network failure writes nothing"

function New-GitShim([string]$Dir) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $body = @'
#!/bin/sh
printf '%s\n' "$*" > "${EJ_GIT_LOG:?}"
if [ "${1:-}" != "ls-remote" ]; then
  printf '%s\n' "unexpected git $*" >> "$EJ_GIT_LOG"
  exit 1
fi
case "$*" in
  *refs/heads/cursor/feature*)
    printf '%s\t%s\n' "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "refs/heads/cursor/feature"
    ;;
  *refs/tags/v9.9.9*)
    printf '%s\t%s\n' "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "refs/tags/v9.9.9"
    printf '%s\t%s\n' "cccccccccccccccccccccccccccccccccccccccc" "refs/tags/v9.9.9^{}"
    ;;
  *refs/heads/both-ej*)
    printf '%s\t%s\n' "dddddddddddddddddddddddddddddddddddddddd" "refs/heads/both-ej"
    printf '%s\t%s\n' "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" "refs/tags/both-ej"
    ;;
esac
exit 0
'@
    if ($Windows) {
        $py = Join-Path $Dir "git-shim.py"
        @'
import os, sys
log = os.environ["EJ_GIT_LOG"]
args = " ".join(sys.argv)
with open(log, "w", encoding="utf-8") as fh:
    fh.write(args + "\n")
if len(sys.argv) < 2 or sys.argv[1] != "ls-remote":
    sys.exit(1)
if "refs/heads/cursor/feature" in args:
    sys.stdout.write("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/heads/cursor/feature\n")
elif "refs/tags/v9.9.9" in args:
    sys.stdout.write("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/v9.9.9\n")
    sys.stdout.write("cccccccccccccccccccccccccccccccccccccccc\trefs/tags/v9.9.9^{}\n")
elif "refs/heads/both-ej" in args:
    sys.stdout.write("dddddddddddddddddddddddddddddddddddddddd\trefs/heads/both-ej\n")
    sys.stdout.write("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\trefs/tags/both-ej\n")
sys.exit(0)
'@ | Set-Content -LiteralPath $py -Encoding ASCII
        @"
@echo off
py -3 "%~dp0git-shim.py" %*
"@ | Set-Content -LiteralPath (Join-Path $Dir "git.cmd") -Encoding ASCII
    } else {
        $body | Set-Content -LiteralPath (Join-Path $Dir "git") -Encoding ASCII
        & chmod +x (Join-Path $Dir "git")
    }
}

$c = New-Case
$shim = Join-Path $c.Case "git-shim"
New-GitShim $shim
$gitLog = Join-Path $c.Case "git.log"
$shimPath = $shim + $sep + $OrigPath
$code = Invoke-Install $c $Install @("--scope", "personal", "--ref", "cursor/feature") @{ EJ_RAW_ROOT = "http://127.0.0.1:9"; EJ_GIT_LOG = $gitLog } $shimPath
Assert-Status $code 1 "slash branch ref exits 1 before install" $c
Assert-Has $c.Out "Hub: engineering-judgment-skill @ aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa (--ref cursor/feature resolved" "slash branch resolves to the commit SHA"
Assert-Has $gitLog "refs/heads/cursor/feature" "slash branch asks git for the full branch ref"
$peelLog = Read-Text $gitLog
# cmd.exe treats ^ as an escape, so a git.cmd shim records refs/tags/name{} for the peeled pattern.
if ($peelLog.Contains("refs/tags/cursor/feature^{}") -or $peelLog.Contains("refs/tags/cursor/feature{}")) {
    Ok "slash branch also asks git for a peeled tag"
} else {
    Bad "slash branch also asks git for a peeled tag"
    Write-Output $peelLog
}
Assert-Lacks $c.Out "Skill: engineering-judgment" "slash branch stops before npx"
Assert-Lacks $c.Err "Remote branch cursor" "slash branch does not clone the name before the slash"
Assert-Clean $c.Home "slash branch writes nothing"

$c = New-Case
New-GitShim (Join-Path $c.Case "git-shim")
$code = Invoke-Install $c $Install @("--scope", "personal", "--ref", "v9.9.9") @{ EJ_RAW_ROOT = "http://127.0.0.1:9"; EJ_GIT_LOG = (Join-Path $c.Case "git.log") } ((Join-Path $c.Case "git-shim") + $sep + $OrigPath)
Assert-Status $code 1 "annotated tag ref exits 1 before install" $c
Assert-Has $c.Out "Hub: engineering-judgment-skill @ cccccccccccccccccccccccccccccccccccccccc (--ref v9.9.9 resolved" "annotated tag uses the peeled commit"
Assert-Lacks $c.Out "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "annotated tag does not use the tag object"

$c = New-Case
New-GitShim (Join-Path $c.Case "git-shim")
$code = Invoke-Install $c $Install @("--scope", "personal", "--ref", "both-ej") @{ EJ_GIT_LOG = (Join-Path $c.Case "git.log") } ((Join-Path $c.Case "git-shim") + $sep + $OrigPath)
Assert-Status $code 1 "ambiguous ref exits 1" $c
Assert-Has $c.Err "matches both a branch" "ambiguous ref names the collision"
Assert-Has $c.Err "Nothing was installed. Rerunning is safe." "ambiguous ref says rerunning is safe"
Assert-Clean $c.Home "ambiguous ref writes nothing"

$c = New-Case
New-GitShim (Join-Path $c.Case "git-shim")
$code = Invoke-Install $c $Install @("--scope", "personal", "--ref", "missing-ej-ref") @{ EJ_GIT_LOG = (Join-Path $c.Case "git.log") } ((Join-Path $c.Case "git-shim") + $sep + $OrigPath)
Assert-Status $code 1 "unknown ref exits 1" $c
Assert-Has $c.Err "Could not resolve hub ref 'missing-ej-ref'" "unknown ref is named"
Assert-Clean $c.Home "unknown ref writes nothing"

$c = New-Case
$shaShim = Join-Path $c.Case "git-shim"
New-Item -ItemType Directory -Force -Path $shaShim | Out-Null
$shaLog = Join-Path $c.Case "git.log"
if ($Windows) {
    @'
@echo off
echo %*>>"%EJ_GIT_LOG%"
exit /b 1
'@ | Set-Content -LiteralPath (Join-Path $shaShim "git.cmd") -Encoding ASCII
} else {
    @'
#!/bin/sh
printf '%s\n' "$*" > "${EJ_GIT_LOG:?}"
exit 1
'@ | Set-Content -LiteralPath (Join-Path $shaShim "git") -Encoding ASCII
    & chmod +x (Join-Path $shaShim "git")
}
$code = Invoke-Install $c $Install @("--scope", "personal", "--ref", $Hub) @{ EJ_RAW_ROOT = "http://127.0.0.1:9"; EJ_GIT_LOG = $shaLog } ($shaShim + $sep + $OrigPath)
Assert-Status $code 1 "full SHA ref exits 1 before install" $c
Assert-Has $c.Out "Hub: engineering-judgment-skill @ $Hub (--ref override" "full SHA is used unchanged"
if (Test-Path -LiteralPath $shaLog) { Bad "full SHA ref called git"; Write-Output (Read-Text $shaLog) } else { Ok "full SHA ref does not ask git to resolve it" }
Assert-Clean $c.Home "full SHA ref writes nothing"

$remoteBranch = "cursor/reproducible-installs-3628"
$remoteLines = @( & git ls-remote "https://github.com/dimitriskl/engineering-judgment-skill.git" "refs/heads/$remoteBranch" 2>$null )
$remoteSha = ""
if ($LASTEXITCODE -eq 0 -and $remoteLines.Count -gt 0) { $remoteSha = ("$($remoteLines[0])" -split "\s+", 2)[0].Trim() }
if ($remoteSha -match '^[0-9a-fA-F]{40}$') {
    $c = New-Case
    $code = Invoke-Install $c $Install @("--scope", "personal", "--ref", $remoteBranch) @{ EJ_RAW_ROOT = "http://127.0.0.1:9" }
    Assert-Status $code 1 "live slash branch exits 1 before install" $c
    Assert-Has $c.Out "Hub: engineering-judgment-skill @ $remoteSha (--ref $remoteBranch resolved" "live slash branch matches git ls-remote"
    Assert-Lacks $c.Err "Remote branch cursor" "live slash branch does not clone the short name"
    Assert-Clean $c.Home "live slash branch writes nothing"
} else {
    Write-Output "SKIP: refs/heads/$remoteBranch is not on origin"
}

$c = New-Case
$utf8 = New-Object System.Text.UTF8Encoding $false
$claudeAgents = Join-Path $c.Home ".claude/agents"
$codex = Join-Path $c.Home ".codex"
New-Item -ItemType Directory -Force -Path $claudeAgents, $codex | Out-Null
$settings = Join-Path $c.Home ".claude/settings.json"
$settingsText = "{`n  `"env`": {`n    `"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`": `"70`",`n    `"OTHER`": `"kept`"`n  }`n}`n"
[IO.File]::WriteAllText($settings, $settingsText, $utf8)
$before = Join-Path $c.Case "settings-before.json"
[IO.File]::WriteAllText($before, $settingsText, $utf8)
[IO.File]::WriteAllText((Join-Path $codex "config.toml"), "personality = `"pragmatic`"`n`n[mcp]`nenabled = true`n", $utf8)
[IO.File]::WriteAllText((Join-Path $claudeAgents "requirements-analyst.md"), "PREEXISTING-AGENT-EDIT`n", $utf8)
$code = Invoke-Install $c $Install @("--scope", "personal")
Assert-Status $code 0 "fresh personal install exits 0" $c
Assert-Has $c.Out "Scope: personal (" "personal install announces personal scope"
Assert-Has $c.Out "Hub: engineering-judgment-skill @ $Hub" "personal install prints the hub pin"
Assert-Has $c.Out "Agent: requirements-analyst @ $Req" "personal install prints the agent pin"
Assert-Has $c.Out "updated    $(Join-Path $claudeAgents 'requirements-analyst.md')" "pre-existing agent file is backed up"
Assert-Has $c.Out ".engineering-workflow.json" "personal install prints the workflow command"
Assert-Clean $c.Work "personal install leaves the working folder free of project agents"
$scopeText = (Read-Text (Join-Path $c.Home ".engineering-judgment/install-scope")).Trim()
if ($scopeText -eq "personal") { Ok "personal scope is remembered under the user directory" } else { Bad "personal scope file was not saved" }
$tomlDir = Join-Path $c.Home ".codex/agents"
$mdCount = if (Test-Path -LiteralPath $claudeAgents) { @(Get-ChildItem -LiteralPath $claudeAgents -Filter *.md).Count } else { 0 }
$tomlCount = if (Test-Path -LiteralPath $tomlDir) { @(Get-ChildItem -LiteralPath $tomlDir -Filter *.toml).Count } else { 0 }
if ($mdCount -eq 8 -and $tomlCount -eq 8) { Ok "personal install places 8 agents in both hosts" } else { Bad "personal install placed $mdCount markdown and $tomlCount toml files" }
$remoteMd = Join-Path $c.Case "remote.md"
$remoteToml = Join-Path $c.Case "remote.toml"
$remoteSkill = Join-Path $c.Case "remote-skill.md"
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/dimitriskl/requirements-analyst/$Req/.claude/agents/requirements-analyst.md" -OutFile $remoteMd | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/dimitriskl/requirements-analyst/$Req/.codex/agents/requirements-analyst.toml" -OutFile $remoteToml | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/dimitriskl/engineering-judgment-skill/$Hub/skills/engineering-judgment/SKILL.md" -OutFile $remoteSkill | Out-Null
$installedMd = Join-Path $claudeAgents "requirements-analyst.md"
$installedToml = Join-Path $c.Home ".codex/agents/requirements-analyst.toml"
if ((Get-FileHash $remoteMd).Hash -eq (Get-FileHash $installedMd).Hash -and (Get-FileHash $remoteToml).Hash -eq (Get-FileHash $installedToml).Hash) {
    Ok "installed agent files match the pinned commits"
} else { Bad "installed agent files do not match the pinned commits" }
$skill = Get-ChildItem -LiteralPath $c.Home -Force -Recurse -Filter SKILL.md -File | Where-Object { $_.Directory.Name -eq "engineering-judgment" } | Select-Object -First 1
if ($skill -and (Get-FileHash $remoteSkill).Hash -eq (Get-FileHash $skill.FullName).Hash) { Ok "installed skill matches the pinned hub commit" } else { Bad "installed skill does not match the pinned hub commit" }
$lock = Get-ChildItem -LiteralPath $c.Home -Recurse -Force -File | Where-Object { $_.Name -eq ".skill-lock.json" -or $_.Name -eq "skills-lock.json" } | Select-Object -First 1
if ($lock -and (Read-Text $lock.FullName).Contains($Hub)) { Ok "skill lock records the hub pin" } else { Bad "skill lock does not record the hub pin" }
if ((Get-FileHash $before).Hash -eq (Get-FileHash $settings).Hash) { Ok "existing auto-compact value is kept" } else { Bad "existing Claude settings were rewritten" }
$tomlText = Read-Text (Join-Path $c.Home ".codex/config.toml")
$keyAt = $tomlText.IndexOf("model_auto_compact_token_limit")
$tableAt = $tomlText.IndexOf("[mcp]")
if ($tomlText.Contains('personality = "pragmatic"') -and $keyAt -ge 0 -and $tableAt -gt $keyAt) { Ok "auto-compact key is inserted before the first TOML table" } else { Bad "Codex config.toml was not updated correctly"; Write-Output $tomlText }
$baks = @(Get-ChildItem -LiteralPath $claudeAgents -Filter "requirements-analyst.md.bak-*" -File)
if ($baks.Count -eq 1 -and (Read-Text $baks[0].FullName).Contains("PREEXISTING-AGENT-EDIT")) { Ok "pre-existing agent file is kept as a timestamped backup" } else { Bad "expected one timestamped backup of the pre-existing file" }

$code = Invoke-Install $c $Update @()
Assert-Status $code 0 "update.ps1 over a personal install exits 0" $c
Assert-Has $c.Out "up to date" "update.ps1 reports files that are already current"
Assert-Has $c.Out "Remembered for your user account" "update.ps1 reuses the saved personal scope"
$bakCount = @(Get-ChildItem -LiteralPath $claudeAgents -Filter "requirements-analyst.md.bak-*" -File).Count
if ($bakCount -eq 1) { Ok "an update of an unchanged file does not add another backup" } else { Bad "unchanged update created backups (count $bakCount)" }

[IO.File]::WriteAllText($installedMd, "SECOND-AGENT-EDIT`n", $utf8)
$code = Invoke-Install $c $Install @()
Assert-Status $code 0 "update after a local edit exits 0" $c
[IO.File]::WriteAllText($installedMd, "THIRD-AGENT-EDIT`n", $utf8)
$code = Invoke-Install $c $Install @()
Assert-Status $code 0 "second update after a local edit exits 0" $c
if ((Get-FileHash $remoteMd).Hash -eq (Get-FileHash $installedMd).Hash) { Ok "the installed agent matches the pin after two edits" } else { Bad "the installed agent does not match the pin after two edits" }
$found = @{ pre = 0; second = 0; third = 0 }
Get-ChildItem -LiteralPath $claudeAgents -Filter "requirements-analyst.md.bak-*" -File | ForEach-Object {
    $body = Read-Text $_.FullName
    if ($body.Contains("PREEXISTING-AGENT-EDIT")) { $found.pre++ }
    if ($body.Contains("SECOND-AGENT-EDIT")) { $found.second++ }
    if ($body.Contains("THIRD-AGENT-EDIT")) { $found.third++ }
}
if ($found.pre -eq 1 -and $found.second -eq 1 -and $found.third -eq 1) { Ok "each local edit is kept in its own backup" } else { Bad "backup contents were overwritten (pre=$($found.pre) second=$($found.second) third=$($found.third))" }

$c = New-Case
$projA = Join-Path $c.Case "project-a"
$projB = Join-Path $c.Case "project-b"
New-Item -ItemType Directory -Force -Path $projA, $projB | Out-Null
$code = Invoke-Install $c $Install @("--scope", "project") $null $null "file" $projA
Assert-Status $code 0 "fresh project install exits 0" $c
Assert-Has $c.Out "Scope: project (" "project install announces project scope"
Assert-Has $c.Out "Config: .engineering-workflow.json added" "project install adds the workflow file"
if ((Test-Path (Join-Path $c.Home ".claude/agents")) -or (Test-Path (Join-Path $c.Home ".agents"))) { Bad "project install wrote agents into the user directory" } else { Ok "project install does not write agents into the user directory" }
$marker = (Read-Text (Join-Path $projA ".engineering-judgment/install-scope")).Trim()
if ($marker -eq "project") { Ok "project scope is stored in the project folder" } else { Bad "project scope marker is missing" }
if (Test-Path (Join-Path $c.Home ".engineering-judgment/install-scope")) { Bad "project install wrote a user-wide scope file" } else { Ok "project install does not remember project scope for every folder" }
$remoteWorkflow = Join-Path $c.Case "workflow.json"
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/dimitriskl/engineering-judgment-skill/$Hub/.engineering-workflow.json" -OutFile $remoteWorkflow | Out-Null
$workflowPath = Join-Path $projA ".engineering-workflow.json"
if ((Get-FileHash $remoteWorkflow).Hash -eq (Get-FileHash $workflowPath).Hash) { Ok "project workflow file matches the hub pin" } else { Bad "project workflow file does not match the hub pin" }
$projSkill = Get-ChildItem -LiteralPath $projA -Force -Recurse -Filter SKILL.md -File | Where-Object { $_.Directory.Name -eq "engineering-judgment" } | Select-Object -First 1
if ($projSkill -and (Get-FileHash $remoteSkill).Hash -eq (Get-FileHash $projSkill.FullName).Hash) { Ok "project skill matches the pinned hub commit" } else { Bad "project skill does not match the pinned hub commit" }
[IO.File]::WriteAllText($workflowPath, "{`"kept`":true}`n", $utf8)
$code = Invoke-Install $c $Install @() $null $null "file" $projA
Assert-Status $code 0 "project update without a flag exits 0" $c
Assert-Has $c.Out "Remembered for this folder only" "a later run in the project folder stays on project scope"
Assert-Has $c.Out "Config: .engineering-workflow.json kept as is" "an existing workflow file is kept"
if ((Read-Text $workflowPath).Contains('"kept":true')) { Ok "the existing workflow file was not replaced" } else { Bad "the existing workflow file was replaced" }

$code = Invoke-Install $c $Install @() @{ EJ_RAW_ROOT = "http://127.0.0.1:9" } $null "file" $projB
Assert-Status $code 1 "another folder does not continue a project install" $c
Assert-Has $c.Out "Scope: personal (" "another folder defaults to personal scope"
Assert-Lacks $c.Out "Scope: project (" "another folder does not announce project scope"
Assert-Clean $projB "another folder receives no project files"

Write-Output ""
Write-Output "$($script:Passes) passed, $($script:Fails) failed"
# pwsh -Command, which is how Actions runs this file, keeps the last native
# exit code. The final case expects the installer to exit 1, so exit explicitly.
if ($script:Fails -ne 0) { exit 1 }
exit 0
