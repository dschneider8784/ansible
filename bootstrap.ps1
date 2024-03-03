# Powershell, enable virtualization and WSL on local machine. Reboot, and continue with the rest of the setup.
workflow New-ComputerSetup {
    # Install Winget
    # get latest download url
    function InstallWinGet()
    {
        $hasPackageManager = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'

        if(!$hasPackageManager)
        {
            Add-AppxPackage -Path 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        
            $releases_url = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
        
            $releases = Invoke-RestMethod -uri $releases_url
            $latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith('msixbundle') } | Select -First 1
        
            "Installing winget from $($latestRelease.browser_download_url)"
            Add-AppxPackage -Path $latestRelease.browser_download_url
        }
    }

    # Install Nerd Fonts
    inlineScript {
        $FontName = 'Ubuntu'
        $NerdFontsURI = 'https://github.com/ryanoasis/nerd-fonts/releases'

        $WebResponse = Invoke-WebRequest -Uri "$NerdFontsURI/latest" -MaximumRedirection 0 -ErrorAction SilentlyContinue

        $LatestVersion = Split-Path -Path $WebResponse.Headers['Location'] -Leaf

        Invoke-WebRequest -Uri "$NerdFontsURI/download/$LatestVersion/$FontName.zip" -OutFile "$FontName.zip"

        Expand-Archive -Path -Force"$FontName.zip"

        $ShellApplication = New-Object -ComObject shell.application
        $Fonts = $ShellApplication.NameSpace(0x14)

        Get-ChildItem -Path ".\$FontName" -Include '*.ttf' -Recurse | ForEach-Object -Process {
            $Fonts.CopyHere($_.FullName)
        }
    }
    
     # Enable Hyper-V Virtualization and WSL
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform, Microsoft-Windows-Subsystem-Linux -NoRestart
    Restart-Computer -Wait

    # Install winget packages (dockerdesktop, vscode, git, windows terminal, oh-my-posh)
    winget install -e --id Git.Git
    winget install -e --id Microsoft.WindowsTerminal
    winget install -e --id Docker.DockerDesktop
    winget install -e --id Microsoft.VisualStudioCode
    winget install JanDeDobbeleer.OhMyPosh -s winget
    Restart-Computer -Wait

    #Setup WSL2
    wsl --set-default-version 2


    # Install Ubuntu WSL2 distro
    winget install -e --id Canonical.Ubuntu.2204
    New-Item -Path $PROFILE -Type File -Force
    Add-Content -Path $PROFILE -Value "oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin.omp.json' | Invoke-Expression"
}

$AtStartup = New-JobTrigger -AtStartup
New-ComputerSetup -JobName ComputerSetup
Register-ScheduledJob -Name ResumeWorkflow -Trigger $AtStartup -ScriptBlock {Import-Module PSWorkflow; Resume-Job -Name ComputerSetup}

Import-Module PSWorkflow
# Unregister scheduled job if completed
$Job = Get-Job -Name ComputerSetup
$JobStatus = $Job.State
if ( $JobStatus -eq "Completed")
{
    Unregister-ScheduledJob -Name ResumeWorkflow
}