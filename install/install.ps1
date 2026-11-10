# Installs or updates the engineering-judgment skill and the pinned agents (Windows PowerShell 5.1 or 7+).
# From a checkout:  pwsh -File install/install.ps1
# From a pipe:      $env:EJ_REF = '<commit-tag-or-branch>'; irm <raw>/install/install.ps1 | iex
# Pins: install/pins.txt (full commit SHAs). --ref / EJ_REF overrides only the hub ref.
# Change scope with --scope personal|project or EJ_SCOPE. Project scope sticks to that folder.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$script:RanAsFile = [bool]$PSCommandPath
$Owner = "dimitriskl"
$RawRoot = if ($env:EJ_RAW_ROOT) { $env:EJ_RAW_ROOT.Trim().TrimEnd("/") } else { "https://raw.githubusercontent.com" }
$Scope = if ($env:EJ_SCOPE) { $env:EJ_SCOPE.Trim() } else { "" }
$RefOverride = if ($env:EJ_REF) { $env:EJ_REF.Trim() } else { "" }
$ExplicitScope = [bool]$Scope

function Fail([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine($Message)
    if ($script:RanAsFile) { exit $Code }
    $global:LASTEXITCODE = $Code
    throw $Message
}
function Get-Usage {
    @"
Usage: install.ps1 [--scope personal|project] [--ref <commit-tag-or-branch>]

Installs the engineering-judgment skill and the agents pinned in install/pins.txt.
Personal scope is remembered for your user account. Project scope is remembered only in that folder.

  --scope personal|project   where to install (or set EJ_SCOPE)
  --ref <ref>                hub commit, tag, or branch for this run (or set EJ_REF)
  EJ_PINS                    path to an alternate pins file
  EJ_RAW_ROOT                raw download host (default https://raw.githubusercontent.com)
"@
}
function Test-Console {
    try { return (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected) }
    catch { return $false }
}
function Assert-Node {
    # Checked before scope is saved and before any download or npx call.
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Fail "Node.js 22.20 or later is required, but node was not found.`nInstall Node.js 22.20 or newer from https://nodejs.org and run this installer again.`nNothing was installed. Rerunning is safe."
    }
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Fail "Node.js 22.20 or later is required, but npx was not found.`nInstall Node.js 22.20 or newer from https://nodejs.org and run this installer again.`nNothing was installed. Rerunning is safe."
    }
    $ver = ""
    try { $ver = (& node -v 2>$null | Out-String).Trim() } catch { $ver = "" }
    if ($ver -notmatch '^v(\d+)\.(\d+)(\.\d+)?$') {
        $shown = if ($ver) { $ver } else { "nothing" }
        Fail "Node.js 22.20 or later is required. Could not read the version from node -v (got: $shown).`nInstall Node.js 22.20 or newer from https://nodejs.org and run this installer again.`nNothing was installed. Rerunning is safe."
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 20)) {
        Fail "Node.js 22.20 or later is required. Found $ver.`nInstall Node.js 22.20 or newer from https://nodejs.org and run this installer again.`nNothing was installed. Rerunning is safe."
    }
}
function Save-Download([string]$Url, [string]$Dest, [string]$Label) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Dest -TimeoutSec 60 | Out-Null
    } catch {
        if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue }
        Fail "Failed to download $Label.`nURL: $Url`n$($_.Exception.Message)`nNothing was installed. Rerunning is safe."
    }
    if (-not (Test-Path -LiteralPath $Dest) -or (Get-Item -LiteralPath $Dest).Length -eq 0) {
        Fail "Failed to download ${Label}: the file was empty.`nURL: $Url`nNothing was installed. Rerunning is safe."
    }
}
function Get-BackupPath([string]$Target) {
    $stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
    $candidate = "$Target.bak-$stamp"
    $n = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = "$Target.bak-$stamp-$n"
        $n++
    }
    return $candidate
}
function Install-AgentFile([string]$Source, [string]$Target) {
    $dir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path -LiteralPath $Target)) {
        Copy-Item -LiteralPath $Source -Destination $Target
        Write-Output "    installed  $Target"
        return
    }
    if ((Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Target).Hash) {
        Write-Output "    up to date $Target"
        return
    }
    $bak = Get-BackupPath $Target
    Copy-Item -LiteralPath $Target -Destination $bak
    Copy-Item -LiteralPath $Source -Destination $Target -Force
    Write-Output "    updated    $Target (old file: $bak)"
}

$scriptArgs = @($args)
$i = 0
while ($i -lt $scriptArgs.Count) {
    $token = "$($scriptArgs[$i])"
    if ($token -eq "--help" -or $token -eq "-h" -or $token -eq "-?") {
        Write-Output (Get-Usage)
        if ($script:RanAsFile) { exit 0 }
        return
    }
    if ($token -eq "--scope" -or $token -eq "-Scope" -or $token -eq "-scope") {
        $next = if ($i + 1 -lt $scriptArgs.Count) { "$($scriptArgs[$i + 1])" } else { "" }
        if (-not $next -or $next.StartsWith("-")) {
            Fail "Missing value for --scope.`n$(Get-Usage)`nNothing was installed. Rerunning is safe." 2
        }
        $Scope = $next
        $ExplicitScope = $true
        $i += 2
        continue
    }
    if ($token -eq "--ref" -or $token -eq "-Ref" -or $token -eq "-ref") {
        $next = if ($i + 1 -lt $scriptArgs.Count) { "$($scriptArgs[$i + 1])" } else { "" }
        if (-not $next -or $next.StartsWith("-")) {
            Fail "Missing value for --ref.`n$(Get-Usage)`nNothing was installed. Rerunning is safe." 2
        }
        $RefOverride = $next
        $i += 2
        continue
    }
    Fail "Unknown option: $token`n$(Get-Usage)`nNothing was installed. Rerunning is safe." 2
}

Assert-Node

if ($env:EJ_RAW) {
    Fail "EJ_RAW is no longer used. Set EJ_REF to a commit, tag, or branch, or set EJ_PINS to a pins file.`nNothing was installed. Rerunning is safe."
}
if ($RawRoot -notmatch '^https?://') {
    Fail "EJ_RAW_ROOT must start with http:// or https://.`nNothing was installed. Rerunning is safe."
}
$UserHome = $env:USERPROFILE
if (-not $UserHome) { $UserHome = $env:HOME }
if (-not $UserHome) {
    Fail "USERPROFILE or HOME must be set so the installer can find your user directory.`nNothing was installed. Rerunning is safe."
}

$ScriptDir = $null
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
}
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("ej-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false

try {
    $pinsFile = $null
    $agentsFile = $null
    if ($env:EJ_PINS) {
        $pinsFile = $env:EJ_PINS
        if (-not (Test-Path -LiteralPath $pinsFile)) {
            Fail "Pins file not found: $pinsFile`nNothing was installed. Rerunning is safe."
        }
    } elseif ($ScriptDir -and (Test-Path -LiteralPath (Join-Path $ScriptDir "pins.txt"))) {
        $pinsFile = Join-Path $ScriptDir "pins.txt"
        $agentsFile = Join-Path $ScriptDir "agents.txt"
    } else {
        if (-not $RefOverride) {
            Fail "This installer was started from a pipe and has no local install/pins.txt.`nRun it from a checkout, or pass --ref <commit-tag-or-branch> (or set EJ_REF) so install/pins.txt can be downloaded.`nNothing was installed. Rerunning is safe."
        }
        $base = "$RawRoot/$Owner/engineering-judgment-skill/$RefOverride/install"
        $pinsFile = Join-Path $Tmp "pins.txt"
        $agentsFile = Join-Path $Tmp "agents.txt"
        Save-Download "$base/pins.txt" $pinsFile "install/pins.txt"
        Save-Download "$base/agents.txt" $agentsFile "install/agents.txt"
        $ScriptDir = $Tmp
    }

    $HubName = ""
    $HubSha = ""
    $agents = @()
    $seen = @{}
    $lineNo = 0
    foreach ($raw in [IO.File]::ReadAllLines($pinsFile)) {
        $lineNo++
        $line = ($raw -split "#", 2)[0].Trim()
        if (-not $line) { continue }
        $parts = $line -split '\s+'
        if ($parts.Count -ne 3) {
            Fail "install/pins.txt:${lineNo} must be: hub|agent <repo> <40-character sha>`nNothing was installed. Rerunning is safe."
        }
        $kind = $parts[0]
        $name = $parts[1]
        $sha = $parts[2]
        if ($name -notmatch '^[A-Za-z0-9._-]+$') {
            Fail "install/pins.txt:${lineNo} has an invalid repository name '$name'.`nNothing was installed. Rerunning is safe."
        }
        if ($sha -notmatch '^[0-9a-fA-F]{40}$') {
            Fail "Pin for $name must be a full 40-character commit SHA, not '$sha'. Branches and tags are not pins.`nNothing was installed. Rerunning is safe."
        }
        if ($kind -eq "hub") {
            if ($HubName) { Fail "install/pins.txt has more than one hub line.`nNothing was installed. Rerunning is safe." }
            $HubName = $name
            $HubSha = $sha
        } elseif ($kind -eq "agent") {
            if ($seen.ContainsKey($name)) { Fail "install/pins.txt lists $name more than once.`nNothing was installed. Rerunning is safe." }
            $seen[$name] = $true
            $agents += [pscustomobject]@{ Name = $name; Sha = $sha }
        } else {
            Fail "install/pins.txt:${lineNo} has an unknown kind '$kind'. Use hub or agent.`nNothing was installed. Rerunning is safe."
        }
    }
    if (-not $HubSha) { Fail "install/pins.txt has no hub line.`nNothing was installed. Rerunning is safe." }
    if ($agents.Count -lt 1) { Fail "install/pins.txt has no agent lines.`nNothing was installed. Rerunning is safe." }

    if (-not $env:EJ_PINS) {
        if (-not $agentsFile -or -not (Test-Path -LiteralPath $agentsFile)) {
            Fail "Missing install/agents.txt beside the pins file.`nNothing was installed. Rerunning is safe."
        }
        $listed = @()
        foreach ($raw in [IO.File]::ReadAllLines($agentsFile)) {
            $line = ($raw -split "#", 2)[0].Trim()
            if ($line) { $listed += $line }
        }
        $pinNames = @($agents | ForEach-Object { $_.Name } | Sort-Object)
        $listNames = @($listed | Sort-Object)
        $pinKey = $pinNames -join "`n"
        $listKey = $listNames -join "`n"
        $pinUnique = @($pinNames | Select-Object -Unique)
        $listUnique = @($listNames | Select-Object -Unique)
        if ($pinUnique.Count -ne $pinNames.Count -or $listUnique.Count -ne $listNames.Count -or $pinKey -ne $listKey) {
            Fail "install/pins.txt and install/agents.txt list different agents.`nNothing was installed. Rerunning is safe."
        }
    }

    $reason = "chosen"
    $cwd = (Get-Location).Path
    if (-not $ExplicitScope) {
        $cwdMarker = Join-Path (Join-Path $cwd ".engineering-judgment") "install-scope"
        $globalFile = Join-Path (Join-Path $UserHome ".engineering-judgment") "install-scope"
        if (Test-Path -LiteralPath $cwdMarker) {
            $markerValue = ([IO.File]::ReadAllText($cwdMarker)).Trim()
            if ($markerValue -ne "project") {
                Fail "Project scope file $cwdMarker must contain project, not '$markerValue'.`nNothing was installed. Rerunning is safe." 2
            }
            $Scope = "project"
            $reason = "remembered-project"
        } elseif (Test-Path -LiteralPath $globalFile) {
            $globalValue = ([IO.File]::ReadAllText($globalFile)).Trim()
            if ($globalValue -eq "personal") {
                $Scope = "personal"
                $reason = "remembered-personal"
            } elseif ($globalValue -eq "project") {
                Fail "A previous install remembered project scope for every folder. Project scope now applies only to the folder it was installed in.`nNothing was installed. Run again in that project with --scope project, or choose a personal install with --scope personal.`nRerunning is safe." 2
            } else {
                Fail "Scope must be personal or project, not '$globalValue'.`nNothing was installed. Rerunning is safe." 2
            }
        } elseif (Test-Console) {
            Write-Output "Where should the skill and agents be installed?"
            Write-Output "  1) personal - all your projects (~/.agents, ~/.claude, ~/.codex)   [default]"
            Write-Output "  2) project  - only this folder: $cwd"
            $answer = Read-Host "Choose 1 or 2"
            if ($answer -eq "2" -or $answer -eq "project") { $Scope = "project" } else { $Scope = "personal" }
            $reason = "chosen"
        } else {
            $Scope = "personal"
            $reason = "default"
        }
    }
    if ($Scope -ne "personal" -and $Scope -ne "project") {
        Fail "Scope must be personal or project, not '$Scope'.`nNothing was installed. Rerunning is safe." 2
    }
    $Base = if ($Scope -eq "personal") { $UserHome } else { $cwd }
    if ($reason -eq "default") {
        Write-Output "Scope: personal ($Base). No saved choice and no terminal, so the default is personal. Run again with --scope personal or --scope project to change it."
    } elseif ($reason -eq "remembered-personal") {
        Write-Output "Scope: personal ($Base). Remembered for your user account. Run again with --scope personal or --scope project to change it."
    } elseif ($reason -eq "remembered-project") {
        Write-Output "Scope: project ($Base). Remembered for this folder only. Run again with --scope personal or --scope project to change it."
    } else {
        Write-Output "Scope: $Scope ($Base). Run again with --scope personal or --scope project to change it."
    }

    if ($RefOverride) {
        $HubRef = $RefOverride
        Write-Output "Hub: $HubName @ $HubRef (--ref override; pin file says $HubSha)"
    } else {
        $HubRef = $HubSha
        Write-Output "Hub: $HubName @ $HubRef"
        if ($ScriptDir -and (Get-Command git -ErrorAction SilentlyContinue)) {
            $head = & git -C $ScriptDir rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $head -and $head.Trim() -ne $HubSha) {
                [Console]::Error.WriteLine("Note: hub pin is $HubSha. This checkout is $($head.Trim()). The installer uses the pin. Pass --ref to install a different hub commit.")
            }
        }
    }

    foreach ($agent in $agents) {
        $md = Join-Path $Tmp ($agent.Name + ".md")
        $toml = Join-Path $Tmp ($agent.Name + ".toml")
        Save-Download "$RawRoot/$Owner/$($agent.Name)/$($agent.Sha)/.claude/agents/$($agent.Name).md" $md "$($agent.Name) .claude/agents/$($agent.Name).md"
        Save-Download "$RawRoot/$Owner/$($agent.Name)/$($agent.Sha)/.codex/agents/$($agent.Name).toml" $toml "$($agent.Name) .codex/agents/$($agent.Name).toml"
    }
    $workflow = Join-Path $Tmp "workflow.json"
    $hubRaw = "$RawRoot/$Owner/$HubName/$HubRef"
    Save-Download "$hubRaw/.engineering-workflow.json" $workflow ".engineering-workflow.json"

    $skillUrl = "https://github.com/$Owner/$HubName/tree/$HubRef"
    Write-Output "Skill: engineering-judgment @ $HubRef"
    # npx skills add installs or updates the pinned skill.
    $skillArgs = @("-y", "skills", "add", $skillUrl, "--skill", "engineering-judgment", "-a", "claude-code", "codex")
    if ($Scope -eq "personal") { $skillArgs += "-g" }
    $skillArgs += "-y"
    & npx @skillArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "Skill install failed (npx exit code $LASTEXITCODE).`nSource: $skillUrl`nNo agent files were written. Rerunning is safe."
    }

    foreach ($agent in $agents) {
        Write-Output "Agent: $($agent.Name) @ $($agent.Sha)"
        Install-AgentFile (Join-Path $Tmp ($agent.Name + ".md")) (Join-Path (Join-Path (Join-Path $Base ".claude") "agents") ($agent.Name + ".md"))
        Install-AgentFile (Join-Path $Tmp ($agent.Name + ".toml")) (Join-Path (Join-Path (Join-Path $Base ".codex") "agents") ($agent.Name + ".toml"))
    }

    $workflowDest = Join-Path $Base ".engineering-workflow.json"
    if ($Scope -eq "project") {
        if (Test-Path -LiteralPath $workflowDest) { Write-Output "Config: .engineering-workflow.json kept as is" }
        else {
            Copy-Item -LiteralPath $workflow -Destination $workflowDest
            Write-Output "Config: .engineering-workflow.json added"
        }
    }

    $claudeDir = Join-Path $Base ".claude"
    $codexDir = Join-Path $Base ".codex"
    New-Item -ItemType Directory -Force -Path $claudeDir, $codexDir | Out-Null
    $settingsPath = Join-Path $claudeDir "settings.json"
    $settings = $null
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    }
    if (-not $settings) { $settings = New-Object PSObject }
    if (-not $settings.PSObject.Properties["env"]) { $settings | Add-Member -NotePropertyName env -NotePropertyValue (New-Object PSObject) }
    if ($settings.env.PSObject.Properties["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"]) {
        Write-Output "Claude Code: auto-compact already set ($($settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)) in $settingsPath"
    } else {
        $settings.env | Add-Member -NotePropertyName CLAUDE_AUTOCOMPACT_PCT_OVERRIDE -NotePropertyValue "40"
        [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 50) + "`n", $utf8)
        Write-Output "Claude Code: auto-compact at 40% set in $settingsPath"
    }
    $tomlPath = Join-Path $codexDir "config.toml"
    $toml = if (Test-Path -LiteralPath $tomlPath) { [IO.File]::ReadAllText($tomlPath) } else { "" }
    if ($toml -match "(?m)^\s*model_auto_compact_token_limit\s*=") {
        Write-Output "Codex: model_auto_compact_token_limit already set in $tomlPath"
    } else {
        $line = "model_auto_compact_token_limit = 160000  # 40% of a 400,000-token context window`n"
        $m = [regex]::Match($toml, "(?m)^[ \t]*\[")
        $pre = $(if ($m.Success) { $toml.Substring(0, $m.Index) } else { $toml }).TrimEnd()
        $toml = $(if ($pre) { "$pre`n" } else { "" }) + $line + $(if ($m.Success) { "`n" + $toml.Substring($m.Index) } else { "" })
        [IO.File]::WriteAllText($tomlPath, $toml, $utf8)
        Write-Output "Codex: auto-compact at 160000 tokens set in $tomlPath"
    }

    if ($Scope -eq "project") {
        $scopeDir = Join-Path $Base ".engineering-judgment"
        New-Item -ItemType Directory -Force -Path $scopeDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $scopeDir "install-scope"), "project`n", $utf8)
        $globalFile = Join-Path (Join-Path $UserHome ".engineering-judgment") "install-scope"
        if (Test-Path -LiteralPath $globalFile) {
            $g = ([IO.File]::ReadAllText($globalFile)).Trim()
            if ($g -eq "project") { Remove-Item -LiteralPath $globalFile -Force }
        }
    } else {
        $scopeDir = Join-Path $UserHome ".engineering-judgment"
        New-Item -ItemType Directory -Force -Path $scopeDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $scopeDir "install-scope"), "personal`n", $utf8)
        if ($ExplicitScope) {
            $cwdMarker = Join-Path (Join-Path $cwd ".engineering-judgment") "install-scope"
            if (Test-Path -LiteralPath $cwdMarker) { Remove-Item -LiteralPath $cwdMarker -Force }
        }
    }

    if ($Scope -eq "personal") {
        Write-Output "Config: in each project root, add .engineering-workflow.json:"
        Write-Output "  irm $hubRaw/.engineering-workflow.json -OutFile .engineering-workflow.json"
    }
    Write-Output "Done. Start a new Claude Code or Codex session to use the updated skill and agents."
} finally {
    if ($Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
}
$global:LASTEXITCODE = 0
