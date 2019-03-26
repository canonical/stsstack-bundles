#!/bin/bash -eu
#rm -rf results
mkdir -p results
touch results/index.txt
echo '01' > results/serial.txt
[ -r "results/cacert.pem" ] || \
    openssl req -x509 -config openssl-ca.cnf -newkey rsa:4096 -sha256 -nodes -out results/cacert.pem -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud"
[ -r "results/servercert.csr" ] || \
    openssl req -config openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out results/servercert.csr -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud/CN=10.5.100.1"
[ -r "results/servercert.pem" ] || \
    openssl ca -batch -config openssl-ca.cnf -policy signing_policy -extensions signing_req -out results/servercert.pem -infiles results/servercert.csr
