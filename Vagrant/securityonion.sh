install_securityonion() {
  export DEBIAN_FRONTEND=noninteractive
  # Add local proxy if file exists
  if [ -f /vagrant/resources/securityonion/00proxy ]; then
    cp /vagrant/resources/securityonion/00proxy /etc/apt/apt.conf.d/00proxy
  fi
  rm -rf /var/lib/apt/lists/*
  apt update -y
  apt-get install -y software-properties-common linux-headers-$(uname -r)
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
  echo "" | so-desktop-gnome
}

   main() {
     install_securityonion
     #future addition
   }

   main
   exit 0
