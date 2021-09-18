# Purpose: Downloads and installs Microsoft Exchange

$username = 'windomain.local\administrator'
$password = 'vagrant'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword
$exchangeFolder = "C:\exchange2016"
$exchangeISOPath = "C:\exchange2016\ExchangeServer2016-x64-cu12.iso"
$exchangeDownloadUrl = "https://download.microsoft.com/download/2/5/8/258D30CF-CA4C-433A-A618-FB7E6BCC4EEE/ExchangeServer2016-x64-cu12.iso"

If (Test-Path c:\exchange_prereqs_complete.txt) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] It appears the Exchange prerequisites have been installed already. Continuing installation..."
}
Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Exchange prerequisites don't appear to be installed. Manual intervention required :["
  exit 0
}

If (-not (Test-Path $exchangeFolder)) {
  mkdir $exchangeFolder
}
Set-Location -Path $exchangeFolder

# Download Exchange ISO and mount it
$ProgressPreference = 'SilentlyContinue'
If (-not (Test-Path $exchangeISOPath)) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Exchange ISO not found at $exchangeISOPath..."
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] Downloading the Exchange 2016 ISO..."
  Invoke-WebRequest -Uri "$exchangeDownloadUrl" -OutFile $exchangeISOPath
}
Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) [+] The Exchange ISO was already downloaded. Moving On."
}

If (!(Get-Volume | Where DriveType -eq "CD-ROM").filesystemlabel -eq "EXCHANGESERVER2016-X64-CU12") {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The Exchange ISO doesn't appear to be mounted."
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Mounting the Exchange 2016 ISO..."
  Try {
    $Mount = Mount-DiskImage -ImagePath $exchangeISOPath -StorageType ISO -Access ReadOnly -PassThru
    $Volume = $Mount | Get-Volume
  }
  Catch {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Something went wrong mounting the Exchange ISO"
    Write-Host $_.Exception | Format-List -force
    Write-Host $Vol
    exit 1
  }
}
Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The exchange ISO appears to already be mounted"
  $Volume = (Get-Volume | Where FileSystemLabel -eq "EXCHANGESERVER2016-X64-CU12")
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Beginning installation of Exchange 2016..."
Try {
  $Install1 = Start-Process -FilePath ($Volume.DriveLetter + ":\setup") -ArgumentList "/PrepareSchema", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait -RedirectStandardError $exchangeFolder/step1stderr.txt -RedirectStandardOutput $exchangeFolder/step1stdout.txt -PassThru > $exchangeFolder/step1.txt
  Write-Host $Install1.ExitCode
  $Install2 = Start-Process -FilePath ($Volume.DriveLetter + ":\setup") -ArgumentList "/PrepareAD", "/OrganizationName: DetectionLab", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait -RedirectStandardError $exchangeFolder/step2stderr.txt -RedirectStandardOutput $exchangeFolder/step2stdout.txt -PassThru > $exchangeFolder/step2.txt
  Write-Host $Install2.ExitCode
  $Install3 = Start-Process -FilePath ($Volume.DriveLetter + ":\setup") -ArgumentList "/Mode:Install", "/Role:Mailbox", "/IAcceptExchangeServerLicenseTerms" -Credential $credential -Wait -RedirectStandardError $exchangeFolder/step3stderr.txt -RedirectStandardOutput $exchangeFolder/step3stdout.txt -PassThru > $exchangeFolder/step3.txt
  Write-Host $Install3.ExitCode
}
Catch {
  Write-Host $_.Exception | Format-List -force
}
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Exchange installation complete!"


# Verify that Exchange actually installed properly
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Sleeping for 2 minutes..."
Start-Sleep 120

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Ensuring Exchange is running..."
if ((Get-Service -Name "MSExchangeFrontendTransport").Status -eq "Running") {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Exchange was installed successfully!"
}
Else {
  "$('[{0:HH:mm}]' -f (Get-Date)) Exchange doesn't appear to be running. Manual intervention required :["
}


Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Doing cleanup now"
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Unmounting disk and cleaning up"
Dismount-DiskImage -ImagePath $exchangeISOPath
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Deleting the ISO to save space"
Remove-Item -Path $exchangeISOPath
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Shrinking the disk..."
c:\Tools\Sysinternals\sdelete64.exe c: -z
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Cleanup complete! All done."

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Exchange installed. Rebooting..."
