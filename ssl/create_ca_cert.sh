#!/bin/bash -eu
state_dir=$1
results_dir=${state_dir}/results
declare -a required=( cacert.pem servercert.csr servercert.pem )

all_exist=true
for f in ${required[@]}; do
    [ -r "$results_dir/$f" ] || all_exist=false && break
done

if $all_exist; then
    echo -e "Using existing ssl certificates in ssl/$state_dir\n"
    exit
else
    echo -e "Generating ssl certificates in ssl/$state_dir\n"
fi

mkdir -p $results_dir
sed -r "s,__RESULTS_PATH__,$results_dir,g" openssl-ca.cnf.template > ${state_dir}/openssl-ca.cnf
sed -r "s,__RESULTS_PATH__,$results_dir,g" openssl-server.cnf.template > ${state_dir}/openssl-server.cnf

sed -i -r "s,__CN_VIP__,${MASTER_OPTS[VIP_ADDR_START]},g" $state_dir/openssl-server.cnf
vip_net=${MASTER_OPTS[VIP_ADDR_START]}
vip_net_prefix=${vip_net%\.*}
vip_net_suffix=${vip_net##*\.}

# TODO: figure out exactly how many we need
for ((i=0;i<20;i++)); do
    echo "IP.$((i+1))  = $vip_net_prefix.$((vip_net_suffix+i))" >> $state_dir/openssl-server.cnf
done

touch $results_dir/index.txt
echo '01' > $results_dir/serial.txt
{
openssl req -x509 -config $state_dir/openssl-ca.cnf -newkey rsa:4096 -sha256 -nodes -out $results_dir/cacert.pem -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud"
openssl req -config $state_dir/openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out $results_dir/servercert.csr -outform PEM -subj "/C=GB/ST=England/L=London/O=Ubuntu Cloud/OU=Cloud/CN=${MASTER_OPTS[VIP_ADDR_START]}"
openssl ca -batch -config $state_dir/openssl-ca.cnf -policy signing_policy -extensions signing_req -out $results_dir/servercert.pem -infiles $results_dir/servercert.csr
} &>/dev/null
