#!/bin/bash -eu
# imports
. `dirname $0`/common/helpers.sh

# vars
opts=(
--template openstack.yaml.template
--path $0
)

# defaults
parameters[__NUM_COMPUTE_UNITS__]=1

list_overlays ()
{
    echo "Supported overlays:"
    sed -r 's/.+\s+(--[[:alnum:]\-]+\*?).+/\1/g;t;d' `basename $0`| \
        egrep -v "\--list-overlays|--num-compute"
}

while (($# > 0))
do
    case "$1" in
        --num-compute)
            parameters[__NUM_COMPUTE_UNITS__]=$2
            shift
            ;;
        --barbican)
            overlays+=( "barbican.yaml" )
            ;;
        --bgp)
            overlays+=( "neutron-bgp.yaml" )
            ;;
        --ceph)
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            ;;
        --ceph-rgw)
            overlays+=( "ceph-rgw.yaml" )
            ;;
        --ceph-rgw-multisite)
            overlays+=( "ceph-rgw-multisite.yaml" )
            ;;
        --designate)
            overlays+=( "memcached.yaml" )
            overlays+=( "designate.yaml" )
            ;;
        --dvr)
            overlays+=( "neutron-dvr.yaml" )
            get_param __DVR_DATA_PORT__ 'Please provide DVR data-port (space-separated list of interface names or mac addresses): '
            ;;
        --graylog)
            overlays+=( "graylog.yaml ")
            echo "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor"
            ;;
        --grafana)
            overlays+=( "grafana.yaml ")
            echo "NOTE: you will need to manually relate grafana (telegraf) to any services you want to monitor"
            ;;
        --heat)
            overlays+=( "heat.yaml ")
            ;;
        --ldap)
            overlays+=( "ldap.yaml" )
            ;;
        --vrrp*)
            get_units $1 __NUM_NEUTRON_GATEWAY_UNITS__ 3
            overlays+=( "neutron-vrrp.yaml" )
            ;;
        --keystone-v3)
            overlays+=( "keystone-v3.yaml" )
            ;;
        --mysql-ha*)
            get_units $1 __NUM_MYSQL_UNITS__ 3
            overlays+=( "mysql-ha.yaml" )
            ;;
        --rabbitmq-server-ha*)
            get_units $1 __NUM_RABBIT_UNITS__ 3
            overlays+=( "rabbitmq-server-ha.yaml" )
            ;;
        --rsyslog)
            overlays+=( "rsyslog.yaml" )
            ;;
        --nova-network)
            # NOTE(hopem) yes this is a hack and we'll get rid of it hwen nova-network is finally no more
            opts+=(--template openstack-nova-network.yaml.template)
            ;;
        --cinder-ha*)
            get_units $1 __NUM_CINDER_UNITS__ 3
            overlays+=( "cinder-ha.yaml" )
            ;;
        --designate-ha*)
            get_units $1 __NUM_DESIGNATE_UNITS__ 3
            overlays+=( "memcached.yaml" )
            overlays+=( "designate.yaml" )
            overlays+=( "designate-ha.yaml" )
            ;;
        --glance-ha*)
            get_units $1 __NUM_GLANCE_UNITS__ 3
            overlays+=( "glance-ha.yaml" )
            ;;
        --heat-ha*)
            get_units $1 __NUM_HEAT_UNITS__ 3
            overlays+=( "heat.yaml ")
            overlays+=( "heat-ha.yaml ")
            ;;
        --keystone-ha*)
            get_units $1 __NUM_KEYSTONE_UNITS__ 3
            overlays+=( "keystone-ha.yaml" )
            ;;
        --neutron-api-ha*)
            get_units $1 __NUM_NEUTRON_API_UNITS__ 3
            overlays+=( "neutron-api-ha.yaml" )
            ;;
        --nova-cloud-controller-ha*)
            get_units $1 __NUM_NOVACC_UNITS__ 3
            overlays+=( "nova-cloud-controller-ha.yaml" )
            ;;
        --openstack-dashboard-ha*)
            get_units $1 __NUM_HORIZON_UNITS__ 3
            overlays+=( "openstack-dashboard-ha.yaml" )
            ;;
        --swift)
            overlays+=( "swift.yaml" )
            ;;
        --swift-ha*)
            get_units $1 __NUM_SWIFT_PROXY_UNITS__ 3
            overlays+=( "swift-ha.yaml" )
            ;;
        --telemetry|--telemetry-gnocchi)
            # ceilometer + aodh + gnocchi (>= pike)
            overlays+=( "ceph.yaml" )
            overlays+=( "gnocchi.yaml" )
            overlays+=( "memcached.yaml" )
            overlays+=( "telemetry.yaml" )
            ;;
        --telemetry-legacy-aodh)
            # ceilometer + aodh + mongodb (<= pike)
            overlays+=( "telemetry-legacy-aodh.yaml" )
            ;;
        --telemetry-legacy)
            # ceilometer + mongodb (<= pike)
            overlays+=( "telemetry-legacy.yaml" )
            ;;
        --telemetry-ha*)
            get_units $1 __NUM_TELEMETRY_UNITS__ 3
            overlays+=( "telemetry.yaml" )
            overlays+=( "telemetry-ha.yaml" )
            ;;
        --vault)
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            overlays+=( "vault.yaml" )
            ;;
        --ha)
            # This is HA for services in the base bundle only.
            overlays+=( "cinder-ha.yaml" )
            overlays+=( "glance-ha.yaml" )
            overlays+=( "keystone-ha.yaml" )
            overlays+=( "neutron-api-ha.yaml" )
            overlays+=( "nova-cloud-controller-ha.yaml" )
            overlays+=( "openstack-dashboard-ha.yaml" )
            overlays+=( "rabbitmq-server-ha.yaml" )
            overlays+=( "mysql-ha.yaml" )
            ;;
        --list-overlays)
            list_overlays
            exit
            ;;
        *)
            opts+=( $1 )
            ;;
    esac
    shift
done

generate
