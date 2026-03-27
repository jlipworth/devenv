# setup-dev-tools.ps1
# Installs Git, Node.js (via fnm), OpenAI Codex CLI, Claude Code, uv,
# psmux, Alacritty, Neovim, and GNU_files config with no admin requirement.
#
# Usage: powershell -ExecutionPolicy Bypass -File setup-dev-tools.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Version pins / minimums - keep in sync with versions.conf where applicable
$AlacrittyVersion = "0.16.1"
$FallbackNeovimVersion = "0.11.6"
$MinimumNeovimVersion = [version]"0.11.2"
$GnuFilesRepoUrl = "https://github.com/jlipworth/devenv.git"
$GnuFilesBootstrapBranch = "master"
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

    $profilePath = $PROFILE
    if ([string]::IsNullOrWhiteSpace($profilePath)) {
        $documentsDir = [Environment]::GetFolderPath("MyDocuments")
        if ([string]::IsNullOrWhiteSpace($documentsDir)) {
            $documentsDir = Join-Path $env:USERPROFILE "Documents"
        }

        $profileRoot = if ($PSVersionTable.PSEdition -eq "Core") { "PowerShell" } else { "WindowsPowerShell" }
        $profilePath = Join-Path $documentsDir "$profileRoot\Microsoft.PowerShell_profile.ps1"
        Write-Warning "`$PROFILE was empty. Falling back to '$profilePath'."
    }

    $profileDir = Split-Path -Parent $profilePath
    if ([string]::IsNullOrWhiteSpace($profileDir)) {
        Write-Warning "PowerShell profile directory could not be determined. Skipping profile update."
        return
    }

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $content = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch [regex]::Escape($Line)) {
        Add-Content -Path $profilePath -Value "`r`n$Line`r`n"
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

function Install-PortableGit {
    $portableDir = Join-Path $env:LOCALAPPDATA "Git\mingit"
    $portableZip = Join-Path $env:TEMP "mingit.zip"
    $releaseApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

    $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{
        "User-Agent" = "GNU_files setup-dev-tools.ps1"
    }

    $asset = $release.assets | Where-Object { $_.name -match '^MinGit-.*-busybox-64-bit\.zip$' } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find a MinGit portable asset in the latest Git for Windows release."
    }

    if (Test-Path $portableDir) {
        Remove-Item -Path $portableDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $portableZip
    Expand-Archive -Path $portableZip -DestinationPath $portableDir -Force
    Remove-Item -Path $portableZip -Force -ErrorAction SilentlyContinue

    $portableCmdDir = Join-Path $portableDir "cmd"
    if (-not (Test-Path (Join-Path $portableCmdDir "git.exe"))) {
        throw "Portable Git install failed: git.exe was not found under $portableCmdDir"
    }

    Add-UserPathOnce $portableCmdDir
    Add-PathOnce $portableCmdDir

    return (Join-Path $portableCmdDir "git.exe")
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-NeovimCommandVersion {
    param([string]$CommandName = "nvim")

    if (-not (Test-CommandExists $CommandName)) {
        return $null
    }

    try {
        $versionLine = (& $CommandName --version | Select-Object -First 1).Trim()
        if ($versionLine -match 'NVIM v(\d+\.\d+\.\d+)') {
            return [version]$Matches[1]
        }
    } catch {
        return $null
    }

    return $null
}

function Get-LatestNeovimVersion {
    $releaseApiUrl = "https://api.github.com/repos/neovim/neovim/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{
            "User-Agent" = "GNU_files setup-dev-tools.ps1"
        }

        if ($release.tag_name -match '^v?(\d+\.\d+\.\d+)$') {
            return $Matches[1]
        }

        Write-Warning "Unexpected Neovim release tag '$($release.tag_name)'. Falling back to pinned version $FallbackNeovimVersion."
    } catch {
        Write-Warning "Failed to query the latest Neovim release. Falling back to pinned version $FallbackNeovimVersion. Error: $($_.Exception.Message)"
    }

    return $FallbackNeovimVersion
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

function Get-FnmMultishellCandidatePaths {
    param([Parameter(Mandatory = $true)][string[]]$BinaryNames)

    if (-not $env:FNM_MULTISHELL_PATH) {
        return @()
    }

    return Get-DirectoryCommandCandidatePaths -Directories @($env:FNM_MULTISHELL_PATH) -BinaryNames $BinaryNames -IncludeExtensionless
}

function Get-PowerShellCandidatePaths {
    return @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "powershell\7\pwsh.exe")
    ) | Where-Object { $_ }
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

    if ((-not $commandInfo) -and (-not $installedBinary)) {
        $installedBinary = Find-WingetInstalledBinary -PackagePrefix $PackagePrefix -BinaryNames $BinaryNames
        if ($installedBinary) {
            Add-UserPathOnce (Split-Path -Parent $installedBinary)
            $candidatePaths += $installedBinary
            $commandInfo = Wait-ForCommandInfo -Names $BinaryNames -CandidatePaths $candidatePaths -TimeoutSeconds 10
        }
    }

    if (-not $commandInfo) {
        throw "$DisplayName was installed but no command was found. Check WinGet package '$Id'."
    }

    return $commandInfo
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

function Test-GnuFilesCheckoutValid {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    if (-not (Test-Path $RepoPath)) {
        return $false
    }

    $requiredPaths = @(
        ".git",
        ".psmux.conf",
        "alacritty.toml",
        "nvim"
    )

    foreach ($requiredPath in $requiredPaths) {
        if (-not (Test-Path (Join-Path $RepoPath $requiredPath))) {
            return $false
        }
    }

    return $true
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
    param(
        [Parameter(Mandatory = $true)][string]$Alias,
        [string]$CommandPath = "fnm"
    )

    $fnmList = & $CommandPath list
    foreach ($line in $fnmList) {
        if (($line -match [regex]::Escape($Alias)) -and ($line -match 'v\d+\.\d+\.\d+')) {
            return $matches[0]
        }
    }

    return $null
}

function Ensure-StableNpmPrefix {
    param([string]$CommandPath = "npm")

    $desiredPrefix = "$env:APPDATA\npm"

    if (-not (Test-Path $desiredPrefix)) {
        New-Item -ItemType Directory -Path $desiredPrefix -Force | Out-Null
    }

    $currentPrefix = (& $CommandPath config get prefix).Trim()
    if ($currentPrefix -ne $desiredPrefix) {
        & $CommandPath config set prefix $desiredPrefix | Out-Null
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
    param([Parameter(Mandatory = $true)][string]$Version)

    $portableDir = "$env:LOCALAPPDATA\nvim-bin"
    $portableZip = "$env:TEMP\nvim-win64.zip"
    $portableRoot = Join-Path $portableDir "nvim-win64"
    $downloadUrl = "https://github.com/neovim/neovim/releases/download/v$Version/nvim-win64.zip"

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

function Install-PortableFnm {
    $portableDir = Join-Path $env:LOCALAPPDATA "fnm"
    $portableZip = Join-Path $env:TEMP "fnm-windows.zip"
    $releaseApiUrl = "https://api.github.com/repos/Schniz/fnm/releases/latest"

    $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{
        "User-Agent" = "GNU_files setup-dev-tools.ps1"
    }

    $asset = $release.assets | Where-Object { $_.name -eq 'fnm-windows.zip' } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find a Windows fnm asset in the latest fnm release."
    }

    if (Test-Path $portableDir) {
        Remove-Item -Path $portableDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $portableZip
    Expand-Archive -Path $portableZip -DestinationPath $portableDir -Force
    Remove-Item -Path $portableZip -Force -ErrorAction SilentlyContinue

    $portableExe = Get-ChildItem -Path $portableDir -Recurse -File -Filter "fnm.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 1

    if (-not $portableExe) {
        throw "Portable fnm install failed: fnm.exe was not found under $portableDir"
    }

    Add-UserPathOnce (Split-Path -Parent $portableExe.FullName)

    return $portableExe.FullName
}

function Install-PortablePowerShell {
    $portableDir = Join-Path $env:LOCALAPPDATA "powershell\7"
    $portableZip = Join-Path $env:TEMP "powershell-win-x64.zip"
    $releaseApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

    $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{
        "User-Agent" = "GNU_files setup-dev-tools.ps1"
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

Write-Host "=== Dev Tools Setup (no admin) ===" -ForegroundColor Cyan

# --- Pre-flight: check winget ---
if (-not (Test-CommandExists "winget")) {
    throw "winget is not available. Install App Installer from the Microsoft Store."
}

# --- 1. Git ---
Write-Host "`n[1/10] Installing Git..." -ForegroundColor Yellow

$portableGitExe = $null

if (-not (Test-CommandExists "git")) {
    Write-Host "Git not found. Installing portable MinGit (no admin)..." -ForegroundColor Yellow
    $portableGitExe = Install-PortableGit
}

Add-UserPathOnce "$env:LOCALAPPDATA\Programs\Git\cmd"

$gitCandidatePaths = @(
    $portableGitExe,
    (Join-Path "$env:LOCALAPPDATA\Programs\Git\cmd" "git.exe"),
    (Join-Path "$env:ProgramFiles\Git\cmd" "git.exe"),
    (Join-Path "$env:LOCALAPPDATA\Git\mingit\cmd" "git.exe")
) | Where-Object { $_ }

$gitCommand = Wait-ForCommandInfo -Names @("git") -CandidatePaths $gitCandidatePaths -TimeoutSeconds 15
if (-not $gitCommand) {
    Write-Warning "Git was not usable from the default locations. Falling back to portable MinGit."
    $portableGitExe = Install-PortableGit
    $gitCommand = Wait-ForCommandInfo -Names @("git") -CandidatePaths @($portableGitExe) -TimeoutSeconds 15
}

if (-not $gitCommand) {
    throw "Git install failed. Neither winget nor the portable MinGit fallback produced a usable 'git' command."
}

$gitVersion = (& $gitCommand.Source --version).Trim()
Write-Host "Git $gitVersion" -ForegroundColor Green

# --- 2. fnm + Node.js + npm ---
Write-Host "`n[2/10] Installing fnm + Node.js..." -ForegroundColor Yellow

$fnmBinary = $null

try {
    $fnmBinary = Ensure-WingetBinaryInstalled -Id "Schniz.fnm" -PackagePrefix "Schniz.fnm" -BinaryNames @("fnm") -DisplayName "fnm"
} catch {
    Write-Warning "WinGet did not expose a usable 'fnm' command in this session. Falling back to portable fnm. Error: $($_.Exception.Message)"
    $portableFnmExe = Install-PortableFnm
    $fnmBinary = Wait-ForCommandInfo -Names @("fnm") -CandidatePaths @($portableFnmExe) -TimeoutSeconds 20
    if (-not $fnmBinary) {
        throw "fnm install failed. Neither winget nor the portable fallback produced a usable 'fnm' command."
    }
}

$fnmExe = $fnmBinary.Source

$fnmInit = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'
Ensure-ProfileLine $fnmInit
Invoke-Expression ((& $fnmExe env --use-on-cd --shell powershell) | Out-String)
Refresh-SessionPath

& $fnmExe install --lts
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to install the latest LTS Node.js release."
}

$ltsNodeVersion = Get-FnmInstalledVersionForAlias -Alias "lts-latest" -CommandPath $fnmExe
if (-not $ltsNodeVersion) {
    throw "fnm installed Node.js, but the latest LTS version could not be resolved from 'fnm list'."
}

& $fnmExe use $ltsNodeVersion
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to activate Node.js $ltsNodeVersion."
}

$fnmActivationCandidatePaths = Get-FnmMultishellCandidatePaths -BinaryNames @("node", "npm")
$nodeCommand = Wait-ForCommandInfo -Names @("node") -CandidatePaths $fnmActivationCandidatePaths -TimeoutSeconds 15
$npmCommand = Wait-ForCommandInfo -Names @("npm") -CandidatePaths $fnmActivationCandidatePaths -TimeoutSeconds 15
if ((-not $nodeCommand) -or (-not $npmCommand)) {
    throw "fnm activated Node.js, but 'node' and/or 'npm' were not available in this session yet. Restart PowerShell and rerun if needed."
}

$nodeVersion = (& $nodeCommand.Source --version).Trim()
$npmExe = $npmCommand.Source

& $fnmExe default $ltsNodeVersion
if ($LASTEXITCODE -ne 0) {
    throw "fnm failed to set Node.js $ltsNodeVersion as the default."
}

$npmVersion = (& $npmCommand.Source --version).Trim()
Write-Host "Node $nodeVersion | npm $npmVersion" -ForegroundColor Green

$npmPrefix = Ensure-StableNpmPrefix -CommandPath $npmExe

# --- 3. OpenAI Codex CLI ---
Write-Host "`n[3/10] Installing OpenAI Codex CLI..." -ForegroundColor Yellow

if (-not (Test-NpmGlobalBinary -Prefix $npmPrefix -CommandName "codex")) {
    & $npmExe install -g @openai/codex
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install OpenAI Codex CLI via npm."
    }
}

Add-UserPathOnce $npmPrefix

$codexCommand = Wait-ForCommandInfo -Names @("codex") -CandidatePaths @(
    (Join-Path $npmPrefix "codex.cmd"),
    (Join-Path $npmPrefix "codex.ps1")
) -TimeoutSeconds 10
if (-not $codexCommand) {
    Write-Warning "Codex was installed, but 'codex' is not on PATH in this session yet. Restart PowerShell if needed."
}

try {
    if ($codexCommand) {
        $codexVersion = (& $codexCommand.Source --version).Trim()
    } else {
        $codexVersion = (codex --version).Trim()
    }
} catch {
    $codexVersion = "installed"
}

Write-Host "Codex: $codexVersion" -ForegroundColor Green

# --- 4. Claude Code ---
Write-Host "`n[4/10] Installing Claude Code..." -ForegroundColor Yellow

if (-not (Test-NpmGlobalBinary -Prefix $npmPrefix -CommandName "claude")) {
    & $npmExe install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Claude Code via npm."
    }
}

Add-UserPathOnce $npmPrefix

$claudeCommand = Wait-ForCommandInfo -Names @("claude") -CandidatePaths @(
    (Join-Path $npmPrefix "claude.cmd"),
    (Join-Path $npmPrefix "claude.ps1")
) -TimeoutSeconds 10
if (-not $claudeCommand) {
    Write-Warning "Claude Code was installed, but 'claude' is not on PATH in this session yet. Restart PowerShell if needed."
}

try {
    if ($claudeCommand) {
        $claudeVersion = (& $claudeCommand.Source --version).Trim()
    } else {
        $claudeVersion = (claude --version).Trim()
    }
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
    Refresh-SessionPath
}

Add-UserPathOnce "$env:USERPROFILE\.local\bin"
Add-UserPathOnce "$env:USERPROFILE\.cargo\bin"

$uvCommand = Wait-ForCommandInfo -Names @("uv") -CandidatePaths (
    Get-DirectoryCommandCandidatePaths -Directories @(
        "$env:USERPROFILE\.local\bin",
        "$env:USERPROFILE\.cargo\bin"
    ) -BinaryNames @("uv") -IncludeExtensionless
) -TimeoutSeconds 15
if (-not $uvCommand) {
    throw "uv was installed but is not on PATH. Check '$env:USERPROFILE\.local\bin'."
}

$uvVersion = (& $uvCommand.Source --version).Trim()
Write-Host "uv $uvVersion" -ForegroundColor Green

# --- 6. Clone GNU_files repo ---
Write-Host "`n[6/10] Preparing GNU_files repo..." -ForegroundColor Yellow

$defaultGnuFilesPath = Join-Path $env:USERPROFILE "GNU_files"
$scriptRepoPath = $PSScriptRoot
$currentWorkingPath = (Get-Location).Path
$gnuFilesPath = $null

$gnuFilesCandidates = @($scriptRepoPath, $currentWorkingPath, $defaultGnuFilesPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique

foreach ($candidatePath in $gnuFilesCandidates) {
    if (Test-GnuFilesCheckoutValid -RepoPath $candidatePath) {
        $gnuFilesPath = $candidatePath
        break
    }
}

if ($gnuFilesPath) {
    if ($gnuFilesPath -eq $scriptRepoPath) {
        Write-Host "Using GNU_files from script directory: $gnuFilesPath" -ForegroundColor Green
    } elseif ($gnuFilesPath -eq $currentWorkingPath) {
        Write-Host "Using GNU_files from current directory: $gnuFilesPath" -ForegroundColor Green
    } else {
        git -C $gnuFilesPath pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "git pull failed (local changes?). Continuing with existing checkout."
        } else {
            Write-Host "GNU_files updated at $gnuFilesPath" -ForegroundColor Green
        }
    }
} else {
    if (Test-Path $defaultGnuFilesPath) {
        $backupPath = "${defaultGnuFilesPath}_backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item -Path $defaultGnuFilesPath -Destination $backupPath
        Write-Warning "Existing GNU_files path was incomplete. Backed it up to $backupPath"
    }

    git clone --branch $GnuFilesBootstrapBranch --single-branch $GnuFilesRepoUrl $defaultGnuFilesPath
    if ($LASTEXITCODE -ne 0) {
        throw "GNU_files clone failed for branch '$GnuFilesBootstrapBranch'."
    }

    $gnuFilesPath = $defaultGnuFilesPath
    if (-not (Test-GnuFilesCheckoutValid -RepoPath $gnuFilesPath)) {
        throw "GNU_files clone completed, but the checkout from branch '$GnuFilesBootstrapBranch' is missing required files."
    }

    Write-Host "GNU_files cloned to $gnuFilesPath from branch '$GnuFilesBootstrapBranch'" -ForegroundColor Green
}

# --- 7. psmux + config + plugins ---
Write-Host "`n[7/10] Installing psmux + config..." -ForegroundColor Yellow

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
    & winget install --id $psmuxWingetId -e --scope user --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
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

    $alacrittyCommand = Wait-ForCommandInfo -Names @("alacritty") -CandidatePaths @(
        (Join-Path "$env:LOCALAPPDATA\alacritty" "alacritty.exe")
    ) -TimeoutSeconds 10

    if (-not $alacrittyCommand) {
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

$alacrittyCommand = Wait-ForCommandInfo -Names @("alacritty") -CandidatePaths @(
    (Join-Path "$env:LOCALAPPDATA\alacritty" "alacritty.exe")
) -TimeoutSeconds 15
if (-not $alacrittyCommand) {
    throw "Alacritty install failed. Neither winget nor the portable fallback produced an 'alacritty' command."
}

$alacrittyWindowsSourcePath = Join-Path $gnuFilesPath "alacritty.windows.toml"
$alacrittyDefaultSourcePath = Join-Path $gnuFilesPath "alacritty.toml"
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
    $jetBrainsMonoNerdInstalled = Test-JetBrainsMonoNerdFontInstalled

    if ((-not $mesloFontInstalled) -and (-not $jetBrainsMonoNerdInstalled)) {
        Write-Host "MesloLGM Nerd Font Mono not found. Installing JetBrainsMono Nerd Font..." -ForegroundColor Yellow
        $fontInstalled = Invoke-WingetInstall -Id "DEVCOM.JetBrainsMonoNerdFont" -UserScope

        if ($fontInstalled) {
            $jetBrainsMonoNerdInstalled = Wait-ForFontInstalled @("JetBrainsMono NFM", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font") -TimeoutSeconds 20
        }

        if (-not $jetBrainsMonoNerdInstalled) {
            if (-not $fontInstalled) {
                Write-Warning "JetBrainsMono Nerd Font install failed via winget. Falling back to direct user-font install."
            } else {
                Write-Warning "JetBrainsMono Nerd Font was not detected after winget install. Falling back to direct user-font install."
            }

            try {
                Install-JetBrainsMonoNerdFont
                $jetBrainsMonoNerdInstalled = Wait-ForFontInstalled @("JetBrainsMono NFM", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font") -TimeoutSeconds 20
            } catch {
                Write-Warning "Direct JetBrainsMono Nerd Font install failed: $($_.Exception.Message)"
            }

            if (-not $jetBrainsMonoNerdInstalled) {
                $jetBrainsMonoFontFiles = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts") -Filter "JetBrainsMonoNerdFontMono-*.ttf" -ErrorAction SilentlyContinue
                if ($jetBrainsMonoFontFiles) {
                    Write-Warning "JetBrainsMono Nerd Font files were copied, but Windows has not reported the font as installed yet. A sign-out or reboot may be required before Alacritty can use it."
                }
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
    $alacrittyVersion = (& $alacrittyCommand.Source --version).Trim()
} catch {
    $alacrittyVersion = "installed"
}

Write-Host "Alacritty: $alacrittyVersion" -ForegroundColor Green

# --- 9. Neovim ---
Write-Host "`n[9/10] Installing Neovim..." -ForegroundColor Yellow

$fdBinary = Ensure-WingetBinaryInstalled -Id "sharkdp.fd" -PackagePrefix "sharkdp.fd" -BinaryNames @("fd") -DisplayName "fd"
$rgBinary = Ensure-WingetBinaryInstalled -Id "BurntSushi.ripgrep.MSVC" -PackagePrefix "BurntSushi.ripgrep.MSVC" -BinaryNames @("rg") -DisplayName "ripgrep"
$gccBinary = Ensure-WingetBinaryInstalled -Id "BrechtSanders.WinLibs.POSIX.UCRT" -PackagePrefix "BrechtSanders.WinLibs.POSIX.UCRT" -BinaryNames @("gcc") -DisplayName "WinLibs GCC"
$treeSitterBinary = Ensure-WingetBinaryInstalled -Id "tree-sitter.tree-sitter-cli" -PackagePrefix "tree-sitter.tree-sitter-cli" -BinaryNames @("tree-sitter") -DisplayName "tree-sitter-cli"
$lazygitBinary = Ensure-WingetBinaryInstalled -Id "JesseDuffield.lazygit" -PackagePrefix "JesseDuffield.lazygit" -BinaryNames @("lazygit") -DisplayName "lazygit"
$cmakeBinary = Ensure-WingetBinaryInstalled -Id "Kitware.CMake" -PackagePrefix "Kitware.CMake" -BinaryNames @("cmake") -DisplayName "CMake"

$fdVersion = (& $fdBinary.Source --version | Select-Object -First 1).Trim()
$rgVersion = (& $rgBinary.Source --version | Select-Object -First 1).Trim()
$gccVersion = (& $gccBinary.Source --version | Select-Object -First 1).Trim()
$treeSitterVersion = (& $treeSitterBinary.Source --version | Select-Object -First 1).Trim()
$lazygitVersion = (& $lazygitBinary.Source --version | Select-Object -First 1).Trim()
$cmakeVersion = (& $cmakeBinary.Source --version | Select-Object -First 1).Trim()
Write-Host "fd: $fdVersion | rg: $rgVersion | gcc: $gccVersion | tree-sitter: $treeSitterVersion | lazygit: $lazygitVersion | cmake: $cmakeVersion" -ForegroundColor Green

$targetNeovimVersion = Get-LatestNeovimVersion
$targetNeovimVersionObject = [version]$targetNeovimVersion
Write-Host "Target Neovim version: $targetNeovimVersion (LazyVim minimum: $MinimumNeovimVersion)" -ForegroundColor Green

$portableNvimBinPath = "$env:LOCALAPPDATA\nvim-bin\nvim-win64\bin"
Add-UserPathOnce $portableNvimBinPath

$nvimCommand = Wait-ForCommandInfo -Names @("nvim") -CandidatePaths @(
    (Join-Path $portableNvimBinPath "nvim.exe")
) -TimeoutSeconds 5
$installedNvimVersion = Get-NeovimCommandVersion

if (($null -eq $installedNvimVersion) -or ($installedNvimVersion -lt $targetNeovimVersionObject)) {
    if ($null -eq $installedNvimVersion) {
        Write-Host "No usable Neovim found on PATH; installing latest portable build..." -ForegroundColor Yellow
    } else {
        Write-Host "Existing Neovim $installedNvimVersion is older than target $targetNeovimVersion; installing latest portable build..." -ForegroundColor Yellow
    }

    Install-PortableNeovim -Version $targetNeovimVersion
    Add-UserPathOnce $portableNvimBinPath
    $nvimCommand = Wait-ForCommandInfo -Names @("nvim") -CandidatePaths @(
        (Join-Path $portableNvimBinPath "nvim.exe")
    ) -TimeoutSeconds 20
}

if (-not $nvimCommand) {
    throw "Neovim install failed. The portable latest-release install did not produce an 'nvim' command."
}

$installedNvimVersion = Get-NeovimCommandVersion
if ($null -eq $installedNvimVersion) {
    throw "Neovim install completed, but the version could not be determined from 'nvim --version'."
}

if ($installedNvimVersion -lt $MinimumNeovimVersion) {
    throw "Neovim $installedNvimVersion is too old for LazyVim. Require >= $MinimumNeovimVersion."
}

$nvimVersion = (& $nvimCommand.Source --version | Select-Object -First 1).Trim()
Write-Host "Neovim: $nvimVersion" -ForegroundColor Green

# --- 10. Neovim config junction ---
Write-Host "`n[10/10] Linking Neovim config..." -ForegroundColor Yellow

$nvimConfigPath = "$env:LOCALAPPDATA\nvim"
$nvimSourcePath = Join-Path $gnuFilesPath "nvim"
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

# --- Optional: LLVM/Clang toolchain ---
$isInteractive = [Environment]::UserInteractive -and -not ([Environment]::GetCommandLineArgs() -match '-NonInteractive')
if ($isInteractive) {
    $installLlvm = Read-Host "Install LLVM/Clang toolchain for C++ development? (y/N)"
} else {
    Write-Host "Non-interactive session - skipping LLVM prompt (default: N)." -ForegroundColor DarkGray
    $installLlvm = 'N'
}
if ($installLlvm -eq 'y' -or $installLlvm -eq 'Y') {
    Write-Host "Installing LLVM..." -ForegroundColor Yellow
    $llvmInstalled = Invoke-WingetInstall -Id "LLVM.LLVM" -UserScope
    if ($llvmInstalled) {
        Add-UserPathOnce "$env:ProgramFiles\LLVM\bin"
        $clangCommand = Wait-ForCommandInfo -Names @("clang") -CandidatePaths (
            Get-DirectoryCommandCandidatePaths -Directories @("$env:ProgramFiles\LLVM\bin") -BinaryNames @("clang")
        ) -TimeoutSeconds 15
        if ($clangCommand) {
            $llvmVersion = (& $clangCommand.Source --version | Select-Object -First 1).Trim()
            Write-Host "LLVM: $llvmVersion" -ForegroundColor Green
        } else {
            Write-Host "LLVM installed - restart PowerShell for clang/clang++ to appear on PATH." -ForegroundColor Yellow
        }
    } else {
        Write-Host "LLVM install failed (exit code $LASTEXITCODE). You can install manually: winget install LLVM.LLVM" -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping LLVM (clangd LSP is still available via Mason in Neovim)." -ForegroundColor DarkGray
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
