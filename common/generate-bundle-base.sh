#!/bin/bash -eu
#
# PLEASE AVOID PUTTING BUNDLE-SPECIFIC CODE IN HERE. INSTEAD USE THE INDIVIDUAL
# BUNDLE GENERATORS.
#
. $LIB_COMMON/helpers.sh

declare -a overlays=()
template=
generator_path=
charm_channel=
params_path=
bundle_name=
replay=false
run_command=false
list_bundles=false
create_model=false
use_stable_charms=false


while (($# > 0))
do
    case "$1" in
        --charm-channel)
            charm_channel=$2
            shift
            ;;
        --create-model)
            # creates a model using the value provided by --name
            create_model=true
            ;;
        --series|-s)
            # stub - see get_series
            shift
            ;;
        --release|-r)
            # stub - see get_release
            shift
            ;;
        --pocket|-p)
            # archive pocket e.g. proposed
            # stub - see get_pocket
            shift
            ;;
        --name|-n)
            # give bundle set a name and store under named dir
            bundle_name=$2
            shift
            ;;
        --replay)
            # replay the last recorded command if exists
            replay=true
            ;;
        --list)
            list_bundles=true
            ;;
        --run)
            # deploy bundle once generated
            run_command=true
            ;;
        --use-stable-charms)
            use_stable_charms=true
            ;;
        --internal-generator-path)
            generator_path=$2
            shift
            ;;
        --internal-template)
            template=$2
            shift
            ;;
        --internal-bundle-params)
            # parameters passed by custom generators
            params_path=$2
            shift
            ;;
        --internal-version-info)
            . $2
            shift
            ;;
        --internal-overlay)
            overlays+=( $2 )
            shift
            ;;
        -h|--help)
            _usage
            exit 0
            ;;
        *)
            echo "ERROR: invalid input '$1'"
            _usage
            exit 1
            ;;
    esac
    shift
done

if [ -z "$template" ]; then
    echo "ERROR: no template provided with --template"
    exit 1
elif [ -z "$generator_path" ]; then
    echo "ERROR: no generator path provided"
    exit 1
elif $create_model && [ -z "$bundle_name" ]; then
    echo "ERROR: no --name provided so cannot create Juju model" 
    exit 1
fi

if $create_model; then
    if `juju list-models| egrep -q "^$bundle_name\* "`; then
        echo -e "Juju model '$bundle_name' already exists and is the current context - skipping create\n"
    elif `juju list-models| egrep -q "^$bundle_name "`; then
        echo "Juju model '$bundle_name' already exists but is not the current context - switching context"
        juju switch $bundle_name
        echo ""
    else
        echo "Creating Juju model $bundle_name"
        juju add-model $bundle_name
        echo ""
    fi
fi

subdir="/${bundle_name}"
[ -n "${bundle_name}" ] || subdir=''
bundles_dir=$generator_path/b$subdir
if $list_bundles; then
    if [ -d "$bundles_dir" ]; then
        echo -e "Existing bundles:\n./b (default)"
        find $bundles_dir/* -maxdepth 0 -type d| egrep -v "$bundles_dir/o$" 
        echo ""
    else
        echo "There are currently no bundles."
    fi
    exit
fi
mkdir -p $bundles_dir

finish ()
{
    if $replay; then
        target=${bundles_dir}/command
        echo -e "INFO: replaying last known command (from $target)\n"
        [ -e "$target" ] || { echo "ERROR: $target does not exist"; exit 1; }
    fi
    echo "Command to deploy:"
    cat ${bundles_dir}/command
    if $run_command; then
        . ${bundles_dir}/command
    fi
    $replay && exit 0 || true
}

# Replay ignores any input args and just prints the previously generated
# command.
$replay && finish

# Each custom bundle generator can specify a set of parameters to apply to
# bundle templates as variable. They are converted into a sed statement that
# is passed in to here inside a file and run against the template(s). There is
# therefore no need to add parameters to this function and they should only
# be defined in the custom generators.
render () {
    # generic parameters only
    sed -i "s,__SERIES__,$series,g" $1

    # service-specific replacements
    if [ -n "$params_path" ]; then
        eval `cat $params_path` $1
    fi

    if $use_stable_charms; then
        sed -i -r 's,~openstack-charmers-next/,,g' $1
    fi
}

# Make copy of template, render, and store in named dir.
dtmp=`mktemp -d`
template_path=$dtmp/`basename $template`
bundle=${template_path%%.template}
cp $template $bundle
render $bundle
mv $bundle $bundles_dir
rmdir $dtmp

base_bundle=$bundles_dir/`basename $bundle`

target=${series}-$release
[ -z "$pocket" ] || target=${target}-$pocket

if $use_stable_charms; then
    msg="using stable charms"
else
    msg="using dev/next charms"
fi

channel_param=
if [ -n "$charm_channel" ]; then
    channel_param="--channel=$charm_channel"
fi

# Generate canonical (de-duped) list of --overlay args.
declare -a _overlays=()
declare -A overlay_dedup=()
app_version=`get_appversion "$release"`
[ -n "$app_version" ] && app_version="($app_version) "
if ((${#overlays[@]})); then
    mkdir -p $bundles_dir/o
    echo "Created $target ${app_version}bundle and overlays ($msg):"
    for overlay in ${overlays[@]}; do
        [ "${overlay_dedup[$overlay]:-null}" = "null" ] || continue
        cp overlays/$overlay $bundles_dir/o
        ((${#_overlays[@]}==0)) && _overlays+=("")  # left padding
        _overlays+=( --overlay $bundles_dir/o/$overlay )
        render $bundles_dir/o/$overlay
        overlay_dedup[$overlay]=true
        echo " + $overlay"
    done
    ((${#_overlays[@]})) && _overlays+=("")  # right padding
    echo ""
else
    echo -e "Created $target ${app_version}bundle ($msg)\n"
fi

echo -e "juju deploy ${base_bundle}${_overlays[@]:- }${channel_param}\n " > ${bundles_dir}/command
finish
