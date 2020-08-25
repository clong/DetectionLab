#! /bin/sh
# Fix the motd script
cp /etc/update-motd.d/20-detectionlab .
tr -d '\15\32' < 20-detectionlab > /etc/update-motd.d/20-detectionlab