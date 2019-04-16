#!/bin/bash -eu
CACHED_STDIN=( $@ )
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# vars
opts=(
--internal-template openstack.yaml.template
--internal-generator-path $0
)
msgs=()
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Series & Release Info
cat << 'EOF' > $f_rel_info
EOF
cat $LIB_COMMON/openstack_release_info.sh >> $f_rel_info

# defaults
parameters[__NUM_COMPUTE_UNITS__]=1
parameters[__NUM_CEPH_MON_UNITS__]=1
parameters[__NUM_NEUTRON_GATEWAY_UNITS__]=1
parameters[__NEUTRON_FW_DRIVER__]=openvswitch  # legacy is iptables_hybrid
parameters[__SSL_CA__]=
parameters[__SSL_CERT__]=
parameters[__SSL_KEY__]=

trap_help ${CACHED_STDIN[@]:-""}
while (($# > 0))
do
    case "$1" in
        --num-compute)  #__OPT__type:<int>
            parameters[__NUM_COMPUTE_UNITS__]=$2
            shift
            ;;
        --barbican)
            assert_min_release queens "barbican" ${CACHED_STDIN[@]}
            overlays+=( "barbican.yaml" )
            ;;
        --bgp)
            assert_min_release queens "dynamic routing" ${CACHED_STDIN[@]}
            overlays+=( "neutron-bgp.yaml" )
            ;;
        --ceph)
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            ;;
        --num-ceph-mons)  #__OPT__type:<int>
            parameters[__NUM_CEPH_MON_UNITS__]=$2
            shift
            ;;
        --ceph-rgw)
            overlays+=( "ceph-rgw.yaml" )
            ;;
        --ceph-rgw-multisite)
            overlays+=( "ceph-rgw-multisite.yaml" )
            ;;
        --designate)
            assert_min_release ocata "designate" ${CACHED_STDIN[@]}
            overlays+=( "neutron-ml2dns.yaml" )
            overlays+=( "memcached.yaml" )
            overlays+=( "designate.yaml" )
            ;;
        --dvr)
            overlays+=( "neutron-dvr.yaml" )
            get_param $1 __DVR_DATA_PORT__ 'Please provide DVR data-port (space-separated list of interface names or mac addresses): '
            ;;
        --dvr-l3ha*)
            get_units $1 __NUM_AGENTS_PER_ROUTER__ 3
            # if we are a dep then don't get gateway units
            if ! `has_opt '--dvr-snat-l3ha' ${CACHED_STDIN[@]}`; then
                get_units $1 __NUM_NEUTRON_GATEWAY_UNITS__ 3
            fi
            overlays+=( "neutron-dvr.yaml" )
            overlays+=( "neutron-l3ha.yaml" )
            get_param_forced $1 __DVR_DATA_PORT__ 'Please provide DVR data-port (space-separated list of interface names or mac addresses): '
            ;;
        --dvr-snat-l3ha*)
            assert_min_release queens "dvr-snat-l3ha" ${CACHED_STDIN[@]}
            get_units $1 __NUM_COMPUTE_UNITS__ 3
            get_units $1 __NUM_AGENTS_PER_ROUTER__ 3
            overlays+=( "neutron-dvr-snat.yaml" )
            set -- $@ --dvr-l3ha:${parameters[__NUM_AGENTS_PER_ROUTER__]}
            parameters[__NUM_NEUTRON_GATEWAY_UNITS__]=0
            ;;
        --dvr-snat*)
            assert_min_release queens "dvr-snat" ${CACHED_STDIN[@]}
            get_units $1 __NUM_COMPUTE_UNITS__ 1
            overlays+=( "neutron-dvr.yaml" )
            overlays+=( "neutron-dvr-snat.yaml" )
            get_param_forced $1 __DVR_DATA_PORT__ 'Please provide DVR data-port (space-separated list of interface names or mac addresses): '
            parameters[__NUM_NEUTRON_GATEWAY_UNITS__]=0
            ;;
        --lma)
            # Logging Monitoring and Analysis
            set -- $@ --graylog --grafana
            ;;
        --graylog)
            overlays+=( "graylog.yaml ")
            msgs+=( "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor" )
            ;;
        --grafana)
            overlays+=( "grafana.yaml ")
            overlays+=( "prometheus-openstack.yaml ")
            if `has_opt '--ceph' ${CACHED_STDIN[@]}`; then
                overlays+=( "prometheus-ceph.yaml ")
            fi
            msgs+=( "NOTE: telegraf has been related to core openstack services but you may need to add to others you have in your deployment" )
            ;;
        --heat)
            overlays+=( "heat.yaml ")
            ;;
        --ldap)
            overlays+=( "ldap.yaml" )
            ;;
        --neutron-fw-driver)  #__OPT__type:[openvswitch|iptables_hybrid] (default=openvswitch)
            assert_min_release newton "openvswitch driver" ${CACHED_STDIN[@]}
            parameters[__NEUTRON_FW_DRIVER__]=$2
            shift
            ;;
        --l3ha*)
            get_units $1 __NUM_NEUTRON_GATEWAY_UNITS__ 3
            get_units $1 __NUM_AGENTS_PER_ROUTER__ 3
            overlays+=( "neutron-l3ha.yaml" )
            ;;
        --keystone-v3)
            # useful for <= pike since queens is v3 only
            overlays+=( "keystone-v3.yaml" )
            ;;
        --mysql-ha*)
            get_units $1 __NUM_MYSQL_UNITS__ 3
            overlays+=( "mysql-ha.yaml" )
            ;;
        --ml2dns)
            # this is internal dns integration, for external use --designate
            overlays+=( "neutron-ml2dns.yaml" )
            ;;
        --nova-cells)
            assert_min_release rocky "nova cells" ${CACHED_STDIN[@]}
            overlays+=( "nova-cells.yaml" )
            ;;
        --octavia)
            # >= Rocky
            assert_min_release rocky "octavia" ${CACHED_STDIN[@]}
            overlays+=( "barbican.yaml" )
            overlays+=( "vault.yaml" )
            overlays+=( "vault-openstack.yaml" )
            overlays+=( "octavia.yaml" )
            ;;
        --rabbitmq-server-ha*)
            get_units $1 __NUM_RABBIT_UNITS__ 3
            overlays+=( "rabbitmq-server-ha.yaml" )
            ;;
        --rsyslog)
            overlays+=( "rsyslog.yaml" )
            ;;
        --ssl)
            if ! `has_opt '--replay' ${CACHED_STDIN[@]}`; then
                (cd ssl; ./create_ca_cert.sh;)
                parameters[__SSL_CA__]=`base64 ssl/results/cacert.pem| tr -d '\n'`
                parameters[__SSL_CERT__]=`base64 ssl/results/servercert.pem| tr -d '\n'`
                parameters[__SSL_KEY__]=`base64 ssl/results/serverkey.pem| tr -d '\n'`
                # Make everything HA with 1 unit (unless --ha has already been set)
                if ! `has_opt '--ha[:0-9]*$' ${CACHED_STDIN[@]}`; then
                    set -- $@ --ha:1
                fi
            fi
            ;;
        --nova-network)
            # NOTE(hopem) yes this is a hack and we'll get rid of it hwen nova-network is finally no more
            opts+=( "--internal-template openstack-nova-network.yaml.template" )
            ;;
        --cinder-ha*)
            get_units $1 __NUM_CINDER_UNITS__ 3
            overlays+=( "cinder-ha.yaml" )
            ;;
        --designate-ha*)
            get_units $1 __NUM_DESIGNATE_UNITS__ 3
            set -- $@ --designate
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
            overlays+=( "memcached.yaml" )
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
            assert_min_release pike "gnocchi" ${CACHED_STDIN[@]} 
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
            assert_min_release queens "vault" ${CACHED_STDIN[@]}
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            overlays+=( "vault.yaml" )
            overlays+=( "vault-ceph.yaml" )
            overlays+=( "vault-openstack.yaml" )
            ;;
        --ha*)
            get_units $1 __NUM_HA_UNITS__ 3
            units=${parameters[__NUM_HA_UNITS__]}
            # This is HA for "core" service apis only.
            set -- $@ --cinder-ha:$units --glance-ha:$units \
                      --keystone-ha:$units --neutron-api-ha:$units \
                      --nova-cloud-controller-ha:$units
            ;;
        --list-overlays)  #__OPT__
            list_overlays
            exit
            ;;
        *)
            opts+=( $1 )
            ;;
    esac
    shift
done

if ((${#msgs[@]})); then
  for m in "${msgs[@]}"; do
    echo -e "$m"
  done
read -p "Hit [ENTER] to continue"
fi

generate $f_rel_info
