# Kubernetes

Kubernetes can be deployed by more than one means including; [Charmed Kubernetes](https://ubuntu.com/kubernetes/charmed-k8s), Microk8s and [Canonical Kubernetes](https://ubuntu.com/kubernetes/install). In this module we provide support for both Charmed Kubernetes and Canonical Kubernetes with the latter being the default install method.

## Getting Started

As with other modules the fastest path to deploying is to run generate bundle with defaults and run:

```console
./generate-bundle.sh --run
```

This will give you a basic Canonical Kubernetes deployment. If you require more than the basic features and configuration you can use the provided options - see ```./generate-bundle.sh --list-overlays```.

You can check the status of your deployment with:

```console
watch -c juju status --color
```

## Configuring Your Cloud

Once deployed and all units are *active/idle*, you need to configure your cloud before you can use it. To do so run:

```console
./configure
```

You can now interact with your cloud e.g. using kubectl:

```console
kubectl get -A po
```

