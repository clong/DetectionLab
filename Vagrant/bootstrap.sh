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
  # that eth1 has a static IP set. We workaround this by telling dhclient to leave it alone.
  echo 'interface "eth1" {}' >> /etc/dhcp/dhclient.conf
  systemctl restart networking.service
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
  if [ "$ETH1_IP" != "192.168.38.5" ]; then
    echo "Incorrect IP Address settings detected. Attempting to fix."
    ifdown eth1
    ip addr flush dev eth1
    ifup eth1
    ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ "$ETH1_IP" == "192.168.38.5" ]; then
      echo "The static IP has been fixed and set to 192.168.38.5"
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
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_forwarder/splunk-add-on-for-microsoft-windows_500.tgz -auth 'admin:changeme'
    /opt/splunk/bin/splunk install app /vagrant/resources/splunk_server/add-on-for-microsoft-sysmon_800.tgz -auth 'admin:changeme'
    # Add a Splunk TCP input on port 9997
    echo -e "[splunktcp://9997]\nconnection_host = ip" > /opt/splunk/etc/apps/search/local/inputs.conf
    # Add props.conf and transforms.conf
    cp /vagrant/resources/splunk_server/props.conf /opt/splunk/etc/apps/search/local/
    cp /vagrant/resources/splunk_server/transforms.conf /opt/splunk/etc/apps/search/local/
    # Skip Splunk Tour and Change Password Dialog
    touch /opt/splunk/etc/.ui_login
    # Enable SSL Login for Splunk
    echo '[settings]
    enableSplunkWebSSL = true' > /opt/splunk/etc/system/local/web.conf
    # Reboot Splunk to make changes take effect
    /opt/splunk/bin/splunk restart
    /opt/splunk/bin/splunk enable boot-start
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
    curl 'https://192.168.38.5:8412/api/v1/kolide/login' -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/login' -H 'authority: 192.168.38.5:8412' --data-binary '{"username":"admin","password":"admin123#"}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.5:8412/setup' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'authority: 192.168.38.5:8412' --compressed --insecure
    sleep 1
    # Setup organization name and email address
    curl 'https://192.168.38.5:8412/api/v1/setup' -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/setup' -H 'authority: 192.168.38.5:8412' --data-binary '{"kolide_server_url":"https://192.168.38.5:8412","org_info":{"org_name":"detectionlab"},"admin":{"admin":true,"email":"example@example.com","password":"admin123#","password_confirmation":"admin123#","username":"admin"}}' --compressed --insecure
    sleep 3
    # Import all Windows configs
    /home/vagrant/configimporter/configimporter -host https://localhost:8412 -user 'admin' -config osquery_to_import.conf

    # Get auth token
    TOKEN=$(curl 'https://192.168.38.5:8412/api/v1/kolide/login' -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/login' -H 'authority: 192.168.38.5:8412' --data-binary '{"username":"admin","password":"admin123#"}' --compressed --insecure | grep token | cut -d '"' -f 4)
    # Set all packs to be targeted to Windows hosts
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/1' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/3/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/2' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/3/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/3' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/3/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/4' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/3/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    sleep 1
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/5' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/3/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"label_ids":[10]}' --compressed --insecure
    # Rename primary pack
    curl 'https://192.168.38.5:8412/api/v1/kolide/packs/5' -X PATCH -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/packs/5/edit' -H 'authority: 192.168.38.5:8412' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' --data-binary '{"name":"windows-pack"}' --compressed --insecure
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
}

main
exit 0
