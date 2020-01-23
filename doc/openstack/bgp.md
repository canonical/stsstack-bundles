# Neutron Dynamic Routing with BGP

## Documentation

https://docs.openstack.org/neutron-dynamic-routing/latest/

## Example Usage

NOTE: based on https://docs.openstack.org/ocata/networking-guide/config-bgp-dynamic-routing.html

```
source novarc
neutron agent-list --agent-type="BGP dynamic routing agent"
openstack address scope create --share --ip-version 4 bgp
openstack subnet pool create --pool-prefix 10.5.0.0/16 \
                             --address-scope bgp provider
openstack subnet pool create --pool-prefix 192.168.21.0/24 \
                             --pool-prefix 192.168.22.0/24 \
                             --address-scope bgp --share selfservice
openstack network create provider --external \
                                  --provider-physical-network physnet1 \
                                  --provider-network-type flat
openstack subnet create --network provider --subnet-pool provider \
                        --prefix-length 16 \
                        --subnet-range 10.5.0.0/16 \
                        --allocation-pool start=10.5.150.0,end=10.5.200.254 \
                        --gateway 10.5.0.1 provider
```

```
openstack network create selfservice1
openstack network create selfservice2
openstack network create selfservice3
openstack subnet create --network selfservice1 --subnet-pool selfservice \
                        --subnet-range 192.168.21.0/24 \
                        --prefix-length 24 subnet1
openstack subnet create --network selfservice2 --subnet-pool selfservice \
                        --subnet-range 192.168.22.0/24 \
                        --prefix-length 24 subnet2
openstack subnet create --network selfservice3 subnet3 \
                        --subnet-range 192.168.23.0/24
```

```
openstack router create router1
openstack router create router2
openstack router create router3

openstack router add subnet router1 subnet1
openstack router add subnet router2 subnet2
openstack router add subnet router3 subnet3

neutron router-gateway-set router1 provider
neutron router-gateway-set router2 provider
neutron router-gateway-set router3 provider
```

```
openstack bpg speaker create --ip-version 4 \
                             --local-as 1234 bgpspeaker

openstack bgp speaker add network bgpspeaker provider
openstack bgp speaker show bgpspeaker
openstack bgp speaker list advertised routes bgpspeaker
openstack bgp peer create --peer-ip 192.0.2.1 \
                          --remote-as 4321 bgppeer
openstack bgp speaker add peer bgpspeaker bgppeer
openstack bgp speaker show bgppeer
```

# Assumes no l3-HA

```
dr_agent=`neutron agent-list --agent-type="BGP dynamic routing agent" -c id -f value`

openstack bpg dragent add speaker $dr_agent bgpspeaker
neutron bgp-dragent-list-hosting-speaker bgpspeaker
neutron bgp-speaker-list-on-dragent $dr_agent
```
