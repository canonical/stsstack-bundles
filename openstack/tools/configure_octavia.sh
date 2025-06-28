#!/bin/bash -eux
# NOTE: assumes that you have already added amphorae image to glance.

. $(dirname $0)/../common/juju_helpers

dout=`mktemp -d`
(
cd $dout
mkdir -p demoCA/newcerts
touch demoCA/index.txt
touch demoCA/index.txt.attr
openssl genrsa -passout pass:foobar -des3 -out issuing_ca_key.pem 2048
openssl req -x509 -passin pass:foobar -new -nodes -key issuing_ca_key.pem \
    -config /etc/ssl/openssl.cnf \
    -subj "/C=US/ST=Somestate/O=Org/CN=www.example.com" \
    -days 365 \
    -out issuing_ca.pem

openssl genrsa -passout pass:foobar -des3 -out controller_ca_key.pem 2048
openssl req -x509 -passin pass:foobar -new -nodes \
        -key controller_ca_key.pem \
    -config /etc/ssl/openssl.cnf \
    -subj "/C=US/ST=Somestate/O=Org/CN=www.example.com" \
    -days 365 \
    -out controller_ca.pem
openssl req \
    -newkey rsa:2048 -nodes -keyout controller_key.pem \
    -subj "/C=US/ST=Somestate/O=Org/CN=www.example.com" \
    -out controller.csr
openssl ca -passin pass:foobar -config /etc/ssl/openssl.cnf \
    -cert controller_ca.pem -keyfile controller_ca_key.pem \
    -create_serial -batch \
    -in controller.csr -days 365 -out controller_cert.pem
cat controller_cert.pem controller_key.pem > controller_cert_bundle.pem
)

juju config octavia \
    lb-mgmt-issuing-cacert="$(base64 $dout/controller_ca.pem)" \
    lb-mgmt-issuing-ca-private-key="$(base64 $dout/controller_ca_key.pem)" \
    lb-mgmt-issuing-ca-key-passphrase=foobar \
    lb-mgmt-controller-cacert="$(base64 $dout/controller_ca.pem)" \
    lb-mgmt-controller-cert="$(base64 $dout/controller_cert_bundle.pem)"

CMD="juju $JUJU_RUN_CMD octavia/leader configure-resources"

if [[ "$JUJU_VERSION" =~ ^3 ]]; then
    CMD="$CMD --wait 10m"
fi

$CMD

# Add load-balancer_admin role for admin user
source $(readlink --canonicalize $(dirname $0))/../novarc
PROJECT_ID=$(openstack project show --domain admin_domain --format value --column id admin)
openstack role add --project ${PROJECT_ID} --user admin load-balancer_admin
