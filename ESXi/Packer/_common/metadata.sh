#!/bin/sh -eux

mkdir -p /etc;
cp /tmp/bento-metadata.json /etc/bento-metadata.json;
chmod 0444 /etc/bento-metadata.json;
rm -f /tmp/bento-metadata.json;
