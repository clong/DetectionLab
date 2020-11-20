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


Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading $title..."
# Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $downloadUrl -OutFile "c:\$title.iso"
$actualHash = (Get-FileHash -Algorithm SHA256 -Path "c:\$title.iso").Hash
If (-not ($actualHash -eq $fileHash)) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) $title.iso was not downloaded correctly: hash from downloaded file: $actualHash, should've been: $fileHash. Re-trying using BitsAdmin now..."
    Remove-Item -Path "c:\$title.iso" -Force
    bitsadmin /Transfer ATA $downloadUrl "c:\$title.iso"
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path "c:\$title.iso").Hash
    If (-not ($actualHash -eq $fileHash)) {
        Throw "$title.iso was not downloaded correctly after a retry: hash from downloaded file: $actualHash, should've been: $fileHash - Giving up."
    }
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Microsoft ATA sucessfully downloaded to c:\$title.iso !"