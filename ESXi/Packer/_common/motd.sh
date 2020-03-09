#!/bin/sh -eux

bento='
This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento'

if [ -d /etc/update-motd.d ]; then
    MOTD_CONFIG='/etc/update-motd.d/99-bento'

    cat >> "$MOTD_CONFIG" <<BENTO
#!/bin/sh

cat <<'EOF'
$bento
EOF
BENTO

    chmod 0755 "$MOTD_CONFIG"
else
    echo "$bento" >> /etc/motd
fi
