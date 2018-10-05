#!/bin/bash

set -ex

juju scp keystone/0:/usr/local/share/ca-certificates/keystone_juju_ca_cert.crt .

sudo mkdir -p /usr/local/share/ca-certificates
sudo cp keystone_juju_ca_cert.crt /usr/local/share/ca-certificates
sudo update-ca-certificates --fresh
