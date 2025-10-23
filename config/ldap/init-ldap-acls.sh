#!/usr/bin/env bash
set -eu

# apply acls
echo -n "Applying acls... "
slapmodify -F /opt/bitnami/openldap/etc/slapd.d -b cn=config -l /opt/bitnami/openldap/etc/schema/50_acls.ldif
if [ $? -eq 0 ]; then
    echo "done."
else
    echo "failed."
fi
