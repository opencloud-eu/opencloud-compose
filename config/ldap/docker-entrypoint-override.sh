#!/bin/bash
echo "Running custom LDAP entrypoint script..."

if [ ! -f /opt/bitnami/openldap/share/openldap.key ]
then	
	openssl req -x509 -newkey rsa:4096 -keyout /opt/bitnami/openldap/share/openldap.key -out /opt/bitnami/openldap/share/openldap.crt -sha256 -days 365 -batch -nodes
fi

# run original docker-entrypoint in background
/opt/bitnami/scripts/openldap/entrypoint.sh "$@" &

# wait until LDAP is started
while ! ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=admin,dc=opencloud,dc=eu" >/dev/null 2>&1; do
    echo "Waiting for LDAP to start..."
    sleep 1
done

# apply ACLs
echo -n "Applying acls... "
ldapmodify -Y EXTERNAL -H ldapi:/// -f /opt/bitnami/openldap/share/50_acls.ldif
if [ $? -eq 0 ]; then
    echo "done."
else
    echo "failed."
fi

# keep container running
wait
