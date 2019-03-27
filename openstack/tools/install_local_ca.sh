#!/bin/bash -eux
sudo cp ssl/results/cacert.pem /etc/ssl/certs
sudo chmod 644 /etc/ssl/certs/cacert.pem
sudo update-ca-certificates --fresh
