#! /bin/bash

apt-get update
apt-get install -y jq whois build-essential git

# Check if Splunk is already installed
if [ -f "/opt/splunk/bin/splunk" ] 
  then echo "Splunk is already installed"
else
  # Download Splunk
  wget -O /root/splunk-6.5.2-67571ef4b87d-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=6.5.2&product=splunk&filename=splunk-6.5.2-67571ef4b87d-linux-2.6-amd64.deb&wget=true'
  # Download the Windows TA
  # wget -O /root/windows_ta.tgz 'https://github.com/Centurion89/resources/raw/master/splunk-add-on-for-microsoft-windows_483.tgz'
  # Download the Sysmon TA
  # wget -O /root/sysmon_ta.tgz 'https://github.com/Centurion89/resources/raw/master/add-on-for-microsoft-sysmon_600.tgz'
  dpkg -i /root/splunk-6.5.2-67571ef4b87d-linux-2.6-amd64.deb
  /opt/splunk/bin/splunk start --accept-license
  /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
  /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
  #/opt/splunk/bin/splunk install app /root/windows_ta.tgz -auth 'admin:changeme'
  #/opt/splunk/bin/splunk install app /root/sysmon_ta.tgz -auth 'admin:changeme'
  echo '[splunktcp://9997]
connection_host = ip' > /opt/splunk/etc/apps/search/local/inputs.conf
  /opt/splunk/bin/splunk restart
fi

