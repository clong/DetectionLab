install_securityonion() {
  if grep -q '# Added for Security Onion' /etc/network/interfaces; then
    echo "Security Onion is already installed... Skipping"
  else
    export DEBIAN_FRONTEND=noninteractive
    # Add local proxy if file exists
    if [ -f /vagrant/resources/securityonion/00proxy ]; then
      cp /vagrant/resources/securityonion/00proxy /etc/apt/apt.conf.d/00proxy
    fi
    rm -rf /var/lib/apt/lists/*
    apt update -y
    apt-get install -y software-properties-common linux-headers-$(uname -r) bash-completion
    add-apt-repository -y ppa:securityonion/stable
    apt-get update -y
    apt-get -y install securityonion-iso syslog-ng
    # Add docker registry if file exists
    if [ -f /vagrant/resources/securityonion/daemon.json ]; then
      mkdir /etc/docker
      cp /vagrant/resources/securityonion/daemon.json /etc/docker/daemon.json
    fi
    sed -i '1 s|^|# Added for Security Onion\n|' /etc/network/interfaces
    echo "yes" | sosetup -f /vagrant/resources/securityonion/sosetup.conf
    ufw allow proto tcp from 192.168.38.1 to any port 22,443,7734
    echo "" | so-desktop-gnome
  fi
}

configure_suricata() {
  if [[ $(sed -n '79s/yes/&/p' /etc/nsm/securityonion-eth2/suricata.yaml | grep yes)  ]]; then
    echo "Suricata yaml is already adjusted... Skipping"
  else
    # Configure suricata to generate eve.json, enable some things, disable some others...
    sed -i -e '79s|\(\ \+enabled:\)\ no|\1 yes|' -e '143,149s|\ #||' -e '154,246s|^|#|' /etc/nsm/securityonion-eth2/suricata.yaml
  fi
}

install_splunkforwarder() {
  if [ -f "/lib/systemd/system/splunk.service" ]; then
    echo "Splunk Universal Forwarder is already installed... Skipping"
  else
    # Download & install splunk universal forwarder
    echo "Installing Splunk Universal Forwarder..."
    wget --progress=bar:force -O splunkforwarder-7.2.1-be11b2c46e23-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.1&product=universalforwarder&filename=splunkforwarder-7.2.1-be11b2c46e23-linux-2.6-amd64.deb&wget=true'
    dpkg -i splunkforwarder-7.2.1-be11b2c46e23-linux-2.6-amd64.deb
    # Add a Systemd service for Splunk Universal Forwarder
    cp /vagrant/resources/securityonion/splunk.service /lib/systemd/system/splunk.service
    systemctl enable splunk.service
    /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme
  fi
}

install_splunkta() {
  if [ -d /opt/splunkforwarder/etc/apps/TA-bro_json ]; then
    echo "Bro Splunk TA is already installed... Skipping"
  else
    SPLUNK_BRO_JSON=/opt/splunkforwarder/etc/apps/TA-bro_json
    SPLUNK_SURICATA_MONITOR='[monitor:///nsm/sensor_data/securityonion-eth2]'
    # Setup security onion to send bro and suricata data to splunk
    git clone https://github.com/jahshuah/splunk-ta-bro-json $SPLUNK_BRO_JSON

    mkdir -p $SPLUNK_BRO_JSON/local
    cp $SPLUNK_BRO_JSON/default/inputs.conf $SPLUNK_BRO_JSON/local/inputs.conf
    sed -i -e 's|opt|nsm|' -e 's|1$|0|' $SPLUNK_BRO_JSON/local/inputs.conf
    echo -e "\n$SPLUNK_SURICATA_MONITOR
index = suricata
sourcetype = json_suricata
whitelist = eve.json
disabled = 0" >> $SPLUNK_BRO_JSON/local/inputs.conf

    # Ensure permissions are correct and restart splunk
    chown -R splunk $SPLUNK_BRO_JSON
    /opt/splunkforwarder/bin/splunk add forward-server 192.168.38.105:9997 -auth admin:changeme
    systemctl restart splunk.service
  fi
}

main() {
  install_securityonion
  configure_suricata
  install_splunkforwarder
  install_splunkta
  #future addition
}

main
exit 0
