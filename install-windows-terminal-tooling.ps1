# install-windows-terminal-tooling.ps1
# Installs/configures only Windows-side psmux + Alacritty tooling for WSL2 workflows.
# Safe to run from Windows PowerShell directly or through bin/install-windows-terminal-tooling-from-wsl.sh.
#
# Usage from Windows:
#   powershell -ExecutionPolicy Bypass -File .\install-windows-terminal-tooling.ps1
#
# Usage from WSL2:
#   ./bin/install-windows-terminal-tooling-from-wsl.sh

param(
    [string]$GnuFilesPath = $PSScriptRoot,
    [switch]$SkipFonts,
    [switch]$SkipPsmuxPlugins
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-VersionFromConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    if (Test-Path $ConfigPath) {
        $match = Select-String -Path $ConfigPath -Pattern "^$Name=`"([^`"]+)`"" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match -and $match.Matches[0].Groups[1].Value) {
            return $match.Matches[0].Groups[1].Value
        }
    }

    return $Fallback
}

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

function Get-DirectoryCommandCandidatePaths {
    param(
        [Parameter(Mandatory = $true)][string[]]$Directories,
        [Parameter(Mandatory = $true)][string[]]$BinaryNames,
        [switch]$IncludeExtensionless
    )

    $candidatePaths = @()
    foreach ($directory in ($Directories | Where-Object { $_ })) {
        foreach ($binaryName in $BinaryNames) {
            $candidatePaths += @(
                (Join-Path $directory "$binaryName.exe"),
                (Join-Path $directory "$binaryName.cmd"),
                (Join-Path $directory "$binaryName.ps1")
            )

            if ($IncludeExtensionless) {
                $candidatePaths += (Join-Path $directory $binaryName)
            }
        }
    }

    return $candidatePaths | Select-Object -Unique
}

function Refresh-SessionPath {
    $pathEntries = @()
    foreach ($pathValue in @(
        $env:Path,
        [Environment]::GetEnvironmentVariable("Path", "User"),
        [Environment]::GetEnvironmentVariable("Path", "Machine")
    )) {
        if (-not $pathValue) { continue }
        foreach ($entry in ($pathValue -split ';' | Where-Object { $_ })) {
            if ($pathEntries -notcontains $entry) {
                $pathEntries += $entry
            }
        }
    }

    if ($pathEntries.Count -gt 0) {
        $env:Path = $pathEntries -join ';'
    }
}

function Get-CommandInfoAny {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    foreach ($name in $Names) {
        $commandInfo = Get-Command $name -ErrorAction SilentlyContinue
        if ($commandInfo) {
            return $commandInfo
        }
    }

    return $null
}

function Wait-ForCommandInfo {
    param(
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string[]]$CandidatePaths = @(),
        [int]$TimeoutSeconds = 15,
        [int]$PollMilliseconds = 500
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Refresh-SessionPath

        foreach ($candidatePath in ($CandidatePaths | Where-Object { $_ })) {
            if (Test-Path $candidatePath) {
                Add-PathOnce (Split-Path -Parent $candidatePath)
            }
        }

        $commandInfo = Get-CommandInfoAny -Names $Names
        if ($commandInfo) {
            return $commandInfo
        }

        foreach ($candidatePath in ($CandidatePaths | Where-Object { $_ })) {
            if (-not (Test-Path $candidatePath)) { continue }
            $commandInfo = Get-Command $candidatePath -ErrorAction SilentlyContinue
            if ($commandInfo) {
                return $commandInfo
            }
        }

        Start-Sleep -Milliseconds $PollMilliseconds
    } while ((Get-Date) -lt $deadline)

    return $null
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
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

function Wait-ForFontInstalled {
    param(
        [Parameter(Mandatory = $true)][string[]]$Names,
        [int]$TimeoutSeconds = 15,
        [int]$PollMilliseconds = 500
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-FontInstalled $Names) {
            return $true
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ((Get-Date) -lt $deadline)

    return (Test-FontInstalled $Names)
}

function Test-JetBrainsMonoNerdFontInstalled {
    $fontNames = @("JetBrainsMono NFM", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font")
    return (Test-FontInstalled $fontNames)
}

function Get-FontRegistryDisplayName {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$FamilyName,
        [Parameter(Mandatory = $true)][string]$FileNamePrefix
    )

    $style = [IO.Path]::GetFileNameWithoutExtension($FileName)
    if ($style.StartsWith($FileNamePrefix)) {
        $style = $style.Substring($FileNamePrefix.Length)
    }

    if (($style -eq '') -or ($style -eq 'Regular')) {
        return "$FamilyName (TrueType)"
    }

    $styleParts = [regex]::Matches($style, '[A-Z][a-z]*') | ForEach-Object { $_.Value }
    if ($styleParts.Count -gt 0) {
        $style = $styleParts -join ' '
    }
    return "$FamilyName $style (TrueType)"
}

function Notify-FontChanged {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd,
    uint Msg,
    System.IntPtr wParam,
    string lParam,
    uint fuFlags,
    uint uTimeout,
    out System.IntPtr lpdwResult);
"@ -ErrorAction SilentlyContinue

    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_FONTCHANGE = 0x001D
    $SMTO_ABORTIFHUNG = 0x0002
    $result = [IntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_FONTCHANGE,
        [IntPtr]::Zero,
        $null,
        $SMTO_ABORTIFHUNG,
        1000,
        [ref]$result
    ) | Out-Null
}

function Install-UserFontsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [Parameter(Mandatory = $true)][string]$FamilyName,
        [Parameter(Mandatory = $true)][string]$FileNamePrefix
    )

    if (-not (Test-Path $SourceDir)) {
        throw "Font source directory not found: $SourceDir"
    }

    $targetDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    if (-not (Test-Path $fontRegistryPath)) {
        New-Item -Path $fontRegistryPath -Force | Out-Null
    }

    $existingFontEntries = (reg query "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" 2>$null) |
        Where-Object { $_ -match [regex]::Escape($FamilyName) }
    foreach ($existingFontEntry in $existingFontEntries) {
        if ($existingFontEntry -match '^\s+(.+?)\s+REG_SZ\s+') {
            & reg delete "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v $Matches[1] /f | Out-Null
        }
    }

    $fontFiles = Get-ChildItem -Path $SourceDir -File | Where-Object {
        $fileName = $_.Name
        $Patterns | Where-Object { $fileName -like $_ }
    }

    if (-not $fontFiles) {
        throw "No font files matched in $SourceDir"
    }

    foreach ($fontFile in $fontFiles) {
        $targetPath = Join-Path $targetDir $fontFile.Name
        Copy-Item -Path $fontFile.FullName -Destination $targetPath -Force
        $displayName = Get-FontRegistryDisplayName -FileName $fontFile.Name -FamilyName $FamilyName -FileNamePrefix $FileNamePrefix
        & reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v $displayName /t REG_SZ /d $fontFile.Name /f | Out-Null
    }

    Notify-FontChanged
}

function Install-JetBrainsMonoNerdFont {
    $downloadUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $archivePath = Join-Path $env:TEMP "JetBrainsMono.zip"
    $extractDir = Join-Path $env:TEMP "JetBrainsMono-font"

    if (Test-Path $extractDir) {
        Remove-Item -Path $extractDir -Recurse -Force
    }

    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath
    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

    Install-UserFontsFromDirectory `
        -SourceDir $extractDir `
        -Patterns @("JetBrainsMonoNerdFontMono-*.ttf") `
        -FamilyName "JetBrainsMono NFM" `
        -FileNamePrefix "JetBrainsMonoNerdFontMono-"

    Remove-Item -Path $archivePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $wingetOutput = (& winget list --id $Id -e --source winget --accept-source-agreements | Out-String)
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
        $candidatePaths = Get-ChildItem -Path $packageDir.FullName -Recurse -File -Filter "$binaryName.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName
        if ($candidatePaths) {
            return $candidatePaths[0].FullName
        }
    }

    return $null
}

function Get-WingetLinkCandidatePaths {
    param([Parameter(Mandatory = $true)][string[]]$BinaryNames)

    $candidateDirs = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps")
    )

    return Get-DirectoryCommandCandidatePaths -Directories $candidateDirs -BinaryNames $BinaryNames
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
        "--source", "winget",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    if ($UserScope) {
        $wingetArgs += @("--scope", "user")
    }

    & winget @wingetArgs
    return ($LASTEXITCODE -eq 0)
}

function Ensure-WingetBinaryInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$PackagePrefix,
        [Parameter(Mandatory = $true)][string[]]$BinaryNames,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string[]]$ExtraCandidatePaths = @()
    )

    $candidatePaths = @(
        @(Get-WingetLinkCandidatePaths -BinaryNames $BinaryNames)
        @($ExtraCandidatePaths | Where-Object { $_ })
    )

    $commandInfo = Wait-ForCommandInfo -Names $BinaryNames -CandidatePaths $candidatePaths -TimeoutSeconds 2
    if ($commandInfo) {
        return $commandInfo
    }

    $installSucceeded = Invoke-WingetInstall -Id $Id -UserScope
    if ((-not $installSucceeded) -and (-not (Test-WingetPackageInstalled $Id))) {
        throw "$DisplayName install failed via winget."
    }

    Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

    $installedBinary = Find-WingetInstalledBinary -PackagePrefix $PackagePrefix -BinaryNames $BinaryNames
    if ($installedBinary) {
        Add-UserPathOnce (Split-Path -Parent $installedBinary)
        $candidatePaths += $installedBinary
    }

    $commandInfo = Wait-ForCommandInfo -Names $BinaryNames -CandidatePaths $candidatePaths -TimeoutSeconds 20
    if (-not $commandInfo) {
        throw "$DisplayName was installed but no command was found. Check WinGet package '$Id'."
    }

    return $commandInfo
}

function Get-PowerShellCandidatePaths {
    return @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "powershell\7\pwsh.exe")
    ) | Where-Object { $_ }
}

function Install-PortablePowerShell {
    $portableDir = Join-Path $env:LOCALAPPDATA "powershell\7"
    $portableZip = Join-Path $env:TEMP "powershell-win-x64.zip"
    $releaseApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

    $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{
        "User-Agent" = "GNU_files install-windows-terminal-tooling.ps1"
    }

    $asset = $release.assets | Where-Object { $_.name -match '^PowerShell-.*-win-x64\.zip$' } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find a Windows x64 PowerShell asset in the latest PowerShell release."
    }

    if (Test-Path $portableDir) {
        Remove-Item -Path $portableDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $portableZip
    Expand-Archive -Path $portableZip -DestinationPath $portableDir -Force
    Remove-Item -Path $portableZip -Force -ErrorAction SilentlyContinue

    $portableExe = Join-Path $portableDir "pwsh.exe"
    if (-not (Test-Path $portableExe)) {
        throw "Portable PowerShell install failed: pwsh.exe was not found under $portableDir"
    }

    Add-UserPathOnce $portableDir
    return $portableExe
}

function Get-PsmuxManagedPluginNames {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        return @()
    }

    $configContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
    if (-not $configContent) {
        return @()
    }

    $pluginNames = @()
    $pluginMatches = [regex]::Matches($configContent, "set\s+-g\s+@plugin\s+'([^']+)'")
    foreach ($pluginMatch in $pluginMatches) {
        $pluginSpec = $pluginMatch.Groups[1].Value.Trim()
        if (($pluginSpec -match '^psmux-plugins/(.+)$') -and ($pluginSpec -ne 'psmux-plugins/ppm')) {
            $pluginNames += $Matches[1]
        }
    }

    return $pluginNames | Select-Object -Unique
}

function Test-PsmuxPluginDirectoryValid {
    param([Parameter(Mandatory = $true)][string]$PluginPath)

    if (-not (Test-Path $PluginPath)) {
        return $false
    }

    $pluginName = Split-Path -Leaf $PluginPath
    $entrypoints = @(
        (Join-Path $PluginPath 'plugin.conf'),
        (Join-Path $PluginPath "$pluginName.ps1")
    )

    foreach ($entrypoint in $entrypoints) {
        if (Test-Path $entrypoint) {
            return $true
        }
    }

    return $false
}

function Repair-PsmuxPluginsFromBootstrapRepo {
    param(
        [Parameter(Mandatory = $true)][string]$BootstrapRepoPath,
        [Parameter(Mandatory = $true)][string]$PluginRoot,
        [Parameter(Mandatory = $true)][string]$ConfigPath
    )

    $pluginNames = Get-PsmuxManagedPluginNames -ConfigPath $ConfigPath
    foreach ($pluginName in $pluginNames) {
        $sourcePath = Join-Path $BootstrapRepoPath $pluginName
        if (-not (Test-Path $sourcePath)) {
            continue
        }

        $targetPath = Join-Path $PluginRoot $pluginName
        if (Test-PsmuxPluginDirectoryValid -PluginPath $targetPath) {
            continue
        }

        if (Test-Path $targetPath) {
            Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
        Write-Host "Bootstrapped plugin from monorepo: $pluginName" -ForegroundColor Green
    }
}

function Install-PsmuxPluginBootstrapRepo {
    param([Parameter(Mandatory = $true)][string]$Destination)

    if (Test-Path $Destination) {
        Remove-Item -Path $Destination -Recurse -Force
    }

    if (Test-CommandExists "git") {
        git clone https://github.com/psmux/psmux-plugins.git $Destination
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Write-Warning "git clone of psmux plugins failed; falling back to GitHub zip download."
    }

    $archivePath = Join-Path $env:TEMP "psmux-plugins.zip"
    $extractRoot = Join-Path $env:TEMP "psmux-plugins-extract"
    if (Test-Path $extractRoot) {
        Remove-Item -Path $extractRoot -Recurse -Force
    }

    $downloaded = $false
    foreach ($branch in @("master", "main")) {
        try {
            Invoke-WebRequest -Uri "https://github.com/psmux/psmux-plugins/archive/refs/heads/$branch.zip" -OutFile $archivePath
            $downloaded = $true
            break
        } catch {
            Write-Warning "Failed to download psmux plugins '$branch' branch zip: $($_.Exception.Message)"
        }
    }
    if (-not $downloaded) {
        throw "Failed to download psmux plugin bootstrap repository from GitHub."
    }

    Expand-Archive -Path $archivePath -DestinationPath $extractRoot -Force
    Remove-Item -Path $archivePath -Force -ErrorAction SilentlyContinue

    $extractedRepo = Get-ChildItem -Path $extractRoot -Directory -Filter "psmux-plugins-*" | Select-Object -First 1
    if (-not $extractedRepo) {
        throw "Failed to extract psmux plugin bootstrap repository."
    }

    Move-Item -Path $extractedRepo.FullName -Destination $Destination
    Remove-Item -Path $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-PortableAlacritty {
    param([Parameter(Mandatory = $true)][string]$AlacrittyVersion)

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

function Resolve-GnuFilesPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path $resolvedPath)) {
        throw "GNU_files path does not exist: $resolvedPath"
    }

    foreach ($requiredPath in @(".psmux.conf", "alacritty.windows.toml", "versions.conf")) {
        if (-not (Test-Path (Join-Path $resolvedPath $requiredPath))) {
            throw "GNU_files path is missing required file '$requiredPath': $resolvedPath"
        }
    }

    return $resolvedPath
}

Write-Host "=== Windows terminal tooling setup: psmux + Alacritty ===" -ForegroundColor Cyan

if (-not (Test-CommandExists "winget")) {
    throw "winget is not available. Install App Installer from the Microsoft Store."
}

$gnuFilesPath = Resolve-GnuFilesPath -Path $GnuFilesPath
$AlacrittyVersion = Get-VersionFromConfig -ConfigPath (Join-Path $gnuFilesPath "versions.conf") -Name "ALACRITTY_VERSION" -Fallback "0.16.1"
Write-Host "Using GNU_files at $gnuFilesPath" -ForegroundColor Green

# --- psmux + config + plugins ---
Write-Host "`n[1/2] Installing psmux + config..." -ForegroundColor Yellow

$psmuxWingetId = "marlocarlo.psmux"
Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
Add-UserPathOnce "$env:USERPROFILE\.cargo\bin"

$pwshBinary = $null
try {
    $pwshBinary = Ensure-WingetBinaryInstalled -Id "Microsoft.PowerShell" -PackagePrefix "Microsoft.PowerShell" -BinaryNames @("pwsh") -DisplayName "PowerShell 7" -ExtraCandidatePaths (Get-PowerShellCandidatePaths)
} catch {
    Write-Warning "WinGet did not expose a usable 'pwsh' command in this session. Falling back to portable PowerShell. Error: $($_.Exception.Message)"
    $portablePwshExe = Install-PortablePowerShell
    $pwshBinary = Wait-ForCommandInfo -Names @("pwsh") -CandidatePaths @($portablePwshExe) -TimeoutSeconds 20
    if (-not $pwshBinary) {
        throw "PowerShell 7 install failed. Neither winget nor the portable fallback produced a usable 'pwsh' command."
    }
}

$psmuxCandidatePaths = @(
    @(Get-WingetLinkCandidatePaths -BinaryNames @("psmux", "tmux"))
    @(Get-DirectoryCommandCandidatePaths -Directories @("$env:USERPROFILE\.cargo\bin") -BinaryNames @("psmux", "tmux") -IncludeExtensionless)
)
$psmuxInstalledBinary = Find-WingetInstalledBinary -PackagePrefix $psmuxWingetId -BinaryNames @("psmux", "tmux")
if ($psmuxInstalledBinary) {
    Add-UserPathOnce (Split-Path -Parent $psmuxInstalledBinary)
    $psmuxCandidatePaths += $psmuxInstalledBinary
}

$psmuxBinary = Wait-ForCommandInfo -Names @("psmux", "tmux") -CandidatePaths $psmuxCandidatePaths -TimeoutSeconds 2
if (-not $psmuxBinary) {
    $psmuxInstalled = Invoke-WingetInstall -Id $psmuxWingetId -UserScope
    if (-not $psmuxInstalled) {
        if (-not (Test-WingetPackageInstalled $psmuxWingetId)) {
            throw "psmux install failed via winget."
        }
        Write-Host "psmux is already installed via winget; continuing." -ForegroundColor Yellow
    }

    $psmuxInstalledBinary = Find-WingetInstalledBinary -PackagePrefix $psmuxWingetId -BinaryNames @("psmux", "tmux")
    if ($psmuxInstalledBinary) {
        Add-UserPathOnce (Split-Path -Parent $psmuxInstalledBinary)
        $psmuxCandidatePaths += $psmuxInstalledBinary
    }

    $psmuxBinary = Wait-ForCommandInfo -Names @("psmux", "tmux") -CandidatePaths $psmuxCandidatePaths -TimeoutSeconds 25
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

$psmuxSourcePath = Join-Path $gnuFilesPath ".psmux.conf"
$psmuxTargetPath = "$env:USERPROFILE\.psmux.conf"
$psmuxPluginRoot = "$env:USERPROFILE\.psmux\plugins"
$ppmTargetPath = Join-Path $psmuxPluginRoot 'ppm'

if (Test-Path $psmuxTargetPath) {
    $existingPsmuxConfig = Get-Content -Path $psmuxTargetPath -Raw -ErrorAction SilentlyContinue
    if ($existingPsmuxConfig -and -not $existingPsmuxConfig.StartsWith("# Managed by install-windows-terminal-tooling.ps1") -and -not $existingPsmuxConfig.StartsWith("# Managed by setup-dev-tools.ps1")) {
        $backupPath = "${psmuxTargetPath}.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -Path $psmuxTargetPath -Destination $backupPath -Force
        Write-Host "Existing psmux config backed up to $backupPath" -ForegroundColor Yellow
    }
}

$managedHeader = "# Managed by install-windows-terminal-tooling.ps1 from GNU_files/.psmux.conf`r`n"
$psmuxConfig = $managedHeader + (Get-Content -Path $psmuxSourcePath -Raw)
Set-Content -Path $psmuxTargetPath -Value $psmuxConfig -NoNewline
Write-Host "psmux config written: $psmuxTargetPath" -ForegroundColor Green

if (-not $SkipPsmuxPlugins) {
    if (-not (Test-Path $psmuxPluginRoot)) {
        New-Item -ItemType Directory -Path $psmuxPluginRoot -Force | Out-Null
    }

    $ppmBootstrapRepo = Join-Path $env:TEMP "psmux-plugins-bootstrap"
    Install-PsmuxPluginBootstrapRepo -Destination $ppmBootstrapRepo

    if (Test-Path $ppmTargetPath) {
        Remove-Item -Path $ppmTargetPath -Recurse -Force
    }
    Copy-Item -Path (Join-Path $ppmBootstrapRepo 'ppm') -Destination $ppmTargetPath -Recurse -Force
    Write-Host "PPM bootstrapped to $ppmTargetPath" -ForegroundColor Green

    Repair-PsmuxPluginsFromBootstrapRepo -BootstrapRepoPath $ppmBootstrapRepo -PluginRoot $psmuxPluginRoot -ConfigPath $psmuxTargetPath

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

    Repair-PsmuxPluginsFromBootstrapRepo -BootstrapRepoPath $ppmBootstrapRepo -PluginRoot $psmuxPluginRoot -ConfigPath $psmuxTargetPath
    Remove-Item -Path $ppmBootstrapRepo -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Skipping psmux plugin bootstrap because -SkipPsmuxPlugins was provided." -ForegroundColor Yellow
}

# --- Alacritty + config ---
Write-Host "`n[2/2] Installing Alacritty + config..." -ForegroundColor Yellow

Add-UserPathOnce "$env:LOCALAPPDATA\alacritty"
if (-not (Test-CommandExists "alacritty")) {
    $alacrittyInstalled = Invoke-WingetInstall -Id "Alacritty.Alacritty" -UserScope
    $alacrittyWingetExitCode = $LASTEXITCODE
    Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"

    $alacrittyCommand = Wait-ForCommandInfo -Names @("alacritty") -CandidatePaths @(
        (Join-Path "$env:LOCALAPPDATA\alacritty" "alacritty.exe")
    ) -TimeoutSeconds 10

    if (-not $alacrittyCommand) {
        if ($alacrittyInstalled) {
            Write-Host "winget did not leave an 'alacritty' command available, falling back to portable Alacritty..." -ForegroundColor Yellow
        } else {
            Write-Host "winget install failed (exit code $alacrittyWingetExitCode), falling back to portable Alacritty..." -ForegroundColor Yellow
        }
        Install-PortableAlacritty -AlacrittyVersion $AlacrittyVersion
    }
}

Add-UserPathOnce "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
Add-UserPathOnce "$env:LOCALAPPDATA\alacritty"

$alacrittyCommand = Wait-ForCommandInfo -Names @("alacritty") -CandidatePaths @(
    (Join-Path "$env:LOCALAPPDATA\alacritty" "alacritty.exe")
) -TimeoutSeconds 15
if (-not $alacrittyCommand) {
    throw "Alacritty install failed. Neither winget nor the portable fallback produced an 'alacritty' command."
}

$alacrittySourcePath = Join-Path $gnuFilesPath "alacritty.windows.toml"
$alacrittyConfigDir = "$env:APPDATA\alacritty"
$alacrittyConfigPath = "$alacrittyConfigDir\alacritty.toml"

if (-not (Test-Path $alacrittyConfigDir)) {
    New-Item -ItemType Directory -Path $alacrittyConfigDir -Force | Out-Null
}

$alacrittyConfig = Get-Content -Path $alacrittySourcePath -Raw
$mesloFontInstalled = Test-FontInstalled @("MesloLGM Nerd Font Mono")
$jetBrainsMonoNerdInstalled = Test-JetBrainsMonoNerdFontInstalled

if ((-not $SkipFonts) -and (-not $mesloFontInstalled) -and (-not $jetBrainsMonoNerdInstalled)) {
    Write-Host "MesloLGM Nerd Font Mono not found. Installing JetBrainsMono Nerd Font..." -ForegroundColor Yellow
    $fontInstalled = Invoke-WingetInstall -Id "DEVCOM.JetBrainsMonoNerdFont" -UserScope
    if ($fontInstalled) {
        $jetBrainsMonoNerdInstalled = Wait-ForFontInstalled @("JetBrainsMono NFM", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font") -TimeoutSeconds 20
    }

    if (-not $jetBrainsMonoNerdInstalled) {
        try {
            Install-JetBrainsMonoNerdFont
            $jetBrainsMonoNerdInstalled = Wait-ForFontInstalled @("JetBrainsMono NFM", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font") -TimeoutSeconds 20
        } catch {
            Write-Warning "Direct JetBrainsMono Nerd Font install failed: $($_.Exception.Message)"
        }
    }
}

if (-not $mesloFontInstalled) {
    if ($jetBrainsMonoNerdInstalled) {
        $alacrittyConfig = $alacrittyConfig -replace 'family = "MesloLGM Nerd Font Mono"', 'family = "JetBrainsMono NFM"'
        Write-Host "Using JetBrainsMono NFM in Alacritty config." -ForegroundColor Green
    } else {
        $alacrittyConfig = $alacrittyConfig -replace 'family = "MesloLGM Nerd Font Mono"', 'family = "Cascadia Mono"'
        Write-Warning "No preferred Nerd Font was found. Using Cascadia Mono in Alacritty config."
    }
}

if (Test-Path $alacrittyConfigPath) {
    $existingAlacrittyConfig = Get-Content -Path $alacrittyConfigPath -Raw -ErrorAction SilentlyContinue
    if ($existingAlacrittyConfig -and -not $existingAlacrittyConfig.StartsWith("# Managed by install-windows-terminal-tooling.ps1") -and -not $existingAlacrittyConfig.StartsWith("# Managed by setup-dev-tools.ps1")) {
        $backupPath = "${alacrittyConfigPath}.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -Path $alacrittyConfigPath -Destination $backupPath -Force
        Write-Host "Existing Alacritty config backed up to $backupPath" -ForegroundColor Yellow
    }
}

$managedHeader = "# Managed by install-windows-terminal-tooling.ps1 from GNU_files/alacritty.windows.toml`r`n"
Set-Content -Path $alacrittyConfigPath -Value ($managedHeader + $alacrittyConfig) -NoNewline
Write-Host "Alacritty config written: $alacrittyConfigPath" -ForegroundColor Green

try {
    $alacrittyVersionText = (& $alacrittyCommand.Source --version).Trim()
} catch {
    $alacrittyVersionText = "installed"
}
Write-Host "Alacritty: $alacrittyVersionText" -ForegroundColor Green

Write-Host "`nWindows terminal tooling setup complete." -ForegroundColor Green
Write-Host "Open a new Windows terminal/session if PATH changes are not visible yet." -ForegroundColor Yellow
