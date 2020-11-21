#! /usr/bin/env bash

# This is the script that is used to provision the logger host

# Override existing DNS Settings using netplan, but don't do it for Terraform AWS builds
if ! curl -s 169.254.169.254 --connect-timeout 2 >/dev/null; then
  echo -e "    eth1:\n      dhcp4: true\n      nameservers:\n        addresses: [8.8.8.8,8.8.4.4]" >>/etc/netplan/01-netcfg.yaml
  netplan apply
fi
sed -i 's/nameserver 127.0.0.53/nameserver 8.8.8.8/g' /etc/resolv.conf && chattr +i /etc/resolv.conf

# Source variables from logger_variables.sh
# shellcheck disable=SC1091
source /vagrant/logger_variables.sh 2>/dev/null || \
source /home/vagrant/logger_variables.sh 2>/dev/null || \
echo "Unable to locate logger_variables.sh"

if [ -z "$MAXMIND_LICENSE" ]; then
  echo "Note: You have not entered a MaxMind API key in logger_variables.sh, so the ASNgen Splunk app may not work correctly."
  echo "However, it is optional and everything else should function correctly."
fi

export DEBIAN_FRONTEND=noninteractive
echo "apt-fast apt-fast/maxdownloads string 10" | debconf-set-selections
echo "apt-fast apt-fast/dlflag boolean true" | debconf-set-selections

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
  apt-fast -qq install -y jq whois build-essential git unzip htop yq mysql-server redis-server python-pip
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
  for package in jq whois build-essential git unzip yq mysql-server redis-server python-pip; do
    echo "[$(date +%H:%M:%S)]: [TEST] Validating that $package is correctly installed..."
    # Loop through each package using dpkg
    if ! dpkg -S $package >/dev/null; then
      # If which returns a non-zero return code, try to re-install the package
      echo "[-] $package was not found. Attempting to reinstall."
      apt-get -qq update && apt-get install -y $package
      if ! which $package >/dev/null; then
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
  USING_KVM=$(sudo lsmod | grep kvm)
  if [ -n "$USING_KVM" ]; then
    echo "[*] Using KVM, no need to fix DHCP for eth1 iface"
    return 0
  fi
  if [ -f /sys/class/net/eth2/address ]; then
    if [ "$(cat /sys/class/net/eth2/address)" == "00:50:56:a3:b1:c4" ]; then
      echo "[*] Using ESXi, no need to change anything"
      return 0
    fi
  fi
  # There's a fun issue where dhclient keeps messing with eth1 despite the fact
  # that eth1 has a static IP set. We workaround this by setting a static DHCP lease.
  echo -e 'interface "eth1" {
    send host-name = gethostname();
    send dhcp-requested-address 192.168.38.105;
  }' >>/etc/dhcp/dhclient.conf
  netplan apply
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
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

  # Make sure we do have a DNS resolution
  while true; do
    if [ "$(dig +short @8.8.8.8 github.com)" ]; then break; fi
    sleep 1
  done
}

install_splunk() {
  # Check if Splunk is already installed
  if [ -f "/opt/splunk/bin/splunk" ]; then
    echo "[$(date +%H:%M:%S)]: Splunk is already installed"
  else
    echo "[$(date +%H:%M:%S)]: Installing Splunk..."
    # Get download.splunk.com into the DNS cache. Sometimes resolution randomly fails during wget below
    dig @8.8.8.8 download.splunk.com >/dev/null
    dig @8.8.8.8 splunk.com >/dev/null
    dig @8.8.8.8 www.splunk.com >/dev/null

    # Try to resolve the latest version of Splunk by parsing the HTML on the downloads page
    echo "[$(date +%H:%M:%S)]: Attempting to autoresolve the latest version of Splunk..."
    LATEST_SPLUNK=$(curl https://www.splunk.com/en_us/download/splunk-enterprise.html | grep -i deb | grep -Eo "data-link=\"................................................................................................................................" | cut -d '"' -f 2)
    # Sanity check what was returned from the auto-parse attempt
    if [[ "$(echo "$LATEST_SPLUNK" | grep -c "^https:")" -eq 1 ]] && [[ "$(echo "$LATEST_SPLUNK" | grep -c "\.deb$")" -eq 1 ]]; then
      echo "[$(date +%H:%M:%S)]: The URL to the latest Splunk version was automatically resolved as: $LATEST_SPLUNK"
      echo "[$(date +%H:%M:%S)]: Attempting to download..."
      wget --progress=bar:force -P /opt "$LATEST_SPLUNK"
    else
      echo "[$(date +%H:%M:%S)]: Unable to auto-resolve the latest Splunk version. Falling back to hardcoded URL..."
      # Download Hardcoded Splunk
      wget --progress=bar:force -O /opt/splunk-8.0.2-a7f645ddaf91-linux-2.6-amd64.deb 'https://download.splunk.com/products/splunk/releases/8.0.2/linux/splunk-8.0.2-a7f645ddaf91-linux-2.6-amd64.deb&wget=true'
    fi
    if ! ls /opt/splunk*.deb 1>/dev/null 2>&1; then
      echo "Something went wrong while trying to download Splunk. This script cannot continue. Exiting."
      exit 1
    fi
    if ! dpkg -i /opt/splunk*.deb >/dev/null; then
      echo "Something went wrong while trying to install Splunk. This script cannot continue. Exiting."
      exit 1
    fi

    /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme
    /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery-status -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index powershell -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index zeek -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index suricata -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index threathunting -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index evtx_attack_samples -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_700.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-microsoft-sysmon_1062.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/asn-lookup-generator_110.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/lookup-file-editor_331.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/splunk-add-on-for-zeek-aka-bro_400.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/force-directed-app-for-splunk_200.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/punchcard-custom-visualization_130.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/sankey-diagram-custom-visualization_130.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/link-analysis-app-for-splunk_161.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/threathunting_144.tgz -auth 'admin:changeme'
    
    # Fix ASNGen App - https://github.com/doksu/TA-asngen/issues/18#issuecomment-685691630
    echo 'python.version = python2' >> /opt/splunk/etc/apps/TA-asngen/default/commands.conf

    # Install the Maxmind license key for the ASNgen App if it was provided
    if [ -n "$MAXMIND_LICENSE" ]; then
      mkdir /opt/splunk/etc/apps/TA-asngen/local
      cp /opt/splunk/etc/apps/TA-asngen/default/asngen.conf /opt/splunk/etc/apps/TA-asngen/local/asngen.conf
      sed -i "s/license_key =/license_key = $MAXMIND_LICENSE/g" /opt/splunk/etc/apps/TA-asngen/local/asngen.conf
    fi

    # Install a Splunk license if it was provided
    if [ -n "$BASE64_ENCODED_SPLUNK_LICENSE" ]; then
      echo "$BASE64_ENCODED_SPLUNK_LICENSE" | base64 -d > /tmp/Splunk.License
      /opt/splunk/bin/splunk add licenses /tmp/Splunk.License -auth 'admin:changeme'
      rm /tmp/Splunk.License
    fi

    # Replace the props.conf for Sysmon TA and Windows TA
    # Removed all the 'rename = xmlwineventlog' directives
    # I know youre not supposed to modify files in "default",
    # but for some reason adding them to "local" wasnt working
    cp /vagrant/resources/splunk_server/windows_ta_props.conf /opt/splunk/etc/apps/Splunk_TA_windows/default/props.conf
    cp /vagrant/resources/splunk_server/sysmon_ta_props.conf /opt/splunk/etc/apps/TA-microsoft-sysmon/default/props.conf

    # Add custom Macro definitions for ThreatHunting App
    cp /vagrant/resources/splunk_server/macros.conf /opt/splunk/etc/apps/ThreatHunting/default/macros.conf
    # Fix props.conf in ThreatHunting App
    sed -i 's/EVAL-host_fqdn = Computer/EVAL-host_fqdn = ComputerName/g' /opt/splunk/etc/apps/ThreatHunting/default/props.conf
    # Fix Windows TA macros
    mkdir /opt/splunk/etc/apps/Splunk_TA_windows/local
    cp /opt/splunk/etc/apps/Splunk_TA_windows/default/macros.conf /opt/splunk/etc/apps/Splunk_TA_windows/local
    sed -i 's/wineventlog_windows/wineventlog/g' /opt/splunk/etc/apps/Splunk_TA_windows/local/macros.conf
    # Fix Force Directed App until 2.0.1 is released (https://answers.splunk.com/answers/668959/invalid-key-in-stanza-default-value-light.html#answer-669418)
    rm /opt/splunk/etc/apps/force_directed_viz/default/savedsearches.conf

    # Add a Splunk TCP input on port 9997
    echo -e "[splunktcp://9997]\nconnection_host = ip" >/opt/splunk/etc/apps/search/local/inputs.conf
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
    echo -e "[search-tour]\nviewed = 1" >/opt/splunk/etc/system/local/ui-tour.conf
    # Source: https://answers.splunk.com/answers/660728/how-to-disable-the-modal-pop-up-help-us-to-improve.html
    if [ ! -d "/opt/splunk/etc/users/admin/user-prefs/local" ]; then
      mkdir -p "/opt/splunk/etc/users/admin/user-prefs/local"
    fi
    echo '[general]
render_version_messages = 1
dismissedInstrumentationOptInVersion = 4
notification_python_3_impact = false
display.page.home.dashboardId = /servicesNS/nobody/search/data/ui/views/logger_dashboard' >/opt/splunk/etc/users/admin/user-prefs/local/user-prefs.conf
    # Enable SSL Login for Splunk
    echo -e "[settings]\nenableSplunkWebSSL = true" >/opt/splunk/etc/system/local/web.conf
    # Copy over the Logger Dashboard
    if [ ! -d "/opt/splunk/etc/apps/search/local/data/ui/views" ]; then
      mkdir -p "/opt/splunk/etc/apps/search/local/data/ui/views"
    fi
    cp /vagrant/resources/splunk_server/logger_dashboard.xml /opt/splunk/etc/apps/search/local/data/ui/views || echo "Unable to find dashboard"
    # Reboot Splunk to make changes take effect
    /opt/splunk/bin/splunk restart
    /opt/splunk/bin/splunk enable boot-start
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

install_fleet_import_osquery_config() {
  if [ -f "/opt/fleet" ]; then
    echo "[$(date +%H:%M:%S)]: Fleet is already installed"
  else
    cd /opt || exit 1

    echo "[$(date +%H:%M:%S)]: Installing Fleet..."
    echo -e "\n127.0.0.1       fleet" >>/etc/hosts
    echo -e "\n127.0.0.1       logger" >>/etc/hosts

    # Set MySQL username and password, create kolide database
    mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'kolide';"
    mysql -uroot -pkolide -e "create database kolide;"

    # Always download the latest release of Fleet
    curl -s https://api.github.com/repos/fleetdm/fleet/releases/latest | grep 'https://github.com' | grep "/fleet.zip" | cut -d ':' -f 2,3 | tr -d '"' | wget --progress=bar:force -i -
    unzip fleet.zip -d fleet
    cp fleet/linux/fleetctl /usr/local/bin/fleetctl && chmod +x /usr/local/bin/fleetctl
    cp fleet/linux/fleet /usr/local/bin/fleet && chmod +x /usr/local/bin/fleet

    # Prepare the DB
    fleet prepare db --mysql_address=127.0.0.1:3306 --mysql_database=kolide --mysql_username=root --mysql_password=kolide

    # Copy over the certs and service file
    cp /vagrant/resources/fleet/server.* /opt/fleet/
    cp /vagrant/resources/fleet/fleet.service /etc/systemd/system/fleet.service

    mkdir /var/log/fleet

    /bin/systemctl enable fleet.service
    /bin/systemctl start fleet.service

    echo "[$(date +%H:%M:%S)]: Waiting for fleet service to start..."
    while true; do
      result=$(curl --silent -k https://127.0.0.1:8412)
      if echo "$result" | grep -q setup; then break; fi
      sleep 1
    done

    fleetctl config set --address https://192.168.38.105:8412
    fleetctl config set --tls-skip-verify true
    fleetctl setup --email admin@detectionlab.network --username admin --password 'admin123#' --org-name DetectionLab
    fleetctl login --email admin@detectionlab.network --password 'admin123#'

    # Set the enrollment secret to match what we deploy to Windows hosts
    mysql -uroot --password=kolide -e 'use kolide; update enroll_secrets set secret = "enrollmentsecret" where active=1;'
    echo "Updated enrollment secret"

    # Change the query invervals to reflect a lab environment
    # Every hour -> Every 3 minutes
    # Every 24 hours -> Every 15 minutes
    sed -i 's/interval: 3600/interval: 180/g' osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
    sed -i 's/interval: 3600/interval: 180/g' osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
    sed -i 's/interval: 28800/interval: 900/g' osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
    sed -i 's/interval: 28800/interval: 900/g' osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml

    # Don't log osquery INFO messages
    # Fix snapshot event formatting
    fleetctl get options >/tmp/options.yaml
    /usr/bin/yq w -i /tmp/options.yaml 'spec.config.options.enroll_secret' 'enrollmentsecret'
    /usr/bin/yq w -i /tmp/options.yaml 'spec.config.options.logger_snapshot_event_type' 'true'
    fleetctl apply -f /tmp/options.yaml

    # Use fleetctl to import YAML files
    fleetctl apply -f osquery-configuration/Fleet/Endpoints/MacOS/osquery.yaml
    fleetctl apply -f osquery-configuration/Fleet/Endpoints/Windows/osquery.yaml
    for pack in osquery-configuration/Fleet/Endpoints/packs/*.yaml; do
      fleetctl apply -f "$pack"
    done

    # Add Splunk monitors for Fleet
    # Files must exist before splunk will add a monitor
    touch /var/log/fleet/osquery_result
    touch /var/log/fleet/osquery_status
    /opt/splunk/bin/splunk add monitor "/var/log/fleet/osquery_result" -index osquery -sourcetype 'osquery:json' -auth 'admin:changeme' --accept-license --answer-yes --no-prompt
    /opt/splunk/bin/splunk add monitor "/var/log/fleet/osquery_status" -index osquery-status -sourcetype 'osquery:status' -auth 'admin:changeme' --accept-license --answer-yes --no-prompt
  fi
}

install_zeek() {
  echo "[$(date +%H:%M:%S)]: Installing Zeek..."
  # Environment variables
  NODECFG=/opt/zeek/etc/node.cfg
  sh -c "echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_18.04/ /' > /etc/apt/sources.list.d/security:zeek.list"
  wget -nv https://download.opensuse.org/repositories/security:zeek/xUbuntu_18.04/Release.key -O /tmp/Release.key
  apt-key add - </tmp/Release.key &>/dev/null
  # Update APT repositories
  apt-get -qq -ym update
  # Install tools to build and configure Zeek
  apt-get -qq -ym install zeek crudini
  export PATH=$PATH:/opt/zeek/bin
  pip install zkg==2.1.1
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
  ' >>/opt/zeek/share/zeek/site/local.zeek

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

  # Configure the Splunk inputs
  mkdir -p /opt/splunk/etc/apps/Splunk_TA_bro/local && touch /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf
  crudini --set /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf monitor:///opt/zeek/spool/manager index zeek
  crudini --set /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf monitor:///opt/zeek/spool/manager sourcetype bro:json
  crudini --set /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf monitor:///opt/zeek/spool/manager whitelist '.*\.log$'
  crudini --set /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf monitor:///opt/zeek/spool/manager blacklist '.*(communication|stderr)\.log$'
  crudini --set /opt/splunk/etc/apps/Splunk_TA_bro/local/inputs.conf monitor:///opt/zeek/spool/manager disabled 0

  # Ensure permissions are correct and restart splunk
  chown -R splunk:splunk /opt/splunk/etc/apps/Splunk_TA_bro
  /opt/splunk/bin/splunk restart

  # Verify that Zeek is running
  if ! pgrep -f zeek >/dev/null; then
    echo "Zeek attempted to start but is not running. Exiting"
    exit 1
  fi
}

install_velociraptor() {
  echo "[$(date +%H:%M:%S)]: Installing Velociraptor..."
  if [ ! -d "/opt/velociraptor" ]; then
    mkdir /opt/velociraptor
  fi
  echo "[$(date +%H:%M:%S)]: Attempting to determine the URL for the latest release of Velociraptor"
  LATEST_VELOCIRAPTOR_LINUX_URL=$(curl -sL https://github.com/Velocidex/velociraptor/releases/latest | grep linux-amd64 | grep href | head -1 | cut -d '"' -f 2 | sed 's#^#https://github.com#g')
  echo "[$(date +%H:%M:%S)]: The URL for the latest release was extracted as $LATEST_VELOCIRAPTOR_LINUX_URL"
  echo "[$(date +%H:%M:%S)]: Attempting to download..."
  wget -P /opt/velociraptor --progress=bar:force "$LATEST_VELOCIRAPTOR_LINUX_URL"
  if [ "$(file /opt/velociraptor/velociraptor*linux-amd64 | grep -c 'ELF 64-bit LSB executable')" -eq 1 ]; then
    echo "[$(date +%H:%M:%S)]: Velociraptor successfully downloaded!"
  else
    echo "[$(date +%H:%M:%S)]: Failed to download the latest version of Velociraptor. Please open a DetectionLab issue on Github."
    return
  fi

  cd /opt/velociraptor || exit 1
  mv velociraptor-*-linux-amd64 velociraptor
  chmod +x velociraptor
  cp /vagrant/resources/velociraptor/server.config.yaml /opt/velociraptor
  echo "[$(date +%H:%M:%S)]: Creating Velociraptor dpkg..."
  ./velociraptor --config /opt/velociraptor/server.config.yaml debian server
  echo "[$(date +%H:%M:%S)]: Installing the dpkg..."
  if dpkg -i velociraptor_*_server.deb >/dev/null; then
    echo "[$(date +%H:%M:%S)]: Installation complete!"
  else
    echo "[$(date +%H:%M:%S)]: Failed to install the dpkg"
    return
  fi
}

install_suricata() {
  # Run iwr -Uri testmyids.com -UserAgent "BlackSun" in Powershell to generate test alerts from Windows
  echo "[$(date +%H:%M:%S)]: Installing Suricata..."

  # Install suricata
  apt-get -qq -y install suricata crudini
  test_suricata_prerequisites
  # Install suricata-update
  cd /opt || exit 1
  git clone https://github.com/OISF/suricata-update.git
  cd /opt/suricata-update || exit 1
  pip install pyyaml
  python setup.py install

  cp /vagrant/resources/suricata/suricata.yaml /etc/suricata/suricata.yaml
  crudini --set --format=sh /etc/default/suricata '' iface eth1
  # update suricata signature sources
  suricata-update update-sources
  # disable protocol decode as it is duplicative of Zeek
  echo re:protocol-command-decode >>/etc/suricata/disable.conf
  # enable et-open and attackdetection sources
  suricata-update enable-source et/open
  suricata-update enable-source ptresearch/attackdetection

  # Configure the Splunk inputs
  mkdir -p /opt/splunk/etc/apps/SplunkLightForwarder/local && touch /opt/splunk/etc/apps/SplunkLightForwarder/local/inputs.conf
  crudini --set /opt/splunk/etc/apps/SplunkLightForwarder/local/inputs.conf monitor:///var/log/suricata index suricata
  crudini --set /opt/splunk/etc/apps/SplunkLightForwarder/local/inputs.conf monitor:///var/log/suricata sourcetype suricata:json
  crudini --set /opt/splunk/etc/apps/SplunkLightForwarder/local/inputs.conf monitor:///var/log/suricata whitelist 'eve.json'
  crudini --set /opt/splunk/etc/apps/SplunkLightForwarder/local/inputs.conf monitor:///var/log/suricata disabled 0
  crudini --set /opt/splunk/etc/apps/SplunkLightForwarder/local/props.conf json_suricata TRUNCATE 0

  # Update suricata and restart
  suricata-update
  service suricata stop
  service suricata start
  sleep 3

  # Verify that Suricata is running
  if ! pgrep -f suricata >/dev/null; then
    echo "Suricata attempted to start but is not running. Exiting"
    exit 1
  fi

  cat >/etc/logrotate.d/suricata <<EOF
/var/log/suricata/*.log /var/log/suricata/*.json
{
    hourly
    rotate 0
    missingok
    nocompress
    size=500M
    sharedscripts
    postrotate
            /bin/kill -HUP \`cat /var/run/suricata.pid 2>/dev/null\` 2>/dev/null || true
    endscript
}
EOF

}

test_suricata_prerequisites() {
  for package in suricata crudini; do
    echo "[$(date +%H:%M:%S)]: [TEST] Validating that $package is correctly installed..."
    # Loop through each package using dpkg
    if ! dpkg -S $package >/dev/null; then
      # If which returns a non-zero return code, try to re-install the package
      echo "[-] $package was not found. Attempting to reinstall."
      apt-get clean && apt-get -qq update && apt-get install -y $package
      if ! which $package >/dev/null; then
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
  cd /opt || exit 1
  apt-get -qq install -y libcairo2-dev libjpeg62-dev libpng-dev libossp-uuid-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libssh-dev tomcat8 tomcat8-admin tomcat8-user
  wget --progress=bar:force "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/source/guacamole-server-1.0.0.tar.gz" -O guacamole-server-1.0.0.tar.gz
  tar -xf guacamole-server-1.0.0.tar.gz && cd guacamole-server-1.0.0 || echo "[-] Unable to find the Guacamole folder."
  ./configure &>/dev/null && make --quiet &>/dev/null && make --quiet install &>/dev/null || echo "[-] An error occurred while installing Guacamole."
  ldconfig
  cd /var/lib/tomcat8/webapps || echo "[-] Unable to find the tomcat8/webapps folder."
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
  echo export PATH="$PATH:/opt/splunk/bin:/opt/zeek/bin" >>~/.bashrc
  echo "export SPLUNK_HOME=/opt/splunk" >>~/.bashrc
  # Ping DetectionLab server for usage statistics
  curl -s -A "DetectionLab-logger" "https:/ping.detectionlab.network/logger" || echo "Unable to connect to ping.detectionlab.network"
}

main() {
  apt_install_prerequisites
  modify_motd
  test_prerequisites
  fix_eth1_static_ip
  install_splunk
  download_palantir_osquery_config
  install_fleet_import_osquery_config
  install_velociraptor
  install_suricata
  install_zeek
  install_guacamole
  postinstall_tasks
}

main
exit 0
