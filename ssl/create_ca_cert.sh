#!/bin/bash -eu
module=${1:-default}
results_dir=${module}/results
#rm -rf $results_dir
mkdir -p $results_dir
sed -r "s,__RESULTS_PATH__,$results_dir,g" openssl-ca.cnf.template > $module/openssl-ca.cnf
sed -r "s,__RESULTS_PATH__,$results_dir,g" openssl-server.cnf.template > $module/openssl-server.cnf
touch $results_dir/index.txt
echo '01' > $results_dir/serial.txt
[ -r "$results_dir/cacert.pem" ] || \
    openssl req -x509 -config $module/openssl-ca.cnf -newkey rsa:4096 -sha256 -nodes -out $results_dir/cacert.pem -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud"
[ -r "$results_dir/servercert.csr" ] || \
    openssl req -config $module/openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out $results_dir/servercert.csr -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud/CN=10.5.100.1"
[ -r "$results_dir/servercert.pem" ] || \
    openssl ca -batch -config $module/openssl-ca.cnf -policy signing_policy -extensions signing_req -out $results_dir/servercert.pem -infiles $results_dir/servercert.csr
