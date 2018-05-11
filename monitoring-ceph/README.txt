# juju model-config -m monitoring
Attribute                     From        Value
agent-version                 model       2.3.3
...
apt-http-proxy                controller  http://squid.internal:3128
apt-https-proxy               controller  http://squid.internal:3128
...
container-networking-method   model       local
...
http-proxy                    default     "http://squid.internal:3128"
https-proxy                   default     ""
...
no-proxy                      model       10.5.0.*
...
use-default-secgroup          controller  true

juju run-action graylog/0 show-admin-password --wait
# use given pw to log into graylog with admin/<password>

# cat /etc/juju-proxy.conf
export no_proxy=10.5.0.*,10.5.0.19,252.0.19.1
export NO_PROXY=10.5.0.*,10.5.0.19,252.0.19.1

# If host running elasticsearch does not have enough memory then do:
Set ES_JAVA_OPTS='-Xms1g -Xmx1g' in /etc/default/elasticsearch

# If charm fails do this:
cd /var/lib/juju/agents/unit-elasticsearch-0/charm/
ansible-playbook -c local playbook.yaml --tags install
systemctl restart elasticsearch
ss -lntp| grep 9200
curl localhost:9200

