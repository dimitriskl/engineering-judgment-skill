# Installs or updates the engineering-judgment skill and all of the author's agents (Windows PowerShell 5.1 or 7+).
#   irm https://raw.githubusercontent.com/dimitriskl/engineering-judgment-skill/main/install/install.ps1 | iex
# The first run asks where to install; later runs reuse that answer and update everything in place.
# Change the answer with:  $env:EJ_SCOPE = "personal"   (or "project"), then run the command again.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Owner = "dimitriskl"
$Raw = if ($env:EJ_RAW) { $env:EJ_RAW } else { "https://raw.githubusercontent.com/$Owner/engineering-judgment-skill/main" }
$UserHome = $env:USERPROFILE
$StateDir = Join-Path $UserHome ".engineering-judgment"
$StateFile = Join-Path $StateDir "install-scope"
$Scope = $env:EJ_SCOPE

function Get-Bytes([string]$Url) {
    if (Test-Path -LiteralPath $Url) { return [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Url)) }
    return (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content
}
function Get-Text([string]$Url) {
    $c = Get-Bytes $Url
    if ($c -is [string]) { return $c }
    return [Text.Encoding]::UTF8.GetString($c)
}
function Save-Url([string]$Url, [string]$Path) {
    $c = Get-Bytes $Url
    if ($c -is [string]) { $c = [Text.Encoding]::UTF8.GetBytes($c) }
    [IO.File]::WriteAllBytes($Path, $c)
}
function Set-AgentFile([string]$New, [string]$Target) {
    # Install, update (keeping a .bak of the old file) or leave as is.
    if (-not (Test-Path -LiteralPath $Target)) { Copy-Item $New $Target; "    installed  $Target"; return }
    if ((Get-FileHash $New).Hash -eq (Get-FileHash $Target).Hash) { "    up to date $Target"; return }
    Copy-Item $Target "$Target.bak" -Force; Copy-Item $New $Target -Force
    "    updated    $Target (old file: $Target.bak)"
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "Node.js 22.20 or later is required (npx not found): https://nodejs.org"
}

# --- Scope: ask once, then remember -------------------------------------------------
if (-not $Scope -and (Test-Path $StateFile)) { $Scope = (Get-Content $StateFile -Raw).Trim() }
if (-not $Scope) {
    "Where should the skill and agents be installed?"
    "  1) personal - all your projects ($UserHome\.claude, $UserHome\.codex)   [default]"
    "  2) project  - only this folder: $(Get-Location)"
    $answer = Read-Host "Choose 1 or 2"
    $Scope = if ($answer -in @("2", "project")) { "project" } else { "personal" }
}
if ($Scope -notin @("personal", "project")) { throw "EJ_SCOPE must be personal or project, not '$Scope'." }
New-Item -ItemType Directory -Force $StateDir | Out-Null
Set-Content -Path $StateFile -Value $Scope -NoNewline

$Base = if ($Scope -eq "personal") { $UserHome } else { (Get-Location).Path }
"Scope: $Scope ($Base). To change it: `$env:EJ_SCOPE = 'personal' or 'project', then run again."

# --- 1. Skill (npx skills add installs or updates) -----------------------------------
"Skill: engineering-judgment"
$skillArgs = @("-y", "skills", "add", "$Owner/engineering-judgment-skill", "--skill", "engineering-judgment", "-a", "claude-code", "codex")
if ($Scope -eq "personal") { $skillArgs += "-g" }
$skillArgs += "-y"
& npx @skillArgs
if ($LASTEXITCODE -ne 0) { throw "Skill install failed (npx exit code $LASTEXITCODE)." }

# --- 2. Agents: install, or update when the published file changed ------------------
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("ej-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $Tmp, "$Base\.claude\agents", "$Base\.codex\agents" | Out-Null
try {
    $agents = (Get-Text "$Raw/install/agents.txt") -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") }
    foreach ($agent in $agents) {
        "Agent: $agent"
        $repo = "https://raw.githubusercontent.com/$Owner/$agent/main"
        Save-Url "$repo/.claude/agents/$agent.md" "$Tmp\$agent.md"
        Save-Url "$repo/.codex/agents/$agent.toml" "$Tmp\$agent.toml"
        Set-AgentFile "$Tmp\$agent.md" "$Base\.claude\agents\$agent.md"
        Set-AgentFile "$Tmp\$agent.toml" "$Base\.codex\agents\$agent.toml"
    }
} finally { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }

# --- 3. Auto-compact at 40% (only added when not set; your own values are kept) -----
$utf8 = New-Object Text.UTF8Encoding($false)
$settingsPath = "$Base\.claude\settings.json"
$settings = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json } else { $null }
if (-not $settings) { $settings = New-Object PSObject }
if (-not $settings.PSObject.Properties["env"]) { $settings | Add-Member -NotePropertyName env -NotePropertyValue (New-Object PSObject) }
if ($settings.env.PSObject.Properties["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"]) {
    "Claude Code: auto-compact already set ($($settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)) in $settingsPath"
} else {
    $settings.env | Add-Member -NotePropertyName CLAUDE_AUTOCOMPACT_PCT_OVERRIDE -NotePropertyValue "40"
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 50) + "`n", $utf8)
    "Claude Code: auto-compact at 40% set in $settingsPath"
}
$tomlPath = "$Base\.codex\config.toml"
$toml = if (Test-Path $tomlPath) { [IO.File]::ReadAllText($tomlPath) } else { "" }
if ($toml -match "(?m)^\s*model_auto_compact_token_limit\s*=") {
    "Codex: model_auto_compact_token_limit already set in $tomlPath"
} else {
    # Top-level keys must come before the first [table], or TOML puts them inside that table.
    $line = "model_auto_compact_token_limit = 160000  # 40% of a 400,000-token context window`n"
    $m = [regex]::Match($toml, "(?m)^[ \t]*\[")
    $pre = $(if ($m.Success) { $toml.Substring(0, $m.Index) } else { $toml }).TrimEnd()
    $toml = $(if ($pre) { "$pre`n" } else { "" }) + $line + $(if ($m.Success) { "`n" + $toml.Substring($m.Index) } else { "" })
    [IO.File]::WriteAllText($tomlPath, $toml, $utf8)
    "Codex: auto-compact at 160000 tokens set in $tomlPath"
}

# --- 4. Agent mapping for the skill -------------------------------------------------
if ($Scope -eq "project") {
    if (Test-Path ".engineering-workflow.json") { "Config: .engineering-workflow.json kept as is" }
    else { Save-Url "$Raw/.engineering-workflow.json" "$Base\.engineering-workflow.json"; "Config: .engineering-workflow.json added" }
} else {
    "Config: in each project root, add .engineering-workflow.json:"
    "  irm $Raw/.engineering-workflow.json -OutFile .engineering-workflow.json"
}

"Done. Start a new Claude Code or Codex session to use the updated skill and agents."
