# Graylog

## Pre-flight Checks

Juju enables fan networking by default and this breaks Graylog so you need to disable it in your model:

```console
juju model-config -m <model> container-networking-method=local no-proxy=10.5.0.*
```

## Post-deployment

### Add `filebeat` relation to services you want to monitor _e.g._

```console
juju add-relation filebeat nova-cloud-controller
juju add-relation filebeat nova-compute
```

### Get admin password to log into GUI

```console
juju run-action graylog/0 show-admin-password --wait
```

Then go to `GRAYLOG_HOST:9001` and login

### Troubleshooting

If host running Elasticsearch does not have enough memory then adjust:

In `/etc/default/elasticsearch`

```console
ES_JAVA_OPTS='-Xms1g -Xmx1g'
```

Check that it is running

```console
ss -lntp| grep 9200
curl localhost:9200
```
