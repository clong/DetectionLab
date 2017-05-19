# Detection Lab

# Overview
This lab has been designed with defenders in mind. Its primary purpose is to simulate a Windows domain that comes pre-loaded with security tooling and some best practices when it comes to system logging configurations.

## Lab Hosts
* DC - Windows 2016 Domain Controller
  * WEF Server Configuration GPO
  * Powershell logging GPO
  * Enhanced Windows Auditing policy GPO
  * Sysmon
  * Osquery
  * Splunk Universal Forwarder (Forwards Sysmon/Osquery)
  * Sysinternals Tools
* WEF - Windows 2016 Server
  * Windows Event Collector
  * Windows Event Subscription Creation
  * Powershell transcription logging share
  * Sysmon
  * Osquery
  * Splunk Universal Forwarder (Forwards WinEventLog/Powershell/Sysmon/Osquery)
  * Sysinternals tools
* Win10 - Windows 10 Workstation
  * Simulates employee workstation
  * Sysmon
  * Osquery
  * Splunk Universal Forwarder (Forwards Sysmon/Osquery)
  * Sysinternals Tools
