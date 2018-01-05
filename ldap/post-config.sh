#!/bin/bash -eux
source ./novarcv3_domain 
admin=`openstack project list -c ID -c Name --domain admin_domain| grep admin| awk '{print $2}'`
for user in 'John Doe' 'Jane Doe'; do
openstack user set --enable --domain userdomain $user 
openstack role add --user $user --user-domain userdomain Member --project $admin
openstack role add --user $user --user-domain userdomain Admin --project $admin
done

cat << 'EOF' > ldap_config.py
import ldap
con = ldap.initialize('ldap://10.5.0.13')
con.simple_bind_s('cn=admin,dc=test,dc=com', 'crapper')
con.passwd_s('cn=johndoe,ou=users,dc=test,dc=com', None, 'password')
con.passwd_s('cn=janedoe,ou=users,dc=test,dc=com', None, 'password')
con.unbind_s()
EOF
chmod +x ldap_config.py
./ldap_config.py
