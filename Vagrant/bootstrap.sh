#! /bin/bash

# Install prerequisites and useful tools
apt-get update
apt-get install -y jq whois build-essential git docker docker-compose unzip

# Install Golang v1.8
wget https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz
tar -xvf go1.8.linux-amd64.tar.gz
mv go /usr/local
mkdir /home/vagrant/.go
chown vagrant:vagrant /home/vagrant/.go
mkdir /root/.go
echo 'export GOPATH=$HOME/.go' >> /home/vagrant/.bashrc
echo 'export GOROOT=/usr/local/go' >> /home/vagrant/.bashrc
echo 'export GOPATH=$HOME/.go' >> /root/.bashrc
echo '/home/vagrant/.bashrc' >> /root/.bashrc
source ~/.bashrc
sudo update-alternatives --install "/usr/bin/go" "go" "/usr/local/go/bin/go" 0
sudo update-alternatives --set go /usr/local/go/bin/go
/usr/bin/go get -u github.com/howeyc/gopass

# Check if Splunk is already installed
if [ -f "/opt/splunk/bin/splunk" ]
  then echo "Splunk is already installed"
else
  # Get Splunk.com into the DNS cache. Sometimes resolution randomly fails during wget below
  dig @8.8.8.8 splunk.com
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
  # Enable SSL Login for Splunk
  echo '[settings]
  enableSplunkWebSSL = true' > /opt/splunk/etc/system/local/web.conf
  # Reboot Splunk to make changes take effect
  /opt/splunk/bin/splunk restart
  /opt/splunk/bin/splunk enable boot-start
fi

# Install Fleet
echo -e "\n127.0.0.1       kolide" >> /etc/hosts
git clone https://github.com/kolide/kolide-quickstart.git
cd kolide-quickstart
cp /vagrant/resources/fleet/server.* .
sed -i 's/ -it//g' demo.sh
./demo.sh up simple
# Set the enrollment secret to match what we deploy to Windows hosts
docker run --rm --network=kolidequickstart_default mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'update app_configs set osquery_enroll_secret = "enrollmentsecret" where id=1;' --batch kolide
echo "Updated enrollment secret"
cd /home/vagrant

# Import Palantir osquery configs
echo "Downloading Palantir configs"
git clone https://github.com/palantir/osquery-configuration.git
git clone https://github.com/kolide/configimporter.git
cd configimporter
go build
cd /home/vagrant

# Modify the config to work with config importer
cat /home/vagrant/osquery-configuration/Endpoints/Windows/osquery.conf  | sed 's#packs/#../packs/#g' | grep -v unwanted-chrome-extensions | grep -v security-tooling-checks | grep -v performance-metrics > /home/vagrant/osquery-configuration/Endpoints/Windows/osquery_to_import.conf
# Install configimporter
echo "Installing configimporter"
echo "Sleeping for 5"
sleep 5
export CONFIGIMPORTER_PASSWORD='admin123#'
cd /home/vagrant/osquery-configuration/Endpoints/Windows/
# Login
echo "Login curl"
curl 'https://192.168.38.5:8412/api/v1/kolide/login' -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/login' -H 'authority: 192.168.38.5:8412' --data-binary '{"username":"admin","password":"admin123#"}' --compressed --insecure
sleep 3
echo "Get setup curl"
curl 'https://192.168.38.5:8412/setup' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'authority: 192.168.38.5:8412' --compressed --insecure
sleep 3
echo "Post setup curl"
curl 'https://192.168.38.5:8412/api/v1/setup' -H 'origin: https://192.168.38.5:8412' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36' -H 'content-type: application/json' -H 'accept: application/json' -H 'referer: https://192.168.38.5:8412/setup' -H 'authority: 192.168.38.5:8412' --data-binary '{"kolide_server_url":"https://192.168.38.5:8412","org_info":{"org_name":"org"},"admin":{"admin":true,"email":"example@example.com","password":"admin123#","password_confirmation":"admin123#","username":"admin"}}' --compressed --insecure
sleep 3
# Import all Windows configs
/home/vagrant/configimporter/configimporter -host https://localhost:8412 -user 'admin' -config osquery_to_import.conf
