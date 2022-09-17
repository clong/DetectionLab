#! /usr/bin/env bash

# This script is run on the Packet.net baremetal server for CI tests.
# While building, the server will start a webserver on Port 80 that contains
# the text "building". Once the test is completed, the text will be replaced
# with "success" or "failed".

export DEBIAN_FRONTEND=noninteractive
# Bypass prompt for libsslv1.1 https://unix.stackexchange.com/a/543706
echo 'libssl1.1:amd64 libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Disable IPv6 - may help with the vagrant-reload plugin: https://github.com/hashicorp/vagrant/issues/8795#issuecomment-468945063
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null

# Install Virtualbox 6.1
echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
echo "[$(date +%H:%M:%S)]: Running apt-get update..."
apt-get -qq update
echo "[$(date +%H:%M:%S)]: Running apt-get install..."
apt-get -qq install -y linux-headers-"$(uname -r)" virtualbox-6.1 build-essential unzip git ufw apache2 vagrant

echo "building" > /var/www/html/index.html

# Set up firewall
ufw allow ssh
ufw allow http
ufw default allow outgoing
ufw --force enable

echo "[$(date +%H:%M:%S)]: Installing vagrant-reload plugin..."
vagrant plugin install vagrant-reload

# Make sure the plugin installed correctly. Retry if not.
if [ "$(vagrant plugin list | grep -c vagrant-reload)" -ne "1" ]; then
  echo "[$(date +%H:%M:%S)]: The first attempt to install the vagrant-reload plugin failed. Trying again."
  vagrant plugin install vagrant-reload
fi

# Re-enable IPv6 - may help with the Vagrant Cloud slowness
echo "net.ipv6.conf.all.disable_ipv6=0" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null

## Git Clone DL (Only needed when manually building)
#git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile
cd /opt/DetectionLab/Vagrant/Exchange || exit 1
sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile
cd /opt/DetectionLab/Vagrant || exit 1

# Recreate a barebones version of the build script so we have some sense of return codes
cat << 'EOF' > /opt/DetectionLab/build.sh
#! /usr/bin/env bash
build_vagrant_hosts() {
  # Kick off builds for logger and dc
  cd "$DL_DIR"/Vagrant || exit 1
  for HOST in logger dc; do
    (vagrant up $HOST &>"$DL_DIR/Vagrant/vagrant_up_$HOST.log" || vagrant reload $HOST --provision &>"$DL_DIR/Vagrant/vagrant_up_$HOST.log") &
    declare ${HOST}_PID=$!
  done
  # We only have to wait for DC to create the domain before kicking off wef and win10 builds
  DC_CREATION_TIMEOUT=30
  MINUTES_PASSED=0
  while ! grep 'I am domain joined!' "$DL_DIR/Vagrant/vagrant_up_dc.log" >/dev/null; do
    (echo >&2 "[$(date +%H:%M:%S)]: Waiting for DC to complete creation of the domain...")
    sleep 60
    ((MINUTES_PASSED += 1))
    if [ "$MINUTES_PASSED" -gt "$DC_CREATION_TIMEOUT" ]; then
      (echo >&2 "Timed out waiting for DC to create the domain controller. Exiting.")
      exit 1
    fi
  done
  # Kick off builds for wef and win10
  cd "$DL_DIR"/Vagrant || exit 1
  for HOST in wef win10; do
    (vagrant up $HOST &>>"$DL_DIR/Vagrant/vagrant_up_$HOST.log" || vagrant reload $HOST --provision &>>"$DL_DIR/Vagrant/vagrant_up_$HOST.log") &
    declare ${HOST}_PID=$!
  done
  # Wait for all the builds to finish
  # shellcheck disable=SC2154
  while ps -p "$logger_PID" >/dev/null || ps -p "$dc_PID" >/dev/null || ps -p "$wef_PID" >/dev/null || ps -p "$win10_PID" >/dev/null; do
    (echo >&2 "[$(date +%H:%M:%S)]: Waiting for all of the hosts to finish provisioning...")
    sleep 60
  done
  ### This code is absolutely terrible. Fix it at some point when I'm less lazy
  for HOST in logger dc wef win10; do
    if [[ "$HOST" == "logger" ]]; then
      if grep 'logger: OK' "$DL_DIR/Vagrant/vagrant_up_$HOST.log" > /dev/null; then
        (echo >&2 "[$(date +%H:%M:%S)]: $HOST was built successfully!")
      else
        (echo >&2 "Failed to bring up $HOST after a reload. Exiting")
        exit 1
      fi
    else 
      if grep -i "$HOST: $HOST Provisioning Complete!" "$DL_DIR/Vagrant/vagrant_up_$HOST.log" > /dev/null; then
        (echo >&2 "[$(date +%H:%M:%S)]: $HOST was built successfully!")
      else
        (echo >&2 "Failed to bring up $HOST after a reload. Exiting")
        exit 1
      fi
    fi
  done
}

main() {
  # Get location of build.sh
  # https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
  DL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Build and Test Vagrant hosts
  cd Vagrant || exit 1
  build_vagrant_hosts
  /bin/bash "$DL_DIR/Vagrant/post_build_checks.sh" &> $DL_DIR/Vagrant/post_build.log
  exit 0
}
main
EOF
chmod +x /opt/DetectionLab/build.sh

# Start the build in a tmux session
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux send-keys -t "$sn:0" 'cd /opt/DetectionLab && ./build.sh && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html' Enter
# tmux new-window -t "$sn:2" -n "exchange" -d
# tmux send-keys -t "$sn:2" 'cd /opt/DetectionLab/Vagrant/Exchange && vagrant up' Enter