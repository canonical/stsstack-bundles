#!/bin/bash

dpkg -l expect || sudo apt-get -yq install expect
juju show-user prometheus 2>/dev/null || juju add-user prometheus

cat <<EOF | expect -f -
spawn juju change-user-password prometheus
expect "new password: "
send "ubuntu\n"
expect "type new password again: "
send "ubuntu\n"
expect "Password for \"prometheus\" has been changed.\n"
EOF

juju grant prometheus read controller || echo "read access already granted"

CONTROLLER_IP=$(juju show-machine -m admin/controller 0 | grep -A1 ip-addresses | head -n2 | tail -n 1 | awk '{print $2}')

sed s/__CONTROLLER_IP__/$CONTROLLER_IP/g prometheus-config.yaml.tpl > prometheus-config.yaml

juju config prometheus scrape-jobs=@prometheus-config.yaml
juju expose prometheus
juju expose grafana
