#!/bin/bash -eu
#
# Run Charmed Openstack CI tests manually in a similar way to how they are run
# by OpenStack CI (OSCI).
#
# Usage: clone/fetch charm to test and run from within charm root dir.
#
FUNC_TEST_PR=
FUNC_TEST_TARGET=()
MANUAL_FUNCTESTS=false
MODIFY_BUNDLE_CONSTRAINTS=true
REMOTE_BUILD=
SKIP_BUILD=false
SLEEP=
WAIT_ON_DESTROY=true
RERUN_PHASE=

. $(dirname $0)/func_test_tools/common.sh

usage () {
    cat << EOF
USAGE: $(basename $0) OPTIONS

Run OpenStack charms functional tests manually in a similar way to how
Openstack CI (OSCI) would do it. This tool should be run from within a charm
root.

Not all charms use the same versions and dependencies and an attempt is made to
cover this here but in some cases needs to be dealt with as a pre-requisite to
running the tool. For example some charms need their tests to be run using
python 3.8 and others python 3.10. Some tests might require Juju 2.9 and others
Juju 3.x - the assumption in this runner is that Juju 3.x is ok to use.

OPTIONS:
    --func-test-target TARGET_NAME
        Provide the name of a specific test target to run. If none provided
        all tests are run based on what is defined in osci.yaml i.e. will do
        what osci would do by default. This option can be provided more than
        once.
    --func-test-pr PR_ID
        Provides similar functionality to Func-Test-Pr in commit message. Set
        to zaza-openstack-tests Pull Request ID.
    --no-wait
        By default we wait before destroying the model after a test run. This
        flag can used to override that behaviour.
    --manual-functests
        Runs functest commands separately (deploy,configure,test) instead of
        the entire suite.
    --remote-build USER@HOST,GIT_PATH
        Builds the charm in a remote location and transfers the charm file over.
        The destination needs to be prepared for the build and authorized for
        ssh. Implies --skip-build. Specify parameter as <destination>,<path>.
        Example: --remote-build ubuntu@10.171.168.1,~/git/charm-nova-compute
    --rerun deploy|configure|test
        Re-run a specific phase. This is useful if the deployment is part of a
        test run that failed, perhaps because of an infra issue, but can safely
        continue where it left off.
    --skip-build
        Skip building charm if already done to save time.
    --skip-modify-bundle-constraints
        By default we modify test bundle constraints to ensure that applications
        have the resources they need. For example nova-compute needs to have
        enough capacity to boot the vms required by the tests.
    --sleep TIME_SECS
        Specify amount of seconds to sleep between functest steps.
    --help
        This help message.
EOF
}

run_test_phase ()
{
    local phase=$1
    local model=$2
    local bundle=${3:-""}
    local args=
    local ret=

    unit_errors=$(juju status --format json| jq '.applications[]| select(.units!=null)| .units[]."workload-status"| select(.current=="error")')
    if [[ -n $unit_errors ]]; then
        echo -e "\nNOTE: before you run a phase make sure that any hook errors have been resolved.\n"
        echo "$unit_errors"
        read -p "press [ENTER] to continue"
    fi

    . .tox/func-target/bin/activate
    echo "Running '$phase' phase..."
    if [[ $phase == deploy ]]; then
        if [[ -z $bundle ]]; then
            read -p "Enter name of bundle we are running (from tests/bundles/): " bundle
        fi
        args="-b tests/bundles/$bundle.yaml"
    fi
    functest-$phase -m $model ${args}
    ret=$?
    deactivate
    return $ret
}


retry_on_fail ()
{
    local model=$1
    local bundle=$2
    local ret=
    juju switch $model
cat << EOF
The tests have failed. You now have the choice to either exit or re-run a test phase.

To re-run the tests you need to choose which of the following phases you want to run:
  * deploy
  * configure
  * test

EOF
    read -p "Enter phase to run (exit|deploy|configure|test): " phase
    case "$phase" in
        deploy|configure|test)
            while true; do
                run_test_phase $phase $model $bundle
                ret=$?
                if (($ret)); then
                    read -p "Failed. Try $phase phase again? [Y/n]" answer
                    [[ -z $answer ]] || [[ ${answer,,} == y ]] || break
                else
                    [[ $phase == test ]] && break
                    [[ $phase == deploy ]] && phase=configure || phase=test
                fi
            done
        ;;
        *)
            echo "ERROR: unrecognised phase name '$phase'"
            exit 1
        ;;
    esac
    return $ret
}


while (($# > 0)); do
    case "$1" in
        --debug)
            set -x
            ;;
        --func-test-target)
            FUNC_TEST_TARGET+=( $2 )
            shift
            ;;
        --func-test-pr)
            FUNC_TEST_PR=$2
            shift
            ;;
        --manual-functests)
            MANUAL_FUNCTESTS=true
            ;;
        --no-wait)
            WAIT_ON_DESTROY=false
            ;;
        --remote-build)
            REMOTE_BUILD=$2
            SKIP_BUILD=true
            shift
            ;;
        --rerun)
            RERUN_PHASE=$2
            [[ $2 = deploy ]] || [[ $2 = configure ]] || [[ $2 = test ]] || opt_error $1 $2
            shift
            ;;
        --skip-modify-bundle-constraints)
            MODIFY_BUNDLE_CONSTRAINTS=false
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        --sleep)
            SLEEP=$2
            shift
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

# Install dependencies
which yq &>/dev/null || sudo snap install yq

# Ensure zosci-config checked out and up-to-date
get_and_update_repo https://github.com/openstack-charmers/zosci-config

TOOLS_PATH=$(realpath $(dirname $0))/func_test_tools
# This is used generally to identify the charm root.
export CHARM_ROOT_PATH=$PWD

# Get commit we are running tests against.
COMMIT_ID=$(git -C $CHARM_ROOT_PATH rev-parse --short HEAD)
CHARM_NAME=$(awk '/^name: .+/{print $2}' metadata.yaml)

echo "Running functional tests for charm $CHARM_NAME commit $COMMIT_ID"

source ~/novarc
export {,TEST_}CIDR_EXT=$(openstack subnet show subnet_${OS_USERNAME}-psd-extra -c cidr -f value)
FIP_MAX=$(ipcalc $CIDR_EXT| awk '$1=="HostMax:" {print $2}')
FIP_MIN=$(ipcalc $CIDR_EXT| awk '$1=="HostMin:" {print $2}')
FIP_MIN_ABC=${FIP_MIN%.*}
FIP_MIN_D=${FIP_MIN##*.}
FIP_MIN=${FIP_MIN_ABC}.$(($FIP_MIN_D + 64))

# Setup vips needed by zaza tests.
for ((i=2;i;i-=1)); do
    export {OS,TEST}_VIP0$((i-1))=$(create_zaza_vip 0$i)
done

# More information on config https://github.com/openstack-charmers/zaza/blob/master/doc/source/runningcharmtests.rst
export {,TEST_}NET_ID=$(openstack network show net_${OS_USERNAME}-psd-extra -f value -c id)
export {,TEST_}FIP_RANGE=$FIP_MIN:$FIP_MAX
export {,TEST_}GATEWAY=$(openstack subnet show subnet_${OS_USERNAME}-psd-extra -c gateway_ip -f value)
export {,TEST_}NAME_SERVER=91.189.91.131
export {,TEST_}CIDR_PRIV=192.168.21.0/24
#export SWIFT_IP=10.140.56.22
export TEST_MODEL_SETTINGS="image-stream=released;default-series=jammy;test-mode=true;transmit-vendor-metrics=false"
# We need to set TEST_JUJU3 as well as the constraints file
# Ref: https://github.com/openstack-charmers/zaza/blob/e96ab098f00951079fccb34bc38d4ae6ebb38606/setup.py#L47
export TEST_JUJU3=1

# NOTE: this should not be necessary for > juju 2.x but since we still have a need for it we add it in
export TEST_ZAZA_BUG_LP1987332=1

# Some charms point to an upstream constraints file that installs python-libjuju 2.x so we need to do this to ensure we get 3.x
export TEST_CONSTRAINTS_FILE=https://raw.githubusercontent.com/openstack-charmers/zaza/master/constraints-juju34.txt

LOGFILE=$(mktemp --suffix=-charm-func-test-results)
(
# 2. Build
if ! $SKIP_BUILD; then
    # default value is 1.5/stable, assumed that later charm likely have charmcraft_channel value
    CHARMCRAFT_CHANNEL=$(grep charmcraft_channel osci.yaml | sed -r 's/.+:\s+(\S+)/\1/')
    sudo snap refresh charmcraft --channel ${CHARMCRAFT_CHANNEL:-"1.5/stable"}

    # ensure lxc initialised
    lxd init --auto || true

    tox -re build
elif [[ -n $REMOTE_BUILD ]]; then
    IFS=',' read -ra remote_build_params <<< "$REMOTE_BUILD"
    REMOTE_BUILD_DESTINATION=${remote_build_params[0]}
    REMOTE_BUILD_PATH=${remote_build_params[1]}
    ssh $REMOTE_BUILD_DESTINATION "cd $REMOTE_BUILD_PATH;git log -1;rm -rf *.charm;tox -re build"
    rm -rf *.charm
    rsync -vza $REMOTE_BUILD_DESTINATION:$REMOTE_BUILD_PATH/*.charm .
fi

# 3. Run functional tests.

# If a func test pr is provided switch to that pr.
if [[ -n $FUNC_TEST_PR ]]; then
    apply_func_test_pr $FUNC_TEST_PR
fi

declare -A func_target_state=()
declare -a func_target_order
if ((${#FUNC_TEST_TARGET[@]})); then
    for t in ${FUNC_TEST_TARGET[@]}; do
        func_target_state[$t]=null
        func_target_order+=( $t )
    done
else
    voting_targets=()
    non_voting_targets=()
    for target in $(python3 $TOOLS_PATH/identify_charm_func_test_jobs.py); do
        if $(python3 $TOOLS_PATH/test_is_voting.py $target); then
            voting_targets+=( $target )
        else
            non_voting_targets+=( $target )
        fi
    done
    # Ensure voting targets processed first.
    for target in ${voting_targets[@]} ${non_voting_targets[@]}; do
        func_target_order+=( $target )
        func_target_state[$target]=null
    done
fi

# Ensure nova-compute has enough resources to create vms in tests. Not all
# charms have bundles with constraints set so we need to cover both cases here.
if $MODIFY_BUNDLE_CONSTRAINTS; then
    (
    [[ -d src ]] && cd src
    for f in tests/bundles/*.yaml; do
        # Dont do this if the test does not have nova-compute
        if $(grep -q "nova-compute:" $f); then
            if [[ $(yq '.applications' $f) = null ]]; then
                yq -i '.services.nova-compute.constraints="root-disk=80G mem=8G"' $f
            else
                yq -i '.applications.nova-compute.constraints="root-disk=80G mem=8G"' $f
            fi
        fi
    done
    )
fi

if [[ -n $RERUN_PHASE ]]; then
    fail=false
    [[ -d src ]] && pushd src &>/dev/null || true
    model=$(juju list-models| egrep -o "^zaza-\S+"|tr -d '*')
    echo "Re-running functest-$RERUN_PHASE (model=$model)"
    juju switch $model
    ((${#FUNC_TEST_TARGET[@]}==1)) && bundle=${FUNC_TEST_TARGET[0]} || bundle=
    run_test_phase $RERUN_PHASE $model $bundle
    popd
fi

first=true
init_noop_target=true
for target in ${func_target_order[@]}; do
    [[ -z $RERUN_PHASE ]] || continue

    # Destroy any existing zaza models to ensure we have all the resources we
    # need.
    destroy_zaza_models

    # Only rebuild on first run.
    if $first; then
        first=false
        tox_args="-re func-target"
    else
        tox_args="-e func-target"
    fi
    [[ -d src ]] && pushd src &>/dev/null || true
    fail=false
    _target="$(python3 $TOOLS_PATH/extract_job_target.py $target)"
    if ! $MANUAL_FUNCTESTS; then
        tox ${tox_args} -- $_target || fail=true
        model=$(juju list-models| egrep -o "^zaza-\S+"|tr -d '*')
    else
        $TOOLS_PATH/manual_functests_runner.sh "$_target" $SLEEP $init_noop_target || fail=true
        model=test-$target
        init_noop_target=false
    fi

    $fail && retry_on_fail "$model" "$target" && fail=false
    if $fail; then
        func_target_state[$target]='fail'
    else
        func_target_state[$target]='success'
    fi

    if $WAIT_ON_DESTROY; then
        read -p "Destroy model '$model' and run next test? [ENTER]"
    fi

    # Cleanup before next run
    destroy_zaza_models
done
popd &>/dev/null || true

# Report results
echo -e "\nTest results for charm $CHARM_NAME functional tests @ commit $COMMIT_ID:"
for target in ${func_target_order[@]}; do
    if $(python3 $TOOLS_PATH/test_is_voting.py $target); then
        voting_info=""
    else
        voting_info=" (non-voting)"
    fi

    if [[ ${func_target_state[$target]} = null ]]; then
        echo "  * $target: SKIPPED$voting_info"
    elif [[ ${func_target_state[$target]} = success ]]; then
        echo "  * $target: SUCCESS$voting_info"
    else
        echo "  * $target: FAILURE$voting_info"
    fi
done
) 2>&1 | tee $LOGFILE
echo -e "\nResults also saved to $LOGFILE"
