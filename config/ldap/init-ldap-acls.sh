#!/usr/bin/env bash
set -eu

# load OpenLDAP environment and functions
. /opt/bitnami/scripts/libopenldap.sh

trap ldap_stop EXIT

# start LDAP in background
ldap_start_bg

# wait until LDAP is started
while ! ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=admin,dc=opencloud,dc=eu" >/dev/null 2>&1; do
    echo "Waiting for LDAP to start..."
    sleep 1
done

# apply acls
echo -n "Applying acls... "
ldapmodify -Y EXTERNAL -H ldapi:/// -f /opt/bitnami/openldap/etc/schema/50_acls.ldif
if [ $? -eq 0 ]; then
    echo "done."
else
    echo "failed."
fi

