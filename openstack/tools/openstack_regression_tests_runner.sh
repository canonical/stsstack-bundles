#!/bin/bash -eu
#
# Run Openstack regression tests.
#
FUNC_TEST_PR=
FUNC_TEST_TARGET=
IMAGES_PATH=$HOME/tmp
MODIFY_BUNDLE_CONSTRAINTS=true

. $(dirname $0)/func_test_tools/common.sh

usage () {
    cat << EOF
USAGE: $(basename $0) OPTIONS

Run Openstack regression tests.

OPTIONS:
    --func-test-target TARGET_NAME
        Provide the name of a specific test target to run.
    --func-test-pr PR_ID
        Provides similar functionality to Func-Test-Pr in commit message. Set
        to zaza-openstack-tests Pull Request ID.
    --skip-modify-bundle-constraints
        By default we modify test bundle constraints to ensure that applications
        have the resources they need. For example nova-compute needs to have
        enough capacity to boot the vms required by the tests.
    --help
        This help message.
EOF
}

while (($# > 0)); do
    case "$1" in
        --debug)
            set -x
            ;;
        --func-test-target)
            FUNC_TEST_TARGET=$2
            shift
            ;;
        --func-test-pr)
            FUNC_TEST_PR=$2
            shift
            ;;
        --skip-modify-bundle-constraints)
            MODIFY_BUNDLE_CONSTRAINTS=false
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: invalid input '$1'"
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ -z $FUNC_TEST_TARGET ]]; then
    echo "ERROR: must provide a target name with --func-test-target"
    exit 1
fi

# This is required for magnum tests and zaza will look in swift if it is not cached so we need to cache it first.
mkdir -p $IMAGES_PATH
if [[ ! -f $IMAGES_PATH/fedora-coreos-35.qcow2 ]]; then
    wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220424.3.0/x86_64/fedora-coreos-35.20220424.3.0-openstack.x86_64.qcow2.xz -O $IMAGES_PATH/fedora-coreos-35.qcow2.xz
    (cd $IMAGES_PATH; xz -d fedora-coreos-35.qcow2.xz; )
fi

# Install dependencies
which yq &>/dev/null || sudo snap install yq

# Ensure zosci-config checked out and up-to-date
get_and_update_repo https://github.com/openstack-charmers/zosci-config

TOOLS_PATH=$(realpath $(dirname $0))/func_test_tools
CHARM_PATH=$PWD

echo "Running regression tests"

source ~/novarc
export {,TEST_}CIDR_EXT=$(openstack subnet show subnet_${OS_USERNAME}-psd-extra -c cidr -f value)
FIP_MAX=$(ipcalc $CIDR_EXT| awk '$1=="HostMax:" {print $2}')
FIP_MIN=$(ipcalc $CIDR_EXT| awk '$1=="HostMin:" {print $2}')
FIP_MIN_ABC=${FIP_MIN%.*}
FIP_MIN_D=${FIP_MIN##*.}
FIP_MIN=${FIP_MIN_ABC}.$(($FIP_MIN_D + 64))

CIDR_OAM=$(openstack subnet show subnet_${OS_USERNAME}-psd -c cidr -f value)
OAM_MAX=$(ipcalc $CIDR_OAM| awk '$1=="HostMax:" {print $2}')
OAM_MIN=$(ipcalc $CIDR_OAM| awk '$1=="HostMin:" {print $2}')
OAM_MIN_ABC=${OAM_MIN%.*}
OAM_MAX_D=${OAM_MAX##*.}
# Picking last two addresses and hoping they dont get used by Neutron.
export {OS,TEST}_VIP00=${OAM_MIN_ABC}.$(($OAM_MAX_D - 1))
export {OS,TEST}_VIP01=${OAM_MIN_ABC}.$(($OAM_MAX_D - 2))

# More information on config https://github.com/openstack-charmers/zaza/blob/master/doc/source/runningcharmtests.rst
export {,TEST_}NET_ID=$(openstack network show net_${OS_USERNAME}-psd-extra -f value -c id)
export {,TEST_}FIP_RANGE=$FIP_MIN:$FIP_MAX
export {,TEST_}GATEWAY=$(openstack subnet show subnet_${OS_USERNAME}-psd-extra -c gateway_ip -f value)
export {,TEST_}NAME_SERVER=91.189.91.131
export {,TEST_}CIDR_PRIV=192.168.21.0/24
export {,TEST_}SWIFT_IP=10.140.56.22
export TEST_MODEL_SETTINGS="image-stream=released;default-series=jammy;test-mode=true;transmit-vendor-metrics=false"
# We need to set TEST_JUJU3 as well as the constraints file
# Ref: https://github.com/openstack-charmers/zaza/blob/e96ab098f00951079fccb34bc38d4ae6ebb38606/setup.py#L47
export TEST_JUJU3=1

# NOTE: this should not be necessary for > juju 2.x but since we still have a need for it we add it in
export TEST_ZAZA_BUG_LP1987332=1

# Some charms point to an upstream constraints file that installs python-libjuju 2.x so we need to do this to ensure we get 3.x
export TEST_CONSTRAINTS_FILE=https://raw.githubusercontent.com/openstack-charmers/zaza/master/constraints-juju34.txt

# NOTE: this is the default applied in zaza-openstack-tests code but setting
#       explicitly so we can use locally.
export TEST_TMPDIR=$HOME/tmp
mkdir -p $TEST_TMPDIR

# required by octavia-tempest-plugin
# go build -a -ldflags '-s -w -extldflags -static' -o test_server.bin octavia_tempest_plugin/contrib/test_server/test_server.go
if [[ ! -f $TEST_TMPDIR/test_server.bin ]]; then
    cp $(dirname $0)/tempest_test_resources/test_server.bin $TEST_TMPDIR
fi

LOGFILE=$(mktemp --suffix=-openstack-release-test-results)
(
    # Ensure charmed-openstack-tester checked out and up-to-date
    get_and_update_repo https://github.com/openstack-charmers/charmed-openstack-tester

    # Ensure nova-compute has enough resources to create vms in tests.
    if $MODIFY_BUNDLE_CONSTRAINTS; then
        for f in tests/distro-regression/tests/bundles/*.yaml; do
            # Dont do this if the test does not have nova-compute
            if $(grep -q "nova-compute:" $f); then
                if [[ $(yq '.applications' $f) = null ]]; then
                    yq -i '.services.nova-compute.constraints="root-disk=40G mem=4G"' $f
                else
                    yq -i '.applications.nova-compute.constraints="root-disk=40G mem=4G"' $f
                fi
            fi
        done
    fi

    # If a func test pr is provided switch to that pr.
    if [[ -n $FUNC_TEST_PR ]]; then
        # We use the zosci-config tools to do this.
        MSG=$(echo "Func-Test-Pr: https://github.com/openstack-charmers/zaza-openstack-tests/pull/$FUNC_TEST_PR"| base64)
        ~/zosci-config/roles/handle-func-test-pr/files/process_func_test_pr.py -f ./test-requirements.txt "$MSG"
    fi

    tox -re func-target -- $FUNC_TEST_TARGET || true
    model=$(juju list-models| egrep -o "^zaza-\S+"|tr -d '*')
) 2>&1 | tee $LOGFILE
echo -e "\nResults also saved to $LOGFILE"
