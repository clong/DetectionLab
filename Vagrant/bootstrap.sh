#! /bin/bash

install_mongo_db_apt_key() {
  # Install key and apt source for MongoDB
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
  echo "deb http://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
}

apt_install_prerequisites() {
  # Install prerequisites and useful tools
  apt-get update
  apt-get install -y jq whois build-essential git docker docker-compose unzip mongodb-org
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
      echo "The static IP has been fixed and set to 192.168.38.105"
    else
      echo "Failed to fix the broken static IP for eth1. Exiting because this will cause problems with other VMs."
      exit 1
    fi
  fi
}

install_python() {
  # Install Python 3.6.4
  if ! which /usr/local/bin/python3.6 > /dev/null; then
    echo "Installing Python v3.6.4..."
    wget https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tgz
    tar -xvf Python-3.6.4.tgz
    cd Python-3.6.4 || exit
    ./configure && make && make install
    cd /home/vagrant || exit
  else
    echo "Python seems to be downloaded already.. Skipping."
  fi
}

install_golang() {
  if [ ! -f "go1.8.linux-amd64.tar.gz" ]; then
    # Install Golang v1.8
    echo "Installing GoLang v1.8..."
    wget https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz
    tar -xvf go1.8.linux-amd64.tar.gz
    mv go /usr/local
    mkdir /home/vagrant/.go
    chown vagrant:vagrant /home/vagrant/.go
    mkdir /root/.go
    echo 'export GOPATH=$HOME/.go' >> /home/vagrant/.
    echo 'export GOROOT=/usr/local/go' >> /home/vagrant/.bashrc
    echo 'export GOPATH=$HOME/.go' >> /root/.bashrc
    echo 'export GOROOT=/usr/local/go' >> /root/.bashrc
    echo 'export PATH=$PATH:/opt/splunk/bin' >> /root/.bashrc
    source /root/.bashrc
    sudo update-alternatives --install "/usr/bin/go" "go" "/usr/local/go/bin/go" 0
    sudo update-alternatives --set go /usr/local/go/bin/go
    /usr/bin/go get -u github.com/howeyc/gopass
  else
    echo "GoLang seems to be downloaded already.. Skipping."
  fi
}

install_splunk() {
  # Check if Splunk is already installed
  if [ -f "/opt/splunk/bin/splunk" ]; then
    echo "Splunk is already installed"
  else
    echo "Installing Splunk..."
    # Get Splunk.com into the DNS cache. Sometimes resolution randomly fails during wget below
    dig @8.8.8.8 splunk.com
    # Download Splunk
    wget --progress=bar:force -O splunk-7.1.2-a0c72a66db66-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.1.2&product=splunk&filename=splunk-7.1.2-a0c72a66db66-linux-2.6-amd64.deb&wget=true'
    dpkg -i splunk-7.1.2-a0c72a66db66-linux-2.6-amd64.deb
    /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme
    /opt/splunk/bin/splunk add index wineventlog -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index osquery-status -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index sysmon -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index powershell -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index bro -auth 'admin:changeme'
    /opt/splunk/bin/splunk add index suricata -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_500.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/add-on-for-microsoft-sysmon_800.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/asn-lookup-generator_012.tgz -auth 'admin:changeme'
    # Add a Splunk TCP input on port 9997
    echo -e "[splunktcp://9997]\nconnection_host = ip" > /opt/splunk/etc/apps/search/local/inputs.conf
    # Add props.conf and transforms.conf
    cp /vagrant/resources/splunk_server/props.conf /opt/splunk/etc/apps/search/local/
    cp /vagrant/resources/splunk_server/transforms.conf /opt/splunk/etc/apps/search/local/
    cp /opt/splunk/etc/system/default/limits.conf /opt/splunk/etc/system/local/limits.conf
    # Bump the memtable limits to allow for the ASN lookup table
    sed -i.bak 's/max_memtable_bytes = 10000000/max_memtable_bytes = 30000000/g' /opt/splunk/etc/system/local/limits.conf
    # Skip Splunk Tour and Change Password Dialog
    touch /opt/splunk/etc/.ui_login
    # Enable SSL Login for Splunk
    echo '[settings]
    enableSplunkWebSSL = true' > /opt/splunk/etc/system/local/web.conf
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
    echo "Fleet is already installed"
  else
    echo "Installing Fleet..."
    echo -e "\n127.0.0.1       kolide" >> /etc/hosts
    git clone https://github.com/kolide/kolide-quickstart.git
    cd kolide-quickstart || echo "Something went wrong while trying to clone the kolide-quickstart repository"
    cp /vagrant/resources/fleet/server.* .
    sed -i 's/ -it//g' demo.sh
    sed -i 's#kolide/fleet:latest#kolide/fleet:1.0.8#g' docker-compose.yml
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
    echo "osquery configs have already been downloaded"
  else
    # Import Palantir osquery configs into Fleet
    echo "Downloading Palantir configs..."
    git clone https://github.com/palantir/osquery-configuration.git
    git clone https://github.com/kolide/configimporter.git
    cd configimporter || exit
    go build
    cd /home/vagrant || exit
  fi
}

import_osquery_config_into_fleet() {
  if [ -f "/home/vagrant/osquery-configuration/Endpoints/Windows/osquery_to_import.conf" ]; then
    echo "The osquery configuration has already been imported into Fleet"
  else
    # Modify the config to work with config importer
    cat /home/vagrant/osquery-configuration/Endpoints/Windows/osquery.conf  | sed 's#packs/#../packs/#g' | grep -v unwanted-chrome-extensions | grep -v security-tooling-checks | grep -v performance-metrics | grep -v logger_snapshot_event_type > /home/vagrant/osquery-configuration/Endpoints/Windows/osquery_to_import.conf
    # Install configimporter
    echo "Installing configimporter"
    echo "Sleeping for 5"
    sleep 5
    export CONFIGIMPORTER_PASSWORD='admin123#'
    cd /home/vagrant/osquery-configuration/Endpoints/Windows/ || exit
    # Fleet requires you to login before importing packs
    # Login
    curl 'https://192.168.38.105:8412/api/v1/kolide/login' -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/login' -H 'authority: 192.168.38.105:8412' --data-binary '{"username":"admin","password":"admin123#"}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.105:8412/setup' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'authority: 192.168.38.105:8412' --compressed --insecure
    sleep 1
    # Setup organization name and email address
    curl 'https://192.168.38.105:8412/api/v1/setup' -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/setup' -H 'authority: 192.168.38.105:8412' --data-binary '{"kolide_server_url":"https://192.168.38.105:8412","org_info":{"org_name":"detectionlab"},"admin":{"admin":true,"email":"example@example.com","password":"admin123#","password_confirmation":"admin123#","username":"admin"}}' --compressed --insecure
    sleep 3
    # Import all Windows configs
    /home/vagrant/configimporter/configimporter -host https://localhost:8412 -user 'admin' -config osquery_to_import.conf

    # Get auth token
    TOKEN=$(curl 'https://192.168.38.105:8412/api/v1/kolide/login' -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/login' -H 'authority: 192.168.38.105:8412' --data-binary '{"username":"admin","password":"admin123#"}' --compressed --insecure | grep token | cut -d '"' -f 4)
    # Set all packs to be targeted to Windows hosts
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/1' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/3/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/2' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/3/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/3' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/3/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/4' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/3/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/5' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/3/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    # Rename primary pack
    curl 'https://192.168.38.105:8412/api/v1/kolide/packs/5' -X PATCH -H 'origin: https://192.168.38.105:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.105:8412/packs/5/edit' -H 'authority: 192.168.38.105:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"name":"windows-pack"}' --compressed --insecure
    # Add Splunk monitors for Fleet
    /opt/splunk/bin/splunk add monitor "/home/vagrant/kolide-quickstart/osquery_result" -index osquery -sourcetype 'osquery:json' -auth 'admin:changeme'
    /opt/splunk/bin/splunk add monitor "/home/vagrant/kolide-quickstart/osquery_status" -index osquery-status -sourcetype 'osquery:status' -auth 'admin:changeme'
  fi
}

install_caldera() {
  if [ -f "/lib/systemd/system/caldera.service" ]; then
    echo "Caldera is already installed... Skipping"
  else
    # Install Mitre's Caldera
    echo "Installing Caldera..."
    cd /home/vagrant || exit
    git clone https://github.com/mitre/caldera.git
    cd /home/vagrant/caldera/caldera || exit
    pip3.6 install -r requirements.txt

    # Add a Systemd service for MongoDB
    # https://www.howtoforge.com/tutorial/install-mongodb-on-ubuntu-16.04/
    cp /vagrant/resources/caldera/mongod.service /lib/systemd/system/mongod.service
    # Create Systemd service for Caldera
    cp /vagrant/resources/caldera/caldera.service /lib/systemd/system/caldera.service
    # Enable replication
    echo 'replication:
    replSetName: caldera' >> /etc/mongod.conf
    service mongod start
    systemctl enable mongod.service
    cd /home/vagrant/caldera || exit
    mkdir -p dep/crater/crater
    wget https://github.com/mitre/caldera-crater/releases/download/v0.1.0/CraterMainWin8up.exe -O /home/vagrant/caldera/dep/crater/crater/CraterMain.exe
    service caldera start
    systemctl enable caldera.service
  fi
}

install_bro() {
  # Environment variables
  NODECFG=/opt/bro/etc/node.cfg
  SPLUNK_BRO_JSON=/opt/splunk/etc/apps/TA-bro_json
  SPLUNK_BRO_MONITOR='monitor:///opt/bro/spool/manager'
  SPLUNK_SURICATA_MONITOR='monitor:///var/log/suricata'
  echo "deb http://download.opensuse.org/repositories/network:/bro/xUbuntu_16.04/ /" > /etc/apt/sources.list.d/bro.list
  curl -s http://download.opensuse.org/repositories/network:/bro/xUbuntu_16.04/Release.key |apt-key add -

  # Update APT repositories
  apt-get -qq -ym update
  # Install tools to build and configure bro
  apt-get -qq -ym install bro crudini
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

  # Install yq to maniuplate the suricata.yaml inline
  /usr/bin/go get -u  github.com/mikefarah/yq
  # Install suricata
  add-apt-repository -y ppa:oisf/suricata-stable
  apt-get -qq -y update && apt-get -qq -y install suricata crudini
  # Install suricata-update
  cd /home/vagrant || exit 1
  git clone https://github.com/OISF/suricata-update.git
  cd /home/vagrant/suricata-update || exit 1
  python setup.py install
  # Add DC_SERVERS variable to suricata.yaml in support et-open signatures
  /root/go/bin/yq w  -i /etc/suricata/suricata.yaml vars.address-groups.DC_SERVERS '$HOME_NET'

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

main() {
  install_mongo_db_apt_key
  apt_install_prerequisites
  fix_eth1_static_ip
  install_python
  install_golang
  install_splunk
  install_fleet
  download_palantir_osquery_config
  import_osquery_config_into_fleet
  install_caldera
  install_suricata
  install_bro
}

main
exit 0
