#!/usr/bin/env bash

# This script is used to prepare DetectionLab to be imported as VM in AWS

if ! which aws > /dev/null; then
  apt-get install -y python-pip
  pip install awscli --upgrade --user
  cp /root/.local/bin/aws /usr/local/bin/aws && chmod +x /usr/local/bin/aws
fi

# Configure credentials for awscli
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region us-west-1
export BUCKET_NAME="FILL_ME_IN"

cd /opt/DetectionLab/Vagrant || exit 1
# Stop logger and export box as an OVA
cd /opt/DetectionLab/Vagrant || exit 1
echo "Halting all VMs..."
vagrant halt

vboxmanage export logger -o /root/logger.ova && echo -n "success" > /root/logger.export || echo "failed" > /root/logger.export

# Sleep until all exports are complete
while [[ ! -f /root/logger.export ]];
  do sleep 5
  echo "Waiting for the OVA export to complete. Sleeping for 5."
done

# Copy each OVA into S3
if [[ "$(cat /root/logger.export)" == "success"  ]]; then
  aws s3 cp /root/logger.ova s3://$BUCKET_NAME/disks/
fi

# Fix the bucket
cd /opt/DetectionLab/AWS/Terraform/vm_import || exit 1
for file in *.json;
  do sed -i "s/YOUR_BUCKET_GOES_HERE/$BUCKET_NAME/g" "$file";
done

# Fix the key names
for file in *.json;
  do sed -i 's#"S3Key": "#"S3Key": "disks/#g' "$file";
done

aws ec2 import-image --description "logger" --license-type byol --disk-containers file:///opt/DetectionLab/AWS/Terraform/vm_import/logger.json
