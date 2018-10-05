== pre-flight checks ==
Juju enables fan networking by default and this breaks graylog so you need to disable it in your model:

juju model-config -m <model> container-networking-method=local no-proxy=10.5.0.*

== post-deployment ==

# add filebeat relation to services you want to monitor e.g.
juju add-relation filebeat nova-cloud-controller
juju add-relation filebeat nova-compute

# get admin password to log into gui
juju run-action graylog/0 show-admin-password --wait

# go to <unit-address>:9001 and login

== troubleshooting ==

# If host running elasticsearch does not have enough memory then adjust:

# in /etc/default/elasticsearch
ES_JAVA_OPTS='-Xms1g -Xmx1g'

# check that it is running
ss -lntp| grep 9200
curl localhost:9200


