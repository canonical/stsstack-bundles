#!/bin/bash -eux
sudo cp ssl/openstack/results/cacert.pem /usr/local/share/ca-certificates/cacert.crt
sudo chmod 644 /usr/local/share/ca-certificates/cacert.crt
sudo update-ca-certificates --fresh
