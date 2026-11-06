# Update using the same scope and behavior as the installer (PowerShell 5.1 or 7+).
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$Raw = if ($env:EJ_RAW) { $env:EJ_RAW } else { "https://raw.githubusercontent.com/dimitriskl/engineering-judgment-skill/main" }
$installer = if (Test-Path -LiteralPath "$Raw/install/install.ps1") {
    [IO.File]::ReadAllText((Resolve-Path -LiteralPath "$Raw/install/install.ps1"))
} else {
    (Invoke-WebRequest -UseBasicParsing -Uri "$Raw/install/install.ps1").Content
}
& ([scriptblock]::Create($installer))
