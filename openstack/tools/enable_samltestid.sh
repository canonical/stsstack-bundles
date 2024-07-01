#!/bin/bash -ex

. $(dirname $0)/../common/juju_helpers

credentials=$(env | grep OS_ || true)

if [[ -z $credentials ]];then
    echo "Missing overcloud credentials"
    exit 1
fi

if [[ $OS_AUTH_URL == *keystone.ps6* ]] || [[ $OS_AUTH_URL == *10.230* ]];then
    echo "Use the overcloud credentials, not undercloud"
    exit 1
fi

HTTPS=false

if [[ $OS_AUTH_URL == https://* ]];then
    HTTPS=true
fi

check_app_exists () {
    if ! juju show-application $1 2>&1; then
        echo "Missing $1 application"
        exit 1
    fi
}

check_app_exists keystone-saml-mellon

check_app_exists test-saml-idp1

juju $JUJU_RUN_CMD --format=json test-saml-idp1/0 get-idp-metadata > idp-metadata.json

if [ $JUJU_VERSION -eq 2 ]; then
    cat idp-metadata.json | jq -r '."unit-test-saml-idp1-0".results.output' > idp-metadata.xml
else
    cat idp-metadata.json | jq -r '."test-saml-idp1/0".results.output' > idp-metadata.xml
fi

IDP_XML=idp-metadata.xml

if $HTTPS; then
    sed 's/http:\/\/10/https:\/\/10/g' idp-metadata.xml > idp-metadata_https.xml
    IDP_XML=idp-metadata_https.xml
fi

juju attach-resource keystone-saml-mellon idp-metadata=./$IDP_XML

status='foo'
while [[ $status != 'active' ]]; do
	sleep 3
	status=$(juju status keystone-saml-mellon --format json | jq -r '."applications"."keystone-saml-mellon"."application-status"."current"')
done

juju $JUJU_RUN_CMD --format=json keystone-saml-mellon/0 get-sp-metadata > sp-metadata.json

if [ $JUJU_VERSION -eq 2 ]; then
    cat sp-metadata.json | jq -r '."unit-keystone-saml-mellon-0".results.output' > sp-metadata.xml
else
    cat sp-metadata.json | jq -r '."keystone-saml-mellon/0".results.output' > sp-metadata.xml
fi  

juju attach-resource test-saml-idp1 sp-metadata=./sp-metadata.xml

status='foo'
while [[ $status != 'active' ]]; do
	sleep 3
	status=$(juju status test-saml-idp1 --format json | jq -r '."applications"."test-saml-idp1"."application-status"."current"')
done

ENTITY_ID=$(egrep -o "entityID=\"(.*)\"" idp-metadata.xml | cut -d "=" -f2 | cut -d '"' -f2)

openstack domain create federated_domain
openstack group create federated_users --domain federated_domain

# Get the federated_users group id and assign the role member
GROUP_ID=$(openstack group show federated_users --domain federated_domain | grep -v domain_id | grep id |awk '{print $4}')
openstack role add --group ${GROUP_ID} --domain federated_domain member

# Use the URL for your idP's metadata for remote-id. The name can be
# arbitrary.
openstack identity provider create --remote-id $ENTITY_ID --domain federated_domain test-saml-idp1

# Get the federated_domain id and add it to the rules.json map
DOMAIN_ID=$(openstack domain show federated_domain |grep id |awk '{print $4}')
cat > rules.json <<EOF
[{
        "local": [
            {
                "user": {
                    "name": "{0}"
                },
                "group": {
                    "domain": {
                        "id": "${DOMAIN_ID}"
                    },
                    "name": "federated_users"
                },
                "projects": [
                {
                    "name": "{0}_project",
                    "roles": [
                                 {
                                     "name": "member"
                                 }
                             ]
                }
                ]
           }
        ],
        "remote": [
            {
                "type": "MELLON_NAME_ID"
            }
        ]
}]
EOF

# Use the rules.json created above.
openstack mapping create --rules rules.json test-saml-idp1_mapping
# The name should be mapped or saml here and must match the configuration
# setting protocol-name. We recommend using "mapped"
openstack federation protocol create mapped --mapping test-saml-idp1_mapping --identity-provider test-saml-idp1
# list related projects
openstack federation project list
# list domains
openstack domain list

rm idp-metadata.json
rm idp-metadata.xml
rm sp-metadata.json
rm sp-metadata.xml
rm -f idp-metadata_https.xml
