#!/bin/bash -ux
[ -e 'xenial/ldap-test-fixture' ] || \
	git clone https://github.com/openstack-charmers/charm-ldap-test-fixture xenial/ldap-test-fixture
wget https://gist.githubusercontent.com/wolsen/9158cb71238914564cfa177c82adfc41/raw/658da293fd180d79945c3766ae79f8ec104cdbc2/create-ldap-users.py
juju add-model ldap
juju switch ldap
juju deploy xenial/ldap-test-fixture
juju add-model default || true
juju switch default
./generate-bundle.sh xenial ocata
addr=`juju run --unit ldap-test-fixture/0 'unit-get private-address' -m ldap`
sed -i "s/__LDAP_SERVER__/$addr/g" ldap.yaml
juju deploy ldap.yaml
watch -c juju status --color
