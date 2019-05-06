# Purpose: Downloads, installs and configures Microsft ATA 1.9
$title = "Microsoft ATA 1.9"
$downloadUrl = "http://download.microsoft.com/download/4/9/1/491394D1-3F28-4261-ABC6-C836A301290E/ATA1.9.iso"
$fileHash = "DC1070A9E8F84E75198A920A2E00DDC3CA8D12745AF64F6B161892D9F3975857" # Use Get-FileHash on a correct downloaded file to get the hash

# Enable web requests to endpoints with invalid SSL certs (like self-signed certs)
if (-not("SSLValidator" -as [type])) {
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

if (-not (Test-Path "C:\Program Files\Microsoft Advanced Threat Analytics\Center"))
{
    $download = $false
    if (-not (Test-Path "$env:temp\$title.iso"))
    {
        Write-Host "$title.iso doesn't exist yet, downloading..."
        $download = $true
    }
    else
    {
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path "$env:temp\$title.iso").Hash
        If (-not ($actualHash -eq $fileHash))
        {
            Write-Host "$title.iso exists, but has wrong hash, downloading..."
            $download = $true
        }
    }
    if ($download -eq $true)
    {
        Write-Host "Downloading $title..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$env:temp\$title.iso"
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path "$env:temp\$title.iso").Hash
        If (-not ($actualHash -eq $fileHash))
        {
            throw "$title.iso was not downloaded correctly: hash from downloaded file: $actualHash, should've been: $fileHash"
        }
    }
    $Mount = Mount-DiskImage -ImagePath "$env:temp\$title.iso" -StorageType ISO -Access ReadOnly -PassThru
    $Volume = $Mount | Get-Volume
    Write-Host "Installing $title"
    $Install = Start-Process -Wait -FilePath ($Volume.DriveLetter + ":\Microsoft ATA Center Setup.exe") -ArgumentList "/q --LicenseAccepted NetFrameworkCommandLineArguments=`"/q`" --EnableMicrosoftUpdate" -PassThru
    $Install
    $Mount | Dismount-DiskImage -Confirm:$false
    $body = get-content "C:\vagrant\resources\microsoft_ata\microsoft-ata-config.json"

    $req = [System.Net.WebRequest]::CreateHttp("https://wef")
    try
    {
        $req.GetResponse()
    }
    catch
    {
        # we don't care about errors here, we just want to get the cert ;)
    }
    $ThumbPrint = $req.ServicePoint.Certificate.GetCertHashString()
    $body = $body -replace "{{THUMBPRINT}}", $ThumbPrint

    Invoke-RestMethod -uri https://localhost/api/management/systemProfiles/center -body $body -Method Post -UseBasicParsing -UseDefaultCredentials -ContentType "application/json"

}

Start-Sleep -Seconds 60

Invoke-Command -computername dc -Credential (new-object pscredential("windomain\vagrant",(ConvertTo-SecureString -AsPlainText -Force -String "vagrant"))) -ScriptBlock {

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [$env:computername] Installing ATA Lightweight gateway..."

    # Enable web requests to endpoints with invalid SSL certs (like self-signed certs)
    if (-not("SSLValidator" -as [type])) {
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

    If (-not (Test-Path "$env:temp\gatewaysetup.zip"))
    {
        Invoke-WebRequest -uri https://wef/api/management/softwareUpdates/gateways/deploymentPackage -UseBasicParsing -OutFile "$env:temp\gatewaysetup.zip" -Credential (new-object pscredential("wef\vagrant",(convertto-securestring -AsPlainText -Force -String "vagrant")))
        Expand-Archive -Path "$env:temp\gatewaysetup.zip" -DestinationPath "$env:temp\gatewaysetup" -Force
    }
    else
    {
        Write-Host "[$env:computername] Gateway setup already downloaded. Moving On."
    }
    if (-not (Test-Path "C:\Program Files\Microsoft Advanced Threat Analytics"))
    {
        Set-Location "$env:temp\gatewaysetup"
        Start-Process -Wait -FilePath ".\Microsoft ATA Gateway Setup.exe" -ArgumentList "/q NetFrameworkCommandLineArguments=`"/q`" ConsoleAccountName=`"wef\vagrant`" ConsoleAccountPassword=`"vagrant`""
    }
    else
    {
        Write-Host "[$env:computername] ATA Gateway already installed. Moving On."
    }
    Write-Host "Sleeping 5 minutes to allow ATA gateway to start up..."
    Start-Sleep -Seconds 300
    If ((Get-Service "ATAGateway").Status -ne "Running")
    {
        throw "ATA lightweight gateway not running"
    }
    # Disable invalid web requests to endpoints with invalid SSL certs again
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
}

# set dc as domain synchronizer
$config = Invoke-RestMethod -Uri "https://localhost/api/management/systemProfiles/gateways" -UseDefaultCredentials -UseBasicParsing
$config[0].Configuration.DirectoryServicesResolverConfiguration.UpdateDirectoryEntityChangesConfiguration.IsEnabled = $true

Invoke-RestMethod -Uri "https://localhost/api/management/systemProfiles/gateways/$($config[0].Id)" -UseDefaultCredentials -UseBasicParsing -Method Post -ContentType "application/json" -Body ($config[0] | convertto-json -depth 99)

# Disable invalid web requests to endpoints with invalid SSL certs again
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

If ((Get-Service -name "ATACenter").Status -ne "Running")
{
    throw "MS ATA service was not running."
}
