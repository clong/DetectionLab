#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
echo "apt-fast apt-fast/maxdownloads string 10" | debconf-set-selections;
echo "apt-fast apt-fast/dlflag boolean true" | debconf-set-selections;
sed -i "2ideb mirror://mirrors.ubuntu.com/mirrors.txt xenial main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-updates main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-backports main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-security main restricted universe multiverse" /etc/apt/sources.list

apt_install_prerequisites() {
  # Add repository for apt-fast
  add-apt-repository -y ppa:apt-fast/stable
  # Install prerequisites and useful tools
  echo "[$(date +%H:%M:%S)]: Running apt-get update..."
  apt-get -qq update
  apt-get -qq install -y apt-fast
  echo "[$(date +%H:%M:%S)]: Running apt-fast install..."
  apt-fast -qq install -y jq whois build-essential git docker docker-compose unzip htop
}

test_prerequisites() {
  for package in jq whois build-essential git docker docker-compose unzip
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
  service networking restart
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
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

install_golang() {
  if ! which go > /dev/null; then
    echo "[$(date +%H:%M:%S)]: Installing Golang v.1.12..."
    cd /home/vagrant || exit
    wget --progress=bar:force https://dl.google.com/go/go1.12.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.12.linux-amd64.tar.gz
    mkdir /root/go
  else
    echo "[$(date +%H:%M:%S)]: Golang seems to be installed already. Skipping."
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
    mkdir splunk

    # Try to resolve the latest version of Splunk by parsing the HTML on the downloads page
    echo "[$(date +%H:%M:%S)]: Attempting to autoresolve the latest version of Splunk..."
    LATEST_SPLUNK=$(curl https://www.splunk.com/en_us/download/splunk-enterprise.html | grep -i deb | grep -Eo "data-link=\"................................................................................................................................" | cut -d '"' -f 2)
    # Sanity check what was returned from the auto-parse attempt
    if [[ "$(echo $LATEST_SPLUNK | grep -c "^https:")" -eq 1 ]] && [[ "$(echo $LATEST_SPLUNK | grep -c "\.deb$")" -eq 1 ]]; then
      echo "[$(date +%H:%M:%S)]: The URL to the latest Splunk version was automatically resolved as: $LATEST_SPLUNK"
      echo "[$(date +%H:%M:%S)]: Attempting to download..."
      wget --progress=bar:force -P splunk/ "$LATEST_SPLUNK"
    else
      echo "[$(date +%H:%M:%S)]: Unable to auto-resolve the latest Splunk version. Falling back to hardcoded URL..."
      # Download Hardcoded Splunk
      wget --progress=bar:force -O splunk/splunk-7.2.6-c0bf0f679ce9-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.6&product=splunk&filename=splunk-7.2.6-c0bf0f679ce9-linux-2.6-amd64.deb&wget=true'
    fi
    dpkg -i splunk/*.deb
    /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme
    /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery-status -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index powershell -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index bro -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index suricata -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index threathunting -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_500.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/add-on-for-microsoft-sysmon_800.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/asn-lookup-generator_101.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/lookup-file-editor_331.tgz
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/force-directed-app-for-splunk_200.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/punchcard-custom-visualization_130.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sankey-diagram-custom-visualization_130.tgz  -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/threathunting_13.tar.gz  -auth 'admin:changeme'
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
    mkdir /opt/splunk/etc/apps/user-prefs/local
    echo '[general]
 render_version_messages = 0
 hideInstrumentationOptInModal = 1
 dismissedInstrumentationOptInVersion = 2
 [general_default]
 hideInstrumentationOptInModal = 1
 showWhatsNew = 0' > /opt/splunk/etc/system/local/user-prefs.conf

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
  if [ -f "/home/vagrant/kolide-quickstart" ]; then
    echo "[$(date +%H:%M:%S)]: Fleet is already installed"
  else
    echo "[$(date +%H:%M:%S)]: Installing Fleet..."
    echo -e "\n127.0.0.1       kolide" >> /etc/hosts
    echo -e "\n127.0.0.1       logger" >> /etc/hosts
    git clone https://github.com/kolide/kolide-quickstart.git
    cd kolide-quickstart || echo "Something went wrong while trying to clone the kolide-quickstart repository"
    cp /vagrant/resources/fleet/server.* .
    sed -i 's/ -it//g' demo.sh
    ./demo.sh up simple
    # Set the enrollment secret to match what we deploy to Windows hosts
    docker run --rm --network=kolidequickstart_default mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'update app_configs set osquery_enroll_secret = "enrollmentsecret" where id=1;' --batch kolide
    # Set snapshot events to be split into multiple events
    docker run --rm --network=kolidequickstart_default mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'insert into options (name, type, value) values ("logger_snapshot_event_type", 2, "true");' --batch kolide
    echo "Updated enrollment secret"
    cd /home/vagrant || exit
  fi
}

download_palantir_osquery_config() {
  if [ -f /home/vagrant/osquery-configuration ]; then
    echo "[$(date +%H:%M:%S)]: osquery configs have already been downloaded"
  else
    # Import Palantir osquery configs into Fleet
    echo "[$(date +%H:%M:%S)]: Downloading Palantir osquery configs..."
    git clone https://github.com/palantir/osquery-configuration.git
  fi
}

import_osquery_config_into_fleet() {
  wget --progress=bar:force https://github.com/kolide/fleet/releases/download/2.1.1/fleet_2.1.1.zip
  unzip fleet_2.1.1.zip -d fleet_2.1.1
  cp fleet_2.1.1/linux/fleetctl /usr/local/bin/fleetctl && chmod +x /usr/local/bin/fleetctl
  fleetctl config set --address https://192.168.38.105:8412
  fleetctl config set --tls-skip-verify true
  fleetctl setup --email admin@detectionlab.network --username admin --password 'admin123#' --org-name DetectionLab
  fleetctl login --email admin@detectionlab.network --password 'admin123#'

  # Use fleetctl to import YAML files
  fleetctl apply -f osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
  fleetctl apply -f osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
  for pack in osquery-configuration/Fleet/Endpoints/packs/*.yaml
    do fleetctl apply -f "$pack"
  done

  # Add Splunk monitors for Fleet
  /opt/splunk/bin/splunk add monitor "/home/vagrant/kolide-quickstart/osquery_result" -index osquery -sourcetype 'osquery:json' -auth 'admin:changeme'
  /opt/splunk/bin/splunk add monitor "/home/vagrant/kolide-quickstart/osquery_status" -index osquery-status -sourcetype 'osquery:status' -auth 'admin:changeme'
}

install_bro() {
  echo "[$(date +%H:%M:%S)]: Installing Bro..."
  # Environment variables
  NODECFG=/opt/bro/etc/node.cfg
  SPLUNK_BRO_JSON=/opt/splunk/etc/apps/TA-bro_json
  SPLUNK_BRO_MONITOR='monitor:///opt/bro/spool/manager'
  SPLUNK_SURICATA_MONITOR='monitor:///var/log/suricata'
  SPLUNK_SURICATA_SOURCETYPE='json_suricata'
  echo "deb http://download.opensuse.org/repositories/network:/bro/xUbuntu_16.04/ /" > /etc/apt/sources.list.d/bro.list
  curl -s http://download.opensuse.org/repositories/network:/bro/xUbuntu_16.04/Release.key |apt-key add -

  # Update APT repositories
  apt-get -qq -ym update
  # Install tools to build and configure bro
  apt-get -qq -ym install bro crudini python-pip
  export PATH=$PATH:/opt/bro/bin
  pip install bro-pkg
  bro-pkg refresh
  bro-pkg autoconfig
  bro-pkg install --force salesforce/ja3
  # Load bro scripts
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
  @load policy/protocols/smb
  @load policy/protocols/conn/vlan-logging
  @load policy/protocols/conn/mac-logging
  @load ja3

  redef Intel::read_files += {
    "/opt/bro/etc/intel.dat"
  };
  ' >> /opt/bro/share/bro/site/local.bro

  # Configure Bro
  crudini --del $NODECFG bro
  crudini --set $NODECFG manager type manager
  crudini --set $NODECFG manager host localhost
  crudini --set $NODECFG proxy type proxy
  crudini --set $NODECFG proxy host localhost

  # Setup $CPUS numbers of bro workers
  crudini --set $NODECFG worker-eth1 type worker
  crudini --set $NODECFG worker-eth1 host localhost
  crudini --set $NODECFG worker-eth1 interface eth1
  crudini --set $NODECFG worker-eth1 lb_method pf_ring
  crudini --set $NODECFG worker-eth1 lb_procs "$(nproc)"

  # Setup bro to run at boot
  cp /vagrant/resources/bro/bro.service /lib/systemd/system/bro.service
  systemctl enable bro
  systemctl start bro

  # Setup splunk TA to ingest bro and suricata data
  git clone https://github.com/jahshuah/splunk-ta-bro-json $SPLUNK_BRO_JSON

  mkdir -p $SPLUNK_BRO_JSON/local
  cp $SPLUNK_BRO_JSON/default/inputs.conf $SPLUNK_BRO_JSON/local/inputs.conf

  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_BRO_MONITOR index   bro
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_BRO_MONITOR sourcetype   json_bro
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_BRO_MONITOR whitelist   '.*\.log$'
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_BRO_MONITOR blacklist   '.*(communication|stderr)\.log$'
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_BRO_MONITOR disabled   0
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR index   suricata
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR sourcetype   json_suricata
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR whitelist   'eve.json'
  crudini --set  $SPLUNK_BRO_JSON/local/inputs.conf $SPLUNK_SURICATA_MONITOR disabled   0
  crudini --set  $SPLUNK_BRO_JSON/local/props.conf  $SPLUNK_SURICATA_SOURCETYPE TRUNCATE    0

  # Ensure permissions are correct and restart splunk
  chown -R splunk $SPLUNK_BRO_JSON
  /opt/splunk/bin/splunk restart

  # Verify that Bro is running
  if ! pgrep -f bro > /dev/null; then
    echo "Bro attempted to start but is not running. Exiting"
    exit 1
  fi
}

install_suricata() {
  # Run iwr -Uri testmyids.com -UserAgent "BlackSun" in Powershell to generate test alerts
  echo "[$(date +%H:%M:%S)]: Installing Suricata..."
  # Install yq to maniuplate the suricata.yaml inline
  /usr/local/go/bin/go get -u github.com/mikefarah/yq

  # Install suricata
  add-apt-repository -y ppa:oisf/suricata-stable
  apt-get -qq -y update && apt-get -qq -y install suricata crudini
  test_suricata_prerequisites
  # Install suricata-update
  cd /home/vagrant || exit 1
  git clone https://github.com/OISF/suricata-update.git
  cd /home/vagrant/suricata-update || exit 1
  python setup.py install
  # Add DC_SERVERS variable to suricata.yaml in support et-open signatures
  /root/go/bin/yq w -i /etc/suricata/suricata.yaml vars.address-groups.DC_SERVERS '$HOME_NET'

  # It may make sense to store the suricata.yaml file as a resource file if this begins to become too complex
  # Add more verbose alert logging
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload true
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload-buffer-size 4kb
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.payload-printable yes
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.packet yes
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.http yes
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.tls yes
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.ssh yes
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.0.alert.smtp yes
  # Turn off traffic flow logging (duplicative of Bro and wrecks Splunk trial license)
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove HTTP
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove DNS
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.1 # Remove TLS
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove SMTP
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove SSH
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove Stats
  /root/go/bin/yq d  -i /etc/suricata/suricata.yaml outputs.1.eve-log.types.2 # Remove Flow
  # Enable JA3 fingerprinting
  /root/go/bin/yq w -i /etc/suricata/suricata.yaml app-layer.protocols.tls.ja3-fingerprints true
  # AF packet monitoring should be set to eth1
  /root/go/bin/yq w -i /etc/suricata/suricata.yaml af-packet.0.interface eth1


  crudini --set --format=sh /etc/default/suricata '' iface eth1
  # update suricata signature sources
  suricata-update update-sources
  # disable protocol decode as it is duplicative of bro
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

  # One-off support for packages which aren't installed via dpkg
  echo "[$(date +%H:%M:%S)]: [TEST] Validating that yq is correctly installed..."
  # Check if the binary exists
  if ! [ -f /root/go/bin/yq ]; then
    # If it doesn't exist, try to re-install the package
    echo "[-] yq was not found. Attempting to reinstall."
    /usr/local/go/bin/go get -u github.com/mikefarah/yq
    if ! [ -f /root/go/bin/yq ]; then
      # If the reinstall fails, give up
      echo "[X] Unable to install yq even after a retry. Exiting."
      exit 1
    fi
  else
    echo "[+] yq was successfully installed!"
  fi
}

postinstall_tasks() {
  # Include Splunk and Bro in the PATH
  echo export PATH="$PATH:/opt/splunk/bin:/opt/bro/bin" >> ~/.bashrc
}

main() {
  apt_install_prerequisites
  test_prerequisites
  fix_eth1_static_ip
  install_golang
  install_splunk
  install_fleet
  download_palantir_osquery_config
  import_osquery_config_into_fleet
  install_suricata
  install_bro
  postinstall_tasks
}

main
exit 0
