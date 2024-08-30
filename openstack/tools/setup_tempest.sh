set -x -u -e

scriptpath=$(readlink --canonicalize $(dirname $0))

source ${scriptpath}/../profiles/common
source ${scriptpath}/../novarc

# Gather vars for tempest template
# TODO: remove fallbacks once we move to queens (they are there for clients still on ocata)
ext_net=$(openstack network list --name ext_net -f value -c ID 2>/dev/null || openstack network list| awk '$4=="ext_net" {print $2}')
router=$(openstack router list --name provider-router -f value -c ID 2>/dev/null || openstack router list| awk '$4=="provider-router" {print $2}')
keystone=$(juju exec --unit keystone/0 unit-get private-address)
ncc=$(juju exec --unit nova-cloud-controller/0 unit-get private-address)
http=${OS_AUTH_PROTOCOL:-http}
if is_ksv3; then
    default_domain_id=$(openstack domain list | awk '/default/ {print $2}')
else
    dashboard="localhost"
    set +e
    dashboard_ip=$(juju exec --unit openstack-dashboard/0 unit-get private-address)
    if [ "$?" == "1" ]; then
        dashboard=$dashboard_ip
    fi
    set -e
fi

# Insert vars into tempest conf
if is_ksv3; then
    sed -e "s/__IMAGE_ID__/$image_id/g" -e "s/__IMAGE_ALT_ID__/$image_alt_id/g" \
        -e "s/__KEYSTONE__/$keystone/g" \
        -e "s/__EXT_NET__/$ext_net/g" -e "s/__PROTO__/$http/g" \
        -e "s/__SWIFT__/$SWIFT_IP/g" \
        -e "s/__NAMESERVER__/$NAMESERVER/g" \
        -e "s/__CIDR_PRIV__/${CIDR_PRIV////\\/}/g" \
        -e "s/__NCC__/$ncc/g" \
        -e "s/__DEFAULT_DOMAIN_ID__/$default_domain_id/g" \
        templates/tempest/tempest-v3.conf.template > tempest.conf
else
    sed -e "s/__IMAGE_ID__/$image_id/g" -e "s/__IMAGE_ALT_ID__/$image_alt_id/g" \
        -e "s/__DASHBOARD__/$dashboard/g" -e "s/__KEYSTONE__/$keystone/g" \
        -e "s/__EXT_NET__/$ext_net/g" -e "s/__PROTO__/$http/g" \
        -e "s/__SWIFT__/$SWIFT_IP/g" \
        -e "s/__NAMESERVER__/$NAMESERVER/g" \
        -e "s/__CIDR_PRIV__/${CIDR_PRIV////\\/}/g" \
        -e "s/__NCC__/$ncc/g" \
        templates/tempest/tempest.conf.template > tempest.conf
fi

# Git tempest, place the rendered tempest template
[ -d tempest ] || git clone https://github.com/openstack/tempest
git --git-dir=tempest/.git --work-tree=tempest checkout master
git --git-dir=tempest/.git --work-tree=tempest pull
cp tempest.conf tempest/etc
cp templates/tempest/accounts.yaml tempest/etc
