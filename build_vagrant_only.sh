#! /bin/bash

# This script skips the entire Packer box building process.
# This script downloads pre-built VirtualBox Packer images from S3 and puts
# them into the "Boxes" directory.
# Only MacOS and Linux are supported.
# If you encounter issues, feel free to open an issue at
# https://github.com/clong/DetectionLab/issues

set -e

print_usage() {
  echo "Usage: ./build.sh <virtualbox|vmware_fusion>"
  exit 0
}

check_vagrant() {
  # Check for existence of Vagrant in PATH
  if ! which vagrant >/dev/null; then
    (echo >&2 "Vagrant was not found in your PATH.")
    (echo >&2 "Please correct this before continuing. Quitting.")
    exit 1
  fi
  # Ensure Vagrant >= 2.0.0
  if [ "$(vagrant --version | grep -o "[0-9]" | head -1)" -lt 2 ]; then
    (echo >&2 "WARNING: It is highly recommended to use Vagrant 2.0.0 or above before continuing")
  fi
}

# Returns 0 if not installed or 1 if installed
check_virtualbox_installed() {
  if ! which VBoxManage >/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_fusion_installed() {
  if [ -e "/Applications/VMware Fusion.app" ]; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_vagrant_plugin_installed() {
  VAGRANT_VMWARE_PLUGIN_PRESENT="$(vagrant plugin list | grep -c 'vagrant-vmware-fusion')"
  if [ "$VAGRANT_VMWARE_PLUGIN_PRESENT" -eq 0 ]; then
    (echo >&2 "VMWare Fusion is installed, but the Vagrant plugin is not.")
    (echo >&2 "Visit https://www.vagrantup.com/vmware/index.html#buy-now for more information on how to purchase and install it")
    (echo >&2 "VMWare Fusion will not be listed as a provider until the Vagrant plugin has been installed.")
    echo "0"
  else
    echo "$VAGRANT_VMWARE_PLUGIN_PRESENT"
  fi
}

# List the available Vagrant providers present on the system
list_providers() {
  VBOX_PRESENT=0
  VMWARE_FUSION_PRESENT=0

  if [ "$(uname)" == "Darwin" ]; then
    # Detect Providers on OSX
    VBOX_PRESENT=$(check_virtualbox_installed)
    VMWARE_FUSION_PRESENT=$(check_vmware_fusion_installed)
    VAGRANT_VMWARE_PLUGIN_PRESENT=$(check_vmware_vagrant_plugin_installed)
  else
    # Assume the only other available provider is VirtualBox
    VBOX_PRESENT=$(check_virtualbox_installed)
  fi

  (echo >&2 "Available Providers:")
  if [ "$VBOX_PRESENT" == "1" ]; then
    (echo >&2 "virtualbox")
  fi
  if [[ $VMWARE_FUSION_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_PLUGIN_PRESENT -eq 1 ]]; then
    (echo >&2 "vmware_fusion")
  fi
  if [[ $VBOX_PRESENT -eq 0 ]] && [[ $VMWARE_FUSION_PRESENT -eq 0 ]]; then
    (echo >&2 "You need to install a provider such as VirtualBox or VMware Fusion to continue.")
    exit 1
  fi
  (echo >&2 -e "\\nWhich provider would you like to use?")
  read -r PROVIDER
  # Sanity check
  if [[ "$PROVIDER" != "virtualbox" ]] && [[ "$PROVIDER" != "vmware_fusion" ]]; then
    (echo >&2 "Please choose a valid provider. \"$PROVIDER\" is not a valid option")
    exit 1
  fi
  echo "$PROVIDER"
}

# A series of checks to identify potential issues before starting the build
preflight_checks() {
  DL_DIR="$1"
  DOWNLOAD_BOXES=1

  # Check to see if curl is in PATH
  if ! which curl >/dev/null; then
    (echo >&2 "Please install curl and make sure it is in your PATH.")
    exit 1
  fi
  # Check to see if wget is in PATH
  if ! which wget >/dev/null; then
    (echo >&2 "Please install curl and make sure it is in your PATH.")
    exit 1
  fi
  # Check to see if boxes exist already
  BOXES_BUILT=$(find "$DL_DIR"/Boxes -name "*.box" | wc -l)
  if [ "$BOXES_BUILT" -gt 0 ]; then
    (echo >&2 "WARNING: You seem to have boxes present in the Boxes directory already. If you would like fresh boxes downloaded, please remove all files from the Boxes directory and re-run this script.")
    DOWNLOAD_BOXES=0
  fi
  # Check to see if any Vagrant instances exist already
  cd "$DL_DIR"/Vagrant/
  # Vagrant status has the potential to return a non-zero error code, so we work around it with "|| true"
  VAGRANT_BUILT=$(vagrant status | grep -c 'not created') || true
  if [ "$VAGRANT_BUILT" -ne 4 ]; then
    (echo >&2 "You appear to have already created at least one Vagrant instance. This script does not support pre-created instances. Please either destroy the existing instances or follow the build steps in the README to continue.")
    exit 1
  fi
  # Check available disk space. Recommend 80GB free, warn if less.
  FREE_DISK_SPACE=$(df -m "$HOME" | tr -s ' ' | grep '/' | cut -d ' ' -f 4)
  if [ "$FREE_DISK_SPACE" -lt 80000 ]; then
    (echo >&2 -e "Warning: You appear to have less than 80GB of HDD space free on your primary partition. If you are using a separate parition, you may ignore this warning.\\n")
    (df >&2 -m "$HOME")
    (echo >&2 "")
  fi
  # Ensure the vagrant-reload plugin is installed
  VAGRANT_RELOAD_PLUGIN_INSTALLED=$(vagrant plugin list | grep -c 'vagrant-reload')
  if [ "$VAGRANT_RELOAD_PLUGIN_INSTALLED" != "1" ]; then
    (echo >&2 "The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.")
    if ! $(which vagrant) plugin install "vagrant-reload"; then
      (echo >&2 "Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.")
      exit 1
    fi
  fi
}

# Downloads pre-built Packer boxes from detectionlab.network to save time during CI builds
download_boxes() {
  DL_DIR="$1"
  PROVIDER="$2"

  if [ "$PROVIDER" == "virtualbox" ]; then
    wget "https://www.detectionlab.network/windows_2016_virtualbox.box" -O "$DL_DIR"/Boxes/windows_2016_virtualbox.box
    wget "https://www.detectionlab.network/windows_10_virtualbox.box" -O "$DL_DIR"/Boxes/windows_10_virtualbox.box
  elif [ "$PROVIDER" == "vmware_fusion" ]; then
    wget "https://www.detectionlab.network/windows_2016_vmware.box" -O "$DL_DIR"/Boxes/windows_2016_vmware.box
    wget "https://www.detectionlab.network/windows_10_vmware.box" -O "$DL_DIR"/Boxes/windows_10_vmware.box
  fi

  # Hacky workaround
  if [ "$PROVIDER" == "vmware_fusion" ]; then
    PROVIDER="vmware"
  fi

  # Ensure Windows 10 box exists
  if [ ! -f "$DL_DIR"/Boxes/windows_10_"$PROVIDER".box ]; then
    (echo >&2 "Windows 10 box is missing from the Boxes directory. Qutting.")
    exit 1
  fi
  # Ensure Windows 2016 box exists
  if [ ! -f "$DL_DIR"/Boxes/windows_2016_"$PROVIDER".box ]; then
    (echo >&2 "Windows 2016 box is missing from the Boxes directory. Qutting.")
    exit 1
  fi
  # Verify hashes of VirtualBox boxes
  if [ "$PROVIDER" == "virtualbox" ]; then
    if [ "$(md5sum windows_10_"$PROVIDER".box | cut -d ' ' -f 1)" != "30b06e30b36b02ccf1dc5c04017654aa" ]; then
      (echo >&2 "Hash mismatch on windows_10_virtualbox.box")
    fi
    if [ "$(md5sum windows_2016_"$PROVIDER".box | cut -d ' ' -f 1)" != "614f984c82b51471b5bb753940b59d38" ]; then
      (echo >&2 "Hash mismatch on windows_2016_virtualbox.box")
    fi
    # Verify hashes of VMware boxes
  elif [ "$PROVIDER" == "vmware" ]; then
    if [ "$(md5 windows_10_"$PROVIDER".box | cut -d ' ' -f 1)" != "174ad0f0fd2089ff74a880c6dadac74c" ]; then
      (echo >&2 "Hash mismatch on windows_10_vmware.box")
      exit 1
    fi
    if [ "$(md5 windows_2016_"$PROVIDER".box | cut -d ' ' -f 1)" != "1511b9dc942c69c2cc5a8dc471fa8865" ]; then
      (echo >&2 "Hash mismatch on windows_2016_vmware.box")
      exit 1
    fi
    # Reset PROVIDER variable
    PROVIDER="vmware_fusion"
  fi
}

# Brings up a single host using Vagrant
vagrant_up_host() {
  PROVIDER="$1"
  HOST="$2"
  DL_DIR="$3"
  (echo >&2 "Attempting to bring up the $HOST host using Vagrant")
  cd "$DL_DIR"/Vagrant
  $(which vagrant) up "$HOST" --provider="$PROVIDER" 1>&2
  echo "$?"
}

# Attempts to reload and re-provision a host if the intial "vagrant up" fails
vagrant_reload_host() {
  HOST="$1"
  DL_DIR="$2"
  cd "$DL_DIR"/Vagrant
  # Attempt to reload the host if the vagrant up command didn't exit cleanly
  $(which vagrant) reload "$HOST" --provision 1>&2
  echo "$?"
}

# A series of checks to ensure important services are responsive after the build completes.
post_build_checks() {
  # If the curl operation fails, we'll just leave the variable equal to 0
  # This is needed to prevent the script from exiting if the curl operation fails
  CALDERA_CHECK=$(curl -ks -m 2 https://192.168.38.5:8888 | grep -c '302: Found' || echo "")
  SPLUNK_CHECK=$(curl -ks -m 2 https://192.168.38.5:8000/en-US/account/login?return_to=%2Fen-US%2F | grep -c 'This browser is not supported by Splunk' || echo "")
  FLEET_CHECK=$(curl -ks -m 2 https://192.168.38.5:8412 | grep -c 'Kolide Fleet' || echo "")

  BASH_MAJOR_VERSION=$(/bin/bash --version | grep 'GNU bash' | grep -o version\.\.. | cut -d ' ' -f 2 | cut -d '.' -f 1)
  # Associative arrays are only supported in bash 4 and up
  if [ "$BASH_MAJOR_VERSION" -ge 4 ]; then
    declare -A SERVICES
    SERVICES=(["caldera"]="$CALDERA_CHECK" ["splunk"]="$SPLUNK_CHECK" ["fleet"]="$FLEET_CHECK")
    for SERVICE in "${!SERVICES[@]}"; do
      if [ "${SERVICES[$SERVICE]}" -lt 1 ]; then
        (echo >&2 "Warning: $SERVICE failed post-build tests and may not be functioning correctly.")
      fi
    done
  else
    if [ "$CALDERA_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Caldera failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$SPLUNK_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Splunk failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$FLEET_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Fleet failed post-build tests and may not be functioning correctly.")
    fi
  fi
}

main() {
  # Get location of build_vagrant_only.sh
  # https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
  DL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROVIDER=""
  LAB_HOSTS=("logger" "dc" "wef" "win10")
  # If no argument was supplied, list available providers
  if [ $# -eq 0 ]; then
    PROVIDER=$(list_providers)
  fi
  # If more than one argument was supplied, print usage message
  if [ $# -gt 1 ]; then
    print_usage
    exit 1
  fi
  if [ $# -eq 1 ]; then
    # If the user specifies the provider as an agument, set the variable
    # TODO: Check to make sure they actually have their provider installed
    case "$1" in
      virtualbox)
        PROVIDER="$1"
        ;;
      vmware_fusion)
        PROVIDER="$1"
        ;;
      *)
        echo "\"$1\" is not a valid provider. Listing available providers:"
        PROVIDER=$(list_providers)
        ;;
    esac
  fi

  check_vagrant
  preflight_checks "$DL_DIR"
  if [ "$DOWNLOAD_BOXES" -eq 0 ]; then
    (echo >&2 "Skipping box downloads since .box files are already present in the Boxes/ directory.")
  else
    download_boxes "$DL_DIR" "$PROVIDER"
  fi

  # Vagrant up each box and attempt to reload one time if it fails
  for VAGRANT_HOST in "${LAB_HOSTS[@]}"; do
    RET=$(vagrant_up_host "$PROVIDER" "$VAGRANT_HOST" "$DL_DIR")
    if [ "$RET" -eq 0 ]; then
      (echo >&2 "Good news! $VAGRANT_HOST was built successfully!")
    fi
    # Attempt to recover if the intial "vagrant up" fails
    if [ "$RET" -ne 0 ]; then
      (echo >&2 "Something went wrong while attempting to build the $VAGRANT_HOST box.")
      (echo >&2 "Attempting to reload and reprovision the host...")
      RETRY_STATUS=$(vagrant_reload_host "$VAGRANT_HOST" "$DL_DIR")
      if [ "$RETRY_STATUS" -ne 0 ]; then
        (echo >&2 "Failed to bring up $VAGRANT_HOST after a reload. Exiting.")
        exit 1
      fi
    fi
  done

  post_build_checks
}

main "$@"
exit 0
