# Detection Lab
CircleCI: [![CircleCI](https://circleci.com/gh/clong/DetectionLab/tree/master.svg?style=svg)](https://circleci.com/gh/clong/DetectionLab/tree/master)

## Purpose
This lab has been designed with defenders in mind. Its primary purpose is to allow the user to quickly build a Windows domain that comes pre-loaded with security tooling and some best practices when it comes to system logging configurations. It can easily be modified to fit most needs or expanded to include additional hosts.

Read more about Detection Lab on Medium here: https://medium.com/@clong/introducing-detection-lab-61db34bed6ae

NOTE: This lab has not been hardened in any way and runs with default vagrant credentials. Please do not connect or bridge it to any networks you care about. This lab is deliberately designed to be insecure; the primary purpose of it is to provide visibility and introspection into each host.

## Primary Lab Features:
* Microsoft Advanced Threat Analytics (https://www.microsoft.com/en-us/cloud-platform/advanced-threat-analytics) is installed on the WEF machine, with the lightweight ATA gateway installed on the DC
* Splunk forwarders are pre-installed and all indexes are pre-created. Technology add-ons for Windows are also preconfigured.
* A custom Windows auditing configuration is set via GPO to include command line process auditing and additional OS-level logging
* [Palantir's Windows Event Forwarding](http://github.com/palantir/windows-event-forwarding)  subscriptions and custom channels are implemented
* Powershell transcript logging is enabled. All logs are saved to `\\wef\pslogs`
* osquery comes installed on each host and is pre-configured to connect to a [Fleet](https://kolide.co/fleet) server via TLS. Fleet is preconfigured with the configuration from [Palantir's osquery Configuration](https://github.com/palantir/osquery-configuration)
* Sysmon is installed and configured using SwiftOnSecurity’s open-sourced configuration
* Mitre's [Caldera](https://github.com/mitre/caldera) server is built on the logger host and the Caldera agent gets pre-installed on all Windows hosts
* All autostart items are logged to Windows Event Logs via [AutorunsToWinEventLog](https://github.com/palantir/windows-event-forwarding/tree/master/AutorunsToWinEventLog)
* SMBv1 Auditing is enabled
 test

## Requirements
* 55GB+ of free disk space
* 16GB+ of RAM
* Packer 1.0.0 or newer
* Vagrant 1.9.2 or newer
* Virtualbox or VMWare Fusion/Workstation

This lab has been successfully tested on:

OS | Vagrant | Packer | Provider
---|---------|--------|-----------
OSX 10.12.4 | 1.9.3 | 1.0.0 | Virtualbox (5.1.14)
OSX 10.12.6 | 2.0.1 | 1.1.2 | Virtualbox (5.1.30)
OSX 10.12.4 | 1.9.2 | 1.0.0 | VMWare Fusion (8.5.6)
OSX 10.12.5 | 1.9.3 | 1.0.0 | VMWare Fusion (8.5.8)
OSX 10.12.6 | 2.0.1 | 1.1.3 | VMWare Fusion (8.5.9)
OSX 10.12.6 | 2.0.1 | 1.1.3 | VMWare Fusion (8.5.10)
OSX 10.12.6 | 2.0.3 | 1.2.1 | VMWare Fusion (10.1.1)
Ubuntu 16.04 | 2.0.1 | 1.1.3 | Virtualbox (5.1)
Ubuntu 16.04 | 2.0.2 | N/A | Virtualbox (5.2)
Ubuntu 16.04 | 2.0.3 | 1.2.1 | Virtualbox (5.2)


**Known Bad Versions:**
* Packer 1.1.2 will fail to build VMWare-ISOs correctly due to [this issue](https://github.com/hashicorp/packer/issues/5622).

---

## Quickstart
DetectionLab now contains build scripts for \*NIX, MacOS, and Windows users!

There is a single build script that supports 3 different options:
- `./build.sh <virtualbox|vmware_fusion>` - Builds the entire lab from scratch. Takes 3-5 hours depending on hardware resources and bandwidth
- `./build.sh <virtualbox|vmware_fusion> --vagrant-only` - Downloads pre-built Packer boxes from https://detectionlab.network and builds the lab from those boxes. This option is recommended if you have more bandwidth than time or are having trouble building boxes.
- `./build.sh <virtualbox|vmware_fusion> --packer-only` - This option only builds the Packer boxes and will not use Vagrant to start up the lab.

Windows users will want to use the following script:
- `./build.ps1 -ProviderName=<virtualbox|vmware_workstation>` - Builds the entire lab from scratch. Takes 3-5 hours depending on hardware resources and bandwidth
- `./build.ps1 -ProviderName=<virtualbox|vmware_workstation> -VagrantOnly` - Downloads pre-built Packer boxes from https://detectionlab.network and builds the lab from those boxes. This option is recommended if you have more bandwidth than time or are having trouble building boxes.

---

## Building DetectionLab from Scratch
1. Determine which Vagrant provider you want to use.
  * Note: Virtualbox is free, the [VMWare vagrant plugin](https://www.vagrantup.com/vmware/#buy-now) is $80.

  **NOTE:** If you'd like to save time, you can skip the building of the Packer boxes and download the boxes directly from https://detectionlab.network and put them into the `Boxes` directory:

Provider | Box  | URL | MD5 | Size
------------|-----|-----|----|----
Virtualbox |Windows 2016 | https://www.detectionlab.network/windows_2016_virtualbox.box | b59cf23dfbcdb63c0dc8a98fbc564451 | 6.4GB
Virtualbox | Windows 10 | https://www.detectionlab.network/windows_10_virtualbox.box | d6304f01caa553a18022ea7b5a73ad0d | 5.8GB
VMware | Windows 2016 | https://www.detectionlab.network/windows_2016_vmware.box | 249fc2472849582d8b736cdabaf0eceb | 6.7GB
VMware | Windows 10 | https://www.detectionlab.network/windows_10_vmware.box | 4355e9758a862a6f6349e31fdc3a6078 | 6.0GB

If you choose to download the boxes, you may skip steps 2 and 3. If you don't trust pre-built boxes, I recommend following steps 2 and 3 to build them on your machine.


2. `cd` to the Packer directory and build the Windows 10 and Windows Server 2016 boxes using the commands below. Each build will take about 1 hour. As far as I know, you can only build one box at a time.

```
$ cd detectionlab/Packer
$ packer build --only=[vmware|virtualbox]-iso windows_10.json
$ packer build --only=[vmware|virtualbox]-iso windows_2016.json
```

3. Once both boxes have built successfully, move the resulting boxes (.box files) in the Packer folder to the Boxes folder:

    `mv *.box ../Boxes`

4. cd into the Vagrant directory: `cd ../Vagrant`
5. Install the Vagrant-Reload plugin: `vagrant plugin install vagrant-reload`

6. Ensure you are in the Vagrant folrder and run `vagrant up`. This command will do the following:
  * Provision the logger host. This host will run the [Fleet](https://kolide.co/fleet) osquery manager and a fully featured pre-configured Splunk instance.
  * Provision the DC host and configure it as a Domain Controller
  * Provision the WEF host and configure it as a Windows Event Collector in the Servers OU
  * Provision the Win10 host and configure it as a computer in the Workstations OU

7. Navigate to https://192.168.38.5:8000 in a browser to access the Splunk instance on logger. Default credentials are admin:changeme (you will have the option to change them on the next screen)
8. Navigate to https://192.168.38.5:8412 in a browser to access the Fleet server on logger. Default credentials are admin:admin123#. Query packs are pre-configured with queries from [palantir/osquery-configuration](https://github.com/palantir/osquery-configuration).
9. Navigate to https://192.168.38.5:8888 in a browser to access the Caldera server on logger. Default credentials are admin:caldera.

## Basic Vagrant Usage
Vagrant commands must be run from the "Vagrant" folder.

* Bring up all Detection Lab hosts: `vagrant up` (optional `--provider=[virtualbox|vmware_fusion|vmware_workstation]`)
* Bring up a specific host: `vagrant up <hostname>`
* Restart a specific host: `vagrant reload <hostname>`
* Restart a specific host and re-run the provision process: `vagrant reload <hostname> --provision`
* Destroy a specific host `vagrant destroy <hostname>`
* Destroy the entire Detection Lab environment: `vagrant destroy` (Adding `-f` forces it without a prompt)
* SSH into a host (only works with Logger): `vagrant ssh logger`
* Check the status of each host: `vagrant status`
* Suspend the lab environment: `vagrant suspend`
* Resume the lab environment: `vagrant resume`

---

## Lab Information
* Domain Name: windomain.local
* Admininstrator login: vagrant:vagrant
* Fleet login: https://192.168.38.5:8412 - admin:admin123#
* Splunk login: https://192.168.38.5:8000 - admin:changeme
* Caldera login: https://192.168.38.5:8888 - admin:caldera
* MS ATA login: https://192.168.38.3 - wef\vagrant:vagrant

## Lab Hosts
* DC - Windows 2016 Domain Controller
  * WEF Server Configuration GPO
  * Powershell logging GPO
  * Enhanced Windows Auditing policy GPO
  * Sysmon
  * osquery
  * Splunk Universal Forwarder (Forwards Sysmon & osquery)
  * Sysinternals Tools
  * Microsft Advanced Threat Analytics Lightweight Gateway
* WEF - Windows 2016 Server
  * Microsoft Advanced Threat Analytics
  * Windows Event Collector
  * Windows Event Subscription Creation
  * Powershell transcription logging share
  * Sysmon
  * osquery
  * Splunk Universal Forwarder (Forwards WinEventLog & Powershell & Sysmon & osquery)
  * Sysinternals tools
* Win10 - Windows 10 Workstation
  * Simulates employee workstation
  * Sysmon
  * osquery
  * Splunk Universal Forwarder (Forwards Sysmon & osquery)
  * Sysinternals Tools
* Logger - Ubuntu 16.04
  * Splunk Enterprise
  * Fleet osquery Manager
  * Mitre's Caldera Server

## Splunk Indexes
Index Name | Description
-----------|------------
osquery | osquery/Fleet result logs
osquery-status | osquery/fleet INFO/WARN/ERROR logs
powershell | Powershell transcription logs
sysmon | Logs from the Sysmon service
wineventlog | Windows Event Logs

## Installed Tools on Windows
  * Sysmon
  * osquery
  * AutorunsToWinEventLog
  * Caldera Agent
  * Process Monitor
  * Process Explorer
  * PsExec
  * TCPView
  * Google Chrome
  * Atom editor
  * WinRar
  * Mimikatz

## Applied GPOs
* [Custom Event Channel Permissions](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Custom%20Event%20Channel%20Permissions.htm)
* [Default Domain Controllers Policy](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Default%20Domain%20Controllers%20Policy.htm)
* [Default Domain Policy](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Default%20Domain%20Policy.htm)
* [Domain Controllers Enhanced Auditing Policy](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Domain%20Controllers%20Enhanced%20Auditing%20Policy.htm)
* [Powershell Logging](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Powershell%20Logging.htm)
* [Servers Enhanced Auditing Policy](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Servers%20Enhanced%20Auditing%20Policy.htm)
* [Windows Event Forwarding Server](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Windows%20Event%20Forwarding%20Server.htm)
* [Workstations Enhanced Auditing Policy](https://rawgit.com/clong/DetectionLab/master/Vagrant/resources/GPO/reports/Workstations%20Enhanced%20Auditing%20Policy.htm)

## Known Issues and Workarounds

Vagrant has been particularly flaky with VMWare and I encountered many issues while testing. However, most of the issues are easily resolved.

---

**Issue:** Vagrant reports: `Message: HTTPClient::KeepAliveDisconnected:` while provisioning.                     
**Workaround:** Run `$ vagrant reload <hostname> --provision`

---

**Issue:** `Vagrant timed out while attempting to connect via WinRM` after Win10 host joins the domain.                        
**Workaround** Documented in [#21](https://github.com/clong/detectionlab/issues/21). Just run `$ vagrant reload win10 --provision`

---

**Issue:** Vagrant is unable to forward a port for you   
**Workaround:** Documented in [#11](https://github.com/clong/detectionlab/issues/11). There are a few possibilities:
1. Try a `vagrant reload <hostname> --provision`. For whatever reason `vagrant up` doesn't fix conflicts but reload does.
2. Check if something is legitimately occupying the port via `sudo lsof -n -iTCP:<port_number>`
3. Follow the instructions from this comment: https://github.com/hashicorp/vagrant/issues/8130#issuecomment-272963103

---

**Issue:** Fleet server becomes unreachable after VM is suspended and resumed

**Workaround:** Documented in [#22](https://github.com/clong/detectionlab/issues/22). The following commands should make it reachable without deleting data:
```
$ docker stop $(docker ps -aq)
$ service docker restart
$ cd /home/vagrant/kolide-quickstart
$ docker-compose up -d
```

---

**Issue:** Your primary hard drive doesn't have enough space for DetectionLab

**Workaround:** Documented in [#48](https://github.com/clong/detectionlab/issues/48). You can change the default location for Vagrant by using the [VAGRANT_HOME](https://www.vagrantup.com/docs/other/environmental-variables.html#vagrant_home) environment variable.

---

## Contributing
Please do all of your development in a feature branch on your own fork of detectionlab.
Requests for tools and features will be reviewed on a case by case basis, but I will always accept fixes and improvements.

## Credits/Resources
A sizable percentage of this code was borrowed and adapted from [Stefan Scherer](https://twitter.com/stefscherer)'s [packer-windows](https://github.com/StefanScherer/packer-windows) and [adfs2](https://github.com/StefanScherer/adfs2) Github repos. A huge thanks to him for building the foundation that allowed me to design this lab environment.

# Acknowledgements 
* [Microsoft Advanced Threat Analytics](https://www.microsoft.com/en-us/cloud-platform/advanced-threat-analytics)
* [Splunk](https://www.splunk.com)
* [osquery](https://osquery.io)
* [Fleet](https://kolide.co/fleet)
* [Caldera](https://github.com/mitre/caldera)
* [Windows Event Forwarding for Network Defense](https://medium.com/@palantir/windows-event-forwarding-for-network-defense-cb208d5ff86f)
* [palantir/windows-event-forwarding](http://github.com/palantir/windows-event-forwarding)
* [osquery Across the Enterprise](https://medium.com/@palantir/osquery-across-the-enterprise-3c3c9d13ec55)
* [palantir/osquery-configuration](https://github.com/palantir/osquery-configuration)
* [Configure Event Log Forwarding in Windows Server 2012 R2](https://www.petri.com/configure-event-log-forwarding-windows-server-2012-r2)
* [Monitoring what matters — Windows Event Forwarding for everyone](https://blogs.technet.microsoft.com/jepayne/2015/11/23/monitoring-what-matters-windows-event-forwarding-for-everyone-even-if-you-already-have-a-siem/)
* [Use Windows Event Forwarding to help with intrusion detection](https://technet.microsoft.com/en-us/itpro/windows/keep-secure/use-windows-event-forwarding-to-assist-in-instrusion-detection)
* [The Windows Event Forwarding Survival Guide](https://hackernoon.com/the-windows-event-forwarding-survival-guide-2010db7a68c4)
* [PowerShell ♥ the Blue Team](https://blogs.msdn.microsoft.com/powershell/2015/06/09/powershell-the-blue-team/)
* [Autoruns](https://www.microsoftpressstore.com/articles/article.aspx?p=2762082)
* [TA-microsoft-sysmon](https://github.com/splunk/TA-microsoft-sysmon)
* [SwiftOnSecurity - Sysmon Config](https://github.com/SwiftOnSecurity/sysmon-config)
