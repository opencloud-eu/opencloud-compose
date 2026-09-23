#!/bin/bash
echo "Running custom LDAP entrypoint script..."

if [ ! -f /opt/bitnami/openldap/share/openldap.key ]
then
	openssl req -x509 -newkey rsa:4096 -keyout /opt/bitnami/openldap/share/openldap.key -out /opt/bitnami/openldap/share/openldap.crt -sha256 -days 365 -batch -nodes
fi
# A slapd.pid left over by an unclean stop makes the bitnami setup kill
# whatever process now holds that PID (often the setup itself), which
# puts the container into a restart loop.
rm -f /opt/bitnami/openldap/var/run/slapd.pid /opt/bitnami/openldap/var/run/slapd.args
# exec so that slapd becomes PID 1 and receives SIGTERM from "docker stop"
exec /opt/bitnami/scripts/openldap/entrypoint.sh "$@"
