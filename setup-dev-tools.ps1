# setup-dev-tools.ps1
# Installs Git, Node.js (via fnm), OpenAI Codex CLI, Claude Code, uv,
# psmux, Alacritty, Neovim, and GNU_files config with no admin requirement.
#
# Usage: powershell -ExecutionPolicy Bypass -File setup-dev-tools.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Version pins - keep in sync with versions.conf
$AlacrittyVersion = "0.16.1"
$NeovimVersion = "0.11.6"
$psmuxVersion = $null

function Add-PathOnce {
    param([Parameter(Mandatory = $true)][string]$Dir)

    if (-not $Dir) { return }
    if (-not (Test-Path $Dir)) { return }

    $pathEntries = $env:Path -split ';'
    if ($pathEntries -notcontains $Dir) {
        $env:Path = "$Dir;$env:Path"
    }
}

function Add-UserPathOnce {
    param([Parameter(Mandatory = $true)][string]$Dir)

    if (-not $Dir) { return }
    if (-not (Test-Path $Dir)) { return }

    Add-PathOnce $Dir

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = @()

    if ($userPath) {
        $pathEntries = $userPath -split ';' | Where-Object { $_ }
    }

    if ($pathEntries -notcontains $Dir) {
        $newUserPath = if ($userPath) { "$userPath;$Dir" } else { $Dir }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }
}

function Remove-UserPathMatches {
    param([Parameter(Mandatory = $true)][string[]]$Patterns)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { return }

    $pathEntries = $userPath -split ';' | Where-Object { $_ }
    $filteredEntries = @()

    foreach ($entry in $pathEntries) {
        $keepEntry = $true
        foreach ($pattern in $Patterns) {
            if ($entry -match $pattern) {
                $keepEntry = $false
                break
            }
        }

        if ($keepEntry) {
            $filteredEntries += $entry
        }
    }

    $newUserPath = $filteredEntries -join ';'
    if ($newUserPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }
}

function Ensure-ProfileLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    $profileDir = Split-Path -Parent $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $content = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch [regex]::Escape($Line)) {
        Add-Content -Path $PROFILE -Value "`r`n$Line`r`n"
    }
}

function Test-FontInstalled {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    $fontRegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($fontRegistryPath in $fontRegistryPaths) {
        if (-not (Test-Path $fontRegistryPath)) { continue }

        $fontProperties = (Get-ItemProperty -Path $fontRegistryPath).PSObject.Properties
        foreach ($name in $Names) {
            if ($fontProperties.Name -match [regex]::Escape($name)) {
                return $true
            }
        }
    }

    return $false
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $wingetOutput = (& winget list --id $Id -e --accept-source-agreements | Out-String)
    return ($wingetOutput -match [regex]::Escape($Id))
}

function Find-WingetInstalledBinary {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePrefix,
        [Parameter(Mandatory = $true)][string[]]$BinaryNames
    )

    $packagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (-not (Test-Path $packagesRoot)) {
        return $null
    }

    $packageDir = Get-ChildItem -Path $packagesRoot -Directory -Filter "$PackagePrefix*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $packageDir) {
        return $null
    }

    foreach ($binaryName in $BinaryNames) {
        $candidatePath = Join-Path $packageDir.FullName "$binaryName.exe"
        if (Test-Path $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$UserScope
    )

    $wingetArgs = @(
        "install",
        "--id", $Id,
        "-e",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    if ($UserScope) {
        $wingetArgs += @("--scope", "user")
    }

    & winget @wingetArgs
    return ($LASTEXITCODE -eq 0)
}

function Get-FnmInstalledVersionForAlias {
    param([Parameter(Mandatory = $true)][string]$Alias)

    $fnmList = fnm list
    foreach ($line in $fnmList) {
        if (($line -match [regex]::Escape($Alias)) -and ($line -match 'v\d+\.\d+\.\d+')) {
            return $matches[0]
        }
    }

    return $null
}

function Ensure-StableNpmPrefix {
    $desiredPrefix = "$env:APPDATA\npm"

    if (-not (Test-Path $desiredPrefix)) {
        New-Item -ItemType Directory -Path $desiredPrefix -Force | Out-Null
    }

    $currentPrefix = (npm config get prefix).Trim()
    if ($currentPrefix -ne $desiredPrefix) {
        npm config set prefix $desiredPrefix | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set npm global prefix to '$desiredPrefix'."
        }
    }

    Remove-UserPathMatches @([regex]::Escape("$env:LOCALAPPDATA\fnm_multishells"))
    Add-UserPathOnce $desiredPrefix

    return $desiredPrefix
}

function Test-NpmGlobalBinary {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    $candidatePaths = @(
        (Join-Path $Prefix "$CommandName.cmd"),
        (Join-Path $Prefix "$CommandName.ps1"),
        (Join-Path $Prefix $CommandName)
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path $candidatePath) {
            return $true
        }
    }

    return $false
}

function Install-PortableAlacritty {
    $portableDir = "$env:LOCALAPPDATA\alacritty"
    $portableExe = Join-Path $portableDir "alacritty.exe"
    $downloadUrl = "https://github.com/alacritty/alacritty/releases/download/v$AlacrittyVersion/Alacritty-v$AlacrittyVersion-portable.exe"

    if (-not (Test-Path $portableDir)) {
        New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    }

    if (-not (Test-Path $portableExe)) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $portableExe
    }

    Add-UserPathOnce $portableDir
}

function Install-PortableNeovim {
    $portableDir = "$env:LOCALAPPDATA\nvim-bin"
    $portableZip = "$env:TEMP\nvim-win64.zip"
    $portableRoot = Join-Path $portableDir "nvim-win64"
    $downloadUrl = "https://github.com/neovim/neovim/releases/download/v$NeovimVersion/nvim-win64.zip"

    if (-not (Test-Path $portableDir)) {
        New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    }

    if (Test-Path $portableRoot) {
        Remove-Item $portableRoot -Recurse -Force
    }

    Invoke-WebRequest -Uri $downloadUrl -OutFile $portableZip
    Expand-Archive -Path $portableZip -DestinationPath $portableDir -Force
    Remove-Item $portableZip -Force
}

Write-Host "=== Dev Tools Setup (no admin) ===" -ForegroundColor Cyan

# --- Pre-flight: check winget ---
if (-not (Test-CommandExists "winget")) {
    throw "winget is not available. Install App Installer from the Microsoft Store."
}

# --- 1. Git ---
Write-Host "`n[1/10] Installing Git..." -ForegroundColor Yellow

if (-not (Test-CommandExists "git")) {
    $gitInstalled = Invoke-WingetInstall -Id "Git.Git" -UserScope
    if (-not $gitInstalled) {
        throw "Git install failed via winget."
    }
}

Add-UserPathOnce "$env:LOCALAPPDATA\Programs\Git\cmd"

if (-not (Test-CommandExists "git")) {
    throw "Git was installed but is not on PATH. Check '$env:LOCALAPPDATA\Programs\Git\cmd'."
}

$gitVersion = (git --version).Trim()
Write-Host "Git $gitVersion" -ForegroundColor Green

# --- 2. fnm + Node.js + npm ---
Write-Host "`n[2/10] Installing fnm + Node.js..." -ForegroundColor Yellow

if (-not (Test-CommandExists "fnm")) {
    $fnmInstalled = Invoke-WingetInstall -Id "Schniz.fnm" -UserScope
    if (-not $fnmInstalled) {
        throw "fnm install failed via winget."
    }
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

if (-not (Test-CommandExists "fnm")) {
    throw "fnm was installed but is not on PATH. Check '$env:LOCALAPPDATA\Microsoft\WinGet\Links'."
}

$fnmInit = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'
Ensure-ProfileLine $fnmInit
Invoke-Expression ((fnm env --use-on-cd --shell powershell) | Out-String)

fnm install --lts
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to install the latest LTS Node.js release."
}

$ltsNodeVersion = Get-FnmInstalledVersionForAlias "lts-latest"
if (-not $ltsNodeVersion) {
    throw "fnm installed Node.js, but the latest LTS version could not be resolved from 'fnm list'."
}

fnm use $ltsNodeVersion
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to activate Node.js $ltsNodeVersion."
}

$nodeVersion = (node --version).Trim()

fnm default $ltsNodeVersion
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to set Node.js $ltsNodeVersion as the default."
}

$npmVersion = (npm --version).Trim()
Write-Host "Node $nodeVersion | npm $npmVersion" -ForegroundColor Green

$npmPrefix = Ensure-StableNpmPrefix

# --- 3. OpenAI Codex CLI ---
Write-Host "`n[3/10] Installing OpenAI Codex CLI..." -ForegroundColor Yellow

if (-not (Test-NpmGlobalBinary -Prefix $npmPrefix -CommandName "codex")) {
    npm install -g @openai/codex
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install OpenAI Codex CLI via npm."
    }
}

Add-UserPathOnce $npmPrefix

if (-not (Test-CommandExists "codex")) {
    Write-Warning "Codex was installed, but 'codex' is not on PATH in this session yet. Restart PowerShell if needed."
}

try {
    $codexVersion = (codex --version).Trim()
} catch {
    $codexVersion = "installed"
}

Write-Host "Codex: $codexVersion" -ForegroundColor Green

# --- 4. Claude Code ---
Write-Host "`n[4/10] Installing Claude Code..." -ForegroundColor Yellow

if (-not (Test-NpmGlobalBinary -Prefix $npmPrefix -CommandName "claude")) {
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Claude Code via npm."
    }
}

if (-not (Test-CommandExists "claude")) {
    Write-Warning "Claude Code was installed, but 'claude' is not on PATH in this session yet. Restart PowerShell if needed."
}

try {
    $claudeVersion = (claude --version).Trim()
} catch {
    $claudeVersion = "installed"
}

$gitBashCandidates = @(
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\bin\bash.exe"
)
$gitBashPath = $gitBashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitBashPath) {
    $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath
    $existingClaudeGitBash = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "User")
    if ($existingClaudeGitBash -ne $gitBashPath) {
        [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashPath, "User")
    }
} else {
    Write-Warning "Git Bash was not found. Claude Code works best on Windows with WSL or Git Bash."
}

Write-Host "Claude Code: $claudeVersion" -ForegroundColor Green

# --- 5. uv (Python manager) ---
Write-Host "`n[5/10] Installing uv..." -ForegroundColor Yellow

if (-not (Test-CommandExists "uv")) {
    $uvInstaller = irm https://astral.sh/uv/install.ps1
    if (-not $uvInstaller) {
        throw "Failed to download uv installer."
    }
    Invoke-Expression $uvInstaller
}

Add-UserPathOnce "$env:USERPROFILE\.local\bin"

if (-not (Test-CommandExists "uv")) {
    throw "uv was installed but is not on PATH. Check '$env:USERPROFILE\.local\bin'."
}

$uvVersion = (uv --version).Trim()
Write-Host "uv $uvVersion" -ForegroundColor Green

# --- 6. Clone GNU_files repo ---
Write-Host "`n[6/10] Preparing GNU_files repo..." -ForegroundColor Yellow

$gnuFilesPath = "$env:USERPROFILE\GNU_files"
$scriptRepoPath = $PSScriptRoot

if ((Test-Path "$scriptRepoPath\.git") -and (Test-Path "$scriptRepoPath\nvim")) {
    $gnuFilesPath = $scriptRepoPath
    Write-Host "Using GNU_files from script directory: $gnuFilesPath" -ForegroundColor Green
} elseif (-not (Test-Path $gnuFilesPath)) {
    git clone https://github.com/jlipworth/devenv.git $gnuFilesPath
    Write-Host "GNU_files cloned to $gnuFilesPath" -ForegroundColor Green
} elseif (Test-Path "$gnuFilesPath\.git") {
    git -C $gnuFilesPath pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git pull failed (local changes?). Continuing with existing checkout."
    } else {
        Write-Host "GNU_files updated at $gnuFilesPath" -ForegroundColor Green
    }
} else {
    throw "Path exists but is not a git repo: $gnuFilesPath"
}

# --- 7. psmux + config + plugins ---
Write-Host "`n[7/10] Installing psmux + config..." -ForegroundColor Yellow

$psmuxWingetId = "marlocarlo.psmux"

if (-not (Test-CommandExists "pwsh")) {
    $pwshInstalled = Invoke-WingetInstall -Id "Microsoft.PowerShell" -UserScope
    if (-not $pwshInstalled) {
        throw "PowerShell 7 (pwsh) install failed via winget."
    }
}

if ((-not (Test-CommandExists "psmux")) -and (-not (Test-CommandExists "tmux"))) {
    & winget install --id $psmuxWingetId -e --scope user --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        if (-not (Test-WingetPackageInstalled $psmuxWingetId)) {
            throw "psmux install failed via winget."
        }

        Write-Host "psmux is already installed via winget; continuing." -ForegroundColor Yellow
    }
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
Add-UserPathOnce "$env:USERPROFILE\.cargo\bin"

$psmuxInstalledBinary = Find-WingetInstalledBinary -PackagePrefix $psmuxWingetId -BinaryNames @("psmux", "tmux")
if ($psmuxInstalledBinary) {
    Add-UserPathOnce (Split-Path -Parent $psmuxInstalledBinary)
}

$pwshBinary = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshBinary) {
    throw "PowerShell 7 (pwsh) is required for the psmux config/bootstrap, but it is not on PATH."
}

$psmuxBinary = Get-Command psmux -ErrorAction SilentlyContinue
if (-not $psmuxBinary) {
    $psmuxBinary = Get-Command tmux -ErrorAction SilentlyContinue
}
if ((-not $psmuxBinary) -and $psmuxInstalledBinary) {
    $psmuxBinary = Get-Command $psmuxInstalledBinary -ErrorAction SilentlyContinue
}

if (-not $psmuxBinary) {
    Write-Warning "psmux was installed, but neither 'psmux' nor its tmux alias is on PATH in this session yet. Restart PowerShell if needed."
} else {
    try {
        $psmuxVersion = (& $psmuxBinary.Source --version | Select-Object -First 1).Trim()
    } catch {
        $psmuxVersion = "installed"
    }
    Write-Host "psmux: $psmuxVersion" -ForegroundColor Green
}

$psmuxSourcePath = "$gnuFilesPath\.psmux.conf"
$psmuxTargetPath = "$env:USERPROFILE\.psmux.conf"
$psmuxPluginRoot = "$env:USERPROFILE\.psmux\plugins"
$ppmTargetPath = Join-Path $psmuxPluginRoot 'ppm'

if (Test-Path $psmuxSourcePath) {
    if (Test-Path $psmuxTargetPath) {
        $existingPsmuxConfig = Get-Content -Path $psmuxTargetPath -Raw -ErrorAction SilentlyContinue
        if ($existingPsmuxConfig -and -not $existingPsmuxConfig.StartsWith("# Managed by setup-dev-tools.ps1")) {
            $backupPath = "${psmuxTargetPath}.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item -Path $psmuxTargetPath -Destination $backupPath -Force
            Write-Host "Existing psmux config backed up to $backupPath" -ForegroundColor Yellow
        }
    }

    $managedHeader = "# Managed by setup-dev-tools.ps1 from GNU_files/.psmux.conf`r`n"
    $psmuxConfig = $managedHeader + (Get-Content -Path $psmuxSourcePath -Raw)
    Set-Content -Path $psmuxTargetPath -Value $psmuxConfig -NoNewline
    Write-Host "psmux config written: $psmuxTargetPath" -ForegroundColor Green
} else {
    Write-Warning "psmux config source path not found: $psmuxSourcePath"
}

if (-not (Test-Path $psmuxPluginRoot)) {
    New-Item -ItemType Directory -Path $psmuxPluginRoot -Force | Out-Null
}

$ppmBootstrapRepo = Join-Path $env:TEMP "psmux-plugins-bootstrap"
if (Test-Path $ppmBootstrapRepo) {
    Remove-Item -Path $ppmBootstrapRepo -Recurse -Force
}

git clone https://github.com/psmux/psmux-plugins.git $ppmBootstrapRepo
if ($LASTEXITCODE -ne 0) {
    throw "Failed to clone psmux plugin bootstrap repository."
}

if (Test-Path $ppmTargetPath) {
    Remove-Item -Path $ppmTargetPath -Recurse -Force
}
Copy-Item -Path (Join-Path $ppmBootstrapRepo 'ppm') -Destination $ppmTargetPath -Recurse -Force
Write-Host "PPM bootstrapped to $ppmTargetPath" -ForegroundColor Green

$ppmInstallScript = Join-Path $ppmTargetPath 'scripts\install_plugins.ps1'
if (Test-Path $ppmInstallScript) {
    & $pwshBinary.Source -NoProfile -File $ppmInstallScript
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "PPM plugin install reported exit code $LASTEXITCODE. You can retry inside psmux with Prefix + I."
    } else {
        Write-Host "psmux plugins installed from .psmux.conf" -ForegroundColor Green
    }
} else {
    Write-Warning "PPM install script not found at $ppmInstallScript"
}

if (Test-Path $ppmBootstrapRepo) {
    Remove-Item -Path $ppmBootstrapRepo -Recurse -Force
}

# --- 8. Alacritty ---
Write-Host "`n[8/10] Installing Alacritty..." -ForegroundColor Yellow

Add-UserPathOnce "$env:LOCALAPPDATA\alacritty"

if (-not (Test-CommandExists "alacritty")) {
    $alacrittyInstalled = Invoke-WingetInstall -Id "Alacritty.Alacritty" -UserScope
    $alacrittyWingetExitCode = $LASTEXITCODE
    Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

    if (-not (Test-CommandExists "alacritty")) {
        if ($alacrittyInstalled) {
            Write-Host "winget did not leave an 'alacritty' command available, falling back to portable Alacritty..." -ForegroundColor Yellow
        } else {
            Write-Host "winget install failed (exit code $alacrittyWingetExitCode), falling back to portable Alacritty..." -ForegroundColor Yellow
        }
        Install-PortableAlacritty
    }
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
Add-UserPathOnce "$env:LOCALAPPDATA\alacritty"

if (-not (Test-CommandExists "alacritty")) {
    throw "Alacritty install failed. Neither winget nor the portable fallback produced an 'alacritty' command."
}

$alacrittyWindowsSourcePath = "$gnuFilesPath\alacritty.windows.toml"
$alacrittyDefaultSourcePath = "$gnuFilesPath\alacritty.toml"
$alacrittySourcePath = if (Test-Path $alacrittyWindowsSourcePath) {
    $alacrittyWindowsSourcePath
} else {
    $alacrittyDefaultSourcePath
}
$alacrittyConfigDir = "$env:APPDATA\alacritty"
$alacrittyConfigPath = "$alacrittyConfigDir\alacritty.toml"

if (Test-Path $alacrittySourcePath) {
    if (-not (Test-Path $alacrittyConfigDir)) {
        New-Item -ItemType Directory -Path $alacrittyConfigDir -Force | Out-Null
    }

    $alacrittyConfig = Get-Content -Path $alacrittySourcePath -Raw
    if ($alacrittySourcePath -eq $alacrittyDefaultSourcePath) {
        $alacrittyConfig = $alacrittyConfig -replace 'program = "wsl\.exe"', 'program = "powershell.exe"'
        $alacrittyConfig = $alacrittyConfig -replace 'args = \["-d", "Ubuntu-20\.04", "--cd", "~"\]', 'args = ["-NoLogo"]'
    }

    $mesloFontInstalled = Test-FontInstalled @("MesloLGM Nerd Font Mono")
    $jetBrainsMonoNerdInstalled = Test-FontInstalled @("JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font")

    if ((-not $mesloFontInstalled) -and (-not $jetBrainsMonoNerdInstalled)) {
        Write-Host "MesloLGM Nerd Font Mono not found. Installing JetBrainsMono Nerd Font..." -ForegroundColor Yellow
        $fontInstalled = Invoke-WingetInstall -Id "DEVCOM.JetBrainsMonoNerdFont" -UserScope

        if ($fontInstalled) {
            $jetBrainsMonoNerdInstalled = Test-FontInstalled @("JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font")
        } else {
            Write-Warning "JetBrainsMono Nerd Font install failed via winget."
        }
    }

    if (-not $mesloFontInstalled) {
        if ($jetBrainsMonoNerdInstalled) {
            $alacrittyConfig = $alacrittyConfig -replace 'family = "MesloLGM Nerd Font Mono"', 'family = "JetBrainsMono Nerd Font Mono"'
            Write-Host "Using JetBrainsMono Nerd Font Mono in Alacritty config." -ForegroundColor Green
        } else {
            $alacrittyConfig = $alacrittyConfig -replace 'family = "MesloLGM Nerd Font Mono"', 'family = "Cascadia Mono"'
            Write-Warning "No preferred Nerd Font was found. Using Cascadia Mono in Alacritty config."
        }
    }

    $alacrittySourceName = Split-Path -Leaf $alacrittySourcePath
    $managedHeader = "# Managed by setup-dev-tools.ps1 from GNU_files/$alacrittySourceName`r`n"
    $alacrittyConfig = $managedHeader + $alacrittyConfig

    if (Test-Path $alacrittyConfigPath) {
        $existingAlacrittyConfig = Get-Content -Path $alacrittyConfigPath -Raw -ErrorAction SilentlyContinue
        if ($existingAlacrittyConfig -and -not $existingAlacrittyConfig.StartsWith("# Managed by setup-dev-tools.ps1")) {
            $backupPath = "${alacrittyConfigPath}.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item -Path $alacrittyConfigPath -Destination $backupPath -Force
            Write-Host "Existing Alacritty config backed up to $backupPath" -ForegroundColor Yellow
        }
    }

    Set-Content -Path $alacrittyConfigPath -Value $alacrittyConfig -NoNewline
    Write-Host "Alacritty config written: $alacrittyConfigPath" -ForegroundColor Green
} else {
    Write-Warning "Alacritty config source path not found: $alacrittySourcePath"
}

try {
    $alacrittyVersion = (alacritty --version).Trim()
} catch {
    $alacrittyVersion = "installed"
}

Write-Host "Alacritty: $alacrittyVersion" -ForegroundColor Green

# --- 9. Neovim ---
Write-Host "`n[9/10] Installing Neovim..." -ForegroundColor Yellow

$portableNvimBinPath = "$env:LOCALAPPDATA\nvim-bin\nvim-win64\bin"
Add-UserPathOnce $portableNvimBinPath

if (-not (Test-CommandExists "nvim")) {
    $wingetSuccess = Invoke-WingetInstall -Id "Neovim.Neovim" -UserScope
    $nvimWingetExitCode = $LASTEXITCODE

    Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

    if (-not (Test-CommandExists "nvim")) {
        if ($wingetSuccess) {
            Write-Host "winget did not leave an 'nvim' command available, falling back to portable zip..." -ForegroundColor Yellow
        } else {
            Write-Host "winget install failed (exit code $nvimWingetExitCode), falling back to portable zip..." -ForegroundColor Yellow
        }
        Install-PortableNeovim
        Add-UserPathOnce $portableNvimBinPath
    }
}

if (-not (Test-CommandExists "nvim")) {
    throw "Neovim install failed. Neither winget nor the portable zip fallback produced an 'nvim' command."
}

$nvimVersion = (nvim --version | Select-Object -First 1).Trim()
Write-Host "Neovim: $nvimVersion" -ForegroundColor Green

# --- 10. Neovim config junction ---
Write-Host "`n[10/10] Linking Neovim config..." -ForegroundColor Yellow

$nvimConfigPath = "$env:LOCALAPPDATA\nvim"
$nvimSourcePath = "$gnuFilesPath\nvim"
$skipNvimRelink = $false

if (-not (Test-Path $nvimSourcePath)) {
    throw "Neovim config source path not found: $nvimSourcePath"
}

if (Test-Path $nvimConfigPath) {
    $existingConfigItem = Get-Item $nvimConfigPath
    if ($existingConfigItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if ($existingConfigItem.Target -eq $nvimSourcePath) {
            Write-Host "Neovim config already linked: $nvimConfigPath -> $nvimSourcePath" -ForegroundColor Green
            $skipNvimRelink = $true
        } else {
            Remove-Item $nvimConfigPath -Force
        }
    } else {
        $backupPath = "${nvimConfigPath}_backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item $nvimConfigPath $backupPath
        Write-Host "Existing nvim config backed up to $backupPath" -ForegroundColor Yellow
    }
}

if (-not $skipNvimRelink) {
    try {
        New-Item -ItemType Junction -Path $nvimConfigPath -Target $nvimSourcePath -ErrorAction Stop | Out-Null
        Write-Host "Neovim config linked: $nvimConfigPath -> $nvimSourcePath" -ForegroundColor Green
    } catch {
        # Junctions can fail on network-backed home directories.
        Write-Host "Junction failed, copying config instead..." -ForegroundColor Yellow
        Copy-Item -Path $nvimSourcePath -Destination $nvimConfigPath -Recurse
        Write-Host "Neovim config copied to $nvimConfigPath (manual sync needed after repo updates)" -ForegroundColor Yellow
    }
}

# --- Done ---
Write-Host "`n=== All tools installed ===" -ForegroundColor Cyan
Write-Host "  git   : $gitVersion"
Write-Host "  node  : $nodeVersion"
Write-Host "  npm   : $npmVersion"
Write-Host "  codex : $codexVersion"
Write-Host "  claude: $claudeVersion"
Write-Host "  uv    : $uvVersion"
if ($psmuxVersion) { Write-Host "  psmux : $psmuxVersion" }
Write-Host "  alacritty: $alacrittyVersion"
Write-Host "  nvim  : $nvimVersion"
Write-Host "  GNU_files: $gnuFilesPath"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell so PATH/profile changes are fully picked up."
Write-Host "  2. Run 'codex' and 'claude' once to complete sign-in/setup."
Write-Host "  3. Run 'psmux' (or 'tmux') once, then verify Alacritty and Neovim load correctly."
