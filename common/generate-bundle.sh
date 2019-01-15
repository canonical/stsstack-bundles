#!/bin/bash -eu
#
# Author: edward.hope-morley@canonical.com
#
# Description: Use this tool to generate a Juju (2.x) native-format bundle e.g.
#
#     Xenial + Queens UCA: ./generate-bundle.sh --series xenial --release queens
#
#     Bionic (Queens) Proposed: ./generate-bundle.sh --series bionic --pocket proposed
#
#     Bionic + Stein UCA: ./generate-bundle.sh --release stein
#
#
series=bionic
series_provided=false
release=
pocket=
template=
path=
params_path=
bundle_name=
replay=false
run_command=false
list_bundles=false
create_model=false
use_stable_charms=false
declare -a overlays=()
declare -A lts=( [trusty]=icehouse
                 [xenial]=mitaka
                 [bionic]=queens )

. `dirname $0`/helpers.sh

while (($# > 0))
do
    case "$1" in
        --create-model)
            # creates a model using the value provided by --name
            create_model=true
            ;;
        --overlay)
            overlays+=( $2 )
            shift
            ;;
        --path)
            path=$2
            shift
            ;;
        --series|-s)
            series=$2
            series_provided=true
            shift
            ;;
        --release|-r)
            release=$2
            shift
            ;;
        --pocket|-p)
            # archive pocket e.g. proposed
            pocket=$2
            shift
            ;;
        --template|-t)
            template=$2
            shift
            ;;
        --bundle-params)
            # parameters passed by custom generators
            params_path=$2
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

if $create_model; then
    if [ -z "$bundle_name" ]; then
        echo "ERROR: no --name provided so cannot create Juju model" 
        exit 1
    else
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
fi

[ -z "$template" ] || [ -z "$path" ] && \
    { echo "ERROR: no template provided with --template"; exit 1; }

ltsmatch ()
{
    [ -z "$release" ] && return 0
    for s in ${!lts[@]}; do
        [ "$s" = "$1" ] && [ "${lts[$s]}" = "$2" ] && return 0
    done
    return 1
}

subdir="/${bundle_name}"
[ -n "${bundle_name}" ] || subdir=''
bundles_dir=`dirname $path`/b$subdir
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

# Replay ingores any args and just prints the previously generated command
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
    eval `cat ${bundles_dir}/command`
fi
$replay && exit 0
}
$replay && finish

if [ -n "$release" ] && ! ltsmatch $series $release; then
    declare -a idx=( ${!lts[@]} )
    i=${#idx[@]}
    _series=${idx[$((--i))]}
    series_plus_one=$_series
    while ! [[ "$release" > "${lts[$_series]}" ]] && ((i>=0)); do
        s=${idx[$((i))]}
        if ! $series_provided && [ "${lts[$s]}" = "$release" ]; then
            _series=$s
            break
        fi
        series_plus_one=$s
        _series=${idx[$((--i))]}
    done
    # ensure correct series
    if $series_provided; then
        if ! [ "$series" = "$_series" ]; then
            echo "Series auto-corrected from '$series' to '$_series'"
        fi
    fi
    series=$_series
else
    release=${lts[$series]} 
fi

source=''
if ! ltsmatch $series $release ; then
  source="cloud:${series}-${release}"
fi

if [ -n "$pocket" ]; then
  if [ -n "$source" ]; then
    source="${source}\/${pocket}"
  else
    source="$pocket";
  fi
fi

os_origin=$source
[ "$os_origin" = "proposed" ] && os_origin="distro-proposed"

render () {
# generic replacements
sed -i -e "s/__SERIES__/$series/g" \
       -e "s/__OS_ORIGIN__/$os_origin/g" \
       -e "s/__SOURCE__/$source/g" $1

# service-specific replacements
if [ -n "$params_path" ]; then
    eval `cat $params_path` $1
fi

if $use_stable_charms; then
    sed -i -r 's,~openstack-charmers-next/,,g' $1
fi
}

fout=`mktemp -d`/`basename $template| sed 's/.template//'`
cp $template $fout
render $fout

mv $fout $bundles_dir
target=${series}-$release
[ -z "$pocket" ] || target=${target}-$pocket
result=$bundles_dir/`basename $fout`

# remove duplicate overlays
declare -a _overlays=()
declare -A overlay_dedup=()
if $use_stable_charms; then
    msg="using stable charms"
else
    msg="using dev/next charms"
fi
if ((${#overlays[@]})); then
    mkdir -p $bundles_dir/o
    echo "Created $target bundle and overlays ($msg):"
    for overlay in ${overlays[@]}; do
        [ "${overlay_dedup[$overlay]:-null}" = "null" ] || continue
        cp overlays/$overlay $bundles_dir/o
        _overlays+=( --overlay $bundles_dir/o/$overlay )
        render $bundles_dir/o/$overlay
        overlay_dedup[$overlay]=true
        echo " + $overlay"
    done
    echo ""
else
    echo -e "Created $target bundle ($msg)\n"
fi

echo -e "juju deploy ${result} ${_overlays[@]:-}\n" > ${bundles_dir}/command
finish
