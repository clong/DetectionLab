#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
echo "apt-fast apt-fast/maxdownloads string 10" | debconf-set-selections;
echo "apt-fast apt-fast/dlflag boolean true" | debconf-set-selections;

sed -i "2ideb mirror://mirrors.ubuntu.com/mirrors.txt bionic main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt bionic-updates main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt bionic-backports main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt bionic-security main restricted universe multiverse" /etc/apt/sources.list

apt_install_prerequisites() {
  echo "[$(date +%H:%M:%S)]: Adding apt repositories..."
  # Add repository for apt-fast
  add-apt-repository -y ppa:apt-fast/stable
  # Add repository for yq
  add-apt-repository -y ppa:rmescandon/yq
　# Add repository for suricata
  add-apt-repository -y ppa:oisf/suricata-stable
  # Install prerequisites and useful tools
  echo "[$(date +%H:%M:%S)]: Running apt-get clean..."
  apt-get clean
  echo "[$(date +%H:%M:%S)]: Running apt-get update..."
  apt-get -qq update
  apt-get -qq install -y apt-fast
  echo "[$(date +%H:%M:%S)]: Running apt-fast install..."
  apt-fast -qq install -y jq whois build-essential git docker docker-compose unzip htop yq
}

modify_motd() {
  echo "[$(date +%H:%M:%S)]: Updating the MOTD..."
  # Force color terminal
  sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc
  sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/vagrant/.bashrc
  # Remove some stock Ubuntu MOTD content
  chmod -x /etc/update-motd.d/10-help-text
  # Copy the DetectionLab MOTD
  cp /vagrant/resources/logger/20-detectionlab /etc/update-motd.d/
  chmod +x /etc/update-motd.d/20-detectionlab
}

test_prerequisites() {
  for package in jq whois build-essential git docker docker-compose unzip yq
  do
    echo "[$(date +%H:%M:%S)]: [TEST] Validating that $package is correctly installed..."
    # Loop through each package using dpkg
    if ! dpkg -S $package > /dev/null; then
      # If which returns a non-zero return code, try to re-install the package
      echo "[-] $package was not found. Attempting to reinstall."
      apt-get -qq update && apt-get install -y $package
      if ! which $package > /dev/null; then
        # If the reinstall fails, give up
        echo "[X] Unable to install $package even after a retry. Exiting."
        exit 1
      fi
    else
      echo "[+] $package was successfully installed!"
    fi
  done
}

fix_eth1_static_ip() {
  # There's a fun issue where dhclient keeps messing with eth1 despite the fact
  # that eth1 has a static IP set. We workaround this by setting a static DHCP lease.
  echo -e 'interface "eth1" {
    send host-name = gethostname();
    send dhcp-requested-address 192.168.38.105;
  }' >> /etc/dhcp/dhclient.conf
  netplan apply
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ "$ETH1_IP" != "192.168.38.105" ]; then
    echo "Incorrect IP Address settings detected. Attempting to fix."
    ifdown eth1
    ip addr flush dev eth1
    ifup eth1
    ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ "$ETH1_IP" == "192.168.38.105" ]; then
      echo "[$(date +%H:%M:%S)]: The static IP has been fixed and set to 192.168.38.105"
    else
      echo "[$(date +%H:%M:%S)]: Failed to fix the broken static IP for eth1. Exiting because this will cause problems with other VMs."
      exit 1
    fi
  fi
}

install_splunk() {
  # Check if Splunk is already installed
  if [ -f "/opt/splunk/bin/splunk" ]; then
    echo "[$(date +%H:%M:%S)]: Splunk is already installed"
  else
    echo "[$(date +%H:%M:%S)]: Installing Splunk..."
    # Get download.splunk.com into the DNS cache. Sometimes resolution randomly fails during wget below
    dig @8.8.8.8 download.splunk.com > /dev/null
    dig @8.8.8.8 splunk.com > /dev/null

    # Try to resolve the latest version of Splunk by parsing the HTML on the downloads page
    echo "[$(date +%H:%M:%S)]: Attempting to autoresolve the latest version of Splunk..."
    LATEST_SPLUNK=$(curl https://www.splunk.com/en_us/download/splunk-enterprise.html | grep -i deb | grep -Eo "data-link=\"................................................................................................................................" | cut -d '"' -f 2)
    # Sanity check what was returned from the auto-parse attempt
    if [[ "$(echo $LATEST_SPLUNK | grep -c "^https:")" -eq 1 ]] && [[ "$(echo $LATEST_SPLUNK | grep -c "\.deb$")" -eq 1 ]]; then
      echo "[$(date +%H:%M:%S)]: The URL to the latest Splunk version was automatically resolved as: $LATEST_SPLUNK"
      echo "[$(date +%H:%M:%S)]: Attempting to download..."
      wget --progress=bar:force -P /opt "$LATEST_SPLUNK"
    else
      echo "[$(date +%H:%M:%S)]: Unable to auto-resolve the latest Splunk version. Falling back to hardcoded URL..."
      # Download Hardcoded Splunk
      wget --progress=bar:force -O splunk/splunk-7.2.6-c0bf0f679ce9-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.6&product=splunk&filename=splunk-7.2.6-c0bf0f679ce9-linux-2.6-amd64.deb&wget=true'
    fi
    dpkg -i /opt/splunk*.deb
    /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme
    /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery-status -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index powershell -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index zeek -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index suricata -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index threathunting -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_500.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/add-on-for-microsoft-sysmon_800.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/asn-lookup-generator_101.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/lookup-file-editor_331.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-zeek-aka-bro_400.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/force-directed-app-for-splunk_200.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/punchcard-custom-visualization_130.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sankey-diagram-custom-visualization_130.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/link-analysis-app-for-splunk_161.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/threathunting_141.tgz  -auth 'admin:changeme'

    # Uncomment the following block to install BOTSv2 
    # Thanks to @MHaggis for this addition!
    # It is recommended to only uncomment the attack-only dataset comment block. 
    # You may also link to the full dataset which is ~12GB if you prefer.
    # More information on BOTSv2 can be found at https://github.com/splunk/botsv2

    ### BOTSv2 COMMENT BLOCK BEGINS ###
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/base64_11.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/jellyfisher_010.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/palo-alto-networks-add-on-for-splunk_611.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard_admin-master.zip  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/SA-ctf_scoreboard-master.zip  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sa-investigator-for-enterprise-security_200.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-apache-web-server_100.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-cloud-services_310.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-iis_101.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-windows_600.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-symantec-endpoint-protection_230.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-unix-and-linux_602.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-app-for-osquery_10.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-common-information-model-cim_4130.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-security-essentials_241.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-ta-for-suricata_233.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/ssl-certificate-checker_32.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/url-toolbox_16.tgz  -auth 'admin:changeme'
    # /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/website-monitoring_274.tgz  -auth 'admin:changeme'

    ### UNCOMMENT THIS BLOCK FOR THE ATTACK-ONLY DATASET (Recommended) ###
    # echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv2 Attack Only Dataset..."
    # wget --progress=bar:force -P /opt/ https://s3.amazonaws.com/botsdataset/botsv2/botsv2_data_set_attack_only.tgz
    # echo "[$(date +%H:%M:%S)]: Download Complete."
    # echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
    # tar zxvf /opt/botsv2_data_set_attack_only.tgz -C /opt/splunk/etc/apps/
    ### ATTACK-ONLY COMMENT BLOCK ENDS ###

    ### UNCOMMENT THIS BLOCK FOR THE FULL 12GB DATASET (Not recommended) ###
    # echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv2..."
    # wget --progress=bar:force https://s3.amazonaws.com/botsdataset/botsv2/botsv2_data_set.tgz /opt/
    # echo "[$(date +%H:%M:%S)]: Download Complete."
    # echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
    # tar zxvf botsv2_data_set.tgz /opt/splunk/etc/apps
    ### FULL DATASET COMMENT BLOCK ENDS ###
    
    ### BOTSv2 COMMENT BLOCK ENDS ###

    # Add custom Macro definitions for ThreatHunting App
    cp /vagrant/resources/splunk_server/macros.conf /opt/splunk/etc/apps/ThreatHunting/default/macros.conf
    # Fix Windows TA macros
    mkdir /opt/splunk/etc/apps/Splunk_TA_windows/local
    cp /opt/splunk/etc/apps/Splunk_TA_windows/default/macros.conf /opt/splunk/etc/apps/Splunk_TA_windows/local
    sed -i 's/wineventlog_windows/wineventlog/g' /opt/splunk/etc/apps/Splunk_TA_windows/local/macros.conf
    # Fix Force Directed App until 2.0.1 is released (https://answers.splunk.com/answers/668959/invalid-key-in-stanza-default-value-light.html#answer-669418)
    rm /opt/splunk/etc/apps/force_directed_viz/default/savedsearches.conf

    # Add a Splunk TCP input on port 9997
    echo -e "[splunktcp://9997]\nconnection_host = ip" > /opt/splunk/etc/apps/search/local/inputs.conf
    # Add props.conf and transforms.conf
    cp /vagrant/resources/splunk_server/props.conf /opt/splunk/etc/apps/search/local/
    cp /vagrant/resources/splunk_server/transforms.conf /opt/splunk/etc/apps/search/local/
    cp /opt/splunk/etc/system/default/limits.conf /opt/splunk/etc/system/local/limits.conf
    # Bump the memtable limits to allow for the ASN lookup table
    sed -i.bak 's/max_memtable_bytes = 10000000/max_memtable_bytes = 30000000/g' /opt/splunk/etc/system/local/limits.conf

    # Skip Splunk Tour and Change Password Dialog
    echo "[$(date +%H:%M:%S)]: Disabling the Splunk tour prompt..."
    touch /opt/splunk/etc/.ui_login
    mkdir -p /opt/splunk/etc/users/admin/search/local
    echo -e "[search-tour]\nviewed = 1" > /opt/splunk/etc/system/local/ui-tour.conf
    # Source: https://answers.splunk.com/answers/660728/how-to-disable-the-modal-pop-up-help-us-to-improve.html
    echo '[general]
render_version_messages = 0
hideInstrumentationOptInModal = 1
dismissedInstrumentationOptInVersion = 1
[general_default]
hideInstrumentationOptInModal = 1
showWhatsNew = 0
notification_python_3_impact = false' > /opt/splunk/etc/system/local/user-prefs.conf
    echo '[general]
render_version_messages = 0
hideInstrumentationOptInModal = 1
dismissedInstrumentationOptInVersion = 1
[general_default]
hideInstrumentationOptInModal = 1
showWhatsNew = 0
notification_python_3_impact = false' > /opt/splunk/etc/apps/user-prefs/local/user-prefs.conf
  # Disable the instrumentation popup
  echo -e "showOptInModal = 0\noptInVersionAcknowledged = 4" >> /opt/splunk/etc/apps/splunk_instrumentation/local/telemetry.conf

    # Enable SSL Login for Splunk
    echo -e "[settings]\nenableSplunkWebSSL = true" > /opt/splunk/etc/system/local/web.conf
    # Reboot Splunk to make changes take effect
    /opt/splunk/bin/splunk restart
    /opt/splunk/bin/splunk enable boot-start
    # Generate the ASN lookup table
    /opt/splunk/bin/splunk search "|asngen | outputlookup asn" -auth 'admin:changeme'
  fi
}

install_fleet() {
  # Install Fleet
  if [ -f "/opt/kolide-quickstart" ]; then
    echo "[$(date +%H:%M:%S)]: Fleet is already installed"
  else
    echo "[$(date +%H:%M:%S)]: Installing Fleet..."
    echo -e "\n127.0.0.1       kolide" >> /etc/hosts
    echo -e "\n127.0.0.1       logger" >> /etc/hosts
    cd /opt && git clone https://github.com/kolide/kolide-quickstart.git
    cd /opt/kolide-quickstart || echo "Something went wrong while trying to clone the kolide-quickstart repository"
    cp /vagrant/resources/fleet/server.* .
    sed -i 's/ -it//g' demo.sh
    ./demo.sh up simple
    # Set the enrollment secret to match what we deploy to Windows hosts
    docker run --rm --network=kolidequickstart_default mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'update app_configs set osquery_enroll_secret = "enrollmentsecret" where id=1;' --batch kolide
    # Set snapshot events to be split into multiple events
    docker run --rm --network=kolidequickstart_default mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'insert into options (name, type, value) values ("logger_snapshot_event_type", 2, "true");' --batch kolide
    echo "Updated enrollment secret"
  fi
}

download_palantir_osquery_config() {
  if [ -f /opt/osquery-configuration ]; then
    echo "[$(date +%H:%M:%S)]: osquery configs have already been downloaded"
  else
    # Import Palantir osquery configs into Fleet
    echo "[$(date +%H:%M:%S)]: Downloading Palantir osquery configs..."
    cd /opt && git clone https://github.com/palantir/osquery-configuration.git
  fi
}

import_osquery_config_into_fleet() {
  cd /opt
  wget --progress=bar:force https://github.com/kolide/fleet/releases/download/2.4.0/fleet.zip
  unzip fleet.zip -d fleet
  cp fleet/linux/fleetctl /usr/local/bin/fleetctl && chmod +x /usr/local/bin/fleetctl
  fleetctl config set --address https://192.168.38.105:8412
  fleetctl config set --tls-skip-verify true
  fleetctl setup --email admin@detectionlab.network --username admin --password 'admin123#' --org-name DetectionLab
  fleetctl login --email admin@detectionlab.network --password 'admin123#'

  # Change the query invervals to reflect a lab environment
  # Every hour -> Every 3 minutes
  # Every 24 hours -> Every 15 minutes
  sed -i 's/interval: 3600/interval: 180/g' osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
  sed -i 's/interval: 3600/interval: 180/g' osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
  sed -i 's/interval: 28800/interval: 900/g' osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
  sed -i 's/interval: 28800/interval: 900/g' osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
  # These can be removed after this PR is merged: https://github.com/palantir/osquery-configuration/pull/14
  sed -i "s/labels: null/labels:\n    - MS Windows/g" osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
  sed -i "s/labels: null/labels:\n    - MS Windows/g" osquery-configuration/Fleet/Endpoint/packs/windows-application-security.yaml
  sed -i "s/labels: null/labels:\n    - MS Windows/g" osquery-configuration/Fleet/Endpoints/packs/windows-compliance.yaml
  sed -i "s/labels: null/labels:\n    - MS Windows/g" osquery-configuration/Fleet/Endpoints/packs/windows-registry-monitoring.yaml
  sed -i "s/labels: null/labels:\n    - MS Windows\n    - macOS/g" osquery-configuration/Fleet/Endpoints/packs/performance-metrics.yaml
  sed -i "s/labels: null/labels:\n    - MS Windows\n    - macOS/g" osquery-configuration/Fleet/Endpoints/packs/security-tooling-checks.yaml

  # Use fleetctl to import YAML files
  fleetctl apply -f osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
  fleetctl apply -f osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
  for pack in osquery-configuration/Fleet/Endpoints/packs/*.yaml
    do fleetctl apply -f "$pack"
  done

  # Add Splunk monitors for Fleet
  /opt/splunk/bin/splunk add monitor "/opt/kolide-quickstart/osquery_result" -index osquery -sourcetype 'osquery:json' -auth 'admin:changeme'
  /opt/splunk/bin/splunk add monitor "/opt/kolide-quickstart/osquery_status" -index osquery-status -sourcetype 'osquery:status' -auth 'admin:changeme'
}

install_zeek() {
  echo "[$(date +%H:%M:%S)]: Installing Zeek..."
  # Environment variables
  NODECFG=/opt/zeek/etc/node.cfg
  SPLUNK_ZEEK_JSON=/opt/splunk/etc/apps/Splunk_TA_bro
  SPLUNK_ZEEK_MONITOR='monitor:///opt/zeek/spool/manager'
  SPLUNK_SURICATA_MONITOR='monitor:///var/log/suricata'
  SPLUNK_SURICATA_SOURCETYPE='json_suricata'
  sh -c "echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_18.04/ /' > /etc/apt/sources.list.d/security:zeek.list"
  wget -nv https://download.opensuse.org/repositories/security:zeek/xUbuntu_18.04/Release.key -O /tmp/Release.key
  apt-key add - < /tmp/Release.key
  # Update APT repositories
  apt-get -qq -ym update
  # Install tools to build and configure Zeek
  apt-get -qq -ym install zeek crudini python-pip
  export PATH=$PATH:/opt/zeek/bin
  pip install zkg
  zkg refresh
  zkg autoconfig
  zkg install --force salesforce/ja3
  # Load Zeek scripts
  echo '
  @load protocols/ftp/software
  @load protocols/smtp/software
  @load protocols/ssh/software
  @load protocols/http/software
  @load tuning/json-logs
  @load policy/integration/collective-intel
  @load policy/frameworks/intel/do_notice
  @load frameworks/intel/seen
  @load frameworks/intel/do_notice
  @load frameworks/files/hash-all-files
  @load base/protocols/smb
  @load policy/protocols/conn/vlan-logging
  @load policy/protocols/conn/mac-logging
  @load ja3

  redef Intel::read_files += {
    "/opt/zeek/etc/intel.dat"
  };
  ' >> /opt/zeek/share/zeek/site/local.zeek

  # Configure Zeek
  crudini --del $NODECFG zeek
  crudini --set $NODECFG manager type manager
  crudini --set $NODECFG manager host localhost
  crudini --set $NODECFG proxy type proxy
  crudini --set $NODECFG proxy host localhost

  # Setup $CPUS numbers of Zeek workers
  crudini --set $NODECFG worker-eth1 type worker
  crudini --set $NODECFG worker-eth1 host localhost
  crudini --set $NODECFG worker-eth1 interface eth1
  crudini --set $NODECFG worker-eth1 lb_method pf_ring
  crudini --set $NODECFG worker-eth1 lb_procs "$(nproc)"

  # Setup Zeek to run at boot
  cp /vagrant/resources/zeek/zeek.service /lib/systemd/system/zeek.service
  systemctl enable zeek
  systemctl start zeek

  mkdir -p $SPLUNK_ZEEK_JSON/local
  cp $SPLUNK_ZEEK_JSON/default/inputs.conf $SPLUNK_ZEEK_JSON/local/inputs.conf

  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_ZEEK_MONITOR index   zeek
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_ZEEK_MONITOR sourcetype   bro:json
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_ZEEK_MONITOR whitelist   '.*\.log$'
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_ZEEK_MONITOR blacklist   '.*(communication|stderr)\.log$'
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_ZEEK_MONITOR disabled   0
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR index   suricata
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR sourcetype   suricata:json
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR whitelist   'eve.json'
  crudini --set  $SPLUNK_ZEEK_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR disabled   0
  crudini --set  $SPLUNK_ZEEK_JSON/local/props.conf  $SPLUNK_SURICATA_SOURCETYPE TRUNCATE    0

  # Ensure permissions are correct and restart splunk
  chown -R splunk $SPLUNK_ZEEK_JSON
  /opt/splunk/bin/splunk restart

  # Verify that Zeek is running
  if ! pgrep -f zeek > /dev/null; then
    echo "Zeek attempted to start but is not running. Exiting"
    exit 1
  fi
}

install_suricata() {
  # Run iwr -Uri testmyids.com -UserAgent "BlackSun" in Powershell to generate test alerts
  echo "[$(date +%H:%M:%S)]: Installing Suricata..."

  # Install suricata
  apt-get -qq -y install suricata crudini
  test_suricata_prerequisites
  # Install suricata-update
  cd /opt || exit 1
  git clone https://github.com/OISF/suricata-update.git
  cd /opt/suricata-update || exit 1
  python setup.py install
  # Add DC_SERVERS variable to suricata.yaml in support et-open signatures
  yq w -i /etc/suricata/suricata.yaml vars.address-groups.DC_SERVERS '$HOME_NET'

  # It may make sense to store the suricata.yaml file as a resource file if this begins to become too complex
  # Add more verbose alert logging
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload true
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload-buffer-size 4kb
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload-printable yes
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.packet yes
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.http yes
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.tls yes
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.ssh yes
  yq w -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.smtp yes
  # Turn off traffic flow logging (duplicative of Zeek and wrecks Splunk trial license)
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove HTTP
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove DNS
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove TLS
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove SMTP
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove SSH
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove Stats
  yq d -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove Flow
  # Enable JA3 fingerprinting
  yq w -i /etc/suricata/suricata.yaml app-layer.protocols.tls.ja3-fingerprints true
  # AF packet monitoring should be set to eth1
  yq w -i /etc/suricata/suricata.yaml af-packet.0.interface eth1

  crudini --set --format=sh /etc/default/suricata '' iface eth1
  # update suricata signature sources
  suricata-update update-sources
  # disable protocol decode as it is duplicative of Zeek
  echo re:protocol-command-decode >> /etc/suricata/disable.conf
  # enable et-open and attackdetection sources
  suricata-update enable-source et/open
  suricata-update enable-source ptresearch/attackdetection
  # Add the YAML header to the top of the suricata config
  echo "Adding the YAML header to /etc/suricata/suricata.yaml"
  echo -e "%YAML 1.1\n---\n$(cat /etc/suricata/suricata.yaml)" > /etc/suricata/suricata.yaml

  # Update suricata and restart
  suricata-update
  service suricata stop
  service suricata start
  sleep 3

  # Verify that Suricata is running
  if ! pgrep -f suricata > /dev/null; then
    echo "Suricata attempted to start but is not running. Exiting"
    exit 1
  fi
}

test_suricata_prerequisites() {
  for package in suricata crudini
  do
    echo "[$(date +%H:%M:%S)]: [TEST] Validating that $package is correctly installed..."
    # Loop through each package using dpkg
    if ! dpkg -S $package > /dev/null; then
      # If which returns a non-zero return code, try to re-install the package
      echo "[-] $package was not found. Attempting to reinstall."
      apt-get clean && apt-get -qq update && apt-get install -y $package
      if ! which $package > /dev/null; then
        # If the reinstall fails, give up
        echo "[X] Unable to install $package even after a retry. Exiting."
        exit 1
      fi
    else
      echo "[+] $package was successfully installed!"
    fi
  done
}

install_guacamole() {
  echo "[$(date +%H:%M:%S)]: Installing Guacamole..."
  cd /opt
  apt-get -qq install -y libcairo2-dev libjpeg62-dev libpng-dev libossp-uuid-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libssh-dev tomcat8 tomcat8-admin tomcat8-user
  wget --progress=bar:force "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/source/guacamole-server-1.0.0.tar.gz" -O guacamole-server-1.0.0.tar.gz
  tar -xvf guacamole-server-1.0.0.tar.gz && cd guacamole-server-1.0.0
  ./configure &> /dev/null && make --quiet &> /dev/null && make --quiet install &> /dev/null || echo "[-] An error occurred while installing Guacamole."
  ldconfig
  cd /var/lib/tomcat8/webapps
  wget --progress=bar:force "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/binary/guacamole-1.0.0.war" -O guacamole.war
  mkdir /etc/guacamole
  mkdir /usr/share/tomcat8/.guacamole
  cp /vagrant/resources/guacamole/user-mapping.xml /etc/guacamole/
  cp /vagrant/resources/guacamole/guacamole.properties /etc/guacamole/
  cp /vagrant/resources/guacamole/guacd.service /lib/systemd/system
  sudo ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat8/.guacamole/
  sudo ln -s /etc/guacamole/user-mapping.xml /usr/share/tomcat8/.guacamole/
  systemctl enable guacd
  systemctl enable tomcat8
  systemctl start guacd
  systemctl start tomcat8
}

postinstall_tasks() {
  # Include Splunk and Zeek in the PATH
  echo export PATH="$PATH:/opt/splunk/bin:/opt/zeek/bin" >> ~/.bashrc
  # Ping DetectionLab server for usage statistics
  curl -A "DetectionLab-logger" "https://detectionlab.network/logger"
}

main() {
  apt_install_prerequisites
  modify_motd
  test_prerequisites
  fix_eth1_static_ip
  install_splunk
  install_fleet
  download_palantir_osquery_config
  import_osquery_config_into_fleet
  install_suricata
  install_zeek
  install_guacamole
  postinstall_tasks
}

main
exit 0
