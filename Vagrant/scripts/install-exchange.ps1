# Purpose: Downloads and installs Microsoft Exchange and its prerequisites

# README
# 1. Provide the WEF VM with 4GB+ of RAM
# 2. Run this script from an elevated powershell prompt to install pre-reqs, then reboot
# 3. Run this script again to download and begin installing exchange
# 4. You MUST manually close each exchange cmd.exe window after completion for installation to continue. 
#    This allows you to verify that each step in the installation process was successful
# 5. Once installation is successful, reboot once more. 

$exchangeFolder = "C:\exchange2016"
$exchangeISOPath = "C:\exchange2016\ExchangeServer2016-x64-cu12.iso"
$exchangeDownloadUrl = "https://download.microsoft.com/download/2/5/8/258D30CF-CA4C-433A-A618-FB7E6BCC4EEE/ExchangeServer2016-x64-cu12.iso"
$username = 'windomain.local\administrator'
$password = 'vagrant'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword
$dotNetInstallerUrl = 'https://download.microsoft.com/download/9/E/6/9E63300C-0941-4B45-A0EC-0008F96DD480/NDP471-KB4033342-x86-x64-AllOS-ENU.exe'
$dotNetInstallerPath = "$env:TEMP/NDP471-KB4033342-x86-x64-AllOS-ENU.exe"
$dotNetInstallLog = "$env:TEMP/dotnet_install_log.txt"
$cplusplusInstallerUrl = "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
$cplusplusInstallerPath = "$env:TEMP/vcredist_x64.exe"
$cplusplusLogPath = "$env:TEMP/cplusplus_install_log.txt"
$maxSleepTime = 900 
$physicalMemory = get-ciminstance -class "cim_physicalmemory" | % { $_.Capacity } | Select-Object -Last 1

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Attempting to install Microsoft exchange."
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Please note, you will have to reboot and re-run this script after the prerequisites have been installed."
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Failure to reboot will cause the Exchange installation to fail."

# Warn the user if less than 8GB of memory
If ($physicalMemory -lt 8000000000) {
    Write-Host "It is STRONGLY recommended that you provide this host with 8GB+ of memory before continuing or it is highly likely that it will run out of memory while installing Exchange."
    $ignore = Read-Host "Type 'ignore' to continue anyways, otherwise this script will exit."
    If ($ignore -ne "ignore") {
        Write-Host "Exiting."
    }
}

# Gotta temporarily re-enable these services
Set-Service TrustedInstaller -StartupType Automatic
Start-Service TrustedInstaller
Set-Service wuauserv -StartupType Automatic
Start-Service wuauserv

If (-not(Test-Path c:\exchange_prereqs_complete.txt)) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Beginning installation of prerequisites..."
    # Install Prerequisites 
    If (-not(choco list -lo | Where-object { $_.ToLower().StartsWith("ucma4".ToLower()) })) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing UCMA4 from Chocolatey..."
        choco install -y --limit-output --no-progress ucma4
    } Else {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) UCMA4 is already installed. Moving on..."
    }

    If ((Get-WindowsOptionalFeature -Online -FeatureName "RSAT-AD-Tools-Feature").State -ne "Enabled") {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing a bunch of items from Microsoft Optional Components..."
        Install-WindowsFeature `
            NET-Framework-45-Features,
            RPC-over-HTTP-proxy,
            RSAT-Clustering,
            RSAT-Clustering-CmdInterface,
            RSAT-Clustering-Mgmt,
            RSAT-Clustering-PowerShell,
            Web-Mgmt-Console,
            WAS-Process-Model,
            Web-Asp-Net45,
            Web-Basic-Auth,
            Web-Client-Auth,
            Web-Digest-Auth,
            Web-Dir-Browsing,
            Web-Dyn-Compression,
            Web-Http-Errors,
            Web-Http-Logging,
            Web-Http-Redirect,
            Web-Http-Tracing,
            Web-ISAPI-Ext,
            Web-ISAPI-Filter,
            Web-Lgcy-Mgmt-Console,
            Web-Metabase,
            Web-Mgmt-Console,
            Web-Mgmt-Service,
            Web-Net-Ext45,
            Web-Request-Monitor,
            Web-Server,
            Web-Stat-Compression,
            Web-Static-Content,
            Web-Windows-Auth,
            Web-WMI,
            Windows-Identity-Foundation,
            RSAT-ADDS
    } Else {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The Windows Feature prerequisites are already installed"
    }
    # Install .NET 4.7.1
    If (-not(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -le 461310) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing .NET 4.7.1..."
        $secondsPassed = 0
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading .NET 4.7.1..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "$dotNetInstallerUrl" -OutFile $dotNetInstallerPath
        Invoke-WebRequest -Uri "$cplusplusInstallerUrl" -OutFile $cplusplusInstallerPath
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Running .NET 4.7.1 installer..."
        . $dotNetInstallerPath /q /norestart /log $dotNetInstallLog -Wait
        while (-not(Test-Path $dotNetInstallLog)) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting for the .NET install log to appear..."
            If ($secondsPassed -eq 0) {
                Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) This usually takes about a minute or so."
            }
            Start-Sleep -Seconds 10
            $secondsPassed += 10
        }
        $secondsPassed = 0
        while (-not(Select-String -Path $dotNetInstallLog -Pattern "Final Result: Installation completed successfully") -and ($secondsPassed -lt $maxSleepTime)) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting for .NET installation to complete. $secondsPassed seconds elapsed..."
            If ($secondsPassed -eq 0) {
                Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) This usually takes about 2-3 minutes."
            }
            Start-Sleep -Seconds 10
            $secondsPassed += 10
        }
        If ($secondsPassed -ge $MaxSleepTime) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Timed out waiting for .NET installation to complete."
            exit 
        } Else {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) .NET installation successfully completed!"
        }
    }
    # Install C++ 2013
    If (-not(Get-WmiObject -Class Win32_Product | Where-Object Name -like "Microsoft Visual C++ 2013*")) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing .NET C++ 2013 Redistributable Package..."
        . $cplusplusInstallerPath /q /norestart /log $cplusplusLogPath -Wait
        while (-not(Test-Path $cplusplusLogPath)) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting for the C++ 2013 install log to appear..."
            Start-Sleep -Seconds 5
        }
        $secondsPassed = 0
        while (-not(Select-String -Path $cplusplusLogPath -Pattern "Exit code: 0x0, restarting: No") -and ($secondsPassed -lt $maxSleepTime)) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting for C++ 2013 installation to complete. $secondsPassed elapsed..."
            Start-Sleep -Seconds 3
            $secondsPassed += 3
        }
        If ($secondsPassed -ge $MaxSleepTime) {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Timed out waiting for C++ 2013 installation to complete."
            exit 
        } Else {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) C++ 2013 Redistributable installation successfully completed!"
        }
    }
    Stop-Service wuauserv
    Set-Service wuauserv -StartupType Disabled
    Set-Service TrustedInstaller -StartupType Disabled
    Stop-Service TrustedInstaller
    # Create a file so this script knows to skip pre-req installation upon next run.
    New-Item -Path "c:\exchange_prereqs_complete.txt" -ItemType "file"
    Write-Host "A reboot is required to continue installation of exchange."
    Write-Host "Rebooting in 3 seconds..."
    Start-Sleep -Seconds 3
    shutdown /r /t 1
    
    # $reboot = Read-Host "Would you like to reboot now? [y/n]"
    # If ($reboot -eq "y") {
    #     Write-Host "Rebooting in 3 seconds..."
    #     Start-Sleep -Seconds 3
    #     shutdown /r /t 1
    #     exit
    # } Else {
    #     Write-Host "Okay, exiting."
    #     exit
    # }
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) It appears the Exchange prerequisites have been installed already. Continuing installation..."
}

If (-not (Test-Path $exchangeFolder)) {
    mkdir $exchangeFolder
}
Set-Location -Path $exchangeFolder


# Download Exchange ISO and mount it
$ProgressPreference = 'SilentlyContinue'
If (-not (Test-Path $exchangeISOPath)) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading the Exchange 2016 ISO..."
    Invoke-WebRequest -Uri "$exchangeDownloadUrl" -OutFile $exchangeISOPath
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The Exchange ISO was already downloaded. Moving On."
}
If (-not (Test-Path "E:\Setup.EXE")) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Mounting the Exchange 2016 ISO..."
    if (Mount-DiskImage -ImagePath $exchangeISOPath) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) ISO mounted successfully."
    }
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The Exchange ISO was already mounted. Moving On."
}

###################################
##      DEBUGGING STUFF          ##
###################################
## Probably a good idea to add some code to see if this script is being run manually or by ansible or not
## Or maybe just split this into two separate scripts - prereq install + exchange install
# (Get-CimInstance win32_process -Filter "ProcessID=$PID" | ? { $_.processname -eq "pwsh.exe" }) | select commandline
# https://stackoverflow.com/questions/9738535/powershell-test-for-noninteractive-mode

<# If (Test-Path "E:\Setup.exe") {
    Start-Process cmd.exe -ArgumentList "/k", "e:\setup.exe", "/PrepareSchema", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait
    Start-Process cmd.exe -ArgumentList "/k", "e:\setup.exe", "/PrepareAD", "/OrganizationName: DetectionLab", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait
    Start-Process cmd.exe -ArgumentList "/k", "e:\setup.exe", "/Mode:Install", "/Role:Mailbox", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait
}
Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Something went wrong downloading or mounting the ISO..."
}
 #>

