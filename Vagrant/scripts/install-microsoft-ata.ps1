# Purpose: Downloads, installs and configures Microsft ATA 1.9
$title = "Microsoft ATA 1.9"
$downloadUrl = "http://download.microsoft.com/download/4/9/1/491394D1-3F28-4261-ABC6-C836A301290E/ATA1.9.iso"
$fileHash = "DC1070A9E8F84E75198A920A2E00DDC3CA8D12745AF64F6B161892D9F3975857" # Use Get-FileHash on a correct downloaded file to get the hash

# Enable web requests to endpoints with invalid SSL certs (like self-signed certs)
If (-not("SSLValidator" -as [type])) {
    add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class SSLValidator {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }

    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(SSLValidator.ReturnTrue);
    }
}
"@
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLValidator]::GetDelegate()

If (-not (Test-Path "C:\Program Files\Microsoft Advanced Threat Analytics\Center"))
{
    $download = $false
    If (-not (Test-Path "c:\$title.iso"))
    {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) $title.iso doesn't exist yet, downloading..."
        $download = $true
    }
    Else
    {
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path "c:\$title.iso").Hash
        If (-not ($actualHash -eq $fileHash))
        {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) $title.iso exists, but the hash did not validate successfully. Downloading a new copy..."
            $download = $true
        }
    }
    If ($download -eq $true)
    {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading $title..."
        # Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile "c:\$title.iso"
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path "c:\$title.iso").Hash
        If (-not ($actualHash -eq $fileHash))
        {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) $title.iso was not downloaded correctly: hash from downloaded file: $actualHash, should've been: $fileHash. Re-trying using BitsAdmin now..."
            Remove-Item -Path "c:\$title.iso" -Force
            bitsadmin /Transfer ATA $downloadUrl "c:\$title.iso"
            $actualHash = (Get-FileHash -Algorithm SHA256 -Path "c:\$title.iso").Hash
            If (-not ($actualHash -eq $fileHash))
            {
                Throw "$title.iso was not downloaded correctly after a retry: hash from downloaded file: $actualHash, should've been: $fileHash - Giving up."
            }
        }
    }
    $Mount = Mount-DiskImage -ImagePath "c:\$title.iso" -StorageType ISO -Access ReadOnly -PassThru
    $Volume = $Mount | Get-Volume
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing $title"
    $Install = Start-Process -Wait -FilePath ($Volume.DriveLetter + ":\Microsoft ATA Center Setup.exe") -ArgumentList "/q --LicenseAccepted NetFrameworkCommandLineArguments=`"/q`" --EnableMicrosoftUpdate" -PassThru
    $Install
    $Mount | Dismount-DiskImage -Confirm:$false
    $body = get-content "C:\vagrant\resources\microsoft_ata\microsoft-ata-config.json"

    $req = [System.Net.WebRequest]::CreateHttp("https://wef")
    Try {
        $req.GetResponse()
    }
    Catch {
        # we don't care about errors here, we just want to get the cert ;)
    }
    $ThumbPrint = $req.ServicePoint.Certificate.GetCertHashString()
    $body = $body -replace "{{THUMBPRINT}}", $ThumbPrint

    Invoke-RestMethod -uri https://localhost/api/management/systemProfiles/center -body $body -Method Post -UseBasicParsing -UseDefaultCredentials -ContentType "application/json"
}

Start-Sleep -Seconds 60

Invoke-Command -computername dc -Credential (new-object pscredential("windomain\vagrant", (ConvertTo-SecureString -AsPlainText -Force -String "vagrant"))) -ScriptBlock {

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Installing the ATA Lightweight gateway on DC..."

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Adding wef.windomain.local to hosts file..."
    Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.56.103    wef.windomain.local'

    # Enable web requests to endpoints with invalid SSL certs (like self-signed certs)
    If (-not("SSLValidator" -as [type])) {
        add-type -TypeDefinition @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public static class SSLValidator {
        public static bool ReturnTrue(object sender,
            X509Certificate certificate,
            X509Chain chain,
            SslPolicyErrors sslPolicyErrors) { return true; }
        public static RemoteCertificateValidationCallback GetDelegate() {
            return new RemoteCertificateValidationCallback(SSLValidator.ReturnTrue);
        }
    }
"@
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLValidator]::GetDelegate()

    If (-not (Test-Path "$env:temp\gatewaysetup.zip")) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Downloading ATA Lightweight Gateway from WEF now..."
        # Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -uri https://wef/api/management/softwareUpdates/gateways/deploymentPackage -UseBasicParsing -OutFile "$env:temp\gatewaysetup.zip" -Credential (new-object pscredential("wef\vagrant", (convertto-securestring -AsPlainText -Force -String "vagrant")))
        Expand-Archive -Path "$env:temp\gatewaysetup.zip" -DestinationPath "$env:temp\gatewaysetup" -Force
    }
    Else {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Microsoft Gateway has already been already downloaded. Moving On."
    }
    If (-not (Test-Path "C:\Program Files\Microsoft Advanced Threat Analytics")) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Attempting to install Microsoft ATA... "
        Set-Location "$env:temp\gatewaysetup"
        Try {
            Start-Process -Wait -FilePath ".\Microsoft ATA Gateway Setup.exe" -ArgumentList "/q NetFrameworkCommandLineArguments=`"/q`" ConsoleAccountName=`"wef\vagrant`" ConsoleAccountPassword=`"vagrant`""
        } Catch { 
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Something went wrong attempting to install the Gateway on DC. Aborting installation."
            Exit 1
        }
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] ATA Gateway installation complete!"
    }
    Else {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] The Microsoft ATA Gateway was already installed. Moving On."
        Exit 0
    }
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Ensuring the ATA Gateway service exists..."
    Try {
        Get-Service "ATAGateway" -ErrorAction Stop
    } Catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Unable to find the ATAGateway service. Installation must have failed. Exiting."
        Exit 1
    }

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Waiting for the ATA Gateway service to start..."
    (Get-Service ATAGateway).WaitForStatus('Running', '00:10:00')
    If ((Get-Service "ATAGateway").Status -ne "Running") {
        Throw "ATA Gateway service failed to start on DC"
    }
    # Disable invalid web requests to endpoints with invalid SSL certs again
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
}

# Set the DC as the domain synchronizer
$config = Invoke-RestMethod -Uri "https://localhost/api/management/systemProfiles/gateways" -UseDefaultCredentials -UseBasicParsing
$config[0].Configuration.DirectoryServicesResolverConfiguration.UpdateDirectoryEntityChangesConfiguration.IsEnabled = $true

Invoke-RestMethod -Uri "https://localhost/api/management/systemProfiles/gateways/$($config[0].Id)" -UseDefaultCredentials -UseBasicParsing -Method Post -ContentType "application/json" -Body ($config[0] | convertto-json -depth 99)

# Disable invalid web requests to endpoints with invalid SSL certs again
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

If ((Get-Service -name "ATACenter").Status -ne "Running") {
    Throw "The Microsoft ATA service was unable to start."
}
