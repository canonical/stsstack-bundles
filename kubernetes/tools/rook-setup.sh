#!/bin/bash
# Clones the rook repo and deploys ceph
# Usage: $0 [rook_version] e.g. $0 1.7.3

# Defaults to version 1.7.3
rook_version=${1:-1.7.3}

k8s_dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
mkdir -p ${k8s_dir}/rook_source
cd ${k8s_dir}/rook_source
rm -rf rook
git clone --single-branch --branch v${rook_version} https://github.com/rook/rook.git
cd ${k8s_dir}/rook_source/rook/cluster/examples/kubernetes/ceph
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
echo "INFO: using sotrageclass 'cdk-cinder' for OSDs..."
sed -i 's/gp2/cdk-cinder/g' cluster-on-pvc.yaml
kubectl create -f cluster-on-pvc.yaml
