# LDAP

## Instructions

This setup allows you to deploy Openstack using the LDAP backend
to keystone. When you generate your deployment it will include both
Openstack and a test LDAP server. Once the LDAP server is deployed
the bundle will need to be re-run to configure keystone with the
server address.

1. Generate your deployment by including the `--ldap` overlay
2. Once the `ldap-test-fixture` charm is deployed, get its IP address:

    ```console
    juju status ldap-test-fixture | awk '/ldap-test-fixture\/0/ { print $5 }'
    ```

3. re-run `./generate-bundle.sh ...` and put in the address when prompted

Authentication to the cloud will still work using the `novarc` (v3) credentials
as the cloud admin is in the SQL domain.

There are two users in the LDAP server by default:

* `johndoe`
* `janedoe`

Both users have the password of `crapper`. Users in the LDAP domain can be
listed by using the `openstack user list` command using the domain filter.

## Post-deploy configuration

Optionally add arbitrary number of users to the LDAP with:

```console
wget https://gist.githubusercontent.com/wolsen/9158cb71238914564cfa177c82adfc41/raw/658da293fd180d79945c3766ae79f8ec104cdbc2/create-ldap-users.py
```

Authenticate with LDAP users:

```console
source novarc
admin=`openstack project list -c ID -c Name --domain admin_domain| grep admin| awk '{print $2}'`
for user in 'John Doe' 'Jane Doe'; do
    openstack user set --enable --domain userdomain "$user" 
    openstack role add --user "$user" --user-domain userdomain Member --project $admin
    openstack role add --user "$user" --user-domain userdomain Admin --project $admin
done
```

Re-create `janedoe/johndoe`:

```console
cat << 'EOF' > ldap_config.py
#!/usr/bin/env python3
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
