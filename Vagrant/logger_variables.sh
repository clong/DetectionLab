#! /usr/bin/env bash

# Get a free Maxmind license here: https://www.maxmind.com/en/geolite2/signup
# Required for the ASNgen app to work: https://splunkbase.splunk.com/app/3531/
export MAXMIND_LICENSE=""

# Get a free Splunk Dev Trial License here: http://dev.splunk.com/page/developer_license_sign_up
# To base64 encode on MacOS: cat Splunk.License | base64 | tr -d '\n' | pbcopy
# Then, simply paste below:
export BASE64_ENCODED_SPLUNK_LICENSE=""

