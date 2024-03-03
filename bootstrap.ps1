# Powershell, enable virtualization and WSL on local machine. Reboot, and continue with the rest of the setup.
workflow New-ComputerSetup {
    # Install Winget
    # get latest download url
    $URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $URL = (Invoke-WebRequest -Uri $URL).Content | ConvertFrom-Json |
            Select-Object -ExpandProperty "assets" |
            Where-Object "browser_download_url" -Match '.msixbundle' |
            Select-Object -ExpandProperty "browser_download_url"

    # download
    Invoke-WebRequest -Uri $URL -OutFile "Setup.msix" -UseBasicParsing

    # install
    Add-AppxPackage -Path "Setup.msix"

    # delete file
    Remove-Item "Setup.msix"

    # Install Nerd Fonts
    $FontName = 'Ubuntu'
    $NerdFontsURI = 'https://github.com/ryanoasis/nerd-fonts/releases'

    $WebResponse = Invoke-WebRequest -Uri "$NerdFontsURI/latest" -MaximumRedirection 0 -ErrorAction SilentlyContinue

    $LatestVersion = Split-Path -Path $WebResponse.Headers['Location'] -Leaf

    Invoke-WebRequest -Uri "$NerdFontsURI/download/$LatestVersion/$FontName.zip" -OutFile "$FontName.zip"

    Expand-Archive -Path "$FontName.zip"

    $ShellApplication = New-Object -ComObject shell.application
    $Fonts = $ShellApplication.NameSpace(0x14)

    Get-ChildItem -Path ".\$FontName" -Include '*.ttf' -Recurse | ForEach-Object -Process {
        $Fonts.CopyHere($_.FullName)
    }
    
     # Enable Hyper-V Virtualization and WSL
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform, Microsoft-Windows-Subsystem-Linux
    Restart-Computer -Wait

    # Install winget packages (dockerdesktop, vscode, git, windows terminal, oh-my-posh)
    winget install -e --id Git.Git
    winget install -e --id Microsoft.WindowsTerminal
    winget install -e --id Docker.DockerDesktop
    winget install -e --id Microsoft.VisualStudioCode
    winget install JanDeDobbeleer.OhMyPosh -s winget
    Restart-Computer -Wait

    # Install Ubuntu WSL2 distro
    winget install -e --id Canonical.Ubuntu.2204
    New-Item -Path $PROFILE -Type File -Force
    Add-Content -Path $PROFILE -Value "oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin.omp.json' | Invoke-Expression"
}

$AtStartup = New-JobTrigger -AtStartup
Register-ScheduledJob -Name ResumeWorkflow -Trigger $AtStartup -ScriptBlock {Import-Module PSWorkflow; Get-Job ComputerSetup -State Suspended | Resume-Job}

New-ComputerSetup -JobName ComputerSetup

Import-Module PSWorkflow
# Unregister scheduled job if completed
$Job = Get-Job -Name ComputerSetup
$JobStatus = $Job.State
if ( $JobStatus -eq "Completed")
{
    Unregister-ScheduledJob -Name ResumeWorkflow
}