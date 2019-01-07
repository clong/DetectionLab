# The region you would like EC2 instances in
# Defaults to us-west-1
region = ""
# Path to the credentials file for AWS (usually /Users/username/.aws/credentials)
shared_credentials_file = ""
# Path to the SSH public key to be added to the logger host
# Example: /Users/username/.ssh/id_terrraform.pub
public_key_path = ""
# AMI ID for each host
# Example: "ami-xxxxxxxxxxxxxxxxx"
logger_ami = ""
dc_ami =  ""
wef_ami = ""
win10_ami = ""
# IP Whitelist - Subnets listed here can access the lab over the internet
# Sample: ["1.1.1.1/32", "2.2.2.2/24"]
ip_whitelist = [""]
