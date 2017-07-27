#! /bin/bash

apt-get update
apt-get install -y jq whois build-essential git

# Check if Splunk is already installed
if [ -f "/opt/splunk/bin/splunk" ]
  then echo "Splunk is already installed"
else
  # Download Splunk
  wget --progress=bar:force -O splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb  'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=6.6.2&product=splunk&filename=splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb&wget=true'
  # Sometimes DNS resolution of splunk.com fails and I have no idea why. Ensure the file exists before continuing.
  if [ ! -e splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb ]; then
    # Retry the download.
    wget --progress=bar:force -O splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb  'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=6.6.2&product=splunk&filename=splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb&wget=true'
  fi
  dpkg -i splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb
  /opt/splunk/bin/splunk start --accept-license
  /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index osquery-status -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index powershell -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_483.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/add-on-for-microsoft-sysmon_600.tgz -auth 'admin:changeme'
  # Add a Splunk TCP input on port 9997
  echo -e "[splunktcp://9997]\nconnection_host = ip" > /opt/splunk/etc/apps/search/local/inputs.conf
  # Add props.conf and transforms.conf
  cp /vagrant/resources/splunk_server/props.conf /opt/splunk/etc/apps/search/local/
  cp /vagrant/resources/splunk_server/transforms.conf /opt/splunk/etc/apps/search/local/
  # Skip Splunk Tour and Change Password Dialog
  touch /opt/splunk/etc/.ui_login
  # Reboot Splunk to make changes take effect
  /opt/splunk/bin/splunk restart
  /opt/splunk/bin/splunk enable boot-start
fi
