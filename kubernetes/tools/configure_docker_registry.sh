#!/bin/bash -ux

# Get the private docker-registry ip and port
ip=`juju run --unit docker-registry/0 'network-get website --ingress-address'`
port=`juju config docker-registry registry-port`
registry=$ip:$port

# Get the current image-registry configured in k8s control-plane (default - rocks.canonical.com:443/cdk)
old_image_registry=`juju config kubernetes-control-plane image-registry`

# All the images used from current image registry need to be uploaded to private docker-registry
# Get the list of images used in the current deployment from the current image-registry
images=`kubectl get po --all-namespaces -o json | jq '.items[].spec.containers[] | {image}' | grep -oP '(?<="image": ").*(?=")' | grep $old_image_registry`

# Upload the identified images from current image-registry to new private docker-registry
# TODO: check if this functionality can be replaced with images specified at
# https://github.com/charmed-kubernetes/bundle/blob/master/container-images.txt
for image in ${images}; do 
    tag=${image/$old_image_registry/$registry};
    juju run-action docker-registry/0 push image=$image tag=$tag --wait
done

# Caveats: 1. Image names are different for coredns 2. Add pause container
juju run-action docker-registry/0 push image=$registry/coredns/coredns-amd64:1.6.7 tag=$registry/coredns/coredns:1.6.7 --wait
juju run-action docker-registry/0 push image=k8s.gcr.io/pause-amd64:3.2 tag=$registry/pause-amd64:3.2 --wait

# Update k8s to point to the private docker-registry
juju config kubernetes-control-plane image-registry=$registry

echo "Wait for the kubernetes control-plane to be active"
