#! /usr/bin/env bash

    # Thanks to @MHaggis for this addition!
    # It is recommended to only uncomment the attack-only dataset comment block.
    # You may also link to the full dataset which is ~12GB if you prefer.
    # More information on BOTSv2 can be found at https://github.com/splunk/botsv2

    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/base64_11.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/jellyfisher_010.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/palo-alto-networks-add-on-for-splunk_620.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard_admin-master.zip  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard-master.zip  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sa-investigator-for-enterprise-security_200.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-apache-web-server_100.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-cloud-services_310.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-iis_101.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-windows_700.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-symantec-endpoint-protection_230.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-unix-and-linux_701.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/osquery-app-for-splunk_060.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-common-information-model-cim_4150.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-security-essentials_306.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-ta-for-suricata_233.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/ssl-certificate-checker_32.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/url-toolbox_18.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/website-monitoring_274.tgz  -auth 'admin:changeme'

    echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv2 Attack Only Dataset..."
    wget --progress=bar:force -P /opt/ https://s3.amazonaws.com/botsdataset/botsv2/botsv2_data_set_attack_only.tgz
    echo "[$(date +%H:%M:%S)]: Download Complete."
    echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
    tar zxvf /opt/botsv2_data_set_attack_only.tgz -C /opt/splunk/etc/apps/


    ## UNCOMMENT THIS BLOCK FOR THE FULL 12GB DATASET (Not recommended) ###
    # echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv2..."
    # wget --progress=bar:force https://s3.amazonaws.com/botsdataset/botsv2/botsv2_data_set.tgz /opt/
    # echo "[$(date +%H:%M:%S)]: Download Complete."
    # echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
    # tar zxvf botsv2_data_set.tgz /opt/splunk/etc/apps
    ## FULL DATASET COMMENT BLOCK ENDS ###

echo "BOTSv2 Installation complete!"