#!/bin/bash -x
# Usage: ./tools/bootstrap-k8s-cloud.sh <cloud-name> <model-name>
CLOUD="${1:-k8scloud}"
MODEL="${2:-secloud}"

check_kubeconfig() {
	if [[ -z "$KUBECONFIG" && ! -f "${HOME}/.kube/config" ]]; then
		echo 'ERROR: Cannot find KUBECONFIG! Set as environment variable.'
		exit 1
	fi
}

get_storageclass() {
	default_storageclass="$(kubectl get sc | grep default | awk '{print $1}')"
	if [[ -z "$default_storageclass" ]]; then
		enable_storage
	fi
}

enable_storage() {
	if leader="$(juju status --format json| jq -r '.applications["microk8s"].units|to_entries[]|select(.value["leader"])|.key' 2> /dev/null)"; then
		echo 'Enabling hostpath-storage on Microk8s.'
		juju ssh "$leader" sudo microk8s enable hostpath-storage
	elif leader="$(juju status --format json| jq -r '.applications["k8s"].units|to_entries[]|select(.value["leader"])|.key' 2> /dev/null)"; then
		echo 'Enabling local-storage on Canonical K8s.'
		juju ssh "$leader" sudo k8s enable local-storage
	else
		echo 'ERROR: No default storage class in Kubernetes. Try deploying a k8s bundle with --ceph.'
		exit 1
	fi
}

bootstrap_k8s() { 
	juju add-k8s "$CLOUD" --client
	juju bootstrap "$CLOUD"
	juju add-model "$MODEL"
}

check_kubeconfig
get_storageclass
bootstrap_k8s
