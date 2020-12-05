# Purpose: Downloads and indexes the EVTX samples from https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES/ into Splunk

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Indexing EVTX Attack Samples into Splunk..."

# Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$inputsConf = "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\local\inputs.conf"

# Download and unzip a copy of EVTX Attack Samples
$evtxAttackDownloadUrl = "https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES/archive/master.zip"
$evtxAttackRepoPath = "C:\Users\vagrant\AppData\Local\Temp\evtxattack.zip"
If (-not (Test-Path "C:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master")) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading EVTX Attack Samples"
    Invoke-WebRequest -Uri "$evtxAttackDownloadUrl" -OutFile "$evtxAttackRepoPath"
    Expand-Archive -path "$evtxAttackRepoPath" -destinationpath 'c:\Tools\EVTX-ATTACK-SAMPLES' -Force
    # Add stanzas to Splunk inputs.conf to index the evtx files
    # Huge thanks to https://www.cloud-response.com/2019/07/importing-windows-event-log-files-into.html for showing how to do this!
    If (!(Select-String -Path $inputsConf -Pattern "evtx_attack_sample")) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Splunk inputs.conf has not yet been modified. Adding stanzas for these evtx files now..."
        Add-Content -Path "$inputsConf" -Value '
[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\AutomatedTestingTools\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Command and Control\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Credential Access\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Defense Evasion\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Discovery\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Execution\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Lateral Movement\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Other\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Persistence\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt

[monitor://c:\Tools\EVTX-ATTACK-SAMPLES\EVTX-ATTACK-SAMPLES-master\Privilege Escalation\*.evtx]
index = evtx_attack_samples
sourcetype = preprocess-winevt'
        # Restart the forwarder to pick up changes
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Restarting the Splunk Forwarder..."
        Try { 
          Restart-Service -Name SplunkForwarder -Force -ErrorAction Stop 
        } Catch {
          Start-Sleep 10
          Stop-Service -Name SplunkForwarder -Force
          Start-Service -Name SplunkForwarder
        }
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Done! Look in 'index=EVTX-ATTACK-SAMPLES' in Splunk to query these samples."
    }
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) EVTX attack samples were already installed. Moving On."
}
