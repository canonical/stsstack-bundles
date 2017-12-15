# Instructions

This setup is a little different than most bundles and is designed
to be deployed repeatedly. The ldap server address is needed for
the parameters to the keystone-ldap subordinate charm.

To deploy this solution it will be easiest to deploy multiple models
and keep the ldap server running separately.

1. Generate the cloud yaml file via ./generate-bundle.sh xenial newton
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
