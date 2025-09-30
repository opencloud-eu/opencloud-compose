#!/bin/bash
echo "Running custom LDAP entrypoint script..."

if [ ! -f /opt/bitnami/openldap/share/openldap.key ]
then	
	openssl req -x509 -newkey rsa:4096 -keyout /opt/bitnami/openldap/share/openldap.key -out /opt/bitnami/openldap/share/openldap.crt -sha256 -days 365 -batch -nodes
fi

# apply ldap acl file in case it exists
if [ -f /ldifs/50_acls.ldif ]; then
  echo -n "Applying ACL file... "
  ldapmodify -Y EXTERNAL -H ldapi:/// -f /ldifs/50_acls.ldif
  test $? -eq 0 && echo "OK" || echo "FAILED"
fi

# run original docker-entrypoint
/opt/bitnami/scripts/openldap/entrypoint.sh "$@"
