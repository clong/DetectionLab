#! /usr/bin/env bash

#Thanks to @MHaggis for this addition!
#More information on BOTSv3 can be found at https://github.com/splunk/botsv3

/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/base64_11.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/jellyfisher_010.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/palo-alto-networks-add-on-for-splunk_620.tgz  -auth 'admin:changeme'    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard_admin-master.zip  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard-master.zip  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sa-investigator-for-enterprise-security_200.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-apache-web-server_100.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-iis_101.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-ta-for-suricata_233.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/ssl-certificate-checker_32.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/website-monitoring_274.tgz  -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/amazon-guardduty-add-on-for-splunk_104.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/cisco-anyconnect-network-visibility-module-nvm-app-for-splunk_20187.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/code42-for-splunk_3012.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/decrypt_20.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/microsoft-365-app-for-splunk_301.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/microsoft-azure-add-on-for-splunk_202.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/osquery-app-for-splunk_060.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-amazon-web-services_500.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-cisco-asa_340.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-cloud-services_401.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-office-365_201.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-sysmon_1062.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-windows_700.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-symantec-endpoint-protection_301.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-tenable_514.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-unix-and-linux_701.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-common-information-model-cim_4150.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-es-content-update_1052.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-security-essentials_306.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-stream_720.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/ta-for-code42-app-for-splunk_3012.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/url-toolbox_18.tgz -auth 'admin:changeme'
/opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/virustotal-workflow-actions-for-splunk_020.tgz -auth 'admin:changeme'

echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv3 Attack Only Dataset..."
wget --progress=bar:force -P /opt/ https://botsdataset.s3.amazonaws.com/botsv3/botsv3_data_set.tgz
echo "[$(date +%H:%M:%S)]: Download Complete."
echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
tar zxvf /opt/botsv3_data_set.tgz -C /opt/splunk/etc/apps/

echo "[$(date +%H:%M:%S)]: Restarting Splunk..."
/opt/splunk/bin/splunk restart

echo "BOTSv3 Installation complete!"
