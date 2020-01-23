# Instructions

This setup is a little different than most bundles and is designed
to be deployed repeatedly. The ldap server address is needed for
the parameters to the keystone-ldap subordinate charm.

To deploy this solution it will be easiest to deploy multiple models
and keep the ldap server running separately.

1. Generate the cloud yaml file via ./generate-bundle.sh adding in the --ldap overlay
2. juju add-model ldap-server
3. juju deploy ./openldap-fixture.yaml
4. After openldap-fixture is deployed, get its IP address:
   LDAPADDR=$(juju status ldap-server | awk '/ldap-server\/0/ { print $5 }')
5. Update the __LDAP_SERVER__ variable in the keystone-ldap.yaml bundle
   sed -i "s,__LDAP_SERVER__,$LDAPADDR,g"
6. juju add-model cloud
7. juju deploy ./ldap.yaml

Authentication to the cloud will still work using the novarc (v3) credentials
as the cloud admin is in the sql domain.

There are two users in the ldap-server by default:

  * johndoe
  * janedoe

Both users have the password of 'crapper'. Users in the ldap domain can be
listed by using the `openstack user list` command using the domain filter.

# Deploy LDAP test server with pre-populated data

git clone https://github.com/openstack-charmers/charm-ldap-test-fixture ldap-test-fixture
wget https://gist.githubusercontent.com/wolsen/9158cb71238914564cfa177c82adfc41/raw/658da293fd180d79945c3766ae79f8ec104cdbc2/create-ldap-users.py
juju add-model ldap
juju switch ldap
juju deploy --series xenial ./ldap-test-fixture

Get address of server and either add to generated bundle or set in deployment
```
juju run --unit ldap-test-fixture/0 'unit-get private-address' -m ldap
```

## Post-deploy config

```
source novarc
admin=`openstack project list -c ID -c Name --domain admin_domain| grep admin| awk '{print $2}'`
for user in 'John Doe' 'Jane Doe'; do
    openstack user set --enable --domain userdomain "$user" 
    openstack role add --user "$user" --user-domain userdomain Member --project $admin
    openstack role add --user "$user" --user-domain userdomain Admin --project $admin
done
```

```
cat << 'EOF' > ldap_config.py
#!/usr/bin/env python
import ldap
con = ldap.initialize('ldap://__LDAP_SERVER__')
con.simple_bind_s('cn=admin,dc=test,dc=com', 'crapper')
con.passwd_s('cn=johndoe,ou=users,dc=test,dc=com', None, 'password')
con.passwd_s('cn=janedoe,ou=users,dc=test,dc=com', None, 'password')
con.unbind_s()
EOF
addr=`juju run --unit ldap-test-fixture/0 'unit-get private-address' -m ldap`
sed -i "s/__LDAP_SERVER__/$addr/g" ldap_config.py
chmod +x ldap_config.py
./ldap_config.py
```
