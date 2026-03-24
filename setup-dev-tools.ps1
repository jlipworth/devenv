# setup-dev-tools.ps1
# Installs Git, Node.js (via fnm), OpenAI Codex CLI, Claude Code, uv, Alacritty, Neovim, and GNU_files config — no admin required.
# Safe to re-run on machines that reset regularly.
#
# Usage: powershell -ExecutionPolicy Bypass -File setup-dev-tools.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Version pins — keep in sync with versions.conf
$NeovimVersion = "0.11.6"

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

Write-Host "=== Dev Tools Setup (no admin) ===" -ForegroundColor Cyan

# --- Pre-flight: check winget ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available. Install App Installer from the Microsoft Store."
}

# --- 1. Git ---
Write-Host "`n[1/9] Installing Git..." -ForegroundColor Yellow

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git -e --scope user --accept-source-agreements --accept-package-agreements
}

Add-UserPathOnce "$env:LOCALAPPDATA\Programs\Git\cmd"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was installed but is not on PATH. Check '$env:LOCALAPPDATA\Programs\Git\cmd'."
}

$gitVersion = (git --version).Trim()
Write-Host "Git $gitVersion" -ForegroundColor Green

# --- 2. fnm + Node.js + npm ---
Write-Host "`n[2/9] Installing fnm + Node.js..." -ForegroundColor Yellow

if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    winget install --id Schniz.fnm -e --scope user --accept-source-agreements --accept-package-agreements
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    throw "fnm was installed but is not on PATH. Check '$env:LOCALAPPDATA\Microsoft\WinGet\Links'."
}

$fnmInit = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'
Ensure-ProfileLine $fnmInit
Invoke-Expression ((fnm env --use-on-cd --shell powershell) | Out-String)

fnm install --lts
fnm use lts
$nodeVersion = (node --version).Trim()
fnm default $nodeVersion

$npmVersion = (npm --version).Trim()
Write-Host "Node $nodeVersion | npm $npmVersion" -ForegroundColor Green

# --- 3. OpenAI Codex CLI ---
Write-Host "`n[3/9] Installing OpenAI Codex CLI..." -ForegroundColor Yellow

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    npm install -g @openai/codex
}

$npmPrefix = (npm config get prefix).Trim()
Add-UserPathOnce $npmPrefix

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Warning "Codex was installed, but 'codex' is not on PATH in this session yet. Restart PowerShell if needed."
}

try {
    $codexVersion = (codex --version).Trim()
} catch {
    $codexVersion = "installed"
}

Write-Host "Codex: $codexVersion" -ForegroundColor Green

# --- 4. Claude Code ---
Write-Host "`n[4/9] Installing Claude Code..." -ForegroundColor Yellow

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    npm install -g @anthropic-ai/claude-code
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
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
Write-Host "`n[5/9] Installing uv..." -ForegroundColor Yellow

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    $uvInstaller = irm https://astral.sh/uv/install.ps1
    if (-not $uvInstaller) {
        throw "Failed to download uv installer."
    }
    Invoke-Expression $uvInstaller
}

Add-UserPathOnce "$env:USERPROFILE\.local\bin"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv was installed but is not on PATH. Check '$env:USERPROFILE\.local\bin'."
}

$uvVersion = (uv --version).Trim()
Write-Host "uv $uvVersion" -ForegroundColor Green

# --- 6. Clone GNU_files repo ---
Write-Host "`n[6/9] Preparing GNU_files repo..." -ForegroundColor Yellow

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

# --- 7. Alacritty ---
Write-Host "`n[7/9] Installing Alacritty..." -ForegroundColor Yellow

if (-not (Get-Command alacritty -ErrorAction SilentlyContinue)) {
    winget install --id Alacritty.Alacritty -e --scope user --accept-source-agreements --accept-package-agreements
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

if (-not (Get-Command alacritty -ErrorAction SilentlyContinue)) {
    Write-Warning "Alacritty was installed, but 'alacritty' is not on PATH in this session yet. Restart PowerShell if needed."
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
        winget install --id DEVCOM.JetBrainsMonoNerdFont -e --scope user --accept-source-agreements --accept-package-agreements

        if ($LASTEXITCODE -eq 0) {
            $jetBrainsMonoNerdInstalled = Test-FontInstalled @("JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font")
        } else {
            Write-Warning "JetBrainsMono Nerd Font install failed (exit code $LASTEXITCODE)."
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

# --- 8. Neovim ---
Write-Host "`n[8/9] Installing Neovim..." -ForegroundColor Yellow

$portableNvimBinPath = "$env:LOCALAPPDATA\nvim-bin\nvim-win64\bin"
Add-UserPathOnce $portableNvimBinPath

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    # Try winget first (try/catch does NOT catch native exe failures in PS 5.1,
    # so we must check $LASTEXITCODE)
    $wingetSuccess = $false
    winget install --id Neovim.Neovim -e --scope user --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        $wingetSuccess = $true
    } else {
        Write-Host "winget install failed (exit code $LASTEXITCODE), falling back to portable zip..." -ForegroundColor Yellow
    }

    Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

    if (-not $wingetSuccess) {
        # Fallback: download portable zip
        $nvimDir = "$env:LOCALAPPDATA\nvim-bin"
        $nvimZip = "$env:TEMP\nvim-win64.zip"
        $nvimExtractedDir = "$nvimDir\nvim-win64"
        if (Test-Path $nvimExtractedDir) {
            Remove-Item $nvimExtractedDir -Recurse -Force
        }
        Invoke-WebRequest -Uri "https://github.com/neovim/neovim/releases/download/v$NeovimVersion/nvim-win64.zip" -OutFile $nvimZip
        Expand-Archive -Path $nvimZip -DestinationPath $nvimDir -Force
        Remove-Item $nvimZip -Force
        Add-UserPathOnce $portableNvimBinPath
    }
}

$nvimVersion = (nvim --version | Select-Object -First 1).Trim()
Write-Host "Neovim: $nvimVersion" -ForegroundColor Green

# --- 9. Neovim config junction ---
Write-Host "`n[9/9] Linking Neovim config..." -ForegroundColor Yellow

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
        # Junction fails on network shares — fall back to copy
        Write-Host "Junction failed (network share?), copying config instead..." -ForegroundColor Yellow
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
Write-Host "  alacritty: $alacrittyVersion"
Write-Host "  nvim  : $nvimVersion"
Write-Host "  GNU_files: $gnuFilesPath"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell so PATH/profile changes are fully picked up."
Write-Host "  2. Run 'codex' and 'claude' once to complete sign-in/setup."
Write-Host "  3. Run 'alacritty' and 'nvim' to verify the GNU_files config loads."
